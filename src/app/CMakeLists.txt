add_library(app STATIC StateStore.cpp)
target_include_directories(app
  PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
)
