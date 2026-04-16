# HANDOFF — Session-to-session pickup

**Last updated:** 2026-04-16 — first build session, Codex rounds 1 + 2 applied

**Current status:** **v0 SHIPPABLE** — all planned artifacts written, TWO Codex adversarial review passes complete (17 findings total, all applied and committed). Joe can hand this repo to his cousin in the morning and flash a test device.

**Next action:** One of the following, in priority order:
1. **Joe:** read the repo, flash a single test device end-to-end, report back what breaks in the real world. `FLASH.md` is the cousin's script; `flash-device.sh` is the PC-side orchestrator.
2. **Optional Codex round 2:** invoke the `codex:rescue` skill again to review the fixes themselves (quick sanity pass on the patches applied in commit `72c74b8`).
3. **Nice-to-haves for v0.1:** populate SHA256 hashes in `flash-device.sh` (currently empty slots, falls back to pinned URL verification only); bundle the three Termux APKs in-repo so fully-offline flashing is possible; add a branded boot splash.

**Blockers:** None for shipping a test flash. For a 20-unit production run, the open items are:
- SHA256 pinning (nice-to-have, not a blocker — URLs are already pinned)
- Real-world smoke test on one device (the only thing this repo hasn't been subjected to)
- BRAND-RISK.md trademark question (Joe decides if he wants to rename before listing)

**Files committed this session:**

```
8cc0c7d  Initial project brief for AI phone agent idea        (pre-existing)
b0930bc  docs: scaffold DevBox v0 repo                         (doc foundation)
0806346  feat: provision + wizard + sync scripts + MCP config  (device software)
b86079b  feat: flash orchestrator + kiosk/reflash docs         (cousin's tooling)
72c74b8  fix: apply Codex adversarial review findings           (round 1: 13 findings)
cbe7346  docs: update HANDOFF + DECISIONS after Codex review    (decision records)
e4da129  fix: Codex round 2 — APK resolution + creds + magic    (round 2: 4 findings)
```

---

## What's in the repo

| File | Purpose |
| --- | --- |
| `README.md` | Public-facing repo description |
| `BRIEF.md` | Original concept pitch, preserved |
| `SCOPE.md` | Locked v0 scope, updated for honest sync copy |
| `DECISIONS.md` | 14 build-time decisions with tradeoffs |
| `BRAND-RISK.md` | MS Azure Dev Box TM concern + 5 alternate names |
| `FLASH.md` | Cousin's step-by-step (quick + detailed) |
| `flash-device.sh` | PC-side orchestrator: ADB, pinned APKs, push, launch |
| `provision.sh` | Termux installer (idempotent, mandatory MCPs fail-fast) |
| `wizard.sh` | 6-step first-boot (auth → keyboard → sync → MCP → kiosk) |
| `sync-github.sh` | Bidirectional GitHub sync, credential-helper auth, private-repo enforced |
| `sync-drive.sh` | Drive backup, drive.file scope (not full access) |
| `mcp-config.json` | Reference config (wizard registers via `claude mcp add`) |
| `kiosk-setup.md` | Screen Pinning path A + rooted path B |
| `reflash-to-stock.md` | Three recovery paths |
| `.gitignore`, `.gitattributes` | Force LF line endings for Termux compatibility |

## Codex review outcomes (13 findings, all addressed)

See `git show 72c74b8` for the full diff. BLOCKERS that were fixed:
1. PAT no longer embedded in `.git/config` — now uses chmod-600 credential helper
2. Git push/pull errors no longer swallowed; repo creation API checked
3. APK URLs pinned with SHA256 slot; fallback to GitHub API

HIGHs fixed: claude mcp flag order; `--scope user`; private-repo enforcement; honest sync copy; drive.file scope; auth copy mentions Pro/API billing; replaced `claude auth status` with credential-file check.

MEDIUMs fixed: removed dead mcp-config.json copy; reboot via adb/power button not Termux; fatal on missing filesystem/git MCP; Termux:Boot one-time-launch documented.

---

## Protocol for any continuation sessions

1. **Read `SCOPE.md`** — the locked v0 scope.
2. **Read `DECISIONS.md`** — build-time choices and their reasons.
3. **Check `git log --oneline -20`** — see what's been committed.
4. **Do the next item** — see the numbered Next action list above.
5. **Before ending the session, update this file.**
6. **Commit atomically** using conventional commits.

## Rules that still apply

- Joe is asleep (or stepping away). Do not block on questions.
- On 50/50 decisions: pick the simpler path, ship it, record in `DECISIONS.md`.
- Do not break working code. `bash -n <script>` before committing.
- If you invoke `codex:rescue` for round 2, feed it the diff since commit `72c74b8`, not the whole repo — round 1 already covered the whole surface.
