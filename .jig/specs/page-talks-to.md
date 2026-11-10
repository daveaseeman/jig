# page-talks-to

Source: Maige-OS hubnode session, 2026-11-10, Dave Seeman (with Claude) (staged as feedback-Maige-OS-2026-11-10-redocument-non-jig-docs.md): No section for what a system talks to.
Source: Maige-OS hubnode session, 2026-11-10, Dave Seeman (with Claude) (staged as feedback-Maige-OS-2026-11-10-redocument-non-jig-docs.md): A subsystem page must have a folder of its own.

## Intent
The page contract gets an optional `## Talks to` section, placed after the body and before
Invariants, for what crosses the system's boundary. A subsystem gets its own page once it has
something to say that its system's page doesn't. Until then it stays a section.

## Why
- What crosses a system's boundary is what breaks its callers when it changes. No single file
  shows it, and a seam page for each pair of systems is more than a list needs. The contract's
  body sections must be named for the system's own parts, so a boundary list has no slot today.
- RULES.md says a part with files of its own "moves to" a page of its own. In modular code
  that means one page per module, which is the per-module mirror jig replaced. The one-file
  folders the report counts come from that rule, not from the folder shape.

## Givens
- `[seen]` RULES.md (Documentation, items 1–4) and `docs-page.md` have no slot for a
  boundary. `grep -rni 'talks to' plugin` finds nothing.
- `[seen]` Scratch repo: a page with `## Talks to` between its body and `## Invariants` gets
  no survey finding. After `## Undefined`, it gets "sections after ## Undefined: Talks to".
  `page_problems` checks no section names.
- `[seen]` Maige-OS `.jig/redocument.md`, the owner's decisions (Dave, 2026-11-10): an
  optional `## Talks to`, after the body and before Invariants, for what crosses the boundary
  only. A module gets a page only when it has a lot that is local to it.
- `[seen]` RULES.md item 2 and `docs-page.md`: a part with files of its own "moves to" a
  subsystem folder with its own page.
- `[seen]` Maige-OS's approved remap: `fsck`, `handle` and `verity` (each a module with its own
  file) stay sections of the crate page. That leaves 8 module pages, against 48 old pages.
- `[seen]` `marketing/FEATURES.md`, Docs shape row: "per-module pages copy them and drift".
- `[assumed]` Repos other than Maige-OS would use the slot. Not checked.

## Design
- RULES.md, Documentation: a new item after Body sections. "`## Talks to`, optional: what
  crosses the system's boundary, meaning what it calls, what calls it and what passes between
  them, each linked to its seam page or contract where one exists. Calls inside the system stay
  in the body."
- Item 2's "moves to" sentence becomes: "A subsystem gets a page of its own, in a subsystem
  folder, once it has something to say that whoever works on it needs and its system's page
  doesn't; the parent's section then shrinks to a paragraph and a link. Until then it is a
  section, its files in its system page's globs." No length trigger.
- `docs-page.md`: a `## Talks to` block in the same place, and the same condition on its "moves
  to a folder of its own" sentence.
- Survey and redocument skills: their contract lists name the optional Talks to. Redocument's
  Subnode step 2 says that an old page's list of what it uses or serves goes under it, keeping
  only what crosses the boundary.

## Done when
- [ ] `grep -n '^## ' plugin/templates/jig/docs-page.md` lists `<Part>`, `Talks to`,
  `Invariants`, `Undefined`, in that order. RULES.md, Documentation, names `## Talks to` as
  optional. This is the reported symptom (no slot), gone.
- [ ] In a scratch repo, `jig survey --json` reports nothing for a page with `## Talks to`
  before `## Invariants`, and reports "sections after ## Undefined: Talks to" when the section
  follows `## Undefined`.
- [ ] `grep -n 'Talks to' plugin/skills/survey/SKILL.md plugin/skills/redocument/SKILL.md`
  finds the contract lists and the Subnode line.
- [ ] `grep -n 'something to say' plugin/templates/jig/RULES.md plugin/templates/jig/docs-page.md`
  finds the condition in both, and neither file still says a subsystem simply "moves to" a
  page of its own.
- [ ] `claude plugin validate ./plugin` passes, `bash tests/smoke.sh` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy' plugin` finds nothing.

## Out of scope
- A survey check of section names or of Talks to's position. Survey checks only that
  Undefined comes last, and that stays.
- Flat part pages, `docs/<system>/<part>.md`, which was the report's fix for its issue 2.
  Every page keeps its own folder: a second shape would undo the shape test that tells a page
  from a linked file, slip past the depth rule, and need a move once the part gains a file.
  It is dropped as too specific unless the owner says otherwise.
- RULES.md's hardware line, "a part whose behavior the code touches is a subsystem with its
  own page". Its datasheets and checks are what it has to say.
- The board template (`templates/hardware.md`).

## Touches
- `plugin/templates/jig/RULES.md`: Documentation, items 2–3
- `plugin/templates/jig/docs-page.md`
- `plugin/skills/survey/SKILL.md` (~32), `plugin/skills/redocument/SKILL.md` (~168)
- `marketing/FEATURES.md`: the Docs shape and Subsystems rows (main checkout only)

## Alternatives considered
- Leave boundaries to seam pages — rejected because a seam page per pair of systems is far more
  than a list needs, and RULES.md keeps seam pages for what needs a page of its own — reason
  is [assumed]
- Make Talks to mandatory — rejected because the owner called it acceptable, not mandatory,
  and a system with no outside callers would carry an empty heading — reason is [seen] (owner's
  decision in Maige-OS's remap)
- A body section named for the interface (`## RPC`) — rejected because it holds what this
  system offers, not what it calls — reason is [assumed]
- A length trigger for a subsystem's page — rejected because length isn't structure (owner,
  Nov 8, `docs-subsystems`) — reason is [seen]

## Decisions
- Talks to is limited to the system's boundary. Module-to-module calls inside it restate the
  code.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
