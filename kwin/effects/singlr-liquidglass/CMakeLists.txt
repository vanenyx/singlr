# KWin's private effect ABI is versioned, not a stable third-party SDK.
find_package(KWin 6.8.1 EXACT REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS OpenGL Test)
add_library(singlr-liquidglass MODULE liquidglass.cpp liquidglass.h)
# KWin effect plugins have no "lib" prefix: the file name is the plugin id, as kcoreaddons_add_plugin does.
set_target_properties(singlr-liquidglass PROPERTIES CXX_STANDARD 23 PREFIX "")
target_link_libraries(singlr-liquidglass PRIVATE KWin::kwin KF6::ConfigCore Qt6::OpenGL)
# Shares the shell's rounded blur rasterization to recover the exact corner radius.
target_include_directories(singlr-liquidglass PRIVATE "${PROJECT_SOURCE_DIR}/shell/session/src")
target_link_options(singlr-liquidglass PRIVATE "LINKER:--no-undefined")
install(TARGETS singlr-liquidglass DESTINATION "${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins")
add_executable(singlr-liquidglass-test EXCLUDE_FROM_ALL tests/config.cpp)
set_target_properties(singlr-liquidglass-test PROPERTIES CXX_STANDARD 23)
target_link_libraries(singlr-liquidglass-test PRIVATE KWin::kwin Qt6::Test KF6::ConfigCore)
target_compile_definitions(singlr-liquidglass-test PRIVATE GLASS_PLUGIN="$<TARGET_FILE:singlr-liquidglass>")
add_dependencies(singlr-liquidglass-test singlr-liquidglass)

# Explicit software-EGL shader verification; never installed or run by the shell.
find_package(OpenGL REQUIRED COMPONENTS EGL OpenGL)
add_executable(singlr-material-optics-test EXCLUDE_FROM_ALL tests/optics.cpp)
target_link_libraries(singlr-material-optics-test PRIVATE Qt6::Gui OpenGL::EGL OpenGL::OpenGL)
