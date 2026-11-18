# Decisions and changes

This log follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/) plus decision entries, and versions follow Semantic Versioning (https://semver.org/).
A breaking change is one that a reader taking the release must act on, and it is released as a major version.

## Open

## Unreleased

### Fixed
- A metarepo gets a generated block of its rules in its always-loaded agent instructions, as a pararepo gets its header: `jig init --meta` writes it, and `jig update` lists it when it is missing or older. A metarepo set up before this writes it in a job, with `jig init --meta` in the job's worktree, and removes the lines it wrote by hand for those rules, which update lists as the repo's procedure.

## v0.14.0 - 2026-11-16
