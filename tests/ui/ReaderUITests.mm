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
    XCUIElement *ch1 = _app.staticTexts[@"Chapter 1"];
    XCTAssertTrue([ch1 waitForExistenceWithTimeout:10]);
    XCTAssertTrue(ch1.isHittable, @"Chapter 1 should be hit-testable when sidebar is open");
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
    XCUIElement *chapter2 = _app.staticTexts[@"Chapter 2"];
    XCTAssertTrue([chapter2 waitForExistenceWithTimeout:10]);
    [chapter2 click];
    XCTAssertTrue([[self positionLabelAt:@"2 / 2"] waitForExistenceWithTimeout:10]);
}

- (void)testSidebarToggleHidesAndShowsSidebar {
    [self waitForWebView];
    // Sidebar starts collapsed: TOC cells exist in the accessibility tree but
    // shouldn't be hit-testable (no visible frame).
    XCTAssertFalse(_app.staticTexts[@"Chapter 1"].isHittable,
                   @"Chapter 1 should not be hittable when sidebar is collapsed");
    [self openSidebar];
    XCUIElement *ch1 = _app.staticTexts[@"Chapter 1"];
    XCTAssertTrue([ch1 waitForExistenceWithTimeout:10]);
    XCTAssertTrue(ch1.isHittable, @"Chapter 1 should be hittable when sidebar is open");
    // Collapse using View menu shortcut (works regardless of which toggle is visible).
    [_app typeKey:@"s" modifierFlags:XCUIKeyModifierCommand | XCUIKeyModifierControl];
    [NSThread sleepForTimeInterval:0.6];
    XCTAssertFalse(_app.staticTexts[@"Chapter 1"].isHittable,
                   @"Chapter 1 should not be hittable after collapsing sidebar");
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
