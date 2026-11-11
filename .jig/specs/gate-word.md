# gate-word

Source: Adventure-Studio hubnode session / 2026-11-11 / Dave, with Claude (staged as feedback-adventure-studio-2026-11-11-sync-log-and-names.md): "`sync` does two unrelated jobs; other names do too"

The owner chose to split `gate`, Nov 11.

## Intent
"Gate" means `jig gate` only: the hubnode's step before a merge. The M1–P4 checks a metarepo or
pararepo's hooks run are rules, like R1–R8, and RULES.md calls them that.

## Why
- Why is "gate" ambiguous? `jig gate` is a step, while RULES.md's table of M1–P4 is headed "Gate",
  and "each side's gates are on only when its file is on trunk" means rules.
- Why does it matter? A product built with jig may have gates of its own (the reporting repo has
  Ordinary, Major and Constitutional), so the word is already busy in the reader's head.

## Givens
- `[seen]` RULES.md ~754: `| Gate | Refuses |`. ~725: "Each side's gates are on only when its
  file is on trunk".
- `[seen]` jig.py prints rule ids (`M2 …`, `P2 …`), not the word "gate", for those refusals.

## Design
- RULES.md: the table heading becomes `| Rule | Refuses |`, and every sentence that calls M1–P4 a
  gate says rule. Skills that say "gate P2" or "the M gates" say "rule".
- jig.py: any printed message or comment that calls M1–P4 a gate says rule.

## Done when
- [ ] `grep -n -iE "gates?\b" plugin/templates/jig/RULES.md plugin/skills` finds the word only for
  `jig gate` and the gate step.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Renaming `jig gate`.

## Touches
- `plugin/templates/jig/RULES.md`, `plugin/skills/*/SKILL.md`, `plugin/templates/jig/jig.py`
  (messages and comments only)
- `tests/smoke.sh` (only if a smoke grep matches the old word)

## Alternatives considered
- Rename `jig gate` and keep the table's word. Rejected: `jig gate` is the more used of the two,
  and the table already sits beside R1–R8, which are called rules. Reason is [assumed].

## Decisions
- Runs after `rename-check-rules`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
