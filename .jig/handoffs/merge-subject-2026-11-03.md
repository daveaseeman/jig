# Handoff: merge-subject

Commit: 7ca17e0eb682e91f5c45de185cadbc99cd7ab702
Date: 2026-11-03
Spec: .jig/specs/bug-merge-subject.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
`jig merge --subject` no longer doubles `: merge <job>`. A subject that already ends in
`: merge <job>` is used as given; anything else is a prefix, as before, so the gate's
deleted-branch fallback still finds the job. The help, RULES.md (the hubnode merges) and the
hubnode skill's merge step now all say the same thing: `--subject` is the ids the subject
leads with, e.g. `D-001, D-002`, and the caller doesn't write the merge. The skill's old
`<ids>: <what>` invitation was the real cause of the reported subject.

## Done-when evidence
- Full subject used once: `bash tests/smoke.sh` → `PASS  merge --subject: a subject that already ends in ': merge <job>' is used as given` (`--subject "D-001: merge S1"` → `D-001: merge S1`).
- Bare ids still get the suffix: `bash tests/smoke.sh` → `PASS  merge --subject: bare ids still get ': merge <job>' added` (`--subject "D-001"` → `D-001: merge S2`).
- Help: `python3 plugin/templates/jig/jig.py merge --help` → `--subject SUBJECT     the ids the subject leads with, e.g. `D-001, D-002`; `: merge <job>` is added unless it's already there`.
- Docs no longer invite a `<what>` that names the merge: RULES.md (the hubnode merges, aad201e) and `plugin/skills/hubnode/SKILL.md` merge step (7ca17e0) say what the help says.
- Smoke and validator, last run at 7ca17e0:
  ```
  rc=0
  0            # FAIL lines
  PASS  merge --subject: the subject is '<ids>: merge J'
  PASS  merge --subject: the gate's fallback still finds job J by its merge after its branch is deleted
  PASS  merge --subject: a subject that already ends in ': merge <job>' is used as given
  PASS  merge --subject: bare ids still get ': merge <job>' added
  PASS  isolation: the user's real jig config folder is unchanged by the run
  ✔ Validation passed
  ```

## Review
Round 1, a fresh claude-opus-5-5 subagent at xhigh:
- Blocking: the spec misdiagnosed the cause. The reported input
  (`E-045, E-044: merge lite-buffer (Maige Lite buffer B1)`) still doubled, because callers
  followed the hubnode skill's `--subject "<ids>: <what>"`. Taken: the spec's Why, Correction,
  Done when and Touches were rewritten, and the docs were fixed so they no longer invite it (aad201e, 7ca17e0).
- Should-fix: the four descriptions of `--subject` (help, RULES.md, hubnode skill, smoke case)
  disagreed. Taken: all now describe ids only; the old smoke case passes `"D-001, D-002"`
  instead of `"D-001: land J"` (aad201e, 7ca17e0).
- Optional: taken, in the same commits.
Nothing deferred.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's rulebook is `plugin/templates/jig/RULES.md`, which this job updated (the hubnode merges, `--subject`). This repo has no docs tree for the checker.

## Shared files changed
- `tests/smoke.sh`: two new cases (and an `emergejob` helper) beside the existing `jig merge --subject` cases, plus that case's subject changed to ids; the spec's Done when needs smoke evidence.
- `plugin/templates/jig/RULES.md`: the `--subject` sentence in the hubnode merges step, so it matches the help (review finding).
- `plugin/skills/hubnode/SKILL.md`: the `--subject` lines in the merge step; its `<ids>: <what>` was the cause of the bug. Edited after owner-steps merged.
- `plugin/templates/jig/jig.py`: `cmd_merge` and its `--subject` help.

## Test by hand
In a jig repo with a handed-off job `x`, run `jig merge x --subject "D-001: merge x"` and
check `git log -1 --format=%s` is `D-001: merge x`; with `--subject "D-001"` it is the same.

## Left
Nothing.
