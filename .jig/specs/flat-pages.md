# flat-pages

Source: Maige-OS hubnode session, 2026-11-10, Dave Seeman (with Claude) (staged as feedback-Maige-OS-2026-11-10-redocument-non-jig-docs.md): "A subsystem page must have a folder of its own" — "A crate with five modules worth a page needs five subfolders holding one file each."

Decided by the owner, Nov 10, overruling the drop: "I like B, the flat part pages more. We should
only create folder pages when there are other files to include … if it was a literal part or
component then it isn't just an .md it might be a step file and a pdf, they all go in a folder
together (so the lowest element is still flat). So the line is at containing the contents that
necessitate a folder (more than 1 file)."

## Intent
A page is a single file until it has company. It sits flat in its parent's folder
(`docs/<system>.md`, `docs/<system>/<part>.md`) and gets a folder of its own, named for it
with the page inside (`docs/<system>/<part>/<part>.md`), only once it has more than itself to
hold: part pages, linked files, a `datasheets/` folder.

## Why
- Why one-file folders? Every page must be `docs/…/<x>/<x>.md` (`folder_page()`), whatever it holds.
- Why is that noise? A crate's five module pages become five folders of one file each; the
  folder carries nothing the path didn't already say.
- Why did jig require it? A folder is how survey tells a page from a note beside it. `docmap`
  (spec `bug-redocument-any-format`) and the page's shape now say that instead.

## Givens
- `[seen]` `folder_page()`, `at_home()`, `page_home()`, `owner_page()` in `jig.py`: a page is
  named for its folder; any other `.md` in a page's folder is one of its files, and one shaped
  like a page is reported as "a subsystem candidate: it gets a folder".
- `[seen]` RULES.md, Homes: "under `docs/`, a page named for its folder"; Documentation: a page's
  folder holds the files it links.
- `[seen]` The investigator's review of Maige-OS's approved remap: 8 module pages once the owner's
  "no tiny pages" rule applied, each a folder of one file under today's rule.

## Design
- **Homes.** A page is flat, `<parent folder>/<name>.md` (`docs/<name>.md` for a system), until
  it holds another file; then it is `<parent folder>/<name>/<name>.md`, its files and part pages
  beside it. "Another file" is a part page, a linked file (a note, a schematic, a step file) or a
  `datasheets/` folder.
- **Page or note.** In a folder that has a page, another `.md` is a flat page when `docmap` (or
  `boards`) names it or it has an Invariants or Undefined section; anything else is one of that page's linked files.
- **Depth counts the page, not its folder.** `docs/a/b.md` is a subsystem, as `docs/a/b/b.md` is;
  `docs/a/b/c.md` is a third level and needs `deep_subsystems` for `docs/a/b/c`, flat or not.
- **Survey reports** a folder page alone in its folder (`docs/a/b/b.md` with nothing beside it:
  "flat at `docs/a/b.md`") and a flat page with a same-named folder (`docs/a/b.md` and
  `docs/a/b/`). A file loose in a folder belongs to that folder's page, so a flat page's own file
  left there can't be told apart; review catches it. `jig update` lists the one-file folders under
  Repo files to review and moves each on a yes, with its `docmap` key.
- **Growing a folder.** When a flat page gains a file, it moves into its folder in that change
  (`git mv`, its `docmap` key, `boards` if it is a board page). RULES.md says so; the fold-in asks
  as for any page.
- `owner_page()` and the reading list's walk-up (spec `reading-list-pages-above`) find a flat
  page's parent as `docs/a/a.md` for `docs/a/b.md`: both count from `page_folder()`, the folder
  a page stands for, `docs/a/b` for either shape.
- **Which flat pages climb.** `pages_above` climbs from a folder page and from any flat page:
  a page filed in a system's folder is that system's, whatever its sections. A seam page lives
  where a datasheet two pages share does, in the nearest folder both systems sit under:
  `docs/<seam>.md` for two systems, flat, with no page above it. Survey doesn't detect a
  misfiled seam (its globs naming "both sides" isn't reliable to read); review catches it.
  Smoke: the guard's seam page moves to `docs/seam-gpio.md` and prints no parent; a
  docmap-named `docs/net/x.md` with no contract sections climbs to `docs/net/net.md`.
- **Migration.** `jig update`'s root `HARDWARE.md` row goes flat, `docs/<board>.md`, since it
  moves alone; into `docs/<board>/<board>.md` only where that page exists already.
- **Wording.** RULES.md Documentation (the opening paragraph, the page-or-note rule, the seam
  paragraph's home, the body
  section's "beside its system's", the page-folder paragraph's survey reports, the board
  paragraph) and Homes (the docs bullet; deep and misplaced pages flat); `jig.py`'s `DOC_HOMES`
  docs line; `/jig:hardware` step 2 (flat when the page holds no file, `<home><board>.md` reads
  as that path); `/jig:adopt`'s homes table (system and board rows); `/jig:redocument` step 2's
  new paths; `/jig:update`'s wrong-shape findings; the AGENTS template's Firmware line.

## Done when
- [ ] Smoke `homes`: `docs/a/a.md` and `docs/a/b.md` (docmap names it, or it has `## Invariants`):
  survey reports neither (the reported symptom gone). `docs/a/notes.md` linked from `a.md` is a
  linked file, not a page.
- [ ] Smoke: `docs/a/b/b.md` alone in its folder is reported "flat at `docs/a/b.md`"; with
  `docs/a/b/wiring.pdf` beside it, it isn't.
- [ ] Smoke: `docs/a/b.md` and `docs/a/b/b.md` together are reported.
- [ ] Smoke: `docs/a/b/c.md` (docmap-named) is deep without a `deep_subsystems` entry for `docs/a/b/c`.
- [ ] Smoke: `jig update` lists `docs/a/b/b.md` under Repo files to review and, on `--apply`,
  leaves it (update never edits repo files unasked).
- [ ] Smoke: `reading-list` for a file `docs/a/c.md` (Invariants) covers prints `docs/a/c.md`, then
  `docs/a/a.md` marked as its parent; a seam page at `docs/seam-gpio.md` prints no parent.
- [ ] RULES.md Homes and Documentation state the rule; `/jig:hardware`, `/jig:adopt`'s homes
  table, `/jig:redocument` and the AGENTS template's Firmware line give a board or part page as
  flat until it holds a file (a board with a spec sheet has `datasheets/`, so a folder).
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Moving any repo's pages: survey and update list, the repo moves on its owner's yes.
- The metarepo's genre folders: spec `meta-docs-tree`, which builds on this.

## Touches
- `plugin/templates/jig/jig.py` (`folder_page`, `at_home`, `page_home`, `owner_page`,
  `unapproved`, `doc_homes`, survey, update's repo files to review)
- `plugin/templates/jig/RULES.md` (Documentation, Homes)
- `plugin/skills/hardware/SKILL.md`, `plugin/skills/adopt/SKILL.md`,
  `plugin/skills/redocument/SKILL.md`, `plugin/skills/update/SKILL.md`, `plugin/templates/AGENTS.md`
- `tests/smoke.sh`

## Alternatives considered
- Folder pages only (today) — rejected by the owner: a folder of one file says nothing —
  reason is [seen: owner, Nov 10]
- Sections in the system page, no part pages — rejected because an agent then reads the whole
  system's page to edit one part, and a part with no section is silently covered — reason is
  [seen: Maige-OS owner decision, in the report]
- Flat pages told apart by path alone — rejected because a flat page and a note beside it share
  a shape of path; `docmap` or the page's own sections say which — reason is [seen: investigator's
  repro, a flat page without Invariants escaped the contract check]

## Decisions
- The line is "more than one file": a page's folder exists to hold its company.
- Runs after `page-talks-to` and `reading-list-pages-above` (same RULES.md sections and
  `owner_page`), and before `meta-docs-tree`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
