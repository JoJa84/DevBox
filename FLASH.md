# FLASH.md — Cousin's step-by-step

**Goal:** turn one factory-fresh Galaxy S22 into a DevBox in ~15 minutes.

## What you need

- One **Galaxy S22** (factory-reset, battery ≥ 50%)
- A **USB-C cable**
- A **PC with ADB installed** (Android SDK platform-tools)
- This repo cloned locally
- WiFi for initial provisioning (buyer will switch to their own WiFi later)

## Quick version (for the experienced)

```bash
# 1. On the PC, from this repo directory:
bash flash-device.sh

# 2. When the script finishes, unplug, hand to buyer, done.
```

If `flash-device.sh` has errors or this is your first time, use the Detailed version below.

---

## Detailed version

### 1. Prep the device (2 min)

1. Power on the Galaxy S22.
2. Complete **skip** through the setup wizard:
   - Skip Google account (tap "Skip" — do not sign in)
   - Skip Samsung account
   - Connect to **your shop's WiFi** (we'll change this for the buyer later, or they will at first boot)
   - Skip everything else it asks — accept only the unavoidable "Continue"s.
3. Enable Developer Options:
   - Settings → About phone → Software information → tap **Build number** 7 times → enter lock PIN if prompted.
4. Enable USB Debugging:
   - Settings → Developer options → **USB debugging** ON.
5. Plug USB-C into PC. On the phone, accept the "Allow USB debugging" prompt. Tick "always allow from this computer."

### 2. Verify ADB (30 sec)

```bash
adb devices
```

Expected: one device listed as `<serial>  device`. If it says `unauthorized`, re-accept the prompt on the phone.

### 3. Install Termux and addons (3 min)

Termux is no longer on the Play Store. We install from F-Droid's or GitHub's APKs.

```bash
# Download latest stable APKs (from GitHub releases — signed consistently)
mkdir -p apks && cd apks

curl -L -o termux.apk \
  "$(curl -s https://api.github.com/repos/termux/termux-app/releases/latest \
     | grep browser_download_url | grep universal.apk | head -1 | cut -d '"' -f 4)"

curl -L -o termux-boot.apk \
  "$(curl -s https://api.github.com/repos/termux/termux-boot/releases/latest \
     | grep browser_download_url | grep universal.apk | head -1 | cut -d '"' -f 4)"

curl -L -o termux-api.apk \
  "$(curl -s https://api.github.com/repos/termux/termux-api/releases/latest \
     | grep browser_download_url | grep universal.apk | head -1 | cut -d '"' -f 4)"

# Install
adb install termux.apk
adb install termux-boot.apk
adb install termux-api.apk

cd ..
```

### 4. Push DevBox files to the device (30 sec)

```bash
# Create a folder in the shared Downloads directory on the phone
adb shell mkdir -p /sdcard/Download/devbox

# Push everything the buyer might need
adb push provision.sh wizard.sh sync-github.sh sync-drive.sh \
         mcp-config.json reflash-to-stock.md \
         /sdcard/Download/devbox/
```

### 5. Run provisioning on the device (5–8 min)

1. On the phone, open **Termux** (tap the app icon).
2. The first time you open Termux it needs ~30 seconds to finish unpacking. Wait for the `$` prompt.
3. Grant storage access — paste this into Termux and press Enter:

   ```
   termux-setup-storage
   ```

   Tap **Allow** when Android prompts.

4. Copy the provisioning files from shared storage into Termux's home directory, then run them:

   ```
   cp ~/storage/downloads/devbox/*.sh ~/storage/downloads/devbox/*.json ~/storage/downloads/devbox/*.md ~/
   bash ~/provision.sh
   ```

   This runs for 5–8 minutes depending on network speed. It installs Node LTS, Python, the Claude Code CLI, and the MCP server packages.

5. When you see `Provisioning complete.`, **reboot the phone**:

   ```
   reboot
   ```

### 6. Final device setup (2 min)

On reboot, the phone will show the lock screen. Unlock, then:

1. **Disable battery optimization for Termux** (critical — Samsung will kill it otherwise):
   Settings → Apps → Termux → Battery → **Unrestricted**
   Do the same for **Termux:Boot** and **Termux:API**.

2. **Enable Screen Pinning** (kiosk-like mode):
   Settings → Biometrics and security → Other security settings → Pin windows → **On** → "Ask for PIN before unpinning" **On**.

3. **Hide other apps from the launcher:**
   Long-press home → Settings → Hide apps → select all except **Termux**, **Settings**, **Phone**, **Messages**.

4. **Open Termux.** The first-boot wizard runs automatically. You can close it if you want the **buyer** to do setup — next time they open Termux, the wizard resumes.

### 7. Wipe shop WiFi (important — privacy)

Before boxing the device, forget your shop's WiFi network:
Settings → Connections → WiFi → (your shop SSID) → **Forget**.

The wizard will prompt the buyer to connect to their own WiFi at first boot.

### 8. Package and ship

- Include a printed card with:
  - "This is a DevBox. Power on, unlock, tap Termux to start."
  - "Run `devbox status` any time in Termux to check on things."
  - "Run `devbox wizard --reconfigure` to change settings."
  - A link to this repo for help.

---

## Troubleshooting

**"adb: no devices/emulators found"**
Re-accept the USB debugging prompt on the phone. Try `adb kill-server && adb start-server`.

**"Failure [INSTALL_FAILED_USER_RESTRICTED]"**
Settings → Developer options → **Install via USB** → On. (Default is off on some Samsung builds.)

**provision.sh fails on `npm install`**
Usually a flaky network. Re-run `bash ~/provision.sh` — it's idempotent.

**Wizard doesn't run on first Termux launch**
Run it manually: `bash ~/wizard.sh` or `devbox wizard`.

**Buyer reports Termux killed overnight**
Battery optimization wasn't disabled — see step 6.1.

---

## What's not in v0

- Automated `flash-device.sh` orchestrator (coming in a later commit; today's flow is copy-paste-able by anyone comfortable with ADB).
- APKs bundled in-repo (we download latest at flash time — fine for a shop with good WiFi; bundle them if you flash offline).
- Branded bootscreen / splash screen — stock Samsung boot.

See `HANDOFF.md` for the live status of what's done vs. pending.
