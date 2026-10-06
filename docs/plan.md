# AfriSafety: Build Plan

> Status: **Phase 3 complete (2026-10-07).** Phase 1 verified on devices (2026-10-05); Phase 2 partly tested on the emulator (2026-10-06). Each phase ends with tests passing, a summary,
> a list of manual setup steps, and a pause for your go-ahead.

## Decisions

The recommended options (✅) were adopted on 2026-10-03 when the owner gave the go-ahead to start building. Any of them can still be revisited before the phase that depends on it.

| # | Question | Options | Why it matters |
|---|---|---|---|
| D1 | **Bring basic E2EE forward to Phase 1?** | ✅ Yes: encrypt locations and alerts from day one; rotation and fingerprint QR stay in Phase 3. / No: plaintext in P1, migrate in P3 | Retrofitting E2EE means rewriting the schema, realtime, map and alert code, and migrating plaintext data that should never have existed. It also means P1 would ship plaintext locations |
| D2 | **Background location package** | ✅ `geolocator` + foreground service (free) / Transistor `flutter_background_geolocation` (paid licence for release) | Cost vs battery quality. Swappable behind an interface either way |
| D3 | **Auth method** | ✅ Email OTP for dev, phone OTP for production (+27 only at first) / phone only / email only | Phone OTP needs a paid SMS provider configured in Supabase and is exposed to SIM-swap |
| D4 | **Minimum age** | ✅ 18+ for MVP / support minors now with guardian consent | POPIA s34–35. A guardian-consent flow is real extra work |
| D5 | **Joining a Circle** | ✅ Invitee accepts; the inviter's device hands over keys automatically, and all members are notified / additionally require owner approval | Approval is safer but slower in an emergency setup |
| D6 | **Repo layout** | ✅ Monorepo: `app/` (Flutter) + `supabase/` / Flutter at repo root | Clean separation, separate CI jobs |
| D7 | **Key model (raised by the design's per-member "SOS alerts only" toggle)** (decided 2026-10-04) | ✅ Per-sender keys: each member encrypts their own location with their own key and gives it only to the members they choose / One shared Circle key (no per-member levels, simpler) | With one Circle key, anyone who holds it can read everyone's location, so per-member levels are impossible. Per-sender keys allow them and make rotation cheaper. Cost: each member's device manages one envelope per recipient. See `design/README.md` |

## Folder structure

```
AfriSafety/
├── CLAUDE.md                     # conventions & decisions for future sessions
├── README.md                     # fresh-machine setup
├── SECURITY.md                   # threat model, mitigations, limitations
├── .env.example                  # server-side/local secrets template (never commit .env)
├── .gitignore
├── .github/workflows/
│   ├── app.yml                   # flutter analyze + test
│   └── supabase.yml              # supabase db lint + pgTAP RLS tests
├── docs/
│   ├── architecture.md
│   ├── plan.md                   # this file
│   ├── privacy-policy.md         # plain-language draft (Phase 1)
│   ├── battery-strategy.md       # Phase 2
│   └── adr/                      # one short file per significant decision
├── app/                          # Flutter application (za.co.afrisafety.app)
│   ├── pubspec.yaml
│   ├── analysis_options.yaml     # strict lints + ban print/debugPrint in lib/
│   ├── .env.example              # PUBLIC client config only (URL, publishable key, tiles)
│   ├── android/
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml
│   │       └── res/xml/network_security_config.xml   # pinning (Phase 3)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── bootstrap.dart        # env, Supabase, Firebase, crypto init
│   │   ├── app.dart              # MaterialApp.router, theme, l10n
│   │   ├── core/
│   │   │   ├── config/           # typed env from --dart-define-from-file
│   │   │   ├── crypto/           # sodium wrapper, key store, payload codec, envelopes
│   │   │   ├── logging/          # SafeLogger (redacts coordinates)
│   │   │   ├── network/          # connectivity, retry/backoff
│   │   │   ├── location/         # LocationSource interface + geolocator impl, adaptive policy
│   │   │   ├── notifications/    # FCM + local notifications
│   │   │   ├── routing/          # go_router, deep links
│   │   │   ├── theme/            # high-contrast, large touch targets
│   │   │   └── widgets/          # shared accessible components (EmergencyDialBar, etc.)
│   │   ├── features/
│   │   │   ├── auth/             # each feature: data/ domain/ presentation/
│   │   │   ├── onboarding/       # consent + permission education
│   │   │   ├── profile/
│   │   │   ├── circles/          # create, invite, join, leave, members
│   │   │   ├── map/              # live map + data-saver list view
│   │   │   ├── sharing/          # foreground service, pause, indicator
│   │   │   ├── panic/            # panic button, countdown, delivery status
│   │   │   ├── alerts/           # incoming alerts, receipts
│   │   │   ├── places/           # Phase 2 geofences
│   │   │   ├── journeys/         # Phase 2 walk-me-home
│   │   │   ├── checkins/         # Phase 2 check-in timer
│   │   │   ├── emergency_contacts/ # Phase 2
│   │   │   ├── history/          # Phase 2
│   │   │   ├── security/         # Phase 3 app lock, devices, fingerprints, security log
│   │   │   ├── privacy/          # export, delete account, consent log
│   │   │   └── community/        # Phase 4
│   │   └── l10n/
│   │       └── app_en.arb        # later: app_zu, app_xh, app_st, app_af
│   ├── test/                     # unit + widget tests mirroring lib/
│   └── integration_test/
└── supabase/
    ├── config.toml
    ├── migrations/               # timestamped SQL, one concern per migration
    ├── functions/
    │   ├── _shared/              # cors, auth, rate-limit, fcm client
    │   ├── dispatch-alert/
    │   ├── send-sms/             # Phase 2
    │   └── checkin-watchdog/     # Phase 2
    ├── tests/                    # pgTAP: RLS proofs, RPC behaviour
    └── seed.sql                  # local dev fixtures only
```

---

## Phase 0: Foundations

Goal: an empty but correctly wired project with CI, crypto core and the security
scaffolding every later phase depends on.

- [x] Monorepo scaffold, `.gitignore`, `.env.example`, `README.md`
- [x] Flutter app in `app/` (Android + iOS), id `za.co.afrisafety.app`, strict `analysis_options.yaml`
- [x] Riverpod, go_router, theme (high contrast, ≥48 dp targets), l10n scaffold with `app_en.arb`, 10111/112 quick-dial bar
- [x] Typed config from `--dart-define-from-file`. Fail fast if missing
- [x] `SafeLogger` with coordinate redaction; `avoid_print` as an error plus an architecture test banning `print`/`debugPrint` in `lib/`
- [x] `core/crypto`: libsodium init, device keypair generation, Keystore-backed storage, AEAD encrypt/decrypt with AAD, sealed-box envelopes, binary location codec
- [x] **Tests:** crypto round-trip, wrong-AAD rejection, tamper rejection, codec round-trip and size bound (≤ 64 bytes ciphertext)
- [x] Supabase local project (`supabase init`, tightened OTP settings), base migration: `private` schema, deny-by-default grants, plus pgTAP guards that fail if *any* table lacks RLS or any `SECURITY DEFINER` function lacks a pinned `search_path`
- [x] GitHub Actions: format check, `flutter analyze`, `flutter test`; `supabase db start` + `db lint` + pgTAP
- [x] Android: `allowBackup=false`, data extraction rules, HTTPS-only network config (debug build allows the local stack), `minSdk 26` (Android 8)

**You configure:** install Flutter SDK, Android Studio, Docker, Supabase CLI (see README). Nothing cloud-side yet.

**Result:** 55 Flutter tests and 6 pgTAP tests passing.

## Phase 1: MVP ✅

- [x] **Migrations:** `profiles`, `consents`, `devices`, `device_push_tokens`, `circles`, `circle_members`, `share_levels`, `circle_invites`, `sender_key_envelopes` (D7), `location_latest`, `alerts`, `alert_receipts`, `security_events`, `private.rate_limits`, RLS, RPCs and the realtime publication
- [x] **pgTAP RLS tests:** 89 behavioural assertions (owner, members, outsider), plus catalog-wide guards
- [x] Auth: email OTP, session in Keystore-backed storage, sign-out revokes the device and wipes its keys *(phone OTP: production, D3)*
- [x] Onboarding: plain-language consent (18+, location sharing, privacy) recorded per policy version; staged permission requests with prominent disclosure
- [x] Profile: display name *(optional photo deferred: data minimisation)*
- [x] Device registration: public keys, push token (owner-only table), `security_events` on new device
- [x] Circles: create, invite code (hashed, 48 h, 5 uses, brute-force limited), accept/decline preview, automatic key hand-over, join/leave notifications, **one-tap Leave**
- [x] Per-sender keys (D7) with rotation on leave, revoke and downgrade
- [x] Sharing: foreground service with persistent notification, adaptive tracking (moving / stationary / low battery / emergency), per-Circle encryption, latest-fix retry *(on-disk queue deferred to Phase 2 with history)*
- [x] App shell from the design: Map · Journey · SOS · Circle · Safety
- [x] Live map: `flutter_map`, Realtime, honest statuses (paused, SOS only, waiting for keys), staleness styling, data-saver list view, tile caching (flutter_map built-in)
- [x] "Who can see me": per-member live/SOS-only toggles, invite, pause all, leave
- [x] Panic: 3 s cancellable countdown, idempotent encrypted alerts retried until stored, `dispatch-alert` Edge Function (generic push, no personal data), delivery and seen receipts, SMS fallback after 10 s, 10111/112
- [x] Incoming alerts: full-screen alert, open in maps, call buttons
- [x] Privacy policy draft (`docs/privacy-policy.md`) and cloud setup guide (`docs/setup-cloud.md`)
- [x] **Tests:** 119 Flutter (crypto, codecs, key protocol, tracking policy, panic flow, consent gating, SOS cancel, formatter, SMS, auth errors), 100 pgTAP, 5 Deno
- [x] **Verified on devices (2026-10-05)** against the cloud project: Galaxy A05 (Android 15) + Pixel 7 emulator (API 35). Email-code sign-in, onboarding, create and join a Circle, both members on each other's map, SOS-only hides the location, SOS shows the full-screen alert with Delivered → Seen. Push (Firebase) not yet configured

**You configure:** see `docs/setup-cloud.md` (Supabase project, email code templates, map tile key, optional Firebase).

**Carried into Phase 2:** headless background service (sharing survives swiping the app away), on-disk upload queue, alert retention job (`pg_cron`, 30 days), decrypt-in-background push.

## Phase 2: Safety features ✅

- [x] Sharing survives swipe-away: process-wide Flutter engine kept alive by the location foreground service (and its notification); in-app battery tip for OEM savers
- [x] On-device encrypted vault (`LocalVault`) for data that never leaves the phone
- [x] Places: stored **only on the phone** (not on the server, see decision below), evaluated on device with hysteresis and an accuracy filter; arrive/leave sent as E2EE `circle_events` under the sender's location key; Recent activity feed and in-app message for members
- [x] Check-in timer: server-side deadline (`checkins`), escrowed E2EE alert per Circle (`checkin_escrows`), `private.expire_checkins()` watchdog every minute via `pg_cron`, missed check-ins shown full-screen to members, "I'm safe" to resolve
- [x] Walk me home: destination from saved places or the map, on-device walking estimate (no routing service), close tracking while active, escrow refreshed with the latest location every ~2 min, auto-arrive within 150 m, 10 min grace before the alert
- [x] SMS emergency contacts (POPIA consent confirmation), stored only on the phone and pre-filled into the SOS `sms:` link
- [x] Location history: off by default, on the phone only, 1/7/30 days, timeline map; turning it off deletes it
- [x] Retention job (`private.purge_expired`, nightly): alerts 30 days, events 7, finished check-ins 7, rate-limit counters 2
- [x] Battery strategy documented (`docs/battery-strategy.md`)
- [x] **Tests:** 161 Flutter (+ vault, geofence hysteresis, event codec, ETA, journey/check-in controller, history, SMS contacts), 139 pgTAP (+ `030_phase2`: events, check-ins, escrows, watchdog, retention), 5 Deno

**Decisions taken in Phase 2** (privacy-preserving simplifications of the original plan):
- Places, SMS contacts and history are **device-only** instead of server-side ciphertext. Less for the server to hold, no key-rotation re-encryption, and nobody else can set geofences on you or browse your past route. Cost: no sync to a second phone.
- **No server-side SMS gateway** (`send-sms`): it would put plaintext location on our infrastructure (security rule 3, needs explicit approval) and costs money. The `sms:` link with pre-filled contacts covers the case without it.
- **Missed check-in without plaintext:** escrowed E2EE alerts replace the planned "SMS escrow" that the server could read.
- **No on-disk upload queue:** with the engine surviving swipe-away the in-memory retry lasts as long as sharing does, and history has nothing to upload.
- Decrypt-in-background push moved to Phase 3 (needs Firebase configured first).

**You configure:** enable **Cron** (pg_cron) in Supabase and run the three Phase 2 migrations (see `docs/setup-cloud.md` §1.5). No SMS gateway needed.

## Phase 3: Security hardening ✅

- [x] Key rotation on leave, removal, device revocation and downgrade: built in Phase 1 with D7 (`planKeySync`, serialised per device, versions never repeat; tests in `key_sync_plan_test.dart` / `key_sync_service_test.dart`)
- [x] Security codes (safety numbers): 60 digits per member pair from both people's device keys (BLAKE2b), compared in person; trust-on-first-use with key-change warnings and a banner in the Circle tab
- [x] Device management: Devices screen (this phone, other phones, last active), sign out all other phones (revokes them and ends their sessions), security activity log; a remotely signed-out phone wipes itself on start/resume instead of re-registering; **revocation is final in the database** (`20261007000100_device_revocation.sql`)
- [x] App lock: 6-digit PIN hashed with Argon2id (libsodium `crypto_pwhash`, sumo build), lock on start and after a chosen background time, growing waits after 5 wrong PINs (persisted), SOS and 10111/112 work while locked, forgotten PIN = sign out (wipe)
- [x] Anti-stalkerware: notification states how many people can see you, weekly "still OK?" review on the map, "Think someone is tracking you?" guide with SA helplines, mute a member's updates for 24 h (SOS breaks through)
- [x] Discreet panic: opt-in shake-to-SOS (4 hard shakes in 2.5 s, cooldown, still shows the cancellable countdown)
- [x] Mock-location flag: "Location may be simulated" on members whose phone reports a mock provider
- [x] Rate limiting: invites, alerts, events, check-ins in SQL (Phases 1–2); push at most once per alert
- [x] CI: Android debug APK build added (compiles Kotlin, plugins and libsodium); `supabase db lint` already runs
- [x] **Tests:** 183 Flutter (+ devices, safety numbers, key trust, app lock, shake detector, mutes/review), 146 pgTAP (+ `040_phase3`), 5 Deno

**Deferred, with reasons** (see `SECURITY.md` §7):
- **Fingerprint unlock:** needs `FlutterFragmentActivity` and an AppCompat theme; add once it can be build-tested (the new CI build job makes that possible).
- **Certificate pinning:** a wrong pin set locks every user out until an app update. Needs the real Supabase chain and a rotation plan; until then Android's default (no user-installed CAs for apps targeting API 24+) covers the rogue-CA case.
- **Rapid screen on/off panic:** needs a native broadcast receiver.
- **OTP CAPTCHA:** Supabase Auth supports hCaptcha/Turnstile but the app needs a widget for it; Supabase's built-in OTP rate limits apply meanwhile.
- **Lock-screen notification redaction:** the notification never contains a location or names, so there's nothing to redact.

**You configure:** run `supabase/migrations/20261007000100_device_revocation.sql` in the SQL Editor (query name `05 AfriSafety Phase 3 – RUN ONCE`).

## Phase 4: Community layer

- [ ] PostGIS-backed `incident_reports` snapped to ~1 km grid, time-bucketed, k-anonymity threshold for display
- [ ] Neighbourhood watch groups with opt-in radius panic alerts (coarse cell only)
- [ ] Moderation: report abuse, auto-hide on N reports, moderator role and tools, ban
- [ ] Separate consent and privacy-policy section for community features

## Later (not scheduled)

isiZulu, isiXhosa, Sesotho and Afrikaans translations · guardian consent for minors ·
iOS release · Huawei (no-GMS) push alternative · Play Integrity · incident response
runbook · Information Officer registration.
