# rename-job-sync

Source: Adventure-Studio hubnode session / 2026-11-11 / Dave, with Claude (staged as feedback-adventure-studio-2026-11-11-sync-log-and-names.md): "`sync` does two unrelated jobs; other names do too"

The owner: "sync has two totally different jobs under one name, keep sync meta/para related and
rename the other and audit other commands/names that have more than one job." Name picked Nov
11: `jig catch-up`.

## Intent
`jig sync` means one thing: a pararepo taking in its metarepo. A job taking in trunk is
`jig catch-up`, everywhere: the command, RULES.md, every printed message, and the skills.

## Why
- Why did the owner ask why a repo with no metarepo was syncing? The hubnode said "the job synced
  with main", and the owner knew the word as the metarepo operation.
- Why are there two meanings? `cmd_sync` branches on where it runs: on a pararepo's trunk it moves
  the pin, and on a job's branch it merges trunk. The two share no code, arguments or audience.

## Givens
- `[seen]` `cmd_sync`'s comment: "trunk for a job, the metarepo for a pararepo's trunk".
- `[seen]` RULES.md's `## Sync` section describes only the job meaning. The metarepo meaning is
  under Metarepo and pararepos and "the sync buffer".
- `[seen]` Messages that use "sync" for a job include "Sync the clean jobs" (`jig merge`),
  "`jig sync` the job, then merge again" (the append-file refusal) and "a synced job needs no new
  handoff".

## Design
- **`jig catch-up`** merges trunk into the job's branch: today's job half of `cmd_sync`, unchanged
  in behavior.
- **`jig sync`** keeps the metarepo half. Run on a job branch it does not merge. It prints
  "`jig sync` is for a pararepo's metarepo; a job takes in trunk with `jig catch-up`", exits
  non-zero, and keeps doing so for one release.
- **Words.** Rename in step: RULES.md (`## Sync` becomes `## Catch-up`), the Commands list, every
  printed message that means the job operation, the hubnode and subnode skills, and every skill
  that says "sync" for a job. "The sync buffer" keeps its name.
- `jig status` and the gate say "catch up" where they say "sync" today.

## Done when
- [ ] Smoke: `jig catch-up` on a job branch merges trunk, as `jig sync` did. Every existing
  job-sync smoke case runs through `catch-up`.
- [ ] Smoke: `jig sync` on a job branch exits non-zero, names `jig catch-up` and merges nothing.
  On a pararepo's trunk it behaves as today.
- [ ] `grep -rn "sync" plugin/templates/jig/RULES.md plugin/skills` finds the word only for the
  metarepo and pararepo, and the same holds for jig.py's printed messages.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- The audit's other splits: specs `rename-check-rules`, `gate-word` and `split-merge-log`. Each
  other item in the audit is kept, by the owner's choice (Nov 11).
- An alias that keeps `jig sync` merging trunk. The owner wants the word to mean one thing.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_sync`, a new `cmd_catch_up`, argparse, messages)
- `plugin/templates/jig/RULES.md`
- `plugin/skills/*/SKILL.md` (every mention of the job meaning)
- `tests/smoke.sh`, `tests/redocument-fixture.sh`
- `AGENTS.md` (this repo's workflow lines, if they say sync for a job)
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- `jig refresh` or `jig take-trunk`. The owner picked `catch-up`, which says what a job does.
  Reason is [seen: owner, Nov 11].
- Keep both meanings under `sync` and explain them in RULES.md. Rejected by the owner. Reason is
  [seen: the report].

## Decisions
- Runs after the open jobs that touch `jig.py`, RULES.md and the skills have merged, since it
  renames words across all of them.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
