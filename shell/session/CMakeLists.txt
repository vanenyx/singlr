find_package(KF6Service 6.0 REQUIRED)
find_package(KF6KIO 6.0 REQUIRED)
find_package(LibKWorkspace 6.8 REQUIRED)
find_package(OpenGL REQUIRED COMPONENTS EGL)
add_executable(singlr-shell
    src/main.cpp src/launcherbridge.h
    src/shortcuts.cpp src/shortcuts.h
    src/tray.cpp src/tray.h
    src/trayformat.cpp src/trayformat.h
    src/system.cpp src/system.h
)
target_link_libraries(singlr-shell PRIVATE
    PW::KWorkspace KF6::Service KF6::KIOGui Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus Qt6::Widgets
    KF6::WindowSystem KF6::GlobalAccel
    LayerShellQt::Interface OpenGL::EGL
)
install(TARGETS singlr-shell RUNTIME DESTINATION "${KDE_INSTALL_LIBDIR}/singlr")
