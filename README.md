# Quiet Word

A personal Bible study app with seven guided studies, reflection notes, prayer, progress tracking, audio reading, backups and Android installation. Hosting uses static Vercel files and Supabase Auth/Postgres. The app does not require OpenAI services or a ChatGPT subscription.

## Deploy to Vercel Hobby

Import this repository into Jodel Tech and select:

- Framework: Other
- Build command: none
- Output directory: public
- Project name: quiet-word

`vercel.json` declares the static output directory and security headers. No paid integrations or domain are needed.

The selected Supabase project is `tyhdiagycqhyqmhoeowa`. Quiet Word is deployed at https://quiet-word-psi.vercel.app/. Its schema in `database/schema.sql` has already been applied. Do not reapply it. Only the publishable key is included in the client. Never add a service-role key to this repository.

In this selected Supabase project, set Authentication > URL Configuration > Site URL to `https://quiet-word-psi.vercel.app/` and add the same URL to the redirect allowlist. Confirm signup and password recovery return to the app. Supabase's default email sender has recipient/rate limits, so verify delivery for the owner's address.

## Use

Create and confirm your account, sign in, then choose a four-digit PIN. Use the same account and PIN on your other devices. Install from Android Chrome using Install app or Menu > Add to Home screen > Install. In Settings, export or restore a JSON backup. To move notes from the earlier app, export a backup there and restore it here after signing in.

Internet is required to unlock and sync. While an already unlocked page remains open, unsynced changes are retained in memory. Keep it open until syncing finishes. Private notes are not stored in the offline asset cache. Preferences remain device-local. Backups contain plaintext notes and should be kept private.

## Security and verification

Journal records, PIN hashes and PIN sessions live in a non-exposed schema with RLS and no direct browser table access. The public RPC is security invoker. Its deliberately privileged private implementation checks the authenticated user and a separate hashed PIN session on every data operation. PINs use bcrypt. Five wrong attempts trigger a five-minute pause. A changed PIN invalidates existing PIN sessions.

Different fields sync independently. Concurrent edits to the same answer ask the user to keep both answers or use the account version.

Tests against the actual Supabase database passed for PIN setup, second-session reading, saving, conflict checks, account isolation, throttling and PIN-session invalidation. Synthetic test records were rolled back. Database advisors reported only informational notices for the intentionally inaccessible no-policy private tables. Production sign-in, email recovery, two-device UI and Android installation still need verification after deployment.

Supabase Free may pause projects after low activity. Vercel Hobby and Supabase Free have usage limits. No paid upgrades are authorized.

Vendored client library: @supabase/supabase-js 2.49.8 UMD distribution. See https://github.com/supabase/supabase-js for its MIT license and release information.
