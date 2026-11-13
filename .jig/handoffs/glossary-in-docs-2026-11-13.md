# Handoff: glossary-in-docs

Commit: 128a1526ea4583f3f46a674b141a19319cff0319
Date: 2026-11-13
Spec: .jig/specs/glossary-in-docs.md
Review: tier 2, effort 2

## Built
A repo's glossary is `docs/glossary.md`, in one of two forms: `## <term>` headings, or a table
whose first column is the term. jig's readers take both forms. The file is at home in any repo,
including directly in a metarepo's `docs/`, and the page contract doesn't apply to it.

- **The move.** `jig update` lists a README `## Glossary` section, or a root `GLOSSARY.md`, under
  Repo files to review. `jig update [--apply] --glossary` moves it in its own form: `###` headings
  become `##`, a bold-paragraph term gets a heading, and a table moves unchanged. The same change
  rewrites every pointer to the old home. The dry run lists:
  - each rewrite;
  - each pointer it can't rewrite;
  - each line the hook would refuse in the move's commit ("edit before committing");
  - each pointer in history, left as written: fenced code, handoffs, and released log or
    changelog sections.
- **The hook** refuses an added line in a page (outside `not_docs`) or in `.jig/decisions.md`
  that names a root document as a path. A Markdown link resolves from its page's folder. Survey
  lists prose mentions, but not released log lines.
- **Metarepo.**
  - `init --meta` seeds `docs/glossary.md` with genre headings, and `entry_files` names it
    instead of README.md.
  - M3 keeps the README exception only while `entry_files` still lists README.md.
  - The move runs off trunk (M4) and rewrites `entry_files` in the same change.
  - The release term report reads either home and reports moved terms as moved, whatever
    their form.
  - The pin-bump report names `<meta>/README.md § term` with its new home.
- **Words.** RULES.md, `docs-page.md`, the init, update and retro skills, and jig's README say
  `docs/glossary.md`.

## Done-when evidence
Every case below ran in `bash tests/smoke.sh` at 128a152's code: exit 0, 1226 PASS, 0 FAIL. The
output is in the session notes folder as `glossary-in-docs-smoke-2.out`.
- [x] README glossary listed, then moved with `##` headings, byte for byte, section removed:
  PASS "glossary: update lists a README glossary under Repo files to review, bound for
  docs/glossary.md" and PASS "glossary: --apply --glossary writes each ### term as a ## heading,
  its text byte for byte, and removes the README section".
- [x] Root `GLOSSARY.md`: PASS "glossary: a root GLOSSARY.md folds into docs/glossary.md, a bold
  term gaining a heading, its text unchanged".
- [x] Table form: PASS "glossary: a README glossary written as a table moves as the same table,
  rows byte for byte".
- [x] Pointers rewritten, dry run first, `§ gone` left, `entry_files` rewritten in a metarepo:
  PASS "glossary: the dry run lists both pointer lines it rewrites, lists README.md § gone as
  left, and changes nothing", PASS "glossary: and rewrites README.md § mote to docs/glossary.md
  § mote and the GLOSSARY.md link, leaving README.md § gone", and PASS "glossary meta: on a
  branch the move rewrites entry_files in the same change".
- [x] Already on a table `docs/glossary.md`: PASS "glossary: a repo on a table docs/glossary.md
  gets no glossary finding from survey, and the readers list its first column" and PASS
  "glossary: nor from update, whose --glossary has nothing to move".
- [x] Hook: PASS "glossary hook: an added page line naming README.md § x is refused, naming the
  line", PASS "glossary hook: so is one naming AGENTS.md, and one in the decision log", and PASS
  "glossary hook: a page line naming docs/glossary.md § mote, or another repo's README, passes".
- [x] Survey in a metarepo: PASS "glossary meta: survey doesn't hold docs/glossary.md to the page
  contract or call it a stray in docs/, and names a bold term in it".
- [x] `init --meta`: PASS "glossary meta: init --meta seeds docs/glossary.md with a ## heading
  per genre, and entry_files has no README.md".
- [x] M3: PASS "glossary meta: a README prose change needs no log line", PASS "glossary meta: a
  glossary term change does", and PASS "glossary meta: and passes with its log line".
- [x] Release across the move, and the pin bump: PASS "glossary meta: a release across the move
  reports each term as moved, a bold-paragraph one too, not removed or added" and PASS
  "glossary meta: at the pin bump, the pararepo's go/README.md § mote is named with its new
  home".
- [x] `grep -rn "README.md § Glossary" plugin README.md` finds nothing.
- [x] Smoke and validator pass, examples generic:
  - `bash tests/smoke.sh` exits 0;
  - `claude plugin validate ./plugin` prints "✔ Validation passed";
  - `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing;
  - `.jig/scripts/check.sh` and `tests/redocument-fixture.sh` exit 0.

## Review
The hubnode's fresh review of 5e7668c, at tier 2 and effort 2, had nine findings, none blocking.
All nine were taken in 128a152, so no DEFERRED rows.
1. **The move's own commit could be refused by the hook:** a rewritten line could still hold a
   second root-document pointer, or a term's text could name CHANGELOG.md or AGENTS.md. Fixed:
   the plan checks every line the commit adds to a page or the log with the hook's own
   predicate, and lists each hit as "edit before committing". Smoke: PASS "glossary: the dry run
   lists, as edit before committing, a rewritten line still naming README.md and a term naming
   CHANGELOG.md" and PASS "glossary: the move's commit is refused until the listed lines are
   edited, then passes".
2. **A link-only README Glossary section gave a finding that never cleared.** Fixed:
   `readme_glossary` counts a section only when it holds terms (headings, bold terms or table
   rows). Smoke: PASS "glossary: a README Glossary section holding only a link to
   docs/glossary.md gets no finding".
3. **A link in a table's first cell was read as the whole link.** Fixed: `term_text` unwraps a
   Markdown link to its text, for table cells and glossary headings. Smoke: PASS "glossary: a
   table term written as a link reads as its text, and docs/glossary.md § vat resolves".
4. **The root-document rule ignored `not_docs`.** Fixed: `boundary_rules` takes the board's
   `not_docs` and skips matching files. Smoke: PASS "glossary hook: a page under a not_docs glob
   may name README.md".
5. **Rewriting touched history.** Fixed: `history_lines` skips fenced code, released sections of
   the log and of a root CHANGELOG.md, and `.jig/handoffs/`. Each skipped pointer is listed under
   "Pointers in history, left as written". Smoke: PASS "glossary: and lists the fenced block, the
   handoff and the released changelog line as history" and PASS "glossary: --apply leaves the
   fenced block, the handoff and the released line as written, and rewrites the unreleased one".
6. **Survey listed released log lines.** Fixed: `root_doc_mentions` skips released lines. Smoke:
   PASS "glossary: survey leaves out a released decision-log line naming the README".
7. **A bold term that gets a heading in the move was reported as added.** Fixed: `term_blocks`
   reads bold-paragraph terms too, so a term is matched by name in any form. Smoke: the "release
   across the move" case now also asserts `grain (moved: …)` and no `grain:` line.
8. **A page's link to its own folder's README was refused.** Fixed: `root_doc_named` resolves a
   Markdown link from the page's folder, and other paths stay root-relative. Survey uses the same
   predicate for paths. Smoke: PASS "glossary hook: a page's link to its own folder's README.md
   passes" and PASS "glossary hook: and a backticked README.md § y in it is refused: a pointer is
   from the root".
9. **M3 lost the README exception for metarepos that haven't moved yet.** Fixed: the exception
   holds while `entry_files` still lists README.md, comparing `old_glossary` on both sides. Smoke:
   PASS "glossary meta: before the move, a README prose edit needs no log line: only its Glossary
   section is cited" and PASS "glossary meta: and an edit inside its Glossary section still needs
   one".

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation: docs point only at docs, the glossary paragraph; the metarepo's docs tree; entry_files; the M3 row; Commands), with the update, init and retro skills.

## Shared files changed
- `plugin/templates/jig/jig.py`: the glossary readers, doc homes, survey, the hook's boundary
  rule, M3, `init --meta`, the release term report, sync's citation report, and the new
  `update --glossary`.
- `plugin/templates/jig/RULES.md`: the rules the spec changes (Words).
- `plugin/templates/jig/docs-page.md`: one line pointing terms at `docs/glossary.md`, and the
  glossary's exemption.
- `tests/smoke.sh`:
  - about 30 existing cases moved from the README glossary to `docs/glossary.md`;
  - one `sec_homes` setup commit runs with hooks off, since its page predates the rule;
  - the new `sec_glossary` section, added to UNITS.
- `README.md`: jig's own glossary line.
- `plugin/skills/init/SKILL.md`, `plugin/skills/update/SKILL.md`, `plugin/skills/retro/SKILL.md`:
  they name `docs/glossary.md`.
- `tests/redocument-fixture.sh`: not changed. Its metarepo has no README glossary, and it passes
  as is.

## Test by hand
In a repo with a README `## Glossary` and a page citing `README.md § <term>`:
1. Run `jig update --glossary` and read the lists: rewrites, left for the session, history.
2. Run `jig update --apply --glossary`, edit each "edit before committing" line, and commit.
   The hook should pass.
3. In a metarepo, run the same on a job branch, then release. A pararepo's `jig sync` names each
   term as moved, and after the pin bump names its old `<meta>/README.md § term` citations with
   the new path.

## Left
- The hubnode's: the `marketing/FEATURES.md` row (main checkout only), and a changelog line in
  `.jig/decisions.md` for the release.
- jig's own `.jig/` gets these rules only through `/jig:update`. After that, this repo's hook
  refuses new page or log lines naming a root document.
