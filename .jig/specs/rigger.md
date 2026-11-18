# rigger: a standard for the design session that feeds one product repo, and the inbox it answers through

Source: Cowork session (Maige OS app manager, Dave with Claude) / 2026-11-17 / Dave (staged as manager-relay-inbox-request.md): "Would it be possible to create a direct messaging link between you and the repo that isn't staging, to replace copyable responses? If so, I would still want to build that such that I can explicitly see the content suggested to send. It'd be ideal if you could show me a window with the content and a button to send that I could press to send to the repo's hubnode. I dont want hubnodes sending to app managers yet though, I like filtering that myself for now."
Source: Cowork session (rigger standard, Dave with Claude) / 2026-11-17 / Dave (staged as rigger-request.md): "`jig rigger <reponame>` for example `jig rigger Adventure-Studio` or `/jig:rigger `Adventure-Studio`` which would make the task the rigger for that repo, create the folder for the record and other docs, and update jig config."

The owner, 2026-11-17, in the inbox request:
- "I see something in a hubnode I wanna share here, I share it, once settled your reply includes an approval window that shows me your text, I approve it, you write a file, done? I like the jig inbox location, too."
- "Should there be a jig command I can use here proceeding feedback from a hubnode so you know whats going on?"
- "To save me some typing, let's also ask jig to create an entry for an "alias" for a repo in jig config so that I can come up with a shorthand when I'm typing relay."

The owner, 2026-11-17, in the rigger request:
- "Let's switch from "manager" to "rigger""
- "Instead of having jig write the pointer, let's have the manager write it when they're initiated."
- "I lean towards outside the repo, the app manager folders do a lot of drafting that I dont want getting into the repo."
- "it's a metarepo and is not an application or product. The other app managers feed into it" and "all repos have a hubnode."
- "Its okay for a rigger to read multiple repos. Especially when there's a meta/para relationship. It probably shouldn't be reading multiple repos without being part of a meta/para or being directly asked anyway"
- "I agree that should become a standard thing for app managers to make and manage."
- "A sonnet worker should double-check every record entry after its made, with a fresh context so it's not biased." Then: "instead of naming sonnet, name jig's plugin/tiers.json and say 3,1."
- "rulings can travel by inbox. I'll use inbox for replying to a hubnode's questions mostly, those are all rulings. if it can't rule it's useless." (in both requests)
- "Staged files need to be split by repo, then ideally by content, but its not a big deal if two features ride together in one staged file. Generally they should propose a plan for what to stage and then I'll approve, each one can use their judgement for what that looks like." And: "hubnodes notice conflict and I resolve."
- "I like letting the hubnode do it too. We dont need all these random headings making it into decisions and docs anyways about Dave and his words lol. Just need the info."
- "you're not trying to be prescriptive about how yet, only to imagine possibilities to explore why and what", "I dont want to explicitly say do why then what then how, it's more fluid than that." and "it can say how. If I want it to be less specific so the hubnode can interpret, I'll ask."
- Of reporting progress during long work: "Absolutely, this is very smart."
- "Standard shouldn't say"
- "jig is a tool for how all repos and app managers work, so problems in one repo that could affect others can be reported, but I control when those reports are filed so they aren't overused. A process or tool for one repo needs a home in that repo, and if jig doesn't have a clear home, that's very likely a feedback item for jig."

The quotes keep the owner's word "manager"; everywhere else this spec says rigger.

## Intent
The design session that holds one product's reasoning outside its repo, until now an "app
manager" with no standard, becomes a jig rigger: `jig rigger <repo>` (or `/jig:rigger <repo>`),
run by the session itself, makes it the rigger for one product repo, creates its folder outside
the repo, records the pointer in jig's repos list and briefs it; a rigger skill states what it
may read and touch, the record it keeps current and has checked, and how it stages and sends.
It answers its repo's hubnode through a one-way `.jig/inbox/`: the owner marks pasted hubnode
text with `/jig:relay <repo>`, settles a reply, and `/jig:send` shows it in a window he edits
and approves before one file is written; the owner's next prompt to the hubnode announces it,
`jig inbox` there shows it, and the quoted owner words in it rule. A repo in the repos list can carry short aliases, and a typed
repo name or alias matches case-insensitively everywhere one is typed.

## Parts
- Part 1, the inbox: `.jig/inbox/`, `jig inbox`, its hook, `/jig:relay`, `/jig:send`, aliases,
  the name rule, and the repos list keeping every key of an entry (Design 1–8, Done when
  "Part 1"). Ends with `jig handoff --partial`.
- Part 2, the rigger standard: `jig rigger`, `/jig:rigger`, the quote rule in `/jig:stage`, and
  RULES.md's Riggers paragraph (Design 9–12, Done when "Part 2"). Ends with `jig handoff`.

## Design
Part 1:
1. **The inbox.** `.jig/inbox/`, made by `jig init` and added by `jig update` (a STEPS entry
   beside staging's), holding only a `.gitignore` (`*`, `!.gitignore`) when empty: never
   committed, as staging isn't. One Markdown file per message, written by the sender. Read
   messages move to `.jig/inbox/read/`; one addressed to another repo moves to
   `.jig/inbox/misaddressed/`, named.
2. **A message.** File `<YYYY-MM-DD>-<slug>.md`, header:
   ```yaml
   ---
   inbox: true
   to: <repo name or alias from `jig repos`>
   from: <the sending session, free text, as staging's source>
   sent: <YYYY-MM-DD HH:MM>
   ---
   ```
   Body: the hubnode's question as a `>` quote, then the answer. The owner's own words appear
   only as `The owner, <date>: "<exact words>"`; everything else is plain text from the rigger,
   with no headings about whose words they are.
3. **`jig inbox`** (jig.py, stdlib), in the trunk checkout only (elsewhere it refuses: the inbox
   is the hubnode's): prints each unread message in full, oldest first, then moves it to
   `read/`; with none, `no unread messages in .jig/inbox/`. **`jig inbox check <file>…`**, run
   from the plugin's copy outside any repo as `staging check` is: fails on a missing header key
   or a `to` the name rule (7) doesn't find.
4. **The hook.** `plugin/hooks/hooks.json` gains `UserPromptSubmit` → `plugin/scripts/inbox.sh`:
   when the project is the trunk checkout of a jig repo that opted in (`.git/jig/enabled`) and
   `.jig/inbox/` holds an unread `.md`, it prints one line with the count and the command,
   `python3 .jig/jig.py inbox`, which shows the messages and marks them read; it reads and
   moves nothing itself. Otherwise it prints nothing. Always exits 0. `session-start.sh` counts unread messages beside open jobs
   and staged files when it decides the trunk checkout is the hubnode's.
5. **`/jig:relay <repo>`** (skill, `disable-model-invocation: true`): the text after it is the
   named repo's hubnode's words, never the owner's; the repo is found by the name rule (7),
   anything else refused with the list shown. It opens a thread in the conversation: a reply is
   owed to that hubnode.
6. **`/jig:send`** (skill, `disable-model-invocation: true`): for the open thread (asks which,
   naming them, if several; asks for a repo if none), shows the approval window: a decision
   card (`/jig:decision-cards`) with the repo at the top, the hubnode's question, the reply in
   an editable text field, and one button that fills `send to <repo>:` followed by the field's
   text. Nothing is written until the owner sends that reply; then the skill writes the
   message from the sent text exactly, into `<repo>/.jig/inbox/` (folder granted as staging's
   is), runs `inbox check`, and says it is sent, with the path, only once that passes. Where no
   card can be drawn: the text in a fenced block, and "reply `send to <repo>:` followed by the
   text, as it stands or as you edit it".
7. **Aliases and the name rule.** `jig repos alias <repo> <alias>` adds one to the entry's
   `aliases` list (`--remove` drops it); `jig repos` lists them; an alias equal to another
   entry's name or alias is refused, and near-duplicate warnings include aliases.
   `load_repos`/`save_repos` keep every key of an entry, so `repos add` never drops an alias.
   One rule, in `repo_path`, finds the repo for staging's target, `/jig:relay`, `jig inbox
   check`'s `to` and `jig rigger`: a name or alias from the list, case-insensitively. A name
   that matches one only once punctuation is dropped too (`near_duplicates`' key) is refused,
   naming it. After review (the hubnode, 2026-11-17): `repos add`, `rename` and `alias` refuse
   a label any other entry answers to (its checkout's own name included); a name more than one
   entry answers to finds none, refused naming them; `jig repos which <name>` prints the repo
   or the refusal, and the two skills call it.
8. **RULES.md**, an Inbox paragraph after Staging: a message is not a staged file (read and
   done with, never landed or resolved, and nothing else (commit, gate, release) looks at the
   inbox); one-way; quoted owner words with their date are the owner's ruling, as if given in
   the hubnode's conversation, and the rest is context; before acting, the hubnode checks the
   state it answers, as for a decision card's reply. The hubnode skill's Every session step 4
   adds `jig inbox`, for hosts with no hook.

Part 2:
9. **`jig rigger <repo> [--folder <path>]`** (jig.py, stdlib, run from the plugin's copy
   outside any repo):
   - The repo is found by the name rule (7). A repo with a near-identical twin in the list gets
     the twin warning.
   - A `meta` entry is refused: a metarepo has no rigger; its pararepos' riggers stage to it.
   - The folder: `--folder`, else the entry's existing `rigger` pointer, else
     `<the folder holding another entry's rigger folder>/<repo name>`, else refused asking for
     `--folder`. It creates what is missing and overwrites nothing: `record/`, `drafts/`,
     `staged/`, and `handoff.md`.
   - It writes `"rigger": "<absolute folder>"` on that repo's entry and changes nothing else.
   - It prints the facts the config and folders give: the folder and what it holds; every repo
     by its listed name, marked `yours`, `reads: its metarepo`, `reads: a pararepo of <meta>`,
     or `on request`; the target's staged files with each `source:` (who else is staging
     there); and whether the target has `.jig/staging/` and `.jig/inbox/`.
   - `jig repos` shows each entry's rigger folder.
10. **`/jig:rigger <repo>`** (skill, `disable-model-invocation: true`): asks for access to
    `~/.config/jig/`, runs the command, asks for its folder and, read-only, the narrowest
    folders of the repos it may read; reads `handoff.md` and the record if present; then holds
    to the standard, stated once in the skill. It says `/jig:rig` is the hubnode's, not the
    rigger's.
    - **Touches**: its folder freely; a repo's `.jig/staging/` on the owner's word; its own
      repo's `.jig/inbox/` through `/jig:send`, and no other repo's; reads its repo, that
      repo's metarepo and the metarepo's other pararepos, any other repo only when asked; never
      edits a repo; writes nothing to jig config but its pointer, through the command.
    - **The record** (`record/`): the owner's running account of one product at the finest
      detail, holding what the request lists (intent in his words, how the idea moved and who
      moved it, concepts, built, planned, open, the product among the others, where the
      authoritative text lives), pointing at that text, never copying it. Every claim names
      what it rests on: the owner's words with their date, a decision-log entry, the code, or
      the rigger's reading. A proposal he agreed to stays the rigger's until a decision log
      carries his name. It ends with a change log.
    - **Keeping it**: updated in the same turn as anything staged or sent, with a copy in
      `staged/`; nothing durable outside the owner's machine; each entry checked after it is
      made by a fresh-context worker at tier 3, effort 1 as `${CLAUDE_PLUGIN_ROOT}/tiers.json`
      maps them; on request, every ruling made in conversation not yet staged or sent.
    - **Metarepo and pararepos**, **staging** (a plan first, split by repo, only what was
      asked, staged only once `staging check` passes, no rigger senior), **how**, **long
      work**, **workers** (nothing beyond the record check), **feedback to jig** (only on the
      owner's word), as the request says them.
    - From the requesting session's proposal: the three-step new record (gather, write, check
      sorting wrong / unverifiable / omitted); the day-one briefing the command doesn't print
      (stages on request and never edits, the record, which source wins with the code on trunk
      first, anything for another session stands alone, the quote rule, how early the product
      is from its roadmap); `handoff.md` holding open `/jig:relay` threads and work in flight;
      and the shared habits list.
11. **`/jig:stage`**: a staged file quotes the owner exactly, with the date, where he asked for
    something; everything else is plain information, with no headings about whose words they
    are. The resolving hubnode sorts settled from open, as it does now.
12. **RULES.md**, a Riggers paragraph after the Inbox one, tool-agnostic: what a rigger is, that
    its folder lives outside every repo and no repo session can open it, and that it reaches a
    repo only by staging and the inbox.

## Done when
From manager-relay-inbox (Part 1):
- [ ] Smoke `inbox`: `jig init` makes `.jig/inbox/.gitignore`; `jig update` on a repo without
      it lists the step and `--apply` adds it; `git status --porcelain` shows nothing after a
      message is written there.
- [ ] Smoke `inbox`: with two unread messages, `jig inbox` in the trunk checkout prints both,
      older first, and moves both to `read/`; a second run prints `no unread messages`; in a
      job's worktree it refuses and moves nothing.
- [ ] Smoke `inbox`: `inbox check` passes a good message, and fails on a missing `sent` and on a
      `to` not in a `JIG_CONFIG` repos list; it passes with `to` set to an alias, and to that
      alias in upper case.
- [ ] Smoke `role_line` (or `inbox`): `inbox.sh` fed `{"prompt": "x"}` with
      `CLAUDE_PROJECT_DIR` at the trunk checkout holding one unread message announces the count
      and `jig inbox`, exits 0 and moves nothing; once `jig inbox` has read it, it prints
      nothing; in a job worktree, a folder with no `.jig/`, or a repo without
      `.git/jig/enabled`, it prints nothing and moves nothing. `hooks.json` registers it under `UserPromptSubmit`.
      `session-start.sh` names the hubnode in a trunk checkout whose only work is one unread
      message.
- [ ] Smoke `repos`: `repos alias app ap` then `jig repos` lists `ap`; `staging check` with
      `target: ap` and with `target: AP` passes, and with `target: a_p` fails naming `ap`;
      `repos alias other ap` and `repos alias other app` are refused; `repos add` of a third
      repo leaves `ap` in the file; `--remove` drops it.
- [ ] `plugin/skills/relay/SKILL.md` and `plugin/skills/send/SKILL.md` exist, each with
      `disable-model-invocation: true`; the decision-cards skill holds the editable-text block;
      `claude plugin validate ./plugin` passes.
- [ ] `grep -rniE 'app manager' plugin README.md` is empty, and so is `grep -rniw` over `plugin`
      for each name and alias `jig repos` lists, `jig` aside; `.jig/scripts/check.sh` exits 0;
      `bash tests/smoke.sh inbox repos role_line staging` passes.

From rigger (Part 2):
- [ ] Smoke `rigger` (a `JIG_CONFIG` repos list in the scratch dir): `jig rigger app --folder
      $T/_riggers/app` creates `record/`, `drafts/`, `staged/` and `handoff.md`, and writes the
      `rigger` key on `app`'s entry, leaving its alias in place. A second run with no
      `--folder`, after writing a line into `handoff.md`, reuses the pointer and keeps the line.
- [ ] Smoke `rigger`: `jig rigger APP` takes `app`'s entry; `jig rigger a_pp` is refused naming
      `app`; `jig rigger nope` is refused; a `meta` entry is refused; `jig rigger <app's alias>`
      works; `jig rigger other` with no `--folder` makes `$T/_riggers/other`; with no pointer
      anywhere, no `--folder` is refused.
- [ ] Smoke `rigger`: for a pararepo `p1` whose metarepo `m` lists `p1` and `p2`, the output
      marks `p1` yours, `m` its metarepo, `p2` a pararepo of `m`, and a plain repo `x` on
      request; it lists a file staged in `p1` with its `source:`; `jig repos` shows the folder.
- [ ] `plugin/skills/rigger/SKILL.md` exists with `disable-model-invocation: true`, holds
      `tiers.json` with "tier 3, effort 1" and says `/jig:rig` is the hubnode's;
      `grep -rniE 'sonnet|haiku|opus|fable' plugin/skills/rigger` is empty;
      `claude plugin validate ./plugin` passes.
- [ ] `grep -rniE 'app manager|app-manager' plugin README.md` is empty, and so is
      `grep -rniw` over `plugin` for each name and alias `jig repos` lists, `jig` aside.
- [ ] `.jig/scripts/check.sh` exits 0; `bash tests/smoke.sh rigger repos inbox staging` passes.

## Out of scope
- Hubnodes writing to riggers (the owner carries that way himself, for now).
- Waking an idle hubnode session: a message waits for the owner's next prompt there.
- Messages between two hubnodes or two riggers.
- A rigger for a metarepo.
- One session being the rigger for several repos.
- A rigger reading another rigger's folder.
- jig checking a rigger's habits: they are skill text, and nothing in a repo can see them.

## Touches
- `plugin/templates/jig/jig.py`: an `INBOX` constant, `ensure_inbox` (init, update `STEPS`),
  `cmd_inbox` and `inbox check`, `load_repos`/`save_repos` (keep keys), `repo_path` (the name
  rule), `near_duplicates`, `cmd_repos` (`alias`, the rigger folder), `cmd_rigger`, the
  argument parser.
- `plugin/templates/jig/RULES.md`: Staging (Inbox and Riggers paragraphs), Commands.
- `plugin/hooks/hooks.json`; new `plugin/scripts/inbox.sh`; `plugin/scripts/session-start.sh`.
- New `plugin/skills/relay/SKILL.md`, `plugin/skills/send/SKILL.md`,
  `plugin/skills/rigger/SKILL.md`.
- `plugin/skills/decision-cards/SKILL.md` (the editable-text block), `plugin/skills/hubnode/SKILL.md`
  (Every session, Rulings), `plugin/skills/repos/SKILL.md` (alias), `plugin/skills/stage/SKILL.md`
  (the quote rule).
- `README.md` (the day-to-day commands).
- `tests/smoke.sh`: new `inbox` and `rigger` sections, `repos`, `role_line`.
- `marketing/FEATURES.md` (gitignored, in the main checkout): rows for the inbox, relay/send,
  aliases and the rigger.

## Alternatives considered
- One command that opens and sends — rejected because the moment of sending must stay the
  owner's; the rigger never puts up a send window because it thinks talk is finished (the
  requesting session's proposal, adopted) — [assumed].
- A new staged kind for a ruling — rejected because a staged file lands in the repo and must
  resolve, and `jig release` waits while anything is staged; a message is read and done with —
  [seen] (RULES.md, Staging).
- A button that writes the file on click — not possible: a card's button only fills the
  owner's reply box and appends, so the owner's sent reply is the approval — [seen]
  (`plugin/skills/decision-cards/SKILL.md`, "Fill, never send").
- The hook shows and marks the messages read — rejected after review (the hubnode, 2026-11-17):
  a subnode session shares the trunk folder as its project, so its prompt would mark the
  hubnode's messages read; the hook announces a count and the hubnode runs `jig inbox` — [seen]
  (this repo's subnode sessions).
- An alias by `jig repos rename` — rejected because a rename replaces the name the list shows,
  one per checkout; the owner wants a shorthand beside it — [seen] (`cmd_repos`).
- The folder inside the repo — rejected by the owner: drafting must not reach the repo — [seen]
  (the request).
- jig writes the pointer when a repo is added — rejected by the owner: the rigger writes it when
  it starts — [seen] (the request).
- `jig rigger` matching names exactly, case included — rejected by the owner (W2): one
  case-insensitive rule for all four places a repo is typed; the wrong-repo incidents the
  request cites (one rigger planned a batch for the wrong repo, another guessed its target) are
  near-identical names, which stay refused — [seen] (the request; `repo_path` already matches
  case-insensitively).
- A `_riggers` path setting in jig config — rejected: the first `--folder` sets it implicitly,
  and repos.json maps names to repos, so a non-repo key there would read as a repo — [seen]
  (`load_repos` reads a string value as a path).
- The command prints the whole day-one briefing — rejected: rules about conduct belong in the
  skill; jig.py prints only what config and folders tell it, so it stays tool-agnostic —
  [assumed].

## Decisions
The owner, 2026-11-17:
- R1, one job or two: "merge into one job". Built in two parts (`## Parts`).
- R2, `/jig:rig` beside `/jig:rigger`: "keep both names; the rigger skill says /jig:rig is the hubnode's"
- R3, RULES.md's standard-terms line mapping the industry's *manager* to a hubnode: "keep it".
  The rename covers the app-manager concept only.
- R4, which hubnodes a rigger sends to by inbox: "only its own repo's". Other repos get staged
  files on the owner's word.
- R5, the approval window (a card whose button fills `send to <repo>:` and the text, since a
  card can't send [seen]; the file written from the sent reply): "accept click then Enter"
- R6, the two drafts: "accept both with these answers"
- W2, how a typed repo name matches: "case-insensitive for all four": `jig rigger`,
  `/jig:relay`, `jig inbox` and a staged target match a name or alias case-insensitively, by
  one rule; a near-identical name (`near_duplicates`) is still refused, which covers the
  wrong-repo incidents the rigger request cites. Where that request says the repo is "named
  exactly as the repos list has it", this spec reads it by W2.

- Interpreted: the requesting session's proposal is adopted for the two commands, the editable
  window, the question quoted above the answer, the hook that announces unread messages, and the
  inbox folder granted per repo as staging is. None of it is the owner's wording.
- Interpreted: the message marks the owner's words the way the rigger request asks of staged
  files (`The owner, <date>: "<words>"`, the rest plain), not with headings; only those quoted
  words rule.
- Interpreted: marking read moves the file to `.jig/inbox/read/`, gitignored and kept, so the
  hubnode can read it again; the ruling's durable home is whatever the hubnode records from it
  (a decision entry, a spec).
- Interpreted: `jig inbox` acts only in the trunk checkout, and the hook announces only there,
  so a subnode never marks a ruling read before the hubnode sees it.
- Interpreted: aliases are a list on the repos-list entry, set by `jig repos alias`, and count
  as the repos list naming the repo.
- Interpreted: the thread `/jig:relay` opens lives in the conversation; part 2's `handoff.md`
  gives it a durable place.
- Hook finding: [seen] the installed Claude Code (2.1.51) describes `UserPromptSubmit` as "Exit
  code 0 - stdout shown to Claude", and `SessionStart` alike; jig's own SessionStart hook
  already relies on that. [assumed] it holds in the current version: the hooks docs site could
  not be fetched from this session.
- Interpreted: the command and the pointer reconcile as the owner's two quotes allow: the
  session runs `jig rigger` when it starts, so the rigger writes its pointer, through the
  command.
- Interpreted: "jig config" is the user's repos list (`~/.config/jig/repos.json`), not a repo's
  `.jig/config.json`: the pointer is to a folder no repo session can open.
- Interpreted: the pointer is the folder's absolute path; a later `jig rigger` for the same repo
  reuses it, so a successor session takes over the same folder.
- Interpreted: a new rigger's folder defaults to beside the existing ones, so `_riggers` is
  named once, by the first `--folder`.
- Interpreted: the folder layout (`record/`, `drafts/`, `staged/`, `handoff.md`), the three-step
  new record, the day-one items and the habits list are the requesting session's proposal,
  adopted; none is the owner's wording.
- Interpreted: "tier 3, effort 1" is read from `tiers.json` when the check runs, so the standard
  names no model.
- Interpreted: "nothing durable anywhere but Dave's machine" means the rigger's folder, not a
  host's memory or cloud project files.
- Interpreted: the quote rule goes into `/jig:stage` for every chat, not only riggers, since the
  resolving hubnode reads every staged file the same way.
- Interpreted (hubnode, 2026-11-17): the inbox hook runs only in a repo that opted in (`.git/jig/enabled`), as check.sh does; rejected: no marker check, which would run a fetched repo's jig.py on any prompt.
- Interpreted (hubnode, 2026-11-17): the hook announces unread messages; the hubnode reads them with `jig inbox`, which marks them read; rejected: the hook marks them read, since a subnode session shares the trunk folder.
- Interpreted (hubnode, 2026-11-17): `jig rigger` refuses a --folder inside any listed repo's checkout, since a rigger's folder lives outside every repo (the owner: 'I lean towards outside the repo'); rejected: allowing it, which puts drafts in a repo.
- Kept separate from bug-decision-records: both add lines to RULES.md Commands and a step in `STEPS`, side by side; no shared function. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed", which has this one job apart.
- Kept separate from bug-gate-pair-answers: nothing shared beyond the files. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed", which has this one job apart.
- Kept separate from bug-meta-agents-block: nothing shared beyond the files. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed", which has this one job apart.
- Kept separate from bug-process-in-pages: both edit the hubnode skill, in different parts; the rigger skill is that spec's "procedure an agent runs" row. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed", which has this one job apart.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
