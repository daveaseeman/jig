# Workflow tiers: the hubnode talks and decides, subnodes do the work at set tiers

Source: cowork session 2026-10-30 (Dave + Claude) (staged as 2026-10-30-workflow-tiers.md)

## Intent
The hubnode writes specs, talks with the owner, reads reviews and decides. Execution, review,
fixes and gate checks go to subnodes it spawns, each at a model tier and effort the owner sets
(jig's defaults, or the repo's override), never one a model picks. Every session says what it
runs on, and the gate warns when a review ran weaker than the spec.

## The workflow (jig's defaults)

| Step | Who | Model tier | Effort | Rule an override must keep |
|---|---|---|---|---|
| spec, decide, retro, hardware page | hubnode | 2 | 2 | — |
| execute, fix | spawned subnode | 2 | 3 | tier ≥ spec's (same or lower model); effort > spec's (lower) |
| review | spawned subnode, always a fresh context | 2 | 1 | tier ≤ spec's (same or higher model); effort < spec's (higher) |
| gate check, release run, survey | spawned subnode | 3 | 4 | none: they run fixed commands and report |

Model tier 1 is the best model available in the tool; a higher number is a lesser model.
Effort 0 is the highest effort the tool has, and each number up is one level lower. The defaults
leave effort 0 unused, so a repo can raise any step. The spec runs below the top, so the
review has a higher effort to run at. The gate check is
`bug-merge-after-sync.md`'s: the hubnode never runs a suite in its own session.

## Workflows the steps make up
Each is a sequence of the steps above; the hubnode runs a step marked H, a spawned subnode one
marked S.
- **Task from a spec:** spec H → execute S → review S → decide H → fix S (the executing
  subnode, up to three rounds, then `/jig:bug` H) → gate check S → merge H.
- **Bug:** investigate (`/jig:bug`, a spec step) H → then as a task from execute on.
- **Staged story or feedback report:** write the spec H → as a task.
- **Adopt:** survey S (gate-check settings) → plan H (spec settings) → each stage as a task.
- **Update:** dry run and decide H → apply and fix stale references S (execute settings).
- **Release:** release run (check, `release.sh`, smoke) S (gate-check settings) → push and
  publish H, on the owner's word.
- **Retro, hardware page:** H, at spec settings: they write rules and pages, not code.

The hubnode's own model and effort are whatever the owner chose for its session. jig can't set
them. The skill reads them, and says so when they're below the spec step's.

## Givens (checked Oct 30)
- `[seen]` `.jig/config.json` exists, after the names release. The spec template is
  `plugin/templates/specs/_template.md`, with no Workflow section.
- `[seen]` The review skill already sends the diff to a fresh-context subagent, and says "if a
  third round is needed, the spec was wrong". The story asks for `/jig:bug` on the failure to
  converge instead.
- `[seen]` In the Claude app, a spawned session can be given a model and an effort "at or
  below yours". A subagent (the Agent tool) takes a model and an effort, and may set effort
  when a skill asks for it explicitly.
- `[seen]` Oct 30, from a hubnode on Opus 5.5 at high:
  - A spawned session asked for Fable at max came up as Opus 5.5 at high. The session tool
    clamps to the hubnode's model and effort, silently.
  - A subagent asked for Fable at max sent its request as `claude-fable-5-1`, so a subagent can
    run a higher model than the hubnode. (That request failed on the account's Fable spend
    limit, which is a separate matter.)
  - The same hubnode then raised a session it had started (Opus at high) to `max` with the
    app's set-effort tool. The session reads `max`, and the app didn't prompt. A raised
    effort, or a pricier model, applies from the session's next turn. The app may ask the
    owner first, and in auto mode it decides.
- `[assumed]` A subagent's effort is applied as asked. The tool accepted `max`, but nothing
  reports the effort a subagent ran at.
- So a session can run above the hubnode: start it with a holding prompt, raise its model and
  effort, then send the brief. Its first turn ran clamped and did nothing.
- `[seen]` `jig reviewed` records only the commit, and `jig handoff` writes the note.

## Done when
`jig.py`, tool-agnostic, holds tiers and never a model name:
- [ ] `WORKFLOW_DEFAULTS` holds the table. `jig workflow` prints the steps in effect (the
      defaults merged with `config.json`'s `workflow` override), one per line:
      `execute: tier 2, effort 3`.
- [ ] An override that breaks a rule is refused by `jig workflow`, and by the commit hook when
      `config.json` changes: `workflow.review: tier 2 is below the spec's tier 1`. Smoke covers
      each of the four rules.
- [ ] `jig reviewed --tier N --effort N [--ran "<text>"]` records them with the commit.
      `jig handoff` writes `Ran: <text>` and the review's tiers into the note.
- [ ] `jig gate` warns, without refusing, when the recorded review's tier is above the spec's
      Workflow tier, or its effort is not below the spec's: `review ran at tier 2, effort 2; the
      spec asks for tier 1, effort 1`. Smoke covers the warning and the clean case.
- [ ] The spec template gains a `## Workflow` section. `/jig:spec` fills it from `jig workflow`
      at writing time. A model never edits a step for one task.

The plugin, Claude-specific and outside `templates/jig/`:
- [ ] `plugin/tiers.json` maps tiers to model ids and efforts to the tool's levels:
      `{"model": {"1": "claude-fable-5-1", "2": "claude-opus-5-5", "3": "claude-sonnet-5-5",
      "5": "claude-haiku-5-5"}, "effort": {"0": "max", "1": "xhigh", "2": "high", "3": "medium",
      "4": "low"}}` (owner, Oct 30). A tier with no model, like 4 today, is refused by the skill. It's the one file to edit when models change, and the
      skills read it.
- [ ] Hubnode skill:
  - It spawns execute, fix and gate-check as subnode sessions at their mapped model and effort,
    and stays free to talk.
  - It spawns review as a fresh-context subagent at its mapped model and effort.
  - Each spawned prompt starts with `running <model> at <effort>`.
  - After a third fix round, it runs `/jig:bug` on why the fixes aren't converging, instead of
    spawning a fourth.
- [ ] Subnode and review skills: the first line of a session's first reply is
      `running <model> at <effort>`. The review skill passes `--tier`, `--effort` and `--ran` to
      `jig reviewed`.
- [ ] `grep -rniE 'claude-(fable|opus|sonnet|haiku)|\b(fable|opus|sonnet|haiku)\b' plugin/templates/jig/`
      finds nothing. (`claude-` alone matches jig's predecessor, `claude-lane`, in the old-layout
      migration.)
- [ ] Smoke passes, and the validator passes.

## Out of scope
- `jig.py` spawning anything: it validates, records and warns.
- Making the gate warning a refusal. It becomes one later, if it keeps happening.
- Per-task overrides. A task that needs other settings means the owner changes the config.

## Touches
- `marketing/FEATURES.md`: rows for workflow tiers and `plugin/tiers.json`, before code.
- `plugin/templates/jig/jig.py`: `WORKFLOW_DEFAULTS`, `cmd_workflow`, the config check,
  `cmd_reviewed`, `cmd_handoff`, `cmd_gate`.
- `plugin/templates/jig/RULES.md`: a Workflow section with the table and the rules, in
  standard terms.
- `plugin/templates/specs/_template.md`, `plugin/tiers.json`.
- Skills: `hubnode`, `subnode`, `review`, `spec`.
- `tests/smoke.sh`.

## Alternatives considered
- Model names in `.jig/config.json`. Rejected by the owner: `.jig/` stays tool-agnostic, and
  names change with every model release. `[seen]`: the story.
- The spec chooses its own tiers. Rejected by the owner: a model would pick its own budget.
  `[seen]`: the story.
- Review as a spawned session, like execute. Rejected: review needs a fresh context, and it
  ends in a report the hubnode reads, not a branch; a subagent is both. `[seen]`: the review
  skill already dispatches a fresh-context subagent, and the Givens show a raised session
  works, so effort isn't the reason.
- The gate refuses a weak review. Deferred by the owner: a warning first. `[seen]`: the story.

## Decisions
- Execute, fix and gate check run as visible sessions, because the owner can watch and steer
  them. When a step's settings are above the hubnode's, the skill starts the session with a
  holding prompt, raises its model and effort, reads them back, then sends the brief.
- Review runs as a subagent, because it needs a fresh context and ends in a report the hubnode
  reads, not a branch. Where the tool has no subagent, it runs as a raised session with no
  history.
- Every spawned session reads its settings back before its brief, and says
  `running <model> at <effort>`. A mismatch stops it and goes to the owner.

- Owner, Oct 30, the roles (tier/effort): hubnode 2/2, execute and fix 2/3, review 2/1 always in
  a fresh context, gate check, release run and survey 3/4. These replace the story's table. A
  fix goes back to the subnode that executed, which has the context, and a newly spawned one
  only when that session is gone. Either way it runs at execute's settings.
- Owner, Oct 30: tier 1 Fable, 2 Opus, 3 Sonnet, 5 Haiku. Effort 0 max, 1 xhigh, 2 high,
  3 medium, 4 low. The lighter defaults ship: spec high, review xhigh, execute medium.
- Owner, Oct 30: a subnode must be able to run above the hubnode. See Givens for what the tools
  allow.

## Workflow
spec: tier 2, effort 2 · execute: tier 2, effort 3 · review: tier 2, effort 1 (jig's defaults,
before `jig workflow` exists to print them)
