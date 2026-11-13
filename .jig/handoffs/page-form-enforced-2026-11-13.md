# Handoff: page-form-enforced

Commit: 949ee5527494d1280550af4579adc6c5e6e504ca
Date: 2026-11-13
Spec: .jig/specs/page-form-enforced.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
- The hook, `jig check` and `jig merge`'s merge commit refuse a change that puts a page in the wrong one of its two forms: a page added or moved into it, a first other file added to a flat page's folder, or a folder page's last other file removed, without the move. The refusal is `<path>: <shape_fix>`, survey's and update's own line.
- `page_form_rules` judges `page_shapes()` on the base and on the change, with survey's skips (no home, sections, unnamed pages, an `exception:` in findings), and refuses only entries the base lacks. Pages already in the wrong form stay survey's.
- Cost follows the change: only the pages it can reform are judged (`form_candidates`), with no `naming()`, page texts read in one `git cat-file --batch` per side, and `page_cover` indexing the docmap once. One-page edit in a 1655-file tree: 0.73s.
- jig's own fixes land right: `page_home` puts a lone page flat, and update's move and fold lines carry the form move they cause (`reforms`). `jig merge`'s hint says to abort and fix a job's own change on its branch.
- RULES.md, Documentation, states the refusal.

## Done-when evidence
- Smoke `homes`, lone `docs/a/b/b.md` refused by the hook and `jig check --staged`, naming `docs/a/b.md`; flat `docs/a/b.md` commits: `PASS  form: a lone docs/a/b/b.md is refused …`, `PASS  form: the same page added flat at docs/a/b.md commits`.
- First file in flat `docs/a/c.md`'s folder refused, naming `docs/a/c/c.md`; with the `git mv` it passes: `PASS  form: a first file in flat docs/a/c.md's folder is refused …`, `PASS  form: the same file with the git mv into its folder commits`.
- Removing `docs/a/d/`'s last other file refused, naming `docs/a/d.md`; flattening in the same commit passes: `PASS  form: removing docs/a/d/'s last other file is refused …`, `PASS  form: the same removal with the page moved flat commits`.
- A lone page already on trunk commits on a text edit and a `src/`-only change, and survey still lists it: `PASS  form: a lone page already on trunk commits …` (3 lines).
- An unnamed lone folder page isn't refused and survey says "name it in docmap": `PASS  form: a lone unnamed folder page isn't refused …` (2 lines).
- `jig merge` of a job that slipped a lone page in with `--no-verify` stops and commits no merge: `PASS  form: jig merge of a job that slipped a lone page in stops …`.
- The refusal holds survey's `shape_fix` line: `PASS  form: the refusal holds survey's line for the same page`.
- RULES.md Documentation states the refusal (page-folder paragraph). FEATURES.md's Flat pages and Subsystems rows: done by the hubnode in main's copy.
- `bash tests/smoke.sh` on 949ee55: exit 0, 1192 PASS, 0 FAIL. `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: exit 0. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing.

## Review
- Round 1 (400109a), blocking: cost grew with the whole repo (3m38s on a 1655-file tree). Fixed: only candidate pages are judged, no naming, batched reads, docmap indexed (27b9c85).
- Round 1, should-fix: sec_hardware's `tmpl` fixture was silently refused; jig's own `page_home` and fold lines landed pages in the wrong form; a recorded `exception:` didn't stop the refusal. Fixed, with smoke lines; two more silently refused fixtures (flat's "b has a file", page_contract's pages) found by grepping the log and switched to hooks off.
- Round 1, cheap: `guarded` reused, RULES.md paragraph rewrapped, `jig merge`'s hint names the abort and the branch. Done.
- Round 1, deferred: a dangling link counting as company; an ignored `datasheets/` read for both sides. Rows in DEFERRED.md.
- Round 2 (27b9c85), should-fix: `reforms` drafted moves for pages already wrong; pages under an added page weren't candidates; `jig check` from a subfolder passed falsely. Fixed with a smoke line each (87662c4).
- Round 2, deferred: `page_cover`'s index changes `covered` for `docs/a/a/a.md`; `page_home`'s lone test counts tracked files only. Rows in DEFERRED.md.
- The review is recorded on 949ee55 by the hubnode.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation: the page-folder paragraph states the refusal).

## Shared files changed
- `plugin/templates/jig/jig.py` (shares): the new check (`page_form_rules`, `form_entries`, `form_candidates`, `cat_files`), ONLY filters on `doc_homes`, `page_shapes` and `page_levels`, the docmap index in `page_cover`, `page_home`'s lone landing, `reforms` in `move_lines`, and `jig merge`'s hint.
- `plugin/templates/jig/RULES.md` (shares): one sentence in Documentation.
- `tests/smoke.sh` (shares): the `form:` cases in `sec_homes`; fixtures that plant a wrong form on purpose commit with hooks off (homes, flat, structure, findings, hardware, page_contract); the board-gate devkit page gets a schematic.
- `.jig/ledgers/DEFERRED.md` (common): four rows for deferred review findings.

## Test by hand
- In a repo on this jig: `mkdir -p docs/x/y && cp docs/<a page>.md docs/x/y/y.md`, name it in docmap, `git add -A && git commit`: the hook refuses with "docs/x/y/y.md: flat at docs/x/y.md: its folder holds nothing else", the same words `jig survey` prints. `git mv` it to `docs/x/y.md` and the commit passes.

## Left
- Nothing on this spec. Pages already in the wrong form (issue 2 of the report) and a repo's own docs test (issue 1) belong to other groups.
