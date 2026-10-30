---
name: survey
description: Read-only inventory of this repo against the jig shape - stray documents, oversized always-loaded files, docs that drifted from the code, missing pieces. Use to check a repo, or periodically to catch strays.
---

Run it. Nothing is written, and nothing needs to be installed first:

```sh
python3 .jig/jig.py survey            # if the repo has jig
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" survey   # if it doesn't
```

Add `--json` to pipe it somewhere.

Report the output, then say what it means in a few lines:

- **Oversized always-loaded file.** Over 40 rule lines and the whole file starts getting
  ignored, so every rule in it is weakened by the ones around it. Highest-value fix.
- **No home in the taxonomy.** Each document gets one job and one home — AGENTS.md rules,
  `docs/` what the code is now, `.jig/specs/` a task in flight, `.jig/ledgers/WORKAROUNDS.md` patches in the code,
  `.jig/ledgers/DEFERRED.md` review findings not in it,
  `.claude/skills/` know-how, `README.md` outsiders, git for history. Zero inbound links plus
  a stale last-commit is a document written once and never read again; git keeps it either way.
  If a directory ships markdown as code, list it under `not_docs` in `.jig/config.json` as a glob
  such as `dir/**`. Survey names any `not_docs` glob that matches no file.
- **No docmap.** Handoff can't tell which page a change touches until pages are mapped to globs.
- **Missing pieces.** What `/jig:init` would add.
- **How parallel work is coordinated today.** What the repo already has, under its standard
  name (`CODEOWNERS`, PR template, husky, worktrees, unmerged branches, a homebrew board), and
  what each maps to in jig. Speak in the repo's terms when reporting this.

Offer, in one line: `/jig:adopt` to turn this into a migration plan, or fix the one or two
things that stand out now. Don't start moving files in this skill.
