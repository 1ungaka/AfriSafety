# AfriSafety Privacy Policy (draft)

> **Draft for review.** This plain-language draft must be reviewed by
> someone qualified in South African data-protection law before public
> release. Placeholders are in [SQUARE BRACKETS].
>
> Policy version: **1** (the app records which version you agreed to)
> Last updated: 4 October 2026

AfriSafety helps you share your location with people you trust and call
for help in an emergency. Because location data can put people at risk if
it's misused, we collect as little as possible and design the app so that
**we can't read your location even if we wanted to.**

This policy explains what we collect, why, and your rights under the
Protection of Personal Information Act, 2013 (POPIA).

## 1. Who we are

AfriSafety is operated by [LEGAL NAME], [ADDRESS], South Africa.
Information Officer: [NAME], [EMAIL]. You can contact the Information
Officer about anything in this policy.

## 2. What we collect, and why

| What | Why | Can AfriSafety read it? |
|---|---|---|
| Your email address (later: phone number) | To sign you in with a one-time code | Yes |
| The name you choose | So your Circle knows who you are | Yes |
| Your consents, with the date and policy version | To prove you agreed (POPIA s11) | Yes |
| Your phone's public encryption keys | So Circle members can send you encrypted data | Yes (public keys only) |
| A push notification token (optional) | To alert you when someone needs help | Yes |
| Which Circles you're in, and when you joined | To know who may see what | Yes |
| **Your location** (only while sharing is on) | To show it to people you chose | **No: end-to-end encrypted** |
| **SOS alerts and the location in them** | To get help to you | **No: end-to-end encrypted** |
| **Arrive/leave and journey updates** ("arrived at Home") | To tell people who can see your location | **No: end-to-end encrypted** |
| That a check-in timer or journey is running, and when it ends | So we can alert your Circles if you don't check in, even if your phone is off | Yes (the time only, never where you are or where you're going) |
| **Missed check-in alerts** (prepared by your phone when you start a timer) | Released to your Circles only if you don't check in | **No: end-to-end encrypted** |
| Technical data: IP address, times of requests | Running and securing the service | Yes, kept briefly |

Some things never leave your phone at all. They are stored there,
encrypted, and deleted when you sign out:

- your **saved places** (Home, Campus...)
- your **SMS emergency contacts** (names and numbers you type in, with
  their permission)
- your **location history**, if you turn it on (it is off by default)
- your **app-lock PIN** (only a scrambled Argon2id hash of it), which members
  you've verified, and who you've muted

We do **not** collect your phone's contact list, photos, messages,
browsing or anything else on your phone.

### What "end-to-end encrypted" means here

Your location is encrypted on your phone before it is sent. Only the
phones of people you share with hold the keys to decrypt it. Our servers
store and pass on scrambled data they cannot read. If you set someone to
"SOS alerts only", their phone never receives the key for your live
location.

What we *can* see is **metadata**: that you're in a Circle with certain
people, and when your phone sends an update. We use it only to run the
service.

## 3. Location is never collected secretly

- Location is collected only while sharing is on, and Android always shows
  a notification while it is.
- You can pause sharing or leave a Circle at any time with one tap. Nobody,
  including the Circle's owner, can stop you or turn sharing back on for you.
- Nobody can add you to a Circle. You join only by entering an invite code
  yourself.
- Everyone in a Circle is told when someone joins or leaves.

## 4. Who we share data with

We never sell your data or share it with advertisers or data brokers.

We use these service providers (operators under POPIA) to run AfriSafety:

| Provider | What they process | Where |
|---|---|---|
| Supabase (database and sign-in) | Account details, encrypted data, metadata | [REGION, e.g. EU (Frankfurt)] |
| Google Firebase Cloud Messaging (optional push) | Push token, and that a push was sent. The push contains no names or locations | Global |
| Map tile provider [NAME] | Which map area your phone displays, and your IP address | [REGION] |

If you send an SOS **by SMS**, the message (including your location) goes
through your mobile network like any SMS. AfriSafety opens your SMS app
with your emergency contacts filled in; you press send. AfriSafety never
sends SMS by itself.

We will disclose information to law enforcement only when legally required
to, and we can only hand over what we can read (see the table above). We
cannot decrypt your locations or alerts.

## 5. Cross-border transfers (POPIA s72)

Our database may be hosted outside South Africa, in a country with data
protection laws at least as strong as POPIA (e.g. the EU under GDPR). By
agreeing to this policy you consent to this transfer.

## 6. How long we keep data

- **Latest location:** replaced with each update, and deleted when you pause,
  leave the Circle or delete your account.
- **SOS and missed check-in alerts:** kept for 30 days, then deleted.
- **Arrive/leave and journey updates:** 7 days.
- **Check-in timers:** 7 days after they end.
- **Location history:** off unless you turn it on; kept only on your phone
  for 1, 7 or 30 days (your choice); turning it off deletes it.
- **Places and SMS contacts:** on your phone until you delete them or sign
  out.
- **Account data:** until you delete your account.
- **Signing out:** erases this phone's encryption keys and revokes it. It
  stops receiving data straight away.

## 7. Your rights

Under POPIA you can:

- ask what personal information we hold about you, and get a copy
- ask us to correct or delete it
- withdraw consent at any time (this stops sharing, and you may need to
  leave your Circles)
- object to processing
- complain to the **Information Regulator**: inforeg.org.za,
  enquiries@inforegulator.org.za

In-app export and account deletion are coming in a later update. Until
then, email the Information Officer.

## 8. Children

AfriSafety is currently for people aged **18 and older**. A version with
parent or guardian consent for children is planned.

## 9. Security

Besides end-to-end encryption, we use encrypted connections, store keys in
your phone's secure hardware (Android Keystore), switch off cloud backups
of keys, and restrict every database table so people can only see data for
their own Circles. The details are published in our security document:
[LINK TO SECURITY.md].

If a breach affects your personal information, we will tell you and the
Information Regulator as POPIA s22 requires.

## 10. Emergencies

**AfriSafety does not replace emergency services.** In danger, call
**10111** (SAPS) or **112**.

## 11. Changes

If we change this policy in a way that matters, the app will ask you to
review and accept the new version.
