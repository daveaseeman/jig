---
name: send
description: Show the reply to a relayed hubnode question in an approval window the owner edits and sends, then write it as one message into that repo's .jig/inbox/. Use on "/jig:send", typed by the owner once a /jig:relay thread is settled.
disable-model-invocation: true
---

`/jig:send` answers a thread `/jig:relay` opened. The owner's sent reply is the approval:
nothing is written before it.

## Which thread

One open thread: that one. Several: ask which, naming each by repo and the question's first
words. None: ask which repo the reply is for, found as `/jig:relay` finds one (`jig repos which`).

## The approval window

Draft the reply first. The owner's own words appear only as
`The owner, <YYYY-MM-DD>: "<exact words>"`, the date the owner said them; everything else is
plain text from you, with no headings about whose words they are. Quote only what the owner
said in this conversation, word for word. Then show a decision card (`/jig:decision-cards`,
"An editable-text block"):

- the repo at the top: `To <repo>'s hubnode`;
- the hubnode's question, quoted;
- the reply, in an editable text field;
- one button, **Fill reply**, that fills `send to <repo>:` followed by the field's text.

The button only fills the owner's reply box. The owner sends that reply, or edits it and sends.
Where no card can be drawn, show the reply in a fenced block and say: reply `send to <repo>:`
followed by the text, as it stands or as you edit it.

## Writing the message

Only once the owner has sent `send to <repo>: <text>`:

1. Find the repo's path with `jig repos which <repo>`, as `/jig:relay` does. Request access to exactly
   `<repo>/.jig/inbox/` with the host's folder-access tool (in the Claude desktop app,
   `request_directory`). If the host has no such tool, ask the owner to add the folder. If the
   repo has no `.jig/inbox/`, say so and suggest `/jig:update` in that repo; don't create it.
2. Write `<repo>/.jig/inbox/<YYYY-MM-DD>-<slug>.md`, the slug a few words of the question,
   never overwriting a file there:

   ```yaml
   ---
   inbox: true
   to: <the repo's name or alias, as jig repos lists it>
   from: <this session, free text, as a staged file's source>
   sent: <YYYY-MM-DD HH:MM>
   ---
   ```

   Then the body: the hubnode's question as a `>` quote, a blank line, then the sent text
   exactly as the owner sent it, the `send to <repo>:` prefix removed.
3. Check it with the plugin's copy:

   ```sh
   python3 "${CLAUDE_PLUGIN_ROOT}/templates/jig/jig.py" inbox check <file>
   ```

   Fix what it names and check again. Say it is sent, with the path, only once it passes.

The thread is then closed. The owner's next prompt in that repo's hubnode session announces
the message, and the hubnode reads it with `jig inbox`.
