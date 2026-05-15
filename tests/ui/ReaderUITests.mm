#import <XCTest/XCTest.h>

@interface ReaderUITests : XCTestCase
@end

@implementation ReaderUITests {
    XCUIApplication *_app;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    [self cleanStateFile];
    _app = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.ureader.app"];
    _app.launchArguments = @[@FIXTURE_EPUB_PATH];
    [_app launch];
}

- (void)tearDown {
    [_app terminate];
    [self cleanStateFile];
}

- (void)cleanStateFile {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
                      @"Library/Application Support/ureader/state.json"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (XCUIElement *)waitForWebView {
    XCUIElement *wv = _app.webViews.firstMatch;
    XCTAssertTrue([wv waitForExistenceWithTimeout:10]);
    return wv;
}

- (XCUIElement *)toolbar {
    return _app.toolbars.firstMatch;
}

- (XCUIElement *)positionLabel {
    return [self toolbar].staticTexts[@"1 / 2"];
}

- (XCUIElement *)positionLabelAt:(NSString *)text {
    return [self toolbar].staticTexts[text];
}

- (XCUIElement *)prevButton {
    return [self toolbar].buttons[@"Previous"];
}

- (XCUIElement *)nextButton {
    return [self toolbar].buttons[@"Next"];
}

- (void)openSidebar {
    XCUIElement *toggle = [self toolbar].buttons[@"Contents"];
    XCTAssertTrue([toggle waitForExistenceWithTimeout:10],
                  @"Contents toggle should be in toolbar when sidebar is closed");
    [toggle click];
}

- (XCUIElement *)sidebarTable {
    // NSTableView with NSTableViewStyleSourceList surfaces as an outline (or
    // table on older macOS) in XCUI. The sidebar's table is the only one in
    // the window, so firstMatch is sufficient.
    XCUIElement *byOutline = _app.outlines.firstMatch;
    if (byOutline.exists) return byOutline;
    return _app.tables.firstMatch;
}

- (XCUIElement *)sidebarEntry:(NSString *)title {
    return [self sidebarTable].staticTexts[title];
}

- (void)testWindowTitleIsBookTitle {
    // Window title still set (visible in Dock / Cmd-Tab) even though hidden from titlebar.
    XCTAssertTrue([_app.windows[@"Test Book"] waitForExistenceWithTimeout:10]);
}

- (void)testBookTitleShownInToolbar {
    XCTAssertTrue([[self toolbar].staticTexts[@"Test Book"] waitForExistenceWithTimeout:10]);
}

- (void)testTOCItemsAreVisibleInSidebar {
    [self waitForWebView];
    [self openSidebar];
    XCTAssertTrue([[self sidebarEntry:@"Chapter 1"] waitForExistenceWithTimeout:10]);
    XCTAssertTrue([self sidebarEntry:@"Chapter 2"].exists);
}

- (void)testInitialPositionIsFirstChapter {
    [self waitForWebView];
    XCTAssertTrue([[self positionLabelAt:@"1 / 2"] waitForExistenceWithTimeout:10]);
}

- (void)testPrevButtonDisabledOnFirstChapter {
    [self waitForWebView];
    XCTAssertTrue([[self positionLabelAt:@"1 / 2"] waitForExistenceWithTimeout:10]);
    XCTAssertFalse([self prevButton].isEnabled);
}

- (void)testNextButtonNavigatesToSecondChapter {
    [self waitForWebView];
    XCTAssertTrue([[self positionLabelAt:@"1 / 2"] waitForExistenceWithTimeout:10]);
    [[self nextButton] click];
    XCTAssertTrue([[self positionLabelAt:@"2 / 2"] waitForExistenceWithTimeout:10]);
    XCTAssertFalse([self nextButton].isEnabled);
    XCTAssertTrue([self prevButton].isEnabled);
}

- (void)testClickingTOCEntryNavigatesToThatChapter {
    [self waitForWebView];
    [self openSidebar];
    XCUIElement *chapter2 = [self sidebarEntry:@"Chapter 2"];
    XCTAssertTrue([chapter2 waitForExistenceWithTimeout:10]);
    [chapter2 click];
    XCTAssertTrue([[self positionLabelAt:@"2 / 2"] waitForExistenceWithTimeout:10]);
}

- (void)testSidebarRevealsTOCEntries {
    [self waitForWebView];
    XCTAssertFalse([self sidebarTable].exists,
                   @"Sidebar table shouldn't be queryable when sidebar is collapsed");
    [self openSidebar];
    XCTAssertTrue([[self sidebarTable] waitForExistenceWithTimeout:10],
                  @"Sidebar table should appear after opening sidebar");
}

- (void)testOpeningSameFileDoesNotCreateDuplicateWindow {
    XCTAssertTrue([_app.windows[@"Test Book"] waitForExistenceWithTimeout:10]);

    NSURL* fileURL = [NSURL fileURLWithPath:@FIXTURE_EPUB_PATH];
    NSURL* appURL  = [NSURL fileURLWithPath:@APP_BUNDLE_PATH];
    NSWorkspaceOpenConfiguration* config = [NSWorkspaceOpenConfiguration configuration];
    config.activates = YES;

    XCTestExpectation* sent = [self expectationWithDescription:@"open request sent"];
    [[NSWorkspace sharedWorkspace] openURLs:@[fileURL]
                        withApplicationAtURL:appURL
                               configuration:config
                           completionHandler:^(NSRunningApplication*, NSError*) {
                               [sent fulfill];
                           }];
    [self waitForExpectations:@[sent] timeout:5];
    [NSThread sleepForTimeInterval:1.0];

    XCTAssertEqual(_app.windows.count, 1u);
}

- (void)testPositionPersistsAfterRelaunch {
    [self waitForWebView];
    XCTAssertTrue([[self positionLabelAt:@"1 / 2"] waitForExistenceWithTimeout:10]);
    [[self nextButton] click];
    XCTAssertTrue([[self positionLabelAt:@"2 / 2"] waitForExistenceWithTimeout:10]);

    [_app terminate];
    [_app launch];

    [self waitForWebView];
    XCTAssertTrue([[self positionLabelAt:@"2 / 2"] waitForExistenceWithTimeout:10]);
}

@end
