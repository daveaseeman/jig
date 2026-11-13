# bug-peers-other-log-id

Source: Maige-Lite hubnode session / 2026-11-13 / Dave with Claude (staged as feedback-Maige-Lite-2026-11-13-sync-report-non-utf8.md): "`jig decision E-054 --peers` in the pararepo answers `jig: no live entry E-054 in .jig/decisions.md`, though E-054 is in `.jig/meta-cache/.jig/decisions.md` at the pin."

## Intent
`jig decision <id> --peers` starts from an entry in any log it reads for peers, not only this
repo's: in a pararepo, the metarepo's at the pin; in a metarepo, a registered pararepo's. When
the same id is in more than one log, `<repo>/<id>` says which.

## Why
- Why refused? `cmd_peers` looks the id up only among `writer == SELF` entries, though
  `touching()` has already read the metarepo's log into the same list.
- Why that? Peers were built for fold-in, which starts from the branch's own entries. The command
  reused that start, and its help ("here and across the metarepo") describes where peers come
  from, not where the starting entry may be.

## Givens
- `[seen]` Repro (`/private/tmp/claude-501/nonutf8/run`): metarepo `mr` at v0.2.0 holds D-001
  (`Touches: docs/shared.md`); pararepo `pr` pinned at v0.2.0, its cache holds D-001, its own log
  has none. `jig decision D-001 --peers` → `jig: no live entry D-001 in .jig/decisions.md`, rc 1.
- `[seen]` `jig decision D-001` (no `--peers`) → `no entry D-001 in .jig/decisions.md or in its
  history`, rc 1.
- `[seen]` `cmd_peers` filters `mine = [e for e in every if e["writer"] == SELF]`; `every` holds
  the metarepo's entries with writer `META_KEY` and label `<meta>/.jig/decisions.md`.
- `[seen]` Both kinds default to the `D-` prefix (the repro's metarepo and pararepo both use it),
  so a plain id can name an entry in this log and another log at once.
- `[seen]` RULES.md § Peers: peers come from this log, the metarepo's at the pin, or each
  registered pararepo's; `/jig:review` step 8 runs `--peers` on the diff's own entries.

## Design
- `cmd_peers` finds the starting entry in this log first. Not there, in the other logs it read.
  Found in more than one other log, it refuses, naming each as `<repo>/<id>`.
- `<repo>/<id>` (the metarepo's name, or a pararepo's key from `jig repos`) starts from that log
  only. The printed first line gives the label, as the peer lines already do.
- Not found anywhere: the refusal names the logs searched and any `not read:` line, so a stale
  cache reads as `run jig sync`, not as a missing entry.
- The `--peers` help: "an entry's peers, from this log or one read for peers (`<repo>/<id>` picks
  the log)". RULES.md § Peers gets one sentence saying the same.

## Done when
- [ ] Smoke `touches`: in a pararepo whose cache holds the metarepo's entry and whose own log
      lacks the id, `jig decision <id> --peers` exits 0, prints the entry under the metarepo's
      label and its peers in this repo's log (the reported symptom).
- [ ] Smoke `touches`: with the same id in both logs, the plain id starts from this repo's entry,
      and `<meta>/<id>` from the metarepo's.
- [ ] Smoke `touches`: in a metarepo with two pararepos holding the same id, the plain id is
      refused naming both `<repo>/<id>` forms.
- [ ] Smoke `touches`: an id in no log is refused naming the logs searched.
- [ ] Existing `--peers` smoke lines still pass; `bash tests/smoke.sh` and
      `claude plugin validate ./plugin` pass.

## Out of scope
- `jig decision <id>` without `--peers` for another repo's id. It walks this repo's git history
  for removed entries, which the cache doesn't have; a metarepo id there is read in the metarepo.
- Fold-in's peer lines: they start from the branch's own entries, correctly.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_peers`, the `--peers` help)
- `plugin/templates/jig/RULES.md` (§ Peers: one sentence)
- `tests/smoke.sh` (`touches`)
- `marketing/FEATURES.md` (Decision log row: `--peers` starts from any log read for peers)

## Alternatives considered
- Help text only: "the id must be this repo's" (the report's other option) — rejected because the
  entry is already read; refusing it makes a pararepo reader switch repos to ask a question this
  one can answer — reason is [seen: `touching()` reads it]
- Plain id only, no `<repo>/` form — rejected because both kinds default to `D-`, so this repo's
  entry would hide the metarepo's — reason is [seen]
- Search other logs first — rejected because `/jig:review` runs `--peers` on the diff's own entries,
  which must win — reason is [seen: review SKILL.md step 8]

## Decisions
- `<repo>/<id>`, matching the `<meta>/<path>` citation form a pararepo already uses.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
