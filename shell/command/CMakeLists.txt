find_package(KF6Runner 6.0 REQUIRED)
qt_add_qml_module(singlr-command SHARED
    URI Singlr.Command VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Singlr/Command"
    SOURCES commandsourcemodel.h)
target_link_libraries(singlr-command PRIVATE Qt6::Qml KF6::Runner)
set_target_properties(singlr-command singlr-commandplugin PROPERTIES INSTALL_RPATH "$ORIGIN")
install(TARGETS singlr-command singlr-commandplugin
    LIBRARY DESTINATION "${KDE_INSTALL_QMLDIR}/Singlr/Command")
install(FILES "${CMAKE_BINARY_DIR}/qml/Singlr/Command/qmldir"
    "${CMAKE_BINARY_DIR}/qml/Singlr/Command/singlr-command.qmltypes"
    DESTINATION "${KDE_INSTALL_QMLDIR}/Singlr/Command")
add_executable(singlr-command-capture EXCLUDE_FROM_ALL ../../tests/shell/command-capture.cpp)
target_link_libraries(singlr-command-capture PRIVATE Qt6::Widgets KF6::Runner)
