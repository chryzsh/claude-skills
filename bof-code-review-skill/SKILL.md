---
name: bof-code-review
description: Use when reviewing BOF code for security vulnerabilities, memory safety issues, API usage correctness, coding standards compliance, or generating security assessments - performs comprehensive security-focused code reviews of Beacon Object Files for red team operations. Identifies critical issues that could crash beacons, cause memory corruption, or compromise operational security.
---

# BOF Code Review

This skill provides a systematic framework for reviewing Beacon Object Files (BOFs) with emphasis on security, stability, and operational safety.

## Core Review Workflow

### Step 1: Initialize Review

Create a new branch and generate initial BOF inventory:

1. Create review branch: `git checkout -b bof-code-review`
2. Scan repository for BOF projects (look for `entry.c` files or Makefiles with BOFNAME)
3. Generate checklist with BOF names and descriptions from README

### Step 2: Review Each BOF

For each BOF, systematically evaluate against all criteria in `references/review-criteria.md`.

**Critical priority order:**
1. **Memory Safety & Stability** - Crashes kill the beacon
2. **API Declarations** - Incorrect usage causes runtime failures
3. **Task Appropriateness** - Some operations shouldn't be BOFs
4. **Code Efficiency** - Stack/execution time constraints

### Step 3: Document Findings

Use priority markers for all findings:
- 🔴 **CRITICAL**: Security vulnerabilities, crashes, memory corruption
- 🟠 **HIGH**: Significant code quality issues
- 🟡 **MEDIUM**: Best practice improvements
- 🟢 **LOW**: Minor style suggestions
- ✅ **PASS**: Meets requirements

**Always include:**
- File and line number references
- Specific explanation of the issue
- Blank lines between each finding for readability

### Step 4: Generate Summary Report

After reviewing all BOFs, create summary including:
- Total BOFs reviewed
- Issue breakdown by priority (counts and lists)
- Common patterns needing improvement
- BOFs requiring refactoring
- Overall security assessment

## Review Criteria Reference

For detailed review criteria, see `references/review-criteria.md`.

**High-level categories:**
1. Project Structure & Naming
2. Coding Standards
3. Documentation
4. API Usage & Declarations
5. Beacon API Usage
6. Code Efficiency
7. Memory Safety & Stability (CRITICAL)
8. String & Memory Operations
9. Global Variables
10. Argument Parsing
11. Compiler Compatibility & Build
12. Task Appropriateness
13. Conversion Quality (Python/.NET)
14. Security Considerations

## Critical BOF Constraints

**Always verify:**
- Main source file named `entry.c` (MANDATORY)
- All APIs declared with `DECLSPEC_IMPORT`
- No standard library functions (printf, malloc)
- Stack usage ≤1MB (preferably ≤4KB per function)
- All return values checked before use
- All allocated memory freed before returning
- Single-threaded execution only
- Short execution time (BOFs block beacon)

**Remember:** BOFs execute in-process. Crashes kill the beacon.

## Output Format

Create `bof_review_checklist.md` with this structure:

```markdown
# BOF Code Review Checklist

## BOF: [name]
**Description**: [from README]
**Status**: [✅ Complete / 🔄 In Progress / ⏸️ Not Started]

### Findings

🔴 CRITICAL: [Issue description] (file.c:line)

🟠 HIGH: [Issue description] (file.c:line)

✅ PASS: [What passed] (file.c:line-range)
```

## Common Issues to Watch For

**Memory Safety:**
- Unchecked return values from HeapAlloc, CreateFile, etc.
- NULL pointer dereferences
- Buffer overflows in string operations
- Memory leaks (allocated but not freed)
- Resource leaks (handles not closed)

**API Usage:**
- Missing DECLSPEC_IMPORT declarations
- Standard library headers included (stdio.h, stdlib.h)
- Wrong string types (char* vs wchar_t*)
- Hardcoded addresses or magic numbers

**BOF Constraints:**
- Large stack allocations (>4KB buffers)
- Long-running operations (loops, network waits)
- Multi-threaded operations
- GUI operations

## Best Practices Reference

For BOF development best practices and conversion patterns, see `references/bof-best-practices.md`.

## Troubleshooting

**Review taking too long:**
- Focus on critical sections first (memory safety, API usage)
- Batch similar issues together
- Use automated tools for initial scan if available

**Uncertain about severity:**
- Default to higher severity for memory/stability issues
- CRITICAL: Could crash beacon or compromise security
- HIGH: Will likely cause problems in production
- MEDIUM: Should be fixed but not urgent
- LOW: Nice to have improvements

**Missing context:**
- Check README for BOF purpose and usage
- Look for related .cna or .py scripts for argument format
- Review Makefile for library dependencies
