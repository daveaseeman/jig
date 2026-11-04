# Smoke runs its sections in parallel

Source: owner, 2026-11-03 ("add faster smoke too"), from `bug-wait-loop.md`'s Out of scope.

## Intent
Smoke takes 9–11 minutes, at an agent's 10-minute foreground limit, so every subnode, gate and
release backgrounds it and has to wait. Make one run finish in a few minutes, with the same cases
and the same verdict, so it can run in the foreground.

## Givens
- `[seen]` Profiled 2026-11-03, one run, 515 PASS, 646 s. Per section (s): rules 45, update 52,
  board split 26, worktree setup 17, metarepo 24, pararepo 34, staging 10, release 20, R6 takes
  10, R6 ints/M5 33, merge after sync 28, repos 2, workflow 20, init beside old board 6, ledger
  rows 2, hardware 9, update per file 15, pararepo commands 79, entry globs 77, report-fixes
  follow-up 77, sync buffer 60. No section dominates: the time is spread, so parallel sections
  are the lever.
- `[seen]` The machine has 10 cores. The longest section is 79 s.
- `[seen]` Per call: `python3 jig.py --help` 84 ms, of which compiling the 204 KB script is
  ~29 ms; `git rev-parse` 12 ms. Smoke has ~560 jig or commit lines, each commit running hooks.
- `[seen]` Helpers are defined inside sections and some may be used later (`fixture`, `board`,
  `stage`, `foldin`, …); two sections define `stage` and `foldin` twice.
- `[assumed]` Sections are otherwise independent: each builds its own repos under `$T`. The
  build must check it; sections that share state run as one unit.

## Done when
- [ ] `bash tests/smoke.sh` runs its sections in parallel (default: the core count) and prints
      each section's lines together, in file order, so the output reads as today.
- [ ] Same verdict: the PASS count is at least today's 515 and every case still runs; any FAIL
      makes the run exit non-zero, as today. A case that fails only in parallel is a bug to fix,
      not a reason to serialize it, unless the spec's handoff names the shared state.
- [ ] Wall time on this machine is under 3 minutes, measured and shown in the handoff with the
      serial time beside it.
- [ ] The isolation case still runs last, after every section, and still fails on any change to
      the real `~/.config/jig`.
- [ ] `bash tests/smoke.sh <section>…` runs only those sections (names as `--list` prints them),
      for a quick rerun.
- [ ] Shared helpers live once, at the top (or a sourced file under `tests/`), not inside a
      section; the duplicate `stage`/`foldin` are resolved.
- [ ] Two full runs at once still both pass (runs stay independent).
- [ ] `marketing/FEATURES.md` row for smoke says so, edited first. The validator passes.

## Out of scope
- Caching jig.py's compiled bytecode in the hooks (~29 ms of every call, every repo). Real, but a
  change to every repo's hooks; a separate spec if wanted.
- Dropping or merging cases to save time.
- Smoke in `check.sh`: still the gate's job, though it now fits in the foreground.

## Touches
`tests/smoke.sh`, new files under `tests/` if the split needs them, `AGENTS.md` (the smoke
command line, if its usage changes), `marketing/FEATURES.md`.

## Alternatives considered
- Speed up the slow calls (bytecode cache, fewer git spawns). Rejected as the fix: no single
  cost dominates, and the profile caps it well short of a few minutes. `[seen]`: 84 ms per jig
  call vs 646 s total.
- Split smoke into a fast subset for check.sh and the full run for the gate. Rejected: two
  suites drift, and the gate's wait stays. `[assumed]`: not tried.
- Cut cases. Rejected: every case is a rule's evidence. `[seen]`: AGENTS.md "That is the evidence".

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
