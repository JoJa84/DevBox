#!/usr/bin/env bash
#
# flash-device.sh — PC-side orchestrator for DevBox provisioning.
#
# Runs on the PC (macOS / Linux / Windows+WSL / Git Bash on Windows).
# Requires: adb, curl, awk, grep.
#
# Flow:
#   1. Verify ADB and a single connected device.
#   2. Download latest Termux / Termux:Boot / Termux:API APKs from GitHub releases.
#   3. Install them via adb.
#   4. Push provision.sh, wizard.sh, sync scripts, config, recovery docs to /sdcard/Download/devbox/.
#   5. Print the final 3-line copy/paste for the human operator to run inside Termux.
#
# Does NOT run provision.sh remotely — Termux's shell isn't reachable from adb
# without enabling RUN_COMMAND intents. For v0 the operator copies one
# command into Termux manually. See FLASH.md for the full flow.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APK_DIR="${REPO_DIR}/apks"
DEVICE_DIR="/sdcard/Download/devbox"

log()  { printf "\033[1;36m[flash]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[flash:warn]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[flash:err]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ─── Preflight ──────────────────────────────────────────────────────────────

command -v adb >/dev/null 2>&1 || die "adb not found. Install Android platform-tools first."
command -v curl >/dev/null 2>&1 || die "curl not found."

log "Checking for connected device..."
adb start-server >/dev/null 2>&1

device_count=$(adb devices | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')
if [ "$device_count" = "0" ]; then
    die "No device connected. Plug in the Galaxy S22 with USB debugging enabled."
elif [ "$device_count" -gt "1" ]; then
    die "Multiple devices connected. Disconnect all but the one you're flashing."
fi

device_serial=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
device_model=$(adb -s "$device_serial" shell getprop ro.product.model | tr -d '\r')
log "Device: $device_serial ($device_model)"

# ─── APK download ───────────────────────────────────────────────────────────

mkdir -p "$APK_DIR"

fetch_apk() {
    local repo="$1" out="$2" url
    if [ -f "$APK_DIR/$out" ]; then
        log "  ✓ $out already cached"
        return 0
    fi
    log "  fetching latest $out from $repo ..."
    url=$(curl -s "https://api.github.com/repos/$repo/releases/latest" \
        | grep browser_download_url \
        | grep -E 'universal\.apk"' \
        | head -1 \
        | cut -d '"' -f 4)
    if [ -z "$url" ]; then
        die "could not determine download URL for $repo"
    fi
    curl -L -f --progress-bar -o "$APK_DIR/$out" "$url" \
        || die "download failed: $repo"
}

log "Fetching Termux APKs..."
fetch_apk "termux/termux-app"  "termux.apk"
fetch_apk "termux/termux-boot" "termux-boot.apk"
fetch_apk "termux/termux-api"  "termux-api.apk"

# ─── Install APKs ───────────────────────────────────────────────────────────

install_apk() {
    local apk="$1" pkg="$2"
    if adb -s "$device_serial" shell pm list packages | grep -q "^package:${pkg}$"; then
        log "  ✓ ${pkg} already installed"
        return 0
    fi
    log "  installing ${pkg} ..."
    adb -s "$device_serial" install -r "$APK_DIR/$apk" >/dev/null 2>&1 \
        || die "install failed: $apk (check 'Install via USB' in Developer Options)"
}

log "Installing APKs..."
install_apk "termux.apk"      "com.termux"
install_apk "termux-boot.apk" "com.termux.boot"
install_apk "termux-api.apk"  "com.termux.api"

# ─── Push DevBox files ──────────────────────────────────────────────────────

log "Pushing DevBox files to device..."
adb -s "$device_serial" shell "mkdir -p $DEVICE_DIR" >/dev/null

FILES=(
    provision.sh
    wizard.sh
    sync-github.sh
    sync-drive.sh
    mcp-config.json
    reflash-to-stock.md
    kiosk-setup.md
)

for f in "${FILES[@]}"; do
    if [ -f "$REPO_DIR/$f" ]; then
        adb -s "$device_serial" push "$REPO_DIR/$f" "$DEVICE_DIR/" >/dev/null
        log "  ✓ $f"
    else
        warn "  missing: $f (skipping)"
    fi
done

# ─── Launch Termux so the user can start ────────────────────────────────────

log "Launching Termux on device (wake it up)..."
adb -s "$device_serial" shell am start -n com.termux/com.termux.app.TermuxActivity >/dev/null 2>&1 || true

# ─── Final instructions ─────────────────────────────────────────────────────

cat << 'FINAL_EOF'

─────────────────────────────────────────────────────────────────────
  PC side done. Now on the phone:
─────────────────────────────────────────────────────────────────────

  1. Wait 20s for Termux to finish unpacking (first launch only).
  2. In Termux, paste this and press Enter:

        termux-setup-storage
        (tap ALLOW when Android prompts)

  3. Then paste this and press Enter:

        cp ~/storage/downloads/devbox/* ~/ && bash ~/provision.sh

  4. When you see "Provisioning complete.", type:

        reboot

  5. On reboot, complete the final device setup (see FLASH.md step 6):
       - Disable battery optimization for Termux/Boot/API
       - Enable Screen Pinning
       - Hide other apps from launcher
       - Forget your shop's WiFi

  6. Box it up and ship.

─────────────────────────────────────────────────────────────────────
FINAL_EOF
