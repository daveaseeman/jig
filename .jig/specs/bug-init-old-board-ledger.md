# Bugs from a pararepo conversion: init writes a second board, the ledger fold misreads pipes

Source: `/jig:feedback` from an ai-dev repo converted to a pararepo, Oct 30
(`jig-feedback-<repo>-2026-10-30.md`). Both reproduced on 0.3.1. Cited lines checked against
`plugin/templates/jig/jig.py` at b5ed1cf.

## Intent
`jig init` never writes a board beside an older one: in a repo on an old layout it says to run
`jig update` first. The ledger fold drops exactly the taken rows, and names a row it can't read
instead of guessing.

## 1. `init --para` (and `--meta`) on an old layout
- `[seen]` `cmd_init` writes `.jig/config.json` and `.jig/jobs.json` and installs hooks before it
  dispatches `--meta`/`--para`, checking only whether `config.json` exists. With
  `.aidev/lanes.json` present, that leaves two boards, and `jig update` then blocks: "two boards
  … can't tell which one the jobs are on".
- `[seen]` The hooks it installs run `<trunk>:.jig/jig.py`, which trunk doesn't have until the
  update lands. So the repo's old hooks are replaced by ones that do nothing.
- `[seen]` `cmd_update` already knows every old board path, in `LAYOUT`'s board row.
- `[assumed]` The same happens for a 0.2.x `jig/lanes.json`. Smoke covers it.
- Correction: `init` refuses, changing nothing, when a board exists at any old path from
  `LAYOUT`. The refusal names the order: `jig update`, commit, then `jig init --para`.
  `repos add meta|para` says the same when it sees an old board.

## 2. `split_ledger` splits on every `|`
- `[seen]` `cells = [...line.strip().strip("|").split("|")]`, then `cells[col]` with `col` from
  the header. A GFM `\|` (a literal pipe) adds a cell, so the status is read from the wrong
  column. A `|` inside backticks does the same, which also makes the row malformed GFM.
- `[seen]` In the reporting repo, three taken rows survived into `DEFERRED.md`. In a four-row
  repro on 0.3.1, a taken row with `\|` and a taken row with a pipe in backticks were both kept.
- `[seen]` M2 splits the same way but tests every cell, so an extra cell can't fool it.
- Correction:
  - One `table_cells(line)` helper splits on `|` not preceded by `\`, unescapes `\|`, and
    strips the outer pipes.
  - `split_ledger` uses it and trusts `col` only when the row has the header's cell count.
  - A row of the wrong shape is kept and named in the dry run.

## Done when
Smoke:
- [ ] With `.aidev/lanes.json` committed, `jig init --para X` exits non-zero, names
      `jig update`, and changes nothing: `git status --porcelain` empty, no `.jig/`, `.git/hooks`
      as before. The same with `jig/lanes.json`, and with `jig init --meta`.
- [ ] After `jig update --apply` and a commit, `jig init --para X` succeeds, and the next
      `jig update` says "up to date".
- [ ] `jig repos add para` beside an old board says to run `jig update`, then `jig init --para`.
- [ ] A ledger with header `| id | review | finding | rank | what happened | reason |` and four
      rows: L-1 taken; L-2 taken, with a pipe inside backticks; L-3 taken, with `\|`; L-4
      deferred. The fold drops L-1 and L-3 and keeps L-4.
- [ ] L-2 (7 cells, header 6) is kept and named in the dry run's Warnings ("row `L-2` has 7
      cells, its header 6: kept, check it"). The ledger line counts it: "N carry over, M dropped,
      K malformed kept".
- [ ] M2 uses `table_cells`, and the existing M2 cases pass.
- [ ] Smoke passes, and the validator passes.

## Out of scope
- Treating a `|` inside backticks as literal. GFM doesn't, and jig shouldn't read a file
  differently from GitHub.

## Touches
`plugin/templates/jig/jig.py` (`cmd_init`, `cmd_repos`, `split_ledger`, `meta_rules`, a new
`table_cells`), `plugin/skills/repos/SKILL.md`, `tests/smoke.sh`.

## Alternatives considered
- Have `init --para` write only `para.json`, the cache and the header when a board exists.
  Rejected: it still installs hooks pointing at a `.jig/jig.py` trunk doesn't have, and leaves
  the order implicit. `[seen]`: `cmd_init` installs hooks unconditionally.
- Have `update` merge a fresh `config.json` with the old board. Rejected: it guesses which board
  is real, the thing "two boards" exists to refuse. `[seen]`
- Drop a malformed row whose misread cell says "taken". Rejected: the misread can go either way,
  which is the bug. `[seen]`: the three rows in the report.
- Search every cell for a status word, as M2 does. Rejected for the ledger: a finding's own text
  can contain "taken" or "deferred". `[assumed]`
