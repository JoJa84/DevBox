# DevBox

A mobile sandbox for Claude Code. A refurbished Galaxy S22, flashed with a Termux-based kiosk, boots into the Claude Code CLI. Log into Anthropic once, start coding on the go, and sync your work back to your PC via GitHub or Google Drive.

## What it is

- **A dedicated device for AI coding agents.** No personal data, no other apps — just Claude Code and your project directory.
- **Secure-by-isolation.** The agent runs on a device that can't touch your main machine. If something goes sideways, reflash and move on.
- **Portable.** It's a phone. Pair a Bluetooth keyboard for real coding, or use voice-first for short prompts.
- **Resumable.** `~/.claude` and `~/projects` sync to a private GitHub repo or Google Drive folder. Start a task in bed, finish at your desk.

## Who it's for

Developers and tinkerers who want to try Claude Code agents without granting `--dangerously-skip-permissions` to their main machine.

## Repo layout

| File | Purpose |
| --- | --- |
| `BRIEF.md` | Original concept pitch (preserved for history) |
| `SCOPE.md` | Locked v0 scope — read first |
| `HANDOFF.md` | Session-to-session continuation state |
| `DECISIONS.md` | Non-obvious build-time choices |
| `BRAND-RISK.md` | Trademark considerations for "DevBox" |
| `FLASH.md` | Cousin's step-by-step for one device |
| `provision.sh` | Termux-side installer |
| `wizard.sh` | First-boot interactive setup |
| `sync-github.sh` | State sync via private GitHub repo |
| `sync-drive.sh` | State sync via Google Drive (rclone) |
| `mcp-config.json` | Preloaded MCP servers |
| `kiosk-setup.md` | Rooted vs. stock lockdown options |
| `reflash-to-stock.md` | Recovery path (safety net) |

## Status

v0 beta. Target: flash 1–3 units for internal test, then 20 units for the first eBay listing.
