# docs-subsystems

Source: owner, Nov 8: "Outgrows a screen is a horrible measure. It should be defined more
mechanically, a sub-system is something that is at least somewhat independent of it's parent
system … like a fluid system in a car, its independent of suspension and power systems even
though they interface. Getting files of it's own is a better indicator. It should not go to any
depth, they should mostly be /systems with /subsystems allowed but jig should have to ask for
permission and provide rationale to propose subsystems within subsystems."

## Intent
A subsystem is defined by independence, not length, and the docs tree is two levels deep:
systems and their subsystems. A third level exists only where the owner approved it, with the
rationale recorded.

## Design
- **The definition** (RULES.md, Documentation). A subsystem is a part of a system that works
  independently of the rest of it. It has files of its own, which the system's other parts
  don't edit, and the rest of the system reaches it only through the interfaces between them.
  Example: a car's cooling system is separate from its suspension and its drivetrain, even where
  they touch. A section with no files of its own stays a section, however long it gets. The
  "outgrows a screen" test goes, from RULES.md and from `docs-page.md`.
- **The depth.** Pages live at `docs/<system>/<system>.md` and
  `docs/<system>/<subsystem>/<subsystem>.md`. A subsystem inside a subsystem needs the owner's
  word:
  - It is proposed with a rationale: what it is independent of, and the files it has of its own.
  - It is recorded in a new board key, `deep_subsystems`, a map from the folder to that
    rationale: `{"docs/power/battery/cells": "own firmware module and test rig; independent of
    pack thermal"}`.
  - The key lives in `config.json`, so R5 already keeps branches from adding to it. Only trunk,
    that is the owner, can.
  - An entry with an empty rationale doesn't count. Each deeper level needs an entry of its own.
  - `docs/hardware/` keeps its own homes and has no cap for now. flatten-hardware, which runs
    after this job, removes that layer, and `components/` becomes the reserved folder name.
- **Survey** (`at_home`, `page_home`, `doc_homes`):
  - A docs page named for its folder, more than two levels down, is at home only if its folder
    is in `deep_subsystems`.
  - Otherwise survey lists it as a new kind, `deep`, under its own heading: fold it into its
    subsystem's page, or propose it to the owner with its rationale for `deep_subsystems`.
  - `page_home` never proposes a destination deeper than a subsystem, unless that folder is
    approved. A page under a subsystem folder gets that subsystem's page as its fold target.
  - Survey's Doc homes line reads "its subsystems one level down", not "nested the same way".
- **Update** lists `deep` pages under repo files to review, with the same two choices.
  `deep_subsystems` is an optional key: it joins the list of optional keys that
  bug-workflow-unknown-key adds next to `BOARD_DEFAULTS`. That way update never warns that jig
  doesn't know the key, and never writes an empty map into every board.
- **Skills.** Where a skill proposes nesting, it proposes only system/subsystem. A third level
  is asked of the owner with its rationale, and lands as a `deep_subsystems` entry on trunk on a
  yes. This covers update's nesting question, redocument's remap, and adopt's homes table.

## Done when
- [ ] Smoke `homes`:
  - with `docs/a/a.md`, `docs/a/b/b.md` and `docs/a/b/c/c.md`, survey lists `docs/a/b/c/c.md`
    as `deep`, with fold target `docs/a/b/b.md`;
  - with `deep_subsystems: {"docs/a/b/c": "<reason>"}` on the board, it isn't listed;
  - with the reason `""`, it is listed again;
  - `docs/c/d/d.md` still passes;
  - a page `docs/a/b/x.md` (an old-format page beside `docs/a/b/b.md`) gets `docs/a/b/b.md`
    as its fold target, not `docs/a/b/x/x.md`.
- [ ] Smoke `homes`: `jig update`'s dry run lists the `deep` page under repo files to review.
  An update of a board with a `deep_subsystems` entry keeps the entry and prints no "not one jig
  knows" warning. An update of a board without the key doesn't add it.
- [ ] RULES.md (Documentation) and `docs-page.md` state the definition and the depth. Neither
  says "outgrows a screen" (`grep -rn "outgrows a screen" plugin` finds nothing).
- [ ] The update, redocument and adopt skills match the Skills line above.
- [ ] `bash tests/smoke.sh` passes, `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Checking "files of its own" mechanically, for example that a subsystem page has a docmap
  glob matching files its system's other globs don't. The definition says it; whether survey
  should check it is a later call.
- Requiring a subsystem's parent folder to have its own page (`at_home` doesn't check this
  today).
- Moving existing deep pages in any repo. Survey and update report them, and the owner decides
  each one.

## Touches
- `plugin/templates/jig/jig.py`: the optional board keys, `at_home`, `page_home`, `doc_homes`, the
  homes line (`~1468`), survey's page listing (`~1808`), update's repo files to review (`~4380`)
- `plugin/templates/jig/RULES.md` (Documentation; the board keys line, `~27`)
- `plugin/templates/jig/docs-page.md`
- `plugin/skills/update/SKILL.md`, `plugin/skills/redocument/SKILL.md`,
  `plugin/skills/adopt/SKILL.md`
- `tests/smoke.sh` (`sec_homes`)
- `marketing/FEATURES.md` (main checkout only: a row for `deep_subsystems`)

## Alternatives considered
- Refuse a too-deep page in the commit hook or at the gate: rejected because every other doc
  home is reported by survey and proposed by update, never refused. A hook would make this the
  one doc-home rule that blocks work [seen: `at_home` and `doc_homes` are called only from
  survey and update, `jig.py:1597`, `1751`, `4352`].
- Record the approval in the page itself, for example a line under its lead: rejected because
  a page is editable on any branch, so the agent proposing the level could approve it, while a
  board key is trunk-only under R5 [seen: RULES.md board keys; R5].
- A depth setting in `config.json` (`docs_depth: 3`): rejected because it approves every third
  level at once, with no rationale per subsystem, which is the opposite of what was asked
  [seen: owner, Nov 8].

## Decisions
- The rationale is stored as the key's value, not in a ledger, so the approval and its reason
  are one line and nothing can drift between them.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
