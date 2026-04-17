# FLASH.md — Cousin's step-by-step (two paths)

**Goal:** turn any supported Android 12+ phone into a DevBox in 15–30 minutes.

**Two device paths**, both documented below:

| Path | Device examples | Bootloader | Root? | Initial flash |
| --- | --- | --- | --- | --- |
| **A — Rooted Pixel** | Pixel 6, 7, 8, 8 Pro, 9 | Unlockable | ✅ Magisk | [flash.android.com](https://flash.android.com) + init_boot patch |
| **B — Locked Samsung** | Galaxy S20 FE Verizon, most carrier-locked | Locked (permanent) | ❌ | Factory reset + bloatware strip |

Both paths converge at **step 5 (Termux provisioning)** and are identical from that point on.

## Shared prerequisites

- A **PC with ADB installed** (Android SDK platform-tools — place at `C:\platform-tools` on Windows, `/usr/local/bin` on macOS/Linux)
- A **USB-C cable** (USB 3+ preferred — USB 2 works but flashing is 3× slower)
- This repo cloned locally
- WiFi for initial provisioning
- Phone with battery ≥ 50%

---

## Path A — Rooted Pixel (Pixel 6+ on unlockable bootloader)

### A1. Unlock bootloader (one-time per device, ~5 min)

1. Phone: **Settings → About phone** → tap **Build number** 7 times → Developer options enabled.
2. Phone: **Settings → System → Developer options** → **OEM unlocking** → ON.
3. Reboot to bootloader: `adb reboot bootloader` (phone must be connected with USB debugging on).
4. Unlock: `fastboot flashing unlock` → on-phone, volume keys to select "Unlock the bootloader", power to confirm. **This wipes the device.**
5. Reboot: `fastboot reboot`. Re-do the initial Android setup wizard.

### A2. Flash stock Android via Flash Tool (~15 min)

1. **Kill any running ADB server first:** `adb kill-server` (Flash Tool uses WebUSB, which can't share the USB handle).
2. Install the **Google USB driver** on Windows (`R:\Downloads\Delete Later\google_usb_driver\usb_driver\` or [download](https://developer.android.com/studio/run/win-usb)).
3. Open **Chrome or Edge** → go to [flash.android.com](https://flash.android.com).
4. Click **Add new device** (or select your plugged-in phone from the list).
5. Select the latest stable build for your device (e.g., `shiba-user BP4A.251205.006` for Pixel 8).
6. **Toggle settings — exactly these:**
   - Wipe Device: ✅ **ON**
   - Lock Bootloader: ❌ **OFF** (critical — locking with custom init_boot bricks device)
   - Force Flash all Partitions: ✅ **ON** (ensures init_boot gets rewritten fresh on both slots)
   - Disable Verity: ❌ OFF (leave default)
   - Disable Verification: ❌ OFF (leave default)
   - Skip Secondary: ❌ OFF (flash both A/B slots)
7. Click **Install**. Approve browser's USB permission prompt. Phone auto-reboots to fastboot and flashing begins.
8. **Don't unplug or close the browser tab.** ~15 min on USB 2, ~5 min on USB 3+.
9. Phone reboots into Android 16 setup wizard. Sign in with any Google account (needed for Play Store). Skip everything else.

### A3. Enable USB debugging + Install via USB

On the fresh Android install:
1. Settings → About phone → tap **Build number** 7 times.
2. Settings → System → Developer options:
   - **USB debugging** ON
   - **Install via USB** ON (required for `adb install` in later steps — default OFF on fresh installs)
   - **OEM unlocking** ON (should already be — confirms we can re-unlock if needed)
3. Plug USB, approve "Allow USB debugging" prompt on phone, check **"Always allow from this computer"**.

### A4. Root via Magisk (~5 min)

1. **Extract init_boot.img from the factory zip** on your PC:
   ```bash
   # The factory zip contains an inner image zip
   cd R:/Downloads/"Delete Later"
   unzip -o shiba-factory.zip -d shiba-extract/
   cd shiba-extract/shiba-*
   unzip -o image-shiba-*.zip init_boot.img -d .
   cp init_boot.img R:/Downloads/"Delete Later"/init_boot.img
   ```
2. **Download Magisk v30.7 APK** (or latest):
   ```bash
   curl -L -o Magisk.apk \
     https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk
   ```
3. **Install Magisk and push init_boot.img to the phone:**
   ```bash
   adb install Magisk.apk
   MSYS_NO_PATHCONV=1 adb push init_boot.img /sdcard/Download/init_boot.img
   ```
   (The `MSYS_NO_PATHCONV=1` prefix is only needed on Git Bash for Windows — it disables path translation that would mangle `/sdcard/...` into a Windows path.)
4. **On the phone:**
   1. Open the **Magisk** app.
   2. At the top, **Magisk** row → **Install**.
   3. Method → **Select and Patch a File**.
   4. Navigate to Downloads → tap **init_boot.img**.
   5. Tap **LET'S GO** (arrow icon top-right). Wait ~30 sec for "All done!"
   6. Patched file saved to Downloads as `magisk_patched-30700_XXXXX.img`.
5. **Pull the patched file back + flash to active slot:**
   ```bash
   MSYS_NO_PATHCONV=1 adb shell ls /sdcard/Download/ | grep magisk_patched
   # copy the exact filename
   MSYS_NO_PATHCONV=1 adb pull /sdcard/Download/magisk_patched-30700_XXXXX.img magisk_patched.img
   adb reboot bootloader
   sleep 12
   fastboot flash init_boot magisk_patched.img
   fastboot reboot
   ```
6. When phone boots, open Magisk app. Top row should show **Magisk — [version number]** and **Ramdisk: Yes**. You're rooted.

**Recovery if bootloop:**
```bash
fastboot set_active a   # swaps to the clean-stock inactive slot
fastboot reboot
```

Now jump to **step 5 (Termux provisioning)** below.

---

## Path B — Locked Samsung (carrier-locked, e.g., S20 FE Verizon)

No bootloader unlock, no root, no flashing. Stock Android with bloatware stripped.

### B1. Factory reset the phone

Settings → General management → Reset → Factory data reset. Confirm. Phone boots into setup wizard.

### B2. Complete Android setup (skip Google for now)

1. Connect to **your shop's WiFi** (we'll forget it before shipping).
2. Skip Google account sign-in. Skip Samsung account. Skip everything optional.
3. Land on home screen.

### B3. Enable Developer Options + USB debugging

1. Settings → About phone → Software information → tap **Build number** 7 times.
2. Settings → Developer options:
   - **USB debugging** ON
   - **Install via USB** ON
3. Plug USB, accept "Allow USB debugging" → **Always allow from this computer**.

### B4. Strip Samsung / Verizon bloatware (~5 min)

Run these `adb shell pm uninstall --user 0 <package>` commands. This *disables* bloat for the current user (user 0) without root — clean and reversible (factory reset restores them).

A curated list lives in `R:\Downloads\Delete Later\devbox-s20-apks\bloat-list.txt` (~195 packages). Short-form: any package starting with `com.samsung.android.bixby`, `com.verizon.`, `com.samsung.advp`, `com.sec.android.app.samsungapps` — uninstall with the command above.

**Do NOT uninstall:** `com.android.*`, `com.google.android.gms`, `com.google.android.gsf`, `com.samsung.android.keyscafe` (keyboard), or anything starting with `com.sec.android.inputmethod` — breaks core phone functions.

(If stripping this manually is tedious, run `bash strip-bloat-s20.sh` — TODO, not yet in repo. For now, work from the curated list.)

Now jump to **step 5 (Termux provisioning)** below.

---

## Step 5 — Install Termux + push DevBox scripts (both paths, ~2 min)

From the repo root on your PC:

```bash
bash flash-device.sh
```

This:
1. Verifies ADB sees one device.
2. Downloads/caches Termux, Termux:Boot, Termux:API APKs.
3. Installs them via `adb install`.
4. Pushes `provision.sh`, `wizard.sh`, sync scripts, and config to `/sdcard/Download/devbox/`.
5. Launches Termux on the phone.

**Common failure:** `Failure [INSTALL_FAILED_USER_RESTRICTED]` — means "Install via USB" is off. Enable it (step A3/B3 above) and re-run.

## Step 6 — Run provisioning on the device (5–8 min)

On the phone:

1. **Open Termux.** First launch takes ~30 sec to finish unpacking.
2. Grant storage access — in Termux, type:
   ```
   termux-setup-storage
   ```
   Tap **Allow** when Android prompts.
3. Copy and run the provisioning:
   ```
   cp ~/storage/downloads/devbox/* ~/
   bash ~/provision.sh
   ```
   Installs Node LTS, Python, Claude Code CLI, MCP server packages. 5–8 min.
4. When it prints `Provisioning complete.`, reboot:
   ```bash
   # From PC (recommended):
   adb reboot
   ```

## Step 7 — Final device setup (~3 min)

After reboot:

1. **Open each Termux app once** so Android registers them — open Termux, close; open Termux:Boot, close; open Termux:API, close.
2. **Disable battery optimization** for all three: Settings → Apps → Termux → Battery → **Unrestricted**. Same for Termux:Boot and Termux:API.
3. **Enable Screen Pinning** (kiosk-like mode):
   - Samsung: Settings → Biometrics and security → Other security settings → Pin windows → On → "Ask for PIN before unpinning" On.
   - Pixel: Settings → Security & privacy → More security & privacy → App pinning → On.
4. **Hide other apps from the launcher:**
   - Samsung: Long-press home → Settings → Hide apps → select all except Termux, Settings, Phone, Messages.
   - Pixel: Pixel's default launcher doesn't support hiding apps. Install a minimal launcher (e.g., [Olauncher](https://play.google.com/store/apps/details?id=app.olauncher)) from the Play Store, set as default.
5. **Open Termux.** The first-boot wizard runs automatically. Close it if you want the **buyer** to run setup themselves — next time they open Termux, the wizard resumes.

## Step 8 — Wipe shop WiFi (both paths, important)

Before boxing:
Settings → Network & internet → WiFi → (your shop SSID) → **Forget**.

The wizard will prompt the buyer to connect to their own WiFi at first boot.

## Step 9 — Package and ship

Include a printed card:
- "This is a DevBox. Power on, unlock, tap Termux to start."
- "Run `devbox status` any time in Termux to check on things."
- "Run `devbox wizard --reconfigure` to change settings."
- Search **JoJa84 DevBox** on GitHub for docs and help.

---

## Troubleshooting

**"adb: no devices/emulators found"**
Re-accept the USB debugging prompt on the phone. Try `adb kill-server && adb start-server`. On Pixel path, ensure Flash Tool tab is closed (it holds the USB handle).

**"Failure [INSTALL_FAILED_USER_RESTRICTED]"**
Settings → Developer options → **Install via USB** → On.

**Flash Tool says "device appears to be in use by another program"**
Classic: ADB server is running on your PC. Fix: `adb kill-server` (and don't run any `adb` commands until Flash Tool finishes — even `adb devices` auto-restarts the server).

**`adb push /sdcard/Download/foo.img` fails with `secure_mkdirs() failed: No such file`**
Git Bash on Windows is mangling the path. Prefix the command with `MSYS_NO_PATHCONV=1` or use a double-slash: `//sdcard/Download/foo.img`.

**Magisk patch completes but phone bootloops**
`fastboot set_active <other-slot>` (if current is `b`, flip to `a`, and vice versa). The other A/B slot is still clean stock. Then decide: re-patch init_boot from a fresh factory extract, or stay on stock without root.

**provision.sh fails on `npm install`**
Usually a flaky network. Re-run `bash ~/provision.sh` — it's idempotent.

**Wizard doesn't run on first Termux launch**
Run it manually: `bash ~/wizard.sh` or `devbox wizard`.

**Buyer reports Termux killed overnight**
Battery optimization wasn't disabled — see step 7.2.

---

## What's not in v0

- Bundled APKs in-repo (we download latest at flash time — fine for a shop with good WiFi; bundle them if you flash offline).
- Automated bloatware-stripper for Path B (`strip-bloat-s20.sh` is a todo).
- Branded bootscreen / splash screen — stock Android boot.

See `HANDOFF.md` for the live status of what's done vs. pending.
