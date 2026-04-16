#!/data/data/com.termux/files/usr/bin/bash
#
# sync-github.sh — bidirectional sync of ~/projects to a PRIVATE GitHub repo.
#
# First run (with --setup): prompts for GitHub username, repo name, PAT;
#   verifies the token's username, creates a private repo if missing
#   (refuses to push into a public repo), initializes ~/projects as a git
#   repo, commits, pushes. Token lives in a chmod-600 credentials file and
#   is NEVER written into origin's URL or .git/config.
#
# Subsequent runs (no args): commits local changes with a timestamp, pulls
#   with rebase, pushes. Fails loudly on any git error.
#
# Only ~/projects is synced. ~/.claude state (auth tokens, conversation
# history) stays on-device. See SCOPE.md.

set -euo pipefail

DEVBOX_HOME="$HOME/.devbox"
PROJECTS_DIR="$HOME/projects"
TOKEN_FILE="$DEVBOX_HOME/github-token"
CRED_FILE="$DEVBOX_HOME/git-credentials"
CONFIG_FILE="$DEVBOX_HOME/github-sync.conf"

log()  { printf "\033[1;36m[sync:gh]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[sync:gh:warn]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[sync:gh:err]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; return 1; }

# ─── Credential helper — keep PAT out of git config and argv ────────────────

write_credentials() {
    # Write https://USER:TOKEN@github.com to a chmod-600 file so git's
    # store helper can read it. URL is never placed in .git/config or CLI args.
    local user="$1" token="$2"
    mkdir -p "$DEVBOX_HOME"
    umask 077
    printf "https://%s:%s@github.com\n" "$user" "$token" > "$CRED_FILE"
    chmod 600 "$CRED_FILE"
}

# Run git with the stored credentials helper attached for this invocation only.
git_auth() {
    git -c "credential.helper=" \
        -c "credential.helper=store --file=$CRED_FILE" \
        "$@"
}

# ─── GitHub API helpers ─────────────────────────────────────────────────────

api_user_from_token() {
    local token="$1"
    curl -s -H "Authorization: token $token" https://api.github.com/user \
        | python -c "import sys,json
d=json.load(sys.stdin)
print(d.get('login',''))" 2>/dev/null
}

api_repo_metadata() {
    local token="$1" user="$2" repo="$3"
    curl -s -w "\n%{http_code}" \
        -H "Authorization: token $token" \
        "https://api.github.com/repos/$user/$repo"
}

api_create_private_repo() {
    local token="$1" repo="$2"
    local response http
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $token" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$repo\",\"private\":true,\"description\":\"DevBox project sync\"}" \
        https://api.github.com/user/repos)
    http=$(printf "%s" "$response" | tail -n1)
    if [ "$http" != "201" ]; then
        err "GitHub API refused to create repo (HTTP $http):"
        printf "%s\n" "$response" | head -n -1 >&2
        return 1
    fi
    return 0
}

# ─── Setup flow ─────────────────────────────────────────────────────────────

setup() {
    log "GitHub sync setup."
    echo

    # Username
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi
    printf "GitHub username [%s]: " "${GH_USER:-}"
    read -r input
    GH_USER="${input:-${GH_USER:-}}"
    [ -z "$GH_USER" ] && die "Username required."

    # Repo name
    printf "Repo name for your DevBox projects [devbox-projects]: "
    read -r input
    GH_REPO="${input:-devbox-projects}"

    # PAT
    echo
    cat << 'TOKEN_EOF'
Now a GitHub Personal Access Token (classic).

  Create one at: https://github.com/settings/tokens/new
  Scopes:        repo (full)

Fine-grained tokens also work — give it "Contents: Read and write"
and "Metadata: Read" on the one repo you're syncing.

TOKEN_EOF
    printf "Paste token (won't be echoed): "
    stty -echo 2>/dev/null
    read -r GH_TOKEN
    stty echo 2>/dev/null
    echo
    [ -z "$GH_TOKEN" ] && die "Token required."

    # Verify token and username match
    log "Verifying token..."
    local who
    who=$(api_user_from_token "$GH_TOKEN")
    [ -z "$who" ] && die "Token rejected by GitHub API."
    if [ "$who" != "$GH_USER" ]; then
        warn "Token verified as user '$who' — you entered '$GH_USER'."
        printf "Use '%s' instead? (y/N): " "$who"
        read -r ok
        if [ "${ok,,}" = "y" ]; then
            GH_USER="$who"
        else
            die "Username mismatch."
        fi
    fi

    # Save non-secret config
    mkdir -p "$DEVBOX_HOME"
    umask 077
    cat > "$CONFIG_FILE" << CONF_EOF
GH_USER="$GH_USER"
GH_REPO="$GH_REPO"
CONF_EOF
    printf "%s" "$GH_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE" "$CONFIG_FILE"
    write_credentials "$GH_USER" "$GH_TOKEN"

    # Repo must exist as PRIVATE or we create it.
    log "Checking repo state..."
    local meta http body
    meta=$(api_repo_metadata "$GH_TOKEN" "$GH_USER" "$GH_REPO")
    http=$(printf "%s" "$meta" | tail -n1)
    body=$(printf "%s" "$meta" | head -n -1)

    case "$http" in
        200)
            # Exists — require private
            local is_private
            is_private=$(printf "%s" "$body" | python -c \
                "import sys,json; print(json.load(sys.stdin).get('private', False))" 2>/dev/null)
            if [ "$is_private" != "True" ]; then
                die "Repo $GH_USER/$GH_REPO is PUBLIC. Refusing to sync project files to a public repo. Pick a different repo name or delete/privatize this one."
            fi
            log "Repo $GH_USER/$GH_REPO exists and is private."
            ;;
        404)
            log "Creating private repo $GH_USER/$GH_REPO..."
            api_create_private_repo "$GH_TOKEN" "$GH_REPO" \
                || die "Repo creation failed."
            ;;
        *)
            err "Unexpected response from GitHub API (HTTP $http):"
            printf "%s\n" "$body" >&2
            die "Aborting."
            ;;
    esac

    # Initialize ~/projects as a git repo if it isn't one
    mkdir -p "$PROJECTS_DIR"
    cd "$PROJECTS_DIR"
    if [ ! -d .git ]; then
        git init -b main >/dev/null
        git config user.name "$GH_USER"
        git config user.email "$GH_USER@users.noreply.github.com"
        # Ambient credential helper: point manual 'git pull'/'git push' inside
        # ~/projects at the same chmod-600 credentials file that git_auth() uses.
        # Without --file, git's default store would be picked up instead, bypassing
        # our token-scoped file entirely.
        git config credential.helper "store --file=$CRED_FILE"

        if [ -z "$(ls -A .)" ]; then
            cat > README.md << README_EOF
# DevBox projects

Synced from a DevBox device. Each subfolder is a project.
README_EOF
        fi

        git add -A
        git commit -m "Initial DevBox sync" >/dev/null
    fi

    # Remote URL is credential-free; git uses the helper for auth.
    local remote_url="https://github.com/${GH_USER}/${GH_REPO}.git"
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "$remote_url"
    else
        git remote add origin "$remote_url"
    fi

    log "Pushing initial commit..."
    if ! git_auth push -u origin main 2>&1 | grep -v "^remote:"; then
        die "Initial push failed. Check network, token scope, and repo permissions."
    fi

    log "GitHub sync configured."
    log "  Repo: https://github.com/$GH_USER/$GH_REPO (private)"
    log "  Token stored: $TOKEN_FILE (chmod 600)"
    log "  Run 'devbox sync' any time to push changes."
}

# ─── Push / pull flow ───────────────────────────────────────────────────────

sync_push_pull() {
    [ -f "$CONFIG_FILE" ] && [ -f "$TOKEN_FILE" ] \
        || die "GitHub sync not configured. Run: bash $0 --setup"

    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    local GH_TOKEN
    GH_TOKEN=$(cat "$TOKEN_FILE")

    # Refresh credentials file (token may have rotated)
    write_credentials "$GH_USER" "$GH_TOKEN"

    cd "$PROJECTS_DIR" || die "$PROJECTS_DIR missing"
    [ -d .git ] || die "$PROJECTS_DIR is not a git repo. Run: bash $0 --setup"

    # Ensure remote URL has no token in it (clean up any legacy state)
    git remote set-url origin \
        "https://github.com/${GH_USER}/${GH_REPO}.git" 2>/dev/null || true

    # Commit local changes
    local changes
    changes=$(git status --porcelain)
    if [ -n "$changes" ]; then
        log "Committing local changes..."
        git add -A
        git commit -m "devbox sync $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null
    else
        log "No local changes."
    fi

    log "Pulling remote..."
    if ! git_auth pull --rebase --autostash origin main 2>&1 | grep -v "^From\|^remote:"; then
        die "Pull failed. Resolve conflicts in $PROJECTS_DIR and re-run 'devbox sync'."
    fi

    log "Pushing..."
    if ! git_auth push origin main 2>&1 | grep -v "^remote:"; then
        die "Push failed. Check network and token validity."
    fi

    log "Sync complete."
}

# ─── Entry point ────────────────────────────────────────────────────────────

case "${1:-}" in
    --setup) setup ;;
    "")      sync_push_pull ;;
    *)       err "Unknown flag: $1"; echo "Usage: $0 [--setup]"; exit 1 ;;
esac
