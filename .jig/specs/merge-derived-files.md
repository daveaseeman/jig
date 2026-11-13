# merge-derived-files

Source: jig hubnode side session (Daisy survey), 2026-11-12, for the owner (staged as feedback-Daisy-2026-11-12-hubnode-merge-scripts.md): the hubnode's merge has no step for a repo's own post-merge work, so the hubnode scripted it.

Report section 2 only; section 1 (append conflicts in `jig merge`) is another group's. The report's
`jig_version` (1a8efef0e75c) is `git hash-object` of today's `plugin/templates/jig/jig.py`.

## Intent
A repo's files derived from the whole tree (a generated reference, an index) are rewritten by its
own `.jig/scripts/derive.sh`, which `jig merge` runs on the merged tree and commits in the merge
commit, as jig already does for its own `ROADMAP.md`. After a merge the hubnode removes the
merged job's worktree and branch once it has looked at them. It never writes a script of its own
around jig's commands.

## Why
1. Q: Why did the hubnode script its merges?
   A: Each merge needed steps `jig merge` doesn't take: regenerate files derived from trunk and
   commit them, push, clean up. Repeated over 31 merges, the steps became a script.
2. Q: Why couldn't the repo put the regeneration where jig runs repo steps?
   A: The one that runs after a merge, `setup.sh`, runs in every checkout and must leave tracked
   files alone. A tracked change there blocks the gate and dirties trunk.
3. Q: Why is this jig's gap and not one repo's?
   A: Two jobs regenerating one whole-tree file merge into a wrong copy or a conflict. jig
   rewrites its own such file, `ROADMAP.md`, in the merge commit for that reason.

## Givens
- `[seen]` Scratch repo (generator writes `INDEX.md`: `count: N`, then `ls src`). Jobs A and B
  each add a source and regenerate. Both `jig merge`s exit 0 with trunk clean, and trunk's
  `INDEX.md` says `count: 7` over 8 sources; regenerating gives `count: 8`.
- `[seen]` Same, with the two additions adjacent: `jig merge B` stops on `INDEX.md`, a non-append
  conflict. Finished by hand: run the generator, `git add`, `jig merge --number`, `git commit`.
- `[seen]` Same, with `setup.sh` running the generator and a job that doesn't regenerate: the
  gate's scratch shows ` M INDEX.md`, so `jig mark E gated` refuses ("has tracked changes
  (INDEX.md)"). After `jig merge E`, trunk shows ` M INDEX.md`, so the next `jig merge` refuses
  ("commit or stash first").
- `[seen]` `cmd_merge` writes `jobs.json`, the numbered ids, `.jig/roadmap.md` and `ROADMAP.md`
  into the merge commit before committing ("the view is rewritten in the merge commit itself").
  It calls `run_setup` after the commit. `check_rules` says why R5 keeps the roadmap on trunk:
  "a branch regenerating the view would only make merge conflicts".
- `[seen]` M4 (`meta_rules`): on a metarepo's trunk, a commit that isn't a merge and touches a
  file outside `.jig/` is refused. A separate derived-files commit after the merge would be
  refused there.
- `[seen]` hubnode SKILL.md "After a merge" covers only `jig sync` and `jig reserve`. Its
  "Never" list doesn't mention scripts.
- `[seen]` `jig merge` leaves the job's worktree and its local branch: after six merges in the
  scratch repo, `git worktree list` and `git branch` show all six. `bug-gate-scratch-left.md`,
  Out of scope: "Removing a job's own worktree at merge. The hubnode does that, after looking at
  it." No skill tells the hubnode to.
- `[seen]` Daisy (read only). AGENTS.md:44: lanes never commit `docs/reference/` or
  `.jig/config.json`, and "the manager regenerates them on `main` after each merge".
  `gen_reference.py` writes both. Commits such as "References regenerated after
  job-relay-data merged" are a separate commit per merge. `test_docs.py` checks the docmap only
  "at the commit that last wrote the board", because a lane's sources are ahead of it.
- `[seen]` `.git/jig/manager/` no longer exists in Daisy. The reporter's givens about the four
  scripts' contents stay inputs, `[assumed]` here. Nothing below depends on them.
- `[seen]` jig.py never runs `git push`. RULES.md: "A handoff is a *pull request*". The adopt
  skill maps "a PR / merge-request template" to the handoff note. `release-publish.md`, Decisions:
  pushing "isn't built into jig: some repos have no remote, or push somewhere other than origin".
- `[seen]` Daisy commit c20d08c8 (Nov 4): "102 GitHub branches and 4 local ones deleted … GitHub
  deletes merged branches from now on". `[assumed]` The reporter's `origin/card-move-undo` and
  `origin/designer-undo`: Daisy's remote-tracking refs list only `origin/main` today.

## One layer up
- Sibling: jig's own derived files. `ROADMAP.md` is trunk-only (R5) and rewritten in the merge
  commit, so it doesn't have this problem. A repo's own derived files have no slot.
- Pattern: a script in `.jig/scripts/` that the repo fills and jig runs at a moment it decides
  (`check`, `format`, `setup`, `release`, `publish`). `publish.sh` is the latest one added this
  way: a template, an `update` step, a skill line.

## Generality (per part)
- **Derived files: a correction.** Any repo with tracked files generated from many sources has
  the same problem with parallel jobs: a wrong clean merge, or a conflict and a re-handoff per
  job. The hubnode either repeats a hand step per merge or writes a script. jig answers the same
  shape for its own file.
- **A PR as the merge's record: too specific.** jig's record of a merge is the handoff note and
  the merge commit. A repo that also wants forge PRs writes that convention in its AGENTS.md:
  push the gated commit to the job's branch and open the PR with the note as its body before
  `jig merge`. Pushing trunk then marks the PR merged. Each push is on the owner's word.
- **Remote branch cleanup: too specific.** jig never pushes a job's branch, so a branch on the
  remote exists only because the repo pushes them. The repo turns on its forge's "delete head
  branches" setting, or adds `git push origin --delete <branch>` to the same AGENTS.md
  convention.
- **Local worktree and branch removal: a correction, text only.** It is jig's, and it's general:
  every merged job leaves both behind, and `jig update` refuses while they're there. The owner
  already decided the hubnode removes them after looking. The skill only has to say so.

## Design
- **`.jig/scripts/derive.sh`**, a new template. Header: it writes the files this repo derives
  from the whole tree, in the checkout it runs in. It takes no arguments and is safe to run
  twice. `jig merge` runs it on trunk and commits what it wrote in the merge commit. Branches
  don't commit these files. If one does, the merge rewrites them, and a conflict in one can be
  settled by taking either side. `check.sh` doesn't compare them with their sources: in the
  gate's checkout they are still trunk's. Solo work on trunk runs it by hand and commits. The
  body is commented examples and `exit 0`, so the template is a no-op.
- **`jig merge`**. After its own writes (the entry, the numbers, the roadmap), it runs
  `setup.sh`, which used to run after the commit, and then `derive.sh` (environment as
  `run_setup`'s). It stages the tracked files `derive.sh` changed or deleted and the files it
  made, prints `derived: <files>`, and commits. If `derive.sh` exits non-zero, nothing is
  committed. jig prints the exit code and how to finish: fix it, then `jig merge --number` and
  `git commit`, or `git merge --abort`, which puts the entry back. Exit 1.
- **`jig merge --number`**, the conflict path's last step before the commit, runs `setup.sh` and
  then `derive.sh` the same way. The conflict message drops "then run setup.sh".
- **`jig update`** adds `derive.sh` from the template where it's missing: a `STEPS` row and an
  add function, as `publish.sh` has. `jig init` copies it with `templates/jig/`.
- **RULES.md**:
  - "Keeping merges mechanical": a file generated from the whole tree is written on trunk by
    `derive.sh` at each merge, never on a branch.
  - "Handoff, gate, merge" step 3: the merge runs `setup.sh` and `derive.sh` and commits what
    derive wrote in the merge commit. A failing derive stops the merge, as a conflict does.
  - Commands: the `--number` line adds "then setup.sh and derive.sh".
- **hubnode SKILL.md**:
  - "After a merge" gains two points. First, `jig merge` wrote the derived files: a step the
    repo repeats after every merge that writes files goes in `derive.sh`, proposed to the
    owner. Second, look at the merged job's worktree. If `git status` is clean,
    `git worktree remove <it>` and `git branch -d <branch>`. Otherwise, tell the owner and
    leave it.
  - Gating step 5: `--number` also runs setup and derive.
  - "Never" gains: write a script of your own around jig's commands. A repeated step that writes
    files is `derive.sh`'s. Anything else the repo wants after a merge (a push, a PR) is the
    owner's word, or a step its AGENTS.md names.
- **Other skills and the template**:
  - Template AGENTS.md, Commands: a `derive:` line.
  - update skill step 2: if `update` added `derive.sh`, ask whether the repo regenerates tracked
    files after merges, fill it with that, and offer to remove the hand-run equivalent.
  - init skill step 3: leave `derive.sh` as the template unless the repo tracks a generator's
    output, and then ask.
  - adopt mapping: "a step run on trunk after each merge that regenerates tracked files" maps
    to `derive.sh`.

## Done when
- [ ] Smoke `merge_derived`, the fix fires. The repo's `derive.sh` writes `INDEX.md` (a count
  and `ls src`). Jobs A and B each add one source and don't touch `INDEX.md`. Run nothing but
  `jig merge A` and `jig merge B`. Each exits 0 and prints `derived: INDEX.md`. After each:
  `git status --porcelain` is empty, HEAD has two parents, `git show --name-only HEAD` lists
  `INDEX.md`, and `INDEX.md` equals a fresh run of the generator.
- [ ] Smoke, the symptom: with the same `derive.sh`, two jobs that each regenerate and commit
  `INDEX.md` and merge cleanly (the `count: 7` case above) leave trunk at `count: 8` after
  `jig merge B`. No step by hand.
- [ ] Smoke: a `derive.sh` that exits 3. `jig merge C` exits 1, `MERGE_HEAD` exists, and stderr
  names `derive.sh`, 3 and `jig merge --number`. After a fix, `jig merge --number` and
  `git commit` leave `INDEX.md` current and the tree clean. A second run that takes
  `git merge --abort` instead has C's entry back in `jobs.json`.
- [ ] Smoke: a merge that stops on a source conflict. Once it's resolved, `jig merge --number`
  logs `setup.sh` once and writes `INDEX.md`. The stop message no longer says to run `setup.sh`
  after the commit.
- [ ] Smoke: with the template's `derive.sh`, `jig merge` prints no `derived:` line, and its
  merge commit lists the same files as before this change. `worktree_setup`'s "logs the
  checkout that merged, once" still passes.
- [ ] Smoke: after init, `derive.sh` is executable and exits 0. `jig update` on a repo without it
  adds it from the template, staged. The exact `.jig/` file lists in smoke name it.
- [ ] Text: hubnode SKILL.md's "After a merge" names `.jig/scripts/derive.sh`, `git worktree
  remove` and `git branch -d`. Its "Never" list has the own-script line. RULES.md names
  `derive.sh` under "Keeping merges mechanical" and in step 3.
  `grep -n derive.sh plugin/templates/AGENTS.md plugin/skills/{update,init,adopt}/SKILL.md`
  hits each file.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A PR per merge: too specific (Generality). This leaves that part of the original symptom: a
  repo that wants it keeps it as its own AGENTS.md step, never as a hubnode's script.
- Remote branch cleanup and pushing trunk after a merge. Both are too specific, and pushes stay
  the owner's word (`release-publish.md`).
- Removing the job's worktree inside `jig merge`. `bug-gate-scratch-left.md` decided the hubnode
  does it after looking: a subnode may still have uncommitted work there.
- Running `derive.sh` in the gate's scratch checkout. Its tracked changes would make
  `jig mark gated` refuse (`gate_scratch_problem`), and the merge writes them fresh anyway.
- A board key listing derived files, and a rule refusing a branch that commits one. The merge
  rewrites them, so a branch's copy never lands.
- Report section 1 (append conflicts). Another group's.
- Daisy's own move: `gen_reference.py` into `derive.sh`, and its AGENTS.md:44 line. That
  happens in Daisy through `/jig:update`.

## Touches
- `plugin/templates/jig/scripts/derive.sh` (new)
- `plugin/templates/jig/jig.py`:
  - `cmd_merge`: setup and derive before the commit, the failure path, the `--number` path and
    the conflict message.
  - A `DERIVE` constant and a `run_derive` beside `run_setup`.
  - A `STEPS` row and `add_derive`.
- `plugin/templates/jig/RULES.md`: "Keeping merges mechanical", "Handoff, gate, merge" step 3,
  and Commands.
- `plugin/templates/AGENTS.md` (Commands)
- `plugin/skills/hubnode/SKILL.md`: Gating step 5, "After a merge" and "Never".
- `plugin/skills/update/SKILL.md`, `plugin/skills/init/SKILL.md`, `plugin/skills/adopt/SKILL.md`
- `tests/smoke.sh`: a new section `merge_derived`, and the exact `.jig/` file lists.
- `marketing/FEATURES.md` (main checkout only): a `derive.sh` row, added before the feature.

## Alternatives considered
- `setup.sh` runs the generator. Rejected because it runs in every new checkout and after every
  merge: its tracked changes block `jig mark gated` and leave trunk dirty, so the next
  `jig merge` refuses. Reason is [seen: the scratch repo].
- Branches regenerate and commit, and `check.sh` checks freshness. Rejected because two
  regenerated copies merge cleanly into a wrong file, or conflict. Every stale case then costs a
  sync, a commit of the job's own and a new handoff. Reason is [seen: the scratch repo; RULES.md
  step 3, "only the job's own commits count"].
- A separate commit after the merge (the report's (a)). Rejected because a metarepo's M4 refuses
  a non-merge commit on trunk outside `.jig/`, and jig writes its own derived view into the merge
  commit, so no merge on trunk has stale derived files. Reason is [seen: `meta_rules`, `cmd_merge`].
- Named `after-merge.sh`. Rejected because a name for the moment invites the push and the PR,
  which can't run before the merge commit and are the owner's word. Reason is [assumed].
- A hubnode skill line only ("run the repo's generator after each merge"). Rejected because a
  hand step repeated per merge is what became the scripts. Reason is [assumed: the reporter's
  account; the scripts are deleted].
- A command list in `config.json`. Rejected for `release-publish.md`'s reason: shell steps read
  better as a script in `.jig/scripts/`. Reason is [assumed].

## Decisions
- `derive.sh` runs last, after jig's own writes and after `setup.sh`. So it sees the numbered ids
  and an environment built from the merged manifests.
- `setup.sh` moves from after the commit to before `derive.sh`. It still runs once per
  `jig merge`. On `jig merge`'s conflict path, `--number` now runs it. That changes
  `worktree-setup.md`'s line "whoever resolves it runs `setup.sh`" for `jig merge` only.
  `jig sync`'s hand-resolved path is unchanged.
- A failing `derive.sh` leaves the merge uncommitted rather than committing stale derived files.
  It finishes the same way a conflict does.
- What `derive.sh` writes is part of the merge commit, so the pre-merge-commit hook judges it
  along with the job's changes (P2 included).
- Order: this spec builds after `bug-merge-append-conflicts.md` (report section 1). Both change
  `cmd_merge`'s path to the commit and RULES.md step 3. Resolved appends come before `setup.sh`
  and `derive.sh`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
