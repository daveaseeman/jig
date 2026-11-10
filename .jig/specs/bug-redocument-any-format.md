# Bug: redocument refuses pages in any format but Now / Rules / Checks

Source: Maige-OS hubnode session, 2026-11-10, Dave Seeman (with Claude) (staged as feedback-Maige-OS-2026-11-10-redocument-non-jig-docs.md): Redocument refuses a repo whose pages are in any format but Now / Rules / Checks.

## Intent
`/jig:redocument` takes a jig repo's pages to the contract whatever format they are in, as
`.jig/specs/redocument.md` meant it to. Survey knows a page by `docmap` as well as by its
shape, and sends a jig repo with pages to convert to redocument, not to `/jig:adopt`.

## Why
- Why did redocument stop? Its step 2 goes on only for an old-contract page, an old-shaped page outside the docs tree, or an old board file. Survey named none.
- Why none? `old_contract()` needs Now, Rules and Checks. A homeless file is a `page` only with those or Invariants/Undefined; any other is a `stray`.
- Why was the repo stuck? The footer falls back to /jig:adopt, and survey lists the repo's docmap pages as "never read since", though fold-in asks them on every change.

## Givens
- `[seen]` A temp clone of Maige-OS at b57615a (its `.jig/jig.py` is blob b9d48e5, the plugin's
  at v0.9.0): survey finds 61 files with no home. All 44 docmap keys are `stray`, and 28 of them are under "never read since". `page_contract` is empty. The last line is "Run /jig:adopt …".
- `[seen]` A scratch jig repo with two docmap pages in a house format at `docs/crates/s/`: both
  are listed "never read since", and `jig reading-list` prints one of them. With the same page at
  home, survey reports only "no lead paragraph", and its last line is still /jig:adopt.
- `[seen]` `naming()` skips `config.json`, so a docmap key has no inbound link.
- `[seen]` `/jig:adopt` step 4 says "propose the map, not new pages", so an adopted repo maps its
  pages where they already are, in their own format.
- `[seen]` Survey's footer prints in any repo, and adopt runs survey on repos that are not on jig.
- `[seen]` In a scratch metarepo, survey reads `docs/y/y.md` against the contract. So a wider
  footer reaches a metarepo's `docs/` pages, where Subnode step 1 traces to code that isn't there and leaves off any claim it can't source.
- `[seen]` I tried this design on a throwaway copy of jig.py. On the Maige-OS clone, survey lists the 44 pages under "Pages outside the docs tree" and its last line names /jig:redocument. A repo not on jig, and a jig repo with only a stray, still get /jig:adopt.

## Design
1. `doc_homes()` takes the board's `docmap`. A homeless Markdown file that `docmap` names is a
   `page` wherever it sits, with `to` from `page_home()`. Survey and update both pass the docmap, so they agree.
2. The survey footer, when `.jig/config.json` exists, never names `/jig:adopt`. Redocument is for conversions: if any `page` is outside the docs tree, any page is in the old Now / Rules / Checks shape, or there is an old-layout board file, the last line names `/jig:redocument`. Otherwise, a page at home but off the contract (no lead paragraph, an Invariant with no holder, a section after Undefined) is fixed where it sits: the last line names `/jig:update`, whose Repo files to review lists each such page with its problems and proposes the edit on a yes (owner, Nov 10: "jig update is the right home and it's worth adding"). A repo with no board still gets /jig:adopt, and an older board still gets /jig:update.
3. `/jig:redocument`:
   - Step 2 goes on only when survey's last line names it. Otherwise it says `no page to convert: nothing to redocument`.
   - Step 1 declines all of update's page moves, because the remap places every page.
   - The seed takes every page to convert (outside the docs tree, or in the old shape); a page at home but off the contract is update's, not the remap's.
   - Subnode: each claim of the old page gets exactly one fate. In a metarepo there is no code, so a claim traces to its decision row or to the pararepo file a pointer names. A claim whose only record is the old page is kept as worded and flagged, never left off.
4. RULES.md, Homes: "a page outside its folder" also covers one that `docmap` names.

## Done when
- [ ] Smoke, in a jig repo with `docs/crates/s/{store,lib}.md` (`## Does`, `## Gotchas`), both of
      them docmap keys: survey lists both under "Pages outside the docs tree", neither under "never
      read since", and its last line names /jig:redocument. `jig update` proposes moving them, with their docmap keys.
- [ ] Smoke: a jig repo whose only page is at home with no lead paragraph gets a last line that names /jig:update, and `jig update`'s dry run lists that page, with "no lead paragraph", under Repo files to review. A repo with no board and that same page still gets /jig:adopt. A jig repo with only a stray gets no /jig:adopt line.
- [ ] `bash tests/redocument-fixture.sh`: `start()` reads survey's last line. The clean repo
      refuses with the new string, and the fixture's old pages start.
- [ ] The reported symptom is gone: on a temp clone of Maige-OS at b57615a, the plugin's
      `jig.py survey` lists the 44 docmap pages under "Pages outside the docs tree", and its last line names /jig:redocument.
- [ ] `grep -n 'In a metarepo' plugin/skills/redocument/SKILL.md` shows the tracing line.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- maige-ecosystem's issue 1, a metarepo's pages outside `docs/`: spec `meta-docs-tree` (owner, Nov 10), which runs after this one.
- The remap's Kind column and the `hold` and `dissolve` verbs. They are not part of the refusal,
  Maige-OS already uses them in its own remap on the owner's word, and a second repo should ask for them first.
- A house-format page at home that has a lead paragraph still passes survey. Whether a section name is a genre is a judgment call, not a pattern survey can match.
- Two pages with the same file name get the same suggested home (`docs/lib/lib.md`), as old-shaped
  pages already do. The remap places them.
- A docmap page that sits flat in another page's folder: spec `flat-pages` makes it a page.

## Touches
- plugin/templates/jig/jig.py: `doc_homes`, its two callers, the survey footer, update's Repo files to review (pages off the contract)
- plugin/templates/jig/RULES.md (Homes); plugin/skills/redocument/SKILL.md; plugin/skills/survey/SKILL.md; plugin/skills/update/SKILL.md
- README.md (the redocument line); marketing/FEATURES.md (the redocument row)
- tests/smoke.sh; tests/redocument-fixture.sh

## Alternatives considered
- Widen `old_contract()` to more heading sets — rejected because every house format would need its own entry — reason is [assumed]
- Keep sending these repos to /jig:adopt — rejected because adopt maps pages where they sit and has no tracing or conversion report — reason is [seen] (adopt step 4, redocument skill)
- Send only homeless docmap pages to redocument (the report's done-when) — rejected because
  update would then move them into the tree, after which they count only as "no lead paragraph"
  and redocument would refuse them again — reason is [seen] (scratch repo, page at home)

## Decisions
- Any problem with a page that survey reports sends a jig repo to redocument. A missing lead paragraph is the sign of a page that was never written from the template.
- The skill's refusal reads survey's footer, so the test lives in jig.py only.
- The metarepo tracing rule ships here because the wider footer reaches a metarepo's `docs/` pages. It is the owner's rule from maige-ecosystem's pilot ("Keep and flag"), and it is not a metarepo contract.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
