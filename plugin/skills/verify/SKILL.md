---
name: verify
description: How to prove a change works before calling it done. Tests for logic, emulator for graphics, hardware for everything else.
---

Pick the cheapest check that is actually evidence:

| Change touches | Check |
|---|---|
| Pure logic (parsing, hashing, state machines) | Unit test. Write it first if the behavior is non-obvious. |
| Display / UI rendering | Emulator screenshot, then hardware when it looks right. |
| Driver, bus, peripheral, timing | Hardware. Serial log the agent can read. Emulation only if the board's page (`docs/hardware/<board>.md`) says that peripheral is modeled. |
| Build config, linker, partitions | Build + flash + boot log. |

Rules:
- Compiled is not verified. A green build earns the right to flash, nothing more.
- Show the output: the command, the result, the log line that proves it. Don't summarize it away.
- Running jig in a throwaway repo? There, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.
- If the check can't be run (no board attached, no emulator), say so explicitly and stop. Don't infer success.
- Prefer a check the next agent can re-run from `.jig/scripts/check.sh` over one that lived only in this session.
