# reflash-to-stock.md — DevBox recovery to stock Android

Safety net. If a buyer returns a device, or provisioning goes sideways, this restores the phone to a clean state so your cousin can sell it as a normal refurb.

**Time:** 5–15 minutes depending on path.
**Tools:** PC with ADB + (path-specific) Flash Tool / Odin, USB-C cable.

Pick the path based on (a) the device family and (b) how broken things are.

---

## Path A — Soft reset (preserves Android, wipes DevBox only)

**Works on:** any device.
**Use when:** the phone still boots normally and you just want to remove DevBox software.

1. Open Termux.
2. Run:
   ```
   pkg uninstall -y nodejs-lts python rclone termux-api
   rm -rf $HOME/.devbox $HOME/projects $HOME/.claude
   rm -f $PREFIX/bin/devbox
   ```
3. Uninstall Termux itself via Settings → Apps → Termux → Uninstall. Also Termux:Boot, Termux:API.
4. Factory reset: Settings → General management (Samsung) / System (Pixel) → Reset → Factory data reset.

After step 4, the phone is indistinguishable from a fresh refurb.

---

## Path B — Factory reset via Recovery (fastest, works even if DevBox is broken)

**Works on:** any device.
**Use when:** Termux won't open or provisioning got stuck.

1. Power off the device.
2. Enter recovery mode:
   - **Samsung:** hold Volume Up + Side button until the Samsung logo appears, then release.
   - **Pixel:** hold Volume Down + Power until the bootloader menu appears → use volume keys to highlight "Recovery mode" → press Power.
3. On the recovery screen, navigate with volume keys to **Wipe data/factory reset** → Power button to select → confirm.
4. After wipe completes, select **Reboot system now**.

Phone boots to Android's welcome screen, clean. Note: this preserves Magisk root on Pixels — root survives a factory reset because it lives in `init_boot`, not userdata. For a complete de-root, use Path D.

---

## Path C — Full Samsung stock firmware flash (nuclear option, Samsung only)

**Works on:** Samsung Galaxy devices.
**Use when:** Odin-only recovery is needed (Knox tripped, deeper corruption, can't enter recovery).

1. Download the correct stock firmware for the device's exact model + region from a reputable source (SamMobile or Frija). Match the model number on the box.
2. Install **Odin** (Samsung's Windows flash tool) on the PC.
3. Put the phone in Download Mode: power off → hold Volume Down + Volume Up while plugging USB-C into a PC.
4. In Odin, load the firmware files into AP / BL / CP / CSC slots and click Start.
5. Wait 5–10 minutes. Do not disconnect.
6. When Odin reports PASS, phone reboots into stock Android.

**Caveats:**
- Knox eFuse, if already tripped, stays tripped. Samsung Pay / Secure Folder won't come back.
- The device is fully functional as an Android phone, just without Knox-dependent features.
- Disclose "Knox tripped" on the eBay/Amazon listing for any unit that went through this.

---

## Path D — Pixel full reflash via Flash Tool (nuclear option, Pixel only)

**Works on:** any Pixel on an unlockable bootloader.
**Use when:** Magisk caused persistent issues, you need a guaranteed-clean stock starting point, or you want to remove root before resale.

1. Plug the phone into the PC.
2. Kill any running ADB server: `adb kill-server`.
3. Open Chrome or Edge → [flash.android.com](https://flash.android.com).
4. Select the device when prompted.
5. Pick the latest stable build for the device (e.g., `shiba-user BP4A.251205.006`).
6. **Toggle settings to wipe everything:**
   - Wipe Device: ✅ ON
   - Lock Bootloader: ❌ OFF (if reselling to a power user, leave unlocked; if shipping as a regular refurb, flip to ON — see caveat below)
   - Force Flash all Partitions: ✅ ON
   - Skip Secondary: ❌ OFF (flash both slots)
7. Click Install, approve USB permission, wait ~15 min.
8. Phone reboots into fresh Android 16 setup. No root, no Magisk, no DevBox.

**Lock Bootloader caveat:** Re-locking the bootloader on a device that has Magisk installed **will brick it** — the bootloader won't accept the Magisk-modified `init_boot.img` signature. Sequence matters: flash stock (step 7) first, which overwrites `init_boot` with a signed stock image, THEN re-lock if desired. If you re-lock in the same flash as wiping DevBox, Flash Tool does this correctly — the wipe+flash happens before the lock command.

---

## What gets wiped

| Path | Apps | User data | Android OS | Bootloader | Magisk/root | Knox |
| --- | --- | --- | --- | --- | --- | --- |
| A — soft | DevBox only | DevBox only | untouched | untouched | untouched | untouched |
| B — factory | all | all | untouched | untouched | **untouched on Pixel** | untouched |
| C — Odin (Samsung) | all | all | reflashed | restored | N/A | permanent if tripped |
| D — Flash Tool (Pixel) | all | all | reflashed | optional relock | **removed** | N/A |

## When to use which

- **Buyer just wants DevBox gone, phone back:** Path A (soft).
- **Default for RMA / return, Samsung:** Path B (factory reset).
- **Default for RMA / return, Pixel that needs to ship un-rooted:** Path D (Flash Tool).
- **Samsung with Knox trip or deeper OS damage:** Path C (Odin).
- **Pixel bootloop / Magisk bricked boot:** first try `fastboot set_active <other-slot>` to hop to the untouched A/B slot; if both slots are bad, Path D.
