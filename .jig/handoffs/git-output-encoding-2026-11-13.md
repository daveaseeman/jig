# Handoff: git-output-encoding

Commit: 6aa7172e0f675840954c1e5207971715e82c64c9
Date: 2026-11-13
Spec: .jig/specs/bug-git-output-encoding.md
Review: tier 2, effort 2

## Built
jig reads git output it can't decode without crashing. Every `text=True` git call decodes with
`errors="replace"`. A new `grep_hits` reads `git grep -n --null` as bytes, splits on `"\n"`
only and keeps records that have two NULs; `used_in`, `naming()` and the `Checks` scan share it.
Text jig writes back into a tracked file round-trips its bytes through `surrogateescape`
(`git_raw`/`read_raw`/`write_raw`): the append-file resolution in `jig merge` and `jig sync`
(`resolve_appends`), and the roadmap rewrites in `cmd_merge` and the update sweep. R7 reads its
diff raw. `CONFLICT` accepts CRLF markers.

## Done-when evidence
- Smoke `pararepo`: `PASS  sync on a pararepo trunk: a tracked file not in UTF-8, or with a form feed or a lone CR on the matching line, is named, not a crash` (it names notes/latin1.txt, notes/ff.txt and notes/cr.txt). This covers the first two Done-when items; the fixture is under notes/ rather than api/.
- Smoke `rules`: `PASS  R7: a code file holding a Latin-1 byte commits`; `PASS  R7: the marker beside a Latin-1 byte is still refused, by R7`.
- Smoke: `PASS  survey: a citation after a form feed on its line counts as inbound`.
- `grep -n 'text=True' plugin/templates/jig/jig.py`: five lines (81, 823, 1184, 1357, 1389), each with `errors="replace"`.
- Added after review: `PASS  merge: R, unsynced, appended a Latin-1 line: the merged CHANGELOG.md has Q's bytes, then R's, unchanged`; `PASS  sync: S, which appended a Latin-1 line, resolves CHANGELOG.md with every line's bytes unchanged`; `PASS  R7: the marker after a lone CR on an added line is still refused`.
- Run against 11dafae's jig.py, the three post-review tests fail: they catch what the review found.
- `bash tests/smoke.sh` at 6aa7172: 1232 PASS, 1 FAIL, `isolation: the user's real jig config folder is unchanged by the run`. The cause was an outside write: `~/.config/jig/repos.json` was modified at 19:11, during the ~53-minute run (18:37–19:30), and it holds no throwaway-repo path, so another session's real jig work changed it, not the smoke. A rerun of `rules report_fixes pararepo` passed, isolation included.
- `claude plugin validate ./plugin`: `✔ Validation passed`.

## Review
Hubnode review of 11dafae:
- Blocking: `blob()` decoded with `replace`, and `jig merge` wrote the result back, silently turning Latin-1 in append files into U+FFFD. Fixed: `blob()` reads with `surrogateescape` via `git_raw`, and the resolved file is written with `write_raw`. The merge-bytes and sync-bytes smoke tests prove the bytes round-trip.
- `check_subject` read the commit message strictly. Fixed: `read_text(errors="replace")`.
- `resolve_appends` was strict. Fixed: `read_raw`/`write_raw`. This needed `CONFLICT` to accept `=======\r\n`, because raw reads keep git's CRLF markers.
- The roadmap rewrite in `cmd_merge` was strict. Fixed: `read_raw`/`write_raw`. The update sweep's roadmap rewrite had the same flaw, also fixed (not in the review).
- Optional, R7's diff went through `git()`'s universal newlines, so a lone CR could hide a marker. Fixed: R7 reads the diff via `git_raw`; smoke test added.
- Optional, comment on `fill_cache`. Done: the cache is a derived, gitignored copy, so U+FFFD is fine there.
Nothing left.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this changes no documented behavior: no command, rule or output text in `plugin/templates/jig/RULES.md` or a skill changes; jig just no longer crashes on, or rewrites, bytes it can't decode.

## Shared files changed
- `plugin/templates/jig/jig.py`: the git and file readers every command shares; the fix is one decoding policy across them.
- `tests/smoke.sh`: tests in `rules`, `pararepo`, `report_fixes` and the survey section.

## Test by hand
In a jig repo, commit a `.h` file holding `/* caf\xe9 */` (printf it): the hook accepts it. In a
pararepo whose metarepo released an id, track a Latin-1 file naming that id and run `jig sync`:
the report names the file.

## Left
Nothing on this job. The spec's Out of scope stands: generic heading words as terms, the
bare-citation lines after a page moves, and universal-newline translation in `git()`'s other
read-only callers.
