# AfriSafety

A privacy-first personal safety and location-sharing app for South African families,
students and communities. It is built to work on low-end Android phones, with
expensive data, patchy signal and load shedding.

> **AfriSafety does not replace emergency services.** In danger, call **10111** (SAPS)
> or **112**.

## Status

**Planning.** The architecture, threat model and phased plan are drafted and waiting
for approval. No application code has been written yet.

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

## Setup

Fresh-machine setup instructions will be added in Phase 0 (Flutter SDK, Docker,
Supabase CLI, Firebase project).
