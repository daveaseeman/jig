# Handoff: derive-candidates

Commit: 5f6cfd1d6078c2d9c53123408fb52580906800ef
Date: 2026-11-13
Spec: .jig/specs/bug-derive-candidates.md
Review: tier 2, effort 2

## Built
- RULES.md (Keeping merges mechanical) states which generated files `derive.sh` writes: those
  built from several sources that separate jobs change, which every merge can rebuild. It lists
  what doesn't qualify: a one-source output regenerated in its job, a file the merge can't
  rebuild, a lockfile, and jig's own `ROADMAP.md`.
- The update skill (After `--apply`, step 2) no longer asks the owner about habits. It finds
  generated files from evidence (a "generated" or "do not edit" header, `linguist-generated`, a
  script's output path, a file `check.sh` compares). It judges each by the RULES.md test, shows
  a verdict and a reason for each, and proposes `derive.sh` only for files that pass. When none
  pass it says so in one line and asks nothing. The init skill's step 3 does the same.
- The derive.sh header, the template AGENTS.md derive line, `jig update`'s plan line and the
  hubnode's "After a merge" use the same wording in place of "whole tree".

## Done-when evidence
- Text: `grep -n "several sources" plugin/templates/jig/RULES.md
  plugin/templates/jig/scripts/derive.sh` hits RULES.md:102 and derive.sh:2. RULES.md's
  paragraph names one source, can't rebuild at merge, and `ROADMAP.md` (and lockfiles).
  `grep -n "regenerates tracked files after" plugin/skills/update/SKILL.md` prints nothing.
  The update and init steps name the four signals, the RULES.md test and "ask nothing".
- The fix fires, by hand: **pending for the gate.** A fresh `/jig:update` session on the fixture
  at `/private/tmp/claude-501/derive-q/r`, with check.sh comparing `assets/out` and derive.sh
  removed, should propose `ICONS.md` and name `assets/out/*.h` as one source each.
- The symptom is gone, by hand: **pending for the gate.** The same run with `icons/` and
  `ICONS.md` removed should end step 2 with one "no file passes" line and no derive question.
- `bash tests/smoke.sh` on 5f6cfd1: `smoke exit 0`, 1226 PASS, 0 FAIL. Last line: `PASS
  isolation: the user's real jig config folder is unchanged by the run`.
  `claude plugin validate ./plugin`: `✔ Validation passed`. `.jig/scripts/check.sh`: exit 0.
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: no output, exit 1.

## Review
Hubnode review, tier 2, effort 2, on 54fca58..3e85a6e. Three findings, all fixed in 7f25a08:
1. Blocking. Init step 3 pointed at the update skill's text, which isn't loaded in an init
   session, so Done-when 1 wasn't met. Fixed: init lists the four signals itself and judges by
   the RULES.md test.
2. Should-fix. Three sibling texts still said "whole tree", the ambiguity Why 2 names: the
   template AGENTS.md derive line, `jig update`'s plan line in jig.py, and the hubnode's
   "After a merge". Fixed: all three use RULES.md's wording, and the hubnode line points at it.
   The AGENTS.md line first named `.jig/RULES.md`, which made jig count it as the Rulebook line.
   Smoke's `agents lines` failed on 7f25a08, and 5f6cfd1 drops the mention. 7f25a08 alone
   fails smoke; the range passes.
3. Should-fix. Lockfiles (`Cargo.lock`, `poetry.lock`) carry "@generated" headers and passed
   the test, so the search would have proposed moving them into derive.sh. Fixed: RULES.md and
   the update skill name a lockfile as a non-candidate, because a branch's own build needs it,
   so its job commits it.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Keeping merges mechanical). The jig.py change is one plan line's wording, and this repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/RULES.md`: the test lives here, its rule's home.
- `plugin/templates/jig/scripts/derive.sh`: header line 1 matches RULES.md and points at it.
- `plugin/skills/update/SKILL.md`: step 2's question is replaced by the search and the test.
- `plugin/skills/init/SKILL.md`: step 3, the same search and test.
- Added after review (finding 2, shares added on trunk in a00abd3):
  - `plugin/templates/AGENTS.md`: the derive line's "whole tree" wording.
  - `plugin/templates/jig/jig.py`: `jig update`'s derive.sh plan line, wording only.
  - `plugin/skills/hubnode/SKILL.md`: "After a merge", wording and a pointer to RULES.md.

## Test by hand
The two fixture runs from Done-when, at the gate:
- In `/private/tmp/claude-501/derive-q/r`, make check.sh run `sh tools/gen_asset.sh && git diff
  --exit-code assets/out`, then remove `.jig/scripts/derive.sh` and commit. Start a fresh
  session with `--plugin-dir ./plugin` and run `/jig:update`, with `JIG_CONFIG` and
  `XDG_CONFIG_HOME` pointing outside the repo, and apply. Watch step 2: `ICONS.md` is proposed
  for derive.sh, and `assets/out/*.h` is named "one source each".
- Repeat with `icons/`, `ICONS.md` and `tools/gen_index.py` removed. Step 2 says in one line
  that no file passes, and asks no derive question.

## Left
- The two by-hand fixture runs above, for the gate.
- Nothing else on this job. Repos that already have derive.sh are not asked again (spec, Out
  of scope).
