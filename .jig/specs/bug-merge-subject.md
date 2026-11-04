# Bug: `jig merge --subject` with a full subject repeats "merge <job>"

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)

Report item 6.

## 1. Why
- Why the doubled "merge lite-buffer"? `cmd_merge` builds `f"{subject}: merge {name}"`, and the
  caller passed a subject that already ended in `merge lite-buffer`.
- Why did they? The flag is named `--subject`. Its help ("the merge subject, before `: merge
  <name>`") is the only place that says it's a prefix.
- Why is the suffix forced? `proposal_in` finds a job whose branch is gone by `merge <job>` at
  the subject's end. Keep that; just don't add it twice.

## 2. Givens
- `[seen]` `jig.py` `cmd_merge`: `msg = (f"{args.subject}: " if args.subject else "") + f"merge {name}"`.
- `[seen]` `proposal_in` matches `(?:^|: )merge (\S+)$`.
- `[seen]` Reported subject: `E-045, E-044: merge lite-buffer (Maige Lite buffer B1): merge lite-buffer`.

## 3. One layer up
No sibling builds a merge subject. `jig sync` writes its own `meta:` subjects whole.

## 4. Correction
Correction. A `--subject` that already ends in `merge <job>` is used as given. Otherwise it's a
prefix, as today. The help names the prefix shape with an example.

## 5. Spec

### Done when
- [ ] Smoke: `jig merge <job> --subject "D-001: merge <job>"` gives the subject `D-001: merge <job>`, once.
- [ ] Smoke: `--subject "D-001"` still gives `D-001: merge <job>`.
- [ ] `jig merge --help` reads: the ids the subject leads with, e.g. `D-001, D-002`; `: merge <job>` is added unless it's already there.
- [ ] Smoke passes, and the validator passes.

### Out of scope
Renaming the flag: repos already pass `--subject`.

### Touches
`plugin/templates/jig/jig.py` (`cmd_merge` and its help), `tests/smoke.sh`.

### Alternatives considered
- Rename to `--ids`. Rejected: it breaks existing callers for a help-text problem. `[seen]`:
  the reporting hubnode used `--subject`.
- Drop the forced suffix. Rejected: `proposal_in` relies on it for a deleted branch. `[seen]`:
  its regex.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
