// T221: preview of the shipped SVGs through KSvg, without installing a theme.
// Build/run instructions and limitations: ../../README.md.
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QFont>
#include <QDir>
#include <QDebug>
#include <KSvg/FrameSvg>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    const QString path = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QDir::currentPath();
    const QStringList names = {"close", "minimize", "maximize", "restore"};
    const QStringList labels = {"Cerrar", "Minimizar", "Maximizar", "Restaurar"};
    const QStringList states = {"active", "hover", "pressed", "inactive", "deactivated"};
    const QStringList stateLabels = {"Reposo", "Hover", "Pulsado", "Inactivo", "Deshabilitado"};
    QImage im(1120, 1080, QImage::Format_ARGB32_Premultiplied);
    im.fill(QColor("#191a1b"));
    QPainter p(&im); p.setRenderHint(QPainter::Antialiasing);
    auto text = [&](int x,int y,QString t,int px,QColor c=QColor("#8a8f98"),int weight=400){
        QFont f("Noto Sans"); f.setPixelSize(px);f.setWeight(QFont::Weight(weight));
        p.setFont(f);p.setPen(c);p.drawText(x,y,t);
    };
    text(32,49,"Singlr",26,QColor("#f7f8f8"),510);
    text(32,78,"Colapso → latencia → expansión",14);
    text(32,103,"SVG originales · render KSvg 6.31 / Qt 6.12 · tamaños físicos exactos",12);
    auto button = [&](QString name, QString state, int x, int y, int scale){
        KSvg::FrameSvg svg;svg.setUsingRenderingCache(false);
        svg.setImagePath(path+"/"+name+".svg");svg.setElementPrefix(state);
        if (!svg.hasElementPrefix(state)) qFatal("Missing button prefix");
        svg.setDevicePixelRatio(scale);svg.resizeFrame(QSizeF(16,16));
        auto pix = svg.framePixmap();
        if (pix.isNull()) qFatal("Empty button pixmap");
        p.drawPixmap(QRect(x,y,16*scale,16*scale),pix);
    };
    auto frame = [&](int x,int y,int w,int h,QString prefix,int scale){
        KSvg::FrameSvg svg;svg.setUsingRenderingCache(false);
        svg.setImagePath(path+"/decoration.svg");svg.setElementPrefix(prefix);
        if (!svg.hasElementPrefix(prefix)) qFatal("Missing frame prefix");
        svg.setDevicePixelRatio(scale);svg.resizeFrame(QSizeF(w/scale,h/scale));
        p.drawPixmap(QRect(x,y,w,h),svg.framePixmap());
    };
    for (int scale : {1,2}) {
        int sy=scale==1?145:490;
        text(32,sy,QString::number(scale*100)+" %",17,QColor("#f7f8f8"),510);
        for (int inactive=0;inactive<2;inactive++) {
            int x=32+inactive*544;
            text(x,sy+30,inactive?"Barra inactiva · #0c0d0e":"Barra activa · #0f1011",12);
            // Actual frame and 30px titlebar, normal 16px buttons / 8px spacing.
            int fy=sy+44;
            frame(x-24*scale,fy-24*scale,512+48*scale,30*scale+48*scale,
                  inactive?"decoration-inactive":"decoration",scale);
            for(int j=0;j<3;j++) button(names[j],inactive?"inactive":"active",x+(12+j*24)*scale,fy+7*scale,scale);
            QFont titleFont("Noto Sans");titleFont.setPixelSize(13*scale);titleFont.setWeight(QFont::Weight(510));
            p.setFont(titleFont);p.setPen(QColor(inactive?"#62666d":"#d0d6e0"));
            p.drawText(QRect(x+88*scale,fy,512-176*scale,30*scale),Qt::AlignCenter,"Singlr");
            int my=fy+30*scale+35;
            for(int j=0;j<4;j++) text(x+164+j*78,my,labels[j],11);
            for(int row=0;row<5;row++) {
                int y=my+12+row*(30*scale+8);
                p.fillRect(QRect(x,y,512,30*scale),QColor(inactive?"#0c0d0e":"#0f1011"));
                text(x+12,y+15*scale+4,stateLabels[row],11);
                QString state=states[row];
                if(inactive && (state=="hover"||state=="pressed"||state=="deactivated"))state+="-inactive";
                if(inactive && state=="active")state="inactive";
                for(int j=0;j<4;j++)button(names[j],state,x+180+j*78-8*scale,y+7*scale,scale);
            }
        }
    }
    text(32,1042,"Halo SVG: 16 px (límite de Aurorae con caja de 16 px). Objetivo de 22 px pendiente de un motor con overflow.",12);
    text(32,1065,"Vista de recursos, no captura de KWin. Fuente de muestra: Noto Sans 13 px / 510. Restaurar sustituye a maximizar.",11);
    p.end();
    if(!im.save(path+"/preview.png"))return 1;
    qInfo()<<"Preview saved:"<<path+"/preview.png";
}
