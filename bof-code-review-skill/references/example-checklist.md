# BOF Code Review Checklist Template

Use this template structure for creating review checklists.

---

## BOF: [bof-name]

**Description**: [Brief description from README]

**Review Status**: ⏸️ Not Started / 🔄 In Progress / ✅ Complete

### 1. Project Structure & Naming

🔴 CRITICAL: Main source file is NOT named entry.c (found: main.c) - MUST rename to entry.c

✅ PASS: BOFNAME in Makefile matches output filenames (entry.c:makefile:3)

✅ PASS: Project follows standard BOF structure

### 2. Coding Standards

🟡 MEDIUM: Inconsistent naming - some functions use camelCase, others use snake_case

✅ PASS: Good commenting on argument parsing section (entry.c:45-52)

🟡 MEDIUM: Missing const correctness on read-only parameters (entry.c:78, 92)

### 3. Documentation

✅ PASS: go() entry point has clear purpose comment (entry.c:12-14)

🟡 MEDIUM: Argument parsing section should document expected order (entry.c:45)

✅ PASS: Complex string formatting logic well-commented (entry.c:120-145)

### 4. API Usage & Declarations

✅ PASS: All Windows APIs properly declared with DECLSPEC_IMPORT (entry.c:20-35)

🔴 CRITICAL: Unnecessary inclusion of stdio.h (entry.c:3) - BOFs should NOT include standard library headers. Remove this and use BeaconPrintf instead.

✅ PASS: Proper use of wide string APIs (FindFirstFileW, CreateFileW)

✅ PASS: No hardcoded addresses detected

### 5. Beacon API Usage

✅ PASS: BeaconPrintf used with correct callback types

🔴 CRITICAL: Using sprintf instead of BeaconPrintf (entry.c:134) - must use Beacon APIs for output

✅ PASS: Argument parsing uses BeaconDataParse correctly (entry.c:48-52)

### 6. Code Efficiency

✅ PASS: No unnecessary code detected

🔴 CRITICAL: Large stack allocation detected - 8KB buffer on stack (entry.c:67). Move to heap using HeapAlloc.

✅ PASS: Single-threaded execution

🟠 HIGH: Loop could potentially run for extended time (entry.c:89-112) - consider timeout or iteration limit

### 7. Memory Safety & Stability

🔴 CRITICAL: Unchecked return value from HeapAlloc (entry.c:73) - could cause NULL pointer dereference. Must check for NULL before use.

🔴 CRITICAL: Handle not checked before use (entry.c:145) - CreateFileW could return INVALID_HANDLE_VALUE

✅ PASS: All allocated memory properly freed (entry.c:95, 102, 156)

🔴 CRITICAL: File handle not closed on error path (entry.c:150-152) - resource leak

### 8. String & Memory Operations

✅ PASS: Uses MSVCRT functions for string operations

🔴 CRITICAL: Potential buffer overflow - strcpy without bounds check (entry.c:78)

🟠 HIGH: Should use wide string conversion for user input (entry.c:92)

### 9. Global Variables

✅ PASS: No global variables used

### 10. Argument Parsing

✅ PASS: Arguments parsed in correct order matching script expectations

🟠 HIGH: Optional parameter not properly validated before extraction (entry.c:54)

### 11. Compiler Compatibility & Build

✅ PASS: x64 and x86 targets in Makefile

✅ PASS: Makefile includes required libraries (iphlpapi, netapi32)

🟡 MEDIUM: Debug symbols not stripped - add strip command to Makefile

### 12. Task Appropriateness

✅ PASS: Task is appropriate for BOF implementation - quick file enumeration

### 13. Conversion Quality

N/A - Original C code, not converted from Python/.NET

### 14. Security Considerations

🔴 CRITICAL: No validation on user-provided path parameter (entry.c:50) - could lead to path traversal

🟠 HIGH: Sensitive file paths logged without redaction (entry.c:134)

---

## Summary for [bof-name]

**Total Issues**: 8 Critical, 4 High, 5 Medium, 0 Low

**Critical Issues Requiring Immediate Fix**:
1. Remove stdio.h inclusion (entry.c:3)
2. Move large buffer to heap (entry.c:67)
3. Check HeapAlloc return value (entry.c:73)
4. Check CreateFileW return value (entry.c:145)
5. Fix resource leak on error path (entry.c:150-152)
6. Fix buffer overflow in strcpy (entry.c:78)
7. Add input validation for path parameter (entry.c:50)
8. Replace sprintf with BeaconPrintf (entry.c:134)

**Recommendation**: 🔴 DO NOT USE until critical issues are fixed. Multiple stability and security problems that could crash beacon or compromise operations.

---

# BOF Review Summary Report

**Repository**: [repo-name]
**Review Date**: YYYY-MM-DD
**Total BOFs Reviewed**: X

## Issue Breakdown by Priority

### 🔴 CRITICAL Issues: X total
- bof-name: Unchecked HeapAlloc return (entry.c:73)
- bof-name: Missing input validation (entry.c:50)
- another-bof: NULL pointer dereference risk (entry.c:89)
[... list all critical issues ...]

### 🟠 HIGH Issues: X total
- bof-name: Missing bounds check (entry.c:78)
- another-bof: Potential timeout in loop (entry.c:145)
[... list all high issues ...]

### 🟡 MEDIUM Issues: X total
- bof-name: Missing const correctness (entry.c:78, 92)
- another-bof: Inconsistent naming conventions
[... list all medium issues ...]

### 🟢 LOW Issues: X total
- bof-name: Variable name could be more descriptive (entry.c:45)
[... list all low issues ...]

## Common Patterns Needing Improvement

1. **Unchecked return values**: Found in 5/10 BOFs
   - Always check HeapAlloc, CreateFileW, etc. before use
   
2. **Stack overflows**: Found in 3/10 BOFs
   - Move large buffers (>4KB) to heap allocation
   
3. **Resource leaks**: Found in 4/10 BOFs
   - Ensure cleanup on all code paths, including error paths
   
4. **Input validation**: Missing in 6/10 BOFs
   - Validate all user-supplied parameters

## BOFs Requiring Refactoring

1. **bof-name**: 8 critical issues - should be rewritten
2. **another-bof**: 3 critical issues - needs significant work
3. **third-bof**: Inappropriate for BOF - recommend execute-assembly

## Overall Security Assessment

**Status**: ⚠️ REQUIRES ATTENTION

**Summary**: Multiple critical stability and security issues identified across the repository. Primary concerns are unchecked return values and missing input validation, which could lead to beacon crashes or security compromises.

**Recommendations**:
1. Immediately address all CRITICAL issues before operational use
2. Establish code review process for new BOFs
3. Create testing harness for stability testing
4. Consider implementing automated static analysis

**Timeline**: Estimate 2-3 days to address all critical issues across reviewed BOFs.
