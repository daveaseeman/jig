# Handoff: flatten-hardware

Commit: 8ffd2a90799d108036ea85a351601eb342f5cd15
Date: 2026-11-09
Spec: .jig/specs/flatten-hardware.md
Review: tier 2, effort 2
Ran: two fresh Opus subagent reviews. 1st (9f59fc9): 1 blocking, 4 should-fix, 2 optional, fixed in 185a900; CRLF deferred. Spec amended by owner (datasheets/, every board has a page), reworked in 42641bc. 2nd (42641bc): 1 blocking (missing-page refusal locked unrelated jobs), 3 should-fix, optional O1/O5 taken, fixed in 8ffd2a9; O2/O3 deferred. B1 repro rerun by hubnode at 8ffd2a9: unrelated job passes

## Built
- `docs/hardware/` is gone as a layer. A board page is a system or subsystem page (`docs/<board>/<board>.md`, or `docs/<system>/<board>/<board>.md`), registered in the optional `boards` config key.
- `datasheets/` sits beside any page and holds its vendor documents. A datasheet two pages use lives in the nearest folder both share, with `docs/datasheets/` at the top. The name is reserved.
- Survey reports: unlinked files (links from notes in the folder count), dangling datasheet links, misplaced shared datasheets, a page named `datasheets`, orphan `datasheets/` folders, and board-build files no board page covers.
- `jig gate` refuses three things:
  - a board-build file (`sdkconfig*`, `platformio.ini`, `idf_component.yml`, `west.yml`, `*.ino`, `*.overlay`) that no registered board page's docmap covers. When docmap maps the file to an unregistered page, the message names that page.
  - a branch that deletes or moves a registered board page.
  - "no page needed" in the fold-in for code a board page covers.
- The board template is on the page contract: "Defined from" in the lead, a Verified column, Invariants. `/jig:hardware` asks whether the board is a system or a subsystem.
- `jig update`:
  - moves a root `HARDWARE.md` to `docs/<slug>/<slug>.md` and adds it to `boards`;
  - maps the old `docs/hardware/` tree for review, with collisions renamed and unplaceable files named;
  - in ignore mode, rewrites the `.gitignore` line to `docs/**/datasheets/**/*.[pP][dD][fF]` and lists each file the old line ignored that the new one won't.
- A repo's own PDFs in a board's folder (a schematic) are deliberately no longer ignored. The old `docs/hardware/<board>/` PDFs move into `datasheets/` with redocument.

## Done-when evidence
- RULES.md flat layout: `plugin/templates/jig/RULES.md` Documentation and Homes. Covers `boards` at system or subsystem depth, the `datasheets/` sharing rule, the three gate refusals, and survey's checks.
- `/jig:hardware` and the template: system by default, subsystem on request; the `boards` entry; the contract skeleton; a vendor spec sheet in `<home>datasheets/`. `claude plugin validate ./plugin` → ✔ Validation passed.
- Gate (smoke `hardware`), all PASS:
  - `platformio.ini` is refused, then passes once a subsystem-depth board page covers it;
  - a changed `sdkconfig` is refused;
  - a job forked before the board page existed passes once the page is registered;
  - deleting a registered board page is refused;
  - a repo with no board-build files passes.
- Fold-in "no page needed" refusal: PASS. An unregistered page has no such refusal: PASS.
- Survey: `datasheets/` is accepted at system depth, subsystem depth and `docs/datasheets/`. The unlinked file, dangling link, page named `datasheets`, orphan folder and misplaced shared datasheet checks each PASS.
- `grep -rn "components/" plugin`: only the old-layout migration remains (`jig.py:1490`, `jig.py:1493`, `redocument/SKILL.md:49`).
- Retro: the board-page line points at the new path (system or subsystem).
- `jig update`: the HARDWARE.md mover, the old-layout map and the ignore-line rewrite each PASS.
- `bash tests/smoke.sh` → exit 0, 702 PASS, 0 FAIL (`flatten-hardware-smoke-5.out` in the shared notes folder).
- `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Review
**Round 1, at 9f59fc9.** All fixed in 185a900 except the CRLF edge.
- Blocking: there was no migration path for old `docs/hardware/` pages. Survey and update now map them, and redocument step 2 proceeds.
- Should-fix:
  - Vendor definitions under `reference_files: ignore`. The dry run lists newly unignored files.
  - A page named with the reserved name is reported.
  - `reference_file` only counts a reserved folder inside a page's folder or at the top of `docs/`, and orphan folders are reported.
  - `component_links` skips `not_docs`.
- Optional:
  - The fold-in regex now handles a path with a space.
  - A non-list `boards` value gets a warning.
- Deferred: a CRLF `.gitignore` keeps the old reference line. It matches the existing `cache_line` behaviour (DEFERRED.md row).

**Owner amendment (c6bc8c1), reworked in 42641bc.** `components/<part>/` became `datasheets/`, and every board has a page, enforced at the gate.

**Round 2, at 42641bc.** All fixed in 8ffd2a9.
- B1, blocking: the missing-page refusal held every job forked before a board page landed. The gate now refuses only a branch that deletes or moves a registered board page, and leaves a page that is missing everywhere to survey's `boards_missing`. The hubnode reran the repro at 8ffd2a9: the unrelated job passes, and the board job passes once registered.
- S1: survey lists board-build files no board page covers. When docmap maps the file to an unregistered page, survey and the gate both say to add it to `boards`.
- S2: old-layout collisions are caught across both kinds of move. Colliding files get their origin as a prefix; any still unresolved are named for the owner to place.
- S3: links from notes in a page's folder count.
- Optional, taken:
  - O1: a page linking into another page's `datasheets/` is reported, with the shared folder the file belongs in.
  - O5: `docs/hardware/hardware.md` and a folder with no board page beside it are set aside for the owner.
- Deferred (DEFERRED.md rows):
  - O2: init and the gate read different firmware markers. The gate's list is now named as its own.
  - O3: build files in vendored trees need docmap globs.
- Dropped: O6, the DEFERRED date. The hubnode confirmed Nov 9 is correct.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's docs are .jig/RULES.md (plugin/templates/jig/RULES.md), updated here: Documentation (board pages, datasheets/, the board gate) and § Homes

## Shared files changed
- `plugin/templates/jig/jig.py`: survey, gate, update and doc homes. This is the job itself.
- `plugin/templates/jig/RULES.md`: Documentation, Homes and the board keys (`boards`).
- `tests/smoke.sh`: `sec_hardware` rewritten; the rules H section and the update sections moved to the new paths; fu-hw moved to `datasheets/`.
- `plugin/skills/{retro,adopt,verify,redocument}/SKILL.md`: these pointed at `docs/hardware/`.
- `plugin/templates/AGENTS.md`: the Firmware line names where the board's page goes. Added to shares by the hubnode (4cb4b21).
- `.jig/ledgers/DEFERRED.md`: three rows (CRLF, O2, O3).

## Test by hand
In a fresh repo with `platformio.ini`, run `/jig:hardware`. Check that it asks system or subsystem, writes the page and `datasheets/`, and proposes the `boards` and docmap lines. Then check that `jig survey` no longer lists `platformio.ini` once those lines are on trunk, and that a job touching it passes `jig gate`.

## Left
Nothing on this job. Follow-ups are in DEFERRED.md (CRLF, O2, O3).
