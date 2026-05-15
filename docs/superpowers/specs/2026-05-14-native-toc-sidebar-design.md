# Native TOC Sidebar Design

**Date:** 2026-05-14  
**Status:** Approved

## Goal

Replace the HTML/JS table of contents sidebar with a native macOS `NSTableView`-based sidebar, matching the look and behavior of Preview/Books app.

## Decisions

- Sidebar **hidden by default**; reading area is full-width until the user opens it.
- TOC entries shown as a **flat indented list** (always fully expanded). No disclosure triangles.
- Toggle via **toolbar button** + View menu item.

## Window Structure

`EpubWindowController` hosts an `NSSplitViewController` as `contentViewController`. Two split items:

| Item | Widget | Initial state |
|---|---|---|
| Left (TOC) | `TocSidebarViewController` | `collapsed = YES` |
| Right (content) | `NSViewController` wrapping `WKWebView` | always visible |

The left `NSSplitViewItem` has `minimumThickness = 160`, `maximumThickness = 320`.

A new `NSToolbar` is added to the window with one item: a sidebar toggle button (`sidebar.left` SF Symbol). Clicking it calls `animator.collapsed = !item.collapsed`. A **View > Table of Contents** menu item mirrors the button with a `Cmd+Ctrl+S` shortcut.

## TOC Sidebar Component

**New file:** `src/ui/macos/TocSidebarViewController.{h,mm}`

- Owns an `NSScrollView` + `NSTableView` (single column, no header, `NSTableViewStyleSourceList`).
- Data source: holds `const std::vector<TocEntry>*` pointing into the live `EpubBook`. No copying.
- Row count = `toc.size()`.
- Each row uses a reusable `NSTableCellView`. In `tableView:viewForTableColumn:row:`, the cell's `textField.stringValue` is set to `entry.title` and its leading constraint constant is set to `12 + entry.depth * 16` pt.
- Weak back-pointer to `EpubWindowController` set at init time.
- `tableViewSelectionDidChange:` calls `[_windowController jumpToTocEntryIndex:selectedRow]` directly.
- `-setActiveTocIndex:(NSInteger)idx` calls `selectRowIndexes:byExtendingSelection:NO` + `scrollRowToVisible:`. Called by `EpubWindowController` whenever `_activeTocIndex` changes.

## JS Bridge Changes

### Removed from shell.html
- `#toc-sidebar` div and all sidebar CSS
- ☰ toggle button
- `buildToc()`, `renderTocItems()`, `doJumpTo()` functions
- `setActiveTocIndex()` CSS class manipulation

### Added to shell.html
When the IntersectionObserver fires and detects a new active TOC entry, post:
```js
window.webkit.messageHandlers.bridge.postMessage(
  { action: 'tocSelectionChanged', tocEntryIndex: idx });
```

### Updated bridge action table

| Direction | Action | Handler |
|---|---|---|
| JS → Native | `ready` | `shellReady` |
| JS → Native | `navigate` | prev/next spine nav |
| JS → Native | `tocSelectionChanged` | `setActiveTocIndex:` (new) |
| Native → JS | `loadBook` | initial book data |
| Native → JS | `navigateTo` | chapter/anchor navigation |

`jumpTo` is removed — TOC clicks go directly to `jumpToTocEntryIndex:` without a JS round-trip.

The `toc` array in `loadBook` data is kept (still needed for `tocAnchors` and IntersectionObserver anchor IDs). The JS just stops rendering it as HTML.

## Files Changed

| File | Change |
|---|---|
| `src/ui/macos/TocSidebarViewController.h` | New |
| `src/ui/macos/TocSidebarViewController.mm` | New |
| `src/ui/macos/EpubWindowController.h` | Add `TocSidebarViewController*` ivar |
| `src/ui/macos/EpubWindowController.mm` | Replace bare window+webview setup with NSSplitViewController; wire sidebar; update `_activeTocIndex` setter to notify sidebar |
| `src/ui/macos/BridgeMessageHandler.mm` | Handle `tocSelectionChanged` action |
| `resources/shell.html` | Remove HTML sidebar; add `tocSelectionChanged` bridge post |
| `src/ui/macos/CMakeLists.txt` | Add new source files |

## Out of Scope

- Sidebar width persistence (not needed; default width on every open is fine)
- Collapse/expand of individual chapters (flat list only)
- Search within TOC
