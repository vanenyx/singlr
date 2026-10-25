find_package(KF6Config REQUIRED)
qt_add_qml_module(singlr-system
    SHARED
    URI Singlr.System VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Singlr/System"
    SOURCES kdeappearance.h kdeappearance.cpp workspacebridge.h
)
target_link_libraries(singlr-system PRIVATE Qt6::Gui Qt6::Quick Qt6::DBus KF6::ConfigGui)
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
