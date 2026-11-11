# bug-gate-scratch-left

Source: owner, Nov 11, from a redoc repo's update to v0.10.0. `jig update` refused: "24 worktrees
exist: the twelve job worktrees and the twelve gate scratch checkouts".

## Intent
Nothing is left behind from a gate. The scratch checkout `jig gate` creates is removed by jig
once the job is marked gated or merged. A leftover one never blocks `jig update`: update removes
it on `--apply`, and refuses only if it holds tracked changes.

## Why
- Why did update refuse on gate checkouts? `worktree_refusals` lists every worktree git
  records, and a gate's scratch checkout (`.git/jig/worktrees/gate-<job>`) is one of them.
- Why were twelve of them left? `jig gate` prints `git worktree remove --force <scratch>` for
  the hubnode to run after the checks, and nothing makes anyone run it.
- Why is that jig's to fix? jig creates the checkout and names it, and it is scratch by
  definition. Leaving cleanup to a printed line is a rule with no enforcement behind it.

## Givens
- `[seen]` `cmd_gate` (jig.py ~1588-1608): it creates the checkout with
  `git worktree add --detach .git/jig/worktrees/gate-<job>`, refuses a second gate while one
  is left ("left from an earlier gate"), and prints the remove command.
- `[seen]` `worktree_refusals` (~6280): every recorded worktree becomes a refusal line with
  `git worktree remove`. It doesn't tell a gate checkout apart from a job's.
- `[seen]` `cmd_mark` (~934) and `cmd_merge` (~948) never touch the gate checkout.
- `[seen]` Owner's report: a repo with twelve gated redocument jobs had twelve gate checkouts
  still present.
- `[assumed]` A gate checkout holds no work worth keeping. The checks run there and the job
  keeps its own worktree. setup.sh may leave untracked files (a venv), and that is why `--force`
  is used.

## Design
- **`jig mark <job> gated` removes the job's gate checkout** if it is there. Marking gated
  means the checks ran, so the checkout is spent. Untracked files (setup's) go with it. A
  tracked change there (someone edited in the scratch checkout) refuses the mark and names the
  checkout, since that edit belongs on the job's branch.
- **`jig merge <job>` removes it too** if it is still there, which covers a job merged without
  being marked gated.
- **`jig update` treats `gate-*` checkouts as scratch.** They aren't refusals. The dry run lists
  each as "gate scratch, removed on --apply", and `--apply` removes it. One with tracked
  changes stays a refusal, naming the checkout.
- `jig gate`'s closing lines say that marking gated removes the checkout, in place of the
  hand-run remove command. The hubnode skill drops its manual remove step.
- RULES.md: a gate's scratch checkout lives until the job is marked gated or merged.

## Done when
- [ ] Smoke: `jig gate J`, then `jig mark J gated`, leaves no `.git/jig/worktrees/gate-J`.
  With a tracked edit in the checkout, the mark is refused and names it.
- [ ] Smoke: `jig gate J` and `jig merge J` with no mark leaves no gate checkout.
- [ ] Smoke: a board with a leftover `gate-J` checkout and no open job. `jig update` (dry run)
  lists it as gate scratch and isn't refused for it, and `--apply` removes it. A job's own
  worktree is still a refusal (the reported symptom: update is refused only for the jobs).
- [ ] `jig gate`'s output and the hubnode skill no longer tell anyone to remove the checkout by hand.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Update refusing while jobs are open. That's by design: a job's worktree holds a copy of the
  old `.jig/`, and the owner closes or merges each job first.
- Removing a job's own worktree at merge. The hubnode does that, after looking at it.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_mark`, `cmd_merge`, `cmd_gate`'s closing lines,
  `worktree_refusals` and update's plan)
- `plugin/templates/jig/RULES.md` (the gate)
- `plugin/skills/hubnode/SKILL.md` (the gate step)
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only: the gate row)

## Alternatives considered
- Make update ignore gate checkouts but leave them in place — rejected because they stay as
  clutter and block the next `jig gate` of that job ("left from an earlier gate") — reason is
  [seen: `cmd_gate` ~1591]
- Have `jig gate` run the checks and remove the checkout itself — rejected because jig never
  runs the project's checks (RULES.md: the gate prints them), and the hubnode reads the output
  in the checkout — reason is [seen: `cmd_gate` "jig never runs them"]
- Refuse `jig mark gated` while the checkout exists, so the hubnode removes it — rejected because
  it adds a manual step where jig can do the removal itself, safely — reason is [assumed]

## Decisions
- Removal happens at the state change that says the checkout is spent (gated or merged), and a
  tracked edit always stops it.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
