# claude-skills

Repo of Claude Code skills (bof-development, bof-code-review-skill,
bof-pe-development, c2-profile-author, sccm-hacking, working-style, etc.).
`install.sh` copies each skill directory (and `agents/`) into `~/.claude/`.
BOF authoring context lives in the `bof-development` skill, not here.

# Skill Maintenance

## Assessing Review Lessons Against Skills

After completing a BOF code review that produces a lessons-learned document (e.g., `review_lessons_report.md`), assess each recommendation against the current skill content before implementing changes.

**Process:**
1. Read the lessons/recommendations from the review report
2. Read the current skill files (`SKILL.md`, `references/review-criteria.md`, etc.) for both `bof-code-review-skill` and `bof-development`
3. For each recommendation, check whether it's already implemented in the skills -- many lessons get integrated during the review itself
4. For unimplemented recommendations, assess on two axes:
   - **Value**: Does it prevent beacon crashes, memory corruption, or silent data bugs? Or is it cosmetic/process?
   - **Scope**: Is it a general BOF pattern, or specific to one project's architecture?
5. Only add items that are high-value general BOF patterns. Skip project-specific lessons, process policies, and LOW-severity cosmetic checks.

**Guard against skill bloat:**
- The review criteria already has 14 categories. Don't add new categories without strong justification.
- Prefer strengthening existing checklist items over adding new ones.
- If a recommendation is already covered by an existing check (even indirectly), skip it.
- A 2-line addition to an existing section is far preferable to a new section.
