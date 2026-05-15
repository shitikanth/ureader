find_package(XCTest REQUIRED)

xctest_add_bundle(ureader_ui_tests ureader ReaderUITests.mm)
target_link_libraries(ureader_ui_tests PRIVATE "-framework AppKit")
target_compile_definitions(ureader_ui_tests PRIVATE
  FIXTURE_EPUB_PATH="${PROJECT_SOURCE_DIR}/modules/epub/tests/fixtures/minimal.epub"
  APP_BUNDLE_PATH="$<TARGET_BUNDLE_DIR:ureader>"
)

get_filename_component(_xctest_fw_dir "${XCTest_LIBRARIES}" DIRECTORY)

add_executable(generate_xctest_config GenerateXCTestConfig.m)
target_include_directories(generate_xctest_config PRIVATE ${XCTest_INCLUDE_DIRS})
target_link_libraries(generate_xctest_config PRIVATE
  "-framework Foundation"
  "-F${_xctest_fw_dir}"
  "-framework XCTest"
)
set_target_properties(generate_xctest_config PROPERTIES
  BUILD_RPATH "${_xctest_fw_dir}"
)

set(XCTEST_CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/ureader_ui_tests.xctestconfiguration")

add_test(NAME register_ureader
  COMMAND /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
          -f "$<TARGET_BUNDLE_DIR:ureader>"
)
set_tests_properties(register_ureader PROPERTIES FIXTURES_SETUP ureader_registered)

add_test(NAME create_xctest_config
  COMMAND generate_xctest_config
          "$<TARGET_BUNDLE_DIR:ureader_ui_tests>"
          "${XCTEST_CONFIG_FILE}"
)
set_tests_properties(create_xctest_config PROPERTIES
  FIXTURES_SETUP    ui_test_config
  FIXTURES_REQUIRED ureader_registered
)

xctest_add_test(XCTest.ureader_ui_tests ureader_ui_tests)
set_tests_properties(XCTest.ureader_ui_tests PROPERTIES
  FIXTURES_REQUIRED "ureader_registered;ui_test_config"
  TIMEOUT           120
  ENVIRONMENT       "XCTestConfigurationFilePath=${XCTEST_CONFIG_FILE}"
)
