# Bug: /jig:rig asks about a same-day batch file by file, then pair by pair, not as one job

Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-rig-batch-one-job.md): "write the /jig:feedback so that these would be offered together in the first round in the future"

The report: `/jig:rig` offered one day's staged decisions files one "write its spec?" at a
time. Once they were specs, it offered them as 15 overlapping pairs. The owner chose one job
for five of the six.

## Intent
`/jig:rig` offers a batch of related staged files and specs as one question, in the round the
batch first appears. A staged decisions file is grouped by the Touches its entries name. Each
group with an overlap is asked once, not once per pair. A staged file a spec already carries is
listed as taken by that spec, not offered again.

## 1. Why
**Part A: a staged decisions file joins no group.**
1. Why did each staged decisions file show `"touches": []`? `rig_items` reads every staged file with `touches_spans`, which reads only `## Touches`. [seen]
2. Why only that? `rig_items` never branches on `kind`. A decisions file's Touches are on each entry's `Touches:` line, which `entry_touches` reads for M2. [seen]
3. Root: rig has no reader for the shape a decisions file has, so a batch can meet only through `after:`. [seen]

**Part B: the card asks per file, then per pair.**
1. Why five "write its spec?" answers? Block 3 of the rig skill is one block per ready staged file, whatever its group. [seen]
2. Why 15 pair blocks next? Block 5 is one block per pair in `overlaps`, and `rig_state` counts each pair as a question. [seen]
3. Root: `consolidate`, the spec role and RULES treat a group as one job. Rig alone turns the group into questions about its members. [seen]

**Part C: a staged file whose spec exists is offered again.**
1. Why "2 can start now" when the files' specs exist? Each staged file is listed as ready, in its own group. [seen]
2. Why still staged? `resolve` refuses a request while its spec's group is unanswered. A decisions file with page work has no route to resolve before its job merges. [seen]
3. Root: `rig_items` never checks whether a waiting spec carries a file's mark, the way `resolve` does (`mark in s.read_text()`). [seen]

## 2. Givens
**Versions**
- [seen] The report's `jig.py` is blob f0005adc5fe4. Trunk's (d578dee) is d9e01ea. Every function
  this spec touches is byte-identical in both: `rig_items`, `rig_state`, `rig_text`, `cmd_rig`,
  `touches_spans`, `kept_separate`, `cmd_consolidate`, `log_entries`, `entry_touches`,
  `provenance`, `covered_by`, `rig_next_step`. `plugin/skills/rig/SKILL.md` last changed
  2026-11-16 (c7165a3).

**Reproduced here** (throwaway repo, trunk's `plugin/templates/jig/jig.py`, `append_files`
holding `.jig/decisions.md`. The two staged decisions files each have one entry,
`Touches: docs/features/x.md`.)
- [seen] Both judged ready: `jig rig --json` gives `touches: []` for both, groups 1 and 2,
  `overlaps: []`, "0 things waiting on your answers; 2 can start now".
- [seen] Then specs `entry-a.md` and `entry-b.md` were added. Each carries its file's exact mark
  and a `## Touches` naming `.jig/decisions.md` and `docs/features/x.md`. `jig rig` shows group 1
  (the two specs, one pair, "1 thing waiting"). Both staged files are still listed, as groups 2
  and 3, with "2 can start now".
- [seen] A third spec on `docs/features/x.md`: `jig consolidate` prints "group 1: 3 specs,
  proposed as one job". `jig rig --json` gives `waiting_on_you` 3 and three
  `overlap … : one job, or kept apart` lines under Waiting on you.
- [seen] Part C on RULES' own path: a staged feature request `request-y.md` and its spec `y.md`,
  carrying the request's mark and overlapping `entry-a`. `jig staging resolve` refuses ("is in a
  group of waiting specs whose Touches overlap … Answer it first"). `jig rig` lists the request
  as ready, alone in group 4, so the card would ask "write its spec?" again for a file whose
  spec exists.

**The rules and skills**
- [seen] RULES, Workflow (`jig rig`): ready items that overlap "are one job to answer (merged,
  or kept apart)". Its count counts "each overlapping pair and each dependency cycle, a ring
  once".
- [seen] `rig_state`'s comment above the count says "Every block that asks the owner something
  counts once: a ring is one question, not one per member". The count still adds `len(pairs)`.
- [seen] Spec skill, Consolidate step 2: "Decide, per group, with the owner. One job is the
  default". "A group can split: merge some, keep others apart, one line per pair kept."
- [seen] Rig skill line 11: "Never reorder, regroup or reword its picture." The hubnode can't
  offer a group on its own reading.
- [seen] `kept_separate(body)` is already read from a staged file in `rig_items`, so a
  `Kept separate` line under its `## Owner's answers` keeps it apart.
- [seen] `/jig:stage` and RULES (Staging) route a `change: new` decisions file straight into the
  log by `resolve`, with no spec. The rig skill's block 3 asks "write its spec?" of every ready
  staged file, and § 4 says to "resolve the staged file as `/jig:stage` says". A decisions file
  whose pages need work has no route through a spec, so the reporting hubnode improvised one.
- [seen] `append_globs` always holds `.jig/decisions.md`, so in every repo the log is an append
  file. `overlap_groups` and `rig_state` count a shared append file as an overlap, and
  `jig open` refuses on it.
- [seen] Smoke `rig` c7 asserts one `overlap <a> and <b>:` line per pair under Waiting on you,
  and that a pair adds 1 to `waiting_on_you`.

**From the report, not reproduced here** (the reporting repo is read-only)
- [assumed] Six staged decisions files from one day. Their entries name overlapping pages
  (`vault.md` in two, `walyt.md` in three, glossary terms). Five became separate specs after
  five "write its spec?" answers, and the next run showed 15 pair blocks. The owner answered
  with one partition in one reply: one job for five, one kept apart.
- [assumed] The report's in-memory prototype on that repo: entry Touches alone give two
  groups. Adding the log as a Touch gives one. Part A without part C gives 66 pairs.
- [assumed] The owner wants this for batches in general, not only this one. His words name
  "these". General? (below) holds either way.

## 3. One layer up
- Readers of "what this touches": `touches_spans` (a spec's `## Touches`), `split_touches` (a
  roadmap item's `(touches …)`) and `entry_touches` (a decision entry's `Touches:`). Rig uses the
  first two and never the third. `log_entries` plus `entry_touches` already solve the shape.
- What already treats the group as the unit: `jig consolidate`, the spec role's Consolidate,
  RULES' "one job to answer", `resolve`'s refusal per group. A cycle is asked once per ring.
  Rig is the one reader that splits a group into its pairs.
- Sibling of part C: a roadmap next step whose pages a waiting spec or job names is `covered`.
  It gets state `taken`, is listed under Waiting on, and asks nothing. A staged file a spec
  carries has the same shape. The link already exists: `provenance(head, path)`, which `resolve`
  matches by substring.
- Staged requests and stories have no Touches shape at all. They still meet only through
  `after:`, and part C keeps them out of rounds after their spec is written.

## 4. Workaround or correction
Correction, all three parts. Each reads a link jig already has (entry Touches, the group, the
mark) at the one place the picture is built, so no new state or line shape is needed.

## General?
Picture another repo using staging and `/jig:rig` as RULES describes, run by people and agents
making ordinary mistakes.
- Part A: any repo whose chats stage decisions (a documented kind, one log) gets
  `touches: []` for each file. A day's related decisions are never grouped while staged. General.
- Part B: any repo with N ≥ 3 overlapping waiting specs is asked N(N−1)/2 times and counts that
  many questions, though `consolidate` proposes one job. Only rig asks per pair. General.
- Part C: any request or story whose spec overlaps another is kept staged by `resolve`, as
  RULES says. Rig then offers it again (reproduced above). That is RULES' healthy path, not a
  misuse. General.
None asks more than RULES promises, and none needs anyone working against jig. Nothing dropped.

## Design
1. **Part A, `rig_items`.** A staged file whose header says `kind: decisions` gets as touches
   the union of `entry_touches` over `log_entries(body, log_prefix(trunk))`, each pointer once.
   A pointer into another repo (`split_pointer` names a repo) is left out, since no job here
   changes it. A `Touches: none — <reason>` entry adds nothing. Then add `.jig/decisions.md`,
   the file's destination: the log is what its spec will list, so the file and its spec group
   by one rule. Every other kind reads as today.
2. **Part C, `rig_items` / `rig_state`.** A staged file whose `provenance` mark is in a waiting
   spec, or in an open job's spec, gets state `taken`. Its `waits_on` names `spec <path>` or
   `job <name>`. It has no group, no block, and is counted in neither `can_start` nor
   `waiting_on_you`. It is listed under Waiting on, as a covered next step is.
3. **Part B, `rig_state`.** Each group with an overlap counts once in `waiting_on_you`, and pairs
   no longer count. Each group in `--json` carries its `overlaps` as now. It also carries, for
   each member, the Touches it shares with the others, and a flag when all of them match an
   `append_globs` path. That member meets the group only through an append-merged file, so it
   is the natural one to keep apart. `rig_state`'s comment on the count says why: a group is one
   question, as a ring is.
4. **Part B, `rig_text`.** Under Waiting on you, one line per such group:
   `group N: one job for K items, or keep some apart`. The pairs stay listed under the group in
   Can start now, as detail.
5. **Part B, rig skill § 3.** Blocks 3 and 5 become:
   - A group with an overlap gets one block. The recommended option is "one job for <items>":
     one spec from its staged files and specs. There is one "keep <item> apart" option for each
     member the stored judgments or the flag set apart (an `after` item, an append-only member,
     one waiting on a ruling). Last is "each its own job". The one reply may name any partition.
   - A group with no overlap that holds ready staged files gets one block: write their specs,
     in `after` order.
   - A lone ready staged file keeps today's block.
   § 2's count line and Waiting on you list say "each group with an overlap", not each pair.
6. **Part B and C, rig skill § 4.**
   - "One job": the spec role's consolidate takes the group's staged files and specs as inputs.
     Each staged file's mark is a `Source:` line in the merged spec.
   - "Keep apart": a `Kept separate from <the group's spec>: <reason>` line in the kept item's
     spec, or under a staged file's `## Owner's answers`.
   - "Write a spec": the spec carries `Source: <source> (staged as <file>)` for each staged file
     it is written from, decisions files included. The job still writes no mark into pages or
     the log.
   `/jig:rig auto` is unchanged: a group with an overlap needs the owner's answer.
7. **RULES (Workflow, `jig rig`)** says the same: a decisions file's Touches, a carried file
   taken, one question per group. **Spec skill, Consolidate**: staged files can be inputs,
   their marks kept as `Source:` lines.
8. **`marketing/FEATURES.md`**, the `/jig:rig` row: "one short block per question" becomes one
   block per group. The why: a batch is one decision, and the owner was asked 20 times for it.

## Done when
- [ ] Part A fires: in the reproduction repo (two staged decisions files, entries
  `Touches: docs/features/x.md`, judged ready, no specs), `jig rig --json` gives each
  `touches` `["docs/features/x.md", ".jig/decisions.md"]`, both in one group, and `overlaps`
  naming the pair.
- [ ] A staged `kind: spec` file keeps its `## Touches` reading. A staged request with no
  `## Touches` still gives `[]`. An entry `Touches: none — <reason>` adds only the log. A
  `<repo>:<path>` pointer is not in `touches`.
- [ ] Part C fires: in the same repo with `entry-a.md` and `entry-b.md` carrying the files'
  marks, `jig rig --json` lists `decisions-a.md` and `decisions-b.md` as `taken`, waiting on
  `spec .jig/specs/entry-a.md` and `entry-b.md`, with `group` null. The text's first line says
  "0 can start now" (today "2"). A staged request whose spec carries its mark and sits in an
  unanswered group is `taken` too, and no "write its spec?" is drawn for it.
- [ ] A staged file whose mark is in an open job's spec is `taken`, waiting on `job <name>`.
- [ ] Part B fires: with three waiting specs that pairwise overlap, `waiting_on_you` is 1, not
  3. Waiting on you holds one `group 1: one job for 3 items, or keep some apart` line and no
  `overlap … and …:` line. The three pairs are still listed under group 1 in Can start now.
- [ ] A member that shares only `.jig/decisions.md` with its group is flagged in `--json`.
- [ ] The symptom is gone, round 1: a smoke fixture of a same-day batch, with three staged
  decisions files whose entries name overlapping pages and one staged request `after:` one of
  them, all judged ready. `jig rig` gives one group, counted once. The skill text draws one
  block for it, "one job" recommended, with no per-file "write its spec?" block and no pair
  block.
- [ ] The symptom is gone, round 2: the same fixture after one merged spec carrying all four
  marks is written. The four staged files are `taken`, waiting on that spec. `waiting_on_you`
  counts no pair and no staged file.
- [ ] `jig rig` stays deterministic: two runs on one state print the same bytes (the existing
  smoke check).
- [ ] Smoke `rig` c7 is rewritten for one line and one count per group. The sections `rig`,
  `staging`, `staging_batches` and `consolidate` pass. `.jig/scripts/check.sh` passes.

## Out of scope
- Touches for staged requests and stories. They have no Touches shape to read. They still meet a
  batch only through `after:` (part C keeps them out once their spec exists). A follow-on could
  let the stored judgment supply them.
- Staged roadmap changes: the hubnode applies them on trunk, and no job builds them.
- What happens to a staged file after the job carrying it merges. That includes a decisions
  file whose entries the job wrote, which `resolve` (`change: new`) would add again, since its
  duplicate check compares numbered ids. That is the merged-job cleanup group's spec (rig's
  "Finished" part); the closing consolidate decides how the two meet. Here a carried file is
  `taken` only while its spec waits or its job is open.
- Exempting append files from overlap. The reporter weighed it (§ 4 of the report): a same-day
  decisions batch that shares only the log would split into separate questions, the opposite of
  what the owner asked. The flag in Design 3 makes keeping such a member apart one option instead.
- Whether a ready decisions file that needs no page work should be offered as "resolve into the
  log" instead of "write its spec". The stored judgment's recommendation already says which,
  and that is unchanged.

## Alternatives considered
- Keep per-pair blocks and only sort them under their group — rejected because the owner still
  answers N(N−1)/2 times for one decision, and the count still says so — this reason is [seen]
  (reproduction: three specs, `waiting_on_you` 3, three pair lines).
- Let the hubnode regroup the picture by its own reading — rejected because the skill forbids
  regrouping so the same state prints the same bytes, and the group already exists in
  `jig rig`'s output — this reason is [seen] (rig skill l. 11, RULES "the same state prints the
  same bytes").
- Record a group's answer as a new kind of line — rejected as unneeded, because one merged spec
  and `Kept separate` lines already answer every partition — this reason is [seen] (spec skill
  Consolidate step 2; `kept_separate` read from staged bodies in `rig_items`).
- Entry Touches without the log as destination — rejected because a decisions file and the spec
  written from it would group by different rules, so a member joined only through the log is
  asked in round 1 and again in round 2 — this reason is [assumed] (the report's prototype on
  its repo; not rerun here).
- Match a carrying spec by any `Source:` line naming the file in its own words — rejected
  because `resolve` finds the carrying spec by the exact mark, and two rules for one link would
  disagree — this reason is [seen] (`resolve`, `mark in s.read_text()`).
- Drop or resolve the staged file as soon as its spec is written — rejected because its work
  isn't on trunk yet, and RULES keeps a request staged until its spec's group is answered —
  this reason is [seen] (RULES, Staging; the reproduction's `resolve` refusal).

## Decisions
- Interpreted: a pointer into another repo is left out of a staged decisions file's Touches,
  since no job here changes it.
- Interpreted: a group's "keep apart" options are offered per member, and the one reply may give
  any partition. That is how the owner answered ("one job for five, keep one apart").
- Interpreted: the count line keeps counting open staged files, the open next step and cycles as
  today. Only pairs become groups.

## Touches
- `plugin/templates/jig/jig.py`: `rig_items`, `rig_state` (count, groups' shared Touches and
  flag, `taken` staged files), `rig_text` (the group line).
- `plugin/skills/rig/SKILL.md`: § 2 (count line, Waiting on you), § 3 (blocks 3 and 5), § 4
  ("Write a spec", one job, keep apart).
- `plugin/skills/spec/SKILL.md`: Consolidate (staged files as inputs, their marks kept).
- `plugin/templates/jig/RULES.md`: Workflow, the `jig rig` paragraph.
- `tests/smoke.sh`: `rig` (c7 rewritten; parts A, B, C and the batch fixture).
- `marketing/FEATURES.md` (gitignored, in the main checkout): the `/jig:rig` row.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
