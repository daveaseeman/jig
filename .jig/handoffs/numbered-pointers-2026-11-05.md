# Handoff: numbered-pointers

Commit: 9444dced59a4ac3cf704db3165e302f73648fb42
Date: 2026-11-05
Spec: .jig/specs/bug-numbered-pointers.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to high, not readable by the subagent)

## Built
A pointer's `§2` or `§2.1` resolves to the heading with exactly that number (`section_number`); `2-factor` and `2.a` stay words.
P2 compares levels (resolves, heading missing, file missing): a change counts when it makes a pointer worse than at the base, so a lost file counts even when its heading already dangled.
Display prints a number whole and cuts prose at a clause or sentence end; each dangling line prints once (`dangling`).
In a pararepo, `jig update`'s report has a Metarepo pointers block (`pointer_cleanup`). Each dangling pointer either names the commit that removed its target, found by `removal` walking the history with `pointer_gap`, plus a BUFFER.md row from `buffer_offer` (or the Open row that already names it), or says this repo never had it and names `jig propose`. Update writes neither the row nor the metarepo.
`removed_by` and `buffer_offer` are separate functions so p2-removals can reuse them.

## Done-when evidence
- sync resolves §2.1, §2, § 10 and reports § 3 and §1: `bash tests/smoke.sh pointers` → `PASS  pointers: sync resolves §2.1, §2 and § 10 by number, and reports § 3 and §1, which ## 10. doesn't satisfy`
- r.md §1 dangles: `PASS  pointers: §1 under ## Rules with ### 1.1 is dangling: 1.1 is not heading 1`
- prose §1.2 prints whole, one line per missing file: `PASS  pointers: a prose §1.2 (… prints its number whole, and two pointers into a missing file print one line`
- the four refusals: `PASS  pointers P2: renaming a file only numbered pointers name is refused…`, `… deleting ### 2.1 Identity is refused…`, `… renaming a file whose one pointer already dangled is refused…`, `… deleting a file whose one pointer (§ Gone) already dangled is refused`
- g.md edit and buffered rename commit: `PASS  pointers P2: an edit that leaves § Gone missing commits`, `PASS  pointers P2: the x.md rename commits with meta: buffered <id>`
- the cleanup in v0.6.0 `po`: `PASS  pointers: under v0.6.0's hook, renaming x.md and deleting ## 4. Keys both commit (the bug)`, `PASS  … update's dry run lists Metarepo pointers…`, `PASS  … update finds the commit that removed a prose heading … and a 4: heading, by the resolver`, `PASS  … update says this repo never had docs/r.md § 1, names jig propose, offers no row, and changes nothing`
- Open row suppresses the offer, --apply leaves BUFFER.md: `PASS  pointers: with an Open row naming docs/x.md committed, update offers no row for it, and --apply leaves BUFFER.md alone`; `PASS  … an Open row about another heading of the file (w.md § 9) doesn't stand in for § 4`
- existing sync_buffer pointer cases, § Colors included: full run, all nine `pointers` lines in sync_buffer PASS (e.g. `PASS  pointers: sync reports a page pointer to a file this repo doesn't have, and to a heading a file lacks`)
- RULES.md grep: `PASS  pointers: RULES.md has the number rule and P2's lost-file rule`
- `bash tests/smoke.sh` at 9444dce: exit 0, 540 PASS, 0 FAIL, `PASS  isolation: the user's real jig config folder is unchanged by the run`; `claude plugin validate ./plugin` → `✔ Validation passed`; `.jig/scripts/check.sh` → exit 0

## Review
Round 1 (hubnode's fresh-context review of 3d071f2, tier 2, effort 2):
- Blocking 1: `removal` used a `git -G` regex that disagreed with the resolver (a prose heading, a `4:` heading, and `Keystone` read as `Keys`). Fixed in 9444dce: it now walks `git log -- <path>` and takes the newest commit whose parent's pointer missed less, by `pointer_gap`. Smoke cases for the prose and `4:` headings were added.
- Should-fix 2: spec Alternatives item 3 was tagged [assumed]. Fixed in 9444dce: now [seen], with what was observed.
- Should-fix 3: no evidence for Done when 8 and 10. Fixed: the full run's output is shown above.
- Optional 4: `section_number` read `2-factor` and `2.a` as 2. Fixed in 9444dce, with non-resolving cases.
- Optional 5: `buffer_offer` let any Open row naming the file suppress a heading's offer. Fixed in 9444dce: a heading's row must name the heading, with a case for it.
- Optional 6: the block shows only on update runs that have other actions. Deferred by the hubnode in DEFERRED.md, as the spec's Decision.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (What the metarepo holds, P2's row), with the update skill's paragraph.

## Shared files changed
- plugin/templates/jig/jig.py: the resolver (`section_number`, `shown_section`, `pointer_gap`, `dangling`, `stale_pointers`), P2's `broken` in `para_rules`, the new `removed_by`/`removal`/`buffer_offer`/`pointer_cleanup`, and their own block in `cmd_update`'s `report()`.
- plugin/templates/jig/RULES.md: the number rule in What the metarepo holds, and P2's lost-file clause.
- plugin/skills/update/SKILL.md: one paragraph on the Metarepo pointers block.
- tests/smoke.sh: the new `pointers` section and its `UNITS` entry.
- .jig/specs/bug-numbered-pointers.md: the review's tag fix (Alternatives item 3).

## Test by hand
In a pararepo on an older jig, run the plugin's `jig update` dry run and read the Metarepo pointers block. Each line should name a real commit and either offer a BUFFER.md row or name `jig propose`. Nothing in the repo or the metarepo should change.

## Left
Nothing on this job. p2-removals (`--after` this job) reuses `removed_by` and `buffer_offer`. The deferred item (the block shows only on runs with other actions) is in DEFERRED.md.
