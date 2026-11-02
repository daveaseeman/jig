# BUFFER

The sync buffer: every metarepo claim this pararepo has moved away from, one row each, made in the
commit that moves away (P2). A change of mind edits the row's middle columns. `jig release` proposes
every Open row at once; `jig sync` closes them when the metarepo releases that proposal. Ids are
B1, B2, … in order; a row keeps its id.

| Id | Metarepo claim (file § section, at the pin) | This repo now (source, commit) | Decided (who, date) | State |
|---|---|---|---|---|
