# Bug: a job synced after its handoff can't be merged or gated as printed

Source: `/jig:feedback` from a repo with parallel jobs (hubnode session), on layout 8, Oct 30
(`jig-feedback-<repo>-2026-10-30.md`). Checked against `plugin/templates/jig/jig.py` at b5ed1cf.

## 1. Why
- Why did `jig merge` refuse? It found files changed between the note's commit and the
  branch, and every one of them came from trunk, through the sync the hubnode skill says to run
  after each merge.
- Why does that count? `cmd_merge` takes `git diff --name-only <note commit> <branch>`, which
  compares trees, so it can't tell trunk's changes brought in by a merge from the job's own.
- Root: the check compares trees. RULES.md's principle, "what trunk brought in is not the
  job's", is followed by the hooks (`AUTO_MERGE`) and not by `cmd_merge`. The gate's recipe has
  the same split: it merges trunk with plain `git merge`, while `jig sync` merges with
  `resolve_appends`. So a conflict in an append file stops the gate and not the sync.

## 2. Givens
- `[seen]` `cmd_merge`: `since = git("diff", "--name-only", <note commit>, branch)`, minus
  `.jig/handoffs/`. Its refusal tells the user to hand off again, or merge by hand.
- `[seen]` Hubnode skill: "Run `jig sync` in every open job's worktree that is clean" after a
  merge. So every synced job hits this refusal, and needs a new note, review and gate with
  nothing of its own changed.
- `[seen]` `cmd_gate` prints `git worktree add --detach <scratch> <note commit>` then
  `git merge <trunk>`. In the report, that merge stopped on `.jig/ledgers/DEFERRED.md`, an
  append file `jig sync` resolves.
- `[seen]` `resolve_appends` (used by `cmd_sync`) is the procedure both should share.
- `[seen]` A job has one reserved value per counter, and no command adds one to an open job.
  The hubnode edited `jobs.json` by hand. The trigger, `### 33.5` under an existing section, is
  no longer refused once `bug-r6-take.md` lands, but a job can still need a second section.

## 3. One layer up
- Sibling: `bug-r6-m5-decisions-dest.md` teaches M5 that a commit adding only `.jig/handoffs/`
  after a reviewed commit changes nothing reviewed. This is the same question ("did the job
  change since what was checked?") asked by `cmd_merge`, and the two should share one answer.
- Existing pattern: `cmd_sync`'s merge of trunk with the append rule.

## 4. Correction
One function, `changed_since(note_commit, branch)`, answers what the job did after its check:
- Files from the first-parent, non-merge commits in `note..branch`, minus `.jig/handoffs/`.
- For each merge of trunk in that range (the second parent reachable from trunk): nothing, when
  its tree equals a re-merge of its two parents by the sync procedure (`git merge-tree` plus
  `resolve_appends`). Otherwise, the files where they differ.

`cmd_merge` and M5's handoff exception use it. `jig gate` sets up the scratch checkout itself,
merging trunk by the sync procedure, and prints only the check to run there and the cleanup.

`jig reserve <job> <counter>` gives an open job the next number by the same rule as
`open --reserve`. A job may then hold several values of one counter, and R6 already reads a set.

## 5. Spec

### Done when
Smoke:
- [ ] A job hands off. Trunk moves, appending to an `append_files` file the job also appended
      to. `jig sync` in the job resolves it. `jig merge <job>` then succeeds with no new
      handoff.
- [ ] A commit of the job's own after the note (not a sync) makes `jig merge` refuse, naming
      that commit's files.
- [ ] A sync merge whose resolution adds an edit the sync procedure wouldn't make makes
      `jig merge` refuse, naming the file.
- [ ] `jig gate <job>`, with that append conflict between trunk and the note commit, leaves a
      scratch checkout with trunk merged and no conflict, and prints its check command.
- [ ] `jig reserve <job> section` adds the next free number to an open job's reservation, R6
      accepts either number on that job's branch, and a second `jig reserve` hands out the next
      one. It refuses a job that isn't open, and a counter with no `pattern`.
- [ ] Hubnode skill: after a merge, sync the clean jobs, and use `jig reserve` (not a hand edit)
      for another number. RULES.md Commands lists `jig reserve`.
- [ ] Smoke passes, and the validator passes.

### Out of scope
- Changing when the hubnode syncs.
- Re-gating automatically.

### Touches
`plugin/templates/jig/jig.py` (`cmd_merge`, `cmd_gate`, a `changed_since` helper shared with
M5, `cmd_reserve`, jobs' `reserved` allowing a list), `plugin/templates/jig/RULES.md`,
`plugin/skills/hubnode/SKILL.md`, `tests/smoke.sh`, and a `marketing/FEATURES.md` row for
`jig reserve`.

Build with `bug-r6-m5-decisions-dest.md`, since both change what counts as "since the check".
Build after `bug-r6-take.md` or with it: both touch `reserved_refusals`.

### Alternatives considered
- Exclude merge commits from the check altogether. Rejected: a merge's resolution can carry the
  job's own edit (an evil merge), and that would merge unchecked. `[seen]`: the report's third
  test.
- Gate the branch head when only syncs and notes follow the note. Rejected: it gates a commit
  no review recorded, and leaves the recipe's plain merge broken for the other cases. `[seen]`:
  `jig handoff` names the reviewed commit.
- Keep the plain `git merge` in the printed recipe and document the append conflict. Rejected:
  the gate would then check a merge that the sync resolves differently. `[seen]`: the conflict
  in the report.
- Allow hand edits of `jobs.json` for reservations. Rejected: nothing then checks the number is
  free. `[seen]`: `open --reserve` computes it from trunk and open jobs.

### Decisions
- Owner, Oct 30: the hubnode's session must not block. `jig gate` prepares the scratch checkout
  and prints the check. It never runs it. The hubnode skill hands that check to a spawned
  subnode (see `workflow.md`), which runs it in the scratch checkout and reports the exit code
  and output. The hubnode then marks the job gated or not. Whoever runs it, it is the same
  deterministic command.
