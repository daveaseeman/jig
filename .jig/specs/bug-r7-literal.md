# Bug: R7 treats any mention of the marker as a workaround comment

## 1. Why
- Why would jig's own commits be refused? R7 refuses an added code line containing
  `WORKAROUND:`, and jig's checker and smoke test contain that text.
- Why does that text count? R7's pattern is `^\+.*WORKAROUND:`. It matches the marker anywhere
  on the line, inside a string or a regex as much as in a comment.
- Why anywhere? Nothing anchors it to a comment, though every rule that states R7 says "a
  `WORKAROUND:` comment". Root: the pattern is wider than the rule it enforces.

## 2. Givens
- `[seen]` `jig.py:226`: `re.search(r"^\+.*WORKAROUND:", diff, re.M)`, run over the diff of
  `CODE_EXT` files only.
- `[seen]` `jig.py:223-224`: R7 already skips `.jig/jig.py`, the installed checker, because it
  quotes the marker and the previous checker judges every update of it. `RULES.md:62` says so.
  Added this session (dot-jig). It exempts one path; `plugin/templates/jig/jig.py`,
  `tests/smoke.sh` and any other repo's code that names the marker in a string are not exempt.
- `[seen]` The marker appears in code at `jig.py:226` (the pattern) and `jig.py:228` (the
  refusal message), and at `tests/smoke.sh:45, 46, 48 and 49`. Line 49 is a fixture that
  writes `# WORKAROUND: x`.
- `[seen]` Markdown is not checked. The smoke case "R7: WORKAROUND: in Markdown is accepted"
  passes, so the skills that mention the marker are not affected. That corrects the adopt
  plan, which said two skills would trip it.
- `[seen]` Only added lines count (`^\+`). A commit trips R7 only if it adds or changes one of
  those lines.
- `[seen]` `CODE_EXT` (`jig.py:903-904`) is C, C++, ino, Rust, TS, JS, Python, Go, Swift, sh,
  cmake and Kconfig. Their comments open with `#`, `//`, `/*`, or `*` continuing a block.
  None uses `--` or `;`.
- `[seen]` The rule's own text: AGENTS template "It gets a `WORKAROUND:` comment"; RULES R7
  (`RULES.md:61`) "adding a `WORKAROUND:` comment"; `/jig:bug` "a one-line code comment …
  starting `WORKAROUND:`".
- `[assumed]` A real workaround comment puts the marker right after its opener (`# WORKAROUND:`,
  `// WORKAROUND:`), as `/jig:bug` tells it to. Held as a risk: `# note — WORKAROUND: x` would
  no longer be caught.

## 3. One layer up
- Sibling: the `.jig/jig.py` exemption. It solved the same symptom for one path. It stays: the
  installed checker is judged by its predecessor, which may carry the wide pattern, and its
  messages may quote the marker in any form later. The fix covers every other file.
- Sibling: `update`'s stale-reference warning tells comments from code with the `COMMENT`
  openers, at the start of a line only. R7 must also see trailing comments
  (`x = 1  # WORKAROUND: …`), so it can't reuse that test as is; it uses the openers
  `CODE_EXT` actually has.

## 4. Workaround or correction
A correction. R7 matches `WORKAROUND:` only directly after a comment opener. The rule then
enforces what it states, in every repo, not just in the checker's own file.

## 5. Spec

### Intent
R7 refuses an added code line only when `WORKAROUND:` follows a comment opener with nothing
but spaces between, because only then is the line the comment the rule is about.

### Done when
Each a smoke case, in a `src/` file with no ledger row staged:
- [ ] `x = 1  # WORKAROUND: y` (`.py`) is refused: a trailing comment.
- [ ] `/* WORKAROUND: y */` (`.c`) is refused.
- [ ] ` * WORKAROUND: y` (`.c`, a block comment's continuation line) is refused.
- [ ] `msg = "adds a WORKAROUND: comment"` (`.py`) is accepted: a string.
- [ ] `a(); log("WORKAROUND: x")` (`.js`) is accepted: `;` is not an opener.
- [ ] `u = "http://h"; s = "WORKAROUND: y"` (`.py`) is accepted: the `//` isn't followed by the
      marker.
- [ ] The R7 message line copied into `src/check.py` is accepted. This is the line that
      trips jig's own source today, in a file the exemption doesn't cover.
- [ ] The existing R7 cases still pass. The fixture at `smoke.sh:49` builds its marker from a
      variable, so smoke.sh itself carries no `# WORKAROUND:`.
- [ ] `grep -nE '(#|//|/\*)\s*WORKAROUND:|^\s*\*\s*WORKAROUND:' plugin/templates/jig/jig.py tests/smoke.sh`
      finds nothing.

### Out of scope
- Markdown and other non-code files: R7 still skips them.
- The `.jig/jig.py` exemption: kept as is.
- What counts as a ledger row.

### Touches
- `plugin/templates/jig/jig.py`: R7's pattern, and its comment.
- `tests/smoke.sh`: the cases above, and the fixture at line 49.
- `RULES.md` needs no change: line 61 already says "comment".

### Alternatives considered
- Split the literal in jig's source (`"WORK" "AROUND:"`), as the adopt plan proposed. Rejected:
  it patches the symptom in one repo and leaves the rule wider than it says for every repo.
  `[seen]`: the pattern at `jig.py:226` has no comment anchor.
- Widen the `.jig/jig.py` exemption to jig's source (`plugin/**`, `tests/smoke.sh`). Rejected:
  it names one repo's paths in a checker every repo runs, and another repo's string that names
  the marker is still refused. `[seen]`: the exemption at `jig.py:224` is a path test.
- Match openers anywhere before the marker on the line. Rejected: `;` and `//` in a URL then
  count, and `a(); log("WORKAROUND: x")` is refused. `[seen]`, from the pattern itself.
- Take the whole `COMMENT` set, `--` and `;` included. Rejected: no `CODE_EXT` language comments
  that way, so they add false refusals and catch nothing. `[seen]`: `jig.py:903-904`.
- Stage a ledger row for these lines. Rejected: they aren't workarounds, and the ledger would
  lie. `[seen]`: the template says the ledger is "patches that are in the code".
- Commit with `--no-verify`. Rejected: the AGENTS template says never. `[seen]`:
  `plugin/templates/AGENTS.md:21`.

### Decisions
- Pattern: `^\+(?:.*(?:#|//|/\*)|\s*\*)\s*WORKAROUND:`. The marker must follow `#`, `//` or `/*`
  anywhere on the line, or a leading `*`, with only spaces between.
- Risk kept: a string that itself reads as a comment (`s = "# WORKAROUND: x"`) is still
  refused, and a marker not directly after its opener is no longer caught. Both are rare;
  the first is the old behaviour.
- Review, Oct 29 (fresh context, on the spec). Blocking, taken: the spec ignored the existing
  `.jig/jig.py` exemption; a rejected alternative was what the code already does; the
  "change the R7 message in jig.py" case would pass before the fix. Should-fix, taken: one
  reading of where the opener sits, `--` and `;` dropped, a continuation-line case. Optional,
  taken: `RULES.md` needs no change.
- Build, Oct 29. Done as written. Smoke: 189 PASS, the seven new R7 cases among them; the
  done-when grep finds nothing; the validator passes. The adopt install copies this repo's
  `plugin/templates/jig/` rather than the installed plugin's, whose only difference is this
  fix, so the hooks judge jig's source with the anchored pattern from the first commit.
