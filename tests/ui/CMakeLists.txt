find_package(XCTest REQUIRED)

# ── Test bundle ──────────────────────────────────────────────────────────────
xctest_add_bundle(ureader_ui_tests ureader ReaderUITests.mm)
target_link_libraries(ureader_ui_tests PRIVATE "-framework AppKit")
target_compile_definitions(ureader_ui_tests PRIVATE
  FIXTURE_EPUB_PATH="${CMAKE_SOURCE_DIR}/src/epub/fixtures/minimal.epub"
  APP_BUNDLE_PATH="$<TARGET_BUNDLE_DIR:ureader>"
)

# ── Helper: generates an XCTestConfiguration so xctest runs in UI-test mode ─
# XCUIApplication requires XCTestConfigurationFilePath to be set; without it
# the framework raises "Device is not configured for UI testing".
#
# The XCTest.framework for macOS lives in the platform developer directory,
# not in the SDK, so we need to locate it explicitly.
# XCTest_LIBRARIES is the path to XCTest.framework; one DIRECTORY step gives
# the containing Frameworks/ directory which is what -F needs.
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

# Path where the config file will be written at test time
set(XCTEST_CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/ureader_ui_tests.xctestconfiguration")

# ── Test fixtures ─────────────────────────────────────────────────────────────

# Fixture 1: register the app with LaunchServices
add_test(NAME register_ureader
  COMMAND /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
          -f "$<TARGET_BUNDLE_DIR:ureader>"
)
set_tests_properties(register_ureader PROPERTIES FIXTURES_SETUP ureader_registered)

# Fixture 2: write the XCTestConfiguration file
add_test(NAME create_xctest_config
  COMMAND generate_xctest_config
          "$<TARGET_BUNDLE_DIR:ureader_ui_tests>"
          "${XCTEST_CONFIG_FILE}"
)
set_tests_properties(create_xctest_config PROPERTIES
  FIXTURES_SETUP    ui_test_config
  FIXTURES_REQUIRED ureader_registered
)

# ── UI test ───────────────────────────────────────────────────────────────────
xctest_add_test(XCTest.ureader_ui_tests ureader_ui_tests)
set_tests_properties(XCTest.ureader_ui_tests PROPERTIES
  FIXTURES_REQUIRED "ureader_registered;ui_test_config"
  TIMEOUT           120
  ENVIRONMENT       "XCTestConfigurationFilePath=${XCTEST_CONFIG_FILE}"
)
