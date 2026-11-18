# Bug: the review-holder check judges prose, and each fix round moved its errors

Source: the hubnode, jig hubnode session, 2026-11-17: "three blocking reviews of bug-process-in-pages, two on the review-holder check". It asked why the job needed three fix rounds, and what the remaining fix should be.
Bug-for: bug-process-in-pages

## Intent
Survey and update show each Invariants entry whose holder names review, for the writer to
judge. They never say what they can't know, such as that the entry has no holder. The owner's
P4a stands: a holder is a named test or what is seen on screen, and review is none. The check
that carries it out reads a word, the way the `.jig/` path listing beside it reads a path.

## 1. Why
1. Why three blocking reviews? Strike 1: PROCESS_PATH missed a `.jig/` path form (`../.jig/`).
   Strikes 2 and 3: the review-holder check, wrong in a new way each round. [seen]
2. Why wrong each round? The finding is a verdict, "held by review, which is no holder". So its
   pattern must decide that review is the only holder, which means reading English. [seen]
3. Why a verdict? The parent spec's Done when says survey "names review as no holder". It tests
   only "held by review." and "held by test_x", and runs nothing over real pages. [seen]

Each round answered the last review's examples. On the 36 real entries whose holder names
review (Givens), 21 are held by review alone and 15 name a test for one part and review for
another:

| Commit | Pattern | On the 36 real entries |
|---|---|---|
| 8aa759d | `held by[^;.]*\breview\b` | Lists all 21. Calls 10 of the 15 "no holder". Misses 5 because a `.` inside a code name ends the match; also flags `review.py` |
| 473bbc7 | the holder is the bare word review, after "the", "code" or "a", at the end of the entry | Lists 9. Misses the 12 written "review of `X`" |
| e5847be | split on and / , / +; a part counts as a test only if it looks like one | Calls 11 of the 15 "no holder". Misses 2 of the 21 |

Root: the parent spec asked jig.py to judge free text (is review the only holder?), and no
pattern can. Every other prose check in this diff lists a precise token and leaves the judgment
to the writer. This one should too.

## 2. Givens
- [seen] P4a, the owner 2026-11-17 (parent spec, Decisions 4a): "a holder is a named test or what
  is seen on screen, still required; survey and update list a holder that is review".
- [seen] RULES.md, Documentation, at e5847be:
  - the Invariants item: "Review is no holder: no step reads a page's Invariants, so an entry
    nothing else holds goes in the body";
  - survey "names … an Invariants entry with no why … or no holder …, or held by review";
  - for the `.jig/` listing, "Whoever writes the line judges it", and update "judges none of
    them";
  - for text that may be the product's, "it can't judge … whoever writes the line judges it".
- [seen] The parent spec's Done when: "survey's `page_contract` names review as no holder, and
  update lists it. '- X — Y; held by test_x.' is not listed". It gives the `.jig/` listing a run
  over Daisy's real lines, and gives the holder check none.
- [seen] Real pages: read-only `git archive` copies of Maige-OS 9a278a1, Maige-Lite 7c510b5 and
  Daisy e23ea548 hold 887 Invariants entries (94, 50 and 743). Each is one line with "held by".
  - 40 holders contain "review".
  - In 36 of them review is a word (Maige-OS 20, Maige-Lite 16).
  - Daisy's 4 have it inside a test name (`test_a_review_reply_too_and_the_rw_grant_is_still_read_only`).
- [seen] I read each of the 36:
  - 21 are held by review alone ("review.", "review of `Store::ingest`", "review of `ui_pin.c`, of `ui_core.c`'s tap log …").
  - 15 name a test and review, each for a different part: "`verity_is_off_by_default` and
    review of `Store::verity_enabled`", "… and by review of `rpc::kind` for the rest". In every
    one of them, review is the only thing named for its part.
- [seen] Survey at e5847be on those copies lists 20, 10 and 0 entries, each one "held by review,
  which is no holder".
  - 11 of them have a test beside review.
  - It misses Maige-Lite's two review-only entries that name files ("review of `ui_pin.c`, …"
    and "review: for a code, of every caller of `identity_codes` …").
- [seen] A scratch copy of jig.py with the listing rule (Correction 1) gave these results:
  - On the same copies it lists 20, 16 and 0 entries, and no line says "no holder".
  - I ran it on the reviewer's 36 probe holders (`rc-pp-e5847be/probe.py`) plus three of mine.
    It fails to match "review is named as a holder" only on "test_x (found in review)",
    "smoke.sh's review section" and "`tests/smoke.sh` (review section)".
- [seen] Daisy has 5 entries that name review before "held by", as its product's own word: "The
  modes are exactly chat, idea, task, plan, code and review". A search over the whole entry
  lists them. A search over the holder clause doesn't.
- [seen] A checkable form for holders (a code-quoted name, a `test_` name, or on screen / on the
  board) fails 49 of the 887. That includes 40 Daisy entries that hold JS tests by their quoted
  titles (`test "…" (designerKeys.test.js)`). 11 "review of `X`" holders pass it.
- [seen] A false hit already has an answer. A `contract:<path>` finding takes the owner's
  `exception: <reason>` in `config.json`'s `findings` (RULES.md, The findings record;
  `FINDING_KINDS` includes `contract`).
- [seen] None of the 887 entries wraps onto a second line. `section_items` reads only the first
  line, and loses no holder text on these pages.
- [assumed] The product's own word "review" in a holder clause, outside code and test names, is
  rare. None of the 887 has one. If it does happen, the cost is one re-listed line, answered by
  an exception.

## 3. One layer up
- **The siblings in this diff list a token and judge nothing.** None of them decides what prose
  means; `held_by_review` is the only one that does. [seen]
  - `PROCESS_PATH` / `process_prose` list a `.jig/` path, "unless the product itself reads it".
  - `project_prose` lists spec paths and quoted scope ids.
  - `root_doc_mentions` lists lines and leaves them to the writer.
- **Strike 1 was a token-form gap,** fixed in 473bbc7, and `docs/../.jig/` has a DEFERRED row.
  On Maige-Lite's copy the path listing lists 44 lines, and each names a real `.jig/` path
  (27 `.jig/scripts/check.sh`, 10 `.jig/ledgers/WORKAROUNDS.md`, …). Its shape is right. [seen]
- **What's different:** those checks were specified as listings, and the holder check was
  specified as a verdict. [seen]
- **The pattern that solves this shape already exists.** A listing of a precise token, the
  writer's judgment, and the owner's exception record for a rare false hit (RULES.md: Product
  and process; The findings record). [seen]

## 4. Correction
This is a correction, not a workaround. The check stops claiming what no pattern can know, and
becomes the kind of listing the rest of this diff uses.

1. **jig.py, the predicate.** An entry is listed when its holder clause names review as a word.
   - The holder clause runs from "held by" to the end of the entry's line, with inline code removed.
   - The word is review, reviews, reviewed, reviewer(s) or reviewing, in any case.
   - It doesn't count inside a path, a file name or a compound (`tests/review/`, `review.py`,
     `review-mode`, `test_review_x`).

   `TEST_NAME`, `REVIEW_WORD` and the split go. The comment says why: no pattern can read
   whether review is the only holder, so the entry is listed and the writer judges. This is the
   rule I measured:
   ```
   REVIEW_NAMED = re.compile(r"(?<![\w/.-])review(?:s|ed|er|ers|ing)?\b(?![-/.]\w)", re.I)
   m = re.search(r"\bheld by\b(.*)$", item, re.I)
   return bool(m and REVIEW_NAMED.search(re.sub(r"`[^`]*`", "", m.group(1))))
   ```
2. **The finding's text** says what was found and what to do, and never says "no holder":
   "invariant whose holder names review, which holds nothing on a page (no step reads a page's
   Invariants): for what review covers, name a test or what is seen on screen (on a board, on
   the board), or move it to the body; where a test holds it all, drop review: <entry>". It
   stays a `page_contract` finding, so update lists it and an `exception:` answers a false hit.
3. **RULES.md, Documentation.**
   - Survey's sentence says "or whose holder names review (listed: survey reads the word, never
     the other holders)" in place of "or held by review".
   - The Invariants item's last sentence says that what only review would hold goes in the body.
4. **`.jig/decisions.md`.** The Unreleased line says "an invariant whose holder names review".
5. **The parent spec.** Its holder item in Done when changes to match, and its Decisions record
   H1's answer.

## Done when
- [ ] The fix fires (smoke `page_contract`). A page's Invariants hold the entries below.
  - Each of these gets its own `page_contract` line saying the holder names review, and no line
    says "no holder":
    - `held by review.`
    - ``held by review of the log calls in `chain_tests.py`.``
    - `held by peer review only.`
    - `held by test_p and review.`
    - `held by TestSumWraps and review.`
    - ``held by review of the calls in `log.py` and `chain.py`.``
    - `held by the reviewer.`
    - `held by reviewing each diff.`
  - None of these is listed:
    - `held by test_x.`
    - `held by review.py.`
    - ``held by `tests/review/test_flow.py`.``
    - `held by test_review_mode.`
    - `held by preview_test.py.`
  - "Z — W." is still listed as missing its holder.
  - `jig update` lists the same eight entries under Repo files to review.
- [ ] The strike-3 symptom is gone, as the smoke above shows:
  - the reviewer's (a) holders, a test beside review, get the listing's text, not "no holder";
  - `tests/review/test_flow.py` isn't listed;
  - the (b) holders are listed: review naming files, reviewer, reviewing.

  `grep -nE "TEST_NAME|which is no holder" plugin/templates/jig/jig.py` finds nothing.
- [ ] Real pages, run by hand. Survey with the fix, on read-only `git archive` copies of Maige-OS
  9a278a1, Maige-Lite 7c510b5 and Daisy e23ea548, lists 20, 16 and 0 entries whose holder names
  review. None of its `page_contract` lines says "no holder". At e5847be it lists 20, 10 and 0,
  every one as "no holder", and 11 of them have a test beside review.
- [ ] `grep -n "names review" plugin/templates/jig/RULES.md` finds survey's sentence.
  `.jig/decisions.md`'s Unreleased line says "whose holder names review".
- [ ] The parent spec's holder item in Done when says the entry is listed as a holder naming
  review, not that review is named as no holder. Its Decisions hold H1's answer.
- [ ] `.jig/scripts/check.sh` exits 0, `bash tests/smoke.sh page_contract` passes, and
  `claude plugin validate ./plugin` passes. The full suite is the check step's.

## Out of scope
- **Holders that say where the repo runs a test** ("held by `make verify` in
  `.jig/scripts/check.sh --full`", seen on Maige-Lite's copy). The `.jig/` path listing already
  lists them; the parent spec's rule is doing its work there. The writer keeps the test's name.
- **`docs/../.jig/` in PROCESS_PATH.** Its DEFERRED row stands.
- **An Invariants entry wrapped onto a second line.** `section_items` reads the first line, both
  for the missing-holder check and for this one. No real page has one (0 of 887).
- **A spec-skill rule that a check reading prose gets a Done when run over real pages.** This is
  its first case. It becomes a retro candidate if it happens again.

## Touches
- `plugin/templates/jig/jig.py`: `held_by_review` and its patterns, and `page_problems`' holder message
- `plugin/templates/jig/RULES.md`: Documentation (the Invariants item's last sentence; survey's sentence on what it names)
- `tests/smoke.sh`: `page_contract` (the `docs/held` fixture and its two assertions)
- `.jig/decisions.md`: the Unreleased line
- `.jig/specs/bug-process-in-pages.md`: Done when (the holder item), Decisions (H1's answer)

## Alternatives considered
- **A fourth classifier** (more joiners, more test shapes such as Go `TestX` and Rust names in
  backticks) — rejected because each of three rounds traded one wrong verdict for another. In
  code quotes, a Rust test name (`` `executor_must_exist_and_support_every_step` ``) looks the
  same as a function under review (`` `dispatch::choose` ``, `` `identity_enter_pin` ``). At
  e5847be it is wrong on 13 of the 36 real entries — this reason is [seen].
- **Only the bare form** (473bbc7's: the holder is the word review and nothing else) — rejected because it lists
  9 of the 21 entries review alone holds. It misses the 12 written "review of `X`", the most
  common real form — this reason is [seen].
- **No mechanical check** (the rule stays in RULES.md, the templates, redocument's admission
  fate and review question 9) — rejected because P4a asks survey and update to list it, and the
  listing has no false hit on 887 real entries. Repos already on jig would hear of it only from
  the release line — this reason is [seen]. It is H1's option (c).
- **A checkable form for holders in the template** (a code-quoted test name, or on screen) —
  rejected because it changes every repo's page contract, and it still can't do the job: 40
  Daisy entries holding JS tests by quoted titles fail it, and 11 "review of `X`" holders pass
  it — this reason is [seen].
- **A search for review anywhere in the entry, not only in the holder clause** — rejected
  because Daisy's product has a review mode, and 5 of its entries name it before "held by" —
  this reason is [seen].
- **Two tiers: a "no holder" verdict for the bare form and a listing for the rest** — rejected
  because it gives two outputs for one rule, the verdict still has to be right, and the action
  is the same — this reason is [assumed].
- **Making review a holder by having review read the touched pages' Invariants** — rejected in
  the parent spec: it writes more process into pages, which the owner objects to — this reason
  is [seen] (the parent spec's Alternatives).

## Decisions
- **H1, for the owner** (it reads P4a): what do survey and update list for "a holder that is
  review"? Recommended: (a).
  - (a) Every entry whose holder names review, whether or not a test is named beside it. The
    listing says what it found and judges no other holder. On the three repos' pages that is 36
    of 887 entries, each with a part named only for review, and nothing else.
  - (b) Only a holder that is the bare word ("held by review.", "peer review"). That is 9 of the
    36, and it misses 12 entries that review alone holds.
  - (c) Nothing mechanical: the rule stays in RULES.md, the templates, redocument and review
    question 9.

  The case for (a): under P4a review holds nothing, so a part named only for review has no
  holder. For "test_x and review", the fix is to drop two words. The reviewer of e5847be read a
  test beside review as a holder that should pass. (a) lists it, but its text says "where a test
  holds it all, drop review", not "no holder".
- Interpreted (for the hubnode): strike 3's two findings are answered by (a)'s wording and its
  predicate, not by a better classifier. Strike 2's finding ("review of the log calls in
  `chain_tests.py`" lost) is listed under (a) too.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
