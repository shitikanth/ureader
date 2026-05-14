#import "EpubWindowController.h"
#import "TocSidebarViewController.h"
#import "EpubSchemeHandler.h"
#import "BridgeMessageHandler.h"
#import "app/StateStore.h"
#include "EpubParser.h"

@interface EpubWindowController () <NSToolbarDelegate>
@end

@implementation EpubWindowController {
    NSWindow*                   _window;
    WKWebView*                  _webView;
    TocSidebarViewController*   _tocSidebar;
    NSSplitViewItem*            _tocSplitItem;
    NSTextField*                _positionLabel;
    std::unique_ptr<EpubBook>   _book;
    NSInteger                   _currentSpineIndex;
    NSInteger                   _activeTocIndex;
    __strong EpubWindowController* _selfRef;
}

@synthesize window = _window;

- (instancetype)initWithPath:(NSString*)path {
    self = [super init];

    _book = EpubParser::parse(path.UTF8String);
    _currentSpineIndex = StateStore::shared().positionForUID(_book->metadata.uid);
    _activeTocIndex = [self firstTocIndexForSpineIndex:_currentSpineIndex];

    NSRect frame = NSMakeRect(0, 0, 1100, 740);
    _window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable |
                             NSWindowStyleMaskResizable |
                             NSWindowStyleMaskFullSizeContentView)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    _window.titlebarAppearsTransparent = YES;
    NSString* title = [NSString stringWithUTF8String:_book->metadata.title.c_str()];
    _window.title = title.length ? title : @"ureader";
    _window.delegate = self;
    _selfRef = self;

    // ── WebView ──────────────────────────────────────────────────────
    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
    EpubSchemeHandler* handler = [[EpubSchemeHandler alloc] initWithBook:_book.get()];
    [config setURLSchemeHandler:handler forURLScheme:@"epub"];
    BridgeMessageHandler* bridge = [[BridgeMessageHandler alloc] initWithController:self];
    [config.userContentController addScriptMessageHandler:bridge name:@"bridge"];

    _webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:config];

    NSString* shellPath = [[NSBundle mainBundle] pathForResource:@"shell" ofType:@"html"];
    if (!shellPath) { NSLog(@"ureader: shell.html not found in bundle"); return nil; }
    NSError* err = nil;
    NSString* html = [NSString stringWithContentsOfFile:shellPath
                                               encoding:NSUTF8StringEncoding
                                                  error:&err];
    if (!html) { NSLog(@"ureader: failed to read shell.html: %@", err); return nil; }
    [_webView loadHTMLString:html baseURL:[NSURL URLWithString:@"epub://book/shell"]];

    // ── TOC sidebar ──────────────────────────────────────────────────
    _tocSidebar = [[TocSidebarViewController alloc] initWithToc:&_book->toc
                                                     controller:self];

    // ── Split view ───────────────────────────────────────────────────
    // Wrap WKWebView so it can be constrained to safeAreaLayoutGuide.topAnchor —
    // WKWebView ignores safe area insets on its own and would overlap the toolbar.
    NSView* contentWrap = [[NSView alloc] init];
    _webView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentWrap addSubview:_webView];
    [NSLayoutConstraint activateConstraints:@[
        [_webView.topAnchor constraintEqualToAnchor:contentWrap.safeAreaLayoutGuide.topAnchor],
        [_webView.bottomAnchor constraintEqualToAnchor:contentWrap.bottomAnchor],
        [_webView.leadingAnchor constraintEqualToAnchor:contentWrap.leadingAnchor],
        [_webView.trailingAnchor constraintEqualToAnchor:contentWrap.trailingAnchor],
    ]];

    NSViewController* contentVC = [[NSViewController alloc] initWithNibName:nil bundle:nil];
    contentVC.view = contentWrap;

    _tocSplitItem = [NSSplitViewItem sidebarWithViewController:_tocSidebar];
    _tocSplitItem.minimumThickness = 260;
    _tocSplitItem.maximumThickness = 420;
    _tocSplitItem.collapsed = YES;
    _tocSplitItem.allowsFullHeightLayout = YES;

    NSSplitViewItem* contentItem = [NSSplitViewItem splitViewItemWithViewController:contentVC];
    contentItem.minimumThickness = 400;

    NSSplitViewController* splitVC = [[NSSplitViewController alloc] init];
    [splitVC addSplitViewItem:_tocSplitItem];
    [splitVC addSplitViewItem:contentItem];
    splitVC.splitView.vertical = YES;
    splitVC.splitView.autosaveName = @"MainSplitView";

    _window.contentViewController = splitVC;
    _window.minSize = NSMakeSize(700, 500);
    [_window setContentSize:NSMakeSize(1100, 740)];
    [_window center];

    // ── Toolbar ──────────────────────────────────────────────────────
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainToolbar"];
    toolbar.delegate = (id<NSToolbarDelegate>)self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    toolbar.centeredItemIdentifiers = [NSSet setWithObjects:
        @"PrevChapter", @"PositionLabel", @"NextChapter", nil];
    _window.toolbarStyle = NSWindowToolbarStyleUnified;
    _window.toolbar = toolbar;

    // ── View menu ────────────────────────────────────────────────────
    NSMenu* menuBar = [NSApp mainMenu];
    NSMenuItem* viewMenuItem = [menuBar itemWithTitle:@"View"];
    if (!viewMenuItem) {
        viewMenuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
        NSMenu* viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
        viewMenuItem.submenu = viewMenu;
        [menuBar addItem:viewMenuItem];
    }
    if (![viewMenuItem.submenu itemWithTitle:@"Table of Contents"]) {
        NSMenuItem* tocItem = [[NSMenuItem alloc]
            initWithTitle:@"Table of Contents"
                   action:@selector(toggleTocSidebar:)
            keyEquivalent:@"s"];
        tocItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
        tocItem.target = self;
        [viewMenuItem.submenu addItem:tocItem];
    }

    return self;
}

- (void)showWindow {
    [_window makeKeyAndOrderFront:nil];
}

// MARK: - NSToolbarDelegate

- (NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
    return @[@"ToggleToc", @"PrevChapter", @"PositionLabel", @"NextChapter"];
}

- (NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)tb {
    return [self toolbarDefaultItemIdentifiers:tb];
}

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
    itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:@"ToggleToc"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.label = @"Contents";
        item.toolTip = @"Show or hide the table of contents";
        item.image = [NSImage imageWithSystemSymbolName:@"sidebar.left"
                                accessibilityDescription:@"Toggle sidebar"];
        item.target = self;
        item.action = @selector(toggleTocSidebar:);
        return item;
    }
    if ([itemIdentifier isEqualToString:@"PrevChapter"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.label = @"Previous";
        item.toolTip = @"Previous chapter";
        item.image = [NSImage imageWithSystemSymbolName:@"chevron.left"
                                accessibilityDescription:@"Previous chapter"];
        item.target = self;
        item.action = @selector(prevChapter:);
        return item;
    }
    if ([itemIdentifier isEqualToString:@"NextChapter"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.label = @"Next";
        item.toolTip = @"Next chapter";
        item.image = [NSImage imageWithSystemSymbolName:@"chevron.right"
                                accessibilityDescription:@"Next chapter"];
        item.target = self;
        item.action = @selector(nextChapter:);
        return item;
    }
    if ([itemIdentifier isEqualToString:@"PositionLabel"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.label = @"";
        _positionLabel = [NSTextField labelWithString:@""];
        _positionLabel.alignment = NSTextAlignmentCenter;
        _positionLabel.textColor = NSColor.secondaryLabelColor;
        _positionLabel.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
        _positionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [_positionLabel.widthAnchor constraintEqualToConstant:60],
        ]];
        item.view = _positionLabel;
        return item;
    }
    return nil;
}

- (void)toggleTocSidebar:(id)sender {
    [_tocSplitItem.animator setCollapsed:!_tocSplitItem.isCollapsed];
}

- (void)prevChapter:(id)sender {
    if (_currentSpineIndex > 0) [self setSpineIndex:_currentSpineIndex - 1];
}

- (void)nextChapter:(id)sender {
    if (_currentSpineIndex < (NSInteger)_book->spine.size() - 1)
        [self setSpineIndex:_currentSpineIndex + 1];
}

- (BOOL)validateToolbarItem:(NSToolbarItem*)item {
    if ([item.itemIdentifier isEqualToString:@"PrevChapter"])
        return _currentSpineIndex > 0;
    if ([item.itemIdentifier isEqualToString:@"NextChapter"])
        return _currentSpineIndex < (NSInteger)_book->spine.size() - 1;
    return YES;
}

// MARK: - Bridge callbacks

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
    [_tocSidebar setActiveTocIndex:_activeTocIndex];
    [self updateNavState];
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
    [_tocSidebar setActiveTocIndex:entryIndex];
}

- (void)setActiveTocIndex:(NSInteger)idx {
    _activeTocIndex = idx;
    [_tocSidebar setActiveTocIndex:idx];
}

// MARK: - Private helpers

- (void)updateNavState {
    _positionLabel.stringValue = [NSString stringWithFormat:@"%ld / %lu",
                                  (long)(_currentSpineIndex + 1),
                                  (unsigned long)_book->spine.size()];
    [_window.toolbar validateVisibleItems];
}

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
    [_tocSidebar setActiveTocIndex:_activeTocIndex];
    [self updateNavState];
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
