add_library(epub STATIC
  src/EpubBook.cpp
  src/EpubParser.cpp
)
target_include_directories(epub PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(epub PUBLIC miniz tinyxml2)

add_executable(epub_tests tests/test_epub_parser.cpp)
target_link_libraries(epub_tests epub doctest)
target_compile_definitions(epub_tests PRIVATE
  FIXTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures")

enable_testing()
add_test(NAME epub_tests COMMAND epub_tests)
