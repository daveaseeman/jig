# /jig:rig: the repo's picture and its batch of decisions

Source: cowork session 2026-11-16 (Dave + Claude) (staged as rig.md): "I want one command that answers "what's next?" with one picture and one batch of decisions."

## Intent
`/jig:rig` gives, in one run, a standard picture of what can start now, what
waits on what and what waits on the owner, then one short block per decision. It covers specs
ready to run, staged files ready to become specs, staged files that need the owner's answers,
and the roadmap's next step. It asks before writing a spec or starting a job, and `/jig:rig auto`
does both without asking while leaving the owner's questions open. The same state always
gives the same picture and the same recommendations. It is called only by name: no phrase
and no other command is an alias for it.

## The four kinds of item (shorthand, from the request)

| Kind | What it is | Where it comes from |
|---|---|---|
| ready spec | a spec no job has opened yet | `.jig/specs/`, the waiting-spec rule `jig consolidate` already uses |
| staged, ready | a staged file that can become a spec as it is | `jig staging`, by the rule below |
| staged, open | a staged file that needs the owner's answers first | the same, by the rule below |
| next step | one step ahead on the roadmap, as if staging and specs were cleared | `.jig/roadmap.md`: Up next items first, then the current phase's first scope no spec or staged file takes |

Whether a staged file is **open** (it needs the owner's answers first) or **ready** (it can
become a spec as it is) is the `/jig:rig` skill's judgment, made each run by reading the file.
`jig rig` lists every staged file with its header and leaves that call to the skill. The
skill gives each open file the questions it needs answered, and those become the question
blocks.

## What it shows

1. **The picture**, the same layout every run, drawn from `jig rig`'s output:
   - a count line first: "N things are waiting on your answers", plus how many can start now;
   - **Can start now:** ready specs and ready staged items, grouped into proposed jobs
     (overlapping Touches → one job, as `jig consolidate` groups; `after:` and spec
     dependencies → ordered within it);
   - **Waiting on:** each item and what it waits for, whether a job, a spec or a staged file;
   - **Waiting on you:** open staged items and the next step;
   - **Running:** open jobs, each with its next step, the role that does it, and whether it
     continues a session or starts one, read from `jig next <job>`, which is unchanged.
2. **Then one block per question**, drawn with the `decision-cards` skill (its card, or its
   text form where the host can't draw one), open staged items first, then the next step. Each block
   has a line saying what it's about ("fixing X in Y"), a line of context ("in Y, X is used
   for Z, so it needs to…"), then the options with one marked recommended, plus "not now".
3. **After the owner answers**, the picture again, so the owner sees items move from open to
   ready to running.

## Done when
- [ ] `jig rig` (in `jig.py`, tool-agnostic) prints the four kinds and the open jobs as plain
      text, and `jig rig --json` as data: each item's kind, id, path, what it waits on, and its
      proposed job group; staged files are listed with their headers, unclassified. Smoke: a
      fixture with one ready spec, two staged files, a roadmap with an Up next item, and an
      open job prints each in its place.
- [ ] Same state, same answer: two `jig rig --json` runs with nothing changed print identical
      bytes, and the order is defined (by kind, then dependency order, then path), never by
      file-system or dict order. Smoke runs it twice and compares.
- [ ] Judgments repeat: for each item the skill stores its open/ready call, its questions and
      its recommended option in `<git-common-dir>/jig/rig.json` (never committed), keyed by the
      item's path and a hash of its content and the board. A run whose key matches replays the
      stored call, questions and recommendation; a changed item or board is judged afresh.
      `/jig:rig fresh` re-judges everything. `jig rig` reads and writes the store
      (`--store-get`/`--store-put`), so smoke checks it is read back, ignored once the item's
      content changes, and cleared by `fresh`.
- [ ] Grouping: ready specs and ready staged items whose Touches overlap are proposed as one
      job, and an item that depends on another (`after:`, or a spec naming one it builds after)
      is placed after it in the same group. Smoke covers one overlap and one dependency.
- [ ] Roadmap look-ahead only proposes: `jig rig` never writes `.jig/roadmap.md` or staging.
      Smoke checks both files are byte-identical after a run.
- [ ] `/jig:rig` (a new skill) draws the picture and the question blocks from `jig rig --json`.
      It asks before writing a spec from a ready staged item, and before starting a job, and
      treats "not now" as an answer: the item stays open, comes back next run, and is never
      dropped. After the answers it runs `jig rig` again and shows the picture.
- [ ] `/jig:rig auto` writes specs from ready staged items and opens and starts every job it
      can, answers no open question, proposes roadmap pulls only, and ends with the picture and
      a short list of what it did.
- [ ] No aliases: `jig rig` and `/jig:rig` are the only ways in. `jig next` and its output are
      byte-for-byte unchanged (smoke's `next` section passes untouched). Neither the rig skill's
      description nor the hubnode skill's names "what's next" or "next" as a trigger:
      `grep -rniE "what.?s next" plugin/skills` finds nothing. Any hubnode text that improvised
      a "what's next" answer is folded into rig or deleted.
- [ ] RULES.md names `jig rig` and the four kinds, in tool-agnostic terms, and the README's
      "Who does what" lists rig as the hubnode's entry point.
- [ ] `bash tests/smoke.sh rig` passes, plus the sections the change touches; the full suite
      runs once at the gate. `claude plugin validate ./plugin` passes, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` is empty.

## Out of scope
- Answering the owner's questions in auto mode, or writing the roadmap: the request rules both
  out.
- A scheduler that runs rig on its own: the owner or the hubnode starts it.
- The look of the picture beyond its fixed sections: the skill may draw it richer where the
  host can (an inline visual), and falls back to text where it can't.

## Touches
- `plugin/templates/jig/jig.py` (a new `cmd_rig`, reusing the waiting-spec rule, staging's
  reader, the roadmap parser, `next_step` (read, not changed), and consolidate's overlap check;
  the parser)
- `plugin/templates/jig/RULES.md` (Staging, Roadmap, Workflow: rig)
- new `plugin/skills/rig/SKILL.md`, which loads `plugin/skills/decision-cards/SKILL.md` for its question blocks; `plugin/skills/hubnode/SKILL.md` (its description and any
  "what's next" text)
- `README.md` (Who does what), `tests/smoke.sh` (a new `rig` section)

## Alternatives considered
- Keep "what's next" as a hubnode trigger beside rig — rejected by the request ("including the
  phrase"), and an alias of rig was rejected by the owner, 2026-11-16: "build jig rig with no
  aliases".
- Make `jig next` an alias of rig — rejected: `jig next` is the workflow's per-job step, read by
  six skills; the owner: "keep jig next as-built for workflows and dont change it".
- Let the model compute the picture each run — rejected because "same state, same answer"
  needs the state, its order and its grouping computed by `jig.py`, not reread by a model —
  [assumed].
- Mark open vs ready by a marker in the file (an `## Open questions` section) — rejected by the
  owner, 2026-11-16: "rig lets the model judge open vs ready each run".

## Decisions
- The owner, 2026-11-16: the model judges open vs ready each run, by reading the file.
- Interpreted: the roadmap's next step is the first Up next item, else the current phase's
  first scope that no spec or staged file takes. One step, as the request says.
- The owner, 2026-11-16: "keep jig next as-built for workflows and dont change it. build jig
  rig with no aliases". This narrows the request's "phrases like 'what's next' trigger it
  too": rig is called by name only, and the "what's next" phrase triggers nothing.
- The owner, 2026-11-16: rig stores its open/ready calls and recommendations and replays them
  until the item or board changes, so "same state, same answer" covers the model's judgments.
- Interpreted: `/jig:rig fresh` is the way to re-judge on purpose, and the store lives in the
  git dir, local and never committed.
- Interpreted: `jig rig` prints plain text and JSON; drawing the picture is the skill's, so
  `jig.py` and the templates stay tool-agnostic.
- Interpreted, accepted by the hubnode 2026-11-16: "a spec naming one it builds after" is the
  repo's existing prose line `` Build after `<name>` ``, matched against waiting specs, staged
  files and open jobs (by name or by their spec's name). No new header for specs.
- Interpreted, accepted by the hubnode 2026-11-16: grouping counts only the staged files whose
  stored judgment says ready, so `jig.py` never guesses; the skill judges, stores, then reruns
  `jig rig --json`. No `--ready` flag.
- Kept separate from bug-sync-trunk-edits: different code in jig.py (rig adds a command; the bug fix changes the R3 check and added-line counting), and the fix shouldn't wait on rig. The owner, 2026-11-16: "Keep separate".

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
