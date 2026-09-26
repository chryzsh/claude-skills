---
name: assistant
description: Answer cross-project status questions about chryzsh's work on this VM - "what's the status of X", "where was I on Y", "is anything still running on Z", "what's the state of the lab". Use when asked about work state, thread status, where a project lives, or which tmux pane has what open. Reads shared state plus lab notes; never reads client project contents.
---

# Assistant

The read side of the work-state system. Answers "where am I" questions across
all of chryzsh's parallel threads without re-deriving context from scratch.

## Sources, in order of authority

1. `~/share/_state/STATE.md` - cross-thread status (what/why/status per thread)
2. `~/share/_state/facts.md` - stable facts (VM layout, lab topology, access)
3. `_notes/sccm/` - lab topology and research evidence. Fair game to read and
   cite as reference. Never edit anything in `_notes/` (todo.txt, later.txt,
   and the rest are chryzsh's personal notes).
4. The thread's own in-repo records, pointed at by `Ref` (RESEARCH_LOG.md,
   FORK_NOTES.md, CONSOLIDATED_ISSUES.md, CLAUDE.md/AGENTS.md in the repo).
5. Live tmux state, for "is it open / where is it" questions.

## Tmux cross-check

When the question is about where something is running or whether a pane is
already open, cross-check live panes against the thread's `Path`:

```
tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} #{pane_current_path} #{pane_current_command}"
```

Match `pane_current_path` against the thread's `Path`. Report both the last
known status (from STATE.md) and whether a live pane is open on it, so the
answer is actionable, not just historical.

Caveat (noted for review, may change): a tmux pane's `pane_current_path` is
wherever that shell last was, not proof the thread is actively being worked
on. A pane open in the right directory is a hint, not confirmation. Say so if
the match is ambiguous rather than asserting the thread is "live".

## Hard rules

- Never read, list, `grep`, or summarize anything under `~/share/projects/`
  unless chryzsh explicitly asks for it in the current session. Client
  threads in STATE.md are name + status only; that's all you report about them.
- Never edit `_notes/`, `todo.txt`, or `later.txt`. Read-only.
- Answer from the state files first. Only shell out (tmux, `git status`,
  reading a `Ref` record) to confirm current state when the question needs it.
- If a thread isn't in STATE.md, say so. Offer to checkpoint it if chryzsh
  wants it tracked; don't silently invent an entry.
