# One job for specs that touch the same files: `jig consolidate`, enforced where work enters

Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-consolidate-specs-one-job.md): "I'd like to make a command to consolidate specs to run as one job: fewer gates, tests, etc"
Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-job-flow-speed.md): "why are these taking so long?"
Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "`comment-anonymity` was opened with `--shares` listing only its docs and ledgers."

## Intent
Specs waiting to be opened whose `## Touches` overlap get one answer before any of them becomes
a job: merged into one spec, or kept separate with a reason. `jig consolidate` finds them, and
the commands work enters through (`jig open`, `jig staging resolve`, `/jig:fix`) refuse until
each overlap is answered, so nobody has to remember. `jig open` also warns on Touches paths
the job's owns and shares leave out, and `jig share` adds one.

## Done when
- [ ] A spec is waiting when no open job names it, no handoff note's `Spec:` line names it, and
      it was added after the newest release tag (any time, with no tag). `jig consolidate`
      lists each group of waiting specs whose Touches overlap (a shared path, a glob covering
      the other's path, or the same `<page> § <term>`), with the shared paths, and a proposed
      grouping. With none, it says so and exits 0. Smoke: three specs, two sharing a page, list
      as one group of two.
- [ ] A group is answered when one spec carries every input's `Source:` lines and the inputs
      are deleted, or when a spec of the pair carries `Kept separate from <spec>: <reason>`.
      `jig consolidate` lists only unanswered groups. Smoke, both answers.
- [ ] `jig open J --spec S` refuses while S is in an unanswered group, naming the group and
      `jig consolidate`. `jig staging resolve <file>` refuses the same when the spec carrying
      the file's mark is in one. Smoke, both.
- [ ] `/jig:fix` runs `jig consolidate` after writing its specs and before resolving, and the
      hubnode skill runs it before opening more than one job.
- [ ] A `/jig:consolidate` skill writes the merged spec: one Intent, each input's Source lines,
      its Done-when items as a labelled group, its Decisions and Out of scope kept; Touches the
      union; Workflow from `jig workflow`. It deletes the inputs in the same commit. Given
      `propose/<repo>-<slug>` branches among the inputs, the spec lists each, and the kickoff
      says to merge each into the job's branch in the order given.
- [ ] Smoke, with a metarepo fixture: two proposals consolidated into one job and merged; after
      `jig release`, the pararepo's `jig sync` reports both proposals released.
- [ ] `jig open` warns, naming each path, when a backticked path in the spec's Touches is
      covered by neither `--owns` nor `--shares` nor `common`. `jig share J <path>…` adds paths
      to J's shares on the board, refusing a path another open job owns. Smoke: opening on a
      Touches of `app/src/x.ts` with `--shares 'docs/**'` warns; `jig share` adds it and
      `jig check` passes.
- [ ] RULES.md names the waiting-spec rule and both answers.
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin`, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- jig merging spec prose: the skill writes the merged spec, and jig checks its result.
- Folding a waiting spec into a job already open: open jobs take new scope by a spec amendment,
  as now.
- Overlap by meaning (two specs that change one claim in different files): `every-copy`.

## Touches
- `plugin/templates/jig/jig.py` (a new `cmd_consolidate` and `cmd_share`, `cmd_open`,
  `cmd_staging`'s resolve, the parser)
- `plugin/templates/jig/RULES.md` (jobs, staging)
- a new `plugin/skills/consolidate/SKILL.md`; `plugin/skills/fix/SKILL.md`,
  `plugin/skills/hubnode/SKILL.md`, `plugin/skills/stage/SKILL.md`
- `tests/smoke.sh` (a new `consolidate` section)

## Alternatives considered
- A skill alone, run when the hubnode notices — rejected by the owner: "I dont want to rely on
  remembering to do it when I notice" — [seen].
- `jig consolidate --into` writing the merged spec itself, as the report asked — rejected
  because merging Intent and Decisions is judgement, and the owner reads it before opening;
  jig finds, refuses and checks the result instead — [assumed].
- Waiting spec = any spec with no handoff note — rejected because this repo has 25 such specs,
  most of them solo work long merged; the release tag bounds it — [seen]: 99 specs, 74 named by
  notes.

## Decisions
- Calls the owner made on 2026-11-13: a command with enforcement at the entry points, a skill to
  write the merged spec, and `jig share`.
- Interpreted: overlap is by Touches paths only, and an answer is one line, so a repo whose
  every spec touches one file (jig's own `jig.py`) pays one line per pair, not a refusal it
  can't clear.
- Interpreted: a `Kept separate` line is per pair, and either spec of the pair may carry it.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
