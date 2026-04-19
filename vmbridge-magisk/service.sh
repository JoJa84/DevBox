#!/system/bin/sh
# Codefone vmbridge Magisk service script.
# Runs at late_start service (after /data is mounted).

MODDIR=${0%/*}
LOG=/data/local/tmp/vmbridge-service.log
: > "$LOG"
exec >>"$LOG" 2>&1
set -x

# ---------- 1. Persistent TCP ADB on 5555 ----------
resetprop persist.adb.tcp.port 5555 2>/dev/null || setprop persist.adb.tcp.port 5555
setprop service.adb.tcp.port 5555

# ---------- 2. Install VM adbkeys ----------
KEYS=/data/misc/adb/adb_keys
mkdir -p /data/misc/adb
touch "$KEYS"
for src in "$MODDIR/vm_adbkey.pub" /sdcard/Codefone/vm_adbkey.pub; do
  [ -f "$src" ] || continue
  K=$(cat "$src")
  grep -qxF "$K" "$KEYS" 2>/dev/null || echo "$K" >> "$KEYS"
done
chown system:shell "$KEYS"
chmod 640 "$KEYS"
restorecon "$KEYS" 2>/dev/null

# ---------- 3. Firewall: 5555 restricted to avf_tap_fixed + lo ----------
# Apply unconditionally; specifying -i avf_tap_fixed before it exists is fine.
iptables -D INPUT -p tcp --dport 5555 -j DROP 2>/dev/null
iptables -D INPUT -p tcp --dport 5555 -i avf_tap_fixed -j ACCEPT 2>/dev/null
iptables -D INPUT -p tcp --dport 5555 -i lo -j ACCEPT 2>/dev/null
iptables -I INPUT -p tcp --dport 5555 -j DROP
iptables -I INPUT -p tcp --dport 5555 -i lo -j ACCEPT
iptables -I INPUT -p tcp --dport 5555 -i avf_tap_fixed -j ACCEPT
ip6tables -D INPUT -p tcp --dport 5555 -j DROP 2>/dev/null
ip6tables -I INPUT -p tcp --dport 5555 -j DROP

# ---------- 4. Restart adbd so new port config takes effect ----------
stop adbd
sleep 1
start adbd

echo "[vmbridge] boot tasks done at $(date)"

# ---------- 5. Fork a post-boot watcher: auto-launch Terminal ----------
# Fully detach via setsid + nohup so it survives this script exiting.
setsid nohup sh "$MODDIR/post-boot.sh" > /data/local/tmp/vmbridge-postboot.log 2>&1 < /dev/null &
