# AfriSafety

A privacy-first personal safety and location-sharing app for South African families,
students and communities. It is built to work on low-end Android phones, with
expensive data, patchy signal and load shedding.

> **AfriSafety does not replace emergency services.** In danger, call **10111** (SAPS)
> or **112**.

## Status

**Phase 0 (foundations) complete.** The project scaffold, encryption core,
security guards and CI are in place. Phase 1 (MVP: sign-in, Circles, live map,
panic button) is next. See the [build plan](docs/plan.md).

- [Architecture](docs/architecture.md)
- [Security & threat model](SECURITY.md)
- [Build plan](docs/plan.md)

## What makes it different

- **End-to-end encrypted** location sharing. The server relays ciphertext it cannot read.
- **Anti-stalkerware by design:** always-visible sharing indicator, one-tap pause and
  leave that nobody can block, join notifications, no hidden modes.
- **Emergency-first:** panic alerts retry until delivered, show delivery status, and
  fall back to SMS when there's no data.
- **POPIA-aligned:** explicit consent, data minimisation, short retention, in-app
  export and delete.

## Stack

Flutter (Android first) · Riverpod · Supabase (Postgres + RLS, Realtime, Edge
Functions) · Firebase Cloud Messaging · flutter_map (OpenStreetMap) · libsodium

## Repository layout

```
app/        Flutter app (package za.co.afrisafety.app)
supabase/   migrations, edge functions, pgTAP security tests
docs/       architecture, plan, privacy policy
```

## Setup on a fresh machine

### 1. Install tools

| Tool | Version | Notes |
|---|---|---|
| [Flutter](https://docs.flutter.dev/get-started/install) | 3.47.x stable | Includes Dart 3.13 |
| Android Studio | latest | Android SDK + an emulator (or a real phone; recommended) |
| C compiler (`gcc`/`clang`) + `make` | any | The `sodium` package builds libsodium from source for host tests |
| [Docker](https://docs.docker.com/get-docker/) | latest | For the local Supabase stack |
| [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) | 2.x | `npm i -g supabase` or `brew install supabase/tap/supabase` |

Run `flutter doctor` and fix anything it reports for Android.

### 2. Start the backend locally

```bash
supabase start          # first run downloads the Docker images
supabase test db        # pgTAP security tests
```

`supabase start` prints an API URL and a publishable (anon) key. You'll need them next.

> No Docker? `supabase/scripts/test_without_docker.sh` runs the database tests
> against a plain local Postgres with pgTAP (see the script header).

### 3. Configure and run the app

```bash
cd app
cp .env.example .env    # then fill in SUPABASE_PUBLISHABLE_KEY and TILE_URL_TEMPLATE
flutter pub get
flutter test
flutter run --dart-define-from-file=.env
```

`.env` is git-ignored. Everything in `app/.env` is compiled into the APK, so it
must only contain public values. Server secrets go in the root `.env` (from
`.env.example`) or `supabase secrets set`.

The first `flutter test` or build takes a minute longer because libsodium is
compiled from source.

### Checks run in CI

```bash
cd app && dart format --set-exit-if-changed lib test && flutter analyze && flutter test
supabase db start && supabase db lint --level error && supabase test db
```
