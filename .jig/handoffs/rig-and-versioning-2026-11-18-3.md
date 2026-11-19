# Handoff: rig-and-versioning

Commit: 3217adc6377362f9baf2f39cd9690a2d3fab6127
Date: 2026-11-18
Spec: .jig/specs/rig-and-versioning.md
Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-rig-batch-one-job.md): "write the /jig:feedback so that these would be offered together in the first round in the future"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make sure subnodes archive and their specs are removed when jobs are done and merged"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make jig:rig also close finished specs and subnodes"
Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-versioning-and-pin-trigger.md): "Maige-Eco's next release moves its glossary from `README.md § Glossary` to `docs/glossary.md`. That release carries a `**Breaking:**` line, so jig's rule makes it a major release, v4.0.0."
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
SF-1, the last of part 3, completing the spec. Parts 1–2 are in `.jig/handoffs/rig-and-versioning-2026-11-18.md` (partial) and part 3 in `.jig/handoffs/rig-and-versioning-2026-11-18-2.md`.
- Only what it broke, for an open request too: a metarepo release rewrites an open pin-bump request (its release above the pin) only when something from the pin to the new tag breaks what the pararepo cites (a dangling citation, a removed or superseded id). Otherwise the file is left as it is, with `<para>: skipped, nothing from <pin> to <tag> breaks what it cites; .jig/staging/pin-bump-<meta>.md left as it is`. A Breaking line alone breaks nothing it cites; Breaking lines still go into the body of a request that is written.
- Text: the spec (Part B item 4, "Taken, and a request rewritten in place"), RULES (Staging, the pin-bump paragraph), the stage skill and `stage_pin_bumps`' docstring say the same. The DEFERRED SF-1 row is taken.

## Done-when evidence
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → exit 0; `claude plugin validate ./plugin` → Validation passed.
- `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh pin_bump versioning release metarepo pararepo staging rig_batch close` → 291 PASS, 0 FAIL at 3217adc.
- Smoke `pin_bump`, two new cases: a release that moves a cited page opens a request above the pin (v0.1.7, 1 rewrite); the move undone in v0.1.8 prints "A: skipped, nothing from v0.1.6 to v0.1.8 breaks what it cites; … left as it is" and the file's hash is unchanged.
- Repros at 3217adc: /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/4a98022a-7218-4a8e-9b83-555f4309e12a/scratchpad/rv9/out1.sh (v0.1.3 skips, the request stays at v0.1.2); /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/4a98022a-7218-4a8e-9b83-555f4309e12a/scratchpad/f1/f1.sh `revert` and `drop` (v0.1.2 and v0.1.3 skip, the file not rewritten). Earlier parts' repros are listed in the earlier notes.

## Review
- Earlier reviews of this job: parts 1–2 in `.jig/handoffs/rig-and-versioning-2026-11-18.md`, part 3 in `.jig/handoffs/rig-and-versioning-2026-11-18-2.md`.
- SF-1 (should-fix of the clean review of bd70018..66594e6) taken on the hubnode's word before the merge: fixed at 962b9c9.
- review-change of 6aeb91b..962b9c9: 1 blocking (B-1, a Breaking line alone still rewrote an open request), with the stage skill and docstring out of step and the smoke case's impossible release (optional) — all taken. Fixed at 3217adc.
- review-change of 962b9c9..3217adc: clean, blocking 0. No new DEFERRED rows.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's documentation is `plugin/templates/jig/RULES.md`, updated here (Staging: the pin-bump request).

## Shared files changed
- `plugin/templates/jig/jig.py`: `stage_pin_bumps`, its skip condition and docstring.
- `plugin/templates/jig/RULES.md`: the pin-bump paragraph under Staging.
- `tests/smoke.sh`: two `pin_bump` cases.
- `plugin/skills/stage/SKILL.md`: the pin-bump kind's rewrite sentence.

## Test by hand
- In a metarepo with a pararepo holding an open pin-bump request: release something that breaks nothing the pararepo cites (even with a `**Breaking:**` line about a page it doesn't cite): the release prints the skip line and the request is unchanged.
- The earlier notes' hand tests stand.

## Left
- Nothing on this job. The owner's open Interpreted calls stay as listed in `.jig/handoffs/rig-and-versioning-2026-11-18-2.md` (Left).
