# page-form-enforced

Source: jig hubnode side session (Daisy survey), 2026-11-12, raised by the owner (staged as feedback-Daisy-2026-11-12-update-leaves-old-contract-enforcers.md): pages in the wrong form commit and merge without a word.

Issue 3 of that report. Issues 1, 2 and 4 belong to other groups.

## Intent
A change that puts a page in the wrong form is refused when it is committed and when it is
merged, with survey's own line for that page. Pages already in the wrong form keep committing,
as they do today.

## Why
1. Q: Why do pages in the wrong form commit and merge without a word?
   A: The hooks and the merge commit run `check_rules`, which never reads page form. Only survey
   and update call `page_shapes()`.
2. Q: Why was form left to survey?
   A: docs-subsystems (Nov 8) made every doc home report-only, "never refused". flat-pages (Nov 10)
   added the form rule under that line and never weighed a hook.
3. Q: Why doesn't report-only fit form the way it fits depth?
   A: Depth's fix needs `deep_subsystems`, which only trunk can add (R5). Form's fix is a `git mv`
   any branch can make, in the change RULES.md names.

Stopped at 3, the root: a rule that names its change and has no holder in that change.

## Givens
- `[seen]` Reproduced here, in a fresh repo set up from this checkout's `plugin/templates/jig`. Its
  `jig.py` blob is the report's `jig_version` (`1a8efef0e75c`).
  - `docs/net/net.md` (with `## Invariants`), alone in `docs/net/`: `jig check --staged` prints
    `ok`, `jig hook pre-commit` exits 0, and the commit lands. Survey then lists
    `docs/net/net.md: flat at docs/net.md: its folder holds nothing else`.
  - Flat `docs/app.md`, plus a new `docs/app/wiring.png` that it links: `ok`, exit 0, committed.
    Survey: `docs/app.md: has a folder of its own name, docs/app/: move it to docs/app/app.md`.
  - A branch that adds a lone `docs/db/db.md`, merged into main with `git merge --no-ff`: the
    pre-merge-commit hook passes and the merge lands.
  - A commit that changes only `src/` prints `ok` with all three pages in the wrong form.
  - `docs/guide/guide.md` with no docmap key and no Invariants is listed with "name it in docmap,
    or it reads as a note there". Its fix is a docmap key, which is trunk's, not a move.
- `[seen]` `page_shapes()` is called only from survey (jig.py ~2619) and update (~7330).
  `check_rules` (~334), `cmd_hook` (~736) and `cmd_gate` (~1573) never call it.
- `[seen]` `jig merge` runs `git merge --no-commit` and then `git commit` (~1049, ~1100). `base()`
  returns HEAD there, trunk's tip, so the merge commit's `check_rules` sees the job's whole diff
  against trunk.
- `[seen]` RULES.md, Documentation: a page is flat "until it holds more than itself … then it
  moves into a folder named for it … in the change that adds the first of them". The rule is
  binary: one other file is enough. It names the change that must make the move. "A branch grows
  the folder with a `git mv` alone": docmap and `boards` keys name a page in either form.
- `[seen]` `.jig/specs/docs-subsystems.md`, Alternatives considered: "Refuse a too-deep page in
  the commit hook or at the gate: rejected because every other doc home is reported by survey
  and proposed by update, never refused. A hook would make this the one doc-home rule that
  blocks work". `marketing/FEATURES.md`'s Subsystems row repeats it under "not": "A hook refusal
  — survey reports and update proposes, like every doc home."
- `[seen]` `.jig/specs/flat-pages.md` never weighs a refusal. Its Design says "Survey reports"
  both forms. On growing a folder it says "RULES.md says so; the fold-in asks as for any page".
  Out of scope: "Moving any repo's pages: survey and update list, the repo moves on its owner's
  yes." None of its alternatives names a hook.
- `[seen]` `.jig/specs/flatten-hardware.md` leaves one thing report-only, the page contract: "Gate-refusing a board page off the page contract
  (survey reports it)". Its Decisions say: "The board rule becomes enforced, not just stated: a
  rule text with no holder was the docs disease in jig's own RULES.md".
- `[seen]` `.jig/specs/rename-check-rules.md` says nothing about page form. It isn't built yet
  (argparse has `check` only, ~8467), so this spec says `jig check`.
- `[seen]` "Never refused" no longer holds. Since `fe115a4` (Nov 11) the hook has refused a
  `roadmap.md` under `docs/` ("a roadmap among the product's pages", `boundary_rules`).
- `[assumed]` The reporter's own run, in a scratch clone of Daisy (`git mv` of a page to flat →
  `ok`). It was reproduced in kind above, not on a Daisy clone. Daisy's `test_docs.py`, which
  enforces the folder form, is issue 1's given and wasn't read here. Nothing below depends on
  either.

## One layer up
- **Sibling, report-only:** depth. A deep page stays survey's, because its fix is a fold or an
  entry in trunk's `deep_subsystems`, which a branch can't add. Form is structurally different:
  its fix is one `git mv` on any branch, with no config edit.
- **Siblings that are enforced:** the hook refuses a `roadmap.md` under `docs/`. The gate refuses
  board-build files that no board page covers (flatten-hardware).
- **The existing pattern:** `boundary_rules` refuses a dangling `(touches …)` with
  `dead_touches(now) - dead_touches(before)`: "Only what this commit breaks is refused." Likewise,
  `added_lines` judges only the lines a change adds, following renames, so an old line in a
  touched page is never refused. The form check takes the same shape: `page_shapes()` over the
  base's tree and over the change's tree, and refuse only what the base doesn't already list.

## Design
- **One judge.** `page_form_rules()` sits beside `boundary_rules` and is called from
  `check_rules`, but only when the change's paths (removed ones included) touch `docs/`.
  - It runs `page_shapes()` twice: once on the base's files, read from the base, and once on the
    change's files, read from the index (or from the working tree without `--staged`).
  - Both runs take trunk's board for the docmap's named pages and for `not_docs`.
  - It refuses each entry in the change's list whose path isn't in the base's list.
  - Each refusal is `<path>: <shape_fix(entry)>` plus the RULES.md pointer. That is the line
    survey and update print for the same page, so all three give one answer.
- **What it refuses**, all of it this change's own doing:
  - a page added or moved into the wrong form;
  - a first file added to a flat page's folder without the page moving in;
  - the last other file removed from a folder page's folder without the page going flat.
- **What it skips:**
  - an entry with `named` false: its fix is a docmap key (R5, trunk's) or page sections, not a move;
  - a page with no home (deep or misplaced, `at_home` false): survey lists those separately, and
    their fix is a fold or the owner's `deep_subsystems` entry.
- **Old pages stay as they are.** Editing a page that is already in the wrong form, or adding to
  its folder, isn't refused, because the base lists the same entry. This matches the reference
  rule, which never refuses an old line in a touched page. Survey keeps listing these pages.
- **Where it holds:**
  - every commit (pre-commit and pre-merge-commit);
  - `jig merge`'s merge commit, which compares the job's whole diff with trunk. That catches a
    wrong form that a `--no-verify` commit slipped in, or one that two jobs make only together.
- **Cost:** only a change that touches `docs/` pays. Company is still judged over the full file
  list, but the entries can be limited to pages whose path or folder the change touches, so a
  commit's cost doesn't grow with the docs tree.
- **RULES.md** (Documentation): add one sentence after the page-folder paragraph's survey
  sentence. The hook refuses a change that puts a page in the wrong one of its two forms (it adds
  or moves a page there, or adds a page's first file, or removes its last, without the move),
  and names the move. A page already in the wrong form is survey's, and a change that leaves it
  there isn't refused.

## Done when
- [ ] Smoke `homes`: in a repo with `docs/a/a.md`, a commit that adds `docs/a/b/b.md` (with
  Invariants) alone in `docs/a/b/` is refused by the hook and by `jig check --staged`. The
  refusal names `docs/a/b.md`. The same page added at `docs/a/b.md` commits. (This is the
  report's "commit … without a word" gone.)
- [ ] Smoke: with `docs/a/c.md` flat, a commit that adds `docs/a/c/x.png` is refused and names
  `docs/a/c/c.md`. The same commit plus `git mv docs/a/c.md docs/a/c/c.md` passes.
- [ ] Smoke: with `docs/a/d/d.md` and `docs/a/d/wiring.pdf`, a commit that deletes the PDF is
  refused and names `docs/a/d.md`. Moving the page flat in the same commit makes it pass.
- [ ] Smoke: take a lone folder page already on trunk (committed with `--no-verify`). A commit
  that edits its text passes, and so does one that changes only `src/`. Survey still lists the
  page. (Untouched old pages commit as today.)
- [ ] Smoke: a lone folder page with no docmap key and no Invariants isn't refused. Survey lists
  it as today, with "name it in docmap".
- [ ] Smoke: take a job whose branch adds a lone folder page with `--no-verify`. `jig merge`
  stops with the hook's refusal and commits no merge. (This is the report's "merge without a
  word" gone.)
- [ ] Smoke: for the same page, the refusal's text holds survey's line (`shape_fix`).
- [ ] RULES.md Documentation states the refusal. In `marketing/FEATURES.md`, the Flat pages row
  says it (what and why), and the Subsystems row's "not" names depth alone.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Pages already in the wrong form: moving them on a yes, recording a deferral, and refusing a
  remap row that contradicts survey. That is issue 2 of the same report, another group's. This
  spec stops new ones only.
- Depth. A deep page stays report-only, because a branch can't add `deep_subsystems` (R5).
- A count threshold other than "more than itself". See the open question.
- A repo's own docs test that enforces the folder form (issue 1, another group's). Until that
  test converts, a new lone page in such a repo can't satisfy both: jig refuses the folder form,
  and the repo's test fails the flat one. The conflict shows at the first such commit instead of
  never.

## Touches
- `plugin/templates/jig/jig.py`: `check_rules` gets one call; `page_form_rules` is new, beside
  `boundary_rules`; `page_shapes` gets an entry filter, if the cost line needs one.
- `plugin/templates/jig/RULES.md`: Documentation, the page-folder paragraph.
- `tests/smoke.sh`: `sec_homes`.
- `marketing/FEATURES.md` (main checkout only): the Flat pages and Subsystems rows.

## Alternatives considered
- Refuse any change that touches a page already in the wrong form (the report's gate line, "a
  page it touched") — rejected because then every edit of an old page carries a move, unlike the
  reference rule, which leaves an old line in a touched page alone. Old pages converge through
  issue 2's recorded moves instead — reason is [seen: `added_lines`, `boundary_rules`].
- A separate gate refusal — rejected because `jig merge`'s merge commit already runs
  `check_rules` over the job's whole diff against trunk, so a gate check would be a second copy
  of one check — reason is [seen: `cmd_merge`, `base()`].
- Keep form report-only, as docs-subsystems chose for doc homes — rejected for three reasons:
  the owner asked for enforcement; that line's premise, "never refused", stopped holding at
  `fe115a4`; and unlike depth, form's fix needs no trunk-only edit — reason is [seen: the report;
  `fe115a4`; RULES.md "a `git mv` alone"].
- A form check of the hook's own instead of `page_shapes()` — rejected because survey, update and
  the hook would then judge form in two places and could disagree, against the owner's "one
  answer" — reason is [seen: the report's goal line].
- Refuse an unnamed lone folder page too — rejected because its fix is a docmap key or page
  sections, not a move a branch can make — reason is [seen: `shape_fix`'s "name it in docmap";
  R5].

## Decisions
- The refusal reuses `page_shapes()` and `shape_fix()`, so the hook, survey and update never
  disagree on a page's form.
- Base and change are compared by entry path. A page moved from one wrong form to another is a
  new entry, so it is refused.

## Open question (owner)
- The owner described the folder logic as "by complexity (count)". RULES.md's line is binary: a
  page gets a folder once it holds one other file. In `.jig/specs/flat-pages.md` the owner gave
  that line as a count on Nov 10: "the line is at containing the contents that necessitate a
  folder (more than 1 file)". Is that the count meant, or a higher one, where a page gets a
  folder only once it holds N files?
  - This spec builds the rule as RULES.md states it.
  - A higher N changes RULES.md's sentence, `company()` in `page_shapes`, and the smoke cases.
    The hook follows with no change of its own.
  - The report asks for this answer before either the hook or the gate refusal is written, so
    execute after the owner answers.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
