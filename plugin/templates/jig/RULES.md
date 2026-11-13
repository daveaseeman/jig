# Jobs: parallel work on one repository

Several sessions change this repo at once. This is how they stay out of each other's way.

**A job** is one piece of work in flight: a *topic branch*, its *git worktree*, and a *CODEOWNERS-style* claim on files.

A handoff is a *pull request*; the gate is a *merge queue* with *branch protection*. The **hubnode** is what others call the *team lead*,
*orchestrator*, or *manager*; a **subnode** is a *teammate* or *worker*. If you already run any of those, you already run most
of a job — `jig survey` names what you have and what it maps to.

## Roles

- **The hubnode** is one session. It owns the trunk branch, the board, the worktrees, and
  the merges. It opens jobs, gates handoffs, merges. It builds no feature.
- **A subnode** is every other session. One job each: its branch, its worktree, its files.
  It never commits on trunk, never pushes trunk, never merges.

**Working alone?** Open no jobs and you are the hubnode of a one-job repo. R1–R5 and R8 go
quiet — a feature branch in your one checkout is nobody else's problem — while R7, the review
record, the handoff note, and the gate all still apply. `jig handoff` names the branch
instead of a job; `jig gate` with no argument gates the current branch. The discipline is
identical; only the coordination disappears.

## The board

Two files on trunk, written only by the hubnode. `.jig/config.json` holds what rarely
changes: `name`, `trunk`, `common`, `append_files`, `reserve`, `docmap`, `not_docs`,
`release`, `reference_files`, `workflow` (optional; see Workflow), `deep_subsystems`,
`boards` and `findings` (all optional; see Documentation), `derived_files` (optional; globs
naming every file `.jig/scripts/derive.sh` writes, which `jig merge` commits) and the layout's
`version`.
`.jig/jobs.json` holds the open jobs, nothing else. Per job:

| Key | Meaning |
|---|---|
| `spec` | its spec: a path under `.jig/specs/`, or one line |
| `state` | claimed → building → ready → gated (or parked) |
| `after` | jobs this one is gated behind |
| `owns` | existing files only this job may change while it is open |
| `shares` | existing files it may change alongside others |
| `reserved` | scarce numbers handed out centrally (migration steps, schema versions) |

A job's branch is its name, and its worktree is `.git/jig/worktrees/<branch>`. A job
adopted on another branch, or checked out somewhere else, stores `branch` or `worktree` —
only the one that differs. The day it opened is the commit that added its entry. Merging a
job deletes its entry in the merge commit, so git log of `jobs.json` is the board's history.

`common` and `append_files` are repo-wide. A file new to the repo belongs to whoever makes it.
`not_docs` lists globs where markdown ships as code (skills, templates, fixtures); `survey`
does not look for a home for those files.

**Owns is narrow on purpose.** Before opening a job, `jig open` diffs every open job's
branch against trunk and refuses an `owns` entry another live branch already touched. Those
go in `shares` from the start, or both jobs get blocked on every commit afterward.

## The rules

Checked before every commit by a git hook, and by `jig check`. A delete changes its path, and
a rename changes both of its paths: R3–R5, P1, P2 and P4 count each.

- **R1** The trunk checkout stays on trunk. Work in `.git/jig/worktrees/<branch>`.
- **R2** A job is built in its own worktree.
- **R3** A job changes only its `owns`, its `shares`, `common`, or files new to the repo, and
  adds to `.jig/decisions.md` (Decision log), whatever its lists say. There it changes lines in
  place only under `## Open`, and a line it added itself, and removes an entry only in adding
  the accepted one that supersedes it.
- **R4** Another open job's `owns` is refused even if this job also lists it.
- **R5** The board is the hubnode's: `config.json` and `jobs.json` are edited on trunk only.
  So is the roadmap, the owner's: `.jig/roadmap.md`, and `ROADMAP.md` where trunk has a
  `.jig/roadmap.md` (Roadmap, below).
- **R6** A scarce number belongs to the one job that reserved it. A change that makes a
  number matching a counter's `pattern` exist where trunk had none, and the branch doesn't
  hold it, is refused; merging a job takes the numbers it holds, and so does the gate's
  scratch checkout of it (a detached HEAD off trunk); a detached trunk holds nothing. Numbers compare as numbers: `D-002` is 2. A number trunk already has
  is taken by nobody, however many times the change adds it: editing or moving a heading, or
  adding a rule under an existing section, takes nothing. A counter marked `"unique"` also
  refuses a change that adds a second match of one number. Two branches that each take
  migration step 17 corrupt the first database that runs both.
- **R7** A change adding a `WORKAROUND:` comment to code must stage `.jig/ledgers/WORKAROUNDS.md` too;
  its first row creates the file. jig's own `jig.py` quotes the marker and is not checked.
  Prose may quote the marker.
- **R8** A job is gated only after the jobs in its `after` have merged.

**The hooks run trunk's copy of `jig.py`** (`git show <trunk>:.jig/jig.py`). A branch
cannot weaken the rules it is judged by, and a stale checkout is still judged by today's rules.
While a merge of trunk is being finished, a change is judged against trunk, so what trunk
brought in is not the job's.

**A bug in `.jig/jig.py`, `.jig/RULES.md` or a skill is the tool's, not this repo's.** Say what
in jig broke and tell the owner, then stop; the owner decides whether to run `/jig:feedback`.
Don't patch them; don't ledger it.

## Keeping merges mechanical

Conventions so two jobs rarely meet in one hunk:

- Append, never edit, shared prose. A change to someone else's section is a note in yours.
- A file of one's own: new routes in your own handler registered by one line; new state in
  your own module; new tests in your own file; a new fixture as a new file.
- Scarce numbers come from the board (`--reserve`, `jig reserve`), never from looking at what seems free.
  Two branches that both take migration 17 corrupt the first database that runs both.
- A file generated from the whole tree (a reference, an index) is written on trunk by
  `.jig/scripts/derive.sh` at each merge and listed in `derived_files`, never on a branch: two branches' copies merge into a
  wrong file, or conflict.

## Reserved numbers

Some things are scarce across the whole repo: migration step numbers, schema versions,
anything a runner stores and compares. Each counter in `config.json` says how
to find its numbers:

```json
"reserve": {
  "step": {"pattern": "^-- step (\\d+)", "files": ["db/migrations/*.sql"]},
  "schema": {"pattern": "SCHEMA_VERSION\\s*=\\s*(\\d+)", "files": ["**/storage.py"], "unique": true}
}
```

A number is taken where trunk had no match for it, in any of the counter's files, and the
change adds one. So editing the file that opens `-- step 17`, where trunk has it, takes
nothing, and a new file opening `-- step 18` takes 18. `"unique": true` is for numbers that
must also appear once: a second `SCHEMA_VERSION = 17` where trunk has one is refused as "17
already exists". It is off unless set, because some numbers rightly appear more than once. It
applies working alone too, with no job open: there is nobody to take a number from, but a
second 17 still breaks. A pattern that captures only the whole part of a dotted number counts
`17.2` as 17, so a dotted number under a whole number trunk already has takes nothing.

`--reserve <counter>` hands the job max(the highest on trunk, the highest an open job
holds) + 1, so two jobs open at once never get the same number. `jig reserve <job> <counter>`
hands an open job another by the same rule; it then holds a list. Nothing stores a "next":
the files say what is taken, and a counter without `pattern` and `files` is refused.

A job holding step N lists the job holding N−1 in `after`, so they merge in order: a
database already past a number never runs a step of that number that merges later.

## Documentation

One page per system, `docs/<system>.md`. A subsystem's page sits in its system's folder,
`docs/<system>/<subsystem>.md`. A page is a single file, flat in its parent's folder, until it
holds more than itself — subsystem pages, files it links, a `datasheets/` folder; then it moves
into a folder named for it, `docs/<system>/<system>.md`, with that company beside it, in the
change that adds the first of them. Both forms are one page, and that is about naming only: a
`docmap` key or `boards` entry written in either names it in either, so a branch grows the
folder with a `git mv` alone, and the key on trunk may be rewritten later or never. A key that
names a page in the wrong form doesn't make that form right: the page still moves. The tree names the product's systems, not its files, so a rule that touches several
files lives once.

In a folder that has a page, another `.md` is a flat page when `docmap` or `boards` names it, or it
has an Invariants section (or a retired `## Undefined`); anything else there is one of the folder page's files.

A **subsystem** is a system inside a system: it works independently of the rest of it. It has files
of its own, which the rest of its system doesn't edit, and the rest of the system reaches it
only through the interfaces between them. A car's cooling system is separate from its
suspension and its drivetrain, even where they touch. A section with no files of its own stays
a section, however long it gets.

The tree is two levels deep: systems and their subsystems. A subsystem inside a subsystem needs
the owner's word. It is proposed with a rationale: what it is independent of, and the files it
has of its own. On a yes, it is recorded on trunk in `config.json`'s `deep_subsystems`, a map
from its folder to that rationale: `{"docs/power/battery/cells": "own firmware module and test
rig; independent of pack thermal"}`. An entry with an empty rationale doesn't count, and each
deeper level needs an entry of its own. `jig survey` lists any other deeper page to fold into
its subsystem's page or to propose.

`jig survey` works out each page's level from evidence, never its path: the files it owns
(its docmap globs' files that no page but those above it covers), the repo's structure maps
and manifests, and with `--levels` its imports. A page below a system whose docmap globs cover no file
is a section of the page above it; one whose every file another page covers is that page's
subsystem, or a seam; each folds on the owner's yes. It also lists the repo's own files that
still hold the old page shape — a check of the Now / Rules / Checks headings, a counter over
numbered page headings, an always-loaded line that makes page rules bind or cites a page by
number — and the files that declare the docs structure beside the docmap. Those convert with
the pages; jig never edits them.

A page describes what is built: what is true of its system on trunk today, in present-tense
prose. It is not a rulebook; this file holds the rules about documentation, and no page
restates them.

**Product and project.** A page and a decision entry are about the product: what it is and how
it behaves today. Priorities, phases, ordering, delivery queues, build status and "not built
yet, phase n" are the project, and live in `.jig/roadmap.md` only (Roadmap). A spec is where
the two meet: it takes project items and turns them into product, as code, pages and decisions.
A page may say what the product doesn't do today ("Changing the PIN isn't supported"); it never
says when, or in what order, that will change. References run one way: a spec, a handoff or
the roadmap cites pages and decisions freely, and a page or a decision entry never names
`.jig/specs/`, `.jig/handoffs/`, `.jig/roadmap.md`, `ROADMAP.md`, or a phase or scope, built or
not. The hook refuses an added line in a page under `docs/`, in `.jig/decisions.md` or in a
metarepo's entry file that names `.jig/specs/`, `.jig/handoffs/` or `.jig/roadmap.md`, or a
scope id the roadmap has in code quotes (`` `alpha/screen` ``), and names the line; a moved
page's old lines aren't new. What can be product text too, it can't judge: `ROADMAP.md`, a
bare scope id ("the v1/api endpoint"), a phase name, prose like "phase 3" or "spec step 6".
`jig survey` lists those. The hook also refuses a `roadmap.md` under `docs/` or matching a
metarepo's `entry_files`: the roadmap is `.jig/roadmap.md`, and the root `ROADMAP.md` is
exempt only where `.jig/roadmap.md` exists.

**Docs point only at docs.** The root documents (`README.md`, `AGENTS.md`, `CLAUDE.md`,
`GEMINI.md`, `CHANGELOG.md`) are for outsiders and for agents: they may point into `docs/`, and
a page or a decision entry never names one. The hook refuses an added line in a page under
`docs/` or in `.jig/decisions.md` that names a root document as a path, with or without `§`
(`README.md § mote`, `../AGENTS.md`), and names the line; a file `not_docs` matches is exempt.
A Markdown link resolves from the page's folder, so a page's link to its own folder's
`README.md` is no root document; any other path is from the repo's root, as jig's pointers are.
Another repo's file (`<repo>/README.md`) and a code path are not root documents. Prose
that names one without a path ("listed in the root README") the hook can't judge; `jig survey`
lists those lines too.

Every page, in this order (`.jig/docs-page.md`, which `jig update` keeps
current, is the skeleton):

1. **A lead paragraph**, with no heading of its own: what the system is and why it exists.
2. **Body sections**, named for what its code has — its nouns (Schema,
   Renderer, Sync) — never for a lifecycle or a genre (Overview, Notes, Misc, Changes). A
   subsystem gets a page of its own, beside its system's, once it has something to say that
   whoever works on it needs and its system's page doesn't; the parent's section then shrinks
   to a paragraph and a link. Until then it is a section, its files in its system page's globs.
3. **`## Talks to`**, optional: what crosses the system's boundary, meaning what it calls, what
   calls it and what passes between them, each linked to its seam page or contract where one
   exists. Calls inside the system stay in the body.
4. **`## Invariants`**, optional: only the facts that are load-bearing. Each entry states,
   inline, why it must hold and what holds it — a named test, review, or on screen:
   `- Rows are at least 44px — the touch-target minimum; held by test_touch_targets.` An
   entry without a why and a holder is description, and goes in the body or nowhere.

A page has no `## Undefined`, `## Status`, `## Current state` or `## Roadmap` section: each holds
the project. Work parked mid-build is an item under `## Up next` in `.jig/roadmap.md`, naming
the pages it will touch (Roadmap), written only on the owner's word. An open product question
is an `## Open` entry in `.jig/decisions.md`, which the page may cite. Review findings not taken
go in `.jig/ledgers/DEFERRED.md`. `jig survey` lists each such heading with where its content
goes; a page that still carries one works as before until it is moved.

Trunk's code is reality. A page that disagrees with the code is a stale page, and gets fixed.
An invariant the code breaks is a finding the handoff surfaces for a person to rule on, never
an instruction to bend the code. Cite a page by its heading (`docs/ui/ui.md § Invariants`),
not by a number. A moved rule leaves no forwarding address behind — that is history, and
git keeps it.

In `docmap`, a subsystem's page names its own files and its system's page names the rest:
fold-in asks every page that covers a changed file, so a system page whose globs reach into
its subsystems is asked about every change made in them.

A **seam** page covers what crosses between two systems: in `docmap`, a page whose globs name
files from both sides. It lives, as a datasheet two pages share does, in the nearest folder both
systems sit under: `docs/<seam>.md` for two systems, flat, with no page above it. `jig reading-list <files>` prints which pages to read before touching
those files, and after each the pages above it in the docs tree, marked as its parent, since a
system's shared facts live on its own page. Fold-in still asks only the pages that cover a
changed file.

A page's folder holds the files the page links — a schematic, a snapshot of a definition, an
image — beside the page and its subsystems' pages. `jig survey` lists a file there that no
page links (a link from a note in the folder counts); a page named for its folder with nothing
else in it, flat at its parent's (`docs/a/b/b.md`: flat at `docs/a/b.md`); and a flat page
with a folder of its own name beside it, to move into. The hook refuses a change that puts a
page in the wrong one of its two forms — it adds or moves a page there, or adds a page's first
other file or removes its last without the move — and names the move, in survey's words. A page
already in the wrong form is survey's, and a change that leaves it there isn't refused. A flat
page's own file left loose in its parent's folder is that folder page's to survey, so review
catches it.

A board, a screen, a battery are parts of the product, so each is a system or subsystem like
any other: `docs/<board>.md`, or `docs/<system>/<board>.md` where the board is part of a larger
system, in a folder of its own once it holds files (a spec sheet makes a `datasheets/`), beside the code's pages, never under a genre folder. Every board has a
page the repo builds, made from jig's board template (`/jig:hardware`) out of a hardware
definition and checked against the code; a dev board gets one too, written from its vendor's
spec sheet. It is a board page because `config.json`'s `boards` lists it, never because of where
it sits. A `docmap` entry ties each page to the code that targets its board, so every handoff
that changes that code asks whether the page still matches. `jig gate` refuses:

- a branch that adds or changes a board-build file (`sdkconfig*`, `platformio.ini`,
  `idf_component.yml`, `west.yml`, `*.ino`, `*.overlay`) that no registered board page's
  `docmap` globs cover: write the board's page, list it in `boards`, map the file to it;
- a branch that deletes or moves a page `boards` lists;
- "no page needed" in the fold-in for a file a registered board page's `docmap` globs cover.

A repo with no board-build files has none of these. `jig survey` lists each board-build file
no registered board page covers, and a `boards` entry naming no page: the page may still be on
a job's branch, so the gate leaves that one to survey. Survey reads board pages against the page
contract like any page, and the gate doesn't refuse one off it.

A part whose behavior the code touches is a subsystem with its own page. A vendor's documents —
datasheets, a dev board's spec sheet, app notes, reference manuals — sit in a `datasheets/`
folder in the folder of the page that leans on them: a part documented only by its datasheet is
a file in its page's `datasheets/`, and a board's own spec sheet is in `docs/<board>/datasheets/`.
A file the repo wrote, its own schematic or a definition the user wrote, sits in the page's
folder itself. A datasheet two pages use lives in the `datasheets/` of the nearest folder both
pages sit under: two subsystems of one system share the system's `datasheets/`, two systems
share `docs/datasheets/`. Both pages link it; it moves there when the second page starts using
it, and is never copied: `jig survey` names a page linking into the `datasheets/` of a page that
is neither its own nor above it, and the shared folder the file belongs in. `datasheets/` is a reserved name at any depth: it holds reference
files, is never a subsystem and never a page's home, and a note inside it is a reference file,
not a page. `jig survey` names a page called `datasheets` (rename its folder), and a
`datasheets/` folder that is neither in a page's folder nor at `docs/datasheets/`.

Each link to a datasheet carries its source URL, the date it was retrieved and the first 12 hex
digits of its sha256 (a board page's Components table, or the page's text), so a check names
the exact document it was made against; a board page's table also says whether each part is
verified on the board yet. Whether the binaries are committed is the repo's call,
`reference_files` in the config: `commit`, or `ignore`: `.gitignore` ignores the PDFs under any
`datasheets/` folder (`docs/**/datasheets/**/*.[pP][dD][fF]`), and the page keeps each one's
URL and hash to fetch it again. Notes stay committed, and so does every file the repo wrote.
`jig survey` reports a link from a page into a `datasheets/` folder that doesn't exist.

### Homes

`jig survey` checks each Markdown file the repo tracks against this list, outside tool folders
(`.jig/`, `.claude/`, `.github/`, …) and `not_docs`:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `README.md` at the root, a `CHANGELOG.md` there
  until `jig update` merges it into `.jig/decisions.md` (Decision log), and `ROADMAP.md` there
  when `.jig/roadmap.md` exists (it is generated: Roadmap, below);
- under `docs/`, a page, flat or named for its folder: `docs/<system>.md` or
  `docs/<system>/<system>.md`, `docs/<system>/<subsystem>.md` or
  `docs/<system>/<subsystem>/<subsystem>.md`, and a deeper one only where `deep_subsystems`
  approves the folder it stands for (`docs/a/b/c` for `docs/a/b/c.md` and `docs/a/b/c/c.md`
  alike) and each level above it past the subsystem;
- any other file in a page's folder or below it, outside the folders of its subsystems;
- nothing under `docs/hardware/`, the layout before boards were systems: survey and update
  say where each of its files goes, and `/jig:redocument` moves them;
- anything under a `datasheets/` folder, inside a page's folder or at `docs/datasheets/`;
- in a metarepo, its decision registers, and its pages under a genre folder (Metarepo and
  pararepos), not the code repo's tree.

Any other file has no home, and survey says which kind: an `AGENTS.md`, `CLAUDE.md` or
`GEMINI.md` off root is a second rulebook; three or more sentences of this file word for word
is a copy, which freezes while this file moves on; a page, flat or in its folder, below a
subsystem, with no `deep_subsystems` entry, is deep: fold it into its subsystem's page, or
propose its folder to the owner with its rationale; a page outside the tree — one with an
Invariants section or a retired Undefined one, the old Now, Rules and Checks headings, or any file `docmap`
names, whatever its format — goes flat beside
the nearest page that has a folder, as a subsystem at most (into that page, where it would be
deeper), or to `docs/<name>.md`, even when it quotes this file;
anything else is a stray. A package's own rules file stays only on the owner's word. A
file names a document by its path, or by its bare name only when no other tracked file has
that name.

Each kind of document has one home: rules in `AGENTS.md`, and the rules about documentation
here; what the code is now and its invariants in `docs/`; a task in flight in
`.jig/specs/`; decisions that outlive their spec, and what a release changed, in
`.jig/decisions.md`; the phases, scopes and parked work ahead in `.jig/roadmap.md`; patches in the code in `.jig/ledgers/WORKAROUNDS.md`; review findings not taken
in `.jig/ledgers/DEFERRED.md`; know-how in the agent's skills; what outsiders need in
`README.md`; history in git.

A repo's terms are its glossary, `docs/glossary.md`: a `# Glossary` title, an optional lead
line, then the terms, each saying what it means and what it is not, in one of two forms: a
`## <term>` heading per term, or one table whose first column is the term, a row per term, its
other columns the repo's own (an owner, what the screen calls it). Either way
`docs/glossary.md § <term>` names one. The glossary is no system's page: it is not in `docmap`,
covers no files, and the page contract doesn't apply to it. No other glossary is a home: survey
and update list a `## Glossary` section of the root `README.md`, or a root `GLOSSARY.md`, with
`docs/glossary.md` as where it goes, and survey names each term in the glossary written as a
bold word opening a paragraph (`**term** — …`) rather than a heading or a row.
`jig update --apply --glossary`, on the owner's yes, moves it: each term in the form it has (a
README's `### <term>` becomes `## <term>`, a bold-paragraph term gets a heading, a table moves
as the table), the old section or file removed, and in the same change every pointer to the old
home rewritten (`README.md § <term>` to `docs/glossary.md § <term>`, a pointer to the
section itself and `GLOSSARY.md` to `docs/glossary.md`). The dry run lists each line it rewrites; each pointer it
can't (a section naming no term, prose naming the README), and each line the hook would refuse
in the move's commit (a term's text naming a root document), which it leaves for the session
to edit before committing; and each pointer in history, left as written: fenced code, a
handoff, a released section of the decision log or of a root `CHANGELOG.md`. A README
`## Glossary` section holding no term, only a link to `docs/glossary.md`, is no glossary.

`jig survey` also reads each page at home under `docs/`, board pages included, against the
contract above, and names a page in the old Now, Rules and Checks shape (convert it: fold
what it says into description, delete what no longer holds, keep as Invariants only what
passes the test), an Invariants entry with no why (` — `) or no holder (`held by`), and a
page whose first line of text after its title is a heading rather than a lead paragraph. It
lists, apart, the project in the product: a `## Status`, `## Current state`, `## Roadmap` or
`## Undefined` heading on a page or a metarepo's entry file, and plan prose ("phase 3", "spec
step 6") on a page or in the decision log, each with where it goes. `jig update --apply` brings this file; it
changes a page only by `--sweep`, below, on the owner's yes, and reshaping a repo's pages is a job of its own there.

`jig update` sweeps a repo onto the boundary, each move on the owner's yes. Under Repo files to
review it lists each page's `## Undefined` entry as the `## Up next` item it would become, the
project headings and plan prose above, each decision entry (or, before the log, register row or
section) whose words read as scope (priorities, phases, milestones, a demo, a launch, a
delivery queue, a sprint, "first, then"), and the repo's plan and register files with where
each one's content goes: `TODO.md`, `BACKLOG.md`, `STATUS.md`, `PLAN.md` and a hand-written
`ROADMAP.md` to `.jig/roadmap.md`; `FEATURES.md` to its systems' pages and decision entries;
`RULES.md`, `CONVENTIONS.md` and `CONTRIBUTING.md` to `AGENTS.md` or a skill. It judges none of
them. `jig update --apply --sweep` writes the Up next items to `.jig/roadmap.md`, creating it when
absent, on trunk (R5), and removes each emptied Undefined section where the pages may change:
on trunk, or in a metarepo a job's worktree (M4), where it removes only the sections whose
entries trunk's roadmap holds.

### The findings record

Each file finding `jig survey` prints, and `jig update` lists under Repo files to review, has
an id, `<kind>:<path>`, the kind as survey's `--json` gives it (`shape`, `page`, `deep`,
`contract`, and a page's level when it isn't a subsystem: `section`, `shared`, `unmapped`):
`shape:docs/a/b/b.md`. Two approved moves onto one path go one at a time: `--apply` makes the
first and keeps the other recorded, and says so. A stray, a metarepo page in no genre, an old board file
and a page whose only problem is the old contract have no id: `/jig:redocument`'s remap answers
them. The owner's answer to each is recorded on trunk in
`config.json`'s `findings`, one entry per id, no globs, trunk-only like the rest of the board
(R5):

- `"approved"`: do it;
- `"deferred: <where>"`: later, and where it will be answered (`deferred: redocument`);
- `"exception: <the owner's reason>"`: the repo differs from this file on purpose. An exception
  or a deferral with nothing after its colon doesn't count, and survey lists each entry that
  doesn't. A deep page's exception is its folder in `deep_subsystems`, with its rationale, never
  a `deep:` entry here: one finding has one exception record.

jig acts on the recorded entry, never on an answer in chat, so the answers are one commit on
trunk before anything acts on them. Survey and update print each finding's outcome beside it —
not answered, approved and not done, the deferral, the exception — and survey's `--json` gives
`id` and `outcome`. Survey's last line counts the findings not answered, those approved and
not done, the exceptions that answer no finding, and the remap rows that contradict it (below),
each with who acts on it, so it never says there is nothing to do while one stands. A carried-out
move never renames an entry onto an id already recorded: it leaves that entry at its old id and
says so.

An answer stays where the owner put it: it answers the finding with its id, at its path, and
nothing reads it anywhere else. An entry moves only with jig's own move, below, and jig never
drops an exception: it is the owner's reason, which no tree can rebuild. When a page moves by
other means (a job, a remap), its exception is recorded again at the new path, or dropped, on
trunk. Survey lists each exception that answers no finding, except while `.jig/redocument.md`
is on trunk.

`jig update --apply` carries out each approved move, whether or not the layout is current: a
`shape` finding, or a `page` outside the tree that isn't a fold. It makes the `git mv`, renames
the `docmap` key and `boards` entry naming the old path, drops the entry, and moves the page's
other entries (an exception on its `contract` finding) to its new path. It drops an approval or
a deferral whose finding no longer fires: that question is settled. What it can't do — a reference in another file, a
`contract_paths` glob, a `BUFFER.md` row per cached pointer, an edit — it prints for the
session to make in the same commit, and an approved finding it can't carry out stays recorded.
The usual refusals apply (open jobs, tracked changes), and it commits nothing. In a metarepo a
page moves only in a job (M4): `--apply` lists the approved moves as the job's and makes none,
and each approval drops on trunk's next `--apply` once its move has merged.

`/jig:redocument`'s remap, `.jig/redocument.md`, is read by its table's `Old path(s)` and `New
path` columns, `same` keeping each old path. The hook refuses a commit that adds or changes it
while a row keeps a page at a path survey moves it from (a `shape` or `page` finding), judged on
the tree the remap leaves — a page alone in its folder today that another row gives company is
in the right form — unless
`findings` records the owner's exception for that page; the refusal names the page, survey's
destination and the entry to record. Survey names such rows in a remap already on trunk.

## Fold-in

Code and the page that documents it move together, or the page starts lying. `jig handoff`
works out every documentation page that covers a file the branch changed — a file can have
several, such as its system page and the page of the board it runs on — and writes a
checklist into the note. A moved file asks the page that covered its old path too. Each line
asks whether the page still describes the code: it is either ticked as updated — the stale
sentences edited, deleting text included — or says why none went stale. Each roadmap item
naming a covering page with `(touches …)`, an `## Up next` item or a taken scope, gets a line
of its own, answered **built**, **untouched**, or **departed: <why>**, with anything after the
answer the answerer's to add. Built means the work's description is in the page's body now. The
roadmap changes on trunk only, so `jig merge` deletes an Up next item answered built from
`.jig/roadmap.md` in the merge commit and rewrites `ROADMAP.md`; a scope's state comes from its
specs, as ever. Solo work on trunk has no merge: there `jig gate` refuses while an item the
note answers built is still under Up next, so it is deleted on trunk in a commit of its own. `jig gate` refuses while a line is unanswered; untouched and departed are answers.

Ownership comes from `docmap` in `config.json`:

```json
"docmap": {"docs/storage/storage.md": ["server/storage.py", "server/migrations/**"]}
```

`docmap` can name any file, config such as `sdkconfig` included; a page is asked about
whenever a file it names changes. A changed source file nothing covers is listed as
`UNOWNED` — add it to `docmap`, starting a new page from `.jig/docs-page.md`, or answer why
it needs no page.

A decision entry and the pages citing it are one home, so a branch that adds, edits or removes
an entry in `.jig/decisions.md` also asks each page whose text cites that id, even in passing,
with the ids on its line; an entry that supersedes another asks for the old id too. The pages
are a metarepo's entry pages, and `docmap`'s pages in any other repo. The id matches whole:
`D-7` is not `D-70`. The log itself is not asked.

An entry the branch adds or changes also gets one line per peer (Decision log), naming both and
the page they meet on:

```
- [ ] D-?id-lock vs <meta>/.jig/decisions.md § D-033 (<meta>/docs/features/gestures.md): ___
```

It is answered **agrees**, **narrows: <how>** (one is an exception the other allows), or
**conflicts: <resolution>**. jig picks the pairs and never judges one; the gate refuses a line
unanswered, reshaped, answered with another word, or answered conflicts or narrows with nothing
after it. A peer log jig couldn't read gets a line too, answered by reading it or saying why not.
The gate finds the pairs again on its merge of trunk, and refuses one the note doesn't answer:
a job merged since the handoff ruled on the same page, so the job syncs and hands off again.

## Sync

`jig sync` merges trunk in. A conflict in an `append_files` file where **both sides only
added at the same spot** is resolved automatically: trunk's lines, then the job's. Anything
else stops with the files named, and a person resolves it.

## Handoff, gate, merge

1. **The subnode hands off.** Runs the checks, has the diff adversarially reviewed, records it
   (`jig reviewed`), then `jig handoff` writes a note naming that exact commit, in
   `.jig/handoffs/<name>-<date>.md` with a `/` in the job's or branch's name as `-`. Its
   `Spec:` is `--spec`, as a path from the repo root, else the job's spec on the board:
   working alone, pass `--spec`. A chunk that doesn't finish its spec hands off with
   `--partial`. Fill every heading, commit the note with the work, tell the hubnode the job
   and the commit. The note and the review's `.jig/ledgers/DEFERRED.md` rows may be one
   commit after the reviewed one: a change there that deletes no line doesn't count as a
   change since the check. A job may hand off several times.
2. **The hubnode gates.** `jig gate <job>` refuses on R8 and on a missing note. Then it sets
   up a **detached scratch checkout of the commit the note names**, with trunk merged in the
   way `jig sync` merges it, and prints the check to run there. It never runs
   the check: whoever runs it runs the same command. Never the job's live worktree, which the
   subnode may still be building in.
   The scratch checkout lives until the job is marked gated or merged: `jig mark <job> gated`
   and `jig merge <job>` remove it, untracked files and all, and refuse while it holds a
   tracked edit, which belongs on the job's branch. `jig update` removes one left behind.
   The hooks set that checkout up with `.jig/scripts/setup.sh`, when it is added and again
   after its merge of trunk, so the checks run in an environment built from the job's own
   manifests.
   That means a merge runs the merged-in `setup.sh`: review a change to it like any other
   code, because the next merge executes it. The same goes for `derive.sh`, whose output the
   merge commits.
3. **The hubnode merges** with `jig merge <job>`, which deletes the job's entry and numbers its
   `D-?<slug>` ids (Decision log) in the merge commit itself, then syncs the clean jobs. A job synced since its note still merges: only
   the job's own commits count as changes since the check, and what a sync's resolution
   carries beyond what `jig sync` would make of it (this replay needs git 2.38 or later).
   Either refuses until it is handed off again. A job that wasn't synced and conflicts with
   trunk only in `append_files` files where both sides only added is resolved in the merge as
   `jig sync` would resolve it (a replay of that sync, so trunk's lines, then the job's; git
   2.38 or later), and the job's branch is left as it was. Any other conflict in an append
   file, or one beside a conflict elsewhere, is refused with "`jig sync` the job, then merge":
   the sync resolves the appends as the gate did and stops on anything else. A job whose only
   conflicts were appends needs no new handoff after it. What the merge touched in shared files goes in that commit's message (`-m`).
   `--subject <ids>` is the ids the subject leads with, e.g. `D-001, D-002`, for a repo whose
   subjects lead with ids: the subject becomes `<ids>: merge <job>`. `: merge <job>` is added
   unless the text already ends with it, so pass the ids and don't write the merge yourself.
   Before its commit the merge runs `.jig/scripts/setup.sh`, then `.jig/scripts/derive.sh`,
   and commits what the board's `derived_files` globs match in the merge commit, and nothing
   else it wrote: a tracked file left changed outside them is named and not committed. A failing
   derive stops the merge before its commit, as a conflict does: fix it, `jig merge --number`,
   `git commit`.
   A hand `git merge` on trunk runs `setup.sh` but not `derive.sh`: run it and commit what it
   wrote, or the derived files stay stale until the next `jig merge`. In a metarepo, don't run
   `derive.sh` on trunk after a hand merge: M4 refuses the commit, and what it writes blocks the
   next `jig merge`, which writes them.

## Workflow

The hubnode writes specs, talks with the owner and decides. The work goes to sessions it
starts, each at a model tier and an effort the owner set, never one a model picks for
itself.

| Step | Who | Tier | Effort | An override must keep |
|---|---|---|---|---|
| `spec`: spec, decide, retro, hardware page | hubnode | 2 | 2 | — |
| `bug`: a bug investigation | a fresh context it starts | 2 | 1 | tier no worse than spec's; effort no lower |
| `execute`: execute, fix | a subnode it starts | 2 | 3 | tier no better than spec's; effort lower |
| `review` | a subnode, always a fresh context | 2 | 1 | tier no worse than execute's; any effort |
| `check`: gate check, release run, survey | a subnode it starts | 3 | 4 | nothing: fixed commands |

Tier 1 is the best model the tool has; a higher number is a lesser model. Effort 0 is the
tool's highest; each number up is one level lower. The defaults leave effort 0 free, so a
repo can raise any step. Which model and level a number means is the tool's business, not
`.jig/`'s.

`jig workflow` prints the steps in effect. A repo overrides them in `config.json`:
`"workflow": {"review": {"tier": 1, "effort": 0}}`. An override that breaks the last column
is refused by `jig workflow` and by the commit hook. There is no per-task override: a task
that needs other settings means the owner changes the config.

A spec's `## Workflow` section is `jig workflow`'s output when it was written. The review
records the review step's configured settings (`jig reviewed --tier N --effort N --ran
"..."`), the handoff note carries them, and `jig gate` warns when they are a worse tier or a
lower effort than the spec asks. So the warning catches a review recorded without them, or a
config changed after the spec was written; it can't see a review that actually ran weaker
than it was set to. A fix goes back to the session that executed. A third round that doesn't converge is a
bug in the spec or the approach: investigate it, don't start a fourth.

## Roadmap

Optional: a repo with no `.jig/roadmap.md` has no roadmap, and nothing here applies to it.
The product is the repo, so there is one roadmap and no product level in it.

- **The source**, `.jig/roadmap.md`: phases as `## <phase>` headings, in order (no dates: order
  is file order); every `## ` heading but `## Up next` is a phase. Each has an `Exit when:` checklist of what
  the owner checks, a `Scopes:` list of `` - `<scope>`: <what it is> `` (unindented, the name
  with no space or `/`), or both. A scope's id is `<phase>/<scope>`. "Every scope is done" is
  implied, never written as a box. A duplicate phase or scope id, a phase with neither list,
  or a line under `Scopes:` that isn't a scope is refused by the hook, by line, and reported
  by `jig roadmap`. A scope may end with `(touches docs/<page>.md, …)`, the pages it will change.
- **Up next**, the one reserved section that isn't a phase: work parked mid-build, in no order,
  on the owner's word. Each item reads
  `` - `<id>`: <what is parked>; stops at <where>; parked <YYYY-MM-DD> (touches docs/<page>.md, …) ``,
  unindented, and names the pages it will touch; the hook refuses one that names none, or a
  duplicate id, by line. `jig reading-list` prints, after each page, the Up next items and the
  scopes not yet done that name it, and fold-in asks about them (Fold-in). An item answered
  built leaves the roadmap in the merge commit.
- **A touched page exists**, in either form. `jig roadmap` reports one that doesn't; on trunk
  the hook refuses a commit that leaves an item or a scope touching no page, so a page renamed
  or deleted there is re-pointed in the same commit; and `jig merge` re-points each page the job
  moved.
- **Specs take scopes** with a `Scope:` line under `Source:`, e.g. `Scope: alpha/screen,
  alpha/battery`. Many-to-many: a spec may take several scopes, a scope may be taken by several
  specs, and a spec with no `Scope:` line takes none.
- **A spec is complete** when a handoff note naming it (`Spec:`) is on trunk and the commit it
  names is in trunk's history, merged or handed off solo on trunk. `jig handoff --partial` is a
  chunk that doesn't finish its spec: its note records `Partial: yes` and completes nothing.
- **States are derived**, never edited. A scope is *open* (no spec takes it), *taken* (a spec
  that takes it isn't complete) or *done* (taken, and every spec that takes it is complete). A
  phase is *done* when every scope in it is done and every `Exit when:` box is ticked; one with
  no scopes and no boxes is *empty*, and never done. The first phase not done is *current*,
  the rest *next*.
- **The view**, `ROADMAP.md` at the root, generated from tracked files and never edited by hand: a line of the
  phases with their states, then per phase its exit boxes and a board, a table with Open, Taken
  and Done columns holding its scopes, each with its specs linked, then Up next, each item with
  its pages. Plain Markdown, so it renders
  anywhere. `jig merge` rewrites it in the merge commit, when states change; after solo work on
  trunk, `jig roadmap --write` rewrites it, and `jig roadmap` says when it is stale.
- **R5** covers both files: they change on trunk only. In a metarepo, M4 lets the hubnode
  commit `ROADMAP.md` on trunk like the rest of jig's bookkeeping. Phases and scopes are the
  owner's plan, not work, so they change on trunk only, and a branch regenerating the view would
  only make merge conflicts. A roadmap change asks for no decision entry and no change line:
  git keeps its history.
- **The hook refuses** a spec whose `Scope:` names a scope trunk's roadmap doesn't have (on
  trunk, the commit's own roadmap), and on trunk a roadmap change that drops or renames a scope
  a spec still takes, naming the spec: re-point it in the same commit.

## Decision log

Every repo keeps one log, `.jig/decisions.md`, which `jig init` writes: what was decided and
why, and what changed, grouped by release. Its format is Keep a Changelog's, plus decision
entries; it opens with two lines saying so, that versions follow SemVer, and what breaking
means here. Then three kinds of section, top to bottom:

- `## Open`: open and proposed decisions. An entry's status changes here in place.
- `## Unreleased`: accepted entries and change lines since the last release.
- `## vX.Y.Z - YYYY-MM-DD`: one per release, newest first, with a plain hyphen.

**A decision entry** is a heading with the id and title, never a status, then a status line,
then a `Touches:` line, then the body: what was decided, why, and what it is not. An entry is
about the product (Documentation, Product and project): a priority order, a delivery queue or
a phase is the roadmap's, never an entry, and an entry names no spec, handoff or scope.

```
### D-012 Store opens graph.sqlite read-only
Accepted (Dave, 2026-11-10). Supersedes D-007.
Touches: docs/store/store.md

When anything but the indexer opens graph.sqlite, it opens it read-only. …
```

**Touches** names the pages the decision rules on, comma-separated, as pointers
(`<repo>/<path>`, `<repo>:<path>`, or a path of this repo's own), each page in either form. A
page is a docs page: under `docs/`, or a file `docmap` names; in a metarepo, a page under
`docs/`. A pararepo names its metarepo's page for anything they share (a product, feature,
principle or concept: `<meta>/docs/<genre>/<page>.md`, read from the cache at the pin) and its
own pages for what is its alone; a metarepo names only its own pages; a repo with neither names
its own docs pages. A bare `docs/…` is always this repo's page: a metarepo named `docs` is
reached as `docs:<path>`. With no cache at the pin, a metarepo pointer is checked for its shape
only, a docs page. Pages are the shared vocabulary, so two repos laying one feature out in
different folders still meet on it. An entry already on trunk with no `Touches:` passes until it
changes, and so do the entries `jig update --merge-log` converts from a register; `jig update`
lists each one to backfill.

**The rule sentence.** The body opens with what the decision rules, as *When <situation>,
<outcome>.*, or *Always, <outcome>.* Two entries that contradict each other govern one
situation with different outcomes, and this sentence is where a reader sees that side by side.
No hook judges it; the review reads it.

**Peers.** Two live entries are peers when their `Touches:` name one page, in either form, or
one names a page above the other's. Peers come from this log; in a pararepo, from the
metarepo's log at the pin; in a metarepo, from each registered pararepo's log on its trunk
(`jig repos`). A log jig can't read (no cache, a cache at another pin than the pin, a pararepo
not found) is named. `jig decision <id> --peers` prints an
entry's peers with their rule sentences. The entry may be in any log read for peers, this one
first; `<repo>/<id>` picks the log when the id is in more than one. In a metarepo, `jig survey` names each of its pages
two pararepos' entries touch while none of its own does: that ruling is probably the
metarepo's.

The status is `Accepted (who, date).`, or under `## Open`, `Open (date).` or `Proposed (date).`.
Only decision entries say who decided. A rejected entry is removed; git and its spec's
Alternatives keep it. A question that binds others gets its entry when it is asked, under
`## Open`, so it can be cited before it is answered.

**Change lines** follow the entries, in Keep a Changelog's groups and order: `### Added`,
`### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`, an empty group
left out. A line is one change, with an area prefix where it has one (`GLOSSARY: Add "vault"`).
A change that is a decision is recorded once, as its entry; the one duplicate allowed is a
`**Breaking:** … (D-007).` pointer in its group.

**What belongs**: a choice that outlives its spec, and any change a reader of the release can
act on. A spec's own Decisions stay with the task, and history stays in git.

**Writing it.** Anyone writing the log writes for anyone deciding whether to take this release:

- Lead with what changes for that reader, in their words, not the code's. One change per line,
  in the imperative or the past tense, the same throughout a section.
- Say what a reader must do when they must do it: a breaking change says what to change, and
  is a major release.
- No commit hashes, file lists or internal names a reader can't act on; link a page by its
  heading instead.
- Deprecate before removing: a removal names the release that deprecated it.
- A yanked release keeps its section, with ` [YANKED]` on its heading and one line under it
  saying why and what to pin instead.

**Ids.** A branch writes `D-?<slug>` (`D-?store-ro`), so no job waits for a number, and pages
can cite it before the merge. `jig merge` numbers each entry the merge brings into the log,
after the highest the log has, in every file the merge changes, with the repo's prefix (a
metarepo's `decision_prefix`, `D-` elsewhere), and lists each number in the merge commit's
message. Only an id with an entry is numbered: the same text with no entry behind it is left
alone. A merge that stops on conflicts numbers them with `jig merge --number`, once they are
resolved and added, before its commit. On trunk an id is a number: M2 refuses a `D-?<slug>`
entry there, and `jig release` refuses to release one.

**Released sections.** The log shows what holds now; git keeps what held before. A reversed
decision is a new accepted entry whose status line ends `Supersedes D-007.`, and the commit
adding it removes D-007's whole block (its heading through the line before the next heading), wherever it
sits, a released section included. A release keeps its change lines: they are what that version
told its readers, and a reversal still goes in the new release's group as a `**Breaking:**`
line. Any other change to a released section is refused, except adding ` [YANKED]` and its
line, and adding or changing an entry's `Touches:` line, which says what the entry is about,
not what it decided (M2 checks its pages); and so is removing an entry no accepted entry supersedes: an open or proposed entry may
name what it would supersede, and retires nothing until it is accepted. The one other removal is
a struck entry, project scope rather than a decision (Documentation: Product and project): the
commit removing it adds, under `## Unreleased` `### Removed`, a line naming its id
(`- D-040: project scope, not a product decision.`). Before the log, a register row struck so
says `struck` in its Status cell, and `--merge-log` leaves it out, its number still taken. `jig decision <id>` prints an
entry and its supersedes chain, newest last; for a removed id it reads the entry from git, with
the commit and release it stood in, and names what holds now. `jig update` lists a superseded
entry an older log still holds, to remove.

**Checked** in every repo, by the hook, whenever a commit touches the log: each entry's status
line and date, an accepted entry's who, supersedes links that resolve (to an entry in the log,
or in trunk's history of it; a shallow clone, which can't say, passes them), one entry per id,
that a release or `## Unreleased` holds accepted entries only, and that an entry added or
changed has a `Touches:` line whose every page is there (M2); and the released sections.
On a branch, the log is judged from where the branch left trunk, as M3 is, so a later commit
may correct an earlier one as their squash would: a section is frozen once trunk has it.
`jig release` renames `## Unreleased` to the version's heading and adds an empty one above it.
A repo that never releases just grows Unreleased.

**Before the log.** A repo whose trunk has no `.jig/decisions.md` yet, a metarepo `jig update`
hasn't moved to it, keeps the rules it had: its register's rows are M2's, M3 asks for a line in
its `CHANGELOG.md`, which any job may add to, and the release writes the version's heading
there (`## vX.Y.Z — YYYY-MM-DD`). Staged decisions land in the register as rows. The log's rules
start with the commit that adds it.

`jig update` lists a root `CHANGELOG.md` and the register as files to review and changes neither
on its own. `jig update --merge-log` shows the log they would make; on the owner's yes,
`--apply --merge-log` writes it and removes both:

- each release section keeps its lines as written, its heading in the log's form, and an
  `## [Unreleased]` is the log's one `## Unreleased`;
- an open or proposed row becomes an entry under `## Open`, keeping who proposed it;
- an accepted row becomes an entry in the oldest release whose lines name its id, ranges
  (`D-029–D-044`) included, or under `## Unreleased` when none does, a row superseded by
  another becoming the one the newer entry supersedes, dated when it was accepted;
- a rejected row is left out, since git keeps it; the log's preamble names its id, so the
  number stays taken;
- a note that names one id joins that entry's body;
- in a metarepo, `entry_files` names the log in place of what was merged; in the board,
  `append_files` and a `reserve` counter over the old files count the log instead, every id
  it names included.

Nothing the owner wrote is dropped. What has no place in the log (a preamble, a note naming
several ids, a section of its own) stays in its old file, which keeps only that, and the run
lists each piece to move by hand. It also lists every file that still names the old ones, to
repoint. A row's words are kept: a decision that opens with a status word goes under a plain
`Decision` heading, and a row with no who says `not recorded`. A who is any text before the
last date, as a row's note was, so every row the old M2 took converts; one it refused is refused
here too, before anything is written. In a metarepo the merge is a change to its files, so it is
a job: run on trunk, `--apply --merge-log` refuses and names `jig open`; in the job's worktree it
writes everything but the board, the job merges like any other, and `--apply --merge-log` on
trunk then rewrites the board (R5). Elsewhere it runs on trunk, board included. The log's rules
judge the change that merges the old files away, one that adds the log and no longer holds
CHANGELOG.md's sections or a register's rows; one that adds a log beside them is still judged by
the old rules, as is everything until trunk has the log. A repo with neither file gets an empty log from `jig update --apply`,
and `jig init` writes none beside them, leaving them for the merge. Numbering, by `jig merge`
or a counter, starts above every id the log has ever named, so a rejected one's is never given
again. A pararepo's bump across the merge reports the register's move on one line, and only the
decisions whose title or status changed.

## Staging

`.jig/staging/` is where a chat drops a file meant for a repo: a spec, a doc, decision entries, a
user story, a feature request, a roadmap change. It is never committed, and nothing in it is decided — read it
for context, never cite it. Each file's header names its `target` (a repo name, or `this`), `kind`, `change`
(`new` or `update`), `destination` inside the target, and `source`. A destination is a bare
path, with no space and no `:`, `,` or `;`: a spec, doc or decisions file whose destination
carries anything else (`.jig/decisions.md, on branch x`, `see docs/x.md`) is refused, never
guessed at. Decisions land only in `.jig/decisions.md`: an open or proposed entry under
`## Open`, an accepted one under `## Unreleased`.

`jig staging resolve <file>` lands it: a new spec or doc is written with its source, new
decision entries are added to the log; an update, a story's or request's spec, or decisions
with other content wait until the work is done and the
source is in it; a file for another repo moves into that repo's staging, found through
`jig repos`. `jig staging drop <file>` deletes it and records nothing: it was never committed.

A batch whose files depend on each other says so in each file's optional `after:` header: the
staged file names it waits for (`a` reads as `a.md`). `jig staging` lists files so each comes after
those it names (name order otherwise), and fails on a cycle, naming its members and the files that
wait on it. A waited-for file that isn't staged is gone: resolved, dropped or forwarded. `resolve`
refuses a file while one it waits for is still staged, naming the cycle if there is one.
`jig staging check <file>…` checks a batch's headers before it is staged, from outside any repo,
and fails on an unknown kind, a missing key, a destination outside the target (absolute, or
climbing out with `..`, as `resolve` judges it), a target `jig repos` doesn't list (case ignored, as
`resolve` matches it), an `after` naming no file in the batch or the target's staging, or a cycle.
A spec resolved new, whose `## Workflow` is empty or missing, gets `jig workflow`'s lines, as
`/jig:spec` writes them; while `jig workflow` refuses, so does `resolve`. `jig repos`, `repos add`
and `repos rename` warn when two names are equal once case and punctuation are dropped, printing
both paths, and `check` warns on a target that has such a twin: a file staged for one lands in the
other. The warning doesn't fail anything, since both may be meant.

A feature request is `kind: feature-request`: the owner's own words for what the product
should do ("I want it to do xyz"), with no required shape. A story names who wants what and
why; a request only describes. Both resolve into a spec carrying their source. Because a
request leaves things undefined, its spec quotes it after the mark
(`Source: … (staged as <file>): "<request>"`), restates it as the Intent (for an update, adds to the amended spec's Intent rather than
replacing it), and lists under that spec's Decisions each thing it filled in that the request didn't say, starting `Interpreted:`, so the owner can correct the reading before the work starts.

A roadmap change is `kind: roadmap`, `change: update`, `destination: .jig/roadmap.md` (any
other change or destination is refused),
whose body says what to add, rename, reorder or drop, and why. Like a story, nothing in it is
decided: the hubnode shows the owner the diff, applies it on trunk on a yes, regenerates
`ROADMAP.md`, and commits with the staged file's `Source: … (staged as <file>)` line in the
message. `resolve` waits until a trunk commit that changed `.jig/roadmap.md` carries that line;
the roadmap itself carries no provenance. A staged root rules file (`AGENTS.md`, `CLAUDE.md`,
`GEMINI.md`), new or an update, resolves the same way, since that file is loaded on every turn:
the line goes in the message of the commit that changed it, on trunk or in a job's merge, never in
the file. A page under `docs/` carries the line itself.

A report on jig itself is `kind: feedback`, staged in the jig repo, whose header also names
`from` (the reporting repo, required) and `jig_version`. When the jig repo isn't in `jig repos`,
it waits in `feedback/` beside the repos list instead; `jig staging` lists that folder too, and
resolves or drops files from it. A report resolves like a story: into a spec carrying its source.

While anything is staged, a report for this repo in that `feedback/` folder included,
`jig release` refuses; `--force` releases anyway and names the staged files in the release
commit. Commits, pushes and gates don't look at staging. A chat needs access to `~/.config/jig/` (where
`jig repos` keeps paths) and then to one repo's `.jig/staging/`; a sweep that skips what the target
already has also reads its `.jig/specs/`, `.jig/roadmap.md` and `.jig/decisions.md`.

## Metarepo and pararepos

A set of repos can share one **metarepo**: docs only — definitions, decisions, conventions, the
contracts the pararepos share (What the metarepo holds). Each **pararepo** (code, firmware,
hardware) cites it at a released tag. The metarepo points; nothing copies it. Three rules do the work:

1. A pararepo writes the metarepo only by branch, via `jig propose`.
2. The metarepo holds no code and no copied pararepo content (What the metarepo holds).
3. Only `jig release` tags, so a pin never names something that failed validation.

**What the metarepo holds.** A claim lives in the metarepo when another repo must agree with it
or build against it: a contract, unless a decision makes a pararepo page its authority; then the
metarepo holds the decision and points to the page. Otherwise a claim lives with its one owner,
and the metarepo points to it (`<repo>/<path> § <section>`) instead of restating it. Each claim
has one home and is stated only there; everywhere else is a pointer. Inside the metarepo, a
decision row and the pages that cite it as their source are one home. A pointer is checked from
the pararepo's side, in what it caches: `jig sync` and its release report each one whose file or
heading (`§`) the pararepo doesn't have, and P2 asks a commit that leaves one dangling for what a
contract change needs. A pointer is `<repo>/<path>` or `<repo>:<path>`, best written in backticks
(`` `app/docs/ui.md § Build (release)` ``): there the section is the span's text, matched whole;
in prose it is any heading the text after `§` begins with. A section that starts with a number,
`2` or `2.1`, names the heading whose leading number is exactly that: `§ 2` is `## 2. Motes`, not `### 2.1`
or `## 20`, and words after the number aren't compared. Headings are compared as read, code
and emphasis marks dropped. The name folds case (`App/…` is `app/…`); the path and heading
don't. A superseded or rejected decision row isn't checked.

The metarepo's decisions are its `.jig/decisions.md` (Decision log), cited as
`<meta>/.jig/decisions.md § D-012`. A superseded entry, and a released section's change lines,
are history: their paths aren't pointers, and this repo's own released lines aren't checked as
citations. `jig sync` and the release say when the pinned release has been yanked, with its
line. A question that binds the pararepos gets its entry under
`## Open` when it is asked, so it can be cited before it is answered; it moves to `Proposed`,
then is accepted (moved to `## Unreleased`) or removed. A reversed decision is a new entry that
supersedes the old, released as a major. A pararepo's own entry that touches a contract cites
its BUFFER row or proposal; once the metarepo accepts it, a new entry here supersedes it and
points to the metarepo's id without restating it.

Each side's gates are on only when its file is on trunk: `.jig/meta.json` or `.jig/para.json`.
`jig init --meta` and `jig init --para <metarepo>` write them; every other command reads them and
does what that kind of repo needs.

**A metarepo's docs tree.** A metarepo's pages are under `docs/`, each in a genre folder:
`docs/<genre>/<name>.md`, or `docs/<genre>/<name>/<name>.md` once it holds more than itself,
with its subsystems below it. A genre is a folder directly under `docs/`, a category of the
ecosystem the metarepo defines (products, features, principles, concepts), so the opposite of a
code repo holds: genre folders are required here, where a code repo's tree names one product's
parts. A genre has no page of its own and adds no depth; its term is a `## <genre>` heading in
`docs/glossary.md`, the one file directly in `docs/`. `meta.json`'s optional `genres` lists them (`jig init --meta --genres
a,b,c`, or `--genres product-ecosystem` for those four); without it, any folder under `docs/`
is one. `jig survey` names a page directly in `docs/`, one in a folder `genres` doesn't declare,
and every other Markdown file outside `docs/` that isn't a root document or a decision register
(a file named `DECISIONS.md`, or holding decision rows), with `docs/<its top folder>/<name>.md`
as where it goes; `/jig:redocument` moves them. `entry_files` never makes a page's home.
There, a claim's source is a decision row or the pararepo file a pointer names; an Invariant's
holder is an accepted decision id; an open question is an `## Open` entry in its log. A dated state
section is checked against the pararepo's trunk and folded into the body or dropped.

`entry_files` in `meta.json` lists what pararepos cite: what a release counts, what M3 asks a
log line for, and what a pararepo caches. Its entries are globs, matched the way `owns`
is: a folder of pages goes in as `docs/**/*.md`, and a new page there needs no edit. Nothing
under `.jig/` counts, whatever the globs say, except `.jig/decisions.md`, which always does.
`jig init --meta` names `.jig/decisions.md` and `docs/glossary.md`, which holds the terms
(Documentation), and writes the glossary. The README is for outsiders and no entry file, so its
prose changes without a log line. A metarepo that hasn't moved its glossary still names
`README.md`, and pararepos cite only its `## Glossary` section: M3 counts a `README.md` change
only there, until the move takes `README.md` out of `entry_files`. A release's term report reads the glossary's terms, headings
and table rows alike, and names each term added, removed or reworded; across the release that
moves a README glossary to `docs/glossary.md`, it reads the older side's README, and names each
term as moved. The move, in a metarepo, runs in a job's worktree (M4), and rewrites
`entry_files` in the same change; a pararepo's `<meta>/README.md § <term>` is named at its pin
bump with the term's new home, `<meta>/docs/glossary.md § <term>`.

| Gate | Refuses |
|---|---|
| M1 | a source file outside `.jig/` in the metarepo |
| M2 | in every repo, a `.jig/decisions.md` entry with a status in its heading, no status line (`Accepted (who, YYYY-MM-DD).`, `Open (YYYY-MM-DD).`, `Proposed (YYYY-MM-DD).`), a supersedes link to no entry in the log or in trunk's history of it, an id used twice, or an open or proposed entry outside `## Open`, or an entry added or changed with no `Touches:` line, or one naming what is no docs page there (Decision log) |
| M3 | an entry file changed without a line or entry in `.jig/decisions.md` (of a `README.md` still listed, only its `## Glossary` section), judged on the branch since it left trunk: a line an earlier commit on the branch added covers this one, and a commit that drops the branch's only line is refused |
| M4 | a commit on trunk that isn't a merge (jig's own files under `.jig/` excepted, but not `.jig/decisions.md`: a decision is reviewed work); a detached HEAD at trunk, or behind it, is trunk |
| M5 | a merge into trunk of a commit `jig reviewed` never recorded. A commit counts as reviewed when a recorded one is its first-parent ancestor and nothing of the job's changed since: handoff notes and the rows they add to `.jig/ledgers/DEFERRED.md` (committed after the review by design) and syncs of trunk that `jig sync` would make don't count. A job's sync of trunk and the gate's scratch merge aren't merges into trunk; a merge on a detached HEAD at trunk, or behind it, is |
| M6 | a subject that doesn't start with the ids it touches (`D-022: …`, `GLOSSARY: …`; on a branch, `D-?store-ro: …`) |
| P1 | an `AGENTS.md` header that differs from what `.jig/para.json` generates |
| P2 | a contract-path change (an edit, a delete, or a rename from one) with none of: a row added or changed in `.jig/ledgers/BUFFER.md` in the same commit, or a spec saying `meta: buffered <row id>`, `meta: <name> proposal <branch>`, `meta: <name> pointers <branch>` or `meta: none — <reason>` (a spec the change touches, or the job's own: the board's `spec`, read as trunk has it, a one-line spec being its own text; in a merge, the one job whose branch tip is what is merged in, or whose own first-parent line holds it, and none for an octopus); the same for a change that deletes or renames a file a cached metarepo pointer names, or the heading its `§` names; a lost file counts even when its heading was already missing. Also, in `BUFFER.md`: a state other than `Open` or `Closed`, a repeated id, an `Open` row deleted, or one closed by any commit but `jig sync`'s |
| P4 | a contract-path change while a file targeting the metarepo is staged |
| P3 | the metarepo's cache (`.jig/meta-cache/`) or its checkout committed into the pararepo |

A fast-forward runs no hook, so a metarepo's release and its pre-push re-check every
first-parent commit since the last release, and refuse any tag `jig release` didn't make: one
whose `.jig/decisions.md` has no heading for it, unless it was made before the log and the
`CHANGELOG.md` that tag holds has the heading the release wrote then.
Pre-push judges the commit pushed to the remote's trunk, which may not be the local trunk's;
a chained `pre-push.local` hook gets the same pushed refs.
In a metarepo the release needs no `release.sh` steps, and defaults to `--minor`: minor for additions and clarifications, major
for a rename or a reversed decision. A pararepo pins a release, never `main`, and bumps it in
a commit of its own, `meta: <name> v0.3.0 → v0.4.0`, with the report `jig sync` prints on its
trunk as the body: each decision id and glossary term that changed, and each entry file the new
release moved (`<old> (now <new>)`) or removed (`<old> (removed)`), with every file here that
uses it, specs and ledgers included. A two-part pin (`v0.3`), from before releases had three parts, keeps
working: it sorts below `v0.3.0`. `jig gate` refuses a job whose spec cites a proposal that isn't in
the pinned release, and one whose `pointers` branch isn't on the metarepo it names (one merged
into its trunk counts, released or not), or names another metarepo; a metarepo it can't reach
refuses too.

**Pointers ahead of the metarepo.** `meta: <name> pointers <branch>` (`jig propose --pointers`)
means the metarepo's pointers into this change are being rewritten on that metarepo branch, and
no metarepo claim changes. A job answered that way merges without waiting for the release:
cached pointers dangle against the pending branch until the pin moves, and `jig sync` and the
release report them meanwhile. A claim change is a `BUFFER.md` row; a dependency on a metarepo
change is `proposal <branch>`, which the gate waits for. P2 can't tell a pointer move from a claim
change, so review holds a `pointers` spec to this sentence.

**The sync buffer.** A pararepo may work ahead of its metarepo: change what a metarepo claim
describes, as often as testing needs, and commit and push each change. Every such difference
is a row in `.jig/ledgers/BUFFER.md` (the first row creates it from jig's ledger template): the
claim at the pin, what this repo does now, who decided, and a state, `Open` or `Closed`. A change
of mind edits the row. `jig release` in the pararepo, before its build, puts every `Open` row
no proposal carries yet, as it stands, into one metarepo proposal (`jig propose --buffer`, also
run by hand): one branch, and a spec here that lists and copies the rows under `## Buffer rows`.
A row edited after it was proposed goes again in the next one. When the metarepo releases a
proposal, `jig sync` on the pararepo's trunk makes the pin commit itself: it moves the pin to
that release and marks `Closed` the rows the proposal carried that are unchanged since, in one
commit `meta: <name> v0.3.0 → v0.4.0` (or, when the pin already holds the release, `meta:
<name> v0.4.0: close B1`). Rows added or edited after the proposal stay `Open` for the next one.
`jig sync` also names each file here that a decision at the pin cites and `contract_paths`
doesn't cover. A path under a folder counts bare or after this repo's name; a root file every
repo has (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `README.md`, `CHANGELOG.md`) counts only after
this repo's name, since named bare it is about every repo. A decision may cite this repo by name in any case (`App/docs/ui.md`); the path
after it is exact. The line asks: the hubnode puts it to the owner with what the decision says,
and adds the path only if the decision describes something this repo can change there.

**Citing the metarepo.** A pararepo cites the metarepo the way the metarepo points to it:
`<meta>/<path>` (or `<meta>:<path>`), with `§ <section>` for a heading, matched as above. On
every run, `jig sync` and the release name each citation in this repo's tracked files, specs and
ledgers included, whose file or heading the pin doesn't have, and each bare path that names an
entry file at the pin and no file here, as `write it as <meta>/<path>`. Handoffs and `Closed`
BUFFER rows are left out: they cite the pin they were written at. Reported; nothing refuses.

Two rules for the metarepo's own pages:

- **Newer wins.** A later decision, or a pararepo page a decision makes the authority, overrides
  older page text it contradicts, whether or not that text is marked Accepted. The update changes
  the claim where it lives (What the metarepo holds); when the home is a pararepo, it already
  says it, and the metarepo points. Any restatement elsewhere becomes a pointer to the home. Only
  when the claim lives in the metarepo does the update give the new text, on the decision and the
  pages that cite it as their source; it keeps an old "Accepted (who, date)" only on what it
  still covers. A decision changes only when the stale claim is one: the newer entry supersedes
  it, and the old entry is removed (Decision log, Released sections). A pararepo citing the
  removed id hears of it at its next pin bump, with the successor named. A page update needs no new sign-off: the decision behind it is
  already the owner's.
- **Every copy.** A metarepo spec that changes a claim lists every place that states it, found
  by meaning, not only by its words, and its done-when covers each one: the claim's home is
  updated (a decision and the pages citing it as their source; when the home is a pararepo, it
  already says it, and the metarepo points), and every other place becomes a pointer to it.

## Release

`jig release` runs the repo's own protocol. On trunk, with a clean tree and nothing staged, it
runs `.jig/scripts/check.sh`, then `.jig/scripts/release.sh <version>`: the build and the version
bump, which only the repo knows how to do. It commits the tracked files the script changed,
checks that each glob in `release.artifacts` matched a file, turns `## Unreleased` in
`.jig/decisions.md` into `## vX.Y.Z - YYYY-MM-DD` with an empty one above it, and tags
`vX.Y.Z`. A failure puts the tracked files back and tags nothing. The version is the last tag
bumped by `--patch` (the default), `--minor` or `--major`; the first is `--version X.Y.Z`, or
`--minor` (0.1.0) or `--major` (1.0.0).

In a plain repo, until `release.sh` has steps and `config.json` names its artifacts, the release
refuses and points to `/jig:release`, which asks what the repo builds and ships. A metarepo and
a pararepo release with defaults: steps and artifacts are optional (any that are given still run
and must match), and jig's own checks run before the tag. A metarepo's are its history checks
(above). A pararepo's refuse when the metarepo can't be reached (`jig repos add meta`), when the
pin isn't one of its releases (`main`, a hand-made tag), when the `AGENTS.md` header isn't the
generated one (P1), when `.jig/meta-cache/` is tracked (P3), or when a `BUFFER.md` row is neither
Open nor Closed or shares its id (P2); a newer metarepo release, a cited path outside
`contract_paths`, or a metarepo pointer to a file or heading this repo doesn't have, is reported as `jig sync` reports it and refuses nothing. Then the release
settles the sync buffer (above).

After the tag, the release runs `.jig/scripts/publish.sh <version> <artifact>…`: what the repo
sends out (a push, a hosted release, a store upload), with the files this run built as paths
from the repo root. While the script still holds its `# TODO: publish steps.` line, the
publish isn't decided yet: jig skips it and prints the push command. A repo that publishes
nothing deletes the line. A publish that fails leaves the tag, which may already be pushed:
jig prints the command to run it again and exits 1.

## Commands

```
jig init [--trunk main]     config.json, jobs.json, git hooks
jig init --meta | --para <metarepo> --contract <globs>   ... as a metarepo / pararepo
jig release [--major|--minor|--patch|--version X.Y.Z] [--force]   the repo's release protocol, then tag, then publish
jig survey [--json] [--levels]   inventory the repo against the jig shape; --levels: each page's level and its evidence
jig update [--apply]        bring the repo to the current jig layout, and carry out the moves findings approves (dry run without --apply)
jig update [--apply] --merge-log   on the owner's yes: CHANGELOG.md and the register into .jig/decisions.md
jig update [--apply] --sweep   on the owner's yes: pages' ## Undefined entries to ## Up next in .jig/roadmap.md
jig update [--apply] --glossary   on the owner's yes: the README's glossary, or GLOSSARY.md, to docs/glossary.md, its pointers rewritten
jig staging [resolve|drop <file>]   list staged files, or land / drop one
jig repos [add repo|meta|para | rename <new>]  where your repos live (user config)
jig open ... --reserve K    allocate scarce counter K to this job
jig reserve <job> <K>       hubnode: give an open job the next number of counter K too
jig reading-list <paths>    what to read before touching these files, and the pages above
jig install-hooks           rewrite the hooks
jig status                  jobs, states, distance from trunk, dirt
jig open <name> --spec … --owns … --shares … --after … --reserve schema
jig mark <name> <state>     claimed|building|ready|gated|parked
jig merge <name> [-m msg] [--subject text]   merge a job, numbering its D-?<slug> ids; its entry is deleted in the merge commit
jig merge --number          in a merge stopped on conflicts, once resolved: number the ids it brings in, then setup.sh and derive.sh
jig check [--staged]        run the rules here
jig job                    this branch's manifest
jig decision <id>           a decision entry and its supersedes chain
jig sync                    merge trunk in, append rule applied; on a pararepo's trunk, the metarepo
jig reviewed [--tier N --effort N] [--ran text]   record that HEAD has been reviewed, and at what
jig workflow                each step's model tier and effort in effect
jig handoff [--spec path] [--partial]   write the note for HEAD; --partial: it doesn't finish the spec
jig roadmap [--write]       the roadmap's states on trunk; --write regenerates ROADMAP.md
jig gate <name>             hubnode: verify, set up the scratch checkout, print its check
jig propose <spec> <slug>   pararepo: open a proposal branch on the metarepo
jig propose <spec> <slug> --pointers  the same, recorded as pointer rewrites worked ahead of
jig propose --buffer [slug]  pararepo: every Open row of the sync buffer, in one proposal
```

## Hooks are opt-in per checkout

`jig install-hooks` writes `.git/jig/enabled`. Anything outside this repo that hooks into
your editor or agent runs this repo's `.jig/scripts/` only when that marker exists; `.git/` is never
cloned, so a fetched repo cannot enable itself.
