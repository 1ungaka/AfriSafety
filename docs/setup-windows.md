# Setting up AfriSafety on Windows

A step-by-step guide for Windows 10/11 (64-bit). Plan for 1–2 hours, mostly
waiting for downloads (about 15 GB in total). Use **PowerShell** for every
command (Start menu → type "PowerShell"). Steps marked **(Admin)** need
"Run as administrator".

> **PowerShell, not Command Prompt.** The prompt must start with `PS`, e.g.
> `PS C:\Users\you>`. Command Prompt (`C:\Users\you>` with no `PS`) can't run
> these commands. Paste only the commands from the grey boxes, never error output.

After each step that changes your PATH, **close and reopen PowerShell**,
otherwise new commands won't be found.

---

## 0. Check your PC

- **Windows 10 (22H2) or 11, 64-bit.**
- **RAM:** 8 GB works if you test on a real phone. With 16 GB you can also run
  the Android emulator alongside Docker.
- **Free disk space:** about 40 GB on `C:`.
- **Virtualisation on:** Task Manager → Performance → CPU → "Virtualization:
  Enabled". If it says Disabled, turn on Intel VT-x / AMD-V (SVM) in your BIOS.
  Docker needs it.

## 1. Turn on Developer Mode

Flutter needs it to build apps that use plugins.

```powershell
start ms-settings:developers
```
Switch **Developer Mode** on.

## 2. Git for Windows

Git downloads the code. Its `bash` is also needed to compile the encryption
library (libsodium) for Android.

```powershell
winget install --id Git.Git -e --source winget
```

Add Git's `bin` folder (and Flutter's, for step 4) to your PATH. It must end in
`\bin`; just `\Git` won't work. This block is safe to run more than once:

```powershell
$p = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($d in "C:\Program Files\Git\bin", "C:\dev\flutter\bin") { if ($p -notlike "*$d*") { $p += ";$d" } }
[Environment]::SetEnvironmentVariable("Path", $p, "User")
```

Reopen PowerShell, then check:
```powershell
git --version
where.exe bash     # one line must be C:\Program Files\Git\bin\bash.exe
```
Typing `bash` on its own may start WSL's bash (`C:\Windows\System32\bash.exe`)
and print a WSL message. That's fine: the libsodium build skips WSL's bash and
uses Git's, as long as Git's appears in the `where.exe` list.

## 3. Scoop, make and the Supabase CLI

Scoop is a small package manager. It installs `make` (needed for the libsodium
build) and the Supabase CLI. Use a **normal** (not administrator) PowerShell:
Scoop refuses to install from an admin window.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

scoop install main/make
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

Check:
```powershell
make --version
supabase --version
```

## 4. Flutter

Install Flutter in a short path with no spaces. Long paths break the libsodium
build.

```powershell
mkdir C:\dev
git clone https://github.com/flutter/flutter.git -b stable C:\dev\flutter
```
(`C:\dev\flutter\bin` was already added to PATH in step 2.)

Reopen PowerShell:
```powershell
flutter --version          # first run downloads the Dart SDK; expect 3.47.x
flutter config --no-analytics
```

## 5. Android Studio and the Android SDK

```powershell
winget install --id Google.AndroidStudio -e --source winget
```

1. Open Android Studio and choose **Standard** in the setup wizard. It downloads
   the Android SDK.
2. On the welcome screen: **More Actions → SDK Manager → SDK Tools** tab. Tick
   **Show Package Details**, then tick:
   - **Android SDK Command-line Tools (latest)**
   - **Android SDK Platform-Tools**
   - **NDK (Side by side) → 28.2.13676358** (needed to compile libsodium).
     Gradle can't install it automatically any more: Google replaced
     `sdkmanager` with the new Android CLI, which fails with
     `Package ndk not found`.
   - **CMake** (latest)

   Then **Apply**.
3. Optional: **Plugins → Flutter** (also installs Dart) if you want to code in
   Android Studio. VS Code with the Flutter extension works too.

Back in PowerShell:
```powershell
flutter doctor --android-licenses     # press y to accept each licence
flutter doctor
```

You want green ticks for **Flutter** and **Android toolchain**. You can ignore
"Visual Studio – develop Windows apps" (only needed for step 10) and "Chrome".

## 6. Docker Desktop (runs Supabase locally)

Docker needs **virtualisation enabled in your firmware** (step 0). If WSL says
`virtualisation is not enabled` or `HCS_E_HYPERV_NOT_INSTALLED`: open Settings →
System → Recovery → Advanced startup → **Restart now** → Troubleshoot → Advanced
options → **UEFI Firmware Settings**, enable **Intel Virtualization Technology
(VT-x)** or **AMD SVM Mode**, then save and exit (usually F10).

Can't enable it (e.g. a locked work laptop)? Skip steps 6 and 8 and use a free
hosted Supabase project at supabase.com instead. A real phone doesn't need
virtualisation.

**(Admin)** PowerShell:
```powershell
wsl --install
```
Restart your PC. Then, in normal PowerShell:
```powershell
winget install --id Docker.DockerDesktop -e --source winget
```
Open **Docker Desktop**, accept the terms (free for personal and educational
use) and keep the default **WSL 2** engine. Wait until it says "Engine running".

Check:
```powershell
docker run hello-world
```

## 7. Get the code

```powershell
cd C:\dev
git clone https://github.com/1ungaka/AfriSafety.git
cd AfriSafety
git checkout claude/safety-app-prompt-ga7xf8
```
Keep the project at `C:\dev\AfriSafety`. Deeper paths can break the build.

## 8. Start the backend

Docker Desktop must be running.

```powershell
cd C:\dev\AfriSafety
supabase start        # first run downloads several GB of images
supabase test db      # security tests; expect "All tests successful"
```

`supabase start` prints a table. Copy the **Publishable key** (it starts with
`sb_publishable_`; older CLIs call it the "anon key"). You'll need it next.
Stop the stack with `supabase stop` when you're done for the day.

## 9. Run the app on your phone

### Prepare the phone (Android 8 or newer)
1. **Settings → About phone →** tap **Build number** 7 times to unlock Developer
   options.
2. **Settings → Developer options →** turn on **USB debugging**.
3. Plug the phone in with a data cable, set USB mode to **File transfer**, and
   tap **Allow** on the "Allow USB debugging?" prompt.
4. Tecno, Infinix, Xiaomi and Oppo phones: also turn on **Install via USB** in
   Developer options.

Check that Flutter sees it:
```powershell
flutter devices
```
If it doesn't show up, install your phone maker's USB driver (e.g. Samsung USB
Driver) and replug.

### Configure and run
```powershell
cd C:\dev\AfriSafety\app
copy .env.example .env
notepad .env
```
In Notepad, paste the Publishable key after `SUPABASE_PUBLISHABLE_KEY=` and change
`SUPABASE_URL` to `http://127.0.0.1:54321`. Save and close.

Forward the phone's port 54321 to your PC over USB. This lets the app reach
your local Supabase without exposing it on Wi-Fi. Repeat it each time you
replug the phone:
```powershell
adb reverse tcp:54321 tcp:54321
```
(If `adb` isn't found, it lives in
`%LOCALAPPDATA%\Android\Sdk\platform-tools`. Add that folder to your PATH the
same way as before.)

Run it:
```powershell
flutter pub get
flutter run --dart-define-from-file=.env
```

The **first build takes 10–20 minutes** (about 8½ minutes on a typical laptop): Gradle downloads, the Android NDK
installs, and libsodium compiles for each phone CPU type. Later builds take
under a minute. You should see the Circle icon and the AfriSafety home screen.

## 10. Optional: run the tests on Windows

GitHub runs the tests on every push, so this is optional. To run
`flutter test` on your PC, libsodium must compile for Windows itself, which
needs Microsoft's C++ compiler (about 7 GB):

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget
```
Open **Visual Studio Installer → Modify**, tick **Desktop development with C++**,
then install. After that:
```powershell
cd C:\dev\AfriSafety\app
flutter test
```

---

## Troubleshooting

| Error | Fix |
|---|---|
| `No usable bash.exe found on Windows` | `C:\Program Files\Git\bin` is missing from PATH (step 2). Reopen PowerShell after adding it |
| `make: command not found` / `make` not recognised | `scoop install main/make`, then reopen PowerShell |
| Path too long, or `cannot open source file` during the libsodium build | Move the project to `C:\dev\AfriSafety` |
| `Building with plugins requires symlink support` | Turn on Developer Mode (step 1) |
| `bash` prints a WSL / virtualisation error | Harmless for the build if `where.exe bash` lists Git's bash. Virtualisation is still needed for Docker (step 6) |
| `supabase start` says Docker isn't running | Open Docker Desktop and wait for "Engine running". If WSL errors appear, run `wsl --update` |
| Port 54321 already in use | `supabase stop`, then `supabase start` again |
| Phone missing from `flutter devices` | Use a data cable (not charge-only), accept the USB debugging prompt, install the OEM driver |
| `Android sdkmanager did not install NDK 28.2.13676358` / `Package ndk not found` | Install **NDK (Side by side) 28.2.13676358** in Android Studio's SDK Manager (step 5) |
| `Android SDK file not found: ...build-tools\36.1.0\aapt` | SDK Manager → SDK Tools → Show Package Details → reinstall **Android SDK Build-Tools 36.1.0** |
| `flutter devices` doesn't list the phone | Run `adb devices`. If it says `unauthorized`, accept the prompt on the phone. If it's empty, check the cable, USB mode (File transfer) and the OEM driver |
| `[sodium] WARNING: configure: ... signal handlers` | Harmless. libsodium's configure step is working |
| "Skipped N frames" in the log of a debug build | Normal for debug. Use `flutter run --release` to judge real speed |
| Build fails in a `sodium` step | Copy the whole error text and send it to Claude. Cross-compiling libsodium on Windows is the most fragile step |
