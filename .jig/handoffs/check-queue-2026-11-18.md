# Handoff: check-queue

Commit: 0530238d4ff7f26667e32713cabfe67da66dada6
Date: 2026-11-18
Spec: .jig/specs/check-queue.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
Part 2, on the owner's 2026-11-18 ruling on S-c and S-d ("Fix before release"). Part 1 is in check-queue-2026-11-17.md.
- `jig checked --ci` now refuses unless the run is the `jig check` workflow AND on `jig-check/<HEAD short sha>`, the same `--short=12` name the overflow route pushes (S-c).
- `jig queue` no longer passes its locks to the command (it reverts `pass_fds`). A process the command leaves behind never holds a slot or the full lock. The trade: a jig killed outright frees its slot early (S-d).
- Spec item 11 and its Done-when, the owner's ruling and the S-d Interpreted line; RULES.md's `--ci` sentence and queue paragraph.

## Done-when evidence
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → check rc=0.
- `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh queue check_levels` → smoke rc=0, 76 PASS, 0 FAIL, including:
  - "PASS  checked --ci: a green run of another workflow on jig-check/<HEAD's sha> is refused"
  - "PASS  checked --ci: a green jig check run on another branch is refused, naming jig-check/<HEAD's sha>"
  - "PASS  queue: a process the command leaves behind holds no slot and no full lock once the command returns"
  - "PASS  queue: jig killed outright (SIGKILL) frees its slot, the trade for never handing the lock to the command"
- Part 1's done-when evidence is in check-queue-2026-11-17.md. The by-hand overflow run is still the hubnode's (Left).

## Review
- Part 1: review-work of 9c86d40 (2 blocking), then a clean review-change at 2b25166. See check-queue-2026-11-17.md.
- Part 2: review-change of 9fd884d..46b3439, clean, blocking 0 and no should-fix, recorded at 46b3439. The reviewer confirmed that the route and `--ci` build the same `jig-check/<--short=12>` name, and that no lock fd reaches the command (lsof: jig holds 2, the command 0).
- Its optional O1–O3 (the SIGKILL case's race on `child.pid`, check/SKILL.md step 3 not naming the branch, `pass_fds` missing from Alternatives considered) are deferred in one DEFERRED.md row (0530238).
- The S-c and S-d rows from part 1 are marked taken.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Workflow: The queue, Two levels of check), updated here for the `--ci` rule and who holds the lock, plus the check skill.

## Shared files changed
- `plugin/templates/jig/jig.py`: `ci_run_passed` (workflow AND branch); `cmd_queue`'s Popen (no `pass_fds`).
- `plugin/templates/jig/RULES.md`: the `--ci` sentence, and the queue paragraph on who holds the lock.
- `tests/smoke.sh`: two `--ci` refusals in `check_levels`; the leftover-process case and the SIGKILL trade in `queue`.
- `.jig/ledgers/DEFERRED.md` (common): S-c and S-d marked taken, plus the part 2 optional row.

## Test by hand
- `python3 .jig/jig.py queue --full -- sh -c 'sleep 30 >/dev/null 2>&1 & echo bg'`, then `python3 .jig/jig.py queue`: it shows `running: 0` and `complete check: none` while the sleep runs.
- The overflow run, as part 1's note says: `jig checked --ci` takes only the `jig check` run on the `jig-check/<sha>` the route printed.

## Left
The hubnode's steps, as before:
- Merge check-queue last before the release. Then `/jig:update` right after, since AGENTS.md's `python3 .jig/jig.py queue` commands fail until the installed jig.py has `queue`.
- After the release and `/jig:update` (main's hook runs the installed jig.py, which only then knows `queue_problems`), commit on main in `.jig/config.json`:
  `"queue": {"width": "all", "overflow": {"to": "github", "reason": "The owner, 2026-11-17: \"Keep the standing yes\" (standing yes for jig-check/* pushes)"}}`
- Then the by-hand overflow run: done-when's last item, "after merge, hubnode".
