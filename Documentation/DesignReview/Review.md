# BookTrace — Reading experience review

## Direction

BookTrace is a personal reading journal: find a book, give it a place on a shelf, make time for it, and see the reading accumulate. The interface uses warm paper, forest green, restrained serif headings, real book covers, and quiet language. It keeps the existing SwiftUI / Observation / NavigatorUI / SwiftData architecture and the AVFoundation scanner wrapped in `UIViewControllerRepresentable`.

## Project review

- App composition: repositories and services are resolved by `AppDependencies`; view models remain injected through `ViewModelFactory`. Each tab retains its own navigation stack.
- Discovery: the bundled shelf snapshot, separate metadata cache, Open Library / Google Books routing, request throttle, and daily budget remain the source of book data. No invented ratings, recommendations, or reading activity were introduced.
- Personal library: existing SwiftData models, identifiers, categories, reading status, ownership and progress rules remain in use. Grouping, sorting, search, confirmed removal, and manual progress updates remain available.
- Reading: elapsed time still comes from dates, so backgrounding and pause / resume continue to work. Saved sessions still advance domain progress and refresh the library and journal through the existing change notifier.
- Settings and recovery: language and appearance remain immediate, cache clearing remains separate from library deletion, and storage recovery still offers retry and confirmed reset.

## Baseline capture and critique

Captured from the running app on iPhone 17 Pro, iOS 26.5, before implementation.

1. **Library:** the same book appeared in both Now Reading and the status section. The primary action required opening a detail screen. The screen's grouped controls were visually stronger than the book itself.
2. **Explore:** narrow covers and two-line titles cut off meaningful book names. Six similar shelves had little hierarchy. Browsing a specific subject required scrolling past unrelated content.
3. **Book details:** metadata and subjects preceded the story; the add action scrolled away. Long descriptions and small covers made the page feel like a record rather than a book.
4. **Add to library:** the save action sat below a long category list and was absent from the first viewport. Optional organization work competed with the essential decision to save the book.
5. **Profile:** useful statistics were presented as a series of identical cards, without a time-based view of reading activity.

Baseline evidence: [Library](before-library.png), [Explore](before-explore.png), [Book details](before-detail.png), [Add to library](before-add-book.png), [Profile](before-profile.png).

## Changes and self-review

### First implementation pass

- Added shared semantic appearance colors, typography, section headings, search fields, filter chips, cards, and primary / secondary button styles.
- Made Now Reading an actionable book card with progress and a direct Continue reading button. Omitted duplicate reading rows when the card is present; category and ownership grouping use complete sections instead.
- Added status filters that combine with existing search and sort. Empty search / filter states explain how to recover.
- Added a subject switcher, an editorial featured book selected from the actual shelf, and wider three-line book cells.
- Gave book details a centered cover and a fixed bottom action; moved optional tags into a disclosure in the editor.
- Made library details editable through the same form, including the previously awkward missing-page-count case. Invalid zero / negative page counts are rejected with an explanation.
- Created a focus screen with book identity, an accessible timer, pause / resume, and finish actions.
- Turned Profile into Journal with real total time, book counts, seven calendar days of activity, personal pace, and recent sessions. Zero-activity days remain visibly empty.

### Screenshot feedback and corrections

- **iPhone SE timer:** the first layout placed part of the timer behind the fixed controls. The focus screen now uses the actual available height to reduce the cover and spacing on compact screens. A second simulator pass confirmed that the complete timer, Pause, and Finish reading fit together. Decorative artwork is omitted at accessibility text sizes to prioritize the timer.
- **Cover loading:** an uncached cover briefly adopted the placeholder text's wide aspect ratio. The loading / failure placeholder now receives the cover's explicit dimensions.

- **First dark library:** the forest / sage surfaces separated the book and the main action well. The long horizontal information row was vulnerable at accessibility sizes. It now falls back to vertical layout, as do the book cards and status / ownership controls.
- **First finish screen with software keyboard:** the large introductory block pushed the page field and projected progress into the fixed action area. While editing, the introduction now becomes a compact title / duration row. Save remains above the keyboard.
- **Form focus:** page-count and category fields now share an explicit focus enum so Done dismisses either keyboard.
- **Long subjects:** the wrapping layout now measures each tag against the available width, allowing long source text to wrap rather than overflow.
- **Short descriptions:** descriptions below the expand / collapse threshold are never line-clipped.
- **Contrast:** the first light sage card gave secondary text only 4.11:1 contrast. The secondary ink was darkened; the final light sage pairing exceeds 4.5:1. Filter counts no longer reduce text opacity.
- **Group changes:** hiding duplicate Now Reading rows is limited to the default shelf presentation; tag and ownership groupings expose all their books.

## Accessibility and localization

- Native navigation, menus, sheets, forms and text fields remain in place.
- Primary actions are at least 54 pt tall; filters and icon actions have 44 pt touch targets.
- Dynamic Type drives text and list-cover sizes. Accessibility text sizes switch constrained horizontal book layouts to vertical layouts.
- Progress has a spoken percentage. Chart columns expose the full calendar date and actual reading duration. Decorative covers and symbols are hidden from VoiceOver to avoid repeated titles.
- Timer transitions respect Reduce Motion. The interface contains no looping decorative animation.
- New copy is translated into English, Turkish and German. Existing user edits to the original string catalog are preserved separately from this change.
- Visual and accessibility-tree inspection do not substitute for a complete VoiceOver audit on a physical device. Camera scanning requires real camera hardware.

## Verification

- Models: 50 tests passed.
- NetworkKit: 6 tests passed.
- App: 101 tests passed, including added checks for combined status / search filtering, complete category grouping, invalid page counts, and seven-day activity with a non-UTC calendar.
- Debug and optimized Release simulator builds succeeded.
- iPhone 17 Pro, iOS 26.5: light / dark appearance, Turkish language changes, accessibility-large text, discovery filters, live search, book details, library editor, pause / finish, and camera-unavailable recovery.
- iPhone SE (2nd generation), iOS 18.4: empty library, first-book discovery, saving a book, library refresh, starting a session, and saving 5 pages with the software keyboard visible. The resulting book changed from To Read to Reading and showed 5 / 246 pages (2%), including after relaunch. The final compact timer layout was checked again after rebuilding. Test content was created in this separate simulator; the original iPhone 17 Pro library was not modified.
- Final captures use the running app, not generated mockups. Some show native iOS 26 floating tabs; the iOS 18 screenshots show the standard bottom tab bar.

## Final screenshots

| Screen | Evidence |
| --- | --- |
| Library, light | [Screenshot](library-light.png) |
| Library, dark | [Screenshot](library-dark.png) |
| Explore, light | [Screenshot](explore-light.png) |
| Live search | [Screenshot](search-light.png) |
| Book details | [Screenshot](book-detail-light.png) |
| Add to library | [Screenshot](add-book-light.png) |
| Journal | [Screenshot](journal-light.png) |
| First launch, iPhone SE | [Screenshot](empty-iphone-se.png) |
| Reading timer, iPhone SE | [Screenshot](reading-iphone-se.png) |
| Session completion with keyboard, iPhone SE | [Screenshot](finish-keyboard-iphone-se.png) |
| Turkish with accessibility-large text | [Screenshot](accessibility-turkish.png) |
