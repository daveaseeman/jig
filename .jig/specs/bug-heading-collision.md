# Bug: under named headings, two parallel jobs can merge one page into two sections of the same name, and nothing notices

Source: Maige-Lite hubnode session / 2026-11-13 / Dave with Claude (staged as feedback-Maige-Lite-2026-11-13-section-counter-after-redocument.md): "what stops two parallel jobs from (a) adding the same heading to one page"

The report's `jig_version` (a8a32d1dbb7e) is v0.12.1's `plugin/templates/jig/jig.py`. The code
read here is main at de3cc14, which has the same reserve, R6 and pointer code.

## Decision
The redocument was right to drop the `reserve.section` counter. Nothing is numbered any more, so
there's nothing to reserve. Names aren't scarce: a job doesn't need a number from the board to
pick `## Cache`. But the counter carried a promise nobody wrote down: a page's citation key
names one place. Numbers kept that promise by reservation. Named headings keep it by nothing.
So the redocument doesn't break job management (open, owns/shares, gate, merge all still
work), but it leaves a hole where the counter used to be. The fix is a hook check that fits
names, not a counter.

## Intent
A page under `docs/` never gains a second heading with the same text as one it already has. The
hook refuses the change that would add it: a commit on a branch, a direct commit on trunk, or
the merge commit (clean or resolved) that would join two jobs' copies. The refusal names the
page, the heading and both lines. A page that already holds a duplicate on trunk isn't refused
for it. Only a change that raises a heading's count past one is refused, the way R6's
`"unique"` works. RULES.md says how two parallel jobs adding sections to one page are kept
apart. Update's `reserve.section` finding names that rule as what replaces the counter.

## Why
1. Q: Why did the owner think the number mattered?
   A: R6 handed each job its own section number (`jig open --reserve section`), so two jobs
   adding rule sections to pages could never take the same one. The board caught a collision
   before merge, not after.
2. Q: What does the redocument replace numbers with?
   A: Named headings, cited `<page> § <heading>` (RULES.md, Documentation: "Cite a page by its
   heading ... not by a number"). A heading's text is now the address, as the number was.
3. Q: Is the address still unique?
   A: No. Two jobs that share a page and each add `## Cache` at different places merge cleanly
   into a page with two `## Cache` headings. No hook, survey or check refuses it (Givens).
4. Q: Does the duplicate break any of jig's tooling?
   A: Yes, quietly. `pointer_gap` resolves a `§` when any heading matches, so a metarepo pointer
   `docs/store.md § Cache` lands on two places. If one of them is later renamed, the pointer still
   resolves on the other, and P2 never asks about the moved section. Inside the repo, `§ Cache`
   in a decision's `Touches:` or another page names two sections with nothing to tell which.
5. Q: Why not keep a counter, or reserve heading names on the board?
   A: A name has no "next" to hand out. Reserving names (`--owns "<page> § <heading>"`) makes the
   hubnode guess every heading a job will write before it writes it. The collision is mechanical
   at merge, so the check belongs where R6's `"unique"` already sits: one more check in the
   hook, which runs on merges too.

## Givens
- `[seen]` RULES.md R6 and Reserved numbers: counters are numbers only (`(\d+)`, compared as
  ints). `"unique"` refuses a second match of one number. Nothing in a counter can carry a name.
- `[seen]` `jig.py` `migration_findings` (around line 2568): update's finding for a counter over
  numbered page headings says "drop it at /jig:redocument's cleanup ... since the contract cites
  a page by its heading". It names no replacement.
- `[seen]` `plugin/skills/redocument/SKILL.md` step 5 cleanup removes "the counter over numbered
  headings from `reserve`".
- `[seen]` `grep -n -i "duplicate\|twice" jig.py`: no check of repeated headings on a page. The
  existing hits are R6 unique, the roadmap and repos.
- `[seen]` `pointer_gap` (around line 6348): `want in heads or ... any(...)`. A heading that
  appears twice resolves, with no warning.
- `[seen]` Repro, `/private/tmp/claude-501/hdgcol/r`, script
  `/private/tmp/claude-501/hdgcol-scripts/repro.sh` and `hooks.sh`. The plugin's template,
  `jig init`, `docmap` `docs/store.md: [src/**]`. Two jobs `ja` and `jb`, each `--shares
  docs/store.md`, each adding `## Cache`:
  - `apart` (ja before `## Schema`, jb before `## Invariants`): both branch commits pass the
    hooks. `git merge --no-ff ja` and then `jb` on main, with jig's hooks installed
    (pre-merge-commit, post-merge), both succeed. `grep -c '^## Cache' docs/store.md` gives 2.
    A third `## Cache` committed straight on main passes too. `jig survey` and `check.sh` say
    nothing.
  - `end` (both append at the end of the page): git conflicts in `docs/store.md`. The person
    resolving it can keep both sections, and nothing then refuses the resolved commit.
- `[inferred]` `jig merge` and the gate's scratch merge go through the same hooks as the plain
  `git merge` above. Neither runs a page check of its own, so they behave the same. Not run
  through `jig merge` itself.
- `[assumed]` from the report: no Maige-Lite job has hit this yet, because no two jobs have
  edited one page in parallel since the redocument.

## What else the report asks
- (b) Two headings that mean the same thing under different names: no mechanical check can
  see this. Fold-in at handoff asks every page covering the changed files, and review reads the
  diff. That's where it belongs. RULES.md says so in the same paragraph, so the owner knows
  it's a judgment, not a guard.
- (c) Two jobs each rewriting one section: overlapping hunks conflict in git. Edits that don't
  overlap merge like any shared file, and "Append, never edit, shared prose. A change to
  someone else's section is a note in yours" (Keeping merges mechanical) already covers it.
  `owns` on the page is the hard guard when a job must rewrite. No change.

## Change
1. `jig.py`, hook (pre-commit, and the merge commit through the same path): for each page the
   change adds or modifies under `docs/` (what survey reads as a page; `not_docs` exempt),
   count its headings outside fenced code blocks, keyed by text as `§` reads it (`plain`, case
   folded). Refuse when a key's count rises past one compared with trunk's copy of the page
   (none for a new page). The error names the page, the heading text and the line numbers of
   both. Judged against trunk while a merge of trunk is being finished, as the other hook
   checks are. Applies with no job open, like `"unique"`.
2. RULES.md, Documentation, after "Cite a page by its heading": a heading's text is its address,
   so a page holds each heading once, and the hook refuses a change that adds a second. Under
   Keeping merges mechanical, one line on how two jobs share a page: each appends its own
   section under its own name, a collision on the name is refused at the merge that makes it,
   and two names for one thing are fold-in's and review's to catch.
3. `migration_findings`: the counter finding's fix text names the replacement, e.g. "drop it at
   /jig:redocument's cleanup, once no page holds a numbered heading: a page cites by heading,
   and the hook refuses a page's second heading of one name (`.jig/RULES.md` (Documentation))".
4. `marketing/FEATURES.md`: a row for the check (what, from this report, why: a heading is the
   address that the section number used to be; not: a name registry, a synonym check), added
   before the code. Update row 72's "not" column too: it says "On for section counters", and
   that no longer applies.
5. `tests/smoke.sh`: the `apart` repro as a case. Both branch commits pass, the second merge is
   refused and names `## Cache`, a page that already has a duplicate on trunk can still be
   edited elsewhere, and a fenced `## x` inside a code block isn't counted.

## Not in scope
- `pointer_gap`'s acceptance of an ambiguous match. Once pages can't gain duplicates, it only
  matters for pages that already have them, and survey could list those later.
- The prefix rule (`§ Cache` in prose also resolves to `## Cache eviction`). It's a separate
  ambiguity, and it predates this.
- Maige-Lite's own config. Its owner keeps the counter until this ships, and then drops it at
  update's word.

## Decisions
- **Every heading level counts** (Dave, 2026-11-13: "Yes, open all eight", taking the hubnode's recommendation). A page with two `### Errors` under different `## ` sections renames one.

## Open question for the owner (answered above)
Which headings count: every level (`#` to `######`), or only `## `? Every level matches how
`§` resolves, since any heading is an address. The cost is that a page with `### Errors` under
two different `## ` sections must rename one (`### Sync errors`). `## ` only is looser and
leaves those `###` citations ambiguous. Recommendation: every level.

## Done when
- The repro's second merge is refused, naming the page and the heading. The `end` case's
  resolved commit that keeps both is refused the same way.
- RULES.md states the rule and how parallel jobs on one page are kept apart. Update's
  `reserve.section` finding names it.
- `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
