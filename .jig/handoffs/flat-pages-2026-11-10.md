# Handoff: flat-pages

Commit: 1bfce3d1f23a4ad1651af1164254dd51e2a0e3cb
Date: 2026-11-10
Spec: .jig/specs/flat-pages.md
Review: tier 2, effort 2
Ran: fresh Opus review of f5eabb5: B1 growing a flat board page into its folder on a branch refused (config trunk-only, board move refusal), fixed in 1bfce3d (one page in two forms) with a gate smoke case; S2 flat owner, S3 ignored datasheet, S4 stale approval, S5 misfiled seams, S6 old-layout boards flat, S7 retro wording, O8 board_home, test gap all fixed; O9 deferred. Hubnode checked 1bfce3d by diff and smoke homes/hardware.

## Built
<!-- what this delivers, in a few lines -->
- A page is one file, flat in its parent's folder (`docs/<system>.md`, `docs/<system>/<part>.md`), until it holds another: part pages, linked files, a `datasheets/` folder. Then it moves into `<name>/<name>.md`.
- In a folder with a page, another `.md` is a flat page when docmap or `boards` names it, or it has Invariants/Undefined (or the old Now/Rules/Checks); anything else is a linked file. Depth counts the folder a page stands for (`page_folder`).
- The two forms are one page (`page_forms`): docmap keys and `boards` entries match either, the gate's board check reads a move between them as the same page, fold-in and reading-list name the form on disk. A job grows a folder with a `git mv` alone.
- A flat `docs/a.md` owns `docs/a/` (`folder_owner`), so its parts and datasheets stay its own while survey tells it to move in.
- Survey: new `page_shapes` (a folder page alone, "flat at …"; a flat page with a same-named folder, "move it to …") and `seams_misfiled` (a page in one system's folder covering another system's files). `jig update` lists the shapes under Repo files to review, with the `git mv`, and changes nothing.
- The reading list climbs from flat part pages; a seam page lives flat in the folder its systems share (`docs/<seam>.md`), with no parent.
- Migration: a root `HARDWARE.md` and an old `docs/hardware/<board>.md` go flat unless files go with them.
- Wording: RULES.md Documentation and Homes, `DOC_HOMES`, `/jig:hardware`, `/jig:adopt`, `/jig:redocument`, `/jig:update`, `/jig:retro`, the AGENTS template's Firmware line.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Smoke `homes` (`flat:` cases, PASS): `docs/a/b.md` (docmap) and `docs/a/c.md` (Invariants) not reported, `docs/a/notes.md` a linked file; `docs/a/d/d.md` alone reported "flat at docs/a/d.md", not with `wiring.pdf` beside it; `docs/a/b.md` with `docs/a/b/` told to move in; `docs/a/b/f.md` with `docs/a/b/f/f.md` folds in; `docs/a/b/e.md` deep without `deep_subsystems`, at home with it, and the approval still matches.
- Smoke `homes`: update lists `docs/a/d/d.md` under Repo files to review with `git mv docs/a/d/d.md docs/a/d.md`; `--apply` leaves it (PASS).
- Smoke `homes`: reading-list for `src/c/c.rs` prints `docs/a/c.md`, then `docs/a/a.md (parent of docs/a/c.md)`; the seam at `docs/seam-gpio.md` prints no parent; a docmap-named `docs/net/x.md` climbs to `docs/net/net.md` (PASS).
- Smoke `homes`: flat `docs/a.md` owns `docs/a/b.md`; a flat page linking its ignored `datasheets/` is told to move in, nothing misplaced; a misfiled seam is named (PASS).
- Smoke `hardware`: a flat board page `boards` lists moves into its folder with a datasheet on job HF1 and `jig gate` passes; flat-form keys name the folder page; a lone old `docs/hardware/b.md` goes to `docs/b.md` (PASS).
- RULES.md, `/jig:hardware`, `/jig:adopt`, `/jig:redocument`, `/jig:update`, `/jig:retro`, AGENTS template: wording changed as the spec's Wording bullet lists.
- `bash tests/smoke.sh` → exit 0, 807 PASS, 0 FAIL (`flat-pages-smoke.out` in the shared notes folder). `claude plugin validate ./plugin` → ✔ Validation passed. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing. `.jig/scripts/check.sh` → exit 0.

## Review
<!-- findings from the adversarial review, and what you did about each -->
- Review of f5eabb5 (hubnode, tier 2 effort 2), all fixed in 1bfce3d unless noted:
  - B1 (blocking): a flat board page couldn't grow its folder on a branch (config is trunk's; the gate refused the move). Fixed: one page in two forms; smoke gate case added.
  - S2: a flat `docs/a.md` didn't own `docs/a/`, giving contradictory advice. Fixed with `folder_owner`.
  - S3: an ignored datasheet didn't count as company, and was called misplaced. Fixed.
  - S4: an approved deep page gone flat left its key `deep_unmatched`. Fixed.
  - S5: an old seam in a system's folder silently gained a parent. Survey now names it.
  - S6: a lone old-layout board page went to a one-file folder. Now flat.
  - S7: retro wording. O8: `board_home` uses the folder when `docs/<board>/` exists. Test gap (both forms present) added.
  - O9: deferred, row in `.jig/ledgers/DEFERRED.md`.
- Earlier, on the hubnode's ruling: a seam page is placed by where it lives, not by its sections.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's docs are .jig/RULES.md (plugin/templates/jig/RULES.md), updated here: Documentation (pages flat until they hold a file, one page in two forms, the seam's home) and Homes

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: the homes helpers, survey, update's review rows, reading-list, fold-in, gate board checks.
- `plugin/templates/jig/RULES.md`: Documentation and Homes.
- `tests/smoke.sh`: `sec_homes` (new `flat:` block, updated page cases), `sec_hardware` (flat part page, band, gate case), `sec_update` (HARDWARE.md flat), `sec_page_contract` (misplaced page goes flat).
- `plugin/skills/redocument/SKILL.md`, `plugin/skills/update/SKILL.md`, `plugin/skills/retro/SKILL.md`, `plugin/templates/AGENTS.md`: the page paths.
- `.jig/ledgers/DEFERRED.md`: the O9 row.

## Test by hand
<!-- what a person should click or watch -->
- In a repo with `docs/x/x.md` alone in its folder, `jig survey` prints it under "Pages in the wrong shape" as "flat at docs/x.md"; `jig update` lists it with its `git mv`.

## Left
<!-- what remains on this job -->
- Nothing on this job. The FEATURES.md row is the hubnode's. `bug-redocument-any-format` and `meta-docs-tree` build on `page_forms`, `folder_owner` and `page_shapes`.
