# HANDOFF — Session-to-session pickup

**Last updated:** 2026-04-16, initial build session (Joe asleep)

**Current status:** Docs foundation written and about to commit. Scripts not yet started.

**Next action:** Write `provision.sh` (Termux-side installer for Node, Claude Code CLI, and MCP server packages). See work sequence in `SCOPE.md`.

**Blockers:** None.

**Files committed this session:** none yet — about to commit docs.

---

## Protocol for continuation sessions

1. **Read `SCOPE.md`** — the locked v0 scope.
2. **Read `DECISIONS.md`** — non-obvious choices made in prior sessions.
3. **Check `git log --oneline -20`** — see what's been committed.
4. **Do the next item in the work sequence** (see SCOPE.md).
5. **Before ending the session, update this file with:**
   - Timestamp of last update
   - What was completed this session
   - Next specific action (not vague)
   - Any blockers
6. **Commit atomically** using conventional commits (`feat:`, `chore:`, `docs:`, `fix:`).

## Rules

- Joe is asleep. Do not wait for answers. Make the call.
- On 50/50 decisions: pick the simpler path, ship it, record in `DECISIONS.md`.
- Do not leave questions for Joe in this file — decisions go in `DECISIONS.md` as records.
- Do not break working code. Run `bash -n` on shell scripts before committing.
- After core is implemented, run the `codex:rescue` skill for an adversarial review pass, apply findings, and commit.
