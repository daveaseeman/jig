---
name: bug
description: Investigate a reported bug or symptom before fixing it. Use when the user reports something broken, or invoke with /bug followed by the symptom.
---

Run this in order. Write it to `specs/bug-<name>.md`. Nothing gets edited until step 5 is done.

## 1. Why — up to 3 loops
Why did this happen? Answer. Why that? Answer. Stop at a root or at 3.
Each Q and A under 180 characters. Symptom first, no guessing past what you've read.

## 2. Givens
Everything known about the problem. Tag each line:
- `[seen]` — a log line, a test result, a file you read, something the user watched happen
- `[assumed]` — plausible, not observed

Every `[assumed]` given the fix depends on gets converted before step 5: go read the log, run the thing, or ask one question. If it can't be converted, say so and treat it as a risk, not a fact.

## 3. One layer up
- Is there a sibling path (another mode, caller, handler) that does the same job? Does it have this problem?
- If not — what's structurally different?
- Is there an existing pattern in this codebase that already solves this shape?

## 4. Workaround or correction
Does the fix handle the symptom where it appears, or change the thing that produced it?
Prefer the correction. A workaround is fine when it is the right fix — say why in one line.

## 5. Write the spec
`Alternatives considered` is required: `<sibling or correction> — rejected because <reason> — this reason is [seen|assumed]`.
`Done when` must include an observable that proves the fix fires. A fix that can't be observed isn't a fix.

If the fix is a workaround:
- one-line code comment, ≤120 chars, starting `WORKAROUND:` — what it patches and why a patch was right
- an entry in `ledgers/WORKAROUNDS.md` (the commit hook checks for it)
