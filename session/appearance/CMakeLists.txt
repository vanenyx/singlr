find_package(KF6Config REQUIRED)
find_package(KF6GuiAddons 6.29 REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KWayland REQUIRED)
find_package(KF6Screen REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS ShaderTools)
qt_add_qml_module(singlr-system
    SHARED
    URI Singlr.System VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Singlr/System"
    SOURCES kdeappearance.h kdeappearance.cpp dockiconmetrics.h
        clipboardpastebridge.h clipboardpastebridge.cpp clipboardhistorymodel.h clipboardhistorymodel.cpp singularity.h singularity.cpp
)
target_link_libraries(singlr-system PRIVATE Qt6::Gui Qt6::Quick Qt6::DBus KF6::ConfigGui
    KF6::GuiAddons KF6::Service Plasma::KWaylandClient KF6::ScreenDpms)
set_target_properties(singlr-system singlr-systemplugin PROPERTIES INSTALL_RPATH "$ORIGIN")
install(TARGETS singlr-system singlr-systemplugin
    LIBRARY DESTINATION "${KDE_INSTALL_QMLDIR}/Singlr/System")
install(FILES "${CMAKE_BINARY_DIR}/qml/Singlr/System/qmldir"
    "${CMAKE_BINARY_DIR}/qml/Singlr/System/singlr-system.qmltypes"
    DESTINATION "${KDE_INSTALL_QMLDIR}/Singlr/System")

# Explicit, disposable-XDG test target; not part of the installed desktop.
find_package(Qt6 REQUIRED COMPONENTS Test)
add_executable(singlr-appearance-test EXCLUDE_FROM_ALL
    ../../tests/shell/appearance.cpp kdeappearance.cpp kdeappearance.h)
target_include_directories(singlr-appearance-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(singlr-appearance-test PRIVATE Qt6::Gui Qt6::Quick Qt6::Qml Qt6::DBus Qt6::Test KF6::ConfigGui)

add_executable(singlr-material-settings-test EXCLUDE_FROM_ALL
    ../../kwin/effects/singlr-liquidglass/tests/config.cpp)
target_link_libraries(singlr-material-settings-test PRIVATE Qt6::Gui Qt6::Test KF6::ConfigCore)

# Exercise the actual Settings FileDialog through KDE's native QWidget helper.
find_package(KF6KIO 6.0 REQUIRED)
add_executable(singlr-file-dialog-test EXCLUDE_FROM_ALL ../../tests/shell/settings_file_dialog.cpp)
target_link_libraries(singlr-file-dialog-test PRIVATE Qt6::Widgets Qt6::Quick Qt6::Qml Qt6::Test KF6::KIOFileWidgets)
target_compile_definitions(singlr-file-dialog-test PRIVATE SINGLR_SOURCE_ROOT="${PROJECT_SOURCE_DIR}")

add_executable(singlr-dock-icon-test EXCLUDE_FROM_ALL ../../tests/shell/dock_icon_metrics.cpp dockiconmetrics.h)
target_include_directories(singlr-dock-icon-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(singlr-dock-icon-test PRIVATE Qt6::Gui Qt6::Qml Qt6::Test)

add_executable(singlr-clipboard-target EXCLUDE_FROM_ALL ../../tests/shell/clipboard_paste_target.cpp)
target_link_libraries(singlr-clipboard-target PRIVATE Qt6::Gui Qt6::Quick Qt6::Qml)

add_executable(singlr-clipboard-paste-test EXCLUDE_FROM_ALL
    ../../tests/shell/clipboard_paste.cpp clipboardpastebridge.h clipboardpastebridge.cpp)
target_include_directories(singlr-clipboard-paste-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(singlr-clipboard-paste-test PRIVATE Qt6::Gui Qt6::Qml Qt6::Test
    KF6::GuiAddons KF6::Service Plasma::KWaylandClient)

qt_add_shaders(singlr-system singularity-shaders
    PREFIX "/singlr/singularity"
    FILES shaders/singularity.vert shaders/singularity.frag)

add_executable(singlr-singularity-test EXCLUDE_FROM_ALL ../../tests/shell/singularity.cpp)
target_include_directories(singlr-singularity-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(singlr-singularity-test PRIVATE singlr-system Qt6::Quick Qt6::Test)

# Opt-in measurement tool, never installed or built with the desktop by default.
# QRhi's documented API requires GuiPrivate and has limited ABI guarantees.
find_package(Qt6 6.6 REQUIRED COMPONENTS GuiPrivate)
add_executable(singlr-singularity-bench EXCLUDE_FROM_ALL ../../tests/shell/singularity_bench.cpp)
target_include_directories(singlr-singularity-bench PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(singlr-singularity-bench PRIVATE singlr-system Qt6::Quick Qt6::GuiPrivate)

add_executable(singlr-clipboard-history-test EXCLUDE_FROM_ALL
    ../../tests/shell/clipboard_history.cpp clipboardhistorymodel.h clipboardhistorymodel.cpp)
target_include_directories(singlr-clipboard-history-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(singlr-clipboard-history-test PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
