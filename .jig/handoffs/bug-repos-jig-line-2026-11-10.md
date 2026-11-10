# Handoff: bug-repos-jig-line

Commit: bdc2726e64afc0f2eb5262119bf34299c7b6d709
Date: 2026-11-10
Spec: .jig/specs/bug-repos-jig-line.md
Review: tier 2, effort 2
Ran: fresh Opus review of 5c4350f: no blocking; S1 two tests for a registered jig (cmd_repos/feedback skill exact name vs staging/forward repo_path) reproduced, fixed in bdc2726 with a smoke case; O1 duplicate smoke msg fixed. Hubnode checked bdc2726 by diff and smoke repos.

## Built
`jig repos` prints "tool reports wait in <dir> while the jig repo isn't registered" only when
`repo_path("jig")` is None. That is the lookup staging and forward already use, so an entry
named `jig`, or a repo whose own board name is `jig` under an alias, both count. The feedback
skill's step 2 now finds the jig repo by the same two tests.

## Done-when evidence
- `bash tests/smoke.sh repos`: PASS "with no entry named jig, it says where tool reports wait",
  PASS "with an entry named jig, it doesn't say reports wait in a folder", PASS "a repo whose own
  name is jig, under an alias, counts as the jig repo". Both negative cases FAIL against the
  previous condition.
- `bash tests/smoke.sh`: exit 0, 755 PASS, 0 FAIL. `claude plugin validate ./plugin`: ✔ Validation passed.

## Review
- S1 (should-fix): `cmd_repos` and the feedback skill tested for an exact `jig` entry, while
  staging and forward use `repo_path("jig")`. Fixed: both now use the `repo_path` rule, and smoke
  covers an aliased repo whose own name is jig.
- O1 (optional): two assertions shared one smoke msg. Fixed with a separate msg.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty, and only the feedback skill describes where reports go (RULES.md and the other skills don't mention the wait line); that skill is updated here

## Shared files changed
- `plugin/templates/jig/jig.py`: the condition and wording of the wait line in `cmd_repos` (3 lines).
- `tests/smoke.sh`: cases appended at the end of `sec_repos`.
- `plugin/skills/feedback/SKILL.md`: step 2, how to tell the jig repo is registered.

## Test by hand
With `jig` registered (by name or alias), run `python3 .jig/jig.py repos`: no "tool reports
wait" line. With no jig repo registered, the line is there.

## Left
Nothing.
