# Handoff: sync-buffer

Commit: ede19d5c8b712f309bf94b337f517d30d62fd48f
Date: 2026-11-02
Spec: .jig/specs/sync-buffer.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
- The sync buffer, `.jig/ledgers/BUFFER.md` (template `plugin/templates/ledgers/BUFFER.md`), is
  one row per metarepo claim the pararepo has moved away from, and each row is `Open` or `Closed`.
- P2 gains a buffered answer. A contract-path change passes with an `Open` row added or edited
  in the same commit, or with a spec saying `meta: buffered <id>` that names an `Open` row.
  `meta: none — <reason>` and a proposal still answer it. In the ledger, P2 refuses:
  - a state other than `Open` or `Closed`;
  - a repeated id;
  - an `Open` row deleted, or the whole ledger deleted;
  - an `Open` row closed, unless a committed buffer spec carries it unchanged and the commit
    changes no contract path.
- `jig propose --buffer [slug]` gives every `Open` row that no proposal carries unchanged one
  metarepo branch, plus a spec here that lists the rows (`## Buffer rows`) and copies them.
  `jig release` in a pararepo does this before its build and commits the spec with the release.
  With nothing left to propose it opens no branch and doesn't need the metarepo.
- On trunk, `jig sync` finds the first release, starting at the current pin, that holds a buffer
  proposal. It closes the rows the proposal carried that are unchanged since. It does this in one
  commit: `meta: <name> <old> → <new>` when the pin moves, or `meta: <name> <pin>: close <ids>`
  when it doesn't. An edited row stays `Open` and goes again in the next proposal.
- `jig sync` names each tracked file a decision at the pin cites (alone or after this repo's
  name) that `contract_paths` doesn't cover.
- RULES.md gains the P2 row, the sync buffer paragraph, Newer wins, Every copy and the
  `propose --buffer` command. The spec and review skills ask Every copy in a metarepo. The release
  skill gains the pararepo step. The hubnode skill's metarepo session start lists the pararepos'
  open rows and their unreleased buffer proposals.

## Done-when evidence
`bash tests/smoke.sh`: 468 PASS, no FAIL, exit 0 (section "sync buffer"). `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: exit 0.
- No buffer row and no spec answer → refused: PASS "a contract-path change with no buffer row and no spec answer is refused"
- A row in the same commit → accepted; `meta: buffered B1` → accepted: PASS on both cases
- A second change edits the row → accepted, no metarepo branch: PASS "a change of mind that edits the row is accepted, and no metarepo branch exists"
- Push with open rows: PASS "pushing with open rows succeeds"
- Release with two Open rows → one branch whose spec lists both; with none → no branch: PASS "jig release with two Open rows opens one metarepo proposal whose spec, in the release, lists both", "a pararepo release with no buffer opens no proposal branch", "a release with every row Closed opens no branch"
- After the metarepo releases it, sync moves the pin and closes both rows in one commit, and a later row stays Open: PASS "after the metarepo releases it, jig sync moves the pin and closes B1 and B2 in one commit; B3 stays Open"
- Sync reports a cited path `contract_paths` doesn't cover: PASS "jig sync reports a pararepo path a metarepo decision cites that contract_paths doesn't cover, and not one it covers or another repo's"
- `none — <reason>` and a proposal still answer P2: PASS "meta: none — <reason> and a proposal still answer it"
- RULES.md states the buffered answer, Newer wins and Every copy (*Metarepo and pararepos*). Spec skill step 3 and review question 7 ask Every copy.
- Round 1 cases: PASS for each of these:
  - a repeated id;
  - closing by hand;
  - deleting a row, or the ledger;
  - `buffered` naming a Closed row;
  - a release needing no metarepo when rows are already proposed;
  - an edited row staying Open, then being re-proposed;
  - closing when the pin was bumped by hand.

## Review
Fresh-context review (hubnode, Opus xhigh), round 1. Ten findings, all taken in ede19d5:
1. Blocking: sync closed a row by id after it had been edited since its proposal. It now closes
   only a row equal to the copy in the proposal's spec, and an edited row stays Open. Smoke case.
2. Every release re-proposed the open rows and needed the metarepo. Rows a proposal already
   carries unchanged are skipped; with none left there is no branch and no metarepo lookup.
3. A row could be closed by hand or deleted, or the ledger deleted, in a contract commit. Now
   refused: deleting is always refused, and closing passes only for a proposed, unchanged row in
   a commit with no contract change.
   - This differs from "except in the pin-moving commit", because finding 6 closes rows without
     moving the pin, and a hook can't reach the metarepo to tell those commits apart.
   - Closing no longer counts as P2's buffer answer.
4. `meta: buffered B1` was accepted for a Closed row. Only Open ids count now.
5. Repeated ids passed. P2 refuses them.
6. Rows never closed once the pin was already past the release. Sync now checks the current pin
   first and closes them there.
7. The cited-path prefix took any repo's name. It now takes only this repo's names
   (`this_repo_names`).
8. RULES.md now says sync makes the pin commit itself.
9. "Opens no branch" is now also tested with every row Closed.
10. The hubnode's metarepo step now names the unreleased buffer proposals and the rows each one
    carries.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's rulebook is `plugin/templates/jig/RULES.md`, which this job updated (P2, the sync buffer, Newer wins, Every copy, `propose --buffer`). This repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/jig.py`: what changed, by area.
  - `PROPOSAL`, plus the buffer helpers placed beside it.
  - `para_rules` (P2).
  - `cmd_propose` (`--buffer`), and `cmd_release`'s pararepo step.
  - `sync_meta`, which is `cmd_sync`'s pararepo path, and its two new helpers.
  - Outside the regions the brief listed: three lines of the `propose` parser in `main()`
    (`--buffer`, optional positionals).
- `plugin/templates/jig/RULES.md`: the P2 row, the sync buffer paragraph, Newer wins, Every copy, the `propose --buffer` command line.
- `tests/smoke.sh`: a new section at the end, nothing above it edited.
- `plugin/skills/hubnode/SKILL.md`: step 5 only, after its first line (the metarepo's open rows and buffer proposals).

## Test by hand
1. In a scratch pararepo with `contract_paths: ["api/**"]`, change `api/a.py` and add a row
   `| B1 | … | … | … | Open |` to `.jig/ledgers/BUFFER.md` in the same commit: it passes.
2. Run `jig release`: the metarepo gains `propose/<repo>-buffer-v…`.
3. Merge that branch in the metarepo and run `jig release` there.
4. In the pararepo's trunk, `jig sync`: `git log -1` shows `meta: <name> v… → v…`, and B1 reads
   `Closed`.

## Left
Nothing on this job. A follow-up for the hubnode to weigh:
- The `AGENTS.md` header `jig init --para` generates still names only a proposal or
  `meta: none` for P2. Changing it would make P1 refuse every existing pararepo's header until
  `jig init --para` is re-run.

A gap I accepted:
- A proposal branch the metarepo rejects and deletes still counts as carrying its rows, so they
  aren't re-proposed until edited.
