find_library(APPKIT AppKit REQUIRED)
find_library(WEBKIT WebKit REQUIRED)
find_library(FOUNDATION Foundation REQUIRED)

add_executable(ureader MACOSX_BUNDLE
  ${PROJECT_SOURCE_DIR}/src/main.mm
  AppDelegate.mm
  EpubWindowController.mm
  EpubSchemeHandler.mm
  BridgeMessageHandler.mm
  ${PROJECT_SOURCE_DIR}/resources/shell.html
)
set_source_files_properties(${PROJECT_SOURCE_DIR}/resources/shell.html
  PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

target_include_directories(ureader PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${PROJECT_SOURCE_DIR}/src
  ${PROJECT_SOURCE_DIR}/third_party
)
target_link_libraries(ureader epub app ${APPKIT} ${WEBKIT} ${FOUNDATION})

# Enable ARC for all Objective-C++ files in this target
set_source_files_properties(
  ${PROJECT_SOURCE_DIR}/src/main.mm
  AppDelegate.mm
  EpubWindowController.mm
  EpubSchemeHandler.mm
  BridgeMessageHandler.mm
  PROPERTIES COMPILE_FLAGS "-fobjc-arc"
)

set_target_properties(ureader PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST ${PROJECT_SOURCE_DIR}/Info.plist
  MACOSX_BUNDLE_BUNDLE_NAME "ureader"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.ureader.app"
)
