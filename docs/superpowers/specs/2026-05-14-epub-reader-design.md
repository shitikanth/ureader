# ureader — Epub Reader Design

**Date:** 2026-05-14  
**Status:** Approved

## Overview

A lightweight desktop epub reader. Each open file gets its own window. The webview renders epub HTML content served via a custom `epub://` URL scheme handler — no embedded HTTP server. Platform UI is written natively per platform; epub parsing is shared C++.

First implementation: macOS. Linux and Windows follow the same module structure with platform-specific `ui/` implementations.

---

## Architecture

Three modules with clean interfaces:

```
epub/        — pure C++, no platform deps
ui/macos/    — Objective-C++ (AppKit + WebKit)
app/         — cross-platform orchestration, state persistence
```

### epub/

Knows about EPUBs. Nothing else.

- **`EpubParser`** — opens the ZIP (via miniz), reads `META-INF/container.xml` to locate the OPF file, parses it (via tinyxml2) to extract spine and metadata, parses NCX or `nav.xhtml` for the TOC
- **`EpubBook`** — holds the parsed result: spine (ordered `SpineItem` list), TOC (`TocEntry` tree), metadata (title, author, uid), open ZIP handle for content reads
- **`SpineItem`** — epub-internal path + media type
- **`TocEntry`** — title, spine index, depth (for nested TOC)

Dependencies: `miniz` (ZIP), `tinyxml2` (XML) — both single-header, vendored in `third_party/`.

### ui/macos/

Knows about windows and the webview. Nothing about epub internals.

- **`AppDelegate`** — `NSApplicationDelegate`. Handles `application:openFiles:` (creates one `EpubWindowController` per path). Returns `YES` from `applicationShouldTerminateAfterLastWindowClosed:`.
- **`EpubWindowController`** — owns one `NSWindow` + one `WKWebView`. On init: configures `WKWebViewConfiguration`, registers the `epub://` scheme handler, loads the HTML shell, then parses the epub and sends book data to JS once the shell signals ready.
- **`EpubSchemeHandler`** — implements `WKURLSchemeHandler`. Resolves `epub://` paths against the epub's OPF directory, reads bytes from the ZIP, infers MIME type from extension, returns response.
- **`BridgeMessageHandler`** — implements `WKScriptMessageHandler`. Receives JS→ObjC messages, dispatches to `EpubWindowController`.

### app/

- **`StateStore`** — reads/writes `~/Library/Application Support/ureader/state.json` via `NSJSONSerialization`. Stores `{ "positions": { "<epub-uid>": <spineIndex> } }`. Epub UID is `dc:identifier` from OPF; falls back to filename if absent.

---

## File Opening

No in-app file picker. Files are opened via:

1. **macOS file association** — `Info.plist` declares `.epub` UTI (`org.idpf.epub-container`). Double-click or "Open With" in Finder launches the app (or routes to the running instance) with the file path.
2. **`argv[1]`** — if a path is passed at launch, open that file directly.
3. **`application:openFiles:`** — macOS routes subsequent opens to the running process; `AppDelegate` handles each path.

If launched with no file and no `openFiles:` event arrives, the process exits immediately (no window shown).

---

## Content Serving — `epub://` Custom Scheme

`EpubSchemeHandler` is registered on `WKWebViewConfiguration` before the webview is created:

```
epub://<any-host>/<path-relative-to-opf-dir>
```

The host component is ignored; only the path matters. The handler reads the requested path from the open ZIP and returns the raw bytes with the appropriate `Content-Type`.

MIME type inference by extension: `.html`/`.xhtml` → `text/html`, `.css` → `text/css`, `.js` → `application/javascript`, `.png` → `image/png`, `.jpg`/`.jpeg` → `image/jpeg`, `.gif` → `image/gif`, `.svg` → `image/svg+xml`, `.ttf`/`.otf`/`.woff`/`.woff2` → appropriate font types.

---

## JS Bridge

**JS → ObjC** via `WKScriptMessageHandler` (handler name: `"bridge"`):

```js
window.webkit.messageHandlers.bridge.postMessage({ action: "ready" })
window.webkit.messageHandlers.bridge.postMessage({ action: "navigate", direction: "next" })
window.webkit.messageHandlers.bridge.postMessage({ action: "navigate", direction: "prev" })
window.webkit.messageHandlers.bridge.postMessage({ action: "jumpTo", spineIndex: N })
```

**ObjC → JS** via `evaluateJavaScript:completionHandler:`:

```js
loadBook({ title, author, toc: [{ title, spineIndex }], currentIndex, spineCount })
navigateTo({ spineIndex, url: "epub://book/path/to/chapter.xhtml" })
```

Serialization uses `NSJSONSerialization` / `NSDictionary` — no third-party JSON library.

---

## UI Shell

A minimal HTML/CSS/JS file embedded in the binary as a string constant (or compiled-in resource). Two-panel layout:

- **TOC sidebar** (left, collapsible) — populated by `loadBook()`, highlights current spine item, clicking calls `jumpTo`
- **Content area** (right) — an `<iframe>` whose `src` is set to the `epub://` URL for the current spine item. The shell stays loaded in the WKWebView; only the iframe src changes on navigation.
- **Navigation footer** — Prev / Next buttons call `navigate()`
- **Toolbar** — ☰ toggle for sidebar, spine position indicator (`3 / 9`)

The shell has no "Open File" button. It only renders content it receives from the bridge.

---

## State Persistence

On spine navigation: `StateStore` writes the new `spineIndex` keyed by epub UID.  
On book load: `StateStore` reads the saved index; if found, `navigateTo` jumps there instead of spine[0].

File location: `~/Library/Application Support/ureader/state.json`

---

## Dependencies

| Library | Purpose | How |
|---------|---------|-----|
| miniz | ZIP extraction | Single header, vendored as `third_party/miniz.h` |
| tinyxml2 | OPF/NCX XML parsing | Two files, vendored as `third_party/tinyxml2.h` + `third_party/tinyxml2.cpp` |
| AppKit | macOS windows | System framework |
| WebKit | WKWebView + scheme handler | System framework |

---

## Build

CMake project. `epub/` compiles as a static library (`libepub.a`). `ui/macos/` Objective-C++ `.mm` files link against it. Output is a `.app` bundle.

```
CMakeLists.txt
src/
  epub/          — EpubParser.cpp, EpubBook.cpp, ...
  ui/macos/      — AppDelegate.mm, EpubWindowController.mm, ...
  app/           — StateStore.mm
  main.mm
third_party/
  miniz.h
  tinyxml2.h
  tinyxml2.cpp
resources/
  shell.html     — embedded UI shell
Info.plist
```

`Info.plist` declares:
- `CFBundleDocumentTypes` with `LSItemContentTypes: [org.idpf.epub-container]`
- `CFBundleExecutable`, `CFBundleIdentifier`, etc.

---

## Error Handling

- **Parse failure** (corrupt ZIP, missing OPF): log to stderr, close window, show `NSAlert` with the error message
- **Missing spine item**: skip to next valid item
- **Scheme handler path not found in ZIP**: return HTTP 404 response to the webview
- **State file unreadable/corrupt**: silently start from spine[0]

---

## Future Platforms

`ui/linux/` — GTK3 + WebKitGTK, `WebKitWebView` + custom URI scheme via `webkit_web_context_register_uri_scheme`.  
`ui/windows/` — WebView2, `ICoreWebView2` + custom scheme via `AddWebResourceRequestedFilter`.

The `epub/` and `app/` modules compile unchanged on all platforms.
