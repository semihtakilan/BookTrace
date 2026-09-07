# App Review notes

Prepared for the release candidate. Copy the text below after the production CloudKit container, App Store Connect products and public privacy/support URLs are configured. Add the account owner's actual review phone number in App Store Connect; it is intentionally absent here.

## Notes for the reviewer

BookTrace is an iPhone reading journal. No BookTrace account or demo login is required. Users can add unlimited books, search catalogs, scan book barcodes, record reading sessions, use basic journal statistics and reading streaks, and import a Goodreads CSV without subscribing.

Open Journal, then Settings, then BookTrace Pro to view the purchase options and Restore Purchases. Pro is offered as monthly or yearly auto-renewable subscriptions, plus a separate non-consumable lifetime purchase. The annual product has a 7-day introductory free trial for eligible Apple Accounts. Monthly and lifetime products do not offer a trial. Availability and pricing are supplied by StoreKit.

Pro features include reading-session Live Activity, widgets, reading goals, detailed statistics, the quote notebook and page scanning, exports, and full year-in-review cards. A basic year-in-review summary is free. Previously saved user quotes and goals remain readable if Pro access expires.

To test a reading session, add a book and start its reading mode. With Pro, the session can appear on the Lock Screen or Dynamic Island; pause/resume and finish/cancel should update or end the Live Activity. Widgets read the shared local store and refresh when library data changes.

Page scanning uses the camera only after the user chooses to scan. Text recognition runs on the device, and recognized text is editable before saving. Manual quote entry is also available. Camera functionality requires a supported device; barcode and page scanning are separate entry points.

Library synchronization uses the user's private iCloud database and is free. It requires an available iCloud account. If iCloud is unavailable, the app continues with local storage. The search/cover cache is separate from the synchronized library. Online searches and book covers use Open Library and, when needed, Google Books.

Support: booktrace.help@gmail.com

## Before copying these notes

- [ ] All described features are present in the selected release build.
- [ ] All three products are attached to the appropriate review submission.
- [ ] Annual trial availability matches the current App Store Connect setup.
- [ ] Production CloudKit schema is deployed and verified with the uploaded build.
- [ ] Public privacy policy and support pages are configured and reachable.
- [ ] Reviewer contact name, email and actual telephone number are entered.

No Apple Account credentials are included. Sandbox purchase behavior, production iCloud sync and the uploaded build's behavior must be verified separately from this document.
