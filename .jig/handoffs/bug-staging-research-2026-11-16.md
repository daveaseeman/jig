# Handoff: bug-staging-research

Commit: 2e98c3eca5115daf8353ab8e42a26970924712c4
Date: 2026-11-16
Spec: .jig/specs/bug-staging-research.md
Source: Maige-Lite hubnode session 25f7e824 / 2026-11-13 / Dave Seeman (staged as feedback-maige-lite-2026-11-13-staging-preliminary-research.md): "I wouldn't log those as decisions because they're so preliminary"
Review: tier 2, effort 2
Ran: Opus high subagent on the full diff (0 blocking, 4 non-blocking: 3 fixed, 1 deferred), then a fresh Opus subagent on the fix round (0 blocking, 2 deferred)

## Built
- `jig staging check` warns (never fails) on each Accepted entry of a `decisions` file: `<id> says Accepted (<who>, <date>): resolve logs it as decided; confirm <who> accepted it, else write Proposed`. The prefix is read from the entries' own headings, so it works outside any repo and for any prefix.
- Stage skill: Staging a file chooses the target by ownership (What the metarepo holds), the kind by content, and `Accepted` only for what the person accepted in the chat; A batch confirms the new warning with the user; Resolving asks whether this repo owns the subject and whether it is as settled as it says.
- RULES.md § Staging: one sentence for the target rule, one for the warning.

## Done-when evidence
- Accepted + Proposed decisions file → exit 0, one warning naming D-?a and Dave: `bash tests/smoke.sh staging_batches pararepo` → PASS "staging check: a decisions file warns once, on the Accepted entry, naming its id and who, and passes".
- X-? prefix warned alike outside any repo; a doc file gets no warning; existing check cases pass: same run, PASS on each, 106 PASS, 0 FAIL.
- Replay (pararepo, generic names hub/rp/widget): four warnings and passes; corrected batch passes with no warning; resolve forwards both; the research page lands with its Source: line; the page update refuses with "needs judgment" and stays staged: five PASS lines "staging replay: …".
- Skill and RULES.md greps: PASS "stage skill: …" and "RULES.md § Staging: …".
- marketing/FEATURES.md row: skipped, the hubnode's (gitignored).
- `.jig/scripts/check.sh` → rc 0 (validates the plugin, compiles jig.py); `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → empty. The `staging` section was not run: it has no `staging check` case on decisions, and the change only adds a warning.

## Review
Full diff (Opus high subagent): 0 blocking. Fixed: nameless Accepted printed `(, date)`; the replay's last case was a bare refuse (now greps 'needs judgment' and checks the file stays); the doc-kind case now asserts `ddoc.md: ok`. Deferred: a later entry with a different prefix than the first gets no warning (DEFERRED.md).
Fix round (fresh Opus subagent, change only): 0 blocking; two deferred (no case for the nameless warning; 'needs judgment' is shared with the root-rules branch, unreachable here).

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap (a new page starts from .jig/docs-page.md), or no page needed because RULES.md § Staging is the description of `staging check`, and this change edits it to name the warning

## Shared files changed
- `plugin/templates/jig/jig.py`: only `cmd_staging_check` (the warning).
- `plugin/templates/jig/RULES.md`: two sentences appended in § Staging.
- `tests/smoke.sh`: cases appended at the end of `sec_staging_batches` and `sec_pararepo`.
- `.jig/ledgers/DEFERRED.md`: three rows for untaken review findings.

## Test by hand
Stage a `decisions` file with an `Accepted (you, date).` entry and run `python3 plugin/templates/jig/jig.py staging check <file>`: one warning line, exit 0.

## Left
- The `marketing/FEATURES.md` staging-batches row (the hubnode's).
- The full suite, at the gate.
