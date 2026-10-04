# AfriSafety: Security

> Status: **Threat model v1 (approved). Phase 1 implemented; see §8 for what is
> in place and the test that proves each item.** Phase 3 updates this file with
> implemented mitigations, test evidence and known limitations.

## Reporting a vulnerability

Please do **not** open a public issue. Email the maintainer (see the GitHub
profile) with steps to reproduce. You'll get an acknowledgement within 7 days.

---

## 1. What we protect

| Asset | Why it matters |
|---|---|
| Real-time and historical location | Physical safety. Reveals home, school, routine |
| Places (Home, School, Work) | Same as above, permanently |
| Circle membership graph | Reveals family and social relationships |
| Emergency contacts' phone numbers | Third-party personal information (POPIA) |
| Panic alerts | Availability is safety-critical. Integrity matters (false alarms, suppression) |
| Device private keys and Circle keys | Compromise means reading all E2EE data |
| Account credentials and sessions | Account takeover leads to joining Circles as the victim |

## 2. Adversaries

| # | Adversary | Capability | Goal |
|---|---|---|---|
| A1 | **Abusive partner or family member (insider)** | Physical access to victim's phone (may know PIN), is or was a Circle member, can coerce | Covert tracking, preventing the victim from leaving or pausing |
| A2 | **Stalker or stranger** | Network attacker, may guess invite codes, may social-engineer | Join a Circle, track a target |
| A3 | **Thief or finder of a phone** | Physical possession, no PIN (or shoulder-surfed PIN) | Read Circle members' locations, impersonate the owner |
| A4 | **Compromised or malicious server** | Full DB read/write, can modify served data, sees metadata | Read locations, inject keys, suppress or forge alerts |
| A5 | **Malicious Circle member** | Legitimate member of a Circle | Spoof location, spam alerts, harvest history, retain access after leaving |
| A6 | **Network attacker** | Wi-Fi/MITM, rogue CA on device | Intercept or modify traffic |
| A7 | **Third-party services** (FCM, SMS gateway, tile provider) | See what we send them | Profiling, data mining |
| A8 | **Spammer or abuser at scale** | Scripts, many accounts | OTP pumping (SMS cost), invite brute force, community-report abuse |

## 3. Trust boundaries

1. Device ↔ Supabase (TLS + pinning; server is **untrusted for confidentiality**)
2. Supabase ↔ Edge Function ↔ FCM / SMS gateway (FCM sees an opaque ID; SMS gateway sees opt-in plaintext)
3. App ↔ OS (Keystore, other apps, accessibility services, backups)
4. Circle member ↔ Circle member (members are trusted with *current* location only while they are members)

---

## 4. STRIDE analysis

Legend: **M** = mitigation (phase it lands in), **R** = residual risk.

### Spoofing

| Threat | Adv. | Mitigation | Residual |
|---|---|---|---|
| Attacker logs in as victim (SIM swap for phone OTP, phished email OTP) | A2 | Supabase Auth OTP with rate limits (P1). New device login creates a `security_events` entry and a push to other devices (P1). New devices get **no Circle keys until an existing member device seals them**, so they see nothing historical (P1). App lock (P3) | SIM swap is a real risk in SA. Email OTP plus a recovery code (later) reduces it |
| Server injects its own public key as a "member device" to receive Circle keys | A4 | TOFU fingerprints with key-change warnings (P1). In-person QR fingerprint verification (P3). Envelopes signed by sender device (P1) | Users who never verify are exposed to an active malicious server. Documented |
| Malicious member spoofs their location | A5 | Out of scope to prevent cryptographically (device controls GPS). Detect mock-location provider on Android and flag "location may be simulated" (P3) | Rooted devices can bypass |
| Forged panic alert | A4, A5 | Alerts are AEAD-encrypted with the sender's alert key, and the AAD binds context, Circle, sender and key version, so the server cannot forge or relabel them (P1). Members can still send real-but-false alerts, handled by rate limits and moderation (P3) | — |

### Tampering

| Threat | Adv. | Mitigation | Residual |
|---|---|---|---|
| Server swaps ciphertext between users or Circles, or replays old locations | A4 | AEAD with AAD = `circle_id ‖ user_id ‖ key_version`, plus a `recorded_at` timestamp inside the ciphertext so clients reject stale or rolled-back fixes (P1) | Server can withhold updates (see DoS) |
| MITM modifies traffic | A6 | TLS 1.2+, Android `network_security_config` pinning to ≥2 CA SPKI hashes with backup pins, cleartext disabled, user-installed CAs not trusted in release (P3) | Pin rotation risk. Mitigated by backup pins and an expiry |
| Tampered APK (repackaged with tracking) | A1, A2 | Distribute via Play Store only. Optional Play Integrity check on sign-up (later) | Sideloaded malicious clones |

### Repudiation

| Threat | Adv. | Mitigation | Residual |
|---|---|---|---|
| "I never joined that Circle" / "I never sent that alert" | A5 | `consents` with timestamps and policy version (P1). `security_events` audit trail visible to the user (P1). Signed envelopes (P1) | — |

### Information disclosure

| Threat | Adv. | Mitigation | Residual |
|---|---|---|---|
| DB breach reveals locations | A4 | E2EE: locations, places, alerts and journeys are ciphertext (P1 basic, P3 rotation). Server never holds Circle keys | **Metadata is visible:** membership graph, timestamps, update frequency, IP addresses, phone numbers/emails |
| Non-member reads a Circle's data via the API | A2 | RLS deny-by-default on every table. `is_circle_member()` helper. **pgTAP tests prove non-members get zero rows** (P1, expanded P3). Invite codes stored as hashes | RLS bugs. Mitigated by tests in CI |
| Departed member keeps reading | A1, A5 | RLS removes access immediately on leave. Per-sender key rotation on leave, device revocation or downgrade to "SOS only" (**P1**, D7). Local key wipe on leave (P1) | A departed member who copied data while a member keeps that data |
| Lost or stolen phone exposes Circle | A3 | App lock with PIN or biometrics plus timeout (P3). Keys in Keystore-backed storage (P1). `android:allowBackup="false"` and excluded from cloud backup (P1). Sign-out revokes the device and wipes its keys, and members rotate away from it (**P1**). Revoking a lost phone *from another device* (P3). Location not shown in notifications on the lock screen (P1) | Unlocked phone in an attacker's hands |
| Location leaks via logs or crash reports | A7 | `SafeLogger` wrapper that redacts coordinate types. Lint ban on raw `print`/`debugPrint` in `lib/`. No third-party analytics or crash SDK in MVP (P1) | — |
| FCM learns content | A7 | Data-only push carrying an opaque alert ID. Content fetched and decrypted on device (P1) | Google sees push timing and frequency |
| SMS gateway learns location | A7 | Opt-in per contact with explicit consent. Sent only for alerts. Not stored server-side (P2) | Gateway and carriers see SMS contents. Documented |
| Tile provider learns where you look | A7 | Tile caching. Data-saver list mode with no tiles (P1) | Viewport plus IP visible to provider |
| Community reports de-anonymise reporters | A2 | ~1 km grid snapping, time bucketing, no user ID on public rows, minimum k reports before display in sparse areas (P4) | Rural sparse areas. Higher k there |

### Denial of service

| Threat | Adv. | Mitigation | Residual |
|---|---|---|---|
| Panic alert not delivered (no data, FCM down, server down) | env, A4 | Idempotent retries until ack. On-device SMS intent fallback (P1/P2). Server-side SMS to contacts (P2). Delivery receipts shown to sender (P1). 10111/112 quick-dial always visible (P1) | A malicious server can drop alerts. SMS-from-phone path does not depend on us |
| OS kills background service | env | Foreground service. OEM-specific battery-optimisation guide. "Last updated" staleness shown honestly (P1) | Aggressive OEMs. Test on real Tecno, Samsung and Xiaomi devices |
| OTP pumping (SMS cost fraud) | A8 | Supabase Auth rate limits plus CAPTCHA (hCaptcha/Turnstile) on OTP request. Restrict phone OTP to +27 initially (P1/P3) | — |
| Invite code brute force | A8 | ~50-bit codes, 48 h expiry, max uses, per-user and per-IP rate limit on redemption (P1/P3) | — |
| Alert spam by a member | A5 | Rate limit: 30 alert rows/hour/user, and each alert pushed at most once (**P1**), and any member can mute another for 24 h, **except** that panic alerts always break through mute (P3) | — |

### Elevation of privilege

| Threat | Adv. | Mitigation | Residual |
|---|---|---|---|
| Circle owner forces a member to share, hides their pause, or blocks leaving | A1 | **No such capability exists in the data model.** `sharing_paused` and leaving are writable only by the member themself (RLS `user_id = auth.uid()`). Owner can remove members but never control them (P1) | — |
| Client calls privileged functions | A2 | Service role key only in Edge Functions. RPCs are `SECURITY INVOKER` unless explicitly reviewed. `SECURITY DEFINER` functions pin `search_path` and live in a non-exposed `private` schema (P1) | — |
| Malicious app on device reads our data | — | Keystore-backed keys. No exported components except the deep-link activity. No world-readable files (P1) | Rooted devices |

---

## 5. Anti-stalkerware design (A1 focus)

Location-sharing apps are routinely misused by abusive partners. AfriSafety treats
this as a **primary** threat, not an edge case:

1. **Never silent.** Collection only happens inside a foreground service with a
   persistent notification ("Sharing location with Family (4)"). There is no
   "hidden mode", no icon hiding, and no remote enable. *(P1)*
2. **Consent belongs to the phone owner.** Sharing starts only after the person on
   that phone accepts an invite and completes the consent screen. No one can add
   you to a Circle. *(P1)*
3. **Pause and Leave are sovereign.** One tap, works offline (enforced locally first,
   synced later), cannot be blocked, delayed or require approval. *(P1 Leave, P3 Pause UX)*
4. **Honest status.** When paused, others see "Paused". We never offer deceptive
   features like "freeze my location", because they create danger when discovered. *(P3)*
5. **Reminders.** Periodic notifications: "You are sharing your location with 6
   people in 2 Circles. Review?" (default weekly). *(P3)*
6. **Join notifications.** Everyone in a Circle is notified when someone joins or a
   member's device key changes. *(P1)*
7. **Safety exit.** The settings screen links to "Think someone is tracking you?"
   guidance, with South African helplines (e.g. the GBV Command Centre). *(P3)*
8. **App lock doesn't hide sharing.** The notification stays visible even when the
   app is locked. *(P3)*

**Known limitation:** someone with the unlocked phone and enough time can install
the app, join a Circle and accept consent on the victim's behalf. Mitigations 1, 5
and 6 make this discoverable, not impossible.

## 6. POPIA considerations (summary)

- **Lawful basis:** consent (s11(1)(a)), recorded with timestamp and policy version.
- **Children (s34–35):** processing a child's information needs consent from a
  competent person. Recommendation: **18+ only for the MVP**. Add a guardian-consent
  flow in a later phase.
- **Minimality (s10):** see the data model's plaintext column audit in
  `docs/architecture.md` §3.
- **Retention (s14):** history defaults to 7 days (max 30), deleted by `pg_cron`.
  Account deletion is a hard delete with cascades.
- **Data subject rights (s23–25):** in-app export (JSON, decrypted on device) and
  delete.
- **Security safeguards (s19):** this document.
- **Breach notification (s22):** incident-response checklist in a later phase.
- **Cross-border transfer (s72):** see architecture §8 (hosting region).
- **Information Officer:** register with the Information Regulator before public
  launch.

## 7. Known limitations

- Metadata (who is in which Circle, when they update, IPs) is visible to the server.
- Users who never verify fingerprints are vulnerable to an actively malicious server.
- SMS fallback reveals location to the SMS gateway and mobile carriers.
- Phones without Google Play Services do not receive push alerts.
- A Circle member can always screenshot or remember your location while they are a member.
- Location spoofing by a member can be flagged but not prevented.
- **Phase 1:** location sharing runs while the app's process is alive (the
  foreground service keeps it alive in the background). If the user swipes the app
  away, sharing stops until it's reopened. A headless background service comes in
  Phase 2.
- **Phase 1:** push notifications are generic ("Someone in your Circle needs
  help"), and a "delivered" receipt is recorded once the recipient's app has fetched
  the alert, not when the push arrives.
- **Phase 1:** envelope signatures are verified against device keys served by the
  server (trust on first use). QR fingerprint verification is Phase 3.

## 8. Phase 1: implemented controls and evidence

| Control | Where | Proven by |
|---|---|---|
| RLS on every public table; signed-out users have no access; every SECURITY DEFINER function pins `search_path` | all migrations | `supabase/tests/database/000_foundations.test.sql` (catalog-wide, so new tables are covered automatically) |
| Outsiders see zero rows in every Circle table; cannot write as others or into Circles they're not in | `20261004000200/300` | `010_circles_rls.test.sql` (89 assertions acting as owner, members and an outsider) |
| Pause and leave are sovereign; the owner can't pause, unpause or remove members directly | `circles` migration | `010`: "the owner cannot change another member's pause state", "members cannot be removed with a direct delete", "Bob leaves without anyone's approval" |
| Joining needs the invitee's own consent; everyone is told about joins and leaves | `accept_invite`, `leave_circle` | `010`: "joining requires consent first", "Alice is told each time someone joins" |
| Invite codes hashed, expiring, brute-force limited (wrong guesses counted) | `circle_invites`, `preview_invite` | `010`: "the 11th attempt in an hour is rate limited". (An early version rolled the counter back on wrong codes; the test caught it) |
| Server holds only ciphertext; AAD binds context, Circle, sender, version | `PayloadCipher`, `CircleAad` | `payload_cipher_test.dart`: relabel / move / version / context swaps all rejected; any flipped bit rejected |
| Per-sender keys (D7): SOS-only viewers never get the location key; leavers and revoked phones can't read new data; server-injected keys rejected | `planKeySync`, `KeySyncService` | `key_sync_plan_test.dart`, `key_sync_service_test.dart` (end-to-end over a fake server that mirrors RLS) |
| Envelope signature binds Circle, channel, version, sender and recipient | `KeyEnvelopeService` | `key_envelope_test.dart` |
| Session refresh token kept in Keystore-backed storage, not SharedPreferences | `SecureSessionStorage` | code review |
| Sign-out revokes the device and wipes keys | `DeviceRepository.revokeAndWipe` | code review |
| No location in logs; no `print`; no SEND_SMS / CALL_PHONE; HTTPS-only; backups off; location only via foreground service | `SafeLogger`, manifest | `security_rules_test.dart`, `safe_logger_test.dart` |
| Push carries no personal data; each alert pushed once, only by its sender, within 10 minutes | `dispatch-alert` | `supabase/functions/tests/dispatch_alert_test.ts`; `010`: "clients cannot set dispatched_at" |

