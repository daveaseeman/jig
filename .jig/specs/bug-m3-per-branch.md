# Bug: M3 asks every commit for a changelog line, though the branch already has one

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)
Item 5 of the report. Checked against `plugin/templates/jig/jig.py` at d9bfedc (0.5.0).

## 1. Why
- Why was a page-only review fix refused on a branch that had its Unreleased line? M3 diffs the
  staged change against HEAD: it sees this commit alone, and this commit left CHANGELOG.md alone.
- Why per commit? `meta_rules` takes one `paths` list (`changed_paths`, against `base()` = HEAD)
  for M1–M4. M1, M2 and M4 are about each commit. M3 isn't: a pararepo reads the changelog at a
  release, and a release only ever sees whole branches, merged.
  Root: M3 judges what a branch promises against one commit's diff.

## 2. Givens
- `[seen]` Reproduced on Nov 3 in a scratch metarepo, `entry_files` with `products/**/*.md` and
  `features/**/*.md`: on a branch whose first commit added a page change and a line, a second
  commit touching two pages only is refused with the report's exact M3 message.
- `[seen]` Globs aren't the cause, they only widen it: the same branch's commit changing only
  `DECISIONS.md`, an exact entry, is refused the same way. The reporter's "with page globs" is
  the case that hit them most, not the condition.
- `[seen]` M3 passes on any change to CHANGELOG.md, not on a line added under Unreleased: a
  commit that deletes the branch's only line passes today. That's how "re-edit the line" worked
  as a workaround, and it's a hole a per-branch check closes.
- `[seen]` M3 never runs on a merge (`meta_rules` returns after M5), so a sync of trunk and the
  gate's scratch merge aren't judged by it. CHANGELOG.md is in the default `append_files`, so a
  sync resolves two branches' lines.
- `[seen]` Nothing after the commit hook re-checks M3: not `handoff`, `gate`, `merge`, nor
  `meta_problems` (release and pre-push).
- `[seen]` Prototype below, in a clone in scratch: the full smoke passes unchanged (478 PASS,
  exit 0), and the scratch cases behave as Done when lists.

## 3. One layer up
- Sibling: P2 in a pararepo asks for a BUFFER row "in the same commit", but it already has a
  branch-wide escape: a spec line (`meta: buffered <row>`). M3 has none. Not changed here.
- The reporter's proposal moves M3 to the gate, merge or handoff. Those see the branch, but late:
  the writer finds out after the review, and solo work has no gate.
- Existing pattern: git's own branch diff, against `git merge-base <trunk> HEAD`. On trunk that
  is HEAD, so trunk's behaviour is unchanged.

## 4. Correction
Keep M3 in the commit hook and judge the branch there: diff the index (or the tree, without
`--staged`) against the merge base with trunk, `--no-renames`, once. Entry files in that diff and
no CHANGELOG.md in it → refuse. One diff replaces the two M3 makes today (`paths` + `gone`):
without rename detection a rename lists both names, so a page moved out of the set still counts.
About five lines in `meta_rules`; `paths` stays as it is for M1, M2 and M4.

## 5. Spec

### Done when
Smoke, in the entry-globs metarepo fixture, on a branch:
- [ ] A page-only commit after a commit that added a page change and a CHANGELOG line passes.
      The same for a `DECISIONS.md`-only commit.
- [ ] A page-only commit on a fresh branch with no line is still refused (the existing case).
- [ ] After trunk moves (another branch with its own line merged) and the branch merges trunk
      in, a page-only commit still passes: the base moved with the sync.
- [ ] A commit that deletes the branch's only line, leaving its page changes, is refused.
- [ ] The existing M3 cases (rename and delete out of the set, staging's M3 hint) pass unchanged.
- [ ] RULES.md's M3 row says it judges the branch since it left trunk; FEATURES row "Metarepo
      gates M1–M6" says the same. Smoke passes, and the validator passes.

### Out of scope
- Checking that the change is a line added under `## Unreleased`, not just any change to the
  file.
- Re-checking M3 at the gate, merge or release for commits made with the hooks off.
- P2's same-commit rule.

### Touches
`plugin/templates/jig/jig.py` (`meta_rules`, M3 only), `plugin/templates/jig/RULES.md` (M3
row), `tests/smoke.sh` (entry-globs section), `marketing/FEATURES.md` (the M1–M6 row).

### Alternatives considered
- M3 at `jig gate` / `jig merge` / `jig handoff`, per the report. Rejected: the writer learns
  after review, solo work never gates, and it adds a second home for one rule while the commit
  hook can see the branch already. `[seen]`: merge-base diff in the prototype.
- Keep the per-commit trigger, satisfy it from the branch (entry files from this commit,
  CHANGELOG from the branch). Rejected: it still lets a commit drop the branch's only line.
  `[seen]`: prototyped both, Nov 3; only the whole-branch diff refuses that commit.
- Let `jig stage`'s hint or the skills tell writers to touch the line each commit. Rejected: the
  workaround the reporter already used, and it trains edits that mean nothing. `[seen]`: report.
- Exempt pages (globs) from M3. Rejected: exact entries hit the same refusal, and a page is cited
  like the decision log. `[seen]`: the DECISIONS.md repro; `bug-meta-entry-globs.md`.

## Decided
Owner, 2026-11-03: each recommendation below is taken. Build to it.

- None recorded in the report for this item. The report leaves the place of the check open
  ("`jig gate` or `jig merge` (or `jig handoff`)"); this spec puts it in the commit hook.
  Recommendation: the hook, as above. If the owner wants a gate-time check as well, it is the same
  diff against trunk run by `cmd_gate` on the gated commit, and adds one Done when line.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
