# Handoff: bug-root-file-contract-path

Commit: bfbf39dfbfc42523444b7668b4a48bdc5f4f9c19
Date: 2026-11-11
Spec: .jig/specs/bug-root-file-contract-path.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on 1c17c11: no blocking; S1 and O1-O3 fixed in bfbf39d; hubnode ran smoke sync_buffer at bfbf39d

## Built
<!-- what this delivers, in a few lines -->
`jig sync` no longer asks about a root file every repo has (`ROOT_DOCS`: AGENTS.md, CLAUDE.md,
GEMINI.md, README.md, CHANGELOG.md) when a decision names it bare. It counts only after this repo's
name (`<name>/AGENTS.md`, `<name>:AGENTS.md`); `this/` is the metarepo's own. Paths under folders
keep the bare match. The line is now a question: "<path> is not a contract path, and <ids> name it.
If the decision describes something this repo can change there, add the path to "contract_paths"
in .jig/para.json; if not, nothing is needed." RULES.md (The sync buffer) and hubnode step 5 say
to put it to the owner with what the decision says, never as a fix.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Bare `AGENTS.md` decision (E-001's wording, D-011) prints no line: smoke sync_buffer "a root file named bare (D-011) or after this/ (D-014) is no pointer here: no AGENTS.md line" PASS.
- `sb-para/AGENTS.md` (D-012) still prints the line, exactly: "a root file after this repo's name (D-012) is reported … and the line asks" PASS; bare `docs/ui.md` (D-013) still reported: "jig sync reports a pararepo path …" PASS.
- The line asks and doesn't open its remedy with "add": checked with `grep -qx` on the full line.
- RULES.md and plugin/skills/hubnode/SKILL.md step 5 say the same as the code (diff).
- `bash tests/smoke.sh`: 982 PASS, 0 FAIL, exit 0 (bug-root-file-contract-path-smoke-2.out in the session notes). `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: ok. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: nothing (exit 1).

## Review
<!-- findings from the adversarial review, and what you did about each -->
Reviewed by the hubnode on 1c17c11; nothing blocking.
- S1 (should-fix) RULES.md's "(`AGENTS.md`, `README.md`, …)" read as open-ended: fixed in bfbf39d, all five named.
- O1 `uncovered_paths` counted `this/AGENTS.md` as this repo's: fixed in bfbf39d (`this_repo_names(root) - {"this"}`, as `pointers()` does), tested by D-014.
- O2 ids ran into the path ("D-001, D-006, and docs/ui.md …"): fixed in bfbf39d, path first.
- O3 no direct test that bare AGENTS.md alone prints nothing: fixed in bfbf39d (release at pin v0.1.0 prints no AGENTS.md line).
- Deferred, rows in .jig/ledgers/DEFERRED.md: a root file in another case (`readme.md`) still matches bare; a nested `docs/README.md` named as every repo's is still reported.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty and has no docs/ tree; the checker's documentation is `plugin/templates/jig/RULES.md` (The sync buffer, updated here) and `plugin/skills/hubnode/SKILL.md` step 5 (updated here).

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: `uncovered_paths` only (the match and the printed line).
- `plugin/templates/jig/RULES.md`: The sync buffer paragraph on cited paths.
- `tests/smoke.sh`: sec_sync_buffer: decisions D-011, D-013, D-014 at v0.1.0, D-012 at v0.2.0; message greps reworded.
- `.jig/ledgers/DEFERRED.md`: two appended rows (append file, on the hubnode's word).

## Test by hand
<!-- what a person should click or watch -->
In a pararepo whose pinned metarepo decision says "every product repo's `AGENTS.md`", run
`python3 .jig/jig.py sync` on trunk: no "AGENTS.md is not a contract path" line.

## Left
<!-- what remains on this job -->
Nothing; the spec is done.
