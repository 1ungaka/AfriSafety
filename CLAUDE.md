# CLAUDE.md

Guidance for Claude Code sessions working on **AfriSafety**, a privacy-first personal
safety and location-sharing app for South Africa (package `za.co.afrisafety.app`).

## Current state

Planning stage. **No application code yet.** Read these before doing anything:
- `docs/architecture.md`: components, data flow, encryption design
- `SECURITY.md`: threat model (STRIDE), anti-stalkerware rules, POPIA
- `docs/plan.md`: phased task list and open decisions (D1–D6)

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
- **State/navigation:** Riverpod (codegen), go_router
- **Backend:** Supabase (Postgres + RLS, Auth, Realtime, Edge Functions in Deno/TS,
  pg_cron; PostGIS for community features only), in `supabase/`
- **Push:** Firebase Cloud Messaging (data-only messages)
- **Maps:** flutter_map + OSM-based tiles (respect provider tile usage policy)
- **Location:** geolocator + Android foreground service, behind `LocationSource`
- **Crypto:** libsodium via `sodium_libs`. Keys in `flutter_secure_storage`
- **Local DB:** drift (SQLite), ciphertext only
- **SMS:** Edge Function → Clickatell/Twilio. On-device `sms:` intent fallback

## Security rules (non-negotiable)

1. **Never hardcode secrets.** Server secrets live in `supabase secrets` and git-ignored
   `.env`. Client config (URL, publishable key) is public by design and comes from
   `--dart-define-from-file`.
2. **Never log location.** Use `SafeLogger`. `print`/`debugPrint` are banned in `lib/`.
3. **Location, places, alerts and journeys are E2EE.** The server must only ever see
   ciphertext for these. Any new plaintext location path needs explicit approval and
   must be documented in `docs/architecture.md` §4.5 and `SECURITY.md`.
4. **AEAD AAD must bind** `circle_id ‖ user_id ‖ key_version` for Circle data.
5. **RLS on every table, deny by default.** Every new table ships with pgTAP tests
   proving non-members get zero rows.
6. **No silent tracking.** Location collection only happens inside the foreground
   service with its visible notification. No hidden modes, no remote enable.
7. **Pause and Leave are sovereign.** Only the member themself can pause or leave,
   and nothing may block or delay it.
8. **No `SEND_SMS` permission.** Use the `sms:` intent.
9. `SECURITY DEFINER` functions go in the `private` schema with a pinned `search_path`.
10. No third-party analytics or crash-reporting SDKs without approval.

## Conventions

- Feature-first layout: `app/lib/features/<feature>/{data,domain,presentation}`,
  shared code in `app/lib/core/`.
- All user-facing strings go in ARB files (`app/lib/l10n/`). No hardcoded UI text.
- Accessibility: ≥48 dp touch targets, WCAG AA contrast, semantic labels.
- Migrations: `supabase/migrations/<timestamp>_<concern>.sql`, one concern each.
- Tests mirror `lib/` under `app/test/`. RLS tests in `supabase/tests/`.
- Every emergency screen shows the 10111 / 112 quick-dial bar and the
  "does not replace emergency services" notice.

## Commands (once scaffolded in Phase 0)

```bash
# App
cd app && flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
dart run build_runner build --delete-conflicting-outputs

# Backend
supabase start                 # local stack (Docker)
supabase db reset              # apply migrations + seed
supabase test db               # pgTAP RLS tests
supabase functions serve       # edge functions locally
```

## Decisions log

| Date | Decision | Status |
|---|---|---|
| 2026-10-03 | App name AfriSafety, package `za.co.afrisafety.app` | Decided |
| 2026-10-03 | D1–D6 in `docs/plan.md` | **Awaiting owner approval** |
