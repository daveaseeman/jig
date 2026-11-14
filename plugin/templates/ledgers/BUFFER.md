# BUFFER

The sync buffer: every metarepo claim this pararepo has moved away from, one row each, made in the
commit that moves away (P2). A row records a claim the metarepo states, even when the fix there
will be a pointer to this repo rather than new text (RULES.md: What the metarepo holds). A change
of mind edits the row's middle columns. `jig release` proposes every Open row at once; `jig sync`
closes them when the metarepo releases that proposal. A row the metarepo answered some other way
closes by `jig sync --answered`, its State then `Closed (answered in <release>: <reason>)`. Ids
are B1, B2, … in order; a row keeps its id.

| Id | Metarepo claim (`<meta>/<path> § section`, at the pin) | This repo now (source, commit) | Decided (who, date) | State |
|---|---|---|---|---|
