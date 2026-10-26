cmake_minimum_required(VERSION 3.22)
project(singlr-output-control LANGUAGES CXX)
set(CMAKE_AUTOMOC ON)
find_package(ECM 6.0 REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Gui Quick Widgets DBus)
find_package(KWin 6.8.1 EXACT REQUIRED)
add_library(singlr-output-control MODULE output-control.cpp)
set_target_properties(singlr-output-control PROPERTIES CXX_STANDARD 23 PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins/kwin/plugins")
target_link_libraries(singlr-output-control PRIVATE KWin::kwin)
# Test-only: no install rule. Loaded exclusively into a private virtual KWin.

find_package(Qt6 REQUIRED COMPONENTS Test Qml)
find_package(LayerShellQt REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6KIO REQUIRED)
set(SINGLR_TEST_SESSION_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../../../shell/session/src" CACHE PATH "Session sources under test")
add_executable(singlr-surface-lifecycle surface-lifecycle.cpp
    "${SINGLR_TEST_SESSION_SRC}/system.cpp" "${SINGLR_TEST_SESSION_SRC}/system.h")
target_include_directories(singlr-surface-lifecycle PRIVATE "${SINGLR_TEST_SESSION_SRC}")
target_compile_definitions(singlr-surface-lifecycle PRIVATE SINGLR_ROOT="${CMAKE_CURRENT_SOURCE_DIR}/../../..")
target_link_libraries(singlr-surface-lifecycle PRIVATE Qt6::Test Qt6::Gui Qt6::Qml Qt6::DBus
    LayerShellQt::Interface KF6::Service KF6::KIOGui)
