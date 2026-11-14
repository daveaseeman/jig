# Handoff: heading-collision

Commit: 497713f6f6f5927ad0cebb68c2245502b4b37bec
Date: 2026-11-13
Spec: .jig/specs/bug-heading-collision.md
Review: tier 2, effort 2

## Built
- The hook refuses a change that leaves a page under `docs/` with more copies of one address than it had. An address is a heading at any level, compared as `§` compares it (code and emphasis marks dropped, case kept); in `docs/glossary.md` a table-row term counts too. A heading inside fenced code doesn't count. A refusal names the page, the heading and every line. This covers branch commits, direct commits on trunk, and merges: the clean case and a conflict resolved by keeping both copies.
- A page's old content is found wherever it came from: a rename anywhere in the tree (one `renames()` helper, which `page_moves` now uses), or, for a rewrite git reads as a delete plus an add, the change's deleted `.md` files. A duplicate a page already had is never refused, edited or moved. `CHANGELOG.md`, `DECISIONS.md`, datasheets and `not_docs` files are exempt.
- RULES.md (Documentation): a heading is a page's address, so each appears once; a fold joins sections of one name into one (both fold passages). Keeping merges mechanical: two jobs sharing a page each add sections under their own names, a name both chose is refused at the merge that would join them, and two names for one thing are fold-in's and review's to catch.
- Update's `reserve.section` finding now names the heading rule as what replaces the counter.

## Done-when evidence
- Repro's second merge refused, naming page and heading: `bash tests/smoke.sh headings` → `PASS headings: the clean merge that would join the second ## Cache is refused, naming the page, the heading and both lines` (message `docs/store.md has \`Cache\` 2 times (lines 5, 13)`).
- `end` case's resolved commit that keeps both is refused: `PASS headings: a conflicted merge resolved by keeping both ## Cache sections is refused`.
- RULES.md states the rule and how parallel jobs on one page are kept apart (Documentation; Keeping merges mechanical). Update's finding names it: `PASS headings: update's section-counter finding names the heading rule that replaces it`.
- Full `bash tests/smoke.sh` at 497713f: 1245 PASS, one FAIL, `isolation: the user's real jig config folder is unchanged by the run`. The run began 18:58:51. `~/.config/jig/repos.json` was written at 19:11:47, mid-run, by an outside process: the file holds only real repos and no smoke temp path. This was another session's real jig work, not the smoke. The earlier full run at e85c659 (before the review fixes) passed isolation with the `headings` section in it (1238 PASS, rc=0).
- `claude plugin validate ./plugin` → `✔ Validation passed`. `.jig/scripts/check.sh` → exit 0.

## Review
- Spec blocker (no `Alternatives considered` section): the hubnode fixed it on trunk (f7baf7c), picked up here by `jig sync`.
- Blocker, renames only under `docs/`: a page moved in from outside, or rewritten past git's similarity cutoff, was compared against nothing, so `/jig:redocument`'s normal move was refused. Fixed: whole-tree `renames()`, shared with `page_moves`, plus the deleted-files fallback. Smoke: `a page moved into docs/ from outside keeps its duplicate`, `a move that rewrites most of the page ... keeps its duplicate too`.
- Should-fix, glossary rows: `§` resolves table rows in `docs/glossary.md`, and the check ignored them. Fixed: rows count with the headings. Smoke: `a second glossary row of one term is refused`, `a glossary heading naming a term a row already has is refused`.
- Should-fix, case and fences vs `§`: RULES.md (line 870) says a `§` heading keeps case. Fixed: the check keeps case, and the text says "case kept". `pointer_gap` is unchanged; it still resolves headings inside fenced code, which this check deliberately doesn't count, since a quoted heading is an example. Smoke: `§ keeps case, so a heading differing only in case is another address and commits`.
- Should-fix, no smoke case for update's finding text: added (above).
- Should-fix, fold test changed to pass: RULES.md now says a fold joins sections of one name (both fold passages). The fold case appends the page whole first and is refused on `## Invariants`, then joins and passes. Smoke: `a fold that appends the page whole is refused for its second ## Invariants`, `the joined fold holds one ## Invariants with both pages' entries`.
- Optional, fence close by the other marker: fixed; only the opening marker, at least as long, closes. Smoke: `only the opening fence's own marker closes it`.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's docs are .jig/RULES.md (plugin/templates/jig/RULES.md), updated here: Documentation (a page holds each heading once; folds join sections of one name) and Keeping merges mechanical (two jobs sharing a page)

## Shared files changed
- `plugin/templates/jig/jig.py`: the check (`heading_lines`, `heading_rules`, called from `check_rules`), the `renames()` helper behind `page_moves`, and update's `reserve.section` finding text.
- `plugin/templates/jig/RULES.md`: the rule, the fold wording, and the shared-page line in Keeping merges mechanical.
- `tests/smoke.sh`: a new `sec_headings` section, appended to `UNITS`, and the `homes` fold case rewritten to join sections.

## Test by hand
- In a repo with jig, add `## Cache` to a docs page on two branches at different places. Merge both: the second merge stops with `docs/<page>.md has \`Cache\` 2 times (lines …)`.
- `git mv` a root `ARCH.md` holding two `### Errors` into `docs/`: it commits.

## Left
- `plugin/skills/update/SKILL.md`'s fold drafting may want the same "join sections of one name" line. It's outside this job's files.
- `pointer_gap` still resolves a `§` against headings inside fenced code; not changed here.
