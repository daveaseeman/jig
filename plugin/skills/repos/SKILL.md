---
name: repos
description: List, register or rename the repos jig knows by name (~/.config/jig/repos.json), so staged files and pararepos can find them. Use on "/jig:repos", "add this repo", "add meta", "add para", or "rename repo".
disable-model-invocation: true
---

Run the plugin's copy, from the folder the session is connected to:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" repos <args>
```

- **No arguments**: list every entry with its kind and path. It flags missing paths and
  marks this folder's entry `← here`.
- **`add repo`, `add meta`, `add para`**: register this folder's repo under its own name and
  path, with that kind. Its own name is the board's `name`, else the folder's. Pass
  `--name <name>` to choose another, or `--path <path>` for a checkout other than this one.
  Adding the same checkout again replaces its entry.
  - `add meta` in a repo with no `.jig/meta.json`: offer `jig meta-init`.
  - `add para` with no `.jig/para.json`: list the meta entries, ask which metarepo it cites,
    and offer `jig para-init --meta <name> --contract <globs>`.
- **`rename <name>`**: give this folder's entry a new name to call it by. **`rename <old>
  <new>`** renames any entry. A rename is an alias in this list only. The repo's own name
  still finds it, so a pararepo citing a metarepo you renamed keeps working.

Report the entry as it now stands. If the repo has no `.jig/staging/`, say so: `/jig:update`
adds it.
