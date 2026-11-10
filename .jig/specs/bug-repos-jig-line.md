# bug-repos-jig-line

Source: maige-ecosystem hubnode session with Dave, 2026-11-10 (Claude) (staged as feedback-maige-ecosystem-2026-11-10-redocument-metarepo.md): "The line "tool reports wait in <dir> while no repo in this list is named jig" prints on every run, whatever the list holds."

## Intent
`jig repos` says tool reports wait in the feedback folder only when that is true: when no entry
is named `jig`.

## Why
- Why does the line print with `jig` registered? The `print` at the end of the listing in
  `cmd_repos` has no condition.
- Why is that wrong? With an entry named `jig`, `/jig:feedback` stages into that repo, so the
  line names a folder nothing goes to.

## Givens
- `[seen]` `plugin/templates/jig/jig.py` `cmd_repos`: `print(f"tool reports wait in
  {feedback_dir()} while no repo in this list is named jig")`, unconditional after the loop.
- `[assumed]` The reporter's `jig repos` listed `jig  repo  …/GitHub/jig` and still printed it;
  follows from the code.

## Done when
- [ ] Smoke `repos`: with an entry named `jig`, `jig repos` doesn't print "tool reports wait";
  with none, it does (the reported symptom gone, and the line kept where it's true).
- [ ] `bash tests/smoke.sh` passes and `claude plugin validate ./plugin` passes.

## Out of scope
- Where reports go, and the feedback folder itself.

## Touches
- `plugin/templates/jig/jig.py` (`cmd_repos`)
- `tests/smoke.sh`

## Alternatives considered
- Drop the line — rejected because without a `jig` entry it is the only place that says where
  reports wait — reason is [seen: `cmd_repos`, `feedback_dir()`]

## Decisions
- The test is an entry named exactly `jig`, the same name the line states.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
