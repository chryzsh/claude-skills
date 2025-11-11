# Claude Skills Collection

Private repository for custom Claude Code skills focused on offensive security development.

## Skills

### bof-development
Develop Beacon Object Files (BOFs) for red team operations. Use when creating new BOFs from scratch, converting Python or .NET code to BOF format, generating Makefiles for BOF compilation, or debugging BOF implementations.

**Capabilities:**
- Generate BOF project scaffolding
- Convert existing code to BOF format
- Create compilation Makefiles
- Handle Windows API integration
- Cross-architecture support (x86/x64)

### oc2-bof-script-generator
Generate Python scripts for OC2 (Operator Console 2) that expose BOF functionality to the C2 agent. Converts Cobalt Strike .cna Aggressor scripts to OC2 .s1.py Python format.

**Capabilities:**
- Convert .cna files to OC2 Python format
- Parse and translate argument encoding
- Handle single and multi-BOF projects
- Preserve validation logic
- Generate proper OC2 interface scripts

## Installation

Each skill can be packaged using the skill-creator tools:

```bash
python3 /path/to/skill-creator/scripts/package_skill.py <skill-directory>
```

The resulting `.zip` file can be imported into Claude Code.

## Project Structure

```
.
├── bof-development/          # BOF development skill
│   ├── SKILL.md
│   ├── assets/               # BOF templates
│   └── references/           # BOF best practices
├── oc2-bof-script-generator/ # OC2 script generator skill
│   ├── SKILL.md
│   └── references/           # .cna and Python patterns
└── CLAUDE.md                 # Project instructions
```

## Usage

These skills are designed to work with Claude Code and assist in offensive security development workflows, specifically:
- Creating and maintaining BOF projects
- Converting BOF interfaces between different C2 frameworks
- Automating repetitive security tool development tasks

## Notes

- These skills are for authorized security testing, defensive security, CTF challenges, and educational contexts
- All development should be conducted within appropriate authorization contexts
