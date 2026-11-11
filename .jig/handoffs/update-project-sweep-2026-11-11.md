# Handoff: update-project-sweep

Commit: d6b4af242956876c6731a935f5cbae274eea1389
Date: 2026-11-11
Spec: .jig/specs/update-project-sweep.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on 6f7f394: B1 two Undefined sections, B2 struck row reviving its superseded row, S1-S5; fixed in d6b4af2; hubnode ran smoke sweep at d6b4af2 (27 PASS, 0 FAIL) covering B1, B2, the metarepo M2/M3 path, not_docs and entry files

## Built
`jig update` sweeps an existing repo onto the project/product boundary, every move on the owner's yes.
- Repo files to review now lists: each page's `## Undefined` entry as the `## Up next` item it would become; project headings and plan prose on product pages; decision entries, and before `--merge-log` register rows and sections, whose words read as scope; plan and register files (TODO, BACKLOG, STATUS, PLAN, a hand-written ROADMAP, FEATURES, RULES, CONVENTIONS, CONTRIBUTING) with their destinations.
- `jig update [--apply] --sweep`: writes the Up next items to `.jig/roadmap.md` on trunk (created when absent) and removes the emptied sections; in a metarepo a second run in a job removes the sections whose entries trunk's roadmap holds (R5 + M4).
- A released entry may be removed when the same commit adds `- D-NNN: …` under Unreleased `### Removed`; a register row with Status `struck` is left out of `--merge-log`, which refuses while a struck row supersedes an unstruck one.
- Survey and update share `product_pages()` (not_docs out, metarepo entry files in) and read trunk's scope ids.
- `plugin/skills/update/SKILL.md` walks the sweep; RULES.md says it (Documentation, Decision log, Commands).

## Done-when evidence
- Undefined → Up next, created, removed, second run silent: `bash tests/smoke.sh sweep` — "update lists each ## Undefined entry…", "--apply --sweep creates .jig/roadmap.md…", "a second dry run says nothing about it": PASS.
- Spec path, "phase 3", `## Status` under Repo files to review: "a page line naming a spec, one saying phase 3, and a ## Status section…": PASS.
- Released D-001 Demo priorities listed; removal with a Removed line commits, without it refused: "a released D-001 Demo priorities is listed…", "removing released D-001 with no ### Removed line…", "removing it with an Unreleased ### Removed line naming D-001 commits…": PASS.
- Register priority row and Pending delivery section listed; struck row left out: plain-repo cases plus the old-shape metarepo cases (M2 takes struck, M3 asks a CHANGELOG line, the job's --apply --merge-log leaves it out): PASS.
- TODO.md and FEATURES.md listed with destinations: "tracked TODO.md and FEATURES.md are each listed…": PASS.
- Skill walks the sweep: `plugin/skills/update/SKILL.md`, "The project in the product".
- `bash tests/smoke.sh`: 1006 PASS, 0 FAIL, rc=0 at d6b4af2 (notes: update-project-sweep-smoke-2.out); `bash tests/redocument-fixture.sh` rc=0; `claude plugin validate ./plugin`: Validation passed; `.jig/scripts/check.sh` rc=0; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing.

## Review
Fresh reviewer on 6f7f394; all fixed in d6b4af2:
- B1 two `## Undefined` sections on one page: spans grouped per page, one `without_sections` write. Smoke: Undefined/Invariants/Undefined/Tail page.
- B2 a struck register row revived the row it superseded as Accepted: `--merge-log` refuses, naming both. Smoke in the old-shape metarepo.
- S1 any id in a Removed line let an entry go: only `- D-NNN:` at line start, by number; a Removed line naming an id the log still has is refused; the refusal says "in the same commit". Smoke for each.
- S2 metarepo evidence: old-shape (v0.9.0) metarepo smoke for struck under M2, M3's CHANGELOG line, the merge-log job; the skill names the M3 line.
- S3 not_docs ignored: `product_pages()` filters it; plan_files too. Smoke.
- S4 entry files outside docs/ missed, scope ids from the working tree: `undefined_sweep` reads `product_pages()`; survey and update read trunk's roadmap. Smoke.
- S5 RULES.md "update brings this file, not the pages": rewritten.
Cheap takes: lowercase page stem in ids (smoke: `bigpage-sync-stuff`); `with_up_next` skips fenced code; `plan_files` skips docmap pages. The last two have no smoke.
Deferred, rows in `.jig/ledgers/DEFERRED.md`: `jig decision` on a struck entry/row; `SCOPE_WORDS` matching paths like `docs/demo/`.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation: the sweep paragraph; Decision log: struck entries; Commands).

## Shared files changed
- `plugin/templates/jig/jig.py`: the sweep block before `update_blocked`; struck-entry removal in `removed_entries`/`frozen_problems`; `struck` rows in `merged_log`; `product_pages()` used by survey; `--sweep` in argparse.
- `plugin/templates/jig/RULES.md`: the update sweep paragraph, the struck-entry sentence in Decision log, one Commands line.
- `tests/smoke.sh`: new section `sweep`, appended to UNITS.
- `.jig/ledgers/DEFERRED.md` (common): two deferred rows.

## Test by hand
In a throwaway repo with a page carrying `## Undefined`, run `jig update`, then `jig update --sweep`, then `jig update --apply --sweep` on trunk; read `.jig/roadmap.md` and the page.

## Left
- `marketing/FEATURES.md` row for the sweep: main checkout only, the hubnode's.
- The deferred rows above.
