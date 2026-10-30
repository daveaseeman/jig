# Handoff: init-ledger

Commit: 249867f775d15613ab1d499e768b4f8f87ade8ff
Date: 2026-10-30
Spec: .jig/specs/bug-init-old-board-ledger.md

## Built
- `jig init` (plain, `--meta`, `--para`) refuses when a board sits at any old `LAYOUT` path, and
  writes nothing: no `.jig/`, no hooks. It says: `jig update` (then --apply), commit, then run
  this same `jig init` again. `install-hooks` refuses the same way. `Board.load` and survey
  send an old-board repo to /jig:update instead of init or adopt. `repos add meta|para` beside
  an old board says update, commit, init; the repos and init skills say the same.
- `table_cells(line)` splits a GFM row on `|` not written `\|`, unescapes `\|`, strips the outer
  pipes. `split_ledger` and M2 use it. A ledger row whose cell count isn't its header's is kept,
  named in update's dry-run Warnings, and counted on the ledger step line ("K malformed kept").

## Done-when evidence
- `bash tests/smoke.sh`: exit 0, 283 PASS, 0 FAIL. The section "init beside an old board" covers:
  - `init --para docs`, `--meta` and plain, beside `.aidev/lanes.json` (ai-dev) and
    `jig/lanes.json` (jig-0.2): non-zero, names `jig update`, `git status --porcelain`
    empty, no `.jig/`, `.git/hooks` unchanged.
  - The refusal gives the order: update, commit, then this same init again.
  - `repos add para` beside each old board says to run `jig update` there, then `jig init --para`.
  - After `update --apply` and a commit, `init --para docs` succeeds, and the next update
    prints "up to date".
  - install-hooks refuses and leaves `.git/hooks` and `.git/jig/` byte-identical. Survey and
    `status` say to run /jig:update first.
- The section "ledger rows of the wrong shape": the four-row ledger (L-1 taken; L-2 taken, with
  a pipe in backticks; L-3 taken, with `\|`; L-4 deferred).
  - The dry-run Warnings include "row `L-2` has 7 cells, its header 6: kept, check it".
  - The step line reads "its 1 untaken row … carry over, its 2 taken rows are dropped,
    1 malformed kept".
  - After --apply, DEFERRED.md has L-2 and L-4, and not L-1 or L-3.
- M2 uses `table_cells`, and the existing M2 cases pass. So does the ai-dev REVIEW_LEDGER case
  (L-001/3/5 kept, L-002/4 dropped).
- `claude plugin validate ./plugin`: ✔ Validation passed.

## Review
A fresh-context review (Opus, xhigh) of 8e9f47e found nothing blocking. Round 1 (249867f):
- should-fix, taken: the refusal's advice led into a crash. Survey and `Board.load` said init or
  adopt, `/jig:init` copied `.jig/` first, and `update --apply` then died on `git mv`.
  - Taken: `Board.load` and survey now say "an older jig's board is at <path>: run
    /jig:update first", and the init skill checks for an old board before copying anything.
  - Not here: the adopt skill (hardware-ref owns it), and plan_moves' crash on an untracked
    destination, which belongs to update-root-specs.
- should-fix, taken: `install-hooks` beside an old board replaced its working hooks with ones
  that exit 0. It now refuses, and has a smoke case. Update installs hooks only after the
  board has moved, so update is unaffected.
- optional, taken: the refusal rebuilt the next command and dropped `--contract`, `--pin`,
  `--location` and the rest. It now says "run this same `jig init` again".
- not taken: a taken row missing its trailing empty cell is now kept and warned, not dropped.
  The hubnode deferred it in DEFERRED.md.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty and has no docs/ tree; the repos and init skills (updated) are what describe init's and repos' behaviour, and RULES.md names neither the refusal nor the ledger fold's cell split

## Shared files changed
- `plugin/templates/jig/jig.py`: the fix itself. Edits are in `cmd_init`, `cmd_install_hooks`,
  `cmd_repos`, `Board.load`'s no-board message, survey's last line, M2's split, `split_ledger`,
  `ledger_step` and `fold_ledger`. Plus three new helpers (`old_board`, `table_cells`,
  `ledger_warnings`) and one line in `cmd_update` that adds the malformed-row warnings. Other
  jobs edit `cmd_update` too, so that line may need a hand merge.
- `tests/smoke.sh`: two new sections at the end, before the cleanup; no existing case changed.
- `plugin/skills/init/SKILL.md`: added to shares in review round 1; a new first paragraph under
  "Before copying anything".
- `RULES.md`, `README.md`: not touched.

## Test by hand
- In a scratch copy of an ai-dev or 0.2.x repo, run
  `python3 <plugin>/templates/jig/jig.py init --para X`: it refuses, and `git status` is clean.
- Run `/jig:update`, commit, then run that same init again: it succeeds.
- Run `/jig:init` in that old repo: it should stop before copying and recommend /jig:update.

## Left
Nothing on this job. Elsewhere: plan_moves' untracked-destination crash (update-root-specs), and
the short-row warning (deferred in DEFERRED.md).
