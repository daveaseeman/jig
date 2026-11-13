# bug-git-output-encoding

Source: Maige-Lite hubnode session / 2026-11-13 / Dave with Claude (staged as feedback-Maige-Lite-2026-11-13-sync-report-non-utf8.md): "`python3 .jig/jig.py sync` prints the proposal and citation lines, then a traceback ending `UnicodeDecodeError: 'utf-8' codec can't decode byte 0xce in position 76417: invalid continuation byte`"; and, once decoding was tolerant, "`ValueError: not enough values to unpack (expected 3, got 2)` at `h.split("\0", 2)`."

## Intent
jig reads git's output as bytes it may not understand: a tracked file in another encoding, or
a line holding a form feed or a lone CR, never crashes a command or a hook. `jig sync`'s
newer-release report names such a file like any other.

## Why
- Why the crash? `git()` runs every git call with `text=True`, which decodes strictly as UTF-8.
  `used_in`'s `git grep` returns a matching line from a Latin-1 file, and decoding dies.
- Why the second crash? `used_in` splits grep's records with `splitlines()`, which also breaks on
  `\f`, `\x1c`–`\x1e`, `\x85`, U+2028/9, and `text=True` turns a lone `\r` into `\n`. One record
  becomes two, and the second has no NUL to unpack.
- Why only some paths? `naming()`, the `Checks` scan and `in_index()` already decode with
  `errors="replace"`; `git()`, `blob()` and `used_in` were written without it. One policy was never set.

## Givens
- `[seen]` Repro (`/private/tmp/claude-501/nonutf8/repro.sh`): metarepo `mr` releases D-001;
  pararepo `pr`, pinned at v0.1.0, tracks `api/readme.txt` = `caf\xe9 D-001 …`. `jig sync`:
  `UnicodeDecodeError … byte 0xe9`, rc 1, from `used_in` → `git()` line 78.
- `[seen]` Same repro with `D-001 is\x0chow …` and with `D-001 is\rhow …`: `ValueError: not enough
  values to unpack (expected 3, got 1)` in `used_in`, rc 1.
- `[seen]` Wider than sync: in a plain `jig init` repo, committing `ui.h` = `/* caf\xe9 */` makes
  the pre-commit hook crash in `check_rules`' R7 diff (`git diff -U0` over code files, via `git()`)
  and the commit is refused with a traceback. `jig check` crashes the same way. A firmware repo
  with a Latin-1 or Windows-1252 header can't commit it.
- `[seen]` `naming()` decodes leniently but still uses `splitlines()`: `"x\0" "1\0" "a\fdocs/ui.md"`
  splits into `x\x001\x00a` and `docs/ui.md`, so a citation after a form feed is silently missed.
- `[seen]` A prototype (`git()` with `errors="replace"`; `used_in` reading grep as bytes, decoding
  with `replace`, splitting on `"\n"` only) gives rc 0 and `D-001: used in api/readme.txt`
  (and `api/ff.txt`, `api/cr.txt`) for all three repros, and the hook commits `ui.h`.
- `[seen]` `Path.write_text("a\udce9b")` raises `UnicodeEncodeError: … surrogates not allowed`.
- `[seen]` The report's `jig_version` a8a32d1dbb7e; every repro above ran on main de3cc14.

## Design
- **One decoding policy.** Every git call that returns text decodes with `errors="replace"`:
  `git()`, `blob()`, and the other `subprocess.run(["git", …], text=True)` sites (merge, merge-tree,
  add). An undecodable byte becomes U+FFFD; nothing jig matches on is non-ASCII.
- **One grep reader.** A helper `grep_hits(args, cwd)` runs `git grep -n --null …`, reads bytes,
  decodes with `replace`, splits on `"\n"` only, and yields `(path, line, text)` for each record with
  two NULs. `used_in`, `naming()` and the `Checks` scan use it in place of their three copies.

## Done when
- [ ] Smoke `pararepo`: a tracked `api/latin1.txt` holding a Latin-1 byte and `D-001` → `jig sync`
      exits 0 and its report reads `D-001: used in` naming `api/latin1.txt` (the reported symptom).
- [ ] Smoke `pararepo`: a tracked file with `D-001` and a form feed on one line, and one with a lone
      CR → `jig sync` exits 0 and names both files.
- [ ] Smoke `rules`: committing a code file (`ui.h`) with a Latin-1 byte is accepted, and one adding
      a `/* WORKAROUND:` line with a Latin-1 byte is still refused by R7.
- [ ] Smoke: a doc citing `docs/x.md` after a form feed on the same line counts as inbound
      (the `naming()` miss).
- [ ] `grep -n 'text=True' plugin/templates/jig/jig.py` shows `errors="replace"` on every line.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- The report's "Also seen": the term list matching generic heading words ("Status", "Open")
  across the tree, a PDF included; and the bare-citation lines `jig sync` stops printing once
  the pin moves past a removed page. Not investigated; each is its own report if it matters.
- Universal-newline translation (`\r\n` → `\n`) in `git()`'s other callers: existing behavior,
  no symptom seen.
- Guessing a file's encoding: the report only needs the file named, not its text shown right.

## Touches
- `plugin/templates/jig/jig.py` (`git`, `blob`, the other `text=True` git calls; new `grep_hits`;
  `used_in`, `naming`, the `Checks` scan)
- `tests/smoke.sh` (`pararepo`, `rules`, and the section holding `naming`'s inbound tests)

## Alternatives considered
- Fix only `used_in`, as the report's minimum — rejected because the same `git()` crash refuses a
  commit of a Latin-1 code file in any jig repo, pararepo or not — reason is [seen]
- `errors="surrogateescape"`, which keeps the bytes — rejected because `fill_cache` and the merge
  resolution write git output with `write_text`, which raises on a surrogate — reason is [seen]
- Skip files that aren't UTF-8 (`-I` already skips binaries) — rejected because the report wants
  the file named: it is a real use of the term — reason is [seen: the report's Done when]
- Keep `splitlines()` and drop short records, the report's second correction alone — rejected
  because the record is then lost, not read: `naming()` already does this and misses the hit —
  reason is [seen]

## Decisions
- `replace`, not `surrogateescape`: jig only matches ASCII ids, paths and headings, and some
  callers write what they read.
- `grep_hits` reads bytes rather than relying on `git()`: `text=True`'s newline translation is
  what turns a lone CR into a record break.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
