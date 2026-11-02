# A pararepo drifts from its metarepo on purpose, logs it, and settles it at release

Source: user story by the maige-ecosystem hubnode session, Nov 2
(`side-session-notes/local_25f7e824…/user-story-meta-drift-log.md`, a draft for the owner's
walkthrough). Owner, Nov 2: "I just want to be able to work on a para repo and change my mind a
few times while testing things before deciding to roll everything into a meta repo for release
once the dust has settled, but of course we can't let drift happen unaccounted for, we need a
backlog of sorts." No preference on where the log lives.

## Intent
A pararepo can change behavior its metarepo describes, as often as testing needs, and commit and
push each change. Every such difference is in a backlog in the pararepo the moment it's made. When
the pararepo releases, the differences that have settled go to the metarepo as one proposal. The
metarepo then updates every page the settled behavior contradicts, and an older Accepted mark
doesn't stop it.

## Why it slipped by (the gap, `[seen]` in the story and in `jig.py`)
- P2 asks for a `meta:` answer only on `contract_paths`. The pararepo's UI doc wasn't one, so
  four changes of mind reached no gate, and two metarepo pages went stale with nobody told.
- `contract_paths` means "a change here needs a proposal before it lands", which is right for a
  protocol and wrong for behavior that's still being tried out. There's no third answer between
  "propose now" and "none".
- `PROPOSAL` (`jig.py` ~1948) accepts only `meta: none — …` and `meta: <name> proposal <branch>`.

## The design, with a recommendation for each open question

**The backlog is a ledger:** `.jig/ledgers/META-DRIFT.md` in the pararepo (open question 3). It
works like `WORKAROUNDS.md`: tracked, append-friendly, and its first row creates it from the
plugin's template. One row per metarepo claim that's now stale:

| Id | Metarepo claim (file § section, at the pin) | This repo now (source, commit) | Decided (who, date) | State |

The state is `settling`, then `settled`, then `proposed <branch>`, then `closed <tag>`. A change
of mind edits its row, and nothing reaches the metarepo. `para.json`'s `defer_until` is
unrelated: it quiets `jig sync`'s report until a date, and stays as it is.

**What asks the question (open question 2, the gap):** `para.json` gains `described`: globs for
the docs and code whose behavior the metarepo describes. It's separate from `contract_paths`. A
new rule, **P5**: a change to a `described` path needs one of these:
- a row added to or changed in `META-DRIFT.md` in the same commit (like R7 with `WORKAROUNDS.md`)
- a spec in the change with `meta: logged <row id>`, `meta: none — <reason>` or a proposal

`contract_paths` keep P2 as now. A protocol change still needs a proposal before it lands,
because other pararepos break the moment it does.

To fill `described`, `jig sync` reports each pararepo path that a metarepo decision cites at the
pin (the way E-045 cites `ui.md`) and that `described` doesn't cover, so the hubnode can add it.
Nothing is added automatically: the rule reads trunk's `para.json`, as every rule does.

**What settles it (open question 4):** `jig release` in the pararepo. It exists for every repo
since 0.3.0. Before its build, the release:
- turns every `settled` row into one metarepo proposal (`jig propose --drift`, one branch, a spec
  listing every row), and marks them `proposed <branch>`
- refuses while any row is `settling`, unless `--force`, which names them in the release commit
  (open question 5). This matches the staged-files refusal: a release shouldn't ship around a
  decision still being tried out.

`jig propose --drift` can also be run by hand, when the owner says so, without a release. That
covers a pararepo that doesn't release yet.

**What closes it:** when the pin moves to a metarepo tag that contains a row's proposal (the
gate's existing "is this proposal in that tag" helper), `jig sync` lists those rows. The bump
commit marks them `closed <tag>`.

**The metarepo's side (open questions 1 and 6, and the two rules).** RULES.md *Metarepo and
pararepos* gains two rules:
- **Newer wins:** a later decision, or a pararepo page a decision makes the authority, overrides
  older page text it contradicts, whether or not that text is marked Accepted. The update needs
  the new text citing its source, and an old "Accepted (who, date)" kept only on what it still
  covers.

  A decision row changes only when the stale claim is itself a decision row: it's marked
  `superseded by` the newer one. So the answer to open question 1 is neither (a) nor (b). A page
  update needs no new sign-off, because the decision that drives it is already the owner's.
- **Every copy:** a metarepo spec that changes a claim lists every place that states it, found
  by meaning, not only by its words, and its done-when covers each one. The spec and review
  skills ask this in a metarepo.

Nothing shows on the metarepo's pages before a proposal (open question 6): rule 1 says the
metarepo is written only by branch. The metarepo hubnode's session-start step lists the open
drift rows of the pararepos registered in `repos.json`, read-only, so the drift is visible
without any writes.

**Open question 7 (the existing deferral)** is the adopting repos' call, not jig's. The advice:
make the deferred `spellbook.md` row the pararepo's first drift row, since its source is the
pararepo's page. It then rides in the next drift proposal.

## Done when
Smoke, in a metarepo plus pararepo fixture:
- [ ] A change to a `described` path with no drift row and no spec answer is refused by P5. With a
      row added to `META-DRIFT.md` in the same commit, it's accepted. So is a spec with
      `meta: logged D1`.
- [ ] A second change to the same behavior that edits the row is accepted. No metarepo branch
      exists afterwards.
- [ ] Pushing with open rows succeeds.
- [ ] `jig release` in the pararepo, with two `settled` rows and none `settling`, opens one
      metarepo proposal branch whose spec lists both. The rows read `proposed <branch>`.
- [ ] With a `settling` row, the release refuses and names it. `--force` releases and names it
      in the release commit.
- [ ] After the metarepo releases the proposal and the pin moves to that tag, `jig sync` lists
      both rows as closable.
- [ ] `jig sync` reports a pararepo path a metarepo decision cites that `described` doesn't cover.
- [ ] A contract-path change still needs a proposal or `none` (P2 unchanged).
- [ ] RULES.md states P5, Newer wins and Every copy. The spec and review skills ask Every copy in a
      metarepo.
- [ ] Smoke passes, and the validator passes.

## Out of scope
- Editing a pararepo from its metarepo.
- Drift for `contract_paths`.
- A drift view rendered in the metarepo's pages.

## Touches
- `marketing/FEATURES.md`: rows for the drift ledger, P5 and `propose --drift`, before code.
- `plugin/templates/jig/jig.py`:
  - `para_rules` (P5) and `PROPOSAL` (`logged`)
  - the `described` default in `para.json`
  - `cmd_propose --drift`, `cmd_release`'s pararepo step
  - `cmd_sync`'s report (closable rows, uncovered cited paths)
  - `init --para --described`
- `plugin/templates/ledgers/META-DRIFT.md` (new).
- `plugin/templates/jig/RULES.md`: P5, Newer wins, Every copy.
- Skills: `hubnode` (session start in a metarepo), `spec` and `review` (Every copy), `release`
  (a pararepo's drift step), `repos` (`add para` offers `described`).
- `tests/smoke.sh`.

## Alternatives considered
- Widen `contract_paths` to the docs. Rejected: every change of mind would then need a metarepo
  proposal, the round trip the owner wants to skip. `[seen]`: the story's cost section.
- Keep the log in `para.json`. Rejected: rows change on every change of mind, and `para.json`
  is the config a rule reads from trunk and a generated header comes from. A ledger is jig's
  shape for a growing list of rows. `[seen]`: `WORKAROUNDS.md`, `DEFERRED.md`.
- Add `described` paths automatically from metarepo decisions. Rejected: a rule would then depend
  on a parse of the metarepo at the pin, not on trunk's own config. The sync report gets the same
  coverage, with the owner choosing. `[seen]`: every rule reads trunk.
- Let a release carry `settling` rows as open in the proposal. Rejected: the metarepo would be
  proposed a behavior still being tried out. `[assumed]`: the owner's "once the dust has settled".

## Open (for the owner)
- Should `--force` on a pararepo release also be allowed to propose `settling` rows, marked
  open? The recommendation above says no.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
