# Lanes: parallel work on one repository

Several sessions change this repo at once. This is how they stay out of each other's way.

**"Lane" is this tool's word for a composite that has no single industry name.** In standard
terms, a lane is a *topic branch*, its *git worktree*, and a *CODEOWNERS-style* claim on files
that lasts for the life of one piece of work. A handoff is a *pull request*; the gate is a
*merge queue* with *branch protection*. The **hubnode** is what others call the *team lead*,
*orchestrator*, or *manager*; a **subnode** is a *teammate* or *worker*. If you already run any of those, you already run most
of a lane — `jig survey` names what you have and what it maps to.

## Roles

- **The hubnode** is one session. It owns the trunk branch, the board, the worktrees, and
  the merges. It opens lanes, gates handoffs, merges. It builds no feature.
- **A subnode** is every other session. One lane each: its branch, its worktree, its files.
  It never commits on trunk, never pushes trunk, never merges.

**Working alone?** Open no lanes and you are the hubnode of a one-lane repo. R1–R5 and R8 go
quiet — a feature branch in your one checkout is nobody else's problem — while R7, the review
record, the handoff note, and the gate all still apply. `jig handoff` names the branch
instead of a lane; `jig gate` with no argument gates the current branch. The discipline is
identical; only the coordination disappears.

## The board

`jig/lanes.json`, on trunk, written only by the hubnode. Per lane:

| Key | Meaning |
|---|---|
| `brief` | the bundle, one paragraph |
| `branch` / `worktree` | where it is built |
| `state` | claimed → building → ready → gated → merged (or parked) |
| `after` | lanes this one is gated behind |
| `owns` | existing files only this lane may change while it is open |
| `shares` | existing files it may change alongside others |
| `reserved` | scarce numbers handed out centrally (migration steps, section numbers) |

`common` and `append_files` are repo-wide. A file new to the repo belongs to whoever makes it.
`payload` lists globs where markdown ships as code (skills, templates, fixtures); `survey`
does not look for a home for those files.

**Owns is narrow on purpose.** Before opening a lane, `jig open` diffs every open lane's
branch against trunk and refuses an `owns` entry another live branch already touched. Those
go in `shares` from the start, or both lanes get blocked on every commit afterward.

## The rules

Checked before every commit by a git hook, and by `jig check`.

- **R1** The trunk checkout stays on trunk. Work in `.git/jig/worktrees/<branch>`.
- **R2** A lane is built in its own worktree.
- **R3** A lane changes only its `owns`, its `shares`, `common`, or files new to the repo.
- **R4** Another open lane's `owns` is refused even if this lane also lists it.
- **R5** The board is the hubnode's; it is edited on trunk only.
- **R6** A scarce number belongs to the one lane that reserved it. A counter in `reserve`
  with a `pattern` and `files` is enforced: a change that makes a matching number exist where
  trunk had none, and the branch doesn't hold it, is refused. Editing or moving an existing
  heading takes nothing. Two branches that each take migration step 17 corrupt the first
  database that runs both.
- **R7** A change adding a `WORKAROUND:` comment to code must stage `jig/ledgers/WORKAROUNDS.md` too.
  Prose may quote the marker.
- **R8** A lane is gated only after the lanes in its `after` have merged.

**The hooks run trunk's copy of `jig.py`** (`git show <trunk>:jig/jig.py`). A branch
cannot weaken the rules it is judged by, and a stale checkout is still judged by today's rules.
While a merge of trunk is being finished, a change is judged against trunk, so what trunk
brought in is not the lane's.

**A bug in `jig/jig.py`, `jig/RULES.md` or a skill is the tool's, not this repo's.** Run `/jig:feedback`, then
park the lane or ask the hubnode. Don't patch them; don't ledger it.

## Keeping merges mechanical

Conventions so two lanes rarely meet in one hunk:

- Append, never edit, shared prose. A change to someone else's section is a note in yours.
- A file of one's own: new routes in your own handler registered by one line; new state in
  your own module; new tests in your own file; a new fixture as a new file.
- Scarce numbers come from the board (`--reserve`), never from looking at what seems free.
  Two branches that both take migration 17 corrupt the first database that runs both.

## Reserved numbers

Some things are scarce across the whole repo: migration step numbers, section numbers in a
shared document, anything a runner stores and compares. `--reserve <counter>` hands the lane
the next one at open. To enforce it as well as allocate it, give the counter a pattern:

```json
"reserve": {
  "schema": {"next": 17, "pattern": "SCHEMA_VERSION\\s*=\\s*(\\d+)", "files": ["**/storage.py"]}
}
```

Without a pattern the counter allocates and trusts; `jig status` marks it `(not enforced)`.

A lane holding step N lists the lane holding N−1 in `after`, so they merge in order: a
database already past a number never runs a step of that number that merges later.

## Documentation

One page per system, with *Now*, numbered *Rules*, and *Checks* — `jig/docs/README.md` has the
shape. Rules written in a system's page bind as if they stood in `AGENTS.md`; that is how the
always-loaded file stays under 40 lines. `jig reading-list <files>` prints which pages to
read before touching those files.

## Fold-in

Code and the page that documents it move together, or the page starts lying. `jig handoff`
works out which documentation page covers each source file the branch changed and writes a
checklist into the note. `jig gate` refuses while a line is unanswered — each is either
ticked as updated, or says why no change was needed.

Ownership comes from `docmap` in the board:

```json
"docmap": {"jig/docs/systems/storage.md": ["server/storage.py", "server/migrations/**"]}
```

A changed file nothing covers is listed as `UNOWNED` — add it to `docmap`, or answer why it
needs no page.

## Sync

`jig sync` merges trunk in. A conflict in an `append_files` file where **both sides only
added at the same spot** is resolved automatically: trunk's lines, then the lane's. Anything
else stops with the files named, and a person resolves it.

## Handoff, gate, merge

1. **The subnode hands off.** Runs the checks, has the diff adversarially reviewed, records it
   (`jig reviewed`), then `jig handoff` writes a note naming that exact commit. Fill every
   heading, commit the note with the work, tell the hubnode the lane and the commit.
   A lane may hand off several times.
2. **The hubnode gates.** `jig gate <lane>` refuses on R8 and on a missing note. Then it runs the checks **against the commit the note names, in a detached
   scratch checkout** — never the lane's live worktree, which the subnode may still be building in.
3. **The hubnode merges**, marks the lane, logs it, and syncs the clean lanes.

## Commands

```
jig init [--trunk main]     board, git hooks
jig survey [--json]         inventory the repo against the jig shape
jig open ... --reserve K    allocate scarce counter K to this lane
jig reading-list <paths>    what to read before touching these files
jig install-hooks           rewrite the hooks
jig status [--all]          lanes, states, distance from trunk, dirt
jig open <name> --brief … --owns … --shares … --after … --reserve schema
jig mark <name> <state>     claimed|building|ready|gated|merged|parked
jig check [--staged]        run the rules here
jig lane                    this branch's manifest
jig sync                    merge trunk in, append rule applied
jig reviewed                record that HEAD has been reviewed
jig handoff [--spec path]   write the note for HEAD
jig gate <name>             hubnode: verify, then print the gate commands
jig log [message] [-n N]    append to or read the log
```

## Hooks are opt-in per checkout

`jig install-hooks` writes `.git/jig/enabled`. Anything outside this repo that hooks into
your editor or agent runs this repo's `jig/scripts/` only when that marker exists; `.git/` is never
cloned, so a fetched repo cannot enable itself.
