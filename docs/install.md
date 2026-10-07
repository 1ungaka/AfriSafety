# How to install AfriSafety (test version)

AfriSafety isn't in the Play Store yet. While it's being tested you install it
straight from a file. It takes about two minutes.

> **AfriSafety does not replace emergency services.** In danger, call **10111**
> (SAPS) or **112**. This is a test version: don't rely on it as your only way
> to get help.

**You need:** an Android phone with Android 8 or newer, and about 60 MB of
data for the download. iPhones aren't supported yet.

## 1. Download

On your phone, open the
[releases page](https://github.com/1ungaka/AfriSafety/releases) and tap the
newest **AfriSafety-x.y.z.apk** under *Assets*.

Only download it from that page. A copy sent around on WhatsApp could have
been changed by someone else.

## 2. Allow the install (first time only)

Open the downloaded file (from the notification or the **My Files** /
**Files** app). Android will say it isn't allowed to install apps from this
source:

1. Tap **Settings**.
2. Turn on **Allow from this source** (it's for the app you downloaded with,
   e.g. Chrome or My Files).
3. Go back and tap **Install**.

You can turn that setting off again afterwards.

## 3. If Play Protect warns you

Google Play Protect may say the app is unknown or ask you to scan it, because
it didn't come from the Play Store. If you downloaded it from the releases
page above, tap **More details**, then **Install anyway** (or **Scan app**,
then install).

## 4. First start

The app explains each permission before asking:

| Permission | Why |
|---|---|
| Location ("Allow all the time") | So your Circle can see you while sharing is on. You can pause or leave any time, and sharing always shows a notification |
| Notifications | For SOS alerts and the "you are sharing" notice |

Your location is encrypted on your phone before it is sent. The server can't
read it. AfriSafety never reads your contacts or sends SMS by itself.

## Updating

When a new version comes out, download the new APK from the releases page and
install it the same way. It installs over the old one and keeps your data.

If Android says **"App not installed"** or that the package conflicts, the new
file wasn't signed by AfriSafety. Don't force it; tell the developer.

## Removing

Hold the AfriSafety icon → **Uninstall**. To delete your account and data on
the server too, first open the **Safety** tab in the app and tap **Delete my account**.

## Problems or feedback

Open an [issue](https://github.com/1ungaka/AfriSafety/issues) or contact the
developer directly. Never include your location or screenshots of the map in
a public issue.

---

<details>
<summary>For the technical: checking the file is genuine</summary>

Each release page lists the SHA-256 of the signing certificate and a
`SHA256SUMS.txt`. With the Android SDK build tools:

```
apksigner verify --print-certs AfriSafety-x.y.z.apk
```

The `certificate SHA-256 digest` must match the one on the release page.
Android also enforces this on updates: a file signed with a different key
can't replace the installed app.
</details>
