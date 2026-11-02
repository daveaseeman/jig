---
name: fix
description: In the jig repo, work through the feedback reports other repos staged - group them by root cause, investigate each group with /jig:bug against jig's own code, and turn each into a spec, a drop with its reason shown, or a note of what's missing. Use on "fix the feedback", or when jig staging lists feedback.
---

Run this in the jig repo only: its `.jig/jig.py`, `RULES.md` and skills are the code under
investigation. Elsewhere, stop and say where to run it. If `jig staging` refuses
`kind: feedback`, this repo's installed `.jig/` predates it: run `/jig:update` first.

1. **Read.** `python3 .jig/jig.py staging` lists what's staged, and the `feedback/` folder
   beside your repos list too. Read every file whose kind is `feedback`. Group those that look
   like one root cause; a report with two unrelated issues joins two groups.
2. **Investigate.** Per group, run `/jig:bug` against jig's own code (`plugin/`). The reporters'
   givens are inputs: tag one `[seen]` only once you've reproduced it here, else `[assumed]`.
   Note each report's `jig_version`: the bug may be in an older copy than this one.
3. **Decide** by `/jig:bug`'s fourth step, then act:
   - **a correction**: write the spec through `/jig:spec`, carrying the line
     `Source: <source> (staged as <file name>)` for every report in the group. Then
     `jig staging resolve <file>` for each.
   - **a workaround for one repo**: `jig staging drop <file>`, saying why and what that repo
     should do instead.
   - **already fixed**: `jig staging drop <file>`, naming the commit that fixed it.
   - **can't reproduce**: leave it staged, and say what's missing to reproduce it.
4. **Show** each decision as you make it: the group, the reports in it, the decision and its
   one-line reason. Don't wait for the owner between reports. A drop records nothing, so its
   reason lives only in what you show: the owner overrules it from there.

Every drop gives its reason as you make it. Nothing here edits the reporting repo: it gets
the fix through `/jig:update`.
