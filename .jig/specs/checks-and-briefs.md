# Two levels of check, a record of the complete one, and the role and briefs that use them

Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "A session that ends a turn, for any reason, starts the full check."
Source: jig hubnode session / 2026-11-13 / Dave with Claude (Opus 5.5) (staged as feedback-jig-2026-11-13-workflow-not-followed.md): "My workflow did not run a check or review like smoke 3-4 times per job, that's insane."
Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-job-flow-speed.md): "why are these taking so long?"
Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "The owner believed jobs ran on a server ("My mac can't run fable")."

Consolidated on 2026-11-13, on the owner's word, from `check-levels` and `role-and-briefs`: both
change the check step and the hubnode's briefs for it, so they build, review and gate as one job.

## Intent
A repo has a quick check (`check.sh`, run on every stop and while working) and a complete one
(`check.sh --full`), and only the check step runs the complete one: once per gate, or once on
trunk after a batch of merges. `jig checked` records each complete run, `jig mark gated` needs
that record, and a failed batch check names the merge that broke it in a few cheap runs.

A session in a jig repo is told its role (`/jig:hubnode` or `/jig:subnode`) at startup, on
resume and after compaction. The hubnode briefs each step from a template that says which
tests the step runs, and reads a session's settings from the host rather than from the
session's own report of its effort.

## Done when
### Check levels
- [ ] The template `check.sh` takes `--full`: with no argument it runs the quick part, with
      `--full` both parts. Its header says which runs where, and no longer says `jig gate`
      runs the suite. A smoke run of the template with and without `--full` shows each part's
      marker line.
- [ ] `jig gate J` prints `(cd <scratch> && ./.jig/scripts/check.sh --full)`, then the check
      step's tier and effort as `jig workflow` gives them (a repo override shows its numbers),
      then `jig checked --tier N --effort N --seconds <s>` and `jig mark J gated`. Smoke.
- [ ] `jig checked --tier N --effort N --seconds S` records HEAD, the numbers, the seconds and
      the date in `<git-common-dir>/jig/checked.log`. A record whose numbers differ from the
      check step's prints a warning naming both. Smoke.
- [ ] `jig mark J gated` with no `jig checked` record for the gate checkout's commit is refused,
      naming `jig checked`. A record for an older commit is refused too. After `jig checked`
      in the checkout, it passes and removes the checkout as today. Smoke.
- [ ] `jig mark J gated --batch` passes with no record, and writes `"check": "batch"` to J's
      entry. `jig merge J` then adds a `Check: batch` trailer to the merge commit. Smoke.
- [ ] `jig release` refuses while a first-parent merge on trunk since the last `jig checked`
      on trunk carries `Check: batch`, naming the merges. After `check.sh --full` and
      `jig checked` on trunk HEAD, it passes. `--force` still overrides. Smoke.
- [ ] `jig checked --trace` on trunk lists the first-parent merges since the last checked trunk
      commit, oldest first, and prints the `git bisect` commands (`--first-parent`, good = the
      last checked commit, bad = HEAD) that run only a given failing command at each step.
      Smoke: three batch merges, the second breaks a marker test; the printed bisect run names
      the second merge.
- [ ] The plugin's Stop hook (`plugin/scripts/check.sh`) skips the run when the working tree,
      untracked files included, is the tree it last passed in this worktree. The key comes from
      a temporary index and `git write-tree`, never touches the real index, and is stored under
      the worktree's git dir. It also skips when the only changes from HEAD are `.jig/jobs.json`
      or `.jig/staging/`. Smoke: stop twice with no change between them, and the check runs
      once. Touch a file, and it runs again.
- [ ] The Stop hook appends the level, seconds and exit code of each run it makes to
      `<git-dir>/jig/check.log`. `jig status` prints the last complete check's seconds and date,
      from `checked.log`. Smoke.
- [ ] `jig update` lists, as a repo file to review, a `.jig/scripts/check.sh` that never reads
      `--full`, and says what to split. Smoke.
- [ ] RULES.md § Workflow names the two levels, `jig checked`, and the batch rhythm: gated jobs
      (`--batch`) merge in sequence with `jig sync` between them, then one `--full` run on
      trunk and `jig checked` before a push or release. A single job keeps its own gate check.
- [ ] The hubnode skill says to run one check session at a time, and to run a post-merge check
      on trunk only for a batch. The subnode skill and the kickoff say: while working, run
      `check.sh` and the parts the change touched, never `--full`.

### Role and briefs
- [ ] The plugin has a SessionStart hook (startup, resume, compact). In a fixture repo's trunk
      checkout with an open job or a staged file, it prints one line telling the session to
      run `/jig:hubnode` before anything else. In that job's worktree it names `/jig:subnode`
      and the job. In a repo with no `.jig/`, or one with no open job and nothing staged, it
      prints nothing. It exits 0 in every case and never writes a file. Smoke runs the script
      in each fixture with each matcher's input.
- [ ] The hubnode skill has a brief template for each of execute, fix, review, recheck (the step
      `cheaper-rounds` adds; its template lands with that job) and check. Each opens with the `running` line and says what the step
      runs: execute and fix run `check.sh` and the parts their change touched, never `--full`;
      review and recheck rerun no check the builder's report shows for the same commit; check
      runs `check.sh --full` once, in the checkout `jig gate` printed, then `jig checked`.
      `grep -n -- "--full" plugin/skills/hubnode/SKILL.md` finds it only in the check template
      and the batch rule.
- [ ] The `running` line: the brief carries `running <model> at <effort>` (the configured
      settings); a session's first reply gives `running <model>`, read from its own settings,
      and no effort. The hubnode checks effort with the host's readout of that session when the
      host has one, and records the configured numbers with `--tier` and `--effort`. A self-read
      the host contradicts is never a mismatch. The review and subnode skills say the same.
- [ ] When the host refuses to start a session on this turn, the hubnode skill says: offer it to
      the owner to start instead, and never run the step in this session.
- [ ] Before opening more than one job, the hubnode says in one line that each job's commands
      and checks run on this machine, with the last complete check's time from `jig status`
      (above), and that jobs may run in the cloud only if the owner asks and the repo
      has a remote.
- [ ] This repo's AGENTS.md no longer says to run the smoke test yourself; it says: while
      working, `check.sh` and the smoke sections you touched; the full suite is the check
      step's, once per gate or batch. The template AGENTS.md says the same in generic terms.

### Both
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin`, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A machine-wide lock on checks, reusing the gate checkout across re-gates, a required `--ran`:
  the owner's "not now".
- This repo's own `.jig/scripts/check.sh` gains its `--full` branch (smoke and the validator)
  when `/jig:update` lists it, run by the owner.
- Splitting any adopting repo's tests: each repo does its own, listed by `jig update`.
- jig running a check: it still records and refuses, nothing more.
- Enforcing which model a session runs on: jig records configured numbers, and the host
  decides.
- A `jig wait <job> <state>` command and per-turn wake-ups: noted in the job-flow report, not
  taken now.
- Making `--ran` required: the owner's "not now".

## Touches
- `plugin/templates/jig/jig.py` (`cmd_gate`, `cmd_mark`, `cmd_merge`, `cmd_release`,
  `cmd_status`, `cmd_update`'s repo-file list, a new `cmd_checked`, the parser)
- `plugin/templates/jig/scripts/check.sh`
- `plugin/scripts/check.sh` (the Stop hook)
- `plugin/templates/jig/RULES.md` § Workflow, § gate
- `plugin/skills/hubnode/SKILL.md`, `plugin/skills/subnode/SKILL.md`,
  `plugin/skills/release/SKILL.md`, `plugin/skills/init/SKILL.md`
- `tests/smoke.sh` (a new `check-levels` section)
- `plugin/hooks/hooks.json`, a new `plugin/scripts/session-start.sh`
- `plugin/skills/hubnode/SKILL.md`, `plugin/skills/subnode/SKILL.md`,
  `plugin/skills/review/SKILL.md`
- `plugin/templates/AGENTS.md`, this repo's `AGENTS.md`
- `tests/smoke.sh` (a new `role-line` section)

## Alternatives considered
- One script with a `--quick` argument for the hook — rejected because a repo that never splits
  would keep running its complete check on every stop; quick by default fails safe — [seen] in
  adventure-studio's report: 429 s stops against a 300 s hook limit.
- A second script for the complete check — rejected because the two parts share setup, and two
  files drift — [assumed].
- Keying the Stop skip on `git status --porcelain` plus `git diff` — rejected because it misses
  a changed untracked file's content; a temp-index `write-tree` hashes everything git would
  commit — [seen] in git's docs for `GIT_INDEX_FILE`.
- A per-job check after each merge in a batch — rejected because the batch's one run tests the
  combined trunk, which is what lands, and `--trace` finds a breaking merge in log2(N) runs of
  one failing command — [assumed]: the bisect cost holds for a deterministic failure only.
- A machine lock now — rejected by the owner: one check session at a time is the hubnode's rule.
- The role line in `AGENTS.md` — rejected because AGENTS.md is read once and lost to compaction,
  which is when this session drifted, and templates must stay tool-agnostic — [seen] in this
  session: the skill was unloaded after compaction until the owner's memory note.
- A hook in `plugin/templates/` — rejected because hooks there are git hooks; a session event
  is the plugin's — [seen] in `plugin/hooks/hooks.json`.
- Keeping effort in the self-read and retrying on a mismatch — rejected because sessions read
  "40", "10" or a stale "low" after a raise, and the host's readout said otherwise — [seen] in
  three reports and this session's addendum.

## Decisions
- Calls the owner made on 2026-11-13: the record is gate-only (no record at handoff); levels by
  argument, `--full`; `mark gated` requires the record; no `--ran` on `jig checked`.
- Interpreted: the record holds tier and effort numbers, not a model name, so `jig.py` stays
  tool-agnostic; the hubnode maps them through `tiers.json`.
- Interpreted: batch tracing uses `git bisect --first-parent` (git 2.29+) over merges; jig
  prints the commands, it doesn't run them.
- Interpreted: `Check: batch` lives in the merge commit, so the owed batch check is derived from
  trunk's history and needs no new state file.
- Calls the owner made on 2026-11-13: memory refresh comes from a SessionStart hook including on
  compact; drop effort from the self-read; review stays at 2/2.
- Interpreted: the hook prints only when there is hubnode or subnode work (an open job, a staged
  file, or a job worktree), so a solo repo with no jobs sees nothing.
- Interpreted: "the host's readout" is named generically in the skill text, with the Claude app's
  session readout as the example, since skills are the plugin's and may name the host.
- Consolidated: one job for both, the owner's call on 2026-11-13.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
