# Handoff: findings-record

Commit: 61a3d1c1a1ff72d5392babc73a48940ee66f5115
Date: 2026-11-13
Spec: .jig/specs/findings-record.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
A yes to a finding is recorded on trunk, carried out, and kept where the owner put it.
- **Ids.** Each file finding survey prints and update lists has an id `<kind>:<path>`. The kinds are `FINDING_KINDS`: rules, copy, reserved, page (with a destination), deep, shape, contract (with a problem other than the old contract), and the level kinds section, shared and unmapped. Strays, genre files, old board files and old-contract-only pages are the remap's and have no id. Survey and update show the same ids on one tree (`file_findings`, `level_findings`, `is_finding`).
- **The record.** `findings` in `.jig/config.json`, in `BOARD_OPTIONAL`, trunk-only under R5. An entry is `approved`, `deferred: <where>` or `exception: <reason>`. `entry_problem` lists every entry that counts as no answer: an empty reason, a `deep:` exception (its home is `deep_subsystems`), an id with stray space, a kind with no id.
- **State.** Survey and update tag each finding with its outcome, and survey's `--json` carries `id` and `outcome`. Survey's last line counts unanswered findings, approved-not-done findings, exceptions answering no finding, and remap rows that contradict survey, each with who acts on it. It never says "nothing to do" while one stands.
- **Carried out.** `jig update --apply` carries out each approved `shape` or `page` move, whether or not the layout is current: the `git mv`, the `docmap` key and `boards` entry, that entry dropped, the page's other entries moved to the new path (never onto an id already recorded). It drops an approval or deferral whose finding no longer fires. Two moves onto one path (case-folded) go one at a time. What it can't do (references, `contract_paths`, `BUFFER.md` rows) it prints for the session, from the lines update already proposes (`move_lines`). The dry run says the same as `--apply` (`settle`). In a metarepo the moves are a job's (M4), and none is made on trunk.
- **Answers stay put** (the owner, 2026-11-13). jig never moves an entry except with its own move, and never drops an exception. Survey lists each exception that answers no finding, except while `.jig/redocument.md` is on trunk.
- **Contradictions refused.** The hook refuses a commit adding or changing `.jig/redocument.md` while a row keeps a page where survey moves it, judged on the tree the remap leaves (`remap_rows`, `remap_end`, `remap_contradictions`), unless the owner's exception is recorded. Survey names such rows in a remap on trunk.
- **Skills and rules.** The update skill asks one recorded answer per finding. Redocument records its deferrals at step 1, records an exception at the new page's id with the remap at step 2, and cleans up the old paths' entries at step 6. The survey skill explains states, unused exceptions and remap rows. RULES.md has "The findings record", the naming wording, and the command line.

## Done-when evidence
- Smoke `findings` and `merge_derived` (`bash tests/smoke.sh findings merge_derived`): 57 PASS, 0 FAIL, exit 0, at 61a3d1c. It covers the spec's three-page case:
  - ids and null outcomes in `--json`;
  - not answered in print, with the last line naming /jig:update;
  - `--apply` with no entry leaving both pages;
  - the approved move staged as `R100 docs/a/b/b.md docs/a/b.md`, with `findings` holding c's deferral only;
  - c printed `deferred: redocument`, and nothing for b;
  - the hook refusing the `same` row, naming the page, its destination and `findings`;
  - an empty exception still refused;
  - a reasoned exception passing and printing;
  - a moving row committing with no entry.

  The section also covers the answers-stay-put cases: rename, merge, split, a by-the-book redocument, and a metarepo. Plus a taken id, two moves onto one path, case-folded destinations, a flagged entry kept, a level finding's id, and dry-run agreement.
- The symptom, on Daisy: a scratch clone at `df641b1d` with this `jig.py`. Survey's "Remap rows that keep a page where survey moves it" lists exactly 24 pages, and its last line counts "24 remap rows keeping a page survey moves". Daisy itself is untouched.
- `grep -c findings plugin/skills/update/SKILL.md plugin/skills/redocument/SKILL.md`: 7 and 3. `grep -n "decline them all" plugin/skills/redocument/SKILL.md`: nothing (rc 1).
- RULES.md: `### The findings record` (line 351) states the record, outcomes, carry-out, answers staying put and the remap check. The naming sentence ("that is about naming only … the page still moves") is in Documentation. Command list, line 971: "carry out the moves findings approves".
- `bash tests/smoke.sh`: exit 0, 1154 PASS, 0 FAIL, at 61a3d1c (1124 PASS at 9ae083b, before the merge with merge-derived-files). `claude plugin validate ./plugin`: "✔ Validation passed". `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing.

## Review
The hubnode ran it at tier 2, effort 2. Round by round:
- Round 1 (6c8481f → b680f3c). Two blocking findings, both fixed:
  - The remap check judged today's tree; it now judges the tree the remap leaves.
  - Carry-out printed only references; it now prints `move_lines`.

  Should-fix S1–S5, all fixed:
  - Survey's last line counts contradictions.
  - A move takes the page's other entries with it.
  - Metarepo moves are a job's.
  - Only kinds both commands show are counted.
  - A deep exception lives in `deep_subsystems`.

  Optional O2 and O3 were taken.
- Rounds 2 and 3 (→ f95547f): fixes for entries following pages moved by other means. Round 3 left a blocking finding in the redocument flow, so the hubnode ran /jig:bug. Its finding: the inferred re-keys never converged.
- Redesign (0190c87): the owner approved "an answer stays where the owner put it" on 2026-11-13. The re-keys were deleted, `gone` leaves out exceptions, and survey lists unused exceptions.
- Redesign review (→ 05de323): fixed, blocking: a move renaming onto a taken id. Fixed, should-fix: per-count routes, and flagging kinds with no id. Two cheap optionals were taken.
- Merge with docs-structure-evidence (0e9e2aa): the conflicts in jig.py, RULES.md, the update skill and smoke.sh were resolved keeping both jobs' changes. `file_findings` passes `sections`.
- Final reviews (→ 7d03293, → a36c16d), all fixed, should-fix:
  - Two moves onto one path; destinations case-folded.
  - A flagged entry is never dropped.
  - Level findings get ids.
  - The dry run warns of a kept id, and agrees with `--apply` (`settle`).
  - One /jig:update route.
- Merge with merge-derived-files (61a3d1c): the hubnode's `jig sync` stopped on two conflicts.
  - RULES.md's board key list now names `findings` beside `deep_subsystems` and `boards`, then main's `derived_files`.
  - smoke.sh keeps both sections, and UNITS has both `merge_derived` and `findings`.
  - DEFERRED.md holds both jobs' rows.

  The hubnode checked the resolution and recorded the review on 61a3d1c. The first note, `findings-record-2026-11-13.md`, is for 9ae083b.
- Deferred: 10 rows in `.jig/ledgers/DEFERRED.md` (a36c16d), dated 2026-11-13, lane findings-record. One is should-fix, marked moot: the merge/split mis-rekey, removed by the redesign. The rest are optional:
  - a `page:` id doesn't pin its destination;
  - a moved page's own links aren't listed;
  - the spec's `[assumed]` tag;
  - `born`;
  - "survey moves it to" wording;
  - the remap hook passing a row that removes a page's company;
  - a revived approval;
  - a held-back approval against a fold;
  - a doubled /jig:update when every finding is approved.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap (a new page starts from .jig/docs-page.md), or no page needed because jig.py is the product's code, which no docs page covers; its behaviour here is stated in RULES.md (Documentation: The findings record) and in the update, redocument and survey skills, all updated in this change

## Shared files changed
- `plugin/templates/jig/jig.py`:
  - `findings` in `BOARD_OPTIONAL`.
  - Ids and outcomes: `FINDING_KINDS`, `LEVEL_KINDS`, `is_finding`, `entry_problem`, `findings_record`, `tagged`, `state_tag`, `file_findings`, `level_findings`.
  - The remap reader: `remap_rows`, `remap_end`, `remap_contradictions`.
  - Carry-out: `approved_moves`, `settle`, `move_entries`, `carry_out`, `move_lines` and `para_pointers`, extracted from `home_findings`.
  - Survey's tags, `exceptions_unused`, `findings_not_counted`, `level_findings`, `remap_contradictions` and its routed last line.
  - Update's tags and carry-out.
  - The remap refusal in `check_rules`.
  - `kind: "shape"` in `page_shapes`.
- `plugin/templates/jig/RULES.md`: the board key list (merged with main's `derived_files`), the naming sentence, "The findings record", and the command line.
- `plugin/skills/update/SKILL.md`, `plugin/skills/redocument/SKILL.md`, `plugin/skills/survey/SKILL.md`: one recorded answer per finding; redocument steps 1, 2, 5 and 6; the survey states.
- `tests/smoke.sh`: a new section, `sec_findings`, appended before `UNITS`, with `findings` added to `UNITS` beside main's `merge_derived`. Two existing cases changed:
  - house, a clean repo: the page is flat and named, since a page alone in its folder is now a counted finding;
  - house, in place: it also asserts that the last line names /jig:update once.
- `.jig/specs/findings-record.md`: Design, Done-when, Alternatives considered and Decisions amended for the owner's 2026-11-13 redesign.
- `.jig/ledgers/DEFERRED.md`: ten rows.

## Test by hand
In a scratch repo on jig, put two pages alone in their folders (`docs/a/b/b.md`, `docs/a/c/c.md`) beside `docs/a/a.md`.
- `jig survey` tags both `not answered`, and its last line counts them.
- On trunk, commit `findings` = `{"shape:docs/a/b/b.md": "approved", "shape:docs/a/c/c.md": "exception: <reason>"}`.
- `python3 <plugin>/templates/jig/jig.py update` (dry run) lists the move under "In .jig/config.json findings, done by --apply". `--apply` stages `docs/a/b/b.md → docs/a/b.md` and drops b's entry.
- Commit `.jig/redocument.md` with a row keeping c `same`: it passes, because the exception is recorded. Delete the exception: the next such commit is refused, naming c, `docs/a/c.md` and `findings`.

## Left
Nothing on this spec. The ten DEFERRED rows are for a later job. `marketing/FEATURES.md`'s row is the hubnode's (main checkout).
