# Project Plan: BookTrace (iOS)

## Phase 1: Project Setup & Infrastructure
In this phase, you will establish the foundational project skeleton, external dependencies, and modular folder structure.

*   **1.1. Version Control:** Initialize a local GitHub repository (main branch) at the start of the project[cite: 6]. Execute subsequent phases on separate feature branches[cite: 6].
*   **1.2. Dependency Management (SPM):** Integrate `Factory` (Dependency Injection), `Navigator` (Routing), and `Kingfisher` (Image Caching) packages[cite: 6].
*   **1.3. Domain Architecture:** Create `Domain`, `Data`, `Presentation`, and `Core` directories strictly adhering to Clean Architecture standards[cite: 6].

## Phase 2: Enhanced Data Models & Local Storage (Data Layer)
You will configure the state management and database setup, which serve as the backbone of the application.

*   **2.1. Define Domain Entities:**
    *   `ReadingStatus` (Enum): Library, Wishlist, To Read, Reading, Finished, Abandoned, Starred.
    *   `OwnershipStatus` (Enum): Borrowed, Not Owned, Owned.
    *   `Category` (Entity): Custom user-defined categories.
    *   `Book` (Entity): Book metadata and reading metrics. (Add properties for `actualReadTime`, `dynamicReadingSpeed`, and `estimatedRemainingTime` to support the calibration algorithm).
*   **2.2. SwiftData Configuration:** Convert the `Book` and `Category` entities into SwiftData models and set up the `.modelContainer(for:)`[cite: 6].
*   **2.3. Local Repository Implementation:** Implement the `BookRepository` protocol using SwiftData and register it within the Dependency Injection container[cite: 6].

## Phase 3: Network Layer & Performance Optimization (Cache)
You will isolate external data fetching from the UI and minimize API requests to optimize performance.

*   **3.1. API Service:** Construct a service to handle ISBN and text-based queries via the Google Books API[cite: 6].
*   **3.2. API Response Models:** Write pure network models (e.g., `GoogleBooksSearchResponse`) to decode the complex JSON responses, avoiding any backend-oriented terminology[cite: 6]. 
*   **3.3. In-Memory Cache (NSCache):** Architect an independent cache manager to store frequent search queries in RAM with a specific Time-to-Live (TTL)[cite: 6].
*   **3.4. Cache-First Strategy:** Read data from the cache first; if missing or expired, fetch from the API and cache the new result[cite: 6].
*   **3.5. Image Caching:** Implement Kingfisher in the UI layer to automatically handle disk and memory caching for fetched cover images[cite: 6].
*   **3.6. Unit Testing:** Validate the cache logic and fallback behaviors using comprehensive unit tests[cite: 6].

## Phase 4: Tab-Based Navigation & Core UI (Presentation)
You will build the three main tabs and their respective features. Each tab will utilize its own independent `NavigationStack`.

*   **4.1. Tab 1: Books (Library)**
    *   **Toolbar:** "Edit" button positioned at the top right.
    *   **Section 1 (Now Reading):** Displays the currently active book's cover, title, and a progress bar.
    *   **Section 2 (Library):** Filtered horizontal or vertical lists based on `ReadingStatus` (Library, Wishlist, To Read, Reading, Finished, Abandoned, Starred).
    *   **Section 3 (Ownership):** Filtered lists based on `OwnershipStatus` (Borrowed, Not Owned, Owned).
    *   **Section 4 (Categories):** User-defined custom tag/category lists.
*   **4.2. Tab 2: Explore**
    *   **Toolbar:** Top right, ordered right-to-left: Barcode Scanner (Camera) button and `+` (Manual Add) button.
    *   **Search System:** Implement a text field with `Debounce` logic for API calls, and integrate the AVFoundation barcode scanner[cite: 6]. The main list view will remain an Empty State for now.
*   **4.3. Tab 3: Statistics**
    *   **Toolbar:** "Settings" button at the top right.
    *   **Section 1 (Goals):** Time-based daily reading goal (e.g., 0 / 15 mins) and annual book completion goal (e.g., 0 of 12 books).
    *   **Section 2 (Calendar):** A heatmap/calendar view to visualize daily goal streaks.
    *   **Section 3 (Trends):** A section with a time-range picker (e.g., "Last 7 Days"). Metric strings must remain static with only the numeric variables changing dynamically (e.g., "Read `X` pages.", "Average reading speed: `X` pages/hour.").

## Phase 5: Reading Session & Custom UI Components
Core mechanics designed to maximize user experience (UX) and daily retention.

*   **5.1. Dynamic Reading Session (Timer & Calibration):** 
    *   Implement a background timer view that starts when the user begins reading.
    *   Upon tapping "Finish", prompt the user to input the exact number of pages read.
    *   **Dynamic Calibration Algorithm:** Calculate the actual reading speed for the session (`Time Spent / Pages Read`). Override the baseline estimate (2 mins/page) with this personalized speed to dynamically recalculate the estimated remaining time for the specific book.
*   **5.2. Signature Feature (Custom Circular Slider):** Develop the algorithm calculating the angle from a drag gesture's coordinate location[cite: 6].
*   **5.3. Percentage Snapping:** Automatically lock the slider to specific quarter thresholds (25%, 50%, etc.)[cite: 6].
*   **5.4. Haptic Feedback:** Integrate appropriate tactile feedback during slider movement and snapping[cite: 6].

## Phase 6: Advanced Analytics & iOS Widgets
*   **6.1. Deep Reading Statistics:** Utilize Swift Charts to generate the heatmap and trend graphs required in Tab 3[cite: 6].
*   **6.2. iOS Widget Extension:** Design Lock Screen and Home Screen widgets that display the cover and progress of the currently active `.reading` book[cite: 6].