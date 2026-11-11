# Handoff: bug-staged-rules-update

Commit: 0e8b25d14cef523f17319b28b740dd375e5d1794
Date: 2026-11-11
Spec: .jig/specs/bug-staged-rules-update.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on 27fe612: B1 stage skill update bullet, S1 merge-commit marks (--full-history), S2 refusal route, S3 new rules files; fixed in 0e8b25d; hubnode ran smoke staging at 0e8b25d (88 PASS, 0 FAIL) including the five new cases

## Built
<!-- what this delivers, in a few lines -->
A staged root rules file (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`), update or new, resolves like the roadmap: once a trunk commit that changed the file carries its `Source: … (staged as <file>)` mark, a job's merge included (`--full-history`). Nothing is written into the file. A new one is written as the body only. The refusal names the commit route. A page under `docs/` still needs the mark in the page. RULES.md § Staging and the stage skill say so. `/jig:init` counts AGENTS.md's 40 lines as rule lines, as survey does.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- [x] AGENTS.md update resolves from a marked trunk commit with no mark in the file: `bash tests/smoke.sh` → PASS "staging: once a trunk commit that changed AGENTS.md carries the mark, it resolves with no mark in the file" (and "a mark only on the merge of a job that changed AGENTS.md resolves it")
- [x] With no such commit it is refused, naming the commit route: PASS "staging: an update to AGENTS.md with no marked trunk commit is refused, naming the commit route" (checks the message has "in the commit message, never in the file" and no "keeping")
- [x] A docs/ page still needs the mark in the page: PASS "staging: an update to a doc waits until the page carries the source" / "the session's name alone isn't provenance" / "once it does, the update resolves"
- [x] RULES.md § Staging states it; `plugin/skills/init/SKILL.md` says "under 40 rule lines (blank lines, headings and table rows don't count), as `jig survey` counts them"
- [x] `bash tests/smoke.sh` at 0e8b25d: exit 0, 987 PASS, 0 FAIL. `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: exit 0. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: no output (exit 1)

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode review of 27fe612 (tier 2, effort 2):
- B1 (blocking) stage skill's update bullet told a session to put the mark in the file: fixed in 0e8b25d, with a rules-file exception like the roadmap bullet.
- S1 a mark on a `--no-ff` merge commit was missed by history simplification: fixed in 0e8b25d with `--full-history` (checked in a scratch repo; `-m` not needed); smoke case added.
- S2 the refusal said "edit on main", which M4 refuses in a metarepo: fixed in 0e8b25d; it names trunk or a job merged to trunk.
- S3 `change: new` wrote the mark into a rules file: fixed in 0e8b25d; body only, resolves from the commit adding it; smoke for GEMINI.md new.
- O4 a marked commit not touching AGENTS.md: taken, smoke case added.
- init wording omits survey's `<!--`/`-->` skip: left, "as `jig survey` counts them" covers it.
- O1 a feature-request update naming AGENTS.md: deferred, row in `.jig/ledgers/DEFERRED.md`.
- O2/O3 an older same-mark commit, or a reverted one, still passes: deferred, row in `.jig/ledgers/DEFERRED.md` (the roadmap shares both).

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (§ Staging) and `plugin/skills/stage/SKILL.md`, both updated here.

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: `cmd_staging`, one rules-file block before the update/new split; the update branch is otherwise unchanged (staging-batches also edits `cmd_staging`).
- `plugin/templates/jig/RULES.md`: § Staging, one sentence after the roadmap's.
- `plugin/skills/stage/SKILL.md`: the spec/doc update bullet (B1).
- `tests/smoke.sh`: five cases in `sec_staging`, after the docs update case.
- `.jig/ledgers/DEFERRED.md`: two rows appended.

## Test by hand
<!-- what a person should click or watch -->
In a throwaway repo, stage a `kind: doc`, `change: update`, `destination: AGENTS.md` file and run `jig staging resolve <file>`: it refuses, naming the commit route. Edit AGENTS.md, commit with the file's `Source:` line in the message, and resolve again: it succeeds and AGENTS.md has no Source line.

## Left
<!-- what remains on this job -->
Nothing on this job.
