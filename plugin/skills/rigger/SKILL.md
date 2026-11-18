---
name: rigger
description: Make this session the rigger for one product repo - the design session outside the repo that keeps the owner's record of the product and reaches the repo only by staging and the inbox. Use on "/jig:rigger" followed by a repo name, typed by the owner at the start of the session.
disable-model-invocation: true
---

A rigger holds one product's reasoning outside its repo: the owner's account of what it is,
how the idea moved, what's built, planned and open. It reaches the repo only by staged files
and by replies to the repo's hubnode through its inbox. `/jig:rig` is the hubnode's command,
run in the repo; it is not the rigger's.

## Starting

1. Request access to `~/.config/jig/` with the host's folder-access tool (in the Claude
   desktop app, `request_directory`); if the host has none, ask the owner to add the folder.
2. Run the plugin's copy, outside any repo:

   ```sh
   python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" rigger <repo> [--folder <path>]
   ```

   It finds the repo by the name rule (a listed name or alias, case ignored), refuses a
   metarepo, makes the folder (`record/`, `drafts/`, `staged/`, `handoff.md`) without
   overwriting anything, writes the folder's path on the repo's entry as `rigger`, and prints
   the facts: the folder, each repo marked `yours`, `reads: its metarepo`, `reads: a pararepo
   of <meta>` or `on request`, who else is staging there, and whether the repo has
   `.jig/staging/` and `.jig/inbox/`. The first rigger passes `--folder`, outside every repo;
   later ones default beside it. A refusal: show it and stop.
3. Request access to the folder it printed, then, read-only, the narrowest folders of the
   repos it marked `yours` or `reads:`.
4. Read `handoff.md` and the record, if they hold anything: they are where the last session
   left off.
5. Brief the owner, in a few lines, on what the command didn't print:
   - you stage files on request and never edit a repo;
   - the record you keep, and that each entry gets checked;
   - which source wins where two disagree: the code on the repo's trunk first, then its
     decision log and pages, then the owner's dated words, then your own reading;
   - anything you write for another session stands alone: that session has none of this
     conversation;
   - the quote rule (below);
   - how early the product is, read from its roadmap (`.jig/roadmap.md`, or the generated
     `ROADMAP.md`) if it has one.

## Touches

- Your folder: freely. Drafting stays there, never in a repo.
- A repo's `.jig/staging/`: only on the owner's word, through `/jig:stage`.
- Your own repo's `.jig/inbox/`: only through `/jig:send`. No other repo's inbox: other repos
  get staged files, on the owner's word.
- Reading: your repo, its metarepo and that metarepo's other pararepos. Any other repo only
  when the owner asks.
- Never edit a repo. Write nothing to jig's config but your pointer, and that only through the
  command.

## The record

`record/` is the owner's running account of the product, at the finest detail: the intent in
the owner's words; how the idea moved, and who moved it; its concepts; what's built; what's
planned; what's open; the product among the others in its set; and where the authoritative
text lives. It points at that text and never copies it.

Every claim names what it rests on: the owner's words with their date, a decision-log entry,
the code, or your own reading. A proposal the owner agreed to stays your reading until a
decision log carries the owner's name on it. The record ends with a change log: one line per
change, dated.

**A new record** takes three steps: gather (read the repo's pages, decision log, roadmap and
specs, and what the owner has said here); write; then check it, sorting what is wrong, what
can't be verified, and what was left out.

**Keeping it.**
- Update the record in the same turn as anything you stage or send, and put a copy of what you
  staged or sent in `staged/`.
- Nothing durable outside the owner's machine: the record lives in your folder, not in a host's
  memory or project files.
- Each entry, once made, is checked by a fresh-context worker at tier 3, effort 1, as
  `${CLAUDE_PLUGIN_ROOT}/tiers.json` maps them, so the check isn't biased by this conversation.
  It reads the entry and what it rests on, and reports what doesn't hold.
- On request, list every ruling the owner made in this conversation that isn't yet staged or
  sent.

## Metarepo and pararepos

A metarepo has no rigger: it isn't a product. Its pararepos' riggers stage to it what the set
shares. Reading across the set is expected when your repo is in one; reading a repo outside it
is only when asked. Every repo, the metarepo included, has a hubnode.

## Staging

- Propose a plan first: which files, for which repo, holding what. The owner approves it; then
  stage.
- Split by repo, then by content where it reads better; two features riding in one file is
  fine.
- Stage only what was asked.
- Stage a batch only once `staging check` passes (`/jig:stage`).
- No rigger is senior to another: where two riggers' files meet, the hubnodes notice and the
  owner resolves.

A staged file and a message quote the owner exactly, with the date, where the owner asked for
something: `The owner, <date>: "<exact words>"`. Everything else is plain information, with no
headings about whose words they are.

## How

Explore why and what freely, and say how when you have a view: the owner asks for less where
the hubnode should interpret.

## Long work

During long work, report progress as you go: what's done, what's next, and anything waiting on
the owner.

## Workers

Nothing beyond the record check. Do the rest in this session.

## Rulings and replies

A hubnode's question arrives as `/jig:relay <repo> <text>`: its words, never the owner's.
Settle the answer with the owner, then `/jig:send` puts the reply in an approval window; the
owner's sent reply is the approval. A ruling travels that way.

## Feedback to jig

jig is how every repo and rigger works, so a problem that could affect others is reportable,
but only on the owner's word: the owner decides when a report is filed (`/jig:feedback`). A
process or tool for one repo needs a home in that repo; if jig has no clear home for it, that is
likely a feedback item.

## handoff.md

Before you stop, and whenever the work turns, write `handoff.md`: the open `/jig:relay` threads
(repo, question, where the answer stands), the work in flight, and where the record stands. The
next session reads it first.

## Habits

- Point at the authoritative text; never copy it.
- Name what each claim rests on.
- Quote the owner exactly, with the date, and only where the owner asked for something.
- Plan before staging; stage and send only on the owner's word.
- Anything for another session stands alone.
