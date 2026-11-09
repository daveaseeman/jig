---
name: verify
description: How to prove a change works before calling it done. Tests for logic, emulator for graphics, hardware for everything else.
---

Pick the cheapest check that is actually evidence:

| Change touches | Check |
|---|---|
| Pure logic (parsing, hashing, state machines) | Unit test. Write it first if the behavior is non-obvious. |
| Display / UI rendering | Emulator screenshot, then hardware when it looks right. |
| Driver, bus, peripheral, timing | Hardware. Serial log the agent can read. Emulation only if the board's page (the one `boards` in `.jig/config.json` lists for it) says that peripheral is modeled. |
| Build config, linker, partitions | Build + flash + boot log. |

Rules:
- Compiled is not verified. A green build earns the right to flash, nothing more.
- Show the output: the command, the result, the log line that proves it. Don't summarize it away.
- Running jig in a throwaway repo? There, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.
- A run that can outlast your shell's foreground time limit goes in the background, with its output to a file, and you act on its exit notice. Where the shell gives no notice, start it with `cmd > out 2>&1 & echo $!`, then in each later command poll that literal pid for less than the limit: `for i in $(seq 50); do kill -0 <pid> 2>/dev/null || break; sleep 10; done`. A pid kept in a variable is gone by the next command, and the loop would end at once as if the run had. Cap the whole wait at about twice the run's usual time, then read the output and report what you see. Never wait on a match: a process pattern (`pgrep -f`, `ps | grep`) can match another waiter's or another run's command line, and a log line never comes from a run that dies early.
- If the check can't be run (no board attached, no emulator), say so explicitly and stop. Don't infer success.
- Prefer a check the next agent can re-run from `.jig/scripts/check.sh` over one that lived only in this session.
