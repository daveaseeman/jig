# Handoff: bug-stage-second-reader

Commit: 4715ed57b8a84c8261da1ea5668b7a2cffd06740
Date: 2026-11-18
Spec: .jig/specs/bug-stage-second-reader.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at medium (the kickoff's line)

## Built
`/jig:stage` gets a **Second reader** step in A batch, before the header check. A fresh worker at tier 2, effort 2 (by `tiers.json`, no model named) reads every file of the batch against a record of the conversation: the owner's messages verbatim and in order, with the author's proposals marked as theirs. It answers five questions for each file: what was left out, what is overstated, what was added unmarked, what a cold reader couldn't act on, and what contradicts. The stager fixes what it finds and shows the owner before saying "staged". A host that can't start a worker stages the batch with `; unreviewed` at the end of `source:`, and Resolving names such a file when it asks whether the file is as settled as it says. Commits: 4555e2e (skill and smoke), 4715ed5 (DEFERRED rows).

## Done-when evidence
- Second reader item in A batch: `plugin/skills/stage/SKILL.md` § A batch, between Order and "Check before you say it's staged". It has the five questions, the verbatim record, report-only, no code facts, fix-then-show, marks in place or as `Interpreted:`, and `; unreviewed`.
- Resolving names unreviewed: § Resolving, "A file whose `source:` ends `unreviewed` had no second reader: say so when you ask the second."
- No model name: the smoke case asserts `! grep -qiE 'opus|sonnet|haiku'` on the skill.
- Smoke: `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh staging_batches` gives 30 PASS and 0 FAIL, including `PASS  stage skill: a batch gets a second reader at tier 2, effort 2, from a verbatim record, and a host with no worker stages it unreviewed, which Resolving names`. The assertion fails against trunk's skill. Check: `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` exits 0.
- Fires (dry run, full report in `bug-stage-second-reader-evidence.md` in the hubnode's shared notes folder): a throwaway repo `widget`, with JIG_CONFIG and XDG_CONFIG_HOME set, and a two-file batch (decisions plus spec) with three planted faults. A fresh worker at Opus, high reported all three before the word "staged":
  - JSON kept, though the owner said "drop json";
  - an unanswered date-format question stated as decided;
  - a quote that wasn't verbatim.

  After the fixes, `jig staging check` passed both files. A `source:` ending `; unreviewed` also passes `staging check` with no code change.
- Symptom gone (Daisy replay, on scratchpad copies; Daisy untouched): Daisy's final `settings-home.md` and D-072–D-074, with the report's six faults put back. `staging check` passed the faulty draft, which is the symptom. The worker named:
  - the table "accepted … as a whole" (overstated agreement);
  - the Intent vs Done when contradiction;
  - the engine-page "ruling", the pipeline "rejected" and the unmarked † additions;
  - the cloud reversal resting on the false inline-caps claim.

  Caveat, the worker's own: the original report was resolved and is gone, so the draft and the record were rebuilt from the final files, which makes the replay partly circular. Full report in `bug-stage-second-reader-evidence.md` in the hubnode's shared notes folder.
- FEATURES row: the hubnode's (gitignored); already written.

## Review
review-work of main...4555e2e, recorded by the hubnode at 4555e2e, with 0 blocking findings. Untaken findings, each a row in `.jig/ledgers/DEFERRED.md` (4715ed5):
- SF1 (should-fix): `; unreviewed` covers only a host with no worker. A failed worker or an ended session leaves files unmarked. Deferred; may be a second part.
- SF2 (should-fix): nothing covers a stager that can't produce a verbatim record (a rigger's `record/` is not this record). Deferred; may be a second part.
- SF3 (should-fix): `/jig:rig auto` can act on an unreviewed file without naming it. Deferred: it touches `rig/SKILL.md`, which rig-and-versioning owns.
- O1–O4 (optional): O1 is the FEATURES "not" column, the hubnode's. O2 is "every batch, including one file". O3 is sorting findings before fixing. O4 is `; unreviewed` carrying into `Source:`. Deferred.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. A pair line
     (`<id> vs <log> § <ids> (<page>): ___`) is answered after its colon, once for every id
     on it: agrees, narrows: <how>, or conflicts: <resolution>; on a line of several ids,
     narrows and conflicts name at least one of them. jig reads the rest of the line, so it
     stays as jig wrote it. -->
- [x] no code changed — nothing to fold in (skill text and a smoke case; no docs page describes the stage skill's steps)

## Shared files changed
- `plugin/skills/stage/SKILL.md`: the step lives there. Only § A batch (one new item) and § Resolving (one sentence) changed. rig-and-versioning's pin-bump edit is elsewhere in the file.
- `tests/smoke.sh`: one case appended in `sec_staging_batches`, after the existing stage-skill case.
- `.jig/ledgers/DEFERRED.md`: four rows appended.

## Test by hand
Stage a two-file batch from a chat with `/jig:stage`. Watch for the worker's findings, then the fixes shown, and only then the word "staged". On a host that can't start a worker, the reply should say unreviewed and each `source:` should end `; unreviewed`.

## Left
Nothing in the spec. SF1 and SF2 if the owner asks for them before the merge (a second part); SF3 belongs with rig's skill.
