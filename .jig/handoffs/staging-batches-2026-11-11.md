# Handoff: staging-batches

Commit: 5a7e911bbc8822b05483ee62e9313a30fa3937b4
Date: 2026-11-11
Spec: .jig/specs/staging-batches.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on bdd3dcf: no blocking; S1-S7, O1-O3 fixed in 8d829aa (hubnode ran smoke staging_batches and repos, 33 PASS); 5a7e911 is a sync of main with append conflicts only, resolved by jig, no hand edits; full smoke 1010 PASS

## Built
<!-- what this delivers, in a few lines -->
- `after:` header: `jig staging` lists files in dependency order (name order within a level),
  names a cycle's members and the files that only wait on one; `resolve` refuses a file while
  one it waits for is staged, naming the cycle if any. Takes a YAML list and names without `.md`.
- `jig staging check <file>…`: headers only, from the plugin copy outside any repo. Fails on a bad
  header, a destination outside the target (the shared `escapes()` rule resolve uses), an unlisted
  target (case folded), an `after` naming no file in the batch or target's staging, a cycle; warns
  on a target with a near-identical twin.
- `resolve` fills an empty or missing `## Workflow` in a new spec with `jig workflow`'s lines, and
  refuses while `jig workflow` refuses.
- `jig repos`, `repos add`, `repos rename` warn on names equal once case and punctuation are
  dropped, printing both paths. `repo_path` folds case as a last resort.
- RULES.md § Staging, the stage and repos skills say each.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- after: order and refusal: `bash tests/smoke.sh staging_batches` → PASS "the list puts each file after the one its after: names (z, b, c)", PASS "resolve refuses c.md while b.md … is staged, and names b.md".
- check outside a repo: PASS "staging check: run outside any repo, a file with no kind: is named, and it exits non-zero", PASS "a good file passes".
- Workflow fill: PASS "a spec with an empty ## Workflow resolves with jig workflow's lines in it" (and missing, kept, odd-heading, refusal cases).
- Near names: PASS "repos: NorthStar and north-star are flagged on the list, with both paths" (generic names used in place of the spec's real repo names, per the kickoff).
- RULES.md § Staging and `plugin/skills/stage/SKILL.md` say each: the diff to both, reviewed.
- `bash tests/smoke.sh` → 1010 PASS, 0 FAIL, rc 0 on 5a7e911; `claude plugin validate ./plugin` → ✔ Validation passed; `.jig/scripts/check.sh` → rc 0; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing.

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode's review of bdd3dcf: nothing blocking. Fixed in 8d829aa:
- S1 a near-duplicate target fails check: now a warning that doesn't change the exit; RULES.md and stage skill agree.
- S2 check and resolve judged destinations differently: shared `escapes()` (absolute, `~`, drive, `..`) used by both.
- S3 check matched targets exactly, resolve case-folded: `repo_path` falls back to a case-folded match.
- S4 the "nothing carries its mark" note misfired: `landed_anywhere` removed; a waited-for file not staged counts as gone; the skill no longer asks.
- S5 check passed a cycle: check runs `batch_order` and fails naming it; resolve's refusal names the cycle.
- S6 files waiting on a cycle were reported as in it: only members are; the rest "waits on a cycle".
- S7 a Workflow heading with trailing text, lower case or at EOF got a second section: the heading line is matched whatever follows, any case, at EOF.
- O1 `repos rename` warns on near names. O2 a `jig workflow` refusal refuses the resolve; a missing section gets the heading. O3 `after: [a, b.md]` and names without `.md`.
Deferred, rows in `.jig/ledgers/DEFERRED.md`: `drop` doesn't say others wait on the dropped file; a forwarded `after` counts as resolved here.
5a7e911: sync of main (0378119, bug-staged-rules-update), append conflicts only, resolved by jig, no hand edits; review re-recorded on it by the hubnode.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` § Staging and the stage and repos skills, updated here.

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: staging list order, resolve's after refusal and Workflow fill, `staging check`, repos near-name warnings, `repo_path` case fallback. `landed` untouched.
- `plugin/templates/jig/RULES.md`: § Staging, one new paragraph and the chat-access sentence.
- `tests/smoke.sh`: new section `staging_batches`, appended with its UNITS entry.
- `plugin/skills/stage/SKILL.md`: header line, "A batch" subsection, Resolving intro; the resolve bullets left to bug-staged-rules-update.
- `.jig/ledgers/DEFERRED.md` (common): two rows.

## Test by hand
<!-- what a person should click or watch -->
In a chat, stage a two-file batch with `after:`, run `staging check` from the plugin copy, then `jig staging` in the target: the order shows, and resolving the second first is refused.

## Left
<!-- what remains on this job -->
Nothing. The two DEFERRED rows stand.
