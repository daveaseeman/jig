# Handoff: buffer-row-close

Commit: eb87ea51914c38c5d632e7d0da687cecd29381a4
Date: 2026-11-13
Spec: .jig/specs/bug-buffer-row-close.md
Review: tier 2, effort 2

## Built
- `jig sync --answered <ids> --in <release> --reason <text>` (pararepo trunk). It closes Open BUFFER rows that a metarepo release at or below the pin answered some other way. Each row's State becomes `Closed (answered in <release>: <reason>)`, committed alone as `meta: <name> <pin>: <ids> answered in <release>`.
- `jig propose --withdraw <branch> --reason <text>` rewrites the spec's line to `meta: <name> withdrawn <branch> — <reason>`. Sync and gate stop waiting on it, it answers no change, and its still-Open rows go in the next proposal. It never deletes the metarepo branch.
- P2 is tighter:
  - A bare `Closed` needs the pin to hold a proposal that carried the row as it stands, checked against the metarepo checkout.
  - An answered `Closed` needs a reason, and a real release at or below the staged pin.
  - Cells must be unchanged, and the commit must touch no contract path.
- Sync now reports:
  - a buffer proposal that carries no Open row, with the `--withdraw` line;
  - a withdrawn proposal that was released anyway, with the `--answered` line.
- Docs: RULES.md (the sync buffer, P2's row, Commands), the BUFFER template, and two clauses in step 5 of the hubnode skill.

## Done-when evidence
Every case below is in `bash tests/smoke.sh buffer_answered`. Full run at eb87ea5: `smoke rc=0`, 1243 PASS, 0 FAIL.
- Symptom gone: PASS "answered: sync --answered closes B1 and B2 in one commit, recording the release and the reason, and offers the withdraw".
- Refusals that commit nothing: PASS "answered: --in a release above the pin, a tag the metarepo doesn't have, no reason, or a row not Open, each refused, committing nothing". Also PASS "a row already Closed is refused, committing nothing".
- By hand: PASS "answered P2: by hand, an answer with no reason, one above the pin, one naming no release, and one beside a contract change are each refused naming P2".
- Tightened bare close: PASS "answered P2: a bare Closed whose proposal the pin doesn't hold is refused, naming the branch". Still PASS: "answered P2: sync's own close, the pin holding the proposal, still commits", and the existing sync_buffer closes.
- Withdraw: PASS for each of:
  - "sync names the proposal as carrying no Open row, with the withdraw";
  - "the spec's line reads withdrawn; committed, sync no longer names the branch, and the metarepo still has it";
  - "a withdrawn proposal's Open row goes again in the next release's proposal";
  - "a proposal the pin's release holds is refused".
- Gate: PASS "withdraw: gate waits on a cited proposal, and not once it is withdrawn". Also PASS "a job that hasn't synced since its proposal was withdrawn on trunk isn't told to wait for it".
- Release: PASS "answered: a release after it opens no proposal for B1 or B2".
- RULES.md: PASS "answered: RULES.md names the answered state, the withdrawn line and both commands".
- `claude plugin validate ./plugin` printed `✔ Validation passed`, and `.jig/scripts/check.sh` exited 0.

## Review
The hubnode reviewed at tier 2, effort 2. Five findings, none blocking, all fixed in c32f7cf:
1. **A tag that isn't a version passed P2.** `version_key("elsewhere")` sorts below any pin. Now the tag must be in the metarepo's released tags when its checkout is reachable, else match the release tag pattern. Smoke: "naming no release, the refusal says so".
2. **The gate read the job's copy of the spec before trunk's**, so an unsynced job still waited on a withdrawn proposal. Now a `withdrawn` line on trunk wins in `unreleased_proposals`. Smoke runs a real job's gate before and after the withdraw.
3. **`--withdraw` accepted a proposal released above the pin**, which would strand its rows. Now refused, saying to bump the pin. Smoke: "a proposal a release above the pin holds is refused, saying to bump the pin".
4. (Optional) **Withdrawn, then released anyway:** sync names it with the `--answered` for its Open rows. Smoke: "a withdrawn proposal released anyway is reported".
5. (Optional) **Thicker tests:** an already-Closed id, and each by-hand refusal checked to name `P2 … row B1`.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (The sync buffer, P2's row, Commands), updated here, plus the BUFFER template and the hubnode skill.

## Shared files changed
- `plugin/templates/jig/jig.py`: the P2 close branch, `sync_meta`, `cmd_sync`, `cmd_propose`, `unreleased_proposals`, `proposed_copy`, and new helpers (`row_state`, `sync_answered`, `withdraw_proposal`, `withdraw_line`).
- `plugin/templates/jig/RULES.md`: The sync buffer paragraph (appended), P2's row, two Commands lines.
- `plugin/templates/ledgers/BUFFER.md`: one sentence.
- `plugin/skills/hubnode/SKILL.md`: step 5, two clauses.
- `tests/smoke.sh`: a new section, `sec_buffer_answered`, placed after `sec_sync_buffer` and listed in `UNITS`. Touches said to extend `sec_sync_buffer`. A section of its own keeps the parallel jobs' smoke.sh edits apart, and the only shared line is `UNITS`.

## Test by hand
In a pararepo whose metarepo answered an Open row's claim by another change:
1. Bump the pin to that release.
2. Run `jig sync --answered B1 --in <release> --reason "<why>"`. Check that the row reads `Closed (answered in …)` and that one commit was made.
3. Run `jig sync`. The proposal should be named as carrying no Open row.
4. Run `jig propose --withdraw <branch> --reason …` and commit the spec. A later `jig sync` should no longer list the branch.

## Left
Nothing on this job. Maige-Lite closes its B1 and B2 with `--answered` after `/jig:update`, on the owner's word. `marketing/FEATURES.md` rows are the hubnode's.
