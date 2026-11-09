# Flatten hardware into systems

Source: cowork session 2026-11-08, Dave with Claude (staged as flatten-hardware.md)

Source: Dave, 2026-11-08. Runs `after` docs-subsystems (consumes its subsystem
definition; both rewrite at_home/page_home/doc_homes and the same RULES.md sections).
Sibling to `redocument`, whose remap carries the page moves.

Amended by the owner, Nov 8, after review: "boards definition should be a .md file we build,
because they'll usually be custom boards. In early dev work they're often a dev board in which
case they should still have an .md even if its made from a spec sheet, that spec sheet should
be in the folder as a reference." And: "a board is not a component of itself, so it's pdf
should go in a subfolder of it's own folder, I'd call that subfolder datasheets/. Same for
other datasheets … boards are just one example of a <system>, and in some architectures there
may also be boards that are a <subsystem> … The pattern has to be general enough to flex to the
use case."

## Intent
Remove `docs/hardware/` as a layer. A board, a screen, a battery are parts of the
product, so they are ordinary systems or subsystems: `docs/<x>/<x>.md` or
`docs/<x>/<y>/<y>.md`, beside the code's. Everything hardware-specific becomes machinery
keyed on what a page *is*, never on where it sits — no genre folders, and no `firmware/` or
`software/` umbrellas by symmetry. Every board has a page we build, and a vendor's document
sits in a `datasheets/` folder beside the page it's for.

## Design
- **Board pages are registered, not path-inferred.** A `boards` list in `config.json`
  names each board page, at any home a page may have: a system
  (`docs/<board>/<board>.md`) or a subsystem (`docs/<product>/<board>/<board>.md`).
  `/jig:hardware` writes the page and the entry; it asks whether the board is a system of its
  own or a subsystem of an existing one, and defaults to a system.
- **Every board has a page we build.** Boards are usually custom, so the page *is* the
  definition. A dev board gets one too, written from its vendor spec sheet. Enforced at
  `jig gate`, which refuses:
  - a branch that adds or changes a **board-build file** — `sdkconfig*`, `platformio.ini`,
    `idf_component.yml`, `west.yml`, `*.ino`, `*.overlay` (the markers `/jig:init` reads as
    firmware) — that no registered board page's docmap globs cover. The refusal names the
    file and says: write the board's page with `/jig:hardware`, list it in `boards`, map the
    file to it.
  - a `boards` entry naming a page missing at the branch head.
  - "no page needed" in the fold-in for a file a registered board page's docmap covers (the
    original refusal, kept as a backstop for a hand-edited note).
  Survey keeps reporting a board page off the page contract; the gate doesn't refuse it.
- **`datasheets/` beside the page.** Any page's folder — system or subsystem, board or not —
  may hold a `datasheets/` folder: the vendor documents the page leans on (datasheets, a dev
  board's spec sheet, app notes, reference manuals). A board's own spec sheet goes in
  `docs/<board>/datasheets/`, never in a folder named for a part of itself. Files the repo
  wrote (its schematic, a definition the user wrote) sit in the page's folder itself, not in
  `datasheets/`.
- **Pages for behavior, datasheets for reference.** A part whose behavior the code touches
  (a screen, a battery) is a subsystem with its own page — and its own `datasheets/` when a
  datasheet exists; a page with none needs no folder. A part documented only by its datasheet
  is a file in the `datasheets/` of the page it's for. Example: a product whose board is a
  system, with subsystems for its screen (page + `datasheets/`) and its battery (page only).
- **Shared datasheets.** A datasheet two pages use lives in the `datasheets/` of the nearest
  folder both pages sit under: two subsystems of one system share the system's `datasheets/`;
  two systems share `docs/datasheets/`. Both pages link it; never a copy per page. It moves on
  the second user, matching retro's twice-is-the-bar.
- **`datasheets/` is a reserved name** at any depth: it holds reference files, is never a
  subsystem, and a note inside it is a reference file, not a page. `docs/datasheets/` holds
  reference files only, never a page. Survey reports a page named `datasheets` (rename its
  folder) and a `datasheets/` folder that is neither in a page's folder nor `docs/datasheets/`.
- **Provenance unchanged.** Each link to a datasheet keeps its source URL, retrieval date and
  sha256 prefix (the board page's Components table, or the page's text). `reference_files`
  covers every `datasheets/` folder; in `ignore` mode `.gitignore` gains
  `docs/**/datasheets/**/*.[pP][dD][fF]` — one line, whatever the depth, so a vendor PDF is
  ignored wherever it sits.
- **Homes simplifies.** `docs/…/<x>/<x>.md`; a page's folder may hold its supporting files
  and a `datasheets/` folder; `docs/datasheets/` is allowed. The hardware special cases are
  deleted, not rewritten.
- **Survey generalizes the reference checks**: every file under a page's folder is linked by
  a page; every datasheet link resolves; a skeleton-shaped .md inside another page's folder is
  flagged as a subsystem candidate.
- **Board page skeleton** under the page contract — no separate board skeleton; the survey
  exemption for board pages ends. Known failure modes is a body section; Pre-flight becomes
  Invariants (each entry with its why and holder); "Defined from" moves into the lead
  paragraph and links the definition (in `datasheets/` when it's a vendor's); Skills stays as a
  body section. An unverified part is a **Verified column** in the Components table —
  description, never an Undefined entry, which is written only on the owner's word. Retro's
  failure-modes line targets the new path.
- **Migration beyond the remap.** `jig update`'s existing mover (root `HARDWARE.md`) targets
  `docs/<slug>/<slug>.md` and writes the `boards` entry. Survey and update map the old layout:
  `docs/hardware/<x>.md` → `docs/<x>/<x>.md` + `boards`; `docs/hardware/<x>/` files → that
  folder, vendor PDFs into its `datasheets/`; `docs/hardware/components/<part>/` → the
  `datasheets/` of the page that uses it, or the shared one when two do. For
  `reference_files: ignore` repos, update rewrites the `.gitignore` line, and its dry run lists
  every file the old line ignored that the new one won't.

## Done when
- [ ] RULES.md Documentation and Homes carry the flat layout: no hardware special cases,
      `boards` registration at system or subsystem depth, `datasheets/` and its sharing rule,
      every board has a page
- [ ] `/jig:hardware` and the board template emit the page (system by default, subsystem on
      request), the `boards` entry, the new skeleton, and save a vendor spec sheet to the
      board's `datasheets/`; `claude plugin validate ./plugin` passes
- [ ] `jig gate` refuses a branch that adds `platformio.ini` (and one that changes
      `sdkconfig`) with no board page covering it, and passes once a registered page's docmap
      covers it — including a board page at subsystem depth; it refuses a `boards` entry
      whose page is missing; a repo with no board-build files is untouched (smoke covers all)
- [ ] fold-in refuses "no page needed" for a file a registered board page's docmap covers
      (smoke: refusal fires, and an unregistered board page has no such teeth)
- [ ] survey accepts `datasheets/` in a system's and a subsystem's folder and at
      `docs/datasheets/`; flags an unlinked file in a page's folder, a dangling datasheet
      link, a page named `datasheets`, and an orphan `datasheets/` folder (smoke covers each)
- [ ] no `components/` folder rule remains in jig.py, RULES.md, skills or templates
      (`grep -rn "components/" plugin` names only the old-layout migration)
- [ ] retro's board-page line points at the new path
- [ ] `jig update` moves a root HARDWARE.md to `docs/<slug>/<slug>.md` with a `boards`
      entry, maps an old `docs/hardware/` tree as above, and rewrites the ignore-mode
      `.gitignore` line (smoke covers each)
- [ ] `bash tests/smoke.sh` passes, and `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`
      finds nothing

## Out of scope
- Migrating any existing repo's pages — the redocument remap moves board pages like any page
- Merging a part's hardware page with its code's system page (per-repo seam call; docmap
  already lets both cover the driver files)
- Gate-refusing a board page off the page contract (survey reports it)

## Touches
- plugin/templates/jig/RULES.md (Documentation, Homes)
- plugin/templates/jig/jig.py (survey checks, gate board refusals, fold-in board refusal,
  update's HARDWARE.md mover, old-layout map and gitignore rewrite, reference_files)
- plugin/templates/hardware.md, plugin/skills/hardware/SKILL.md, plugin/skills/retro/SKILL.md
- plugin/skills/adopt/SKILL.md (homes table), plugin/skills/verify/SKILL.md (its board-page
  pointer), plugin/skills/redocument/SKILL.md (its `docs/hardware/` exclusion): each names
  `docs/hardware/` today (hubnode, Nov 8)
- plugin/templates/AGENTS.md (Firmware: where the board's page goes)
- tests/smoke.sh

`boards` is an optional board key: it joins the list bug-workflow-unknown-key adds beside
`BOARD_DEFAULTS`, so update never writes an empty list into a repo with no boards
(hubnode, Nov 8).

## Alternatives considered
- Keep `docs/hardware/` as an umbrella — rejected because it is a genre folder, which
  contradicts the-tree-names-the-product's-parts, and forces `firmware/`/`software/`
  umbrellas by symmetry — reason is [seen]
- `components/<part>/` folders (this spec's first version) — rejected by the owner: a board
  is not a component of itself, and a folder per part is heavier than a file in the page's
  `datasheets/` — reason is [seen: owner, Nov 8]
- Per-page copies of shared datasheets — rejected because copies drift; one home in the
  nearest shared folder — reason is [seen]
- Never move a shared datasheet; later pages link the first owner's copy — rejected because
  the first owner is arbitrary and the home moves when that page is dropped — reason is [seen]
- Only the fold-in refusal for the board rule — rejected because handoff builds the fold-in
  from trunk's docmap, so a covered file never gets an UNOWNED line, and board code no glob
  covers is never asked about — reason is [seen: `foldin_lines`, jig.py ~1218]

## Decisions
- Board pages are explicit (`boards` in config), never inferred from path, at system or
  subsystem depth
- Every board has a page we build; the gate refuses board-build files no board page covers
- The board rule becomes enforced, not just stated: a rule text with no holder was the
  docs disease in jig's own RULES.md
- `datasheets/` is a reserved name at any depth, exempt from the subsystem definition
- A shared datasheet lives in the nearest folder both pages share; `docs/datasheets/` is the
  top of that, a reference-file pool, never a page's home
- No separate board skeleton; the contract exemption for board pages ends

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
