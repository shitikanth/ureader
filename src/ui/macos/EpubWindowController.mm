#import "EpubWindowController.h"
#import "EpubSchemeHandler.h"
#import "BridgeMessageHandler.h"
#import "app/StateStore.h"
#include "EpubParser.h"

@implementation EpubWindowController {
    NSWindow*   _window;
    WKWebView*  _webView;
    std::unique_ptr<EpubBook> _book;
    NSInteger   _currentIndex;
    __strong EpubWindowController* _selfRef;
}

- (instancetype)initWithPath:(NSString*)path {
    self = [super init];

    _book = EpubParser::parse(path.UTF8String);
    _currentIndex = StateStore::shared().positionForUID(_book->metadata.uid);

    NSRect frame = NSMakeRect(0, 0, 900, 700);
    _window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable |
                             NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    NSString* title = [NSString stringWithUTF8String:_book->metadata.title.c_str()];
    _window.title = title.length ? title : @"ureader";
    _window.delegate = self;
    _selfRef = self;
    [_window center];

    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
    EpubSchemeHandler* handler = [[EpubSchemeHandler alloc] initWithBook:_book.get()];
    [config setURLSchemeHandler:handler forURLScheme:@"epub"];
    BridgeMessageHandler* bridge = [[BridgeMessageHandler alloc] initWithController:self];
    [config.userContentController addScriptMessageHandler:bridge name:@"bridge"];

    _webView = [[WKWebView alloc] initWithFrame:_window.contentView.bounds
                                  configuration:config];
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_window.contentView addSubview:_webView];

    NSString* shellPath = [[NSBundle mainBundle] pathForResource:@"shell" ofType:@"html"];
    NSString* html = [NSString stringWithContentsOfFile:shellPath
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    [_webView loadHTMLString:html baseURL:[NSURL URLWithString:@"epub://ureader/shell"]];

    return self;
}

- (void)showWindow {
    [_window makeKeyAndOrderFront:nil];
}

- (void)shellReady {
    NSMutableArray* tocArray = [NSMutableArray array];
    for (const auto& entry : _book->toc) {
        [tocArray addObject:@{
            @"title":      [NSString stringWithUTF8String:entry.title.c_str()],
            @"spineIndex": @(entry.spineIndex),
            @"depth":      @(entry.depth)
        }];
    }

    NSString* currentUrl = [self urlForSpineIndex:_currentIndex];
    NSDictionary* data = @{
        @"title":        [NSString stringWithUTF8String:_book->metadata.title.c_str()],
        @"author":       [NSString stringWithUTF8String:_book->metadata.author.c_str()],
        @"toc":          tocArray,
        @"spineCount":   @(_book->spine.size()),
        @"currentIndex": @(_currentIndex),
        @"currentUrl":   currentUrl
    };
    [self callJS:@"loadBook" withData:data];
}

- (void)navigate:(NSString*)direction {
    NSInteger next = _currentIndex;
    if ([direction isEqualToString:@"next"])
        next = MIN(_currentIndex + 1, (NSInteger)_book->spine.size() - 1);
    else if ([direction isEqualToString:@"prev"])
        next = MAX(_currentIndex - 1, 0);
    if (next != _currentIndex) [self setSpineIndex:next];
}

- (void)jumpToSpineIndex:(NSInteger)index {
    if (index >= 0 && index < (NSInteger)_book->spine.size())
        [self setSpineIndex:index];
}

- (void)setSpineIndex:(NSInteger)index {
    _currentIndex = index;
    StateStore::shared().setPosition(static_cast<int>(index), _book->metadata.uid);
    NSDictionary* data = @{
        @"spineIndex": @(index),
        @"url":        [self urlForSpineIndex:index]
    };
    [self callJS:@"navigateTo" withData:data];
}

- (NSString*)urlForSpineIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_book->spine.size())
        return @"about:blank";
    std::string fullZipPath = _book->fullPath(_book->spine[index]);
    return [NSString stringWithFormat:@"epub://book/%s", fullZipPath.c_str()];
}

- (void)callJS:(NSString*)fn withData:(NSDictionary*)data {
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString* js = [NSString stringWithFormat:@"%@(%@)", fn, json];
    [_webView evaluateJavaScript:js completionHandler:nil];
}

- (void)windowWillClose:(NSNotification*)notification {
    StateStore::shared().setPosition(static_cast<int>(_currentIndex), _book->metadata.uid);
    _selfRef = nil;
}

@end
