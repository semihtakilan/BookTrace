# Library and Discover refinement

This pass responds to the requested reading-first library, incorrect completed-book progress, richer discovery, and more consistent book proportions.

## Library and progress

The active reading section is now independent of the lower shelf. Reading books remain at the top while searching, sorting, filtering, or grouping the lower shelf. The lower shelf excludes reading books and defaults to To Read, Finished, Wishlist, and Abandoned sections, in that order. Its counts and filters describe only those books.

The completed-book bug came from saving `readingStatus = .finished` before applying the page count. Applying the count reconciled the still-zero progress and changed the status back to Reading. Completion now has a shared domain operation: the known edition length becomes the current page, without generating fictional sessions or reading time. The form applies this explicit status selection after its page-count calculation. The library detail status picker uses the same operation.

A finished record with a known length also normalizes on loading, covering older Finished / zero-page records. If the earlier bug already stored a book as Reading, its intended status cannot be inferred safely; selecting Finished again completes it. Unknown page counts remain unknown; adding a length later completes a finished book correctly.

## Discover direction and screenshot feedback

1. [Starting screen](01-discover-before.png): a single arbitrary feature and six repeated shelves gave browsing little structure. The tilted cover also made proportion comparisons harder.
2. [New discovery entrance](04-discover-light.png): a compact title and search lead into a horizontal selection from different subjects. The visible next card signals more books. The shuffle action opens an actual loaded book, with no additional request or invented recommendation claim.
3. [Topics and shorter books](05-discover-collections.png): six distinct topic cards lead to complete collections. A separate short-book selection uses known lengths of 1–250 pages and removes duplicate book IDs across subjects. Repeated subject shelves on the home screen are reduced to two previews with See all actions.
4. [Light collection](03-subject-light.png) and [dark collection](02-subject-dark.png): two columns provide a complete shelf. Covers retain their original aspect ratio within consistent, unrotated display areas. Title and author rows reserve the same space at normal text sizes, so adjacent books align. Source images are fitted rather than stretched or cropped.
5. Navigation feedback: the first collection implementation mixed native item navigation with the existing NavigatorUI path. Book details then replaced the selected collection. Collections now use the same navigation path and the same loaded view model; opening a book and going back retains the subject.
6. [iPhone SE](06-discover-iphone-se.png): the feature card adapts to the narrower width while preserving cover proportions and keeping its action inside the card.
7. [Accessibility text](10-accessibility-subject.png): the collection switches to one column and removes title/author line limits. Topic tiles also switch to one column; feature cards stack their content vertically.

## Real simulator flow

The original iPhone 17 Pro library was left untouched. Two additional test books were added to the existing iPhone SE test library through the real interface.

1. Open The Caves of Steel, choose Finished in Add to Library, and save without entering a custom length. The resulting detail shows [259 / 259 pages and Finished](07-finished-progress.png). Opening the manual progress dialog also shows 259. No reading session was generated.
2. Relaunch the app. The completed book still appears under Finished with 259 / 259 pages.
3. Add Frankenstein as To Read. The [upper section](09-library-reading-first.png) keeps the existing Dorian Gray session at 5 / 246 pages. The [lower shelf](08-library-other-statuses.png) lists Frankenstein under To Read and The Caves of Steel under Finished.
4. Select To Read and then All. Only the lower shelf changes; Dorian Gray remains in the active reading section.

## Validation

- 53 Models tests passed, including known / unknown lengths, explicit completion, and editing the completed edition length.
- 106 application tests passed, including add-as-finished with source and custom lengths, preserving actual sessions, older finished records, and reading-first grouping / filtering.
- Debug and optimized Release simulator builds succeeded.
- Tested iPhone 17 Pro (iOS 26.5) and iPhone SE 2 (iOS 18.4), light / dark appearance and accessibility-large Dynamic Type. Temporary main-simulator appearance and text-size changes were restored.
- Added 14 English, Turkish and German strings. Earlier user edits in the catalog remain unchanged and outside the commit.
- These captures verify layout and the exercised interactions; they are not a complete physical-device VoiceOver audit. Camera code was unchanged in this pass.
