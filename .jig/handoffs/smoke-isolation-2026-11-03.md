# Handoff: smoke-isolation

Commit: 5d2552b01f0caa5fc0d8301eb272a12322ee0376
Date: 2026-11-03
Spec: .jig/specs/bug-smoke-isolation.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
- `tests/smoke.sh` exports `JIG_CONFIG="$T/repos.json"` and `XDG_CONFIG_HOME="$T/config"` right after `T=`, before any jig command. The per-section exports stay.
- Before that export, smoke records the listing and hashes of the real `$HOME/.config/jig`. A final case fails the run if they changed, and prints both listings so the cause shows.
- The header says runs are independent and safe to run at the same time.
- Skills `bug`, `review`, `verify` and `hubnode`: in a throwaway repo, set both variables on every jig command (agent shells don't keep an `export`), pointed at a folder beside the repo.
- `hubnode`'s gate check: the run's output always goes to `$(git rev-parse --git-common-dir)/jig/gate-<name>.out`, outside `worktrees/`, and an unreproducible failure is reported with that path.

## Done-when evidence
- Export after `T=`: `tests/smoke.sh:20`. Nothing above it runs jig (reviewer checked lines 1–19).
- Real config unchanged: the final smoke case PASSes. The reviewer's scratch copy fails (exit 1) when the folder is created, or when a file in it is changed or added.
- Header comment: `tests/smoke.sh:4-5`.
- Skills: review, bug, verify and hubnode each carry the line.
- Gate output kept: `plugin/skills/hubnode/SKILL.md` gate check.
- `bash tests/smoke.sh` at 5d2552b: PASS 478, FAIL 0, exit 0. `claude plugin validate ./plugin`: ✔ Validation passed. The reviewer's own run at 0ff639c: 478/478.
- Two runs at once in two worktrees, at 0ff639c: 478/478 each (the builder, by hand).

## Review
Round 1 (fresh context, Opus xhigh): nothing blocking, 2 should-fix, 2 optional. All four taken in 5d2552b.
- SF1: the skills said to export once, but agent shells don't keep exports. They now say to set both variables on every jig command.
- SF2: "under `.git/jig/`" pointed into the gate checkout, which is removed before the next gate. Output now goes to `<git-common-dir>/jig/gate-<name>.out`.
- O1: on a mismatch, the final case prints both listings.
- O2: the config folder goes beside the throwaway repo, not inside it.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] no code changed — nothing to fold in: only `tests/smoke.sh` and skill prose; `jig.py` and RULES.md are untouched

## Shared files changed
- `tests/smoke.sh`: the isolation at the top and the final case. That's the fix itself.
- `plugin/skills/{bug,review,verify,hubnode}/SKILL.md`: one instruction each, as the spec names.

## Test by hand
- Run `ls -la ~/.config/jig; shasum ~/.config/jig/*`, then `bash tests/smoke.sh`, then the same `ls` and `shasum` again. They should match, and the last smoke line should be the real-config PASS.

## Left
- Nothing. The leaked `plp`, `pm` and `tp` entries in the real `repos.json` are the owner\'s, and out of scope.
