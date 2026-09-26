---
name: checkpoint
description: Record a work-state checkpoint in ~/share/_state/STATE.md. Use at natural checkpoints on a tracked thread (opened or merged a PR, finished or blocked an experiment, paused or resumed a thread, ended a session mid-thread), when chryzsh asks to log progress, or when starting work on a thread that has no entry yet.
---

# Checkpoint

Update the thread's section in `~/share/_state/STATE.md`.

## Procedure

1. Read `~/share/_state/STATE.md`. Find the thread's section by `Path` or slug.
2. If the section exists: update `Status`, `Updated` (today, YYYY-MM-DD), and
   `Last` (one line: what changed and where things stand now). Fix `Ref` if a
   better in-repo record now exists.
3. If it doesn't exist: add a section using the schema in the file header.
   Place new sections above any `done` threads.
4. Keep the file tidy: one section per thread, no duplicate slugs.

## Rules

- `Last` stays one line. Details belong in the in-repo record (RESEARCH_LOG.md,
  FORK_NOTES.md, CONSOLIDATED_ISSUES.md, issue trackers); `Ref` points at it.
- Client threads: name + status + a generic one-liner only. Never write
  client specifics (findings, hosts, targets, credentials) into STATE.md.
  If a fork originated from client work, "forked during an engagement to
  check X" is the most detail allowed.
- Never edit `todo.txt`, `later.txt`, or anything else in `_notes/`.
  STATE.md is the agent-writable tracker; the notes are chryzsh's.
- A finished thread gets `Status: done`, not deletion. chryzsh prunes.
- A blocked thread says why in `Last` ("blocked on X").
- Don't checkpoint trivial movement (reading a file, starting a session).
  Checkpoints are for state changes another session would want to know about.
