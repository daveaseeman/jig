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
changes: `trunk`, `common`, `append_files`, `reserve`, `docmap`, `not_docs`, `release`,
`reference_files` and the layout's `version`. `.jig/jobs.json` holds the open jobs, nothing else. Per job:

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

**A bug in `.jig/jig.py`, `.jig/RULES.md` or a skill is the tool's, not this repo's.** Run `/jig:feedback`, then
park the job or ask the hubnode. Don't patch them; don't ledger it.

## Keeping merges mechanical

Conventions so two jobs rarely meet in one hunk:

- Append, never edit, shared prose. A change to someone else's section is a note in yours.
- A file of one's own: new routes in your own handler registered by one line; new state in
  your own module; new tests in your own file; a new fixture as a new file.
- Scarce numbers come from the board (`--reserve`, `jig reserve`), never from looking at what seems free.
  Two branches that both take migration 17 corrupt the first database that runs both.

## Reserved numbers

Some things are scarce across the whole repo: migration step numbers, section numbers in a
shared document, anything a runner stores and compares. Each counter in `config.json` says how
to find its numbers:

```json
"reserve": {
  "section": {"pattern": "^### (\\d+)\\.\\d+", "files": ["docs/**/*.md"]},
  "schema": {"pattern": "SCHEMA_VERSION\\s*=\\s*(\\d+)", "files": ["**/storage.py"], "unique": true}
}
```

A number is taken where trunk had no match for it, in any of the counter's files, and the
change adds one. So `### 31.2` under a section 31 that trunk has takes nothing, and `### 32.1`
takes section 32. `"unique": true` is for numbers that must also appear once: a second
`SCHEMA_VERSION = 17` where trunk has one is refused as "17 already exists". It is off unless
set, because a section number appears once per rule under it. It applies working alone too,
with no job open: there is nobody to take a number from, but a second 17 still breaks.

A section's rule numbers (`### 31.2`) belong to whoever holds the section. R6 counts whole
numbers, so within a section trunk already has, nothing stops two jobs adding the same rule
number: give each job its own section, or settle it at the merge.

`--reserve <counter>` hands the job max(the highest on trunk, the highest an open job
holds) + 1, so two jobs open at once never get the same number. `jig reserve <job> <counter>`
hands an open job another by the same rule; it then holds a list. Nothing stores a "next":
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

Only `docs/hardware/<board>.md` is a board page. The files a page leans on have two homes
beside it: `docs/hardware/components/<part>/`, one folder per part with its datasheets and
notes, shared by every board that uses the part; and `docs/hardware/<board>/`, one board's
files that aren't its page (a schematic, a snapshot of its definition). The page's Components
table links each datasheet with its source URL, the date it was retrieved and the first 12
hex digits of its sha256, so a check names the exact document it was made against. Whether
the binaries are committed is the repo's call, `reference_files` in the config: `commit`, or
`ignore` with `docs/hardware/*/**/*.[pP][dD][fF]` in `.gitignore`, covering both homes, and
the URL and hash on the page to fetch it again. `jig survey` reports a component file no board page links, and a link
to one that doesn't exist.

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
2. **The hubnode gates.** `jig gate <job>` refuses on R8 and on a missing note. Then it sets
   up a **detached scratch checkout of the commit the note names**, with trunk merged in the
   way `jig sync` merges it, and prints the check to run there and the cleanup. It never runs
   the check: whoever runs it runs the same command. Never the job's live worktree, which the
   subnode may still be building in.
   The hooks set that checkout up with `.jig/scripts/setup.sh`, when it is added and again
   after its merge of trunk, so the checks run in an environment built from the job's own
   manifests.
   That means a merge runs the merged-in `setup.sh`: review a change to it like any other
   code, because the next merge executes it.
3. **The hubnode merges** with `jig merge <job>`, which deletes the job's entry in the merge
   commit itself, then syncs the clean jobs. A job synced since its note still merges: only
   the job's own commits count as changes since the check, and what a sync's resolution
   carries beyond what `jig sync` would make of it (this replay needs git 2.38 or later).
   Either refuses until it is handed off again. A job that wasn't synced and conflicts with
   trunk in an `append_files` file is refused with "`jig sync` the job, then merge": the sync
   resolves the appends as the gate did and stops on anything else. A job whose only
   conflicts were appends needs no new handoff after it. What the merge touched in shared files goes in that commit's message (`-m`).
   `--subject <ids>` is the ids the subject leads with, e.g. `D-001, D-002`, for a repo whose
   subjects lead with ids: the subject becomes `<ids>: merge <job>`. `: merge <job>` is added
   unless the text already ends with it, so pass the ids and don't write the merge yourself.

## Workflow

The hubnode writes specs, talks with the owner and decides. The work goes to sessions it
starts, each at a model tier and an effort the owner set, never one a model picks for
itself.

| Step | Who | Tier | Effort | An override must keep |
|---|---|---|---|---|
| `spec`: spec, decide, retro, hardware page | hubnode | 2 | 2 | — |
| `execute`: execute, fix | a subnode it starts | 2 | 3 | tier no better than spec's; effort lower |
| `review` | a subnode, always a fresh context | 2 | 1 | tier no worse than spec's; effort higher |
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

## Staging

`.jig/staging/` is where a chat drops a file meant for a repo: a spec, a doc, decision rows, a
user story. It is never committed, and nothing in it is decided — read it for context, never
cite it. Each file's header names its `target` (a repo name, or `this`), `kind`, `change`
(`new` or `update`), `destination` inside the target, and `source`. A destination is a bare
path, with no space and no `:`, `,` or `;`: a spec, doc or decisions file whose destination
carries anything else (`docs/DECISIONS.md, on branch x`, `see docs/x.md`) is refused, never
guessed at. In a metarepo, decisions land only in a register `entry_files` names.

`jig staging resolve <file>` lands it: a new spec or doc is written with its source; an
update, a story's spec, or decisions with other content wait until the work is done and the
source is in it; a file for another repo moves into that repo's staging, found through
`jig repos`. `jig staging drop <file>` deletes it and records nothing: it was never committed.

A report on jig itself is `kind: feedback`, staged in the jig repo, whose header also names
`from` (the reporting repo, required) and `jig_version`. When the jig repo isn't in `jig repos`,
it waits in `feedback/` beside the repos list instead; `jig staging` lists that folder too, and
resolves or drops files from it. A report resolves like a story: into a spec carrying its source.

While anything is staged, a report for this repo in that `feedback/` folder included,
`jig release` refuses; `--force` releases anyway and names the staged files in the release
commit. Commits, pushes and gates don't look at staging. A chat needs access to `~/.config/jig/` (where
`jig repos` keeps paths) and then to one repo's `.jig/staging/`, nothing more.

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
decision row and the pages that cite it as their source are one home.

A question that binds the pararepos gets its decision row when it is asked, with status
`open`, so it can be cited before it is answered. The same row then moves to `proposed`, then
`accepted` or `rejected`; a reversed decision is marked `superseded` (or `rejected`, when an accepted one is withdrawn)
and released as a major.

Each side's gates are on only when its file is on trunk: `.jig/meta.json` or `.jig/para.json`.
`jig init --meta` and `jig init --para <metarepo>` write them; every other command reads them and
does what that kind of repo needs.

`entry_files` in `meta.json` lists what pararepos cite: what a release counts, what M3 asks a
changelog line for, and what a pararepo caches. Its entries are globs, matched the way `owns`
is: a folder of pages goes in as `docs/**/*.md`, and a new page there needs no edit. Nothing
under `.jig/` counts, whatever the globs say.

| Gate | Refuses |
|---|---|
| M1 | a source file outside `.jig/` in the metarepo |
| M2 | a decision row (`| D-001 | … |`) without a status cell (open, proposed, accepted, superseded or rejected, optionally with a note in parentheses or `by D-…`) and a `YYYY-MM-DD` date |
| M3 | an entry file changed without a line in `CHANGELOG.md`, judged on the branch since it left trunk: a line an earlier commit on the branch added covers this one, and a commit that drops the branch's only line is refused |
| M4 | a commit on trunk that isn't a merge (jig's own files under `.jig/` excepted); a detached HEAD at trunk, or behind it, is trunk |
| M5 | a merge into trunk of a commit `jig reviewed` never recorded. A commit counts as reviewed when a recorded one is its first-parent ancestor and nothing of the job's changed since: handoff notes (committed after the review by design) and syncs of trunk that `jig sync` would make don't count. A job's sync of trunk and the gate's scratch merge aren't merges into trunk; a merge on a detached HEAD at trunk, or behind it, is |
| M6 | a subject that doesn't start with the ids it touches (`D-022: …`, `GLOSSARY: …`) |
| P1 | an `AGENTS.md` header that differs from what `.jig/para.json` generates |
| P2 | a contract-path change with none of: a row added or changed in `.jig/ledgers/BUFFER.md` in the same commit, or a spec saying `meta: buffered <row id>`, `meta: <name> proposal <branch>` or `meta: none — <reason>`. Also, in `BUFFER.md`: a state other than `Open` or `Closed`, a repeated id, an `Open` row deleted, or one closed by any commit but `jig sync`'s |
| P4 | a contract-path change while a file targeting the metarepo is staged |
| P3 | the metarepo's cache (`.jig/meta-cache/`) or its checkout committed into the pararepo |

A fast-forward runs no hook, so a metarepo's release and its pre-push re-check every
first-parent commit since the last release, and refuse any tag `jig release` didn't make.
Pre-push judges the commit pushed to the remote's trunk, which may not be the local trunk's;
a chained `pre-push.local` hook gets the same pushed refs.
In a metarepo the release also turns `## Unreleased` into the version's heading, needs no
`release.sh` steps, and defaults to `--minor`: minor for additions and clarifications, major
for a rename or a reversed decision. A pararepo pins a release, never `main`, and bumps it in
a commit of its own, `meta: <name> v0.3.0 → v0.4.0`, with the report `jig sync` prints on its
trunk as the body. A two-part pin (`v0.3`), from before releases had three parts, keeps
working: it sorts below `v0.3.0`. `jig gate` refuses a job whose spec cites a proposal that isn't in
the pinned release.

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
doesn't cover; adding it is the hubnode's call. A decision may cite this repo by name in any
case (`App/docs/ui.md`); the path after it is exact.

Two rules for the metarepo's own pages:

- **Newer wins.** A later decision, or a pararepo page a decision makes the authority, overrides
  older page text it contradicts, whether or not that text is marked Accepted. The update changes
  the claim where it lives (What the metarepo holds); when the home is a pararepo, it already
  says it, and the metarepo points. Any restatement elsewhere becomes a pointer to the home. Only
  when the claim lives in the metarepo does the update give the new text, on the decision and the
  pages that cite it as their source; it keeps an old "Accepted (who, date)" only on what it
  still covers. A decision row changes only when the stale claim is one: it is marked
  `superseded by` the newer. A page update needs no new sign-off: the decision behind it is
  already the owner's.
- **Every copy.** A metarepo spec that changes a claim lists every place that states it, found
  by meaning, not only by its words, and its done-when covers each one: the claim's home is
  updated (a decision and the pages citing it as their source; when the home is a pararepo, it
  already says it, and the metarepo points), and every other place becomes a pointer to it.

## Release

`jig release` runs the repo's own protocol. On trunk, with a clean tree and nothing staged, it
runs `.jig/scripts/check.sh`, then `.jig/scripts/release.sh <version>`: the build and the version
bump, which only the repo knows how to do. It commits the tracked files the script changed,
checks that each glob in `release.artifacts` matched a file, and tags `vX.Y.Z`. A
failure puts the tracked files back and tags nothing. The version is the last tag bumped by
`--patch` (the default), `--minor` or `--major`, or `--version X.Y.Z` for the first.

In a plain repo, until `release.sh` has steps and `config.json` names its artifacts, the release
refuses and points to `/jig:release`, which asks what the repo builds and ships. A metarepo and
a pararepo release with defaults: steps and artifacts are optional (any that are given still run
and must match), and jig's own checks run before the tag. A metarepo's are its history checks
(above). A pararepo's refuse when the metarepo can't be reached (`jig repos add meta`), when the
pin isn't one of its releases (`main`, a hand-made tag), when the `AGENTS.md` header isn't the
generated one (P1), when `.jig/meta-cache/` is tracked (P3), or when a `BUFFER.md` row is neither
Open nor Closed or shares its id (P2); a newer metarepo release, or a cited path outside
`contract_paths`, is reported as `jig sync` reports it and refuses nothing. Then the release
settles the sync buffer (above).

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
jig reserve <job> <K>       hubnode: give an open job the next number of counter K too
jig reading-list <paths>    what to read before touching these files
jig install-hooks           rewrite the hooks
jig status                  jobs, states, distance from trunk, dirt
jig open <name> --spec … --owns … --shares … --after … --reserve schema
jig mark <name> <state>     claimed|building|ready|gated|parked
jig merge <name> [-m msg] [--subject text]   merge a job; its entry is deleted in the merge commit
jig check [--staged]        run the rules here
jig job                    this branch's manifest
jig sync                    merge trunk in, append rule applied; on a pararepo's trunk, the metarepo
jig reviewed [--tier N --effort N] [--ran text]   record that HEAD has been reviewed, and at what
jig workflow                each step's model tier and effort in effect
jig handoff [--spec path]   write the note for HEAD
jig gate <name>             hubnode: verify, set up the scratch checkout, print its check
jig propose <spec> <slug>   pararepo: open a proposal branch on the metarepo
jig propose --buffer [slug]  pararepo: every Open row of the sync buffer, in one proposal
```

## Hooks are opt-in per checkout

`jig install-hooks` writes `.git/jig/enabled`. Anything outside this repo that hooks into
your editor or agent runs this repo's `.jig/scripts/` only when that marker exists; `.git/` is never
cloned, so a fetched repo cannot enable itself.
