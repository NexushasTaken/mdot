cmake_minimum_required(VERSION 3.15)
project(mdot CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

find_package(spdlog REQUIRED)
find_package(tl-expected REQUIRED)
find_package(CLI11 REQUIRED)
find_package(sol2 REQUIRED)
find_package(platform_folders REQUIRED)

# === library
add_library(mdot_core src/link.cpp src/apply.cpp src/error.cpp src/common.cpp)
target_include_directories(mdot_core PUBLIC src)
target_link_libraries(
    mdot_core
    PUBLIC spdlog::spdlog tl::expected sol2::sol2 platform_folders
)

# === cli
add_executable(mdot src/main.cpp)
target_link_libraries(mdot PRIVATE mdot_core CLI11::CLI11)

# === unit test
enable_testing()
find_package(Catch2 REQUIRED)

add_executable(mdot_tests test/test_plan_link.cpp test/test_apply_link.cpp)
target_link_libraries(mdot_tests PRIVATE mdot_core Catch2::Catch2WithMain)

include(Catch)
catch_discover_tests(mdot_tests)
