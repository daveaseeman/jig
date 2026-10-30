---
name: stage
description: Stage a chat-born file (spec, doc, decisions, user story) for a jig repo, or resolve what sits in .jig/staging/ - land each in its target or drop it with a reason. Use when a chat produced something meant for a repo, at session start when files are staged, or on "resolve staging".
---

A staged file is a Markdown file in `.jig/staging/` with this header. Nothing in it is
decided until it is resolved: read it for context, never cite it as decided.

```yaml
---
staged: true
target: <repo name from `jig repos`, or "this">
kind: spec | doc | decisions | user-story
change: new | update
destination: <inside the target: a path if known, else a filename, else a description>
source: <session / date / author>
status: staged
---
```

## Staging a file

Write it into the target's `.jig/staging/`, found with `jig repos` (needs only
`~/.config/jig/` — then ask for access to exactly `<repo>/.jig/staging/`). Say `new` or
`update`, and make `destination` as precise as you can, never an absolute path.

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
  the commit without it.
- **user-story**: run `/jig:brief` with the story as input — a new spec, or an amendment to
  the spec it extends — carrying `Source: <source> (staged as <file name>)`. Then `resolve`.
- **another repo's**: `resolve` forwards it into that repo's `.jig/staging/`; it is resolved
  in a session there.
- **not wanted**: show it, ask, then `jig staging drop <file>`. Nothing records it: it was
  never committed.

Resolve one file per step and show the result before the next.
