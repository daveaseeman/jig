# Handoff: update-spec

Commit: 0888a4209474ce420fce5ec8e7219f32601cc871
Date: 2026-10-30
Spec: .jig/specs/update-root-specs.md

## Built
A spec only; no code changed. It covers the jig side of an adopting repo's report on `jig update`. Each of the report's six candidates was checked against today's template `jig.py` in a scratch ai-dev repo, and each is assigned to jig or to the repo. jig gets:
- per-file collisions for every folder row;
- mixed subfolders of root `specs/`/`ledgers/` left whole;
- a warning for moved files that use their own location;
- worktree refusal advice per case, including folders left on disk;
- the plan printed under a refusing dry run.

The repo keeps: rewriting stale references, and editing script lines.

## Done-when evidence
Spec-only handoff: the Done-when items are the build's, checked by `bash tests/smoke.sh` when the spec is built. Evidence for the spec's own claims, from the scratch repo (`plugin/templates/jig/jig.py` at `bb1eb98`):
- The dry run printed `specs/prework/t.rs is in specs/ but isn't Markdown … left there`, and the stale-reference report for `Makefile` (so the report is not apply-only).
- With a tracked `.jig/specs/b.md`: `specs/ and .jig/specs/ both exist: both left as they are, not merged`.
- Repo renamed with a worktree: `worktree list` showed `prunable`. update refused with `git worktree remove <path>`. Removing the old path exited 0 and left `.aidev/worktrees/l1` on disk, still ignored only by the `.gitignore` line update removes.
- `git worktree repair .aidev/worktrees/l1`, then `remove`, deleted the folder. After the record was dropped, `repair` failed ("unable to locate repository") and `remove` failed (128).
- No `check.sh`/`format.sh` template at `eaec973`, `66a044c`, `62c8d9f`, `5d955a2` or now has a `cd`/`dirname` line. Every brief skill writes specs flat.
- `.jig/scripts/check.sh` passed. `grep -rniE 'prework|maige' plugin` finds nothing.

## Review
Fresh-context reviewer: 2 blocking, 8 should-fix, 5 optional. All taken in `0888a42`.
- B1, blocking: repair fails once the record is gone. The advice is now per case, with "look, then delete it" when the record is gone. Reproduced, plus a done-when case.
- B2, blocking: "move a mixed subfolder whole" was rejected as [assumed]. It is now [seen], on the filter's own reason, and the old open question is reframed as an opt-in.
- S1: per file now applies to every folder row, and the changed smoke case is named.
- S2: the meaning of a partial row is defined, and the board keeps the old glob.
- S3: stale means "the path no longer exists".
- S4: why the top level and a subfolder differ, now [seen].
- S5: what the worktree check searches.
- S6: new cases for prune, `.jig/worktrees/` and output order.
- S7: the depth warning drops the `..` test and skips Markdown.
- S8: retagged [seen].
- O1–O5: open question 3 dropped; the untracked-move warning added; the adopt skill added to Touches; generic fixture names; the refusal gated like the others.

No DEFERRED rows.

## Fold-in
- [x] no code changed — nothing to fold in

## Shared files changed
None. The lane owns only `.jig/specs/update-root-specs.md`. This note is new.

## Test by hand
Nothing to click. Read the spec's candidate table against the report, and answer its open questions.

## Left
- Owner: the two open questions, and approval of the spec, before any build.
- The build collides with lane `names` (same functions, smoke, and the update/adopt skills). Build it after `names` merges, in its words: job, `/jig:spec`.
