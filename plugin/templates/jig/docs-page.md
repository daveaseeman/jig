# <System>

<One paragraph, no heading: what this system is and why it exists.>

## <Section>

<What this section's code is and does on trunk today, in present tense: never when or in what order it
will change, and no spec, phase or scope, which are .jig/roadmap.md's. Name each section for what
the code has (Schema, Renderer, Sync), never Overview, Notes or Changes. A section whose code has files of
its own, which the rest of the system reaches only through its interfaces, is a subsystem. It
gets a page of its own once it has something to say that whoever works on it
needs and this page doesn't; this section then shrinks to a paragraph and a link. Until then it
stays a section here. A subsystem's page holds sections, not subsystems, unless the owner approved a deeper
level. Point only at docs: a term as docs/glossary.md § <term>, never the README or another root
document. The glossary itself is no system's page, and takes none of this skeleton.>

## Talks to

<Optional; delete the section if nothing crosses the boundary. What crosses this system's
boundary: what it calls, what calls it, and what passes between them, each linked to its seam
page or contract where one exists. Calls inside the system stay in the body.>

- <Other system> — <what passes, which way>; see <seam page or contract>.

## Invariants

<Optional; delete the section if nothing qualifies. Only load-bearing facts, each with why it
must hold and what holds it: a named test, review, or on screen.>

- <Fact> — <why it must hold>; held by <test_name>.
