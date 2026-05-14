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
Find text across all chapters of a book.

**FEAT-02: Persistent window and TOC state**
Window size, position, and TOC sidebar state should be remembered across sessions.

**FEAT-03: External link handling**
Clicking a link to an external website should open it in the browser, not the reading pane.

**FEAT-04: Book identity in Dock and Mission Control**
When several books are open simultaneously, each window should be visually distinguishable.

**FEAT-05: Theme support**
The app chrome is dark but book content typically has a white background. Reading theme should be adjustable (light, dark, sepia).

**FEAT-06: Adjustable text size**
Text size should be adjustable for readability and accessibility.

**FEAT-07: Keyboard navigation**
Chapters should be navigable from the keyboard.

**FEAT-08: Reading progress**
The position indicator should convey overall progress through the book, not just the current chapter number.

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
