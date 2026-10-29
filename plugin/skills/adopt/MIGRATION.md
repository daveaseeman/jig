# Migrating a repo onto jig

For a repo that already coordinates parallel work some other way. That might be the standard
GitHub shape — topic branches, worktrees, `CODEOWNERS`, a PR template, branch protection,
husky or pre-commit hooks — or a homebrew system with its own board and hooks. Either way the
goal is one system to manage, not a better one, and the path has to be safe for work that is
mid-stream. Each stage is one commit on trunk and can be undone by reverting it.

"Lane" below is jig's word; `jig/RULES.md` defines it in standard terms. Your repo
need not have called anything a lane. What matters is whether it has the *parts*:

| If the repo has… | it maps to jig's… |
|---|---|
| `CODEOWNERS` | `owns` / `shares` on the board |
| a PR / merge-request template | the handoff note |
| branch protection, required reviews, a merge queue | the gate |
| husky, pre-commit, lefthook, or hooks in `.git/hooks` | the hooks (to be replaced) |
| `CLAUDE.md`, `.cursorrules`, copilot instructions | `AGENTS.md` |
| ADRs | `jig/specs/` decisions and `jig/ledgers/WORKAROUNDS.md` |
| branches not merged into trunk | lanes to adopt |
| a homebrew board with owners and states | the board |

## 0. Survey

```sh
python3 <plugin>/templates/jig/jig.py survey
```

Read-only. Its last section, *How parallel work is coordinated today*, lists what the repo
already has under its standard name and what each maps to. Note the hooks, any board or
ownership file, the record of past merges, and **every branch not merged into trunk** — those
branches are the whole difficulty; everything else is files.

## 1. Install files, hooks off

Copy `jig/jig.py`, `jig/RULES.md`, `jig/ledgers/WORKAROUNDS.md`, `jig/ledgers/DEFERRED.md`, `jig/specs/_template.md`, and
`jig/scripts/check.sh` / `jig/scripts/format.sh` (fast checks only — the Stop hook has a time limit).
Then:

```sh
python3 jig/jig.py init --no-hooks
```

That writes an empty board and leaves the predecessor's hooks
running. Now fill the board by hand, from the predecessor's:

| jig board | from the predecessor |
|---|---|
| `trunk` | its main branch |
| `common` | files every lane may touch |
| `append_files` | files whose conflicts resolve by appending |
| `reserve.<counter>` | each scarce number it allocates — set `next` to the highest ever taken, and give it a `pattern` + `files` so it is enforced |
| `docmap` | its file → documentation map, if it has one |

A counter's `files` must name every file its numbers live in — if the rules moved from
`AGENTS.md` to `docs/**`, the pattern must cover both, or R6 enforces nothing.

Commit on trunk. The predecessor still enforces; jig enforces nothing yet.

## 2. Adopt every open lane

**Walk the predecessor's board, not git's branch list.** A lane that is claimed but has no
commits yet is "merged" by git's definition — `git branch --no-merged` will not show it — but
it holds reserved numbers that must come across or they will be handed out twice. The survey's
*branches not merged into trunk* is a cross-check for work the board forgot, not the list.

For each lane the board shows as not merged — whether the repo called it a lane, a feature
branch, a workstream, or nothing — in the trunk checkout:

```sh
python3 jig/jig.py open <name> --branch <its branch> --worktree <where it lives> \
    --reserve schema=<held> section=<held> --owns <its owns> --shares <its shares> \
    --after <its after> --state <its state>
```

`open` sees the branch exists and adopts it: no new branch, no new worktree, the numbers it
already holds recorded and fenced off from the counter. `--owns` and `--shares` come from
`CODEOWNERS` if there is one, or from the predecessor's board, or from `git diff --name-only
trunk...branch` — the files it has already touched are at minimum its `shares`. Keep the worktree where it is —
R2 checks the path the board records, so `.claude/worktrees/x` is as good as
`.git/jig/worktrees/x`. Commit the board.

A lane with uncommitted work is fine; its next commit is judged by whichever hooks are
installed at that moment, and its ownership and numbers are the same under both.

Then prune. A predecessor that never removed worktrees for merged lanes leaves dozens behind;
`git worktree list` shows them. `git worktree remove <path>` for each whose branch is merged,
then `git worktree prune`. Do this before cutting hooks over, so the cutover touches only
live checkouts.

## 3. Cut the hooks over

```sh
python3 jig/jig.py install-hooks --replace
```

`--replace` removes the predecessor's hooks instead of chaining them as `.local`. Without it,
both systems enforce every commit — the default chaining is right for a lint or format hook you
want to keep, wrong for a predecessor coordination system. Husky and pre-commit users: those
tools manage `.git/hooks` themselves, so uninstall them (`npx husky uninstall`,
`pre-commit uninstall`) rather than letting `--replace` delete files they will rewrite.
Confirm with `ls .git/hooks`.

Worktrees share `.git`, so this one command switches every live session at once. Each subnode
runs `python3 jig/jig.py check` in its worktree; `ok` means its lane came across clean.

## 4. Switch the skills and the always-loaded file

- Remove the predecessor's hubnode and subnode skills; `/jig:hubnode` and `/jig:subnode`
  take over. Subnodes check in again with the new skill.
- In `AGENTS.md`, replace the predecessor's process section with a pointer to `jig/RULES.md`.
- Leave its handoff records where they are. They are history; `jig survey` skips tooling
  directories, and new notes go to `jig/handoffs/`.

## 5. Prove it, then delete the predecessor

One lane completes a full cycle on the new system — build, review, `jig reviewed`,
`jig handoff`, `jig gate`, merge — before anything is deleted. Then remove the
predecessor's script, board, rendered list, rulebook, and installer in one commit. Its tests,
if any, go with it.

## What does not migrate

- **A lane built on another lane's branch** (`on`). jig syncs against trunk only. Merge or
  rebase such a lane before adopting it.
- **Intake of a branch that predates any board.** Adopt it by hand with `open --branch`.
- **A rendered human-readable board.** `jig status` is the view.
- **Repo-specific docs tests.** They stay the repo's, reading whatever file they read.
- **CODEOWNERS itself.** GitHub keeps reading it for review assignment; jig's `owns` is
  exclusive write during an open lane, a stronger claim. Keep both; derive `owns` from it.
