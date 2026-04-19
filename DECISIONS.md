# DECISIONS — Non-obvious build-time choices

Each entry: what was picked, what was rejected, why. Future sessions read this to avoid re-litigating.

---

## D1 — Termux on stock Android over a custom ROM

**Pick:** Install Termux (from F-Droid) on stock Android. Claude Code runs inside Termux.
**Rejected:** LineageOS fork; bespoke AOSP ROM; PostmarketOS.
**Why:** Custom ROM is weeks of work (device trees, signing, OTA infra) for a beta of 20 units. Termux is production-ready, ships Node/npm/git trivially, works on unrooted stock Android, and has addons (Boot, API) that cover what we need.
**Tradeoff:** Less lockdown than a custom ROM. Sophisticated buyers can leave Termux and explore stock Android. Acceptable for a developer-targeted beta.

## D2 — BYOA billing, not bundled credits

**Pick:** Buyer signs into their own Anthropic account via `claude login` at first boot.
**Rejected:** Pre-loading an API key or credits on the device.
**Why:** Bundled credits likely violate Anthropic's ToS (unattributed automated use), create ongoing liability (per-device cost forever), and couple device sales to API economics.
**Tradeoff:** Buyer needs an Anthropic account. Wizard links to `claude.ai` signup if they don't have one.

## D3 — Ship under "Codefone" despite TM risk

**Pick:** Ship v0 as "Codefone", flag the Microsoft Azure Dev Box trademark concern, make rename cheap (~15 min grep/replace).
**Rejected:** Rename to Loom / Anvil / Kiln upfront.
**Why:** Joe chose Codefone. Brand appears only in user-facing docs, not in file paths or scripts. Risk is managed in `BRAND-RISK.md`.

## D4 — Termux from F-Droid, not Play Store

**Pick:** Flash script sideloads Termux + Termux:Boot + Termux:API from F-Droid APKs (or bundled APK files).
**Rejected:** Play Store Termux install.
**Why:** The Play Store build of Termux was deprecated in 2022 and no longer receives updates. F-Droid is the authoritative source.
**Tradeoff:** Cousin's flash process needs to enable "Install unknown apps" once. Documented in `FLASH.md`.

## D5 — Screen Pinning over third-party launcher for kiosk-ish behavior

**Pick:** Use Android's built-in Screen Pinning (Settings → Security → Pin windows) plus a lightweight launcher configuration to hide other apps.
**Rejected:** Third-party kiosk launcher (costs, trust, support).
**Why:** Screen Pinning is free, built-in, and escapable with a PIN (so the buyer isn't locked out of their own device if something breaks). It's not true kiosk lockdown but matches v0's "this is a dev sandbox, not a consumer appliance" positioning.
**Tradeoff:** Sophisticated users can escape. That's fine — the *isolation* from their main machine is the product, not the *lockdown* of this device.

## D6 — State sync offers both GitHub and Drive; wizard picks one

**Pick:** Ship both `sync-github.sh` and `sync-drive.sh`. Wizard asks once, writes choice to `~/.codefone/sync-method`.
**Rejected:** GitHub-only (devs like it, but some buyers don't have GitHub); both-simultaneously (double complexity for no benefit).
**Why:** Joe picked "both, user decides" in the questionnaire.
**Tradeoff:** Two code paths to maintain. Acceptable because each path is a ~50-line shell script.

## D7 — npm global install for Claude Code, not a containerized install

**Pick:** `npm install -g @anthropic-ai/claude-code` in Termux.
**Rejected:** Docker/podman in Termux; nix; pkgx.
**Why:** Containers don't run natively in unrooted Termux (no user namespaces without proot-distro). npm global install is the official install path, is well-supported, and is a 30-second operation.
**Tradeoff:** Updates are `npm update -g` — the user needs to run this occasionally. `wizard.sh` writes a `codefone update` alias that does it.

## D8 — Provision script is idempotent and re-runnable

**Pick:** `provision.sh` checks "is X installed?" before installing, and `wizard.sh` checks "is X configured?" before prompting.
**Rejected:** One-shot "only runs once" scripts.
**Why:** Re-runnability lets cousin debug without reflashing, and lets the buyer recover from a botched setup without starting over.
**Tradeoff:** Slightly more code. Worth it.

---

## D9 — GitHub PAT is stored via git's credential-helper, never in repo config

**Pick:** `sync-github.sh` keeps the remote URL credential-free (`https://github.com/u/r.git`) and authenticates each git operation with a chmod-600 credentials file consumed by `git -c credential.helper="store --file=..."`.
**Rejected:** Embedding the PAT in origin's URL (the simpler path).
**Why:** The embedded-URL pattern writes the token into `.git/config`, where any process inside Termux — including Claude Code itself, which has filesystem MCP access to the repo — can trivially exfiltrate it. Credential file in `$CODEFONE_HOME/git-credentials` with `chmod 600` limits the attack surface.
**Tradeoff:** Slightly more complex sync code. Worth it for a device that's explicitly marketed as a "sandbox the agent can't escape from" — a readable PAT would make that promise a lie.

## D10 — GitHub sync refuses to push to a public repo

**Pick:** During `--setup`, if the named repo already exists and is not private, `sync-github.sh` aborts with an error.
**Rejected:** Warn-and-continue; auto-privatize existing public repos.
**Why:** Project code on a sandbox device can include secrets the user forgot to redact. Leaking that to a public repo because we didn't check is a foot-gun. Auto-privatizing someone else's existing repo is presumptuous.

## D11 — MCP servers wired at user scope, not project scope

**Pick:** `wizard.sh` registers every MCP with `claude mcp add --scope user`.
**Rejected:** Default (local/project) scope.
**Why:** Claude Code's default local scope binds MCPs to the cwd at registration time. Buyers will `cd` into various project subdirectories — registering at user scope means the servers are available everywhere without re-registration.

## D12 — Google Drive sync uses drive.file, not full Drive access

**Pick:** rclone setup guides the buyer to scope 3 (drive.file — files rclone creates only).
**Rejected:** scope 1 (Full access — Codefone can see every file in the buyer's Drive).
**Why:** Codefone only needs to read/write its own backup folder. Full-drive access violates least-privilege and would let a compromised agent enumerate the buyer's entire Google Drive. drive.file limits exposure to the Codefone backup folder only.
**Tradeoff:** If the buyer wants to pull existing Drive files onto the device, they'd need a wider scope. For v0, that's a feature we're not offering.

## D13 — Filesystem MCP install is install-fatal; github / fetch MCPs are warn-only

**Pick:** `provision.sh` exits non-zero if `@modelcontextprotocol/server-filesystem` or `mcp-server-git` fails to install. github and fetch are optional.
**Rejected:** Warn-only on everything (the original behavior — let provisioning "complete" with missing MCPs).
**Why:** Claude Code without filesystem access is useless. Shipping a device that installed-but-broken is worse than failing early and visibly. github and fetch are nice-to-have — their absence degrades but doesn't cripple the device.

## D14 — APK versions pinned with fallback to GitHub latest-release API

**Pick:** `flash-device.sh` encodes an explicit version string and URL for each of the three Termux APKs, plus an empty SHA256 slot ready for a hash pin. Unauthenticated GitHub latest-release API is a fallback, not the primary path.
**Rejected:** Always use `releases/latest` (the original behavior).
**Why:** Unauthenticated GitHub API is rate-limited to 60 requests/hour per IP. A shop flashing 20 phones in an afternoon would either hit the limit or inherit whatever upstream breaking change happened to ship that morning. Pinning gives deterministic behavior across a batch; the fallback covers "we moved to a newer version and forgot to update the script."

---

## D15 — Pivot from LineageOS back to stock Android (2026-04-17)

**Pick:** Ship Codefone on **stock Android**, not LineageOS. On Pixel-class devices with unlockable bootloaders, add Magisk root as an additive feature.
**Rejected:** LineageOS as the default OS (the original v0.1 direction).
**Why:** LineageOS was picked for "isolation / no Google services." In practice on Pixel 8:
- **Broken UX debts:** no TTS engine ships by default, several voice input paths fail on Android 16 (`termux-speech-to-text` BadTokenException), Signal 11 Termux crashes observed.
- **No Play Store** means customers can't install the voice keyboards and apps they expect (Whisper Input, Gboard).
- **Isolation was already handled by Termux.** Claude Code is sandboxed at the process level regardless of underlying OS — LineageOS added no meaningful security, only friction.
- **Worse for reselling.** Customers buy a "phone that runs Claude Code," not "a phone with a weird OS."
Stock Android with bloatware stripped + optional Magisk root gives root-where-we-can + app compat + security patches + familiar UX. Net win.
**Tradeoff:** We lose the "runs a clean de-Googled OS" marketing line. Replaced with "real Android, no clutter, optional root" — arguably stronger for the target buyer.

## D16 — Flash Tool (flash.android.com) over manual fastboot for Pixel-path flashing

**Pick:** Use Google's official web-based Android Flash Tool (flash.android.com) as the primary flashing path for Pixels. Manual fastboot-from-CLI is the documented fallback.
**Rejected:** Command-line only (the "pro" path). Heimdall / Odin (Samsung-only, wrong device family).
**Why:** Flash Tool is zero-install (runs in Chrome/Edge via WebUSB), handles A/B slot flashing correctly, keeps the bootloader unlocked by default for our workflow, and is officially supported by Google for every Pixel. It removes the biggest human-error risk from the flashing step — typos in fastboot commands. For Joe's cousin flashing 20 devices, a web UI with a "Flash" button beats a command transcript every time.
**Tradeoff:** Requires Chrome/Edge and a live USB connection for ~15 min. Requires killing any running ADB server (one-process-owns-USB rule) — documented in `FLASH.md`.

## D17 — Magisk root is best-effort and additive; never required

**Pick:** Magisk root is installed on devices that can be unlocked (Pixels, unlocked Samsungs). Path B devices (carrier-locked Samsungs) ship without root. All Codefone core features (Claude Code, Termux, SSH, sync) must work without root. Root unlocks *additional* features (hardened kiosk mode, systemless hosts blocklist).
**Rejected:** "Rooted devices only" as a product positioning (excludes carrier-locked resale stock). Requiring root for any core feature.
**Why:** The S20 FE (Verizon) has a permanently locked bootloader. Joe's cousin's inventory includes many such devices. Making root a requirement would cut our addressable supply dramatically. And practically, Termux + Claude Code on unrooted stock Android is indistinguishable from the rooted experience for 95% of coding work.
**Tradeoff:** Two device paths to document and QA. Acceptable because Path A and Path B converge at step 2 (Termux provisioning) — they only differ in the initial flashing step.

## D18 — Pixel 8 Magisk patches `init_boot.img`, NOT `boot.img`

**Pick:** Extract `init_boot.img` from the factory zip, patch via Magisk's "Patch a File" mode, flash with `fastboot flash init_boot magisk_patched.img` to active slot only.
**Rejected:** Patching `boot.img` (the pre-Android 13 path). Flashing to both slots simultaneously.
**Why:** Pixel 8 (shiba) and all Pixel 7-class+ devices split kernel and ramdisk into separate partitions — `boot.img` holds the kernel, `init_boot.img` holds the ramdisk. Magisk's code-injection point is the ramdisk. Patching the wrong partition does nothing (if we're lucky) or bootloops (if we're not). Flashing only the active slot preserves the inactive slot as a clean-stock recovery option: `fastboot set_active <other>` recovers a botched root in 3 seconds.
**Tradeoff:** Requires knowing which partition to patch per device. Magisk v26+ auto-detects from the image type, so as long as we feed it the right file, it patches correctly. We also document the partition explicitly in FLASH.md so nothing relies on implicit detection.

---

## D19 — Pivot from Termux to Android's Linux Terminal (Debian VM) on Pixel (2026-04-17)

**Pick:** On Pixel 8+ (Android 15+), Claude Code runs inside **Android's native Linux Terminal** — a Debian VM backed by the Android Virtualization Framework (AVF). Termux is abandoned on this path.
**Rejected:** Termux on Pixel (the original v0.2 plan).
**Why:** Claude Code 2.1.x ships a pre-built native binary (`@anthropic-ai/claude-code-linux-arm64-musl`) that expects a musl dynamic linker at `/lib/ld-musl-aarch64.so.1`. Termux's Bionic libc lacks that linker — the binary fails to exec on Android at the ABI level. Patching Termux to fake a `linux-arm64-musl` platform gets the npm install past the platform check, but the binary still can't load. Android 15's Linux Terminal provides a real Debian rootfs with glibc, where the official installer `curl -fsSL https://claude.ai/install.sh | bash` produces a working binary in ~30 seconds. Confirmed `2.1.113 (Claude Code)` running natively on Pixel 8.
**Tradeoff:**
- **Pixel-only.** Samsung (and any non-Pixel Android 15+ device without the AVF Terminal) stays on the Termux path as legacy. Google is expected to broaden AVF Terminal support in late 2026.
- **VM overhead.** 565 MB rootfs + ~1 GB RAM floor. Acceptable on an 8 GB Pixel 8.
- **"Preparing terminal" hang quirk.** The VM can wedge when the screen locks mid-session. Fix: force-stop + relaunch. Product mitigation: ship a `codefone revive` one-tap script.
- **No Termux add-ons** (Termux:Boot autostart, Termux:API for Android intents). We lose boot-time autostart but gain a real Linux userland. Net positive for a coding agent; neutral for device-integration features we weren't using anyway.

## D20 — Drop Magisk root from Codefone's core requirements (2026-04-17)

**Pick:** Ship Codefone on **pure stock Android**, no root. Magisk is neither required nor recommended.
**Rejected:** Magisk root as an additive feature (D17).
**Why:** The original motivation for root was (a) "run Claude Code with full system access" and (b) kiosk-mode launcher replacement. (a) is solved more cleanly by the Linux Terminal VM — `droid` has full root inside the Debian guest with zero Android-side privilege. (b) turns out to not need root on modern Android (launcher default + Screen Pinning cover the UX). Meanwhile, Magisk on Pixel has a recurring failure mode: Android auto-applies OTAs to the inactive slot, and when the device reboots into that slot, root is silently gone (init_boot reverted to stock). Observed firsthand on our test unit — an OTA to `CP1A.260305.018` flipped the phone from rooted slot B to clean slot A with no warning, making the Magisk app show "Installed: N/A." A product that buyers expect to "just work" cannot have root silently break on a monthly cadence.
**Tradeoff:**
- **Lose iptables-level tweaks** (custom NAT, VPN rules). Not needed for the product.
- **Lose Magisk-module kiosk hardening.** Accept Screen Pinning as the best-available soft lockdown.
- **Simpler docs, smaller attack surface, no "re-root after OTA" support burden.** Net big win for v0.2 shipping quality.

## D21 — Rename DevBox → Codefone (2026-04-19)

**Pick:** Rebrand the project from "DevBox" to **"Codefone"** across all docs, scripts, config paths, CLI command names, and the GitHub repo. Register the Codefone mark; publish a trademark usage policy in TRADEMARKS.md.
**Rejected:** Ship under "DevBox" as a provisional working name (the position held up until 2026-04-19).
**Why:** "DevBox" collides with multiple commercial products in the developer-tools space: **Microsoft Dev Box** (Azure cloud developer workstation, shipping since 2022), **Sealos DevBox** (cloud dev environment), and **Jetify Devbox** (Nix-based dev environments). Even though our product category differs (on-device Linux VM, not cloud workstation), the overlap is close enough for consumer confusion and for any incumbent — particularly Microsoft — to send a cease-and-desist if we reach visibility. Renaming now is cheap (zero forks, zero stars, zero downstream users at time of rename). Renaming at 1,000 users would be expensive and damaging. "Codefone" tested clean: no GitHub repos, no USPTO hits, `codefone.com` available, nearest neighbor is `cophone.io` (semantically adjacent but phonetically distinct).
**Tradeoff:**
- Every prior contributor's existing `~/.devbox/` directory on their own Pixel becomes stale. One-line migration: `mv ~/.devbox ~/.codefone` then re-run `provision.sh`.
- The one external signal we had (43 clones / 30 uniques on 2026-04-17 from Joe's eBay listing) saw the old name on the listing. Listing text needs updating to match.
- Any existing forum posts, Discord mentions, or video demos referencing "DevBox" become orphaned history. Acceptable at this stage — the audience is negligibly small.
- Replaces BRAND-RISK.md (which analyzed the DevBox collision risk and is now obsolete) — deleted in this commit.
