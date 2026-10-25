find_package(KF6Service 6.0 REQUIRED)
add_executable(singlr-shell
    src/main.cpp src/launcherbridge.h
    src/shortcuts.cpp src/shortcuts.h
    src/secretagent.cpp src/secretagent.h
    src/secretformat.cpp src/secretformat.h
    src/tray.cpp src/tray.h
    src/trayformat.cpp src/trayformat.h
    src/system.cpp src/system.h
)
target_link_libraries(singlr-shell PRIVATE
    KF6::Service Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus Qt6::Widgets
    KF6::WindowSystem KF6::GlobalAccel KF6::NetworkManagerQt KF6::Wallet
    LayerShellQt::Interface PkgConfig::LIBNM
)
install(TARGETS singlr-shell RUNTIME DESTINATION "${KDE_INSTALL_LIBDIR}/singlr")
