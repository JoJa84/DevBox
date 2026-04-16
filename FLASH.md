# FLASH.md — Cousin's step-by-step

**Goal:** turn one factory-fresh Galaxy S22 into a DevBox in ~15 minutes.

> ⚠️ **This doc is a stub.** The scripts it references (`provision.sh`, `wizard.sh`) are being written in parallel. Once they land, this file gets a full walkthrough. For now, this outlines the flow so we know the scripts are building toward the right target.

## What you need

- **One Galaxy S22** (factory-reset, battery ≥ 50%).
- **A USB-C cable** and a PC with **ADB installed** (platform-tools from Google).
- **The DevBox flash package** (this repo cloned locally).
- **A WiFi network** (the device connects once for provisioning — the buyer will switch it to their own network later).

## Overview of the flow

1. Factory-reset the phone.
2. Skip Google account setup. Connect to WiFi only.
3. Enable Developer Options and USB Debugging (Settings → About phone → tap Build number 7× → back → Developer options → enable USB debugging).
4. Connect via USB. Accept the ADB fingerprint prompt on the device.
5. On your PC, from this repo directory: run `bash flash-device.sh` (script will land in a later commit).

The flash script will:
- Sideload Termux, Termux:Boot, Termux:API (from F-Droid APKs bundled in `apks/` — these will be added in a later commit).
- Push `provision.sh` and `wizard.sh` to the device.
- Run `provision.sh` inside Termux via `adb shell`.
- Reboot the device.

On boot, the buyer's experience:
- Phone shows stock Android lock screen.
- After unlock, launcher shows one prominent icon (Termux or a wrapper we ship).
- Tapping the icon opens a terminal that runs `wizard.sh` (first time) or `claude` (every time after).
- Wizard walks them through WiFi / OAuth / keyboard choice / sync setup.

## What's NOT in this stub yet

- Exact ADB sideload commands (pending APK bundle in `apks/`).
- The `flash-device.sh` orchestrator script (next after `provision.sh` + `wizard.sh`).
- Disable-battery-optimization steps for Termux on Samsung.
- Screen Pinning setup.
- Troubleshooting section.

See `HANDOFF.md` for the current build state.
