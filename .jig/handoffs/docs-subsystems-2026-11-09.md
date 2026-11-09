# Handoff: docs-subsystems

Commit: 453cbe82529caa1725ea4b9ae10f03e2e8f8b3e1
Date: 2026-11-09
Spec: .jig/specs/docs-subsystems.md
Review: tier 2, effort 2
Ran: fresh Opus subagent, effort high: diff main...docs-subsystems, spec, AGENTS.md; 1 blocking (RULES.md Homes/kinds still allowed any depth), 3 should-fix (deep old-shape pages not contract-checked or counted for redocument; update's deep row left docmap/contract_paths/stale lines; survey named only the deepest unapproved level), 3 optional (unmatched deep_subsystems keys; move vs fold wording; skills restating RULES.md) — all fixed in 453cbe8, checked by the hubnode

## Built
A subsystem is now defined by independence: it has files of its own that the rest of its system
reaches only through interfaces, as a car's cooling system is separate from its suspension.
"Outgrows a screen" is gone. The docs tree is two levels deep, `docs/<system>/<system>.md` and
`docs/<system>/<subsystem>/<subsystem>.md`. A deeper page is at home only where `config.json`'s
optional `deep_subsystems` approves its folder, and each level below the subsystem, with a
non-empty rationale. Survey and update list any other deeper page as kind `deep`: fold it into
its subsystem's page (or move it there when that page doesn't exist), or ask the owner to approve
the levels named. `page_home` never proposes a destination deeper than a subsystem. Survey also
reports `deep_subsystems` keys that name no tracked folder. `docs/hardware/` keeps its own homes,
behind one `BOARD_PAGES` check in `unapproved()` that flatten-hardware can remove.

## Done-when evidence
- Smoke `homes` (survey: deep page, approved, empty reason, docs/c/d/d.md, docs/a/b/x.md fold target): `bash tests/smoke.sh homes` — 23 PASS, 0 FAIL, including "a page below a subsystem is deep, folding into its subsystem's page; docs/c/d/d.md passes; a page beside a subsystem's folds into it", "with docs/a/b/c approved, survey doesn't list docs/a/b/c/c.md", "an empty rationale approves nothing".
- Smoke `homes` (update): PASS "the dry run lists the deep page to review; --apply writes no deep_subsystems key", PASS "update keeps the deep_subsystems entry and calls no key unknown".
- RULES.md and docs-page.md: `grep -rn "outgrows a screen" plugin` printed nothing; RULES.md Documentation states the definition, the depth, `deep_subsystems`, Homes and the `deep` kind.
- Skills: update, redocument and adopt propose only system/subsystem; a third level goes to the owner as a `deep_subsystems` entry, pointing at RULES.md for the rationale.
- `bash tests/smoke.sh`: exit 0, 665 PASS, 0 FAIL (on 453cbe8). `claude plugin validate ./plugin`: ✔ Validation passed. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` printed nothing. `.jig/scripts/check.sh`: exit 0.

## Review
Hubnode's fresh reviewer, tier 2 effort 2, on 35e5f52. All seven were fixed in 453cbe8, so nothing is deferred.
- Blocking: RULES.md Homes and the kinds list still allowed a page at any depth and had no `deep`. Fixed: both now state the depth, the `deep_subsystems` approval and the `deep` kind with its two choices.
- Should-fix: a deep page in the old shape skipped the page-contract check and didn't count toward /jig:redocument. Fixed: deep pages get the contract check and count. Smoke check added.
- Should-fix: update's deep row left the docmap behind. Fixed: it shares the page fold's lines (docmap, contract_paths, stale lines, pointers, BUFFER rows). Smoke check added, with a docmap key on a deep page.
- Should-fix: survey named the deepest folder, not the unapproved level. Fixed: `unapproved()` names every unapproved level. Smoke check added.
- Optional, taken: a misspelled `deep_subsystems` key approved nothing, silently. Fixed: survey reports it (`deep_unmatched`).
- Optional, taken: "fold into" could name a page that doesn't exist. Fixed: it says "move it to" when `fold` is false.
- Optional, taken: the update and redocument skills restated RULES.md's rationale wording. Fixed: they point at `.jig/RULES.md` (Documentation).

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation: subsystem definition, depth, Homes, the `deep` kind; the board keys line).

## Shared files changed
- `plugin/templates/jig/jig.py`: `deep_subsystems` in `BOARD_OPTIONAL`, `folder_page`/`depth_ok`/`unapproved`/`deep_home`/`deep_fix`, `at_home`, `page_home`, `doc_homes`, survey's listing and homes line, update's home findings (the page-fold lines factored into `commit_lines` so deep rows share them).
- `plugin/templates/jig/RULES.md`: the Documentation definition and depth, Homes, kinds, the board keys line.
- `tests/smoke.sh`: new cases in `sec_homes` (repos `homes-deep`, `homes-deep-old`).
- `plugin/skills/update/SKILL.md`, `plugin/skills/redocument/SKILL.md`, `plugin/skills/adopt/SKILL.md`: each skill's nesting line.

## Test by hand
In a repo with `docs/a/a.md`, `docs/a/b/b.md` and `docs/a/b/c/c.md`, run `jig survey`: "Pages below a subsystem" lists `docs/a/b/c/c.md: fold it into docs/a/b/b.md, or ask the owner to approve docs/a/b/c …`. Add `"deep_subsystems": {"docs/a/b/c": "<reason>"}` to `.jig/config.json` and commit: the line goes away.

## Left
Nothing on this job. flatten-hardware, which comes next, removes the `docs/hardware/` exemption in `unapproved()` and `at_home`. `marketing/FEATURES.md` is done on main.
