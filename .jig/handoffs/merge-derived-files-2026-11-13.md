# Handoff: merge-derived-files

Commit: d7dbbc5b6795e8fb97dbf4b87432d74d18ad7d88
Date: 2026-11-13
Spec: .jig/specs/merge-derived-files.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
- `.jig/scripts/derive.sh`, a new no-op template. `jig merge` runs `setup.sh` (moved from after the commit) and then `derive.sh` before its commit, and stages exactly what the board's new `derived_files` globs match (tracked or untracked, changed or deleted, literally via `--pathspec-from-file`), even when derive fails, so `git merge --abort` resets it. It prints `derived: <files>`. A tracked change left outside the globs is named "changed and not committed" and left out. With no `derived_files`, nothing is staged.
- A failing derive stops the merge before its commit (exit 1, with how to finish). `jig merge --number` runs setup and derive too. A job already in trunk skips derive (M4) and says derived files may be stale when `derived_files` is set. An untracked file matching `derived_files` refuses the merge before it starts. A glob matching nothing after derive is named. `jig merge` now chdirs to the repo root, so it works from a subdirectory.
- `jig update` adds `derive.sh` (a STEPS row). RULES.md (The board, Keeping merges mechanical, step 2, step 3, Commands), the template AGENTS.md, and the init, update, adopt and hubnode skills name `derive.sh` and `derived_files`. The hubnode's After a merge has removing the worktree and branch when clean, and its Never has the own-script line.
- The design changed after three non-converging review rounds: outputs are declared (`derived_files`), not inferred from disk. Approved by the owner on 2026-11-13; the spec's Design, Alternatives, Decisions and Done-when are amended.

## Done-when evidence
- `bash tests/smoke.sh merge_derived`: 25 `derive:` cases pass. They cover the fix firing (A and B, `derived: INDEX.md`, two parents, current), the clean-merge symptom (count corrected), derive exits 3 (exit 1, MERGE_HEAD, --number, then abort), the conflict path (`--number` runs setup once and writes INDEX.md; no "then run setup.sh"), the template's no-op (no `derived:` line, same files), the four redesign cases (temp file, abort, hand run, undeclared write), deletions, non-ASCII, the untracked stray, a glob matching nothing, already-in-trunk with and without `derived_files`, and a run from a subdirectory.
- Smoke: init's exact `.jig/` list names `derive.sh`, and the update loop asserts it's added from the template, executable and staged.
- `grep -n derive.sh plugin/templates/AGENTS.md plugin/skills/{update,init,adopt}/SKILL.md` hits each. hubnode SKILL.md names `derive.sh`, `git worktree remove` and `git branch -d`.
- Full `bash tests/smoke.sh` on 29141d7: rc=0, 1123 pass, 0 fail. `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: clean. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing.

## Review
Seven rounds by the hubnode's reviewer (claude-opus-5-5, effort unknown), recorded on d7dbbc5.
- Round 1: 1–8 taken (NUL paths, no derive when already in trunk, setup's writes, the spec's [assumed] tag, the derive.sh header, numbered printed first, RULES lines).
- Rounds 2 and 3: blocking findings in the inference (by name, then by stat), each fixed. Round 4's blocking finding (a failed run's temp file committed) stopped the rounds. /jig:bug found the root: outputs were inferred. The owner approved design (b), declared `derived_files`.
- Redesign review: S1 (untracked stray), S2 (stale-files line), the header line, O1 (how to drop changes), O2 (glob matching nothing) and O4 (metarepo hand merge) taken.
- Final: the subdirectory run (plus the chdir it exposed), the warning keyed on `derived_files`, the plural, the O2 test and the RULES metarepo line taken.
- Deferred to DEFERRED.md: O3 (`derived:` lists a job's own matching files), O5 (partial output staged after a failure), and a glob whose only matches are gitignored.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (The board, Keeping merges mechanical, Handoff, gate, merge steps 2–3, Commands). This repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/jig.py`: `cmd_merge` (setup and derive before the commit, the stray check, chdir), `run_derive`, `derived_files`, `setup_and_derive`, `BOARD_OPTIONAL`, and the STEPS row with `add_derive`.
- `plugin/templates/jig/RULES.md`: as in Fold-in.
- `plugin/templates/AGENTS.md`: a `derive:` line under Commands.
- `plugin/skills/{hubnode,update,init,adopt}/SKILL.md`: the derive.sh and derived_files lines, plus the hubnode's worktree and branch removal.
- `tests/smoke.sh`: the new `merge_derived` section and UNITS entry, the exact `.jig/` lists, and the update loop's derive.sh assertion.
- `.jig/specs/merge-derived-files.md` (the job's own spec), amended for design (b). `.jig/ledgers/DEFERRED.md`: three rows.

## Test by hand
In a scratch repo: set `"derived_files": ["INDEX.md"]`, have derive.sh write INDEX.md from `ls src`, open two jobs that each add a source, and `jig merge` both. Each prints `derived: INDEX.md`, and trunk's INDEX.md lists both with the tree clean.

## Left
Nothing on this spec. `marketing/FEATURES.md` has the derive.sh row in the main checkout; the hubnode updated it for `derived_files`. Spec order: `bug-merge-append-conflicts.md` still has to sync with this `cmd_merge` when it builds.
