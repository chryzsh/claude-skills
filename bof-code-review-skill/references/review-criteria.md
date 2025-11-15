# BOF Code Review Criteria

This document contains detailed criteria for reviewing Beacon Object Files (BOFs).

## 1. Project Structure & Naming

### 🔴 CRITICAL
- **Main source file named entry.c**: The main BOF source file MUST be named `entry.c` - NO EXCEPTIONS. This is the mandatory standard across all BOF projects.

### 🟠 HIGH
- **BOFNAME in Makefile matches output filenames**: The `BOFNAME` variable must match the expected .o file names for C2 framework compatibility.

### 🟡 MEDIUM
- **Compiled .o files match C2 script expectations**: Verify that `BOFNAME` produces correct output files (e.g., `mybof.x64.o`, `mybof.x86.o`).
- **Project follows standard structure**: Should contain entry.c, beacon.h, and Makefile at minimum.

---

## 2. Coding Standards

### 🟡 MEDIUM (all items)
- **Naming conventions adherence**: Variables, functions use descriptive names following C conventions.
- **Commenting quality**: Especially for exported functions and argument parsing sections.
- **Const correctness**: Read-only pointer parameters marked `const` for safety.
- **Follows established patterns**: Consistent with patterns in bof-best-practices.md.

---

## 3. Documentation

### 🟡 MEDIUM
- **go() entry point has purpose comment**: Brief description of what the BOF does.
- **Argument parsing section documented**: Expected arguments and their order clearly documented.
- **Complex logic has comments**: Non-trivial code blocks (>10 lines) have explanatory comments.

### 🟢 LOW
- **Helper functions have comments**: Brief purpose statement for helper functions if present.

---

## 4. API Usage & Declarations

### 🔴 CRITICAL
- **API functions declared with DECLSPEC_IMPORT**: ALL Windows APIs MUST use this pattern:
  ```c
  DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD, DWORD);
  ```
- **Uses proper Windows API patterns**: Follow established BOF API usage patterns.
- **No hardcoded addresses**: No magic numbers or hardcoded memory addresses.
- **No unsafe API state assumptions**: Don't assume APIs are in specific states.

### 🟠 HIGH
- **Dynamic function resolution when needed**: Proper use of GetProcAddress/LoadLibraryA if required.
- **Proper wide string handling**: Use LPWSTR for Unicode APIs, proper conversion functions.

---

## 5. Beacon API Usage

### 🔴 CRITICAL
- **BeaconDataParse/Int/Short/Extract correct**: Proper argument parsing using Beacon APIs.
- **No standard library functions**: NO printf, malloc, free, etc. - use Beacon/MSVCRT equivalents.

### 🟠 HIGH
- **Correct BeaconPrintf() usage**: Proper callback types (CALLBACK_OUTPUT, CALLBACK_ERROR).
- **Proper BeaconOutput() for binary data**: Use BeaconOutput for non-text data.

---

## 6. Code Efficiency

### 🔴 CRITICAL
- **Reasonable stack usage**: ≤1MB total, preferably ≤4KB per function to avoid crashes.
- **Single-threaded execution**: BOFs must be single-threaded only.
- **No long-running operations**: Avoid loops, network waits that block beacon.

### 🟠 HIGH
- **Short execution time**: BOFs block other beacon tasks - keep execution brief.

### 🟡 MEDIUM
- **No unnecessary code**: Remove dead code, unused variables.
- **No large static data**: Avoid large arrays or structs in .data section.
- **No debug symbols in release**: Strip symbols with `--strip-unneeded`.

---

## 7. Memory Safety & Stability

**CRITICAL SECTION - BOF crashes kill the beacon**

### 🔴 CRITICAL (all items)
- **Proper error handling on all API calls**: Every API call must have error handling.
- **All return values checked before use**: Verify success before using returned data.
  ```c
  HANDLE hFile = KERNEL32$CreateFileW(...);
  if (hFile == INVALID_HANDLE_VALUE) {
      BeaconPrintf(CALLBACK_ERROR, "Failed: %d\n", KERNEL32$GetLastError());
      return;
  }
  ```
- **No NULL pointer dereferences**: Check pointers before dereferencing.
- **Bounds checking on all buffers**: Prevent buffer overflows.
- **Heap allocation uses correct pattern**:
  ```c
  HANDLE hHeap = KERNEL32$GetProcessHeap();
  LPVOID buffer = KERNEL32$HeapAlloc(hHeap, HEAP_ZERO_MEMORY, size);
  if (!buffer) { /* error handling */ }
  // ... use buffer ...
  KERNEL32$HeapFree(hHeap, 0, buffer);
  ```
- **All allocated memory freed**: No memory leaks - every allocation must have corresponding free.
- **No memory leaks**: Track all allocations and ensure cleanup.
- **Resource cleanup**: Close all handles before returning (files, registry keys, etc.).

---

## 8. String & Memory Operations

### 🔴 CRITICAL
- **Uses MSVCRT functions for strings**: Import from MSVCRT, not libc:
  ```c
  DECLSPEC_IMPORT size_t CDECL MSVCRT$strlen(const char*);
  DECLSPEC_IMPORT char* CDECL MSVCRT$strcpy(char*, const char*);
  DECLSPEC_IMPORT int CDECL MSVCRT$strcmp(const char*, const char*);
  DECLSPEC_IMPORT void* CDECL MSVCRT$memset(void*, int, size_t);
  DECLSPEC_IMPORT void* CDECL MSVCRT$memcpy(void*, const void*, size_t);
  ```
- **Proper string literal handling**: Use `L"..."` for wide strings when calling LPWSTR APIs.
- **No buffer overflows**: Check sizes before copying, use safe string functions.

### 🟠 HIGH
- **Wide string conversion**: Use `MultiByteToWideChar` when converting to LPWSTR.

---

## 9. Global Variables

### 🔴 CRITICAL
- **All globals initialized to non-zero**: BOFs don't support .bss section. Globals MUST be initialized:
  ```c
  // WRONG - will cause issues
  int myGlobal;
  
  // CORRECT
  int myGlobal = 1;
  ```

### 🟠 HIGH
- **Globals in .data section if needed**: Use compiler directives if necessary.

### 🟡 MEDIUM
- **Minimal globals usage**: Prefer local variables and function parameters.

---

## 10. Argument Parsing

### 🔴 CRITICAL
- **Correct Beacon data parsing**:
  ```c
  void go(char* args, int len) {
      datap parser;
      BeaconDataParse(&parser, args, len);
      int arg1 = BeaconDataInt(&parser);
      char* arg2 = BeaconDataExtract(&parser, NULL);
  ```
- **Buffer format matches input**: Parsing order matches how arguments are packed.
- **Arguments parsed in correct order**: Match the order from .cna or .py script.

### 🟠 HIGH
- **Proper handling of optional parameters**: Check parameter existence before extracting.

### 🟡 MEDIUM
- **String encoding documented**: Note if expecting ASCII vs Unicode strings.

---

## 11. Compiler Compatibility & Build

### 🔴 CRITICAL
- **Avoid libc unless from known DLLs**: Only use functions from MSVCRT, KERNEL32, etc.

### 🟠 HIGH
- **x86/x64 compatibility**: Test both architectures if supporting both.
- **No compiler intrinsics for math on x86**: Avoid multiplication/division with long long on x86.
- **Compiled with position-independent code**: Required for in-memory execution.
- **Makefile properly configured**: Libraries in LIBINCLUDE (e.g., `-l iphlpapi`).
- **No external library dependencies**: Only Win32 APIs allowed.

### 🟡 MEDIUM
- **Switch/case statements kept small**: Use if/else for large switches (>10 cases).
- **Debug symbols stripped**: Use `--strip-unneeded` for .o files.

---

## 12. Task Appropriateness

### 🔴 CRITICAL
- **Verify task is BOF-appropriate**: Check against unsuitable operations:
  - Long-running operations (blocks beacon)
  - Complex .NET operations (requires CLR)
  - Large memory allocations (>1MB stack)
  - Complex exception handling
  - GUI operations
  - Fork/spawn operations
- **No CLR runtime operations**: Cannot load .NET assemblies from BOF.

### 🟠 HIGH
- **Recommend alternatives if unsuitable**: Suggest execute-assembly or fork & run.
- **No heavy crypto operations**: May timeout or crash due to time/memory limits.

---

## 13. Conversion Quality (Python/.NET to BOF)

### 🟠 HIGH (all items)
- **Proper API mapping**: stdlib/BCL → Windows API equivalents:
  - `os.listdir()` → `FindFirstFileW()/FindNextFileW()`
  - `open()/read()` → `CreateFileW()/ReadFile()`
  - `System.IO.File` → Win32 File APIs
  - `System.Diagnostics.Process` → `CreateToolhelp32Snapshot()`
- **Dynamic to static typing**: Python/C# types correctly converted to C types.
- **Exception to return code conversion**: try/except → return value checking.

### 🟡 MEDIUM
- **Follows conversion patterns**: Matches established patterns in bof-best-practices.md.

---

## 14. Security Considerations

### 🔴 CRITICAL (all items)
- **Input validation**: Validate all user-supplied parameters before use.
- **No sensitive data in cleartext**: Encrypt or hash sensitive data.
- **Proper sensitive data cleanup**: Zero memory containing passwords, keys before freeing.
- **Thread-safe operations**: Avoid operations that could deadlock or race.

---

## Quick Reference: BOF-Appropriate vs Inappropriate Tasks

### ✅ BOF-Appropriate
- Quick enumeration (processes, files, registry)
- Single API calls or short sequences
- Network reconnaissance
- Credential access operations
- Privilege checks
- Small data collection

### ❌ NOT BOF-Appropriate
- Long-running operations
- Complex .NET requiring CLR
- Large memory allocations (>1MB)
- Complex exception handling
- GUI operations
- Fork/spawn operations

---

## Common API Patterns

### File Operations
```c
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateFileW(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$ReadFile(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$CloseHandle(HANDLE);
```

### Process Enumeration
```c
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD, DWORD);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32FirstW(HANDLE, LPPROCESSENTRY32W);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32NextW(HANDLE, LPPROCESSENTRY32W);
```

### Registry Operations
```c
DECLSPEC_IMPORT LONG WINAPI ADVAPI32$RegOpenKeyExW(HKEY, LPCWSTR, DWORD, REGSAM, PHKEY);
DECLSPEC_IMPORT LONG WINAPI ADVAPI32$RegQueryValueExW(HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD);
DECLSPEC_IMPORT LONG WINAPI ADVAPI32$RegCloseKey(HKEY);
```
