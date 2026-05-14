#import "EpubWindowController.h"
#import "EpubSchemeHandler.h"
#import "BridgeMessageHandler.h"
#import "app/StateStore.h"
#include "EpubParser.h"

@implementation EpubWindowController {
    NSWindow*   _window;
    WKWebView*  _webView;
    std::unique_ptr<EpubBook> _book;
    NSInteger   _currentSpineIndex;
    NSInteger   _activeTocIndex;
    __strong EpubWindowController* _selfRef;
}

- (instancetype)initWithPath:(NSString*)path {
    self = [super init];

    _book = EpubParser::parse(path.UTF8String);
    _currentSpineIndex = StateStore::shared().positionForUID(_book->metadata.uid);
    _activeTocIndex = [self firstTocIndexForSpineIndex:_currentSpineIndex];

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
    if (!shellPath) { NSLog(@"ureader: shell.html not found in bundle"); return nil; }
    NSError* err = nil;
    NSString* html = [NSString stringWithContentsOfFile:shellPath
                                               encoding:NSUTF8StringEncoding
                                                  error:&err];
    if (!html) { NSLog(@"ureader: failed to read shell.html: %@", err); return nil; }
    // epub://book origin — same as chapter content so shell can access iframe.contentDocument
    [_webView loadHTMLString:html baseURL:[NSURL URLWithString:@"epub://book/shell"]];

    return self;
}

- (void)showWindow {
    [_window makeKeyAndOrderFront:nil];
}

// ── Bridge callbacks ──────────────────────────────────────────────

- (void)shellReady {
    NSMutableArray* tocArray = [NSMutableArray array];
    for (const auto& entry : _book->toc) {
        [tocArray addObject:@{
            @"title":      [NSString stringWithUTF8String:entry.title.c_str()],
            @"spineIndex": @(entry.spineIndex),
            @"depth":      @(entry.depth)
        }];
    }
    NSDictionary* data = @{
        @"title":          [NSString stringWithUTF8String:_book->metadata.title.c_str()],
        @"author":         [NSString stringWithUTF8String:_book->metadata.author.c_str()],
        @"toc":            tocArray,
        @"spineCount":     @(_book->spine.size()),
        @"currentIndex":   @(_currentSpineIndex),
        @"currentUrl":     [self urlForSpineIndex:_currentSpineIndex],
        @"activeTocIndex": @(_activeTocIndex),
        @"tocAnchors":     [self tocAnchorsForSpineIndex:_currentSpineIndex]
    };
    [self callJS:@"loadBook" withData:data];
}

- (void)navigate:(NSString*)direction {
    NSInteger next = _currentSpineIndex;
    if ([direction isEqualToString:@"next"])
        next = MIN(_currentSpineIndex + 1, (NSInteger)_book->spine.size() - 1);
    else if ([direction isEqualToString:@"prev"])
        next = MAX(_currentSpineIndex - 1, 0);
    if (next != _currentSpineIndex) [self setSpineIndex:next];
}

- (void)jumpToTocEntryIndex:(NSInteger)entryIndex {
    if (entryIndex < 0 || entryIndex >= (NSInteger)_book->toc.size()) return;
    const auto& entry = _book->toc[entryIndex];
    _currentSpineIndex = entry.spineIndex;
    _activeTocIndex    = entryIndex;
    StateStore::shared().setPosition(static_cast<int>(_currentSpineIndex), _book->metadata.uid);
    NSDictionary* data = @{
        @"spineIndex":     @(_currentSpineIndex),
        @"url":            [self urlForTocEntryIndex:entryIndex],
        @"activeTocIndex": @(entryIndex),
        @"tocAnchors":     [self tocAnchorsForSpineIndex:_currentSpineIndex]
    };
    [self callJS:@"navigateTo" withData:data];
}

// ── Private helpers ───────────────────────────────────────────────

- (void)setSpineIndex:(NSInteger)index {
    _currentSpineIndex = index;
    _activeTocIndex    = [self firstTocIndexForSpineIndex:index];
    StateStore::shared().setPosition(static_cast<int>(index), _book->metadata.uid);
    NSDictionary* data = @{
        @"spineIndex":     @(index),
        @"url":            [self urlForSpineIndex:index],
        @"activeTocIndex": @(_activeTocIndex),
        @"tocAnchors":     [self tocAnchorsForSpineIndex:index]
    };
    [self callJS:@"navigateTo" withData:data];
}

- (NSString*)urlForSpineIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_book->spine.size())
        return @"about:blank";
    std::string p = _book->fullPath(_book->spine[index]);
    return [NSString stringWithFormat:@"epub://book/%s", p.c_str()];
}

- (NSString*)urlForTocEntryIndex:(NSInteger)entryIndex {
    if (entryIndex < 0 || entryIndex >= (NSInteger)_book->toc.size())
        return @"about:blank";
    const auto& entry = _book->toc[entryIndex];
    NSString* base = [self urlForSpineIndex:entry.spineIndex];
    if (!entry.fragment.empty())
        return [base stringByAppendingFormat:@"#%s", entry.fragment.c_str()];
    return base;
}

- (NSInteger)firstTocIndexForSpineIndex:(NSInteger)spineIndex {
    for (int i = 0; i < (int)_book->toc.size(); i++)
        if (_book->toc[i].spineIndex == spineIndex) return i;
    return -1;
}

- (NSArray*)tocAnchorsForSpineIndex:(NSInteger)spineIndex {
    NSMutableArray* anchors = [NSMutableArray array];
    for (int i = 0; i < (int)_book->toc.size(); i++) {
        const auto& entry = _book->toc[i];
        if (entry.spineIndex == spineIndex && !entry.fragment.empty())
            [anchors addObject:@{
                @"id":       [NSString stringWithUTF8String:entry.fragment.c_str()],
                @"tocIndex": @(i)
            }];
    }
    return anchors;
}

- (void)callJS:(NSString*)fn withData:(NSDictionary*)data {
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [_webView evaluateJavaScript:[NSString stringWithFormat:@"%@(%@)", fn, json]
               completionHandler:nil];
}

- (void)windowWillClose:(NSNotification*)notification {
    StateStore::shared().setPosition(static_cast<int>(_currentSpineIndex), _book->metadata.uid);
    _selfRef = nil;
}

@end
