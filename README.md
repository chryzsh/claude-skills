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
| `simple-english` | Plain English in the spirit of ASD-STE100. Copied from the [AminBlg/SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) plugin (v2.1.0, MIT) without its hooks, so it loads on demand instead of at every session start |
| `humanizer` | Rewrite AI-sounding prose. Copied from the [blader/humanizer](https://github.com/blader/humanizer) plugin (v3.0.0, MIT) |
| `writing-clearly-and-concisely` | Strunk, The Elements of Style, as a writing skill. Copied from the elements-of-style plugin in [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) (v1.0.0, public domain) |

## Settings

`settings.json` contains a bash command allowlist/denylist. Destructive commands (`rm`, `git push --force`, `gh repo delete`, etc.) are denied. Common dev commands are auto-approved.

## Notes

These skills are for authorized security testing, defensive security, CTF challenges, and educational contexts.
