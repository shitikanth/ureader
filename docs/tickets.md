# ureader — Ticket Backlog

## Infrastructure

**INFRA-01: CI/CD — GitHub Actions build and test pipeline**
Set up a GitHub Actions workflow on every push and PR:
- macOS runner (macos-latest)
- Configure CMake with Ninja (`cmake -G Ninja -B build`)
- Build all targets (`cmake --build build`)
- Run unit tests only (`ctest -R epub_tests -V`) — UI tests require accessibility permissions and a real display, not suitable for CI
- Fail the build on any test failure

Optional follow-on: upload `ureader.app` as a build artifact on pushes to `main`.

## Features

### Enriched Reading

**FEAT-01: In-book search**
Search across spine items for a text string. Show results list; clicking navigates to the match.

**FEAT-02: Persist window size and TOC sidebar state**
Restore last window frame and TOC open/closed state on re-open.

**FEAT-03: External link handling**
Open `http://` / `https://` links from epub content in the default browser rather than attempting to load in the iframe.

**FEAT-04: Cover image in Dock / window thumbnail**
Extract cover image from epub manifest and use as window thumbnail for better discoverability in Mission Control.

---

## Cleanup

**CLEANUP-01: Remove stale "implemented in Task 6" comment**
`src/epub/EpubParser.cpp:58` — the forward declarations are for functions in the same file.

**CLEANUP-02: Remove meaningless `(void)wc;` cast**
`src/ui/macos/AppDelegate.mm:41` — `wc` is already used on the previous line.

**CLEANUP-03: Replace `_selfRef` self-retain with AppDelegate window list**
`EpubWindowController` retaining itself is non-obvious. Have `AppDelegate` maintain an `NSMutableArray<EpubWindowController*>` instead.

**CLEANUP-04: Add `webp` and XML MIME types to EpubSchemeHandler**
`src/ui/macos/EpubSchemeHandler.mm` — missing `webp`, `xml`, `opf`, `ncx`.
