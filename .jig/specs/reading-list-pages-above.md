# reading-list-pages-above

Source: Maige-OS hubnode session, 2026-11-10, Dave Seeman (with Claude) (staged as feedback-Maige-OS-2026-11-10-redocument-non-jig-docs.md): The reading list gives a part page without its system page.

## Intent
`jig reading-list` prints, after each page that covers a file, the pages above that page in
the docs tree, so whoever edits a subsystem's file also reads its system's page. Fold-in is
unchanged.

## Why
RULES.md puts a fact that spans several files once, on the system page, and has a
subsystem's page name only its own files in `docmap`, so fold-in doesn't ask the system page
about every subsystem change. The reading list reads that same map, so it can never hand the
system page to someone about to edit a subsystem file. Any repo with a subsystem has this gap.

## Givens
- `[seen]` Scratch repo, `docs/a/a.md` (globs `src/a/lib.rs`), `docs/a/b/b.md` (globs
  `src/a/b.rs`): `jig reading-list src/a/b.rs` prints `AGENTS.md`, `.jig/RULES.md` and
  `docs/a/b/b.md` only.
- `[seen]` `cmd_reading_list` (`jig.py` ~1315) prints `doc_owners` only. `owner_page` (~1704)
  finds the page whose folder a path sits in; it honours `deep_subsystems` and skips `datasheets/`.
- `[seen]` RULES.md, Documentation: "a subsystem's page names its own files and its system's
  page names the rest", and "a rule that touches several files lives once".
- `[seen]` Same repo, a handoff for a branch changing only `src/a/b.rs`: one fold-in line,
  `docs/a/b/b.md`.
- `[seen]` A 12-line prototype of the design below, in the scratch repo's copy: prints
  `docs/a/a.md` after `docs/a/b/b.md`; with `deep_subsystems` approving `docs/a/b/c`, prints
  `docs/a/b/b.md` and `docs/a/a.md` after `docs/a/b/c/c.md`.
- `[seen]` Only the spec skill (step 5) uses the output. Nothing parses it.
- `[assumed]` Reading the system page is worth its context cost on every subsystem edit.
  Inferred from RULES.md, not measured.

## Design
In `cmd_reading_list`, after each covering page, add the page of each folder above it, once
each, by walking `owner_page` up. Start from the page's own folder for a page named for its
folder, and from the file itself for any other `docmap` key. A page listed only because it is
above another is printed as `<page>   (parent of <covering page>)`, once. A page that also
covers a named file is printed without the note. RULES.md's reading-list sentence (the seam
paragraph) and its Commands line say it lists the pages above too.

## Done when
- [ ] Smoke `homes`: with `docs/a/a.md` covering `src/a/lib.rs` and `docs/a/b/b.md` covering
  `src/a/b.rs`, `jig reading-list src/a/b.rs` prints `docs/a/b/b.md`, then `docs/a/a.md` with
  the note. This is the reported symptom, gone.
- [ ] Smoke `homes`: with `docs/a/b/c` approved in `deep_subsystems` and `docs/a/b/c/c.md`
  covering `src/a/c/**`, `reading-list src/a/c/c.rs` prints c, b and a, each once.
- [ ] Smoke `homes`: `reading-list src/a/lib.rs src/a/b.rs` prints `docs/a/a.md` once, without
  the note.
- [ ] Smoke `homes`: a handoff changing only `src/a/b.rs` has one fold-in line, `docs/a/b/b.md`.
- [ ] `bash tests/smoke.sh` passes (the existing "system page and a board page lists both" case
  included), `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Fold-in, `doc_owners` and `docmap`: still only the covering pages are asked.
- The covering page's sibling subsystems, and the other side of a seam.
- Flat part pages (issue 2 in the same report): dropped. This walk works the same for either
  shape.

## Touches
- `plugin/templates/jig/jig.py`: `cmd_reading_list`
- `plugin/templates/jig/RULES.md`: Documentation (the seam paragraph's reading-list sentence), Commands
- `tests/smoke.sh`: `sec_homes`, after the `deep_subsystems` approval (~3015)
- `marketing/FEATURES.md`: the `reading-list` row (main checkout only)

## Alternatives considered
- Map the file to both pages in `docmap` — rejected because fold-in would then ask the system
  page on every subsystem change, which RULES.md's docmap paragraph rules out — reason is [seen]
- A line in the spec skill telling the agent to read the parent page — rejected because the
  reading list is the one mechanical answer, and the skill line reaches only agents that load
  that skill — reason is [assumed]
- List the whole system: the parent and its other subsystems — rejected because a subsystem's
  page exists so its siblings aren't loaded — reason is [seen] (RULES.md, Documentation)

## Decisions
- Walk all the way up, not one level: under an approved `deep_subsystems` level, a system-wide
  fact sits two pages up. Without one, the chain is at most one page.
- The note says why a page is listed when its globs don't cover the file.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
