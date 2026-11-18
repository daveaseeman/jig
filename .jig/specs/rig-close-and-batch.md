# rig-close-and-batch: `/jig:rig` starts `/jig:fix`, asks one question per batch, and closes what a merge leaves

Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-rig-batch-one-job.md): "write the /jig:feedback so that these would be offered together in the first round in the future"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make sure subnodes archive and their specs are removed when jobs are done and merged"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make jig:rig also close finished specs and subnodes"
Source: the owner, jig hubnode session, 2026-11-18: "make `/jig:rig` in the jig repo also run `/jig:fix`(only in the jig repo)"

Merged from `bug-rig-batch-one-job`, `bug-merged-job-cleanup` and `rig-runs-fix`. Their
investigations (Why, Givens, One layer up, General?) are unchanged at c721fd3:
`git show c721fd3:.jig/specs/<input>.md`.

## Intent
`/jig:rig` carries work through its whole life in one run. In the jig repo it starts
`/jig:fix` on each staged feedback report no fix is already working on, and shows it under
Running. It offers a batch of related staged files and specs as one question per group, in the
round the batch first appears: a staged decisions file is grouped by the Touches its entries
name, and a staged file a spec already carries is listed as taken by that spec, not offered
again. A merged job leaves nothing behind: its spec and bug specs leave `.jig/specs/` in the
merge commit, their scopes kept in its handoff note, and its sessions are archived; rig closes
whatever a merge left. In any other repo, rig treats feedback as it does now.

## Design

Each input's design holds, as written at c721fd3, except where **Where they meet** below
joins two of them. In short:

**From bug-rig-batch-one-job** (Design 1–8 there).
1. Part A, `rig_items`: a `kind: decisions` staged file's touches are the union of
   `entry_touches` over its `log_entries`, less `<repo>:<path>` pointers and
   `Touches: none — …`, plus `.jig/decisions.md`. Every other kind reads as today.
2. Part C: a staged file whose `provenance` mark is in a waiting spec, or in an open job's spec,
   gets state `taken`, `waits_on` `spec <path>` or `job <name>`, no group, no block, counted in
   neither `can_start` nor `waiting_on_you`, listed under Waiting on.
3. Part B, `rig_state`: each group with an overlap counts once in `waiting_on_you`; pairs no
   longer count. Each group in `--json` keeps its `overlaps` and gains, per member, the Touches
   it shares with the others and a flag when all of them match an `append_globs` path.
4. Part B, `rig_text`: under Waiting on you, one `group N: one job for K items, or keep some
   apart` line per such group; the pairs stay under the group in Can start now.
5. Rig skill § 3: one block per group with an overlap ("one job for <items>" recommended, a
   "keep <item> apart" option per member the judgments or the flag set apart, then "each its
   own job"); one block per group with no overlap that holds ready staged files (write their
   specs, in `after` order); a lone ready staged file keeps today's block. § 2's count line and
   Waiting on you say "each group with an overlap".
6. Rig skill § 4: "one job" is the spec role's consolidate with the group's staged files and
   specs as inputs, each staged file's mark a `Source:` line; "keep apart" is a
   `Kept separate from <the group's spec>: <reason>` line; "write a spec" carries
   `Source: <source> (staged as <file>)` for each staged file, decisions files included.
   `/jig:rig auto` is unchanged for these blocks.
7. RULES (Workflow, `jig rig`) says the same. Spec skill, Consolidate: staged files can be
   inputs, their marks kept as `Source:` lines.
8. `marketing/FEATURES.md`, the `/jig:rig` row: one block per group, not per question.

**From bug-merged-job-cleanup** (its Design there).
- `finished_specs(snap, board, job=None)`: each spec in the tree that is complete
  (`complete_specs`) and named by no open job, or a `Bug-for: <job>` spec whose job isn't on the
  board; each with its completing note; with `job`, only that job's. A spec a cached metarepo
  pointer names is left out, and the step prints why.
- `close_specs(list)`: a `Scope: …` line after the completing note's `Spec:` line (from the
  spec's `Scope:` as trunk holds it at close time), and a `git rm` of each spec.
- `cmd_merge`, on a clean merge, after the entry is deleted and before the roadmap view is
  written: `close_specs(finished_specs(index, board, name))`, printing `closed <spec>`; then,
  after the removal line, `close the sessions that worked on <job>`. A conflicted merge closes
  nothing.
- The roadmap: `roadmap_state` takes scopes from a landed, non-partial note's `Scope:` too (a
  spec in the tree wins); `scope_cell` links a closed spec's stem to its note; `roadmap_rules`
  treats a note's `Scope:` as a spec's.
- Rig: `jig rig --json` gains `finished`; `jig rig --close` (refused off trunk, outside the
  trunk checkout or on a dirty tree, writing nothing then) runs `close_specs`, rewrites
  `ROADMAP.md` when there is a roadmap, and commits once, `close finished specs: <stems>`; the
  text picture names the finished specs.
- Skills and rules: hubnode Merging archives every session started for the merged job (work,
  review, check, bug), with the host's tool where it has one, unless one is still working; a
  session that served no job is archived once its report is read and acted on; each archived
  session is named to the owner. Rig gains a sixth part, **Finished**. RULES: `.jig/specs/`
  holds a task in flight; the merge removes a job's spec and bug specs, the note keeps their
  scopes, `jig rig --close` removes the rest, a job's sessions end at its merge; the command
  list gains `jig rig --close`. `AGENTS.md` drops the release-time archiving sentence.
  `marketing/FEATURES.md` gains a row for merge-time cleanup and `rig --close`.

**From rig-runs-fix** (Design 1–5 there).
1. `jig rig --json`, in the jig repo (`addressed_here("jig", root)`), gives each staged
   `kind: feedback` file addressed here `kind: "feedback"`. Feedback items join no group and no
   overlap, and count as neither can start now nor waiting on the owner. A new `feedback` count
   says how many wait. In any other repo, nothing changes.
2. Rig skill: before drawing the picture, the hubnode starts `/jig:fix` on feedback whose
   `judged` is null, and stores each report's judgment as
   `{"call": "fixing", "about": "<group>", "context": "<the session that took it>"}`. A
   `fixing` report is replayed, never started twice, and listed under **Running** with its
   group and its session.
3. No decision block. `/jig:fix`'s drops and specs show as it shows them; its specs come back
   as waiting specs on the next run.
4. `/jig:rig auto` does the same.
5. RULES' Feedback row: "staged feedback, in the jig repo (`/jig:rig` starts it; `/jig:fix` by
   hand too)".

**Where they meet.** All three change `rig_items`, `rig_state`, `jig rig --json`'s shape, the
rig skill's picture and run, RULES' `jig rig` text and the smoke `rig` section. One design holds
all three:

- **An item's state.** `RIG_KINDS` gains `feedback`. A staged file is, in this order of
  precedence: `taken` when a waiting spec or an open job's spec carries its mark (Part C,
  whatever its kind, feedback included); else, in the jig repo and `kind: feedback`, a
  `feedback` item, state `fixing` when its stored call is `fixing` and `new` when nothing is
  stored; else as today. So a report `/jig:fix` has turned into a spec leaves Running and waits
  on that spec under Waiting on. `--store-put` takes `"call": "fixing"` for a feedback item
  only, and `ready` or `open` for any other staged file, as now.
- **The counts.** `waiting_on_you` = open and unjudged staged files that are neither taken nor
  feedback, plus the open next step, plus each group with an overlap (once), plus each cycle (a
  ring once). `can_start` = items whose `opens` is `now`, as today: taken and feedback items
  have no group, so never count. `feedback` = feedback items not taken. `finished` is a list and
  counts in neither: closing needs no answer. The text's first line keeps its two numbers;
  `rig_text` lists feedback items under Running and finished specs under Finished, the parts
  the skill draws them in.
- **A carried staged file after its job merges.** bug-rig-batch-one-job left this to "the
  closing consolidate"; bug-merged-job-cleanup's Finished part didn't cover it. `close_specs`
  drops each staged file whose mark a spec it closes carries (as `jig staging drop` does, since
  staged files are never committed) and prints `dropped <file>: built by <spec>`. A decisions
  file the job wrote into the log is never resolved into it again, and no carried file comes
  back as ready once its spec is gone. A spec kept by a partial note keeps its files taken.
- **The run's order** (rig skill). § 1: start `/jig:fix` on new feedback and store `fixing`,
  judge every other unjudged item, then `jig rig --json` again. § 2: draw parts 1–5 (Running
  holds the open jobs, then the `fixing` reports). Then `jig rig --close` and the archiving of
  sessions this hubnode started for jobs no longer on the board, listed as part 6, **Finished**.
  § 3: the decisions, with the group blocks. § 4: act, `jig rig --json` again, judge, redraw.
  `/jig:rig auto` runs the same order. A `/jig:fix` session served no job, so the hubnode's
  Merging rule archives it once its report is read and acted on, not rig's Finished step.
- **FEATURES.** The `/jig:rig` row also says that in the jig repo it starts `/jig:fix` on
  staged feedback (AGENTS.md: every feature has a row).

## Done when
From bug-rig-batch-one-job:
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

From bug-merged-job-cleanup:
- [ ] Smoke `roadmap` or `merge_derived`: a job whose spec takes a scope and that carries a
      `Bug-for: <job>` spec is merged. In `HEAD^1..HEAD`, both specs are deleted and the note
      gains `Scope:`. The output names both and prints the close-sessions line after the
      removal line.
- [ ] Smoke: that scope reads `done` before and after the merge, and `jig roadmap` reports
      `ROADMAP.md` fresh, with the scope's link pointing at the note.
- [ ] Smoke: a spec a second open job still names stays after the first job's merge. A spec
      whose only note is `Partial: yes` stays.
- [ ] Smoke: a waiting spec with `` Build after `<merged spec>` `` is still offered by `jig rig`
      as it was.
- [ ] Smoke: after a merge, a new job opened under the merged job's name isn't let through by the
      old `Bug-for` spec (`jig reviewed`'s strike refusal still holds at its third strike).
- [ ] Smoke `roadmap`: a trunk commit dropping a scope that only a note takes is refused, naming
      the note. Re-pointing the note's `Scope:` in the same commit passes.
- [ ] Smoke `rig`: a solo spec completed by a landed note is in `jig rig --json`'s `finished`,
      and a partial note's spec isn't. `jig rig --close` removes it in one commit, and
      `jig roadmap`'s scope states are identical before and after. `--close` off trunk or on a
      dirty tree is refused, and `git status` shows nothing written.
- [ ] The merge and `--close` both call `finished_specs` (`grep -n finished_specs` shows both
      callers).
- [ ] `grep -n archive plugin/skills/hubnode/SKILL.md plugin/skills/rig/SKILL.md` shows the
      Merging step and rig's Finished part, each with the still-working exception.
      `grep -rniE 'archiv' plugin/templates/` finds nothing.
- [ ] The symptom: on this repo's trunk after the job merges, one `jig rig --close` leaves only
      specs that no landed, non-partial note names and no merged job's `Bug-for` names (from
      115, about 95 go). The next merge's commit deletes that job's spec. The hubnode's
      report names the sessions it archived.
- [ ] `AGENTS.md` no longer holds the release-time archiving sentence.
- [ ] `check` passes, and the smoke sections touched pass through `jig queue`.

From rig-runs-fix:
- [ ] Smoke `rig`, in a throwaway repo registered as `jig` (`JIG_CONFIG` set):
  - a staged `kind: feedback` file with `target: jig` is listed with `kind: "feedback"`, in no
    group;
  - `feedback` counts it;
  - `waiting_on_you` and can start now don't count it.
- [ ] Smoke `rig`: the same file in a repo registered under another name is listed as today
  (`kind: "staged"`).
- [ ] Smoke `rig`: after `--store-put` with `{"call": "fixing", …}`, the item's `judged`
  replays it. A change to the file voids it, as for any staged file.
- [ ] `plugin/skills/rig/SKILL.md` names the feedback step, the `fixing` judgment and its place
  under Running. `plugin/skills/fix/SKILL.md` says `/jig:rig` starts it in the jig repo.
- [ ] RULES.md's Feedback trigger names `/jig:rig`.
- [ ] `.jig/scripts/check.sh` exits 0. `bash tests/smoke.sh rig staging` passes (through
  `jig queue` once it's installed). `claude plugin validate ./plugin` passes. The full suite
  runs once, at the check step.

From the merge (Where they meet):
- [ ] Smoke `rig`, repo registered as `jig`: a staged feedback file stored as `fixing`, then a
  waiting spec carrying its mark, is `taken`, waiting on that spec, listed under Waiting on and
  not under Running, and `feedback` no longer counts it.
- [ ] Smoke `rig`: `--store-put` with `"call": "fixing"` on a staged file that isn't feedback
  is refused, and on a feedback item it is stored.
- [ ] Smoke `roadmap` or `merge_derived`: a staged decisions file carried by the merged job's
  spec is gone from `.jig/staging/` after the merge, the output prints
  `dropped <file>: built by <spec>`, and the next `jig rig --json` doesn't list it. The same
  holds for `jig rig --close`. A staged file carried by a spec whose only note is
  `Partial: yes` stays, `taken`.
- [ ] `plugin/skills/rig/SKILL.md` gives the run's order as Where they meet says: feedback in
  § 1, the picture, then `--close` and Finished, then the decisions.

## Out of scope
From bug-rig-batch-one-job:
- Touches for staged requests and stories. They have no Touches shape to read. They still meet a
  batch only through `after:` (part C keeps them out once their spec exists). A follow-on could
  let the stored judgment supply them.
- Staged roadmap changes: the hubnode applies them on trunk, and no job builds them.
- What happens to a staged file after the job carrying it merges. That includes a decisions
  file whose entries the job wrote, which `resolve` (`change: new`) would add again, since its
  duplicate check compares numbered ids. That is the merged-job cleanup group's spec (rig's
  "Finished" part); the closing consolidate decides how the two meet. Here a carried file is
  `taken` only while its spec waits or its job is open.
  *(Merged: now in scope here; Where they meet, "A carried staged file after its job merges".)*
- Exempting append files from overlap. The reporter weighed it (§ 4 of the report): a same-day
  decisions batch that shares only the log would split into separate questions, the opposite of
  what the owner asked. The flag in Design 3 makes keeping such a member apart one option instead.
- Whether a ready decisions file that needs no page work should be offered as "resolve into the
  log" instead of "write its spec". The stored judgment's recommendation already says which,
  and that is unchanged.

From bug-merged-job-cleanup:
- `jig update` listing finished specs: `jig rig --close` is the one sweep. An updated repo loses
  nothing before it runs, because its specs and their scopes stay as they are.
- Spec-only jobs, whose full note names a spec another job builds later. `complete_specs`
  already counts those as done, and today's skills write specs on trunk, not in a job. A repo
  that still runs one hands off with `--partial`.
- Specs with no note (old solo work). `complete_specs` can't prove them done, so they stay.
- Waiting specs that cite a merged spec's path as evidence. The path stays readable in git
  history (`git show <commit>:<path>`).
- An open job whose branch edited a spec another job's merge closes. Its next sync stops on the
  modify/delete conflict, which is the job's to resolve like any other.

From rig-runs-fix:
- What rig shows for a staged feedback file in a repo that isn't jig. Today `jig staging
  resolve` forwards it, and rig's handling there is unchanged.
- How `/jig:fix` groups, investigates and decides: unchanged.
- The rig batch grouping and the Finished part, which belong to the feedback specs
  `bug-rig-batch-one-job` and `bug-merged-job-cleanup`, still being written. The consolidate
  decides how they meet this one.
  *(Merged: decided here; Where they meet.)*

## Touches
- `plugin/templates/jig/jig.py`: `RIG_KINDS`, `rig_items`, `rig_state` (state, counts,
  `feedback`, `taken`, groups' shared Touches and flag), `rig_text` (the group line, Running,
  Finished), `cmd_rig` (`--store-put`'s `fixing`, `--close`), rig's argparse, `cmd_merge`,
  `complete_specs` callers (`finished_specs`, `close_specs`), `roadmap_state`, `scope_cell`,
  `roadmap_rules`
- `plugin/templates/jig/RULES.md`: Documentation's `.jig/specs/` line, Merging, Workflow (the
  `jig rig` paragraph, the Feedback row), the command list
- `plugin/skills/rig/SKILL.md`: § 1 (feedback), § 2 (count line, Waiting on you, Running,
  Finished), § 3 (blocks 3 and 5), § 4 ("Write a spec", one job, keep apart), the run's order
- `plugin/skills/spec/SKILL.md`: Consolidate (staged files as inputs, their marks kept)
- `plugin/skills/hubnode/SKILL.md`: Merging
- `plugin/skills/fix/SKILL.md`
- `tests/smoke.sh`: `rig` (c7 rewritten; parts A, B, C, the batch fixture, `finished` and
  `--close`, feedback), `roadmap`, `merge_derived` or `workflow`
- `AGENTS.md`
- `marketing/FEATURES.md` (gitignored, in the main checkout): the `/jig:rig` row, a row for
  merge-time cleanup and `rig --close`

## Alternatives considered
From bug-rig-batch-one-job:
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

From bug-merged-job-cleanup:
- `jig handoff` copies `Scope:` into the note (the report's answer) — rejected because a scope
  re-pointed on trunk after the handoff would leave the note stale, and old notes need the
  close step to write theirs anyway. One writer, at close time — [seen] (`roadmap_rules`
  re-points on trunk; 95 notes have no `Scope:`).
- The roadmap reads a closed spec's `Scope:` from history (the deleting commit's parent) with no
  note edit — rejected because a renamed scope's done work could never be re-pointed, and every
  roadmap read would walk history — [seen] for re-pointing, [assumed] for cost.
- Sweep every finished spec at each merge — rejected because the first merge after this lands
  would carry about 95 unrelated deletions. `cmd_merge` refuses a dirty tree because "the merge
  commit carries the job and its entry, nothing else" — [seen].
- `jig update` lists and removes finished specs too (the report's section 2) — rejected because
  it is a second sweep of the same list, and rig runs far more often — [seen] (rig/SKILL.md runs
  per decision batch).
- Move finished specs to `.jig/specs/done/` — rejected because RULES.md gives history to git,
  not the tree — [seen].
- Archive at release, as AGENTS.md does now — rejected because the owner asked for "when jobs are
  done and merged" — [seen].
- jig.py records session ids on the board — rejected because sessions are the host's, and
  `jig.py` has no AI-tool dependency (AGENTS.md, Code) — [seen].
- A decision block per finished spec in rig — rejected because the owner said "close", and both
  a removal (git) and an archive can be undone — [seen].

From rig-runs-fix:
- A decision block "run /jig:fix on these?" — rejected, because the owner asked rig to run it,
  and `/jig:fix` itself starts without asking — [seen].
- Rig reads a feedback report as a staged request and writes its spec — rejected, because
  feedback needs the bug role's investigation and General? test, and that is `/jig:fix`'s
  workflow — [seen] (RULES.md, Workflow: Feedback).
- Detect the jig repo by a `plugin/` folder — rejected, because staging already decides "this
  is jig" by `addressed_here`. One test keeps rig and staging from ever disagreeing — [seen].

From the merge:
- A `fixing` feedback report stays under Running after its spec carries it — rejected because
  `/jig:fix`'s work on it is done once its spec exists, and Part C already says where a carried
  file waits — [seen] (`/jig:fix` resolves each report into the spec that carries its mark).
- Resolve a carried decisions file into the log after its job merges — rejected because the job
  already wrote its entries, and `resolve` (`change: new`) would add them again — [seen]
  (bug-rig-batch-one-job, Out of scope; `resolve`'s duplicate check by numbered id).

## Decisions
- The owner, 2026-11-18: "Three rig ones as one job".

From bug-rig-batch-one-job:
- Interpreted: a pointer into another repo is left out of a staged decisions file's Touches,
  since no job here changes it.
- Interpreted: a group's "keep apart" options are offered per member, and the one reply may give
  any partition. That is how the owner answered ("one job for five, keep one apart").
- Interpreted: the count line keeps counting open staged files, the open next step and cycles as
  today. Only pairs become groups.

From rig-runs-fix:
- The owner, 2026-11-18: "make `/jig:rig` in the jig repo also run `/jig:fix`(only in the jig
  repo)".
- Interpreted: "run" means start: rig starts the grouping and the bug roles and doesn't wait for
  them. Their results come back through later runs.
- Interpreted: a stored `fixing` judgment is what keeps rig from starting a second fix on a
  report one is already working on.

From the merge:
- Interpreted: `taken` wins over `fixing`: a feedback report whose spec exists waits on that
  spec, and `feedback` counts only reports not taken.
- Interpreted: the closing step drops the staged files a closed spec carries, the seam
  bug-rig-batch-one-job left to this consolidate and bug-merged-job-cleanup's design didn't
  reach.
- Interpreted: `/jig:fix` sessions are archived by the hubnode's no-job rule, not by rig's
  Finished step, which archives only sessions of jobs no longer on the board.
- Interpreted: rig starting `/jig:fix` is named in the `/jig:rig` FEATURES row, which
  rig-runs-fix's Touches left out.

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
