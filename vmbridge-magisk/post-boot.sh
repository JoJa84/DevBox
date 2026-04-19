#!/system/bin/sh
# vmbridge post-boot watcher. Runs detached via setsid from service.sh.
# Waits for boot_completed, launches the Terminal app to start the VM.
set -x
echo "[post-boot] started at $(date)"

# Wait up to 10 minutes for boot_completed
i=0
while [ $i -lt 600 ]; do
  [ "$(getprop sys.boot_completed)" = "1" ] && break
  sleep 1
  i=$((i+1))
done

if [ "$(getprop sys.boot_completed)" != "1" ]; then
  echo "[post-boot] ERROR: boot_completed never reached"
  exit 1
fi

echo "[post-boot] boot completed at $(date)"

# Keep screen awake so AVF doesn't wedge (Terminal app needs display on)
svc power stayon true 2>/dev/null

# Wake the screen in case device booted with display off
input keyevent KEYCODE_WAKEUP 2>/dev/null

# Launch Terminal (starts the Debian VM)
am start -n com.android.virtualization.terminal/.MainActivity
echo "[post-boot] launched Terminal at $(date)"

# Wait for avf_tap_fixed to appear (VM is running)
j=0
while [ $j -lt 120 ]; do
  ip link show | grep -q avf_tap_fixed && break
  sleep 1
  j=$((j+1))
done

if ip link show | grep -q avf_tap_fixed; then
  echo "[post-boot] avf_tap_fixed up at $(date); VM should be online"
else
  echo "[post-boot] WARN: avf_tap_fixed never appeared"
fi
