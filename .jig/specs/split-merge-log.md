# split-merge-log

Source: Adventure-Studio hubnode session / 2026-11-11 / Dave, with Claude (staged as feedback-adventure-studio-2026-11-11-sync-log-and-names.md): "`sync` does two unrelated jobs; other names do too"

The owner chose to split `jig update --merge-log`, Nov 11.

## Intent
Moving a `CHANGELOG.md` and a decisions register into `.jig/decisions.md` is its own command,
`jig migrate-log`, with a dry run and `--apply`. `jig update` does layout migration only. It
names `jig migrate-log` when a repo still has the old files.

## Why
- Why split it? `jig update` migrates jig's own layout. `--merge-log` is a different operation,
  with its own review, apply and job flow in a metarepo, under the same name.
- Why now? `update-project-sweep` added `--sweep` beside it, so update carries three operations.

## Givens
- `[seen]` `jig update --merge-log` and `--apply --merge-log` (jig.py ~3825 and update's
  parser). In a metarepo it refuses on trunk and runs in a job.
- `[seen]` Update's review list names `--merge-log` for a root CHANGELOG.md (~2398) and a register
  (~613).

## Design
- **`jig migrate-log [--apply] [--number]`** does exactly what `jig update --merge-log` does now,
  metarepo job flow included.
- **`jig update`** lists a root CHANGELOG.md or register under Repo files to review with
  "`jig migrate-log` moves it into .jig/decisions.md". `--merge-log` stays a hidden alias for
  one release, printing the new name.
- RULES.md, the update skill, and every message naming `--merge-log` say `jig migrate-log`.
- `--sweep` stays on update: it is part of bringing a repo onto the current rules.

## Done when
- [ ] Smoke: every existing `--merge-log` case runs through `jig migrate-log`, and passes.
- [ ] Smoke: `jig update --merge-log` prints the new name and does the same thing.
- [ ] No skill or RULES.md line names `--merge-log`.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Splitting `--sweep` out of update.
- Any change to what the migration does.

## Touches
- `plugin/templates/jig/jig.py` (argparse, `cmd_update`, a new `cmd_migrate_log`, messages)
- `plugin/templates/jig/RULES.md`, `plugin/skills/update/SKILL.md`
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- Keep it under update and document it better. Rejected by the owner's choice to split it.
  Reason is [seen: owner, Nov 11].
- The name `jig merge-log`. Rejected: `merge` already names merging a job. The name
  `migrate-log` is the hubnode's pick, open to the owner's change. Reason is [assumed].

## Decisions
- Runs after `update-project-sweep` merges (it changes `cmd_update`) and after `gate-word`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
