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

## Path B — Rooted kiosk (Pixel + Magisk devices)

**Target buyer:** power users who explicitly want a single-purpose device.
**Lockdown level:** High — user cannot escape without a root-level reset.
**Availability:** Only on devices with Magisk root (Path A in `FLASH.md`). Carrier-locked Samsungs cannot do this.

Since DevBox v0.2 ships with Magisk root on Pixels, hardened kiosk mode is now a real option rather than a v1 aspiration. Optional for the v0.2 beta cohort, recommended for any buyer asking for "ChromeOS-style single-purpose phone."

### Steps

1. Confirm Magisk root is working: open Magisk app → top row shows `Magisk — [version]`.
2. Grant Magisk root to Termux: Magisk → **Superuser** tab → **Termux** → toggle ON.
3. Install a kiosk launcher from F-Droid or Play Store (e.g., [Olauncher](https://play.google.com/store/apps/details?id=app.olauncher) minimal + long-press escape, or [Fully Kiosk Browser](https://www.fully-kiosk.com/) app-mode for maximum lockdown).
4. Optionally install Magisk modules to further harden:
   - `systemless-hosts` — blocks ad/tracking domains at DNS level.
   - Disable setup wizard re-triggers, hide system notifications, etc.
5. Set the kiosk launcher as default (Settings → Apps → Default apps → Home app).
6. Pin Termux via Screen Pinning (Path A step 1) with "require PIN to unpin" ON — layered defense.

### Escape path

If the buyer ever gets locked out (forgot kiosk PIN): power off → Vol Down + Power to bootloader → recovery → wipe data. They lose their DevBox work but the phone recovers. Document this prominently on the shipping card.

### Knox caveat (Samsung-specific)

Samsung's eFuse (Knox bit) trips the moment you unlock the bootloader. Knox-dependent features (Samsung Pay, Secure Folder, work profiles) are permanently disabled. For an unlocked Samsung DevBox this is fine — we're not positioning it as a stock daily driver. Pixel devices do not have a Knox equivalent; unlocking is a clean "yellow banner on boot" with no hidden cost.

---

## Recommendation

For the 20-unit beta: **Path A**. Ship with a sticker on the box that reads:

> "This is a developer sandbox. It runs on stock Samsung software with Claude Code preinstalled. To reset it, see `devbox reflash`."

That matches the positioning. Anyone who wants a truly locked-down kiosk isn't in our ICP for v0.
