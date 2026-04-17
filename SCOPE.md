# SCOPE (v0.2 — post-Magisk-pivot, locked)

Joe approved this scope. Do not re-litigate it.

## Target

- **Device:** Any modern Android 12+ phone. Test fleet: Google Pixel 8 128GB, Galaxy S20 FE 5G 128GB, Galaxy S23 Ultra 256GB.
- **OS strategy (two paths):**
  - **Path A — Unlockable bootloader (Pixel, unlocked Samsungs):** stock Android flashed via [flash.android.com](https://flash.android.com). Bootloader unlocked. Magisk root via `init_boot.img` patch. Termux runs root-aware.
  - **Path B — Carrier-locked bootloader (e.g., Verizon-locked Samsung S20 FE):** stock Android as shipped. Bootloader stays locked. Bloatware stripped via `adb shell pm uninstall --user 0 ...`. Unrooted Termux — still full Linux userland, just no `su`.
- **Custom ROM:** explicitly rejected. See `DECISIONS.md` D15 (pivot from LineageOS).
- **Kiosk strategy:** best-effort with Android Screen Pinning + launcher configuration. Full lockdown is v1.

## User experience

- **First boot:** Wizard walks buyer through WiFi → Anthropic OAuth (`claude login`) → keyboard mode (voice-first or Bluetooth keyboard) → sync choice (GitHub or Drive) → done.
- **Normal use:** Unlock phone → tap DevBox icon → terminal opens running `claude`. Screen pinning keeps them there.
- **Code sync:** `~/projects` (code only — not `~/.claude`) pushes to the buyer's chosen remote on demand via `devbox sync`. GitHub path is bidirectional (pull + push); Drive path is one-way backup (push only).
- **Why not sync `~/.claude`?** It contains Claude Code credentials and conversation history. Keeping it on-device avoids leaking auth tokens to a cloud remote and matches the "isolation from your main machine" positioning.

## Claude Code setup

- Installed in Termux via `npm install -g @anthropic-ai/claude-code` (official package).
- MCP servers preloaded: **filesystem, git, github, web-fetch**.
- Billing: **BYOA** (buyer brings own Anthropic account). Wizard links out to `claude.ai` signup if they don't have one.

## Root-enabled features (Path A only, best-effort)

- `su` available to Termux via Magisk "Superuser" grant.
- System-level writes for pinning/launcher lockdown (kiosk-v2 candidate).
- Systemless hosts module option for ad-blocking at the DNS level on-device.
- Everything above is **additive** — Path B devices ship without them and still work.

## Branding

- Name: **DevBox** for v0. TM risk flagged in `BRAND-RISK.md`.
- Brand string appears in user-visible docs only — never hardcoded into file names or scripts. Rename is cheap.

## What's explicitly NOT in v0

- Custom ROM / LineageOS fork.
- Branded bootscreen / animations.
- Bundled Bluetooth keyboard (future product decision).
- Prepaid API credits / any Anthropic ToS-adjacent billing setup.
- Relocking the bootloader after flashing (would brick Magisk-patched devices).

## Build work sequence (v0.2)

1. Docs foundation (README, SCOPE, HANDOFF, DECISIONS, BRAND-RISK, FLASH) ✅
2. `provision.sh` — Termux install of Node, Claude Code CLI, MCP packages ✅
3. `wizard.sh` — interactive first-boot ✅
4. `mcp-config.json` — preloaded MCP config ✅
5. `sync-github.sh` + `sync-drive.sh` — state sync ✅
6. `kiosk-setup.md` + `reflash-to-stock.md` ✅
7. Fill out `FLASH.md` two-path step-by-step for cousin ⏳
8. Codex adversarial review → fix findings → commit ✅ (v0.1)
9. **Pivot doc pass** — update all docs to reflect stock+Magisk direction ⏳
10. Final polish, update `HANDOFF.md`

## Decision protocol

Joe delegated all build-time decisions. On 50/50 calls: pick the simpler path, ship, note the alternative in `DECISIONS.md`. Do **not** leave a question in `HANDOFF.md` asking Joe — make the call yourself.
