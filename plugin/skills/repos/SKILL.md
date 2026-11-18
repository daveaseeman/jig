---
name: repos
description: List, register, rename or alias the repos jig knows by name (~/.config/jig/repos.json), so staged files, inbox messages and pararepos can find them. Use on "/jig:repos", "add this repo", "add meta", "add para", "rename repo" or "alias repo".
disable-model-invocation: true
---

Run the plugin's copy, from the folder the session is connected to:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" repos <args>
```

- **No arguments**: list every entry with its kind, path and aliases. It flags missing paths
  and marks this folder's entry `← here`.
- **`add repo`, `add meta`, `add para`**: register this folder's repo under its own name and
  path, with that kind. Its own name is the board's `name`, else the folder's. Pass
  `--name <name>` to choose another, or `--path <path>` for a checkout other than this one.
  Adding the same checkout again replaces its entry, keeping its aliases.
  - `add meta` or `add para` beside an older jig's board (it names the file): offer
    `/jig:update` first, then a commit, then the init. `jig init` refuses until then, since
    it would write a second board.
  - `add meta` in a repo with no `.jig/meta.json`: offer `jig init --meta`.
  - `add para` with no `.jig/para.json`: list the meta entries, ask which metarepo it cites,
    and offer `jig init --para <name> --contract <globs>`.
- **`rename <name>`**: give this folder's entry a new name to call it by. **`rename <old>
  <new>`** renames any entry. A rename is an alias in this list only. The repo's own name
  still finds it, so a pararepo citing a metarepo you renamed keeps working.

- **`alias <repo> <alias>`**: a shorthand for an entry, kept beside its name (a rename
  replaces the name). `--remove` drops one. An alias equal to any other entry's name or alias is
  refused. A typed repo name, anywhere jig takes one (a staged target, `/jig:relay`, an inbox
  message's `to`), matches a name or alias with case ignored; one that matches only once its
  punctuation is dropped is refused, naming the near one.

The list, `add`, `rename` and `alias` warn when two names are equal once case and punctuation are dropped
(`NorthStar`, `north-star`), printing both paths. Show the warning: ask whether both are meant,
and offer a `rename` so the two read apart.

Report the entry as it now stands. If the repo has no `.jig/staging/`, say so: `/jig:update`
adds it.
