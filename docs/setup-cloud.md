# Connecting AfriSafety to the cloud (Phase 1)

Phase 1 needs a **Supabase** project (database, sign-in, realtime) and a
**map tile** key. **Firebase** is optional: it adds push alerts when the app
is closed. All three have free tiers.

Commands are for **PowerShell** on Windows, run from `C:\dev\AfriSafety`
unless stated. First pull the latest code:

```powershell
cd C:\dev\AfriSafety
git pull origin claude/safety-app-prompt-ga7xf8
```

---

## 1. Supabase project (about 15 minutes)

### 1.1 Create the project
1. Sign up at **supabase.com** and click **New project**.
2. Name: `afrisafety`. Set a strong database password and save it in a
   password manager.
3. **Region:** pick the closest one with strong data-protection law, e.g.
   *West EU (Ireland)* or *Central EU (Frankfurt)*. Note the region; it goes
   in the privacy policy (POPIA s72, cross-border transfer).
4. Wait for the project to finish setting up.

### 1.2 Push the database schema
```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```
`YOUR_PROJECT_REF` is the code in your project URL
(`https://supabase.com/dashboard/project/<ref>`). `db push` creates every
table, RLS policy and function from `supabase/migrations`.

Check that it worked: **Table Editor** should list `circles`, `devices`,
`location_latest` and the other tables, each with a **RLS enabled** badge.

### 1.3 Configure sign-in (email codes)
Dashboard → **Authentication**:

1. **Sign In / Providers → Email:** enabled. Turn **Confirm email** on.
2. **Emails → Templates:** the app signs in with a 6-digit **code**, not a
   link, so edit **both** the *Confirm signup* and *Magic Link* templates to
   show the code. For example:
   ```html
   <h2>Your AfriSafety code</h2>
   <p>Enter this code in the app: <strong>{{ .Token }}</strong></p>
   <p>It expires in 10 minutes. Never share it with anyone.</p>
   ```
3. **Configuration → Auth settings:** set *Email OTP Expiration* to `600`
   seconds (10 minutes).
4. **Rate limits:** keep the defaults or tighten them.

> **Email delivery:** Supabase's built-in email only sends to members of
> your Supabase team, and only a few emails per hour. That's fine for
> testing with your own address. Before family or friends can sign up, add
> a custom SMTP provider (e.g. Resend or Brevo free tier) under
> **Authentication → Emails → SMTP settings**.

### 1.4 Get the app keys
Dashboard → **Project Settings → API Keys**. Copy:
- **Project URL** (e.g. `https://abcd1234.supabase.co`)
- **Publishable key** (`sb_publishable_…`). It's safe to put in the app,
  because RLS protects the data.

Never put the **secret / service_role** key in the app.

---

## 2. Map tiles (about 5 minutes)

The OpenStreetMap Foundation's own tile servers don't allow app traffic,
so use a provider with a free tier. **MapTiler** is one:

1. Sign up at **maptiler.com** and go to **Account → API keys**.
2. Your tile URL is:
   ```
   https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=YOUR_KEY
   ```
3. In MapTiler, restrict the key to your app if the option is offered.

(Stadia Maps and Thunderforest work too. Use any `{z}/{x}/{y}` raster URL.)

---

## 3. Point the app at the cloud

Edit `app\.env` (Notepad is fine; keep the file name exactly `.env`):

```
APP_ENV=dev
SUPABASE_URL=https://YOUR_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
TILE_URL_TEMPLATE=https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=YOUR_KEY
```

Then run it:
```powershell
cd C:\dev\AfriSafety\app
flutter pub get
flutter run --dart-define-from-file=.env
```

You don't need `adb reverse` any more: the cloud URL is HTTPS.

**Test the whole flow with two phones** (or one phone plus a friend's):
1. Sign in with an email code, accept the consents, enter a name and allow
   location ("Allow all the time").
2. Phone A: **Circle → Create a Circle** → share the invite code.
3. Phone B: **Join with a code** → check the preview → **Join**.
4. Both phones should appear on each other's map within a few seconds.
5. On phone A, open **Circle**, switch phone B to *SOS alerts only*. Phone B
   now shows "Shares SOS alerts only with you" for A.
6. Press **SOS** on one phone and let the countdown finish. The other phone
   (with AfriSafety open) shows the full-screen alert, and the sender's
   screen shows *Delivered*, then *Seen*.

---

## 4. Optional: push alerts with Firebase (about 15 minutes)

Without this, alerts arrive only while the other person has AfriSafety open.

### 4.1 Firebase project and app
1. Go to **console.firebase.google.com** → **Add project** → name it
   `afrisafety`. Turn Google Analytics **off** (not needed, and it collects
   data).
2. **Add app → Android**. Package name: `za.co.afrisafety.app`.
3. Download `google-services.json`. You don't add it to the project, you
   just read four values from it:

| `app\.env` key | Where in google-services.json |
|---|---|
| `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |
| `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |

Add those four lines to `app\.env`, then delete the downloaded file. It's
already git-ignored, but there's no need to keep it.

### 4.2 Let Supabase send pushes
1. Firebase console → **Project settings → Service accounts → Generate new
   private key**. This downloads a JSON file. It is a **secret**: never
   commit it or put it in the app.
2. Store it as a Supabase secret and deploy the function:
   ```powershell
   $sa = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\afrisafety-firebase-adminsdk.json"))
   supabase secrets set FCM_SERVICE_ACCOUNT_B64=$sa
   supabase functions deploy dispatch-alert
   ```
   (Change the file name to match your download.)
3. Delete the JSON file from Downloads once the secret is set.
4. Rebuild the app (`flutter run --dart-define-from-file=.env`). With
   AfriSafety closed on phone B, an SOS from phone A now shows a
   notification: *"AfriSafety emergency alert. Someone in your Circle needs
   help."* The notification never contains names or locations.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| No email arrives | Check spam. Built-in email only reaches Supabase team members (see 1.3). Check **Authentication → Logs** |
| Email has a link but no code | Edit both templates to include `{{ .Token }}` (1.3) |
| "That code didn't work" | Codes expire after 10 minutes and work once. Request a new one |
| Map is grey, but members are listed | Check `TILE_URL_TEMPLATE` and your MapTiler key. The list view works without tiles |
| Member shows "Waiting for keys from their phone" | Their phone hasn't been online since you joined. Opening AfriSafety on it hands over the keys |
| Sharing stops after swiping the app away | Known Phase 1 limitation. Keep the app in recents. Fixed in Phase 2 (headless background service) |
| `supabase db push` fails | Run `supabase link` again, and check the database password |
