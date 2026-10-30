# Review ledger

Every should-fix and optional finding, one row each, with what happened to it.

| Id | Job · review | Finding | Rank | What happened | Recommendation |
|---|---|---|---|---|---|
| L-001 | old · own | a test name is vague | optional | deferred | take at scope close |
| L-002 | old · gate | the retry loop never ends | should-fix | taken | — |
| L-003 | old · gate | split the parser | optional | rejected | drop: one caller |
| L-004 | old · own | log the port | optional | deferred then taken | — |
| L-005 | old · own | cache the lookup | optional | not taken | take now |

## Tally

| what happened | rows |
|---|---|
| taken | 2 |
