# BOF Code Review Checklist Template

Use this template structure for creating review checklists. The format is **top-down**: summary and findings first, detailed audit trail at the bottom.

---

## BOF: [bof-name]

**Description**: [Brief description from README]
**Files Reviewed**: entry.c, beacon.h, Makefile
**Review Status**: ✅ Complete

### Executive Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 8 |
| 🟠 High | 4 |
| 🟡 Medium | 5 |
| 🟢 Low | 0 |

**Assessment**: Multiple stability and security issues that could crash the beacon or compromise operations.

**Recommendation**: 🔴 DO NOT USE until critical issues are fixed.

### Automated Lint Results

```
$ python3 $BOFLINT bof-name.x64.o --loader cs
[PASS] Valid entry point: go
[PASS] All relocations supported
[PASS] All imports resolvable
[PASS] No stack-probing symbols
```

### Top Findings

#### 🔴 CRITICAL (8)

**1. [API Usage] Standard library header included** `entry.c:3`

`#include <stdio.h>` pulls in standard library dependencies that are unavailable in a BOF context. The linker cannot resolve libc symbols, so this will cause load failures or undefined behavior at runtime. Remove the include and use `BeaconPrintf` for all output.

**2. [Beacon API] Using sprintf instead of BeaconPrintf** `entry.c:134`

`sprintf` is a libc function unavailable to BOFs. Output written via `sprintf` never reaches the operator console — it writes to a local buffer with no Beacon callback. Replace with `BeaconPrintf(CALLBACK_OUTPUT, ...)` which routes output through the C2 channel.

**3. [Code Efficiency] Large stack allocation** `entry.c:67`

An 8KB buffer declared on the stack (`char buf[8192]`) exceeds the 4KB-per-function guideline. Functions with >4KB stack frames trigger `__chkstk_ms`, which BOF loaders cannot resolve — this will fail at load time. Move to heap allocation via `KERNEL32$HeapAlloc`.

**4. [Memory Safety] Unchecked HeapAlloc return value** `entry.c:73`

`HeapAlloc` can return NULL if the process heap is exhausted. The returned pointer is used directly on line 75 without a NULL check, which would cause an access violation and crash the beacon. Heap allocations in BOFs should always be validated before use.

**5. [Memory Safety] Unchecked CreateFileW return value** `entry.c:145`

`CreateFileW` returns `INVALID_HANDLE_VALUE` on failure, but the handle is used directly without checking. Passing an invalid handle to `ReadFile` or `CloseHandle` causes undefined behavior. Check against `INVALID_HANDLE_VALUE` before use.

**6. [Memory Safety] Resource leak on error path** `entry.c:150-152`

The file handle opened at line 145 is not closed when the error branch at line 150 returns early. Each leaked handle persists for the beacon's lifetime and counts against the process handle limit. Use a goto-cleanup pattern to ensure handles are closed on all paths.

**7. [String & Memory Operations] Buffer overflow via strcpy** `entry.c:78`

`MSVCRT$strcpy` copies without bounds checking. If the source string exceeds the destination buffer size, it overwrites adjacent stack or heap memory — corrupting data or crashing the beacon. Use `MSVCRT$strncpy` or `MSVCRT$_snprintf` with explicit size limits.

**8. [Security] No validation on user-provided path** `entry.c:50`

The path parameter from `BeaconDataExtract` is used directly in `CreateFileW` without validation. A malformed or malicious path could access unintended files. Validate path length and characters before use.

#### 🟠 HIGH (4)

**1. [Code Efficiency] Potentially unbounded loop** `entry.c:89-112`

The enumeration loop has no iteration limit or timeout. If the target contains an unexpectedly large number of entries, the BOF blocks the beacon for the entire duration — no other tasks can execute. Add a reasonable iteration cap with a warning when reached.

**2. [String & Memory Operations] Missing wide string conversion** `entry.c:92`

User input arrives as `char*` but is passed to a Unicode API (`CreateFileW`) without conversion. This silently produces a corrupted wide string — every ASCII byte becomes a character paired with the next byte. Use `KERNEL32$MultiByteToWideChar` to convert properly.

**3. [Argument Parsing] Optional parameter not validated** `entry.c:54`

`BeaconDataExtract` is called for an optional parameter without first checking if the parser has remaining data. If the argument was not packed by the script, the parser returns stale or garbage data. Check `BeaconDataLength` before extracting optional parameters.

**4. [Security] Sensitive paths logged without redaction** `entry.c:134`

Full file paths including target-specific directory names are sent to the operator via `BeaconPrintf`. If beacon traffic is intercepted or logs are compromised, these paths reveal operational targets. Consider truncating or hashing paths in output.

#### 🟡 MEDIUM (5)

**1. [Coding Standards] Inconsistent naming conventions**

Some functions use camelCase, others use snake_case. Pick one convention and apply consistently for maintainability.

**2. [Coding Standards] Missing const correctness** `entry.c:78, 92`

Read-only pointer parameters should be marked `const` to prevent accidental modification and signal intent to future reviewers.

**3. [Documentation] Argument parsing order undocumented** `entry.c:45`

The argument parsing section extracts 3 parameters but doesn't document their expected order or types. When someone modifies the companion script, they have to reverse-engineer the parser to match.

**4. [Compiler Compatibility] Debug symbols not stripped**

The Makefile omits `--strip-unneeded`. Debug symbols increase the BOF size and may leak function/variable names to defenders analyzing memory.

**5. [Coding Standards] Missing const on read-only params** `entry.c:78, 92`

Read-only pointer parameters should be marked `const`.

### Review Coverage

| # | Category | Result | Notes |
|---|----------|--------|-------|
| 1 | Project Structure & Naming | ✅ Pass | |
| 2 | Coding Standards | 🟡 Issues | 2 medium (M1, M2) |
| 3 | Documentation | 🟡 Issues | 1 medium (M3) |
| 4 | API Usage & Declarations | 🔴 Issues | 1 critical (C1) |
| 5 | Beacon API Usage | 🔴 Issues | 1 critical (C2) |
| 6 | Code Efficiency | 🔴 Issues | 1 critical (C3), 1 high (H1) |
| 7 | Memory Safety & Stability | 🔴 Issues | 3 critical (C4, C5, C6) |
| 8 | String & Memory Operations | 🔴 Issues | 1 critical (C7), 1 high (H2) |
| 9 | Global Variables | ✅ Pass | |
| 10 | Argument Parsing | 🟠 Issues | 1 high (H3) |
| 11 | Compiler Compatibility & Build | 🟡 Issues | 1 medium (M4) |
| 12 | Task Appropriateness | ✅ Pass | Quick file enumeration |
| 13 | Conversion Quality | N/A | Original C code |
| 14 | Security Considerations | 🔴 Issues | 1 critical (C8), 1 high (H4) |

### OC2 Script Review

_No .s1.py script present — skipped._

---

### Detailed Category Breakdown

This section is the full audit trail showing every check performed per category. Findings reference the Top Findings section above.

#### 1. Project Structure & Naming

✅ PASS: BOFNAME in Makefile matches output filenames (Makefile:3)

✅ PASS: Project follows standard BOF structure

#### 2. Coding Standards

🟡 MEDIUM (M1): Inconsistent naming — some functions use camelCase, others use snake_case

🟡 MEDIUM (M2): Missing const correctness on read-only parameters (entry.c:78, 92)

✅ PASS: Good commenting on argument parsing section (entry.c:45-52)

#### 3. Documentation

✅ PASS: go() entry point has clear purpose comment (entry.c:12-14)

🟡 MEDIUM (M3): Argument parsing section should document expected order (entry.c:45)

✅ PASS: Complex string formatting logic well-commented (entry.c:120-145)

#### 4. API Usage & Declarations

✅ PASS: All Windows APIs properly declared with DECLSPEC_IMPORT (entry.c:20-35)

🔴 CRITICAL (C1): Unnecessary inclusion of stdio.h (entry.c:3)

✅ PASS: Proper use of wide string APIs (FindFirstFileW, CreateFileW)

✅ PASS: No hardcoded addresses detected

#### 5. Beacon API Usage

✅ PASS: BeaconPrintf used with correct callback types

🔴 CRITICAL (C2): Using sprintf instead of BeaconPrintf (entry.c:134)

✅ PASS: Argument parsing uses BeaconDataParse correctly (entry.c:48-52)

#### 6. Code Efficiency

✅ PASS: No unnecessary code detected

🔴 CRITICAL (C3): Large stack allocation — 8KB buffer on stack (entry.c:67)

✅ PASS: Single-threaded execution

🟠 HIGH (H1): Loop could run for extended time without limit (entry.c:89-112)

#### 7. Memory Safety & Stability

🔴 CRITICAL (C4): Unchecked return value from HeapAlloc (entry.c:73)

🔴 CRITICAL (C5): Handle not checked before use (entry.c:145)

✅ PASS: All allocated memory properly freed (entry.c:95, 102, 156)

🔴 CRITICAL (C6): File handle not closed on error path (entry.c:150-152)

#### 8. String & Memory Operations

✅ PASS: Uses MSVCRT functions for string operations

🔴 CRITICAL (C7): Potential buffer overflow — strcpy without bounds check (entry.c:78)

🟠 HIGH (H2): Should use wide string conversion for user input (entry.c:92)

#### 9. Global Variables

✅ PASS: No global variables used

#### 10. Argument Parsing

✅ PASS: Arguments parsed in correct order matching script expectations

🟠 HIGH (H3): Optional parameter not properly validated before extraction (entry.c:54)

#### 11. Compiler Compatibility & Build

✅ PASS: x64 and x86 targets in Makefile

✅ PASS: Makefile includes required libraries (iphlpapi, netapi32)

🟡 MEDIUM (M4): Debug symbols not stripped — add strip command to Makefile

#### 12. Task Appropriateness

✅ PASS: Task is appropriate for BOF implementation — quick file enumeration

#### 13. Conversion Quality

N/A — Original C code, not converted from Python/.NET

#### 14. Security Considerations

🔴 CRITICAL (C8): No validation on user-provided path parameter (entry.c:50)

🟠 HIGH (H4): Sensitive file paths logged without redaction (entry.c:134)

---

# BOF Review Summary Report

**Repository**: [repo-name]
**Review Date**: YYYY-MM-DD
**Total BOFs Reviewed**: X

## Aggregate Severity Counts

| Severity | Total | BOFs Affected |
|----------|-------|---------------|
| 🔴 Critical | 12 | 3 |
| 🟠 High | 8 | 4 |
| 🟡 Medium | 15 | 6 |
| 🟢 Low | 3 | 2 |

## Critical Issues

| BOF | Issue | Location |
|-----|-------|----------|
| bof-name | Unchecked HeapAlloc return value | entry.c:73 |
| bof-name | Missing input validation on path | entry.c:50 |
| bof-name | Buffer overflow via strcpy | entry.c:78 |
| another-bof | NULL pointer dereference risk | entry.c:89 |
| third-bof | Use-after-free in cleanup path | entry.c:201 |

## High Issues

| BOF | Issue | Location |
|-----|-------|----------|
| bof-name | Potentially unbounded loop | entry.c:89-112 |
| bof-name | Missing wide string conversion | entry.c:92 |
| another-bof | Missing bounds check on output buffer | entry.c:145 |

## Common Patterns

| Pattern | Frequency | Impact |
|---------|-----------|--------|
| Unchecked return values | 5/10 BOFs | Beacon crash on API failure |
| Stack allocations >4KB | 3/10 BOFs | Load failure (__chkstk_ms) |
| Resource leaks on error paths | 4/10 BOFs | Handle exhaustion over time |
| Missing input validation | 6/10 BOFs | Unexpected behavior or crash |

## BOFs Requiring Refactoring

1. **bof-name** — 8 critical issues, should not be used until rewritten
2. **another-bof** — 3 critical issues, needs significant work
3. **third-bof** — inappropriate for BOF, recommend execute-assembly

## Overall Security Assessment

**Status**: 🔴 REQUIRES IMMEDIATE ATTENTION

**Summary**: Multiple critical stability and security issues identified across the repository. Primary concerns are unchecked return values and missing input validation, which could crash beacons or compromise operations.

**Recommendations**:
1. Address all CRITICAL issues before operational use
2. Establish code review process for new BOFs
3. Create testing harness for stability testing
4. Implement automated static analysis via boflint in CI
