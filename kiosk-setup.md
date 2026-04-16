# kiosk-setup.md — Lockdown options for DevBox

v0 positions DevBox as a **developer sandbox**, not a consumer appliance. The point is *isolation from the buyer's main machine*, not *lockdown of this device*. The buyer owns it and should be able to unlock / reset / reflash it freely.

That said, a kiosk-like experience makes the out-of-box flow cleaner. Two paths, pick per device.

## Path A — Stock Android (default)

**Target buyer:** developers, tinkerers, beta cohort.
**Lockdown level:** Low. User can escape with a PIN.
**Effort to set up:** ~2 minutes per device.

### 1. Screen Pinning

Android's built-in Screen Pinning locks the phone to one app until you enter the unlock PIN.

1. Settings → Biometrics and security → Other security settings → Pin windows → **On**
2. Enable "Ask for PIN before unpinning"
3. Open Termux (the DevBox app). Tap the overview / recents button.
4. Long-press the Termux card → **Pin this app**.

To escape: hold Back + Overview → enter PIN.

### 2. Hide other apps from the launcher

Samsung's One UI launcher lets you hide apps:

1. Long-press the home screen → **Settings** → **Hide apps**
2. Select every app except Termux, Settings, and Phone.

Note: these apps are still *installed* and *launchable* via Settings or Tasker, so this is a cosmetic change, not a security boundary. Appropriate for v0.

### 3. Disable battery optimization for Termux

Samsung's One UI aggressively kills Termux background processes. Disable this:

1. Settings → Apps → Termux → Battery → **Unrestricted**
2. Settings → Battery and device care → Battery → Background usage limits → Never sleeping apps → **Add Termux**

Without this, Termux:Boot autostart and long Claude Code sessions get killed.

### 4. Disable auto-lock timeout (optional)

For coding sessions, a short auto-lock is annoying:

- Settings → Display → Screen timeout → **10 minutes** (or longer).

### 5. Default launcher

Stock Samsung One UI launcher is fine. Third-party launchers (Nova, Lawnchair) give more customization but add moving parts. **Skip for v0.**

---

## Path B — Rooted (v1+ territory, documented for the curious)

**Target buyer:** power users, enterprise kiosk deployments.
**Lockdown level:** High — single-purpose device, user cannot escape.
**Effort:** ~30 min per device, voids warranty, trips Knox eFuse (permanent).

This is **not** the v0 path. Notes for future work:

1. Unlock bootloader: `adb reboot bootloader` → `fastboot flashing unlock` (Samsung requires enabling OEM unlock first + 7-day waiting period).
2. Flash Magisk: download Magisk APK, patch the stock boot image, flash the patched image.
3. Install a kiosk launcher that requires a long-press escape sequence (e.g. Fully Kiosk Browser in app mode, Hexnode, or a custom launcher).
4. Use Magisk modules to disable setup wizard, Google services, etc.
5. Flash a custom recovery (TWRP) so the user can reflash to stock themselves.

**Knox caveat:** Samsung's eFuse (Knox bit) trips the moment you unlock the bootloader. Knox-dependent features (Samsung Pay, Secure Folder, work profiles) are permanently disabled. For a dev sandbox, this is fine.

---

## Recommendation

For the 20-unit beta: **Path A**. Ship with a sticker on the box that reads:

> "This is a developer sandbox. It runs on stock Samsung software with Claude Code preinstalled. To reset it, see `devbox reflash`."

That matches the positioning. Anyone who wants a truly locked-down kiosk isn't in our ICP for v0.
