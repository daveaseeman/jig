# findings-record

Source: jig hubnode side session (Daisy survey), 2026-11-12, raised by the owner (staged as feedback-Daisy-2026-11-12-update-leaves-old-contract-enforcers.md): 26 of Daisy's pages are still in the wrong form after update, survey and redocument have all run with the owner's approval.

Report issue 2 of 4. The owner's words: "We need to re-architect what a yes MEANS."

## Intent
A yes to a finding is recorded on trunk and carried out, and it stays carried out. Each finding survey and update raise has an id and one recorded outcome. jig carries out an approved move itself. A remap row that contradicts survey is refused unless the owner's exception is recorded. Survey reports each finding's state, not just the finding.

## Why
1. Q: Why are Daisy's lone folder pages still in folder form after three approved runs?
   A: No yes reached them. Update's yes covered the layout only, and the approved remap keeps them where they are.
2. Q: Why did the approved remap keep them, against survey?
   A: A pasted brief misread RULES.md, and nothing compared the remap to survey. The contradiction was one line of prose, approved with the rest.
3. Q: Why can a yes be lost or contradicted with no trace?
   A: A finding has no id and no recorded outcome. Answers live in chat, `--apply` carries out none, and survey can't tell unanswered from deferred.

## Givens
- `[seen]` Daisy transcript `73019500…`:
  - line 17077: the update session lists "26 pages alone in their own folder… move each one up" and recommends "the redocument project here too";
  - line 17074: the only question is "Apply the jig update and add the setup line?";
  - line 17081: the owner answers "Yes, apply both";
  - `git show --stat 9450375d` moves no page.
- `[seen]` `plugin/skills/update/SKILL.md`: Repo files to review are made "only on a yes. `--apply` never touches them". For the wrong shape it says "ask before each". `redocument` step 1 says "decline them all, because the remap places every page".
- `[seen]` Daisy transcript `609eb98d…`:
  - line 427, the first remap: "Every part page goes flat (`docs/<system>/<part>.md`), as the contract asks";
  - line 431, a pasted brief: "Keep the folder form …, which RULES.md accepts. Don't flatten pages";
  - line 435, the revised remap: "No page is flattened", and survey's 27 "flat at" lines "I'll treat … as accepted";
  - line 444, the owner approves it and names only the glossary as an exception.

  It is committed as Daisy's `.jig/redocument.md` (`31481708`). Rows 3, 4 and 18 say `same` for 24 of those pages. Rows 13–15 merge the other three away.
- `[seen]` A scratch repo with `docs/a/b/b.md` and `docs/a/c/c.md`, each alone in its folder:
  - `jig update` lists both under "Repo files to review (update never applies these)", each with its `git mv`;
  - `--apply` leaves both where they are;
  - `jig survey` lists both, and its last line says "On jig already: nothing to do."
- `[seen]` `jig survey` on a clone of Daisy at `df641b1d` lists 27 pages as "flat at …: its folder holds nothing else", with no state.
- `[seen]` `jig.py` records no outcome anywhere. `BOARD_OPTIONAL` holds `workflow`, `deep_subsystems` and `boards`, and nothing in it reads `.jig/redocument.md`.
- `[seen]` `deep_subsystems` is already an owner's exception recorded on trunk:
  - R5 makes it trunk-only;
  - an empty rationale doesn't count (`unapproved()`);
  - survey stops listing the page it approves.
- `[seen]` `--merge-log` and `--sweep` already carry out review items on the owner's yes.
- `[seen]` Redocument step 6 deletes `.jig/redocument.md` at cleanup.
- `[seen]` The report's `jig_version` `1a8efef0e75c` is `git hash-object` of today's `plugin/templates/jig/jig.py`.
- `[assumed]` The brief's "RULES.md accepts" the folder form came from RULES.md's "Both forms are one page" sentence, which is about naming. It is kept as a risk, and the wording item below answers it either way.

## One layer up
- `deep_subsystems` is the healthy pattern for one kind of finding: an exception on trunk with the owner's reason, which survey reads. Other findings have nothing like it.
- `--merge-log` and `--sweep` carry out their items on a yes. Page moves have no equivalent; their `git mv` lines are only printed.
- Daisy's `.jig/redocument.md` records and resumes per-row decisions. But it lasts one run, and nothing checks it against survey.

## Design
- **Ids.** Each file finding survey prints, and update lists under Repo files to review, has an id `<kind>:<path>`. The kind is the one survey's `--json` gives it (`shape`, `page`, `deep`, `contract`, …).
- **The record.** `findings`, an optional key in `.jig/config.json`, trunk-only under R5 like `deep_subsystems`: `{"<id>": "approved" | "deferred: <where>" | "exception: <the owner's reason>"}`. It has one entry per id and no globs. An exception with no reason doesn't count. jig acts on the recorded entry, never on an answer in chat.
- **Carried out.** `jig update --apply` carries out each `approved` move, whether or not the layout is current. A move is a `shape` finding, or a `page` outside the tree that isn't a fold.
  - It makes the `git mv`, rewrites the board keys that name the old path (`docmap`, `boards`) and drops the entry.
  - It drops an approval or a deferral whose finding no longer fires: that question is settled.
  - What it can't do, it prints for the session as today: references in other files, `contract_paths`, `BUFFER.md` rows, edits. An approved finding it can't carry out stays recorded.
  - The usual update refusals apply (open jobs, tracked changes), and it commits nothing.
- **Answers stay put.** An entry answers the finding with its id, at its path, and nothing reads it anywhere else. jig changes `findings` only where it acts itself: its own carried-out move (exact: the git mv, docmap and boards, that entry dropped, the page's other entries moved to the new path), and dropping a settled approval or deferral. It never moves an entry by inference and never drops an exception. Survey lists each exception that answers no finding ("drop it on trunk, or record it at the page's new path"), in its print and as `exceptions_unused` in `--json`, and counts them in its last line. The list is held back while `.jig/redocument.md` is on trunk.
- **State.** Survey and update's review list print each finding's outcome beside it:
  - not answered;
  - approved, not done;
  - `deferred: <where>`;
  - `exception: <reason>`.

  `--json` carries `id` and `outcome`. Survey's last line counts the unanswered and approved findings, so it never says "nothing to do" while one stands.
- **Contradictions refused.** jig reads `.jig/redocument.md`'s table by its `Old path(s)` and `New path` columns, where `same` keeps the old path. The hook refuses a commit that adds or changes the file while a row keeps a page at a path survey moves it from (a `shape` or `page` finding), unless `findings` records the owner's exception for it. The refusal names the path, survey's destination and the entry to record. Survey names such rows in a remap already on trunk.
- **Asking.**
  - Update skill: list the findings with their ids and take one answer each: yes, defer to where, or an exception with the owner's reason. Record the answers on trunk in one commit, then run `--apply`. A recommendation is not an answer, and no one question covers some findings and leaves the rest.
  - Redocument step 1 records each page move it takes as `deferred: redocument`.
  - Redocument step 2 shows a row that keeps a page where survey would move it as an exception to jig's rule, with survey's line beside it. The owner's reason is recorded before the remap is committed. A brief that says jig accepts the form is checked against survey.
  - Redocument step 2 also records, in the remap's commit, an exception for a page the remap moves, merges or splits at the new page's id, on the owner's word.
  - Redocument step 6: the cleanup removes the old paths' `findings` entries with their docmap keys, and survey lists no finding unanswered or deferred to redocument, and no exception that answers no finding.
- **Wording.** RULES.md's "Both forms are one page" sentence says it is about naming: a key names a page in the wrong form, and that page still moves.

## Done when
- [ ] Smoke `findings`: a repo with `docs/a/a.md`, `docs/a/b/b.md` and `docs/a/c/c.md`, where b and c are alone in their folders and docmap names all three.
  - `jig survey --json` gives b and c the ids `shape:docs/a/b/b.md` and `shape:docs/a/c/c.md`, with outcome null. The print marks both not answered, and its last line names `/jig:update`.
  - Commit `findings` `{"shape:docs/a/b/b.md": "approved", "shape:docs/a/c/c.md": "deferred: redocument"}` on trunk. With no `git mv` run by the test, `jig update --apply` leaves:
    - `R100 docs/a/b/b.md docs/a/b.md` in `git diff --cached -M --name-status`;
    - `findings` holding only c's entry;
    - `docs/a/c/c.md` where it was.

    This is the fix firing.
  - After that commit, `jig survey` prints c with `deferred: redocument` and prints nothing for b.
  - The pre-commit hook refuses a commit adding `.jig/redocument.md` with the row ``| `docs/a/c/c.md` | same | rewrite | |``, naming `docs/a/c/c.md`, `docs/a/c.md` and `findings`.
    - It still refuses with `"exception: "`, which has no reason.
    - With `"exception: the generator reads folder paths"`, the commit passes, and survey prints c with that exception.
    - A row that moves c to `docs/a/c.md` commits with no entry.
  - With no `findings` entry, `--apply` leaves both pages where they are, as today.
- [ ] Smoke `findings`, answers stay put. b off the contract carries `contract:docs/a/b/b.md: exception: table lead`.
  - Rename: a job renames b to `docs/a/q.md`. `--apply` drops only the deferral and keeps the exception at b's id. Survey lists it as answering no finding, counts it in the last line, and shows q's contract finding not answered.
  - Merge: the remap merges b into a, and b is deleted. `--apply` keeps the exception, and survey holds back the unused list while the remap is on trunk.
  - Split: the remap splits b into e and f. The exception lands on neither half, and both are not answered.
  - By the book: the remap moves b to `docs/a/e.md`, the owner's exception is recorded at e in the remap's commit, and the cleanup removes b's entries. Survey ends with e's exception shown and no exception unused.
  - Metarepo: after the job's move of an approved page merged, trunk's `--apply` drops the approval and keeps the page's exception at the old id.
  - Kept: an exception the remap check asked for outlives `--apply` while the remap stands, and a page that changed form by hand doesn't carry its move's answer onto the opposite move.
- [ ] The symptom, on Daisy. In a scratch clone at `df641b1d`, with this `jig.py` as `.jig/jig.py`, `jig survey` names the 24 pages that `.jig/redocument.md` rows 3, 4 and 18 keep in folder form. It reports each as contradicting survey with no exception recorded, so the approval that left them is no longer silent. Daisy itself is not touched.
- [ ] `grep -n findings plugin/skills/update/SKILL.md plugin/skills/redocument/SKILL.md` shows the record step in each. `grep -n "decline them all" plugin/skills/redocument/SKILL.md` finds nothing.
- [ ] RULES.md Documentation states the record, its outcomes, the carry-out, the remap check and the naming wording. The command list says `jig update --apply` carries out approved moves.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Issues 1, 3 and 4 of the report are other groups: the old contract's enforcers, a hook or gate refusing pages in the wrong form, and system vs subsystem. Each can give its findings ids in this record.
- Daisy's pages and remap. Daisy gets this through `/jig:update`, and its owner then answers survey's contradictions.
- Folding `deep_subsystems` into `findings`. It is already the `deep` finding's exception, and the homes check reads it.
- Repointing references in the repo's own files on a yes. Those are edits, not renames, and stay the session's.
- The review list's other lines (AGENTS.md lines, the log merge, the sweep). Each is already one ask with its own carry-out.
- Contradictions a path can't show, such as a move to a third path or a merge. Review catches them.

## Touches
- `marketing/FEATURES.md`: a "Findings record" row, before the code.
- `plugin/templates/jig/jig.py`:
  - `BOARD_OPTIONAL` gains `findings`;
  - finding ids, and the outcomes in survey's print, `--json` and last line;
  - update's Repo files to review;
  - `cmd_update --apply` carries out approved moves (reusing `home_findings`'s `commit_lines`) and drops entries;
  - a reader for the remap's two path columns;
  - the remap refusal in `check_rules`, and survey's contradictions line.
- `plugin/templates/jig/RULES.md`: Documentation, and the command list.
- `plugin/skills/update/SKILL.md`, `plugin/skills/redocument/SKILL.md`, `plugin/skills/survey/SKILL.md`.
- `tests/smoke.sh`: a `findings` section.

## Alternatives considered
- Skill text only: ask per item, and write deferrals down. Rejected because the update skill already says "ask before each", and the session grouped the items anyway. A rule that only a skill states fails the way this one did. Reason is [seen]: transcript `73019500…` line 17074, update SKILL.md.
- Keep the outcomes in `.jig/redocument.md`. Rejected because cleanup deletes it, so an exception would vanish and survey would list the pages again. Update's findings also come before any remap exists. Reason is [seen]: redocument step 6.
- A new record file such as `.jig/findings.md`. Rejected because `config.json` already holds jig's one owner-approved exception record, R5 keeps it trunk-only, and survey and update already read it. A new file is a new home. Reason is [seen].
- The decision log. Rejected because an entry is a product decision with peers and Touches, and 27 page moves, approvals and deferrals are none. Reason is [assumed].
- `jig update --apply --move <id>`, where the flag is the yes. Rejected because deferrals and exceptions need a record anyway, and two ways to say yes is the ambiguity this spec removes. Reason is [assumed].
- Refuse `--apply` until every finding has an outcome. Rejected because Daisy had about 85 findings, and blocking the layout on all of them invites blanket deferrals, the grouping this spec removes. Reason is [assumed].
- Let redocument's end check catch it. Rejected because the check runs after every job has merged, and Daisy's remap pre-accepted it: "At the end, `jig survey` still lists … That is accepted." Reason is [seen]: Daisy `.jig/redocument.md`.
- Infer where a moved page's answers went, from a job's `git mv`, the page's other form or the remap's rows, and move or drop them. Rejected after three review rounds that didn't converge: each inference missed an actor (redocument writes the new page and deletes the old, merges and splits have no one destination, a moved page can take the opposite form), and each miss lost or misplaced the owner's exception. An exception is the owner's reason, and no tree can rebuild it. Reason is [seen]: the round 1–3 repros and the /jig:bug write-up.

## Decisions
- The owner, 2026-11-13: a recorded answer is never moved or dropped by inference; approved after three non-converging rounds.
- General: in any repo running update, survey and redocument as RULES.md describes, a long finding list, an agent that groups its asks, or a relayed brief loses a yes the same way. RULES.md promises each move "on the owner's yes", and the record keeps that promise. A repo's deliberate difference becomes a visible exception rather than a finding listed forever. Nobody has to work against jig to hit this.
- The yes lands on trunk before anything acts on it: the answers are one commit, then `--apply`. A subnode can't record an exception, because R5 keeps `findings` trunk-only.
- A rename on a recorded yes amends `update.md`'s "never edits the repo's own files" and `flat-pages.md`'s "`--apply` leaves it". A rename is not an edit, and with no entry nothing changes.
- Approved moves wait for a quiet board, as every update move does.
- RULES.md states the remap's two path columns, since `jig.py` reads them. The rest of the format stays the skill's.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
