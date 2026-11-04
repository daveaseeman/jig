# Steps that need the owner: a release asked for in a brief, and a settings mismatch

Source: maige-ecosystem hubnode session, 2026-11-03 (sync-buffer replay) (staged as feedback-maige-ecosystem-2026-11-03.md)

Report items 3 and 9.

## 1. Why
- Why did a hubnode release without asking? A relayed brief said "cut a release", and the
  hubnode skill lists a release as a `check` step it runs, with only push and publish "on the
  owner's word".
- Why does that matter before a push? A tag is what pararepos pin, and in a metarepo the
  release rewrites Unreleased into a version heading. It's the owner's call, like a merge.
- Why did a subagent run at the wrong effort? Unverified (the harness or the subagent's reading
  of itself). But jig's rule can't hold for a subagent anyway: "a mismatch stops it… don't
  brief it" assumes the `running` line comes back before the brief is sent. An Agent call
  carries the brief in its first prompt, so the work has already started.

## 2. Givens
- `[seen]` `plugin/skills/hubnode/SKILL.md`: "Release and survey are `check` steps too… The
  push and publish stay yours, on the owner's word." Nothing says the release itself waits.
- `[seen]` The same skill: every spawned prompt starts with the `running` line, "and its first
  reply must start with the same line… A mismatch stops it: tell the owner, don't brief it."
  Sessions get a holding prompt first. Subagents get no equivalent step.
- `[seen]` Owner (quoted in the report): a release asked for in a spec or brief goes to him
  first. A release in a test clone is fine.
- `[assumed]` Why the subagent read "low". It isn't reproducible from jig, so it's kept as a risk.
  The correction below catches it whatever the cause.

## 3. One layer up
- Sibling: `jig merge` is already "on the owner's word". A release is the same kind of
  outward-facing step and should read the same way.
- Sibling: sessions already get a holding prompt and a read-back. Subagents need the
  equivalent: the prompt says to stop at a mismatch.

## 4. Correction
Skill text only.
- A release on a real repo runs on the owner's word in the conversation, like a merge. A spec,
  brief or another session's message asking for one isn't that word. A scratch or test clone
  is exempt.
- A subagent's prompt says: "if your own model or effort differs from this line, reply with
  only your `running` line and stop". At a mismatch, the hubnode retries once, then tells the
  owner. It never uses that run's output.

## 5. Spec

### Done when
- [ ] `plugin/skills/hubnode/SKILL.md`, the Release bullet: the release itself waits for the
      owner's word on a real repo, even when a spec or brief asks for it. A scratch or test
      clone is exempt. `plugin/skills/release/SKILL.md` says the same in one line.
- [ ] `plugin/skills/hubnode/SKILL.md`, the `running` paragraph: a subagent's prompt tells it to
      stop at a mismatch. The hubnode retries once, then asks the owner, and discards the
      mismatched run.
- [ ] Nothing Claude-specific is added to `plugin/templates/jig/` or RULES.md. The validator
      and smoke pass.

### Out of scope
- Why the Agent tool's effort read back lower: that's the harness, and not jig's to fix.
- Any check in `jig release` itself. jig can't tell a brief from the owner.

### Touches
`plugin/skills/hubnode/SKILL.md`, `plugin/skills/release/SKILL.md`.

### Alternatives considered
- `jig release` asks for confirmation on a TTY. Rejected: agents run it without a TTY, and a
  prompt an agent can answer itself isn't the owner's word. The decision point is the conversation.
  `[seen]`: hubnode runs `jig release` from Bash.
- Keep "don't brief it" for subagents. Rejected: an Agent call has no point between the read-back
  and the brief. `[seen]`: the Agent tool takes one prompt.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
