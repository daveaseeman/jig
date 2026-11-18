# check-queue: a local queue for check runs, with GitHub Actions as the overflow for the complete check

Source: the owner, jig hubnode session, 2026-11-17: "Did we talk about running tests and checks in a remote environment here at some point, because my mac is becoming a bottleneck at some points?"
Source: the owner, jig hubnode session, 2026-11-17: "Can we run on github actions only when my computer gets overloaded past a certain point, is there a way to know because jobs are waiting or something?"
Source: the owner, jig hubnode session, 2026-11-17: "Write the spec"

## Intent
A machine running several jobs at once stops overloading itself. Every test or check run a
role starts takes one of a fixed number of slots, and waits when none is free. When the
complete check finds the queue full, or another complete check already running, and the
owner has said yes to it once, the check role runs it on GitHub Actions instead. `jig checked`
records that CI run for the exact commit, with its URL, only after jig has read the run's
result itself.

What goes to Actions is only the complete check, which runs once per gate or batch. The runs
that overload the Mac most, the work sessions' and reviewers' smoke runs, stay local and wait
their turn in the queue.

## Why (from the session)
- [seen] Everything runs on the owner's Mac today. The hubnode skill says so before opening jobs
  (hubnode/SKILL.md:136–138: "jobs run in the cloud only if the owner asks and the repo has a
  remote"). jig has never built anything else.
- [seen] The load isn't the complete check, which runs once per gate or batch and takes about
  9.5 minutes here (`checked.log`: 565s, 620s). It's the work sessions and reviewers, five or
  more at once, each running smoke sections. `tests/smoke.sh` already runs its sections in
  parallel (`JIG_SMOKE_JOBS`, default the core count, smoke.sh:8003), so overlapping runs
  fight for the same cores.
- [seen] The hubnode skill says the check "runs one at a time on this machine: two complete
  suites at once each run slower than both in turn" (hubnode/SKILL.md:105). Nothing
  enforces it.
- [seen] jig's records live in the local `.git` and never reach a remote: `reviewed.log`,
  `checked.log` (`checked_log()`, jig.py:1496) and `.git/jig/worktrees/`. A cloud session that
  ran `jig checked` would record into its own clone. So a CI result can come home only as a
  record the local `jig checked` writes.
- [seen] The complete check is the step that can leave the machine: it already runs from files
  alone, in a scratch checkout, and needs nothing from a session (check/SKILL.md).
- [seen] The signal the owner asked for, "because jobs are waiting", is queue depth: runs
  holding a slot plus runs waiting for one. It's tool-agnostic, deterministic and testable in
  smoke. Machine load also works (`sysctl vm.loadavg` and `hw.ncpu` on macOS, `/proc/loadavg`
  on Linux), but a browser or a build spikes it, and the right threshold differs per machine.

## Design

### Part 1: the queue (local, no cloud)
1. **`jig queue -- <command…>`** runs the command while holding one slot, and returns its exit
   code. Slots are lock files in `$(git rev-parse --git-common-dir)/jig/queue/`, shared by
   every worktree of the repo. Each is held with an OS file lock (`fcntl.flock`), so a run
   that dies or is killed frees its slot without cleanup. A run that finds no free slot prints
   one line ("waiting for a slot: N running, M waiting") and waits. jig chooses nothing about
   what runs: the command is the caller's.
2. **`jig queue --full -- <command…>`**, the complete check, also takes the single full lock.
   So two complete checks never run at once, which enforces hubnode/SKILL.md:105's rule.
3. **`jig queue`** with no command prints the depth: each held slot with its command, its
   worktree and how long it has run, the waiting runs, and whether a complete check is
   running.
4. **The number of slots**, from the session's formula: the core count divided by the cores
   one run uses. `queue.width` in `.jig/config.json` is the cores one run uses. It defaults to
   1, and `"all"` means the core count. The slots are the core count divided by the width, at
   least 1. `queue.slots`, if set, overrides the computed number. This repo, whose smoke uses
   every core (`JIG_SMOKE_JOBS`), sets `queue.width: "all"`, which gives one slot.
5. **Optional machine-load signal:** `queue.max_load` in `.jig/config.json`, a load average per
   core. When it's set, no new slot is handed out while the 1-minute load per core is above
   it. jig reads it with `os.getloadavg()` and `os.cpu_count()`, which work on both macOS and
   Linux. When it's unset, which is the default, only queue depth counts.
6. **Who goes through it.** The work, review and check roles run their tests and checks as
   `jig queue -- <command>`. Their skills say so, and so do the Commands lines in this repo's
   AGENTS.md. The Stop hook's quick `check.sh` doesn't go through it: the hook has a
   300-second limit (plugin/hooks/hooks.json), and waiting in a queue would make it time out.

### Part 2: GitHub Actions as the overflow, complete check only
7. **The owner's standing yes for check branches only:** `queue.overflow: {"to": "github",
   "reason": "<the owner's words>"}` in `.jig/config.json`, committed on trunk. Like a `roles`
   entry, the commit hook refuses it without a reason. Without it, nothing is ever pushed for
   a check, and a complete check just waits its turn.
8. **This changes a fixed rule.** RULES.md says the owner's word before a push holds
   "whatever the config says", and lists push among the hubnode's own steps. Part 2 amends both
   in one place each:
   - with the overflow key, the check role may push and delete `jig-check/*` branches, and only
     those;
   - every other push stays the hubnode's, on the owner's word.
   The commit hook's check that a config never weakens a fixed rule accepts this one key, and
   nothing else.
9. **When it overflows:** as the session put it, when "the queue [is] full, or a full run
   already going". That is, every slot is held, or the full lock is held. In either case, with
   the overflow key set, `jig queue --full -- …` doesn't wait. It exits 3 and prints the CI
   route:
   - push the checkout's HEAD as `jig-check/<short sha>`;
   - the workflow runs `.jig/scripts/setup.sh`, then `.jig/scripts/check.sh --full`, on that
     commit;
   - once the run passes, record it with `jig checked --ci <run url>`;
   - then delete the branch.
   Without the key, it waits as in item 1.
10. **The workflow:** a template, `plugin/templates/github/jig-check.yml`, runs on a push to
    `jig-check/**`. It does a full clone (`fetch-depth: 0`), runs setup, then the complete
    check. A full clone is needed because some suites read history: jig's smoke rebuilds old
    layouts from the repo's own history (smoke.sh:23, "the smoke test needs a full clone")
    [seen]. The hubnode copies the template to `.github/workflows/` on the owner's yes, in the
    same commit as the overflow key. For jig's own repo, its job also installs the `claude`
    CLI, because `check.sh` runs `claude plugin validate`.
11. **Recording a CI run:** `jig checked --ci <run url> --tier N --effort N --seconds S`.
    - jig reads the run with `gh run view <id> --json headSha,conclusion,status,url`.
    - It refuses unless the run's `headSha` is HEAD, its status is completed and its
      conclusion is success.
    - It also refuses when `gh` is missing or can't read the run, and names which.
    - On success it appends the record with the URL as a sixth field.
    - `checked_records()` reads both 5- and 6-field lines.
    - `jig status`, and the gate's mark, treat a CI record the same as a local one.
12. **The tier and effort** are the check role session's: it pushes, watches the run (for
    example with `gh run watch`), records it and reports. `--seconds` is the run's own
    duration.

## Done when
- [ ] Smoke `queue`, with `queue.slots: 1`:
  - a first `jig queue -- sleep` holds the slot, and a second waits, printing "waiting for a
    slot";
  - killing the first lets the second run, with no file left to clean up;
  - `jig queue` lists the holder and the waiter;
  - the exit code passes through: `jig queue -- false` exits 1.
- [ ] Smoke `queue`: with `queue.width: "all"` and no `queue.slots`, `jig queue` reports one
  slot. With `queue.width: 2` on a known core count, it reports the core count divided by 2.
- [ ] Smoke `queue`: two `jig queue --full --` runs never overlap, even with `queue.slots: 4`.
  The second waits for the first. With the overflow key set, it exits 3 and prints the CI route
  with `jig-check/<sha>`, and does the same when every slot is held by ordinary runs.
- [ ] Smoke `queue`: with `queue.max_load: 0` (always over), a run waits even with a free
  slot. Unset, the load is never read.
- [ ] Smoke `queue`: an overflow key with no reason is refused by the commit hook. A config
  that weakens any other fixed rule is still refused.
- [ ] Smoke `check_levels` (where the `jig checked` cases live), with a stub `gh` on PATH:
  - a run whose `headSha` isn't HEAD is refused;
  - a failed or in-progress run is refused;
  - a missing `gh` is refused, naming it;
  - a passing run on HEAD is recorded with its URL;
  - `jig status` shows the record;
  - an old 5-field line in `checked.log` is still read.
- [ ] The work, review, check and hubnode skills, and RULES.md's Workflow, name `jig queue` for
  test and check runs.
  - The hubnode skill's lines 136–138 say: runs go through the queue, and the complete check
    overflows to CI only with the overflow key.
  - RULES.md says jig holds the slot and never chooses what runs.
  - RULES.md's "Fixed, whatever the config says" and the hubnode's own steps name the
    `jig-check/*` exception (item 8), and nothing wider.
- [ ] This repo's `.jig/config.json` sets `queue.width: "all"`, in the hubnode's commit on
  main right after the merge (R5 keeps the board's config on trunk). Its AGENTS.md Commands
  lines for smoke and check run through `jig queue`.
- [ ] `plugin/templates/github/jig-check.yml` exists and is valid YAML. Nothing
  Claude-specific is in it; the `claude` CLI step is in this repo's own copy only.
- [ ] `.jig/scripts/check.sh` exits 0. `bash tests/smoke.sh queue check_levels` passes, and
  `claude plugin validate ./plugin` passes. The full suite runs once, at the check step.
- [ ] By hand, part 2 in this repo, after the owner's yes: one real overflow. The branch is
  pushed, Actions passes, `jig checked --ci` records it, and the branch is deleted.

## Out of scope
- **Reviews in cloud sessions: the next spec, not this one.** The session said they "mostly
  work today": the reviewer reports back and the hubnode records locally. The job's branch
  has to be pushed before each review, which is a push this spec's exception doesn't cover.
- **Work sessions in the cloud.** The hardest option: their commits would have to come back to
  the local worktree, and the board would have to follow a remote branch.
- **An SSH devbox.** It needs no jig change, if the repo and its `.git` live there. The hubnode
  would run there too.
- **CI systems other than GitHub Actions.** The `--ci` record reads `gh`; another system is a
  later spec.
- **The Stop hook's quick check** (item 6).
- **`tests/smoke.sh`'s own parallelism.** `JIG_SMOKE_JOBS` stays, and `queue.width` accounts
  for it.

## Touches
- `plugin/templates/jig/jig.py`: `cmd_queue` and its parser; `cmd_checked`'s `--ci`;
  `checked_records`; the config check for `queue` and its fixed-rule exception; `jig status`'s
  check line.
- `plugin/templates/jig/RULES.md`: Workflow (the queue, the overflow, a CI record, the fixed
  rule and the hubnode's own steps); Commands.
- `plugin/templates/github/jig-check.yml` (new).
- `plugin/skills/work/SKILL.md`, `review/SKILL.md`, `check/SKILL.md`, `hubnode/SKILL.md`.
- `tests/smoke.sh`: a new `queue` section, and `--ci` cases in `check_levels`; UNITS.
- `AGENTS.md`, in part 1.
- `.github/workflows/jig-check.yml` in this repo: part 2, on the owner's yes.
- `.jig/config.json` (`queue.width: "all"` and `queue.overflow`): the hubnode's commit on main
  right after the merge, since R5 keeps the board's config on trunk and main's hook must know
  the `queue` keys before it accepts them.

## Alternatives considered
- Machine load as the trigger — rejected as the default, because it's noisy and
  machine-specific, and the owner asked about jobs waiting. It's kept as an optional extra
  (item 5) — [seen] (this session's discussion).
- The complete check on Actions every time, as the session first proposed — rejected, because
  the owner then asked for "only when my computer gets overloaded", and every push shows the
  commits on a public repo — [seen].
- Reviews in cloud sessions — deferred to the next spec, not rejected (Out of scope) — [seen].
- Work sessions in cloud sessions — rejected for now, because their commits and the board
  would have to follow a remote branch — [seen] (this session's discussion).
- A slot taken and released by `check.sh` itself (`jig slot take`/`release`) — rejected,
  because a killed run would leave its slot held. Only a process holding an OS lock for the
  run's length frees it on death — [assumed]: a stale-lock scheme with pids could work, at the
  cost of the cleanup `flock` makes unnecessary.
- `jig checked --ci` trusting the URL it's handed — rejected, so that jig never claims a check
  it didn't see — [assumed]: the session said only that the URL is the evidence. Reading the
  run through `gh` is this spec's own choice.
- The hubnode pushing the check branch instead of the check role — rejected, because the
  session said the check role pushes, and a hubnode relay would hold the check up — [assumed].

## Decisions
- The owner, 2026-11-17: "Can we run on github actions only when my computer gets overloaded
  past a certain point, is there a way to know because jobs are waiting or something?"
- Interpreted: "overloaded past a certain point" is queue depth by default (the queue full, or
  a complete check already running). The optional load threshold is the "certain point" for an
  owner who wants the machine's load read.
- Interpreted: "only when overloaded → Actions" covers the complete check only. The smoke runs
  that overload the Mac most stay local and wait in the queue, as the session said ("The queue
  is what helps them").
- Interpreted: `jig queue` runs the caller's command so it can hold the lock for the
  command's length. This changes "jig never runs a check" (`cmd_checked`'s docstring, RULES.md)
  to "jig never chooses what runs".
- Interpreted: the push is the owner's standing yes for `jig-check/*` branches only, given once
  as the overflow key with his words as its reason. That amends a fixed rule (item 8), and only
  for those branches.
- Interpreted: a complete check takes one slot and the single full lock, not every slot.
- Interpreted: the overflow exits 3 and prints the route. jig doesn't push itself, so the push
  stays a step the check role takes and reports.
- Interpreted: the names, paths, flags, config keys, exit code, branch name, message text and
  refusal rules in Design are this spec's. The session named none of them.
- Open for the owner before part 2 is used:
  - **This repo is public.** A pushed `jig-check/*` branch of trunk's tip shows unreleased
    commits until it's deleted. The marketplace serves `./plugin` from main only, so nothing
    ships.
  - **Actions minutes.** A private repo spends them.
- The owner, 2026-11-17, on item 8's amendment (a standing yes for `jig-check/*` pushes, or
  approval each push): "Keep the standing yes". Item 8 stands as written. The overflow key's
  reason in this repo quotes these words.
- Interpreted: R5 keeps `.jig/config.json` trunk-only, so the queue keys land in the hubnode's
  commit after the merge.
- Risk [assumed]: `claude plugin validate` runs in CI without a login. If it doesn't, this
  repo's workflow skips the validate line and the check role runs it locally. The by-hand
  done-when item settles this.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
