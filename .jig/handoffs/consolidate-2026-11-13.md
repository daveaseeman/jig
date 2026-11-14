# Handoff: consolidate

Commit: 37ec48ab1c9106121b48fe6e708af713bc4eb4e9
Date: 2026-11-13
Spec: .jig/specs/consolidate.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
- `jig.py`: `jig consolidate` lists groups of waiting specs (no open job, no note's `Spec:`, not in the newest release tag) whose `## Touches` meet (one path, a glob or `dir/` covering a path, the same `page § term`), with the shared paths; an answer is a merged spec replacing its inputs, or a `Kept separate from <spec>: <reason>` line per pair. `jig open` and `jig staging resolve` (story/request/report whose spec carries the mark) refuse a spec in an unanswered group. `jig open` warns on Touches paths outside owns/shares/common, and its kickoff reads a spec's `## Proposals` (`jig sync`, then merge each in order). `jig share <job> <path>…` adds shares, refusing another open job's owns.
- `plugin/skills/consolidate/SKILL.md` (new); `/jig:fix`, hubnode and stage skills run `jig consolidate` before resolving / opening several jobs.
- `RULES.md`: The board (waiting specs, both answers, `## Proposals`, the Touches warning, `jig share`), Staging, Commands.
- Smoke section `consolidate` (15 cases).

## Done-when evidence
- Waiting specs and groups: `bash tests/smoke.sh consolidate` → `PASS consolidate: with no specs waiting it says so and exits 0`, `PASS consolidate: three specs, two sharing a page, list as one group of two, with the shared paths`, `PASS consolidate: a spec the newest release holds, or a job or note names, isn't waiting`, `PASS consolidate: a job opened as ./.jig/specs/x.md names that spec; a folder ending in / covers what is under it; an indented Kept separate line answers`.
- Both answers: `PASS consolidate: a Kept separate line on either spec of the pair answers it`, `PASS consolidate: one spec carrying both Source lines, the inputs deleted, answers the group`.
- Refusals: `PASS open: a spec in an unanswered group is refused, naming the group and jig consolidate, and nothing is opened`, `PASS staging resolve: a report whose spec is in an unanswered group is refused, naming the group`, `PASS staging resolve: with the pair answered it resolves`.
- `/jig:fix` and hubnode run it: `plugin/skills/fix/SKILL.md` step 4, `plugin/skills/hubnode/SKILL.md` Opening a job step 1 (stage skill too).
- `/jig:consolidate` skill: `plugin/skills/consolidate/SKILL.md` (Intent, Source lines, labelled Done-when groups, Decisions/Out of scope kept, Touches union, `jig workflow`, inputs deleted in the same commit, `## Proposals`).
- Metarepo: `PASS metarepo: open on a spec listing proposals: the kickoff says to merge each into the job's branch, in the spec's order`, `PASS metarepo: after the release, the pararepo's sync reports both proposals released`.
- Touches warning and `jig share`: `PASS open: a Touches path in neither owns, shares nor common is warned about, by name; a § term counts as its page`, `PASS share: a path another open job owns is refused, the board unchanged`, `PASS share: adds the path to the job's shares, and jig check in the job then passes`.
- RULES.md: The board, "Overlapping specs are answered before they open".
- `bash tests/smoke.sh consolidate` → 15 PASS, 0 FAIL at 37ec48a; `sync_buffer` (the other section writing Touches) → 42 PASS, 0 FAIL. `.jig/scripts/check.sh` → ok; `claude plugin validate ./plugin` → `✔ Validation passed`; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing. The full suite was not run here: it runs at the gate.

## Review
Fresh-context subagent (Opus; it read its effort as unknown), round 1, on 87724b9. Nothing blocking.
- S1 (should-fix) deleting one spec of a pair answers with no Source-line check: deferred (DEFERRED.md), the spec leaves the merge to the skill and the owner's read.
- S2 (should-fix) a spec held past a release stops being waiting (e.g. `every-copy` at the release that ships this): deferred, it is the spec's own definition; owner's call.
- S3 (should-fix) spec paths compared as raw strings (`./.jig/specs/a.md`): taken, `spec_key` normalises board, notes, `open` and `group_of`; smoke case.
- O1 `dir/` Touches and `/jig:…` names: taken (folder = `dir/**`, a leading `/` isn't a path). Basename-only spans left as is.
- O2 duplicated shared paths: taken. O3 indented `Kept separate` bullet: taken, smoke case.
- O4 `open --shares` lacks `share`'s refusal, O5 no-spec open skips the refusal: deferred.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (The board, Staging, Commands).

## Shared files changed
- `plugin/templates/jig/jig.py`: new block after `cmd_reserve` (consolidate/share helpers), lines in `cmd_open`, an `unanswered` check inside `cmd_staging` resolve, two parser lines and the dispatch.
- `plugin/templates/jig/RULES.md`: a paragraph appended to The board's "Owns is narrow", two lines in Staging, two Commands lines.
- `plugin/skills/hubnode/SKILL.md`, `plugin/skills/stage/SKILL.md`: a few lines each, appended inside existing steps.
- `tests/smoke.sh`: a new `sec_consolidate` before `UNITS`, and `consolidate` appended to `UNITS`.
- `.jig/specs/consolidate.md` (common): `Interpreted:` decisions (`## Proposals`, sync before merging proposals, which resolves refuse). `.jig/ledgers/DEFERRED.md` (common): four rows.

## Test by hand
- In the trunk checkout, `python3 .jig/jig.py consolidate` (after `/jig:update`): today it prints "no waiting specs overlap" (every-copy is the only waiting spec).
- Write two specs touching one file and `jig open` one: refused, naming both and `jig consolidate`.

## Left
- Nothing on the spec. The owner's call on S2 (held specs leaving "waiting" at a release). Kickoff wording for proposals now says `jig sync` first: a merge in a job is judged against trunk, and a fresh job lacks its own open commit (R5).
