# Google Play: listing, Data safety and permissions (draft)

Draft answers for the Play Console. Check them against the current forms
before submitting; Google changes the wording often.

## Store listing

- **App name:** AfriSafety
- **Short description (80 chars):** Share your location with family, privately. SOS, check-ins, walk me home.
- **Full description:** start with what it does, then the privacy promise:
  locations are end-to-end encrypted, sharing always shows a notification,
  anyone can pause or leave at any time, no ads, no tracking SDKs.
  End with: "AfriSafety does not replace emergency services. In danger, call 10111 or 112."
- **Category:** Lifestyle (or Tools). **Contact email:** required.
- **Privacy policy URL:** required. Publish `docs/privacy-policy.md` (with
  the [placeholders] filled in) on a public page, e.g. GitHub Pages.

## Content rating and audience

- Target audience: **18+** (D4). Not designed for children.
- Questionnaire: user-to-user communication = **yes** (location sharing,
  alerts, community reports).

## Data safety form

| Data type | Collected? | Shared? | Notes for the form |
|---|---|---|---|
| Precise location | Yes | No | End-to-end encrypted in transit; only the user's chosen Circle members can read it. Optional (sharing can be paused). Purpose: app functionality |
| Approximate location | Yes | No | Community reports only (optional, ~1 km square). Purpose: app functionality |
| Email address / phone number | Yes | No | Sign-in. Purpose: account management |
| Name | Yes | No | Display name shown to Circle members |
| Contacts | No | No | SMS emergency contacts are typed in and stay on the phone (never uploaded) |
| App activity, diagnostics, device IDs | No | No | No analytics or crash SDKs |

- Data is encrypted in transit: **yes**.
- Users can request deletion: **yes**, in the app (Safety → Delete my account).
- Data deletion URL (if asked for a web link): a page explaining the
  in-app steps, or an email address that handles requests.

## Permissions declarations

**Background location (`ACCESS_BACKGROUND_LOCATION`)** needs a declaration
and a short video.

- Core feature: "Sharing your live location with family members you choose,
  including while the app is in the background, so they can find you in an
  emergency, and noticing when you arrive home or miss a check-in."
- Prominent disclosure: the onboarding screen explains this before the
  Android prompt (Play policy). Show it in the video.
- Video (30 s): onboarding disclosure → "Allow all the time" → the
  persistent "AfriSafety is sharing your location with N people"
  notification → another phone seeing the location → Pause.

**Foreground service type `location`:** same justification; the
notification is always visible while location is collected.

**Not requested:** SMS, call log, contacts, camera, microphone.

## Before going public

- [ ] Internal testing track with at least a few real phones for a week
- [ ] Battery behaviour checked on Samsung and a Tecno/Infinix phone
- [ ] Privacy policy published with real name and contact details
- [ ] Information Officer registered with the Information Regulator (POPIA)
