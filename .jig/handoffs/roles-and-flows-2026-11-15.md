# Handoff: roles-and-flows

Commit: 8211b56d9f8112159236704de4c748373960932a
Date: 2026-11-15
Spec: .jig/specs/roles-and-flows.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown
Partial: yes

## Built
Part 1 of roles-and-flows (`--partial`: written by hand as `Partial: yes`, since this repo's
installed jig predates the flag): jig.py and the tests.
- `ROLES`, `HUBNODE_STEPS`, `FLOWS` (plus `FIXED_RULES`, `FIX_ROUNDS`) replace `WORKFLOW_DEFAULTS`.
- `jig roles`, `jig flows`, `jig workflow` (alias: the old step names, then the flows), `jig next [<job>]`.
- Config key `roles`, each entry with a reason; fixed rules refused; the old `workflow` key read
  (execute → work, review → review; recheck dropped with a note, the hubnode's ruling), rewritten
  by `jig update --apply`; the hook refuses a new or changed override under the old key.
- Contracts: `jig merge` refuses an ungated job; `jig reviewed --blocking N`, and `jig handoff`
  refuses while the newest review has blocking findings; past three fix rounds per part,
  `jig reviewed` (full or `--change`) is refused until a spec with `Bug-for: <job>` is committed.
- Renames: `jig check` → `jig rules` (alias kept); `--recheck` → `--change` (hidden alias);
  `Recheck:` → `Review-change:` in notes (old lines and records still read); the gate reads a
  spec's `## Roles` or `## Workflow`. The kickoff says `jig.py rules`.
- Spec template: `## Workflow` → `## Roles`; staging fills `## Roles` (or an old `## Workflow`).

## Done-when evidence
Part 1 items. Checks run while building, each section once unless it failed:
- `.jig/scripts/check.sh` → exit 0 (after every change).
- `bash tests/smoke.sh board_split cheaper_rounds check_levels consolidate decisions entry_globs homes merge_after_sync merge_derived metarepo next page_contract pararepo pararepo_commands r6_ints report_fixes roadmap staging_batches supersede sweep touches workflow`
  (every unit my edits touched: the `gated` helper before ~80 merges, `$J check` → `$J rules`,
  the renames) → 838 PASS, 2 FAIL (workflow: a ## Roles gate case placed after a job opened;
  homes: a `tip` taken before the gated commit). Both fixed; `bash tests/smoke.sh workflow homes`
  → rc 0, 124 PASS, no FAIL.
- After the review fixes: `bash tests/smoke.sh next workflow` → rc 0, 62 PASS (twice, one per
  fix round); after the last: `bash tests/smoke.sh next` → rc 0, 24 PASS.
- ROLES/FLOWS as data, no model names: jig.py `ROLES`, `FLOWS`; `grep WORKFLOW_DEFAULTS` empty.
- roles/flows/workflow: smoke `workflow` "roles: prints jig's defaults…", "flows: each workflow's steps…", "workflow: the old command prints…".
- `roles` key, reason, fixed rule, old key mapped, update lists/applies: smoke `workflow` "roles: … is refused" (9 rules × jig roles and the hook), "an old workflow key is read…", "update: lists…", "update --apply rewrites workflow as roles…", "the commit hook refuses a new override under the old workflow key".
- `jig next`: smoke `next` walks job k through Job (work, review-work, fix, review-change, bug, handoff, gate, check, gate mark, merge) and its Fix rounds, each line checked exactly; k2 checks rounds per part.
- Contracts: smoke `next` "merge: a job not marked gated is refused", "handoff: refused while the newest review of HEAD has blocking findings", "reviewed: a fourth round's review-change is refused, naming Bug-for", "a full review in its place is refused too".
- Renames: smoke `workflow` "rules: prints ok…, and the old name check prints the same"; `cheaper_rounds` "--change" cases and "the old --recheck … records a review-change"; `workflow` "gate: a spec's ## Roles is read…" and the old `## Workflow` cases.
- Template `## Roles`: plugin/templates/specs/_template.md; smoke `staging_batches` "staging: a spec with an empty ## Roles resolves with jig roles' lines".

## Review
Review-work of 24af0a9..4e413ff, a fresh subagent at tier 2, effort 2 (claude-opus-5-5; its first
run read its effort as a raw number and stopped, the retry ran with effort `unknown`):
- blocking: the fourth-round refusal fired at the third → fixed in f911244 (rounds counted from review-changes), then b46e8c0/f53b6bf (see below).
- should-fix: a full `jig reviewed` bypassed the round limit → fixed f911244.
- should-fix: a new override under the old `workflow` key needed no reason → fixed f911244 (the hook refuses it).
- should-fix: a `workflow.recheck` override mapped onto review lowered full reviews → the hubnode ruled: drop it; b46e8c0, with an Interpreted line in the spec.
- should-fix: the checks-and-briefs DEFERRED row not closed → taken in f911244, reason rewritten in b46e8c0.
- should-fix: the last-round message was wrong → fixed f911244.
- optional: `jig workflow` didn't print execute/recheck → taken f911244.
- optional ×4 (HUBNODE_FLOOR unused, next never names spec, hand `git merge`, "Fix or Sync" label after --partial) → DEFERRED.md rows.
Review-change of f911244 (no blocking): should-fix, a round recorded as a full review never counted → b46e8c0; optional, hook refuses trimming the old key → DEFERRED; optional, the closed row's reason → b46e8c0.
Review-change of b46e8c0: blocking, `--partial` parts' first reviews counted as rounds → f53b6bf counts per part; should-fix, no smoke for either → f53b6bf adds both.
Review-change of f53b6bf (no blocking): should-fix, code committed with a note starts a part one round short; optional ×3 (any handoffs file resets rounds, every note resets, unbounded lookup) → DEFERRED rows in 8211b56.
The installed jig (`.jig/`) predates `--blocking`, `--change` and `--partial`, so each round was recorded with its plain `jig reviewed`; 8211b56 holds only the DEFERRED rows and carries the same record.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, whose § Workflow, Handoff and Commands this job rewrites in Part 2 (its next handoff).

## Shared files changed
- `plugin/templates/jig/jig.py` (shares): the whole of Part 1.
- `tests/smoke.sh` (shares): new `next` section; `workflow`, `staging_batches` and `cheaper_rounds` rewritten for roles; a `gated <job>` helper before every merge of a job never gated (the hubnode's ruling), `$J check` → `$J rules` throughout.
- `plugin/templates/jig/RULES.md` (shares): not yet; Part 2.
- `.jig/specs/roles-and-flows.md` (common): four Interpreted lines, each on the hubnode's word.
- `.jig/ledgers/DEFERRED.md` (common): the checks-and-briefs row taken; rows for untaken findings.

## Test by hand
In a scratch repo with `JIG_CONFIG`/`XDG_CONFIG_HOME` set: `jig open k`, then `jig next k` after each
step (a commit, `jig reviewed --blocking 1`, a fix, `jig reviewed --change --blocking 0`, `jig handoff`):
each line names the step, the role and continue/new session. `jig merge k` before `jig mark k gated`
refuses.

## Left
Part 2: the seven node and role skills, the inventory's skill rows, RULES.md § Workflow, README's
"Who does what" with the generated light and dark SVGs, `scripts/roles_svg.py` and its freshness
check in `.jig/scripts/check.sh`, AGENTS.md and the templates' AGENTS.md. Then the final handoff.
