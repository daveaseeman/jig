# bug-workflow-unknown-key

Source: hubnode, Nov 8, in the jig repo's own `jig update` dry run before the v0.8.0 release:
"board key `workflow` is not one jig knows: kept, and the checker ignores it". No feedback
report filed it. The same warning shows in every repo whose `config.json` sets `workflow`.

## 1. Why
- Why the warning? Update warns about any board key that isn't in `BOARD_DEFAULTS` or the
  retired-keys tuple. `workflow` is in neither (`jig.py:4174`).
- Why not? `workflow` has no default to write. Its defaults are `WORKFLOW_DEFAULTS`, and a board
  sets the key only to override them. `BOARD_DEFAULTS` doubles as the list of known keys, so an
  optional key has no place in it.
- Why does that matter? There is no list of optional keys. Any key jig reads but never writes by
  default looks unknown to update, and the warning's "the checker ignores it" is then false.

## 2. Givens
- [seen] The warning prints in this repo's `jig update` dry run, whose `config.json` has a
  `workflow` override, added in cb6af2f on Nov 4.
- [seen] The warning arrived with update on Oct 29 (41ba4d7). The `workflow` key came a day
  later, on Oct 30 (32be42c), without being added to `BOARD_DEFAULTS` or the tuple.
- [seen] jig reads the key: `workflow_steps` (`jig.py:189`) is called by `jig workflow`
  (`:238`), and the commit hook validates a staged `config.json` with it (`:319`). So "the
  checker ignores it" is false.
- [seen] `workflow` is the only board key jig reads that isn't in `BOARD_DEFAULTS`. The other
  keys it reads are meta.json's, or job fields.
- [seen] RULES.md's list of config keys (Board, `RULES.md:26`) omits `workflow` too.
- [seen] No feedback is staged here, and `~/.config/jig/feedback/` doesn't exist.

## 3. One layer up
- **Sibling: the same check for other optional keys.** `reference_files` avoided this by having
  a default (`""`), so update writes it into every board. A key whose absence means "use jig's
  defaults" can't do that without writing a no-op `workflow: {}` everywhere.
- **Sibling: the spec docs-subsystems.** It adds `deep_subsystems`, another optional key. That
  spec puts it in `BOARD_DEFAULTS` as `{}`. A list of optional keys would let it be optional too.
- **Pattern already there.** The tuple `("lanes", "log", "payload")` already exempts keys
  outside `BOARD_DEFAULTS`, for retired keys that update migrates. A sibling tuple of optional
  keys is the same shape.

## 4. Workaround or correction
Correction: name the optional keys once, beside `BOARD_DEFAULTS`, and build update's
known-keys check from both. RULES.md's config-key list names `workflow`.

## Intent
`jig update` warns only about board keys jig neither writes nor reads.

## Done when
- [ ] Smoke `update` (or `workflow`): on a board with a valid `workflow` override, `jig update`
  prints no "is not one jig knows" line for `workflow`, and leaves the override unchanged. This
  shows the symptom is gone.
- [ ] Smoke: a board with an unknown key `bogus` still gets the warning for `bogus`. This shows
  the check still fires.
- [ ] Smoke: update doesn't add a `workflow` key to a board that lacks one.
- [ ] RULES.md (Board) lists `workflow` among `config.json`'s keys.
- [ ] `bash tests/smoke.sh` passes, `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- `deep_subsystems`. It belongs to the docs-subsystems spec, which can use this list once both
  have landed.

## Touches
- `plugin/templates/jig/jig.py`: a `BOARD_OPTIONAL` tuple next to `BOARD_DEFAULTS`, used by the
  check at `~4174`
- `plugin/templates/jig/RULES.md`: the Board section's list of config keys
- `tests/smoke.sh`

## Alternatives considered
- Add `"workflow": {}` to `BOARD_DEFAULTS`: rejected because update would then write a no-op
  override into every board. An empty override also reads as "this repo chose the defaults"
  when it decided nothing [seen: update writes every missing `BOARD_DEFAULTS` key,
  `jig.py:4165-4169`].
- Add `"workflow"` to the retired-keys tuple: rejected because that tuple holds keys update
  migrates or drops, and putting a live key there would mislabel it [seen: `jig.py:4174` and
  the migrations above it].
- Suppress the warning only in this repo: rejected because every repo with an override sees it,
  so this is jig's bug and no one repo's [seen: the warning's condition depends only on the key].

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
