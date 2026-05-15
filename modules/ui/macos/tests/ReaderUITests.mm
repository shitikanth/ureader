#import <XCTest/XCTest.h>

@interface ReaderUITests : XCTestCase
@end

@implementation ReaderUITests {
    XCUIApplication *_app;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    [self cleanStateFile];
    [self cleanUserDefaults];
    _app = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.ureader.app"];
    _app.launchArguments = @[@FIXTURE_EPUB_PATH];
    [_app launch];
}

- (void)tearDown {
    [_app terminate];
    [self cleanStateFile];
    [self cleanUserDefaults];
}

- (void)cleanStateFile {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
                      @"Library/Application Support/ureader/state.json"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void)cleanUserDefaults {
    // Wipe com.ureader.app's NSUserDefaults so the NSSplitView autosave
    // (sidebar collapsed/width) doesn't leak between tests. Goes through
    // /usr/bin/defaults so cfprefsd flushes its in-memory cache.
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/defaults";
    task.arguments  = @[@"delete", @"com.ureader.app"];
    task.standardOutput = [NSPipe pipe];
    task.standardError  = [NSPipe pipe];
    [task launch];
    [task waitUntilExit];
}

- (XCUIElement *)waitForWebView {
    XCUIElement *wv = _app.webViews.firstMatch;
    XCTAssertTrue([wv waitForExistenceWithTimeout:10]);
    return wv;
}

- (XCUIElement *)toolbar {
    return _app.toolbars.firstMatch;
}

- (void)assertPositionIs:(NSString *)expected {
    XCTAssertTrue([[self toolbar].staticTexts[expected] waitForExistenceWithTimeout:10],
                  @"Expected position '%@' not found in toolbar", expected);
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

- (void)assertSidebarEntry:(NSString *)title {
    XCTAssertTrue([[self sidebarEntry:title] waitForExistenceWithTimeout:10],
                  @"TOC entry '%@' not found in sidebar", title);
}

- (void)testWindowTitleIsBookTitle {
    XCTAssertTrue([_app.windows[@"Test Book"] waitForExistenceWithTimeout:10]);
}

- (void)testBookTitleShownInToolbar {
    XCTAssertTrue([[self toolbar].staticTexts[@"Test Book"] waitForExistenceWithTimeout:10]);
}

- (void)testInitialPositionIsFirstChapter {
    [self waitForWebView];
    [self assertPositionIs:@"1 / 2"];
}

- (void)testPrevButtonDisabledOnFirstChapter {
    [self waitForWebView];
    [self assertPositionIs:@"1 / 2"];
    XCTAssertFalse([self prevButton].isEnabled);
}

- (void)testNextButtonNavigatesToSecondChapter {
    [self waitForWebView];
    [self assertPositionIs:@"1 / 2"];
    [[self nextButton] click];
    [self assertPositionIs:@"2 / 2"];
    XCTAssertFalse([self nextButton].isEnabled);
    XCTAssertTrue([self prevButton].isEnabled);
}


- (void)testSidebarRevealsTOCEntries {
    [self waitForWebView];
    XCTAssertFalse([self sidebarTable].exists, @"Sidebar table shouldn't be queryable when sidebar is collapsed");
    [self openSidebar];
    XCTAssertTrue([[self sidebarTable] waitForExistenceWithTimeout:10],
                  @"Sidebar table should appear after opening sidebar");
    [self assertSidebarEntry:@"Chapter 1"];
    [self assertSidebarEntry:@"Chapter 2"];
}

- (void)testClickingTOCEntryNavigatesToThatChapter {
    [self waitForWebView];
    [self openSidebar];
    [self assertSidebarEntry:@"Chapter 2"];
    [[self sidebarEntry:@"Chapter 2"] click];
    [self assertPositionIs:@"2 / 2"];
}

- (void)testExternalLinkOpensInBrowser {
    XCUIElement *wv = [self waitForWebView];
    // The link must be visible; wait up to 10 s for the chapter to load.
    XCUIElement *link = wv.links[@"External Link"];
    XCTAssertTrue([link waitForExistenceWithTimeout:10],
                  @"External Link should be present in chapter 1 content");
    [link click];
    // After clicking an external link the epub content must remain visible —
    // the webview must not have navigated the iframe (or the app) away.
    XCTAssertTrue([wv.staticTexts[@"Chapter 1"] waitForExistenceWithTimeout:5],
                  @"Epub content should remain after clicking external link");
}

- (void)testPositionPersistsAfterRelaunch {
    [self waitForWebView];
    [self assertPositionIs:@"1 / 2"];
    [[self nextButton] click];
    [self assertPositionIs:@"2 / 2"];

    [_app terminate];
    [_app launch];

    [self waitForWebView];
    [self assertPositionIs:@"2 / 2"];
}

@end
