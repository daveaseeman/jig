# Handoff: update-adopts-standard

Commit: 41ddccb69ceeb8fe1ad462602771694a59efae49
Date: 2026-11-16
Spec: .jig/specs/update-adopts-standard.md
Source: Maige-Lite hubnode session 25f7e824 / 2026-11-15 / Dave Seeman (staged as feedback-maige-lite-2026-11-15-update-replaces-workflow.md): "make sure that update checks jig config and completely replaces workflows with the new standard since some were accidentally reset"
Source: Maige-Lite hubnode session 25f7e824 / 2026-11-13 / Dave Seeman (staged as feedback-maige-lite-2026-11-13-section-counter-outlives-redocument.md): after `/jig:redocument` finished, "`jig update` and `jig survey` listed one finding left: `.jig/config.json reserve.section: numbers page headings: drop it at /jig:redocument's cleanup, once no page holds a numbered heading`". "The cleanup had already run, two days before ... Nothing in jig removes the counter now."
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high, fresh subagents: full diff, then each fix round's change; 0 blocking after round 2's one

## Built
- `jig update` removes a `workflow` key outright. Under Removed it lists the old values and jig's standard, or that `roles` stays. The mapping to `roles` is gone. `jig roles` ignores the key and says so on stderr, and the hook refuses a config holding it.
- `RETIRED_LINES` holds 15 lines from jig's old AGENTS.md template. Update replaces each in place as part of the plan, and removes one whose replacement is already there. It skips a pararepo header and retired blocks. In a metarepo the edits are listed as a job's. The `check:` line waits until check.sh reads `--full`.
- Under Repo files to review, update lists two kinds of item, each with what owns its step now (`step_owner`, or `roles` for a tier or effort):
  - procedure lines in always-loaded instruction files;
  - repo skills, commands and agents in the root skill folders that overlap a node, role or step.
  Nothing there is edited.
- check.sh's finding names AGENTS.md's `test:` command.
- Text changes:
  - update skill: no keep option, skills never edited or deleted, the memory pass;
  - hubnode: a run's model instruction stays in that run's sessions;
  - RULES.md: `workflow` isn't read, and run-scoped settings.
- Part B: `contract_holders` gives fixes that name a condition. A heading counter that matches no line, with no run under way, is marked removable, and update removes it from the board. The update and survey skills and RULES.md say so.

## Done-when evidence
- **Fixtures A–E, the hook, `jig roles`/`jig workflow` on a `workflow` key, the mapping gone, `workflow` a retired key**: `bash tests/smoke.sh update_roles` printed all PASS: "update roles A: …", B, C, D (both lines), E, "the mapping is gone", "workflow is a retired board key".
- **The table**: same section, "each RETIRED_LINES opening matches exactly one template line, and no key is a template line" PASS (15 lines).
- **Fixture F, `check:` per repo, no duplicates**: update_roles F's six cases PASS, among them "--apply replaces each in place and every other line stays byte-identical", "a retired line whose replacement the file holds is listed for removal", "with a one-level check.sh the check: line waits", and "once check.sh reads --full, the check: line is replaced".
- **Pararepo and metarepo**: "lines inside a pararepo's generated header are not read; the retired line after it is" PASS, and "in a metarepo the retired line is listed as a job's, and --apply leaves AGENTS.md unchanged" PASS.
- **Fixture G**: the review line names /jig:review (a fresh session, once per handoff), the tier line names `roles`, the CLAUDE.md line names /jig:work, the product line isn't listed, and both files are byte-identical after --apply: all PASS. Review controls also pass: "Review at tier 1" is listed, and a product Tier/effort line isn't.
- **Fixture H, root folders only**: three PASS. ship → /jig:review and /jig:work, and land → /jig:hubnode. flash-board, notes and plugin/skills aren't listed. Every file is byte-identical, and `git status --porcelain -- .claude skills` is empty.
- **check.sh names `test:`**: `bash tests/smoke.sh check_levels` all PASS, with the template's TODO naming none and `npm test` named as the candidate.
- **Skill text**: `grep -nE "no keep|never edited or deleted|memory" plugin/skills/update/SKILL.md` matches lines 45, 58, 61 and 64. `grep -n "that run's sessions" plugin/skills/hubnode/SKILL.md` matches line 62. RULES.md § Workflow "Settings in effect" is rewritten, along with the per-task sentence.
- **No repo names**: the spec's grep over jig.py and the update skill prints nothing, and so does `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`. The update_roles case for it also PASS.
- **`marketing/FEATURES.md` rows (A and B)**: not done. The file is the hubnode's (gitignored).
- **Part B, holders A–E**: `bash tests/smoke.sh holders` all PASS. A: no "drop it at /jig:redocument's cleanup" in survey or the dry run; `board: reserve.section (` under Removed; reserve = step only, staged; survey has no holder block after the commit. B names docs/y.md:5 without "cleanup" and the counter is kept. C: a run under way keeps it. D: step is never listed. E: three holders, none saying cleanup.
- **State 1 and existing cases**: `bash tests/smoke.sh update agents_lines structure headings` all PASS, after one fix. Its first run failed 6 update cases: old-layout AGENTS.md now has retired lines replaced, and a Lanes block holds a retired Rulebook line. retired_lines now skips retired blocks, and the "never edits" case allows AGENTS.md changes only on RETIRED lines. The rerun of `update agents_lines update_roles` printed 147 PASS, 0 FAIL.
- **workflow section**: `bash tests/smoke.sh workflow` all PASS, its pre-roles block rewritten.
- `.jig/scripts/check.sh` exit 0; `claude plugin validate ./plugin`: "✔ Validation passed".
- **Evidence (registered repos with `workflow`)**: on the hubnode's word, `git clone --no-hardlinks` of jig, Maige-Eco, Maige-Lite and Maige-OS into the scratchpad. The plugin's dry run ran only inside each clone, with `JIG_CONFIG`/`XDG_CONFIG_HOME` outside it, and the clones were deleted after. `--apply` was not run, per the hubnode, so the "--apply leaves jig roles printing the standard" part is covered by smoke Fixture A only. The plans, trimmed to the relevant lines:

  jig (main fe2a494; refuses on its two open jobs, and still prints the plan):
    refused: the repo is behind this jig's layout (.jig/config.json, version 9), but:
      jobs are open: update-adopts-standard, bug-staging-research. Merge each (`jig merge`), or close it by deleting its entry from .jig/jobs.json on trunk, first: update moves files their worktrees rely on
      board: workflow (review 2,2; jig's standard: spec 2,2 · bug 2,1 · work 2,3 · review 2,2 · check 3,4)
      AGENTS.md: names no `.jig/RULES.md`: add under ## Workflow `- Rulebook `.jig/RULES.md`, enforced by `python3 .jig/jig.py`. Nodes: /jig:hubnode, /jig:subnode. Roles: /jig:spec, /jig:bug, /jig:work, /jig:review, /jig:...
      AGENTS.md: names no `.jig/scripts/setup.sh`: add under ## Commands `- setup:  `.jig/scripts/setup.sh` (runs itself in new worktrees and after merges; run it after changing dependencies)`
      tests/fixtures/ai-dev/repo/AGENTS.md: a second rulebook: fold what still binds into AGENTS.md or a page's Invariants, repoint what names it (nothing), then delete it. A package's own rules file may stay on the owner...
      tests/fixtures/claude-lane/repo/AGENTS.md: a second rulebook: fold what still binds into AGENTS.md or a page's Invariants, repoint what names it (nothing), then delete it. A package's own rules file may stay on the ...
      tests/fixtures/dot-jig-v7/repo/AGENTS.md: a second rulebook: fold what still binds into AGENTS.md or a page's Invariants, repoint what names it (nothing), then delete it. A package's own rules file may stay on the o...
      tests/fixtures/jig-0.2/repo/AGENTS.md: a second rulebook: fold what still binds into AGENTS.md or a page's Invariants, repoint what names it (nothing), then delete it. A package's own rules file may stay on the owne...
      .jig/scripts/check.sh: never reads --full: split it into a quick part (lint, type-check, unit tests: what runs on every stop) and a complete part run only with --full (the full suite, slow or end-to-end tests: what ...
      AGENTS.md:17: runs a step in the repo's own words; what owns it now: /jig:spec (/jig:spec). Kept as it is: the owner rewords or removes it
      AGENTS.md:20: runs a step in the repo's own words; what owns it now: /jig:review (a fresh session, once per handoff) (/jig:review, jig reviewed); /jig:work (jig handoff). Kept as it is: the owner rewords or removes it
      AGENTS.md:21: runs a step in the repo's own words; what owns it now: /jig:hubnode (jig gate); `roles` in .jig/config.json (.jig/RULES.md § Workflow) (a tier or effort). Kept as it is: the owner rewords or removes it
      AGENTS.md:22: runs a step in the repo's own words; what owns it now: /jig:hubnode (jig release). Kept as it is: the owner rewords or removes it
      tests/fixtures/ai-dev/repo/.aidev/RULES.md: rules for agents: what still binds goes to AGENTS.md (40 lines at most) or a skill; remove the file once it is empty
    Dry run: nothing changed, and --apply refuses until the above is fixed.
    exit 2

  Maige-Eco (main 5b1e420, metarepo: AGENTS.md lines listed as a job's):
      board: workflow (spec 1,2 · bug 1,1 · execute 1,3 · review 1,3; jig's standard: spec 2,2 · bug 2,1 · work 2,3 · review 2,2 · check 3,4)
      .jig/scripts/check.sh: never reads --full: split it into a quick part (lint, type-check, unit tests: what runs on every stop) and a complete part run only with --full (the full suite, slow or end-to-end tests: what ...
      AGENTS.md:10: jig's retired `check:` line: replaced with the template's (`- check:  `.jig/scripts/check.sh` (the quick part: runs on every stop; must pass before you're done). `check.sh --full` adds the complete sui...
      AGENTS.md:34: jig's retired line: replace it with `- Rulebook `.jig/RULES.md`, enforced by `python3 .jig/jig.py`. Nodes: /jig:hubnode, /jig:subnode. Roles: /jig:spec, /jig:bug, /jig:work, /jig:review, /jig:check, ea...
      AGENTS.md:28: runs a step in the repo's own words; what owns it now: /jig:spec (/jig:spec). Kept as it is: the owner rewords or removes it
      AGENTS.md:31: runs a step in the repo's own words; what owns it now: /jig:hubnode (jig release). Kept as it is: the owner rewords or removes it
      AGENTS.md:32: runs a step in the repo's own words; what owns it now: /jig:review (a fresh session, once per handoff) (/jig:review, jig reviewed); /jig:work (jig handoff). Kept as it is: the owner rewords or removes it
    Dry run: nothing changed. Run again with --apply to apply it; it stages and commits nothing.
    exit 0

  Maige-Lite (main 3bfb9ed):
      board: workflow (spec 1,2 · bug 1,1 · execute 1,3 · review 1,1; jig's standard: spec 2,2 · bug 2,1 · work 2,3 · review 2,2 · check 3,4)
    AGENTS.md, jig's retired lines (every other line stays as it is):
      .jig/scripts/check.sh: never reads --full: split it into a quick part (lint, type-check, unit tests: what runs on every stop) and a complete part run only with --full (the full suite, slow or end-to-end tests: what ...
      AGENTS.md:18: jig's retired `check:` line: replaced with the template's (`- check:  `.jig/scripts/check.sh` (the quick part: runs on every stop; must pass before you're done). `check.sh --full` adds the complete sui...
    Dry run: nothing changed. Run again with --apply to apply it; it stages and commits nothing.
    exit 0

  Maige-OS (main b2bbb54):
      board: workflow (bug effort 2 · review effort 3 · check effort 3; jig's standard: spec 2,2 · bug 2,1 · work 2,3 · review 2,2 · check 3,4)
    AGENTS.md, jig's retired lines (every other line stays as it is):
      .jig/scripts/check.sh: never reads --full: split it into a quick part (lint, type-check, unit tests: what runs on every stop) and a complete part run only with --full (the full suite, slow or end-to-end tests: what ...
      AGENTS.md:20: jig's retired `check:` line: replaced with the template's (`- check:  `.jig/scripts/check.sh` (the quick part: runs on every stop; must pass before you're done). `check.sh --full` adds the complete sui...
      AGENTS.md:27: runs a step in the repo's own words; what owns it now: /jig:spec (/jig:spec). Kept as it is: the owner rewords or removes it
      AGENTS.md:30: runs a step in the repo's own words; what owns it now: /jig:review (a fresh session, once per handoff) (/jig:review, jig reviewed). Kept as it is: the owner rewords or removes it
      AGENTS.md:36: runs a step in the repo's own words; what owns it now: /jig:bug (/jig:bug). Kept as it is: the owner rewords or removes it
    Dry run: nothing changed. Run again with --apply to apply it; it stages and commits nothing.
    exit 0


## Review
Three fresh Opus subagents at high reviewed: the full diff, then each fix round's change only.
- Round 1, full diff: 0 blocking, 10 non-blocking.
  - Taken:
    - #2: the tier/effort regex misfired on product text ("Tier 1 suppliers", "effort: 3 days"), which is what the spec rejects.
    - #6: positive controls for the pararepo case and for C and E.
    - #8: the stale home_findings comment.
  - Deferred, with rows in DEFERRED.md: the other seven.
    - retired lines outside AGENTS.md;
    - name-only matching on hubnode and flow step names;
    - an AGENTS.md symlink;
    - the old Lanes line about the hubnode;
    - a refused `roles` in the Removed line;
    - a header with no end line;
    - an empty remap.
- Round 2, change only: 1 blocking. The narrowed regex dropped a capitalized role beside one tier ("- Review at tier 1"). Fixed: the role group is case-insensitive with a plural. Also taken: a line-start anchor, since the lookahead had been quadratic (32 KB took 8 s, now 0.001 s); Fixture G lines for both cases; a comment reworded. JSON or flag settings deferred.
- Round 3, change only: 0 blocking. Three non-blocking, deferred: a weak negative control, the wider role match, and the spec's Fixture G now having five lines.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Workflow: Settings in effect; Documentation: the holders sentence), with the update, survey and hubnode skills.

## Shared files changed
- `plugin/templates/jig/jig.py`:
  - role_overrides and settings_or_refuse, the hook's config check, rewrite_board and BOARD_OPTIONAL: the reset;
  - RETIRED_LINES and the scans beside agents_lines;
  - check_levels_review;
  - contract_holders and cmd_update (Part B).
  Kept to those functions plus new ones beside agents_lines.
- `plugin/templates/jig/RULES.md`: § Workflow "Settings in effect", and the Documentation holders sentence.
- `plugin/skills/hubnode/SKILL.md`: Assigning a step, the run-scoped rule.
- `tests/smoke.sh`:
  - the `workflow` section's pre-roles block, rewritten;
  - new sections `update_roles` and `holders`, appended before UNITS and added to it;
  - two cases in `check_levels`;
  - the old-layout "never edits" case in `update` now allows retired AGENTS.md lines.

## Test by hand
In a repo with a `workflow` key, run the plugin's `jig update` dry run. Check that Removed names the old values and the standard, and that AGENTS.md's retired lines show with their replacements. Then run `--apply` and `git diff --cached AGENTS.md`: only those lines change.

## Left
- `marketing/FEATURES.md`: the `update` row and the Old-contract holders row (the hubnode's).
- The full suite at the gate.
- The spec's Fixture G text could add the two control lines smoke now has (deferred).
