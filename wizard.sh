#!/data/data/com.termux/files/usr/bin/bash
#
# DevBox wizard.sh — first-boot interactive setup.
#
# Runs after provision.sh has completed. Walks the buyer through:
#   1. Internet check
#   2. Anthropic OAuth (claude login)
#   3. Keyboard mode preference (voice or Bluetooth keyboard)
#   4. State sync choice (GitHub, Google Drive, or skip)
#   5. Initial project directory
#   6. Screen Pinning reminder
#   7. Hand off to Claude Code
#
# Idempotent: re-running picks up where it left off, or reconfigures with --reconfigure.

set -euo pipefail

DEVBOX_HOME="$HOME/.devbox"
mkdir -p "$DEVBOX_HOME"

# ─── Style ──────────────────────────────────────────────────────────────────

BOLD=$'\033[1m'
CYAN=$'\033[1;36m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

banner() {
    clear
    printf "%s" "$CYAN"
    cat << 'BANNER_EOF'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║           D E V B O X                     ║
  ║                                           ║
  ║   Your pocket Claude Code sandbox         ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER_EOF
    printf "%s\n" "$RESET"
}

step() { printf "\n${BOLD}${CYAN}▸ %s${RESET}\n" "$*"; }
ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
err()  { printf "  ${RED}✗${RESET} %s\n" "$*" >&2; }
ask()  { printf "\n${BOLD}%s${RESET} " "$*"; }

pause() {
    printf "\n  ${DIM}Press Enter to continue...${RESET}"
    read -r _
}

# ─── Reconfigure flag ───────────────────────────────────────────────────────

RECONFIGURE=0
if [ "${1:-}" = "--reconfigure" ]; then
    RECONFIGURE=1
    rm -f "$DEVBOX_HOME/wizard-done"
fi

if [ -f "$DEVBOX_HOME/wizard-done" ] && [ "$RECONFIGURE" = "0" ]; then
    # Already done. Fall through to claude launch silently.
    exec claude
fi

# ─── Welcome ────────────────────────────────────────────────────────────────

banner
cat << 'WELCOME_EOF'
  Welcome.

  This is a developer sandbox. A full Claude Code environment in your
  pocket, isolated from your main machine.

  Setup takes about 3 minutes. You'll need:

    • WiFi credentials
    • An Anthropic account (we'll link you if you don't have one)
    • Optional: a GitHub account or Google Drive for state sync

WELCOME_EOF
pause

# ─── Step 1: Internet check ─────────────────────────────────────────────────

step "1/6  Internet check"

check_internet() {
    curl -s -m 5 -o /dev/null -w "%{http_code}" https://api.anthropic.com/ 2>/dev/null | grep -q "^[23]"
}

if check_internet; then
    ok "Connected."
else
    err "No internet. Open Settings → WiFi to connect, then re-run: devbox wizard"
    exit 1
fi

# ─── Step 2: Anthropic OAuth ────────────────────────────────────────────────

step "2/6  Sign into Anthropic"

# Claude Code stores credentials in ~/.claude/.credentials.json after login.
# Check for that file rather than relying on a subcommand whose name has
# shifted between Claude Code releases.
if [ -f "$HOME/.claude/.credentials.json" ] || [ -f "$HOME/.claude/auth.json" ]; then
    ok "Already signed in."
else
    cat << 'AUTH_EOF'

  Running 'claude login' — a browser window opens. Sign into Anthropic.

  To use Claude Code you need one of:
    • A Claude Pro or Claude Max subscription (recommended — runs
      Claude Code against your monthly quota).
    • OR an Anthropic API account with billing set up (pay per token).

  No account? Open https://claude.ai to create one, add a plan, then
  come back here.

AUTH_EOF
    ask "Ready? (y/N)"
    read -r ready
    if [ "${ready,,}" != "y" ]; then
        warn "Skipping for now. Run 'claude login' whenever you're ready."
    else
        claude login || warn "claude login did not complete — you can retry with 'claude login' later."
    fi
fi

# ─── Step 3: Keyboard mode ──────────────────────────────────────────────────

step "3/6  How will you type?"

cat << 'KBD_EOF'

  [1] Voice-first
        Use Termux:API voice-to-text. Great for short prompts.
  [2] Bluetooth keyboard
        Pair a BT keyboard for real coding. (Pair it from Android
        Settings → Connections → Bluetooth, then come back.)
  [3] Both / decide later

KBD_EOF
ask "Pick 1, 2, or 3:"
read -r kbd_choice

case "$kbd_choice" in
    1) echo "voice" > "$DEVBOX_HOME/keyboard-mode"; ok "Saved: voice-first." ;;
    2) echo "bt-keyboard" > "$DEVBOX_HOME/keyboard-mode"; ok "Saved: Bluetooth keyboard." ;;
    *) echo "both" > "$DEVBOX_HOME/keyboard-mode"; ok "Saved: both." ;;
esac

# ─── Step 4: Sync method ────────────────────────────────────────────────────

step "4/6  How should your project code sync to your PC?"

cat << 'SYNC_EOF'

  Only your ~/projects folder syncs — Claude Code's own settings and
  conversation history stay on this device (they contain auth tokens
  and private chats).

  [1] GitHub repo (recommended for developers)
        Your ~/projects pushes to a private GitHub repo.
        You'll need a GitHub Personal Access Token.
        Bidirectional — edit on PC, pull on phone, and vice versa.
  [2] Google Drive folder
        Uses rclone. One-way backup (phone → Drive).
        Pick this if you don't want GitHub.
  [3] Skip for now
        Set up later with 'devbox wizard --reconfigure'.

SYNC_EOF
ask "Pick 1, 2, or 3:"
read -r sync_choice

case "$sync_choice" in
    1)
        echo "github" > "$DEVBOX_HOME/sync-method"
        ok "Saved: GitHub sync."
        if [ -f "$DEVBOX_HOME/sync-github.sh" ]; then
            ask "Set up GitHub now? (y/N)"
            read -r setup_now
            if [ "${setup_now,,}" = "y" ]; then
                bash "$DEVBOX_HOME/sync-github.sh" --setup || \
                    warn "GitHub setup did not complete. Run it later with 'devbox sync'."
            fi
        fi
        ;;
    2)
        echo "drive" > "$DEVBOX_HOME/sync-method"
        ok "Saved: Google Drive sync."
        if [ -f "$DEVBOX_HOME/sync-drive.sh" ]; then
            ask "Set up Drive now? (y/N)"
            read -r setup_now
            if [ "${setup_now,,}" = "y" ]; then
                bash "$DEVBOX_HOME/sync-drive.sh" --setup || \
                    warn "Drive setup did not complete. Run it later with 'devbox sync'."
            fi
        fi
        ;;
    *)
        echo "none" > "$DEVBOX_HOME/sync-method"
        ok "Skipped sync. Configure later with 'devbox wizard --reconfigure'."
        ;;
esac

# ─── Step 5: MCP servers ────────────────────────────────────────────────────

step "5/6  Wiring up MCP servers"

# Wire MCPs at user scope so they're available in any working directory.
# All options go BEFORE <name>; <command> goes after `--`.
#   claude mcp add --scope user [--env K=V] <name> -- <command> [args...]

mcp_exists() {
    # Parse 'claude mcp list' — first whitespace-delimited token per line is name.
    claude mcp list 2>/dev/null | awk '{print $1}' | grep -qx "$1"
}

add_mcp() {
    local name="$1"; shift
    if mcp_exists "$name"; then
        ok "${name} already wired."; return 0
    fi
    if claude mcp add --scope user "$name" "$@" >/dev/null 2>&1; then
        ok "${name} wired."
    else
        warn "${name} wire failed. Retry: claude mcp add --scope user ${name} $*"
    fi
}

add_mcp_with_env() {
    local name="$1" env_assign="$2"; shift 2
    if mcp_exists "$name"; then
        ok "${name} already wired."; return 0
    fi
    if claude mcp add --scope user --env "$env_assign" "$name" "$@" >/dev/null 2>&1; then
        ok "${name} wired."
    else
        warn "${name} wire failed. Retry manually."
    fi
}

add_mcp filesystem -- npx -y @modelcontextprotocol/server-filesystem "$HOME/projects"
add_mcp git        -- python -m mcp_server_git
add_mcp fetch      -- python -m mcp_server_fetch

# GitHub MCP needs a token — only wire it if sync-github.sh wrote one.
if [ -f "$DEVBOX_HOME/github-token" ]; then
    GH_TOKEN=$(cat "$DEVBOX_HOME/github-token")
    add_mcp_with_env github \
        "GITHUB_PERSONAL_ACCESS_TOKEN=${GH_TOKEN}" \
        -- npx -y @modelcontextprotocol/server-github
else
    warn "GitHub MCP skipped (no token). Set up later with 'devbox wizard --reconfigure'."
fi

# ─── Step 6: Screen Pinning reminder ────────────────────────────────────────

step "6/6  Lock this into kiosk mode (optional)"

cat << 'PIN_EOF'

  For a cleaner experience, enable Screen Pinning:

    Settings → Security → Advanced → Pin windows → ON
    Then open this app (Termux), tap the overview button,
    long-press this app's card, and choose "Pin".

  Unpin by holding Back + Overview. Requires your PIN/biometric.

  This is optional. You can always come back to it.

PIN_EOF
pause

# ─── Done ───────────────────────────────────────────────────────────────────

touch "$DEVBOX_HOME/wizard-done"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$DEVBOX_HOME/wizard-done"

banner
cat << 'DONE_EOF'

  Setup complete.

  Launching Claude Code now. Type your first prompt and go.

  Tips:
    • 'devbox status'  — check installed versions and config
    • 'devbox sync'    — push/pull state on demand
    • 'devbox wizard --reconfigure' — change any setting above
    • Exit Claude Code with Ctrl+C, then 'exit' to close Termux.

DONE_EOF
sleep 2

cd "$HOME/projects"
exec claude
