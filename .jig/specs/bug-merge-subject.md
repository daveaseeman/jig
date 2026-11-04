# Bug: `jig merge --subject` with a full subject repeats "merge <job>"

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)

Report item 6.

## 1. Why
- Why the doubled "merge lite-buffer"? `cmd_merge` builds `f"{subject}: merge {name}"`, and the
  caller's `--subject` already named the merge: `E-045, E-044: merge lite-buffer (Maige Lite buffer B1)`.
- Why did they? The hubnode skill invites it: `--subject "<ids>: <what>"`, and a caller fills
  `<what>` with what the merge does, the merge included. RULES.md ("`--subject <text>` puts text
  before it") and the help ("the merge subject, before `: merge <name>`") call it a prefix of any
  text too; none says it is only the ids.
- Why is the suffix forced? `proposal_in` finds a job whose branch is gone by `merge <job>` at
  the subject's end. Keep that; just don't add it twice.

## 2. Givens
- `[seen]` `jig.py` `cmd_merge`: `msg = (f"{args.subject}: " if args.subject else "") + f"merge {name}"`.
- `[seen]` `proposal_in` matches `(?:^|: )merge (\S+)$`.
- `[seen]` Reported subject: `E-045, E-044: merge lite-buffer (Maige Lite buffer B1): merge lite-buffer`.

## 3. One layer up
No sibling builds a merge subject. `jig sync` writes its own `meta:` subjects whole.

## 4. Correction
Correction. A `--subject` that already ends in `: merge <job>` is used as given. Otherwise it's a
prefix, as today. The help, RULES.md and the hubnode skill all say the same: it is the ids the
subject leads with, with an example, and the merge isn't written by the caller.

## 5. Spec

### Done when
- [ ] Smoke: `jig merge <job> --subject "D-001: merge <job>"` gives the subject `D-001: merge <job>`, once.
- [ ] Smoke: `--subject "D-001"` still gives `D-001: merge <job>`.
- [ ] `jig merge --help` reads: the ids the subject leads with, e.g. `D-001, D-002`; `: merge <job>` is added unless it's already there.
- [ ] The docs no longer invite a `<what>` that names the merge: RULES.md (jobs, the hubnode merges) and
      `plugin/skills/hubnode/SKILL.md` say what the help says.
- [ ] Smoke passes, and the validator passes.

### Out of scope
Renaming the flag: repos already pass `--subject`.

### Touches
`plugin/templates/jig/jig.py` (`cmd_merge` and its help), `tests/smoke.sh`,
`plugin/templates/jig/RULES.md` (the hubnode merges), `plugin/skills/hubnode/SKILL.md` (its merge step,
after job owner-steps merges).

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
