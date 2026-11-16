# update-adopts-standard: `jig update` puts every repo on jig's standard roles, workflows and board

Source: Maige-Lite hubnode session 25f7e824 / 2026-11-15 / Dave Seeman (staged as feedback-maige-lite-2026-11-15-update-replaces-workflow.md): "make sure that update checks jig config and completely replaces workflows with the new standard since some were accidentally reset"
Source: jig hubnode session / 2026-11-16 / Dave: "make sure update implements our new roles & flows system unilaterally - several repos have an alternative way of doing things that accidentally crept in. I can always customize within each repo again afterwards. Make sure update doesn't try to erase any custom skills in those repos, just that it fully adopts the new role and workflow system, which could require different adaptation per repo. Update shouldn't be built for our cases, but to generally work on all of the cases we have."
Source: Maige-Lite hubnode session 25f7e824 / 2026-11-13 / Dave Seeman (staged as feedback-maige-lite-2026-11-13-section-counter-outlives-redocument.md): after `/jig:redocument` finished, "`jig update` and `jig survey` listed one finding left: `.jig/config.json reserve.section: numbers page headings: drop it at /jig:redocument's cleanup, once no page holds a numbered heading`". "The cleanup had already run, two days before ... Nothing in jig removes the counter now."

Consolidated on 2026-11-16, on the owner's word ("One job"), from `bug-update-adopts-roles` and
`bug-section-counter`: both change `jig update`'s plan output and its board edits, so they build,
review and gate as one job. Part A's and Part B's Done-when items are all this job's.

## Part A: update adopts the roles and workflows standard (bug-update-adopts-roles)
### 1. Why
- Why does a repo whose `workflow` set every step to tier 1 still run tier 1 after `jig update`?
  `rewrite_board` maps `workflow` onto `roles` with the reason "carried over from `workflow` by
  jig update". In a scratch repo, `jig roles` printed tier 1 after `--apply`.
- Why does update carry it over? roles-and-flows read the key as the owner's choice under an old
  name ("read, mapped … rewrites it"), and `role_settings` accepts all four overrides on file.
- Why can't update keep the deliberate ones and drop the accidental ones? A `workflow` entry
  has no reason and no source, so nothing in a repo tells a one-run instruction from a choice.
  Root: jig's standard is the only safe state.

### 2. Givens
- [seen] Four registered repos have `workflow` in `.jig/config.json` on trunk: Maige-Lite (spec 1,2 ·
  bug 1,1 · execute 1,3 · review 1,1), Maige-Eco (spec 1,2 · bug 1,1 · execute 1,3 · review
  1,3), Maige-OS (bug effort 2 · review effort 3 · check effort 3), jig (review 2,2). Daisy,
  Maige-Familiar, Adventure-Studio and zenshape have none. No repo has `roles`.
- [seen] `role_settings`, from the plugin's `jig.py`, accepts all four overrides. Removing them
  changes the settings in effect in Maige-Lite, Maige-Eco and Maige-OS. jig's own
  override equals the standard, so removing it changes nothing.
- [seen] Every repo's installed `.jig/jig.py` predates roles (`WORKFLOW_DEFAULTS`). roles-and-flows
  is only on local main, 56 commits ahead of origin/main, and the installed plugin is 0.12.2,
  which has no mapping. So no repo has a `roles` entry the mapping wrote.
- [seen] Reproduction in a scratch repo, using Maige-Lite's installed `jig.py` and `RULES.md`, its
  `AGENTS.md`, its esp-idf skill and its override, with the plugin's `jig update`:
  - The dry run prints one line about the override: `Board: workflow: renamed roles
    (execute → work)`. It shows neither the old values nor the standard, and says nothing about
    AGENTS.md or the skill. It does list check.sh.
  - `--apply` writes four `roles` entries with the "carried over" reason, and `jig roles` prints
    `spec 1,2; bug 1,1; work 1,3; review 1,1`.
  - AGENTS.md is unchanged, "Roles: /jig:hubnode, /jig:subnode." included.
- [seen] Update edits only lines jig wrote in a repo file, and only in `.gitignore` ("A line the repo
  wrote itself is its own"). For AGENTS.md it proposes only missing lines (`agents_lines`), and
  the Rulebook line only when no line names `.jig/RULES.md`. Every surveyed AGENTS.md names it.
- [seen] Earlier AGENTS.md templates shipped 15 lines about how steps run that the current template
  has dropped: the `check:`, `derive:`, `Task bigger`, ``Run `check` ``, `A mergeable`,
  `Rulebook` and `Bug reported` variants in `git log -p plugin/templates/AGENTS.md`. Six of the
  eight repos still carry some of them word for word.
- [seen] Every repo's `check.sh` has one level (no `--full`), and update already lists that
  (`check_levels_review`). Daisy's complete suite, `pytest tests -q` ("about 7 minutes"), isn't
  in it. Its AGENTS.md `test:` line names that suite. zenshape, Maige-OS and Maige-Familiar run
  their whole test command on every stop.
- [seen] Repo skills on trunk: Maige-Lite `.claude/skills/esp-idf/` (and `.claude/skill-template/`),
  Maige-OS `.claude/skills/linux-vm/`. None runs a jig command or has a node, role or step name.
  linux-vm uses "the Linux gate" and "merged" for the product's own Linux gate. No repo tracks
  `.claude/commands/`, `.claude/agents/` or agent settings. The untracked local settings hold
  permissions only (Daisy's not read).
- [seen] Outside jig's own files, step commands, node and role skills, and tier or effort numbers
  appear only in AGENTS.md lines, comments in jig's script templates, Daisy's `docs/README.md`
  (which describes the handoff note), and the word "tier" in one Adventure-Studio tax memo. The
  procedures live in always-loaded instruction files, and a whole-tree word search would misfire.
- [seen] Project memory outside the repos carries step rules:
  - Maige-Lite: "Subnode model by judgement". It says "Don't follow the jig hubnode skill's
    raise-to-tier ritual".
  - Maige-Eco: "Fable tier means 5.2".
  - Daisy: "Merge on gate pass" and "jig gate is the hubnode's".
  - zenshape: "No auto full test runs".
  - jig: "Follow jig workflow", which names `jig workflow` and `execute`.

  The host loads a project's memory index into every session. This session shows it.
- [seen] As merged, RULES.md says "There is no per-task override: a task that needs other settings
  means the owner changes the config", and the hubnode skill says "a task that needs others is a
  config change". That is the route the report's override took (its why 2).
- [seen] M4: in a metarepo, every commit on trunk that isn't a merge is refused, except changes to
  jig's own files under `.jig/`. AGENTS.md isn't one of them. Maige-Eco is a metarepo.
- [seen] `plugin/tiers.json` maps tier 1 to `claude-fable-5-1`. Maige-Eco's memory records the
  owner's "Use Fable 5.2" (2026-11-10) and tier-1 sessions started on `claude-fable-5-2`. The
  report says the same.
- [seen] Many specs on trunk still carry old review lines: 19 in Maige-Eco at `review: tier 1,
  effort 1`. The old default review was 2,1 and the new one is 2,2.
- [seen] Open jobs on trunk: Maige-Lite 1, Maige-OS 1, Daisy 5, Adventure-Studio 2. Update refuses
  `--apply` in those repos until the jobs merge.
- [assumed] Some repo jig meets will have a skill that redefines a node, role or workflow. None of
  the eight does, so the detection rule below is untested on a real one.
- [assumed] `claude-fable-5-2` is a valid model id today. The memory and the report say so, but
  nothing here checked it against the host.

### 3. One layer up
- **Sibling: AGENTS.md lines.** Update replaces `jig.py` and `RULES.md` but never revisits jig's own
  lines in AGENTS.md. "Roles: /jig:hubnode, /jig:subnode." survives in six repos and names none
  of the five roles. Lines in a repo's own words that set a procedure are never listed. Maige-OS
  reviews every commit in the builder's session, and jig sets a lighter review per kind of diff.
- **Sibling: skill folders.** Update reads none. The procedure lives where a skill sits beside
  jig's.
- **Sibling: project memory.** It sits outside the repo, but it steers every session. After the
  reset, Maige-Lite's memory would still tell the hubnode to pick models by judgement.
- **The producer.** One-run instructions become standing config through "no per-task override →
  change the config". Under `roles` the same thing can happen again, now with a reason attached.
- **Patterns already there.** The retired board keys tuple (`lanes`, `log`, `payload`: update
  removes them). `RETIRED_BLOCKS`: AGENTS.md blocks jig cut, found by heading.
  `OLD_SKILL_TEMPLATE`: a file jig wrote, found by its hash. The `.gitignore` rewrite: only lines
  jig wrote. `jobs_moves`: a metarepo's edits listed as a job's. `COORDINATION`: the
  agent-instruction files and skill folders, named as data.

### 4. Workaround or correction
Correction. Update stops translating the old system and removes it. It replaces what jig itself
wrote, and lists what the repo wrote, each with the role or rule that owns that step now. The
producer changes too: a one-run instruction stays in that run.

### Survey (2026-11-16, read-only, trunk)

| Repo | Deviation | Class | What update does |
|---|---|---|---|
| Maige-Lite | `workflow`: spec 1,2 · bug 1,1 · execute 1,3 · review 1,1 | 1 | removes it, saying old and standard |
| Maige-Lite | AGENTS.md:20, 24, 26, 28, 33 retired template lines (derive, Run `check`, old handoff, Rulebook "Roles: /jig:hubnode, /jig:subnode.", Bug reported) | 2 | replaces each |
| Maige-Lite | AGENTS.md:18 retired `check:` line | 2 | lists it until check.sh reads `--full` |
| Maige-Lite | check.sh one level | 4 | lists (today's finding), naming the `test:` command |
| Maige-Lite | `.claude/skills/esp-idf/`, `.claude/skill-template/` | 5b | untouched, unlisted |
| Maige-Lite | memory "Subnode model by judgement" | 6 | the skill lists it |
| Maige-OS | `workflow`: bug effort 2 · review effort 3 · check effort 3 | 1 | removes |
| Maige-OS | AGENTS.md:26 Rulebook (retired); :20 `check:` (retired) | 2 | replaces 26; lists 20 until `--full` |
| Maige-OS | AGENTS.md:30 a review of every staged commit in the builder's session; :27 spec line; :36 bug on any report | 3 | lists: `/jig:review` (a fresh session, once per handoff), `/jig:spec`, `/jig:bug` |
| Maige-OS | check.sh one level (`cargo test --workspace` every stop) | 4 | lists |
| Maige-OS | `.claude/skills/linux-vm/` ("the Linux gate", `scripts/linux-gate.sh`) | 5b | untouched, unlisted |
| Maige-Eco | `workflow`: spec 1,2 · bug 1,1 · execute 1,3 · review 1,3 | 1 | removes (`.jig/` file: allowed on trunk under M4) |
| Maige-Eco | AGENTS.md:34 Rulebook, :10 `check:` (retired) | 2 | metarepo: listed as a job's (M4) |
| Maige-Eco | AGENTS.md:28, :31, :32 (names `/jig:spec`, `jig release`, `/jig:review` and `jig reviewed`) | 3 | lists |
| Maige-Eco | check.sh one level | 4 | lists |
| Maige-Eco | memory "Fable tier means 5.2" | 6 | the skill lists it |
| jig | `workflow`: review 2,2 (the standard) | 1 | removes; nothing changes in effect |
| jig | AGENTS.md:21 "lighter review: tier 2, effort 3" for docs-only diffs; :17, :20 | 3 | lists: settings come from `roles` only |
| jig | check.sh one level (smoke at the gate) | 4 | lists |
| jig | memory "Follow jig workflow" | 6 | the skill lists it |
| Maige-Familiar | AGENTS.md:24, 32, 37, 42 retired; :22 `check:` | 2 | replaces; lists 22 until `--full` |
| Maige-Familiar | check.sh one level | 4 | lists |
| Adventure-Studio | AGENTS.md:20, 24, 29 retired; :15 `check:` | 2 | replaces; lists 15 until `--full` |
| Adventure-Studio | check.sh one level | 4 | lists |
| zenshape | AGENTS.md:21 Rulebook; :13 `check:` | 2 | replaces 21; lists 13 until `--full` |
| zenshape | AGENTS.md:20 shortened handoff line; :26 bug on any report | 3 | lists |
| zenshape | check.sh one level (`npm test` every stop) | 4 | lists |
| zenshape | memory "No auto full test runs" | 6 | the skill lists it |
| Daisy | AGENTS.md:36 handoff in its own words; :40 Rulebook naming hubnode and subnode as "Roles"; :42 `jig merge` | 3 | lists |
| Daisy | check.sh one level; complete suite (pytest, 7 min) outside it | 4 | lists, naming the `test:` command |
| Daisy | memory "Merge on gate pass", "jig gate is the hubnode's" | 6 | the skill lists them |
| Daisy | `docs/README.md`:80, 84 describe `jig handoff` and `jig gate` | — | none: a docs page, not loaded as instructions |
| Maige-Lite, Maige-Eco, Maige-OS | specs on trunk with old `## Workflow` review lines | — | out of scope (below) |

### Classes

Each class is recognized from evidence in the repo: a key's name, a line's exact text, a command
or skill a line names, a skill's name or the commands it runs, or a script's text. None is
recognized from the repo's name.

| Class | Evidence | Update does |
|---|---|---|
| 1 `workflow` in config.json (the old system's key) | the key | **replaces**: `--apply` removes it. The dry run puts it under `Removed:` with the old values and the standard. There is no keep option. |
| 1b `roles` in config.json (the new system's key) | the key, each entry with a reason | keeps it: this is where the owner customizes afterwards |
| 2 jig's retired template lines in AGENTS.md | equal to a `RETIRED_LINES` entry, whitespace aside | **replaces** it with the current template line, as part of the plan. The `check:` line waits until check.sh reads `--full`. In a metarepo, the replacement is listed as a job's (M4). |
| 3 a procedure in the repo's own words | a line of an always-loaded instruction file that names a node or role skill (`/jig:hubnode`, `subnode`, `spec`, `bug`, `work`, `review`, `check`), a command that records a step (`jig reviewed`, `handoff`, `gate`, `checked`, `mark`, `merge`, `release`), or a tier or effort number, and isn't jig's current or retired text | **lists** it with the role, node or rule that owns that step |
| 4 a one-level check.sh | the script never reads `--full` | **lists** it, as today, and names the repo's own `test:` command when AGENTS.md has one |
| 5a a repo skill that overlaps a node, role or step | in a skill folder (`COORDINATION`, plus `.claude/commands`, `.claude/agents`): its `name:` or folder is a node, role or step name taken from `ROLES`, `HUBNODE_STEPS` or `FLOWS`; or its body runs a step-recording command, loads a node or role skill, or sets a tier or effort | **lists** it with the standard skill that owns the step. Never edited, never deleted. |
| 5b any other repo skill | none of the above | untouched and unlisted |
| 6 project memory that sets models, who runs a step, or when to merge | the memory index the host loaded into the session | the update skill **lists** each entry, and the owner retires it on a yes. jig.py never reads memory. |
| 7 the producer | — | a one-run instruction applies to that run's sessions only. `roles` changes only when the owner says a setting is standing, and the commit quotes his words |

### Intent
After `jig update --apply`, every repo runs jig's standard roles and workflows. No `workflow`
override survives, and jig's retired template lines are replaced. Every other place that runs
steps another way is listed with what now owns that step: a procedure in the repo's own words,
an overlapping skill, a one-level check.sh, project memory. A custom skill is never edited or
deleted. A one-run model instruction no longer becomes a standing setting.

### Done when

#### The reset (jig.py; new smoke section `update_roles`)
- [ ] **Fixture A: an override like the reporter's.** The board has
      `"workflow": {"spec": {"tier": 1, "effort": 2}, "bug": {"tier": 1, "effort": 1}, "execute": {"tier": 1, "effort": 3}, "review": {"tier": 1, "effort": 1}}`.
      - The dry run prints one line under `Removed:`: `board: workflow`, with each old entry
        and jig's standard (`spec 2,2 · bug 2,1 · work 2,3 · review 2,2 · check 3,4`). No
        "renamed roles" line, and nothing about it under Repo files to review.
      - After `--apply` the board has neither `workflow` nor `roles`. `jig roles` prints exactly
        the five standard lines, and `jig workflow` prints `execute: tier 2, effort 3`.

      This is the report's symptom gone: the repo ends on the standard.
- [ ] **Fixture B: an override that looks deliberate.** `"workflow": {"review": {"tier": 2,
      "effort": 2}}`, committed with a message giving its reason, is removed exactly as in A.
- [ ] **Fixture C: no override.** Update says nothing about `workflow`, and `jig roles` prints the
      standard.
- [ ] **Fixture D: both keys.** A board with `workflow` and `roles`: `workflow` is removed and
      said. `roles` is the same after `--apply` (compared as parsed JSON), and `jig roles`
      prints it.
- [ ] **Fixture E: `roles` only.** Update says nothing about it, and `--apply` keeps it.
- [ ] **A `workflow` key under the new jig.py.**
      - `jig roles` ignores the key: it prints the standard, or `roles` when the board has
        one, and adds one stderr line saying update removes `workflow`.
      - The commit hook refuses any staged `config.json` holding `workflow`, naming `roles`.
- [ ] **The mapping is gone.**
      - `grep -nE "carried over from|RECHECK_DROPPED" plugin/templates/jig/jig.py` prints nothing.
      - `role_overrides` reads `roles` only.
      - `workflow` sits in update's retired keys tuple, not in `BOARD_OPTIONAL`, and no warning
        calls it an unknown key.

#### Instruction files (jig.py; `update_roles`)
- [ ] **The table.** `RETIRED_LINES` maps each retired line (the 15 in Givens; more are added in
      the same commit that cuts a template line) to the opening of the template line that
      replaced it. Update reads the replacement text from the template beside `jig.py`. Smoke
      asserts that each opening matches exactly one line of `plugin/templates/AGENTS.md`, and
      that no table key is a line of it.
- [ ] **Fixture F: retired lines.** The AGENTS.md holds these, verbatim except for doubled spaces
      in one, plus a line of the repo's own:
      - "Roles: /jig:hubnode, /jig:subnode." (the old Rulebook line);
      - "Run \`check\` yourself";
      - the old handoff line;
      - "Bug reported → /jig:bug".

      The dry run lists each in the plan with its replacement. `--apply` replaces each in place,
      and every other line stays byte-identical.
- [ ] **Per-repo evidence for `check:`.** In fixture F with a one-level check.sh, the retired
      `check:` line isn't replaced: it is listed beside the check.sh finding. Once check.sh reads
      `--full`, the line is replaced.
- [ ] **No duplicates.** A retired line whose replacement the file already holds is removed.
- [ ] **Pararepo and metarepo.**
      - In a pararepo, lines inside the generated `<!-- jig:meta -->` header are not read.
      - In a metarepo (`.jig/meta.json`), the replacements are listed as a job's (M4), and
        `--apply` leaves AGENTS.md unchanged.
- [ ] **Fixture G: procedures in the repo's own words.** The fixture has:
      - in AGENTS.md:
        - "Every commit: review the staged diff (/jig:review), then commit; record it with
          \`jig reviewed\`";
        - "Docs-only diffs get review at tier 2, effort 3";
        - a product line: "'hubnode', 'gate' and 'merge' in the owner's words mean the app's
          own";
      - in CLAUDE.md, a line naming \`jig handoff\`.

      Expected:
      - Under Repo files to review: the AGENTS.md review line, naming `/jig:review` (a fresh
        session, once per handoff); the tier line, naming `roles` in config.json (RULES.md
        § Workflow); and the CLAUDE.md line, naming `/jig:work`.
      - The product line is not listed.
      - After `--apply`, both files are byte-identical.

#### Skills (jig.py; `update_roles`)
- [ ] **Fixture H: custom skills survive untouched.** The fixture has:
      - `.claude/skills/review/SKILL.md` (`name: review`);
      - `.claude/skills/ship/SKILL.md`, which runs `jig reviewed` and `jig handoff`;
      - `.claude/commands/land.md`, which runs `jig merge`;
      - `.claude/skills/flash-board/SKILL.md`, which says "the flash gate" and "merged images"
        and runs `scripts/flash-gate.sh`;
      - `skills/notes/SKILL.md`, which does unrelated work.

      Expected:
      - The dry run lists review → `/jig:review`; ship → `/jig:review` (reviewed) and
        `/jig:work` (handoff); land → `/jig:hubnode` (merge).
      - It lists neither flash-board nor notes.
      - After `--apply` all five files are byte-identical, and
        `git status --porcelain -- .claude skills` is empty.
- [ ] Only the root skill folders are read. The jig repo's own `plugin/skills/` is never listed.

#### check.sh (jig.py; `check_levels`)
- [ ] With a one-level check.sh and an AGENTS.md line ``- test: `npm test` ``, the check.sh
      finding names `npm test` as the candidate for the `--full` part. With no `test:` line,
      the text is as today.

#### Skills, rules, plugin data
- [ ] The update skill says:
      - a `workflow` key is replaced with jig's standard in every repo, with no keep option and
        no exception. The old values and the standard are said out loud, and an owner who wants
        other settings sets `roles` afterwards, with a reason;
      - each listed procedure line and skill is shown with what owns it now. A custom skill is
        never edited or deleted, and nothing proposes deleting one;
      - after the dry run, the session reads its project memory index. Each entry that sets a
        model, tier or effort, says who runs a step or when to merge, or names `jig workflow`
        is listed with what owns it now, and retired only on the owner's yes.

      Check: `grep -nE "no keep|never edited or deleted|memory" plugin/skills/update/SKILL.md`
      hits each.
- [ ] The hubnode skill (Assigning a step) says that the owner's instruction about models for a
      run applies to that run's sessions only. `roles` changes only when the owner says a setting
      is standing, and the commit quotes his words as each entry's reason. Check:
      `grep -n "that run's sessions" plugin/skills/hubnode/SKILL.md`.
- [ ] RULES.md § Workflow, "Settings in effect":
      - `workflow` is not read: `jig update --apply` removes it, and jig's standard replaces
        what it held;
      - the "no per-task override" sentence says a one-run instruction stays in that run's
        sessions, and `roles` changes only on the owner's standing word.
- [ ] No repo names, no exception list:
      `grep -nE 'Maige|maige|Daisy|daisy|Adventure|adventure|zenshape|Zenshape|Walyt|walyt' plugin/templates/jig/jig.py plugin/skills/update/SKILL.md`
      prints nothing.
- [ ] `marketing/FEATURES.md`'s `update` row says this: what it replaces and what it lists. Its
      "what it is not" names "a judge of whether an override was deliberate" and "a remover of
      skills".

#### Evidence
- [ ] Every registered repo with `workflow` on its trunk gets a `git clone` in a scratch folder,
      with `JIG_CONFIG` and `XDG_CONFIG_HOME` pointed beside it. Nothing is written in the repo
      itself. In each clone, the plugin's dry run lists the removal, and a refusing dry run
      still prints its plan. In a clone with no open job, `--apply` leaves `jig roles` printing
      the standard. The handoff note shows the output.
- [ ] `.jig/scripts/check.sh` exits 0 and `claude plugin validate ./plugin` passes. The smoke
      sections `workflow update update_roles agents_lines check_levels` pass, and the full
      suite runs once at the gate.

### Out of scope
- **Recording answers.** The answers to listed lines and skills go unrecorded in `findings`, so
  a kept one is listed again at the next update. Give them ids later if the repetition costs.
- **Old specs.** Specs on trunk whose `## Workflow` review line is stronger than the standard
  stay as they are. `jig gate` warns when a review falls short of them, as RULES.md intends for
  "a config changed after the spec was written", and the owner gates as proposed. Maige-Eco
  has 19 such specs.
- **`jig checked`.** It can't tell that a one-level check.sh ran only its quick part under
  `--full`. Update lists the split. A warning there is a separate change.
- **Running update in the registered repos.** Each runs `/jig:update` itself, once its open jobs
  merge.
- **Docs pages.** Pages that describe jig's procedure, like Daisy's `docs/README.md`, aren't loaded
  as instructions. Survey's home findings cover rules files.

### Touches
- `plugin/templates/jig/jig.py`:
  - `role_overrides` and `settings_or_refuse` (~294–378);
  - the hook's config check (~544);
  - `BOARD_OPTIONAL` (~56) and the retired keys tuple (~9548);
  - `rewrite_board`'s pre-roles block (~9525);
  - `RETIRED_LINES` beside `RETIRED_BLOCKS` (~9699);
  - a procedure-line scan and a skill scan beside `agents_lines`, using `COORDINATION` (~4059);
  - `check_levels_review` (~1544);
  - `cmd_update`: its actions, plan, apply and report (~9999).
- `plugin/templates/jig/RULES.md` § Workflow (Settings in effect)
- `plugin/skills/update/SKILL.md`, `plugin/skills/hubnode/SKILL.md`
- `tests/smoke.sh`: the `workflow` section's pre-roles block (~1953–1978) is rewritten, and a new
  `update_roles` section and a `check_levels` case are added.
- `marketing/FEATURES.md`: the `update` row

### Alternatives considered
- **Keep the merged mapping** (`workflow` → `roles`, reason "carried over") — rejected because it
  carries forward exactly what the owner wants gone. The scratch repo's all-tier-1 override came
  out as four `roles` entries, and `jig roles` printed tier 1 — [seen].
- **Map only entries that match or beat the standard** — rejected because no rule tells a one-run
  instruction from a choice. A `workflow` entry carries no reason, and the report resets the
  deliberate ones too — [seen].
- **Ask per override in the dry run** — rejected because the owner said "unilaterally", and the
  report asks for "no per-repo answer that keeps one" — [seen].
- **Reset `roles` at every update too** — rejected because `roles` is where the owner customizes
  afterwards ("I can always customize within each repo again afterwards"). Each update would
  undo it — [seen].
- **Rewrite every AGENTS.md line that names a jig step to the template's** — rejected because those
  lines carry the repo's own rules too: Daisy's handoff line adds its decision-record rule —
  [seen].
- **Leave AGENTS.md to the session reading it against RULES.md** (today's skill text) — rejected
  because nothing flagged the stale Rulebook line in any of six repos, and the reproduction's
  dry run said nothing about AGENTS.md — [seen].
- **Replace the retired `check:` line everywhere** — rejected because its new text says
  `check.sh --full` adds the complete suite, which is false in all eight repos today — [seen].
- **Write `--full` into each check.sh from AGENTS.md's `test:` command** — rejected because only the
  repo knows which tests are quick. Three repos already run their whole test command on every
  stop — [seen].
- **Recognize skills and lines by words** (gate, merge, review, hubnode) — rejected because
  linux-vm's "the Linux gate" and Daisy's scope line ("hubnode", "gate" as the app's own) would
  read as jig's procedure — [seen].
- **Delete or rename an overlapping custom skill** — rejected because the owner said update
  shouldn't "erase any custom skills" — [seen].
- **A list of repo names or exceptions in jig.py** — rejected because "Update shouldn't be built
  for our cases" — [seen].
- **Read memory files in jig.py** — rejected because jig.py has no AI-tool dependency (AGENTS.md
  § Code) and memory sits outside the repo — [seen]. The skill sees the index the host already
  loaded — [seen in this session].
- **Fix only the hubnode skill** — rejected as the whole fix because four repos already carry
  overrides that only update reaches — [seen].

### Decisions
- **Reset over mapping**, per the owner (2026-11-16) and the report. This supersedes the
  roles-and-flows done-when "An old `workflow` key is read, mapped … and listed by `jig update`,
  whose `--apply` rewrites it". Its "recheck dropped" decision is moot, since every entry is
  dropped. `OLD_STEPS` stays only for the names the `jig workflow` alias prints.
- **`roles` is kept.** It is the new process's own override, and each entry carries its reason.
  With `roles` kept, the run-scoped rule below is what stops a one-run instruction from coming
  back as a standing setting.
- **Interpreted: run-scoped instructions.** This amends roles-and-flows' RULES.md sentence
  "There is no per-task override: a task that needs other settings means the owner changes the
  config". That sentence is how the report's override got written, and with `roles` kept it
  would happen again under the new key. The owner approved it, 2026-11-16: "Amend it".
- **Retired lines are replaced as part of the plan, not asked line by line.** Oct 28's "present
  edits and ask, never apply them automatically" still holds: the dry run presents each line
  with its replacement, and `--apply` is the yes. Lines in the repo's own words are listed,
  never edited. This draws the same line as `.gitignore`: jig rewrites only what jig wrote.
- **Per-repo adaptation comes from evidence.** The `check:` line waits for `--full`. A metarepo's
  AGENTS.md edits are a job's. A pararepo's generated header is skipped.
- **Each listed item names its owner**, through `step_owner`: reviewed → review, handoff → work,
  gate/mark/merge/release → hubnode, checked → check. A tier or effort points to `roles`.
- **The jig repo's own AGENTS.md is scanned for class 3**, since it is how this repo runs.
  `agents_lines`' exemption for the repo that ships the template stays for template proposals.
- **tiers.json stays as it is.** Tier 1 keeps mapping to `claude-fable-5-1`: the owner's call,
  2026-11-16 ("Keep fable-5-1").

## Part B: a counter over numbered page headings (Bug: a counter over numbered page headings outlives the redocument that should have dropped it)
The report's `jig_version` is c2af1224b3cc. The code read here is main at 4bc3171 (jig.py blob
9f4fee9). Its `contract_holders` is byte for byte the report version's, and `FINDING_KINDS` is
the same, so main still has the bug. Reproduced on main below.

### Intent
Every counter that jig lists as an old-contract holder has a way out that exists in the repo's
current state. If no `/jig:redocument` run is under way and no line matches the counter's
pattern, the `jig update` dry run lists the counter's removal and `--apply` removes it from
`reserve`. If a line still matches, the fix names that line and the condition for removal, not
a cleanup that may already be over. More generally, in a repo with no run under way, no holder's
fix waits on a redocument cleanup.

### 1. Why
1. Q: Why did Maige-Lite's counter survive its redocument?
   A: The remap seeds its holder rows from survey. The jig that ran it (b9d48e5fbf9e,
   13a476358699) had no counter check, which 76d83d9 added on 2026-11-12.
2. Q: Why doesn't a later update clear it?
   A: Update only lists a holder, with the fix "drop it at /jig:redocument's cleanup". With no old
   page left, redocument refuses to run, and a `counter` finding has no finding id.
3. Q: Why does the fix name a cleanup that's already over?
   A: `contract_holders` writes one fix per kind as if the redocument were still ahead. It never
   checks whether a remap is on trunk or a line still matches. This is the root.

### 2. Givens
- [seen] `contract_holders` (jig.py:3379-3399) lists any `reserve` counter whose pattern matches
  a numbered-heading sample over docs pages as kind `counter`. It always gets the same fix, "drop
  it at /jig:redocument's cleanup, once no page holds a numbered heading", whatever state the
  repo is in.
- [seen] I reproduced it on main's jig in a throwaway repo (scripts in the session scratchpad,
  `sc/lib.sh`, `sc/a.sh`, `sc/bc.sh`). The repo has no `.jig/redocument.md`, a flat
  `docs/x.md` with no `### N.1` heading, and
  `reserve.section = {"pattern": "^### (\\d+)\\.1(?!\\d)", "files": ["docs/**/*.md"]}`:
  - The update dry run says `up to date`, then lists `.jig/config.json reserve.section: numbers
    page headings: drop it at /jig:redocument's cleanup, ...` under Repo files to review.
  - `--apply` leaves `reserve.section` unchanged.
  - Survey's last line: "Checks, counters or lines that hold the old page contract, with no old
    page left: run /jig:update to edit each where it sits."
- [seen] The output is the same with a page holding `### 3.1 X`, and the same with
  `.jig/redocument.md` committed. A `step` counter over `db/migrations/*.sql` is never listed.
- [seen] The route loops. Survey sends the owner to update, and update's fix sends them to
  redocument's cleanup. Redocument step 2 refuses unless survey's last line names
  `/jig:redocument` (redocument SKILL.md), and here it names `/jig:update`.
- [seen] The update skill says a holder "is listed with its fix and never proposed for deletion:
  it converts with the pages". The survey skill says "Never propose deleting one; such a file
  holds more than the contract". RULES.md (Documentation) says "Those convert with the pages; jig
  never edits them." So no session proposes the drop.
- [seen] `FINDING_KINDS` has no `counter`, and `entry_problem` refuses an id with any other kind.
  I recorded `"counter:.jig/config.json": "approved"` in the repro, and update's output didn't
  change.
- [seen] The report's version claims check out. Blobs b9d48e5fbf9e and 13a476358699 have no
  "numbers page headings" check. a8a32d1dbb7e and c2af1224b3cc have it, with today's
  `FINDING_KINDS`. It came in with 76d83d9 on 2026-11-12.
- [seen] `.jig/redocument.md` on trunk means a run is under way, and the cleanup deletes it
  (redocument SKILL.md, "A resume?" and step 6). Survey already reads it this way:
  `at_rev(trunk, REMAP)` (jig.py:4342-4348).
- [seen] The board is jig's to edit on update. `rewrite_board` already drops a counter's `next`,
  and it drops whole keys (`lanes`, `log`), which the plan lists under Removed as `board: ...`.
- [seen] `heading_rules` keys a duplicate on the whole heading text (jig.py:8895-8918).
  `### 12.1 Foo` and `### 12.1 Bar` are two names, so while headings are numbered and cited by
  number, the counter is what keeps each number to one heading.
- [seen] A counter's numbers are only its pattern's matches (`highest_on_trunk`, RULES.md R6). A
  counter that matches no line holds nothing.
- [seen] Daisy's `.jig/config.json` has `reserve.section`, pattern
  `^#{2,3} (\d+)(?:\.\d+[a-z]?)?\.? `, over `AGENTS.md`, `docs/core/core.md` and twelve
  `docs/**` folders, beside `schema` and `record`. Its `.jig/redocument.md` has been on trunk
  since 31481708 (2026-11-12, amended 2026-11-15). Row 20 reads `.jig/config.json`
  `reserve.section` — drop, at cleanup. So Daisy's run is under way and its remap names the
  counter. The report's "no redocument is coming, as in Daisy" is wrong.
- [seen] Every old-layout update fixture (`tests/fixtures/*/repo/docs/alpha/alpha.md`, and the
  `old()` helper) holds `## 1 One` under its `^## (\d+) ` counter, so those counters stay.
  sec_headings (smoke.sh:6568-6570) sets a counter that matches no heading. It asserts that
  update's `reserve.section` line names the heading rule.
- [assumed] Maige-Lite's history (7e2a285, 5da422f, d6ada90, and the hand drop to
  `"reserve": {}` in 8f17cbb) is the reporter's. I didn't read it, because it's another repo. The
  fix doesn't depend on it.
- [assumed] The reporter says Adventure-Studio's and maige-ecosystem's counters cover a migration
  journal and a decision log. I didn't read them. The fix only removes counters that
  `contract_holders` already lists as holders, so a journal or register counter is untouched
  whatever it is.
- [assumed] No repo keeps a page-heading counter on purpose before it writes its first numbered
  heading. This is a risk, not a fact: `--apply` would remove such a counter. The dry run names
  the removal first.

### 3. One layer up
- **Sibling holders.** A check of the Now / Rules / Checks headings and an always-loaded line are
  the repo's own files. Update lists their fixes, the session edits them in place, and the
  finding goes away. The line's fix is the same in every state. The check's fix still says
  "while /jig:redocument runs and only the new one after its cleanup", but its fix is an edit, so
  the session can make it. The counter is the one holder whose fix is a deletion, which no
  session proposes, and whose home is jig's own board.
- **Future holder kinds.** The root is that a holder's fix names an event (the cleanup) rather
  than a condition. Any holder kind jig learns to detect after a repo's redocument has finished
  hits the same thing. A fix that names a condition jig or the owner can check stays true after
  the run. The general fixture below fails for any later kind that waits on the cleanup.
- **Existing patterns.** Three already fit:
  - `rewrite_board` edits the board on update and names each edit in the plan.
  - `approved_moves` drops a findings entry once its finding no longer fires.
  - `shape_fix` gives survey and update one shared fix.

### 4. Correction
This is a correction, not a workaround. It changes how holder fixes are produced, which caused
the symptom, rather than clearing Maige-Lite's leftover.

1. `contract_holders` decides once, for survey and update both. For each counter it reads two
   things: whether a run is under way (`.jig/redocument.md` on trunk), and the lines its pattern
   matches in every tracked file its `files` globs match.
   - **No run and no line:** the fix says `jig update --apply` removes it, and the holder is
     marked removable.
   - **A line matches:** the fix names the first `<file>:<line>` and how many more, and says
     update removes the counter once none matches and no run is under way. It doesn't say
     "drop it at /jig:redocument's cleanup".
   - **A run is under way and no line matches:** the fix stays as today, because the run's
     cleanup is real.
   - **The check holder:** its fix becomes the condition: accept only the new shape once no page
     is in the old one, and both while a run is under way.
2. `cmd_update` deletes each removable counter from the new board. It lists the removal under
   Removed as `board: reserve.<name> (a counter over numbered page headings, and no line holds
   one: the hook refuses a page's second heading of one name instead)`, and `--apply` writes it
   with the board. A repo that is otherwise current gets the plan, not `up to date`.
   `home_findings` reads the new board, so the counter isn't listed again under Repo files to
   review.
3. Text:
   - **Update skill:** in the holder paragraph, a counter that matches no line, with no run under
     way, is removed by `--apply`. Once no run is under way, the rest are edited where they sit.
   - **Survey skill:** the Old-contract holders bullet says the same.
   - **RULES.md (Documentation):** "jig never edits them" gets the counter's exception.
   - **`marketing/FEATURES.md`:** in the Old-contract holders row, the "not" column ("A deleter
     of the repo's files") adds that update removes a counter that numbers nothing, since the
     board is jig's.

### Done when
These run in a new smoke section, `holders`, with the plugin's update (`$UP`). Fixture A is
`pcnew` plus `jig init`, a flat `docs/x.md` (`# X`, a lead line, `## Thing`) with docmap
`{"docs/x.md": []}`, `db/migrations/001.sql` holding `-- step 1`, and
`reserve = {"section": {"pattern": "^### (\\d+)\\.1(?!\\d)", "files": ["docs/**/*.md"]}, "step":
{"pattern": "^-- step (\\d+)", "files": ["db/migrations/*.sql"]}}`. There's no
`.jig/redocument.md`, and everything is committed.
- [ ] **A, the reported symptom is gone.** Neither `jig survey` nor the update dry run prints
  `drop it at /jig:redocument's cleanup`. Today both do. The dry run's Removed section has
  `  board: reserve.section (`, and Repo files to review doesn't list `reserve.section`.
- [ ] **A, the fix fires.** `$UP --apply` leaves `.jig/config.json` `reserve` equal to
  `{"step": {...}}`, staged. After that, `jig survey` prints no "Checks, counters and lines that
  hold the old page contract" block.
- [ ] **B, a line still matches.** Fixture A plus `docs/y.md` holding `### 3.1 X` on line 5. The
  dry run lists no removal. It lists `.jig/config.json reserve.section:` under Repo files to
  review, with a fix that names `docs/y.md:5` and doesn't contain `cleanup`. `--apply` leaves
  `reserve.section` as it was.
- [ ] **C, a run is under way.** Fixture A plus a committed `.jig/redocument.md`. The dry run
  lists no removal and lists `reserve.section` as a holder. `--apply` leaves it.
- [ ] **D, other counters stay.** In A, `step` is never listed by survey or update and is still
  there after `--apply`. In the structure section, `reserve.adr` over `docs/adr/*.md` is still
  not listed (already a case).
- [ ] **E, every holder kind (one layer up).** Fixture A plus three things:
  - `tests/test_docs.py` holding `HEADS = ["Now", "Rules", "Checks"]`, written with `%s` the way
    sec_structure writes it;
  - an `AGENTS.md` line `- Rules written in a documentation page bind as if they stood in this
    file.`;
  - `docs/y.md` with `### 3.1 X`.

  There's no old page and no run. Survey lists three holders, and no holder line in survey or in
  the update dry run contains `cleanup`. Today two of them do: the check's and the counter's
  [seen, on main].
- [ ] **State 1 is unchanged.** sec_structure's holder cases pass as they are. Its old page,
  `docs/a/b.md`, holds `### 1.1 y`, so the counter stays and is listed.
- [ ] **Existing cases pass as they are.** sec_headings' "update's section-counter finding names
  the heading rule" case passes unchanged, now on the Removed line. sec_update's old-layout cases
  pass, so the counter over a page that update moves (read from where it is now) stays.
- [ ] `.jig/scripts/check.sh`, `claude plugin validate ./plugin`, and
  `bash tests/smoke.sh holders structure headings update` pass. The full suite runs at the
  check step.

### Out of scope
- **Maige-Lite needs nothing.** The reporter says its counter is already gone (8f17cbb). I haven't
  read that repo.
- **Daisy needs nothing.** Its remap's row 20 drops `reserve.section` at cleanup. If that cleanup
  misses it, the first update after the run removes it once no line matches.
- **Update never edits a check or an always-loaded line.** Those are the repo's files. Only the
  check's fix wording changes.
- **Survey's last line during a run.** In fixture C, with a remap on trunk, survey still says
  "with no old page left: run /jig:update to edit each where it sits" [seen]. A run resumes from
  the remap, not from that line (redocument SKILL.md, "A resume?"), so it's left as it is.

### Touches
- `plugin/templates/jig/jig.py`: `contract_holders` (the counter's and the check's fixes, and the
  removable mark carried in survey's `--json`), `cmd_update` (the removal into the new board and
  `removed`, or through `rewrite_board`), and the "never edited here" comment in `home_findings`.
- `plugin/skills/update/SKILL.md` (the holder paragraph) and `plugin/skills/survey/SKILL.md` (the
  Old-contract holders bullet).
- `plugin/templates/jig/RULES.md` (Documentation, the holders sentence).
- `marketing/FEATURES.md` (the Old-contract holders row), before the code.
- `tests/smoke.sh`: the new `holders` section, fixtures A to E.

### Alternatives considered
- **Add `counter` to `FINDING_KINDS`, so a `findings` "approved" drops it.** Rejected because an
  id is `<kind>:<path>` and every counter's path is `.jig/config.json`, so two counters would
  share one id. Also, a recorded yes carries out only renames (`MOVE_KINDS`), and this condition
  is one jig can check itself. Reason is [seen]: jig.py:3699-3714.
- **Skill text only, so update's session proposes the drop by hand.** Rejected because the
  condition is mechanical, and survey and update would still print a fix naming a cleanup that
  has already run. Reason is [seen]: the repro's output.
- **Remove every counter holder when no run is under way, whether or not lines match.** Rejected
  because while headings are numbered and cited by number, the counter keeps each number to one
  heading, and the heading hook doesn't (`### 12.1 Foo` and `### 12.1 Bar` both pass). Reason is
  [seen]: `heading_rules`, jig.py:8895-8918.
- **Offer `/jig:redocument` where lines still match and no run is coming (the report's
  proposal).** Rejected because redocument refuses unless survey's last line names it, and with
  no old page left that line names `/jig:update`. Reason is [seen]: redocument SKILL.md step 2,
  survey's verdict, and the repro's last line.
- **Also require that no old page is left, as survey's verdict does.** Rejected because a
  counter's numbers are only its pattern's matches, so one with none holds nothing for a
  redocument to convert. Reason is [seen]: `highest_on_trunk` (jig.py:702-715) and RULES.md R6.
- **Drop it at redocument's cleanup, the run that missed it.** Rejected because the cleanup
  deletes `.jig/redocument.md`, so there's no run left to resume. Reason is [seen]: redocument
  SKILL.md step 6 and "A resume?".
- **Have update edit the check and line holders too.** Rejected because those are the repo's own
  files, which RULES.md says jig never edits. The board is jig's, and update already edits it.
  Reason is [seen]: RULES.md (Documentation) and `rewrite_board`.
- **Fix Maige-Lite by hand and stop there.** Rejected because the loop reproduces on main for any
  repo whose redocument ran before 76d83d9. Reason is [seen]: the repro and the blobs.

### Decisions
- **This changes update's plan output.** The fix adds a `Removed:` line (`board: reserve.<name>
  ...`) and a board edit in `cmd_update`/`rewrite_board`. That's the same step and the same plan
  sections where `bug-update-adopts-roles.md` resets `workflow`/`roles`. The two jobs should be
  consolidated into one, or run one after the other, with the second rebased on the first's plan
  output and smoke assertions.
- **"A run is under way" means `.jig/redocument.md` on trunk.** That's the redocument skill's
  resume rule, and it's how survey already reads it (`at_rev(trunk, REMAP)`).
- **"No line" means no match anywhere the counter looks.** That's no match of its pattern in any
  tracked file its `files` globs match: pages, `AGENTS.md`, anything. It's judged on the repo as
  update's moves will leave it, with each moved file read from where it is now, as
  `home_findings` reads it. Any match keeps the counter.
- **One place decides.** `contract_holders` makes the call for survey and update both, as
  `shape_fix` does, so both say the same thing.
- **A holder's fix names a condition, not an event.** During a run, the counter's fix may still
  name that run's cleanup, because the run exists.
- **No exception for a heading counter kept on purpose.** A page-heading counter that numbers
  nothing belongs to the retired contract (RULES.md, Documentation: cite a page by its heading;
  FEATURES "One heading text per page"). The dry run names the removal before `--apply`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
