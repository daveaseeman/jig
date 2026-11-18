# rig-runs-fix: `/jig:rig` in the jig repo starts `/jig:fix` on staged feedback

Source: the owner, jig hubnode session, 2026-11-18: "make `/jig:rig` in the jig repo also run `/jig:fix`(only in the jig repo)"

## Intent
In the jig repo, a `/jig:rig` run starts the Feedback workflow (`/jig:fix`) on every staged
feedback report no fix is already working on, and shows those reports under Running. It never
offers them as "write its spec?". In any other repo, rig behaves as it does now.

## Why (from the session)
- [seen] `rig_items` (jig.py ~13353) lists every staged file the same way, whatever its kind.
  A `kind: feedback` file in the jig repo is judged ready or open and offered as "write its
  spec?" (rig/SKILL.md, block 3). That's the wrong workflow: feedback is grouped and
  investigated by `/jig:fix`, one bug role per group, and its spec is the bug role's.
- [seen] Today the owner runs `/jig:fix` by hand. On 2026-11-18, three reports (Daisy,
  maige-ecosystem, jig) sat in staging until he did.
- [seen] RULES.md's Workflow table gives Feedback the trigger "staged feedback, in the jig
  repo", and `/jig:fix` refuses to run outside the jig repo.
- [seen] "The jig repo" is already one test in jig.py: `addressed_here("jig", root)`, the
  lookup staging uses to keep a `target: jig` report here rather than forward it.

## Design
1. `jig rig --json`, in the jig repo, gives each staged `kind: feedback` file addressed here
   `kind: "feedback"`, not `"staged"`. Feedback items join no group and no overlap, and don't
   count as can start now or as waiting on the owner. A new `feedback` count says how many
   wait. In any other repo, nothing changes.
2. **The rig skill:** before drawing the picture, if `jig rig --json` lists feedback whose
   `judged` is null, the hubnode starts `/jig:fix` on those reports: its grouping, then one bug
   role per group, as that skill says. Then it stores each report's judgment as
   `{"call": "fixing", "about": "<group>", "context": "<the session that took it>"}`. A report
   whose stored judgment is `fixing` is replayed and never started twice. It is listed under
   **Running** with its group and its session.
3. **No decision block.** Starting `/jig:fix` needs no owner answer, because `/jig:fix` doesn't
   wait for the owner between reports. Its drops and specs show as `/jig:fix` shows them. The
   specs it writes come back as waiting specs on the next run, through the usual blocks.
4. `/jig:rig auto` does the same.
5. RULES.md's Feedback row: the trigger reads "staged feedback, in the jig repo (`/jig:rig`
   starts it; `/jig:fix` by hand too)".

## Done when
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

## Out of scope
- What rig shows for a staged feedback file in a repo that isn't jig. Today `jig staging
  resolve` forwards it, and rig's handling there is unchanged.
- How `/jig:fix` groups, investigates and decides: unchanged.
- The rig batch grouping and the Finished part, which belong to the feedback specs
  `bug-rig-batch-one-job` and `bug-merged-job-cleanup`, still being written. The consolidate
  decides how they meet this one.

## Touches
- `plugin/templates/jig/jig.py` (`rig_items`, `rig_state`, `--json`'s counts)
- `plugin/skills/rig/SKILL.md`
- `plugin/skills/fix/SKILL.md`
- `plugin/templates/jig/RULES.md` (Workflow: the Feedback row)
- `tests/smoke.sh` (`rig`)

## Alternatives considered
- A decision block "run /jig:fix on these?" — rejected, because the owner asked rig to run it,
  and `/jig:fix` itself starts without asking — [seen].
- Rig reads a feedback report as a staged request and writes its spec — rejected, because
  feedback needs the bug role's investigation and General? test, and that is `/jig:fix`'s
  workflow — [seen] (RULES.md, Workflow: Feedback).
- Detect the jig repo by a `plugin/` folder — rejected, because staging already decides "this
  is jig" by `addressed_here`. One test keeps rig and staging from ever disagreeing — [seen].

## Decisions
- The owner, 2026-11-18: "make `/jig:rig` in the jig repo also run `/jig:fix`(only in the jig
  repo)".
- Interpreted: "run" means start: rig starts the grouping and the bug roles and doesn't wait for
  them. Their results come back through later runs.
- Interpreted: a stored `fixing` judgment is what keeps rig from starting a second fix on a
  report one is already working on.

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
