# A pararepo works ahead of its metarepo in a sync buffer, and settles it at release

Source: user story by the maige-ecosystem hubnode session, Nov 2
(`side-session-notes/local_25f7e824…/user-story-meta-drift-log.md`, a draft for the owner's
walkthrough). Owner, Nov 2: "I just want to be able to work on a para repo and change my mind a
few times while testing things before deciding to roll everything into a meta repo for release
once the dust has settled, but of course we can't let drift happen unaccounted for, we need a
backlog of sorts." No preference on where the log lives.

## Intent
A pararepo can change behavior its metarepo describes, as often as testing needs, and commit and
push each change. Every such difference is in a buffer in the pararepo the moment it's made. When
the pararepo releases, the whole buffer goes to the metarepo as one proposal. The
metarepo then updates every page the settled behavior contradicts, and an older Accepted mark
doesn't stop it.

## Why it slipped by (the gap, `[seen]` in the story and in `jig.py`)
- P2 asks for a `meta:` answer only on `contract_paths`. The pararepo's UI doc wasn't one, so
  four changes of mind reached no gate, and two metarepo pages went stale with nobody told.
- P2's only answers are `none — <reason>` and a proposal (`PROPOSAL`, `jig.py` ~1948). So putting
  the doc in `contract_paths` today would mean a metarepo round trip for every change of mind.

## The design
Owner, Nov 2: keep `contract_paths` and the proposal. This only adds a buffer to work in, so
changes don't have to be proposed, merged and released one at a time.

**The buffer is a ledger:** `.jig/ledgers/SYNC_BUFFER.md` in the pararepo. It sits beside the
others:
- `WORKAROUNDS.md`: patches that are in the code
- `DEFERRED.md`: review findings not taken

It's tracked, append-friendly, and its first row creates it from the plugin's template. One row
per metarepo claim the pararepo has moved away from:

| Id | Metarepo claim (file § section, at the pin) | This repo now (source, commit) | Decided (who, date) | State |

The state is `Open` or `Closed`, nothing else. Everything open is still settling until the owner
releases. A change of mind edits the row's middle columns. `para.json`'s `defer_until` is
unrelated: it quiets `jig sync`'s report until a date.

**P2 gains a third answer: buffered.** A contract-path change is accepted when one of these comes
with it:
- a row added to or changed in `SYNC_BUFFER.md` in the same commit (like R7 with
  `WORKAROUNDS.md`)
- a spec line `meta: buffered <row id>`, beside the existing `none — <reason>` and proposal

Everything else about P2 stays. In particular, the gate's check that a job's spec doesn't cite an
unreleased proposal is unaffected, because a buffered change cites none.

**Closing the gap is a config change.** The UI doc goes into `contract_paths`. To help, `jig sync`
reports each pararepo path a metarepo decision cites at the pin (the way E-045 cites `ui.md`) that
`contract_paths` doesn't cover, so the hubnode can add it. Nothing is added automatically: the
rule reads trunk's `para.json`, as every rule does.

**Release proposes the whole buffer at once.** `jig release` in the pararepo, before its build,
puts every `Open` row into one metarepo proposal: `jig propose --buffer`, one branch, a spec that
lists every row by id. Nothing in jig splits proposals: one `jig propose` is one branch. The rows
stay `Open`, and the proposal's spec is the record of which ones went. With an empty buffer, the
release just releases.

`jig propose --buffer` can also be run by hand, on the owner's word, without a release, for a
pararepo that doesn't release yet.

**`jig sync` closes them.** When the metarepo releases a tag that contains the proposal, `jig sync`
in the pararepo moves the pin to that tag, as it already proposes. In the same commit it marks
`Closed` every row the proposal's spec lists. Rows added after the proposal stay `Open` for the
next one.

**The metarepo's side.** RULES.md *Metarepo and pararepos* gains two rules:
- **Newer wins:** a later decision, or a pararepo page a decision makes the authority, overrides
  older page text it contradicts, whether or not that text is marked Accepted. The update needs
  the new text citing its source, and an old "Accepted (who, date)" kept only on what it still
  covers.

  A decision row changes only when the stale claim is itself one: it's marked `superseded by` the
  newer one. A page update needs no new sign-off, because the decision behind it is already the
  owner's. (The story's question 1: neither (a) nor (b).)
- **Every copy:** a metarepo spec that changes a claim lists every place that states it, found by
  meaning, not only by its words, and its done-when covers each one. The spec and review skills
  ask this in a metarepo.

Nothing shows on the metarepo's pages before the proposal: rule 1 says the metarepo is written
only by branch. The metarepo hubnode's session-start step lists the open rows in the registered
pararepos' buffers, read-only. (The story's question 6.)

The existing `spellbook.md` deferral is the adopting repos' call. The advice: make it the
pararepo's first buffer row, so it rides in the next proposal. (The story's question 7.)

## Done when
Smoke, in a metarepo plus pararepo fixture:
- [ ] A contract-path change with no buffer row and no spec answer is refused by P2. With a row
      added to `SYNC_BUFFER.md` in the same commit, it's accepted. So is a spec with
      `meta: buffered B1`.
- [ ] A second change to the same behavior that edits the row is accepted. No metarepo branch
      exists afterwards.
- [ ] Pushing with open rows succeeds.
- [ ] `jig release` in the pararepo with two `Open` rows opens one metarepo proposal branch whose
      spec lists both. With none, it opens no branch.
- [ ] After the metarepo releases the proposal, `jig sync` moves the pin and marks both rows
      `Closed` in one commit. A row added after the proposal stays `Open`.
- [ ] `jig sync` reports a pararepo path a metarepo decision cites that `contract_paths` doesn't
      cover.
- [ ] `none — <reason>` and a proposal still answer P2.
- [ ] RULES.md states the buffered answer, Newer wins and Every copy. The spec and review skills
      ask Every copy in a metarepo.
- [ ] Smoke passes, and the validator passes.

## Out of scope
- Editing a pararepo from its metarepo.
- A buffer view rendered in the metarepo's pages.

## Touches
- `marketing/FEATURES.md`: rows for the sync buffer and `propose --buffer`, before code.
- `plugin/templates/jig/jig.py`:
  - `para_rules` (P2's buffered answer) and `PROPOSAL`
  - `cmd_propose --buffer`, `cmd_release`'s pararepo step
  - `cmd_sync` (closing rows in the pin commit; uncovered cited paths)
- `plugin/templates/ledgers/SYNC_BUFFER.md` (new).
- `plugin/templates/jig/RULES.md`: P2, Newer wins, Every copy.
- Skills: `hubnode` (session start in a metarepo), `spec` and `review` (Every copy), `release`
  (the pararepo's buffer step).
- `tests/smoke.sh`.

## Alternatives considered
- A separate `described` list and a new rule beside `contract_paths`. Rejected by the owner: a
  buffer on the existing flow does the job with one list. `[seen]`, Nov 2.
- Per-row states (settling, settled, proposed). Rejected by the owner: everything open settles
  together and closes together, at `jig sync`. `[seen]`, Nov 2.
- Keep the buffer in `para.json`. Rejected: rows change on every change of mind, and `para.json`
  is the config a rule reads from trunk and a generated header comes from. `[seen]`
- Add contract paths automatically from metarepo decisions. Rejected: a rule would then depend on
  a parse of the metarepo at the pin, not on trunk's own config. The sync report gets the same
  coverage, with the owner choosing. `[seen]`: every rule reads trunk.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
