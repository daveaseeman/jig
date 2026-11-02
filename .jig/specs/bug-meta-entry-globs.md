# Bug: a metarepo can't release a change to its pages; `jig merge`'s subject carries no ids

Source: `/jig:feedback` from a metarepo on layout 8, Oct 31
(`jig-feedback-<metarepo>-2026-10-31.md`). Checked against `plugin/templates/jig/jig.py` at
2be8b03 (0.4.0). Issues 2 and 3 of the report are fixed in 0.4.0, by
`bug-r6-m5-decisions-dest.md` and `bug-merge-after-sync.md`.

## 1. Why
- Why was a release refused? The change touched only a page (`products/<x>.md`) and the
  changelog, and `jig release` counts only `entry_files` changes: "nothing to release".
- Why didn't the page count? `entry_files` is a list of exact paths, defaulting to
  `DECISIONS.md` and `GLOSSARY.md`. A pararepo cites pages at a tag just as it cites the
  decision log.
- Root: one list of exact paths does three jobs: what a release counts, what M3 asks a
  changelog line for, and what a pararepo's cache copies. A folder can't go in it, because the
  cache runs `git show <pin>:<path>` and would write a tree listing as a file.

## 2. Givens
- `[seen]` `cmd_release`: `git diff --name-only <last> HEAD -- *entry_files`.
- `[seen]` M3: `any(p in entry for p in paths)`, an exact match.
- `[seen]` `fill_cache`: `for f in [*entry_files, CHANGELOG]: git show {pin}:{f}`.
- `[seen]` The repo's workaround lists all 24 pages by hand in `entry_files`. A new page needs a
  new line.
- `[seen]` Run on Nov 2 in a scratch repo with `products/a.md`, `products/x/b.md` and `notes.md`:
  - `git show v1:products` prints `tree v1:products` and a listing, so a folder in the cache
    loop would be written as a junk file.
  - A plain git pathspec `products/**/*.md` matches only `products/x/b.md`: git's `**` without
    `:(glob)` doesn't match zero folders. `:(glob)products/**/*.md` matches both.
  - jig's own `matches()` takes `products/**/*.md` to both files and refuses `notes.md`, the
    same as `:(glob)`. `DECISIONS.md` still matches itself.
- `[seen]` The first release checks `(root / f).exists()` for each entry, so a glob there never
  exists, and a metarepo whose entries are all globs would say "nothing to release" on its first
  release.
- `[seen]` `init --meta` seeds only the files in its own seed list, so a glob in `entry_files`
  makes it write nothing odd.
- `[seen]` `jig merge` writes `merge <job>`, and `-m` appends to the body only. The metarepo's
  rules ask every subject to start with its ids, so the hubnode amended each merge by hand.
  M6 exempts merges, so jig doesn't require it.
- `[seen]` The gate's deleted-branch fallback (added in 0.4.0) finds a proposal job by
  matching `^merge (\S+)$` on the merge subject. A subject change must keep it findable.

## 3. One layer up
- Every other path list jig keeps is a glob list (`owns`, `shares`, `common`, `not_docs`,
  `release.artifacts`, a counter's `files`), matched by `matches()`. `entry_files` is the one
  exact list.

## 4. Correction
`entry_files` takes globs, like every other path list, with jig's glob meaning, never git's.
One helper, `entry_paths(rev, cwd)`, lists the tracked files at a revision (`git ls-tree -r
--name-only`) and keeps those `matches(entry_files)` names. Every reader uses it or `matches()`:
- the release check: the names `git diff --name-only <last> HEAD` prints, kept by `matches()`.
  The first release uses `entry_paths(HEAD)`.
- M3: `matches()` in place of `in`.
- the cache: `entry_paths(pin)` in the metarepo's checkout, one file at a time.

No glob goes to git as a pathspec. Git's `**` reads differently from jig's (Givens), and the
same list would then mean two things.

The defaults don't change. `init --meta` writes a comment in `meta.json`'s place in RULES saying
pages go in as globs (`docs/**/*.md`).

`jig merge --subject "<text>"` sets the subject. jig keeps ` merge <job>` at its end, so the
gate's fallback still finds the job: `E-045, E-044: merge walyt-alpha-mapping` matches
`merge (\S+)$`.

The hubnode skill's `jig workflow` step: when the command doesn't exist, the repo's `.jig/` is
older than the plugin, so the skill says "run /jig:update first" and stops.

## 5. Spec

### Done when
Smoke, in a metarepo fixture with `entry_files: ["DECISIONS.md", "products/**/*.md"]`:
- [ ] A commit changing only `products/a.md` (directly under `products/`) and `CHANGELOG.md`,
      then `jig release --minor`, tags the next minor. The same with `products/x/b.md`.
- [ ] A metarepo whose `entry_files` are all globs makes its first release from them.
- [ ] M3 refuses a change to `products/a.md` with no changelog line, and accepts a change to
      `notes.md`, which no glob names, without one.
- [ ] A new `products/b.md` needs no `meta.json` edit: the next release counts it.
- [ ] `jig init --para` in a pararepo caches `products/a.md` and `products/b.md` as files and
      writes no file named for a folder.
- [ ] Exact paths still work: the existing meta smoke cases pass unchanged.
- [ ] `jig merge J --subject "D-001: land J"` makes the subject `D-001: land J: merge J`, and the
      gate's fallback still finds job J by its merge after its branch is deleted.
- [ ] The hubnode skill says to run `/jig:update` when `jig workflow` isn't a command.
- [ ] RULES.md says `entry_files` takes globs. Smoke passes, and the validator passes.

### Out of scope
- Splitting `entry_files` into separate lists for release, M3 and the cache.
- Changing the default `entry_files`.

### Touches
`plugin/templates/jig/jig.py` (`cmd_release`, `meta_rules` M3, `fill_cache`, `cmd_merge`, the
merge parser), `plugin/templates/jig/RULES.md`, `plugin/skills/hubnode/SKILL.md`,
`tests/smoke.sh`, and a `marketing/FEATURES.md` row for `--subject`.

### Alternatives considered
- Split it into `release_paths` (globs, default every tracked `.md` outside `.jig/`) and
  `entry_files`. Rejected: a third list to keep in step, and a page is read at a tag exactly as
  the decision log is, so its changes belong in the changelog too. `[seen]`: M3's own comment,
  "a change to what pararepos cite is recorded where they will read it".
- Default `entry_files` to every tracked `.md`. Rejected: existing metarepos' M3 would start
  asking for changelog lines on files they never listed. `[assumed]`
- Take the ids for the merge subject from the branch's commit subjects. Rejected: it guesses
  which ids the merge is about, and a branch can carry several. `[assumed]`
- Folders as entries (`products/`). Rejected: the cache's `git show` writes a tree listing as a
  file. `[seen]`: run on Nov 2.
- Pass the globs to git as pathspecs. Rejected: plain pathspecs miss `products/a.md` for
  `products/**/*.md`, and `:(glob)` would make one list follow git's rules here and jig's
  everywhere else. `[seen]`: run on Nov 2.

### Open
- Should `release` also count `.md` files no glob names, so that no page can be left out of a
  release? It would mean a page change with no changelog line could still trigger a release.

### Decisions
- Evaluated with `/jig:bug`, Nov 2. Every given the fix depends on is now `[seen]`. That
  changed the correction: the spec first had the release check pass globs to `git diff` as
  pathspecs, and that would have missed every page directly under its folder.
