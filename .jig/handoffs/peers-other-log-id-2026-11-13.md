# Handoff: peers-other-log-id

Commit: b1cee840020717034690c232e6e49751b78f30f4
Date: 2026-11-13
Spec: .jig/specs/bug-peers-other-log-id.md
Review: tier 2, effort 2

## Built
`jig decision <id> --peers` now starts from an entry in any log it reads for peers, not only
this repo's: in a pararepo, the metarepo's log at the pin; in a metarepo, a registered
pararepo's log.
- **Plain id.** It is looked up in this repo's log first, since `/jig:review` runs `--peers` on
  the diff's own entries. Then it is looked up in the one other log that holds it. Two other logs
  holding it is a refusal naming each `<repo>/<id>`.
- **`<repo>/<id>`.** Reads only that repo's log: this repo's name, the metarepo's, or a
  pararepo's key. An unknown repo is refused. A repo whose log wasn't read is refused as unread,
  with its `not read:` lines.
- **Output.** An entry from another log prints its label on the first line
  (`hub/.jig/decisions.md § D-033 …`), as the peer lines do.
- **Superseded ids.**
  - An id this repo superseded or removed is refused, naming what holds now; another log's
    entry with the same number is never taken for it.
  - An id another log superseded starts from its successor, with a line saying it hopped.
- **Not found.** The refusal names the logs searched and each `not read:` line.
- **Words.** The `--peers` help and one sentence in RULES.md § Peers say the same.

## Done-when evidence
Every case below ran in `bash tests/smoke.sh` at b1cee84: exit 0, 1235 PASS, 0 FAIL. The output
is in the session notes folder as `peers-other-log-id-smoke-2.out`.
- [x] The reported symptom: PASS "touches: --peers in a pararepo starts from the metarepo's entry
  this log lacks, with its peers here".
- [x] Same id in both logs: PASS "touches: with an id in both logs, the plain id starts from this
  repo's entry" and PASS "touches: with an id in both logs, <meta>/<id> starts from the
  metarepo's".
- [x] Two pararepos, one id: PASS "touches: --peers in a metarepo refuses an id two pararepos
  hold, naming both <repo>/<id>" and PASS "touches: --peers pa/D-007 starts from pa's entry,
  with peers here and in pb".
- [x] An id in no log: PASS "touches: --peers on an id in no log is refused naming the logs
  searched and the one not read".
- [x] Existing `--peers` lines still pass: PASS "touches: jig decision --peers lists the peers
  with their first body sentence" and PASS "touches: --peers in a metarepo reads the pararepos,
  and names one it can't find".
- [x] Checks pass, and examples stay generic:
  - `bash tests/smoke.sh` exits 0;
  - `claude plugin validate ./plugin` prints "✔ Validation passed";
  - `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Review
The hubnode's fresh review of c0bcd51, at tier 2 and effort 2, had three findings, none blocking.
All three were taken in f82aed0, each with a smoke case, so there are no DEFERRED rows.
1. **Should-fix: this repo's removed id fell through to another log.** A plain id this repo had
   superseded and removed matched an unrelated live entry with the same number in another log,
   since both default to `D-`. Fixed: before the other logs are searched, this repo's log and
   history are checked (`holds_now` from HEAD, then `removed_entry`). An id that was ours is
   refused, naming what holds now. PASS "touches: --peers on an id this repo superseded
   refuses, naming what holds now, not another log's same number".
2. **Optional: an unread `<repo>/` log was reported as a missing entry.** Fixed: it is refused as
   `<repo>'s log was not read for peers`, with the `not read:` lines. PASS "touches: --peers on
   <repo>/<id> whose log wasn't read says so, not that the entry is missing".
3. **Optional: a superseded id in another log was refused as "no live entry".** Fixed: it starts
   from the successor through `holds_now` on that log's text, and prints that it hopped. PASS
   "touches: --peers on an id another log superseded starts from its successor, and says so".
   Limit: a chain whose middle entry was also removed isn't followed, since the metarepo cache
   has no git history.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (§ Peers: one sentence saying where `--peers` may start and what `<repo>/<id>` picks), with the `--peers` help.

## Shared files changed
- `plugin/templates/jig/jig.py`:
  - the new `start_entry` picks the starting entry;
  - `cmd_peers` reads the logs itself, so it has their texts for `holds_now`;
  - the `--peers` help.
  `touching()` and fold-in's peers are unchanged.
- `plugin/templates/jig/RULES.md`: one sentence in § Peers.
- `tests/smoke.sh`: ten new cases in `touches`, after the pararepo gate cases and after the
  metarepo `--peers` case.

## Test by hand
In a pararepo synced to its metarepo's pin:
1. Run `jig decision <metarepo id> --peers`. It prints `<meta>/.jig/decisions.md § <id> …` and
   this repo's peers.
2. In a metarepo with registered pararepos, run `--peers` on an id that two of them hold. It is
   refused naming each `<repo>/<id>`. Then run `<repo>/<id>`.

## Left
- The hubnode's: the `marketing/FEATURES.md` row (already written, main checkout only).
- jig's own `.jig/` gets this only through `/jig:update`.
