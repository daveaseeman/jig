---
name: feedback
description: Report a bug in the jig tool itself (.jig/jig.py, .jig/RULES.md, its hooks, or a skill) for the plugin owner. Use when the tool, not the repo's code, misbehaved. Changes nothing in the repo.
disable-model-invocation: true
---

Runs only when the owner asks for it. A session that finds a bug in jig says what broke and
tells the owner; it never starts this on its own.

This is `/jig:bug` pointed at the tool. The user decides which one applies; don't guess.

Investigate exactly as `/jig:bug` does — whys, givens tagged `[seen]`/`[assumed]`, one
layer up, workaround or correction, spec — reading `.jig/jig.py`, `.jig/RULES.md`, the
hook output, and the skill involved.

Then:

1. Write the report as a staged file, `feedback-<repo>-<date>-<slug>.md`, the slug a few words
   naming the issue. Never overwrite a staged file: if the name is taken, pick another slug.
   One section per issue, each with the five steps and a "done when" the plugin owner can
   test. Its header:

   ```yaml
   ---
   staged: true
   target: jig
   kind: feedback
   change: new
   destination: a fix in jig
   source: <session / date / author>
   from: <this repo's name>
   jig_version: <first 12 hex digits of `git hash-object .jig/jig.py`>
   status: staged
   ---
   ```

2. Find the jig repo with `python3 .jig/jig.py repos` (it reads `~/.config/jig/`). It is
   the entry named `jig`, or the one whose own name (`name` in its `.jig/config.json`) is
   `jig`; `jig repos` shows it is registered by not printing where tool reports wait. Request
   access to each folder you need with the host's folder-access tool (in the Claude desktop app,
   `request_directory`), `~/.config/jig/` first if you can't read it; if the host has none, ask
   the user to add the folder to the session. Never stop at "no access": the folder is the
   user's to grant. If it is registered, write the file into `<its path>/.jig/staging/`
   (request exactly that folder; if it has no `.jig/staging/` yet, say so and suggest
   `/jig:update` in that repo, and don't create it). If not, write it into the `feedback/`
   folder beside your repos list (`jig repos` prints where; `~/.config/jig/feedback/` by
   default), requesting that folder the same way. Never a temp folder: reports there were lost
   when it was cleared.
3. Print the path. The report waits there until `/jig:fix` runs in the jig repo.
4. Stop. Do not edit `.jig/jig.py` or `.jig/RULES.md`, do not add a `WORKAROUND:` or a ledger row, do not commit.
   If the job is blocked, say so and ask the hubnode to park it.
