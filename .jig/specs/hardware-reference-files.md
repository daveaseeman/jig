# Reference files for boards: a home for datasheets, board pages only at the top, provenance on the page

Source: `/jig:feedback` from a pararepo after a `/jig:hardware` session, Oct 30
(`jig-feedback-<repo>-2026-10-30.md`). Checked against `plugin/templates/jig/jig.py`,
`plugin/templates/hardware.md` and the hardware and adopt skills at b5ed1cf.

## Intent
A board repo has standard places for the files a board page leans on: datasheets per
component, and per-board files that aren't the page. The survey reads them correctly, and the
page records which exact document each check was made against.

## Givens
- `[seen]` `DOC_HOMES` names Markdown homes only. The stray check runs over Markdown only
  (`for f in md:`), so a committed PDF is never reported, and never given a home either.
- `[seen]` `/jig:hardware` step 1 accepts "a spec sheet, BOM, wiring doc, vendor page". A
  board's checks lean on datasheets (rail voltages, chip ids), but nothing says where those go.
- `[seen]` `boards_unmapped` is `f.startswith(BOARD_PAGES)` at any depth. So a note beside a
  datasheet, or a vendor snapshot in a board's folder, is reported as an unmapped board page.
  Everything else in jig means `docs/hardware/<board>.md` exactly (`update`'s `HARDWARE.md`
  rows, RULES.md).
- `[seen]` `templates/hardware.md` Components is `Component | Part | Role | Notes`. `Defined
  from:` takes a path or "pasted <date>". A URL to a page that changes carries nothing to pin it.
- `[seen]` The reporting repo's choice is `docs/hardware/components/<part>/` for datasheets,
  shared across boards, and `docs/hardware/<board>/` for one board's other files. It's private,
  so it commits vendor PDFs. A public repo may not be allowed to.

## Done when
Smoke and checks:
- [ ] `DOC_HOMES` names two more homes:
  - `docs/hardware/components/`: one folder per part, its datasheets and notes, shared by board
    pages
  - `docs/hardware/<board>/`: one board's files that aren't its page (schematic, a snapshot of
    its definition)

  RULES.md Documentation, the adopt skill's homes table and the AGENTS.md template's home line
  say the same. `jig survey` prints them in its Homes line.
- [ ] Survey, with `docs/hardware/watch.md` mapped plus `components/pmic/notes.md` and
      `watch/vendor-definition.md` committed: no unmapped board pages. With the page unmapped:
      only `docs/hardware/watch.md`.
- [ ] Survey reports a file under `docs/hardware/components/` that no board page links, and a
      board page that links a component file that doesn't exist.
- [ ] `templates/hardware.md` Components gains a `Datasheet` column: relative link · source URL
      · retrieved date · first 12 hex of its sha256. `Defined from:` asks for a commit or hash
      when it's a URL.
- [ ] `/jig:hardware`:
  - When the definition or a datasheet is a file, step 2 saves it under those homes and records
    its hash.
  - On the repo's first board page, it asks once whether reference binaries are committed or
    ignored.
  - It records the answer as `"reference_files": "commit" | "ignore"` in `.jig/config.json`.
  - On `ignore`, it adds `docs/hardware/components/**/*.pdf` to `.gitignore`. The page keeps
    the URL and hash, so the file can be fetched again.
- [ ] Smoke passes, the validator passes, and no repo-specific part or board names appear in
      `plugin/`.

## Out of scope
- Fetching datasheets automatically.
- Binaries outside `docs/hardware/`. Firmware images and build outputs are the repo's own.

## Touches
- `marketing/FEATURES.md`: a row for reference files, before code.
- `plugin/templates/jig/jig.py`: `DOC_HOMES`, `boards_unmapped`, a survey check for component
  links, `reference_files` in `BOARD_DEFAULTS` (`update` adds it as a missing key, `STAMP` 9).
- `plugin/templates/jig/RULES.md`, `plugin/templates/AGENTS.md`, `plugin/templates/hardware.md`.
- Skills: `hardware`, `adopt`.
- `tests/smoke.sh`.

## Alternatives considered
- Leave it to each repo. Rejected: every board repo re-decides it, and the survey misreads the
  result. `[seen]`: two false board pages in the report.
- List those folders in `not_docs`. Rejected: that key means "Markdown that ships as code", and
  it would hide real strays there. `[seen]`: its definition in RULES.md.
- Key datasheets by board (`docs/hardware/<board>/datasheets/`). Rejected: one part sits on
  several boards, and the same PDF would be copied per board. `[seen]`: the repo's two boards
  share parts.
- Always commit the binaries. Rejected: a public repo may not be allowed to redistribute vendor
  PDFs, so this is the repo's call. `[seen]`: the report's reasoning.

## Decisions
- The template's existing ESP32 examples stay: they are generic, and jig ships an `esp-idf`
  skill. New examples use made-up parts (QX-100).
- `ignore` covers PDFs in both homes, any case: `docs/hardware/*/**/*.[pP][dD][fF]`.
- The `.gitignore` edit and the `reference_files` line are trunk files: in a job, the skill
  hands both to the hubnode.
- Until the open question below is settled, `/jig:hardware` asks.

## Open
- `reference_files` defaults to unset, so the skill asks. Should `init` ask instead, for every
  repo with a Firmware section?
