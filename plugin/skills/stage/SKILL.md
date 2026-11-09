---
name: stage
description: Stage a chat-born file (spec, doc, decisions, user story, feature request, roadmap change) for a jig repo, or resolve what sits in .jig/staging/ - land each in its target or drop it with a reason. Use when a chat produced something meant for a repo, at session start when files are staged, or on "resolve staging".
---

A staged file is a Markdown file in `.jig/staging/` with this header. Nothing in it is
decided until it is resolved: read it for context, never cite it as decided.

```yaml
---
staged: true
target: <repo name from `jig repos`, or "this">
kind: spec | doc | decisions | user-story | feature-request | feedback | roadmap
change: new | update
destination: <inside the target: a path if known, else a filename, else a description>
source: <session / date / author>
status: staged
---
```

A `feedback` file, written by `/jig:feedback`, also carries `from:` (the reporting repo) and
`jig_version:`. When the jig repo isn't registered it waits in the `feedback/` folder beside your
repos list (`jig repos` prints where), which `jig staging` lists too.

## Staging a file

Write it into the target's `.jig/staging/`, found with `jig repos` (needs only
`~/.config/jig/` — then ask for access to exactly `<repo>/.jig/staging/`). Say `new` or
`update`, and make `destination` as precise as you can, never an absolute path.

A user story names who wants what and why. A feature request just describes what the thing
should do, in the owner's words ("I want it to do xyz"): free prose, no template, no Done-when.
Pick whichever fits what was said. For a request, `change: update` means it changes a feature a
spec already describes; name that spec in `destination` if known.

## Resolving

`python3 .jig/jig.py staging` lists what's there. For each file, with the user:

- **spec / doc, new**: `jig staging resolve <file>` writes it, with its source.
- **spec / doc, update**: find the page — the path, else search for the filename, else ask
  from the description. Merge the content in with the user, add the line
  `Source: <source> (staged as <file name>)` as provenance, then `resolve`.
- **decisions**: `resolve` appends the rows. Body lines that aren't rows (doc edits listed
  with them) are refused: apply those with the user, delete them from the staged file,
  resolve again. An `update` changes existing rows; edit them, then `resolve`.
  In a metarepo, add the `CHANGELOG.md` line `resolve` prints before committing: M3 refuses
  the commit on a branch with no line yet.
- **roadmap**: `destination: .jig/roadmap.md`, `change: update`; the body says what to add,
  rename, reorder or drop (a phase, a scope, an exit box) and why. It is the owner's decision,
  made on trunk: the hubnode applies it and commits with the file's `Source:` line in the
  message (its skill, "A roadmap change"), then `resolve` finds that commit. Any other
  destination is refused.
- **user-story**: run `/jig:spec` with the story as input — a new spec, or an amendment to
  the spec it extends — carrying `Source: <source> (staged as <file name>)`. Then `resolve`.
- **feature-request**: run `/jig:spec` with the request as input. The spec quotes the request
  in the owner's words after its mark, `Source: <source> (staged as <file name>): "<request>"`
  (as `/jig:fix` does a report's symptom); restates it as the Intent (if that won't fit in a
  sentence, ask the owner one question first); and lists under Decisions each thing it filled in that the request didn't say, starting `Interpreted:`.
  Show the spec; `resolve` once the owner accepts it. It refuses until a spec carries the mark.
- **feedback**: work through it with `/jig:fix` in the jig repo. Elsewhere, `resolve` forwards it
  there.
- **another repo's**: `resolve` forwards it into that repo's `.jig/staging/`; it is resolved
  in a session there.
- **not wanted**: show it, ask, then `jig staging drop <file>`. Nothing records it: it was
  never committed.

Resolve one file per step and show the result before the next.
