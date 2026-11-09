# Flatten hardware into systems

Source: cowork session 2026-11-08, Dave with Claude (staged as flatten-hardware.md)

Source: Dave, 2026-11-08. Runs `after` docs-subsystems (consumes its subsystem
definition; both rewrite at_home/page_home/doc_homes and the same RULES.md sections).
Sibling to `redocument`, whose remap carries the page moves.

## Intent
Remove `docs/hardware/` as a layer. A board, a screen, a battery are parts of the
product, so they are ordinary systems: `docs/<x>/<x>.md`, flat beside the code's
systems. Everything hardware-specific becomes machinery keyed on what a page *is*,
never on where it sits — no genre folders, and no `firmware/` or `software/` umbrellas
by symmetry.

## Design
- **Board pages are registered, not path-inferred.** A `boards` list in `config.json`
  names each board page; `/jig:hardware` writes the entry when it creates the page at
  `docs/<board>/<board>.md`. The board rule ("code that runs on a board does not pass
  without a page that matches it") is a **new refusal** — RULES.md promised it but
  jig.py never enforced it: fold-in refuses "no page needed" for any file a registered
  board page's docmap globs cover.
- **Pages for behavior, component folders for datasheets.** A part with behavior the
  code touches (screen, battery) is a system with a page. A part documented by
  reference files gets `components/<part>/` (datasheets + notes) inside the folder of
  the page that owns it: `docs/tdeck/components/esp32-s3/`,
  `docs/screen/components/st7789/`. `components/` is a **reserved folder name**: it
  holds reference files, is never a subsystem, and a note inside it is a reference
  file, not a page — the same rule as the pool.
- **Promotion on second use.** A part a second page uses moves to
  `docs/components/<part>/` and both pages link it. Twice is the bar; no pool for
  parts used once. `docs/components/` holds reference files only, never a page.
- **Provenance unchanged.** The page's Components table keeps URL, retrieval date and
  sha256 prefix per datasheet. `reference_files` globs update to cover
  `docs/*/components/**` and `docs/components/**`.
- **Homes simplifies.** `docs/…/<x>/<x>.md`; a page's folder may hold its supporting
  files; `docs/components/*/` is allowed. The two hardware special cases are deleted,
  not rewritten.
- **Survey generalizes the component checks**: every file under a page's folder is
  linked by a page; every component link resolves; a skeleton-shaped .md inside
  another page's folder is flagged as a subsystem candidate.
- **Board page skeleton** under the new contract — no separate board skeleton; the
  survey exemption for board pages ends. Known failure modes is a body section;
  Pre-flight becomes Invariants (each entry with its why and holder); "Defined from"
  moves into the lead paragraph; Skills stays as a body section. An unverified part is
  a **verified column** in the Components table — description, never an Undefined
  entry, which is written only on the owner's word. Retro's failure-modes line targets
  the new path.
- **Migration beyond the remap.** `jig update`'s existing mover (root `HARDWARE.md` →
  `docs/hardware/<slug>.md`) retargets to `docs/<slug>/<slug>.md` and writes the
  `boards` entry. For `reference_files: ignore` repos, update rewrites the `.gitignore`
  glob to the new paths, or gitignored datasheets surface as untracked.

## Done when
- [ ] RULES.md Documentation and Homes carry the flat layout: no hardware special
      cases, `boards` registration, both component allowances
- [ ] `/jig:hardware` and the board template emit `docs/<board>/<board>.md`, the
      `boards` entry, and the new skeleton; `claude plugin validate ./plugin` passes
- [ ] fold-in refuses "no page needed" for a file a registered board page's docmap
      covers (smoke: refusal fires, and an unregistered board page has no such teeth)
- [ ] survey flags an unlinked file in a page's folder and a dangling component link,
      and accepts `docs/components/<part>/` (smoke covers all three)
- [ ] retro's board-page line points at the new path
- [ ] `jig update` moves a root HARDWARE.md to `docs/<slug>/<slug>.md` with a `boards`
      entry, and rewrites the ignore-mode `.gitignore` glob (smoke covers both)
- [ ] `bash tests/smoke.sh` passes

## Out of scope
- Migrating any existing repo's pages — the redocument remap moves board pages like
  any page
- Merging a part's hardware page with its code's system page (per-repo seam call;
  docmap already lets both cover the driver files)

## Touches
- plugin/templates/jig/RULES.md (Documentation, Homes)
- plugin/templates/jig/jig.py (survey checks, fold-in board refusal, update's
  HARDWARE.md mover and gitignore rewrite, reference_files)
- plugin/templates/hardware.md, plugin/skills/hardware/SKILL.md,
  plugin/skills/retro/SKILL.md
- plugin/skills/adopt/SKILL.md (homes table), plugin/skills/verify/SKILL.md (its board-page
  pointer), plugin/skills/redocument/SKILL.md (its `docs/hardware/` exclusion): each names
  `docs/hardware/` today (hubnode, Nov 8)
- tests/smoke.sh

`boards` is an optional board key: it joins the list bug-workflow-unknown-key adds beside
`BOARD_DEFAULTS`, so update never writes an empty list into a repo with no boards
(hubnode, Nov 8).

## Alternatives considered
- Keep `docs/hardware/` as an umbrella — rejected because it is a genre folder, which
  contradicts the-tree-names-the-product's-parts, and forces `firmware/`/`software/`
  umbrellas by symmetry — reason is [seen]
- Per-board copies of shared parts — rejected because copies drift; promotion keeps
  one home — reason is [seen]
- Never promote; later pages link the first owner's copy — rejected because the first
  owner is arbitrary and the home moves when that board is dropped — reason is [seen]

## Decisions
- Board pages are explicit (`boards` in config), never inferred from path
- The board rule becomes enforced, not just stated: a rule text with no holder was the
  docs disease in jig's own RULES.md
- `components/` is a reserved name at any depth, exempt from the subsystem definition
- No separate board skeleton; the contract exemption for board pages ends
- `docs/components/` is a reference-file pool, never a page's home
- Promotion bar is a second user, matching retro's twice-is-the-bar

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
