# reflash-to-stock.md — DevBox recovery to stock Android

Safety net. If a buyer returns a device, or provisioning goes sideways, this restores the Galaxy S22 to a clean state so your cousin can sell it as a normal refurb.

**Time:** ~10 minutes.
**Tools:** PC with ADB + Odin, USB-C cable.

---

## Path A — Soft reset (preserves Android, wipes DevBox)

Use when the device still boots normally and you just want to remove DevBox software.

1. Open Termux.
2. Run:
   ```
   pkg uninstall -y nodejs-lts python rclone termux-api
   rm -rf $HOME/.devbox $HOME/projects $HOME/.claude
   rm -f $PREFIX/bin/devbox
   ```
3. Uninstall Termux itself via Settings → Apps → Termux → Uninstall. Also Termux:Boot, Termux:API.
4. Factory reset: Settings → General management → Reset → Factory data reset.

After step 4, the phone is indistinguishable from a fresh refurb.

---

## Path B — Factory reset only (fastest, works even if DevBox is broken)

Use when Termux won't open or provisioning got stuck.

1. Power off the device.
2. Hold Volume Up + Side button until the Samsung logo appears, then release. Phone boots to recovery mode.
3. Navigate with volume buttons to **Wipe data/factory reset** → Power button to select → confirm.
4. After wipe completes, select **Reboot system now**.

Phone boots to Android's welcome screen, clean.

---

## Path C — Full stock firmware flash (nuclear option)

Use when the bootloader was unlocked, Knox was tripped, or something deeper broke.

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

## What gets wiped

| Path | Apps | User data | Android OS | Bootloader | Knox |
| --- | --- | --- | --- | --- | --- |
| A — soft | DevBox only | DevBox only | untouched | untouched | untouched |
| B — factory | all | all | untouched | untouched | untouched |
| C — Odin | all | all | reflashed | restored | permanent if tripped |

## When to use which

- **Default for RMA / return:** Path B (factory reset). Fastest, cleanest.
- **If DevBox damaged Android:** Path C (Odin).
- **If the buyer just wants DevBox gone but the phone back:** Path A (soft).
