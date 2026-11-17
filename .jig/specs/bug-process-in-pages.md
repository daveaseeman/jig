# Bug: pages fill up with how the repository is worked, and jig never says so

Source: Daisy hubnode session / 2026-11-16 / the owner (staged as feedback-Daisy-2026-11-16-process-in-pages.md): "docs/ is meant to describe daisy's own code not how to use a tool that defines itself how it is used … Jig has a place for release process, we dont need that in docs because it doesnt describe the app", and "WHY IS JIG MENTIONED IN DAISYS DOCS".

The report's jig_version, f0005adc5fe4, is the blob hash of `jig.py` in v0.14.0. It matches this
worktree's `plugin/templates/jig/jig.py` and Daisy's `.jig/jig.py`, and `RULES.md` and
`docs-page.md` are identical too. The bug is in the current code.

## 1. Why
- Why do pages hold jig, `.jig/`, a reading order, commands, code style, CI and release steps, and "held by review"?
  The steps that write pages put them there, and no step says they don't belong there.
- Why doesn't any step say so? RULES.md names one thing a page never holds, the project. The repo's process has homes
  (AGENTS.md, skills, release.sh), but no rule says it is never a page's.
- Why does that reach pages? Each step that writes a page follows the gap. Redocument keeps any true claim, the template offers
  review as a holder, and the cap says "move the rest" without saying where.

Root: jig's rules name the plan as the only text a page never holds. They never name how the
repository is worked: its reading order, commands, code style, review, jig's own machinery, and
build, CI and release steps. So every step that writes or checks a page lets that text land in
`docs/`.

## 2. Givens
The reporter's givens are inputs. Each line below was reproduced here unless it is tagged
`[assumed]`. The throwaway repo `r1` is a fresh `jig init` from this worktree's templates. The
Daisy copy is `git archive` of Daisy's HEAD in a scratch folder, and Daisy itself was only read.

**The rule (issue 1)**
- [seen] RULES.md, Documentation, says "A page describes what is built … It is not a rulebook".
  "Product and project" names only the plan (priorities, phases, ordering, queues, build
  status). Homes gives "rules in `AGENTS.md` … know-how in the agent's skills". No line says
  that the repo's process (its commands, style, reading order, review, jig, the release steps)
  is never a page's.
- [seen] In r1, these three page lines commit and neither `jig survey` nor the `jig update` dry run lists them:
  - "jig's `docmap` in `.jig/config.json` says which page owns a file."
  - "Run `make test` before every handoff; review holds the style."
  - "The release is `scripts/release.py`, then CI publishes."

  A line naming `.jig/specs/` is refused by the hook.
- [seen] On the Daisy copy, v0.14.0's survey lists some of the reported lines and not others:
  - Listed: `docs/core.md:20` and `:156` (they name `AGENTS.md`, a root document) and `:27` (`.jig/specs/`).
  - Not listed: `:23` and `:215` (jig's `docmap` in `.jig/config.json`), `:162` (a layout tree with `.jig/`), `:217`, `:218` (`.jig/RULES.md`), `docs/app/releases.md:128` (`.jig/scripts/derive.sh`), `:169` ("jig's merge"), and the `## 11. Code style and testing` and `## 12. Commands` sections.

  So the report's "survey listed none" holds except for lines 20, 27 and 156.
- [seen] Redocument kept the process text. Daisy's remap (`a94f1dfc^:.jig/redocument.md`) row 4
  rewrote `releases.md` with its path kept. Commit 9de64bd8 wrote that page "from the code on
  main: the Makefile, build.py, … CI, the release workflow". The redocument Work role gives
  every old claim one of five fates: still true → body, admission → Invariants, plan → Up next,
  question → Open, stale → deleted. None of them is for a rule about working the repo.
- [seen] Review question 9 (`plugin/skills/review/SKILL.md`) and the spec skill's step 5 ask
  "about the product, or about when and in what order we build it?". Neither asks about the
  repo's process.
- [seen] The update skill and `home_fix` (`jig.py`, the survey and update text for a rules file
  off root) say "fold what still binds into AGENTS.md or a page's Invariants". So a process rule
  is sent to a page too.
- [seen] jig's board template, `plugin/templates/hardware.md`, has these, and `/jig:hardware` copies them onto a page under `docs/`:
  - a comment, "jig's board template, on the page contract (.jig/RULES.md, Documentation)";
  - a `## Toolchain` section and a `## Flash / rollback` section;
  - a `## Skills` section.
- [seen] RULES.md lets a page cite an `## Open` entry in `.jig/decisions.md`.
- [seen] The jig repo has no `docs/`, its `docmap` is `{}` and its `not_docs` is `plugin/**`. Its product's docs are `RULES.md` and the skills, not pages.
- [seen] A builder's reading order already has homes: `jig reading-list <files>` (RULES.md, Documentation) and AGENTS.md.
- [seen] There is also a separate problem. The root-document hook refuses a product line in r1: "The app reads the
  `AGENTS.md` in a folder the user attached, as the user's own file." A page can't name a
  user's `AGENTS.md` today (see Out of scope).

**The docmap (issue 2)**
- [seen] In r1, a handoff that changes `scripts/release.py`, `tools/gen.py`, `Makefile`,
  `.github/workflows/ci.yml` and `src/app.py` writes UNOWNED lines only for the two `.py` files.
  `foldin_lines` skips dot paths and files that aren't source. Its line reads "add to docmap (a
  new page starts from .jig/docs-page.md), or no page needed because ___".
- [seen] Survey lists no uncovered file. It prints only a count of source files, and that count
  leaves out `scripts/`, `tests/`, `build/`, `dist/`, `vendor/` and dot paths. In r1 it printed
  "(1 source files)". The report's "survey counts uncovered files" is not so.
- [seen] Daisy's docmap already mapped `releases.md` to `daisy/Makefile`, `.github/**` and the
  scripts on 2026-11-10 (`f66e30b4`), before the redocument run. Adopt carries a repo's own
  "file → documentation map, if it has one" into `docmap` (adopt, step 6's map table). jig
  never asked for those files.

**The holder (issue 3)**
- [seen] `docs-page.md:28`, `RULES.md:254` and `hardware.md:57` each offer "a named test, review, or on screen" as what holds an invariant.
- [seen] The review role reads the diff, the spec and `AGENTS.md`. No step reads a page's
  Invariants. So "held by review" names a holder that jig's workflow doesn't provide.
- [seen] In r1, the entry "- Sums never overflow — …; held by review." raises no survey problem. An entry with no holder is flagged.
- [seen] About 26 lines in Daisy's pages (outside `docs/decisions/`) name review as the holder.
  `tests/smoke.sh` uses "held by review" as a passing entry at lines 2318, 3708, 3726, 3925, 3969 and 4582.

**The cap (issue 4)**
- [seen] Daisy's commit 8fb1fcdf (2026-10-26) removed 1,669 lines from AGENTS.md and added 174
  to `docs/core.md`. It came before jig's first commit, eaec973 (2026-10-27), and ran under
  ai-dev.
- [seen] Adopt §3, at eaec973 and now, says commands, style rules, workflow and gotchas stay in
  AGENTS.md. The rest goes to `docs/` (if it's state), a skill (know-how) or git (history). So
  Daisy's diet went against adopt's own line.
- [seen] These name no destination for text cut from AGENTS.md:
  - the AGENTS.md template comment ("would removing it cause a mistake? If not, cut it.");
  - init ("If it's longer after filling, cut.");
  - survey ("cut to 40 lines, move the rest").

  In r1, `jig update` says nothing about an AGENTS.md of 61 rule lines.
- [assumed] An agent told to "move the rest" with no destination picks `docs/`, because it is
  the nearest place for text. This can't be reproduced: Daisy's only case ran against adopt's
  text. It is the risk the wording fix covers, and the fix doesn't depend on it.

## 3. One layer up
- **The pattern already exists: the project boundary.** It has a rule naming the kind of text,
  a hook for exact paths, survey and update listing old text, a question in spec and review, a
  redocument fate and an update sweep. The repo's process uses the same pattern without the
  hook. Unlike `.jig/specs/`, a `.jig/` path and the release can be product text: in a repo
  whose product is jig, or reads jig's files.
- **Sibling paths route process into pages.** These are:
  - redocument's fates;
  - update's and `home_fix`'s fold of a rules file "into AGENTS.md or a page's Invariants";
  - adopt carrying a repo's own file map into `docmap`;
  - the board template.
- **Fold-in and survey differ.** Survey's source count leaves out `scripts/` and `tests/`, but
  fold-in's UNOWNED line asks about them. The question stays, because a product's `scripts/` can
  be its shipped CLI. Only the excuse wording changes, to name tooling.

## 4. Correction
Correction for issues 1, 3 and 4, plus the part of issue 2 that applies to any repo. The
`tooling` key in issue 2 is dropped as too specific (see Alternatives). Each item below changes
jig's own rules or templates, so the spec writes it down once:
- **Product and process** (issue 1, and issue 2's general part). Make these changes:
  - **RULES.md.** Documentation names the repo's process as text a page never holds, and gives
    each part its home. It keeps product behaviour as the product's, and a board page's
    Toolchain and Flash / rollback as the board's (Decisions 1, 3). Homes says the same in its
    one-home sentence.
  - **Survey and update** list a page line naming a path under `.jig/` other than
    `.jig/decisions.md`, outside fenced code and HTML comments. The hook refuses nothing new
    (Decision 2).
  - **The skills that write or judge a page**:
    - redocument gains a process fate and a Flagged line, and its Docmap list leaves tooling out;
    - spec and review question 9 ask "or about how the repository is worked?";
    - adopt's docmap row leaves tooling out;
    - update and `home_fix` send a rule for working the repo to AGENTS.md or a skill, and only a
      fact the product must keep to a page's Invariants.
  - **Fold-in.** The UNOWNED line's excuse names the repo's own tooling as needing no page.
- **Holders** (issue 3). "Review" leaves the holders in RULES.md, `docs-page.md` and
  `hardware.md`. A holder is still required, and an entry nothing holds goes in the body.
  Survey and update list an entry whose holder is review as off the page contract (Decision 4).
- **Where cut lines go** (issue 4). The AGENTS.md template comment, survey's "Too long" line,
  init and adopt §3 say where a cut line goes:
  - a rule or know-how to a skill;
  - a release step to `.jig/scripts/release.sh`;
  - a fact about the product to its system's page;
  - history to git.

  None of them sends how the repo is worked to a page (Decision 5).

## Intent
A page describes the product, never how the repository is worked. jig's rules say so, and the
steps that write pages ask it. Survey and update list the precise traces already on pages: a
`.jig/` path, or an invariant held by review. A product that runs tests, ships releases, reads
`AGENTS.md` or is jig can still describe what it does.

## Done when
- [ ] RULES.md, Documentation, has the Product and process paragraph with its homes and both
  carve-outs: product behaviour, and a board page's Toolchain and Flash / rollback. Homes' one-home
  sentence names how the repo is worked as AGENTS.md's, a skill's or `release.sh`'s, never
  `docs/`. `grep -n "Product and process" plugin/templates/jig/RULES.md` finds the paragraph.
- [ ] Smoke (`boundary` or `page_contract`), showing the fix fires. A page line "jig's `docmap` in
  `.jig/config.json` says which page owns a file." commits, and then:
  - `jig survey` lists it under a heading that names the repo's process and its homes;
  - the `jig update` dry run lists it under Repo files to review.

  On the same page, these are not listed under that heading:
  - a line citing `.jig/decisions.md § Open`;
  - `.jig/RULES.md` inside an HTML comment or fenced code;
  - a `.jig/specs/` line, which stays under the project heading only.
- [ ] Smoke (`hardware`). A board page copied from `plugin/templates/hardware.md` has no line
  under the process heading.
- [ ] Smoke. These page lines commit, and survey lists none of them under the process heading:
  - "The app runs the user's pytest suite and shows its results."
  - "The service builds each pushed branch and reports the result."
- [ ] Smoke (`page_contract`). For an Invariants entry "- X — Y; held by review.", survey's
  `page_contract` names review as no holder, and update lists it. "- X — Y; held by test_x." is
  not listed, and "- X — Y." is still listed as missing its holder. The fixtures at
  `tests/smoke.sh:2318, 3708, 3726, 3925, 3969, 4582` hold `test_*` holders instead.
- [ ] `grep -n "review" plugin/templates/jig/docs-page.md` finds no holder offer. RULES.md's
  Invariants item and `hardware.md`'s placeholders name a named test, or what is seen on screen (on a
  board: on the board).
- [ ] Smoke. In a handoff that changes an unmapped `scripts/release.py`, the UNOWNED line's
  excuse names the repository's own tooling (build, CI, release, dev scripts) as needing no
  page.
- [ ] Smoke (`agents_lines` or `homes`). On a 61-rule-line AGENTS.md, survey's "Too long" line
  names where a cut line goes (a skill, `.jig/scripts/release.sh`, a product fact's page, git)
  and says how the repo is worked never goes to a page. The AGENTS.md template comment, init's
  cap line and adopt §3 say the same: `grep` each one.
- [ ] The skill text is in place:
  - redocument's Work role has the process fate and a "Process:" Flagged line, and its Docmap list leaves tooling out;
  - review question 9 and spec step 5 ask about how the repository is worked;
  - adopt's docmap row leaves the repo's tooling out;
  - the update skill's rules-file fold and `home_fix` send a working rule to AGENTS.md or a skill.
- [ ] The reported symptom is gone. Make a scratch repo seeded with the report's kinds of
  lines: a reading order naming `.jig/config.json`, a layout tree with `.jig/`, two "held by
  review" invariants. Survey and update list every one of them. v0.14.0 lists none, as this
  spec's givens show. By hand, on a read-only `git archive` copy of Daisy's HEAD, survey lists
  `docs/core.md:23, :162, :215, :218` and `docs/app/releases.md:128`.
- [ ] `bash tests/smoke.sh` passes, `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy' plugin` finds nothing.

## Out of scope
- **Daisy's own pages.** Its `bug-docs-describe-tools.md` moves them. Daisy gets this fix
  through `/jig:update`, whose dry run then lists the `.jig/` lines and the invariants held by
  review.
- **A `tooling` board key (issue 2).** Too specific; see Alternatives.
- **Bare words in pages:** "jig", "docmap", "pytest", "Makefile", "CI". None is searched,
  because each can be the product's own word. The writer, spec and review judge them.
- **`jig update` proposing a home for each surplus AGENTS.md line.** jig.py doesn't judge prose.
- **The root-document hook refusing a product line that names a user's `AGENTS.md`.** This is
  seen in r1, and it goes against this group's "an app that reads a user's AGENTS.md". It is the
  root-document rule's own path match, a separate root. It is shown to the owner to file as its
  own bug. Until then a page can write `<folder>/AGENTS.md`.
- **Adopt step 1's sentence that survey gives "source files with no docs page".** Survey prints
  only a count. This is stale text with its own one-line fix, not this root.

## Touches
- `plugin/templates/jig/RULES.md`: Documentation (the Product and process paragraph; the Invariants item's holders; the sentences on what survey lists), Homes (the one-home sentence)
- `plugin/templates/jig/docs-page.md`: the section placeholder, the Invariants placeholder
- `plugin/templates/hardware.md`: the Invariants holder placeholders
- `plugin/templates/AGENTS.md`: the cap comment
- `plugin/templates/jig/jig.py`:
  - a process-path listing beside `project_prose`, in survey's report and print and in update's Repo files to review;
  - `page_problems` (holder is review);
  - survey's "Too long" line;
  - `foldin_lines`' UNOWNED wording;
  - `home_fix`'s rules-file text
- `plugin/skills/redocument/SKILL.md`, `review/SKILL.md`, `spec/SKILL.md`, `survey/SKILL.md`, `update/SKILL.md`, `init/SKILL.md`, `adopt/SKILL.md`
- `tests/smoke.sh`: sections `boundary` or `page_contract`, `hardware`, `agents_lines` or `homes`; the "held by review" fixtures
- `.jig/decisions.md`: a line under `## Unreleased` (a release's reader can act on it: survey and update list new findings)
- `marketing/FEATURES.md` (untracked, in the main checkout): the rows Project / product boundary, Invariants (page section) and Board page, written before the change

## Alternatives considered
- **A hook refusing the word "jig" in a page (the report, issue 1).** Rejected because
  `/jig:hardware` copies jig's own board template onto a page, and the template names "jig's
  board template" — this reason is [seen] (`plugin/templates/hardware.md:5`, hardware skill
  step 2). In firmware, "jig" is also the name of a test or programming fixture — this reason is
  [assumed].
- **A hook refusing any `.jig/` path (the report).** Rejected because RULES.md lets a page cite
  `.jig/decisions.md`, and `hardware.md`'s comment names `.jig/RULES.md` — this reason is [seen].
  A product that reads jig's files names them too — this reason is [assumed]. A listing leaves
  that call to the writer.
- **A hook refusing `docmap` (the report).** Rejected because it is one of many jig words, and
  a list of them only chases words. Daisy's two docmap lines also name `.jig/config.json`, which
  the path listing catches — this reason is [seen] (`docs/core.md:23, :215`).
- **A word list: pytest, Makefile, CI (the report's own alternative).** Rejected because those
  words are often the product's (an app that runs pytest, a CI service) — this reason is
  [assumed]. RULES.md also records that survey "searches no words that may be the product's" —
  this reason is [seen].
- **A `tooling` board key (issue 2).** Rejected as too specific. Fold-in already skips dot paths
  and files that aren't source, and it accepts "no page needed" for a script. Survey lists no
  uncovered file. Daisy's tooling globs came from its own file map before the redocument run —
  this reason is [seen] (the r1 handoff and survey; Daisy's `f66e30b4` docmap).
- **Fold-in leaving out `scripts/` and `tests/`, as survey's count does.** Rejected because a
  product's `scripts/` can be its shipped CLI. The question stays, and only its excuse names
  tooling — this reason is [assumed].
- **Making an invariant's holder optional (the report, issue 3).** Rejected because the holder
  is the admission test: "An entry without a why and a holder is description". Without it,
  every "must" sentence becomes an invariant — this reason is [seen] (RULES.md, Documentation).
- **Keeping review as a holder, and having the review role read the touched pages' Invariants.**
  Rejected because it writes more process into pages, which is what the owner objects to — this
  reason is [seen] (the report's quote).
- **`jig update` proposing a home for each surplus AGENTS.md line (issue 4).** Rejected because
  update "judges none of them" and jig.py reads no prose for meaning. Adopt §3 already sorts each
  line — this reason is [seen] (RULES.md, Documentation; adopt §3).
- **Fixing it in Daisy only (a workaround for one repo).** Rejected because the gaps are in
  jig's rules, templates and skills, and every repo gets them. The r1 reproduction is a fresh
  repo — this reason is [seen].

## Decisions
Each of these is a question for the owner, because it changes a rule or the page contract. The
recommendation comes first.
1. **Product and process (RULES.md, Documentation).** Add a paragraph after Product and project.
   Recommended: yes, worded as below. The implementer may edit the wording; the content needs
   the owner's yes.
   > A page describes the product, never how the repository is worked: the order a builder
   > reads in, the commands that build, test and check it, its code style, its review and
   > handoff, jig and its files under `.jig/`, and the steps of its build, CI and release. Each
   > has its own home: `AGENTS.md` for rules and commands, a skill for know-how, `jig
   > reading-list` for what to read, `.jig/scripts/release.sh` and `publish.sh` for the release,
   > and CI's own files for CI. What the product does with the same things is the product's: a
   > page describes an app that runs a user's tests, a CI service, an app that reads a user's
   > instruction files, or a tool whose product is jig. A board page's Toolchain and Flash /
   > rollback belong to the board. Whoever writes the line judges it, and the spec and review
   > ask.
2. **How jig catches it.** Recommended: (a).
   - (a) Survey and update list a page line naming a `.jig/` path other than `.jig/decisions.md`, outside fenced code and HTML comments. The hook refuses nothing new.
   - (b) As (a), and the hook also refuses an added line with such a path, as it refuses `.jig/specs/`. This matches the owner's Nov 13 "tooling that splits them as they're created".
   - (c) Nothing mechanical.

   The case for (a): a hook can't tell a page about this repo's process from a product that
   reads jig's files, or a repo whose product is jig. The cost: like the root-document listing,
   it re-prints a line it has already shown on every run. In practice that happens only where
   the product names `.jig/`.
3. **Board pages.** Recommended: Toolchain, Flash / rollback and Skills stay in
   `templates/hardware.md` as facts about the board (what builds for it, how an image reaches it,
   what to load before touching it), and the carve-out names them. The other option is to move
   flash and skills to the board's skill and AGENTS.md.
4. **Holders.** Recommended: (a).
   - (a) A holder is "a named test, or what is seen on screen" (on a board: on the board). Review is dropped, a holder is still required, an entry nothing holds goes in the body, and survey and update list a holder that is review.
   - (b) The report's version: review is dropped and the holder becomes optional.
   - (c) No change.
5. **Where cut lines go (the AGENTS.md cap).** Recommended: yes, the wording in step 4 goes into
   the template comment, survey's line, init and adopt §3. Update's per-line proposal is not
   built.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
