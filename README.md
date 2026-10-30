# 🔩 jig

A jig holds the work so every cut lands where it should. This one holds AI coding agents:
a few short rules, a written spec before building, an adversarial review before merging, and
parallel sessions on one repo that cannot step on each other — enforced by git hooks, not
by asking nicely.

Built for prototyping software and firmware with Claude Code. Runs without it.

## ✨ Highlights

- **Parallel sessions that can't collide.** Each one works a *lane*: its own branch, worktree
  and declared files. A commit outside those files is refused by a git hook.
- **Hooks run trunk's copy of the rules.** A branch cannot weaken the rules it is judged by.
- **A bug gets investigated before it gets fixed.** `/jig:bug` walks the whys, tags what is
  seen vs assumed, looks one layer up for the sibling path that doesn't have the problem, and
  makes you say whether the fix is a correction or a patch. Patches are allowed, labeled and
  ledgered — so they don't pile up unseen.
- **Review once per handoff, by a reader who hasn't seen your reasoning.** The handoff command
  refuses a commit nobody reviewed.
- **One always-loaded file, under 40 lines.** Everything else is read when a task needs it.
- **Portable.** The repo half is stdlib Python, JSON and POSIX hooks. A person can run every
  command by hand; another agent harness can call the same ones.

## 🧰 Features

| | What you get |
|---|---|
| **Brief** | `.jig/specs/<task>.md`: intent, observable done-when, out-of-scope, alternatives considered |
| **Bug protocol** | `/jig:bug` — whys ≤3, givens tagged `[seen]`/`[assumed]`, one layer up, correction or patch |
| **Verify** | tests for logic, emulator for graphics, hardware as early as confidence allows |
| **Review** | fresh-context adversarial reader, once per handoff; `jig handoff` refuses an unreviewed commit |
| **Lanes** | one branch + worktree + declared files per session; `hubnode` owns trunk, `subnode` works a lane |
| **Rules R1–R8** | git hooks, run from trunk's copy: ownership, reserved numbers, board, ordering, ledger |
| **Two ledgers** | `.jig/ledgers/WORKAROUNDS.md` for patches in the code, `.jig/ledgers/DEFERRED.md` for review findings not taken |
| **Docs fold-in** | `docmap` ties pages to files; a handoff answers for every page a change touched |
| **Survey / adopt** | read-only inventory in the repo's own terms, then a staged migration plan to approve |
| **Retro** | same fix twice → a skill; two workarounds in one subsystem → refactor task |
| **Feedback** | report a bug in jig itself, without patching your copy |

## ⚖️ Compared to other toolkits

The frameworks jig was distilled from all do the basics well: a spec before building, a small
always-loaded context file, phase gates, runnable checks, a fresh-context reviewer. These are
the places jig goes further. Full argument in [`marketing/DIFFERENCES.md`](marketing/DIFFERENCES.md).

| | Superpowers | mattpocock/skills | ECC | Claude Code best practices | Kiro | **jig** |
|---|---|---|---|---|---|---|
| Spec before building | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fresh-context review | ✅ | — | ✅ | ✅ | — | ✅ once per handoff, bound to the commit |
| Parallel agents | worktrees | — | worktrees | worktrees / teams | — | worktrees **+ declared file ownership, hook-enforced** |
| Scarce numbers (migrations, sections) | — | — | — | — | — | allocated by the board, refused by the hook |
| Rules enforced from trunk's copy | — | — | — | — | — | ✅ a branch can't weaken its own rules |
| Docs must move with code | — | — | — | — | — | handoff lists every page touched; gate refuses unanswered |
| Workarounds | comment, maybe | — | — | — | — | labeled **and ledgered**, hook-refused otherwise |
| Bug investigation shape | — | — | — | — | — | fixed five steps before any fix |
| Runs without the AI tool | — | — | — | — | — | ✅ stdlib Python + git hooks |

## 🧭 Overview

jig is two things in one folder:

- **A Claude Code plugin** (`plugin/`): skills for the loop — `brief`, `bug`, `verify`,
  `review`, `retro` — plus `init`, `survey` and `adopt` to set a repo up, `update` to bring
  it to the current layout, `hubnode` and `subnode` for parallel sessions, `hardware` for
  speccing a board and installing the skills it needs, `stage` for landing chat-born files, and `feedback` for reporting a bug in
  jig itself.
- **A repo-side checker** (`plugin/templates/jig/jig.py`) that `init` copies into a hidden `.jig/`.
  It owns the board of lanes, runs the rules from git hooks, and drives sync, handoff and gate.
  The skills are thin wrappers around it.

The loop a task follows:

```
brief → plan → do → commit (hook-checked) → … → checks → adversarial review → handoff → gate → merge
```

**Where it came from.** It was distilled from the frameworks people share for agentic
coding (Superpowers, mattpocock/skills, ECC, Anthropic's best practices, Kiro's spec-driven
development, and a handful of embedded-firmware papers), then cut down to what a solo
prototyper actually needs. `marketing/DIFFERENCES.md` is what it does that those don't; `marketing/FEATURES.md`
is every piece with where it came from and why — add a row there before adding a piece.

**Compared to the alternatives.** Most agent frameworks are prose: a long instructions file
the model reads and mostly follows. jig keeps the prose to one short file and puts the parts
that must not be skipped into git hooks. Its coordination model — lanes, a board, a gate — is
a small, enforced version of what teams already do with topic branches, CODEOWNERS, PR
templates and a merge queue; `survey` names what a repo already has and what each maps to.

## 🚀 Usage

In a new or small repo:

```
/jig:init
```

In a repo with history and its own way of doing things — read-only, writes a plan for you to approve:

```
/jig:survey      # what's here, in the repo's own terms
/jig:adopt       # a staged migration plan in .jig/specs/
```

In a repo already running jig, after the plugin moves where it keeps things — a dry run first,
then it asks:

```
/jig:update      # jig's files to their current paths; your own files only on a yes
```

Day to day:

```
/jig:brief <task>        # .jig/specs/<task>.md before building
/jig:bug <symptom>       # investigate before fixing
/jig:review              # fresh-context adversarial review, once per handoff
/jig:hubnode             # the session that owns trunk, the board and merges
/jig:subnode             # a session that works one lane
```

Everything the hooks enforce is in `.jig/RULES.md` after init — eight rules, one page.

## 📦 Installation

```sh
claude plugin marketplace add ./jig       # path to this folder
claude plugin install jig@squarish
```

Or for one session without installing: `claude --plugin-dir ./jig/plugin`.

Requires git, Python 3.10+ and Claude Code. The repo half needs only git and Python.

**On trust.** Claude Code warns about every plugin's hooks, because hooks run shell commands
as you. jig's two hooks (`format` on edit, `check` on stop) run the repo's own
`.jig/scripts/format.sh` and `.jig/scripts/check.sh` — and only in a repo that opted in by running
`jig install-hooks`, which writes a marker inside `.git/`. `.git/` is never cloned, so a repo
you fetched can't enable itself. `hooks/hooks.json` is four lines; read it.

## 💬 Feedback and development

This is a personal tool, developed in the open. Issues and discussion on GitHub.

Found a bug in jig while using it in your repo? `/jig:feedback` investigates it the way
`/jig:bug` would and writes a report to a temp file you can attach to an issue — without
patching your copy.

To work on jig itself, see `AGENTS.md`. `bash tests/smoke.sh` exercises every rule in a
throwaway repo; `claude plugin validate ./plugin` checks the plugin's shape.

## 📚 Further reading

- `plugin/templates/jig/RULES.md` — the rulebook a repo gets
- `plugin/skills/adopt/SKILL.md` — bringing an existing repo onto jig, including one that already coordinates parallel work
- `marketing/DIFFERENCES.md` — what jig does that the frameworks it came from don't
- `marketing/FEATURES.md` — every piece, its origin, and why it exists
