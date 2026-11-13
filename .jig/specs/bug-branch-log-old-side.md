# bug-branch-log-old-side

Source: Maige-Eco hubnode session / 2026-11-12 / Claude (Fable 5.2), filed on Dave's word ("Yes, file them") (staged as feedback-maige-ecosystem-2026-11-12-merge-log-conversion.md): the merge-log job cannot land its review fixes on its branch because jig's hook freezes the branch's own unmerged log and refuses its revert.

## Intent
On a job's branch, the log's rules and R6 judge a commit against where the branch left trunk,
not the branch's last commit. A section is frozen once trunk has it, and a branch's commits
pass or fail as their squash would. Trunk is judged as today.

## Why
- Why was a correction to a release section on the job's branch refused? `log_rules()` reads its old side at `base(trunk)`, which is HEAD on a branch. `frozen_problems()` freezes every `## v` section it finds there.
- Why does a converted entry then need `Touches:`? `touches_problems()` exempts converted entries only while the old side has none and `migrating_log()`, also read at HEAD, sees old files there. After A, neither holds.
- Root: "what trunk has" is read at the branch's last commit. R3's log rule and M3 read it where the branch left trunk. The log rules and R6 don't.

## Givens
Line numbers hold: `git hash-object plugin/templates/jig/jig.py` is the report's `1a8efef0e75c`.
- `[seen]` Reproduced in a throwaway metarepo with `CHANGELOG.md` (v0.1.0, v0.2.0) and a 3-row register. Job `ml` ran `--apply --merge-log` and committed it (A). Each of these commit-B edits on `ml` was then refused:
  - D-002's status line in `## v0.2.0`: "release v0.2.0 is frozen …" and "M2 … D-002 names no page it touches".
  - `### Changed` added above v0.2.0's change line: the same two.
  - The converted D-003 under Unreleased, retitled: "M2 … names no page it touches".
- `[seen]` The same three edits pass today's hook when they are folded into commit A. Refusing them in B protects nothing that a squash doesn't already get past.
- `[seen]` `git revert --no-commit A` then `git commit` was refused, with a counter on the register's rows. The refusals were "decision log: it is never deleted", "R6 this change takes decision 001 … holds no decision", and "R3 .jig/decisions.md: a job adds to the log …". The report relayed R3 and R6. The never-deleted line has the same cause: `log_rules()` reads its old side at HEAD.
- `[seen]` A plain `git revert A` commits without running pre-commit (git's sequencer doesn't run it). It passed, while `jig check --staged` refused the same index. A test has to stage the revert and then commit it.
- `[seen]` It isn't only a migration problem. Set-up: a plain repo released v0.1.0 with D-001 and D-002. Job `su`'s commit A adds D-?str `Supersedes D-001.` and removes D-001, as RULES.md asks. Two follow-ups on the branch are both refused "release v0.1.0 is frozen": reverting A, and correcting A to supersede D-002 instead. With a counter `^### D-(\d+)` over the log, R6 also says "takes decision 001". Against the merge base, the first is a no-op and the second an allowed supersede.
- `[seen]` R3's log branch (457–464) passes only when the staged log is non-empty. Removing a log that the merge base doesn't have is refused.
- `[seen]` RULES.md already uses trunk as the reference. R6: "exist where trunk had none". R3: a job changes "a line it added itself". Touches: "An entry already on trunk … passes until it changes, and so do the entries `jig update --merge-log` converts". `touches_problems()`'s docstring: "An entry as trunk has it". The code reads HEAD.
- `[seen]` `jig release` refuses off trunk ("release from main"). So the only `## v` sections a branch can write that trunk doesn't have are the converter's.
- `[seen]` Prototype, in a scratch copy of `jig.py`. A helper returns `git merge-base trunk HEAD` on a branch and `base(trunk)` otherwise. `log_rules()`'s old side, `migrating_log()` and `reserved_refusals()` read at it, and R3's log branch passes a log absent at both ends. Results:
  - Every commit-B case and revert above passes.
  - These are still refused: a new entry with no `Touches:`, an edit to D-002 that trunk released, dropping D-002 with nothing superseding it, and deleting a log trunk has.
  - On trunk after `jig merge ml`, the status-line edit is still refused as frozen.
  - Full smoke in a clone with the prototype: 1038 PASS, 0 FAIL, exit 0.
- `[relayed]` Maige-Eco's messages as the report quotes them. That repo is read-only here and was not reread.
- `[assumed]` Maige-Eco has no `docs/` pages, so no `Touches:` answer was possible there (the reporter's `[seen]`). The fix doesn't depend on it.

## One layer up
- R3's log rule (458) already reads the log at `git merge-base trunk HEAD`. M3 is "judged on the branch since it left trunk" (`bug-m3-per-branch`). `log_rules()`, `migrating_log()` and R6 are the siblings that read HEAD.
- `base()` already judges a merge of trunk against trunk, through `MERGE_HEAD` or trunk under `pre-merge-commit`. So a sync's merge commit on this branch is already judged against trunk's log. Only ordinary commits read HEAD. `[seen, in code]`
- `bug-r3-log-merge` isn't built yet (458 is unchanged). It makes R3's log rule use `base(trunk)` during a merge of trunk, which is the same choice as this helper's first branch.

## Workaround or correction
Correction. Add one helper beside `base()` (name open, e.g. `since_trunk`). It returns:
- `base(trunk)` while a merge of trunk is in progress,
- `git merge-base trunk HEAD` on a branch other than trunk,
- HEAD on trunk, or on a detached HEAD, which keeps the gate's scratch checkout as it is today.

It replaces `base(trunk)` as `log_rules()`'s old side (released sections, Touches, never deleted), as `migrating_log()`'s before, and as `reserved_refusals()`'s base (R6). R3's log branch also passes a change when the log is absent both there and in the index. The freeze names trunk: `release v0.2.0 is frozen on main: …`.

## Done when
- [ ] Smoke, symptom gone. Set-up: in a metarepo job, commit A runs `--apply --merge-log` over a `CHANGELOG.md` with a release and over a register. Each of these then passes the hook as commit B, and each is refused today:
  - B changes a status line in that release.
  - B adds `### Changed` above the release's change lines.
  - B retitles a converted entry that has no `Touches:` line.
- [ ] Smoke: on that branch, `git revert --no-commit A` then `git commit` passes, with a counter on the register's rows. No R3, no R6, no never-deleted.
- [ ] Smoke, fix fires beyond migration. Set-up: in a plain repo, a job's commit A supersedes a released D-001. Reverting A (staged, then committed) passes. Correcting A to supersede D-002 instead passes. With a counter over the log, neither gets an R6.
- [ ] Smoke: still refused on a branch. Editing an entry trunk released. Removing a released entry nothing supersedes. Deleting a log trunk has. A new entry with no `Touches:`.
- [ ] Smoke: on trunk after the job merges, B's status-line edit is refused with `release v0.2.0 is frozen on main`.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.
- [ ] `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin tests` finds nothing new.

## Out of scope
- A repo that runs `--merge-log` on trunk (a plain repo may). Its sections are trunk's from that commit and stay frozen, as today.
- `git revert`, `cherry-pick` and `rebase` commit without the pre-commit hook. That is git's behaviour, and this spec doesn't change it. The gate's scratch merge still judges the branch.
- Bugs 1–3 and the report's "Also seen" lines are in `bug-merge-log-conversion`.

## Touches
- `plugin/templates/jig/jig.py`: the helper beside `base()`, `log_rules`, `migrating_log`, R3's log branch in `check_rules`, `reserved_refusals`, and the trunk name in `frozen_problems`' message.
- `plugin/templates/jig/RULES.md`: one sentence in Decision log, **Checked**. On a branch, the log is judged from where the branch left trunk, as M3 is. A section is frozen once trunk has it. R3's and R6's text already say "trunk".
- `tests/smoke.sh`: `sec_decisions` (the migration cases) and `sec_supersede`.
- `marketing/FEATURES.md` (main checkout only): the R6 row ("the base had no match" becomes where the branch left trunk), and the Decision log row (frozen once trunk has it).

## Alternatives considered
- A flag on the commit or the job that lifts the freeze — rejected because a branch could weaken the rule it is judged by, and the hook runs trunk's checker "so a branch cannot weaken its own rules" — this reason is [seen] (the hook's header).
- Ask for the log right in one commit — rejected because a review exists to find what the first commit got wrong, and the hook already takes the same edits squashed into it — this reason is [seen].
- Special-case a commit that restores trunk's files exactly, as the report also proposes — rejected because the plain-repo correction (supersede D-002 instead) is no revert, and a byte-compare to trunk would be a second reference point beside the merge base — this reason is [seen].
- Judge against trunk's tip, not the merge base — rejected because a branch that hasn't synced would read trunk's newer release as removed (`frozen_problems`: "release … is gone") — this reason is [seen].
- Move only `frozen_problems` and `touches_problems`, the report's ask, and leave R6 reading HEAD — rejected because the plain-repo revert hits R6 too, with a counter over the log — this reason is [seen].

## Decisions
- Every log rule and R6 read the same point, so a branch is judged as its squash. No commit can pass what the squash would fail, or fail what it would pass.
- A branch commit that got past the hook (hooks off) is judged again with every later commit that touches the log. That is stricter than today, and it is what judging the branch means.
- Sequencing with `bug-r3-log-merge`: both change R3's log line (458). Whichever lands second uses the other's helper.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
