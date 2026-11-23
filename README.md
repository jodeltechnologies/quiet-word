# Quiet Time

Personal Bible study PWA at https://quiet-word-psi.vercel.app/ with all 66 Bible books, 1,189 chapter studies, full KJV text, Matthew Henry concise commentary, topic and character pathways, reading plans, seven starter studies and weekly Word downloads.

## Access and sync

Email account creation, passwords and confirmation links are removed from the app. Choose Create my PIN, enter and confirm four digits, then save the private recovery code shown after setup. On another device choose Connect my notes, paste that code and enter the same PIN. The app remembers the code locally, so later visits on a connected device only ask for the PIN. Creating a new PIN from the welcome screen creates a separate journal. Change an existing PIN in Settings to keep the same notes.

The recovery code is a random 256-bit credential. Keep it private. It can be viewed, copied or downloaded from Settings after unlocking. If every connected device is cleared or lost and the code was not saved, the journal cannot be recovered. Disconnect device removes the local code after syncing and confirmation. It does not delete the cloud journal.

Internet is required to unlock and sync. While an already unlocked page remains open, notes can be edited in memory and synced on reconnection. Keep the page open until syncing completes. Private notes and PIN-session tokens are not stored in the offline asset cache. Preferences and the journal credential remain device-local. Backups and recovery-code files are plaintext and should be kept private.

## Hosting

Repository: jodeltechnologies/quiet-word. Vercel project: quiet-word, static public directory, framework Other, no build command. Supabase project: tyhdiagycqhyqmhoeowa. No OpenAI services or ChatGPT subscription are required. Vercel Hobby and Supabase Free have usage limits and no paid upgrade is authorized.

The client sends its publishable key to the public security-invoker RPC quiet_time_pin. No service-role key is included. Supabase Auth settings are not changed or required for this flow. The former email-account RPC and tables are retained for rollback. No cloud notes or PIN accounts existed there when changing access.

For a fresh database, apply database/schema.sql and database/pin-access.sql once. Existing deployments already have both applied. Do not reapply create-table statements.

## Security

The RPC delegates to a private function using capability authentication, rather than auth.uid(): a hashed recovery code plus a hashed 30-minute PIN session is checked before every journal operation. The PIN uses bcrypt. Records are scoped to the hashed code and callers cannot choose another journal ID. Private tables have RLS and no direct anon/authenticated table grants. PIN guessing pauses for five minutes after five wrong attempts. A changed PIN revokes all prior PIN sessions.

Concurrent edits to the same answer are held for review. Different fields sync independently. New journals are capped at 10/hour and 100 total for this personal installation. Each journal has a 2,000,000-character note limit. Existing journals remain accessible when creation limits are reached.

## Weekly Word files

Journal > Download weekly notes or Library > Weekly notes exports current notes from studies last edited in the chosen Monday-to-Sunday week, using Africa/Douala time. Include Scripture and commentary optionally, or prepare seven consecutive chapter studies. Earlier versions of answers are not reconstructed. Documents are prepared on the device without a third-party document service. JSON backup and restore remain available in Settings.

## Validation

The full Bible content and weekly Word package were checked, rendered and inspected in the library update. PIN checks in database/check-pin-access.sql run in a transaction that rolls back all synthetic journals. Checks cover setup, second-device reading, original and final study IDs, weekly timestamps, conflicts, atomic validation, isolation, wrong/absent/expired sessions, PIN throttling, PIN changes and no direct anonymous table access. Anonymous REST access and the live welcome/setup screen are checked before delivery. Owner-device Android installation and a real cross-device journal still require owner verification.

Vendored client library supabase-js 2.49.8 is retained for rollback but no longer loaded by the PIN app. See https://github.com/supabase/supabase-js for its MIT license.

## Storytelling library

The main opening route now leads to Bible stories and spiritual lessons. The connected journey contains all 168 original 1904 retellings by Jesse Lyman Hurlbut, reproduced from the Heritage History 2009 educational edition with source attribution. Three original focused studies address Eli and his sons, David/Nathan/Solomon and the prophet in 1 Kings 13. Each retelling has an original spiritual reflection, passage references, questions, prayer, synced notes and reading-aloud support. Historic retellings and commentary are interpretation and are visibly distinguished from the biblical text.

A separate coverage index assigns every KJV verse exactly once to 3,705 passage sections. It covers all 31,102 verses and all 66 books, including passages not selected by the historical storyteller. Poetry, law, letters and visions are identified rather than represented as invented narrative events. There is no assertion of one universally agreed count of distinct Bible stories.

Stable journal IDs: the existing seven studies and chapter IDs stay 0–1195. Passage section IDs are 50000 plus their canonical zero-based starting verse index. The 168 historical story IDs are 90000–90167, and the three original featured IDs are 90200–90202. IDs must not be reassigned. database/story-ids.sql updates only the existing private RPC ID validation to permit these five-digit IDs, preserving PIN/session checks and note scoping.

Weekly Word exports include the retelling, its source attribution, spiritual reflection and saved responses. A seven-story preparation pack is available alongside the previous chapter pack. Audio uses the browser device voice rather than the reference creator’s voice. Story files are cached after opening.

Source: Jesse Lyman Hurlbut, Story of the Bible Told for Young and Old. Original Copyright 1904 by Jesse Lyman Hurlbut. Distributed by Heritage History 2009. https://www.heritage-history.com/index.php?author=hurlbut&book=bible&c=read. Original public-domain content is reproduced without alteration for this personal educational app, with attribution in both the story pages and Word export. Source maps and source hashes document the extraction.

### Book-by-book retellings

The first Gospel batch adds 71 studies from Matthew and 35 from Mark. Each book has a connected path in Scripture order, with original retellings, parables and teaching studies, spiritual lessons, reflection questions and exact verse ranges. All 1,749 verses of these two books are assigned to the new studies in order. The Bible text and the retellings remain separately labelled in the reader.

Edit the book study source files in `source/` and run `python scripts/build-book-studies.py` to regenerate the study catalogue. The builder checks for incomplete or repeated Scripture coverage. Matthew uses stable journal IDs 91000–91070, and Mark uses 91071–91105. Preserve these IDs when editing existing entries and reserve a new range for each subsequent book.

The next batch adds 61 studies from Luke (IDs 91106–91166) and 47 from John (IDs 91167–91213). All four Gospels can now be read in order in 214 original studies, with 385 connected studies across the complete catalogue.

The third batch adds Acts (49), Romans (26), 1 Corinthians (24), 2 Corinthians (15) and Galatians (11). This gives 339 original book-by-book studies from Matthew through Galatians and 510 connected studies in the catalogue. Stable IDs for this batch run from 91214 through 91338. Cross-chapter ranges preserve each verse reference in the reader and Word. The letters use guided explanations of the argument and historical exchanges.

The fourth batch adds 59 studies from Ephesians through Philemon (IDs 91339–91397). The catalogue now includes 569 connected studies, with 398 original studies by passage across 18 books from Matthew through Philemon.

The next fuller batch adds Hosea (9 studies, IDs 101500–101508), Joel (3, IDs 102000–102002), Hebrews (9, IDs 91400–91408) and James (5, IDs 91450–91454). All 681 verses across their 35 chapters are covered in Scripture order. Each entry has four original paragraphs of at least 400 words in total, a spiritual lesson and a reflection question. Existing study IDs and source content are unchanged. Reader navigation, journal input and Word exports are checked for all 26 new entries.

The following batch adds Amos (7 studies, IDs 102500–102506), Obadiah (2, IDs 103000–103001), 1 Peter (9, IDs 91500–91508) and 2 Peter (4, IDs 91550–91553). All 333 verses across their 18 chapters are covered once and in order. The 22 entries each contain four original paragraphs of more than 400 words in total, with a spiritual lesson and reflection question. Every new entry is checked for reading, journal input, Scripture boundaries and Word export, and prior studies retain their IDs and content.
