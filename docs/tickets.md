# ureader — Ticket Backlog

## Bugs

### Critical

**BUG-01: C++ exceptions crash app on malformed epub**
C++ exceptions from `EpubParser::parse` unwind through ObjC frames — UB that crashes in practice. `AppDelegate` only catches `NSException`, not `std::exception`.
_Fix: wrap `EpubParser::parse` in `try/catch (const std::exception&)` inside `initWithPath:`, convert to NSError or show alert._
_Ref: code-review #2_

**BUG-02: App crashes on epub with non-UTF-8 metadata**
`[NSString stringWithUTF8String:]` returns `nil` for invalid UTF-8. Inserting `nil` into an NSDictionary literal raises `NSInvalidArgumentException` → uncaught → crash.
_Fix: guard every `stringWithUTF8String:` with `?: @""`._
_Ref: code-review #9_

**BUG-03: state.json data loss on crash**
`save()` truncates and rewrites the file in-place. A crash mid-write leaves a partial/empty file and all saved positions are lost.
_Fix: write to `state.json.tmp` then `rename()` (atomic on POSIX)._
_Ref: code-review #11_

---

### High

**BUG-04: IntersectionObserver scroll tracking may be silently broken**
WKWebView custom schemes may assign opaque/unique origins per load. If the shell (`epub://book/shell`) and the iframe content (`epub://book/OEBPS/...`) are not same-origin, `iframe.contentDocument` returns `nil` and `injectObserver` silently exits — scroll-based TOC tracking does nothing.
_Fix: add logging to verify; if broken, switch to WKUserScript injection._
_Ref: code-review #3_

**BUG-05: Percent-encoded fragment IDs and filenames don't resolve**
`TocEntry.fragment` is stored without percent-decoding. `doc.getElementById("Chapter%201")` finds nothing when the element has `id="Chapter 1"`. Also affects filenames with spaces in epub hrefs.
_Fix: percent-decode hrefs at parse time; canonicalize to decoded form._
_Ref: code-review #4, #5_

**BUG-06: App shows no error when shell.html is missing from bundle**
`initWithPath:` returns `nil` if shell.html is not found. `AppDelegate` calls `[wc showWindow]` without nil-checking — silent failure, no window, no error message.
_Fix: check `if (!wc)` in `openEpubAtPath:` and show an alert._
_Ref: code-review #7_

**BUG-07: All books without dc:identifier share the same saved position**
Epubs missing `<dc:identifier>` get `metadata.uid == ""`. All such books use `""` as the state key and overwrite each other's position.
_Fix: fall back to a hash of the file path when uid is empty._
_Ref: code-review #8_

---

### Medium

**BUG-08: IntersectionObserver not disconnected between chapter loads**
`injectObserver` creates a new observer but never disconnects the previous one. Stale observers can fire `setActiveTocIndex` with indices from a departed chapter during rapid navigation.
_Fix: store active observer in `_activeObserver`; call `.disconnect()` before creating a new one._
_Ref: code-review #10_

**BUG-09: epub hrefs with `..` segments don't resolve**
`fullPath` joins `opfDir + "/" + item.path` without normalizing. Hrefs like `../Images/cover.jpg` produce invalid ZIP paths and fail silently.
_Fix: resolve `..` segments when constructing full paths._
_Ref: code-review #6_

**BUG-10: TOC entries with `<span>`-wrapped labels are silently dropped**
EPUB 3 nav documents often use `<a href="..."><span>Title</span></a>` for styling. `a->GetText()` returns empty → TOC entry not added → incomplete table of contents.
_Fix: fall back to first child `<span>` text when `a->GetText()` is empty._
_Ref: code-review #15_

**BUG-11: state.json written on every navigation — unnecessary disk I/O**
Every prev/next tap synchronously writes the file. Redundant given `windowWillClose:` already saves on exit.
_Fix: remove `save()` from `setPosition` called during navigation; keep only the `windowWillClose:` save (or debounce)._
_Ref: code-review #12_

---

### Low

**BUG-12: Blank page with no error when epub is on unmounted volume**
The epub file is held open via `FILE*` for the window's lifetime. If the source volume is unmounted, `readFile` returns empty silently — the iframe shows a blank page.
_Fix: detect empty response for primary navigation requests and show an alert._
_Ref: code-review #13_

**BUG-13: NCX navPoint depth incorrect when parent has no valid spine match**
`parseTocNcxElement` recurses with `depth + 1` even when the parent navPoint was skipped (no label or no matching spine item). Child entries get wrong nesting depth.
_Ref: code-review #14_

---

## Features

### Phase 3 — Reading Comfort Sprint

**FEAT-01: Dark/light/sepia theme with content CSS injection**
The shell chrome is dark but epub content renders with its own (typically white) CSS. Inject a CSS override into the iframe based on user preference and/or system appearance.

**FEAT-02: Font size controls**
Allow user to increase/decrease font size via injected CSS. Persist per-book or globally.

**FEAT-03: Keyboard navigation**
Arrow keys / space / page-down to advance, backspace / page-up to go back. Standard desktop reading expectation.

---

### Phase 3 — Discovery Sprint

**FEAT-04: Recent files list**
Show recently opened books when no file is open (instead of exiting). Persist across sessions via NSUserDefaults or a small JSON list alongside state.json.

**FEAT-05: Re-open file from within window**
Allow opening a different book from an existing window (e.g. File menu > Open, or drag-and-drop onto the window).

**FEAT-06: Window title includes author name**
Show `Title — Author` in the window title bar and Dock tooltip. Helps distinguish multiple open windows.

---

### Phase 4 — Enriched Reading

**FEAT-07: Bookmarks**
Mark and name specific positions within a book. Persist alongside reading position in state.json.

**FEAT-08: In-book search**
Search across spine items for a text string. Show results list; clicking navigates to the match.

**FEAT-09: Persist window size and TOC sidebar state**
Restore last window frame and TOC open/closed state on re-open.

**FEAT-10: External link handling**
Open `http://` / `https://` links from epub content in the default browser rather than attempting to load in the iframe.

**FEAT-11: Fixed-layout EPUB detection**
Detect `rendition:layout="pre-paginated"` in the OPF and show a clear message ("This book uses a fixed layout and is not supported") rather than rendering incorrectly.

**FEAT-12: Cover image in Dock / window thumbnail**
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
