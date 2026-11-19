# Handoff: bug-m5-release-level

Commit: ab208611d97d9946dde452a02c03df968bbd9757
Date: 2026-11-18
Spec: .jig/specs/bug-m5-release-level.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high

## Built
The M5 case in `sec_r6_ints` (tests/smoke.sh ~1897) releases its metarepo with `--feature` and still expects v0.2.0, so the batch check of trunk 786e212 passes that case again. jig.py is unchanged: `--patch` stays the default, as rig-and-versioning built it.

## Done-when evidence
- `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh r6_ints` → 20 PASS, 0 FAIL, exit 0, including `PASS  M5: review, then a note, then a sync of trunk: jig merge is accepted, and so is the release`.
- `grep -n "release >/dev/null 2>&1 && git tag | grep -qx v0.2.0" tests/smoke.sh` → no matches. The other metarepo cases that expect a feature tag pass `$(mf)` (~1012), or are first releases expecting v0.1.0 (~1880, ~4953).
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → exit 0 (`check.sh exit=0`, at ab20861).

## Review
- review-work of main...ab20861: clean, blocking 0.
- should-fix: the spec's Intent reads as "expects the default level", while its Correction and the diff use `--feature`. Deferred (a DEFERRED row): a wording slip in the spec, which the merge closes.
- should-fix: no check.sh evidence was shown to the reviewer. Taken: it is above.
- optional: Alternatives could list an assertion with no level. Deferred (a DEFERRED row).

## Fold-in
- [x] No documentation page covers `tests/smoke.sh`, and the test's change describes no product behavior.

## Shared files changed
- `tests/smoke.sh`: the one M5 case.

## Test by hand
- None: the smoke section is the test.

## Left
- Nothing.
