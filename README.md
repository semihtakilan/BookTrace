# BookTrace

BookTrace is a native iOS app for discovering books, organizing a personal library, and tracking reading time and progress. Find books through Open Library and Google Books, keep your reading list on your device, and turn reading sessions into a record of your activity and pace.

Built with **SwiftUI**, **SwiftData**, and local **Swift packages**, the project uses MVVM and repository abstractions to keep presentation, persistence, networking, and domain logic separate.

## Contents

- [Features](#features)
- [Reading experience](#reading-experience)
- [Technology stack](#technology-stack)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Book data sources](#book-data-sources)
- [Google Books API configuration](#google-books-api-configuration)
- [Using BookTrace](#using-booktrace)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Reading progress and estimates](#reading-progress-and-estimates)
- [Storage and offline behavior](#storage-and-offline-behavior)
- [Localization and appearance](#localization-and-appearance)
- [Build and test](#build-and-test)
- [Troubleshooting](#troubleshooting)
- [Project status and roadmap](#project-status-and-roadmap)

## Features

### Book discovery

- Search Open Library by title, author, or other search terms, with Google Books as a fallback. Search waits 500 ms after typing to reduce unnecessary requests.
- Browse six featured shelves: Fiction, Science Fiction, History, Philosophy, Technology, and Biography.
- Scan book barcodes with the device camera and look up the corresponding ISBN.
- View book descriptions, authors, covers, subjects, page counts, publication dates, and ISBNs when available.
- Retry individual shelves when a request fails; each shelf loads independently.
- Show cached results immediately, with separate refresh and expiry windows for searches, subject shelves, and ISBN lookups.
- Load missing descriptions on demand, share concurrent requests for the same book, and reuse enriched metadata on later visits.

### Personal library

- Organize books by reading status: **Wishlist**, **To Read**, **Reading**, **Finished**, or **Abandoned**.
- Track ownership as **Borrowed**, **Not Owned**, or **Owned**.
- Add custom categories or choose suggestions from existing tags and the book's subjects.
- Set a page count and choose progress entry in pages or percentages.
- Search and filter **All Books**, including titles currently being read; use **Now Reading** to resume the most recently read books.
- Update existing library details while preserving reading progress and saved sessions.
- Remove individual books or erase the library from Settings.

### Reading sessions

- Start a full-screen timer from a book in your library.
- Pause and resume, then finish by recording the number of pages read.
- Save the session to advance progress and update the reading status when appropriate.
- Review a book's session history and accumulated reading time.
- Get a remaining-time estimate that adapts to the sessions recorded for that book.

Reading Mode tracks time spent reading a book outside the app; BookTrace does not currently include an EPUB or PDF reader.

### Journal and settings

- View library totals, books in progress, and finished books.
- Review total reading time, recorded pages, session counts, reading pace, and the current reading streak.
- See the last seven days of reading activity in Library; a streak ending yesterday remains active until today ends.
- Select a day in the activity chart to inspect its totals and sessions; browse the complete reading history by date and open any session’s book.
- Inspect reading-status and ownership breakdowns and the five most recent sessions.
- Choose System, Light, or Dark appearance.
- Switch between the system language, English, Turkish, and German.
- Set the default reading status and progress type for newly added books.
- Clear the search cache independently of the personal library.

## Reading experience

The interface uses a shared paper-and-ink design system with light and dark appearances, Dynamic Type, and English, Turkish, and German copy. Library’s **All Books** search, sorting, grouping, and status filters include every saved book, while **Now Reading** provides quick access to recently read titles. Adding a finished book completes its known page count. Discover offers subject spotlights, topic collections, a short-book shelf, and proportional cover grids. Book editing and session completion keep their save actions above the keyboard.

Book covers supply the color palette, while subjects and titles select one of ten visual atmospheres for details and Reading Mode. Ambient motion respects Reduce Motion and Low Power Mode. Session completion includes a page dial, keyboard entry, and projected progress, with brief celebrations for the first reading session, progress milestones, and finishing a book.

Journal combines reading time and personal pace with selectable daily activity and a complete session history that links back to each book.

See the [latest simulator design review](Documentation/DesignReview/Iteration4/Review.md) for the findings, screenshots, changes, and validation evidence.

## Technology stack

| Area | Technology | Role |
| --- | --- | --- |
| Interface | SwiftUI | Screens, forms, navigation presentation, and shared components |
| State | Observation | Observable view models and shared application settings |
| Persistence | SwiftData | Library entries, categories, and saved reading sessions |
| Networking | Foundation / URLSession | Asynchronous requests through the local `NetworkKit` package |
| Dependency injection | [FactoryKit](https://github.com/hmlongco/Factory) | Service registration and dependency composition |
| Navigation | [NavigatorUI](https://github.com/hmlongco/Navigator) | Independent navigation stacks for each tab |
| Cover images | [Kingfisher](https://github.com/onevcat/Kingfisher) | Remote image loading and caching |
| Barcode scanning | AVFoundation | Camera access and barcode capture |
| Localization | String Catalogs | English, Turkish, and German interface strings |
| Testing | Swift Testing | Domain, cache behavior, and endpoint tests |

Dependencies are managed through Swift Package Manager. The committed Xcode [dependency resolution](BookTrace.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) records Factory **3.3.2**, Navigator **2.1.3**, and Kingfisher **8.11.0**.

## Requirements

| Requirement | Details |
| --- | --- |
| Development environment | macOS with Xcode 26.x and a Swift 6.2 or newer toolchain |
| Deployment target | iOS 17.6 or later; the app currently targets iPhone |
| Book discovery | Internet access for uncached requests; a Google Books API key is optional for the primary Open Library flow |
| Barcode scanning | A physical device with an available camera and camera permission |

The app target uses Swift 6 language mode, while the local packages use Swift 6 tools. In particular, `Models/Package.swift` requires Swift tools version 6.2. The app and project deployment settings both specify iOS 17.6.

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/semihtakilan/BookTrace.git
   cd BookTrace
   ```

2. Open the Xcode project:

   ```bash
   open BookTrace.xcodeproj
   ```

3. Allow Xcode to resolve Swift package dependencies. Keep `Models`, `NetworkKit`, and `NetworkRegistration` beside the app project; they are local package dependencies.
4. Optionally configure `GOOGLE_BOOKS_API_KEY` using the [steps below](#google-books-api-configuration) to enable Google Books fallback and enrichment.
5. Select the **BookTrace** scheme and an iOS Simulator or connected device.
6. For a physical device, select your development team under **Signing & Capabilities** and adjust the bundle identifier if needed for your signing setup.
7. Run the app with **Command-R**.

You can explore the Library, Discover, and Journal flows in the Simulator. Use a physical device to exercise camera scanning.

## Book data sources

BookTrace uses Open Library for discovery and Google Books for fallback and missing metadata. The routing policy limits Google Books usage through a persisted budget on each device. That local budget is separate from the Google Cloud project quota shared by installations using the same credentials.

**Breadth comes from Open Library, depth from Google Books.**

| Flow | Primary | Fallback | Why |
| --- | --- | --- | --- |
| Discover shelves | Bundled snapshot, then Open Library | Google Books when Open Library is empty or fails | Show bundled books immediately, then refresh in the background |
| Text search | Open Library | Google Books when the search is empty or fails | Keep routine discovery on the primary source |
| Book detail | Cached description, then the book's own catalogue | For Open Library books, Google Books starts after 800 ms or an earlier empty/error response | Return the first usable description within the available budget |
| Barcode / ISBN | Open Library edition record | Google Books | Edition records carry the printing the user scanned |

The app uses public book metadata and keeps its personal library locally. It requires no sign-in to either service.

Text search displays up to 20 results and each subject shelf up to 15. Open Library shelf requests fetch up to 30 candidates to prefer books with covers. Barcode lookup returns one book and may make an additional search to resolve an edition or its author. Discovery displays a single batch per query; pagination is not implemented.

### Open Library

```text
GET https://openlibrary.org/search.json      # search and subject shelves
GET https://openlibrary.org/works/{id}.json  # description and subjects
GET https://openlibrary.org/isbn/{isbn}.json # edition record for a scanned barcode
```

No key is required. Requests carry a `User-Agent` naming the app and a contact address. The app’s `RequestThrottle` spaces Open Library operations by at least 340 ms.

List requests ask for a narrow `fields` set without edition-wide ISBN arrays. Cover images use cover IDs (`/b/id/{id}-M.jpg`). ISBN lookup uses edition records and can fall back to an ISBN search.

### Google Books

```text
GET https://www.googleapis.com/books/v1/volumes      # search, subject shelves, ISBN
GET https://www.googleapis.com/books/v1/volumes/{id} # one volume, for enrichment
```

The hybrid router checks `DailyRequestBudget` before starting a Google Books operation: the default allowance is 25 operations per device per calendar day, with a one-hour suspension after a quota error. This counts routing attempts rather than individual transport retries. Exhausting the budget skips Google Books; cached data and successful Open Library results remain usable, while unresolved lookups can still return an empty result or an error.

### Detail loading

Known descriptions are shown without a new request. For an Open Library book with a missing description, Open Library gets an 800 ms head start; Google Books can then join within the daily budget. The first usable description wins and the remaining request is cancelled. Google Books records use their own volume endpoint directly.

Detail endpoints use a six-second timeout and one transport attempt. The combined operation has an eight-second deadline, including the Open Library queue. Concurrent callers for the same book share one operation; leaving one screen cancels only that caller, and leaving the last one cancels the network work. Successful results without a description have a 30-second in-memory retry delay. Errors and cancellations do not enter that delay.

The detail screen distinguishes loading, unavailable descriptions, and failures with a retry action. See the [detail-loading performance review](Documentation/PerformanceReview/HybridDetails/Review.md) for implementation evidence and previous validation results.

### Shelf snapshot

Discover's six subject shelves have a bundled snapshot in `BookTrace/Resources/ShelfSeed.json`. A first launch can display those books without waiting for a network request, including offline. The cache treats the snapshot as stale, so it refreshes in the background on first use. Regenerate it with:

```bash
python3 Scripts/generate_shelf_seed.py
```

The script's field mapping mirrors `OpenLibraryDocument.toDomain()`; `ShelfSeedTests` fails if the two drift apart.

## Google Books API configuration

### Create an API key

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and create or select a project.
2. Under **APIs & Services → Library**, enable **Books API**.
3. Open **APIs & Services → Credentials → Create credentials → API key**.
4. Limit the key's API access to Books API and review the project's quota settings.

Google documents API keys as an application identifier for public-data requests. See the [Google Books API guide](https://developers.google.com/books/docs/v1/using) for credential requirements. Configure your own key for Google Books fallback and enrichment. Open Library discovery works without it; the client may still attempt Google Books requests without a key, which can fail with access or quota errors.

### Supply the key through `Config/Secrets.xcconfig`

The project is wired to read the key from a build configuration file that Git ignores. Create it once per checkout:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Open the copy and replace the placeholder with your key:

```xcconfig
GOOGLE_BOOKS_API_KEY = YOUR_GOOGLE_BOOKS_API_KEY
```

`Config/Secrets.xcconfig` is listed in `.gitignore`, so it never travels with a commit, a clone, or a merge. It also has no entry in the Xcode project navigator by design; the build reads it from disk.

The key reaches the app through this chain:

```text
Config/Secrets.xcconfig    Git-ignored, holds the real key
    |  #include?           Skipped silently when the file is absent
Config/Shared.xcconfig     Base configuration of the app target (Debug and Release)
    |  $(GOOGLE_BOOKS_API_KEY)
Config/Info.plist          INFOPLIST_FILE; Xcode merges its generated entries on top
    |  Bundle.main.object(forInfoDictionaryKey:)
GoogleBooksAPIKey.value
```

Because `#include?` tolerates a missing file, a fresh clone builds and runs without a key. Open Library discovery and bundled shelves remain available; Google Books fallback may fail.

To check configuration, run from Xcode and inspect whether `GoogleBooksAPIKey.value` is non-nil in the debugger. Avoid printing the key into shared build logs.

### Restrict the key before distributing

**A key inside an iOS binary is not a secret.** Anyone who downloads the app can read it out of `Info.plist`, and obfuscation does not change that. What protects the key is the restriction configured in Google Cloud:

- **Application restrictions → iOS apps** → add the bundle identifier `com.semihtakilan.BookTrace`. The app sends an `X-Ios-Bundle-Identifier` header on every request, which is what Google matches against this list.
- **API restrictions → Restrict key** → select **Books API** only, so a leaked key cannot bill any other Google service.

See Google’s [API key restriction guide](https://docs.cloud.google.com/api-keys/docs/add-restrictions-api-keys). A backend proxy could keep the key off devices and enforce centralized request limits; the current app calls the catalogues directly.

### Continuous integration

`Config/Secrets.xcconfig` is not in the repository. CI only needs to create it when a build should include Google Books credentials; compilation and mock-based tests need no key. Store the key as a CI secret and generate the file:

```bash
printf 'GOOGLE_BOOKS_API_KEY = %s\n' "$GOOGLE_BOOKS_API_KEY" > Config/Secrets.xcconfig
```

### Scheme environment variable (development only)

To try a different key without touching the file, add `GOOGLE_BOOKS_API_KEY` under **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**. The environment value takes precedence over the bundled one.

This applies only to launches started by Xcode. An archived or installed app never receives it, so distribution always depends on the xcconfig path above.

### Configuration behavior

- A process environment value takes precedence over the bundled value.
- Whitespace is trimmed. An empty value or an unresolved `$(...)` placeholder is treated as a missing key.
- `.env` files are not loaded by the app.
- Requests include a `country` value from `Locale.current.region`, with `US` as the fallback. This follows the device region, independently of the app's selected interface language.
- The network logger can include the API key in request URLs. Remove the `key` query value before sharing logs.
- Without a key the app still runs: Open Library is the primary source. A failed Google Books fallback does not guarantee that the lookup can be resolved.
- Debug builds show the day's Google Books request count under **Journal → Settings → About**.

## Using BookTrace

1. Open **Discover** and search for a book, browse a subject shelf, or scan a barcode.
2. Open the book's details and choose **Add to Library**.
3. Set the reading status, ownership, page count, progress type, and categories, then save.
4. Open **Library** and select the book. Use **Update progress** for a manual update or **Reading Mode** to time a session.
5. In Reading Mode, choose **Finish**, enter the number of pages read, and select **Save Session**.
6. Visit **Journal** to review activity and open the gear button for Settings.

When you encounter a book that is already saved, **Update Library Details** edits its existing entry. Library identity uses the source-prefixed book ID (`gb:` or `ol:`). Legacy Google Books IDs are migrated at launch. Different editions or records from different catalogues can remain separate library entries; metadata matching during enrichment does not automatically merge saved entries.

## Architecture

BookTrace follows **MVVM with repository abstractions**. Views observe view models, and view models depend on domain protocols. Concrete services and persistence are assembled at the application boundary.

```mermaid
flowchart TD
    Views[SwiftUI views] --> ViewModels[Observable view models]
    ViewModels --> Search[BookSearching / BookDetailFetching]
    ViewModels --> Library[LibraryRepository]
    Search --> Cached[CachedBookSearching<br/>serves stale, refreshes behind]
    Cached --> Store[SwiftDataBookCacheStore]
    Store --> Seed[ShelfSeed.json<br/>answers a cold cache]
    Cached --> Hybrid[HybridBookSearching<br/>routing policy]
    Hybrid --> OpenLibrary[OpenLibraryService<br/>throttled, no key]
    Hybrid --> Budget[DailyRequestBudget<br/>cap + circuit breaker]
    Budget --> Google[GoogleBooksService]
    OpenLibrary --> Network[NetworkKit / URLSession]
    Google --> Network
    Library --> Repository[LocalLibraryRepositoryImpl]
    Repository --> Persistence[SwiftData]
```

Each layer answers one question. `CachedBookSearching` asks whether the answer is already on the device; `HybridBookSearching` asks which catalogue should answer; `DailyRequestBudget` asks whether the expensive one may be asked at all. View models see none of this — they depend on the `BookSearching` and `BookDetailFetching` protocols.

### Local packages

| Package | Responsibility |
| --- | --- |
| [Models](Models) | Domain values, repository protocols, progress rules, reading-speed estimates, and the source-routing and caching decorators; independent of SwiftUI, SwiftData, and both catalogues |
| [NetworkKit](NetworkKit) | Typed endpoints, the `NetworkService` actor, HTTP request construction, request/response interceptors, logging, and retries for eligible failures |
| [NetworkRegistration](NetworkRegistration) | Factory registrations for networking configuration, the environment manager, and request/response interceptors |

### Key implementation choices

- **Composition root:** `AppDependencies` creates the SwiftData container and connects the concrete repository to Factory registrations.
- **View model creation:** `ViewModelFactory` supplies dependencies to navigation destinations through the SwiftUI environment.
- **Portable models:** `BookReference` carries catalogue metadata; `LibraryEntry` adds the user's state. SwiftData models convert to and from these domain values.
- **Source-tagged identity:** book ids carry their catalogue (`gb:zyTCAlFPjgYC`, `ol:/works/OL166894W`), so two catalogues cannot collide on one string. An id with no prefix is read as Google Books, which is how entries saved before the second source was added keep working. `BookReference.matchingKey` — ISBN when known, otherwise title, author and year — is what lets the two catalogues agree on a book.
- **Field-level merging:** a book gathers data as it travels from a shelf to a detail screen to the library. `merging` never lets an empty value overwrite a known one, so the poorer record arriving second cannot erase the richer one.
- **Tab navigation:** Library, Discover, and Journal each have their own Navigator instance. Their internal feature names remain `Books`, `Explore`, and `Profile`.
- **Data refresh:** `LibraryChangeNotifier` publishes a revision after successful writes so library details, shelves, and profile statistics refresh after changes.
- **Error presentation:** `UserFacingError` maps service and persistence errors into localized messages and suppresses cancellation errors.

## Project structure

```text
BookTrace/
├── BookTrace/
│   ├── App/                         # App entry point, root views, and tab routing
│   ├── Core/
│   │   ├── DI/                      # Registrations and dependency composition
│   │   ├── ErrorPresentation/       # User-facing error mapping
│   │   ├── Settings/                # Persisted theme, language, and defaults
│   │   └── ViewState/               # Loading, success, and failure state
│   ├── Data/
│   │   ├── Caching/                 # Search-result disk cache
│   │   ├── Network/                 # Open Library and Google Books endpoints and response mapping
│   │   ├── Persistence/             # SwiftData models and library repository
│   │   └── Services/                # Book lookup and API-key resolution
│   ├── Domain/Repositories/         # App-facing repository protocol aliases
│   ├── Presentation/
│   │   ├── Features/
│   │   │   ├── Books/               # Library, book progress, and reading sessions
│   │   │   ├── Explore/             # Search, discovery, details, and scanning
│   │   │   ├── Profile/             # Journal, reading history, and settings
│   │   │   └── Splash/              # Launch screen
│   │   └── Shared/                  # Covers, rows, tags, and formatters
│   ├── Resources/ShelfSeed.json     # Bundled subject shelves
│   ├── Assets.xcassets/
│   └── Localizable.xcstrings
├── BookTrace.xcodeproj/
├── BookTraceTests/                  # App, persistence, transport, and view-model tests
├── Config/                          # Shared build settings and API-key template
├── Documentation/                   # Design and performance reviews
├── Scripts/generate_shelf_seed.py    # Refresh the bundled subject shelves
├── Models/
│   ├── Sources/Models/
│   └── Tests/ModelsTests/
├── NetworkKit/
│   ├── Sources/NetworkKit/
│   └── Tests/NetworkKitTests/
├── NetworkRegistration/
│   └── Sources/NetworkRegistration/
├── Plan.md                          # Original development plan, in Turkish
└── README.md
```

## Reading progress and estimates

### Domain model

| Type | Purpose |
| --- | --- |
| `BookReference` | A source-prefixed book ID and available metadata, including title, authors, cover URL, page count, description, ISBN, and subjects |
| `LibraryEntry` | A book plus reading status, ownership, preferred progress unit, current page, categories, and saved sessions |
| `ReadingSession` | A session ID, start date, active duration in seconds, and number of pages read |
| `Category` | A user tag with an identity derived from its normalized name |
| `ReadingSpeedEstimator` | Pure calculations for reading pace and estimated remaining time |

### Progress rules

Progress is stored as a page number. Percentage entry is converted to pages, keeping session updates and estimates in the same unit.

A positive user-supplied page count takes precedence over the count returned by the catalogue. Without a known total, the app can record pages and sessions, but percentage progress and remaining-time estimates are unavailable.

Saving a reading session adds its pages to the current position, caps that position at the known page count, moves Wishlist or To Read entries into Reading, and marks an entry Finished when the known total is reached. Manual progress changes do not create timed sessions and therefore do not contribute to recorded reading pace.

### Reading pace

Before recorded totals include both positive time and positive pages, the estimate uses **120 seconds per page**. Once measurements are available for a book:

```text
seconds per page = total recorded seconds / total recorded pages
remaining time   = remaining pages × seconds per page
```

Each book's estimate uses its own sessions. Journal statistics also calculate an overall pace across the library's saved sessions. Time estimates are omitted when the total page count is unknown or no pages remain.

The session timer measures elapsed time from timestamps and accumulated active intervals. It stays accurate when the app returns from the background and excludes paused time. The active timer is held in memory; only saved sessions survive an app relaunch.

## Storage and offline behavior

| Data | Storage | Behavior |
| --- | --- | --- |
| Library metadata, categories, and sessions | SwiftData | Persisted on the device and available without fetching book details again |
| Search, subject, and ISBN results | SwiftData store in the app's cache directory, separate from the library | Served immediately, refreshed in the background once stale: searches after a day, shelves after a week, ISBN lookups after a month |
| Books themselves | One row per book in the same store | Deduplicated across shelves and enriched in place as detail data arrives |
| Cover images | Kingfisher cache | Cached separately from search results; a generated placeholder appears while unavailable |
| Theme, language, and new-book defaults | UserDefaults | Restored on subsequent launches |

Query freshness and expiry are defined in `BookQuery`:

| Query | Background refresh after | Expires after |
| --- | --- | --- |
| Text search | 1 day | 7 days |
| Subject shelf | 7 days | 30 days |
| ISBN lookup | 30 days | 365 days |

Library management, saved progress, session recording, and Journal calculations work locally. Discover’s bundled shelves work offline on a first launch when the cache store is available. Stale results remain usable until their expiry; expired queries are removed, with bundled shelves available as a fallback for matching subjects. Uncached searches and cover images require a connection.

The cache has a separate SwiftData store in the app’s cache directory. Clearing it deletes cached query and book rows without touching the library. Startup pruning removes expired queries and keeps at most 2,000 cached books. If the cache store cannot open, discovery falls back to direct network requests.

**Clear search cache** removes the stored discovery results. It does not erase library entries, reading sessions, or Kingfisher's image cache, and already displayed results may remain in memory. **Erase library** removes all saved books, their sessions, and stored categories after confirmation.

The current implementation has no account system, cloud synchronization, or library import/export.

## Localization and appearance

Interface strings live in [BookTrace/Localizable.xcstrings](BookTrace/Localizable.xcstrings), with English as the source language and Turkish and German translations. Theme and language preferences are applied at the root view and updated through Settings.

When adding interface text, use the existing localization approach and update the string catalog. Book titles, descriptions, and source subjects remain the metadata supplied by Open Library or Google Books; the interface language setting does not translate that content.

## Build and test

Run commands from the repository root with the required Xcode toolchain selected.

### Build for the Simulator

```bash
xcodebuild \
  -project BookTrace.xcodeproj \
  -scheme BookTrace \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This builds the app without installing or launching it. No API key is needed for compilation or Open Library discovery. Google Books credentials are optional, as described above.

### Run package tests

```bash
swift test --package-path Models
swift test --package-path NetworkKit
```

The existing Swift Testing suites cover:

| Suite | Coverage |
| --- | --- |
| `LibraryEntryTests` | Defaults, page-count overrides, progress calculations, session application, and status transitions |
| `ReadingSpeedEstimatorTests` | Default pace, measured pace, and remaining-time estimates |
| `CachedBookSearchingTests` | Query caching, background refresh, shared detail requests, cancellation, and missing-description retry delays |
| `BookQueryTests` | Cache keys per query kind and the invariant that every query refreshes before it expires |
| `HybridBookSearchingTests` | Source routing, delayed detail fallback, deadlines, quota limits, and cancellation |
| `BookIdentifierTests` | Source-prefixed ids, unprefixed ids read as Google Books, and cross-catalogue matching |
| `BookReferenceMergingTests` | An empty value never overwriting a known one |
| `ReadingStreakTests`, `BookAmbienceTests` | Consecutive reading days, recent activity, and subject/title atmosphere classification |
| `CategoryTests`, `ReadingSpeedEstimatorValidationTests` | Category normalization and pace validation |
| `EndpointTests`, `NetworkServiceRetryTests` | URL construction, request encoding, endpoint overrides, retry limits, and cancellation |

The `BookTraceTests` target covers library persistence, the SwiftData cache, bundled shelves, request budgets, both catalogue decoders, detail transport limits, view models, error presentation, cover palettes, and session outcomes. Choose an installed Simulator with `xcrun simctl list devices available`, then substitute its UUID below:

```bash
xcodebuild test -project BookTrace.xcodeproj -scheme BookTrace \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  CODE_SIGNING_ALLOWED=NO
```

These tests use local values and mocks; they call neither catalogue and need no API key. Swift Package Manager may need network access to resolve dependencies before the first run. The repository currently has no app-level UI test target, and `NetworkRegistration` has no dedicated test target.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Google Books fallback displays a quota or access error | Confirm that `Config/Secrets.xcconfig` exists and defines `GOOGLE_BOOKS_API_KEY`, Books API is enabled, and the key's restrictions and project quotas allow the request. The app groups HTTP 403 and 429 into its quota message. |
| The key works from Xcode but not when launching the installed app | A scheme variable is supplied only during an Xcode launch. Configure the bundled value for other launch paths. |
| Requests return HTTP 503 | Retry, then check the device or Simulator region under **Settings → General → Language & Region → Region**, including any difference introduced by a VPN. The request uses that region; a 503 can also be a service-side failure. |
| Open Library reports that it is busy | Retry later; Google Books can help only while its local budget and credentials allow the fallback. |
| Scanning reports no camera | Use a physical device. In the Simulator, search by title or enter an `isbn:` query instead. |
| Camera access is off | Use **Open Settings** from the scanner to enable camera access for BookTrace. |
| Percentage progress or remaining time is missing | Provide a positive page count in the book's library details. |
| Discovery results have not changed | Cached results are shown first and refreshed in the background, so a change appears on the next visit. Clear the search cache in Settings and relaunch to force a reload. |
| A book description is missing | Wait for detail loading to finish. Use the retry action after a failure; an unavailable description means the completed lookup supplied none. Successful empty results are reused for 30 seconds. |
| A shelf shows the same books on a brand-new install with no connection | That is the bundled snapshot in `BookTrace/Resources/ShelfSeed.json`. It refreshes from Open Library as soon as a request succeeds. |
| Search returns nothing for a title you can find on Google Books | Open Library answers search first. Confirm the daily Google Books budget is not spent (debug builds show it under **Settings → About**) and that a fallback request is not being blocked by a quota suspension. |
| Xcode reports a missing local package | Check that all three package directories are present beside `BookTrace.xcodeproj`. |
| Swift tools version is unsupported | Select an Xcode installation that includes Swift 6.2 or newer and check the active command-line toolchain. |
| Device signing fails | Set your development team and, if needed, a bundle identifier available to that team. |

## Project status and roadmap

Book discovery, library management, timed reading sessions, pace estimates, reading streaks, Journal statistics, cover palettes, visual reading atmospheres, themes, and language settings are implemented.

The following work remains planned:

- Author search, author profiles, and bibliographies.
- Recommendations based on library subjects and categories.
- Reading goals and richer reading trends; the current streak and recent-activity strip are already implemented.
- A backend proxy to keep the Google Books key off devices and manage shared usage limits.

See [Plan.md](Plan.md) for the original phased development plan, written in Turkish. Its phase checklists predate some of the implemented profile and settings features described here.
