# Nodes, roles and workflows: who does each step, in what order, in which session

Source: the owner, jig hubnode session, 2026-11-14 to 2026-11-15: "what we really need is a list of roles and a list of workflows that use those roles, not just one list"; "flows need to be pulled from the skills, skills should define the roles and the flows should be more programmatic/contractual - not relying on judgement but triggers and things we can guarantee."
Source: the owner, 2026-11-11 (staged as feedback-adventure-studio-2026-11-11-sync-log-and-names.md): "`sync` does two unrelated jobs; other names do too". Folded in from `rename-check-rules`, written then and never built.

## Intent
Every session is a node: the hubnode (the owner's session) or a subnode. A subnode takes one of
five roles: spec, bug, work, review or check. Each node and each role is one skill, and each role
has its own model tier and effort. Workflows are data in `jig.py`, not prose in skills: `jig next`
names the next step, the role that does it, and whether it continues a session or starts one,
and each recording command refuses a step taken out of order. A new session starts only where a
role needs a fresh context or different settings.

## The design (this table goes in README.md)

**Nodes.** One skill each. The SessionStart hook loads the right one.

| Node | Settings | What it does | Roles it may load |
|---|---|---|---|
| hubnode | the owner's session; jig warns below 2,1 | talks, decides, assigns, gates, merges, pushes, publishes | spec (only for specs drafted from the conversation) |
| subnode | the role's | takes one role on one job, works only in its worktree, reports back, never touches trunk | any of the five |

**Roles.** One skill each, loaded when assigned.

| Role | Tier, effort | Default model | Steps it owns |
|---|---|---|---|
| spec | 2, 2 | Opus at high | spec, consolidate |
| bug | 2, 1 | Opus at xhigh | bug, then the spec for what it found |
| work | 2, 3 | Opus at medium | work, handoff, fixes, hand-resolved syncs |
| review | 2, 2 | Opus at high | review-work (the job's whole diff), review-change (only what changed since the last review); always a fresh session |
| check | 3, 4 | Sonnet at low | check (the complete suite), trace a failed batch, survey, release run |

The hubnode's own steps, which are no role's: assign, gate, merge, push, publish. jig itself
(no model): refuses a step out of order, removes a merged job's clean worktree and branch.

**Workflows.** `→` continues the same session; `⇢` starts a new one.

| Workflow | Steps | Trigger | Controls |
|---|---|---|---|
| Job | spec ⇢ work ⇢ review-work → handoff → gate ⇢ check → merge | `jig open` | merge only on the owner's word |
| Fix | work ⇢ review-change → handoff | a review with blocking findings | three rounds at most; a fourth is refused and Bug runs |
| Sync | work ⇢ review-change → handoff | a sync with a hand-resolved conflict | a clean sync needs nothing |
| Bug | bug → spec ⇢ Job | a fourth fix round, a feedback group, or the owner's `/jig:bug` | never on a session's own reading that something is broken |
| Feedback | consolidate ⇢ bug + spec (one per group) → consolidate ⇢ Job | staged feedback, in the jig repo | overlaps answered before any job opens |
| Batch | gate → merge ⇢ check → trace | two or more gated jobs | one check on trunk; a failure is traced to its merge, then Fix on that job |
| Release | check → release run → push → publish | the owner's word | refused while a batch check is owed; push and publish only on the owner's word |
| Survey | survey ⇢ spec ⇢ Jobs | `/jig:survey`, `/jig:adopt`, `/jig:update` | |
| Redocument | spec ⇢ Jobs ⇢ Batch ⇢ Job | `/jig:redocument` | the spec is the remap; the last job is the cleanup |

**Fixed, whatever the config says:** the owner's word before merge, push and publish; a fresh
session for every review; a complete check before a release. Everything else the hubnode may
propose to reconfigure, with a reason, and apply only on the owner's yes; on a no it continues
with the defaults.

**Session rules.**
1. A session never changes model or effort once it holds context: a model change discards its
   cache, and the next turn re-reads everything at full price.
2. One session per role per job. The work session keeps the build through every fix and sync.
3. A new session starts only when the role changes and the new role needs a fresh context
   (review), different settings, or nothing but files (check).

## Done when

### Part 1: jig.py and tests (its own handoff, `--partial`)
- [ ] `ROLES` and `FLOWS` in `jig.py` hold the tables above as data, tool-agnostic: tiers and
      efforts, never a model name. `WORKFLOW_DEFAULTS` is gone.
- [ ] `jig roles` prints each role's tier and effort in effect; `jig flows` prints each
      workflow's steps with their roles and `→`/`⇢` marks. `jig workflow` stays as an alias that
      prints both, so old skill text keeps working until `/jig:update`.
- [ ] `.jig/config.json`'s override key is `roles`, and each entry needs a `reason`. The commit
      hook refuses an override without one, and refuses any that weakens a fixed rule. An old
      `workflow` key is read, mapped (execute → work, recheck → review, review → review) and
      listed by `jig update`, whose `--apply` rewrites it. Smoke covers each.
- [ ] `jig next [<job>]` prints the job's next step, the node or role that does it, and
      `continue <session>` or `new session`. It reads only records jig already keeps (board
      state, review and check records, handoff notes). Smoke walks one job through Job and one
      Fix round, and checks each line.
- [ ] Contracts, each a refusal naming the missing step, each with a smoke case:
      - `jig merge J` refuses a job not marked gated (closes the checks-and-briefs DEFERRED row).
      - `jig reviewed` takes `--blocking N`; `jig handoff` refuses while the newest review of
        HEAD has blocking findings.
      - after three rounds whose reviews recorded blocking findings, a fourth `jig reviewed
        --change` is refused until a bug spec for the job is committed (`Bug-for: <job>` in it).
- [ ] Renames, each with its old name refused or mapped as stated, and smoke updated:
      - `jig check` → `jig rules` (the 2026-11-11 decision); the hooks call `jig rules`.
      - the `recheck` step → `review-change`; `jig reviewed --recheck` → `--change`; the note's
        `Recheck:` line → `Review-change:`. Old notes' lines still read.
      - `jig gate`'s review-shortfall reads an old spec's `## Workflow` (`execute:`, `review:`,
        `recheck:`) and a new spec's `## Roles` alike.
- [ ] The spec template's `## Workflow` section becomes `## Roles`, filled from `jig roles`.

### Part 2: skills, rules and README (second handoff)
- [ ] Seven skills define the nodes and roles: `hubnode`, `subnode`, `spec`, `bug`, `work`,
      `review`, `check`. Each says its settings come from `jig roles`, which steps it owns, and
      that `jig next` decides what comes after. No skill holds a workflow's order.
- [ ] The plugin's SessionStart hook loads the node skill only: hubnode on trunk, subnode in a job
      worktree. Role skills load on assignment.
- [ ] `bug`'s description fires only when a workflow or the owner calls it; nothing in it says to
      run when something looks broken. `grep -n "reports something broken" plugin/skills` is empty.
- [ ] Every row of the inventory below is carried out as its Resolution says, and the job's note
      lists each row with the commit that did it.
- [ ] README.md gains a section, "Who does what", drawn the way the owner approved in the hubnode
      chat on 2026-11-15, as an image above the text tables:
      - **Roles:** one card per node and role, in a responsive grid. Each card has the name, its
        tier and effort and where it runs (`2,2 · fresh session`), and the steps it owns. The
        last card, "jig itself", has a dashed outline: no model, it refuses steps out of order
        and cleans up.
      - **Workflows:** one row per workflow. The name sits on the left, then its steps as small
        rounded pills, each colored by the role that owns it. A plain `→` continues the same
        session; a red `⇢` starts a new one. A subscript letter names the session (`work W`,
        `review-work R1`), and a nested workflow is an outlined pill (`Job`). Under each row, one
        muted line holds its trigger and controls.
      - **Style:** flat, no shadows or gradients; sentence case; 0.5px hairlines; two type sizes.
        One color per role, the same in both drawings: hubnode yellow, spec violet, bug red,
        work green, review magenta, check blue. A one-line legend explains `→` and `⇢`.
      - **Light and dark:** two SVGs, `assets/roles-and-flows-light.svg` and `-dark.svg`, shown
        through `<picture>` with `prefers-color-scheme`, so GitHub shows the one matching the
        reader's theme. Alt text summarizes the tables.
      - **No drift:** a script in this repo (`scripts/roles_svg.py`, not in `plugin/`) draws both
        SVGs from `ROLES` and `FLOWS` in `jig.py`, and `.jig/scripts/check.sh` fails when the
        committed SVGs differ from what it draws. Smoke: change a role's effort in a scratch copy
        and the check fails, naming the SVG.
      - **Text as well:** the same three tables follow the image as Markdown, inside
        `<details>`, for search, screen readers and copying.
- [ ] After its merge commit, `jig merge` removes the job's worktree when `git status` there is
      clean, then runs `git branch -d`; otherwise it names what's left and removes nothing (the
      owner, 2026-11-15: "Build it in Part 2"). Smoke covers both, and the cases that read a
      job's branch after its merge are updated. The hubnode skill's after-merge step matches.
- [ ] RULES.md § Workflow states the tables and the session rules with the contracts, as text.
      Neither it nor the README names Claude, Opus, Sonnet or a session tool: tiers and efforts
      only, with `plugin/tiers.json` named as where they map.
- [ ] Both parts: `.jig/scripts/check.sh` exits 0, the sections each part touches pass, and the
      full suite runs once at the gate. `claude plugin validate ./plugin` passes, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` is empty.

## Inventory (proposed; the job confirms each row, and changes one only by asking the owner)

**Skills (19 today, 7 node and role skills after).**

| Skill | Today | Resolution |
|---|---|---|
| hubnode | the hubnode, plus its own job cycle and briefs | node skill; keeps assign, gate, merge, push, publish; its job cycle and the order of steps move to `FLOWS`; briefs move to each role skill |
| subnode | the job session: check in, build, hand off, sync | node skill: check in, take one role, report back; build, hand off and sync move to `work` |
| spec | writes a spec | role skill `spec`; absorbs `consolidate`, and redocument's remap and adopt's plan |
| bug | investigation | role skill `bug`; ends with its spec; trigger narrowed |
| review | review dispatch and record | role skill `review`: review-work and review-change |
| (new) check | spread over the gate brief, `release`, `verify` | role skill `check`: complete suite, `jig checked`, trace, survey run, release run |
| (new) work | in `subnode` | role skill `work`: build, evidence (absorbs `verify`), handoff, fixes, syncs |
| consolidate | writes a merged spec | merged into `spec` |
| verify | how to prove a change works | merged into `work` |
| feedback | `/jig:bug` aimed at jig, staged as a report | stays the owner's command; a wrapper that loads `bug` and stages the result |
| fix | the Feedback workflow, in prose | entry point: starts Feedback; its grouping step is `spec`'s consolidate |
| release | the release protocol | entry point: starts Release; the run is `check`'s |
| redocument | remap, jobs, cleanup | entry point: starts Redocument; the remap is `spec`'s |
| adopt | survey, plan, stages | entry point: starts Survey; the plan is `spec`'s |
| update | dry run, apply | entry point: starts Survey for what it finds; the apply is `work`'s |
| survey | read-only inventory | standalone tool; also the check role's survey step |
| stage | stage or resolve a file | standalone tool |
| retro | turn a repeat into a skill, triage ledgers | standalone tool |
| hardware | a board's page | standalone tool; the page is `spec`'s |
| repos | the repos list | standalone tool |
| init | set up a repo | standalone tool |

**Commands (27 today).**

| Command | Who runs it | Records or serves |
|---|---|---|
| init, install-hooks, update, repos | owner or hubnode | setup |
| status | anyone | the board |
| open, consolidate, share, reserve, mark | hubnode | Job start, consolidate, the board |
| next (new), roles (new), flows (new), workflow (alias) | anyone | the tables |
| reviewed | review | review-work, review-change |
| handoff | work | handoff |
| gate | hubnode | gate |
| checked | check | check |
| merge | hubnode | merge, then removes a clean worktree and branch |
| sync | work, hubnode | Sync |
| release | check (run), hubnode (tag on the owner's word) | Release |
| check → rules | the hooks, anyone | the rules |
| job, decision, roadmap, reading-list, survey, staging | anyone | lookups and staging |
| propose | hubnode | pararepo proposals |
| hook | the git hooks | internal |

## Out of scope
- `every-copy`: held by the owner.
- A machine-wide lock, cloud sessions, `jig wait`: not now.
- jig starting sessions: the hubnode still does, from `jig next`'s output.

## Touches
- `plugin/templates/jig/jig.py`, `plugin/templates/jig/RULES.md`, `plugin/templates/specs/_template.md`
- `plugin/skills/**` (every skill in the inventory), `plugin/hooks/hooks.json`, `plugin/scripts/session-start.sh`
- `plugin/templates/AGENTS.md`, this repo's `AGENTS.md`, `README.md`
- new: `assets/roles-and-flows-light.svg`, `assets/roles-and-flows-dark.svg`, `scripts/roles_svg.py`;
  this repo's `.jig/scripts/check.sh` gains the freshness check (the owner's file to edit, on his
  word, as `.jig/` changes otherwise only by `/jig:update`)
- `tests/smoke.sh`

## Alternatives considered
- Keep one steps table and fix the names (`rereview`) — rejected by the owner: steps without
  roles and workflows hid where a step falls and which session runs it — [seen]: "recheck"
  listed before the first check, and bug picking up a trigger outside any flow.
- A supporter role for mechanical steps — rejected: each of its chores was a jig command or
  already held by a session with the context (the checker traces its own failure) — [seen] in
  the session-boundary pass, 2026-11-15.
- A drafter session for every spec — rejected for specs drafted from the owner's conversation,
  whose decisions live in the hubnode; kept for specs from files — [assumed].
- Role skills named for the role (`drafter`, `solver`, `worker`) — rejected by the owner: the
  step names (`spec`, `bug`, `work`, `review`, `check`) are what he types.
- One job without parts — rejected because a diff this size gets a shallow review; two
  `--partial` handoffs, each fully reviewed, keep one job and one gate — [assumed].

## Decisions
- Calls the owner made, 2026-11-14 to 15: two nodes and five roles; role skills named spec, bug,
  work, review, check; the hubnode may reconfigure only with a reason and on his word; bug
  runs only when a workflow or he calls it; the tables go in the README; the inventory is
  part of this spec.
- Interpreted: `review-change` uses the review role's settings (2, 2); the 2, 1 default the owner
  first listed for it predates roles.
- Interpreted: bug's narrower trigger lives in its description, not in a flag that blocks a
  model from loading it, since the hubnode and subnodes load it by name when a workflow calls it.
- Interpreted: `jig workflow` survives as an alias for one release, so repos on older skills
  keep working until `/jig:update`.
- Interpreted: the README's drawing is a generated SVG pair, because GitHub's Markdown strips the
  styling the chat's pills and cards use; drawing it from `ROLES` and `FLOWS` keeps it from
  stating the tables a second time by hand.
- Interpreted (hubnode, 2026-11-15): `→` continues a session that already exists (the work
  session, the hubnode, the check session), named by its letter; `⇢` starts a new one. Read
  literally as "the same session", handoff would run in the review session.
- Interpreted (hubnode, 2026-11-15): `jig check` stays as an alias of `jig rules`, and
  `jig reviewed --recheck` as a hidden alias of `--change`, for one release like `jig workflow`;
  old `recheck` review records read as review-change.
- Interpreted (hubnode, 2026-11-15): the smoke's `gated <job>` helper sets a job's state on trunk
  in place of gate, check and mark, since about 80 smoke merges never gated their job; the `next`
  section walks the real gate → check → mark path.
- Interpreted (hubnode, 2026-11-15): an old `workflow.recheck` override is dropped, not mapped
  onto review, replacing the literal "recheck → review" mapping above. Review-change runs at the
  review role's settings, so a cheaper recheck mapped onto review would lower every full review;
  and `recheck` was never released. `jig update` lists the drop, and `jig roles` notes it on stderr.
- Consolidated: `rename-check-rules` (2026-11-11) is folded in, and its spec file is deleted in
  the commit that adds this one.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
