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
    die "No device connected. Plug in the target phone with USB debugging enabled."
elif [ "$device_count" -gt "1" ]; then
    die "Multiple devices connected. Disconnect all but the one you're flashing."
fi

device_serial=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
device_model=$(adb -s "$device_serial" shell getprop ro.product.model | tr -d '\r')
log "Device: $device_serial ($device_model)"

# ─── APK download (GitHub-API-resolved + cached + integrity-checked) ────────
#
# We don't pin exact filenames in this script — Termux's release asset names
# contain build-metadata suffixes that drift between versions (e.g. the app
# uses `+github-debug_universal.apk` while the boot addon uses
# `+github.debug.apk` without `_universal`). Instead we query the GitHub API
# once per APK and filter by a per-repo regex that we know matches.
#
# Cache: the first flash downloads 3 APKs to apks/. Every subsequent flash
# in the same clone reuses them offline. Integrity is verified two ways:
#   1. Optional SHA256 pin — fill TERMUX_*_SHA256 after the first flash
#      using  `sha256sum apks/*.apk` to lock the cache against corruption.
#   2. Magic-byte check — APKs are zip files, so the first two bytes must
#      be "PK". Catches truncated / HTML-error-page downloads.
#
# Rate-limit note: 3 API calls per clone is well under GitHub's 60/hr cap,
# even if your cousin's shop flashes from a single IP.

TERMUX_APP_SHA256=""
TERMUX_BOOT_SHA256=""
TERMUX_API_SHA256=""

mkdir -p "$APK_DIR"

verify_sha256() {
    local file="$1" expected="$2"
    [ -z "$expected" ] && return 0   # no hash pinned, skip
    local actual
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        warn "no sha256sum/shasum tool — skipping hash verify for $file"
        return 0
    fi
    if [ "$actual" != "$expected" ]; then
        die "SHA256 mismatch on $file (expected $expected, got $actual). Delete $file and retry."
    fi
}

verify_apk_magic() {
    local file="$1"
    # APK is a zip; zip files start with "PK\x03\x04". Read first two bytes.
    local head2
    head2=$(head -c 2 "$file" 2>/dev/null || true)
    if [ "$head2" != "PK" ]; then
        die "$file is not a valid APK (magic bytes mismatch). Delete it and retry."
    fi
}

resolve_apk_url() {
    # Args: <repo>  <asset-filter-pattern>
    # Returns: first browser_download_url whose filename matches the pattern.
    local repo="$1" pattern="$2"
    curl -s "https://api.github.com/repos/$repo/releases/latest" \
        | grep browser_download_url \
        | grep -E "$pattern" \
        | head -1 \
        | cut -d '"' -f 4
}

fetch_apk() {
    local out="$1" repo="$2" pattern="$3" expected_sha="$4"

    if [ -f "$APK_DIR/$out" ]; then
        verify_apk_magic "$APK_DIR/$out"
        verify_sha256 "$APK_DIR/$out" "$expected_sha"
        log "  ✓ $out already cached (magic OK)"
        return 0
    fi

    log "  resolving latest $out from $repo ..."
    local url
    url=$(resolve_apk_url "$repo" "$pattern")
    [ -z "$url" ] && die "could not locate an APK asset matching /$pattern/ in $repo/releases/latest"
    log "  downloading $(basename "$url") ..."
    curl -L -f --progress-bar -o "$APK_DIR/$out" "$url" \
        || die "download failed: $repo"
    verify_apk_magic "$APK_DIR/$out"
    verify_sha256 "$APK_DIR/$out" "$expected_sha"
}

log "Fetching Termux APKs (cached to $APK_DIR/)..."
# Patterns come from observed Termux release naming:
#   termux-app       : *_universal.apk         (always has _universal)
#   termux-boot      : *github\.debug\.apk     (no _universal, dotted suffix)
#   termux-api       : *github\.debug\.apk     (no _universal, dotted suffix)
# grep -E expression must exclude checksum/signature files, so keep \.apk at end.
fetch_apk "termux.apk"      "termux/termux-app"  '_universal\.apk"'       "$TERMUX_APP_SHA256"
fetch_apk "termux-boot.apk" "termux/termux-boot" 'github[.-]debug\.apk"'  "$TERMUX_BOOT_SHA256"
fetch_apk "termux-api.apk"  "termux/termux-api"  'github[.-]debug\.apk"'  "$TERMUX_API_SHA256"

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
