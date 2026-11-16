# decision-cards: one way to put decisions to the owner

Source: the owner, jig hubnode session, 2026-11-16: "/jig:spec decision-cards as a skill that is available to hubnodes throughout their workflow and for other commands like jig:rig". Prototyped in the same session over five rounds: the play button, several questions in one card, "; and" between answers, the Elaborate and Hold buttons, and one fill per card.

## Intent
A `decision-cards` skill that the hubnode, and any command that asks the owner something
(`/jig:rig` first), loads to present one or more pending decisions the same way every time.
Each decision is a block with its options and one marked recommended, plus two standing
buttons, Elaborate and Hold. The card combines the owner's picks into one reply, with "; and"
between answers. Where the host can't draw a card, the same content goes out as text.

## The card (the approved prototype)
- **One block per decision.** A line saying what it's about, a line of context, then the
  options as buttons with one marked recommended. `/jig:rig`'s blocks use this shape.
- **Two small standing buttons on each block's right.** Elaborate fills
  "on <decision>: show me these options with more context", and Hold fills
  "on <decision>: hold until I can provide more context". Each counts as that block's answer,
  in place of its options. Clicking a selected button again clears it.
- **Picks only change the card.** A preview line shows the combined reply. One "Fill reply"
  button at the bottom writes it once, joined with "; and". Plain ", and" is ambiguous,
  because answers contain their own commas and "and"s.
- **Fill, never send.** In the Claude app a card's button writes into the owner's reply box and
  appends to what's there. So the label says "Fill reply", and the hint says to press Enter.
- **The sent reply is the answer, not the card.** A card can be stale: before acting on a reply,
  the hubnode checks the current state (the board, the staged file, the job) and asks again if
  it moved. A filled reply the owner hasn't sent is no answer.
- **No card where the host can't draw one.** In a terminal, or a host with no inline visual
  tool, the same blocks go out as text: numbered decisions, lettered options, the recommended
  one marked, and the two standing answers named, so the owner can reply "1b; and 2 hold".

## Done when
- [ ] `plugin/skills/decision-cards/SKILL.md` exists, with a description that fires when the
      hubnode or a command has decisions to put to the owner, and never otherwise. It states
      every rule in "The card" above, and holds one complete card as a working example: HTML
      with only the host's theme variables, no external scripts.
- [ ] The hubnode skill points to it where it puts decisions to the owner (the merge, the
      release, a ruling a subnode raised, a reconfiguration), and nowhere restates the card's
      rules. `grep -n "; and" plugin/skills/hubnode/SKILL.md` finds nothing.
- [x] The rig spec (`.jig/specs/rig.md`) names `decision-cards` as how its question blocks are
      drawn, in its Touches and its "What it shows" (done on trunk before the jobs opened).
- [ ] Nothing tool-specific reaches the templates: `grep -rn "decision-cards" plugin/templates`
      is empty, and RULES.md names no card. A rule a repo must follow stays in RULES.md, in
      words any host can follow.
- [ ] The text fallback is in the skill, with an example reply ("1b; and 2 hold"), so a
      terminal session can follow it.
- [ ] `claude plugin validate ./plugin` passes, `.jig/scripts/check.sh` exits 0, and
      `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` is empty. No smoke section: this is
      skill text only, so it gets the lighter review AGENTS.md sets for skill-only diffs.

## Out of scope
- A jig command that draws cards: `jig.py` stays tool-agnostic, and data for a card comes from
  the command that asks (`jig rig --json`, the board).
- Cards for subnodes: a subnode's questions go to the hubnode, which puts them to the owner.
- Remembering answers across runs: rig's recommendation store is rig's.

## Touches
- new `plugin/skills/decision-cards/SKILL.md`
- `plugin/skills/hubnode/SKILL.md` (pointers where it asks the owner)
- `marketing/FEATURES.md` (a row, the hubnode's)

## Alternatives considered
- Keep cards as the hubnode's own habit, not in jig — the owner's first call on 2026-11-16,
  reversed by this request, now that `/jig:rig` needs the same blocks — [seen].
- Put the card's rules in the hubnode skill — rejected because rig and later commands would
  restate them, and two copies drift — [assumed].
- Send on click — rejected: the host only fills the reply box, and appends, so a click that
  claims to send misleads — [seen] in the prototype rounds.

## Decisions
- Interpreted: the skill is neither a node nor a role. It's a shared presentation skill, like
  `/jig:stage` is a standalone tool, and the roles-and-flows inventory gains a row for it.
- Interpreted: the text fallback uses numbered decisions and lettered options, so a reply like
  "1b; and 2 hold" maps back without the card.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
