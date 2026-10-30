# 🔩 jig

AI coding agents are fast, and they drift. They skip the spec, fix the symptom, wave a review
through, and step on each other when two of them share a repo. A woodworker solves the same
problem with a jig: you clamp the work in place once, and then every cut lands where it should.

So that's what this is. A few short rules, a written spec before building, a reviewer who hasn't
seen your reasoning, and parallel sessions that can't collide, with the parts that matter
enforced by git hooks instead of a polite request in a prompt.

I built it for prototyping software and firmware with Claude Code. The enforcement runs fine
without Claude Code.

## ✨ What it does

- **Parallel sessions stay in their lanes.** Each session gets a *lane*: its own branch,
  worktree and declared files. A commit outside those files is refused by a git hook.
- **The rules come from trunk.** Hooks run trunk's copy of the checker, so a branch can't
  weaken the rules it's judged by.
- **A bug gets investigated before it gets fixed.** `/jig:bug` asks why up to three times, tags
  every fact `[seen]` or `[assumed]`, looks for the sibling code path that doesn't have the
  problem, and makes you say whether you're correcting the cause or patching the symptom.
  Patches are allowed. Each one gets a `WORKAROUND:` comment and a ledger row, and the hook
  refuses the commit if the row is missing.
- **One review per handoff, from a fresh reader.** The reviewer sees the diff, the spec and the
  rules, and none of the conversation. `jig handoff` refuses a commit nobody reviewed.
- **One always-loaded file, under 40 lines.** Agents read `AGENTS.md` on every task, and a long
  one gets ignored wholesale. Everything else loads when a task needs it.
- **Docs move with the code.** A board maps docs pages to source files, and a handoff has to
  answer for every page its change touched.
- **Files from a chat land on purpose.** A spec or a user story written in some other chat goes
  into the repo's `.jig/staging/` and waits there until a session in the repo resolves it. A
  release is refused while anything is still staged.
- **Every repo ships its own way, through one command.** `jig release` runs the repo's own
  `.jig/scripts/release.sh` (a plugin file for one repo, a `.dmg` and an `.exe` for another),
  checks the files it promised came out, and tags `vX.Y.Z`. The first time, `/jig:release`
  asks you what the repo builds and writes the script with you.
- **Repos that share decisions stay in sync.** A *metarepo* holds definitions and decisions; each
  *pararepo* cites it at a released tag, and `para-sync` reports when a newer release lands.
- **It's portable.** The repo half is one stdlib Python file, some JSON and POSIX hooks. You can
  run every command by hand, and any other agent tool can call the same ones.

## ⚖️ Compared to other toolkits

jig started as a reading of the toolkits people share for agentic coding: Superpowers,
mattpocock/skills, ECC, Anthropic's Claude Code best practices and Kiro's spec-driven
development, plus a few papers on embedded firmware. They all do the basics well (a spec before
building, a small context file, a fresh-context reviewer), and I cut that down to what one
person prototyping actually needs. Then I added the things none of them enforce.

| | Superpowers | mattpocock/skills | ECC | Claude Code best practices | Kiro | **jig** |
|---|---|---|---|---|---|---|
| Spec before building | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fresh-context review | ✅ | | ✅ | ✅ | | ✅ once per handoff, bound to the commit |
| Parallel agents | worktrees | | worktrees | worktrees / teams | | worktrees **plus declared file ownership, hook-enforced** |
| Scarce numbers (migrations, sections) | | | | | | handed out by the board, refused by the hook |
| Rules enforced from trunk's copy | | | | | | ✅ |
| Docs must move with code | | | | | | the gate refuses an unanswered page |
| Workarounds | a comment, maybe | | | | | labeled and ledgered, or the hook refuses |
| A fixed shape for bug investigation | | | | | | five steps before any fix |
| Runs without the AI tool | | | | | | ✅ stdlib Python and git hooks |

Most agent toolkits are prose: a long instructions file the model reads and mostly follows. jig
keeps the prose to one short file and moves everything that must not be skipped into hooks. Its
lanes, board and gate are a small, enforced version of what teams already do with topic
branches, CODEOWNERS, PR templates and a merge queue, and `/jig:survey` names which of those a
repo already has.

## 🧭 How it's put together

This repo holds two things:

- **A Claude Code plugin** in `plugin/`. Its skills run the loop (`brief`, `bug`, `verify`,
  `review`, `retro`), set a repo up (`init`, `survey`, `adopt`, `update`), coordinate parallel
  sessions (`hubnode`, `subnode`), spec a circuit board and install the skills it needs
  (`hardware`), land files from other chats (`stage`, `repos`), cut releases (`release`), and report bugs in jig itself
  (`feedback`).
- **A checker**, `plugin/templates/jig/jig.py`, which `init` copies into a hidden `.jig/` folder
  in your repo with the rulebook, the board and three scripts. The checker owns the board,
  runs the rules from git hooks, and drives sync, handoff and gate. The skills are thin
  wrappers around it.

Everything jig makes in your repo lives in `.jig/`, so nobody mistakes it for your project.
Your root gets an `AGENTS.md` and a one-line `CLAUDE.md`, and that's it.

A task moves through:

```
brief → plan → do → commit (hook-checked) → … → checks → review → handoff → gate → merge
```

## 🚀 Usage

A new or small repo:

```
/jig:init
```

A repo with history and its own way of doing things. Both are read-only, and adopt writes a
plan for you to approve before anything moves:

```
/jig:survey      # what's here, in the repo's own terms
/jig:adopt       # a staged migration plan in .jig/specs/
```

A repo already on jig, after you install a newer plugin. It's a dry run first, and it asks
before touching any file of yours:

```
/jig:update
```

Day to day:

```
/jig:brief <task>        # .jig/specs/<task>.md before building
/jig:bug <symptom>       # investigate before fixing
/jig:review              # fresh-context review, once per handoff
/jig:stage               # send a file from this chat to a repo, or resolve what's staged
/jig:repos add repo      # register this folder so other chats can stage files to it
/jig:release             # build and tag a version, the way this repo ships
/jig:hubnode             # the session that owns trunk, the board and merges
/jig:subnode             # a session that works one lane
```

Every rule the hooks enforce is written in `.jig/RULES.md` after init.

## 📦 Installation

```sh
claude plugin marketplace add daveaseeman/jig
claude plugin install jig@squarish
```

To try it for one session without installing, clone this repo and run
`claude --plugin-dir ./jig/plugin`.

You need git, Python 3.10 or newer, and Claude Code. The repo half needs only git and Python.

**On trust.** Claude Code warns about every plugin with hooks, because hooks run shell commands
as you. jig's two (a format step after an edit and a check when the agent stops) run your repo's
own `.jig/scripts/format.sh` and `.jig/scripts/check.sh`, and only in a repo that opted in with
`jig install-hooks`, which writes a marker inside `.git/`. Git never clones `.git/`, so a repo you
fetched can't turn itself on. The whole hook config is `plugin/hooks/hooks.json`, and it's short
enough to read in a minute.

## 💬 Feedback and development

This is a personal tool, built in the open. Issues and discussion are on GitHub.

If jig misbehaves in your repo, run `/jig:feedback`. It investigates the way `/jig:bug` does and
writes a report to a temp file you can attach to an issue, without patching your copy.

To work on jig itself, start with `AGENTS.md`. `bash tests/smoke.sh` runs every rule end to end
in a throwaway repo, and `claude plugin validate ./plugin` checks the plugin's shape. This repo
runs jig on itself, so `.jig/` here is the installed release and `plugin/` is the code you edit.

## 📚 Further reading

- `plugin/templates/jig/RULES.md`: the rulebook a repo gets
- `plugin/skills/adopt/SKILL.md`: bringing an existing repo onto jig, including one that already
  coordinates parallel work its own way
