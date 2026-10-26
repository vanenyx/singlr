find_package(KF6Config REQUIRED)
find_package(KF6GuiAddons 6.29 REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KWayland REQUIRED)
qt_add_qml_module(singlr-system
    SHARED
    URI Singlr.System VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Singlr/System"
    SOURCES kdeappearance.h kdeappearance.cpp workspacebridge.h dockiconmetrics.h
        clipboardpastebridge.h clipboardpastebridge.cpp
)
target_link_libraries(singlr-system PRIVATE Qt6::Gui Qt6::Quick Qt6::DBus KF6::ConfigGui
    KF6::GuiAddons KF6::Service Plasma::KWaylandClient)
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
