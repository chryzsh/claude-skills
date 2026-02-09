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

### Step 1.5: Automated Lint Check (boflint) - REQUIRED

**This step is MANDATORY.** Do not skip linting and proceed directly to manual review.

**boflint.py location:** `~/.claude/skills/bof-development/assets/boflint.py`

```bash
# Set boflint path
BOFLINT=~/.claude/skills/bof-development/assets/boflint.py

# Compile BOFs first if needed
make all

# Run boflint on compiled BOF
python3 $BOFLINT mybof.x64.o --loader cs    # For Cobalt Strike
python3 $BOFLINT mybof.x64.o --loader oc2   # For OC2
python3 $BOFLINT mybof.x64.o --loader any   # Check all loaders

# Verbose output shows all sections/symbols/relocations
python3 $BOFLINT mybof.x64.o --loader cs -v
```

**boflint checks:**
- ✅ Valid entry point (`go` or `sleep_mask`)
- ✅ Supported relocation types for target loader
- ✅ Resolvable imports (DFR format or recognized implant functions)
- ✅ No stack-probing symbols (`___chkstk_ms` = stack variable too large)
- ✅ No unsupported exception handling

**Lint errors are HIGH/CRITICAL priority** - fix before proceeding with manual review.

**If boflint.py is not found:** Check `~/.claude/skills/bof-development/assets/` or download from https://github.com/Cobalt-Strike/bof-vs/blob/main/BOF-Template/utils/boflint.py

### Step 2: Review Each BOF

For each BOF, systematically evaluate against all criteria in `references/review-criteria.md`.

**Critical priority order:**
1. **Memory Safety & Stability** - Crashes kill the beacon
2. **API Declarations** - Incorrect usage causes runtime failures
3. **Task Appropriateness** - Some operations shouldn't be BOFs
4. **Code Efficiency** - Stack/execution time constraints

### Step 3: Document Findings

Use priority markers for all findings:
- 🔴 **CRITICAL**: Will crash the beacon, corrupt memory, or fail at load/runtime
- 🟠 **HIGH**: Will cause incorrect behavior, data loss, or significant OPSEC risk in production
- 🟡 **MEDIUM**: Real bug or unsafe pattern that doesn't manifest in current code but would under reasonable future changes
- 🟢 **LOW**: Style, naming, or documentation improvement with no functional impact
- ✅ **PASS**: Meets requirements

**Severity calibration — the "would it break?" test:**
Before assigning any severity, ask: *what actually goes wrong?* Trace the code path. If the answer is "nothing goes wrong because another function handles it" or "this is a standard pattern used across the repo," it's not a finding — it's a PASS. A finding must describe a concrete failure mode, not a hypothetical one that the code already prevents.

**Zero findings is a valid outcome.** Clean code exists. Do not inflate severity or manufacture findings to fill the report. A review that reports "0 issues found" for a well-written BOF is more useful than one that scrapes up cosmetic non-issues and labels them MEDIUM. If the only findings are style preferences or "could rename this variable," either report them as LOW or drop them entirely.

**Always include:**
- File and line number references
- Specific explanation of the issue — what *actually goes wrong*, not what *looks inconsistent*
- Blank lines between each finding for readability

### Step 3.5: Remediation Refresh (after fixes are applied)

If fixes have been applied since the initial review:
1. Re-read all modified files -- do NOT rely on the original checklist as source of truth
2. Re-run `make clean && make` and boflint to confirm fixes compile cleanly
3. Update checklist to reflect current state, marking resolved items and flagging any regressions
4. Check for same-class issues that may have been missed (e.g., `BytesToHex` fixed but `HexToBinary` has the same bug)

**Why:** Reviewers develop blind spots within a single pass. The same pattern can be fixed in one function and missed in another. A stale checklist documents the wrong snapshot.

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

Create `bof_review_checklist.md` using a **top-down** structure: summary first, findings front-and-center, passes compressed into a table. The output serves two audiences: an LLM that will auto-fix issues (needs exact locations, clear problem statements) and a human learner (needs reasoning, not just the verdict).

For the full template with examples, see `references/example-checklist.md`.

### Per-BOF Review Structure (7 sections, in order)

#### 1. Header
BOF name, description, files reviewed, review status — same metadata block as today.

#### 2. Executive Summary
Moves to the top so readers immediately know the verdict.
- Severity counts as a compact table
- Overall assessment: one sentence
- Recommendation: GO / FIX REQUIRED / DO NOT USE

#### 3. Automated Lint Results
boflint output per architecture (x64, x86). Keep current format — already compact.

#### 4. Top Findings
**Only actual issues.** Grouped by severity (critical → low). This is the star of the review.

```markdown
### 🔴 CRITICAL (N)

**1. [Category] Short title** `entry.c:73`

Description of what's wrong and *why it matters*. Enough context that an LLM
can locate and fix the issue, and a human reader understands the risk.
```

Each finding has:
- **Number within severity group** — referenceable ("Critical #3")
- **Category tag in brackets** — which review area it came from
- **Short title** — scannable, ~5 words describing the issue
- **File:line as inline code** — precise location for LLM fixing
- **Description paragraph** — explains *why*, not just *what*: the consequence (crash? leak? OPSEC risk?) and the fix direction without being prescriptive

#### 5. Review Coverage
Replaces individual PASS lines with a compact table — one row per category:

```markdown
| # | Category                     | Result     | Notes                    |
|---|------------------------------|------------|--------------------------|
| 1 | Project Structure & Naming   | ✅ Pass    |                          |
| 7 | Memory Safety & Stability    | 🟡 Issues | 1 critical (Finding C1)  |
```

- **Pass** for clean categories
- **Issues** with severity + count + cross-reference to findings for categories with problems
- **N/A** for inapplicable categories (e.g., Conversion Quality for original BOFs)

#### 6. OC2 Script Review
Brief section for .s1.py script validation — argument order, encoding, help text. Omit if no script exists.

#### 7. Detailed Category Breakdown
Full per-category listing with all findings and passes. Same content as today but relocated to the bottom after the important stuff. Always visible (not collapsible), serves as the audit trail showing what was checked. Clearly separated with a heading so readers know this is supplementary detail.

### Summary Report Structure (multi-BOF)

Same top-down philosophy. Use tables instead of nested bullet lists:
- Aggregate severity counts table (with "BOFs Affected" column)
- Critical issues table (BOF, issue, location)
- High issues table
- Common patterns table (pattern, frequency, impact)
- BOFs requiring refactoring list
- Overall security assessment

## Common Issues to Watch For

**Memory Safety:**
- Unchecked return values from HeapAlloc, CreateFile, etc.
- NULL pointer dereferences
- Buffer overflows in string operations
- Memory leaks (allocated but not freed)
- Resource leaks (handles not closed)
- Unsigned integer underflow in loop bounds (`DWORD val - constant` wraps when `val < constant`)
- UTF-16LE paired-byte reads that only bounds-check the first byte

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
- Run `boflint.py` first to catch obvious issues automatically
- Focus on critical sections first (memory safety, API usage)
- Batch similar issues together

**Uncertain about severity:**
- Trace the actual code path before assigning severity — don't guess
- CRITICAL: *Will* crash beacon, corrupt memory, or fail at runtime
- HIGH: *Will* cause incorrect behavior or OPSEC risk in production
- MEDIUM: Real bug that doesn't manifest now but would under reasonable changes
- LOW: Style or documentation — no functional impact
- If you can't articulate what *actually breaks*, downgrade or drop it

**Missing context:**
- Check README for BOF purpose and usage
- Look for related .cna or .py scripts for argument format
- Review Makefile for library dependencies

## Multi-Pass Review Guidance

For complex BOFs (RPC, LDAP, crypto, multi-file), use at least two independent review passes. A single reviewer develops blind spots -- same-class issues get fixed in one function and missed in another. A second pass with fresh eyes catches issues the first pass normalized.

When debugging LDAP/RPC failures during review, request temporary diagnostic instrumentation (error codes, `ldap_err2stringA`, search base/filter). Require that debug instrumentation be isolated in its own commit for clean revert after diagnosis.
