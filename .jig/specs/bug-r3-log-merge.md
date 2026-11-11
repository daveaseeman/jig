# bug-r3-log-merge

Source: Adventure-Studio hubnode session / 2026-11-11 / Dave, with Claude (staged as feedback-adventure-studio-2026-11-11-sync-log-and-names.md): "`jig sync` in a job refuses R3 when trunk edited the decision log in place"

## Intent
While a merge of trunk into a job is being finished, R3's decision-log check asks whether the
result lacks a line that trunk's log has. It doesn't compare against the job's fork point. What
trunk rewrote is trunk's, not the job's. The gate's scratch merge and `jig merge` follow the same
rule.

## Why
- Why was the sync refused? R3's log check saw a line outside `## Open` disappear: trunk had
  rewritten an unreleased entry's body after the job branched.
- Why did it read as the job's deletion? It compared the merged result with
  `merge-base(trunk, HEAD)`. During a merge of trunk, HEAD is still the job's tip, so that is the
  old fork point.
- Why only the log? Every other R3 path is judged through `base(trunk)`, which returns trunk (or
  `MERGE_HEAD`) while a merge of trunk is in progress, as RULES.md says: "what trunk brought in
  is not the job's".

## Givens
- `[seen]` jig.py ~458: `since = git("merge-base", trunk, "HEAD") or base(trunk)`. `merge-base`
  always answers, so the fallback never runs.
- `[seen]` `base()` (~262) returns trunk under `AUTO_MERGE` (pre-merge-commit), or `MERGE_HEAD`
  when it is trunk's, and HEAD otherwise.
- `[seen]` Trunk may edit an unreleased accepted entry in place. Only released sections are
  frozen.
- `[assumed]` The refusal and sequence as the report gives them. The reporter didn't reproduce
  it in a scratch repo, and this spec's smoke does.
- `[assumed]` The gate's scratch merge runs the same hook against a HEAD at the job's tip, so it
  has the same bug. The smoke checks it.

## Design
- In R3's log branch: when `base(trunk)` isn't HEAD (a merge of trunk is in progress, either
  path), compare the result against that base's log. The result may not lack a line outside
  `## Open` that trunk's log has. Lines the job added (and keeps) can't be missing from trunk's
  log, so they need no exception. Otherwise keep the fork-point comparison, which covers a job
  adding its entry over several commits.
- The removals that `decision-remove-superseded` and `update-project-sweep` allow (supersede,
  `### Removed`) are judged the same way against that base.
- RULES.md, R3's log sentence: one clause saying a merge of trunk is judged against trunk.

## Done when
- [ ] Smoke: open a job. On trunk, rewrite the body of an accepted entry under `## Unreleased`.
  In the job, append an entry under `## Open` and commit. `jig sync` in the job merges with no
  R3 (the reported symptom gone).
- [ ] Smoke: the same, but the job's commit deletes a line of an accepted entry that trunk still
  has. The ordinary commit is refused R3, and so is a sync merge carrying that deletion.
- [ ] Smoke: `jig gate` and `jig merge` pass on the first case's job.
- [ ] The smoke covers both the `MERGE_HEAD` path (a merge stopped on a conflict elsewhere and
  then committed) and the `pre-merge-commit` (`AUTO_MERGE`) path.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Renaming the job's sync (the same report, part 2): spec `rename-job-sync`, once the owner
  picks the name.
- Rebasing as a way to take trunk. Syncs are merges.

## Touches
- `plugin/templates/jig/jig.py` (R3's log branch)
- `plugin/templates/jig/RULES.md` (R3)
- `tests/smoke.sh`

## Alternatives considered
- Rebase the job instead of syncing, as the reporter did. Rejected: it rewrites history, and
  RULES.md's merge rules assume syncs are merges. Reason is [seen: the report and RULES.md].
- Skip the log check during any merge. Rejected: a sync merge could then carry a job's own
  deletion of trunk's line. Reason is [seen: Done-when 2's case].

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
