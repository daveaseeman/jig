# Decisions and changes

This log follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/) plus decision entries, and versions follow Semantic Versioning (https://semver.org/).
A breaking change is one that a reader taking the release must act on, and it is released as a major version.

## Open

## Unreleased

### Fixed
- A metarepo gets a generated block of its rules in its always-loaded agent instructions, as a pararepo gets its header: `jig init --meta` writes it, and `jig update` lists it when it is missing or older. A metarepo set up before this writes it in a job, with `jig init --meta` in the job's worktree, and removes the lines it wrote by hand for those rules, which update lists as the repo's procedure.

### Changed
- Pages describe the product only: how the repository is worked has its homes, by one test in `.jig/RULES.md` (Homes), and the rest of it goes to `.jig/process.md`, created on first use with a pointer line in the always-loaded rules file naming when to read which section (a repo already on jig adds that line itself; only jig's template has it). `jig survey` and `jig update` now list a page line naming a `.jig/` path other than the decision log, and an invariant held by review: move each line to its home, and give each such invariant a named test or what is seen on screen, or move it to the body.

## v0.14.0 - 2026-11-16
