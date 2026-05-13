add_library(epub STATIC
  EpubBook.cpp
  EpubParser.cpp
  ${PROJECT_SOURCE_DIR}/third_party/tinyxml2.cpp
  ${PROJECT_SOURCE_DIR}/third_party/miniz.c
  ${PROJECT_SOURCE_DIR}/third_party/miniz_tdef.c
  ${PROJECT_SOURCE_DIR}/third_party/miniz_tinfl.c
  ${PROJECT_SOURCE_DIR}/third_party/miniz_zip.c
)
target_include_directories(epub
  PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}
          ${PROJECT_SOURCE_DIR}/third_party
)

add_executable(epub_tests tests/test_epub_parser.cpp)
target_include_directories(epub_tests PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${PROJECT_SOURCE_DIR}/third_party
)
target_link_libraries(epub_tests epub)
target_compile_definitions(epub_tests PRIVATE
  FIXTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

enable_testing()
add_test(NAME epub_tests COMMAND epub_tests)
