# Handoff: feature-request

Commit: bf45fcde704cea9c8e4793110c2717ad13bbcdd3
Date: 2026-11-09
Spec: .jig/specs/feature-request.md
Review: tier 2, effort 2
Ran: fresh Opus review of e26a307: no blocking; S1 update request resolved by an unrelated spec (reproduced, fixed + smoke), S2 update-Intent wording, O1 hubnode duplicate cut, O2 header case exit code; user-story/feedback sibling gap deferred. Fixes in bf45fcd checked by diff and smoke staging.

## Built
A new staging kind, `kind: feature-request`: plain prose from the owner ("I want it to do xyz") that the hubnode interprets into a spec.
- `jig staging resolve` refuses until a spec carries the file's mark, saying "a request resolves into a spec".
- A `change: update` request whose destination names a spec waits for that spec.
- RULES.md (Staging) and the stage skill describe the kind, its free-prose body, the quoted `Source:` line, and the `Interpreted:` decisions.
- The hubnode skill's staging bullet points to /jig:stage.

## Done-when evidence
- Smoke `staging`: `bash tests/smoke.sh staging` → PASS "a feature request is listed, and its header passes", "a request waits for a spec that carries it, saying it resolves into a spec", "with that spec, the request resolves", "an update request naming spec A waits while only spec B carries its mark", "once spec A carries it, the update request resolves".
- Header check: same run → PASS "a misspelt kind is refused, naming the kinds" (`feature` refused, message lists `feature-request`).
- Docs: RULES.md Staging and plugin/skills/stage/SKILL.md name the kind, the free-prose body, and `Interpreted:`; the stage description names "feature request" (see diff).
- `bash tests/smoke.sh` → exit 0, 751 PASS, 0 FAIL; `claude plugin validate ./plugin` → "✔ Validation passed"; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → no output (exit 1). `.jig/scripts/check.sh` → exit 0.

## Review
Fresh review of e26a307 at tier 2, effort 2, by the hubnode. Nothing blocking.
- S1 (should-fix): an update request naming a spec resolved as soon as any spec carried its mark. Fixed in bf45fcd: it now checks `landed(dest)`, with two new smoke cases. The same gap in user-story and feedback is deferred (DEFERRED.md row) because it is outside this spec.
- S2 (should-fix): it was unclear how an update request's Intent relates to the amended spec. Fixed: add to that spec's Intent and list the decisions under its Decisions (RULES.md, stage skill).
- O1 (optional): the hubnode skill repeated the rules. Taken: cut to a pointer in its staging bullet.
- O2 (optional): the header case now also asserts that `jig staging` exits 0. Taken.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Staging), updated here, plus the stage skill.

## Shared files changed
- plugin/templates/jig/jig.py: `KINDS` and `cmd_staging`'s resolve branch.
- plugin/templates/jig/RULES.md: the Staging section.
- tests/smoke.sh: cases in `sec_staging`.
- plugin/skills/stage/SKILL.md: the header, the description, and how a request is staged and resolved.
- plugin/skills/hubnode/SKILL.md: one line in the staging bullet.
- .jig/ledgers/DEFERRED.md: the review's deferred row, on the hubnode's request.

## Test by hand
Stage a `kind: feature-request` file in a repo and run `jig staging resolve` on it. It should refuse until a spec carries `Source: <source> (staged as <file>)`, then resolve. Run `/jig:stage` on a request and check that the spec it produces quotes the request and lists `Interpreted:` decisions.

## Left
- The FEATURES.md row in the main checkout (the spec's Touches; outside this worktree's files).
- The deferred user-story/feedback destination check.
