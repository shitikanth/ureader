add_library(app STATIC src/StateStore.cpp)
target_include_directories(app PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
