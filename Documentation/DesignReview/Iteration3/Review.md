# Every book brings its own light

This pass answers a single complaint: the interface was calm but inert. Nothing
on screen belonged to the book you were actually reading, nothing moved, and the
most emotional screen in the app — the reading timer — was the flattest one.

The paper / ink / serif direction is kept. What changes is where the colour comes
from, how much of the screen the chrome is allowed to take, and what happens when
you finish something.

## What was wrong

Captured from the running app before this pass.

1. **Chrome ate the first screen.** Every tab opened with an eyebrow, a large
   serif title and a subtitle — roughly 200 pt — above any content, while the
   navigation bar said "BookTrace" one line higher. On iPhone SE nothing useful
   was above the fold.
2. **Every screen was the same colour.** Sage cards on paper, everywhere. A
   science-fiction epic and a book of poems looked identical.
3. **Books had no presence.** Covers were 56–88 pt thumbnails inside cards. The
   card was more visible than the book.
4. **Nothing moved and nothing was ever celebrated.** Finishing a 700-page novel
   produced exactly the same screen as editing a page count.
5. **The reading timer was a stopwatch on a card.**
6. **The number pad arrived at the worst moment.** Right after a reading session,
   the app asked for a page count with a numeric keyboard covering half the
   screen.
7. **No sense of continuity.** Nothing recorded that you had read three days in a
   row.

## Direction

- The **cover** gives each screen its colour.
- The **genre** gives the reading screen its texture and motion.
- Motion appears only where it means something: progress moving, a session
  running, a threshold crossed.

### The book's colour

`BookPalette` takes only the *hue* from the cover. The image is drawn into a
16×24 buffer, pixels are weighted by saturation and midtone affinity, and the
dominant hue bucket wins — a plain "most common colour" always returned the white
or black that covers are mostly made of. Saturation and brightness are then
clamped per use, so a cover can tint a card without any text falling below
contrast. Covers with no colour at all fall back to a hue derived from the book
id, so the colour is still stable per book rather than random.

Seeds are cached in `UserDefaults`. Without that, every cover was re-analysed on
launch and the whole library visibly changed colour a moment after appearing.

### The book's weather

`BookAmbience` (in `Models`, so it is testable without SwiftUI) maps the source's
free-text subjects onto ten moods. Ordering matters: nearly every novel is also
tagged "Fiction", so more specific keywords are tried first. Each mood drives a
`Canvas` field drawn as a pure function of time — drifting motes, a parallax star
field, fog, paper grain, breathing rings, a grid and scan line, lamplight,
rising lines, falling leaves, sparks. Because position is a function of `t` and
not stored state, pausing, backgrounding and Reduce Motion need no extra code.

The mood also nudges the hue, but only by a capped rotation. Moving a red cover
half-way to science-fiction blue landed on magenta — neither the book's colour
nor the genre's.

## Changes

### Library

- The editorial header is gone; the navigation bar carries the title.
- A slim streak strip replaces it: consecutive days plus seven dots. Today counts
  as still open, so an unread evening does not break a streak.
- Now Reading is a swipeable deck of full-width cards tinted by the cover, with
  the book drawn as a volume — spine shading, a page block on the fore edge, and
  a bookmark whose length is the progress.
- The shelf became a three-column cover grid. The old full-width rows fitted
  three books per screen; the grid fits nine, and a cover is the fastest way to
  recognise a book. Status shows as a corner badge — a percentage while reading.
- The Discover nudge is always present, so a library with an empty shelf is not a
  half-empty screen.

### Reading Mode

- Full-bleed ambience for the book's genre, coloured by its cover, paused with
  the timer so a paused session also *looks* paused.
- The book floats on a slow, time-based tilt with a halo of its own colour.
- Elapsed-time thresholds (5, 10, 15, 20, 30, 45, 60, 90, 120 minutes) raise a
  short banner. A long background gap announces only the highest threshold
  crossed rather than a queue of them.
- **The number pad is gone.** Pages read are dialled on a ruler with momentum,
  snapping and a haptic tick per page; the number itself stays tappable for
  keyboard entry, and the dial is an accessibility-adjustable control. A live
  bar shows where the book will land before saving.
- Saving a session that crosses 25 / 50 / 75 %, finishes a book, or is a book's
  first real session shows a short celebration over the reading room.

### Book screens

Detail pages open with the cover's own blurred enlargement fading into paper,
the sharp volume in front, and page count / year / mood as tinted pills. The
previous fixed sage box made every book look the same.

### Discover and Journal

- Topic cards are drawn in their own genre colours instead of six identical white
  boxes; shelf books scale slightly as they approach the edge.
- Journal counts roll up on appear, the week's bars rise left to right, and
  recent sessions show the book's cover.

## Corrections found while testing

- **The celebration closed instantly.** `try? await Task.sleep` swallowed the
  cancellation raised when SwiftUI rebuilt the overlay, so `onDismiss` ran before
  the first frame. Cancellation now returns without dismissing.
- **The finish screen lost the book's colour.** `navigationDestination` content
  inherits the navigation stack's environment, not that of the view declaring the
  modifier. The finish screen now establishes the atmosphere itself.
- **The light card was a colour blob.** The first tint values put a saturated
  block on the paper. Light-mode saturation is now roughly a third of the first
  attempt; the colour speaks through the accent, not the background.
- **The celebration card was see-through.** The title and timer underneath were
  legible through the message. The scrim and card are now opaque enough to read
  against.
- **A bookmark on an unopened book.** The ribbon was drawn at zero progress and
  sat over the cover art. It now appears only once something has been read, and
  closer to the fore edge.
- **Accessibility sizes broke the reading room.** The Turkish room name wrapped
  to three lines and covered the close button, and the timer fell behind the
  controls. The top bar stacks at accessibility sizes, the controls stack and
  gain labels, the timer scale is capped, and the order becomes timer-first —
  the screen's only job is the timer.

## Accessibility and localisation

- Every animation is gated on Reduce Motion; ambient fields also stop in Low
  Power Mode. With motion off the fields still draw, frozen, rather than leaving
  a bare gradient.
- The page dial exposes an adjustable action and a spoken value; the celebration
  is a single combined announcement; covers stay hidden from VoiceOver because
  their text is already beside them.
- Palette roles are clamped so tinted text stays readable in both appearances.
- 45 new strings were added in English, Turkish and German, including a plural
  rule for the streak. No existing entry was removed or reworded.
- Text that is not language — separators and user-supplied titles — no longer
  passes through the string catalog.

## Validation

- 117 application tests, 66 `Models` tests, 6 `NetworkKit` tests pass. New
  coverage: ambience classification and its stability, streak counting across an
  open day and a missed day, session outcomes, the celebration gate on
  dismissal, and elapsed-time thresholds.
- Debug and optimised Release simulator builds succeed.
- iPhone 17 Pro (iOS 26.5): light and dark, the reading room for a science
  fiction cover, the page dial, discovery, journal, book detail.
- iPhone SE 2 (iOS 18.4): compact reading room and finish screen, the cover grid,
  Turkish, accessibility-extra-large text, and a full session saved end to end
  through the celebration.
- Test content was created on the iPhone SE, which has been the scratch device
  since the previous pass; its three books now carry sessions from this testing.
  The iPhone 17 Pro library was left as it was. Simulator appearance and text
  size were restored afterwards.
- These captures verify layout and the interactions exercised here. They are not
  a full VoiceOver audit on hardware, and the camera scanner was not touched.

## Screenshots

| Screen | Evidence |
| --- | --- |
| Library, dark | [Screenshot](01-library-dark.png) |
| Reading Mode, science fiction | [Screenshot](02-reading-room-scifi.png) |
| Page dial | [Screenshot](03-page-dial.png) |
| Discover | [Screenshot](04-discover.png) |
| Discovery shelves | [Screenshot](05-discover-shelves.png) |
| Journal | [Screenshot](06-journal.png) |
| Recent sessions | [Screenshot](07-journal-sessions.png) |
| Book detail | [Screenshot](08-book-hero.png) |
| Cover grid, light, iPhone SE | [Screenshot](09-shelf-light-iphone-se.png) |
| Reading Mode, mystery, iPhone SE | [Screenshot](10-reading-room-mystery-iphone-se.png) |
| Projected progress | [Screenshot](11-projected-progress-iphone-se.png) |
| Milestone celebration | [Screenshot](12-milestone-celebration-iphone-se.png) |
