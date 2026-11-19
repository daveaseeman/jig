# Handoff: bug-meta-agents-block

Commit: 55438e005912c392d1aa95713e1f9bd70c2585e2
Date: 2026-11-17
Spec: .jig/specs/bug-meta-agents-block.md
Source: Maige-Eco hubnode session / 2026-11-17 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-17-metarepo-agents-line.md): "A metarepo's AGENTS.md has no jig line for its rules, so `jig update` flags the repo's own line for good": `AGENTS.md:31: runs a step in the repo's own words; what owns it now: /jig:hubnode (jig release). Kept as it is: the owner rewords or removes it`
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
A metarepo's AGENTS.md gets jig's generated block for its rules, as a pararepo gets its header.
- `meta_header` (jig.py): the four lines of the owner's M2 (2026-11-17, spec Decisions 1). They cover M1, M4, M6 with `meta.json`'s `decision_prefix`, M3 naming `entry_files` (not listing them), and "Only `jig release` tags". The block sits under the shared `jig:meta` markers, so `outside_header` already exempts it.
- `jig init --meta` writes the block through `with_header`.
  - On a metarepo's trunk (meta.json on trunk) it writes nothing to AGENTS.md. It names a job's worktree (M4) and any files it did write.
  - In a job's worktree it rewrites the block and says to commit it on the branch. When the block is current it says so.
  - It refuses in a repo with `.jig/para.json`.
- `jig update` lists AGENTS.md (`meta_block_lines`) when a metarepo's block is missing or older than this jig's, as a job's once this jig is on trunk. The repo's restated lines are the owner's to remove. `--apply` leaves AGENTS.md as it was.
- `agents_lines` reads only lines outside generated blocks, so the block's `.jig/RULES.md` citation doesn't hide the Rulebook-line proposal.
- Docs: RULES.md (Metarepo and pararepos), the init skill's metarepo paragraph, and a `### Fixed` line in `.jig/decisions.md`.

## Done-when evidence
- The block, at setup: smoke `metarepo`, "meta block: init --meta writes one block under AGENTS.md's title, at most 5 lines between its markers", "…states M1, M4, M6 with the E- prefix, M3, that only jig release tags, and names .jig/RULES.md", "…the console names AGENTS.md among the files to commit": PASS.
- The fix fires: smoke `update_roles`, "no line of a metarepo's block is listed, jig release included": PASS.
- Update lists a missing or stale block: smoke `update_roles`, "a metarepo with no block lists AGENTS.md: jig's block, init --meta in a job once this jig is on trunk (M4), restated lines the owner's; --apply leaves it as it was", "a metarepo block in an older wording is listed the same way", "a plain repo gets no metarepo block line", "a pararepo gets no metarepo block line": PASS.
- Refresh happens in a job: smoke `metarepo`, "on trunk with meta.json there, init --meta leaves AGENTS.md alone and names a job's worktree (M4)", "in a job's worktree init --meta rewrites the old block…", "after the job merges, update's dry run lists no AGENTS.md line": PASS.
- Only metarepos get it: "meta block: a plain jig init writes no metarepo block", "para: init --para writes no metarepo block", "meta block: init --meta in a pararepo refuses…": PASS.
- The reported symptom is gone: smoke `update_roles`, "the repo's own line beside the block is the only AGENTS.md line listed": PASS.
  - By hand, on a `git archive` copy of Maige-Eco's HEAD (the repo only read), the plugin's dry run before listed the block line and `AGENTS.md:31: runs a step in the repo's own words; what owns it now: /jig:hubnode (jig release)`.
  - After `init --meta` on a branch replaced line 31 with the block, it listed no AGENTS.md line. The copy's M5 hook stopped the scratch merge, so the dry run read the merged working tree.
- The docs say so: `grep -n "init --meta" plugin/templates/jig/RULES.md` finds lines 1104–1110 (the block beside the pararepo header). `grep -n "AGENTS.md" plugin/skills/init/SKILL.md` finds lines 58–60.
- The whole check:
  - `.jig/scripts/check.sh`: rc=0.
  - `bash tests/smoke.sh metarepo update_roles pararepo agents_lines`: rc=0, 220 PASS, 0 FAIL.
  - `grep -rnE 'Maige|maige|E-058' plugin`: no hits.
  - The full smoke is the check role's, at the gate.

## Review
- review-work of 0812388: blocking 0.
  - should-fix 1: the block hid the Rulebook-line proposal, because `agents_lines`' `outside` ignored `outside_header`. Fixed in 55438e0 and smoked ("the block's citation of .jig/RULES.md loads no rulebook…"). On that fixture 0812388's jig.py proposed nothing; 55438e0's proposes the line.
  - optional 2, taken in 55438e0:
    - `init --meta` refuses where para.json exists;
    - the trunk message names what it wrote;
    - a current block says so;
    - the init skill says "in a job's worktree once `.jig/meta.json` is on trunk".
- review-change of 55438e0: blocking 0, all five items confirmed. One optional note was deferred: `init --para` in a metarepo would replace the metarepo block. It has a row in `.jig/ledgers/DEFERRED.md` ([assumed], out of scope by the spec).

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Metarepo and pararepos, updated here) and the init skill (metarepo paragraph, updated here).

## Shared files changed
- `plugin/templates/jig/jig.py`: `meta_header`, `cmd_meta_init`, `meta_block_lines` (new, called from `files_to_review`), `agents_lines`' `outside`, and `outside_header`'s docstring. No function is shared with bug-process-in-pages.
- `plugin/templates/jig/RULES.md`: three sentences appended to the paragraph at "Each side's gates are on only when its file is on trunk".
- `tests/smoke.sh`: new cases at the end of `sec_metarepo`, one after `sec_pararepo`'s header-size case, and new cases in `sec_update_roles` after the metarepo retired-line fixture.
- `plugin/skills/init/SKILL.md`: two sentences closing the metarepo paragraph. bug-process-in-pages edits this skill's cap line, not this paragraph.
- `.jig/decisions.md`: a `### Fixed` line under `## Unreleased`.

## Test by hand
In a repo with the AGENTS.md template, run `jig init` and then `jig init --meta --prefix E-`. AGENTS.md shows the block under its title. Commit, then rerun `init --meta` on main: AGENTS.md is untouched and the message names a job's worktree. Edit the block's last line on a branch, merge it, and run the plugin's `jig update`: AGENTS.md is listed as a job's.

## Left
Nothing on this job. Maige-Eco gets the fix through `/jig:update`, then a job there runs `jig init --meta` and removes line 31 (the spec's Out of scope).
