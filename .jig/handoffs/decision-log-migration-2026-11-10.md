# Handoff: decision-log-migration

Commit: 1331c871d33fa9b3aa0ff579c1a93da1e77ba9a8
Date: 2026-11-10
Spec: .jig/specs/decision-log.md
Review: tier 2, effort 2
Ran: fresh Opus review of d897b21 with a Maige-Eco clone trial: B1 prose outside the table deleted, B2 reserve/append_files left on old files, S1-S8 (ranges, whose, [Unreleased], reused rejected ids, branch-switchable guard, terms_changed across migration, seeded log blocking the merge, stale references) all reproduced; fixed in c2e439d, 8e894ab (status who/note any text), 1331c87 (migration commit judged migrated; metarepo migrates on a job). Hubnode trials on fresh Maige-Eco clones: 45 entries, leftover text kept, config rewritten, E-017 converts, migration commit on a job branch passes the hooks.

## Built
Chunk 2 of `.jig/specs/decision-log.md`, the migration. With chunk 1 (merged as 4e14962) it
finishes the spec.
- `jig update` lists a root `CHANGELOG.md` and the decision register under Repo files to review
  and changes neither. `--merge-log` previews the log; `--apply --merge-log`, the owner's yes,
  writes it.
- Release sections are kept and re-headed. Rows land by status and release, ranges included.
  Rejected ids are left out but stay taken. A note naming one id joins its entry. Everything else
  stays in its old file, listed "no home, move by hand".
- `entry_files`, `append_files` and a reserve counter are rewritten. Files still naming the old
  ones are listed to repoint.
- In a metarepo the merge is a job: refused on trunk, written in the job's worktree, then the
  board is rewritten on trunk after the merge.
- The log's rules judge the change that merges the old files away; until then the old rules
  hold. Numbering never reuses an id. A pin bump across the merge reports the move on one line.
- `jig init` writes no seed beside the old files. Empty logs come from `update --apply` (STAMP 10).

## Done-when evidence
- Smoke: `jig update` lists `CHANGELOG.md` and `DECISIONS.md` for merging and changes nothing
  without a yes; `--apply --merge-log` writes the merged log and removes both. Section
  `decisions` (migration cases, metarepo as a job and plain repo): PASS.
- RULES.md's Decision log covers the migration; `grep -rn CHANGELOG.md plugin` names only
  migration, pre-migration and old-tag text and code.
- Full smoke in two foreground batches covering every section: 439 + 432 PASS, 0 FAIL, exit 0.
  `claude plugin validate ./plugin`: passed. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`:
  nothing. `.jig/scripts/check.sh`: exit 0.
- The hubnode trialled 1331c87 on a fresh Maige-Eco clone: refused on main naming the job;
  applied in a job worktree; the hooks accepted the migration commit.

## Review
All findings from the review of d897b21 and the hubnode's two clone trials are fixed:
- c2e439d: B1 (prose deleted), B2 (config left on old files), S1 ranges, S2 whose and `#`
  column, S3 `[Unreleased]`, S4 reused rejected ids, S5 branch-switchable guard, S6 terms across
  the migration, S7 seeded log blocking the merge, S8 stale references, and both optionals. Also
  R6 refusing the number a merge gave against a decision counter.
- 8e894ab: a status line's who is any text, as a row's note was. Rows the old M2 refused are
  still refused.
- 1331c87: the migration commit is judged by the log's rules. In a metarepo the migration is a
  job, with the board rewritten on trunk after.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Decision log: "Before the log" and the migration; Homes; Commands), updated here, plus the update and release skills.

## Shared files changed
- `plugin/templates/jig/jig.py`: the migration block (`merged_log`, `cmd_merge_log` and helpers),
  `migrated_here` (which rules judge a change) in `meta_rules`, R6's merge-given numbers, numbering above every id,
  `terms_changed` and `entries_moved` across the migration, the update STEP and STAMP 10, init's
  seed, and survey's adoption row.
- `plugin/templates/jig/RULES.md`: Decision log migration paragraphs, Commands.
- `plugin/skills/update/SKILL.md`: the CHANGELOG/register step.
- `tests/smoke.sh`: migration cases in `decisions`, and update fixtures expecting the log and
  version 10.

## Test by hand
On a throwaway clone of a metarepo still on CHANGELOG.md: run `jig update --merge-log` on trunk
and read the preview. Then open a job, run `--apply --merge-log` in it, commit, merge, and run
`--apply --merge-log` on trunk for the board.

## Left
Nothing on this spec. Noted for the owner: RULES.md's "Writing it" rules are a draft (the
request's appendix was never reachable). In the real repo, the leftover spans the migration keeps
in `decisions/DECISIONS.md` are moved by hand.
