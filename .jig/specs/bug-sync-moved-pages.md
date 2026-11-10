# bug-sync-moved-pages

Source: maige-ecosystem hubnode session with Dave, 2026-11-10 (Claude) (staged as feedback-maige-ecosystem-2026-11-10-redocument-metarepo.md): "Nothing checks a pararepo's citations of a metarepo page that moves." Moving `products/hardware/walyt.md` "leaves Maige-Lite's `BUFFER.md` rows and specs citing a path the next pin no longer has."

## Intent
When a newer metarepo release moves or deletes an entry file, the pararepo's "Changed, in this
repo's terms" report names the old path, where it went, and every file here that cites it, its
specs and `BUFFER.md` included.

## Why
- Why is a moved page not reported? `jig sync` checks pointers one way only, the cache's into
  this repo (`stale_pointers`). Nothing reads this repo's citations of the metarepo.
- Why doesn't the term report catch it? It lists changed ids and headings, never a moved file,
  and its "used in" search skips all of `.jig/`, where `BUFFER.md` and specs live.
- Why skip `.jig/`? 59f574f widened the skip from the cache to all of `.jig/` to drop the
  rulebook's examples. Specs and ledgers live there too, and were dropped with it.

## Givens
- `[seen]` Repro, throwaway metarepo `mm` and pararepo `pp`, jig from `plugin/templates`
  (whose `jig.py` is the report's blob b9d48e5): v0.2.0 moves `products/hardware/walyt.md` to
  `products/walyt/walyt.md` and renames `## Interaction (E-045, E-038)` to `## Interaction`. `pp`
  pins v0.1.0 and cites the old path in a BUFFER row, a spec and `docs/a.md`. Before the bump,
  `jig sync` prints `Interaction (E-045, E-038): not used here` and no line for the path. After a
  hand bump it prints only `mm v0.2.0 is the latest release`.
- `[seen]` `changes_report` drops every `git grep` hit under `.jig/`. `terms_changed` reads only
  `| D-n |` rows and `##`/`###` lines from the diff.
- `[seen]` `git -C mm diff -M --name-status v0.1.0 v0.2.0` gives `R073 products/hardware/walyt.md
  products/walyt/walyt.md`.
- `[seen]` `changes_report` feeds sync's newer-release report, the body of the pin commit sync
  makes, and the pararepo release's warning.
- `[seen]` BUFFER's template column is "Metarepo claim (file § section, at the pin)". Maige-Lite
  cites bare (`` `products/hardware/walyt.md` § Interaction (E-045, E-038) ``) in BUFFER.md and specs.
- `[seen]` A throwaway prototype of the design below (about 20 lines) printed
  `products/hardware/walyt.md (now products/walyt/walyt.md): used in .jig/ledgers/BUFFER.md,
  .jig/specs/s.md, docs/a.md` and `Interaction (E-045, E-038): used in .jig/ledgers/BUFFER.md`.

Amended by the owner, Nov 10: "if its consistent across all repos and reliable, lets keep it.
citing needs to be strong." So a citation has one form everywhere, and the standing check the
first draft rejected becomes reliable.

## Design
- **At a release jump.** `changes_report` adds one line for each entry file at the old release
  that the new one lacks: `<old> (now <new>)` or `<old> (removed)`. It finds them with `git diff
  -M --name-status` over the same entry paths `terms_changed` reads. The "used in" search counts
  `.jig/specs/` and `.jig/ledgers/` and skips the rest of `.jig/`. It reports, as the term report
  does now. RULES.md's pin-bump sentence says what the report lists.
- **One citation form.** A pararepo cites the metarepo as `<meta>/<path>` (or `<meta>:<path>`),
  with `§ <heading>` for a section: the form RULES.md already gives the metarepo's pointers, now
  required both ways. BUFFER's template column says so.
- **On every sync.** `jig sync` checks each such citation in this repo's tracked files (specs and
  ledgers included, handoffs and Closed BUFFER rows excepted: they cite the pin they were written
  at) against the cache, mirroring `stale_pointers`: a path or `§` heading the pin lacks is named.
  A bare path that names a metarepo entry file at the pin and no file here is named too, as
  `write it as <meta>/<path>`. It reports and refuses nothing.

## Done when
- [ ] Smoke `pararepo`: the repro above. `jig sync` prints the `(now products/walyt/walyt.md)`
      line naming the BUFFER row's ledger, the spec and `docs/a.md`. The heading line reads `used in
      .jig/ledgers/BUFFER.md`, not `not used here`, so the reported symptom is gone.
- [ ] Smoke: a deleted entry file reads `(removed)`. A path mentioned only in `.jig/handoffs/`
      or `.jig/RULES.md` reads `not used here`.
- [ ] Smoke `pararepo`: after the bump, a spec citing `mm/products/hardware/walyt.md § Two
      stages` is named by `jig sync` as missing at the pin; one citing `mm/products/walyt/walyt.md`
      isn't; a spec citing bare `products/walyt/walyt.md` is named with `write it as
      mm/products/walyt/walyt.md`; a Closed BUFFER row and a handoff citing the old path are not named.
- [ ] The existing `D-001: used in api/ids.md` case still passes.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- Rewriting citations. The hubnode fixes them in the bump job; Maige-Lite's bare citations
  are that repo's to requalify once the check names them.
- A refusal from P2 or the gate.

## Touches
- `plugin/templates/jig/jig.py` (`changes_report`, a small helper beside `terms_changed`)
- `plugin/templates/jig/jig.py` (`cmd_sync`: the citation check beside `stale_pointers`)
- `plugin/templates/jig/RULES.md` (Metarepo and pararepos: the pin-bump sentence, the citation form)
- `plugin/templates/ledgers/BUFFER.md` (the claim column: `<meta>/<path> § section`)
- `tests/smoke.sh` (`pararepo`)
- `marketing/FEATURES.md` (`init --para` / `sync` / `propose` row)

## Alternatives considered
- Report only at a release jump (the first draft) — rejected by the owner: citing must be strong,
  so a bad citation is named on every sync, not once — reason is [seen: owner, Nov 10]
- Accept bare paths as citations — rejected because a bare path can't always be told from one of
  this repo's own; it is named only when it matches a metarepo entry file and nothing here —
  reason is [seen: Maige-Lite's BUFFER.md]
- Quote the changelog line that moved the file, as the report asks — rejected because `git diff -M`
  already names the new path, and a changelog line is free text — reason is [seen]
- Have the metarepo's release tell its pararepos what moved — rejected because the pararepo
  already fetches both tags and diffs them in `changes_report`, so no new channel is needed —
  reason is [seen]
- Refuse in P2 or at the gate — rejected because a Closed row and a finished spec cite the pin
  they were written at. That is history, which `pointers()` already skips in the changelog —
  reason is [seen]

## Decisions
- Both: the move list once per release jump (the bump commit's body keeps it), and the citation
  check on every sync. Both report; neither refuses.
- Specs and ledgers count as this repo's use of a term too, which fixes the heading line.
- Workaround until it lands: before a bump, run `git -C <meta> diff -M --name-status <pin> <new>
  -- <entry files>`, then `git grep -F` for each R/D path.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
