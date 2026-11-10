# Handoff: bug-meta-changelog-r3

Commit: c92d622f730d845c034eb55018e88e50e36e03ff
Date: 2026-11-10
Spec: .jig/specs/bug-meta-changelog-r3.md
Review: tier 2, effort 2
Ran: fresh Opus review of 4c0b11b: B1 exemption allowed rewriting or deleting CHANGELOG.md (reproduced), fixed in c92d622 (adds only, vs the job's base) with rewrite and delete smoke cases; O1 comment fixed; FEATURES R3 row updated by the hubnode. Hubnode checked c92d622 by diff and smoke metarepo/rules.

## Built
In a metarepo, R3 lets every job add lines to `CHANGELOG.md` without the hubnode listing it,
because M3 asks every job that changes an entry file for a line. The exemption reads M3's
`CHANGELOG` constant and holds only while the file is still in the index and the change deletes
none of its lines (`changelog_only_grows`); a rewrite or a delete stays an R3 refusal. Outside a
metarepo nothing changed. Smoke's `emergejob` no longer works around the bug with `--owns CHANGELOG.md`.

## Done-when evidence
- Metarepo job with `--owns GLOSSARY.md` commits a term plus its line: `bash tests/smoke.sh metarepo` → `PASS  meta R3: a job given only GLOSSARY.md commits a term with its CHANGELOG.md line` (FAIL with the exemption removed).
- `emergejob` without `CHANGELOG.md` in `--owns`: `bash tests/smoke.sh entry_globs` → both `merge --subject` cases PASS (FAIL with the exemption removed).
- No meta.json, unlisted `CHANGELOG.md` still refused: `bash tests/smoke.sh rules` → `PASS  R3: outside a metarepo, a CHANGELOG.md the job doesn't own or share is refused`.
- Review B1: `PASS  meta R3: the same job rewriting CHANGELOG.md is refused` and `PASS  meta R3: the same job deleting CHANGELOG.md is refused` (both FAIL with the 4c0b11b exemption).
- `bash tests/smoke.sh` → exit 0, 755 PASS, 0 FAIL; `claude plugin validate ./plugin` → `✔ Validation passed`; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → empty.

## Review
- B1 (blocking): the exemption allowed any change, so a job could rewrite or delete the changelog and erase released history. Fixed in c92d622: added lines only, file must stay; two smoke cases refuse each.
- O1: the comment claimed one line while the code allowed anything. Comment and the RULES.md R3 line now say "lines added".

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's docs are .jig/RULES.md (plugin/templates/jig/RULES.md), updated here: the R3 line names lines added to `CHANGELOG.md` in a metarepo

## Shared files changed
- `plugin/templates/jig/jig.py`: the R3 exemption and `changelog_only_grows`.
- `plugin/templates/jig/RULES.md`: the R3 line.
- `tests/smoke.sh`: `emergejob` drops its workaround; new cases in `rules` and `metarepo`.
- `.jig/specs/bug-meta-changelog-r3.md` (common): Done-when ticked.

## Test by hand
Nothing beyond smoke. Optionally: in a throwaway metarepo, open a job with only `--owns GLOSSARY.md`, add a term and a `CHANGELOG.md` line, and watch the commit pass; then replace the changelog and watch R3 refuse.

## Left
Nothing. A later commit editing a changelog line the job itself added is refused too (the check is per commit); accepted as harmless. The FEATURES.md R3 row is the hubnode's.
