# Bug: a buffer row the metarepo answered by other means, or a moot proposal, never settles

Source: Maige-Lite hubnode session / 2026-11-13 / Dave with Claude (staged as feedback-Maige-Lite-2026-11-13-buffer-row-no-close.md): "a buffer row answered by other means, or carried by a moot proposal, has no way to close."

## Intent
A pararepo can close an Open `BUFFER.md` row as answered by a metarepo release it pins, on the
owner's word, with the release and the reason recorded in the row. It can withdraw a proposal
the metarepo will never release, so `jig sync` stops waiting on it. P2 gets stricter, not
looser: a row closes only through jig, and a plain `Closed` needs the release that holds its
proposal.

## 1. Why
1. Why is "close both as answered" refused? P2 refuses an Open row that turns Closed with its cells edited, or that no unchanged proposal copy carries. [seen]
2. Why can't `jig sync` close it? Sync closes a row only when a release holds the proposal branch that carried it. Here a different metarepo change answered the claim. [seen]
3. Why is there no other way? The ledger has one way to leave Open, and a proposal one way to end: released. Nothing records "answered elsewhere" or "withdrawn". *(Root.)* [seen]

## 2. Givens
The reporter's `jig_version` is a8a32d1dbb7e, v0.12.1's `jig.py`. Since then `para_rules`, `sync_meta`, `unproposed` and `proposal_in` are unchanged. Reproduced Nov 13 with `plugin/templates/jig/jig.py` at de3cc14, in `/private/tmp/claude-501/bufclose/`: metarepo `mm` (D-001), pararepo `pr` (`contract_paths: ["api/**"]`), rows B1 and B2 Open. `jig release` 0.1.0 proposed them as `propose/pr-buffer-v0.1.0`. `mm` then changed D-001 on another branch and released v0.2.0, and the pin was bumped to v0.2.0.
- `[seen]` Refused, naming `P2 … row B1 closed by hand`:
  - closing with the answer written into the row (`names shown; answered by mm v0.2.0`);
  - closing in a commit that also changes `api/a.py`;
  - closing a row edited after its proposal;
  - closing a row no proposal carried.
- `[seen]` **Accepted: a bare `Open` → `Closed` flip** of both rows, cells unchanged, in a commit touching no contract path. The proposal was never released. P2 approximates "sync's commit" as "a proposed, unchanged row, no contract path" and can't tell a hand commit from sync's. RULES.md's P2 row says "closed by any commit but `jig sync`'s" is refused. So an agent told "close them" can close with no record, and one that records why is refused.
- `[seen]` `jig sync` prints `proposal propose/pr-buffer-v0.1.0 (.jig/specs/buffer-v0.1.0.md): not released` on every run:
  - before and after the pin bump;
  - after the rows were closed by the bare flip;
  - after `mm` deleted the branch.
  It stops only when the spec is deleted, which loses the record of what went.
- `[seen]` A row noted as answered while still Open is a changed row. The next `jig release` (0.1.1) proposed it again, as `propose/pr-buffer-v0.1.1`, a second moot branch on `mm`. A row left unchanged is not proposed again: `unproposed` skips rows a spec carries as they stand. The report's "`jig release` would propose them again" holds only for an edited row.
- `[read]` `unreleased_proposals` refuses at gate only a job whose own spec cites the proposal. The buffer spec itself is no job's. `proposed_copy` reads `## Buffer rows` whatever the spec's `meta:` line says.
- `[assumed]` Maige-Lite's refused commit edited the row or touched a contract path. Its message is the one seen above. Not checked against that repo: this task touches no Maige checkout.

## 3. One layer up
- **Metarepo pointers** already have this: update's "pending on <branch>" and "the metarepo's rewrite missed it" tell apart what a release did. Buffer rows have only "released as it stands".
- **`meta: none — <reason>`** is the existing pattern for "the owner says no metarepo change is owed". It is free text, on the owner's word, kept in the repo. An answered close is the same kind of answer, with a release that can be checked.
- **Regular proposals** (`jig propose <spec> <slug>`) go moot too. A job citing one waits at gate until it's released. Withdrawal must cover both kinds.

## 4. Correction
Two commands, and P2 rewritten to check what they write.
- **`jig sync --answered <id>[,<id>…] --in <release> --reason "<text>"`**, on a pararepo's trunk.
  - Refuses unless:
    - every id is an Open row;
    - `<release>` is one of the metarepo's released tags, at or below the pin;
    - the reason is non-empty;
    - the tree is clean.
  - Sets each row's State cell to `Closed (answered in <release>: <reason>)`. The other cells stay as they are.
  - Commits alone as `meta: <name> <pin>: <ids> answered in <release>`, the reason as the body. Same shape as sync's own close commit.
  - When that leaves a proposal with no Open row, it prints the `--withdraw` line for that proposal.
- **`jig propose --withdraw <branch> --reason "<text>"`**, in a pararepo.
  - Rewrites the spec's `- meta: <name> proposal <branch>` line to `- meta: <name> withdrawn <branch> — <reason>`, and leaves it for the owner to commit, as `propose` does.
  - Refuses when no spec names the branch, or when the pin's release already holds it.
  - Prints the command that deletes the branch on the metarepo, for the metarepo's owner. It deletes nothing there: rule 1, a pararepo writes the metarepo only by `jig propose`.
  - Effects:
    - `PROPOSAL` doesn't match a withdrawn line. So sync doesn't list it, gate doesn't wait on it, and it answers no new P2 change.
    - `proposed_copy` skips a spec whose proposal is withdrawn. Its rows still Open go again in the next release's proposal: they are still owed.
- **Sync's report.** A proposal that is not released and carries no Open row reads `not released, and carries no Open row: \`jig propose --withdraw <branch> --reason …\` if it won't be`.
- **P2, a row leaving Open.** One helper, `row_state(cell)`, gives Open or Closed. Every reader of the State cell goes through it: P2's well-formed check, `closed_row`, sync's close and release's ledger check.
  - Every close keeps the other cells unchanged and touches no contract path, as today.
  - A bare `Closed` is accepted only when a proposal carrying the row as it stands is in the pin, read from the staged `para.json`. The hook checks this against the metarepo checkout with `proposal_in`. If the metarepo can't be reached, it refuses and names `jig repos add meta`. Sync's own commit passes: it fetched first, and stages the pin it moved.
  - `Closed (answered in <tag>: <reason>)` is accepted only when the reason is non-empty and `<tag>` is a version at or below the staged pin. Whether `<tag>` exists is checked by `--answered`, where the metarepo has just been fetched.
  - Any other close is refused. The message names both commands.
- **RULES.md.**
  - The sync buffer paragraph gets a third way out of Open (answered, on the owner's word, release recorded) and withdrawal.
  - P2's row says what a close needs: the proposal released at the pin, or an answer naming a release at or below it.
  - Commands lists both.
- **BUFFER template.** One sentence on the answered state.
- **Hubnode skill**, step 5.
  - Pararepo: put a "carries no Open row" proposal to the owner; withdraw it only on a yes.
  - Metarepo: leave out a branch whose pararepo spec says `withdrawn`, and name it as deletable on the owner's word.

## Done when
Section `sync_buffer` in `tests/smoke.sh`, extended. Fixture: B1 and B2 Open, proposed as `propose/sb-para-buffer-v…`. The metarepo answers D-001 on another branch, releases, and the pin is bumped.
- [ ] Symptom gone. `jig sync --answered B1,B2 --in <that release> --reason "redocumented"` makes one commit:
  - its subject names B1, B2 and the release;
  - both rows read `Closed (answered in <release>: redocumented)`, other cells unchanged;
  - `git status --porcelain` is empty.
- [ ] Refused, with nothing committed:
  - `--in` a release above the pin;
  - `--in` a tag the metarepo doesn't have;
  - an empty `--reason`;
  - an id that is Closed or missing.
- [ ] By hand, each refused naming P2:
  - an `answered` state with no reason;
  - one naming a release above the pin;
  - one in a commit that touches `api/a.py`.
- [ ] The tightened bare close. A bare `Open` → `Closed` flip of a proposed, unchanged row whose proposal isn't released is refused naming P2. The existing smoke case where sync closes B1 and B2 after the release still passes.
- [ ] After the answered close, sync prints the `--withdraw` line for the proposal. `jig propose --withdraw <branch> --reason moot` rewrites the spec's line to `withdrawn`. Committed, a later `jig sync` prints no line for that branch, and the metarepo still has the branch.
- [ ] Withdraw a proposal whose row B3 is still Open. The next `jig release` opens a new proposal listing B3.
- [ ] `jig propose --withdraw` on a branch the pin's release holds is refused.
- [ ] A job whose spec cites a withdrawn proposal gates without waiting for it.
- [ ] `jig release` after the answered close opens no proposal for B1 or B2.
- [ ] `grep` finds RULES.md's "answered in", "withdrawn" and both Commands lines.
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin` and `.jig/scripts/check.sh` pass, output shown.

## Out of scope
- **Checking that the claim is really gone.** A claim is prose. jig checks the release, and the owner's reason says why, the way `meta: none — <reason>` does.
- **Deleting the metarepo branch.** That is the metarepo's own change. Withdraw prints the command.
- **Reopening a Closed row.** A claim that drifts again gets a new row, as today.
- **Maige-Lite's rows B1 and B2.** It gets the commands through `/jig:update`, then closes them on the owner's word.

## Touches
- `marketing/FEATURES.md` (gitignored), first. Rows: "Sync buffer", "`propose --buffer`, release proposes the buffer, sync closes it", "Pararepo gates P1–P3", "`init --para` / `sync` / `propose`".
- `plugin/templates/jig/jig.py`:
  - `row_state` (new), and its callers: `para_rules`, `closed_row`, `sync_meta`'s close and release's ledger check;
  - `para_rules` P2: the close branch;
  - `sync_meta` and `cmd_sync`: `--answered`, the "carries no Open row" line;
  - `cmd_propose`: `--withdraw`;
  - `proposed_copy` skips withdrawn specs;
  - the argument parser.
- `plugin/templates/jig/RULES.md`: The sync buffer, P2's row, Commands.
- `plugin/templates/ledgers/BUFFER.md`: one sentence.
- `plugin/skills/hubnode/SKILL.md`: step 5, two clauses.
- `tests/smoke.sh`: `sec_sync_buffer`.

## Alternatives considered
- **Let a hand edit close a row if it writes a reason.** Rejected: today a bare flip already slips through, and the hook can't tell a hand commit from sync's. A command that checks the release and writes a fixed form is what P2 can verify. Reason is [seen].
- **A new `jig buffer close` command**, as the report suggests. Rejected: RULES.md has `jig sync` as the one closer of rows, and the hubnode already runs it on trunk. A flag keeps that true. Reason is [seen] (RULES.md, hubnode step 5).
- **Withdraw by deleting the proposal's spec.** Rejected: sync goes quiet, but the record of what went is lost. Any Open rows it carried silently go again. Reason is [seen].
- **Sync stops listing a proposal with no Open row, no command.** Rejected: a regular proposal has no rows, and "carries no Open row" isn't "won't be released". Withdrawal is the owner's word, so it is a command. Reason is [seen]: `sync_meta` lists every `proposal` line.
- **Note the answer in the Open row and leave it.** Rejected: the edited row is proposed again at the next release, opening a moot branch. Reason is [seen].
- **A sixth column for the answer.** Rejected: it changes the table every pararepo has, which means a LAYOUT step. The State cell already says how the row left Open. Reason is [assumed].

## Decisions
- **Tightening the bare close is in scope.** It is the same branch of P2. Without it the new command is optional, and the silent close stays the easy path.
- **The hook reaches the metarepo for a bare close only.** Every other commit is unaffected, and an answered close checks against the staged pin, not the network.
- **No STAMP bump.** No file moves and no default changes. A State cell reading `Closed (…)` is new content, read by the repo's own trunk `jig.py`.

- **The hook may check the metarepo checkout for a bare `Closed`** (Dave, 2026-11-13: "Yes, open all eight", taking the hubnode's recommendation).

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
