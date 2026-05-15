find_library(APPKIT AppKit REQUIRED)
find_library(WEBKIT WebKit REQUIRED)
find_library(FOUNDATION Foundation REQUIRED)

add_executable(ureader MACOSX_BUNDLE
  src/main.mm
  src/AppDelegate.mm
  src/EpubWindowController.mm
  src/EpubSchemeHandler.mm
  src/BridgeMessageHandler.mm
  src/TocSidebarViewController.mm
  ${PROJECT_SOURCE_DIR}/resources/shell.html
  ${PROJECT_SOURCE_DIR}/resources/icon/AppIcon.icns
)
set_source_files_properties(${PROJECT_SOURCE_DIR}/resources/shell.html
  PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
set_source_files_properties(${PROJECT_SOURCE_DIR}/resources/icon/AppIcon.icns
  PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

target_include_directories(ureader PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(ureader epub app ${APPKIT} ${WEBKIT} ${FOUNDATION})

set_source_files_properties(
  src/main.mm
  src/AppDelegate.mm
  src/EpubWindowController.mm
  src/EpubSchemeHandler.mm
  src/BridgeMessageHandler.mm
  src/TocSidebarViewController.mm
  PROPERTIES COMPILE_FLAGS "-fobjc-arc"
)

set_target_properties(ureader PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/src/Info.plist
  MACOSX_BUNDLE_BUNDLE_NAME "ureader"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.ureader.app"
)

add_subdirectory(tests)
