# SCOPE (v0, locked)

Joe approved this scope before sleeping. Do not re-litigate it.

## Target

- **Device:** Galaxy S22 (refurbished stock from cousin's shop).
- **OS strategy:** Stock Android 13/14 with Termux as the userland. No custom ROM in v0.
- **Kiosk strategy:** Best-effort with Android Screen Pinning + launcher configuration. Full lockdown is v1.

## User experience

- **First boot:** Wizard walks buyer through WiFi → Anthropic OAuth (`claude login`) → keyboard mode (voice-first or Bluetooth keyboard) → sync choice (GitHub or Drive) → done.
- **Normal use:** Unlock phone → tap DevBox icon → terminal opens running `claude`. Screen pinning keeps them there.
- **State sync:** `~/.claude` (settings, history, MCP state) and `~/projects` (code) push to the buyer's chosen remote on interval and on demand.

## Claude Code setup

- Installed in Termux via `npm install -g @anthropic-ai/claude-code` (official package).
- MCP servers preloaded: **filesystem, git, github, web-fetch**.
- Billing: **BYOA** (buyer brings own Anthropic account). Wizard links out to `claude.ai` signup if they don't have one.

## Branding

- Name: **DevBox** for v0. TM risk flagged in `BRAND-RISK.md`.
- Brand string appears in user-visible docs only — never hardcoded into file names or scripts. Rename is cheap.

## What's explicitly NOT in v0

- Custom ROM / LineageOS fork.
- Branded bootscreen / animations.
- Bundled Bluetooth keyboard (future product decision).
- Prepaid API credits / any Anthropic ToS-adjacent billing setup.
- Anything requiring Google Play Services certification.

## Build work sequence

1. Docs foundation (README, SCOPE, HANDOFF, DECISIONS, BRAND-RISK, rename BRIEF, FLASH stub)
2. `provision.sh` — Termux install of Node, Claude Code CLI, MCP server packages
3. `wizard.sh` — interactive first-boot
4. `mcp-config.json` — preloaded MCP config
5. `sync-github.sh` + `sync-drive.sh` — state sync
6. `kiosk-setup.md` + `reflash-to-stock.md`
7. Fill out `FLASH.md` step-by-step for cousin
8. Codex adversarial review → fix findings → commit
9. Final polish, update `HANDOFF.md`

## Decision protocol

Joe delegated all build-time decisions. On 50/50 calls: pick the simpler path, ship, note the alternative in `DECISIONS.md`. Do **not** leave a question in `HANDOFF.md` asking Joe — make the call yourself.
