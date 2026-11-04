# Bug: the metarepo rules never say what lives there, so Newer wins and "no copied content" disagree

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)

Item 2 of that report. In the replay, a buffer row (B1) asked the metarepo to catch up with
the pararepo's menu routing. The writer restated the new routing on two metarepo pages, and the
reviewer blocked it as copied pararepo content. Both fixes removed the stale claim. They
disagreed only on what took its place: the new text, or a pointer to it.

## 1. Why
- Why did the writer copy? Newer wins says "The update gives the new text with its source", and
  the buffer proposal spec says the metarepo "updates every place that states it".
- Why did the review block it? Rule 2 says "The metarepo holds no code and no copied pararepo
  content", and the section opens "The metarepo points; nothing copies it."
- Why can't a session tell which rule applies? Nothing says which claims the metarepo holds and
  which it only points to. Root: there's no rule for where a claim lives, so each of the two
  rules can be read as covering the case.

## 2. Givens
- `[seen]` RULES.md "Metarepo and pararepos" (`plugin/templates/jig/RULES.md` ~276-281): "docs
  only — definitions, decisions, conventions", "The metarepo points; nothing copies it", and rule
  2. Nothing says which claims belong there.
- `[seen]` Newer wins (~340-345) lets "a pararepo page a decision makes the authority" override
  metarepo text, then says the update "gives the new text". When the authority is a pararepo
  page, that new text is copied pararepo content. The two rules conflict in the text itself.
- `[seen]` Reproduced in scratch (a throwaway metarepo and pararepo, one Open row B1 against a
  metarepo page, `jig propose --buffer menu`). The spec it writes says: "m updates every place
  that states it (RULES.md: Newer wins, Every copy)." It says nothing about pointing, and the
  row's "This repo now" column holds the text there is to copy. Written by `buffer_proposal`,
  `jig.py` ~2592-2596.
- `[seen]` Every copy (~346-347), spec skill step 3 and review skill item 7 all say a changed
  claim gets updated everywhere it's stated. None of them says a restatement could become a
  pointer instead.
- `[seen]` A pointer form already exists: a decision cites `<repo>/<path>`
  (`sb-para/docs/ui.md` in smoke ~2017), and `jig sync` reports a cited file that
  `contract_paths` doesn't cover (`jig.py` ~2511).
- `[assumed]` The reporter's proposed rule (a claim lives in the metarepo when another repo must
  agree with it or build against it) gives one answer per claim in practice. It was checked here
  only against the report's two examples, not against a real metarepo. The owner called it right;
  see Open questions.

## 3. One layer up
- Siblings: every text that tells a writer what to do with a changed claim. That's Newer wins,
  Every copy, the buffer proposal template, the BUFFER ledger header, spec step 3 and review
  item 7. None of them asks where the claim lives, so all of them have the same gap.
- Existing pattern: the metarepo already cites pararepo files by path, and `jig sync` follows
  those citations. A pointer needs no new mechanism, only a rule for when to use one.

## 4. Correction
Add one rule for where a claim lives, and make Newer wins, Every copy and the buffer proposal
spec defer to it. Each claim then has one home and is stated only there. Nothing is gated: no
check can tell restating from pointing by meaning.

## 5. Spec

### Done when
- [ ] RULES.md "Metarepo and pararepos" has a **What the metarepo holds** paragraph: a claim
      lives in the metarepo when another repo must agree with it or build against it (a
      contract). Otherwise it lives with its one owner, and the metarepo points to it
      (`<repo>/<path> § <section>`). Rule 2 cites it.
- [ ] Newer wins reads: update the claim where it lives; replace any restatement elsewhere with a
      pointer to it. "gives the new text" applies only when the claim lives in the metarepo. Every
      copy says each place it lists is either updated (the home) or turned into a pointer.
- [ ] `buffer_proposal`'s spec names the rule. For each row, the metarepo decides where the claim
      lives. A contract gets the new text with its source; a claim the pararepo owns gets a
      pointer to the "This repo now" source wherever the metarepo states it. A smoke case greps
      the written spec for the rule's name and the word "pointer".
- [ ] Spec skill step 3 and review skill item 7 ask the same: is each changed claim stated only
      at its home, with a pointer everywhere else? The BUFFER ledger header says the row records
      a claim the metarepo states, even when the fix is a pointer.
- [ ] A `marketing/FEATURES.md` row for the rule, added before the change.
- [ ] Smoke passes, and the validator passes.
- [ ] Replayed by hand once, at build. A throwaway metarepo page restates pararepo-owned
      behaviour, with one buffer row against it. A fresh writer given the spec from
      `jig propose --buffer` replaces the restatement with a pointer, and a fresh review raises no
      copy finding.

### Out of scope
- Any gate or hook. Restating versus pointing is a judgment of meaning; review catches it.
- Changing P2 or `contract_paths` (see Open questions).
- Fixing any adopting repo's pages, or its own AGENTS.md rules.

### Touches
`plugin/templates/jig/RULES.md`, `plugin/templates/jig/jig.py` (the `buffer_proposal` string
only), `plugin/templates/ledgers/BUFFER.md`, skills `spec` and `review`, `tests/smoke.sh` (one
case), `marketing/FEATURES.md`.

### Alternatives considered
- Keep Newer wins as is and let rule 2 win by precedence. Rejected: Newer wins already makes a
  pararepo page the authority and then says to give its text, so the conflict stays in the rule
  itself. `[seen]`: RULES.md ~340-342.
- Make the metarepo the home of everything a pararepo does, and drop rule 2's "copied content".
  Rejected: that brings back the drift the pin and cache exist to prevent. Every pararepo change
  would become a metarepo change. `[seen]`: FEATURES.md `init --para` row, "Copies drift
  silently".
- Fix only the buffer proposal template. Rejected: it patches the one path seen. A metarepo spec
  written by hand, and the reviewer's item 7, would still lack the rule. `[seen]`: the same gap in
  spec step 3 and review item 7.
- A gate that refuses pararepo text in metarepo pages. Rejected: matching by meaning isn't
  checkable, and matching by words would miss paraphrases. `[assumed]`.

## Decided
Owner, 2026-11-03: each recommendation below is taken. Build to it.

- **The rule's wording is the owner's to confirm.** The proposal: "lives in the metarepo when
  another repo must agree with it or build against it". Dave (2026-11-03) asked for "a rule about
  WHAT lives in the meta" and called this proposal right. Recommend adopting it as worded. The
  spec builds the same way with any wording that gives one answer per claim.
- **Does the buffer's scope shrink?** The report says behaviour a pararepo owns outright needs no
  row. P2 already allows that through `meta: none — <reason>` or narrower `contract_paths`.
  Recommend no code change. A row is still the way to get a stale metarepo restatement turned
  into a pointer, once; after that the claim has no metarepo statement to drift from. If the
  owner wants the scope cut, it's one sentence in the sync buffer paragraph.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
