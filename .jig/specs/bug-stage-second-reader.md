# Bug: a staged batch gets no reader but its author

Source: Dave, chat with Claude, 2026-11-17 (staging Daisy's settings decisions and spec) (staged as feedback-Daisy-2026-11-17-stage-second-reader.md): "we should always double-check staged documents with an opus worker because every time ive done it they found things to correct, make it part of the staging command. please include this example."

Kept separate from rig-and-versioning: the owner, 2026-11-18, chose the rig specs and then versioning as one job, keeping this apart; this is a skill-only change to stage that shares tests/smoke.sh and the stage skill (a different section: versioning adds the pin-bump kind's resolving), and ships on its own lighter review.

## Intent
Before `/jig:stage` writes anything into the target's staging, a fresh worker that did not write
the drafts reads every one against a record of the conversation and reports what is missing,
overstated, added or contradictory; the staging session fixes what it reports and shows the
owner, then writes the files and runs `jig staging check`. A batch with no reader, or with a
record that isn't verbatim, is written marked unreviewed from the start. A file's `source:`
never changes once it is written.

## 1. Why
- Why did Daisy's staged batch need correcting after it was written? Its author was the session that had the chat, and it wrote its own reading of the chat as agreed.
- Why was that not caught? `/jig:stage`'s only check is `jig staging check`, which reads headers and warns on `Accepted` lines. Nothing reads a body against the chat.
- Why does nothing read the body? The skill has no review step. A job's diff gets a fresh-context review; a staged file, acted on cold later, gets none.

## 2. Givens
- [seen] Trunk at d578dee, `plugin/skills/stage/SKILL.md`, "Check before you say it's staged": the only check is `jig staging check`, which "names each bad header". No step reads a body. The reporter's copy (0.14.0, `jig_version` f0005adc5fe4) is the same here.
- [seen] Trunk is newer than the report in one way: it adds "Whose words" (the quote rule, from `f182a5c`, after v0.14.0): the owner's words appear only as `The owner, <date>: "<exact words>"`, and everything else is plain. That is a rule for the author; nothing checks that it was kept.
- [seen] Daisy's final files are still staged: `Daisy/.jig/staging/settings-00-decisions.md` and `settings-01-settings-home.md`. `jig staging check` (trunk's plugin copy) passes both, with an `Accepted` warning on each of the three entries. Every fix the report lists sits in a body.
- [seen] The final spec carries the marks the worker's findings call for: "did not answer the table itself", items marked † as "Claude added them here from the code", "an interpretation: the owner agreed … and no more", the pipeline "not declined: the owner said 'a pipeline would be nice'", and "the owner accepted the reversal on a wrong premise".
- [assumed] The first draft and the worker's findings as the report gives them. The draft is gone; only the fixed files remain. One detail differs from what is on disk: the report says the held question "became an `Open` decision entry", but `settings-00-decisions.md` has three `Accepted` entries and no `Open` one; the spec says the held question was "since settled in `lanes-00-decisions.md`".
- [assumed] "Every time ive done it": the owner's report of earlier sessions.
- [seen] `jig roles` refuses outside a repo ("jig: not a git repository", run in a scratch folder with `JIG_CONFIG`/`XDG_CONFIG_HOME` set). A staging chat cannot read the target's roles, so the step names the worker's tier itself.
- [seen] `plugin/tiers.json` maps tier 2 to Opus (`claude-opus-5-5`) and tier 3 to Sonnet. The model rule: no model name in `plugin/templates/` or RULES.md; a skill names a tier and effort, as `/jig:rigger` does ("at tier 3, effort 1, as `${CLAUDE_PLUGIN_ROOT}/tiers.json` maps them, in a context that has not seen your reasoning").
- [seen] The worker checks against the author's own record of the chat, not the transcript, and cannot read the target repo (from the report; nothing in the step changes either).
- [assumed] Some hosts a chat runs in cannot start a second worker.

## 3. One layer up
- Sibling with the same shape that already has the fix: `/jig:rigger`'s record. "Check: a reader with the sources and none of your conclusions sorts what it finds into wrong, unverifiable and omitted," and each entry is checked "at tier 3, effort 1 … in a context that has not seen your reasoning" [seen]. This step copies that pattern.
- `/jig:send` writes chat-born text into a repo too, but the owner reads and edits the whole reply in the approval window before anything is written [seen, send skill]. The owner is its second reader, so it needs nothing.
- `/jig:feedback` reports are read again by `/jig:fix`, whose bug role re-tags every given [seen, fix skill]. They have a second reader too.
- Resolving asks the owner "does this repo own the subject, and is it as settled as it says?" [seen]. That comes after the chat is gone, and it does not ask what is missing, so the lost questions and unmarked additions the report lists get through it.

## 4. Workaround or correction
Correction: the step goes into `/jig:stage` itself, so it runs without the owner asking. `jig staging check` stays a header check.

## General?
Yes. Any repo's chat sessions, and every rigger, stage through this skill, and the author is
always the session that had the chat. An agent writing its own reading as agreed is an ordinary
mistake. The quote rule and the `Accepted` warning on trunk show the owner has already met this
shape twice. RULES.md's promise is that a staged file is decided only when resolved. A file
that claims more agreement than there was undercuts that promise, so this asks for nothing
stricter.

## Done when
- [ ] `plugin/skills/stage/SKILL.md`, A batch, gets a **Second reader** item before "Check before you say it's staged". The reader reads the drafts before anything is written into the target's `.jig/staging/` (part 3). It says:
  - Start a fresh worker that has not seen your reasoning, at tier 2, effort 2, as `${CLAUDE_PLUGIN_ROOT}/tiers.json` maps them. Hand it every draft of the batch and a record of the conversation.
  - The record holds the owner's messages verbatim and in order, with your own proposals between them, marked as yours. It is not a summary of what was agreed.
  - The worker answers five questions for each file: what the chat raised that the files leave out (a question the owner held, a point left open); what the files call agreed, accepted or the owner's that the owner did not say, including a quote that is not verbatim; what the files add that the chat does not support and do not mark; what a cold reader in the target could not act on; and where the files contradict themselves or each other. It reports and edits nothing. It is told it cannot see the target repo, so it judges no code fact.
  - You fix what it reports, show the owner its findings and what you changed, and only then write the files into staging, before the word "staged". Nothing you filled in may stand unmarked: mark it in place or as an `Interpreted:` line, never under a heading about whose words it is (Whose words).
  - Where there is no reader (the host can start no worker, or the worker errors, times out or returns no report), say in the reply that the batch is staged unreviewed, and write each file with `source:` ending `; unreviewed`.
- [ ] Part 3 (replaces part 2's SF1 design): the reader reads drafts, not staged files. With no reader, the batch is written with `; unreviewed` from the start, and the mark is never removed: a file's `source:` is final once written, since a spec, page or commit made from it carries that exact line as its mark.
- [ ] SF2: where the stager can't give the owner's messages verbatim (after compaction, say), it hands the worker what it has, says so in the reply, and writes every file with `; unreviewed`. A summary, or a rigger's `record/`, is not this record.
- [ ] Resolving: a file whose `source:` ends `unreviewed` is named as unreviewed (no reader, or no verbatim record) when the owner is asked whether it is as settled as it says.
- [ ] No model name in the skill text: it names tier 2, effort 2 and `tiers.json`.
- [ ] Smoke, `sec_staging_batches`: one case asserts that the stage skill names the second reader, `tier 2, effort 2`, the verbatim record, and `unreviewed`. Part 3's case asserts that the reader reads drafts before staging, that no reader or a record that isn't verbatim means `; unreviewed` from the start, that `source:` is final once written, and that a summary or a rigger's `record/` is not the record. Run `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh staging_batches`, and show the output.
- [ ] Observable that it fires: a dry run of `/jig:stage` in a chat, staging a two-file batch into a throwaway repo (with `JIG_CONFIG`/`XDG_CONFIG_HOME` set). The worker's findings, or the unreviewed notice, appear before the word "staged". Record it in the handoff note.
- [ ] Observable that the symptom is gone: a replay on copies in the scratchpad, never on Daisy's staging folder. Rebuild a draft from Daisy's two final settings files with the report's faults put back:
  - the table written as "accepted as a whole";
  - "The engine gets no page" under the owner's words;
  - the † marks and the `Interpreted:` lines removed;
  - Intent saying no control is added or removed, without the Done when exceptions;
  - the pipeline listed as an alternative set aside;
  - the wrong-premise note removed.

  Write a record from the owner's quoted lines in the final files and the report. A worker at tier 2, effort 2, given the step's questions, names at least the overstated agreement and the Intent / Done when contradiction. Record its report in the handoff note.
- [ ] `marketing/FEATURES.md` (gitignored in the main checkout, edited there and not committed): a row for the second reader, added before the skill change, with what it is, where it came from (this report), why (the author does not see its own reading as a fault), and what it is not (a check of code facts, or a change to `jig staging check`).

## Out of scope
- Checking code facts in the target repo. The worker can't read it from a chat. Resolving's two questions stay as they are.
- Any change to `jig staging check`, `jig.py` or RULES.md: the `; unreviewed` mark rides in `source:`, which needs no new key.
- `/jig:send` and `/jig:feedback`: each already has a second reader (One layer up).
- A worker that reads the transcript itself: no host gives it one today. The author's record stays a risk, which the step reduces by asking for the owner's messages verbatim.

## Touches
`plugin/skills/stage/SKILL.md` (A batch, Resolving), `tests/smoke.sh` (`sec_staging_batches`),
`marketing/FEATURES.md` (not committed).

## Alternatives considered
- Leave it to the owner to ask each time. Rejected: the owner asked for it as a step, and it found faults the one time it was seen. This reason is [seen] for the Daisy case and [assumed] for the earlier ones.
- Have the staging session reread its own files. Rejected: the faults were the author's own readings, which the author took as right; the draft was believed correct when written. This reason is [assumed] (the report's account).
- Extend `jig staging check` to read bodies. Rejected: it is fixed code with no model and no conversation to compare against. This reason is [seen] (stage skill: it "names each bad header").
- Move the review to resolve time, in the target repo. Rejected: the chat is gone by then, and Resolving's two questions don't ask what is missing. This reason is [seen] (Resolving's text).
- Run the worker at the staging session's own model. Rejected: the owner asked for Opus, and a chat session may run on anything. Naming a tier keeps the rule that skills name tiers, not models. This reason is [seen] (the owner's words; `tiers.json`; the rigger skill's line).
- Mark every file `; unreviewed` when it is written and remove the mark once the findings are fixed and shown (part 2's SF1 design). Rejected: removing the mark breaks the exact-mark link. A spec, page or commit made from the file while it was marked carries `Source: …; unreviewed (staged as …)`, and once the mark is gone `jig staging resolve` no longer finds that carrier (exit 1, "write a new spec … carrying …"); rig's `taken` matching breaks the same way. This reason is [seen] (part 2's review-change, which reproduced it). Part 2 had rejected review-before-staging because a draft held outside staging would be lost to a crash or compaction; that was wrong, since a lost draft never reaches staging, which fails safe.
- A second mark, "partly reviewed", for a batch read against a record that isn't verbatim. Rejected: Resolving has one mark to name, and a reader working from a paraphrase cannot catch a misquote copied into both. This reason is [assumed].
- A new header key (`reviewed: no`) for an unreviewed batch. Rejected: `staging check` would have to learn it, and this fix needs no code. This reason is [assumed]; nobody checked whether `staging check` refuses an unknown key.

## Decisions
- Interpreted: tier 2, effort 2. Tier 2 is Opus in `tiers.json`, which is what the owner asked for. Effort 2 is the review role's default, since the worker is a review of prose. The owner said only "an opus worker".
- Interpreted: one pass. The worker reports once, the author fixes, and the owner sees both. The owner asked for no second round.
- Interpreted: what the author filled in is marked in place or as `Interpreted:` lines, which is how the final Daisy spec did it and how Resolving's feature-request spec does it. This follows trunk's quote rule, which forbids headings about whose words a line is, not marks.
- The owner, 2026-11-18, on SF1 and SF2: "Fix before merge".
- The owner, 2026-11-18: "Review before staging".
- Interpreted (SF1): a worker that errors, times out or returns no report counts as no reader, so the batch is written with `; unreviewed`. A session that ends or compacts before writing stages nothing.
- Interpreted (SF2): a record that isn't verbatim still gets a reader, but the batch is written with `; unreviewed` (Alternatives considered, the second mark).
- Interpreted: the report's Done when asked for "a quote under the owner's name is verbatim". Trunk's quote rule already says that, so here it becomes one of the worker's questions rather than a new rule.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
