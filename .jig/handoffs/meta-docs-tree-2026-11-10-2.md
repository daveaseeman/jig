# Handoff: meta-docs-tree

Commit: 13faae30e65eb05bea8a3e684e6506ba10859ae3
Date: 2026-11-10
Spec: .jig/specs/meta-docs-tree.md
Review: tier 2, effort 2
Ran: sync of main into meta-docs-tree at 13faae3: one tests/smoke.sh conflict, main's sec_decisions kept whole and UNITS lists meta_docs and decisions; review of 364105a carries. Hubnode checked the resolution (no markers, smoke.sh parses); subnode's full smoke 868 PASS / 0 FAIL.

## Built
A metarepo's pages live in `docs/<genre>/<name>.md` (flat until they hold more), a genre being a
folder under `docs/` with no page and no depth. `meta.json` gains optional `genres`; `jig init --meta
--genres product-ecosystem|a,b` writes it, adds `docs/**/*.md` to `entry_files`, and seeds a
`### <genre>` heading per genre under `README.md § Glossary`. Survey finds every metarepo page
outside `docs/<genre>/` whatever its shape (only root docs and registers stay), names pages in
`docs/` with no genre or an undeclared one, names `not_docs` globs hiding pages, and routes to
`/jig:redocument`; `entry_files` no longer makes a home. Update proposes `genres` (and the glob).
The init skill asks for genres with two templates; redocument gains Cited-by, the `not_docs` drop and the
`entry_files` rewrite at cleanup. A code repo's tree is unchanged.

## Done-when evidence
- Smoke `meta_docs` (17 cases): `products/hardware/x.md` → `docs/products/x.md`, last line names /jig:redocument; DECISIONS.md, CHANGELOG.md, README.md not listed — PASS.
- `docs/products/w.md` with a lead passes, no `docs/products/products.md`; `docs/y.md` "needs a genre" — PASS.
- Code repo: `docs/products/x.md` beside `docs/products.md` is at home, no genre wording — PASS.
- `--genres product-ecosystem` writes the four genres and four `###` headings; `--genres a,b` those two; `docs/misc/z.md` "is no genre" — PASS.
- init SKILL asks for genres with the two templates; RULES.md Homes no longer has "what `entry_files` names"; redocument SKILL has Cited-by and the `entry_files` rewrite.
- `bash tests/smoke.sh` after the sync at 13faae3: 868 PASS / 0 FAIL, rc 0 (side-session-notes meta-docs-tree-smoke-5.out; 833 / 0 at 364105a); `claude plugin validate ./plugin`: ✔ Validation passed; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: no output.

## Review
- B1 folder-named pages outside docs/ at home — fixed: outside docs/ only root docs and registers are at home; smoke case.
- B2 not_docs hid the pages silently — fixed: survey names each hiding glob and routes to redocument; redocument drops them first; smoke case.
- S1 GLOSSARY.md sent to a genre — fixed: glossary check first; smoke case.
- S2 entry_files missed docs/ pages — fixed: `--genres` adds `docs/**/*.md`, update proposes it; smoke cases.
- O1 genres only loaded in doc_homes — fixed: loaded in main; misfiled_seams reads docs/<genre>/<page> as the system.
- O2 Doc homes line printed the code tree — fixed; smoke case.
- Wording (not blocking): `GLOSSARY.md` in a not_docs glob counts as "hides 1 page" — left as is: any change after 364105a would void the recorded review.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Homes; Metarepo and pararepos), updated here, plus the init and redocument skills.

## Shared files changed
- `plugin/templates/jig/jig.py`: genre helpers before `folder_page`, one-line gates in the tree helpers, doc_homes' metarepo branch, survey's genre/not_docs prints, update's proposal, `init --genres`, `load_genres` in main.
- `plugin/templates/jig/RULES.md`: the Homes bullet; a "metarepo's docs tree" paragraph in Metarepo and pararepos.
- `plugin/skills/redocument/SKILL.md`: metarepo paragraph in step 1, one line after the table, one cleanup bullet.
- `tests/smoke.sh`: `sec_meta_docs` before `SLOW=`, `meta_docs` in UNITS.
- Sync with main (13faae3): only `tests/smoke.sh` conflicted, on UNITS; main's `sec_decisions` kept whole, UNITS carries `meta_docs` and `decisions`.

## Test by hand
In a fresh repo, `/jig:init` for a metarepo: it should ask for genres and offer product ecosystem or custom. Then run `jig survey` on a metarepo with pages at the root and in content folders, and read where it sends each page.

## Left
Nothing in the spec. Follow-ups: the GLOSSARY.md "hides 1 page" wording, and the FEATURES.md row (the hubnode's).
