# Claude Skills

Custom Claude Code skills and agents.

## Install

```bash
git clone git@github.com:chryzsh/claude-skills.git
cd claude-skills
./install.sh
```

This copies all skills to `~/.claude/skills/` and agents to `~/.claude/agents/`. It does not touch `~/.claude/settings.json` or `~/.claude/CLAUDE.md`. Restart Claude Code after installing.

## Skills

| Skill | Description |
|-------|-------------|
| `bof-development` | Develop Beacon Object Files for red team operations |
| `async-bof` | Write async BOFs and BOF-PEs that run on their own C2 thread (Outflank async BOF spec) |
| `bof-code-review-skill` | Code review for BOF projects |
| `oc2-bof-script-generator` | Convert Cobalt Strike .cna scripts to OC2 Python format |
| `codex-prepush-review` | Pre-push code review using Codex CLI as a review partner |
| `sccm-hacking` | Expert on the Misconfiguration Manager project and SCCM/ConfigMgr offensive security (submodule, see [chryzsh/sccm-hacking-skill](https://github.com/chryzsh/sccm-hacking-skill)) |
| `simple-english` | Plain English in the spirit of ASD-STE100. Copied from the [AminBlg/SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) plugin (v2.1.0, MIT) without its hooks, so it loads on demand instead of at every session start |
| `humanizer` | Rewrite AI-sounding prose. Copied from the [blader/humanizer](https://github.com/blader/humanizer) plugin (v3.0.0, MIT) |
| `iart` | "I ain't reading that." Summarize long text, files, or links into a short, no-fluff briefing |
| `writing-clearly-and-concisely` | Strunk, The Elements of Style, as a writing skill. Copied from the elements-of-style plugin in [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) (v1.0.0, public domain) |
| `re-pipeline` | Lead-agent playbook for security RE with the `reverser` and `assessor` agents: preflight checklist, dispatch template, coordinator rules. Reads host-specific notes from `~/.claude/re-pipeline-local.md` if present |

## Agents

`install.sh` copies `agents/*.md` to `~/.claude/agents/`.

| Agent | Description |
|-------|-------------|
| `reverser` | Mythos 5.1 RE specialist. Documents binary behavior neutrally and checkpoints to file |
| `assessor` | Opus 5.5 security assessor. Works from `reverser` reports, traces each handler's inputs to dangerous sinks |

## Notes

These skills are for authorized security testing, defensive security, CTF challenges, and educational contexts.
