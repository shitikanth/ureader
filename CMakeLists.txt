cmake_minimum_required(VERSION 3.20)

# Detect macOS SDK path before project() so XCTest can find it
if(APPLE AND NOT CMAKE_OSX_SYSROOT)
    execute_process(
        COMMAND xcrun --sdk macosx --show-sdk-path
        OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(CMAKE_OSX_SYSROOT "${CMAKE_OSX_SYSROOT}" CACHE PATH "macOS SDK path" FORCE)
endif()

project(ureader)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

enable_testing()

add_subdirectory(third_party)
add_subdirectory(src/epub)
add_subdirectory(src/app)
add_subdirectory(src/ui/macos)
add_subdirectory(tests/ui)
