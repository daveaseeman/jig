# Bug: a reported hang came back after its spec shipped

Source: owner, 2026-11-03, after a subnode's wait loop was found spinning hours after its job
merged. Reopens `bug-smoke-isolation.md`. Owner: why did the spec miss this, and is there a better
pattern than a skill sentence?

## 1. Why
- Why did the loop never end? It waited for two matches to clear that never did: any running
  `bash tests/smoke.sh` (other sessions ran many), and "isolation:" in a log later deleted with
  its worktree. Not itself: macOS `pgrep` skips its own process and its ancestors.
- Why did the agent wait on a pattern? Smoke runs 8½–10 min, at the 10-min foreground limit, so
  agents background it; nothing says how to wait for a background run.
- Why didn't bug-smoke-isolation catch it? Its whys re-diagnosed the hang as a config leak, and
  its Done when proves the leak fix only. Nothing checked the symptom the owner reported.

## 2. Givens
- `[seen]` pid 28194, para-release's session: `until ! pgrep -f "para-release.*smoke|bash
  tests/smoke.sh" … && grep -q "isolation:" para-smoke.log; do sleep 10; done`, still running
  after the job merged and its worktree was removed. Killed by hand.
- `[seen]` `man pgrep` (macOS), under `-a`: pgrep excludes its own process and all its ancestors
  by default. Reviewer, round 1, bounded loops: a lone loop on its own pattern ended; two loops
  at once matched each other's command lines and stuck. Linux `pgrep` excludes only itself.
- `[seen]` The `kill -0 $pid` fallback, reviewer round 1, zsh and bash: in one command the loop is
  itself foreground and hits the same limit; split across commands `$pid` is empty, the loop
  exits at once with the error hidden, and a partial log reads as finished.
- `[seen]` `/jig:bug` writes no `Source:` line, and `/jig:fix` writes specs through `/jig:spec`
  with `Source: <source>`, which is provenance, not the symptom. Review has nowhere to read the
  reported symptom from.
- `[seen]` `bug-smoke-isolation.md` Source names the hang ("a session's wait loop (`pgrep -f
  "tests/smoke.sh"`) could hang on its own command line"). Its Givens call the loop "an agent's
  own shell, not jig code". None of its seven Done when items mentions waiting or the hang.
- `[seen]` Smoke durations, from the gate output files today: 8m36s to 9m50s; a subnode reported
  10m43s under load. An agent's foreground shell command is capped at 10 min (the Bash tool's
  limit), so smoke can't reliably run in the foreground.
- `[seen]` The agent's harness gives a background run an exit notice ("you will be notified when
  it completes — do not poll"). The subnode didn't use it.
- `[seen]` `/jig:bug` step 5: "`Done when` must include an observable that proves the fix fires."
  It says nothing about the reported symptom. Review item 1 checks Done when evidence only.

## 3. One layer up
- **Why the spec missed it.** `/jig:bug` lets the whys move from the symptom to a cause, which is
  its job, but then only asks that the fix for that cause be observable. A spec can fix a real
  cause and leave the reported symptom standing, and review can't see it: review item 1 judges
  against the spec's own Done when. Same shape in every repo that runs `/jig:bug`.
- **The waiting itself.** Sibling: every agent waiting on its own long run (a subnode before
  committing, a gate check, a release). All of them hit the foreground cap with smoke.
- Existing pattern: `/jig:verify` already holds "how to run a check and show it"; the gate brief
  already says where output goes (`gate-<name>.out`). The missing half is how to wait.

## 4. Correction
Two corrections, one per root:
1. `/jig:bug` and `/jig:review` hold the reported symptom: a spec's Done when includes an
   observable that the symptom in the Source no longer happens, or says in Out of scope why it's
   left, so the owner sees it.
2. `/jig:verify` gives the positive pattern for waiting, not just a ban: background a long run
   with its output to a file and act on its exit notice; with no notice, poll its literal pid,
   bounded. Never a match: not a process pattern, not a log line.

## 5. Spec

### Done when
- [ ] `plugin/skills/bug/SKILL.md` step 5: the spec opens with `Source:` naming who reported
      it, when, and the symptom in their words; the spec template has that line; `/jig:fix`
      copies each report's symptom into it.
- [ ] `plugin/skills/bug/SKILL.md` step 5: `Done when` also includes an observable that the
      symptom the report describes no longer happens. If the whys moved to a different cause,
      the spec says what happens to the original symptom; leaving it is an Out of scope line
      with its reason.
- [ ] `plugin/skills/review/SKILL.md` item 1 also asks: does Done when cover the symptom in the
      spec's `Source:` line? A fix spec whose Done when doesn't, and doesn't say why in Out of scope, is
      blocking.
- [ ] `plugin/skills/verify/SKILL.md` Rules gains: a run that can outlast your shell's foreground
      limit goes in the background with its output to a file, and you act on its exit notice;
      where there's no notice, start it with `cmd > out 2>&1 & echo $!` and, in each later
      command, poll that literal pid for less than the limit (`for i in $(seq 50); do kill -0
      <pid> 2>/dev/null || break; sleep 10; done`). Cap the wait at about twice the run's usual
      time, then read the output and report what you see. Never wait on a match: a process
      pattern (it can match another waiter's or another run's command line) or a log line (a
      run that dies early never prints it).
- [ ] `plugin/skills/subnode/SKILL.md` (running the checks), the hubnode's gate brief and its
      "Release and survey" bullet point to that rule.
- [ ] `grep -rn 'pgrep' plugin/skills` finds only the warning.
- [ ] The symptom, replayed by hand once at build: a fresh subagent given only the verify skill
      and "run `bash tests/smoke.sh` and commit once it passes" waits without a match loop, and
      no wait loop is left after it ends (`ps -axo pid,command | grep -E 'until|while|sleep'`
      shows none of its). Its prompt and result are kept for the handoff.
- [ ] `marketing/FEATURES.md` rows for `bug`, `review` and `verify` say so, edited first. Smoke and
      validator pass.

### Out of scope
- Making `tests/smoke.sh` fast enough to run in the foreground. A real gain for this repo's
  gates, but it's this repo's test, not every repo's check; a separate spec if the owner wants it.
- Killing stray loops on a machine: done by hand, once (pid 28194).

### Touches
`plugin/skills/bug/SKILL.md`, `plugin/skills/review/SKILL.md`, `plugin/skills/verify/SKILL.md`,
`plugin/skills/subnode/SKILL.md`, `plugin/skills/hubnode/SKILL.md`, `plugin/skills/fix/SKILL.md`,
`plugin/templates/specs/_template.md`.

### Alternatives considered
- Only the verify sentence, as first proposed ("run it in the foreground … never pgrep").
  Rejected: smoke runs at the foreground limit, so the advice can't be followed here, and it
  leaves the reason the spec missed this unfixed. `[seen]`: durations above; old Done when.
- A done-marker file or lock written by `tests/smoke.sh`. Rejected: it gives agents something to
  poll, which is the bug, and it's this repo's test, not every repo's check. `[seen]`: the loop
  polled a log for "isolation:".
- A hook that refuses Bash commands containing `pgrep -f` in a loop. Rejected: matching shell by
  text is the same fragility as the bug, and a legitimate `pgrep` would be blocked. `[seen]`: the
  real loop combined a process pattern with a log wait, and pgrep's matching differs between
  macOS and Linux (Givens), so no text match on the command catches every shape.
- Leave waiting to the agent. Rejected: that was bug-smoke-isolation's call, and the loop
  recurred a day later. `[seen]`: pid 28194.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
