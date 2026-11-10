# bug-meta-decision-foldin

Source: maige-ecosystem hubnode session with Dave, 2026-11-10 (Claude) (staged as feedback-maige-ecosystem-2026-11-10-redocument-metarepo.md): "A changed decision row asks no page." "Every copy" "is enforced by a spec author's memory: a decision changes and the pages citing it as their source are not asked."

## Intent
In a metarepo, `jig handoff` asks every page that cites a decision whose row the branch
changed, one fold-in line per page, the same way it asks a page whose docmap file changed.

## Why
- Why does changing D-007 ask no page? `foldin_lines` asks only docmap pages whose globs match a
  changed file. A metarepo's docmap is `{}`, and a row is not a file.
- Why can't docmap carry it? It maps a page to file globs. Mapping a page to the register asks it
  on every row change, so mapping each page that way asks all of them on any row change.
- Why does it matter? RULES.md makes a row and the pages citing it one home (What the metarepo
  holds). Only the spec author's memory ("Every copy") finds those pages.

## Givens
- `[seen]` Repro, throwaway metarepo, jig from `plugin/templates` (whose `jig.py` is the report's
  blob b9d48e5): `features/pay/pay.md` (an entry file) cites D-001. A branch that changes only
  D-001's row hands off with `- [ ] no code changed — nothing to fold in`.
- `[seen]` The same repo with docmap `{"features/pay/pay.md": ["DECISIONS.md"]}` asks the page. It
  would ask it for any row's change.
- `[seen]` maige-ecosystem (read only): docmap `{}`, prefix `E-`, register
  `decisions/DECISIONS.md`, and every page folder is in `entry_files`. `E-045` appears in
  `GLOSSARY.md`, `products/hardware/mods.md`, `walyt.md` and `products/software/maige-lite.md`.
- `[seen]` `jig gate` refuses any `- [ ]` fold-in line. A throwaway prototype of the design below
  (about 15 lines in `foldin_lines`) wrote `- [ ] features/pay/pay.md — updated / no change
  because ___   (D-001)`, and the unchanged gate refused it.
- `[seen]` The pararepo side already does this across repos: `changes_report` greps for
  changed ids, whole word.
- `[seen]` RULES.md, Homes: a metarepo's homes are what `entry_files` names.

## Design
In `foldin_lines`, when `meta.json` is on trunk:
- Read the changed ids: the decision ids on added or removed `| <prefix>N |` rows in the branch's
  diff of `.md` files. This is the row regex M2 and `terms_changed` use.
- For each entry file at HEAD whose text holds one of those ids as a whole id, add the page with
  its ids. `D-7` is not `D-70`. Skip `CHANGELOG.md` and any file holding a changed row.
- Write one line per page with its ids in place of the file count. If docmap also names the page,
  the two merge into one line.
- Leave the gate unchanged. Add one sentence to RULES.md's Fold-in section.

## Done when
- [ ] Smoke `metarepo`: page A cites D-007, page B cites D-0070, and a page outside
      `entry_files` cites D-007. A branch that changes only row D-007 hands off with
      `- [ ] A — updated / no change because ___   (D-007)`, and with no line for B, the stray page,
      `DECISIONS.md` or `CHANGELOG.md`. "No code changed" is gone, which is the reported symptom.
- [ ] Smoke: `jig gate` refuses that note, and passes once the line is answered.
- [ ] Smoke: a branch that marks D-007 `superseded by D-012` asks A.
- [ ] Smoke: a repo with no `meta.json` writes the fold-in it writes today (existing cases pass).
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- Changed glossary terms asking the pages that use them. A term is free text.
- `jig reading-list` by decision id.
- Telling a page that cites an id "as its source" from one that only mentions it. Both are asked,
  and "no change because" answers a passing mention.

## Touches
- `plugin/templates/jig/jig.py` (`foldin_lines`)
- `plugin/templates/jig/RULES.md` (Fold-in)
- `tests/smoke.sh` (`metarepo`)
- `marketing/FEATURES.md` (`docmap` + fold-in row)

## Alternatives considered
- Docmap each page to the register — rejected because every row change would ask every page, and
  in maige-ecosystem that means every page maps to `decisions/DECISIONS.md` — reason is [seen]
- A config map from page to ids — rejected because it is a second hand-kept list beside page text
  that already names its ids — reason is [seen]
- Check "Every copy" in the spec — rejected because a spec is written before the change, and
  a row edit with no such spec escapes it. Fold-in runs at every handoff — reason is [seen]
- Ask every tracked `.md` outside `.jig/` — rejected because a metarepo's homes are its entry
  files, and survey already reports a stray — reason is [seen]

## Decisions
- An id counts only whole: `(?<![\w-])<id>(?!\d)`.
- The line names the ids that asked it, so the answerer knows which claim to check.
- Workaround until it lands: before handoff, run `git grep -lw <id>` for each changed row and
  list the pages in the spec's Done when ("Every copy").

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
