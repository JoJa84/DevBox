#!/usr/bin/env bash
# codefone-ssh.sh — SSH into the Debian VM on a Codefone.
# Auto-discovers the VM IP via the AVF tap interface (no hardcoding), spawns
# a toybox-nc relay on Android port 2223, forwards 2223 locally, and ssh's.
#
# Usage:
#   bash scripts/codefone-ssh.sh              # interactive shell
#   bash scripts/codefone-ssh.sh 'command'    # run one command and exit
#
# Env:
#   ADB=/c/platform-tools/adb.exe
#   USER_ON_VM=droid

set -euo pipefail
ADB="${ADB:-C:/platform-tools/adb.exe}"
USER_ON_VM="${USER_ON_VM:-droid}"

"$ADB" devices | grep -qE '\bdevice$' || { echo "No adb device" >&2; exit 1; }

VM_IP=$("$ADB" shell 'ip neigh show dev avf_tap_fixed 2>/dev/null | grep -v FAILED | head -1 | awk "{print \$1}"' | tr -d '\r')
[ -n "$VM_IP" ] || { echo "VM not up (avf_tap_fixed has no neighbour). Open Terminal on the phone or wait for auto-launch." >&2; exit 2; }

# Spawn (or re-spawn) relay
"$ADB" shell "pkill -9 nc 2>/dev/null; nohup nc -L -p 2223 nc $VM_IP 2222 >/data/local/tmp/relay.log 2>&1 &" >/dev/null 2>&1 || true
"$ADB" forward --remove tcp:2223 >/dev/null 2>&1 || true
"$ADB" forward tcp:2223 tcp:2223 >/dev/null

# Wait briefly for sshd to be reachable
for i in 1 2 3 4 5 6 7 8 9 10; do
  if "$ADB" shell "nc -z $VM_IP 2222 2>/dev/null && echo y" | grep -q y; then break; fi
  sleep 2
done

exec ssh -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=10 -o ServerAliveInterval=30 \
  "$USER_ON_VM@127.0.0.1" "$@"
