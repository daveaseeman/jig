---
name: feedback
description: Report a bug in the jig tool itself (.jig/jig.py, .jig/RULES.md, its hooks, or a skill) for the plugin owner. Use when the tool, not the repo's code, misbehaved. Changes nothing in the repo.
---

This is `/jig:bug` pointed at the tool. The user decides which one applies; don't guess.

Investigate exactly as `/jig:bug` does — whys, givens tagged `[seen]`/`[assumed]`, one
layer up, workaround or correction, spec — reading `.jig/jig.py`, `.jig/RULES.md`, the
hook output, and the skill involved.

Then:

1. Write the report as a staged file, `feedback-<repo>-<date>.md`. One section per issue,
   each with the five steps and a "done when" the plugin owner can test. Its header:

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

2. Find the jig repo with `python3 .jig/jig.py repos` (it needs only `~/.config/jig/`). If an
   entry is named `jig`, write the file into `<its path>/.jig/staging/` — ask for access to
   exactly that folder. If not, write it into `~/.config/jig/feedback/`. Never a temp folder:
   reports there were lost when it was cleared.
3. Print the path. The report waits there until `/jig:fix` runs in the jig repo.
4. Stop. Do not edit `.jig/jig.py` or `.jig/RULES.md`, do not add a `WORKAROUND:` or a ledger row, do not commit.
   If the job is blocked, say so and ask the hubnode to park it.
