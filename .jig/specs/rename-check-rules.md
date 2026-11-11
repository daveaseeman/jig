# rename-check-rules

Source: Adventure-Studio hubnode session / 2026-11-11 / Dave, with Claude (staged as feedback-adventure-studio-2026-11-11-sync-log-and-names.md): "`sync` does two unrelated jobs; other names do too"

The owner chose to split `check`, Nov 11.

## Intent
"check" names one thing: the project's own checks, `.jig/scripts/check.sh`, and the workflow step
that runs them. `jig check`, which runs jig's own rules, becomes `jig rules`.

## Why
- Why is "the check passed" ambiguous? `jig check` runs jig's rules (R1–R8, M, P), `.jig/scripts/
  check.sh` runs the project's build and tests, and the workflow step `check` runs the gate's
  checks. Three things share one word.
- Why rename the jig command and not the script? The script is the repo's own and is named in
  every repo's AGENTS.md. `jig check` is jig's.

## Givens
- `[seen]` argparse `check` ("run the rules here", jig.py ~8013), dispatched to `cmd_check`.
- `[seen]` The hooks call `jig.py hook <name>`, not `check`, so renaming the command doesn't touch
  any installed hook.
- `[seen]` The kickoff line says "Read .jig/RULES.md, then `python3 .jig/jig.py check`" (~912),
  and skills tell subnodes to run it.

## Design
- **`jig rules [--staged]`** runs what `jig check` runs today. `jig check` stays as a hidden alias,
  printing nothing extra, so older kickoffs and notes keep working.
- **Words.** The kickoff, RULES.md's Commands list, every skill and every message that means jig's
  rules say `jig rules`. "check" and `check.sh` mean the project's checks only.
- The workflow step `check` keeps its name, since it runs the project's checks.

## Done when
- [ ] Smoke: `jig rules` prints `ok` in a clean job and the R-refusal in a job that breaks one.
  `jig check` gives the same output.
- [ ] The kickoff names `jig rules`, and no skill or RULES.md line uses `jig check`.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Renaming `check.sh` or the workflow step.

## Touches
- `plugin/templates/jig/jig.py` (argparse, the kickoff line, messages)
- `plugin/templates/jig/RULES.md`, `plugin/skills/*/SKILL.md`
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- Rename `check.sh`. Rejected: it is the repo's own script, named in every repo's AGENTS.md, and
  renaming it means a migration in every repo. Reason is [seen: templates/AGENTS.md].
- Drop `jig check` outright. Rejected: kickoffs and handoff notes already in repos name it.
  Reason is [seen: the kickoff line].

## Decisions
- Runs after `rename-job-sync`, which edits many of the same lines.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
