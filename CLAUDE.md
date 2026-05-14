# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

Release:
```bash
cmake -G Ninja -B build-release -DCMAKE_BUILD_TYPE=Release
cmake --build build-release
```

The app bundle is at `build/src/ui/macos/ureader.app`.

## Tests

Unit tests only (fast, no display required):
```bash
cd build && ctest -R epub_tests -V
```

UI tests launch and drive the real app — do NOT run without asking the user first, as they take over the entire screen for ~30 seconds:
```bash
cd build && ctest -R XCTest -V
```

Run a single doctest case by name:
```bash
./build/src/epub/epub_tests -tc="EpubParser — valid epub2"
```

Regenerate the test fixture epub after changing `src/epub/fixtures/create_fixtures.sh`:
```bash
src/epub/fixtures/create_fixtures.sh
```

## Architecture

Three modules with clean interfaces:

**`src/epub/`** — pure C++17, no platform dependencies. `EpubParser::parse(path)` opens a ZIP (miniz), reads `META-INF/container.xml` → OPF → spine + manifest + TOC (NCX or nav.xhtml). Returns `std::unique_ptr<EpubBook>` which owns the open ZIP handle for its lifetime. `TocEntry` has a `fragment` field for subsection anchors (`chapter.xhtml#section-1`). Internal header `epub_internal.h` defines `EpubBook::ZipHandle` (wraps `mz_zip_archive`) and must be included by any file that constructs one — keeps miniz out of the public `EpubBook.h`.

**`src/app/`** — pure C++17. `StateStore` singleton persists reading position (spine index) keyed by epub `dc:identifier` to `~/Library/Application Support/ureader/state.json`.

**`src/ui/macos/`** — Objective-C++ (.mm). One `EpubWindowController` per open book: creates `NSWindow` + `WKWebView`, registers `EpubSchemeHandler` for the `epub://` custom URL scheme, and wires `BridgeMessageHandler` for JS↔native messaging. The shell UI (`resources/shell.html`) is a permanent WKWebView load; epub chapter content loads inside an `<iframe>` at `epub://book/<zip-path>`. Shell and iframe share origin `epub://book` so JavaScript in the shell can access `iframe.contentDocument` for IntersectionObserver-based TOC tracking.

**JS bridge** — shell → native via `window.webkit.messageHandlers.bridge.postMessage({action, ...})` with actions `ready`, `navigate`, `jumpTo` (sends `tocEntryIndex`). Native → shell via `evaluateJavaScript:` calling `loadBook(data)` or `navigateTo(data)`, both passing `activeTocIndex` and `tocAnchors` (subsection anchor IDs for the current chapter).

**File opening** — no in-app picker. Files arrive via `application:openFile:` (Finder double-click / "Open With") or `argv[1]` (CLI). The app exits immediately if launched with no file.

## Tickets

Tracked as GitHub Issues: https://github.com/shitikanth/ureader/issues

When the user says "work on #N", look up issue #N there. Use `gh issue view N` to fetch it.

## Third-party libraries

All vendored in `third_party/`, each built as an independent CMake target:
- `miniz` — ZIP reading (`miniz.h` + `miniz.c`, release 3.1.1)
- `tinyxml2` — XML parsing
- `doctest` — C++ unit test framework (header-only, test binary only)
