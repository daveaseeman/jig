# Handoff: roles-and-flows

Commit: 89b1c226e426904a76b247e6417659b2b50fa96b
Date: 2026-11-15
Spec: .jig/specs/roles-and-flows.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high

## Built
Part 2 of roles-and-flows, finishing the spec (Part 1 handed off at 8211b56):
- Seven node and role skills (hubnode, subnode, spec, bug, work, review, check), each naming its
  settings (`jig roles`), its steps, and `jig next` for what follows; briefs live in each role.
  consolidate and verify are removed; the entry points and standalone tools say where they sit.
- RULES.md § Workflow: the nodes, roles and workflows tables, the fixed rules, the session rules
  and the contracts, tiers and efforts only, `plugin/tiers.json` named. § Nodes replaces Roles.
- README "Who does what": generated light and dark SVGs (`scripts/roles_svg.py`, from ROLES,
  HUBNODE_STEPS and FLOWS) through `<picture>`, the tables in `<details>`; `.jig/scripts/check.sh`
  fails when the SVGs are stale.
- The owner's rulings during the build: `jig merge` removes a merged job's clean worktree and
  branch (a new done-when line); the hubnode runs `jig release` ("Hubnode runs it"); every
  subnode runs outside the trunk checkout ("Detached worktrees"), so `jig staging` lists the
  primary checkout's files from any worktree, `jig checked --trace` takes a detached commit of
  trunk's, and session-start.sh names the subnode in any worktree; Release is
  check → release → push → publish.

## Done-when evidence
Part 2 items. Checks run, each section once unless it failed:
- `.jig/scripts/check.sh` → exit 0 (validate, compile, `roles_svg.py --check`); `claude plugin validate ./plugin` → passed.
- `bash tests/smoke.sh svg agents_lines update role_line` → rc 0, 128 PASS.
- After the merge cleanup: `bash tests/smoke.sh next report_fixes decisions svg workflow` → rc 0, 173 PASS;
  every other unit that merges a job: `board_split cheaper_rounds consolidate entry_globs homes merge_after_sync merge_derived metarepo page_contract pararepo pararepo_commands r6_ints roadmap staging_batches supersede sweep touches` → rc 0, 647 PASS.
- After B1/B2: `bash tests/smoke.sh role_line check_levels` → rc 0, 42 PASS.
- After the review-change fixes: `bash tests/smoke.sh next workflow metarepo svg role_line check_levels` → 200 PASS, 1 FAIL (the new ignored-file case committed its .gitignore after `jig open`); fixed, `bash tests/smoke.sh next` → rc 0, 26 PASS.
- After the Release row: `bash tests/smoke.sh svg workflow` → rc 0, 47 PASS.
- Seven skills: plugin/skills/{hubnode,subnode,spec,bug,work,review,check}/SKILL.md (9fc8ec1); each names `jig roles`, its steps, `jig next`.
- SessionStart loads the node only: plugin/scripts/session-start.sh (hubnode on trunk; subnode, then the brief's role, in any worktree: 885bf67); smoke `role_line` "in a detached checkout of trunk, it names /jig:subnode…".
- bug's trigger: plugin/skills/bug/SKILL.md description; `grep -n "reports something broken" -r plugin/skills` → empty.
- Every inventory row carried out: listed below, each with its commit.
- `jig merge` cleanup: smoke `next` "a gated job merges, then its clean worktree and its branch are removed", "an untracked file … left, named", "a clean worktree holding an ignored file is removed, and the merge names the file"; report_fixes and decisions updated (d241b59, 537a3cb).
- README "Who does what": README.md, assets/roles-and-flows-{light,dark}.svg, scripts/roles_svg.py; smoke `svg` "a role's effort changed in a scratch copy fails the check, naming each SVG".
- RULES.md § Workflow: plugin/templates/jig/RULES.md (d5f9360, 885bf67, 29ab9ec); no Claude, Opus or Sonnet in it or the README's section.
- `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → empty.

Inventory, each row with the commit that did it:
- hubnode: node skill; assign, gate, merge, release, push, publish; order to FLOWS; briefs to the roles — 9fc8ec1, d241b59, 885bf67, 29ab9ec
- subnode: node skill; check in, take one role, report back — 9fc8ec1, 885bf67
- spec: role skill; absorbs consolidate; the remap and the plan are its, pointed to in redocument and adopt (DEFERRED row: pointers, not moved text) — 9fc8ec1, 885bf67
- bug: role skill; ends with its spec; trigger narrowed — 9fc8ec1, 885bf67
- review: role skill; review-work, review-change, `--blocking`, who records — 9fc8ec1, d241b59
- (new) check: role skill; complete suite, `jig checked`, trace, survey — 9fc8ec1, 885bf67, 29ab9ec
- (new) work: role skill; build, evidence (verify's), handoff, fixes, syncs — 9fc8ec1
- consolidate: merged into spec, removed — 9fc8ec1
- verify: merged into work, removed — 9fc8ec1
- feedback: the owner's command, a wrapper loading bug — 9fc8ec1
- fix: entry point for Feedback; grouping is spec's consolidate — 9fc8ec1, d241b59
- release: entry point for Release; the check before it is check's, `jig release` the hubnode's — 9fc8ec1, 885bf67, 537a3cb
- redocument: entry point; the remap is spec's — 9fc8ec1
- adopt: entry point for Survey; the plan is spec's — 9fc8ec1
- update: entry point; the plan is spec's, the apply work's — 9fc8ec1
- survey: standalone; the check role's survey step — 9fc8ec1
- stage, retro, hardware, repos, init: standalone (stage: `## Roles`; hardware: the page is spec's; init: the check role) — 9fc8ec1
- Commands: next, roles, flows, workflow alias, rules, reviewed --change --blocking (Part 1); merge's cleanup — d241b59; release — 885bf67, 29ab9ec

## Review
Review-work of 0b7b6d0..053c844, a fresh subagent at tier 2, effort 2 (claude-opus-5-5 at unknown):
- blocking B1, the check role's release run ran `jig release` → the owner ruled "Hubnode runs it"; 885bf67, then the Release row (29ab9ec, the hubnode's ruling).
- blocking B2, role sessions with no job had no place to run and the hook called them hubnode → the owner ruled "Detached worktrees"; 885bf67.
- should-fix S1, who records a review → d241b59 (skills), 537a3cb (RULES.md).
- should-fix S2, fix skill grouped inline and wrote two specs → d241b59.
- should-fix S3, no subnode card, bug card without its spec → d241b59.
- optional, taken: a `session` override's message, AGENTS.md's cycle, the hook comment, README's legend, subnode's role from its brief (d241b59).
- optional, deferred (DEFERRED rows in 885bf67): the hubnode's Gating/Batch prose, the hand-written README tables, the drawing's red/letters/width, Bug's `⇢ Job`, spec's pointers to the remap and plan.
Review-change of 053c844..885bf67 (claude-opus-5-5 at high): blocking, a leftover release clause → 537a3cb; blocking, `jig staging` blind in a detached worktree → 537a3cb (smoke: staging); should-fix, RULES.md's third version of who records → 537a3cb; should-fix, the Release row → the hubnode's ruling, 29ab9ec; optional taken: ignored files named at cleanup, `--trace` on any detached commit of trunk's, the check description, the briefs' worktree slot, the `steps` refusal, the hook header, the subnode card (537a3cb); optional deferred: reserved worktree names, the `branch -d` message (DEFERRED rows, 537a3cb).
Review-change of 885bf67..29ab9ec (claude-opus-5-5 at high): all four fixed, no blocking or should-fix; optional ×3 (`--trace` accepts a merged job's commit, refuses a non-trunk branch at trunk's tip, a long RULES.md line) → DEFERRED rows in 89b1c22, which holds only those rows and carries the same record.
The installed jig (`.jig/`) predates `--blocking`, `--change` and `--partial`, so each round was recorded with its plain `jig reviewed`.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here: § Nodes, § Workflow, Handoff, gate, merge (the merge's cleanup), Commands.
- [x] UNOWNED scripts/roles_svg.py — no page needed because it is this repo's own build script, described in its docstring and in README's "Who does what"; this repo's docmap is empty and it has no docs/ tree.

## Shared files changed
- `plugin/templates/jig/jig.py` (shares): ROLES' `session` and `then`, HUBNODE_STEPS' release, FLOWS' Release row; `jig merge`'s cleanup; `jig staging` reading the primary checkout; `--trace` in a detached commit of trunk's; the consolidate messages; the override refusal reason.
- `plugin/templates/jig/RULES.md` (shares): § Nodes, § Workflow, Handoff, Commands, Staging.
- `tests/smoke.sh` (shares): sections `svg` (new), `next` (merge cleanup), `role_line`, `check_levels`, `staging`, `workflow`; report_fixes and decisions for the removed worktree and branch.
- `.jig/scripts/check.sh` (owns, the one `.jig/` file the owner approved): the SVG freshness line.
- `.jig/specs/roles-and-flows.md` (common): the merge-cleanup done-when line, the Commands row for release, and the owner's and hubnode's rulings in Decisions.
- `.jig/ledgers/DEFERRED.md` (common): rows for the untaken findings.

## Test by hand
Open README.md on GitHub in light and dark themes: the "Who does what" picture matches the theme,
and the tables under "The same, as tables" say the same. In a scratch repo, merge a gated job and
watch its worktree and branch go; leave a file in another job's worktree and see the merge name it.

## Left
Nothing on this spec. marketing/FEATURES.md is the hubnode's at merge (gitignored here). The
full suite runs once at the gate.
