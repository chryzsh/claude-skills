# Skill Optimizer Prompt

Use this prompt to analyze and restructure large Claude skills for better performance.

---

## The Prompt

```
You are a Claude Skill optimization expert. Analyze the provided SKILL.md file and restructure it following these principles:

## Context & Research Background

LLM performance degrades as context length increases. Research shows:
- At 32k tokens, most models drop below 50% of short-context performance
- "Lost in the middle" effect: information buried in long documents gets missed
- Instruction dilution: long/noisy instructions reduce model focus
- Each token in SKILL.md competes with conversation history and other context

Progressive disclosure architecture means:
- Only ~100 tokens load at startup (name + description)
- Full SKILL.md loads when triggered (<5k tokens ideal)
- Reference files load on-demand (no cost until accessed)

## Optimization Targets

**SKILL.md Body:**
- Target: 50-80 lines (recommended)
- Maximum: 500 lines (Anthropic's documented limit)
- Ideal tokens: <5,000

**Description field:**
- Target: <200 characters (~30 tokens)
- Must include: what it does AND when to use it

## Analysis Steps

1. **Measure current state:**
   - Count lines in SKILL.md body
   - Estimate tokens (lines × 20 = rough token count)
   - Identify redundant explanations

2. **Challenge every section:**
   - "Does Claude already know this?" (e.g., what a PDF is, how imports work)
   - "Will this change based on context?" → Move to reference file
   - "Is this step-by-step workflow?" → Keep concise version, move details to reference
   - "Are these examples essential or nice-to-have?" → Move extensive examples to reference

3. **Apply progressive disclosure:**
   - SKILL.md = Quick start + navigation to references
   - Reference files = Deep details, loaded on-demand
   - Scripts = Executable code (never loaded into context, just executed)

## Restructuring Rules

**Keep in SKILL.md:**
- Critical workflow steps (high-level)
- Essential patterns Claude MUST follow
- Brief examples (1-2 per concept)
- Links to reference files with clear "when to read" guidance

**Move to references/:**
- Detailed API references
- Extensive examples
- Edge cases and troubleshooting
- Background explanations
- Conversion tables and mappings

**Remove entirely:**
- Explanations of concepts Claude already knows
- Redundant variations of the same instruction
- Verbose prose that can be bullets
- "What is X" explanations for common technical concepts

## Output Format

Provide:
1. **Analysis summary**: Current lines, estimated tokens, identified issues
2. **Restructured SKILL.md**: The optimized main file
3. **New reference files**: If content was extracted (name them descriptively)
4. **Metrics**: Before/after line count and estimated token savings

## Restructuring Example

**Before (verbose):**
```markdown
## Argument Encoding

When encoding arguments for the BOF, you need to understand how the format string works.
The format string is found in the bof_pack() call in the .cna file. This format string
defines what types of arguments the BOF expects. Here are the format characters and their
meanings:

- The character `i` means integer, which corresponds to BOFArgumentEncoding.INT in Python
- The character `z` means narrow string (ANSI), which corresponds to BOFArgumentEncoding.STR
- The character `Z` means wide string (Unicode), which corresponds to BOFArgumentEncoding.WSTR
- The character `b` means buffer (binary data), which corresponds to BOFArgumentEncoding.BUFFER

It is critical that you match the exact order of arguments as they appear in the bof_pack()
call. If the order is wrong, the BOF will receive incorrect data and may crash or behave
unexpectedly.
```

**After (concise):**
```markdown
## Argument Encoding

Match `bof_pack()` format string exactly. Order matters.

| Format | Python Encoding |
|--------|----------------|
| `i` | INT |
| `z` | STR (narrow) |
| `Z` | WSTR (wide) |
| `b` | BUFFER |

See [references/encoding-details.md](references/encoding-details.md) for edge cases.
```

**Token reduction:** ~180 tokens → ~60 tokens (67% reduction)

---

Now analyze and optimize this skill:

<skill_content>
[PASTE SKILL.MD CONTENT HERE]
</skill_content>
```

---

## Usage

1. Copy the prompt above
2. Replace `[PASTE SKILL.MD CONTENT HERE]` with your skill's content
3. Run with Claude
4. Review the restructured output
5. Create any new reference files as suggested
6. Test the skill to ensure functionality is preserved

## Quick Self-Check Checklist

Before restructuring, ask:

- [ ] Is SKILL.md over 200 lines? → Definitely needs restructuring
- [ ] Are there paragraphs explaining what things are? → Remove/condense
- [ ] Are there more than 3 examples per concept? → Move extras to reference
- [ ] Is there a "Background" or "Overview" section over 10 lines? → Condense drastically
- [ ] Are troubleshooting steps in main file? → Move to reference
- [ ] Are there conversion tables over 10 rows? → Move to reference

## Expected Results

| Metric | Before | After |
|--------|--------|-------|
| SKILL.md lines | >300 | 50-150 |
| Estimated tokens | >6,000 | <3,000 |
| Reference files | 0-1 | 2-4 |
| Time to find key info | Scan entire doc | Jump to section |

## Notes for BOF Skills

When optimizing BOF-related skills, **keep BOF-specific patterns inline** since Claude doesn't have deep knowledge of:
- DECLSPEC_IMPORT syntax
- DLL$FunctionName naming convention
- go() entry point signature
- BeaconDataParse argument parsing
- goto cleanup pattern

These are domain-specific and must remain visible in SKILL.md.
