cmake_minimum_required(VERSION 3.20)
project(ureader)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

add_subdirectory(src/epub)
add_subdirectory(src/app)
add_subdirectory(src/ui/macos)
