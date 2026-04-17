# HANDOFF — Session-to-session pickup

**Last updated:** 2026-04-17 evening — Pixel 8 successfully rooted on stock Android 16 + Magisk v30.7.

**Current status:** **v0.2 in flight.**
- **Galaxy S20 FE (Verizon, Path B):** ✅ shipped — stock Android + bloatware-stripped, Claude Code 2.1.112 running, SSH on 8022, OpenBrain MCP wired.
- **Pixel 8 (Path A):** ✅ stock Android 16 flashed via flash.android.com, ✅ Magisk v30.7 rooted (init_boot.img patched, slot B active, slot A = clean-stock bailout). **⏳ Provisioning in progress** — Termux APK install blocked on "Install via USB" Developer Option, user toggling it now.
- **Galaxy S23 Ultra:** not started.

## Next actions, in priority order

1. **Finish Pixel 8 provisioning** (user's current focus):
   - User toggles Settings → Developer options → **Install via USB** ON.
   - Re-run `bash flash-device.sh` — should install Termux/Termux:Boot/Termux:API cleanly.
   - On phone, run `termux-setup-storage` → grant → `cp ~/storage/downloads/devbox/* ~/ && bash ~/provision.sh`.
   - Run `devbox wizard` to configure Anthropic auth, sync, MCP.
   - Verify `claude` works; verify SSH on port 8022 works.
2. **Grant Magisk root to Termux** (Path A extension):
   - Open Magisk app → Superuser tab → Termux → grant.
   - Verify `su` works inside Termux. Document in README / FAQ.
3. **Root-aware provisioning tweaks** (optional v0.2):
   - If `su` available: install systemless hosts module for on-device ad-blocking.
   - If `su` available: enable stronger kiosk lockdown via system-level launcher pinning.
4. **Path B bloatware-strip script** — consolidate the 195 commands used on S20 FE into `strip-bloat-s20.sh` and check it in.
5. **Galaxy S23 Ultra** — acquire, repeat Path A or Path B based on carrier.
6. **Production run prep** — decide batch size (10? 20?), finalize logo, write eBay/Skool listing copy.

## Blockers for shipping a production run

- [ ] Pixel 8 full end-to-end validated (currently in progress).
- [ ] `strip-bloat-s20.sh` checked in (currently manual).
- [ ] SHA256 pins populated in `flash-device.sh` (nice-to-have).
- [ ] Logo selected (5 options generated, none chosen).
- [ ] Real-world smoke test on one fully-provisioned device.

## What happened in this session (2026-04-17 evening)

1. Resumed from dropped session. Searched Open Brain, found `project:devbox` entry showing Pixel 8 mid-flash back to stock.
2. Verified shiba-factory.zip on disk was complete (3.73 GB), USB drivers installed, ADB working.
3. User opened [flash.android.com](https://flash.android.com) → we pivoted to Flash Tool instead of manual fastboot. Better choice for the product workflow.
4. Hit "device in use by another program" — resolved by killing the ADB server.
5. Flashed `shiba-user BP4A.251205.006` with Wipe + Force Flash + bootloader-stays-unlocked. ~15 min.
6. On boot, set up Android 16, enabled USB debugging, authorized ADB.
7. Extracted `init_boot.img` from factory zip, downloaded Magisk v30.7 APK, installed both to phone.
8. User patched `init_boot.img` via Magisk app. Patched file pulled back to PC.
9. `fastboot flash init_boot magisk_patched.img` → slot B flashed in 0.235s → reboot.
10. Magisk app on boot confirmed root installed with ramdisk support. 🎉
11. Started `flash-device.sh` — Termux APK install failed on Install via USB restriction.
12. Pivoted to doc update pass — the entire repo was still describing the LineageOS direction. README, SCOPE, DECISIONS, FLASH, HANDOFF rewritten to reflect stock+Magisk two-path strategy. (This commit.)

## Key learnings baked into docs

- **Pixel 8 patches init_boot.img, NOT boot.img** (D18)
- **Flash Tool is the Pixel path** (D16) — zero-install, handles A/B, removes typo-risk
- **Magisk root is additive, never required** (D17) — Path B ships without
- **Git Bash path mangling** bites `adb push /sdcard/...` — use `MSYS_NO_PATHCONV=1`
- **ADB server and Flash Tool fight over USB** — always `adb kill-server` before Flash Tool

## Key files and artifacts

| Artifact | Location | Purpose |
| --- | --- | --- |
| Repo | `R:\Projects\ai-phone-agent` + `github.com/JoJa84/DevBox` | Source of truth |
| ADB/fastboot | `C:\platform-tools` | Device communication |
| Factory image (shiba) | `R:\Downloads\Delete Later\shiba-factory.zip` | Stock Android 16 for Pixel 8 |
| Extracted stock init_boot | `R:\Downloads\Delete Later\init_boot.img` | Pre-Magisk patching source |
| Magisk-patched init_boot | `R:\Downloads\Delete Later\magisk_patched.img` | Flashed to Pixel 8 slot B |
| Magisk APK | `R:\Downloads\Delete Later\magisk\Magisk-v30.7.apk` | Installed on Pixel 8 |
| SSH keys | `R:\Downloads\Delete Later\devbox_key(.pub)` | Shared between devices |
| S20 apks/configs | `R:\Downloads\Delete Later\devbox-s20-apks\` | Reference from shipped device |
| Open Brain canonical | `project:devbox` (ID 2292161) | Long-term memory |

## Protocol for any continuation sessions

1. **Check Open Brain** — `memory_search "project:devbox"` returns canonical state.
2. **Read `SCOPE.md`** — locked v0.2 scope with two-path strategy.
3. **Read `DECISIONS.md`** — D1–D18. D15–D18 are the pivot decisions.
4. **Check `git log --oneline -20`** — see what's been committed.
5. **Do the next item** — see "Next actions" above.
6. **Before ending the session, update this file AND the Open Brain entry.**
7. **Commit atomically** using conventional commits.

## Rules that still apply

- Joe is not a developer. Decide and execute. No technical branching questions.
- On 50/50 decisions: pick the simpler path, ship it, record in `DECISIONS.md`.
- Do not break working code. `bash -n <script>` before committing.
- Preserve the A-slot bailout lane on Pixels (never flash Magisk to both slots).
