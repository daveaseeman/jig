# decision-touches

Source: owner, Nov 11, from a maige-lite session's report: "Nothing checks contradiction by
meaning … The identity lock ignores accelerometer gestures on a hubnode decision here, while
the metarepo's E-033 says gestures count as activity. No gate flagged it; a reviewer found it
by reading both." The owner: "I think jig can be made to interpret meaning, just carefully …
the jig system should record future decisions in a way that makes them automatic and easy to
track and move in the future (meaning needs to be baked in or pointed to)". Then "agreed on
all", on the design below, including a repo with no metarepo using its own pages.

## Intent
Every decision says what it touches and what it rules. When one is added or changed, jig lists
every live decision that touches the same thing, here and in the metarepo, and the handoff
answers, pair by pair, whether they agree. jig picks the pairs and the reviewer judges each one.

## Why
- Why did the gesture conflict pass? Two entries in two repos ruled on the same situation, and
  nothing put them in front of one reader.
- Why not? A decision entry doesn't say what it is about, so jig can't tell which entries share
  a subject, and the two repos lay the same feature out in different folders.
- Why does that matter? A contradiction is a question of meaning. A gate can't judge meaning, but
  it can make sure the right pairs always get read side by side, and that an answer is recorded.

## Givens
- `[seen]` RULES.md, Decision log: an entry is a heading, a status line, then a body. Nothing in
  it names a page or a feature.
- `[seen]` Fold-in already asks every page whose text cites a changed decision id
  (`foldin_lines` ~1379, `decision_citers` ~4108), and `jig gate` refuses an unanswered line.
- `[seen]` A pararepo caches the metarepo's entry files at its pin (`.jig/meta-cache/`), the
  log included. A metarepo can read registered pararepos' trunks through `jig repos` (spec
  `meta-docs-tree`, redocument's Cited-by column).
- `[seen]` A metarepo's genre pages (`docs/<genre>/<name>.md`) name products, features,
  principles and concepts, independent of any pararepo's code tree.
- `[assumed]` Most contradictions are between two entries governing the same situation with
  different outcomes, so a *when … then …* sentence makes them visible side by side.

## Design
- **`Touches:` on every entry.** A line right after the status line, listing page pointers:
  `Touches: <meta>/docs/features/gestures.md, docs/identity.md`.
  - A pararepo names the metarepo's pages for anything shared (a product, feature, principle or
    concept), and its own pages for what is its alone.
  - A metarepo names its own pages.
  - A repo with neither names its own docs pages.
  - Each pointer resolves the way any pointer does: either page form, cached at the pin for a
    metarepo page. M2 refuses a new or changed entry with no `Touches:`, or with one naming no
    page. An entry already on trunk is grandfathered until it changes.
- **The rule sentence.** The body opens with what the decision rules, as *When <situation>,
  <outcome>.* (or *Always, <outcome>.*). This is a writing rule in RULES.md, not a hook check:
  a regex can't judge it, and the review below reads it.
- **Peers.** Two live entries are peers when their `Touches:` share a page, in either form, or
  when one names a page above the other's (`pages_above`). Peers come from:
  - this repo's log;
  - in a pararepo, the metarepo's log at the pin;
  - in a metarepo, each registered pararepo's log on its trunk, through `jig repos`. A
    pararepo that isn't registered or found is named on one line as not read.
- **Pair lines at handoff.** A branch that adds or changes an entry gets one fold-in line per
  peer:
  `- [ ] D-?id-lock vs <meta>/.jig/decisions.md § D-033 (features/gestures): ___`
  It is answered **agrees**, **narrows: <how>** (one is an exception the other allows), or
  **conflicts: <resolution>**. `jig gate` refuses an unanswered line, as it does a fold-in line.
- **`jig decision <id> --peers`** prints an entry's peers with their rule sentences, so anyone
  can run the comparison outside a handoff.
- **The review skill** gets the pair questions. For each pair:
  1. Do both govern the same situation?
  2. Do their outcomes differ?
  3. Is one an exception the other permits?
  4. Is either in the wrong repo, binding others from a pararepo, or binding one pararepo from
     the metarepo?

  A "conflicts" answer with no resolution is blocking.
- **Placement hint.** In a metarepo, `jig survey` names each metarepo page that two pararepos'
  entries touch while the metarepo has no entry on it ("probably the metarepo's").
- **Backfill.** `jig update` lists each live entry with no `Touches:` under Repo files to review.
  The one-time audit prompt's approved mapping is written in this form so a session can apply it.

## Done when
- [ ] Smoke: M2 refuses a new entry with no `Touches:`. It accepts one naming an existing page
  in either form, and accepts an untouched old entry with none.
- [ ] Smoke: in a pararepo whose metarepo's pinned log has `E-033 … Touches:
  <meta>/docs/features/gestures.md`, a branch adds `D-?id-lock` touching the same page.
  `jig handoff` writes one pair line naming both, and `jig gate` refuses it unanswered and
  accepts **agrees** (the reported symptom: the pair is now put in front of a reader).
- [ ] Smoke: an entry touching `docs/a/b.md` peers with one touching `docs/a.md` (a page above).
  An entry touching an unrelated page gets no line.
- [ ] Smoke: in a metarepo with two registered pararepos whose entries touch
  `docs/features/x.md`, and no metarepo entry on it, survey names the page.
- [ ] Smoke: `jig decision <id> --peers` lists the peers with their first body sentence.
- [ ] `jig update` lists live entries without `Touches:` under Repo files to review.
- [ ] RULES.md (Decision log, Fold-in) and `plugin/skills/review/SKILL.md` say it.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- jig judging a pair itself. jig.py chooses the pairs, and the reviewer answers them.
- Mapping a pararepo's pages to the metarepo's pages wholesale. An entry names the shared page
  directly; a page-level map waits until entries show they need one.
- Fixing existing contradictions. That is the one-time audit prompt, run per ecosystem.

## Touches
- `plugin/templates/jig/jig.py` (M2's entry check, `foldin_lines`, gate's unanswered lines,
  `cmd_decision --peers`, survey's metarepo placement line, update's repo files)
- `plugin/templates/jig/RULES.md` (Decision log, Fold-in, the M2 row)
- `plugin/skills/review/SKILL.md`
- `tests/smoke.sh`
- `marketing/FEATURES.md` (main checkout only: a new row)

## Alternatives considered
- Leave contradictions to review and "Every copy", as today. Rejected: the reported conflict
  passed because no one was handed both entries. Reason is [seen: maige-lite's report].
- Tag entries with free-form keywords. Rejected: two repos would spell one feature two ways,
  the same failure that made one feature's pages miss each other. Page pointers resolve and are
  checked. Reason is [seen: the seam bug, `bug-seam-ownerless-folder`].
- Have jig.py judge contradictions itself. Rejected: meaning needs reading, and jig.py is
  stdlib with no AI dependency (AGENTS.md, Code). Reason is [seen].

## Decisions
- A repo with no metarepo uses its own docs pages as the vocabulary (owner, Nov 11).
- Runs after `decision-remove-superseded`: a removed entry is never a peer.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
