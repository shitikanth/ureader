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
Users cannot search for text within a book.

**FEAT-02: Window and TOC state not persisted**
Window size, position, and TOC sidebar open/closed state reset on every launch.

**FEAT-03: External links open inside the reader**
Clicking a link to an external website loads it inside the reading pane instead of the browser.

**FEAT-04: Multiple open windows are indistinguishable in the Dock**
When several books are open, the Dock and Mission Control show identical icons with no visual way to tell them apart.

**FEAT-05: Content theme does not match the app chrome**
The app chrome is dark but book content typically renders with a white background, creating a jarring contrast. There is no way to switch themes.

**FEAT-06: Text size cannot be adjusted**
There are no controls to make text larger or smaller.

**FEAT-07: No keyboard navigation**
Users cannot navigate between chapters using the keyboard.

**FEAT-08: Progress indicator shows chapter number, not book progress**
The "3 / 9" indicator counts spine items. Users have no sense of how far through the book they are.

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
