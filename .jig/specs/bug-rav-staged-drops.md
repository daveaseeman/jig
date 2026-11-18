# Bug: rig-and-versioning guesses which staged files a closed spec built, and each fix moved the guess

Source: the hubnode, jig hubnode session, 2026-11-18: "three blocking reviews in a row, each on which staged files a closed spec carried and when to drop them" — the reviews of main...d8b8fa8 (recorded at ec64582; B1, and S1 as the spec cites it), of main...a12af04 (B1, B2) and of a12af04..64a8fd3 (F1, F2), for job rig-and-versioning, its third strike.
Bug-for: rig-and-versioning

## Intent
A staged file leaves `.jig/staging/` one way: `jig staging resolve`, which looks at what the tree
holds now and refuses when it can't tell, or `jig staging drop` by hand. A merge and
`jig rig --close` delete nothing in staging. What a closed spec carried stays findable in the
tree: the close copies its `Source: … (staged as …)` lines onto its note, as it copies `Scope:`.
`resolve` lands a carried story, request or report whose spec has closed, without writing
anything; `jig rig --close` runs exactly those resolves. A carried decisions file stays, noted,
for the hubnode to drop or resolve by reading the job and the log. A file
nothing in the tree carries is an ordinary staged item again, judged like any other.

## 1. Why
1. Q: Why did three reviews block on staged files? A: Each found a case where the drop rule deleted
   a staged file nothing built, or missed one a job did build. Each fix moved where the rule looks.
2. Q: Why can't a rule find "this job built that file"? A: Nothing records it. The drop infers it
   from a spec leaving the tree while carrying the file's mark: in the index, in HEAD, in history.
3. Q: Why infer instead of using staging's exit? A: `resolve` re-adds a decisions file's entries a
   job wrote and numbered. The drop routed around that gap with a second exit that deletes. Root.

Root: the job added a second way out of staging, a delete keyed on an inferred link (a spec that
carried the mark left the tree), while the staged file is uncommitted, so every wrong inference is
a loss git can't undo; the gap it routed around is one missing check in `resolve`.

## 2. Givens
- [seen] Round 1 (main...d8b8fa8) B1 is about a `Bug-for:` spec left on trunk by a merge finished
  by hand. a12af04 fixed it (close at `jig merge --number`, `jig open` refusing the old name). It
  isn't about staged files; the staged-file thread starts at that review's S1 (drop before the
  commit lands), cited in rig-and-versioning's Alternatives.
- [seen] Round 2 (main...a12af04): B1, a merge stopped before its commit had already staged the
  close, so `--number` found no finished spec and the drop was never named; B2, a partial note's
  spec didn't count as a carrier, so its file was offered again.
- [seen] Round 3 (a12af04..64a8fd3): F1, `closed_carriers()` reads every first-parent deletion of
  a spec as a close; F2, every spec in the tree carries, a spec no flow builds included.
- [seen] F1 rerun at 64a8fd3 (the reviewer's `repro3.sh`, run with `SRC=<this worktree>`; a copy
  is in the shared notes folder, `bug-rav-staged-drops/repro3.sh`): a
  spec removed by hand (A), a reverted spec (B) and an old spec with the same mark (D) each make
  rig list the file `taken … closed: jig rig --close drops it`; `jig rig --close` then prints
  `dropped da.md / dr.md / notes.md: built by …` and deletes all three. Case C: a spec held by the
  newest tag, no note, leaves its file `taken` while `specs []` and `finished []`.
- [seen] The drop machinery at 64a8fd3: `close_specs` returns drops; `pending_drops` (index vs HEAD
  and MERGE_HEAD), `closed_carriers` (trunk history), `owed_drops`, `drop_built`; callers
  `cmd_merge` (clean, stopped at derive, refused commit, `--number`), `close_merged` and
  `rig_close`. Four readers of one inferred link, each from a different source.
- [seen] `resolve`'s exits are all present-state: a story, request or feedback resolves when a spec
  in `.jig/specs/` carries its mark and the spec's group is answered; a roadmap or root rules file
  when a trunk commit's message carries the mark; an update when the destination carries it; a
  pin-bump (versioning design) when trunk's pin reaches its release.
- [seen] `resolve` of a `change: new` decisions file, in a throwaway repo after a commit wrote its
  `D-?foo Use foo` entry and renamed it `D-001`: `resolved dec.md: 1 entry added`, and the log has
  `D-?foo` and `D-001` both. Its duplicate check compares numbered ids, so a placeholder never
  matches. This is the gap the drop was built around (rig-and-versioning, Alternatives: "Resolve a
  carried decisions file … `resolve` would add them again").
- [seen] rig-and-versioning's Alternatives reject "drop as soon as the spec is staged for removal"
  because "a refused commit or an aborted merge then loses an uncommitted file git can't bring
  back". Every later round is a different answer to "when is it safe to delete", each reached by
  inference.
- [seen] `close_specs` already writes one fact onto the note at close time (`Scope:`), with "one
  writer, at close time" as the reason (bug-merged-job-cleanup's Alternatives).
- [seen] The drop is `Interpreted:` in rig-and-versioning's Decisions ("the closing step drops the
  staged files a closed spec carries"); no owner line asks for it. The owner's words ask that
  merged jobs leave no specs or sessions behind and that rig close finished specs.
- [assumed] A `Bug-for:` spec carries no staged file's mark: bug specs come from reviews, not
  staging. If one did, its mark goes nowhere at close (it has no note), and the file is an ordinary
  staged item again. A risk, not a loss: nothing deletes it.
- [assumed] A note header line `Source: … (staged as …)` trips no note check. The work role
  confirms with the `close` smoke section before relying on it.

## 3. One layer up
- Sibling: every other staged kind leaves through `resolve`, and none is deleted by a merge. The
  roadmap and root rules files had the same problem (the landing isn't in the file) and solved it
  by a recorded mark (the commit message), not by inference. This job is the one place a staged
  file leaves without `resolve`.
- Sibling: `Scope:` had the same problem (a closed spec's facts must outlive it) and the job
  solved it by copying onto the note at close. The carried marks are the same shape.
- Structural difference: `resolve` asks "is it landed now?" and refuses when unsure; the drop asks
  "did a past event build it?" and deletes when it guesses yes. A guess about history can't be made
  exact, so each round found a new history (stopped merge, partial note, reverted commit).

## 4. Correction
A correction, not a workaround: remove the second exit, record the link at the one moment it is
known (the close), and fill `resolve`'s one gap.

1. **No drops.** `close_specs` returns its lines only. `pending_drops`, `closed_carriers`,
   `owed_drops` and `drop_built` go, with every caller's drop and "owed drop" lines. A merge and
   `jig rig --close` write nothing under `.jig/staging/`.
2. **The close records what the spec carried.** `close_specs` copies each `Source: … (staged as
   …)` line of a spec it closes onto its note's header, beside `Scope:`, by the same writer.
3. **Carriers are present state.** A staged file is `taken` when a spec in flight carries its
   mark: a waiting spec, an open job's spec, or a spec whose only note is partial. It is `built`
   when a finished spec still in the tree (pending its close, or kept) or a landed note's header
   carries it: rig lists it under Finished, "`jig rig --close` resolves it". Otherwise it is an
   ordinary staged item. Nothing reads history to decide. (This is F2's rule.)
4. **`resolve` fills its gap for requests.** A story, request or feedback file resolves when a
   landed note's header carries its mark, as it does for a spec. A decisions file is never
   resolved by matching its entries against the log (the owner, 2026-11-18): when a landed note
   carries it, it is an ordinary staged item `noted: <note>`, counted for the owner, and the
   hubnode reads the note's job and the log, then `jig staging drop`s it when the job logged its
   entries, `jig staging resolve`s it when it didn't, and judges with the owner when only some
   are there. Hand `resolve` of a decisions file adds its entries under its existing checks.
5. **`jig rig --close`** (trunk, clean tree, after its own commit when it closed anything) runs
   `resolve` on each `built` file for which `resolve` would write nothing, printing resolve's own
   line. A carried file that isn't `built` (a decisions file) stays, an ordinary staged item for
   the hubnode, `noted` with the note that carried it.

Original symptoms: round 2 B1 (stopped merge) — nothing is owed, the close in the index lands with
the commit, and `--close` resolves afterwards. Round 2 B2 — a partial note's spec is in flight, so
`taken`. Round 3 F1 A, B, D — no note carries the mark (no close wrote it), so the file is an
ordinary item, never deleted. F1 D with a close-written note carrying a same-named mark from the
same source would resolve: marks are taken as unique, as `resolve` takes them today (Out of scope).
Round 3 F2 case C — a released spec with no note is not in flight and not finished, so its file is
an ordinary item.

## Design
In rig-and-versioning's spec, this replaces, under **Where they meet**, the bullet "A carried
staged file after its job merges" and, under **Where rig and versioning meet**, "After the pin-bump
job merges" (the pin-bump resolves through `resolve` once trunk's pin reaches its release, which
`--close` runs). Its Intent's "no carried file comes back as ready once its spec is gone" holds,
by `built` and `resolve`. The Decisions lines "Interpreted: the closing step drops…", "Interpreted
(review of a12af04): every spec in the tree carries…" and "Interpreted (review of part 1): a staged
file is dropped only when…" are replaced by this spec's. The Done-when items that print
`dropped <file>: built by <spec>` print resolve's line from `jig rig --close` instead, and a merge
prints nothing about staging.

- `jig.py`: `close_specs` (no drops; copies `Source: … (staged as …)` lines to the note header);
  remove `pending_drops`, `closed_carriers`, `owed_drops`, `drop_built` and their callers' lines in
  `cmd_merge`, `close_merged`, `rig_close`; `rig_items` (carriers as Correction 3, state `built`);
  `rig_text` (Finished lists `built` files); `cmd_staging` resolve (note headers as carriers, the
  decisions "already in the log" landing); `rig_close` (resolves `built` files that write nothing).
- RULES.md, Staging: a staged file leaves only by `resolve` or `drop`; a closed spec's marks go on
  its note; `jig rig --close` resolves what closed specs built. Remove the "a merge or `jig rig
  --close` drops a staged file a closed spec carries" text the job added.
- Rig skill, Finished: lists `built` files and what `--close` resolved.

## Done when
- [ ] F1 fixed: `repro3.sh` cases A, B and D at the fixed HEAD — rig lists each file as an ordinary
  staged item (no `covered`), `jig rig --close` prints no `dropped` line, and `ls .jig/staging`
  still shows `da.md`, `dr.md` and `notes.md`.
- [ ] F2 fixed: case C lists `dx.md` as an ordinary staged item, counted in `waiting_on_you` until
  judged.
- [ ] The correction fires: a job whose spec carries a staged request and a staged decisions file,
  and whose branch writes the decisions entry, merges clean. `git show HEAD -- .jig/handoffs/`
  shows both `Source: … (staged as …)` lines on the note's header; both staged files still exist;
  `jig rig --json` lists the request as `built` and the decisions file as an ordinary item,
  `noted` with the note, counted. `jig rig --close` prints `resolved <request>: carried by
  <note>`, leaves the decisions file staged, and the log holds the entry once.
- [ ] Same job merged through conflicts (`jig merge`, resolve, `jig merge --number`, `git commit`)
  and through a stop at derive.sh: no output names a drop, a carried request is `built` after the
  commit, and `--close` resolves it as above.
- [ ] A partial note: the spec stays, both files are `taken` waiting on it, and `--close` leaves
  them.
- [ ] A decisions file a merged job carried is `noted`, counted, and left by `--close`, the log
  untouched; a staged decisions file nothing carries whose title matches a logged entry is an
  ordinary item `--close` leaves.
- [ ] `grep -nE 'pending_drops|closed_carriers|owed_drops|drop_built|built by' plugin/templates/jig/jig.py`
  finds nothing; `grep -n unlink` in the merge and rig paths finds none for staging.
- [ ] `check` passes; smoke `rig`, `rig_batch`, `close`, `staging` and `roadmap` pass through
  `jig queue`.

## Out of scope
- Two staged files with the same `source:` and the same file name. `resolve` already treats a mark
  as one file's; a collision resolves both here as it would today.
- Resolving a request into its spec before the job merges. `resolve` already allows it once the
  group is answered; this spec doesn't make `--close` do it, since rig-and-versioning keeps a
  carried file `taken` until its spec closes.
- Part 3 (versioning) beyond the pin-bump's landing named in Design; it is held as patches.
- Round 1's B1 (`Bug-for:` spec after a hand-finished merge): fixed at a12af04, not staged files.

## Touches
- `plugin/templates/jig/jig.py`: `close_specs`, `pending_drops`, `closed_carriers`, `owed_drops`,
  `drop_built`, `cmd_merge`, `close_merged`, `rig_close`, `rig_items`, `rig_text`, `cmd_staging`
  (resolve)
- `plugin/templates/jig/RULES.md`: Staging, Handoff, gate, merge (step 3), Workflow (the
  `jig rig` paragraph)
- `plugin/skills/rig/SKILL.md`: Finished
- `plugin/skills/hubnode/SKILL.md`: Merging
- `plugin/skills/spec/SKILL.md`: Consolidate
- `tests/smoke.sh`: `close`, `rig_batch`, `staging`
- `.jig/specs/rig-and-versioning.md`: the bullets, Decisions and Done-when lines Design names

## Alternatives considered
- Keep the drop, keyed on history narrowed to merges whose landed, non-partial note completed the
  spec or a merged job's `Bug-for:` spec (the round 3 reviewer's rule) — rejected because it is a
  fourth reading of history for a delete git can't undo, and the next history (a note edited on
  trunk, a merge reverted after it landed) needs a fifth — [seen] for the pattern (three rounds,
  three sources: index, HEAD/MERGE_HEAD, first-parent log); [assumed] that the reverted merge is
  the next hole.
- Record the built marks in the merge or close commit's message, as the roadmap and rules files do
  — rejected because a merge finished by hand writes its own message, which jig doesn't own, and
  `Scope:` already set the note as the close's one record — [seen] (`cmd_merge` leaves the commit
  to the hubnode after conflicts; bug-merged-job-cleanup's Alternatives).
- Leave carried files to the hubnode: rig names "its spec closed: drop it?" as a decision block —
  rejected because the tree can answer it (`resolve`'s checks) and the owner asked for fewer
  questions per run, not more — [seen] (rig-and-versioning, bug-rig-batch-one-job's Source).
- Resolve a decisions file into the log when its spec is written — rejected because an accepted
  entry under `## Unreleased` would claim work not yet on trunk, and the job writes its entries
  with the pages — [assumed].
- Delete at close but keep a copy (move to a trash folder) — rejected because it is the same
  inference, now with a second place nobody reads — [assumed].

## Decisions
- The owner, 2026-11-18: "Only via resolve". That is option (a): no drops; the close copies the
  spec's `Source: … (staged as …)` lines onto its note; `resolve` lands a carried file from the
  note, writing nothing; `jig rig --close` runs those resolves. Rejected: (b) the auto-drop on a narrowed history rule, and (c) a hand step per
  carried file.
- Interpreted: `taken` covers a spec in flight (waiting, open job's, partial note); `built` covers
  a finished spec still in the tree or a closed spec's note. A released spec with no note carries
  nothing (F2).
- The owner, 2026-11-18, on how a merged job's decisions file leaves staging: "Ya just make it
  the hubnodes job". A decisions file is never resolved by matching its entries against the log:
  it stays `noted`, and the hubnode drops or resolves it. Rejected: matching by title, then word
  for word but the id (five review rounds: renumbered bodies, settled statuses, title collisions).
- Interpreted (review of 205589b): `built` needs a finished spec still in the tree or a landed,
  non-partial note's header carrying the file's mark as a whole `Source:` line; `jig rig --close`
  resolves only what rig marks `built`, and a file resolve refuses is left, named, while the
  rest are tried.

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
