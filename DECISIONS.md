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

## D3 — Ship under "DevBox" despite TM risk

**Pick:** Ship v0 as "DevBox", flag the Microsoft Azure Dev Box trademark concern, make rename cheap (~15 min grep/replace).
**Rejected:** Rename to Loom / Anvil / Kiln upfront.
**Why:** Joe chose DevBox. Brand appears only in user-facing docs, not in file paths or scripts. Risk is managed in `BRAND-RISK.md`.

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

**Pick:** Ship both `sync-github.sh` and `sync-drive.sh`. Wizard asks once, writes choice to `~/.devbox/sync-method`.
**Rejected:** GitHub-only (devs like it, but some buyers don't have GitHub); both-simultaneously (double complexity for no benefit).
**Why:** Joe picked "both, user decides" in the questionnaire.
**Tradeoff:** Two code paths to maintain. Acceptable because each path is a ~50-line shell script.

## D7 — npm global install for Claude Code, not a containerized install

**Pick:** `npm install -g @anthropic-ai/claude-code` in Termux.
**Rejected:** Docker/podman in Termux; nix; pkgx.
**Why:** Containers don't run natively in unrooted Termux (no user namespaces without proot-distro). npm global install is the official install path, is well-supported, and is a 30-second operation.
**Tradeoff:** Updates are `npm update -g` — the user needs to run this occasionally. `wizard.sh` writes a `devbox update` alias that does it.

## D8 — Provision script is idempotent and re-runnable

**Pick:** `provision.sh` checks "is X installed?" before installing, and `wizard.sh` checks "is X configured?" before prompting.
**Rejected:** One-shot "only runs once" scripts.
**Why:** Re-runnability lets cousin debug without reflashing, and lets the buyer recover from a botched setup without starting over.
**Tradeoff:** Slightly more code. Worth it.
