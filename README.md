# Claude Skills

Custom Claude Code skills and settings.

## Install

```bash
git clone git@github.com:chryzsh/claude-skills.git
cd claude-skills
./install.sh
```

This copies all skills to `~/.claude/skills/` and installs `settings.json` to `~/.claude/settings.json` (backs up any existing one). Restart Claude Code after installing.

## Skills

| Skill | Description |
|-------|-------------|
| `bof-development` | Develop Beacon Object Files for red team operations |
| `bof-code-review-skill` | Code review for BOF projects |
| `oc2-bof-script-generator` | Convert Cobalt Strike .cna scripts to OC2 Python format |
| `codex-prepush-review` | Pre-push code review using Codex CLI as a review partner |
| `sccm-hacking` | Expert on the Misconfiguration Manager project and SCCM/ConfigMgr offensive security (submodule, see [chryzsh/sccm-hacking-skill](https://github.com/chryzsh/sccm-hacking-skill)) |

## Settings

`settings.json` contains a bash command allowlist/denylist. Destructive commands (`rm`, `git push --force`, `gh repo delete`, etc.) are denied. Common dev commands are auto-approved.

## Notes

These skills are for authorized security testing, defensive security, CTF challenges, and educational contexts.
