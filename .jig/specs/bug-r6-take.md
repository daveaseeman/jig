# Bug: R6's rulebook and code disagree on what "takes" a number

Source: `/jig:feedback` from a pararepo, Oct 30 (`jig-feedback-<repo>-2026-10-30-r6.md`). Checked
against `plugin/templates/jig/jig.py` at b5ed1cf.

## 1. Why
- Why were `### 1.5` and `### 1.6` refused under a section 1 that trunk already had? R6
  counts each number's matches per file, and refuses any count that rose.
- Why is that a surprise? RULES.md says a take "makes a number … exist where trunk had none".
  By that wording, a second rule under section 1 takes nothing.
- Root: the two definitions agree only when each number appears once (migration steps). The
  Documentation shape puts many rules under one section, `### 31.1`, `### 31.2`, so a
  rule-level pattern matches each section number many times.

## 2. Givens
- `[seen]` `reserved_refusals`: `if after[got] <= before.get(got, 0): continue`. Its docstring
  says "only a count that rose is a take".
- `[seen]` `RULES.md` R6: "makes a number matching a counter's `pattern` exist where trunk had
  none". The Reserved numbers section shows only `SCHEMA_VERSION\s*=\s*(\d+)`.
- `[seen]` The reporting repo's counter was `^### (\d+)\.\d+` over `docs/**/*.md`. Two jobs
  rewrote work to get past it. `^### (\d+)\.1(?!\d)` gives the behavior the rulebook describes.
- `[seen]` What the count rule catches that "exist where none" wouldn't: a branch adding a
  second `SCHEMA_VERSION = 17` where trunk has one. Two step-17 migrations is the corruption R6
  exists to stop.

## 3. One layer up
Both readings are coherent, and they differ only on a number that is already taken. The rule
is about collisions, and a collision is two changes taking the same number. A second rule under
a section that's already on trunk isn't one. A second migration 17 is one, but the number then
also appears twice in one file. That's a different check, and it happens wherever the number
is defined.

## 4. Correction
The code follows the text: a number is taken when trunk had no match for it and the branch
adds one. Same file or another, the count doesn't matter. A counter whose numbers must also be
unique gets `"unique": true`, which refuses a branch that raises any number's count beyond one
in the counter's files.

## 5. Spec

### Done when
Smoke, with the section counter `^### (\d+)\.\d+` over `docs/**`:
- [ ] Trunk has `### 1.1`, and a branch with no reservation adds `### 1.2`: accepted.
- [ ] A branch adds a page with `### 12.1` and holds no section: refused, "takes section 12".
      Holding section 12: accepted.
- [ ] Moving or editing a heading still takes nothing (the existing cases).
- [ ] A `schema` counter with `"unique": true`: a branch adding a second
      `SCHEMA_VERSION = 17` where trunk has one is refused, "17 already exists". Without
      `unique`, it's accepted (and nothing takes 17).
- [ ] `RULES.md` R6, the Reserved numbers section, and the `reserved_refusals` docstring say the
      same rule. Reserved numbers shows the section example and the `unique` example.
- [ ] Smoke passes, and the validator passes.

### Touches
`plugin/templates/jig/jig.py` (`reserved_refusals`), `plugin/templates/jig/RULES.md`,
`tests/smoke.sh`. This sits beside `bug-r6-m5-decisions-dest.md`, which makes the same
function compare ints: build them in one pass.

### Alternatives considered
- Text follows code: document "a rise in the count", and give a section example that matches
  once per section. Rejected: every repo using the Documentation shape writes the natural
  pattern first, as this one did, and the rule then refuses ordinary edits. `[seen]`: two jobs
  rewrote work.
- "Exist where none" with no `unique`. Rejected: it loses the duplicate-migration catch the
  count gave for free. `[seen]`: R6's own example is migration step 17.

### Open
- Should `unique` be on by default for a counter? The default today would be off. Then a
  plain migration counter loses the duplicate catch until someone sets it.
