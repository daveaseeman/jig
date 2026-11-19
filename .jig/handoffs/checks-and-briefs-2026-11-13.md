# Handoff: checks-and-briefs

Commit: b4dea710dc20f3c7098fb0561f2e2dde53d56e59
Date: 2026-11-13
Spec: .jig/specs/checks-and-briefs.md
Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "A session that ends a turn, for any reason, starts the full check."
Source: jig hubnode session / 2026-11-13 / Dave with Claude (Opus 5.5) (staged as feedback-jig-2026-11-13-workflow-not-followed.md): "My workflow did not run a check or review like smoke 3-4 times per job, that's insane."
Source: maige-ecosystem hubnode session / 2026-11-13 / Dave (staged as feedback-maige-ecosystem-2026-11-13-job-flow-speed.md): "why are these taking so long?"
Source: adventure-studio hubnode session / 2026-11-13 / Dave (staged as feedback-adventure-studio-2026-11-13-job-speed-local-checks.md): "The owner believed jobs ran on a server ("My mac can't run fable")."
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high

## Built
- Two check levels: the template `check.sh` runs its quick part bare and both parts with `--full`; `jig gate` prints `check.sh --full`, the check step's tier and effort, and `jig checked`.
- `jig checked --tier --effort --seconds` records to `<git-common-dir>/jig/checked.log` and warns on numbers that differ from the check step's. `jig checked --trace [COMMAND]` prints the first-parent bisect.
- `jig mark J gated` requires a record for the gate checkout's commit, and refuses with no checkout. `--batch` writes `"check": "batch"`, and `jig merge` then adds a `Check: batch` trailer. `jig release` refuses while a batch merge since trunk's last record exists; `--force` overrides. `jig status` prints the last complete check. `jig update` lists a `check.sh` that never reads `--full`.
- Stop hook: skips when the worktree's tree (built through a temporary index) is the one that last passed, or when only `.jig/jobs.json` or `.jig/staging/` changed. A dirty submodule always runs. It logs each run to `<git-dir>/jig/check.log`.
- SessionStart hook (`session-start.sh`, matcher startup|resume|compact): one line naming /jig:hubnode on trunk when a job is open or a file is staged, or /jig:subnode and the job in a job's worktree. Otherwise it prints nothing.
- Skills: the hubnode skill gets briefs (execute, fix, review, check), the `running <model>` rule with effort taken from the host, a refused-start rule, the local-machine line, one check session at a time, and the batch rhythm. The subnode, review, release and init skills change to match, as do RULES.md § gate and § Workflow and both AGENTS.md files.

## Done-when evidence
- Template `--full`: smoke check_levels "the template check.sh runs only its quick part…", "with --full it runs the quick part, then the complete one", "header no longer says jig gate runs the suite": PASS.
- Gate prints: "gate: prints check.sh --full…", "a repo override of the check step shows its numbers": PASS.
- `jig checked` record and warning: "checked: records HEAD, the numbers…", "numbers that differ… warn, naming both": PASS.
- `mark gated` refusals and pass: "gated with no gate checkout at all is refused", "with no jig checked record… refused", "a record for another (older) commit is refused too", "after jig checked in the checkout, gated passes and removes the checkout": PASS. merge_after_sync updated and PASS.
- `--batch` and the trailer: "gated --batch passes with no record and writes check: batch", "a job gated --batch merges with a Check: batch trailer": PASS.
- Release: "refuses while merges… carry Check: batch, naming them", "after check.sh --full and jig checked… passes", "--force still overrides": PASS.
- `--trace`: "lists the merges… oldest first", "the printed first-parent bisect… names the second merge": PASS.
- Stop hook: "two stops with no change… run the check once", "the real index is left as it was", "a touched file runs it again, an untracked one too", "keyed under the worktree's git dir" (main and linked worktree), "a change to only .jig/jobs.json or .jig/staging/ runs nothing", "a failing check… records no pass", "an edit inside a submodule is a change": PASS.
- check.log and status: "each run's level, seconds and exit code are appended…", "status: prints the last complete check's seconds and date": PASS.
- Update: "lists a .jig/scripts/check.sh that never reads --full", "the template's check.sh… is not listed": PASS.
- RULES.md § Workflow ("Two levels of check") and § gate, the hubnode, subnode, review, release and init skills, and both AGENTS.md files: in the diff. `grep -n -- "--full" plugin/skills/hubnode/SKILL.md` gives lines 161 (the batch rule) and 203 (the check template) only.
- Role line: smoke role_line (no .jig/, no work, staged file, open job, job worktree, each source, exit 0, no file written, hooks.json matcher): PASS.
- Both: `.jig/scripts/check.sh` exits 0; `claude plugin validate ./plugin` passes; the Maige/Daisy grep is empty. Sections run: check_levels, role_line (40 PASS at the last commit); rules, merge_after_sync, hardware and release earlier, all PASS once the hooks.json formatting was fixed. The full `bash tests/smoke.sh` is the check step's at the gate.

## Review
Fresh Opus subagent at high, given only the diff, the spec and AGENTS.md. It found nothing blocking.
- should-fix: an edit inside a submodule didn't change the tree key, so the Stop hook skipped the check. Fixed: a dirty submodule disables the skip. Smoke case added.
- should-fix: `jig merge` of a job never marked gated owes no check. Deferred to DEFERRED.md: a trailer on every ungated merge would make 13 smoke sections' releases refuse, and it changes release for adopters. The owner should decide this.
- should-fix (partial): the kickoff that `jig open` prints lacks "never --full". Deferred: `cmd_open` is outside Touches, and the subnode skill carries the line.
- should-fix (partial): the worktree key was tested only in the main checkout. Fixed: a linked-worktree smoke case.
- optional: `--trace` printed a compound command unquoted. Fixed: it now prints `git bisect run sh -c '<cmd>'`.
- optional: the temp index's loose objects, the commit-keyed record going stale on a re-gate, the jobs.json-only skip when HEAD never passed, and this repo's `check.sh` lacking `--full`. All deferred with reasons in DEFERRED.md.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's product docs are RULES.md and the skills, both updated here; this repo has no docs/ tree for jig.py

## Shared files changed
- plugin/templates/jig/jig.py: new `cmd_checked`, plus helpers next to `cmd_mark`, and edits to `cmd_mark`, `cmd_merge` (the trailer), `cmd_gate` (the printed lines), `cmd_release` (the refusal), `cmd_status` and `cmd_update`'s review list, and the parser.
- plugin/templates/jig/RULES.md: § Handoff, gate, merge item 2; a new `### Two levels of check` at the end of § Workflow; two lines in § Commands.
- plugin/skills/hubnode/SKILL.md: Who runs each step (the running line, refused starts), Opening a job (the local-machine line), Gating a handoff (one check session at a time, mark needs checked), and new `## A batch` and `## Briefs` sections ahead of A roadmap change.
- plugin/skills/subnode/SKILL.md: Check in (the running line), Build (never --full), Hand off step 1.
- plugin/skills/review/SKILL.md: Dispatch (the running line), and "rerun no check the builder's report shows".
- tests/smoke.sh: new sections check_levels and role_line, added to UNITS; one added line in merge_after_sync (`jig checked` in the scratch checkout before `mark K gated`).
- .jig/specs/checks-and-briefs.md: two `Interpreted:` decisions the hubnode accepted. .jig/ledgers/DEFERRED.md: six rows.

## Test by hand
- In a jig repo, start a session in the trunk checkout with a job open: its first context shows the hubnode line. Run `/compact` and the line returns. Open the job's worktree in a session: it shows the subnode line.
- End two turns in a row with no edits: the second stop returns at once (the stop log `<git-dir>/jig/check.log` gains one line, not two).

## Left
- Nothing in the spec. The recheck brief arrives with `cheaper-rounds`. The owner's `/jig:update` will list this repo's `.jig/scripts/check.sh` for its `--full` split.
