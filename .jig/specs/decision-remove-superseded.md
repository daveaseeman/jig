# decision-remove-superseded

Source: owner, Nov 11: "I dont like that a release is frozen. That's the whole point of git, we
can see what decisions changed. I'd rather remove the old decision, give the overriding decision
a new number that points back to the old one findable in git instead of on the page … Makes
what's current more readable." Then "agreed on all", on keeping release sections' change lines.

## Intent
`.jig/decisions.md` shows only the decisions that hold now. A superseded entry is removed in the
commit that adds the entry superseding it, wherever it sits, release sections included. The new
entry names the old id, and git keeps the old text. A release's change lines stay as released.

## Why
- Why is the log hard to read? A reversed decision stays in its release section forever, so the
  live decisions sit among dead ones, and you need `jig decision` to tell them apart.
- Why does it stay? Frozen releases (`frozen_problems`) refuse any edit to a released section,
  so the log doubles as its own history.
- Why change it? git already keeps history. Decision entries say what holds now, the same job a
  docs page does. Change lines tell a reader what a version changed, and that job is history.

## Givens
- `[seen]` RULES.md, Decision log, "Frozen releases": a commit that changes a line in a released
  section is refused, except ` [YANKED]`. `jig.py` `frozen_problems` (~3217) refuses a removed
  or changed release body.
- `[seen]` M2: "a supersedes link to no entry" is refused (RULES.md gate table, `log_problems`).
- `[seen]` `cmd_decision` (~3336) reads only the current log, and dies on an id that isn't there.
- `[seen]` Numbering starts above every id the log has ever named (RULES.md, Before the log), so
  a removed id's number is never given again.
- `[seen]` A pararepo's citation of a superseded metarepo entry is skipped as history
  (`DEAD_ROW`, jig.py ~4547, ~4565). The pin bump report names removed decision headings with
  their citers (bug-sync-moved-pages).

## Design
- **Remove on supersede.** A commit may remove an entry's whole block (its heading through the
  line before the next `###` or `##`) from any section, released ones included, when the same
  commit's log has an entry whose status line says `Supersedes <that id>`. Anything else in a
  released section stays frozen: change lines, headings, and the yanked line. An entry superseded
  but kept is still allowed, so old logs keep working.
- **M2: a supersedes link resolves through git.** A `Supersedes D-007` whose entry the log
  doesn't have is fine when trunk's history has a `### D-007` heading in the log. Otherwise it is
  a link to no entry, as today. The hook pays for one `git log -S` per missing id.
- **`jig decision <id>` reads history.** For an id the log doesn't have, it finds the last
  commit whose log had the entry, prints the entry as it stood there with that commit and the
  release it was in, then walks forward through the `Supersedes` links to what holds now.
- **The release section keeps its line.** A removed entry's release keeps its change lines. A
  reversed decision is still a major release, and its `**Breaking:** … (D-012)` line goes in
  the new release's group as today.
- **Citations move to the successor.** A pararepo citing a metarepo id that the pin no longer
  has gets the dangling-pointer line `jig sync` already prints. It now adds the successor's id
  (the entry whose `Supersedes` names it), as `now <meta>/.jig/decisions.md § D-012`.
- **Existing logs.** `jig update` lists every superseded entry still in the log under Repo files
  to review, with the edit "remove it; the entry superseding it names it". It makes the edit
  only on a yes, as it does for other repo files.
- **Only an accepted entry removes.** An Open or Proposed entry may name `Supersedes`, but only
  an accepted one's link lets the old entry go, counts as what holds now, or is a successor a
  pararepo is pointed to (added after review: a proposal must not retire a live decision).
- RULES.md: "Frozen releases" becomes "Released sections", covering the removal rule. "Newer
  wins" says a superseded decision is removed, not marked.

## Done when
- [ ] Smoke: a log with `D-001` released in v0.1.0. One commit adds `D-002 … Supersedes D-001.`
  under Unreleased and removes `D-001`'s block. The commit is accepted. The same removal without
  the superseding entry is refused, naming `D-001`. Editing a v0.1.0 change line is still refused.
- [ ] Smoke: after that, a later commit touching the log passes M2 (`Supersedes D-001` resolves
  through history). `Supersedes D-099`, which never existed, is refused.
- [ ] Smoke: `jig decision D-001` prints D-001's text, the release it was in, and `D-002` as
  what holds now. `jig decision D-002` names D-001 as superseded and removed.
- [ ] Smoke: a pararepo citing `<meta>/.jig/decisions.md § D-001` gets the dangling-pointer line
  after a pin bump past the removal, naming `D-002`.
- [ ] Smoke: `jig update` on a log holding a superseded entry lists it under Repo files to review.
- [ ] RULES.md, Decision log and Newer wins, say it.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Editing a release's change lines. They are what that version told its readers.
- Removing an entry nothing supersedes. Rejected entries are already removed (RULES.md), and an
  accepted one is changed only by a newer decision.
- Decisions naming what they touch (spec `decision-touches`).

## Touches
- `plugin/templates/jig/jig.py` (`frozen_problems`, `log_problems`, `cmd_decision`, sync's
  citation check, update's repo files)
- `plugin/templates/jig/RULES.md` (Decision log, Metarepo and pararepos: Newer wins, the M2 and R3 rows)
- `plugin/skills/subnode/SKILL.md`, `plugin/skills/stage/SKILL.md` ("supersede, never edit" becomes
  "supersede and remove"; added after review)
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only: the decision log row)

## Alternatives considered
- Keep releases frozen, as shipped in v0.10.0. Rejected by the owner: the current state
  should be readable on the page, and git is the history. Reason is [seen: owner, Nov 11].
- Remove superseded entries and their release's change lines too. Rejected: a release section
  is what that version told its readers, and the removed entry is still findable through git.
  Reason is [seen: owner agreed, Nov 11].
- List removed ids in the log's preamble, as rejected ones are, so M2 resolves them without
  git. Rejected: it puts a growing list of dead ids back on the page this change clears.
  Reason is [assumed].

## Decisions
- A decision entry is current state, and a change line is history. Only current state is
  removed when it stops being true.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
