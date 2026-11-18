# Bug: a metarepo's AGENTS.md has no jig block for its rules, so update lists the repo's own line forever

Source: Maige-Eco hubnode session / 2026-11-17 / Dave Seeman (staged as feedback-maige-ecosystem-2026-11-17-metarepo-agents-line.md): "A metarepo's AGENTS.md has no jig line for its rules, so `jig update` flags the repo's own line for good": `AGENTS.md:31: runs a step in the repo's own words; what owns it now: /jig:hubnode (jig release). Kept as it is: the owner rewords or removes it`

The report's jig_version, f0005adc5fe4, is the blob hash of v0.14.0's `jig.py`. This worktree's
`plugin/templates/jig/jig.py` and Maige-Eco's `.jig/jig.py` are the same blob, so the bug is in
the current code.

## 1. Why
- Why does every `jig update` list AGENTS.md:31? `procedure_lines` lists any line outside a generated block that names `jig release`, and a "keep" has no id to record.
- Why are a metarepo's rules in the repo's own words? jig writes no metarepo line. The template is every repo's, and `jig init --meta` prints the rules only on the console.
- Why does the repo want them always loaded? An agent meets M4, M6 and M3 on every commit, and RULES.md isn't always loaded. A pararepo gets its rules as a block; a metarepo, none.

Root: jig puts a pararepo's rules in AGENTS.md as a generated block, which it keeps current and
exempts from the listing. It gives a metarepo nothing, so the metarepo writes jig's rules by
hand, and update lists that line as the repo's procedure.

## 2. Givens
The reporter's givens are inputs. A line is `[seen]` only if it was reproduced or read here.
Scratch repos were built from this worktree's templates. Maige-Eco was only read, through
`git archive` of its HEAD (f8c8064) into a scratch folder.
- [seen] **The reported line, reproduced.** On the Maige-Eco copy, the plugin's
  `jig update` dry run prints the report's line word for word. Nothing else is under Repo files
  to review.
- [seen] **Reproduced in a fresh metarepo too.** Setup: `jig init`, then
  `jig init --meta --prefix E-` on the AGENTS.md template, then the report's line added by a
  reviewed merge. Two dry runs in a row list it unchanged.
- [seen] **`jig init --meta` leaves AGENTS.md alone.** After it runs, AGENTS.md is unmodified.
  It ends "Commit these on main. From then on main takes only reviewed merges, and only
  `jig release` tags."
- [seen] **The template has no metarepo line.** `plugin/templates/AGENTS.md` carries jig's rules
  for every repo (the handoff line, the decision-log line, the Rulebook line). Nothing in it
  belongs to one kind of repo.
- [seen] **What `procedure_lines` skips.** It skips three kinds of line: template lines,
  `RETIRED` lines, and lines between `<!-- jig:meta — ` and `<!-- jig:meta end -->`
  (`outside_header`). The markers alone are enough. The same line wrapped in them in the scratch
  metarepo is not listed, and nothing checks that jig wrote the block.
- [seen] **Why the line says hubnode.** `STEP_COMMAND` matches `jig release`, and
  `COMMAND_STEP` maps it to the release step, which the hubnode owns.
- [seen] **A keep can't be recorded.** I committed `findings: {"procedure:AGENTS.md":
  "exception: …"}` to the scratch board. Survey then says "no finding has the kind procedure:
  survey gives ids only to rules, copy, reserved, page, deep, shape, contract, section, shared,
  unmapped", and the dry run still lists the line. Yet `plugin/skills/update/SKILL.md` tells
  the owner they "rewords, keeps or retires it".
- [seen] **The pararepo sibling.** `jig init --para` writes `para_header` through
  `with_header`. P1 refuses a header that differs from what `para.json` generates, and
  `jig sync` says when it is out of date. Smoke `update_roles` checks that update reads no line
  inside it. `para_header` carries `para.json`'s data, the pin and contract paths, so P1 keeps
  that data true.
- [seen] **The block can't be written on a metarepo's trunk.** M4 refuses an AGENTS.md commit
  there ("jig: M4 main takes only merges of reviewed branches: commit on a branch"), so the block
  for an existing metarepo is a job's. Before `meta.json` is on trunk the gates are off: the
  scratch repo's first commit after `init --meta` put `docs/glossary.md` on main.
- [seen] **A job's worktree can run init again.** Rerunning `jig init --meta` in a job's
  worktree of the scratch metarepo leaves that worktree clean and reinstalls the hooks. It still
  prints "Commit these on main".
- [seen] **Update can't be the block's writer.** `jig update` refuses its layout work while
  jobs are open (`jig.py`, "jobs are open: …"). So in the run that brings a new jig, update
  can't write the block in a job.
- [seen] **The hand-copied line kept chasing jig.** Maige-Eco's line was rewritten by hand four
  times as jig changed:
  - c282ba4: `jig meta-release` became `jig release` (layout 8);
  - dbaffda: the entry-file wording (layout 9);
  - c1ebd92: `CHANGELOG.md` became `.jig/decisions.md`;
  - 05342a9: the entry files after the docs move.

  b546ce2 also changed its example id.
- [seen] **The 40-line cap counts the block.** Survey counts lines inside a generated block
  toward AGENTS.md's cap; it skips only headings, `<!--`/`-->` lines and table rows. Maige-Eco's
  AGENTS.md has 25 rule lines.
- [seen] **The other metarepo here hasn't started.** `repos.json` lists a second metarepo,
  Guild-Rulebook. It has no commits and no `meta.json` yet, and its AGENTS.md is the template,
  with no metarepo line.
- [assumed] **Other metarepos would write the same line.** Only Maige-Eco has run
  `init --meta` here. The fix doesn't depend on this: the console-only rules and the pararepo's
  block are seen.

## 3. One layer up
- **Sibling: the pararepo.** It has the same need, its rules always loaded, and doesn't have
  this problem. jig writes the header, P1 and `jig sync` keep it current, and `outside_header`
  exempts it, "so its words are no repo's procedure".
- **What's structurally different.** `init --meta` has no counterpart to
  `para_header`/`with_header`, and nothing proposes or refreshes a metarepo block.
- **Existing pattern.** The generated block can be used as it is:
  - `with_header` replaces any begin line starting `<!-- jig:meta — `;
  - `outside_header` exempts any such block.

  A metarepo block under those markers needs no change to either. The original design says the
  same: "jig rewrites only what jig wrote", and "A pararepo's generated header is skipped"
  (`.jig/specs/update-adopts-standard.md`).
- **Another listing that repeats.** A survey finding without an id is printed again on every
  run: `FINDING_KINDS` gives ids to none of these lines. Examples:
  - procedure lines;
  - root-document lines;
  - the `.jig/` path lines bug-process-in-pages adds (its Decision 2 accepts that cost).

  A recorded keep would serve all of them. It is a different root from this one (Out of scope,
  Decisions 2).
- **How this fits bug-process-in-pages.** It fits and doesn't overlap. That spec's Homes test
  (approved 2026-11-17) puts "jig's own rules" nowhere a repo writes: `.jig/RULES.md` holds
  them. This fix makes that true for a metarepo. The subset every task needs arrives as jig's
  own lines, as the template's do for every repo and the header does for a pararepo, so a
  metarepo writes none.
  - **Shared files.** Both touch `RULES.md` (Metarepo here, Documentation and Homes there),
    `jig.py` (`cmd_meta_init` and update's AGENTS.md listing here, the page listings there) and
    `smoke.sh` (`metarepo` and `update_roles` here). No function or section is shared.
  - **One wording to coordinate.** That table's row could say jig's own lines in AGENTS.md (the
    template's, a generated block) carry what every task needs. Then no reader takes "nowhere"
    to mean jig's lines in AGENTS.md go.
  - **The closing consolidate.** `jig consolidate` will likely group the two specs by Touches.
    They are kept separate: different roots, different functions.

## General?
Picture any metarepo run the way RULES.md describes it. M1, M3, M4 and M6 refuse on every
commit, and `init --meta` states the rules only on the console. Writing them into AGENTS.md is
the ordinary next step, so update then lists that line on every run if it names a step. Either
way it drifts from jig's wording, as Maige-Eco's did four times. This asks for nothing beyond
RULES.md: the block states jig's own rules, as the template and the pararepo header do. It is
worth keeping.

## 4. Correction
A correction: a metarepo gets the generated block a pararepo gets. Its rules are then jig's
words in AGENTS.md, written by `jig init --meta`, listed by `jig update` when they are missing
or out of date, and exempt from the procedure listing. A recorded keep would only hide the
listing. The rules would stay in the repo's words and keep drifting.

## Intent
A metarepo's AGENTS.md carries jig's own block stating the metarepo rules. `jig init --meta`
writes it, and `jig update` lists it when it is missing or out of date, as a job's (M4). No
metarepo writes jig's rules by hand, and no line of the block is listed as the repo's procedure.

## Done when
- [ ] **The block, at setup.** Smoke `metarepo`: a repo with the AGENTS.md template runs
  `jig init --meta --prefix E-`. AGENTS.md then has one block under its title, at most 5 lines
  between `<!-- jig:meta — … -->` and `<!-- jig:meta end -->`, stating:
  - docs only, and a claim another repo owns is pointed to, never copied (M1, rule 2);
  - trunk takes only reviewed merges, so work on a branch (M4);
  - a commit subject starts with the ids it touches, its example using `meta.json`'s
    `decision_prefix` (`E-…`) (M6);
  - an entry-file change adds a change line under `## Unreleased` in `.jig/decisions.md` (M3);
  - only `jig release` tags (rule 3);
  - and it names `.jig/RULES.md` (Metarepo and pararepos).

  The console names AGENTS.md among the files to commit. The wording is the implementer's; the
  content is the owner's (Decisions 1).
- [ ] **The fix fires.** Smoke `update_roles`: in a metarepo whose AGENTS.md holds that block,
  the plugin's `jig update` dry run lists no "runs a step in the repo's own words" line for any
  line inside it, `jig release` included.
- [ ] **Update lists a missing or stale block.** Smoke `update_roles`: in a metarepo whose
  AGENTS.md has no block, or a block other than the one this jig writes (an older wording), the
  dry run lists `AGENTS.md` under Repo files to review. The line says the block is jig's and is
  written by `jig init --meta` in a job's worktree (M4). It also says the job runs once this
  update's `.jig/jig.py` is on trunk, and that the repo's lines the block restates are the
  owner's to remove. `--apply` on trunk leaves AGENTS.md byte-identical. A plain repo and a
  pararepo get no such line.
- [ ] **Refresh happens in a job.** Smoke `metarepo`: with `meta.json` on trunk, `jig init
  --meta` on trunk leaves AGENTS.md unmodified (`git status`) and says to run it in a job's
  worktree (M4). Run in a job's worktree, it writes the block there and says to commit it on the
  job's branch. After that job merges, the dry run lists no block line.
- [ ] **Only metarepos get it.** Smoke `metarepo`: a plain `jig init` and a `jig init --para`
  write no metarepo block.
- [ ] **The reported symptom is gone.** Smoke `update_roles`: the fixture is a metarepo
  (prefix `E-`) whose AGENTS.md is the template plus the report's line 31.
  - With the block written and line 31 removed, Repo files to review names no AGENTS.md line.
  - With line 31 still beside the block, it is the only AGENTS.md line listed. The owner removes
    it; jig.py judges no prose.
  - By hand, on a `git archive` copy of Maige-Eco's HEAD: once the block replaces line 31, the
    dry run lists no AGENTS.md line. v0.14.0 lists `AGENTS.md:31`, as the givens show.
- [ ] **The docs say so.** `grep -n "init --meta" plugin/templates/jig/RULES.md` finds the
  Metarepo sentence naming the block beside the pararepo header. `grep -n "AGENTS.md"
  plugin/skills/init/SKILL.md` finds the metarepo paragraph naming it.
- [ ] **The whole check.** `bash tests/smoke.sh` passes, `claude plugin validate ./plugin`
  passes, and `grep -rnE 'Maige|maige|E-058' plugin` finds nothing.

## Out of scope
- **A recorded keep for listings without an id.** That is procedure lines, root-document lines,
  and bug-process-in-pages' `.jig/` path lines. It is a separate root (One layer up), and the
  owner decides whether it gets its own bug (Decisions 2).
- **Listing line 31 as "restates the block".** jig.py judges no prose (RULES.md: survey and
  update "judge none of them"). The line is listed as it is today until the owner removes it,
  and update's block line says so.
- **A hook gate like P1 for the block.** Update's listing is the check (Alternatives).
- **A repo with both `meta.json` and `para.json`.** One generated block per AGENTS.md. RULES.md
  describes a metarepo as docs only and a pararepo as code, firmware or hardware.
- **The 40-line count.** Survey still counts the block's lines, as it counts a pararepo
  header's.
- **`outside_header` trusting any block with the markers.** A repo hiding its own line there
  would be working against jig.
- **Maige-Eco's AGENTS.md.** It gets the fix through `/jig:update`. The job that writes its
  block removes line 31.

## Touches
- `plugin/templates/jig/jig.py`:
  - a `meta_header` beside `para_header`, with the same markers and a begin line naming
    `jig init --meta`, built from `meta.json`'s `decision_prefix` and the board's trunk;
  - `cmd_meta_init`: write it through `with_header`. On an existing metarepo's trunk, write
    nothing to AGENTS.md and name the job instead. Its last line names AGENTS.md;
  - update's AGENTS.md listing (`agents_lines` or `files_to_review`): a missing or different
    block in a metarepo, as a job's;
  - `outside_header`'s docstring: a pararepo's or a metarepo's block.
- `plugin/templates/jig/RULES.md`: Metarepo and pararepos, the paragraph at "Each side's gates
  are on only when its file is on trunk": `jig init --meta` writes AGENTS.md's metarepo block,
  as `jig init --para` writes the header, and `jig update` lists it, a job's (M4).
- `plugin/skills/init/SKILL.md`: the metarepo paragraph names the block.
- `tests/smoke.sh`: sections `metarepo` and `update_roles`.
- `.jig/decisions.md`: a line under `## Unreleased`. A metarepo's reader can act on it: update
  lists the block, and the hand-written line can go.
- `marketing/FEATURES.md` (in the main checkout): the `init --meta` row, written before the
  change.

## Alternatives considered
- **A metarepo line in `templates/AGENTS.md`.** Rejected because that template is every repo's,
  so plain repos and pararepos would get a metarepo rule. jig already scopes a repo kind's lines
  through a generated block — this reason is [seen] (the template; `para_header`,
  `outside_header`).
- **A recorded keep for the line, as this group's fix.** Rejected because the rules would stay
  in the repo's words, which chased jig's wording by hand four times — this reason is [seen]
  (c282ba4, dbaffda, c1ebd92, 05342a9). The approved Homes test also puts jig's own rules
  nowhere a repo writes — this reason is [seen] (bug-process-in-pages, Correction). The keep is
  kept as its own question.
- **Narrowing `STEP_COMMAND` so "Only `jig release` tags" isn't matched.** Rejected because a
  word rule can't tell a constraint from a procedure, and `STEP_SETTING`'s comment shows the
  guarding one needs — this reason is [seen]. It would also hide the drift, not end it — this
  reason is [seen] (the line drifted while naming the old command).
- **Drop the report: the repo deletes line 31, and RULES.md and the refusals teach the rules.**
  Rejected because a pararepo gets its rules always loaded and a metarepo would not, and
  `init --meta` itself states the rules only where no agent reads them again — this reason is
  [seen] (`para_header`; `init --meta`'s console line). That each refusal costs an agent a round
  trip is [assumed].
- **A workaround for one repo: Maige-Eco wraps its line in the `jig:meta` markers.** Rejected
  because it marks the repo's words as generated, so they would never be refreshed — this reason
  is [seen] (the markers alone exempt the line in the scratch repo).
- **`jig update --apply` writes the block (the report's own Done when).** Rejected because a
  metarepo's AGENTS.md changes only in a job (M4), and update refuses its layout work while a
  job is open. A rerun of `jig init --meta` runs cleanly in a job's worktree and matches how
  `jig init --para` regenerates a header — this reason is [seen] (M4's refusal; "jobs are open";
  the rerun in a scratch job).
- **A marker pair of its own (`jig:metarepo`).** Rejected for now because the shared markers
  already exempt the block and `with_header` already replaces by that prefix. Only a repo with
  both files would need two blocks, and RULES.md describes none — this reason is [seen].
- **A P1-like gate refusing a metarepo AGENTS.md whose block differs.** Rejected because P1
  guards `para.json`'s data in the header (the pin, the contract paths), while this block
  carries jig's wording and the id prefix only — this reason is [seen] (`para_header`). That
  update's listing is enough at R0 is [assumed].

## Decisions
Questions for the owner, the recommendation first.
1. **The block's content.** Recommended: these four lines, worded by the implementer:
   > - This is a metarepo (`.jig/RULES.md`, Metarepo and pararepos): docs only, no code (M1);
   >   a claim another repo owns is pointed to (`<repo>/<path> § <section>`), never copied.
   > - `main` takes only reviewed merges, so work on a branch (M4). A commit subject starts
   >   with the ids it touches (`E-012: …`, `GLOSSARY: …`) (M6).
   > - A change to an entry file (`.jig/meta.json`'s `entry_files`) adds a change line under
   >   `## Unreleased` in `.jig/decisions.md` (M3).
   > - Only `jig release` tags.

   It names `entry_files` and lists none of them. A list would make every `entry_files` edit
   leave the block stale.
2. **A recorded keep for listings without an id.** Recommended: its own bug, not this spec.
   - **What it fixes.** The update skill offers "keeps", but jig.py can't record one. The same
     re-listing applies to root-document lines and to bug-process-in-pages' `.jig/` path lines.
   - **What it wouldn't fix.** A line that restates jig's rules, as here: keeping it keeps the
     drift.
- The owner, 2026-11-17, M2: "use the four lines in the spec" (Decisions 1, naming `entry_files` rather than listing files). M3: a recorded "keep" for listed lines with no finding id is "its own bug, after these".
- Kept separate from bug-process-in-pages: a generated metarepo block vs page and process homes; process-in-pages builds after it. The owner, 2026-11-17: "K1: no merges among the four; the six jobs as proposed".

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
