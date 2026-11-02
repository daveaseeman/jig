# Handoff: entry-globs

Commit: 81a6ea9eb9f352a367d237bcea55b9bf825886fb
Date: 2026-11-02
Spec: .jig/specs/bug-meta-entry-globs.md
Review: tier and effort not recorded

## Built
- `entry_files` in a metarepo's `meta.json` take jig's globs (`products/**/*.md`). One check,
  `is_entry`, never counts anything under `.jig/`. `entry_paths(rev)` (`ls-tree` filtered by it)
  feeds the first release and the pararepo cache. The release check filters `git diff
  --name-only --no-renames` names by it, and M3 uses it. No glob goes to git as a pathspec, and
  paths are read with `core.quotePath=false`.
- `jig merge <job> --subject "<text>"` writes `<text>: merge <job>`. `proposal_in`'s fallback
  matches `(?:^|: )merge (\S+)$`, so a deleted proposal branch is still found.
- Hubnode skill: `jig workflow` missing → "run /jig:update first" and stop. The merge step names
  `--subject`.

## Done-when evidence
`bash tests/smoke.sh`: 405 PASS, no FAIL, exit 0. `claude plugin validate ./plugin`: ✔ Validation passed.
- products/a.md + CHANGELOG → `release --minor` tags v0.2.0: PASS "a change to products/a.md (directly under the glob's folder) releases the next minor"
- products/x/b.md the same: PASS "a change to products/x/b.md releases the next minor"
- All-glob first release: PASS "a metarepo whose entry_files are all globs makes its first release from them"
- M3 refuses products/a.md with no line, takes notes.md: PASS on both M3 cases
- New products/b.md needs no meta.json edit: PASS "a new products/b.md needs no meta.json edit; the next release counts it"
- init --para caches pages as files, no folder file: PASS "init --para caches products/a.md and products/b.md as files, and no file named for a folder"
- Exact paths still work: the existing meta and para cases pass unchanged, plus PASS "a cited file moved out of the exact entry_files still counts for the release"
- `--subject` and the gate fallback: PASS "the subject is '<text>: merge J'" and "the gate's fallback still finds job J by its merge after its branch is deleted"
- Hubnode skill says to run /jig:update: `plugin/skills/hubnode/SKILL.md` step 6
- RULES.md says entry_files take globs: Metarepo and pararepos section. Smoke and validator as above.
- Round-1 additions: PASS non-ASCII page released; PASS the three `**/*.md` cases (a .jig/ commit on trunk needs no line, a .jig/-only change is nothing to release, no .jig/ file in the cache)

## Review
Fresh-context review (hubnode, Opus xhigh), round 1, nothing blocking. Six findings, all taken in 81a6ea9:
1. The release diff's rename detection dropped a cited file moved out of the set → `--no-renames`, with a smoke case.
2. A glob reaching `.jig/` deadlocked M3/M4 and leaked notes into releases and caches → `is_entry` excludes `.jig/`, with smoke cases.
3. `proposal_in`'s regex change was missing from the spec's Touches, and the Correction was wrong → added to Touches and Decisions.
4. The hubnode merge step didn't name `--subject` → named.
5. `entry_paths` separated the STATUS_CELL comment from its code → moved.
6. Non-ASCII paths were quoted, so `matches` missed them → `core.quotePath=false`, with a smoke case.
Out of scope, moved to `report-fixes-followup.md` item 20a: M3's rename miss via `changed_paths`. Also noted for it: `changed_paths` quotes non-ASCII names, so M3 misses those too.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because jig's rulebook is `plugin/templates/jig/RULES.md`, which this job updated (entry_files globs, `--subject`). This repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/jig.py`: the fix itself (release, M3, cache, merge, `proposal_in`).
- `plugin/templates/jig/RULES.md`: entry_files take globs, `.jig/` never counts, `--subject` and its command line.
- `tests/smoke.sh`: a new section at the end, nothing above it edited.
- `plugin/skills/hubnode/SKILL.md`: step 6 (/jig:update when `jig workflow` is missing) and the merge step (`--subject`).
- `.jig/specs/bug-meta-entry-globs.md`: Touches and Decisions, from review finding 3.

## Test by hand
In a scratch metarepo, set `entry_files` to `["DECISIONS.md", "docs/**/*.md"]`. Merge a branch that changes only `docs/a.md` and the changelog, then run `jig release`: it tags. From the hubnode, `jig merge <job> --subject "D-001: land it"`, then `git log -1 --format=%s` shows `D-001: land it: merge <job>`.

## Left
Nothing on this job. Open in the spec, unbuilt: should release count .md files that no glob names?
