# stage-ask-access

Source: owner, Nov 10: "I've asked sessions to stage to `repo-name` and it'll say 'I dont have
access' instead of just asking for access, how could we direct sessions to ask instead?"

## Intent
A session staging into another repo asks for access to that repo's staging folder through its
host. It never reports "no access" and stops.

## Why
- Why does a session stop at "I don't have access"? The stage and feedback skills say "ask for
  access to exactly that folder" but don't say how. A session that doesn't know its host can
  grant a folder treats the lack of access as final.
- Why not a config line? A session can read `.jig/config.json` only after it has access to the
  repo, so a setting there would never be seen.

## Design
- In `plugin/skills/stage/SKILL.md` (Staging a file) and `plugin/skills/feedback/SKILL.md`
  (step 2), the access sentence becomes: find the path with `jig repos`, then request access to
  exactly `<path>/.jig/staging/` with the host's folder-access tool (in the Claude desktop app,
  `request_directory`). If there is none, ask the user to add that folder to the session.
  Never stop at "no access": the folder is the user's to grant.
- Skills only. `RULES.md` and the templates name no Claude tool (AGENTS.md, Code).

## Done when
- [ ] `grep -n 'request_directory' plugin/skills/stage/SKILL.md plugin/skills/feedback/SKILL.md`
  finds the sentence in both.
- [ ] `grep -n 'no access' plugin/skills/stage/SKILL.md plugin/skills/feedback/SKILL.md` finds the
  "never stop" clause in both.
- [ ] `grep -rn 'request_directory' plugin/templates` finds nothing.
- [ ] `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- `jig staging resolve` forwarding into another repo (`forward()`). It runs where the jig repo
  is open, and is a separate question.
- Granting access itself. That stays the user's, through the host.

## Touches
- `plugin/skills/stage/SKILL.md`
- `plugin/skills/feedback/SKILL.md`

## Alternatives considered
- A line in the target repo's `.jig/config.json` — rejected because a session reads it only
  after it has the access it is asking for — reason is [seen: the stage skill reads `jig repos`
  from `~/.config/jig/` before touching the repo]
- Rely on agents to ask — rejected because sessions are already stopping at "no access" with
  the current wording — reason is [seen: owner, Nov 10]

## Decisions
- Runs after `decision-log`, which owns the stage skill.
- Owner, Nov 10, for this job only: the spec and its review run on Opus, and the build and the
  checks on Sonnet ("write and review with opus, use sonnet for the rest"). The Workflow below
  is the repo's setting as printed; this line is the owner's override for this one job.
- Skill text only (no `jig.py`, hooks, templates or tests), so AGENTS.md's lighter review
  applies: tier 2, effort 3.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
