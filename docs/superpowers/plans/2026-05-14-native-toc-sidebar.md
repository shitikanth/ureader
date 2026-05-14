# Native TOC Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the HTML/JS TOC sidebar with a native macOS `NSTableView`-based sidebar that is hidden by default and toggled via a toolbar button.

**Architecture:** An `NSSplitViewController` replaces the bare `NSWindow`+`WKWebView` setup. The left split item is a new `TocSidebarViewController` (NSTableView, flat indented list, starts collapsed). The right split item wraps the existing WKWebView. The HTML sidebar and its JS are removed; scroll-based TOC tracking posts a new `tocSelectionChanged` bridge action instead.

**Tech Stack:** Objective-C++ (ARC), AppKit (`NSSplitViewController`, `NSTableView`, `NSToolbar`), WebKit JS bridge, CMake/Ninja

---

## File Map

| File | Action |
|---|---|
| `src/ui/macos/TocSidebarViewController.h` | Create |
| `src/ui/macos/TocSidebarViewController.mm` | Create |
| `src/ui/macos/EpubWindowController.h` | Modify — add `TocSidebarViewController*` ivar + `setActiveTocIndex:` declaration |
| `src/ui/macos/EpubWindowController.mm` | Modify — replace bare window setup with NSSplitViewController; wire sidebar; update `_activeTocIndex` mutation sites |
| `src/ui/macos/BridgeMessageHandler.mm` | Modify — handle `tocSelectionChanged` |
| `resources/shell.html` | Modify — remove HTML sidebar; post `tocSelectionChanged` from IntersectionObserver |
| `src/ui/macos/CMakeLists.txt` | Modify — add new source files + ARC flag |

---

## Task 1: Add `TocSidebarViewController` header

**Files:**
- Create: `src/ui/macos/TocSidebarViewController.h`

- [ ] **Step 1: Create the header**

```objc
// src/ui/macos/TocSidebarViewController.h
#pragma once
#import <AppKit/AppKit.h>
#include <vector>
#include "EpubBook.h"

@class EpubWindowController;

@interface TocSidebarViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
- (instancetype)initWithToc:(const std::vector<TocEntry>*)toc
                 controller:(EpubWindowController*)controller;
- (void)setActiveTocIndex:(NSInteger)idx;
@end
```

- [ ] **Step 2: Build to verify the header compiles**

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug 2>&1 | tail -5
cmake --build build 2>&1 | tail -20
```

Expected: existing build still passes (new header not yet wired in).

- [ ] **Step 3: Commit**

```bash
git add src/ui/macos/TocSidebarViewController.h
git commit -m "feat: add TocSidebarViewController header"
```

---

## Task 2: Implement `TocSidebarViewController`

**Files:**
- Create: `src/ui/macos/TocSidebarViewController.mm`
- Modify: `src/ui/macos/CMakeLists.txt`

- [ ] **Step 1: Create the implementation**

```objc
// src/ui/macos/TocSidebarViewController.mm
#import "TocSidebarViewController.h"
#import "EpubWindowController.h"

static NSString* const kCellID = @"TocCell";

@implementation TocSidebarViewController {
    const std::vector<TocEntry>* _toc;
    __weak EpubWindowController* _controller;
    NSTableView* _tableView;
}

- (instancetype)initWithToc:(const std::vector<TocEntry>*)toc
                 controller:(EpubWindowController*)controller {
    self = [super initWithNibName:nil bundle:nil];
    _toc = toc;
    _controller = controller;
    return self;
}

- (void)loadView {
    NSScrollView* scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;

    _tableView = [[NSTableView alloc] init];
    _tableView.style = NSTableViewStyleSourceList;
    _tableView.headerView = nil;
    _tableView.rowHeight = 24;
    _tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    _tableView.allowsEmptySelection = YES;
    _tableView.dataSource = self;
    _tableView.delegate = self;

    NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    col.resizingMask = NSTableColumnAutoresizingMask;
    [_tableView addTableColumn:col];
    [_tableView sizeLastColumnToFit];

    scroll.documentView = _tableView;
    self.view = scroll;
}

// MARK: - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tv {
    return _toc ? (NSInteger)_toc->size() : 0;
}

// MARK: - NSTableViewDelegate

- (NSView*)tableView:(NSTableView*)tv
  viewForTableColumn:(NSTableColumn*)col
                 row:(NSInteger)row {
    NSTableCellView* cell = [tv makeViewWithIdentifier:kCellID owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = kCellID;
        NSTextField* tf = [NSTextField labelWithString:@""];
        tf.lineBreakMode = NSLineBreakByTruncatingTail;
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:tf];
        cell.textField = tf;
        // vertical centre
        [NSLayoutConstraint activateConstraints:@[
            [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4]
        ]];
        // leading constraint stored as a named tag via objc_setAssociatedObject isn't
        // available cleanly — we add it below every time since reuse resets it anyway.
    }
    const auto& entry = (*_toc)[row];
    cell.textField.stringValue = [NSString stringWithUTF8String:entry.title.c_str()];
    cell.textField.font = [NSFont systemFontOfSize:13];

    // Remove any old leading constraint and add one with correct indent
    for (NSLayoutConstraint* c in cell.constraints) {
        if (c.firstAttribute == NSLayoutAttributeLeading) {
            [cell removeConstraint:c];
            break;
        }
    }
    CGFloat indent = 12.0 + entry.depth * 16.0;
    [NSLayoutConstraint activateConstraints:@[
        [cell.textField.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor
                                                     constant:indent]
    ]];

    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification*)note {
    NSInteger row = _tableView.selectedRow;
    if (row >= 0) [_controller jumpToTocEntryIndex:row];
}

// MARK: - Active tracking

- (void)setActiveTocIndex:(NSInteger)idx {
    if (idx < 0) {
        [_tableView deselectAll:nil];
        return;
    }
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)idx]
            byExtendingSelection:NO];
    [_tableView scrollRowToVisible:idx];
}

@end
```

- [ ] **Step 2: Register sources in CMakeLists.txt**

In `src/ui/macos/CMakeLists.txt`, add `TocSidebarViewController.mm` to the executable and to the ARC `set_source_files_properties` call:

```cmake
add_executable(ureader MACOSX_BUNDLE
  ${PROJECT_SOURCE_DIR}/src/main.mm
  AppDelegate.mm
  EpubWindowController.mm
  EpubSchemeHandler.mm
  BridgeMessageHandler.mm
  TocSidebarViewController.mm
  ${PROJECT_SOURCE_DIR}/resources/shell.html
)
```

```cmake
set_source_files_properties(
  ${PROJECT_SOURCE_DIR}/src/main.mm
  AppDelegate.mm
  EpubWindowController.mm
  EpubSchemeHandler.mm
  BridgeMessageHandler.mm
  TocSidebarViewController.mm
  PROPERTIES COMPILE_FLAGS "-fobjc-arc"
)
```

- [ ] **Step 3: Build**

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build 2>&1 | tail -20
```

Expected: builds cleanly. Fix any compile errors before continuing.

- [ ] **Step 4: Commit**

```bash
git add src/ui/macos/TocSidebarViewController.mm src/ui/macos/CMakeLists.txt
git commit -m "feat: implement TocSidebarViewController"
```

---

## Task 3: Wire `NSSplitViewController` into `EpubWindowController`

**Files:**
- Modify: `src/ui/macos/EpubWindowController.h`
- Modify: `src/ui/macos/EpubWindowController.mm`

- [ ] **Step 1: Update the header**

Replace the entire contents of `src/ui/macos/EpubWindowController.h`:

```objc
#pragma once
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <memory>
#include "EpubBook.h"

@interface EpubWindowController : NSObject <NSWindowDelegate>
@property (nonatomic, readonly) NSWindow* window;
- (instancetype)initWithPath:(NSString*)path;
- (void)showWindow;

// Called by BridgeMessageHandler
- (void)shellReady;
- (void)navigate:(NSString*)direction;
- (void)jumpToTocEntryIndex:(NSInteger)entryIndex;
- (void)setActiveTocIndex:(NSInteger)idx;
@end
```

- [ ] **Step 2: Rewrite `EpubWindowController.mm`**

Replace the entire file:

```objc
#import "EpubWindowController.h"
// Class extension — declare NSToolbarDelegate conformance here so the compiler
// knows the delegate methods in this file satisfy the protocol.
@interface EpubWindowController () <NSToolbarDelegate>
@end
#import "TocSidebarViewController.h"
#import "EpubSchemeHandler.h"
#import "BridgeMessageHandler.h"
#import "app/StateStore.h"
#include "EpubParser.h"

@implementation EpubWindowController {
    NSWindow*                   _window;
    WKWebView*                  _webView;
    TocSidebarViewController*   _tocSidebar;
    NSSplitViewItem*            _tocSplitItem;
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
    NSViewController* contentVC = [[NSViewController alloc] initWithNibName:nil bundle:nil];
    contentVC.view = _webView;

    _tocSplitItem = [NSSplitViewItem sidebarWithViewController:_tocSidebar];
    _tocSplitItem.minimumThickness = 160;
    _tocSplitItem.maximumThickness = 320;
    _tocSplitItem.collapsed = YES;

    NSSplitViewItem* contentItem = [NSSplitViewItem splitViewItemWithViewController:contentVC];

    NSSplitViewController* splitVC = [[NSSplitViewController alloc] init];
    [splitVC addSplitViewItem:_tocSplitItem];
    [splitVC addSplitViewItem:contentItem];
    splitVC.splitView.vertical = YES;

    _window.contentViewController = splitVC;

    // ── Toolbar ──────────────────────────────────────────────────────
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainToolbar"];
    toolbar.delegate = (id<NSToolbarDelegate>)self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    _window.toolbar = toolbar;

    return self;
}

- (void)showWindow {
    [_window makeKeyAndOrderFront:nil];
}

// MARK: - NSToolbarDelegate

- (NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
    return @[@"ToggleToc"];
}

- (NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)tb {
    return @[@"ToggleToc"];
}

- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
    itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:@"ToggleToc"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.label = @"Table of Contents";
        item.toolTip = @"Show or hide the table of contents";
        item.image = [NSImage imageWithSystemSymbolName:@"sidebar.left"
                                accessibilityDescription:@"Toggle sidebar"];
        item.target = self;
        item.action = @selector(toggleTocSidebar:);
        return item;
    }
    return nil;
}

- (void)toggleTocSidebar:(id)sender {
    [_tocSplitItem.animator setCollapsed:!_tocSplitItem.isCollapsed];
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
    [_tocSidebar setActiveTocIndex:entryIndex];
}

- (void)setActiveTocIndex:(NSInteger)idx {
    _activeTocIndex = idx;
    [_tocSidebar setActiveTocIndex:idx];
}

// MARK: - Private helpers

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
```

- [ ] **Step 3: Build**

```bash
cmake --build build 2>&1 | tail -20
```

Expected: clean build. The app should launch and display the book with a toolbar sidebar button (TOC hidden by default).

- [ ] **Step 4: Commit**

```bash
git add src/ui/macos/EpubWindowController.h src/ui/macos/EpubWindowController.mm
git commit -m "feat: replace bare window with NSSplitViewController + native TOC sidebar"
```

---

## Task 4: Handle `tocSelectionChanged` in the bridge

**Files:**
- Modify: `src/ui/macos/BridgeMessageHandler.mm`

- [ ] **Step 1: Add the new action handler**

Replace the entire file:

```objc
#import "BridgeMessageHandler.h"
#import "EpubWindowController.h"

@implementation BridgeMessageHandler {
    __weak EpubWindowController* _controller;
}

- (instancetype)initWithController:(EpubWindowController*)controller {
    self = [super init];
    _controller = controller;
    return self;
}

- (void)userContentController:(WKUserContentController*)controller
      didReceiveScriptMessage:(WKScriptMessage*)message {
    NSDictionary* body = message.body;
    NSString* action = body[@"action"];

    if ([action isEqualToString:@"ready"]) {
        [_controller shellReady];
    } else if ([action isEqualToString:@"navigate"]) {
        [_controller navigate:body[@"direction"]];
    } else if ([action isEqualToString:@"tocSelectionChanged"]) {
        [_controller setActiveTocIndex:[body[@"tocEntryIndex"] integerValue]];
    }
}

@end
```

- [ ] **Step 2: Build**

```bash
cmake --build build 2>&1 | tail -10
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add src/ui/macos/BridgeMessageHandler.mm
git commit -m "feat: handle tocSelectionChanged bridge action"
```

---

## Task 5: Remove HTML sidebar, update JS bridge post

**Files:**
- Modify: `resources/shell.html`

- [ ] **Step 1: Rewrite `shell.html`**

Replace the entire file with this cleaned-up version (HTML sidebar removed, `tocSelectionChanged` posted from IntersectionObserver):

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ureader</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: #111;
  color: #ccc;
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 13px;
  overflow: hidden;
  -webkit-user-select: none;
  user-select: none;
}

#toolbar {
  display: flex;
  align-items: center;
  padding: 0 14px;
  height: 36px;
  background: #161616;
  border-bottom: 1px solid #222;
  flex-shrink: 0;
}
#position {
  flex: 1;
  text-align: center;
  color: #555;
  font-size: 12px;
}

#content-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
#content-frame {
  flex: 1;
  border: none;
  width: 100%;
  background: #fff;
}

#nav-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 16px;
  background: #161616;
  border-top: 1px solid #222;
  flex-shrink: 0;
}
.nav-btn {
  background: #2a2a2a;
  border: 1px solid #333;
  color: #999;
  padding: 5px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
}
.nav-btn:hover:not(:disabled) { background: #333; color: #ccc; }
.nav-btn:disabled { opacity: 0.3; cursor: default; }
#book-title { font-size: 11px; color: #444; }
</style>
</head>
<body>

<div id="toolbar">
  <span id="position"></span>
</div>

<div id="content-area">
  <iframe id="content-frame" src="about:blank" sandbox="allow-same-origin allow-scripts"></iframe>
  <div id="nav-footer">
    <button class="nav-btn" id="prev-btn" onclick="doNavigate('prev')">← Prev</button>
    <span id="book-title"></span>
    <button class="nav-btn" id="next-btn" onclick="doNavigate('next')">Next →</button>
  </div>
</div>

<script>
var _spineCount = 0;
var _currentIndex = 0;

function doNavigate(direction) {
  window.webkit.messageHandlers.bridge.postMessage(
    { action: 'navigate', direction: direction });
}

function injectObserver(iframe, tocAnchors) {
  if (!tocAnchors || !tocAnchors.length) return;
  var doc = iframe.contentDocument;
  if (!doc) return;
  var targets = tocAnchors
    .map(function(a) { return { el: doc.getElementById(a.id), tocIndex: a.tocIndex }; })
    .filter(function(a) { return !!a.el; });
  if (!targets.length) return;

  var observer = new IntersectionObserver(function(entries) {
    var visible = entries
      .filter(function(e) { return e.isIntersecting; })
      .sort(function(a, b) { return a.boundingClientRect.top - b.boundingClientRect.top; });
    if (visible.length > 0) {
      var target = visible[0].target;
      var match = targets.find(function(a) { return a.el === target; });
      if (match) {
        window.webkit.messageHandlers.bridge.postMessage(
          { action: 'tocSelectionChanged', tocEntryIndex: match.tocIndex });
      }
    }
  }, { threshold: 0.1 });

  targets.forEach(function(a) { observer.observe(a.el); });
}

function loadBook(data) {
  _spineCount = data.spineCount;
  document.getElementById('book-title').textContent = data.title || '';

  navigateTo({
    spineIndex:     data.currentIndex,
    url:            data.currentUrl,
    activeTocIndex: data.activeTocIndex,
    tocAnchors:     data.tocAnchors || []
  });
}

function navigateTo(data) {
  _currentIndex = data.spineIndex;
  var frame = document.getElementById('content-frame');
  frame.src = data.url;
  document.getElementById('position').textContent =
    (_currentIndex + 1) + ' / ' + _spineCount;
  document.getElementById('prev-btn').disabled = (_currentIndex === 0);
  document.getElementById('next-btn').disabled = (_currentIndex === _spineCount - 1);

  var anchors = data.tocAnchors || [];
  frame.onload = anchors.length
    ? function() { injectObserver(frame, anchors); }
    : null;
}

window.webkit.messageHandlers.bridge.postMessage({ action: 'ready' });
</script>
</body>
</html>
```

- [ ] **Step 2: Build**

```bash
cmake --build build 2>&1 | tail -10
```

Expected: clean build.

- [ ] **Step 3: Smoke-test the app**

```bash
open build/src/ui/macos/ureader.app /path/to/a/book.epub
```

Verify:
- Reading area fills the full window width on launch
- Toolbar shows the sidebar icon button
- Clicking the toolbar button reveals the native TOC list
- Clicking a TOC entry navigates to that chapter
- Clicking the toolbar button again hides it
- Prev/Next buttons still work
- Position counter (`1 / N`) updates correctly

- [ ] **Step 4: Commit**

```bash
git add resources/shell.html
git commit -m "feat: remove HTML sidebar from shell, post tocSelectionChanged from IntersectionObserver"
```

---

## Task 6: Add View > Table of Contents menu item

**Files:**
- Modify: `src/ui/macos/EpubWindowController.mm`

The app creates its window programmatically. Add a View menu item that mirrors the toolbar toggle, with a `Cmd+Ctrl+S` keyboard shortcut. This is done once in `initWithPath:` after the toolbar is set up.

- [ ] **Step 1: Add menu item creation to `initWithPath:` in `EpubWindowController.mm`**

Inside `initWithPath:`, after `_window.toolbar = toolbar;`, add:

```objc
    // ── View menu ────────────────────────────────────────────────────
    NSMenu* menuBar = [NSApp mainMenu];
    NSMenuItem* viewMenuItem = [menuBar itemWithTitle:@"View"];
    if (!viewMenuItem) {
        viewMenuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
        NSMenu* viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
        viewMenuItem.submenu = viewMenu;
        [menuBar addItem:viewMenuItem];
    }
    NSMenuItem* tocItem = [[NSMenuItem alloc]
        initWithTitle:@"Table of Contents"
               action:@selector(toggleTocSidebar:)
        keyEquivalent:@"s"];
    tocItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
    tocItem.target = self;
    [viewMenuItem.submenu addItem:tocItem];
```

- [ ] **Step 2: Build**

```bash
cmake --build build 2>&1 | tail -10
```

Expected: clean build.

- [ ] **Step 3: Verify menu item appears**

```bash
open build/src/ui/macos/ureader.app /path/to/a/book.epub
```

Check that the View menu contains "Table of Contents" and that `Cmd+Ctrl+S` toggles the sidebar.

- [ ] **Step 4: Commit**

```bash
git add src/ui/macos/EpubWindowController.mm
git commit -m "feat: add View > Table of Contents menu item with Cmd+Ctrl+S shortcut"
```
