# ureader Code Review — 2026-05-14

## Critical

### #1 — `EpubParser::parse` destructs uninitialized ZIP on failure
**File:** `src/epub/EpubParser.cpp:235-239`

`ZipHandle` is allocated and zeroed before `mz_zip_reader_init_file`. If init fails, the exception unwinds through `~EpubBook`, which calls `mz_zip_reader_end` on a never-initialized archive. miniz tolerates this on a zeroed struct today but it is fragile.

**Fix:** Track an "initialized" flag in `ZipHandle`, or use a unique_ptr-with-deleter so the cleanup only runs on successful init.

---

### #2 — C++ exceptions escape into ObjC frames → undefined behaviour / crash
**File:** `src/ui/macos/EpubWindowController.mm:19`

```objc
_book = EpubParser::parse(path.UTF8String);  // throws std::runtime_error
```

`AppDelegate.mm` only `@catch (NSException*)`. A malformed epub unwinds through ObjC frames — formally UB, in practice a crash.

**Fix:** Wrap `EpubParser::parse` in `try/catch (const std::exception& e)` inside `initWithPath:` and either convert to `NSException` or return `nil` and pass an `NSError**` to the caller.

---

### #3 — IntersectionObserver same-origin assumption may be silently broken
**File:** `resources/shell.html`, `src/ui/macos/EpubWindowController.mm:57`

The shell is loaded with `baseURL: epub://book/shell`. WKWebView custom schemes typically have opaque/unique origins per-load unless explicitly configured. If the shell and iframe are not actually same-origin, `iframe.contentDocument` returns `nil`, `injectObserver` silently returns early, and scroll-based TOC tracking does nothing.

**Fix:** Log from `injectObserver` to verify `iframe.contentDocument` is non-null. If broken, inject the observer script via `WKUserScript` with `WKUserScriptInjectionTimeAtDocumentEnd` targeting epub:// URLs instead.

---

### #4 — Percent-encoded fragment IDs not decoded → TOC anchor lookup fails
**File:** `src/epub/EpubParser.cpp:160-162, 200-202`

`TocEntry.fragment` is taken from `href.substr(hash + 1)` without URL-decoding. If a nav document uses `Chapter%201` as an ID, the JS calls `doc.getElementById("Chapter%201")` but the HTML element has `id="Chapter 1"` — lookup returns null, observer not attached.

**Fix:** Percent-decode the fragment after extracting it, before storing in `TocEntry.fragment`.

---

## Important

### #5 — URL path decoding inconsistency in EpubSchemeHandler
**File:** `src/ui/macos/EpubSchemeHandler.mm:37-39`

`NSURL.path` returns a percent-decoded path. If `urlForSpineIndex:` built the URL from a raw OPF href that was already percent-encoded (e.g. `Chapter%201.xhtml`), the round-trip through `NSURL.path` will double-decode, producing the wrong zip path.

**Fix:** Normalize epub hrefs to decoded form at parse time in `EpubParser`. Canonicalize once, use everywhere.

---

### #6 — Relative paths containing `..` in epub hrefs don't resolve
**File:** `src/epub/EpubBook.cpp:21-24`

`fullPath` blindly joins `opfDir + "/" + item.path`. An href like `../Images/cover.jpg` from a nav file in a subdirectory produces an invalid ZIP path. Common in real-world epubs.

**Fix:** Normalize paths when constructing `fullPath` — resolve `..` segments and strip leading `/`.

---

### #7 — `initWithPath:` returns `nil` but caller doesn't check
**File:** `src/ui/macos/EpubWindowController.mm:50, 55`, `src/ui/macos/AppDelegate.mm:39`

If `shell.html` is missing from the bundle, `initWithPath:` returns `nil`. `AppDelegate` calls `[wc showWindow]` without a nil check — silently does nothing, no error shown to user.

**Fix:** Check `if (!wc)` in `AppDelegate.openEpubAtPath:` and show an alert.

---

### #8 — Empty UID uses `""` as state key — all UID-less books collide
**File:** `src/ui/macos/EpubWindowController.mm:20`

Epubs without a `<dc:identifier>` get `metadata.uid == ""`. All such books share the same state slot; opening any of them overwrites the others' saved position.

**Fix:** Fall back to a hash of the file path (or the absolute path itself) when `metadata.uid` is empty.

---

### #9 — `stringWithUTF8String:` returns nil on invalid UTF-8 → crash in `callJS`
**File:** `src/ui/macos/EpubWindowController.mm:68-88`

```objc
[NSString stringWithUTF8String:entry.title.c_str()]
```

Returns `nil` if the epub contains non-UTF-8 metadata. A `nil` entry in an NSDictionary literal `@{key: nil}` raises `NSInvalidArgumentException` → uncaught → crash.

**Fix:** Guard every `stringWithUTF8String:` with a fallback: `[NSString stringWithUTF8String:s.c_str()] ?: @""`.

---

### #10 — IntersectionObserver not disconnected between chapter loads
**File:** `resources/shell.html`

Each `injectObserver` call creates a new observer but never disconnects the previous one. Stale observers can call `setActiveTocIndex` for indices belonging to a previous chapter during rapid navigation.

**Fix:** Store the active observer in a module-level variable (`var _activeObserver = null`) and call `_activeObserver.disconnect()` before creating a new one.

---

### #11 — Non-atomic `state.json` write → data loss on crash
**File:** `src/app/StateStore.cpp:44-60`

The file is opened and overwritten in-place. A crash mid-write leaves an empty or partial file; on next launch all saved positions are lost.

**Fix:** Write to `state.json.tmp`, then `rename()` (atomic on POSIX).

---

### #12 — `state.json` written on every navigation — unnecessary disk I/O
**File:** `src/app/StateStore.cpp:39-42`

Every prev/next tap synchronously writes the file. For users with many books and rapid navigation this is wasteful.

**Fix:** Debounce writes, or rely on the `windowWillClose:` save which already exists and is sufficient for position persistence.

---

### #13 — EPUB file held open for entire window lifetime
**File:** `src/epub/EpubParser.cpp:238`

`mz_zip_reader_init_file` holds the file open via `FILE*`. If the epub is on a removable volume that is unmounted, subsequent `readFile` calls return empty silently — the reader shows blank pages with no user-visible error.

**Fix:** Detect `readFile` returning empty for a primary resource (not image/css) and surface an alert.

---

### #14 — `parseTocNcxElement` recurses even when parent navPoint is invalid
**File:** `src/epub/EpubParser.cpp:167`

Children of a navPoint that has no label or no valid spine index are still walked with `depth + 1`, producing incorrect nesting levels.

**Fix:** Only recurse when the parent navPoint was successfully added, or pass the parent's resolved depth rather than always incrementing.

---

### #15 — `<span>`-wrapped TOC labels silently skipped
**File:** `src/epub/EpubParser.cpp:191`

Many EPUB 3 nav documents use `<a href="..."><span>Chapter</span></a>` for styling. `a->GetText()` returns empty → entire TOC entry is dropped.

**Fix:** Fall back to `a->FirstChildElement("span")` when `a->GetText()` is empty, or collect all descendant text nodes.

---

## Minor

### #16 — Stale comment "implemented in Task 6"
**File:** `src/epub/EpubParser.cpp:58`

The forward declarations are for functions implemented in the same file. Remove the comment.

---

### #17 — Meaningless `(void)wc;` cast
**File:** `src/ui/macos/AppDelegate.mm:41`

`wc` is already used on the previous line. Remove the cast.

---

### #18 — `_selfRef` self-retain pattern is fragile
**File:** `src/ui/macos/EpubWindowController.mm:13, 35, 174`

Retaining `self` to keep the controller alive is non-obvious. A cleaner approach: have `AppDelegate` keep an `NSMutableArray<EpubWindowController*>` of open windows and remove on `windowWillClose:`.

---

### #19 — Missing `webp` MIME type in EpubSchemeHandler
**File:** `src/ui/macos/EpubSchemeHandler.mm:5-19`

`webp` cover images are increasingly common. Also missing: `xml`, `opf`, `ncx`.

**Fix:** Add `@"webp": @"image/webp"` and the XML types.

---

### #20 — Namespace-prefixed OPF elements silently fail to parse
**File:** `src/epub/EpubParser.cpp:64`

tinyxml2 does no namespace processing. An OPF with a non-default prefix (e.g. `<opf:manifest>`) would produce an empty spine. Rare in practice; worth a comment.

---

### #21 — Duplicate manifest IDs silently overwrite
**File:** `src/epub/EpubParser.cpp:106`

Malformed but common. Should log a warning.

---

### #22 — `StateStore::shared()` not thread-safe for concurrent windows
**File:** `src/app/StateStore.cpp:24-27`

The singleton is safely initialized (C++11), but `setPosition` / `positionForUID` mutate the map without locking. Currently safe because all calls happen on the main thread. Fragile for future work.

---

## Priority Order

| # | Issue | Action |
|---|-------|--------|
| 2 | C++ exceptions crash on bad epub | Fix now |
| 9 | nil crash on non-UTF-8 metadata | Fix now |
| 11 | Non-atomic state.json write | Fix now |
| 3 | Verify IntersectionObserver same-origin | Investigate |
| 4/5 | Percent-encoding fragment/path mismatch | Fix now |
| 7 | nil window controller not checked | Fix now |
| 8 | Empty UID collision | Fix now |
| 10 | Observer not disconnected | Fix now |
| 13 | Blank page on unmounted volume | Defer |
| 6 | `..` in epub paths | Defer |
| 15 | `<span>` TOC labels | Defer |
| 16-22 | Minor/style | Fix opportunistically |
