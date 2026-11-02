# Feedback lands in the jig repo, and `/jig:fix` works through it

Source: cowork session 2026-11-02 (Dave + Claude) (staged as 2026-11-02-feedback-and-fix.md)

## Intent
A `/jig:feedback` report never sits in a temp folder again: it's staged into the jig repo as
`kind: feedback`, where `jig release` waits for it. `/jig:fix` works through what's there, one
root cause at a time. Every staged file dropped anywhere leaves a recorded reason.

## Givens
- `[seen]` Reports were lost twice to a cleared `$TMPDIR` (Oct 30–Nov 2). One came back only by
  hand.
- `[seen]` Staging already finds another repo through `repos.json`, forwards into its
  `.jig/staging/`, and `jig release` refuses while anything is staged.
- `[seen]` `jig staging drop` deletes and records nothing (release.md). Owner, Nov 2: drop now
  records a reason: "can't hurt".
- `[seen]` `KINDS` is `spec, doc, decisions, user-story`, and `read_staged` refuses any other.

## Done when
- [ ] `KINDS` gains `feedback`. Its header adds `from:` (the reporting repo's name) and
      `jig_version:` (its `.jig/jig.py` hash or version). `jig staging` lists `feedback` files,
      and refuses one without `from:`.
- [ ] `/jig:feedback` writes its report to the `jig` repo's `.jig/staging/` through `jig repos`.
      If the `jig` repo isn't registered, it writes to `~/.config/jig/feedback/` and prints the
      path. It never writes to `$TMPDIR`, and it still changes nothing in the reporting repo.
- [ ] `jig staging` also lists `~/.config/jig/feedback/`. `resolve` and `drop` act on files there
      too.
- [ ] `jig staging drop <file> --why "<reason>"` requires the reason. It appends a row to
      `.jig/ledgers/DROPPED.md` (date, file, kind, from or source, reason) and deletes the file.
      The first row creates the ledger from the plugin's template. Smoke: a drop without `--why`
      is refused, and one with it writes the row.
- [ ] `resolve` on `kind: feedback` works like a user story: it needs a spec carrying
      `Source: <source> (staged as <file>)`.
- [ ] `/jig:fix`, a skill run in the jig repo:
  1. Read every feedback file, and group those that look like one root cause.
  2. Per group, run `/jig:bug` against jig's own code. The reporter's givens are inputs, tagged
     `[seen]` only if reproduced here.
  3. Decide by `/jig:bug`'s fourth step:
     - a correction becomes a spec through `/jig:spec`, carrying the Source line for every report
       in the group
     - a workaround for one repo is dropped with that reason, plus what the repo should do instead
     - already fixed is dropped, naming the commit
     - anything it can't reproduce stays staged, with what's missing
  4. Show each decision as it goes. It doesn't wait for the owner between reports.
- [ ] Smoke passes, and the validator passes.

## Out of scope
- Applying a fix in the reporting repo: it gets it through `/jig:update`.
- Any registry beyond `repos.json`.

## Touches
- `marketing/FEATURES.md`: rows for `kind: feedback`, `/jig:fix` and drop's ledger, before code.
- `plugin/templates/jig/jig.py`: `KINDS`, header keys, `cmd_staging` (`drop --why`, the
  fallback folder).
- `plugin/templates/ledgers/DROPPED.md` (new).
- `plugin/templates/jig/RULES.md`: Staging.
- Skills: `feedback`, `stage`, a new `fix`.
- `tests/smoke.sh`.

## Alternatives considered
- Keep temp files and have `/jig:fix` search for them. Rejected: they were cleared twice.
  `[seen]`
- Record a drop in the commit message. Rejected: staged files are untracked, so a drop may never
  be followed by a commit. `[seen]`: release.md's reason for dropping the board log.
- A new folder for feedback in the jig repo. Rejected: staging already gives it a durable home,
  and the release refusal. `[seen]`

## Decisions
- This reverses release.md's "drop records nothing". The owner's reason: a reason can't hurt, and
  `/jig:fix` drops reports for reasons the owner may want to overrule later.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
