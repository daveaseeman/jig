# Bug: a merged job leaves its sessions open and its spec in `.jig/specs/`

Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make sure subnodes archive and their specs are removed when jobs are done and merged"
Source: jig hubnode session / 2026-11-18 / Dave (staged as feedback-jig-2026-11-18-merged-job-cleanup.md): "make jig:rig also close finished specs and subnodes"

## Intent
A merged job leaves nothing behind. Its sessions are archived at the merge. Its spec and its
bug specs leave `.jig/specs/` in the merge commit. Their roadmap scopes move into the handoff
note, so a done scope still reads done. `/jig:rig` closes whatever a merge left: specs a
hand-finished merge or older jig left behind, and sessions still working at the merge.

## 1. Why
1. Why are merged jobs' sessions open and their specs still in the tree? `jig merge` removes
   the entry, worktree and branch, then stops. Neither it nor the hubnode skill mentions either. [seen]
2. Why didn't merge remove the spec? The roadmap reads a scope's state only from specs in the
   tree, so removing one makes a done scope read "open". [seen, reproduced]
3. Why are sessions never closed? Only the host can archive a session. The one rule about it is
   in this repo's own AGENTS.md, and it waits for a release. [seen]

## 2. Givens
- [seen] `cmd_merge` (jig.py ~1886) deletes the entry, numbers ids, edits the roadmap and
  `ROADMAP.md`, and commits. `clean_up_job` removes the worktree and branch and prints
  "removed <job>'s worktree and branch <branch>". Nothing touches `.jig/specs/`.
- [seen] `plugin/skills/hubnode/SKILL.md` has no archive line. `grep -rni archiv plugin/skills
  plugin/templates` finds only redocument's "session archive", which is unrelated.
- [seen] `AGENTS.md:24`: the hubnode archives "the subnode sessions it started whose jobs have
  merged" after a release, in this repo only.
- [seen] Linked sessions here: rigger, bug-gate-pair-answers, bug-meta-agents-block,
  bug-decision-records, bug-process-in-pages and check-queue sit idle after their merges.
- [seen] 115 files in `.jig/specs/`, 117 notes. 95 specs are named by a note's `Spec:` line.
- [seen] `roadmap_state` (~9601) builds `takes` only from `snap.ls(SPECS)`, and
  `complete_specs` (~9586) marks done from landed, non-partial notes. Reproduced in a scratch
  repo with the plugin copy: `alpha/screen` read `done` with its spec. After `git rm` of the
  spec it read `open`.
- [seen] `roadmap_rules` (~10037): a roadmap commit that drops a scope is refused while a spec in
  the tree takes it ("re-point its Scope: line in this commit"). This is the only way to re-point
  done work today.
- [seen] `roadmap_items` (~2588) and rig's next step (`rig_next_step`, ~13401) read
  `roadmap_state`. A done scope that turned "open" would be offered again as the next step.
- [seen] `waiting_specs` (~1278) skips a spec any note names, a `Bug-for` spec, and one the
  newest release holds. A merged spec is never waiting, so removing it changes no rig item.
- [seen] `built_after` and `kept_separate` resolve names only among waiting items and open jobs'
  specs (`rig_state` `by_name`, `job_of`). A removed spec named in `Build after` is satisfied,
  as it is now.
- [seen] `review_shortfall` (gate, ~3030) reads the job's spec from trunk at gate time, before
  any merge. P2 in a merge commit reads the job's spec with `at_rev(trunk, …)`, the commit before
  the merge (~7633), so a `git rm` in the merge commit hides no `meta:` answer.
  `trunk_answers` and `contract_removals` read specs at historical commits (~8545).
- [seen] `bug_spec_for` (~2370) finds a `Bug-for: <job>` spec on any rev's `.jig/specs/`. Two
  stale ones sit on trunk now: `Bug-for: rig` and `Bug-for: bug-process-in-pages`, both jobs
  merged. A new job reusing either name would have its strike refusal lifted by the old spec.
- [seen] One spec can have several notes: `decision-log.md` has two `Partial: yes` notes and a
  later full one from another job. `jig open` doesn't refuse a spec an open job already names
  (~1120–1180). So "named by no open job" is a real condition, not a hypothetical.
- [seen] Older spec-only jobs (update-spec, para-spec) wrote non-partial notes naming a spec that
  a later job built. `complete_specs` already counts those as done. Today's spec and bug skills
  write specs in a detached worktree and commit nothing: the hubnode commits them on trunk
  (`spec/SKILL.md:10`, `:79`).
- [seen] `.jig/decisions.md` names no spec path. Other specs cite merged specs by path as
  evidence (e.g. `page-form-enforced.md`), and git history keeps those paths readable.
- [seen] `ROADMAP.md`'s `scope_cell` links each spec by path. A removed spec's link would be
  dead.
- [seen] `rig/SKILL.md`'s picture has five parts, and its actions write specs and open jobs.
  Nothing removes or archives. `cmd_rig` writes only the store.
- [assumed] A metarepo pointer never names a spec. If one did, P2 would refuse the commit that
  removes it. The design skips such a spec, so this need not be converted.
- [assumed] The Claude app lets the starting session archive the sessions it started
  (`archive_session`). Other hosts may not. The skill text says "with the host's tool, where it
  has one".

## 3. One layer up
- The sibling is the worktree and branch. `jig merge` removes them in the same run when they're
  clean, and keeps and names them when they aren't. Specs and sessions follow the same rule:
  removed at the merge, unless something still holds them (an open job naming the spec, a
  session still working).
- The handoff note is the record that stays, and it already decides completion. It can also hold
  the scopes. The roadmap hook already makes re-pointing a commit-time edit, so it can name notes
  as it names specs.
- One rule for "finished", used by both the merge and rig, so they never disagree:
  `complete_specs` plus no open job naming the spec, plus `Bug-for` specs whose job is gone.

## 4. Workaround or correction
Correction. The merge gets the cleanup step it lacks. The roadmap gets a source for scopes that
outlives the spec. Rig sweeps what the merge couldn't reach.

## General?
Yes. Any repo with parallel jobs piles up finished specs in a folder RULES.md reserves for "a
task in flight". A reused job name inherits a stale `Bug-for` spec's strike lift. Sessions pile
up under the hubnode. Nobody has to work against jig to hit any of these: ordinary merges cause
them.

## Design

**Finished specs, one rule** (jig.py). `finished_specs(snap, board, job=None)` returns each spec
in the tree that is either:
- complete (`complete_specs`) and named by no open job's `spec`; or
- a `Bug-for: <job>` spec whose job isn't on the board. A bug spec reaches trunk only with its
  job's merge (RULES.md, The board).

Each result carries the newest landed, non-partial note that completed it (none for a bug spec).
With `job`, the list holds only that job's: specs its notes name, plus `Bug-for: <job>`.
A spec a cached metarepo pointer names is left out, and the step prints why.

**Close step.** `close_specs(list)` stages two changes:
- For each spec with a `Scope:` line, a `Scope: …` line right after the `Spec:` line of its
  completing note, unless the note already has one.
- A `git rm` of each spec.

It reads the spec's `Scope:` as trunk holds it at close time, so a scope re-pointed on trunk
after the handoff is carried right. That is why `jig handoff` doesn't write it.

**At the merge.** On a clean merge, after the entry is deleted and before the roadmap view is
written, `cmd_merge` runs `close_specs(finished_specs(index, board, name))` and prints
`closed <spec>` for each. The roadmap view in that same commit then reads the note's scopes.
A conflicted merge closes nothing, as it numbers nothing, and rig sweeps it later. After the
removal line, `jig merge` prints one tool-neutral line: `close the sessions that worked on
<job>`.

**The roadmap.**
- `roadmap_state` takes a scope from a spec in the tree, or from a landed, non-partial note's
  `Scope:` line, keyed by the note's `Spec:` path. A spec still in the tree wins over its note.
  A note's scopes are done.
- `scope_cell` links a closed spec's stem to its note.
- `roadmap_rules` treats a note's `Scope:` line as it treats a spec's. A dropped scope that a note
  still takes is refused with "re-point the Scope: line in <note> in this commit". A note
  committed with a scope the roadmap lacks is refused too.

**Rig.**
- `jig rig --json` gains `finished`: `finished_specs` over trunk, each with its note.
- `jig rig --close` is refused off trunk, outside the trunk checkout, or on a dirty tree, and
  writes nothing then. Otherwise it runs `close_specs` on that list, rewrites `ROADMAP.md` when
  the repo has a roadmap, and commits once: `close finished specs: <stems>`. It prints each one.
- Rig's text picture names the finished specs.

**Skills and rules.**
- hubnode `Merging`: after `jig merge`, archive every session you started for that job (work,
  review, check, bug), with the host's tool where it has one, unless one is still working. A
  session that served no job (a batch check, a consolidate, a feedback group's bug or spec) is
  archived once its report is read and acted on. Name each archived session in the report to the
  owner. A session still working stays, and you say why.
- rig: a sixth part of the picture, **Finished**. On every run (and `auto`), after drawing the
  picture and before the decisions, run `jig rig --close`, archive the sessions this hubnode
  started for jobs no longer on the board (same exception), and list both under Finished. Keep
  to that part. The batch-grouping spec owns the blocks and the grouping.
- RULES.md: `.jig/specs/` holds a task in flight. The merge removes a job's spec and its bug
  specs, and the note keeps their scopes. `jig rig --close` removes the rest. A job's sessions
  end at its merge. The command list gains `jig rig --close`.
- `AGENTS.md` (this repo): drop the release-time archiving sentence.
- `marketing/FEATURES.md`: a row for merge-time cleanup and `rig --close`, added before the code.

## Done when
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

## Out of scope
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

## Alternatives considered
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

## Touches
- `plugin/templates/jig/jig.py` (`cmd_merge`, `complete_specs` callers, `roadmap_state`,
  `scope_cell`, `roadmap_rules`, `cmd_rig`, rig's argparse and text picture)
- `plugin/templates/jig/RULES.md` (Documentation's `.jig/specs/` line, Merging, `jig rig`,
  command list)
- `plugin/skills/hubnode/SKILL.md` (Merging)
- `plugin/skills/rig/SKILL.md` (the picture's Finished part, the run's close step)
- `tests/smoke.sh` (`roadmap`, `merge_derived` or `workflow`, `rig`)
- `AGENTS.md`
- `marketing/FEATURES.md`

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
