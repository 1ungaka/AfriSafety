# Launch checklist

What stands between "works on the emulator" and "people can rely on it".
✅ = done in the code; ☐ = yours to do (accounts, money, legal).

## Done in the code

- ✅ All four phases (sharing, safety features, hardening, community)
- ✅ Delete my account in the app (Google Play requirement, POPIA s24)
- ✅ Phone-number sign-in, switchable with `AUTH_METHOD=phone` (+27 only)
- ✅ Fingerprint unlock for the app lock
- ✅ Release signing set up (needs your key, see `docs/release.md`)
- ✅ CI builds a release app bundle on every change
- ✅ Signed test APKs published to GitHub Releases when you push a tag
  (`docs/release.md` §6), with an install guide for testers (`docs/install.md`)

## Yours to do

### Accounts and money
- ☐ **Supabase paid plan** (about $25/month). Free projects pause after a
  week without activity, which would silently break the app for everyone.
- ☐ **MapTiler key** (free tier to start) in your production `.env`.
- ☐ **SMS provider for phone sign-in** (Twilio, MessageBird or Vonage) set up
  in Supabase → Authentication → Providers → Phone. Costs per SMS. Turn on
  Supabase's CAPTCHA and SMS rate limits too.
- ☐ **Test APK:** add the GitHub secrets and variables, then tag `v0.1.0`
  (`docs/release.md` §6a). Send testers `docs/install.md`.
- ☐ **Google Play developer account** (once-off $25).
- ☐ Optional: **Firebase push**, so alerts reach closed apps
  (`docs/setup-cloud.md` §4). Strongly recommended before real use.

### Database
- ☐ Run any migrations you haven't yet, newest last:
  `20261007000100_device_revocation.sql`, `20261008000100_community_reports.sql`,
  `20261009000100_account_deletion.sql`.
- ☐ Record them in Supabase's history from a network that allows the CLI:
  `supabase migration repair --status applied <each timestamp>`.

### Legal (POPIA)
- ☐ Fill in the [placeholders] in `docs/privacy-policy.md` (your name,
  address, contact, hosting region) and publish it on a web page.
- ☐ Register as Information Officer with the Information Regulator.
- ☐ Decide the age rule (currently 18+).

### Testing
- ☐ A week on real phones with real people (Samsung + a Tecno/Infinix),
  checking battery, sharing after swipe-away, and SOS delivery.
- ☐ Ask one friend to try to break it (pause, leave, sign out other phones,
  community reports) and note anything confusing.

### Release
- ☐ Create the upload key and `key.properties` (`docs/release.md`).
- ☐ Store listing, Data safety form, background-location video
  (`docs/play-store.md`).
- ☐ Internal testing track first, then production.
