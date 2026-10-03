# AfriSafety: Build Plan

> Status: **Phase 0 complete.** Each phase ends with tests passing, a summary,
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
| D7 | **Key model (raised by the design's per-member "SOS alerts only" toggle)** (*open: decide before Phase 1*) | ✅ Per-sender keys: each member encrypts their own location with their own key and gives it only to the members they choose / One shared Circle key (no per-member levels, simpler) | With one Circle key, anyone who holds it can read everyone's location, so per-member levels are impossible. Per-sender keys allow them and make rotation cheaper. Cost: each member's device manages one envelope per recipient. See `design/README.md` |

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
│   │   │   ├── storage/          # drift DB: offline queue, cache (ciphertext only)
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

## Phase 1: MVP

- [ ] **Migrations:** `profiles`, `consents`, `devices`, `circles`, `circle_members`, `circle_invites`, `circle_key_envelopes`, `location_latest`, `alerts`, `alert_receipts`, `security_events`, `rate_limits`, plus RLS policies and `private.is_circle_member()`
- [ ] **pgTAP RLS tests:** non-member sees zero rows in every Circle table; member can't write as another user; member can't change another member's `sharing_paused`; owner can't un-pause others; invite codes not readable
- [ ] Auth: email OTP (phone OTP behind a flag), session persistence, sign-out
- [ ] Onboarding: plain-language "what is shared, with whom, why", consent recorded with policy version, staged permission requests (foreground, then background, then notifications) with Play-compliant prominent disclosure
- [ ] Profile: display name, optional photo (Supabase Storage, private bucket, RLS)
- [ ] Device registration: upload public keys and FCM token. `security_events` on new device
- [ ] Circles: create (generates Circle key v1), invite code/link (hashed, expiring, rate-limited), accept/decline screen, automatic key handoff, join notifications, **one-tap Leave**
- [ ] Sharing: foreground service with persistent notification, basic adaptive interval, encrypt per Circle, offline queue (drift), upload with backoff
- [ ] App shell from the design: bottom nav Map · Journey · SOS · Circle · Safety (`design/reference/home-map.dc.html`)
- [ ] Live map: `flutter_map`, decrypt member locations from Realtime, "last updated" + staleness styling, data-saver list view, tile caching
- [ ] "Who can see me" screen: member list, Pause all, Leave (`design/reference/who-can-see-me.dc.html`)
- [ ] Panic button (design: `sos-alert-sent.dc.html`): 3 s cancellable countdown, idempotent alert insert with retries, `dispatch-alert` Edge Function (data-only FCM), on-device decrypt + local notification, delivery and seen receipts on sender's screen, SMS-intent fallback when offline, 10111/112 quick-dial
- [ ] Privacy policy draft (`docs/privacy-policy.md`)
- [ ] **Tests:** unit (crypto, codec, queue, adaptive policy, invite code), widget (onboarding consent, panic countdown/cancel, leave), RLS (above)

**You configure:** Supabase cloud project (region choice), Firebase project + `google-services.json`, FCM service-account secret for Edge Functions, real Android phone for testing.

## Phase 2: Safety features

- [ ] Places: encrypted with Circle key, **evaluated on device** against the location stream (enter/exit with hysteresis), arrive/leave alerts sent as E2EE alerts
- [ ] Journey ("Walk me home"): ephemeral journey key, chosen app contacts via sealed box, non-app contacts via share link with key in URL fragment (static web viewer, optional), on-device straight-line ETA (no third-party routing), auto-stop on arrival or timeout
- [ ] Check-in timer: server-side deadline (`checkins`), `checkin-watchdog` via `pg_cron`, E2EE push to Circle, optional opt-in SMS escrow for SMS contacts
- [ ] Emergency contacts (SMS-only) with explicit SMS consent. `send-sms` Edge Function (Clickatell or Twilio)
- [ ] SMS fallback for panic: server SMS when there's some data, SMS intent when there's none
- [ ] Location history: encrypted points, batched upload, user-set retention (default 7, max 30 days), `pg_cron` deletion, on-device timeline view
- [ ] Battery strategy refinement + `docs/battery-strategy.md`
- [ ] **Tests:** geofence hysteresis, ETA calc, watchdog SQL, retention job, history RLS

**You configure:** SMS gateway account + secrets, `pg_cron` enabled on the Supabase project.

## Phase 3: Security hardening

- [ ] Circle key rotation on leave, removal or device revocation (race-safe), with tests
- [ ] Fingerprint verification via QR. Key-change warnings
- [ ] Anti-stalkerware: pause UX, honest "Paused" status, periodic sharing reminders, safety guidance screen, mute-but-panic-breaks-through
- [ ] Discreet panic: shake gesture (threshold + confirm window), rapid screen on/off detection while the service runs (no accessibility-service abuse), accidental-trigger protection
- [ ] App lock: PIN + biometrics, auto-lock timeout, lock-screen notification redaction
- [ ] Device management: list devices, remote sign-out, revocation
- [ ] Certificate pinning via `network_security_config.xml` (≥2 pins, expiry), cleartext disabled
- [ ] Mock-location detection flag
- [ ] Rate limiting: invites, alerts, OTP (CAPTCHA), Edge Functions
- [ ] Expand RLS test suite. Run `supabase db lint` and the advisors in CI
- [ ] Finalise `SECURITY.md` with evidence and limitations

## Phase 4: Community layer

- [ ] PostGIS-backed `incident_reports` snapped to ~1 km grid, time-bucketed, k-anonymity threshold for display
- [ ] Neighbourhood watch groups with opt-in radius panic alerts (coarse cell only)
- [ ] Moderation: report abuse, auto-hide on N reports, moderator role and tools, ban
- [ ] Separate consent and privacy-policy section for community features

## Later (not scheduled)

isiZulu, isiXhosa, Sesotho and Afrikaans translations · guardian consent for minors ·
iOS release · Huawei (no-GMS) push alternative · Play Integrity · incident response
runbook · Information Officer registration.
