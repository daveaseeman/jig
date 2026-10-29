---
name: adopt
description: Analyze an existing repo and propose how to bring it to the jig shape - trim the always-loaded file, give every stray document a home, fill the gaps, and move any existing lanes and hooks onto jig. Proposes a plan; applies nothing without approval.
disable-model-invocation: true
---

Produce a migration plan. Steps 1–5 **change nothing**: the deliverable is
`jig/specs/adopt-<repo>.md`, which the user reads and approves before step 6 carries out any
of it.

## 1. Measure

```sh
python3 jig/jig.py survey                                     # repo already has jig
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" survey    # it doesn't — nothing to install
```

The checker surveys any repo from outside it, so this pass installs nothing.

The survey gives you: every markdown file with its size, last commit, and how many other
files reference it; which ones have no home; always-loaded files over 40 lines; source files
with no docs page and docs pages with no source. Its last section, *How parallel work is
coordinated today*, lists what the repo already has under its standard name and what each
maps to: note the hooks, any board or ownership file, the record of past merges, and every
branch not merged into trunk.

## 2. Classify every document

Each one gets exactly one job and one home:

| Home | Job |
|---|---|
| `AGENTS.md` | rules an agent needs on every task — and nothing else |
| `CLAUDE.md` | one line importing AGENTS.md |
| `README.md` | for people outside the repo |
| `docs/<system>/<system>.md` | what the code is now, one page per system; subsystems nest inside |
| `jig/specs/` | a task in flight |
| `jig/ledgers/WORKAROUNDS.md` | patches that are in the code |
| `jig/ledgers/DEFERRED.md` | review findings that are not |
| `docs/hardware/<board>.md` | one per board: components, wiring, toolchain, flash |
| `.claude/skills/` | reusable know-how, loaded on demand |
| git history | everything else |

Then decide per file: **keep** · **merge into X** · **move to Y** · **split** · **delete**.

Judgment, in order:
0. **Is it a document at all?** A directory that ships markdown as code — skill files,
   templates, fixtures, a docs site's source — gets a `payload` glob (`dir/**`) in the plan,
   not a move. Survey reads trunk's board, so after `jig init` and a commit, re-run survey and
   judge only what is still listed.
1. **Does anything read it?** Zero inbound links and months since the last commit is the
   signature of a document written once and never consulted. Deleting it loses nothing —
   git still has it.
2. **Is it rules, state, or history?** Rules go to AGENTS.md or a skill. State (what the code
   does now) goes to `docs/`. History — round contracts, changelogs of decisions already
   made, "what we did in sprint 12" — is history. Git keeps history.
3. **Is it duplicated?** Three files describing the architecture means one file and two
   deletions, not a merge of all three.
4. **Would an agent loading it make better decisions?** If not, it's costing tokens for nothing.

## 3. The always-loaded diet

If `AGENTS.md` is over 40 lines, that is the highest-value item in the plan — a long one gets
ignored wholesale, so every rule in it is weakened by the ones around it.

Propose, line by line, what stays: commands an agent can't guess, style rules that differ
from the language default, workflow, repo-specific gotchas. Everything else moves to `docs/`
(if it's state), a skill (if it's situational know-how), or git (if it's history). Per-round
or per-sprint sections are almost always history.

**Forwarding addresses are history too.** A line that only says "X is now at Y" records a
move, not a rule; propose removing it from every document the plan touches. A numbered heading
already resolves the citation by search.

## 3b. When the repo's rule contradicts the template

The template is a default for repos that have not decided. A repo that has decided — a rule
with a date, a reason, and a test behind it — outranks the default. Do not propose replacing
it because the template says otherwise.

List each such conflict in the plan under **Decisions**, with: the repo's rule and its stated
reason, the template's rule, what the research says if it says anything, and a recommendation.
Recommend keeping the repo's rule unless it is one the research shows harmful: an always-loaded
file too long to be read, a prose rule where a hook would do, a workaround with no record.
A style preference — comment style, naming, formatting — is the repo's to keep.

When a rule has separable parts, say which part is contested. A rule that says "comments state
what the code does, and never cite a section number" is two rules; the second survives whatever
is decided about the first.

## 3c. A rule change is not done when the rule text changes

For every rule the plan changes — whether the repo's or the template's gives way — the plan
must say two more things, or the repo ends up stating one rule and living another:

1. **The test or hook that enforced the old rule.** Name it. It changes in the same stage as
   the rule, never a later one.
2. **The code that followed the old rule.** *Sweep* it in its own lane, or *grandfather* it:
   the new rule applies to changed code and old code migrates as touched. Grandfather by
   default for style rules — an agent rewriting comments it did not write will invent reasons.

## 4. Write the plan

`jig/specs/adopt-<repo>.md`, using `jig/specs/_template.md`, plus:

- **Inventory** — a table: file, lines, inbound links, verdict, destination, why.
- **AGENTS.md before/after** — the proposed 40-line version in full, and a list of what left
  and where it went.
- **Gaps** — which jig pieces are missing and what `init` would add.
- **Docmap** — which pages cover which files; propose the map, not new pages.
- **Stages** — ordered, each independently mergeable. Deletions last, after the content that
  replaced them has landed.
- **Risks** — anything a reader might disagree with, named rather than buried.

## 4b. Parallel work already coordinated some other way

The repo may already coordinate parallel work: the standard GitHub shape — topic branches,
worktrees, `CODEOWNERS`, a PR template, branch protection, husky or pre-commit hooks — or a
homebrew system with its own board and hooks. The goal is one system to manage, not a better
one, and the path has to be safe for work that is mid-stream.

"Lane" is jig's word; `jig/RULES.md` defines it in standard terms. Use the repo's own words in
the plan and never assume it calls anything a lane. What matters is whether it has the
*parts*:

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

If any of those are present, the plan's first stages are the migration stages in step 6.

List every lane the predecessor's board shows as open, by name with the numbers it holds;
those are the whole difficulty. **Walk the predecessor's board, not git's branch list.** A lane
that is claimed but has no commits yet is "merged" by git's definition — `git branch
--no-merged` will not show it — but it holds reserved numbers that must come across or they
will be handed out twice. The survey's *branches not merged into trunk* is a cross-check for
work the board forgot, not the list. Count stale worktrees too, and plan to remove the ones
whose branch has merged.

## 5. Stop

Present the plan in chat as a short summary: counts, the biggest wins, and anything you were
unsure about. Ask for approval, and go no further without it.

## 6. Carry it out

On approval, execute the stages — one lane each if the repo has lanes, one commit each if
not. Each stage can be undone by reverting it. Never delete a file in the same stage that
created its replacement.

When the repo already coordinates parallel work (4b), these stages come first, in this order.

### 6.1 Install files, hooks off

Copy `${CLAUDE_PLUGIN_ROOT}/templates/jig/` to `jig/` as `/jig:init` does, and
`chmod +x jig/scripts/*.sh`. `AGENTS.md` and `CLAUDE.md` are the plan's diet, not this copy.
Keep `jig/scripts/check.sh` and `format.sh` to fast checks — the Stop hook has a time limit.
Then:

```sh
python3 jig/jig.py init --no-hooks
```

That writes an empty board and leaves the predecessor's hooks running. Now fill the board by
hand, from the predecessor's:

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

### 6.2 Adopt every open lane

For each lane on the plan's list (4b) — whether the repo called it a lane, a feature branch, a
workstream, or nothing — in the trunk checkout:

```sh
python3 jig/jig.py open <name> --branch <its branch> --worktree <where it lives> \
    --reserve schema=<held> section=<held> --owns <its owns> --shares <its shares> \
    --after <its after> --state <its state>
```

`open` sees the branch exists and adopts it: no new branch, no new worktree, the numbers it
already holds recorded and fenced off from the counter. `--owns` and `--shares` come from
`CODEOWNERS` if there is one, or from the predecessor's board, or from `git diff --name-only
trunk...branch` — the files it has already touched are at minimum its `shares`. Keep the
worktree where it is — R2 checks the path the board records, so `.claude/worktrees/x` is as
good as `.git/jig/worktrees/x`. Commit the board.

A lane with uncommitted work is fine; its next commit is judged by whichever hooks are
installed at that moment, and its ownership and numbers are the same under both.

Then prune. A predecessor that never removed worktrees for merged lanes leaves dozens behind;
`git worktree list` shows them. `git worktree remove <path>` for each whose branch is merged,
then `git worktree prune`. Do this before cutting hooks over, so the cutover touches only
live checkouts.

### 6.3 Cut the hooks over

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

### 6.4 Switch the skills and the always-loaded file

- Remove the predecessor's hubnode and subnode skills; `/jig:hubnode` and `/jig:subnode`
  take over. Subnodes check in again with the new skill.
- In `AGENTS.md`, replace the predecessor's process section with a pointer to `jig/RULES.md`.
- Leave its handoff records where they are. They are history; `jig survey` skips tooling
  directories, and new notes go to `jig/handoffs/`.

### 6.5 Prove it, then delete the predecessor

One lane completes a full cycle on the new system — build, review, `jig reviewed`,
`jig handoff`, `jig gate`, merge — before anything is deleted. Then remove the
predecessor's script, board, rendered list, rulebook, and installer in one commit. Its tests,
if any, go with it.

### What does not migrate

- **A lane built on another lane's branch** (`on`). jig syncs against trunk only. Merge or
  rebase such a lane before adopting it.
- **Intake of a branch that predates any board.** Adopt it by hand with `open --branch`.
- **A rendered human-readable board.** `jig status` is the view.
- **Repo-specific docs tests.** They stay the repo's, reading whatever file they read.
- **CODEOWNERS itself.** GitHub keeps reading it for review assignment; jig's `owns` is
  exclusive write during an open lane, a stronger claim. Keep both; derive `owns` from it.
