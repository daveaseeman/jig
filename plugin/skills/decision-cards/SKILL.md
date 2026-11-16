---
name: decision-cards
description: Put one or more pending decisions to the owner as a decision card - one block per decision with a recommended option, Elaborate and Hold on each, one combined reply - or as numbered text where the host can't draw a card. Use when the hubnode or a jig command (/jig:rig) has decisions waiting on the owner's word. Not for a subnode's questions (those go to the hubnode) or for anything that isn't a decision.
---

A decision card puts the owner's pending decisions in one place, the same way every time, and
turns the owner's picks into one reply. The card only fills the reply; the owner's sent reply
is the answer.

## The card

- **One block per decision.** A line naming what it's about, a line of context, then the
  options as buttons, with one marked recommended.
- **Two small standing buttons on each block's right: Elaborate and Hold.** Elaborate fills
  `on <decision>: show me these options with more context`; Hold fills
  `on <decision>: hold until I can provide more context`. Either counts as that block's answer,
  in place of its options. Clicking a selected button again clears it.
- **Picks only change the card.** A preview line shows the combined reply as the owner picks.
  One "Fill reply" button at the bottom writes it once, the blocks' answers joined with
  `; and`. Not ", and": answers carry their own commas and "and"s.
- **Fill, never send.** The host's button writes into the owner's reply box and appends to
  what is there. So the button says "Fill reply", the hint says to press Enter, and nothing on
  the card claims to send.
- **The sent reply is the answer, not the card.** A card can go stale. Before acting on a
  reply, check the current state it decides (the board, the staged file, the job); if it moved,
  say what changed and ask again. A filled reply the owner hasn't sent is no answer.

Each option's label is the reply text for that block, so it reads as an answer on its own:
"merge auth-retry now", not "Yes".

## Where the host can't draw a card

In a terminal, or a host with no inline visual tool, send the same blocks as text: numbered
decisions, lettered options, the recommended one marked, and the two standing answers named.

```
1. Merge auth-retry — gated, check passed on 4f2c1a0.
   a. merge now (recommended)
   b. wait for the cache job
   Or: elaborate, hold.
2. Release 0.14.0 — three merges since 0.13.0.
   a. release after the merge (recommended)
   b. hold the release
   Or: elaborate, hold.
Reply like: 1a; and 2 hold
```

Read a reply like "1b; and 2 hold" back through the same numbers and letters, then check the
current state as above before acting.

## A working card

HTML using only the host's theme variables, the host's `sendPrompt` for the fill, and no
external scripts. Replace the `decisions` array; everything else stays.

```html
<div id="dc" style="display:flex; flex-direction:column; gap:12px; padding:0.5rem 0;">
  <div id="dc-blocks" style="display:flex; flex-direction:column; gap:12px;"></div>
  <div style="border-top:0.5px solid var(--border); padding-top:12px; display:flex; flex-direction:column; gap:8px;">
    <div style="font-size:13px; color:var(--text-secondary);">Reply: <span id="dc-preview" style="color:var(--text-primary);">pick an answer above</span></div>
    <div style="display:flex; align-items:center; gap:12px;">
      <button type="button" id="dc-fill">Fill reply ↗</button>
      <span style="font-size:12px; color:var(--text-muted);">Fills your reply box. Press Enter to send.</span>
    </div>
  </div>
</div>
<script>
const decisions = [
  { name: "merge auth-retry", context: "Gated; the check passed on 4f2c1a0.",
    options: ["merge auth-retry now", "wait for the cache job"], recommended: 0 },
  { name: "release 0.14.0", context: "Three merges since 0.13.0.",
    options: ["release 0.14.0 after the merge", "hold the release"], recommended: 0 }
];
const standing = {
  Elaborate: d => `on ${d}: show me these options with more context`,
  Hold: d => `on ${d}: hold until I can provide more context`
};
const picks = decisions.map(() => null);
const blocks = document.getElementById("dc-blocks");
const preview = document.getElementById("dc-preview");

function button(label, small) {
  const b = document.createElement("button");
  b.type = "button";
  b.textContent = label;
  if (small) b.style.cssText = "font-size:12px; padding:2px 8px;";
  return b;
}
function mark(b, on) {
  b.setAttribute("aria-pressed", on ? "true" : "false");
  b.style.background = on ? "var(--bg-accent)" : "";
  b.style.color = on ? "var(--text-accent)" : "";
  b.style.borderColor = on ? "var(--border-accent)" : "";
}
function reply() {
  return picks.filter(p => p !== null).join("; and ");
}
function render() {
  blocks.querySelectorAll("button[data-i]").forEach(b => {
    mark(b, picks[+b.dataset.i] === b.dataset.answer);
  });
  preview.textContent = reply() || "pick an answer above";
}

decisions.forEach((d, i) => {
  const block = document.createElement("div");
  block.style.cssText = "border:0.5px solid var(--border); border-radius:12px; padding:12px 16px; display:flex; gap:12px;";
  const main = document.createElement("div");
  main.style.cssText = "flex:1; min-width:0; display:flex; flex-direction:column; gap:6px;";
  const title = document.createElement("div");
  title.style.cssText = "font-size:14px; font-weight:500; color:var(--text-primary);";
  title.textContent = `${i + 1}. ${d.name}`;
  const context = document.createElement("div");
  context.style.cssText = "font-size:13px; color:var(--text-secondary);";
  context.textContent = d.context;
  const row = document.createElement("div");
  row.style.cssText = "display:flex; flex-wrap:wrap; gap:8px;";
  d.options.forEach((o, k) => {
    const b = button(k === d.recommended ? `${o} (recommended)` : o, false);
    b.dataset.i = i; b.dataset.answer = o;
    row.appendChild(b);
  });
  main.append(title, context, row);
  const side = document.createElement("div");
  side.style.cssText = "display:flex; flex-direction:column; gap:6px; align-items:flex-end;";
  Object.entries(standing).forEach(([label, text]) => {
    const b = button(label, true);
    b.dataset.i = i; b.dataset.answer = text(d.name);
    side.appendChild(b);
  });
  block.append(main, side);
  blocks.appendChild(block);
});

blocks.addEventListener("click", e => {
  const b = e.target.closest("button[data-i]");
  if (!b) return;
  const i = +b.dataset.i;
  picks[i] = picks[i] === b.dataset.answer ? null : b.dataset.answer;
  render();
});
document.getElementById("dc-fill").addEventListener("click", () => {
  const text = reply();
  if (!text) { preview.textContent = "pick an answer first"; return; }
  sendPrompt(text);
});
render();
</script>
```
