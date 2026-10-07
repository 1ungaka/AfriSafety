<p align="center">
  <img src="design/brand/icon-circle.svg" width="96" alt="AfriSafety logo">
</p>

<h1 align="center">AfriSafety</h1>

<p align="center">
  A privacy-first personal safety and location-sharing app for South Africa.<br>
  Like a family locator, but the server can't see where anyone is.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter">
  <img alt="Supabase" src="https://img.shields.io/badge/Supabase-Postgres%20%2B%20RLS-3ECF8E?logo=supabase">
  <img alt="libsodium" src="https://img.shields.io/badge/crypto-libsodium-555">
  <img alt="Android" src="https://img.shields.io/badge/platform-Android%208%2B-3DDC84?logo=android">
</p>

> **AfriSafety does not replace emergency services.** In danger, call **10111** (SAPS) or **112**.

---

## Why

Location-sharing apps are useful for safety, but they collect a detailed record of
where people live, work and go, and they are routinely misused by abusive partners
to track someone covertly. AfriSafety tries to keep the safety benefits while
removing those risks:

- **The server is a relay, not a reader.** Locations, alerts, check-ins and journey
  updates are end-to-end encrypted on the phone. The backend stores ciphertext.
- **It can't be used as stalkerware.** Sharing always shows a notification, says how
  many people can see you, and can be paused or left in one tap that nobody can
  block.
- **It's built for South African conditions:** low-end Android phones, expensive
  data (a location update is 19 bytes before encryption), patchy signal and load
  shedding.

## Features

**Sharing**
- Circles (family, friends) joined with invite codes; live map of members
- Per-person control: each member chooses who sees their live location and who only
  gets SOS alerts
- Keeps sharing after the app is swiped away (always with a visible notification)

**Emergencies**
- SOS with a cancellable 3-second countdown, delivery and "seen" receipts, and an
  SMS fallback pre-filled with your emergency contacts
- **Check-in timer** and **Walk me home**: if you don't check in or arrive in time,
  your Circles get an alert, even if your phone is switched off or taken
- Shake-to-SOS (opt-in) and 10111/112 quick-dial on every emergency screen

**Everyday safety**
- Places ("arrived at Home"), detected on the phone, with an activity feed
- Optional location history that never leaves the phone
- Anonymous community incident reports on a ~1 km grid

**Security and privacy controls**
- App lock (PIN hashed with Argon2id, fingerprint unlock), SOS still works while locked
- Security codes to verify Circle members' keys in person, with key-change warnings
- Devices screen: see signed-in phones, sign them out remotely
- "Think someone is tracking you?" guide with South African helplines
- Delete my account, in the app

## Security design

The full threat model (STRIDE, anti-stalkerware rules, POPIA) is in
[SECURITY.md](SECURITY.md) and the design in [docs/architecture.md](docs/architecture.md).
The highlights:

| Area | Design |
|---|---|
| Encryption | libsodium: XChaCha20-Poly1305 for data, X25519 sealed boxes for key exchange, Ed25519 signatures on every key envelope. AAD binds context, Circle, sender and key version, so the server can't swap or relabel ciphertext |
| Keys (D7) | **Per-sender keys**: each phone has its own key per Circle and channel (location / alert), handed only to the members its owner chooses. "SOS only" viewers never receive the location key. Keys rotate whenever someone loses access |
| Missed check-ins without trusting the server | The phone escrows an already-encrypted alert per Circle. A `pg_cron` watchdog releases it unchanged if the deadline passes, so help is raised even if the phone is off, and the server never reads it |
| Database | Row Level Security on every table, deny by default. `SECURITY DEFINER` code lives in a private schema with a pinned `search_path`. Catalogue-wide tests enforce both rules for every future table and function |
| On-device data | Places, SMS contacts and history are sealed in a local vault (key in Android Keystore) and never uploaded |
| Community reports | Category only (no free text), snapped to a ~1 km square **on the phone**, 4-hour time blocks, no raw-row reads, shown only when 3+ different people reported (k-anonymity) |
| Devices | Signing a phone out is final in the database. A revoked phone wipes itself instead of quietly re-registering |
| Abuse | Rate limits on invites, alerts, events, check-ins and reports; invite codes stored as hashes; moderation for community reports |

**Deliberate trade-offs** (documented in SECURITY.md): metadata such as Circle
membership and update timing is visible to the server; no certificate pinning yet
(a wrong pin locks everyone out); a 6-digit PIN relies on attempt limits more than
on its hash.

## Tests

| Suite | What it covers |
|---|---|
| ~200 Flutter tests (`app/test`) | Crypto and AAD tampering, key-sync protocol over a fake server that mirrors RLS, geofence hysteresis, check-in flow, app lock, shake detection, security codes, consent gates, accessibility |
| ~180 pgTAP assertions (`supabase/tests/database`) | Acting as members and an outsider: outsiders get zero rows, nobody writes as someone else, pause and leave can't be blocked, rate limits, watchdog, k-anonymity, moderation, account deletion |
| Deno tests (`supabase/functions/tests`) | Push payloads carry no personal data; FCM signing |
| CI (GitHub Actions) | Formatting, analysis, all tests, `supabase db lint`, and a release Android app bundle build on every push. Tagged versions become signed APKs on GitHub Releases, after a check that they aren't signed with the debug key |

## Tech stack

Flutter (Dart) · Riverpod · go_router · Supabase (Postgres, RLS, Auth, Realtime,
Edge Functions, pg_cron) · libsodium (`sodium`) · flutter_map · geolocator ·
Firebase Cloud Messaging (optional)

## Repository layout

```
app/        Flutter app (package za.co.afrisafety.app), feature-first
supabase/   migrations, pgTAP security tests, Edge Functions
docs/       architecture, plan, privacy policy, setup and release guides
design/     brand (icon, colours, type) and screen designs
```

## Running it

- **Windows, step by step:** [docs/setup-windows.md](docs/setup-windows.md)
- **Connect to a cloud Supabase project:** [docs/setup-cloud.md](docs/setup-cloud.md)
- **Build for Google Play:** [docs/release.md](docs/release.md)
- **Install the test version on Android:** [docs/install.md](docs/install.md)

Short version (macOS/Linux, local Supabase in Docker):

```bash
supabase start && supabase test db          # backend + security tests
cd app && cp .env.example .env              # fill in the URL and publishable key
flutter pub get && flutter test
flutter run --dart-define-from-file=.env
```

`app/.env` is compiled into the app, so it only ever holds public values. Server
secrets go in `supabase secrets`. The first build takes longer because libsodium is
compiled from source.

## Project status

All four planned phases are built: sharing, safety features, security hardening and
the community layer. What's left before a public release (real-phone testing,
production accounts, POPIA registration, Play Store listing) is tracked in
[docs/launch-checklist.md](docs/launch-checklist.md). Decisions and their reasons are
in [docs/plan.md](docs/plan.md).

## Author

Built by **Lunga Ngaka** as a security-focused portfolio project.
