#!/usr/bin/env bash
# vm-provision.sh — runs inside the Debian VM. Called by codefone-setup.sh
# over SSH. Idempotent.
set -euo pipefail
umask 022

PC_KEY_URL="${PC_KEY_URL:-}"   # optional: URL serving the PC's ssh public key

# ---- 1. Packages ----
sudo apt-get update -q
sudo apt-get install -y -q --no-install-recommends \
  openssh-server curl ca-certificates git \
  android-tools-adb python3 python3-pip \
  sox alsa-utils espeak-ng \
  build-essential cmake ffmpeg unzip

# ---- 2. Claude Code (native installer) ----
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Symlink into /usr/local/bin so non-interactive SSH commands (ssh user@host 'claude ...')
# find it without relying on ~/.bashrc PATH tweaks.
if [ -x "$HOME/.local/bin/claude" ]; then
  sudo ln -sf "$HOME/.local/bin/claude" /usr/local/bin/claude
fi

# Ensure PATH for interactive + non-interactive shells
for rc in ~/.bashrc ~/.profile ~/.bash_profile; do
  [ -f "$rc" ] || touch "$rc"
  grep -q 'HOME/.local/bin' "$rc" || echo 'export PATH=$HOME/.local/bin:$HOME/bin:$PATH' >> "$rc"
done
# .bash_profile must source .bashrc for non-interactive SSH
grep -q "source ~/.bashrc" ~/.bash_profile 2>/dev/null || cat >> ~/.bash_profile <<'RC'
[ -f ~/.bashrc ] && . ~/.bashrc
RC

# ---- 3. SSH server ----
if ! sudo grep -q '^Port 2222' /etc/ssh/sshd_config 2>/dev/null; then
  echo 'Port 2222' | sudo tee -a /etc/ssh/sshd_config >/dev/null
fi
sudo systemctl enable --now ssh >/dev/null 2>&1
sudo systemctl restart ssh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

if [ -n "$PC_KEY_URL" ]; then
  curl -fsSL "$PC_KEY_URL" | while read -r k; do
    grep -qxF "$k" ~/.ssh/authorized_keys 2>/dev/null || echo "$k" >> ~/.ssh/authorized_keys
  done
fi

# ---- 4. ADB inside VM (for the bridge) ----
mkdir -p ~/.android
if [ ! -f ~/.android/adbkey ]; then
  # Generating via `adb devices` produces the keypair
  adb kill-server >/dev/null 2>&1 || true
  adb start-server >/dev/null
fi
chmod 700 ~/.android
chmod 600 ~/.android/adbkey

# ---- 5. ~/bin helpers ----
mkdir -p ~/bin
cat > ~/bin/rootsh <<'EOF'
#!/usr/bin/env bash
exec sudo -E bash "$@"
EOF
chmod +x ~/bin/rootsh

cat > ~/bin/claude-root <<'EOF'
#!/usr/bin/env bash
exec /home/droid/.local/bin/claude --dangerously-skip-permissions "$@"
EOF
chmod +x ~/bin/claude-root

# ~/bin/android — VM→Android bridge helper
cat > ~/bin/android <<'BRIDGE'
#!/usr/bin/env bash
# android — run commands on the Android host from inside this VM.
set -euo pipefail
PORT=5555
IP_CACHE=$HOME/.cache/android-host-ip
mkdir -p "$(dirname "$IP_CACHE")"
detect_ip() {
  if [ -s "$IP_CACHE" ]; then
    local cached; cached=$(cat "$IP_CACHE")
    if timeout 1 bash -c "echo > /dev/tcp/$cached/$PORT" 2>/dev/null; then echo "$cached"; return; fi
  fi
  local gw; gw=$(ip route | awk '/^default/ {print $3; exit}')
  if [ -n "$gw" ] && timeout 1 bash -c "echo > /dev/tcp/$gw/$PORT" 2>/dev/null; then
    echo "$gw" > "$IP_CACHE"; echo "$gw"; return
  fi
  echo ""
}
ensure_connected() {
  local ip; ip=$(detect_ip)
  [ -z "$ip" ] && { echo "error: no Android adb on port $PORT" >&2; exit 2; }
  adb connect "$ip:$PORT" >/dev/null 2>&1 || true
  local st; st=$(adb -s "$ip:$PORT" get-state 2>&1 || true)
  [ "$st" = "device" ] || { echo "error: adb not ready ($st)" >&2; exit 3; }
  echo "$ip:$PORT"
}
cmd=${1:-shell}
case "$cmd" in
  ip) detect_ip ;;
  reconnect) rm -f "$IP_CACHE"; adb kill-server; adb start-server; ensure_connected ;;
  ""|shell) dev=$(ensure_connected); exec adb -s "$dev" shell ;;
  su) shift; dev=$(ensure_connected); adb -s "$dev" shell "su -c $(printf '%q' "$*")" ;;
  sh) shift; dev=$(ensure_connected); adb -s "$dev" shell "$*" ;;
  install) shift; dev=$(ensure_connected); bn=$(basename "$1")
    adb -s "$dev" push "$1" "/data/local/tmp/$bn" >/dev/null
    adb -s "$dev" shell "su -c 'pm install -r /data/local/tmp/$bn && rm /data/local/tmp/$bn'" ;;
  tap)  shift; dev=$(ensure_connected); adb -s "$dev" shell "su -c 'input tap $1 $2'" ;;
  text) shift; dev=$(ensure_connected); esc=$(echo "$*" | sed 's/ /%s/g')
    adb -s "$dev" shell "su -c 'input text \"$esc\"'" ;;
  *) echo "unknown subcommand: $cmd" >&2; exit 1 ;;
esac
BRIDGE
chmod +x ~/bin/android

# ---- 6. Voice stack (whisper.cpp input + Piper neural TTS output) ----
if [ ! -x ~/bin/whisper-cli ]; then
  mkdir -p ~/src && cd ~/src
  if [ ! -d whisper.cpp ]; then
    git clone --depth=1 https://github.com/ggerganov/whisper.cpp.git
  fi
  cd whisper.cpp
  cmake -B build -DWHISPER_OPENBLAS=OFF -DGGML_NATIVE=OFF -DGGML_CPU_ARM_ARCH=armv8-a >/dev/null 2>&1
  cmake --build build -j --config Release --target whisper-cli >/dev/null 2>&1
  mkdir -p ~/models
  [ -f ~/models/ggml-small.en.bin ] || \
    curl -fsSL -o ~/models/ggml-small.en.bin \
      https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
  cp build/bin/whisper-cli ~/bin/whisper-cli
fi

cat > ~/bin/v <<'V'
#!/usr/bin/env bash
# v — hold-to-talk voice input. Records from mic via arecord, transcribes with
# whisper.cpp, prints transcript.
set -euo pipefail
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
echo "[listening… Ctrl-C to stop]" >&2
arecord -q -f S16_LE -r 16000 -c 1 "$TMP/in.wav" 2>/dev/null &
REC=$!
trap "kill $REC 2>/dev/null; wait $REC 2>/dev/null; true" INT
wait $REC 2>/dev/null || true
~/bin/whisper-cli -m ~/models/ggml-small.en.bin -f "$TMP/in.wav" -nt -ojf "$TMP/out" >/dev/null 2>&1
cat "$TMP/out.json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(' '.join(s['text'].strip() for s in d.get('transcription',[])))" 2>/dev/null || cat "$TMP/in.wav.txt" 2>/dev/null
V
chmod +x ~/bin/v

# Piper TTS: download binary + default voice (aarch64 prebuilt from upstream).
# Audio must be routed through paplay (PulseAudio) so Android's media audio
# manager handles it correctly — raw aplay hits ALSA directly and silently
# drops on VirtIO. See D27.
if [ ! -x ~/piper/bin/piper ]; then
  mkdir -p ~/piper
  curl -fsSL -o /tmp/piper.tgz \
    https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_aarch64.tar.gz
  tar -xzf /tmp/piper.tgz -C ~/piper --strip-components=1
  rm /tmp/piper.tgz
fi
mkdir -p ~/piper/voices
for v in en_US-amy-medium en_US-libritts_r-medium; do
  if [ ! -f ~/piper/voices/$v.onnx ]; then
    base="https://huggingface.co/rhasspy/piper-voices/resolve/main"
    case $v in
      en_US-amy-medium)        path="en/en_US/amy/medium/$v" ;;
      en_US-libritts_r-medium) path="en/en_US/libritts_r/medium/$v" ;;
    esac
    curl -fsSL -o ~/piper/voices/$v.onnx       "$base/$path.onnx"
    curl -fsSL -o ~/piper/voices/$v.onnx.json  "$base/$path.onnx.json"
  fi
done

# Install working say + Stop hook from repo (see scripts/vm-files/).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"
install -m 755 "$SCRIPT_DIR/vm-files/say"                 ~/bin/say
mkdir -p ~/.claude/hooks
install -m 755 "$SCRIPT_DIR/vm-files/speak-response.sh"   ~/.claude/hooks/speak-response.sh

# ---- 8. Claude settings: bypassPermissions by default ----
mkdir -p ~/.claude
cat > ~/.claude/settings.local.json <<'JSON'
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)", "WebFetch(*)"]
  }
}
JSON

echo "[vm-provision] done at $(date)"
