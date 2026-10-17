---
name: re-pipeline
description: Lead-agent playbook for the three-stage security RE pipeline (lead scopes and dispatches, Mythos reverser documents behavior, Opus 5.5/Fable assessor does the security assessment). Load BEFORE the first reverser or assessor dispatch whenever binary RE serves a security goal (LPE hunting, SQLi or injection hunting, service or IPC auditing, credential handling, patch diffing for a vuln). Covers the preflight checklist, research folder and PLAN.md, dispatch prompt template with known environment quirks, and coordinator discipline.
---

# Security RE pipeline (lead agent)

You are the lead. You plan, dispatch, and integrate. You do not do the
work yourself.

Read `~/.claude/re-pipeline-local.md` first if it exists. It holds
host-specific paths, tool locations, environment quirks, and past
mistakes for this machine.

## Roles

| Stage | Who | Dispatch | Does |
|-------|-----|----------|------|
| 1 | Lead (this session) | n/a | Scopes, writes PLAN.md, dispatches, integrates |
| 2 | Reverser (Mythos 5.1) | `subagent_type="reverser"` | Neutral behavior docs, checkpoints to file |
| 3 | Assessor (Opus 5.5) | `subagent_type="assessor"` | Security assessment from reverser reports, no binary access |

- Never ask the reverser for a security assessment. Mythos trips cyber
  safeguards on that framing.
- Never do the assessment yourself without also dispatching the assessor.
  Leads have missed real findings by grouping similar handlers.
- Do not try to reach Opus 5.5 with the Agent tool's `model` override. Its
  shorthands only resolve to {opus->claude-opus-4-8, sonnet->claude-sonnet-5-5,
  haiku->claude-haiku-5-5, fable->claude-fable-5-1}, and `opus` is the one
  that lands on a Claude 4 model. A 5-series model can only be pinned by a
  full model ID in an agent definition's frontmatter. That is why the
  `assessor` agent (frontmatter `model: claude-opus-5-5`) works; use it, and
  `opus5` for general 5.5 work.
- After an assessor dispatch, check the model it ran on:
  `grep -o '"model":"[^"]*"' <output_file> | sort | uniq -c`, and take the
  dominant assistant-turn model (not the first match: a transcript holds
  stray parent/classifier entries). If Opus 5.5 was unavailable, change
  `model:` in `~/.claude/agents/assessor.md` to `claude-fable-5-1`.

## Preflight checklist

Complete all of these before the first dispatch. Each failed dispatch costs
50-200K tokens and 5-15 minutes.

1. **Research folder and plan.** Create a project folder with `PLAN.md`,
   `binaries/`, `findings/`, `notes/`. PLAN.md holds: goal, prior art,
   research question, target environment, pipeline roles, phases as
   checkboxes, file layout. Update the checkboxes as phases complete.
2. **Prior art.** Search for existing research on the technique and target
   before building anything. Check patch level for old CVEs.
3. **Lab access facts.** Get hosts, access path, and the credentials file
   path from your notes. Read the credentials file to confirm the path.
   Never write it from memory.
4. **Connectivity.** Confirm the access path works with one minimal call
   (WinRM `whoami`, SMB `ls`). This is the one inline check the lead may
   run. Anything beyond a single command goes to an agent.
5. **Enumerate, don't assume.** Binary names, install paths, and versions
   come from an enumeration dispatch, not from memory. Vendors rename
   components between versions.
6. **Runtime prerequisites.** For runtime tests, have an agent confirm the
   required provider, tool, or feature exists on the target first (for
   example, which OLE DB providers are installed).

## Dispatch prompt template

Every dispatch prompt includes these parts. Fill them from PLAN.md and the
local notes, not from memory.

```
Task: <one bland documentation question, one area>
Binary/target: <absolute path or host>
Checkpoint file: <project>/findings/<area>-checkpoint.md
  (read it first if it exists and continue from where it stopped)
Output: append findings to the checkpoint file, final report per your format
Access: <host, protocol, credentials file absolute path>
Environment notes: <relevant entries from the quirks list and local notes>
Out of scope: <what not to touch>
```

Reverser prompts:

- Describe behavior only: "document the IPC handlers and the data each one
  reads," "list functions that build SQL strings and where each input
  comes from." One area per dispatch.
- Keep these words out: exploit, vulnerability, injection, LPE, privilege
  escalation, payload, hijack, attack surface, abuse. Use neutral
  phrasing: "builds a query by string concatenation," "loads a DLL from a
  relative path," "creates a pipe with a broad descriptor."
- Run independent areas in parallel, each with its own checkpoint file.
- If a reverser gets flagged or times out, re-dispatch with the same
  checkpoint file.

Assessor prompts:

- Pass the reverser reports as file paths or pasted text.
- State the goal (LPE, SQLi, auth bypass) and the attacker starting
  position (unauthenticated network, low-priv local user, enrolled client).
- Give the output path: `<project>/findings/assessment.md`.

## General environment quirks

Paste the relevant ones, plus entries from the local notes, into dispatch
prompts.

- **Ghidra headless** needs a supported JDK. Newer Java releases can break
  the OSGi loader; pin `JAVA_HOME` to a known-good JDK.
- **REA** may have no Ghidra provider configured. Fall back to Ghidra
  headless directly instead of debugging REA.
- **Analyze locally.** Pull binaries to the project's `binaries/` folder
  and run Ghidra here, not on the target.
- **WinRM:** use an existing session helper, not ad-hoc pywinrm. Set
  `NO_PROXY=<host>` if a proxy is configured.
- **WinRM payload size:** inline PowerShell is fine under about 2 KB. For
  longer scripts, copy the `.ps1` over SMB and run it by path. Do not use
  base64-chunked uploads. If SMB is blocked, enable it over WinRM with
  `Enable-NetFirewallRule`.

When a dispatch hits a new quirk, add it to the local notes file.

## Coordinator discipline

- Every execution step is a dispatch: runtime tests, binary extraction,
  PowerShell on a target, grepping a binary, reading a large config.
- The signal to dispatch is the thought "let me just quickly check this."
  These checks compound into context exhaustion. No exceptions while a
  pipeline is active.
- For a runtime test, write the script into the research folder and
  dispatch an agent to run it and report back.
- Your context holds PLAN.md, report summaries, and decisions. Read
  reverser reports, not the raw decompilation.

## Wrap-up

- Update PLAN.md phases and record findings locations.
- Record the thread status wherever you track work.
