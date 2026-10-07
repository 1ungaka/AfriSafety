# Building a release for Google Play

## 1. Create your upload key (once, keep it forever)

Google Play identifies your app by this key. **Back it up** (e.g. on a USB
stick and in a password manager). If you lose it you need Google support to
reset it; if someone else gets it they can sign apps as you.

In PowerShell (the `keytool` that comes with Android Studio):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore C:\dev\keys\afrisafety-upload.jks -keyalg RSA -keysize 2048 `
  -validity 10000 -alias upload
```

Make the folder first (`mkdir C:\dev\keys`). Choose a strong password and
answer the questions (your name, "AfriSafety", city, `ZA`). Keep the `.jks`
file **outside** the project folder.

## 2. Tell the build where the key is

Create `C:\dev\AfriSafety\app\android\key.properties` (it is git-ignored):

```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\dev\\keys\\afrisafety-upload.jks
```

(Double backslashes are required.) Without this file, release builds are
signed with the debug key, which Google Play rejects.

## 3. Production settings in `.env`

Make a separate `app\.env.prod` (also git-ignored):

```
APP_ENV=prod
SUPABASE_URL=https://YOUR_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
TILE_URL_TEMPLATE=https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=YOUR_MAPTILER_KEY
AUTH_METHOD=phone
```

Not the OpenStreetMap tile URL: its servers don't allow app traffic at scale.

## 4. Build

```powershell
cd C:\dev\AfriSafety\app
flutter build appbundle --release --dart-define-from-file=.env.prod
```

The file to upload is `build\app\outputs\bundle\release\app-release.aab`.

Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`) for every upload; the
number after `+` must always go up.

## 5. Play Console

Follow `docs/play-store.md` for the store listing, the Data safety form and
the background-location declaration, then upload the `.aab` to an
**internal testing** track first and test it on real phones before going
public.

## 6. Test builds (APK) for direct install

Before the Play Store, testers can install an `.apk` file straight from the
repository's **Releases** page. They follow `docs/install.md`. Every APK must
be signed with the **upload key from step 1**: Android only lets an update
replace the app if it has the same signature, so a lost or changed key forces
everyone to uninstall.

The repository must be **public** for testers to download releases without a
GitHub account.

### 6a. Automatic (recommended): GitHub builds it when you tag

`.github/workflows/release-apk.yml` builds, verifies the signature and
publishes a pre-release. Set it up once:

1. **MapTiler key.** Sign up free at maptiler.com → *API keys* → copy your
   key. Your tile URL is
   `https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=YOUR_KEY`.
   (The workflow refuses the OpenStreetMap tile URL: anyone can download a
   release, which is more than light testing.) In MapTiler you can limit the
   key to your app's package `za.co.afrisafety.app`.
2. **Copy the key file as text.** In **PowerShell**:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\dev\keys\afrisafety-upload.jks")) | Set-Clipboard
   ```
3. On GitHub: your repository → **Settings → Secrets and variables →
   Actions**.
   - **Secrets** tab → *New repository secret*, three times:

     | Name | Value |
     |---|---|
     | `ANDROID_KEYSTORE_BASE64` | paste (Ctrl+V) from step 2 |
     | `ANDROID_KEYSTORE_PASSWORD` | your keystore password |
     | `ANDROID_KEY_PASSWORD` | your key password (often the same) |

   - **Variables** tab → *New repository variable*. These are public (they
     end up inside the app), the same values as your `.env.prod`:

     | Name | Value |
     |---|---|
     | `SUPABASE_URL` | `https://YOUR_REF.supabase.co` |
     | `SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_...` |
     | `TILE_URL_TEMPLATE` | the MapTiler URL from step 1 |
     | `AUTH_METHOD` | `email` (or `phone` once SMS is set up) |

4. **Try it without publishing:** **Actions** tab → *Release APK* → *Run
   workflow*. After about 15 minutes, open the run and download the APK
   under *Artifacts* (it's a zip). Install it on the emulator by dragging the
   `.apk` onto the emulator window.
5. **Publish:** in **Command Prompt or PowerShell**, from `C:\dev\AfriSafety`:
   ```
   git pull
   git tag v0.1.0
   git push origin v0.1.0
   ```
   The tag must match `version:` in `app/pubspec.yaml` (`0.1.0+1` → `v0.1.0`).
   The release appears under **Releases** with the APK, its checksum and the
   signing certificate's fingerprint.

**Next versions:** bump `version:` in `app/pubspec.yaml`, e.g. `0.1.1+2`
(the number after `+` must always go up, or phones refuse the update), commit,
push, then tag `v0.1.1`.

**Why the key in GitHub is acceptable here:** secrets are encrypted, never
shown in logs and never given to workflows started from other people's forks
or pull requests. The workflow deletes the key from the build machine after
use and refuses to publish anything signed with the debug key. The
remaining risk is someone with write access to your repository, which is
only you. Keep the offline backup from step 1 regardless.

### 6b. By hand on your PC

With `key.properties` and `.env.prod` from steps 2–3, in **PowerShell**:

```powershell
cd C:\dev\AfriSafety\app
flutter build apk --release --dart-define-from-file=.env.prod
```

The file is `build\app\outputs\flutter-apk\app-release.apk`. On GitHub:
**Releases → Draft a new release** → choose a tag such as `v0.1.0` (*Create
new tag*) → attach the APK → tick *Set as a pre-release* → *Publish*. (If
you've also done 6a, the workflow then attaches its own build to the same
release.)

### Moving testers to Google Play later

Google Play re-signs apps with its own key (Play App Signing), so the Play
version can't update an APK installed from Releases. Testers uninstall the
test version, install from Play and sign in again. Their Circles hand them
fresh keys automatically (members see a security-code change warning, which
is expected).
