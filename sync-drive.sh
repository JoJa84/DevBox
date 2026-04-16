#!/data/data/com.termux/files/usr/bin/bash
#
# sync-drive.sh — backup-style sync of ~/projects to Google Drive via rclone.
#
# First run (with --setup): runs 'rclone config' to create a 'devbox-drive'
#   remote. Google Drive requires a one-time OAuth in a browser. The user
#   follows rclone's link, signs in, pastes back a token.
#
# Subsequent runs (no args): push-only. Copies ~/projects to
#   Drive:devbox/projects. Deletes remote files no longer local.
#
# Note: this is intentionally NOT a two-way sync. rclone bisync exists but is
# beta-quality; for v0 we treat Drive as a backup target. If the user wants
# bidirectional, they should pick the GitHub option. Documented in wizard.sh.

set -euo pipefail

DEVBOX_HOME="$HOME/.devbox"
PROJECTS_DIR="$HOME/projects"
REMOTE_NAME="devbox-drive"
REMOTE_PATH="${REMOTE_NAME}:devbox/projects"

log()  { printf "\033[1;36m[sync:drive]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[sync:drive:warn]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[sync:drive:err]\033[0m %s\n" "$*" >&2; }

# ─── Setup ──────────────────────────────────────────────────────────────────

setup() {
    log "Google Drive sync setup."
    echo

    if ! command -v rclone >/dev/null 2>&1; then
        err "rclone not installed. provision.sh should have installed it — run 'pkg install rclone' and retry."
        return 1
    fi

    # Does the remote already exist?
    if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
        log "Remote '${REMOTE_NAME}' already configured."
        printf "Reconfigure it? (y/N): "
        read -r redo
        if [ "${redo,,}" = "y" ]; then
            rclone config delete "${REMOTE_NAME}"
        else
            log "Keeping existing config."
            mkdir -p "$DEVBOX_HOME"
            touch "$DEVBOX_HOME/drive-configured"
            return 0
        fi
    fi

    cat << 'SETUP_EOF'

  rclone will now ask you a series of questions. Answer as follows:

    n) New remote
    name> devbox-drive
    Storage> drive      (or type 'drive' and pick the number it shows)
    client_id> (leave blank, press Enter)
    client_secret> (leave blank, press Enter)
    scope> 3            (drive.file — files rclone creates only;
                         DevBox cannot read your existing Drive files,
                         only the ones it writes to its own folder)
    service_account_file> (leave blank, press Enter)
    Edit advanced config> n
    Use auto config> n  (important: say N so you get a URL)
    ...then open the URL it prints, sign in with Google, and paste
    the code it gives you back into rclone.
    Configure as Shared Drive> n
    Keep this 'devbox-drive' remote> y
    q) Quit config

  When you see the 'Current remotes:' list with devbox-drive in it,
  choose 'q' to quit.

  Why scope 3 (drive.file)? DevBox only needs to read/write its own
  backup folder. Scope 1 (Full access) would let rclone — and anything
  with access to this device — read your entire Google Drive. We pick
  the minimum permission that gets the job done.

SETUP_EOF

    printf "Press Enter to start rclone config..."
    read -r _

    rclone config

    if rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
        mkdir -p "$DEVBOX_HOME"
        touch "$DEVBOX_HOME/drive-configured"
        log "Drive sync configured."
        log "  Remote: ${REMOTE_NAME}"
        log "  Target: Drive:devbox/projects"
        log "  Run 'devbox sync' any time to push changes."
    else
        err "Drive remote not created. Re-run: bash $0 --setup"
        return 1
    fi
}

# ─── Push ───────────────────────────────────────────────────────────────────

sync_push() {
    if ! command -v rclone >/dev/null 2>&1; then
        err "rclone not installed."
        return 1
    fi
    if ! rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
        err "Drive sync not configured. Run: bash $0 --setup"
        return 1
    fi
    if [ ! -d "$PROJECTS_DIR" ]; then
        err "$PROJECTS_DIR does not exist."
        return 1
    fi

    log "Syncing $PROJECTS_DIR to $REMOTE_PATH ..."
    rclone sync \
        --progress \
        --exclude "node_modules/**" \
        --exclude ".git/**" \
        --exclude "*.log" \
        --exclude ".DS_Store" \
        "$PROJECTS_DIR" "$REMOTE_PATH"
    log "Sync complete."
}

# ─── Pull (explicit — not default) ──────────────────────────────────────────

sync_pull() {
    if ! rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:"; then
        err "Drive sync not configured. Run: bash $0 --setup"
        return 1
    fi

    cat << 'PULL_WARN_EOF'

  PULL will OVERWRITE local files in ~/projects with what's on Drive.

  This is a destructive operation. Local-only files under ~/projects
  that are NOT on Drive will be deleted.

PULL_WARN_EOF
    printf "Continue? (type YES in capitals): "
    read -r confirm
    if [ "$confirm" != "YES" ]; then
        log "Aborted."
        return 0
    fi

    mkdir -p "$PROJECTS_DIR"
    log "Pulling $REMOTE_PATH to $PROJECTS_DIR ..."
    rclone sync --progress "$REMOTE_PATH" "$PROJECTS_DIR"
    log "Pull complete."
}

# ─── Entry ──────────────────────────────────────────────────────────────────

case "${1:-}" in
    --setup) setup ;;
    --pull)  sync_pull ;;
    "")      sync_push ;;
    *)       err "Unknown flag: $1"; echo "Usage: $0 [--setup|--pull]"; exit 1 ;;
esac
