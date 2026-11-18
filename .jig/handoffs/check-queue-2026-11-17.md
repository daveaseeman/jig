# Handoff: check-queue

Commit: 0408bfb9da7d5bb318393485a9c50190fd81e848
Date: 2026-11-17
Spec: .jig/specs/check-queue.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
- `jig queue -- <command…>`: runs a test or check holding one of the machine's slots (fcntl locks in `.git/jig/queue/`, shared by every worktree, freed when a run dies), waits with "waiting for a slot: N running, M waiting" when none is free, and returns the command's exit code (128+N on a signal). `jig queue` lists the slots, holders, waiters and any complete check. `queue.width` / `queue.slots` / `queue.max_load` set it.
- `jig queue --full`: also takes the single full lock, so two complete checks never overlap. With `queue.overflow` set and every slot held or a complete check running, it exits 3 and prints the GitHub Actions route (push `jig-check/<sha>`, `gh run list` / `gh run watch`, `jig checked --ci`, delete the branch). A wait for load alone just waits.
- `jig checked --ci <url>`: reads the run with `gh run view` and records it, with the URL as a sixth field, only for origin's repo, the `jig check` workflow or a `jig-check/*` branch, HEAD, completed, success. It refuses a missing `gh` or a run it can't read. `checked_records` reads 5- and 6-field lines, and `jig status` shows the URL.
- The commit hook validates `queue` (`queue_problems`): the overflow key needs the owner's words as its reason and nothing wider. Every other fixed rule is still refused.
- `plugin/templates/github/jig-check.yml` (generic) and this repo's `.github/workflows/jig-check.yml` (adds the `claude` CLI install).
- RULES.md (The queue, the CI record, the fixed-rule exception, the hubnode's steps, Commands), the work/review/check/hubnode/release skills, gate's and release's printed commands, and AGENTS.md all run tests and checks through `jig queue`.

## Done-when evidence
- Smoke `queue` (one slot: holder/waiter, kill frees it, listing, exit code): `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh queue check_levels release` → rc=0, 95 PASS, 0 FAIL, incl. "PASS  queue: with one slot, a second run waits…", "…killing the holder lets the waiter run, and leaves no waiting file behind", "…with no command it lists the slots, the holder and the waiter", "…the command's exit code passes through".
- Smoke `queue` width: "PASS  queue: width all and no slots gives one slot", "PASS  queue: width 2 gives the core count divided by 2".
- Smoke `queue` --full: "two complete checks never overlap, even with free slots: the second waits", "with the overflow key and a complete check running, it exits 3 and prints the CI route for jig-check/<sha>", "with the overflow key and every slot held by ordinary runs, it exits 3 too", "with the overflow key, free slots and only the load over, it waits and never exits 3" — all PASS.
- Smoke `queue` max_load: "with max_load 0, a run waits even with every slot free", "with no max_load, the machine's load is never read" — PASS.
- Smoke `queue` config: "an overflow key with no reason is refused by the commit hook", "a config that weakens another fixed rule is still refused" — PASS.
- Smoke `check_levels` `--ci` with a stub gh: headSha not HEAD, in progress, failed, unreadable, no gh, no origin, another repo, another workflow on another branch: each refused. "a passing run on HEAD is recorded with its URL as a sixth field", "jig status shows the CI record", "an old five-field line after it is still read" — all PASS.
- Skills and RULES.md name `jig queue`: see 415fa94 and 2b25166 (work, review, check, hubnode, release skills; RULES.md The queue, the Fixed sentence, the hubnode's own steps).
- `.jig/config.json` `queue.width: "all"`: the hubnode's commit, after the release and `/jig:update` (Left). AGENTS.md's Commands run through `python3 .jig/jig.py queue --`.
- `jig-check.yml` is valid YAML: `ruby -ryaml` loaded both files. `grep -ci claude plugin/templates/github/jig-check.yml` → 0.
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → rc=0; `claude plugin validate ./plugin` → "✔ Validation passed". The full suite is the check step's.
- By-hand overflow: not run. It's the hubnode's step, after the config commit (Left).

## Review
- review-work of 9c86d40: 2 blocking (strike 1).
  - B1 (config done-when unmet on the branch): spec amended. The queue keys land in the hubnode's commit (2b25166).
  - B2 (overflow on load alone): fixed, with a smoke case.
  - S1 and S2 fixed. O1, O2, O3 and O8 taken. O4–O7, S3 and S4 deferred (DEFERRED.md).
- review-change of 9c86d40..2b25166: clean, blocking 0, recorded at 2b25166. Its S-a, S-b, S-c, S-d and O-a–O-e are deferred in DEFERRED.md (0408bfb), because the fix round was used. S-c (`--ci` accepts a non-check workflow on a `jig-check/*` branch) and S-d (grandchildren inherit the lock fds) are the ones worth a follow-up.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Workflow: The queue, Two levels of check, the Fixed sentence and the hubnode's steps; Commands), updated here, plus the check, work, review, hubnode and release skills.

## Shared files changed
- `plugin/templates/jig/jig.py`: `cmd_queue`, `queue_problems`, `ci_run_passed`, `checked_records`' sixth field, the status line, and the gate's and release's printed commands.
- `plugin/templates/jig/RULES.md`: The queue, the CI record, the fixed-rule exception, the hubnode's steps, the gate command, Commands.
- `tests/smoke.sh`: the new `queue` section (in UNITS), `--ci` cases in `check_levels`, and the gate expectation.
- `AGENTS.md`: Commands and Workflow run through `jig queue`.
- `plugin/skills/work`, `review`, `hubnode`, `release` SKILL.md: name `jig queue` (and the overflow exception, in hubnode's).
- `.github/workflows/jig-check.yml`: this repo's copy of the template, plus the `claude` CLI install.
- `.jig/decisions.md` (common): Unreleased Added lines. `.jig/ledgers/DEFERRED.md` (common): the deferred rows.

## Test by hand
- In any worktree: `python3 .jig/jig.py queue -- sleep 20` in one shell, `python3 .jig/jig.py queue` in another. It shows the holder.
- The overflow run (the hubnode's step, after the config commit): with a complete check running (`jig queue --full -- sleep 600`), run `jig queue --full -- ./.jig/scripts/check.sh --full` in a detached worktree of main. It exits 3. Take the printed route, and check that `jig checked --ci` records the run and the branch is deleted.

## Left
The hubnode's steps:
- Merge check-queue last before the release. Then `/jig:update` right after, since AGENTS.md's `python3 .jig/jig.py queue` commands fail until the installed jig.py has `queue`.
- After the release and `/jig:update`, not right after the merge (main's hook runs the installed jig.py, which only then knows `queue_problems`), commit on main in `.jig/config.json`:
  `"queue": {"width": "all", "overflow": {"to": "github", "reason": "The owner, 2026-11-17: \"Keep the standing yes\" (standing yes for jig-check/* pushes)"}}`
- Then the by-hand overflow run: done-when's last item, "after merge, hubnode". It settles the `claude plugin validate`-without-login risk in the spec.
