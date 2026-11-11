# bug-seam-ownerless-folder

Source: owner, Nov 11, from a maige-lite session's survey: five pages in `docs/systems/` and
`docs/hardware/` were listed under "Pages in one system's folder that cover another's files",
read "as subsystems of systems called 'systems' and 'hardware'".

## Intent
Survey calls a page a seam filed under one system only when that system has a page. A page in a
folder no page owns is misplaced, and survey already lists it once, with where it goes.

## Why
- Why was `docs/systems/old.md` listed as a seam? `misfiled_seams` reads its system from path
  depth alone: anything at `docs/<x>/<y>` sits in system `docs/<x>`.
- Why is that wrong? `docs/systems/` has no page, so it isn't a system. The page is in the wrong
  place, and survey's "Pages not in their home" section already says so (`→ docs/old.md`).
- Why does it matter? The repeat is noise, and it names the wrong problem. A session reading it
  went looking for a seam that the page's misplacement explains.

## Givens
- `[seen]` Repro in a throwaway repo, with flat `docs/walyt.md` and `docs/gesture.md`, a
  folder-form `docs/memory/memory.md`, and `docs/systems/old.md`, all with docmap globs over
  `src/drv/bma.c`. Survey lists `docs/systems/old.md` under the move section
  (`→ docs/old.md`) and again under the seam section (`also docs/walyt.md's`). The three
  top-level pages aren't flagged.
- `[seen]` `misfiled_seams` (jig.py ~2217) keeps a page when `page_folder(p).count("/") >= n + 1`
  and takes its system as the first `n + 1` path parts. It never checks that a page owns that
  folder.
- `[seen]` `owner_page` and `pages_above` (~1995, ~2007) find the page above through
  `folder_owner`, which accepts either form of the page (`d/<name>.md` or `d.md`) and returns
  nothing for a folder that has no page.

## One layer up
The reading list's climb (`owner_page`) does the same job, "which system is this page under",
and doesn't have this problem, because it asks `folder_owner`. The seam check is the odd path out.

## Design
- In `misfiled_seams`, a page is under a system only when `folder_owner(<its system folder>,
  have)` returns a page. If nothing owns the folder, skip the page: doc_homes already reports it.
- `tops` stays as it is (the top-level pages, in either form).
- Amended after review (Nov 11): doc_homes reported only the flat form. `at_home` accepts any
  folder-form page within depth, so `docs/systems/old/old.md` was at home and, once the seam
  check skips it, reported nowhere. A folder-form page below `docs/<x>` is at home only when a
  page owns the folder above it, the test the flat form already passes through `owner_page`.
  Survey then lists it as a page to move.

This is a correction: the seam check uses the same test for "has a system above it" as the
reading list does.

## Done when
- [ ] Smoke: the repro layout above. Survey lists `docs/systems/old.md` once, under the move
  section, and the seam section doesn't name it (the reported symptom gone).
- [ ] Smoke: the folder form, `docs/systems/old/old.md` with no page owning `docs/systems/`, is
  listed once, as a page to move, and not as a seam.
- [ ] Smoke: the existing seam case still fires. A page in `docs/a/` whose system page is
  `docs/a.md` (flat) or `docs/a/a.md`, covering a file that `docs/b.md` also covers, is listed
  as a seam in both forms.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Overlapping docmaps between top-level pages. RULES.md allows them, and each page that covers
  a file is asked at fold-in.
- Survey's wording for a misplaced page.

## Touches
- `plugin/templates/jig/jig.py` (`misfiled_seams`, `at_home`)
- `tests/smoke.sh`

## Alternatives considered
- Drop the seam line only when the same page is already in the move list. Rejected: it couples
  two report sections, and the seam claim would still be false for an ownerless folder that
  survey misses for some other reason. Reason is [assumed].
- Leave it, since the remap moves those pages anyway. Rejected: it misled a session in a live
  repo. Reason is [seen: the owner's paste].

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
