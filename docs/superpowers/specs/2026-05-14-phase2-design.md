# ureader Phase 2 Design

**Date:** 2026-05-14  
**Status:** Approved

## Scope

Four independent sub-projects:

| Sub-project | Type | Needs spec? |
|---|---|---|
| A — TOC subsection navigation | Functional bug fix + feature | Yes (this doc) |
| B — XCTest UI end-to-end tests | Non-functional | Separate spec (pending Xcode install) |
| C — Third-party CMake refactoring | Non-functional | No — mechanical |
| D — Comprehensive code review + fixes | Maintenance | No — execution |

---

## Sub-project A: TOC Subsection Navigation

### Problem

Three bugs, one root cause:

1. **Fragment lost during parsing.** `TocEntry` has no `fragment` field. `stripFragment()` discards the `#anchor` from NCX `src` and nav `href` attributes during spine index lookup, and the anchor is never stored anywhere.

2. **Fragment absent from navigation URL.** `urlForSpineIndex:` builds `epub://book/OEBPS/chapter.xhtml` — the fragment is gone before it gets here, so the iframe loads the chapter but doesn't scroll to the section.

3. **Wrong TOC item highlighted.** The sidebar marks every TOC entry whose `spineIndex` matches the loaded chapter. Multiple subsection entries for the same chapter all light up. Active state should track which specific entry is current.

4. **Scroll doesn't update active entry.** As the user reads down through a long chapter, the sidebar should track which subsection is in view.

---

### Data model changes

**`TocEntry`** gains one field:

```cpp
struct TocEntry {
    std::string title;
    int spineIndex;
    int depth;
    std::string fragment;   // anchor id, e.g. "section-1" (empty if none)
};
```

**`EpubParser`** — stop discarding fragments:

- In `parseTocNcxElement`: split `src` on `#`, store the path part for spine lookup, store the fragment part in `TocEntry.fragment`.
- In `parseNavOl`: same for `href`.
- `spineIndexFor()` continues to use `stripFragment()` — the lookup uses paths only.

---

### Same-origin fix

The shell is loaded with `baseURL: epub://ureader/shell`. Chapter content loads at `epub://book/…`. Different hosts = cross-origin = the shell's JavaScript cannot access `iframe.contentDocument`.

**Fix:** Change the shell's `baseURL` to `epub://book/shell`. Shell and all chapter content share origin `epub://book`. The `EpubSchemeHandler` already ignores the host component, so no handler changes are needed.

This is required for the IntersectionObserver injection to work.

---

### Navigation state

`EpubWindowController` gains a second index:

```
_currentSpineIndex   — which spine item is loaded (was _currentIndex)
_activeTocIndex      — which TOC entry is highlighted (-1 if none)
```

**Prev/Next navigation** (`navigate:`) sets `_currentSpineIndex` and sets `_activeTocIndex` to the first TOC entry whose `spineIndex` matches — i.e. it lands at the top of the chapter.

**TOC entry click** (`jumpToTocEntryIndex:`) sets both: `_currentSpineIndex = toc[i].spineIndex`, `_activeTocIndex = i`. The URL includes the fragment: `epub://book/OEBPS/chapter.xhtml#section-1`.

**Scroll** (reported from iframe via `window.parent.setActiveTocIndex(i)`) updates only `_activeTocIndex`.

**State persistence** continues to save and restore `_currentSpineIndex` (spine-level granularity). Restoring always lands at the top of the chapter.

---

### Bridge payload changes

**`loadBook` (ObjC → JS)** — add `activeTocIndex`, replace `currentUrl` logic:

```json
{
  "title": "…",
  "author": "…",
  "toc": [{"title": "…", "spineIndex": 0, "depth": 0}],
  "spineCount": 9,
  "currentIndex": 2,
  "currentUrl": "epub://book/OEBPS/chapter3.xhtml",
  "activeTocIndex": 5,
  "tocAnchors": [
    {"id": "section-1", "tocIndex": 5},
    {"id": "section-2", "tocIndex": 6}
  ]
}
```

**`navigateTo` (ObjC → JS)** — add `activeTocIndex` and `tocAnchors`:

```json
{
  "spineIndex": 2,
  "url": "epub://book/OEBPS/chapter3.xhtml#section-1",
  "activeTocIndex": 5,
  "tocAnchors": [
    {"id": "section-1", "tocIndex": 5},
    {"id": "section-2", "tocIndex": 6}
  ]
}
```

`tocAnchors` contains only entries for the current spine item that have a non-empty fragment.

**JS → ObjC bridge** — `jumpTo` now sends `tocEntryIndex` (not `spineIndex`):

```js
window.webkit.messageHandlers.bridge.postMessage(
  { action: 'jumpTo', tocEntryIndex: N });
```

---

### Shell HTML changes

**`navigateTo(data)`:**
1. Set `iframe.src = data.url` (includes fragment if any)
2. Update position indicator and prev/next disabled state
3. Call `setActiveTocIndex(data.activeTocIndex)`
4. If `data.tocAnchors.length > 0`, set `iframe.onload` to inject the observer

**`setActiveTocIndex(i)`** (new, also exposed on `window` for iframe to call):
- Removes `active` class from all TOC items
- Adds `active` class to item at index `i` (no-op if `i === -1`)

**Observer injection (called from `iframe.onload`):**
```js
function injectObserver(iframe, tocAnchors) {
  var doc = iframe.contentDocument;
  var targets = tocAnchors
    .map(function(a) { return { el: doc.getElementById(a.id), tocIndex: a.tocIndex }; })
    .filter(function(a) { return a.el; });
  if (!targets.length) return;

  var observer = new IntersectionObserver(function(entries) {
    var visible = entries
      .filter(function(e) { return e.isIntersecting; })
      .sort(function(a, b) { return a.boundingClientRect.top - b.boundingClientRect.top; });
    if (visible.length > 0) {
      var match = targets.find(function(a) { return a.el === visible[0].target; });
      if (match) window.setActiveTocIndex(match.tocIndex);
    }
  }, { threshold: 0.1 });

  targets.forEach(function(a) { observer.observe(a.el); });
}
```

`window.setActiveTocIndex` is the shell's `setActiveTocIndex` function — accessible because the iframe and shell are now same-origin.

---

### Files changed

| File | Change |
|---|---|
| `src/epub/EpubBook.h` | Add `fragment` to `TocEntry` |
| `src/epub/EpubParser.cpp` | Store fragment in `parseTocNcxElement`, `parseNavOl` |
| `src/ui/macos/EpubWindowController.h` | Replace `jumpToSpineIndex:` with `jumpToTocEntryIndex:` |
| `src/ui/macos/EpubWindowController.mm` | `_activeTocIndex` state; `urlForTocEntryIndex:`; `tocAnchorsForSpineIndex:`; `firstTocIndexForSpineIndex:`; baseURL fix |
| `src/ui/macos/BridgeMessageHandler.mm` | Handle `jumpTo` with `tocEntryIndex` |
| `resources/shell.html` | `setActiveTocIndex`, observer injection, updated `navigateTo` and `loadBook` |
| `src/epub/tests/test_epub_parser.cpp` | Add fragment assertions to TOC tests |
| `src/epub/fixtures/create_fixtures.sh` | Add subsection anchors to fixture chapters and NCX |

---

## Sub-project C: Third-party CMake Refactoring

Move vendored library compilation out of `src/epub/CMakeLists.txt` and into `third_party/CMakeLists.txt`. Each library becomes an independent CMake target.

**`third_party/CMakeLists.txt`:**
```cmake
add_library(miniz STATIC miniz.c)
target_include_directories(miniz PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_library(tinyxml2 STATIC tinyxml2.cpp)
target_include_directories(tinyxml2 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
```

**Root `CMakeLists.txt`:** add `add_subdirectory(third_party)` before `add_subdirectory(src/epub)`.

**`src/epub/CMakeLists.txt`:** remove `tinyxml2.cpp` and `miniz.c` from `epub` sources; replace `target_include_directories` for `third_party` with `target_link_libraries(epub PUBLIC miniz tinyxml2)`.

No behaviour change — same compilation, cleaner dependency graph.

---

## Sub-project D: Code Review

A full pass over the codebase looking for:
- Memory management issues (C++ ownership, ObjC ARC correctness)
- Error paths not handled (e.g. nil `shellPath`, empty `html` string in `EpubWindowController`)
- Correctness issues in `EpubParser` (malformed OPF edge cases, NCX without navMap)
- `StateStore` load parser correctness (escaped keys, numbers > 9)
- `EpubSchemeHandler` correctness (URL path decoding, percent-encoded characters)
- `shell.html` JS correctness (`onload` overwritten on fast navigation, observer not disconnected on chapter change)

Findings become fixes, each committed separately.
