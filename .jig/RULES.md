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
changes: `trunk`, `common`, `append_files`, `reserve`, `docmap`, `not_docs`, `release` and the
layout's `version`. `.jig/jobs.json` holds the open jobs, nothing else. Per job:

| Key | Meaning |
|---|---|
| `spec` | its spec: a path under `.jig/specs/`, or one line |
| `state` | claimed → building → ready → gated (or parked) |
| `after` | jobs this one is gated behind |
| `owns` | existing files only this job may change while it is open |
| `shares` | existing files it may change alongside others |
| `reserved` | scarce numbers handed out centrally (migration steps, section numbers) |

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

Checked before every commit by a git hook, and by `jig check`.

- **R1** The trunk checkout stays on trunk. Work in `.git/jig/worktrees/<branch>`.
- **R2** A job is built in its own worktree.
- **R3** A job changes only its `owns`, its `shares`, `common`, or files new to the repo.
- **R4** Another open job's `owns` is refused even if this job also lists it.
- **R5** The board is the hubnode's: `config.json` and `jobs.json` are edited on trunk only.
- **R6** A scarce number belongs to the one job that reserved it. A change that makes a
  number matching a counter's `pattern` exist where trunk had none, and the branch doesn't
  hold it, is refused; merging a job takes the numbers it holds. Editing or moving an existing
  heading takes nothing. Two branches that each take migration step 17 corrupt the first
  database that runs both.
- **R7** A change adding a `WORKAROUND:` comment to code must stage `.jig/ledgers/WORKAROUNDS.md` too;
  its first row creates the file. jig's own `jig.py` quotes the marker and is not checked.
  Prose may quote the marker.
- **R8** A job is gated only after the jobs in its `after` have merged.

**The hooks run trunk's copy of `jig.py`** (`git show <trunk>:.jig/jig.py`). A branch
cannot weaken the rules it is judged by, and a stale checkout is still judged by today's rules.
While a merge of trunk is being finished, a change is judged against trunk, so what trunk
brought in is not the job's.

**A bug in `.jig/jig.py`, `.jig/RULES.md` or a skill is the tool's, not this repo's.** Run `/jig:feedback`, then
park the job or ask the hubnode. Don't patch them; don't ledger it.

## Keeping merges mechanical

Conventions so two jobs rarely meet in one hunk:

- Append, never edit, shared prose. A change to someone else's section is a note in yours.
- A file of one's own: new routes in your own handler registered by one line; new state in
  your own module; new tests in your own file; a new fixture as a new file.
- Scarce numbers come from the board (`--reserve`), never from looking at what seems free.
  Two branches that both take migration 17 corrupt the first database that runs both.

## Reserved numbers

Some things are scarce across the whole repo: migration step numbers, section numbers in a
shared document, anything a runner stores and compares. Each counter in `config.json` says how
to find its numbers:

```json
"reserve": {
  "schema": {"pattern": "SCHEMA_VERSION\\s*=\\s*(\\d+)", "files": ["**/storage.py"]}
}
```

`--reserve <counter>` hands the job max(the highest on trunk, the highest an open job
holds) + 1, so two jobs open at once never get the same number. Nothing stores a "next":
the files say what is taken, and a counter without `pattern` and `files` is refused.

A job holding step N lists the job holding N−1 in `after`, so they merge in order: a
database already past a number never runs a step of that number that merges later.

## Documentation

One page per system, `docs/<system>/<system>.md`. A subsystem's page sits in a folder of its
own inside its system's, `docs/<system>/<subsystem>/<subsystem>.md`, and its parts nest the
same way. Every page is named for its folder, so the path alone says what it covers. The tree
names the product's own parts, not its files, so a rule that touches several files lives
once. Every page has three headings:

- **Now** — what is true on trunk today.
- **Rules** — what binds, as if the text stood in `AGENTS.md`; that is how the always-loaded
  file stays under 40 lines. Number every rule; the number is the heading (`### 31.1 …`), so
  a citation resolves by search wherever the text moves.
- **Checks** — one line per rule naming what holds it: a named test, "review", or "on screen".

When Now and Rules disagree, Rules wins and Now gets fixed. A moved rule leaves no forwarding
address behind — that is history, and git keeps it.

In `docmap`, a subsystem's page names its own files and its system's page names the rest:
fold-in asks every page that covers a changed file, so a system page whose globs reach into
its subsystems is asked about every change made in them.

A **seam** page covers what crosses between two systems: in `docmap`, a page whose globs name
files from both sides. `jig reading-list <files>` prints which pages to read before touching
those files.

A repo that builds for boards has one page per board, `docs/hardware/<board>.md`, made from
jig's board template (`/jig:hardware`) out of a hardware definition and checked against the
code. A `docmap` entry ties each page to the code that targets its board, so every handoff
that changes that code asks whether the page still matches. Code that runs on a board does
not pass the gate without a page that matches it; for that code, "no page needed" is not an
answer.

## Fold-in

Code and the page that documents it move together, or the page starts lying. `jig handoff`
works out every documentation page that covers a file the branch changed — a file can have
several, such as its system page and the page of the board it runs on — and writes a
checklist into the note. `jig gate` refuses while a line is unanswered — each is either
ticked as updated, or says why no change was needed.

Ownership comes from `docmap` in `config.json`:

```json
"docmap": {"docs/storage/storage.md": ["server/storage.py", "server/migrations/**"]}
```

`docmap` can name any file, config such as `sdkconfig` included; a page is asked about
whenever a file it names changes. A changed source file nothing covers is listed as
`UNOWNED` — add it to `docmap`, or answer why it needs no page.

## Sync

`jig sync` merges trunk in. A conflict in an `append_files` file where **both sides only
added at the same spot** is resolved automatically: trunk's lines, then the job's. Anything
else stops with the files named, and a person resolves it.

## Handoff, gate, merge

1. **The subnode hands off.** Runs the checks, has the diff adversarially reviewed, records it
   (`jig reviewed`), then `jig handoff` writes a note naming that exact commit. Fill every
   heading, commit the note with the work, tell the hubnode the job and the commit.
   A job may hand off several times.
2. **The hubnode gates.** `jig gate <job>` refuses on R8 and on a missing note. Then it runs the checks **against the commit the note names, in a detached
   scratch checkout** — never the job's live worktree, which the subnode may still be building in.
   The hooks set that checkout up with `.jig/scripts/setup.sh`, when it is added and again
   after its merge of trunk, so the checks run in an environment built from the job's own
   manifests.
   That means a merge runs the merged-in `setup.sh`: review a change to it like any other
   code, because the next merge executes it.
3. **The hubnode merges** with `jig merge <job>`, which deletes the job's entry in the merge
   commit itself, then syncs the clean jobs. What the merge touched in shared files goes in
   that commit's message (`-m`).

## Staging

`.jig/staging/` is where a chat drops a file meant for a repo: a spec, a doc, decision rows, a
user story. It is never committed, and nothing in it is decided — read it for context, never
cite it. Each file's header names its `target` (a repo name, or `this`), `kind`, `change`
(`new` or `update`), `destination` inside the target, and `source`.

`jig staging resolve <file>` lands it: a new spec or doc is written with its source; an
update, a story's spec, or decisions with other content wait until the work is done and the
source is in it; a file for another repo moves into that repo's staging, found through
`jig repos`. `jig staging drop <file>` deletes it and records nothing: it was never committed.

While anything is staged, `jig release` refuses; `--force` releases anyway and names the staged
files in the release commit. Commits, pushes and gates don't look at staging. A chat needs access to `~/.config/jig/` (where
`jig repos` keeps paths) and then to one repo's `.jig/staging/`, nothing more.

## Metarepo and pararepos

A set of repos can share one **metarepo**: docs only — definitions, decisions, conventions.
Each **pararepo** (code, firmware, hardware) cites it at a released tag. The metarepo points;
nothing copies it. Three rules do the work:

1. A pararepo writes the metarepo only by branch, via `jig para-propose`.
2. The metarepo holds no code and no copied pararepo content.
3. Only `jig release` tags, so a pin never names something that failed validation.

A question that binds the pararepos gets its decision row when it is asked, with status
`open`, so it can be cited before it is answered. The same row then moves to `proposed`, then
`accepted` or `rejected`; a reversed decision is marked `superseded` and released as a major.

Each side's gates are on only when its file is on trunk: `.jig/meta.json` or `.jig/para.json`.
`jig init --meta` and `jig init --para <metarepo>` write them; every other command reads them and
does what that kind of repo needs.

| Gate | Refuses |
|---|---|
| M1 | a source file outside `.jig/` in the metarepo |
| M2 | a decision row (`| D-001 | … |`) without a status cell (open, proposed, accepted, superseded or rejected, optionally with a note in parentheses or `by D-…`) and a `YYYY-MM-DD` date |
| M3 | an entry file changed without a line in `CHANGELOG.md` |
| M4 | a commit on trunk that isn't a merge (jig's own files under `.jig/` excepted) |
| M5 | a merge of a commit `jig reviewed` never recorded |
| M6 | a subject that doesn't start with the ids it touches (`D-022: …`, `GLOSSARY: …`) |
| P1 | an `AGENTS.md` header that differs from what `.jig/para.json` generates |
| P2 | a contract-path change with no spec saying `meta: <name> proposal <branch>` or `meta: none — <reason>` |
| P4 | a contract-path change while a file targeting the metarepo is staged |
| P3 | the metarepo's cache (`.jig/meta-cache/`) or its checkout committed into the pararepo |

A fast-forward runs no hook, so a metarepo's release and its pre-push re-check every
first-parent commit since the last release, and refuse any tag `jig release` didn't make.
In a metarepo the release also turns `## Unreleased` into the version's heading, needs no
`release.sh` steps, and defaults to `--minor`: minor for additions and clarifications, major
for a rename or a reversed decision. A pararepo pins a release, never `main`, and bumps it in
a commit of its own, `meta: <name> v0.3.0 → v0.4.0`, with `para-sync`'s report as the body.

## Release

`jig release` runs the repo's own protocol. On trunk, with a clean tree and nothing staged, it
runs `.jig/scripts/check.sh`, then `.jig/scripts/release.sh <version>`: the build and the version
bump, which only the repo knows how to do. It commits the tracked files the script changed,
checks that each glob in `release.artifacts` matched a file, and tags `vX.Y.Z`. A
failure puts the tracked files back and tags nothing. The version is the last tag bumped by
`--patch` (the default), `--minor` or `--major`, or `--version X.Y.Z` for the first.

Until `release.sh` has steps and `config.json` names its artifacts, the release refuses and points
to `/jig:release`, which asks what the repo builds and ships.

## Commands

```
jig init [--trunk main]     config.json, jobs.json, git hooks
jig init --meta | --para <metarepo> --contract <globs>   ... as a metarepo / pararepo
jig release [--major|--minor|--patch|--version X.Y.Z] [--force]   the repo's release protocol, then tag
jig survey [--json]         inventory the repo against the jig shape
jig update [--apply]        bring the repo to the current jig layout (dry run without --apply)
jig staging [resolve|drop <file>]   list staged files, or land / drop one
jig repos [add repo|meta|para | rename <new>]  where your repos live (user config)
jig open ... --reserve K    allocate scarce counter K to this job
jig reading-list <paths>    what to read before touching these files
jig install-hooks           rewrite the hooks
jig status                  jobs, states, distance from trunk, dirt
jig open <name> --spec … --owns … --shares … --after … --reserve schema
jig mark <name> <state>     claimed|building|ready|gated|parked
jig merge <name> [-m msg]   merge a job; its entry is deleted in the merge commit
jig check [--staged]        run the rules here
jig job                    this branch's manifest
jig sync                    merge trunk in, append rule applied
jig reviewed                record that HEAD has been reviewed
jig handoff [--spec path]   write the note for HEAD
jig gate <name>             hubnode: verify, then print the gate commands
jig para-sync / para-propose   pararepo: refresh and report / propose
```

## Hooks are opt-in per checkout

`jig install-hooks` writes `.git/jig/enabled`. Anything outside this repo that hooks into
your editor or agent runs this repo's `.jig/scripts/` only when that marker exists; `.git/` is never
cloned, so a fetched repo cannot enable itself.
