# rig-and-versioning: `/jig:rig` starts `/jig:fix`, asks one question per batch and closes what a merge leaves; versions measure the product, and a metarepo release stages pin bumps

Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-rig-batch-one-job.md): "write the /jig:feedback so that these would be offered together in the first round in the future"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make sure subnodes archive and their specs are removed when jobs are done and merged"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make jig:rig also close finished specs and subnodes"
Source: the owner, jig hubnode session, 2026-11-18: "make `/jig:rig` in the jig repo also run `/jig:fix`(only in the jig repo)"
Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-versioning-and-pin-trigger.md): "Maige-Eco's next release moves its glossary from `README.md § Glossary` to `docs/glossary.md`. That release carries a `**Breaking:**` line, so jig's rule makes it a major release, v4.0.0."

The owner's words, quoted in the versioning report's Source line:
- "I just dont think that's what major release version should be for, they should be for more fundamental changes or significant progress or something like that."
- "in terms of significance to the meta repo this change is a +0.0.1 in my opinion. So maybe we need a better way to update other repos. I mean, why not update them on every version move of the meta?"
- "I think jig's rule should be updated for meta repos. The breaking line should be enough for paras to move their pin. I think semantic versioning is too strict."

The versioning report also quotes the owner's rulings on its Versioning draft, made in that
session (quoted under Part A). Everything else that report proposes is the reporter's. What this
spec adopts from it is marked `Interpreted:`.

Merged from `rig-close-and-batch` (itself merged from `bug-rig-batch-one-job`,
`bug-merged-job-cleanup` and `rig-runs-fix`) and `bug-versioning-pin-trigger`. Their
investigations (Why, Givens, One layer up, General?) are unchanged at c721fd3:
`git show c721fd3:.jig/specs/<input>.md`, and versioning's at d397071:
`git show d397071:.jig/specs/bug-versioning-pin-trigger.md`.

## Intent
`/jig:rig` carries work through its whole life in one run. In the jig repo it starts
`/jig:fix` on each staged feedback report no fix is already working on, and shows it under
Running. It offers a batch of related staged files and specs as one question per group, in the
round the batch first appears: a staged decisions file is grouped by the Touches its entries
name, and a staged file a spec already carries is listed as taken by that spec, not offered
again. A merged job leaves nothing behind: its spec and bug specs leave `.jig/specs/` in the
merge commit, their scopes kept in its handoff note, and its sessions are archived; rig closes
whatever a merge left. In any other repo, rig treats feedback as it does now.
And every jig repo versions by how much its product changed, so a `**Breaking:**` line no
longer raises the level. A metarepo release instead stages a pin-bump request in each pararepo
whose citations it broke, carrying those Breaking lines and the rewrite list; in that pararepo,
rig offers it like any other staged file.

## Design

Each input's design holds, as written at c721fd3 and d397071, except where **Where they meet**
and **Where rig and versioning meet** below join two of them. In short:

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

**From bug-versioning-pin-trigger** (its Design there, as written).

*Part A: versions measure the product.*

1. RULES.md gets a `## Versioning` section just before `## Release`. Interpreted: its text is
   the report's block, which the report says the owner agreed in the session. That agreement is
   [assumed]: it isn't in the Source line. The owner's rulings, as the report quotes them: "1.
   Agreed, adapt it to work for regular repos, meta, and para universally"; "2. I would drop it
   [user effort as a criterion] or dramatically change it then, because this should be an 0.0.1
   in my opinion, a minor fix"; "4. No the policy is for jig which often starts from zero, so it
   needs a policy that applies there and it should be written such that it's clear this section
   simply doesn't apply to repos that are past it"; "Your trigger idea is good, but I dont wanna
   pick the version every time, I'd rather give the hubnodes some idea of how to judge it."
   Two changes to the block: its "What others must do" paragraph says the request goes to "each
   pararepo whose citations the release broke" (Part B's selector), and it ends with one
   sentence: "A repo published to a package registry, whose users expect SemVer, needs a rule of
   its own; jig has none yet."
2. Interpreted: the flags are `--milestone` (X), `--feature` (Y) and `--patch` (Z, the default
   in every kind after the first release), with `--major` and `--minor` kept as aliases. A
   metarepo's first release stays v0.1.0, and a plain repo's first still needs `--version` or
   `--feature`. `--milestone` refuses while the latest release is `0.y.z` or there is none, and
   names `--version 1.0.0` as the owner's call.
3. `LOG_SEED`'s two lines become: "…plus decision entries, and versions are
   MILESTONE.FEATURE.PATCH, set by how much the product changed (`.jig/RULES.md`, Versioning)."
   and "A breaking change is one that a reader taking the release must act on: a `**Breaking:**`
   line says what to change, and it doesn't set the version's level." `log_is_seed` also
   accepts the old seed.
4. Interpreted: `jig update` gets a step that swaps the old two header lines for the new ones,
   only where they match the old text exactly; a header that differs is named, not rewritten.
   R3 allows exactly that swap and nothing else. In a metarepo the swap lands through a job (M4).
5. `newer_release` drops "(a major release)". Under the "is out" line, it prints each
   `**Breaking:**` line of the releases between the pin and the latest, each with its release,
   read with `release_sections` from the metarepo's log at the latest tag.
6. The text, each changed to say Versioning sets the level and a Breaking line doesn't: RULES.md
   923, 1000-1001, 1266-1267 (drop ", released as a major"), 1331-1332, 1416-1418, 1443; release
   skill 16, 20-21 ("Propose the level as RULES.md § Versioning says: the highest level of any
   change in Unreleased, with a one-line reason; a `**Breaking:**` line doesn't raise it") and 53;
   redocument skill 90; hubnode skill's release step ("propose the level with a one-line reason;
   the owner's yes releases it"); jig's own `AGENTS.md` release line (`--feature` or `--patch`).
   RULES.md 991 and 1021-1022 (Breaking lines themselves) stay. Nothing is renumbered.

*Part B: a metarepo release stages a pin-bump request.*

1. **When.** In a metarepo's `jig release`, after the tag. A request that can't be written
   doesn't undo the tag. It prints one line saying why.
2. **Who.** Each name in `meta.json`'s `pararepos`, found through `jig repos`, whose trunk
   `para.json` names this metarepo. One line per pararepo: staged (with counts), or skipped
   because it isn't in `jig repos`, doesn't cite this metarepo, has a future `defer_until`
   (compared exactly as `sync_meta` does), already pins this release, or cites nothing the
   release broke.
3. **Selector.** Interpreted from "The breaking line should be enough for paras to move their
   pin": a pararepo is selected when this release broke something it cites. It reads the
   pararepo's trunk with `meta_citations`' files and exclusions, comparing the previous tag with
   the new one:
   - (a) a citation that resolves at the previous tag and dangles at the new one;
   - (b) a decision id the release removed or superseded, cited as a whole word.

   Rewordings, Open → Accepted, and glossary rewording don't select. The pararepo's own sync
   reports those, as today. `changes_report`'s word grep doesn't select. `meta_citations` takes
   the pararepo and metarepo revisions as arguments instead of reading the cache and HEAD.
4. **What it writes.** `<para>/.jig/staging/pin-bump-<meta>.md`. Its header: `staged: true`,
   `target`, `kind: pin-bump`, `change: update`, `destination: .jig/para.json`,
   `source: <meta> release <tag> / <date>`, `from`, `pin`, `release`, `status: staged`. Its body
   runs from the pin to the new tag: the `**Breaking:**` lines with their releases, the rewrite
   list with each new home jig can name, the removed or superseded ids with the files that cite
   them, and the commit line `newer_release` prints. A later release rewrites the same file in
   place. jig writes nothing else there, and leaves a same-named file that isn't a pin-bump from
   this metarepo alone, naming it. It uses `forward`'s checks.
5. **Landing.** `kind: pin-bump` joins `KINDS`. `jig staging resolve` refuses it until the
   pararepo's trunk `para.json` pins the request's release or a later one. Its message names the
   way to land it: a job (`/jig:spec`) whose pin commit carries the request as its body, with
   the listed uses rewritten. `jig staging check` accepts the kind only with that destination.
   `drop` works as for any staged file. jig commits nothing in a pararepo.
6. Interpreted: a staged pin-bump doesn't block the pararepo's own `jig release`. The release
   names it instead, as RULES.md already says a newer metarepo release "refuses nothing" there.
   The pin stays the pararepo's buffer.
7. RULES.md: Staging gains the kind and how it resolves. The pin-bump paragraph (1332-1336) says
   the release stages the request. `defer_until` is documented as a date. hubnode step 5: in a
   pararepo, a staged pin-bump becomes a job; in a metarepo, report the release's per-pararepo
   lines to the owner. The stage skill covers resolving `pin-bump`.

**Where rig and versioning meet.** Versioning's code is the release, `jig sync`'s report and
staging's resolve; rig's is the picture, the merge and `--close`. They share no function. They
meet in five places, and one design holds both in each:

- **A staged pin-bump in rig's picture.** Rig lists it as any staged file (`kind: "staged"`): it
  is judged, and a ready one gets "write its spec?", which is versioning's landing (a job from
  `/jig:spec`). So hubnode step 5's "a staged pin-bump becomes a job" goes through rig's usual
  blocks. Interpreted: its touches read as today (`[]`, no `## Touches` in its body), like a
  staged request's (Out of scope, from bug-rig-batch-one-job); it meets other items only through
  `after:`.
- **Taken, and a request rewritten in place.** The pin-bump's mark carries its release
  (`source: <meta> release <tag> / <date>`), and rig's Part C matches the exact mark. While its
  spec waits or its job is open, it is `taken`. A later metarepo release rewrites the file, so the
  mark changes and it is a staged item again, judged afresh. Interpreted: no special case. The
  rewritten request covers the whole gap from the pin, and its spec covers what the open job's
  doesn't.
- **After the pin-bump job merges.** `close_specs` drops each staged file its closed spec carries
  (Where they meet). The merge moved the pin, so `resolve` would accept the request too; the drop
  prints `dropped <file>: built by <spec>` as for any carried file. A request rewritten during the
  job carries a newer mark, isn't dropped, and `resolve` still refuses it until the pin reaches
  its release.
- **The same text, edited for both.** `AGENTS.md`'s release line: versioning changes its flags
  (`--feature` or `--patch`), and rig drops its release-time archiving sentence. RULES.md's
  Commands block: `jig release`'s flags, and `jig rig`'s `--close`. RULES.md's Staging section:
  the `pin-bump` kind and how it resolves; that a merge or `jig rig --close` drops a staged file
  a closed spec carries; and its `jig rig` sentence (rig "lists every staged file") saying a
  taken file waits on its spec and, in the jig repo, feedback goes to `/jig:fix`. The hubnode
  skill: Merging (rig's archiving), step 5 and the release step (versioning's). `tests/smoke.sh`'s
  `staging` section takes both inputs' cases. `marketing/FEATURES.md` gains or changes the rows
  each names.
- **The release and staging.** A release refuses while anything is staged; versioning exempts a
  staged pin-bump in a pararepo. Rig changes nothing there: a `taken` file still blocks a
  release, as today.

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

From bug-versioning-pin-trigger:
In throwaway repos, with `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config` on every jig
command and `<dir>` beside the repos:
- [ ] `jig init` writes a log header that names MILESTONE.FEATURE.PATCH and Versioning, without
  "Semantic Versioning" or "released as a major version". RULES.md has `## Versioning` just
  before `## Release`.
- [ ] Plain repo at v0.3.0 with a `**Breaking:**` line under Unreleased: `jig release` tags
  v0.3.1, and `--feature` tags v0.4.0. `--milestone` exits non-zero naming `--version 1.0.0`, and
  tags nothing. `--version 1.0.0` then `--milestone` tags v2.0.0. `--major` and `--minor` behave
  as `--milestone` and `--feature`.
- [ ] **The reported symptom is gone.** Metarepo after v0.1.0, with only a page move and its
  `**Breaking:**` line merged: `jig release` with no flag tags v0.1.1 (v0.2.0 today), and no rule
  text tells the hubnode to pass `--major`. `grep` over RULES.md, `LOG_SEED` and
  `plugin/skills/**/SKILL.md` finds none of "means `--major`", "is a major release", "released as
  a major", "so it is a major", "Semantic Versioning", "follow SemVer".
- [ ] A pararepo pinned to v0.1.0 of a metarepo at v1.0.0, whose log has one `**Breaking:**`
  line: the pararepo's `jig sync` prints that line under "is out", and no "(a major release)".
- [ ] A log with the old header: `jig update` lists the header step, and `--apply` swaps exactly
  those two lines. The commit passes the hook, and in a metarepo so do the job commit and its
  merge. A log equal to the old seed still counts as the seed.
- [ ] **The trigger fires.** Metarepo `M` lists pararepos `A`, `B` and `C` (each `jig repos add`-ed,
  `init --para M --pin v0.1.0`). `A` cites `` `M/docs/products/x.md` `` in a doc, `B` cites
  `M/.jig/decisions.md § E-002` in a spec, and `C` uses a glossary word in source only. `M` merges
  a job that moves `x.md` (with its Breaking line) and supersedes E-002. Then `jig release` in `M`
  tags v0.1.1 and prints one line each: `A` staged (1 rewrite), `B` staged (1 superseded id),
  `C` cites nothing v0.1.1 broke.
- [ ] `A`'s request passes `jig staging check`, carries the Breaking line and the citation's new
  home, and `B`'s names E-002's successor. In every repo, `git rev-list --count HEAD` and the pin
  are unchanged.
- [ ] In `A`, `jig staging resolve pin-bump-M.md` refuses while trunk pins v0.1.0, naming the
  job. It resolves after a merge that moves the pin to v0.1.1. A second `M` release before then
  leaves one file, covering v0.1.0 → v0.1.2. `A`'s `jig release` with the request staged isn't
  refused, and names it.
- [ ] A pararepo with `defer_until` in the future gets no request, and its skip line says why.
- [ ] `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh` passes, with these
  cases in `release`, `metarepo`, `pararepo`, `decisions`, `staging` and `update`, and smoke.sh's
  1043-1045, 1725-1726 and 5226 moved to the new header and flags.

From the merge with versioning (Where rig and versioning meet):
- [ ] Smoke `rig` (or `pararepo`): in `A` after `M`'s release, `jig rig --json` lists
  `pin-bump-M.md` as `kind: "staged"`, `touches` `[]`. With a waiting spec carrying its mark it is
  `taken`. After a second `M` release rewrites it, it is no longer `taken` and its stored
  judgment is void.
- [ ] Smoke: in `A`, merging the job whose spec carries the request's mark and moves the pin
  drops `pin-bump-M.md`, printing `dropped pin-bump-M.md: built by <spec>`.
- [ ] `AGENTS.md`'s release line names `--feature` or `--patch` and holds no archiving sentence.
  RULES.md's Commands block shows both `jig release`'s new flags and `jig rig --close`. RULES.md's
  Staging section names `pin-bump`, the drop of a carried file at a merge or `--close`, and rig's
  `taken` and feedback items.

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

From bug-versioning-pin-trigger:
- Renumbering any release, and the level of Maige-Eco's next release: its hubnode proposes that.
- A check that judges a level. The hubnode proposes it, and the owner's word releases it.
- Holds set by the metarepo, and re-staging from a metarepo's trunk `jig sync` (General?).
- A `defer_until` that isn't a date, which holds forever by accident. It's a bug of its own:
  this spec compares the same way `sync_meta` does and leaves it.
- Rewriting a pararepo's citations. The job does that.
- Changes inside a cited section whose heading and path still resolve. The pararepo's sync
  report covers those.

## Touches
- `plugin/templates/jig/jig.py`: `RIG_KINDS`, `rig_items`, `rig_state` (state, counts,
  `feedback`, `taken`, groups' shared Touches and flag), `rig_text` (the group line, Running,
  Finished), `cmd_rig` (`--store-put`'s `fixing`, `--close`), rig's argparse, `cmd_merge`,
  `complete_specs` callers (`finished_specs`, `close_specs`), `roadmap_state`, `scope_cell`,
  `roadmap_rules`; `LOG_SEED`, `log_is_seed`, `outside_open_deleted`, update `STEPS`,
  `next_version`, release arguments, `newer_release`, `cmd_release`, `meta_citations`, `KINDS`,
  `read_staged`, `cmd_staging_check`, staging resolve, `staged_refusal` callers
- `plugin/templates/jig/RULES.md`: Documentation's `.jig/specs/` line, Roadmap (a note's
  `Scope:`), Merging, Workflow (the
  `jig rig` paragraph, the Feedback row), Decision log, Writing it, Metarepo and pararepos,
  Staging (the `pin-bump` kind, the carried-file drop, its `jig rig` sentence), new Versioning,
  Release, Commands (`jig release`'s flags, `jig rig --close`); Homes row: a rule, so RULES.md
- `plugin/skills/rig/SKILL.md`: § 1 (feedback), § 2 (count line, Waiting on you, Running,
  Finished), § 3 (blocks 3 and 5), § 4 ("Write a spec", one job, keep apart), the run's order
- `plugin/skills/spec/SKILL.md`: Consolidate (staged files as inputs, their marks kept)
- `plugin/skills/hubnode/SKILL.md`: Merging; Every session step 5; Release, push, publish
- `plugin/skills/fix/SKILL.md`
- `plugin/skills/release/SKILL.md`, `plugin/skills/redocument/SKILL.md`,
  `plugin/skills/stage/SKILL.md` (resolving `pin-bump`)
- `tests/smoke.sh`: `rig` (c7 rewritten), new sections `rig_batch` (parts A, B, C, the batch
  fixture, feedback) and `close` (merge-time closing, `finished` and `--close`), a staged pin-bump, `roadmap`, `merge_derived` or `workflow`, `release`,
  `metarepo`, `pararepo`, `decisions`, `staging`, `update`
- `AGENTS.md` (the release line: its flags, and the archiving sentence dropped)
- `marketing/FEATURES.md` (gitignored, in the main checkout): the `/jig:rig` row, a row for
  merge-time cleanup and `rig --close`, rows for both versioning parts

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

From bug-versioning-pin-trigger:
- Keep SemVer and pass `--patch` by hand — rejected because the header, RULES.md and /jig:release
  still say major, and the next hubnode proposes major again — [seen] (release skill 20-21).
- Apply the policy to metarepos only — rejected by the owner: "1. Agreed, adapt it to work for
  regular repos, meta, and para universally" — [seen] (quoted in the report).
- Request to every pararepo on every release ("why not update them on every version move of the
  meta?") — rejected because a pararepo the release didn't break has nothing to do, and the
  owner's later word ties the move to the Breaking line — [seen] (the Source line).
- Select by `changes_report`'s "used in" — rejected because a word grep matches nearly every
  pararepo on every term — [assumed] (the report's 37-40 hits, not rerun here).
- Select on any changed id or reworded term, as the report does — rejected because those don't
  break a citation, and the pararepo's own sync reports them — [assumed] (that the owner meant
  "broke", not "changed").
- Deliver through the inbox — rejected because a message is read and done with, and nothing
  tracks that the pin moved — [seen] (RULES.md Inbox).
- Commit the pin bump in the pararepo — rejected because the pin is the pararepo's buffer, and
  the rewrites are reviewed work — [seen] (RULES.md, Metarepo and pararepos).
- A `"versioning": "semver"` switch now — rejected because no jig repo publishes to a registry
  today — [seen, per the report: publish.sh steps].
- `meta.json` `holds` — rejected as one repo's policy, since jig's hold is `defer_until` — [seen].

From the merge with versioning:
- Keep a pin-bump `taken` across a rewrite, by matching its file name instead of its mark —
  rejected because `resolve` and Part C link a staged file to its spec by the exact mark, and the
  rewritten request covers releases the open job's spec doesn't — [seen] (`provenance` includes
  the `source:`, which names the release).

From the reviews of parts 1 and 2:
- A conflicted merge closes nothing and leaves it to `jig rig --close` — rejected because once
  the name is open again `--close` can't remove its `Bug-for:` spec, which then lifts the new
  job's strike limit — [seen] (review of d8b8fa8, B1's repro).
- Drop a carried staged file as soon as its spec is staged for removal — rejected because a
  refused commit or an aborted merge then loses an uncommitted file git can't bring back —
  [seen] (review of d8b8fa8, S1).
- Name the owed drops only, with no sweep — rejected because a drop nobody runs brings the file
  back as unjudged — [seen] (review of a12af04, B1's repro).
- Count only waiting specs and open jobs' specs as carriers — rejected because a spec a partial
  note names is neither, and its file was offered again — [seen] (review of a12af04, B2's repro).
- Keep the board in a feedback report's judgment key — rejected because opening any job would
  void `fixing` and rig would start a second `/jig:fix` on the same report — [assumed].

## Decisions
- The owner, 2026-11-18: "Three rig ones as one job".
- The owner, 2026-11-18: "Merge versioning with rig".

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
- Interpreted (review of part 2): a feedback report's judgment is keyed on the report alone,
  not the board, so a `fixing` report outlives a job opened; a report `/jig:fix` ends with still
  staged is stored `concluded` and waits on the owner, to drop or keep.
- Interpreted (review of part 2): a group's line counts in its K items each waiting spec
  outside the group that one of its pairs reaches ("one job for 2 items" for theta and gamma).
- Interpreted (review of a12af04): every spec in the tree carries its staged files, a partial
  one too; a file only a spec trunk's history closed carried waits on that closed spec, and
  `jig rig --close` drops it. Every path that stages a close without making its commit names
  the `jig staging drop` that commit owes.
- Interpreted (review of part 1): a staged file is dropped only when no spec left in the tree
  carries its mark (a request split into two specs is built when the last one closes), and only
  after the commit that closes its spec lands: staged files are never committed, so a refused
  commit or an aborted merge would otherwise lose them. A conflicted merge closes at `jig merge
  --number` and names the drops to make after `git commit`. `jig open` refuses a name whose
  earlier job's `Bug-for:` spec is still on trunk, naming `jig rig --close`.
- Interpreted: `/jig:fix` sessions are archived by the hubnode's no-job rule, not by rig's
  Finished step, which archives only sessions of jobs no longer on the board.
- Interpreted: rig starting `/jig:fix` is named in the `/jig:rig` FEATURES row, which
  rig-runs-fix's Touches left out.

From bug-versioning-pin-trigger:
- Interpreted, open to the owner at review: the flag names and their aliases; `--patch` as the
  default in every kind; `--milestone` refusing before 1.0.0; the header swap through `jig update`
  with the narrow R3 allowance; the selector's "broke", not "changed"; a pin-bump that doesn't
  block the pararepo's release; and the kind name `pin-bump`, one file per metarepo.

From the merge with versioning:
- Interpreted: a staged pin-bump is an ordinary staged item in rig, with no Touches read, as a
  staged request is; a ready one gets "write its spec?", which is versioning's landing.
- Interpreted: a pin-bump rewritten by a later release is a new item to rig (its mark changed),
  with no special case; its spec covers what the open job's doesn't.
- Interpreted: a carried pin-bump is dropped at its job's merge like any carried file, not
  resolved; both are open to it, since the merge moved the pin.

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
