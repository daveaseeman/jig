# Bug: a sync from main brought two readers of `Bug-for:` past the one this job made

Source: the hubnode, 2026-11-19, the third blocking review of bug-strikes-and-gates (review-change
of 8549a87..2b42b3b, raised by the sync merge 5716007 that brought rig-and-versioning in from
main): "B1: `finished_specs` reads `Bug-for:` with its own regex … a waiting spec that quotes
`Bug-for: <job>` in a fence is listed by `jig rig --json`, and `jig rig --close` deletes and
commits it" and "S1: `cmd_open` still calls `bug_spec_for(args.name, [board.trunk])` with
main's old signature, so its guard fires only when that spec is trunk's newest commit".

Bug-for: bug-strikes-and-gates

## Intent
Every reader of the `Bug-for:` line goes through `bug_for(text)`, or `bug_specs_at(rev, job)`
for a spec at a commit, so a quoted line or a `<job>` placeholder is no bug spec anywhere, and
a reader that bypasses them fails the smoke the day a sync brings it in.

## 1. Why
1. Why can `jig rig --close` delete a spec that only quotes the line? `finished_specs` (jig.py
   ~10029) matches `^Bug-for:[ \t]*(\S+)` with `re.M`: fences and `<job>` included. [seen]
2. Why is there a third reader after Correction 1 made one? It came in by the sync 5716007:
   rig-and-versioning (a12af04, 0fd1f4e) wrote it on main against main's two readers. [seen]
3. Why did the sync not flag it, or `cmd_open`'s call? No textual conflict; `bug_spec_for` kept
   its name and arity but now takes a chain, not a list of revs, so the old call runs. [seen]

Why each round found a new hole: rounds 1 and 2 were the part rule's history walk (which
commits touched which spec), each fix closing one edge the reviewer then tested past. Round 3
is a different cause: nothing stops a parallel job from adding a reader, and the job's tests
exercise only the readers it knew of. The process caught it as designed: the review-change
after the sync. [seen]

## 2. Givens
- [seen] jig.py at 2b42b3b: `bug_for` (~1326) reads the line on its own, outside fences, no
  `<`, `>` or spaces; `waiting_specs`, `bug_spec_for` and `bug_specs_at` call it.
  `finished_specs` (~10029) has its own regex; `cmd_open` (~1167) calls
  `bug_spec_for(args.name, [board.trunk])`.
- [seen] `bug_spec_for(job, chain)` reads only specs a commit of `this_part(chain)` touched:
  with `[trunk]` that is trunk's newest commit alone, and none if that commit added a note.
- [seen] `finished_specs` feeds `jig rig --json` ("finished"), `jig rig --close`, and the
  close at `jig merge` (~2069, ~2135) with JOB set, so merging job X closes a spec quoting
  `Bug-for: X` in a fence.
- [seen] Main's jig.py holds three patterns for the line (`waiting_specs` ~1345,
  `bug_spec_for` ~2457, `finished_specs` ~9962); every one starts `^Bug-for`. At 2b42b3b,
  `grep -nE '\^Bug-for|Bug-for:\[' plugin/templates/jig/jig.py` prints two lines: 1332
  (`bug_for`) and 10029 (`finished_specs`).
- [seen] Smoke `rig` (~8171) checks a fenced quote is a waiting spec, not that it is never
  finished; smoke `close` (~8610) commits the leftover spec as trunk's newest commit, the one
  case S1's call still catches.
- [seen] RULES.md ~666 promises `jig open` refuses a name whose earlier job's `Bug-for:` spec is
  still on trunk, "which would lift the new job's strike limit". Under this job's part rule it
  wouldn't (the spec names the job at the part's base); the leftover would still be read as the
  new job's: listed in its refusal, closed by its merge as its own.
- [seen] The one other open job, bug-m5-release-level, touches only `tests/smoke.sh`.

## 3. One layer up
- Readers of the line: `waiting_specs`, `finished_specs` (text), `bug_specs_at`, `cmd_open`
  (a rev), `bug_spec_for` (a part). Two entry points serve them all: `bug_for(text)` and
  `bug_specs_at(rev, job)`. [seen]
- The same shape already has a guard: smoke greps jig.py for `finished_specs(` callers (~8700).
  A check that allows one reader of the line is the same kind of check. [seen]

## 4. Correction
1. `finished_specs` reads `bug_for(snap.show(f))` in place of its regex.
2. `cmd_open` asks `bug_specs_at(board.trunk, args.name)` (any spec on trunk naming the job),
   naming the first, sorted. RULES.md ~666's why becomes what is true: the earlier job's spec
   would be read as the new job's.
3. Smoke `next` asserts jig.py reads the line only in `bug_for` and `bug_specs_at`: outside
   them, every line naming `Bug-for` quotes it in backticks, as messages and docstrings do. A
   reader a sync brings in, in any form (a regex, `startswith`, `in`), fails it.

## Done when
- [ ] Smoke `rig`: with a job X off the board, a spec quoting `Bug-for: X` in a fenced block,
      and one with `Bug-for: <job>`, are not under "finished" in `jig rig --json`, and
      `jig rig --close` leaves both files. FAILs at 2b42b3b.
- [ ] Smoke `close`: merging a job X leaves a spec that quotes `Bug-for: X` in a fence; its own
      `Bug-for: X` spec is still closed. FAILs at 2b42b3b.
- [ ] Smoke `close`: `jig open OB` is refused naming the leftover spec and `jig rig --close`
      when a later commit sits on trunk above the one that added it. FAILs at 2b42b3b.
- [ ] Smoke `next`: the one-reader check passes; with main's `finished_specs` line put back, or
      a `startswith` reader spliced in, it fails (shown once in the evidence, not kept).
- [ ] `.jig/scripts/check.sh` exits 0; `bash tests/smoke.sh next rig close consolidate`
      passes; `claude plugin validate ./plugin` passes. The full suite runs at the check step.

## Out of scope
- The three optional findings (rename detection's 50% threshold, the moved gated job's reason
  vs step, the `git mv` check's missing "new path" assertion): polish, deferred by the owner's
  rule; rows in `.jig/ledgers/DEFERRED.md` at handoff.
- The part rule itself (8549a87, 2b42b3b): it meets the job's Intent; unchanged.

## Touches
- `plugin/templates/jig/jig.py` (`finished_specs`, `cmd_open`)
- `plugin/templates/jig/RULES.md` (~666, the open refusal's why)
- `tests/smoke.sh` (`next`, `rig`, `close`)
- `.jig/ledgers/DEFERRED.md` (the three optional findings)

## Alternatives considered
- Drop `cmd_open`'s guard, since the part rule already keeps a leftover spec from lifting the
  new job's limit — rejected because the guard is a merged job's (rig-and-versioning) promise
  in RULES.md, and removing a feature is the owner's call, not a bug fix — [seen].
- Rename `bug_spec_for` so an old-signature call from a sync fails by name — rejected because
  Python finds the name only when the line runs, so it is no stronger than the smoke, and the
  one other open job doesn't touch jig.py — [seen].
- Replace the part rule's history walk with a count (more specs name the job at the part's tip
  than at its base: no `diff -M`, no 50% threshold) — rejected for now because the present rule
  meets the Intent and is twice reviewed; rewriting it invites a fourth round for findings the
  owner calls polish — [assumed]. Worth a DEFERRED row with the optional findings.
- Fix the regex in `finished_specs` alone — rejected because it leaves two patterns to drift,
  which is how this round began — [seen].

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
