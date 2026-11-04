# Handoff: sync-report

Commit: 13793e16c21445bcee3c3c3b640ece168aaeb6ee
Date: 2026-11-03
Spec: .jig/specs/bug-sync-report.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
`jig sync` on a pararepo now:
- names a file that a decision at the pin cites, whatever case the decision spells the repo's name in (the path stays exact)
- reports only terms from the entry files, so no headings from the metarepo's `.jig/` files
- names the first release that held a proposal, the pin included, not the latest release

Repo names now compare case-insensitively through one `name_in` in three more places:
- `release_waits_for`, which holds `jig release` while a report waits in the fallback folder
- `staging resolve`'s target check
- the P4 check on files staged for the metarepo

## Done-when evidence
- 1: `bash tests/smoke.sh` → `PASS buffer: a decision may name this repo in any case, the path still exact` (`SB-Para/docs/z.md` → `docs/z.md is cited by D-003`). The existing case still passes, so `other-para/docs/x.md` is not reported.
- 7: `PASS sync: the changes report lists a new decision, and no heading from the metarepo's .jig/ files` (D-004 listed; no Built/Left/Done when/Touches)
- 8: `PASS sync on a pararepo trunk: once a later release is out, a proposal reads released by the first release that held it` (`released by v0.2.0` after v0.3.0)
- Decided 2: `PASS feedback: a report naming this repo in another case holds the release too` (`target: FR`); `PASS para P4: a file staged for the metarepo by its name in another case holds it back too` (`target: DOCS`)
- RULES.md: the sync-buffer paragraph now ends "A decision may cite this repo by name in any case (`App/docs/ui.md`); the path after it is exact."
- Smoke and validator, last run at 13793e1:
  - `bash tests/smoke.sh`: 483 PASS, 0 FAIL, exit 0. Tail: `PASS feedback: jig repos prints where tool reports wait` / `PASS isolation: the user's real jig config folder is unchanged by the run`
  - `claude plugin validate ./plugin`: `✔ Validation passed`

## Review
Round 1 was a fresh claude-opus-5-5 subagent at xhigh. It found nothing blocking: two should-fix and five optional findings.
- S1, Decided 2 had no Done when, no Touches and no smoke case: taken. All three added, with a `target: FR` release case.
- S2, P4 compared a staged file's target to the metarepo name exactly: taken. It now uses `name_in`, with a smoke case.
- O1, the status line dropped the pin: taken. It now scans the tags plus the pin.
- O2, the `re.IGNORECASE` rejection was tagged `[assumed]`: taken. Now `[seen]`.
- O3, the paths were still read as globs: taken. Now `--literal-pathspecs`.
- O4, the docstring named `App-Lite`: taken. Now `App`/`app`.
- O5, case is folded two ways (`(?i:)` and `casefold()`): deferred, with a row in `.jig/ledgers/DEFERRED.md`.
All fixes are in 13793e1.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty and has no docs/ tree. RULES.md's sync-buffer paragraph (updated) is what describes `jig sync`'s cited-file report.

## Shared files changed
- `plugin/templates/jig/jig.py`: where the three functions live, plus `name_in` and its callers.
- `plugin/templates/jig/RULES.md`: one sentence added to the sync-buffer paragraph.
- `tests/smoke.sh`: cases added inside the pararepo P4, pm gate, sync buffer and feedback sections, not at the end of the file.
- `.jig/ledgers/DEFERRED.md`: one appended row, for O5.

## Test by hand
Nothing beyond smoke. To see it yourself, in a pararepo whose metarepo has a decision citing `<Repo-Name-In-Other-Case>/docs/x.md`, run `jig sync` and check it names `docs/x.md`.

## Left
Nothing on this job. Folding `-`, `_` and spaces in names was not built (Decided 1).
