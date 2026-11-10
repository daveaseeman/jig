# <System>

<One paragraph, no heading: what this system is and why it exists.>

## <Part>

<What this part is and does on trunk today, in present tense. Name each section for a part
the code has (Schema, Renderer, Sync), never Overview, Notes or Changes. A part with files of
its own, which the rest of the system reaches only through its interfaces, is a subsystem. It
gets a folder and a page of its own once it has something to say that whoever works on it
needs and this page doesn't; this section then shrinks to a paragraph and a link. Until then it
stays a section here. A subsystem's page holds sections, not subsystems, unless the owner approved a deeper
level.>

## Talks to

<Optional; delete the section if nothing crosses the boundary. What crosses this system's
boundary: what it calls, what calls it, and what passes between them, each linked to its seam
page or contract where one exists. Calls inside the system stay in the body.>

- <Other system> — <what passes, which way>; see <seam page or contract>.

## Invariants

<Optional; delete the section if nothing qualifies. Only load-bearing facts, each with why it
must hold and what holds it: a named test, review, or on screen.>

- <Fact> — <why it must hold>; held by <test_name>.

## Undefined

<Optional, always last; delete the section if nothing is parked. Written only on the owner's
word. Nothing here binds or promises.>

- <What was parked> — stops at <where the work stops>; parked <YYYY-MM-DD>.
