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
