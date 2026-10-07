# CLAUDE.md

Guidance for Claude Code sessions working on **AfriSafety**, a privacy-first personal
safety and location-sharing app for South Africa (package `za.co.afrisafety.app`).

## Current state

**All planned phases (0–4) are built (Phase 1 verified on devices; Phases 2–4 tested on the emulator/CI). Launch readiness code is done; owner steps are in `docs/launch-checklist.md`.** Read these
before doing anything:
- `docs/architecture.md`: components, data flow, encryption design
- `SECURITY.md`: threat model (STRIDE), anti-stalkerware rules, POPIA
- `docs/plan.md`: phased task list and decisions (D1–D7)
- `docs/setup-cloud.md`, `docs/setup-windows.md`: how the owner runs it (Windows)

## Commits

Commits are authored as **Lunga Ngaka <lungaka777@gmail.com>** with no
co-author or session trailers (owner's request, 2026-10-07; history was
rewritten to match). The public default branch is **`main`**; keep it in step
with the working branch.

## Working agreement

- Build **one phase at a time** (`docs/plan.md`). At the end of each phase: run all
  tests, summarise what was built, list manual setup steps (keys, Supabase, Firebase),
  then **stop and wait for approval**.
- Small, descriptive commits, one per feature.
- Briefly explain security-relevant decisions in code comments and phase summaries.
  The owner is a CS/cybersecurity student and this is a portfolio project.
- Update this file when a decision is made or a convention changes.

## Stack

- **App:** Flutter (Dart), Android first (minSdk 26), in `app/`
- **State/navigation:** Riverpod 3 (plain providers, no codegen, which keeps the code
  readable without build_runner), go_router
- **Backend:** Supabase (Postgres + RLS, Auth, Realtime, Edge Functions in Deno/TS,
  pg_cron), in `supabase/`. Community reports use an integer 0.01° grid, not PostGIS
- **Push:** Firebase Cloud Messaging, optional, configured from dart-defines (no
  google-services.json). Pushes carry generic text plus an opaque id, never personal data
- **Maps:** flutter_map + OSM-based tiles (respect provider tile usage policy)
- **Location:** geolocator + Android foreground service, behind `LocationSource`
- **Crypto:** libsodium via the `sodium` package (v4 builds libsodium from source
  through build hooks; `sodium_libs` is deprecated, don't add it). The app loads
  the sumo build (`SodiumSumoInit`) for Argon2id; it falls back to the normal
  build and hides app lock if sumo is unavailable. Keys in
  `flutter_secure_storage`. All primitives live in `app/lib/core/crypto/`
- **Offline:** in-memory retry of the latest fix per Circle (no drift/codegen). The
  Flutter engine is process-wide (`MainActivity.provideFlutterEngine`), so it
  survives swipe-away while the location foreground service runs
- **On-device data:** places, SMS contacts and history live only in `LocalVault`
  (`app/lib/core/storage/`), never on the server
- **SMS:** on-device `sms:` link with saved contacts pre-filled. No server gateway
  (it would need explicit approval under rule 3)

## Security rules (non-negotiable)

1. **Never hardcode secrets.** Server secrets live in `supabase secrets` and git-ignored
   `.env`. Client config (URL, publishable key) is public by design and comes from
   `--dart-define-from-file`.
2. **Never log location.** Use `SafeLogger`. `print`/`debugPrint` are banned in `lib/`.
3. **Location, places, alerts and journeys are E2EE.** The server must only ever see
   ciphertext for these. Any new plaintext location path needs explicit approval and
   must be documented in `docs/architecture.md` §4.5 and `SECURITY.md`.
4. **AEAD AAD must bind** `context ‖ circle_id ‖ user_id ‖ key_version` for Circle
   data (`CircleAad`).
5. **RLS on every table, deny by default.** Every new table ships with pgTAP tests
   proving non-members get zero rows.
6. **No silent tracking.** Location collection only happens inside the foreground
   service with its visible notification. No hidden modes, no remote enable.
7. **Pause and Leave are sovereign.** Only the member themself can pause or leave,
   and nothing may block or delay it.
8. **No `SEND_SMS` permission.** Use the `sms:` intent.
9. `SECURITY DEFINER` functions go in the `private` schema with a pinned `search_path`.
10. No third-party analytics or crash-reporting SDKs without approval.
11. **Per-sender keys (D7).** Never reintroduce a shared Circle key. Who may hold a
   key is decided only in `planKeySync`; rotation must follow any loss of access.

## Design

- Reference: `design/README.md` (tokens, type, icon, screen → phase map) and
  `design/reference/*.dc.html` (the owner's Claude Design screens). Build
  screens to match these layouts.
- Colours only via `AppColors` (`app/lib/core/theme/app_colors.dart`). No raw hex in
  widgets. Amber is never used for text on light backgrounds.
- Fonts: Bricolage Grotesque (headings) and DM Sans (body), bundled in
  `app/assets/fonts`. Never use `google_fonts` or any runtime font fetching.
- App icon: concept B "The Circle". Source SVGs in `design/brand/`. The in-app mark
  is `AfriSafetyLogo`.

## Conventions

- Feature-first layout: `app/lib/features/<feature>/{data,domain,presentation}`,
  shared code in `app/lib/core/`.
- All user-facing strings go in ARB files (`app/lib/l10n/`). No hardcoded UI text.
- Accessibility: ≥48 dp touch targets, WCAG AA contrast, semantic labels.
- Migrations: `supabase/migrations/<timestamp>_<concern>.sql`, one concern each.
- Tests mirror `lib/` under `app/test/`. RLS tests in `supabase/tests/database/*.test.sql`.
- `app/test/architecture/security_rules_test.dart` enforces rules 2 and 8 and the
  manifest hardening. `supabase/tests/database/000_foundations.test.sql` enforces
  rules 5 and 9 across *all* tables and functions. Keep both passing; never weaken them.
- Generated l10n Dart files (`app/lib/l10n/app_localizations*.dart`) are committed.
  Regenerate with `flutter gen-l10n` after editing ARB files.
- Every emergency screen shows the 10111 / 112 quick-dial bar and the
  "does not replace emergency services" notice.

## Commands

```bash
# App
cd app && flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
dart format lib test            # CI fails on unformatted code

# Backend
supabase start                 # local stack (Docker)
supabase db reset              # apply migrations + seed
supabase test db               # pgTAP RLS tests
supabase functions serve       # edge functions locally
supabase/scripts/test_without_docker.sh   # pgTAP tests without Docker (run as non-root)
deno check supabase/functions/dispatch-alert/index.ts && deno test supabase/functions/tests/
```

Toolchain: Flutter 3.47.6 / Dart 3.13. Supabase local Postgres is 17.

## Decisions log

| Date | Decision | Status |
|---|---|---|
| 2026-10-03 | App name AfriSafety, package `za.co.afrisafety.app` | Decided |
| 2026-10-03 | D1: basic E2EE from Phase 1 (rotation + QR verification in Phase 3) | Decided (recommended default) |
| 2026-10-03 | D2: `geolocator` + foreground service behind `LocationSource` | Decided (recommended default) |
| 2026-10-03 | D3: email OTP for dev, phone OTP (+27) for production | Decided (recommended default) |
| 2026-10-03 | D4: 18+ only for MVP | Decided (recommended default) |
| 2026-10-03 | D5: invitee accepts; inviter's device hands over keys; all members notified | Decided (recommended default) |
| 2026-10-03 | D6: monorepo `app/` + `supabase/` | Decided |
| 2026-10-03 | Riverpod without codegen; `sodium` instead of deprecated `sodium_libs` | Decided |
| 2026-10-03 | Device keys stored as 32-byte seeds; key pairs re-derived on load | Decided |
| 2026-10-04 | Visual design from the owner's Claude Design canvas; icon B "The Circle" | Decided |
| 2026-10-04 | D7: per-sender keys (location + alert channel per device per Circle) | Decided (owner: "D7 yes") |
| 2026-10-04 | Backend: cloud Supabase project instead of local Docker (owner: "(b)") | Decided |
| 2026-10-04 | Push optional; generic notification text, details decrypted in-app | Decided |
| 2026-10-05 | OSM standard tiles allowed for light dev testing only; a release needs a tile provider (MapTiler) | Decided |
| 2026-10-06 | Places, SMS contacts and history are device-only (encrypted vault), not server ciphertext | Decided (Phase 2) |
| 2026-10-06 | Missed check-ins via escrowed E2EE alerts released by a pg_cron watchdog; no server-readable escrow | Decided (Phase 2) |
| 2026-10-06 | No server SMS gateway; `sms:` link with pre-filled contacts | Decided (Phase 2; gateway needs owner approval) |
| 2026-10-06 | Circle events (place/journey) use the location key; escrowed alerts use the alert key | Decided (Phase 2) |
| 2026-10-07 | Commits authored as the owner, no AI trailers; history rewritten | Decided (owner) |
| 2026-10-07 | App lock = 6-digit PIN with Argon2id (libsodium sumo); fingerprint unlock deferred until build-tested | Decided (Phase 3) |
| 2026-10-07 | Security codes: BLAKE2b over each person's device keys, 60 digits; TOFU with change warnings | Decided (Phase 3) |
| 2026-10-07 | Device revocation is final (DB trigger); revoked phones wipe themselves | Decided (Phase 3) |
| 2026-10-07 | Certificate pinning deferred (lock-out risk) | Decided (Phase 3) |
| 2026-10-08 | Firebase push skipped for now (owner); missed-check-in push code kept in a local stash only | Decided (owner) |
| 2026-10-08 | Community reports: category only, grid snapped on the phone, k = 3, no raw reads, no PostGIS, no stranger SOS | Decided (Phase 4) |
| 2026-10-09 | Account deletion leaves Circles first (ownership passes on), then deletes auth.users | Decided (launch) |
| 2026-10-09 | MainActivity is a FlutterFragmentActivity (local_auth); fingerprint unlock is biometrics-only | Decided (launch) |
| 2026-10-09 | Phone sign-in behind AUTH_METHOD=phone, +27 only | Decided (launch) |
| 2026-10-07 | Test APKs: tag `v*` → CI signs with the upload key (GitHub secrets), refuses debug-signed or OSM-tile builds, publishes a GitHub pre-release. One universal APK | Decided |
| 2026-10-04 | Invite RPCs return null/empty for wrong codes (never raise), so rate-limit hits aren't rolled back | Decided (security fix) |
