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
