#!/usr/bin/env bash
# codefone-setup.sh — one-shot post-Magisk provisioning for a Codefone.
#
# PREREQUISITES (manual, ~10 min):
#   1. Pixel 8+ flashed to stock Android 16 via flash.android.com (Wipe + Force
#      Flash, bootloader unlocked, Locked OFF).
#   2. Bootloader unlocked, USB debugging ON, OEM unlocking ON.
#   3. Magisk installed via init_boot patching on both A/B slots (see FLASH.md §A0).
#   4. Phone connected via USB, `adb devices` shows one device.
#
# WHAT THIS SCRIPT DOES (~5-10 min):
#   • Verifies Magisk root via `su`.
#   • Installs the vmbridge Magisk module (persistent VM↔Android adb on 5555).
#   • Blocks OTA auto-update.
#   • Pushes Aurora Store APK if not yet installed.
#   • Enables Linux Terminal, launches it, waits for Debian VM to come online.
#   • Inside the VM: installs Claude Code, writes CLAUDE.md, ~/bin helpers,
#     voice stack (whisper.cpp + espeak-ng), SSH server, registers VM's
#     generated adbkey with the vmbridge Magisk module.
#   • Grants Terminal app RECORD_AUDIO + CAMERA for voice/vision features.
#   • Verifies end-to-end: VM→Android root, Claude runs, voice works.
#
# Usage:
#   bash codefone-setup.sh [--skip-vm-setup]
#
# Idempotent. Safe to re-run. If a step fails, you can re-run without undoing.

set -euo pipefail
ADB="${ADB:-C:/platform-tools/adb.exe}"
SKIP_VM=0
for a in "$@"; do [ "$a" = "--skip-vm-setup" ] && SKIP_VM=1; done

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
say() { echo; echo "▶ $*"; }
die() { echo "✗ $*" >&2; exit 1; }

# ---------- 0. Preflight ----------
say "Preflight: adb, Magisk root, device identity"
"$ADB" devices | grep -qE '\bdevice$' || die "No adb device. Plug USB + accept debugging prompt."
MODEL=$("$ADB" shell getprop ro.product.model | tr -d '\r')
BUILD=$("$ADB" shell getprop ro.build.id | tr -d '\r')
echo "Device: $MODEL ($BUILD)"
case "$MODEL" in *Pixel\ 8*|*Pixel\ 9*) ;; *) echo "⚠  model '$MODEL' untested, continuing anyway" ;; esac
"$ADB" shell 'su -c id' 2>&1 | grep -q 'uid=0' || die "Magisk root not active. Finish Magisk install first."

# ---------- 1. Install vmbridge Magisk module ----------
say "Installing vmbridge Magisk module"
ZIP="$REPO_DIR/vmbridge-magisk/vmbridge-magisk-v1.0.0.zip"
if [ ! -f "$ZIP" ]; then
  python3 - <<PY
import zipfile, os
src = r'$REPO_DIR/vmbridge-magisk'
dst = r'$ZIP'
z = zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk(src):
    for f in files:
        if f.endswith('.zip'): continue
        full = os.path.join(root, f)
        rel = os.path.relpath(full, src).replace(os.sep, '/')
        z.write(full, rel)
z.close()
PY
fi
TMP_WIN=$(cygpath -w "$ZIP" 2>/dev/null || echo "$ZIP")
MSYS_NO_PATHCONV=1 "$ADB" push "$TMP_WIN" //data/local/tmp/vmbridge.zip >/dev/null
"$ADB" shell 'su -c "
  rm -rf /data/adb/modules/vmbridge
  mkdir -p /data/adb/modules/vmbridge
  unzip -o /data/local/tmp/vmbridge.zip -d /data/adb/modules/vmbridge >/dev/null
  chmod 755 /data/adb/modules/vmbridge/*.sh
"'

# ---------- 2. Run service.sh once so bridge is live immediately ----------
say "Activating bridge"
"$ADB" shell 'su -c "sh /data/adb/modules/vmbridge/service.sh"' 2>&1 | tail -3 || true
# Wait for adbd to come back
for i in 1 2 3 4 5 6 7 8 9 10; do
  "$ADB" devices 2>&1 | grep -q 'device$' && break
  sleep 2
done

# ---------- 3. Block OTAs ----------
say "Blocking OTA auto-update"
"$ADB" shell 'settings put global ota_disable_automatic_update 1; settings put global auto_update_apps 0'
"$ADB" shell 'su -c "pm disable-user --user 0 com.google.android.gms.policy_update 2>/dev/null; pm disable-user --user 0 com.google.mainline.telemetry 2>/dev/null"' >/dev/null 2>&1 || true

# ---------- 4. Install Aurora Store if missing ----------
if ! "$ADB" shell 'pm list packages' | grep -q com.aurora.store; then
  say "Installing Aurora Store"
  AURORA="$REPO_DIR/apks/aurora-store.apk"
  if [ -f "$AURORA" ]; then
    "$ADB" install -r "$AURORA"
  else
    echo "⚠  apks/aurora-store.apk missing; sideload later via ~/bin/android install"
  fi
fi

# ---------- 5. Grant Terminal app mic + camera ----------
say "Granting Terminal app RECORD_AUDIO + CAMERA"
"$ADB" shell 'pm grant com.android.virtualization.terminal android.permission.RECORD_AUDIO' 2>/dev/null || true
"$ADB" shell 'pm grant com.android.virtualization.terminal android.permission.CAMERA' 2>/dev/null || true

# ---------- 6. Launch Terminal / start VM ----------
say "Starting Debian VM (Terminal app)"
"$ADB" shell 'am force-stop com.android.virtualization.terminal'
sleep 2
"$ADB" shell 'svc power stayon true; input keyevent KEYCODE_WAKEUP'
"$ADB" shell 'am start -n com.android.virtualization.terminal/.MainActivity' >/dev/null

# ---------- 7. Wait for VM to get an IP on avf_tap_fixed ----------
say "Waiting for VM network to come up"
VM_IP=""
for i in $(seq 1 60); do
  NEIGH=$("$ADB" shell 'ip neigh 2>/dev/null | grep "dev avf_tap_fixed" | awk "{print \$1}" | head -1' | tr -d '\r')
  if [ -n "$NEIGH" ] && "$ADB" shell "ping -c 1 -W 1 $NEIGH" 2>/dev/null | grep -q "1 received"; then
    VM_IP="$NEIGH"
    break
  fi
  sleep 2
done
[ -n "$VM_IP" ] || die "VM network never came up. Terminal may be stuck on 'Preparing terminal' — force-stop and retry."
echo "VM at $VM_IP"

# ---------- 8. Spawn nc relay for SSH ----------
say "Setting up nc relay for SSH (port 2223)"
"$ADB" shell "pkill -9 nc 2>/dev/null; nohup nc -L -p 2223 nc $VM_IP 2222 >/data/local/tmp/relay.log 2>&1 &"
"$ADB" forward --remove tcp:2223 2>/dev/null || true
"$ADB" forward tcp:2223 tcp:2223 >/dev/null

# ---------- 9. VM-side setup over SSH ----------
if [ "$SKIP_VM" = "1" ]; then
  say "--skip-vm-setup: leaving VM alone"
else
  # Ensure we can SSH (VM might not have openssh-server yet; first-boot handled later)
  sleep 3
  if ! ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 droid@127.0.0.1 'true' 2>/dev/null; then
    echo "⚠  SSH not yet available — the VM is on its first boot. On the phone, open the Terminal app and run:"
    echo "    curl -fsSL https://claude.ai/install.sh | bash"
    echo "    sudo apt install -y openssh-server"
    echo "    echo 'Port 2222' | sudo tee -a /etc/ssh/sshd_config && sudo systemctl restart ssh"
    echo "    mkdir -p ~/.ssh && curl -fsSL https://raw.githubusercontent.com/JoJa84/Codefone/main/setup-keys.sh | bash"
    echo "Then re-run: bash codefone-setup.sh"
    exit 0
  fi

  say "Installing Claude Code + helpers + CLAUDE.md"
  scp -P 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$REPO_DIR/vm-CLAUDE.md" droid@127.0.0.1:/home/droid/.claude/CLAUDE.md
  ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null droid@127.0.0.1 "$(cat "$REPO_DIR/scripts/vm-provision.sh" 2>/dev/null || echo 'echo no vm-provision.sh yet')"
fi

# ---------- 10. Register VM adbkey with the Magisk module ----------
say "Registering VM adbkey with vmbridge module"
VM_KEY=$(ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null droid@127.0.0.1 'cat ~/.android/adbkey.pub' 2>/dev/null || true)
if [ -n "$VM_KEY" ]; then
  # Stash into /sdcard/Codefone/ so vmbridge service.sh picks it up on every boot
  "$ADB" shell "su -c 'mkdir -p /sdcard/Codefone'"
  "$ADB" shell "cat > /sdcard/Codefone/vm_adbkey.pub" <<< "$VM_KEY"
  "$ADB" shell "su -c 'sh /data/adb/modules/vmbridge/service.sh' >/dev/null 2>&1" || true
fi

# ---------- 11. Verify end-to-end ----------
say "Verification"
sleep 3
# Respawn relay (adbd may have restarted)
"$ADB" shell "pkill -9 nc 2>/dev/null; nohup nc -L -p 2223 nc $VM_IP 2222 >/data/local/tmp/relay.log 2>&1 &"
"$ADB" forward tcp:2223 tcp:2223 >/dev/null
sleep 2
OUT=$(ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null droid@127.0.0.1 '
  claude --version 2>&1 | head -1
  ~/bin/android su "id" 2>&1 | head -1
' 2>&1 || true)
echo "$OUT"
echo "$OUT" | grep -q 'Claude Code' && echo "✓ Claude installed" || echo "✗ Claude missing"
echo "$OUT" | grep -q 'uid=0'       && echo "✓ Android root via bridge" || echo "✗ bridge broken"

say "DONE. Summary:"
cat <<EOF
  Device: $MODEL ($BUILD)
  VM IP : $VM_IP
  SSH   : ssh -p 2223 droid@127.0.0.1
  Root  : ~/bin/android su 'CMD'
  Claude: ssh ... 'claude'
  Voice : ssh ... '~/bin/v' (hold-to-talk), '~/bin/say "text"' (tts)
EOF
