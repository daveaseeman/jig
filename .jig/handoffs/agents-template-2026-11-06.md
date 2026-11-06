# Handoff: agents-template

Commit: 7d260f811d3416f98b4ee3ec7d56d3319cb4ea78
Date: 2026-11-06
Spec: .jig/specs/bug-doc-homes.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to high, not readable by the subagent); findings A, B blocking fixed at 7d260f8, C–E taken

## Built
<!-- what this delivers, in a few lines -->
Job 2 of bug-doc-homes. The template restates nothing RULES.md holds: the Jobs block is gone, its Rulebook/Roles line now under Workflow; the docs, homes and Firmware board-page lines point at `.jig/RULES.md` (Documentation) and name no paths. RULES.md § Homes gains the one-home-per-kind list the old template line held. Update's whole-file "AGENTS.md against the template" diff (and `difflib`) is removed. `files_to_review` now ends with `agents_lines`: the template's Rulebook line when AGENTS.md doesn't name `.jig/RULES.md` other than as a section citation; a Commands line for each `.jig/scripts/<x>` the template's Commands names that the repo has or this run adds; and per retired block (`RETIRED_BLOCKS`: `## Lanes (parallel sessions)`, `## Jobs (parallel sessions)`, by exact heading), replace it with the Rulebook line, or delete it when that line already stands outside. The update skill offers each on a yes, and reads AGENTS.md against RULES.md to offer pointer lines for restated ones.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Template diff (#3): `bash tests/smoke.sh agents_lines` — PASS "no template diff and none of the filled text; the one AGENTS.md line proposes the template's setup: line"; PASS "with the setup: line restored, no AGENTS.md line prints"; PASS "with the Rulebook line removed, it is proposed, though the docs lines cite RULES.md (Documentation)"; PASS "a mention of RULES.md with an aside after it counts as the Rulebook line". `update`'s old "shows AGENTS.md against the template" assertion replaced by PASS "no template diff; eaec973's Lanes block is proposed for replacement with the Rulebook line, by its lines" and PASS "on the run that adds .jig/scripts/setup.sh to eaec973's layout, its setup: line is proposed".
- Retired blocks (#3's cleanup): PASS "a reworded Jobs block, the Rulebook line already under Workflow, is proposed for deletion, naming its lines; --apply leaves AGENTS.md alone"; PASS "the same block under Lanes is proposed too"; PASS "a repo's own ## Jobs we run gets no proposal"; eaec973's real Lanes block proposed as lines 24–28 (replace, its only Rulebook line being inside it).
- Template grep: `grep -nE 'docs/<system>|docs/hardware/|^## (Jobs|Lanes)' plugin/templates/AGENTS.md` prints nothing (rc 1). Template: 28 rule lines, 44 lines in all.
- `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` prints nothing.
- At 7d260f8: `bash tests/smoke.sh` rc=0, 595 PASS, 0 FAIL, isolation PASS; `claude plugin validate ./plugin` ✔ Validation passed; `.jig/scripts/check.sh` rc 0.
- Other spec items (rules file, pages, pararepo pages, copy, RULES.md grep, real repos): job `doc-homes`, merged at 5a8b9f0.

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode, tier 2 effort 2, at 103be8d; all fixed or taken in 7d260f8, review recorded at 7d260f8:
- A. Blocking: the `setup:`/`check:` line was never proposed on the update run that adds or moves the script, since `agents_lines` tested only `exists()` before apply — a regression against the spec's "first run of every changed jig.py". Fixed: a script counts as present when this run's plan moves, writes or adds it (`arriving`); smoke case on eaec973's dry run.
- B. Blocking: the spec's Out of scope relies on the update skill reading AGENTS.md against RULES.md, and the skill said the opposite. Fixed: one sentence — offer, one at a time on a yes, the template's pointer line for a line that restates RULES.md; the rest stays the repo's wording.
- C. Optional, taken: a retired block is proposed for deletion when the Rulebook line already stands outside it.
- D. Optional, taken: only `(Capitalized` or `§` after `.jig/RULES.md` reads as a section citation; "(the rulebook)" counts as the Rulebook line. Smoke case added; no DEFERRED row needed.
- E. Optional, taken: the section's helpers renamed `alines`/`abehind`, so they no longer shadow the global `lines()` or duplicate `behind()`.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's docs are .jig/RULES.md (plugin/templates/jig/RULES.md), updated here: Documentation § Homes, the one-home-per-kind paragraph

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- plugin/templates/jig/jig.py: `files_to_review` gains `template`/`arriving` params and ends with `agents_lines` (new, beside `RETIRED_BLOCKS`); one `arriving` line and the call in `cmd_update`; the template diff removed from `report()`; `import difflib` dropped.
- plugin/templates/jig/RULES.md: one paragraph appended at the end of `### Homes`.
- plugin/skills/update/SKILL.md: one paragraph after the home-findings paragraph.
- tests/smoke.sh: `sec_agents_lines` before `SLOW=`, `agents_lines` in UNITS; in `update`, the template-diff assertion replaced and the setup: line case added before the HARDWARE board case.
- marketing/FEATURES.md (gitignored, main checkout): the `AGENTS.md` ≤40 row and both `update` rows.

## Test by hand
<!-- what a person should click or watch -->
In a repo set up from an older jig whose AGENTS.md has a `## Jobs (parallel sessions)` or `## Lanes (parallel sessions)` block, run `python3 plugin/templates/jig/jig.py update`: no "AGENTS.md against the template" diff; Repo files to review names the block's lines and the Rulebook line, plus a Commands line for any `.jig/scripts/` file AGENTS.md doesn't name. A fresh `/jig:init` AGENTS.md has no Jobs block and names no docs paths.

## Left
<!-- what remains on this job -->
Nothing on this job. Deviation from the spec's wording, by design: retired headings are the ones jig shipped, `## Lanes (parallel sessions)` (the spec writes `## Lanes`) and `## Jobs (parallel sessions)`.
