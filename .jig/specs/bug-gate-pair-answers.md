# Bug: the gate misreads a note's pair answers, and busy pages ask too many

Source: Adventure Studio hubnode session / 2026-11-16 / Claude for Dave (staged as feedback-adventure-studio-2026-11-16-gate-pair-answers.md): "a pair line whose shape was changed is reported as \"main moved\""
Source: Adventure Studio hubnode session / 2026-11-16 / Claude for Dave (staged as feedback-adventure-studio-2026-11-16-gate-pair-answers.md): "a pair is made for every entry that shares a page, so most pairs say nothing"

The owner, 2026-11-16, told that two reviewed jobs were sent back at the gate: "is that really
necessary?"

## Intent
A fold-in line that tries to answer a decision pair is either read as that answer or refused
when the note is committed, naming the line. The gate never says trunk moved unless it did.
And a new entry on a busy page asks one line per page, not one line for every entry that ever
touched it. The second part changes a rule and waits on the owner (Decisions).

## 1. Why
**Issue 1: a reshaped pair line is read as missing, and blamed on trunk.**
1. Why was `exports` refused with "main moved since the handoff"? `gate_pairs` found 11 pairs with no keyed line in the note. Its caller has one message for any unmet pair. [seen]
2. Why no keyed line, when the note answered all 11? The job dropped `.jig/decisions.md § ` from each line. `PAIR_LINE` needs it, so `pair_key` returns None. [seen]
3. Why wasn't that caught at commit? `PAIR_SHAPED` needs `vs <log> § ` too, so `pair_problem` skips the line in the hook and in the gate's fold-in check. Root. [seen]

The note itself doesn't help: its Fold-in comment says "Replace each ___ and tick the box", and
never names a pair line's three answers or says that jig reads the line as written. [seen]

**Issue 2: one line per peer, and a page's peers grow with the log.**
1. Why did one `rulings-d92` note hold 187 pair lines? Its 12 new or changed entries each got a line per live entry on their pages: 26 for one entry on docs/governance.md. [seen]
2. Why every entry on the page? `peers_of` pairs two entries when any pointers meet (`keys_meet`: one page, or one above the other), and `pair_lines` writes a line per pair. [seen]
3. Why only whole pages? RULES.md lets `§` name a glossary term only, so a heading rename can't break a pointer (bug-touches-abstract). A page is the finest unit. Root. [seen]

## 2. Givens
**Versions**
- [seen] The report's copy, c2af1224b3cc, is v0.12.2's `jig.py`. The copy here, `git rev-parse
  HEAD:plugin/templates/jig/jig.py`, is f0005adc5fe4: v0.14.0's, and the report's "current copy".
- [seen] fcee5a0 (cheaper-rounds, 2026-11-13, in v0.13.0) did two things. It added
  `pair_problem` to the commit hook for a job's own notes. And it changed the gate's remedy for
  unmet pairs from "`jig sync`, then hand off again" (v0.12.2, line 1880) to "add each to the
  fold-in …, commit it, and gate again" (now ~2907). So the sync, the review of the sync and the
  second handoff the report counts are gone since v0.13.0.
- [seen] `PAIR_LINE` and `PAIR_SHAPED` are the same in both copies.

**Issue 1, reproduced here** (scratch repos, this copy, the hooks installed by `jig init`)
- [seen] Repo r1 has D-001 to D-003 on `docs/privacy.md`. Job `ex` adds `D-?x` on the same page.
  `jig handoff` writes three lines of the form
  `- [ ] D-?x vs .jig/decisions.md § D-003 (docs/privacy.md): ___`. The job ticks each, drops the
  label, and answers in its own words: `- [x] D-?x vs D-003 (docs/privacy.md): different
  situations, they share docs/privacy.md only`.
  - The commit passes with the hook on.
  - `jig gate ex` prints "main moved since the handoff, and the note doesn't answer these
    pairs: …", listing all three.
  - Trunk's log hasn't changed since the job's base. Trunk's only commit since is the board's
    `open ex`.
- [seen] The same note with the label kept and answered "different situations: …": the hook
  refuses it at commit, naming each line, with "answer agrees, narrows: <how>, or conflicts:
  <resolution>". This is fcee5a0's fix.
- [seen] One generated line deleted, the rest answered agrees: the commit passes, and the gate
  says "main moved since the handoff", naming the deleted pair. This is a sibling path with the
  same false cause.
- [seen] The label-dropped note, then the gate's remedy followed: the note holds six lines (three
  reshaped, three in jig's shape) and the gate passes. The reshaped lines stay as noise.

**The reporting repo** (read only; trees taken with `git --no-optional-locks archive` and
committed in scratch repos as `main` and a branch)
- [seen] `exports`' first note (e7024bb, for commit de2ae5d on base cb04982) has 11 pair lines in
  the form `- [x] D-?member-cap-table vs D-066 (docs/privacy.md): different situations. …`. Its
  answers include "different situations", "consistent", "within it" and "related but not in
  conflict": none is one of the three answers. On that snapshot, this copy's `pair_problem`
  names none of its lines, and `gate_pairs` returns all 11.
  - So that note had two faults: the label dropped, and answers in other words. With the label
    kept, today's hook would have refused the words at commit (as in r1).
- [seen] `rulings-d92`'s gate output ("ten pair lines … answered 'different situations: they
  share docs/cp.md only'") came from the gate's fold-in check, `pair_problem`, not from
  `gate_pairs`.
  - The printed lines carry the job's answers. `gate_pairs` prints jig's blank lines.
  - On the snapshot (6d8ca13 on 3fa017f), this copy's `pair_problem` names 165 lines of
    bca7754's note, and `gate_pairs` names none.
  - The gate prints only the first ten (`open_lines[:10]`, in both copies), with no count of the
    rest. That is why the report read "nine" pairs for an entry that had 21.
  - This refusal is the one fcee5a0 moved to commit. Today's hook names all 165 when the note is
    committed.
- [seen] Later notes keep jig's shape and add lines of the job's own beside them, with no
  checkbox: `- D-?accountant-file vs D-075 (not paired by --peers; …): agrees.`
  (exports-2026-11-16-2.md).

**The rules**
- [seen] RULES.md, the fold-in paragraph: "the gate refuses a line unanswered, reshaped,
  answered with another word …", and "The commit hook refuses a note whose pair line has none
  of the three answers, naming the line". The code doesn't keep the first promise for a line
  reshaped before the `§`.
- [seen] The note's Fold-in comment (`NOTE`) and the work skill's Handoff ("Fill every heading")
  say nothing about a pair line's answers or its shape.

**Issue 2**
- [seen] `rulings-d92`'s three notes each hold 187 pair lines, and 165 of them answer "… they
  share <page> only". By entry and page there are 15 groups, the largest 26
  (`D-?members-comment-petition`, docs/governance.md).
- [seen] On the snapshot, both copies make 187 pair lines for 6d8ca13 against 3fa017f, in 15
  (entry, log, page) groups. `exports` makes 11 lines in 4 groups.
- [seen] Adventure Studio's trunk log has 72 entries. Touches lines name docs/governance.md 22
  times, docs/cp.md 21 and docs/protocol.md 15 (superseded entries included).
- [seen] Scratch r2 has ten entries on `docs/a.md`, and a branch adds an eleventh. `jig handoff`
  writes 10 pair lines. After an unrelated trunk commit, `jig sync` and a second `jig handoff`,
  the new note asks all 10 again, blank.
- [seen] `pair_lines` makes lines only for entries the branch adds or changes
  (`edited_decisions` over `trunk...HEAD`). A later job that changes neither entry of an
  answered pair is never asked it. The report's "asked again of the next job" holds only when an
  entry changed, which RULES.md asks for.
- [seen] RULES.md, Touches: "`§` names a glossary term only, never a heading of another page".
  The owner chose this in bug-touches-abstract: "so a pointer can't break when an ordinary
  heading is renamed". The report's "`PAIR_LINE` already allows a pointer with a section" is
  that glossary term, the only `§` allowed.
- [seen] FEATURES.md, Decision log row: "Touches and peers exist because a pararepo decision
  contradicted a metarepo one and nothing put the two in front of one reader".
- [seen] `jig reviewed` records the blocking count, tier and effort, and nothing about peers.
  Only the fold-in records that anyone read a peer before the merge.
- [assumed] The job dropped the label because every peer is in one log, so the label looked
  redundant (the report's own guess, not asked). The fix doesn't depend on it.
- [assumed] A job reads a page's peers no less carefully from one line than from one line each.
  The 165 identical answers suggest the per-pair lines weren't read one by one either. Not
  checked. The review's step 8 reads the peers either way.

## 3. One layer up
- **The gate's two paths.** The gate has two paths for an unanswered pair. Its fold-in check
  names a line in the note and says what is wrong with it. `gate_pairs` names a pair missing
  from the note, and has one cause built in. A reshaped line falls out of the first path into
  the second. [seen]
- **The pattern that already solves this.** `pair_problem` already handles the shape: a line
  that tries to be a pair line gets a named reason. Widening what counts as trying reuses it, at
  commit and at the gate. [seen]
- **Siblings.**
  - An `Up next` or `Scope` item line reshaped and ticked is invisible the same way
    (`ITEM_LINE`). Its cost is different: a "built" answer missed, so the item stays on the
    roadmap. No refusal, and no report. [seen]
  - Solo work's note is never checked by the hook (the hook returns before its note check when
    there is no job). The gate checks it, run by the same session. [seen]
- **The fold-in already groups by page.** `foldin_lines` writes one line per page, listing what
  it covers: "(3 files)" and the decision ids the page cites. A per-page pair line follows the
  same pattern. [seen]
- **Pairs below the page.** Glossary terms already narrow pairs below the page, and supersession
  removes a pair. Neither helps an ordinary page. [seen]

## 4. Workaround or correction
Corrections, both.
- **Issue 1.** Change what jig treats as an attempt at a pair line, and make the gate say the
  cause it found.
- **Issue 2.** Change the fold-in's unit from a peer to a page.

A workaround in the repo doesn't help. Keeping the label fixes only that note. Section pointers
are refused by M2, and every accepted entry already names whole pages.

## General?
**Issue 1: keep.** Any repo with a decision log gets pair lines once two entries share a page.
Agents and people edit lines jig printed: a label that looks redundant with one log, an answer
in their own words. That is an ordinary mistake. RULES.md already promises that a reshaped line
is refused and that the hook names a pair line with no answer at commit. The fix brings the
code to that promise. A gate message that names a cause it never checked misleads any repo.

**Issue 2: keep.** Every repo's log grows, and Touches can name only whole pages and glossary
terms. So each new entry on a page pairs with every live entry on it, and on the pages above and
below it. Adventure Studio is 72 entries in and already writes 187 lines for one job, 88% of
them "they share <page> only". The repo asks nothing beyond what RULES.md promises. It asks
that the promise cost what it is worth. No one has to work against jig to hit this: honest
entries on a central page do.

## Design
**Issue 1** (a correction, no question)
1. **What counts as a pair line.** A fold-in checklist line `- [ ] <x> vs …` or `- [x] <x> vs …`
   is an attempt at one: `PAIR_SHAPED` is widened from `vs <log> § ` to ` vs `. `pair_problem`
   then refuses any such line that isn't `PAIR_LINE` with "keep a pair line's shape: …",
   naming the line, in the hook (the job's own note, at commit) and in the gate's fold-in check.
   A line with no checkbox is the job's own note and stays free (exports' `- D-?accountant-file
   vs D-075 …`).
2. **The gate names the cause it found.** For its unmet pairs, the gate also finds the pairs at
   the note's commit against its base (the merge-base with trunk), with the same pair finder.
   - An unmet pair found there too is one jig listed at the handoff: the gate lists it as left
     out of the note.
   - The rest are new on trunk since the job's base.

   Each list says its own cause and neither claims the other's. The remedy is the same for
   both: add each line ticked and answered, and commit the note alone.
3. **No silent cut.** The gate's fold-in list, cut at ten, ends with `… and N more` when it cuts.
4. **The note says how.** The note's Fold-in comment says a pair line is answered after its
   colon: agrees, narrows: <how>, or conflicts: <resolution>. Jig reads the rest of the line,
   so it stays as jig wrote it.
5. **RULES.md.** The fold-in paragraph says the hook refuses a reshaped pair line too, and that
   the gate says which pairs are new on trunk.

**Issue 2** (waits on the owner's answer, Decisions; recommended)

6. **One line per page.** Each entry the branch adds or changes gets one line per page it meets
   peers on, per peer log, listing every peer there:
   `- [ ] D-?x vs .jig/decisions.md § D-001, D-039, D-041 (docs/cp.md): ___`. What a peer is
   doesn't change.
7. **Answered once.** The answers are agrees (for every id on the line), narrows: <id>…, <how>,
   or conflicts: <id>…, <resolution>. On a line with more than one id, a narrows or conflicts
   names at least one of the line's ids, or the hook and the gate refuse it, naming the line.
   The gate still tells an answer from a blank: the three words, as now.
8. **Keys per id.** An answered line covers each id on it. A one-id line in today's shape, in a
   note written before this change, still counts. The gate's unmet list prints only the ids
   left uncovered, one line per entry, page and log.
9. **The words around it.** These change to match:
   - RULES.md, the fold-in paragraph and its example line;
   - the review skill's step 8, "These are the pairs the handoff's fold-in will ask about",
     which becomes one line per page;
   - FEATURES.md's Decision log row, "a handoff line per peer entry".

## Done when
**Issue 1**
- [ ] Smoke `touches`: a job's note whose pair line drops the log label (`- [x] D-?x vs D-001
  (docs/a.md): agrees`) is refused by the commit hook, naming the line with "keep a pair line's
  shape". This FAILs at v0.14.0, where the commit passes [seen].
- [ ] Smoke `touches`: the same note committed with the hook off is refused by `jig gate` in its
  fold-in check, naming the line, and the output has no "moved since the handoff". This FAILs
  at v0.14.0, which says "main moved since the handoff" [seen].
- [ ] Smoke `cheaper_rounds`: a note with one generated pair line deleted and the rest answered
  agrees. `jig gate` refuses it, naming that pair as left out of the note, and says nothing of
  trunk moving. This FAILs at v0.14.0 [seen]. In the same run, a pair from a job merged since
  the handoff is still named as new on trunk (the existing two-jobs case in `touches` keeps
  passing).
- [ ] Smoke: a line with no checkbox, `- D-?x vs D-075 (not paired): agrees`, still commits.
- [ ] Smoke: a fold-in with more than ten unanswered lines makes the gate print ten and
  `… and N more`.
- [ ] The reported symptom is gone. A note whose every pair line drops the label never meets
  "main moved since the handoff": the hook names each line at commit. And on the exports
  snapshot (Adventure Studio's de2ae5d on cb04982, as in Givens), this copy's `pair_problem`
  names all 11 lines of e7024bb's note. v0.14.0 names 0 [seen].

**Issue 2** (once the owner answers yes)
- [ ] Smoke `touches`: with ten entries on `docs/a.md` and a branch adding an eleventh,
  `jig handoff` writes one pair line for it, naming D-001 to D-010 on `(docs/a.md)`. This FAILs
  at v0.14.0, which writes 10 lines [seen].
- [ ] Smoke: that line answered `agrees` commits and passes the gate. Answered `narrows: D-004,
  when …`, it commits. Answered `narrows: when …`, with none of its ids, the hook refuses it,
  naming the line. Answered `___`, the hook refuses it.
- [ ] Smoke: a note in today's one-id shape, answered, still passes the gate.
- [ ] Smoke: a job merged since the handoff adds D-011 on `docs/a.md`. The gate names only D-011
  for that entry and page, as new on trunk. The ten answered ids aren't asked again.
- [ ] The reported symptom is gone. On the rulings-d92 snapshot (6d8ca13 on 3fa017f),
  `pair_lines` makes 15 lines, where v0.14.0 makes 187 [seen]. On the exports snapshot it makes
  4, where v0.14.0 makes 11 [seen].

**Both**
- [ ] `.jig/scripts/check.sh` exits 0. `bash tests/smoke.sh touches touches_terms cheaper_rounds`
  passes, and so does `claude plugin validate ./plugin`. `grep -rniE 'adventure|rulings-d92'
  plugin` finds nothing. The full suite runs once, at the check step.

## Out of scope
- **Carrying a pair's answer from one handoff note to the job's next.** In r2 the second note
  asks all 10 again, blank. A per-page line cuts that to one line per page. Carrying answers
  needs a rule for when an answer goes stale (an entry changed between notes), which is its own
  question.
- **A later job asked a pair again.** This already doesn't happen unless one of its entries
  changed [seen], so the report's second Done-when holds today. Nothing changes.
- **A reshaped `Up next` or `Scope` item line.** It is invisible the same way, but costs a
  roadmap item left behind, not a refusal, and nothing reported it.
- **The hook checking solo work's note.** The gate checks it, in the same session, so no round
  is lost.
- **The report's own out-of-scope item:** `jig reviewed` with blocking findings in
  c2af1224b3cc. Today's copy records them (`reviewed --blocking`), and they reach the repo with
  `/jig:update`.

## Alternatives considered
**Issue 1**
- Accept a line naming both ids as that pair's answer, label or not — rejected because in a
  pararepo or metarepo one id can be in two logs (RULES.md: `<repo>/<id>` picks the log), so the
  label is what tells two pairs apart, and RULES.md already says a reshaped line is refused —
  this reason is [seen].
- Leave the regexes and add a hint to the gate's message (the report's first alternative) —
  rejected because the job still learns at the gate, after its review and handoff, that jig
  didn't read its lines — this reason is [seen] (r1: the hook passes the reshaped note).
- Have `jig handoff` lock the pair lines and refuse any edit but the answer — rejected because
  the note is the job's file, and jobs add lines of their own beside jig's — this reason is
  [seen] (exports-2026-11-16-2.md).
- Have the commit hook find every pair and refuse a note missing one — rejected because it would
  read every peer log (in a metarepo, each pararepo's trunk) on every note commit, while the
  gate already finds the pairs on its merge. The fault reported is the wrong cause in the
  message — this reason is [assumed].
- One neutral list at the gate, naming no cause — rejected because a pair new on trunk asks the
  job to read an entry it has never seen, and a left-out pair asks about one it already read. A
  neutral list doesn't say which — this reason is [assumed].

**Issue 2**
- Touches names a section, such as `docs/cp.md § Grants`, pairing on one section only (the
  report's proposal) — rejected because the owner kept `§` for glossary terms so a heading
  rename can't break a pointer (bug-touches-abstract), and every entry on trunk names whole
  pages, which would still meet every section — this reason is [seen].
- Narrow what a peer is, such as two shared pages, or only entries since the last release —
  rejected because peers exist for two entries on one page ruling one situation differently
  (FEATURES.md, the maige-lite report) — this reason is [seen].
- Keep one line per pair and accept free text — rejected because the gate could no longer tell
  an answer from a blank — this reason is [seen] (`pair_problem`).
- Keep one line per pair, and have `jig handoff` prefill agrees — rejected because a prefilled
  answer is a blank the gate can't see — this reason is [seen] (`pair_problem` passes any
  agrees).
- Drop the pairs and leave them to review — rejected because only the fold-in records that
  anyone read a peer before the merge — this reason is [seen] (`jig reviewed` records the
  blocking count, tier and effort only).

## Decisions
- **A question for the owner (Issue 2): what does the fold-in ask per peer?** Recommended:
  - one line per entry, page and peer log, listing every peer there;
  - answered once: agrees, narrows: <id>, <how>, or conflicts: <id>, <resolution>;
  - a narrows or conflicts on a line of several ids names at least one of them.

  What a peer is stays as RULES.md says, and the gate still tells an answer from a blank. On
  rulings-d92 this writes 15 lines for its 187, and on exports 4 for 11.

  The other ways, if the owner prefers one:
  - section pointers, which reverses bug-touches-abstract;
  - a narrower peer, which misses the case peers exist for.

  Until the owner answers, Design 6–9 and their Done-when items wait. Design 1–5 stand alone.
- Interpreted: a reshaped pair line is refused, not read by its ids. RULES.md already says so.
- Interpreted: "left out of the note" is judged against the pairs at the job's base on trunk,
  since jig doesn't record trunk's tip at the handoff. A pair from an entry trunk gained
  between the base and the handoff reads as new on trunk. That is true, though the note may
  have had it.
- Interpreted: a fold-in line with no checkbox is the job's own and is never a pair line.

## Touches
- `plugin/templates/jig/jig.py`:
  - `PAIR_SHAPED` and `pair_problem`;
  - `cmd_gate`: the fold-in list's cut at ten, and the unmet-pairs message;
  - `gate_pairs`;
  - `NOTE`'s Fold-in comment;
  - with the owner's yes: `pair_lines`, `PAIR_LINE`, `pair_key`, `pair_problem` and
    `gate_pairs` for per-page lines.
- `plugin/templates/jig/RULES.md`: the fold-in paragraph (the pair line, its answers, the hook
  and the gate).
- `plugin/skills/review/SKILL.md`: step 8's sentence on the pairs the fold-in asks (owner's yes
  only).
- `tests/smoke.sh`: `touches` and `cheaper_rounds`.
- `marketing/FEATURES.md` (gitignored, in the main checkout): the Decision log row's "a handoff
  line per peer entry" (owner's yes only).
- The owner, 2026-11-17, G1: "one line per page, answered once": one fold-in line per entry, page and peer log, listing every peer there, answered `agrees`, `narrows: <id>, <how>` or `conflicts: <id>, <resolution>`. Design items 6–9 go ahead.
- Kept separate from bug-meta-agents-block: the gate and pair code vs init --meta and update; nothing shared. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed".
- Kept separate from bug-process-in-pages: the gate and pair code vs page rules; only the note's Fold-in comment, merged as text by whichever lands second. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed".

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
