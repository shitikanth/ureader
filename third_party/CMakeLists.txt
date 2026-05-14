add_library(miniz STATIC miniz.c)
target_include_directories(miniz PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_library(tinyxml2 STATIC tinyxml2.cpp)
target_include_directories(tinyxml2 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_library(doctest INTERFACE)
target_include_directories(doctest INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
