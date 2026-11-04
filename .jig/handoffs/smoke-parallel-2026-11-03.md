# Handoff: smoke-parallel

Commit: 727b4d0e35bafb4432a1118fa3a1e560ce52c86b
Date: 2026-11-03
Spec: .jig/specs/smoke-parallel.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to xhigh, not readable by the subagent)

## Built
`tests/smoke.sh` runs each section in its own process and temp folder (own `JIG_CONFIG` and
`XDG_CONFIG_HOME`), in parallel through `xargs -P` (default the core count, `JIG_SMOKE_JOBS`
overrides). Output prints unit by unit in file order once all finish; the isolation case runs
last in the parent. `bash tests/smoke.sh <section>...` reruns a few, `--list` names them. Every
helper and shared constant (`R`, `JR`, `UP`, `FX`) is defined once at the top; the duplicate
`stage`/`foldin` are one each. No assertion changed.

Shared state, so two pairs run as one unit (comma-joined in `UNITS`):
- metarepo,staging: staging releases and resolves into metarepo's `$M` repo.
- r6_takes,r6_ints: R6 as ints works in R6 takes' `$R` (`$T/r6`) repo.

Behaviour that moved:
- The staging block now prints right after metarepo, before pararepo (it was after it).
- "repos: works outside any git repo" now really runs outside a repo: its `cd "$T"` is the
  section's own folder, where before `$T` was the rules section's repo.
- init beside an old board borrowed pararepo's `repos.json` for metarepo `docs`; it now builds
  and registers its own (the one case that failed only in parallel).

## Done-when evidence
- Parallel, file order: `bash tests/smoke.sh` → rc=0, 515 PASS, 0 FAIL; PASS/FAIL lines diffed
  against a serial run of the old file: identical except the staging block's position.
- Same verdict: 515 PASS (old: 515), every case runs; a run with the one parallel-only FAIL
  exited rc=1; a unit that dies prints `FAIL section X did not finish`.
- Wall time: 108 s parallel (727b4d0; 135 s at 4187299) vs 496 s serial (old file, same
  machine, run alone). Reviewer measured 123 s vs 641 s.
- Isolation case: in the parent after every unit, comparison code unchanged; passes each run.
  Not exercised against a real change (that would write to ~/.config/jig).
- `bash tests/smoke.sh init_old_board` → 15 PASS + isolation, rc 0; `staging r6_ints` → 74
  PASS (their whole units); `--list` prints 22 names; `nosuch` → "no section nosuch", rc 2.
- Helpers once at the top; `stage` and `foldin` defined once.
- Two full runs at once: A rc=0 515 PASS, B rc=0 515 PASS, 210 s together.
- Guards by hand (throwaway copies): UNITS name misspelt (`ledger_rowz`) → `FAIL no section
  ledger_rowz`, rc 1; `ledger_rows` dropped from UNITS → `FAIL section ledger_rows is not in
  UNITS`, rc 1.
- Kill by hand: SIGTERM to the parent 10 s in → parent rc 130, `$RUN` removed, 0 processes
  left naming `$RUN`.
- FEATURES.md row: edited by the hubnode, not touched here. `claude plugin validate ./plugin`
  → ✔ Validation passed; `jig check` ok; `check.sh` rc 0.

## Review
Round 1: fresh claude-opus-5-5 subagent, effort set to xhigh (recorded as unknown). Nothing
blocking; one should-fix, five optional.
- Should-fix 1 (a section could be skipped with exit 0): taken, 727b4d0 — `--unit` fails on a
  name with no `sec_` function; the parent fails on a `sec_` function not in `UNITS`.
- Optional 2 (staging prints before pararepo): noted, not changed; stated in Built.
- Optional 3 ("repos: works outside any git repo" now runs outside a repo): noted, not
  changed; stated in Built.
- Optional 4 (a killed parent left units and `$RUN`): taken, 727b4d0 — units run in their own
  process group, INT/TERM kills it and removes `$RUN`; `$RUN` printed at start.
- Optional 5 (`__pycache__` races with `cp -r`): taken, 727b4d0 — `PYTHONDONTWRITEBYTECODE=1`
  in each unit.
- Optional 6 (longest first): taken, 727b4d0 — a `SLOW` list dispatched first; `UNITS` stays
  in file order because the print loop walks it.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] no code changed — nothing to fold in (only tests/smoke.sh and AGENTS.md's smoke line)

## Shared files changed
- AGENTS.md: the smoke command line now says sections run in parallel (~2 min) and gives the
  `<section>...` / `--list` usage.

## Test by hand
Run `bash tests/smoke.sh` in the foreground: about 2 minutes, `smoke: sections run in <dir>`
first, then every section's lines in file order, ending with the isolation PASS. Press Ctrl-C
partway: it stops, and `<dir>` is gone.

## Left
Nothing on this job. Out of scope, per the spec: bytecode caching in the hooks.
