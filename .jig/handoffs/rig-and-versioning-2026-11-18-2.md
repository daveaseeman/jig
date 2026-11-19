# Handoff: rig-and-versioning

Commit: a23d801cdb6026b0c81e4dd02ad7f0d1e2cba01a
Date: 2026-11-18
Spec: .jig/specs/rig-and-versioning.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
Part 3 of rig-and-versioning, completing the spec; parts 1–2 (merged-job cleanup, rig's batching and `/jig:fix`, bug-rav-staged-drops) are in the partial note `.jig/handoffs/rig-and-versioning-2026-11-18.md`.
- Versions measure the product: RULES.md gains `## Versioning`, the rebuilt report's block with the spec's two changes (the selector's "whose citations the release broke", the registry sentence before `### Before 1.0.0`). Flags `--milestone`, `--feature`, `--patch` (the default in every kind after the first release; `--major`/`--minor` aliases); `--milestone` refuses before 1.0.0, naming `--version 1.0.0`. `LOG_SEED`'s header names MILESTONE.FEATURE.PATCH; `log_is_seed` accepts the old seed; `jig update` swaps the old header word for word (in a metarepo, listed as a job's step; R3 allows exactly that swap). A pararepo's `jig sync` prints the Breaking lines between its pin and the latest release, without "(a major release)".
- A metarepo release stages a pin-bump request (`.jig/staging/pin-bump-<meta>.md`, `kind: pin-bump`) in each listed pararepo whose citations it broke (the owner: "Only what it broke"): a citation that resolved at the previous tag and dangles at the new one, or a removed or superseded id cited as `<meta>/<path> § <id>` (bare too where the prefixes differ). Its body runs from the pin: Breaking lines, rewrites with new homes, ids with their files. Skips print why (not in `jig repos`, older layout, not citing it, `defer_until`, already pinned, nothing broke); a file not ours is left. An open request is rewritten each release; an answered one only when a release breaks something. `resolve` refuses until trunk's pin holds the release; a carried one is `built` once it does, and `jig rig --close` resolves it. A staged pin-bump doesn't hold the pararepo's release, which names it.
- Text: RULES (Versioning, Decision log header and Writing it, Metarepo and pararepos with "A pin-bump request" and `defer_until`, Release flags, Staging's pin-bump kind, Commands), release, redocument, hubnode, rig and stage skills, AGENTS.md's release line. Old metarepo smoke cases that expected v0.2.0 pass `--feature`.

## Done-when evidence
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → exit 0; `claude plugin validate ./plugin` → Validation passed.
- `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh versioning pin_bump release metarepo pararepo decisions staging staging_batches update pararepo_commands sync_buffer buffer_answered pointers removals report_fixes entry_globs supersede glossary consolidate rig rig_batch close roadmap merge_derived next workflow` → 951 PASS, 0 FAIL at 66594e6; after the sync onto 98d2e57 (d8df537), `staging staging_batches pin_bump close rig_batch rig versioning` → 245 PASS, 0 FAIL.
- Smoke `versioning`: the header (MILESTONE.FEATURE.PATCH, no SemVer), `## Versioning` before `## Release`, v0.3.0 + Breaking → v0.3.1, `--feature` v0.4.0, `--milestone` refused before 1.0.0, then v2.0.0, the aliases, no rule text making Breaking a major, the old seed counted, the update swap (2+/2−, commit passes), a header in words of its own named, in a metarepo the job's R3 pass and its merge, and update listing it as a job's.
- Smoke `pin_bump`: the reported symptom (a move with a Breaking line tags the patch, A 1 rewrite, B 1 superseded id, C nothing broke, D deferred), staging check, Breaking line and new home, no commit or pin moved in any pararepo, rig `staged` with `[]` touches, resolve refused naming the job, `taken`, the second release rewriting the one file v0.1.0→v0.1.2 and voiding the judgment, A's release named not held, sync's Breaking lines, the pin job's merge leaving it `built` and `--close` resolving it, an answered request left and then overwritten (equal and below the pin), a same-named file left, D- on both sides.
- Repro scripts (pass at 66594e6): /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rw-rav-p3-48e80ed/ (repro1.sh, repro2.sh, repro3.sh), /private/tmp/claude-501/-Users-daveseeman-Documents-GitHub-jig/89e42143-af29-4fe8-b329-f482cf80befe/scratchpad/rc-rav-p3-bd70018/ (repro1–6.sh, repro4.sh below).

## Review
- review-work of c1ffa30..48e80ed: 3 blocking (B1 selector (b) never fired with default prefixes; B2 RULES' stale drop lines; B3 a metarepo's update staged the header on trunk) — strike 1 of part 3. S1 (a request the pin holds re-asked), S2 (a noted pin-bump's step), O1, O4 taken; O2, O3 DEFERRED. Fixed at 00af374.
- The owner, 2026-11-18, on the selector (S3): "Only what it broke" — recorded in the spec at bd70018.
- review-change of 48e80ed..bd70018: 1 blocking (B-1 an answered request called foreign) — strike 2 of part 3. S-1, S-2, O-a, O-c, O-e taken; O-b, O-d DEFERRED. Fixed at 66594e6.
- Sync onto 98d2e57 (bug-stage-second-reader): clean, d8df537.
- review-change of bd70018..66594e6 (recorded at d8df537): clean, blocking 0. SF-1 and O-1–O-3 are DEFERRED rows (a23d801); SF-1 may become a part 4 on the owner's word.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's documentation is `plugin/templates/jig/RULES.md`, updated here (Versioning; Decision log; Metarepo and pararepos: A pin-bump request; Release; Staging; Commands).

## Shared files changed
- `plugin/templates/jig/jig.py`: release flags and levels, the log header and its update step, `newer_release`, `meta_citations` at revisions, `stage_pin_bumps`, the pin-bump kind and its resolve, rig's `built` for a pin-bump.
- `plugin/templates/jig/RULES.md`: the rules those enforce.
- `tests/smoke.sh`: new sections `versioning` and `pin_bump` (in UNITS); metarepo releases that expect v0.2.0 pass `--feature`; release 1725-1726 and the decisions header case moved to the new flags and header.
- `plugin/skills/hubnode/SKILL.md` (release level, step 5, a noted pin-bump), `plugin/skills/stage/SKILL.md` (the pin-bump kind; synced with bug-stage-second-reader).
- `AGENTS.md`: the release line (`--feature` or `--patch`).

## Test by hand
- In a metarepo with a listed, registered pararepo that cites a page: move the page with a `**Breaking:**` line, merge, `jig release`: it tags the patch and prints the pararepo's "staged … (1 rewrite)" line; the pararepo's `.jig/staging/pin-bump-<meta>.md` names the new home.

## Left
- The owner's open Interpreted calls the spec names: the flag names and their aliases; `--patch` as the default in every kind; `--milestone` refusing before 1.0.0; the header swap through `jig update` with the narrow R3 allowance; a pin-bump that doesn't block the pararepo's release; the kind name `pin-bump`, one file per metarepo; and from the reviews, the prefix rule, a request the pin holds being answered, the old-layout skip, and a carried pin-bump `built` once the pin holds it.
- SF-1 (DEFERRED): a part 4 before the merge if the owner says so.
