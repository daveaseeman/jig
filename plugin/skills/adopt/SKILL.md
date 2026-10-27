---
name: adopt
description: Analyze an existing repo and propose how to bring it to the jig shape - trim the always-loaded file, give every stray document a home, fill the gaps. Proposes a plan; applies nothing without approval.
disable-model-invocation: true
---

Produce a migration plan. **Change nothing in this pass.** The deliverable is
`specs/adopt-<repo>.md`, which the user reads and approves before any of it happens.

## 1. Measure

```sh
python3 .jig/jig.py survey                                     # repo already has jig
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" survey    # it doesn't — nothing to install
```

The checker surveys any repo from outside it, so this pass installs nothing.

The survey gives you: every markdown file with its size, last commit, and how many other
files reference it; which ones have no home; always-loaded files over 40 lines; source files
with no docs page and docs pages with no source.

## 2. Classify every document

Each one gets exactly one job and one home:

| Home | Job |
|---|---|
| `AGENTS.md` | rules an agent needs on every task — and nothing else |
| `CLAUDE.md` | one line importing AGENTS.md |
| `README.md` | for people outside the repo |
| `docs/systems/` | what the code is now, one page per system |
| `specs/` | a task in flight |
| `ledgers/WORKAROUNDS.md` | patches that are in the code |
| `ledgers/DEFERRED.md` | review findings that are not |
| `docs/HARDWARE.md` | board, wiring, voltages, flash |
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

`specs/adopt-<repo>.md`, using `specs/_template.md`, plus:

- **Inventory** — a table: file, lines, inbound links, verdict, destination, why.
- **AGENTS.md before/after** — the proposed 40-line version in full, and a list of what left
  and where it went.
- **Gaps** — which jig pieces are missing and what `init` would add.
- **Docmap** — which pages cover which files; propose the map, not new pages.
- **Stages** — ordered, each independently mergeable. Deletions last, after the content that
  replaced them has landed.
- **Risks** — anything a reader might disagree with, named rather than buried.

## 4b. Parallel work already coordinated some other way

The survey's last section lists what the repo already has — `CODEOWNERS`, a PR template,
husky or pre-commit, hooks in `.git/hooks`, worktrees, unmerged branches, a homebrew board —
and what each maps to. Use the repo's own words for them in the plan; never assume it calls
anything a lane. If any of those are present, the plan gets the stages from
`${CLAUDE_PLUGIN_ROOT}/skills/adopt/MIGRATION.md`: install with hooks off, fill the board from what exists
(`CODEOWNERS` → owns/shares, the predecessor board if any), adopt each unmerged branch with
`jig open --branch`, cut hooks over with `--replace`, prove one full cycle, then retire the
predecessor. List every lane the predecessor's board shows as open — not only what git shows as unmerged,
since a claimed lane with no commits is merged by git's definition yet still holds reserved
numbers — by name with the numbers it holds; those are the whole difficulty. Count stale
worktrees too, and plan to remove the ones whose branch has merged.

## 5. Stop

Present the plan in chat as a short summary: counts, the biggest wins, and anything you were
unsure about. Ask for approval. On approval, execute the stages — one lane each if the repo
has lanes, one commit each if not — and never delete a file in the same stage that created
its replacement.
