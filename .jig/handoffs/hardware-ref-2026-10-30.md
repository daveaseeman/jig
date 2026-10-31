# Handoff: hardware-ref

Commit: 89461771af6390682292c9948d03227babf7d266
Date: 2026-10-30
Spec: .jig/specs/hardware-reference-files.md

## Built
Two doc homes beside board pages: `docs/hardware/components/<part>/` (a part's datasheets
and notes, shared by boards) and `docs/hardware/<board>/` (a board's files that aren't its
page). Board pages are only `docs/hardware/<board>.md`. Survey reports component files no
board page links and links to component files that don't exist (inline, reference-style,
`<angle>`, root-absolute and spaced links). The board template gains a Datasheet column
and a hash on `Defined from:`. `/jig:hardware` saves the definition and datasheets with
their sha256-12 and asks once for `reference_files: commit | ignore`, a new config default
(`STAMP` 9).

## Done-when evidence
- DOC_HOMES, RULES.md, adopt table, AGENTS.md template: `bash tests/smoke.sh` → `PASS  reference files: survey's Homes line names both new homes`
- Unmapped/mapped board pages: `PASS  reference files: unmapped, only docs/hardware/<board>.md is a board page`; `PASS  reference files: mapped, a component note and a board's folder are no board pages`
- Component link checks: `PASS  reference files: a component file no board page links is reported, a linked one is not`; `PASS  … reference-style, <angle>, root-absolute and spaced links all count as links`; `PASS  … a board page linking a component file that doesn't exist is reported`
- Template Datasheet column and `Defined from:` hash: `plugin/templates/hardware.md` (prose; no command)
- `/jig:hardware` saving files, hashes, asking once, `reference_files`, ignore pattern: `plugin/skills/hardware/SKILL.md` step 2 (prose); `PASS  reference files: init leaves reference_files unset, so /jig:hardware asks`; `PASS  reference files: update adds reference_files to a config that lacks it`
- Smoke: 272 PASS, 0 FAIL at 8946177. `claude plugin validate ./plugin` → `✔ Validation passed`. New examples use made-up parts (QX-100, acme-devboard-2).

## Review
Fresh-context review (round 1), nothing blocking, every finding taken:
1. The skill wrote `.gitignore` and `reference_files` itself: both are trunk files; now handed to the hubnode in a job, made directly solo on trunk; `git rm --cached` for PDFs already committed on `ignore`.
2. Reference-style, `<angle>`, root-absolute and spaced links misread: `link_targets()` parses all of them; one smoke case covers the four.
3. Install-only path read every page under `docs/hardware/`: now board pages only.
4. `ignore` covered only `components/**/*.pdf`: now `docs/hardware/*/**/*.[pP][dD][fF]`, both homes, any case.
5. The "homeless" smoke case passed on main too: dropped.
6. URL-only datasheet: the skill says the cell holds URL, date and "not saved", no hash.
7. RULES.md config key list gains `reference_files`.
Kept: the template's existing ESP32 examples, generic (jig ships an `esp-idf` skill); recorded in the spec's Decisions.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo has no docs/ tree; RULES.md (updated: Documentation, the board's config keys) and the hardware and adopt skills are jig.py's documentation

## Shared files changed
- `plugin/templates/jig/jig.py`: `DOC_HOMES`, `board_pages`/`boards_unmapped`, the survey's component-link check, `reference_files` in `BOARD_DEFAULTS`, `STAMP` 8 → 9 (renumber at merge if another job bumps it). Plus `import urllib.parse` for `%20` in link targets.
- `plugin/templates/jig/RULES.md`: Documentation gains the two homes and `reference_files`; the board section's config key list gains `reference_files`.
- `tests/smoke.sh`: a new "hardware reference files" section at the end; `version` 8 → 9 in three update/board cases; `reference_files` in init's key list.
- `.jig/specs/hardware-reference-files.md` (common): a Decisions section.

## Test by hand
In a board repo: `/jig:hardware` with a definition file and a datasheet. Check the definition lands in `docs/hardware/<board>/`, the datasheet in `docs/hardware/components/<part>/`, the Datasheet cell has link · URL · date · hash, and it asks commit/ignore once (and, in a job, hands the config and `.gitignore` lines to the hubnode). Then `jig survey`: no extra board pages, both homes in the Homes line.

## Left
- Open: should `init` ask for `reference_files` instead of `/jig:hardware`? Left to `/jig:hardware` for now.
- `STAMP` and the end of `tests/smoke.sh` will conflict with the other jobs at merge.
