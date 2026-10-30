# Bug: `/jig:feedback` doesn't show up in the slash-command list

## 1. Why
- Why isn't it listed? The installed plugin is 0.3.0, where `feedback` still has
  `disable-model-invocation: true`. The fix (48b6407) is committed but not released.
- Why does that flag hide it? The app's list of this session's slash commands left out every jig
  skill with the flag, and only those: adopt, feedback, init, repos, survey, update.
- Why did typing it once do nothing? That message didn't start with it ("I want ai-dev …
  /jig:feedback …"), so it arrived as plain text, not a command.

## 2. Givens
- `[seen]` Installed copy (`…/rpm/plugin_01LNA…/`): version 0.3.0. Seven skills carry the flag:
  adopt, feedback, init, release, repos, survey, update.
- `[seen]` This session's "slash commands available" list named jig's brief, bug, hardware,
  hubnode, retro, review, stage, subnode and verify: the unflagged ones, none of the flagged.
- `[seen]` Typed in full at the start of a message, a flagged skill still runs: `/jig:update`
  and `/jig:adopt` arrived here as commands.
- `[seen]` The earlier `/jig:feedback` came mid-message and arrived as plain text.
- `[seen]` 48b6407 removes the flag from `feedback` only. It is on `main`, not in any release.
- `[assumed]` The app's slash menu hides the same skills its command list leaves out. The fix
  doesn't depend on this: the flag is gone either way. To confirm, check whether
  `/jig:update` shows in the menu today.

## 3. One layer up
The six other flagged skills have the same problem: they're missing from the list, and they
run only when typed in full. Five of them are flagged on purpose, because each one changes the
repo or tags (init, adopt, update, release, repos). `survey` changes nothing, like `feedback`.

## 4. Correction
Release 48b6407: `feedback` loses the flag, so it's listed and the model can run it. Give
`survey` the same treatment, since it is read-only too. The five that change things stay
flagged, and the README says they're typed in full.

## 5. Spec

### Done when
- [x] `grep -l disable-model-invocation plugin/skills/*/SKILL.md` lists exactly adopt, init,
      release, repos, update.
- [x] Smoke: no skill whose description says it changes nothing carries the flag (feedback,
      survey).
- [x] README's usage section says `/jig:init`, `/jig:adopt`, `/jig:update`, `/jig:release` and
      `/jig:repos` are typed in full at the start of a message, and why.
- [ ] After installing the release, `/jig:feedback` and `/jig:survey` show in the slash list.

### Touches
`plugin/skills/survey/SKILL.md`, `README.md`, `tests/smoke.sh`, and a release.

### Alternatives considered
- Drop the flag from all seven. Rejected: the model could then start `init`, `adopt`,
  `update`, `release` or `repos` on its own, and each changes the repo, tags or writes user
  config. The flag exists for that. `[seen]`: the update and release skills.
- Keep `feedback` flagged and change RULES.md to "ask the user". Rejected in
  `bug-hook-modes.md`: the agent hit exactly that wall. `[seen]`: the report.

### Open
- Should `repos` stay flagged? It writes only `~/.config/jig/repos.json`, outside any repo.

### Decisions
- Build, Oct 30. Done as written. `repos` stays user-only until the owner says otherwise.
  Smoke 264 PASS; the smoke case checks that the user-only set is exactly adopt, init, release,
  repos and update. The last box waits for the release.
