# decision-log

Source: cowork session 2026-11-10 (Dave + Claude) (staged as one-decision-log-in-every-repo.md): "Pararepos have no decision log, while metarepos have both decisions and a changelog. I want one standard in every jig repo instead of several in some places and none in others. Both records track changes, and the decision log goes one step further by recording why. One format is good enough for both."

## Intent
Every jig repo, whether plain, meta or para, keeps one log at `.jig/decisions.md`. It holds decision entries and Keep a Changelog change lines, grouped by release, and it replaces a metarepo's `CHANGELOG.md` and decisions register.

## Design
- **The file.** `.jig/decisions.md`, in every repo `jig init` and `jig update` set up. It has a
  two-line preamble: it follows Keep a Changelog plus decision entries, it uses SemVer, and what
  "breaking" means here. Then three kinds of section, top to bottom:
  - `## Open`: open or proposed decision entries. Their status changes in place.
  - `## Unreleased`: accepted entries and change lines since the last release.
  - `## vX.Y.Z - YYYY-MM-DD`: one per release, newest first.
- **A decision entry.** A heading `### D-012 Store opens graph.sqlite read-only` carries the id
  and title, never a status. The next line is the status: `Accepted (Dave, 2026-11-10).`, or
  `Open (2026-11-10).` / `Proposed (…)` under Open. It can add `Supersedes D-007.` Then the body:
  what was decided, why, and what it is not. Only decision entries say who decided.
- **Change lines.** After the entries, a release or Unreleased has Keep a Changelog's groups:
  `### Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`. They come in that order,
  and an empty group is left out. A line is one change, with an area prefix where it has one
  (`GLOSSARY: Add "vault", …`). A change that is a decision is recorded once, as its entry. The
  one allowed duplicate is a `**Breaking:** … (D-007).` pointer in its type group.
- **What belongs.** A choice that outlives its spec, and any change a reader of the release can
  act on. A spec's own Decisions stay with the task, and history stays in git. RULES.md says
  this, and adds the writing rules from the request's appendix, with the changes listed under
  Decisions.
- **Release.** `jig release`, in every kind of repo, renames `## Unreleased` to
  `## vX.Y.Z - YYYY-MM-DD` and adds an empty `## Unreleased` above it. A repo that never
  releases just grows Unreleased, with no nag. A yanked release keeps its section, with
  ` [YANKED]` on the heading and one line saying why and what to pin.
- **Checks.**
  - **M2** (every repo): each entry's status line and date. Supersedes links must resolve. A
    release section holds accepted entries only.
  - **New: released sections are frozen.** A commit that changes a line under a
    `## vX.Y.Z` heading is refused, except adding ` [YANKED]` and its line. A superseded
    entry is read from the chain (`jig decision D-007` prints it, with what superseded it),
    never edited.
  - **M3** (metarepo): an entry-file change needs a line or entry under Unreleased in
    `.jig/decisions.md`.
  - The tag check reads the release heading from `.jig/decisions.md` at the tag. For older
    tags it reads `CHANGELOG.md`, so they still validate.
- **Ids.** An entry is written `D-?<slug>` (`D-?store-ro`) on a branch, so a job never asks the
  hubnode for a number. `jig merge` numbers each `D-?<slug>` in the merged files, in the merge
  commit (as it rewrites `ROADMAP.md`), from the repo's prefix (`decision_prefix`, default `D-`).
  M6 accepts a `D-?<slug>` subject.
- **Every job may append.** R3 lets any job change `.jig/decisions.md`, and it is an append file
  for merges. M4 does not exempt it on a metarepo's trunk, though it does other `.jig/` files,
  because a decision is reviewed work.
- **Across repos.** In a metarepo, `.jig/decisions.md` is the one file under `.jig/` that
  `entry_files` counts and pararepos cache and cite (`<meta>/.jig/decisions.md § D-012`). A
  pararepo entry that touches a contract cites its BUFFER row or proposal. Once the metarepo
  accepts it, a new entry supersedes it and points to the metarepo id, without restating it.
  Fold-in by id (spec `bug-meta-decision-foldin`) reads this file in every repo.
- **Migration.** `jig update`, on a yes, merges a root `CHANGELOG.md` and the decisions register
  into `.jig/decisions.md`:
  - release sections are kept as they are, re-headed to the hyphen form;
  - open and proposed rows go to `## Open`, and accepted rows to their release, or to
    Unreleased when that can't be told;
  - the old files are removed;
  - in a metarepo, `entry_files` is rewritten.

  Pararepo citations of the old paths are named by `bug-sync-moved-pages` at the next pin bump.

## Done when
- [ ] Smoke `decisions`, in a plain repo: `jig init` writes `.jig/decisions.md` with the
  preamble, `## Open` and `## Unreleased`. `jig release --minor` renames Unreleased to
  `## v0.1.0 - <date>` and adds a new one.
- [ ] Smoke: M2 refuses an entry with a status in its heading, an entry with no status line, a
  supersedes link to no id, and an open entry under a release heading.
- [ ] Smoke: a commit editing a line under `## v0.1.0` is refused, and adding ` [YANKED]` with
  its line is not. `jig decision D-001` names the entry that supersedes it.
- [ ] Smoke: a job opened with no `--shares` commits an entry `D-?store-ro`. `jig merge`
  numbers it `D-003` in the log and in a page citing it, in the merge commit.
- [ ] Smoke `metarepo`: M3 asks for a line in `.jig/decisions.md`. A pararepo's `jig sync`
  caches it and reads a term or decision change from it. A tag made before the change, with
  only `CHANGELOG.md`, still validates.
- [ ] Smoke: `jig update` lists `CHANGELOG.md` and `DECISIONS.md` for merging, changes nothing
  without a yes, and with `--apply` on a yes writes the merged log and removes both.
- [ ] RULES.md has a Decision log section with the file, entries, groups, what belongs, the
  writing rules and the checks. M2, M3, M4 and M6 are updated. `grep -rn 'CHANGELOG.md'
  plugin` names only migration and old-tag code.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- This repo's own `dist/notes-X.Y.Z.md` release notes and GitHub release text. This repo adopts
  the log by `/jig:update` like any other, and its release step can then quote the version's
  section. That is the owner's change to AGENTS.md.
- Generating anything from the log: it is written by hand, as the request says.
- Converting a repo's history: migration keeps the old entries' words as they are.

## Touches
- `plugin/templates/jig/jig.py`: init, release, M2, M3, M4, M6, R3, the tag check, sync's cache
  and entry paths, merge numbering, a new `jig decision`, and update's migration
- `plugin/templates/jig/RULES.md`: a Decision log section, plus Metarepo and pararepos, Release,
  Commands and Board
- `plugin/skills/hubnode/SKILL.md`, `plugin/skills/subnode/SKILL.md`,
  `plugin/skills/release/SKILL.md`, `plugin/skills/update/SKILL.md`,
  `plugin/skills/stage/SKILL.md` (a `decisions` kind lands in the log)
- `plugin/templates/AGENTS.md` (one Workflow line)
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only)

## Alternatives considered
- Status changed in place on every entry — rejected because it rewrites released sections and
  breaks "merges just append". Open entries change in place under `## Open`, which is never
  released as a section of its own; a released entry is superseded by a new one — reason is
  [seen: the request's point 1]
- Accepted entries only, with open questions kept elsewhere — rejected because RULES.md has an
  open question get its row "when it is asked … so it can be cited before it is answered".
  `## Open` keeps that, and is in every tag's copy of the file — reason is [seen: RULES.md,
  Metarepo and pararepos]
- Ids reserved from the board up front — rejected because a decision found partway through a
  job would wait on the hubnode. Merge-time numbering needs no round trip, and `jig merge`
  already writes into the merge commit — reason is [seen: the request's point 3; `jig merge`
  rewriting ROADMAP.md]
- A root `DECISIONS.md` or `CHANGELOG.md` — rejected by the owner: "It's a jig artifact, not a
  standard file like a changelog" — reason is [seen: the request]
- Two-part `vMAJOR.MINOR` versions — rejected because `jig release` makes three parts, and
  two-part pins already sort below them — reason is [seen: RULES.md, Release]

## Decisions
- The request's points, settled:
  - **1. Append-only.** Released sections are frozen, and supersession is a new entry. Status
    changes in place only under `## Open`.
  - **2.** Release sections hold accepted entries only. Open and proposed entries live under
    `## Open`. A rejected entry is removed, and git and the spec's Alternatives keep it.
  - **3.** `D-?<slug>` on branches, numbered by `jig merge`.
  - **4.** `vX.Y.Z`.
  - **5.** A repo that never releases is fine, with no nag.
  - **6.** `**Breaking:**` pointers are allowed.
  - **7.** Plain hyphen in release headings, with the `v` kept.
  - **8.** The two-line preamble.
  - **9.** Who decided is on decision entries only.
- Interpreted: an `## Open` section above Unreleased. The request had no home for open
  questions, and RULES.md needs them citable.
- Interpreted: `.jig/decisions.md` is the one `.jig/` file pararepos cite and cache, and the
  one M4 doesn't exempt. Both follow from putting a cited, reviewed record under `.jig/`.
- Interpreted: placeholder ids are `D-?<slug>`, so two in one branch stay distinct and pages can
  cite them before merge.
- Interpreted: the appendix's writing rules go into RULES.md's Decision log section with three
  changes:
  - the release heading uses a plain hyphen (point 7);
  - the reader is "anyone deciding whether to take this release", not only a repo bumping its
    jig pin, since the log is in every repo;
  - the opening line "You are writing release notes …" becomes a rule for anyone writing the
    log, not a prompt.
- Interpreted: `jig decision <id>` is a new read-only command to show the supersedes chain,
  which the request names.
- Supersedes the scope of `bug-meta-changelog-r3`: that spec's quick fix (R3 passes
  `CHANGELOG.md` in a metarepo) can land first. This one moves the permission to
  `.jig/decisions.md` in every repo.
- Runs after `bug-meta-decision-foldin` and `bug-sync-moved-pages`, and likely hands off in two
  chunks (`--partial`): first the log, release and checks, then the migration.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
