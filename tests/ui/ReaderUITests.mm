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

- (void)testWindowTitleIsBookTitle {
    XCTAssertTrue([_app.windows[@"Test Book"] waitForExistenceWithTimeout:10]);
}

- (void)testTOCItemsAreVisible {
    XCUIElement *wv = [self waitForWebView];
    XCTAssertTrue([wv.staticTexts[@"Chapter 1"] waitForExistenceWithTimeout:10]);
    XCTAssertTrue(wv.staticTexts[@"Chapter 2"].exists);
}

- (void)testInitialPositionIsFirstChapter {
    XCUIElement *wv = [self waitForWebView];
    XCTAssertTrue([wv.staticTexts[@"1 / 2"] waitForExistenceWithTimeout:10]);
}

- (void)testPrevButtonDisabledOnFirstChapter {
    XCUIElement *wv = [self waitForWebView];
    XCTAssertTrue([wv.staticTexts[@"1 / 2"] waitForExistenceWithTimeout:10]);
    XCTAssertFalse(wv.buttons[@"← Prev"].isEnabled);
}

- (void)testNextButtonNavigatesToSecondChapter {
    XCUIElement *wv = [self waitForWebView];
    XCTAssertTrue([wv.staticTexts[@"1 / 2"] waitForExistenceWithTimeout:10]);
    [wv.buttons[@"Next →"] click];
    XCTAssertTrue([wv.staticTexts[@"2 / 2"] waitForExistenceWithTimeout:10]);
    XCTAssertFalse(wv.buttons[@"Next →"].isEnabled);
    XCTAssertTrue(wv.buttons[@"← Prev"].isEnabled);
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
    XCUIElement *wv = [self waitForWebView];
    XCTAssertTrue([wv.staticTexts[@"1 / 2"] waitForExistenceWithTimeout:10]);
    [wv.buttons[@"Next →"] click];
    XCTAssertTrue([wv.staticTexts[@"2 / 2"] waitForExistenceWithTimeout:10]);

    [_app terminate];
    [_app launch];

    wv = [self waitForWebView];
    XCTAssertTrue([wv.staticTexts[@"2 / 2"] waitForExistenceWithTimeout:10]);
}

@end
