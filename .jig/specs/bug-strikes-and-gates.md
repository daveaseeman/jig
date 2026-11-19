# Bug: three gaps in the strike limit and the gated state

Source: the owner, jig hubnode session, 2026-11-16: "start the deferred rows". Three findings that reviews deferred on 2026-11-16, each reproduced by its reviewer or seen in this session:
- rig's last review-change (c7165a3): "`waiting_specs` skips any spec matching `^Bug-for:[ \t]*\S`, looser than `bug_spec_for`'s `^Bug-for: <job>\s*$`; a spec quoting the line in a fenced example drops out of `jig rig`, `jig consolidate` and `jig open`'s overlap refusal" (DEFERRED.md, rig).
- bug-strike-count's review-work (ea5d2f4): "A committed `Bug-for: <job>` spec clears the strike limit for every later part of the job, so strikes are unlimited after it" (DEFERRED.md, bug-strike-count).
- The hubnode, every-copy's fix after its first gate: the board still said gated while new commits sat on the branch, and `jig next every-copy` printed "merge — hubnode … on the owner's word". `jig merge` refuses that state ("has changed since the commit … names: hand off again and gate that"), so nothing unreviewed could merge; `jig next` named a step that would be refused.

## Intent
A spec counts as a bug spec only by the same line `jig reviewed` reads; a bug spec lifts the
strike limit only for the part it was written for; and `jig next` never names merge for a job
`jig merge` would refuse for changes since its note.

## 1. Why
1. Why can a quoted line hide a spec? `waiting_specs` (jig.py ~1292) matches any `Bug-for:`
   with text after it, anywhere, fences included; `bug_spec_for` (~2088) wants
   `Bug-for: <job>` on a line of its own. Two readers of one line disagree. [seen]
2. Why are strikes unlimited after a bug spec? `cmd_reviewed` refuses only while no
   `Bug-for: <job>` spec exists on HEAD or trunk (~2117), and once committed it exists
   forever. The count is per part; the spec that clears it isn't. [seen]
3. Why did `jig next` say merge? `next_step` returns merge for any job whose state is gated
   (~2155), without the check `cmd_merge` makes (`changed_since` the note's commit, ~1651). [seen]

## 2. Givens
- [seen] The three code sites above, and RULES.md's waiting-spec sentence (~64) and strike
  contract (~678).
- [seen] `blocking_reviews` cuts the chain at the first commit adding a handoff note, so a
  part begins after the last note; smoke `next` has jobs k..k6 for the strike cases.
- [seen] A bug spec for a job is committed on the job's branch (bug/SKILL.md), and reaches
  trunk only when the job merges.

## 3. One layer up
- `waiting_specs` and `bug_spec_for` are the two readers of `Bug-for:`; after this, one rule
  (a shared helper) serves both. [seen]
- `next_step` and `cmd_merge` both decide whether a gated job can merge; after this they use the
  same `changed_since` test. [seen]

## 4. Correction
1. One reader of `Bug-for:`: a line of its own, `Bug-for: <name>` where the name is a job name
   (no `<`, `>` or spaces), outside fenced code. `waiting_specs` and `bug_spec_for` both use it.
2. A bug spec clears the limit for one part: `cmd_reviewed` and `next_step` accept a
   `Bug-for: <job>` spec only if a commit of the current part (on the job's first-parent chain
   after the part's last handoff note, merges aside) added or changed it, it names the job at
   the part's tip, and it did not name the job at the part's base (the commit before the
   part's first), a `git mv` read under its old path. A draft that gets its line later in the
   part counts; a line removed later doesn't; an earlier part's spec, edited or moved, doesn't.
   A later part that reaches three strikes needs a new one, at a new path, and the refusal
   says so when an earlier part's spec names the job.
3. `next_step` for a gated job whose branch changed since its newest note's commit doesn't name
   merge: it names the step the branch would get ungated (review-change, then handoff), with
   the reason "gated at <commit>, changed since: mark it back; review-change, handoff, gate
   again". `jig merge` is unchanged.

## Done when
- [ ] Smoke `next`: a spec quoting `Bug-for: <job>` inside a fenced block, and one with
      `Bug-for: x y`, are waiting specs (`jig rig --json` lists them, `jig consolidate` groups
      them on overlap); a spec with `Bug-for: k` on a line of its own is not. Each FAILs at
      v0.14.0 where the old match differs.
- [ ] Smoke `next`: a job reaches 3 strikes, commits its bug spec, records more reviews (part
      1), hands off with `--partial`, then records 3 blocking reviews in part 2: the fourth
      review of part 2 is refused naming `Bug-for`, and `jig next` names bug. FAILs at v0.14.0
      (the reviewer's reproduction: part 2 counted strikes 1 to 4 with no refusal).
- [ ] Smoke `next`: in part 2, ticking a box in part 1's bug spec, or moving it, leaves the
      fourth review refused, the refusal asking for a new path; a part-2 spec at a new path
      lifts it. A draft given its `Bug-for:` line in a later commit lifts it; the line removed
      later doesn't.
- [ ] Smoke `next`: a job marked gated, then given a new commit on its branch, makes `jig next`
      name review-change with "gated at <commit>, changed since: mark it back", not merge; with
      no new commit, it still names merge.
- [ ] RULES.md's waiting-spec sentence and strike contract say a bug spec counts for the part
      it was written in, by a line of its own.
- [ ] `.jig/scripts/check.sh` exits 0; `bash tests/smoke.sh next workflow rig consolidate`
      passes; `claude plugin validate ./plugin` passes. The full suite runs once at the check
      step.

## Out of scope
- The drawing's `bug → spec ⇢ Job` (DEFERRED, roles-and-flows, optional): unchanged.
- Changing the board state when a gated job gets a commit: `jig next` reports it, and `jig merge`
  already refuses it; the hubnode marks the job back by hand, as now.
- Jobs already past a bug spec on this machine: the new rule applies to the next `jig reviewed`.

## Touches
- `plugin/templates/jig/jig.py` (`waiting_specs`, `bug_spec_for`, `cmd_reviewed`, `next_step`)
- `plugin/templates/jig/RULES.md` (The board: the waiting-spec sentence; Workflow: the strike contract)
- `tests/smoke.sh` (`next`)
- `.jig/ledgers/DEFERRED.md` (the two rows these answer, marked taken)

## Alternatives considered
- Keep the loose match and document it — rejected because two readers of one line disagree,
  and the looser one hides a spec from the overlap refusal — [seen] (rig's review-change).
- Count a bug spec only if committed after the part's third strike — rejected for one written
  in the part, because the owner's `/jig:bug` may commit one at strike 2 and the fixing goes on
  under it (bug-strike-count's k6 case) — [seen].
- Drop a job from gated when its branch moves — rejected because the board is trunk's and a
  commit on a job's branch can't write it; `jig next` reading the branch is enough — [seen]
  (`next_step` already reads the branch).

## Decisions
- The owner, 2026-11-16: "start the deferred rows".
- Interpreted: a bug spec lifts the limit for the part it was written in (item 2's rule), the
  option the hubnode put to the owner on 2026-11-16 in its narrower form.
- Interpreted: the job name in `Bug-for:` is a token with no `<`, `>` or spaces, so a template
  placeholder never counts.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
