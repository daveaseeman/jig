# Handoff: bug-sync-trunk-edits

Commit: 0faca447025fe4b6dba8563e5659075b6cdc9968
Date: 2026-11-16
Spec: .jig/specs/bug-sync-trunk-edits.md
Source: adventure-studio hubnode session / 2026-11-16 / Dave (staged as feedback-adventure-studio-2026-11-16-sync-judged-for-trunk-edits.md): "A sync is refused for an edit that came from trunk, and moving entries marks untouched ones as changed"
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
- Part 1: R3's decision-log check reads `since = since_trunk(trunk)`, so a sync isn't blamed for trunk's in-place edit of an accepted entry. A job's own rewrite is still refused, in a sync's merge or a plain commit.
- Part 2: new `net_added(diff, want)`, shared by `added_lines` (boundary rule) and R7. A line counts as added only while its file's diff adds the text more times than it removes it, so a line moved within a file isn't new. The diff is read raw and split on "\n" only, and the tab git ends a spaced name's `+++` header with is stripped.
- R7 (review finding): a `WORKAROUND:` comment only moved within its file commits without a ledger row. A new one, or a second copy, is still refused.
- RULES.md boundary paragraph: "a moved page's old lines, or a line moved within a file, aren't new" (owner-approved clause).

## Done-when evidence
- Part 1, the reporter's done-when (conflict path): smoke `decisions` "R3: a sync bringing in trunk's rewrite of an accepted line, with an append conflict, commits the merge" (exit 0, "append conflicts resolved automatically", no `R3 .jig/decisions.md`, no MERGE_HEAD, HEAD^2 set). PASS. It FAILs on main's jig.py.
- Part 1, then `jig merge`: "after that sync, jig merge merges with no new handoff, keeping trunk's line and numbering the job's entry". PASS.
- Part 1, no DEFERRED rows (pre-merge-commit): "the same sync with nothing to resolve … commits too" ("nothing to resolve"). PASS. It FAILs on main.
- Part 1 controls: "a sync merge whose resolution rewrites an accepted line trunk has is still refused" and "a plain job commit rewriting an accepted line is still refused". Both PASS.
- Part 2, the reporter's done-when: smoke `boundary` "accepting A and C moves them past B …; it commits, jig rules says ok, and B is unchanged". PASS. It FAILs on main.
- Part 2: "an entry whose own body names the quoted scope, moved and accepted, commits" and "a page's old line naming the quoted scope, moved within the page, commits". Both PASS, and both FAIL on main.
- Part 2 controls: "a new log line naming the quoted scope is still refused" and "a second copy of an old line … in a new entry, is still refused". Both PASS.
- Existing rename cases in `boundary`: PASS.
- `.jig/scripts/check.sh`: rc=0, at 0faca44.
- `bash tests/smoke.sh decisions boundary rules metarepo supersede touches roadmap merge_after_sync cheaper_rounds removals glossary merge_log` at e098e88: rc=0, 499 PASS, 0 FAIL. Then `bash tests/smoke.sh rules boundary decisions` at 0faca44: rc=0, 137 PASS, 0 FAIL.
- `claude plugin validate ./plugin`: "✔ Validation passed".
- `grep -rni adventure plugin`: nothing.

## Review
1. review-work on e098e88 (tier 2, effort 2): blocking 0.
   - should-fix: R7 had the same positional bug (a moved WORKAROUND comment read as added). Fixed in b7aa42e with the shared `net_added` helper, plus smoke cases.
   - optional: `added_lines` read the diff in text mode with `.splitlines()`, so a form feed could fake a `diff ` line. Fixed in b7aa42e: read raw, split on "\n".
   - optional, deferred to DEFERRED.md: M2 before the log; P2's "rowed" check and the contract-removals reader; the first-occurrence line number in a refusal; the spec's partly wrong `--color-moved` reason.
2. review-change on b7aa42e: blocking 1, fix round 1.
   - BLOCKING: `net_added` missed a path with a space, because git ends the `+++` header with a tab. Fixed in 976658a, with a smoke case: a WORKAROUND in `src/my file.py` is refused. That case FAILs on b7aa42e.
   - optional: smoke undid by commit count. Fixed in 976658a: reset to a saved `keep` commit, including the old line 237.
   - optional: the second-copy control should exercise the net count. Fixed in 976658a: move plus a copy in one commit.
   - deferred to DEFERRED.md: code file names git quotes (non-ASCII), which predates this job.
3. review-change on 976658a: blocking 0.
   - should-fix: neither R7 move case moved the marker line. Fixed in 0faca44: the marker's function is the smaller block, and the reorder FAILs under e098e88's R7.
   - optional: check the refusal text "R7 the diff adds". Fixed in 0faca44.
   - optional: name `added_lines` in the quoted-names DEFERRED row too. Fixed in 0faca44.
4. review-change on 0faca44: blocking 0, no new findings.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`. The boundary paragraph is updated here ("or a line moved within a file"). R3's "judged against trunk" sentence already described the fixed behaviour, and R7's text doesn't mention position. This repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/jig.py`: R3's log branch in `check_rules`, R7's diff read, `added_lines`, and the new `net_added` beside it. The fix lives there.
- `plugin/templates/jig/RULES.md`: one clause of the boundary paragraph (owner-approved).
- `tests/smoke.sh`: new cases at the end of `sec_boundary` (its own `boundary-move` repo), at the end of `sec_decisions` (its own `dl-sync` and `dl-sync-clean` repos), and R7 cases in `sec_rules`. Two lines in sec_rules changed: the old ledger case's `HEAD~1` reset became a reset to a saved commit.
- `.jig/ledgers/DEFERRED.md`: 5 appended rows, for the reviews' untaken findings.

## Test by hand
- In a repo with an open job that added `### D-?…` under `## Open`: on trunk, reword one line of an accepted entry and commit, then run `jig sync` in the job's worktree. It commits, with no R3.
- Move an old entry or paragraph holding a quoted scope id within its file. The commit isn't refused. Add a new line naming the scope, and it is.

## Left
- Nothing on this spec. The rows above in DEFERRED.md cover the other positional readers, and the hubnode owns the FEATURES.md clause, already done on trunk.
