# Bug: a `**Breaking:**` line makes a release major, and nothing tells the pararepos it touches

Source: Maige-Eco hubnode session / 2026-11-18 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-18-versioning-and-pin-trigger.md): "Maige-Eco's next release moves its glossary from `README.md § Glossary` to `docs/glossary.md`. That release carries a `**Breaking:**` line, so jig's rule makes it a major release, v4.0.0."

The owner's words, quoted in the report's Source line:
- "I just dont think that's what major release version should be for, they should be for more fundamental changes or significant progress or something like that."
- "in terms of significance to the meta repo this change is a +0.0.1 in my opinion. So maybe we need a better way to update other repos. I mean, why not update them on every version move of the meta?"
- "I think jig's rule should be updated for meta repos. The breaking line should be enough for paras to move their pin. I think semantic versioning is too strict."

The report also quotes the owner's rulings on its Versioning draft, made in that session (quoted
under Part A). Everything else the report proposes is the reporter's. What this spec adopts from it
is marked `Interpreted:`.

## Intent
Every jig repo versions by how much its product changed, so a `**Breaking:**` line no longer
raises the level. A metarepo release instead stages a pin-bump request in each pararepo whose
citations it broke, carrying those Breaking lines and the rewrite list.

## 1. Why
1. Why is the glossary move a major? Its Unreleased has a `**Breaking:**` line, and the log header,
   RULES.md and /jig:release all say a breaking change is a major. [seen]
2. Why does jig say that? It adopted SemVer for every kind of repo, and SemVer's major is how a
   dependent learns it must act. [seen: `LOG_SEED`, RULES.md 923]
3. Why is that wrong for a metarepo? Its pararepos cite it by path and heading, so any move
   breaks them: majors end up counting bookkeeping, and the version stops saying how much the
   product changed. [seen: Maige-Eco tagged v2.0.0 and v3.0.0 on 2026-11-13]

Root: the version number has two jobs. One is how much the product changed. The other is
"dependents must act", and that job already has its own carriers: the `**Breaking:**` line, and
the pararepo's sync report. What's missing is a push. A pararepo hears of a release only at its
own `jig sync`.

## 2. Givens
Trunk `c721fd3`, `plugin/templates/jig/…` (the report read `f0005adc5fe4`; it diffed each place
it names against trunk, and those places match).
- [seen] `LOG_SEED` (jig.py 5626-5632) writes "versions follow Semantic Versioning … released as a
  major version". A throwaway `jig init` log opens with those two lines, and so does Maige-Eco's
  `.jig/decisions.md` (read with `git --no-optional-locks show`).
- [seen] RULES.md states the rule at 923 ("versions follow SemVer"), 1000-1001 ("is a major
  release"), 1266-1267 ("released as a major"), 1331-1332 (a metarepo "defaults to `--minor` …
  major for a rename or a reversed decision") and 1416-1418 and 1443 (the flags).
  `skills/release/SKILL.md` 16, 20-21 ("means `--major`") and 53 (`--minor` for 0.1.0, a line the
  report missed). `skills/redocument/SKILL.md` 90 ("so it is a major"). No other skill or template
  says "major" or "SemVer" (`grep -rni`).
- [seen] No code ties `**Breaking:**` to a level. Reproduced in a throwaway plain repo with the
  plugin copy: `release --version 0.3.0`, a `**Breaking:**` line under Unreleased, then `jig
  release` tagged v0.3.1, with no refusal or warning.
- [seen] `next_version` (6768-6786): after v3.0.0 a metarepo's default is 3.1.0 and a plain
  repo's is 3.0.1 (called directly). `--major` help is "in a metarepo: a rename or a reversed
  decision" (13718).
- [seen] `newer_release` (8134-8138) is the only code that reads X. It adds "(a major release)"
  to the pararepo's `jig sync` report when X rose, and prints no `**Breaking:**` line.
- [seen] R3 refuses a job that rewrites a header line (`outside_open_deleted`, 5903; smoke.sh 1043-1045).
  `log_is_seed` (11908) compares the whole log with `LOG_SEED`.
- [seen] `cmd_release` in a metarepo ends at the tag and the push line. It never reads
  `meta.json`'s `pararepos`. A metarepo's trunk `jig sync` dies "not on a job branch" (2155).
- [seen] `forward` (9302) is "the one place jig writes in another repo": into the target's
  `.jig/staging/`, after checking `pararepos` and the target's `para.json`. A release refuses
  while anything is staged (`staged_refusal`, 8870, called from `cmd_release`).
- [seen] RULES.md Inbox (1195): a message "is read and done with, never landed or resolved, and
  nothing else (a commit, a gate, a release) looks at the inbox". Staging (1126) holds a file
  with a `destination` until it's resolved or dropped.
- [seen] `defer_until` (para.json) is the only hold. `init --para` writes null. `sync_meta`
  (7981) and `para_problems` (7471) skip the upstream report before its date. RULES.md never
  mentions it. A non-date string holds forever by accident: `"2026-11-18" < "Phase 1 demo gate"`
  is True.
- [seen] Maige-Eco lists Maige-Lite, Maige-OS and Maige-Familiar in `pararepos`, and has tags
  v1.0.0 (10-30), v1.1.0 (10-31), and v2.0.0 and v3.0.0 (both 11-13).
- [assumed] The report's selection runs: `changes_report`'s word grep hits 37-40 items per
  Maige pararepo on this release, and `meta_citations` finds new dangling citations only in
  Maige-OS. Not rerun here. The selector below avoids the word grep either way, so the design
  doesn't depend on the count.
- [assumed] The Claude Code plugin host orders `plugin.json` versions as X.Y.Z, with no meaning
  per part. Not checked. The format doesn't change, so ordering holds either way.
- [assumed] A job branch that moves `para.json`'s pin passes the gate and P1. Not tested. If it
  doesn't, the job lands the rewrites, and the pin commit is made on trunk by today's path.

## 3. One layer up
- Siblings: plain repos and pararepos share `LOG_SEED`, `next_version` and the release skill, so
  they get the same rule. In a plain repo, a `**Breaking:**` line marks a reader's work, not the
  product's size, just as it does in a metarepo.
- The reverse push already exists. A pararepo's release sends its Open BUFFER rows to the
  metarepo (`buffer_proposal`). `forward` already writes into a pararepo's staging. `peer_logs`
  already reads pararepos from the metarepo. And `meta_citations` already finds dangling
  citations and names their new homes. The push is these pieces run from the metarepo's side.
- Staging or inbox: staging. A pin bump must be tracked until the pin moves, and it has a
  destination (`para.json`). The inbox is one-way, read and done with, and nothing tracks it.

## 4. Workaround or correction
Today's workaround is `jig release --patch` by hand. But the header, RULES.md and /jig:release
would still say major, so the next hubnode proposes major again [seen: release skill 20-21].
Correction: replace the rule wherever it's written, and move the dependents' signal into the
Breaking lines, printed by sync and pushed by the release.

## General?
- **Levels by product change: kept.** Any metarepo used as RULES.md describes, cited by path and
  `§` heading, breaks its pararepos on ordinary moves (redocument says so), so its majors count
  bookkeeping. A prototyping plain repo renames often for the same reason. Nobody has to work
  against jig to hit this. The owner ruled it applies to every repo kind (Part A).
- **Pin-bump request: kept.** Any metarepo with pararepos has the gap: a pararepo hears of a
  breaking release only when its own sync runs.
- **`meta.json` `holds`: dropped.** It serves one metarepo's own policy (Maige-Eco's sprint rule
  for Maige-OS, which lives in its `AGENTS.md`). What jig promises is the pararepo's own
  `defer_until`, and the request honours it. Maige-OS can set a `defer_until` date. Or it can
  leave the request staged: a request doesn't block its release (Part B), and each later release
  rewrites the file in place.
- **`jig sync` on a metarepo's trunk re-staging requests: dropped.** No repo needs it. The
  pararepo's own `jig sync` still reports every newer release, now with its Breaking lines, and
  the next metarepo release stages a request covering the whole gap.
- **A SemVer switch for registry-published libraries: dropped.** None of the owner's repos
  publishes to a registry [seen, per the report]. RULES.md says in one sentence that such a repo
  would need one.

Issues 1 and 2 are one group. Part A could ship alone, since its sync change restores the signal
on pull. But both parts edit the same RULES.md release paragraph (1331-1336), the release skill
and `cmd_release`, so consolidate would join them anyway. And the owner's sentence ties them:
"The breaking line should be enough for paras to move their pin."

## Design

### Part A: versions measure the product

1. RULES.md gets a `## Versioning` section just before `## Release`. Interpreted: its text is
   the report's block, which the report says the owner agreed in the session. That agreement is
   [assumed]: it isn't in the Source line. The owner's rulings, as the report quotes them: "1.
   Agreed, adapt it to work for regular repos, meta, and para universally"; "2. I would drop it
   [user effort as a criterion] or dramatically change it then, because this should be an 0.0.1
   in my opinion, a minor fix"; "4. No the policy is for jig which often starts from zero, so it
   needs a policy that applies there and it should be written such that it's clear this section
   simply doesn't apply to repos that are past it"; "Your trigger idea is good, but I dont wanna
   pick the version every time, I'd rather give the hubnodes some idea of how to judge it."
   Two changes to the block: its "What others must do" paragraph says the request goes to "each
   pararepo whose citations the release broke" (Part B's selector), and it ends with one
   sentence: "A repo published to a package registry, whose users expect SemVer, needs a rule of
   its own; jig has none yet."
2. Interpreted: the flags are `--milestone` (X), `--feature` (Y) and `--patch` (Z, the default
   in every kind after the first release), with `--major` and `--minor` kept as aliases. A
   metarepo's first release stays v0.1.0, and a plain repo's first still needs `--version` or
   `--feature`. `--milestone` refuses while the latest release is `0.y.z` or there is none, and
   names `--version 1.0.0` as the owner's call.
3. `LOG_SEED`'s two lines become: "…plus decision entries, and versions are
   MILESTONE.FEATURE.PATCH, set by how much the product changed (`.jig/RULES.md`, Versioning)."
   and "A breaking change is one that a reader taking the release must act on: a `**Breaking:**`
   line says what to change, and it doesn't set the version's level." `log_is_seed` also
   accepts the old seed.
4. Interpreted: `jig update` gets a step that swaps the old two header lines for the new ones,
   only where they match the old text exactly; a header that differs is named, not rewritten.
   R3 allows exactly that swap and nothing else. In a metarepo the swap lands through a job (M4).
5. `newer_release` drops "(a major release)". Under the "is out" line, it prints each
   `**Breaking:**` line of the releases between the pin and the latest, each with its release,
   read with `release_sections` from the metarepo's log at the latest tag.
6. The text, each changed to say Versioning sets the level and a Breaking line doesn't: RULES.md
   923, 1000-1001, 1266-1267 (drop ", released as a major"), 1331-1332, 1416-1418, 1443; release
   skill 16, 20-21 ("Propose the level as RULES.md § Versioning says: the highest level of any
   change in Unreleased, with a one-line reason; a `**Breaking:**` line doesn't raise it") and 53;
   redocument skill 90; hubnode skill's release step ("propose the level with a one-line reason;
   the owner's yes releases it"); jig's own `AGENTS.md` release line (`--feature` or `--patch`).
   RULES.md 991 and 1021-1022 (Breaking lines themselves) stay. Nothing is renumbered.

### Part B: a metarepo release stages a pin-bump request

1. **When.** In a metarepo's `jig release`, after the tag. A request that can't be written
   doesn't undo the tag. It prints one line saying why.
2. **Who.** Each name in `meta.json`'s `pararepos`, found through `jig repos`, whose trunk
   `para.json` names this metarepo. One line per pararepo: staged (with counts), or skipped
   because it isn't in `jig repos`, doesn't cite this metarepo, has a future `defer_until`
   (compared exactly as `sync_meta` does), already pins this release, or cites nothing the
   release broke.
3. **Selector.** Interpreted from "The breaking line should be enough for paras to move their
   pin": a pararepo is selected when this release broke something it cites. It reads the
   pararepo's trunk with `meta_citations`' files and exclusions, comparing the previous tag with
   the new one:
   - (a) a citation that resolves at the previous tag and dangles at the new one;
   - (b) a decision id the release removed or superseded, cited as a whole word.

   Rewordings, Open → Accepted, and glossary rewording don't select. The pararepo's own sync
   reports those, as today. `changes_report`'s word grep doesn't select. `meta_citations` takes
   the pararepo and metarepo revisions as arguments instead of reading the cache and HEAD.
4. **What it writes.** `<para>/.jig/staging/pin-bump-<meta>.md`. Its header: `staged: true`,
   `target`, `kind: pin-bump`, `change: update`, `destination: .jig/para.json`,
   `source: <meta> release <tag> / <date>`, `from`, `pin`, `release`, `status: staged`. Its body
   runs from the pin to the new tag: the `**Breaking:**` lines with their releases, the rewrite
   list with each new home jig can name, the removed or superseded ids with the files that cite
   them, and the commit line `newer_release` prints. A later release rewrites the same file in
   place. jig writes nothing else there, and leaves a same-named file that isn't a pin-bump from
   this metarepo alone, naming it. It uses `forward`'s checks.
5. **Landing.** `kind: pin-bump` joins `KINDS`. `jig staging resolve` refuses it until the
   pararepo's trunk `para.json` pins the request's release or a later one. Its message names the
   way to land it: a job (`/jig:spec`) whose pin commit carries the request as its body, with
   the listed uses rewritten. `jig staging check` accepts the kind only with that destination.
   `drop` works as for any staged file. jig commits nothing in a pararepo.
6. Interpreted: a staged pin-bump doesn't block the pararepo's own `jig release`. The release
   names it instead, as RULES.md already says a newer metarepo release "refuses nothing" there.
   The pin stays the pararepo's buffer.
7. RULES.md: Staging gains the kind and how it resolves. The pin-bump paragraph (1332-1336) says
   the release stages the request. `defer_until` is documented as a date. hubnode step 5: in a
   pararepo, a staged pin-bump becomes a job; in a metarepo, report the release's per-pararepo
   lines to the owner. The stage skill covers resolving `pin-bump`.

## Done when
In throwaway repos, with `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config` on every jig
command and `<dir>` beside the repos:
- [ ] `jig init` writes a log header that names MILESTONE.FEATURE.PATCH and Versioning, without
  "Semantic Versioning" or "released as a major version". RULES.md has `## Versioning` just
  before `## Release`.
- [ ] Plain repo at v0.3.0 with a `**Breaking:**` line under Unreleased: `jig release` tags
  v0.3.1, and `--feature` tags v0.4.0. `--milestone` exits non-zero naming `--version 1.0.0`, and
  tags nothing. `--version 1.0.0` then `--milestone` tags v2.0.0. `--major` and `--minor` behave
  as `--milestone` and `--feature`.
- [ ] **The reported symptom is gone.** Metarepo after v0.1.0, with only a page move and its
  `**Breaking:**` line merged: `jig release` with no flag tags v0.1.1 (v0.2.0 today), and no rule
  text tells the hubnode to pass `--major`. `grep` over RULES.md, `LOG_SEED` and
  `plugin/skills/**/SKILL.md` finds none of "means `--major`", "is a major release", "released as
  a major", "so it is a major", "Semantic Versioning", "follow SemVer".
- [ ] A pararepo pinned to v0.1.0 of a metarepo at v1.0.0, whose log has one `**Breaking:**`
  line: the pararepo's `jig sync` prints that line under "is out", and no "(a major release)".
- [ ] A log with the old header: `jig update` lists the header step, and `--apply` swaps exactly
  those two lines. The commit passes the hook, and in a metarepo so do the job commit and its
  merge. A log equal to the old seed still counts as the seed.
- [ ] **The trigger fires.** Metarepo `M` lists pararepos `A`, `B` and `C` (each `jig repos add`-ed,
  `init --para M --pin v0.1.0`). `A` cites `` `M/docs/products/x.md` `` in a doc, `B` cites
  `M/.jig/decisions.md § E-002` in a spec, and `C` uses a glossary word in source only. `M` merges
  a job that moves `x.md` (with its Breaking line) and supersedes E-002. Then `jig release` in `M`
  tags v0.1.1 and prints one line each: `A` staged (1 rewrite), `B` staged (1 superseded id),
  `C` cites nothing v0.1.1 broke.
- [ ] `A`'s request passes `jig staging check`, carries the Breaking line and the citation's new
  home, and `B`'s names E-002's successor. In every repo, `git rev-list --count HEAD` and the pin
  are unchanged.
- [ ] In `A`, `jig staging resolve pin-bump-M.md` refuses while trunk pins v0.1.0, naming the
  job. It resolves after a merge that moves the pin to v0.1.1. A second `M` release before then
  leaves one file, covering v0.1.0 → v0.1.2. `A`'s `jig release` with the request staged isn't
  refused, and names it.
- [ ] A pararepo with `defer_until` in the future gets no request, and its skip line says why.
- [ ] `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh` passes, with these
  cases in `release`, `metarepo`, `pararepo`, `decisions`, `staging` and `update`, and smoke.sh's
  1043-1045, 1725-1726 and 5226 moved to the new header and flags.

## Out of scope
- Renumbering any release, and the level of Maige-Eco's next release: its hubnode proposes that.
- A check that judges a level. The hubnode proposes it, and the owner's word releases it.
- Holds set by the metarepo, and re-staging from a metarepo's trunk `jig sync` (General?).
- A `defer_until` that isn't a date, which holds forever by accident. It's a bug of its own:
  this spec compares the same way `sync_meta` does and leaves it.
- Rewriting a pararepo's citations. The job does that.
- Changes inside a cited section whose heading and path still resolve. The pararepo's sync
  report covers those.

## Touches
- `plugin/templates/jig/jig.py` (`LOG_SEED`, `log_is_seed`, `outside_open_deleted`, update `STEPS`,
  `next_version`, release arguments, `newer_release`, `cmd_release`, `meta_citations`, `KINDS`,
  `read_staged`, `cmd_staging_check`, staging resolve, `staged_refusal` callers)
- `plugin/templates/jig/RULES.md` (Decision log, Writing it, Metarepo and pararepos, Staging, new
  Versioning, Release, Commands; Homes row: a rule, so RULES.md)
- `plugin/skills/release/SKILL.md`, `plugin/skills/redocument/SKILL.md`,
  `plugin/skills/hubnode/SKILL.md`, `plugin/skills/stage/SKILL.md`
- `tests/smoke.sh` (`release`, `metarepo`, `pararepo`, `decisions`, `staging`, `update`)
- `AGENTS.md` (the release line)
- `marketing/FEATURES.md` rows for both parts, as AGENTS.md asks. The file is gitignored and
  lives only in the trunk checkout [seen], so the hubnode adds the rows there.

## Alternatives considered
- Keep SemVer and pass `--patch` by hand — rejected because the header, RULES.md and /jig:release
  still say major, and the next hubnode proposes major again — [seen] (release skill 20-21).
- Apply the policy to metarepos only — rejected by the owner: "1. Agreed, adapt it to work for
  regular repos, meta, and para universally" — [seen] (quoted in the report).
- Request to every pararepo on every release ("why not update them on every version move of the
  meta?") — rejected because a pararepo the release didn't break has nothing to do, and the
  owner's later word ties the move to the Breaking line — [seen] (the Source line).
- Select by `changes_report`'s "used in" — rejected because a word grep matches nearly every
  pararepo on every term — [assumed] (the report's 37-40 hits, not rerun here).
- Select on any changed id or reworded term, as the report does — rejected because those don't
  break a citation, and the pararepo's own sync reports them — [assumed] (that the owner meant
  "broke", not "changed").
- Deliver through the inbox — rejected because a message is read and done with, and nothing
  tracks that the pin moved — [seen] (RULES.md Inbox).
- Commit the pin bump in the pararepo — rejected because the pin is the pararepo's buffer, and
  the rewrites are reviewed work — [seen] (RULES.md, Metarepo and pararepos).
- A `"versioning": "semver"` switch now — rejected because no jig repo publishes to a registry
  today — [seen, per the report: publish.sh steps].
- `meta.json` `holds` — rejected as one repo's policy, since jig's hold is `defer_until` — [seen].

## Decisions
- Interpreted, open to the owner at review: the flag names and their aliases; `--patch` as the
  default in every kind; `--milestone` refusing before 1.0.0; the header swap through `jig update`
  with the narrow R3 allowance; the selector's "broke", not "changed"; a pin-bump that doesn't
  block the pararepo's release; and the kind name `pin-bump`, one file per metarepo.

## Roles
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
