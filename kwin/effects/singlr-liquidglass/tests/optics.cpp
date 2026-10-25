// SPDX-License-Identifier: GPL-2.0-or-later
// Actual production GLSL on surfaceless EGL. This is NOT a KWin screenshot.
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include "../shader.h"
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <cmath>
#include <algorithm>
#include <cstdio>
#include <stdexcept>

static GLuint compile(GLenum type, const char *source) {
    GLuint id = glCreateShader(type);
    glShaderSource(id, 1, &source, nullptr); glCompileShader(id);
    GLint ok; glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    char log[8192]; glGetShaderInfoLog(id, sizeof(log), nullptr, log);
    if (!ok) throw std::runtime_error(log);
    return id;
}
static double difference(const QImage &a, const QImage &b, QRect rect) {
    double sum = 0;
    for (int y=rect.top(); y<=rect.bottom(); ++y)
        for (int x=rect.left(); x<=rect.right(); ++x) {
            const auto c=a.pixelColor(x,y), d=b.pixelColor(x,y);
            sum += std::abs(c.red()-d.red())+std::abs(c.green()-d.green())+std::abs(c.blue()-d.blue());
        }
    return sum/(rect.width()*rect.height()*3);
}
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    try {
        const QString directory = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QString();
        if (!directory.isEmpty()) QDir().mkpath(directory);
        EGLDisplay display = eglGetPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, nullptr, nullptr);
        EGLint major, minor;
        if (!eglInitialize(display, &major, &minor) || !eglBindAPI(EGL_OPENGL_API))
            throw std::runtime_error("Surfaceless OpenGL/EGL unavailable");
        const EGLint attributes[] = {EGL_SURFACE_TYPE,EGL_PBUFFER_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_BIT,
            EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8,EGL_NONE};
        EGLConfig config; EGLint count;
        if (!eglChooseConfig(display, attributes, &config, 1, &count) || count != 1)
            throw std::runtime_error("No EGL configuration");
        EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, nullptr);
        if (!eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context))
            throw std::runtime_error("No EGL context");
        const char *vertex = R"GLSL(#version 140
out vec2 texcoord0;
void main() {
    vec2 p = gl_VertexID == 0 ? vec2(-1,-1) : gl_VertexID == 1 ? vec2(3,-1) : vec2(-1,3);
    texcoord0 = (p+1.0)*0.5; gl_Position=vec4(p,0,1);
})GLSL";
        const auto vs=compile(GL_VERTEX_SHADER,vertex), fs=compile(GL_FRAGMENT_SHADER,glassFragment);
        GLuint program=glCreateProgram(); glAttachShader(program,vs); glAttachShader(program,fs); glLinkProgram(program);
        GLint ok; glGetProgramiv(program,GL_LINK_STATUS,&ok);
        if (!ok) throw std::runtime_error("Shader link failed");
        glUseProgram(program);
        GLuint vao; glGenVertexArrays(1,&vao); glBindVertexArray(vao);
        constexpr int w=1000,h=680;
        GLuint source,target,fbo;
        glGenTextures(1,&source); glGenTextures(1,&target); glGenFramebuffers(1,&fbo);
        glBindTexture(GL_TEXTURE_2D,target); glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,nullptr);
        glBindFramebuffer(GL_FRAMEBUFFER,fbo); glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,target,0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE) throw std::runtime_error("Incomplete FBO");
        glViewport(0,0,w,h);
        glBindTexture(GL_TEXTURE_2D,source);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR); glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
        auto uniform=[&](const char *name,float value){glUniform1f(glGetUniformLocation(program,name),value);};
        glUniform1i(glGetUniformLocation(program,"sampler"),0);
        glUniform2f(glGetUniformLocation(program,"sourceExtent"),w,h);
        uniform("diagnosticOverlay",0);
        auto render=[&](const QImage &input,QRect panel,float radius,bool dark,float strength,float scale=1) {
            const auto upload=input.convertToFormat(QImage::Format_RGBA8888).flipped(Qt::Vertical);
            glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,upload.constBits());
            glUniform2f(glGetUniformLocation(program,"extent"),panel.width()/scale,panel.height()/scale);
            glUniform2f(glGetUniformLocation(program,"inset"),panel.x()/scale,panel.y()/scale);
            uniform("radius",radius); uniform("dark",dark); uniform("deviceScale",scale);
            glUniform2f(glGetUniformLocation(program,"sourceExtent"),w/scale,h/scale); uniform("strength",strength);
            glClearColor(0,0,0,0); glClear(GL_COLOR_BUFFER_BIT); glDrawArrays(GL_TRIANGLES,0,3);
            QImage result(w,h,QImage::Format_RGBA8888);
            glReadPixels(0,0,w,h,GL_RGBA,GL_UNSIGNED_BYTE,result.bits());
            if (glGetError()!=GL_NO_ERROR) throw std::runtime_error("GL render/read failed");
            return result.flipped(Qt::Vertical);
        };
        // Device-space coverage, premultiplication and no writes outside the SDF.
        // Includes subpixel radii, both themes and both requested viewport scales.
        for (float scale : {1.f, 2.f}) for (bool dark : {false, true}) {
            QImage input(w,h,QImage::Format_RGBA8888); input.fill(Qt::white);
            const QRect panel(40,60,720,490);
            const float radius = 12.5;
            const auto image = render(input,panel,radius,dark,.65,scale);
            int partial = 0;
            for (int y=58;y<95;++y) for (int x=38;x<75;++x) {
                const double qx=std::abs((x+.5-panel.x())/scale-panel.width()/scale/2) - (panel.width()/scale/2-radius);
                const double qy=std::abs((y+.5-panel.y())/scale-panel.height()/scale/2) - (panel.height()/scale/2-radius);
                const double d=std::hypot(std::max(qx,0.),std::max(qy,0.)) + std::min(std::max(qx,qy),0.) - radius;
                const double expected=std::clamp(.5-d*scale,0.,1.);
                const auto c=image.pixelColor(x,y);
                if (std::abs(c.alphaF()-expected)>1.5/255.) throw std::runtime_error("Device-space SDF coverage mismatch");
                if (c.red()>c.alpha() || c.green()>c.alpha() || c.blue()>c.alpha()) throw std::runtime_error("Output not premultiplied");
                if (c.alpha()>0 && c.alpha()<255) ++partial;
            }
            if (partial<4) throw std::runtime_error("Binary corner edge: no fractional coverage");
        }
        QJsonObject report{{"kind","surfaceless-EGL-production-shader-fixture-NOT-KWin"},
            {"renderer",QString::fromLatin1(reinterpret_cast<const char *>(glGetString(GL_RENDERER)))},
            {"version",QString::fromLatin1(reinterpret_cast<const char *>(glGetString(GL_VERSION)))}};
        // Exercise the production shader AND the subsequent sRGB Qt tint.
        // No glyph backing is present. Check actual relative luminance instead
        // of a channel clamp, across the whole intensity range and optical rim.
        auto linear=[](double v) { return v<=.04045 ? v/12.92 : std::pow((v+.055)/1.055,2.4); };
        auto luminance=[&](QColor c) { return .2126*linear(c.redF())+.7152*linear(c.greenF())+.0722*linear(c.blueF()); };
        double maximumDarkY=0, minimumLightY=1;
        int checked=0;
        const QRect samplePanel(40,60,720,490);
        for (bool dark : {false,true})
            for (int intensity : {1,25,50,65,75,100})
                for (const QColor color : {QColor(Qt::black),QColor(Qt::white),QColor(Qt::red),QColor(Qt::green),QColor(Qt::blue),QColor("#efb63c")}) {
            QImage input(w,h,QImage::Format_RGBA8888); input.fill(color);
            const auto image=render(input,samplePanel,16,dark,intensity/100.f);
            const double t=.85*intensity/100., a=1-t, tint=dark?.14:.90;
            for (int y=65;y<545;y+=4) for (int x=60;x<740;x+=4) {
                const auto c=image.pixelColor(x,y);
                const double value=luminance(QColor::fromRgbF(a*tint+t*c.redF(),a*tint+t*c.greenF(),a*tint+t*c.blueF()));
                if (dark) maximumDarkY=std::max(maximumDarkY,value);
                else minimumLightY=std::min(minimumLightY,value);
                if (dark ? value>.115 : value<.42) throw std::runtime_error("Composited material contrast envelope violated");
                ++checked;
            }
        }
        report["compositedPixelsChecked"]=checked;
        report["maximumDarkLuminance"]=maximumDarkY;
        report["minimumLightLuminance"]=minimumLightY;
        QImage backdrop(w,h,QImage::Format_RGBA8888);
        QPainter background(&backdrop);
        background.fillRect(backdrop.rect(),QColor("#56717c"));
        for (int y=0;y<h;y+=40) for (int x=0;x<w;x+=40)
            background.fillRect(x,y,40,40,QColor(((x/40+y/40)%2) ? "#dbd9bc" : "#244e69"));
        background.setPen(QPen(QColor("#ea8363"),8));
        for (int x=-h;x<w;x+=120) background.drawLine(x,0,x+h,h);
        background.end();
        QJsonArray comparisons;
        QList<QPair<QString,QImage>> backdrops;
        if (argc > 2) {
            QImage warm(QString::fromLocal8Bit(argv[2]));
            if (warm.isNull()) throw std::runtime_error("Cannot read warm wallpaper");
            backdrops.append({"warm",warm.scaled(w,h,Qt::IgnoreAspectRatio,Qt::SmoothTransformation)});
        } else backdrops.append({"checker",backdrop});
        for (const QString name : {"white","black"}) {
            QImage image(w,h,QImage::Format_RGBA8888); image.fill(name=="white"?Qt::white:Qt::black);
            backdrops.append({name,image});
        }
        for (const auto &[backdropName, backdropImage] : backdrops) {
        const QString outputDirectory = directory.isEmpty() ? QString() : directory+"/"+backdropName;
        if (!outputDirectory.isEmpty()) QDir().mkpath(outputDirectory);
        const bool detailed = backdropName=="warm" || backdropName=="checker";
        for (bool dark : {false,true}) for (const QString surface : {"control-center","launcher","clipboard"}) {
            const QRect panel = surface=="clipboard" ? QRect(120,60,760,542) : surface=="launcher" ? samplePanel : QRect(580,60,340,520);
            {
                QImage previous;
                for (int intensity : {0,25,50,75,100}) {
                    const float strength=intensity/100.f;
                    QImage optical=render(backdropImage,panel,surface=="dock"?14:16,dark,strength);
                    QImage result=backdropImage;
                    QPainter painter(&result); painter.setRenderHint(QPainter::Antialiasing);
                    // A fixture shadow; production uses existing QML RectangularShadow.
                    painter.setPen(Qt::NoPen);
                    for (int spread=16;spread>=1;--spread) {
                        painter.setBrush(QColor(0,0,0,3)); painter.drawRoundedRect(panel.adjusted(-spread,2-spread,spread,2+spread),16+spread,16+spread);
                    }
                    optical.reinterpretAsFormat(QImage::Format_RGBA8888_Premultiplied);
                    if (intensity>0) painter.drawImage(0,0,optical);
                    QColor tint(dark?"#191b1e":"#ededed"); tint.setAlphaF(1-.85*strength);
                    painter.setBrush(tint); painter.drawRoundedRect(panel, surface=="dock"?14:16,surface=="dock"?14:16);
                    painter.end();
                    // Measure optics before captions, text and crop labels.
                    if (!previous.isNull()) {
                        double delta=difference(previous,result,panel.adjusted(20,12,-20,-12));
                        comparisons.append(QJsonObject{{"backdrop",backdropName},{"dark",dark},{"surface",surface},{"intensity",intensity},{"meanQuarterStepRGB255",delta}});
                        if (detailed && delta < 0.4) throw std::runtime_error("Intensity quarter-step visually collapsed");
                    }
                    previous=result;
                    if (!directory.isEmpty()) {
                        QPainter labels(&result);
                        labels.setRenderHint(QPainter::Antialiasing);
                        labels.setRenderHint(QPainter::TextAntialiasing);
                        labels.setPen(dark?QColor("#f7f8f8"):QColor("#292929"));
                        labels.setFont(QFont("Inter",12));
                        const QString caption = surface=="dock" ? "Finder     Browser     Terminal     Settings"
                            : "Singlr · Material\n\nReadable content\n\n25 / 50 / 75 / 100\n\nBackdrop + flat glass";
                        QPainterPath glyphs;
                        const auto lines = caption.split('\n');
                        for (int i=0;i<lines.size();++i)
                            glyphs.addText(panel.x()+22,panel.y()+(surface=="dock"?30:120)+i*22,labels.font(),lines[i]);
                        labels.setPen(Qt::NoPen);
                        labels.setBrush(dark?QColor("#f7f8f8"):QColor("#292929"));
                        labels.drawPath(glyphs);
                        labels.fillRect(0,0,w,40,QColor("#111111")); labels.setPen(Qt::white);
                        labels.drawText(QRect(12,0,w-24,40),Qt::AlignVCenter,QString("EGL SHADER FIXTURE · NOT KWin · %1 · %2 · %3 · %4%").arg(surface,dark?"dark":"light","glass").arg(intensity));
                        labels.end();
                        QString name=QString("%1/%2-%3-%4-%5.png").arg(outputDirectory,surface,"glass",dark?"dark":"light").arg(intensity,3,10,QChar('0'));
                        if (!result.save(name)) throw std::runtime_error("Cannot save evidence");
                        const QRect edge=panel.adjusted(-12,-12,12,12).intersected(result.rect());
                        result.copy(edge).scaled(edge.size()*2).save(name.chopped(4)+"-edge.png");
                    }
                }
            }

        }
        }
        report["comparisons"]=comparisons;
        const auto json=QJsonDocument(report).toJson(QJsonDocument::Indented);
        if (!directory.isEmpty()) { QFile file(directory+"/optics.json"); if(!file.open(QIODevice::WriteOnly)) return 1; file.write(json); }
        std::fwrite(json.constData(),1,json.size(),stdout);
        glDeleteProgram(program); glDeleteShader(vs); glDeleteShader(fs);
        eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT); eglDestroyContext(display,context); eglTerminate(display);
        return 0;
    } catch (const std::exception &e) { std::fprintf(stderr,"Optics: %s\n",e.what()); return 1; }
}
