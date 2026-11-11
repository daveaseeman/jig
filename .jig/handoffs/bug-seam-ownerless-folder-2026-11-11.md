# Handoff: bug-seam-ownerless-folder

Commit: 47f85d980f5f0ad29b9b52d377604cfb257a9dd9
Date: 2026-11-11
Spec: .jig/specs/bug-seam-ownerless-folder.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on 80112e9: one blocking (folder-form page in an ownerless folder reported nowhere), fixed in 90b8a38; hubnode re-review of 90b8a38 found the self-named subsystem hint, fixed in 47f85d9; both verified in a throwaway repo and smoke homes

## Built
- `misfiled_seams` places a page under a system only when `folder_owner` finds a page for that system's folder. A page in a folder no page owns (`docs/systems/old.md`) is no longer called a seam. It is listed once, as a page to move.
- `at_home` takes a folder page as at home only when `system_above` holds: the folder above it is the page root, or a page owns a folder above it. This is the test a flat page already passes through `owner_page`. `docs/systems/rest/rest.md` is now listed once, as kind `page`.
- `page_home` climbs from the folder above a folder page and keeps the folder form, so the folder moves with its files (`docs/rest/rest.md`).
- Survey's subsystem hint for a misplaced folder page climbs from the folder above, so it no longer names the page as its own parent.

## Done-when evidence
- Repro layout: `bash tests/smoke.sh homes` → `PASS  flat: a page in a folder no page owns is listed once, as misplaced, and never as a seam` (FAILs on main's jig.py)
- Folder form (spec amended after review): → `PASS  flat: a folder page in a folder no page owns is listed once, to move with its folder, and never as a seam` (also asserts the hint doesn't name the page as its own parent)
- Seam still fires in both forms: `PASS  flat: a page in one system's folder covering another system's file is named as a misfiled seam` (flat `docs/a.md`) and `PASS  flat: with its system page in the folder, docs/a/a.md, the seam is still named`
- `bash tests/smoke.sh` → exit 0, 901 PASS, 0 FAIL. `claude plugin validate ./plugin` → `✔ Validation passed`. `.jig/scripts/check.sh` → exit 0. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → no output (exit 1).

## Review
- Fresh review of 80112e9: one blocking finding. A folder-form page in an ownerless folder (`docs/systems/old/old.md`) was reported nowhere, because `at_home` accepted it. Fixed in 90b8a38 (`system_above` in `at_home`, `page_home` for folder pages, spec amended).
- Hubnode re-review of 90b8a38: one should-fix. Survey's hint named a misplaced folder page as its own parent. Fixed in 47f85d9.
- Two optional findings deferred, with rows in `.jig/ledgers/DEFERRED.md`: (a) a docmap-named `docs/systems/README.md` is now unreported (a README isn't a page); (b) `docs/a/b/seam.md` with no page for the intermediate `docs/a/b` is still listed twice (outside this spec).

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Documentation). That section already says a page in a folder with no page of its own is out of place, and this change makes survey follow it. No sentence went stale.

## Shared files changed
- `.jig/ledgers/DEFERRED.md` (common): two appended rows for the deferred optional findings, as the hubnode asked.

## Test by hand
- In a throwaway repo, with `JIG_CONFIG` and `XDG_CONFIG_HOME` set outside it: add `docs/systems/old.md` and `docs/systems/rest/rest.md` (with a file beside it), give each docmap globs that overlap another top-level page's, and run `python3 .jig/jig.py survey`. Each should be listed once, under "Pages outside the docs tree", as `→ docs/old.md` and `→ docs/rest/rest.md`. The seam section should be absent.

## Left
- Nothing on this job.
