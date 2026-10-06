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
