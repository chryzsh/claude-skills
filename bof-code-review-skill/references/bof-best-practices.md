# BOF Development Best Practices

This reference provides essential BOF development knowledge for code review context.

## Core BOF Constraints

### Memory and Execution
- **Stack size**: Limited to ~1MB total, keep per-function usage ≤4KB
- **Heap allocation**: Use `KERNEL32$GetProcessHeap()` + `HeapAlloc/HeapFree`
- **Execution model**: Single-threaded, short-running only
- **In-process execution**: Crashes kill the beacon - stability is critical

### API Usage Requirements
- **NO standard library**: Cannot use printf, malloc, free, etc.
- **DECLSPEC_IMPORT required**: All Windows APIs must be declared this way
- **Use MSVCRT for strings**: Import strlen, strcpy, strcmp from MSVCRT
- **Beacon APIs for I/O**: BeaconPrintf, BeaconOutput, BeaconDataParse

### BOF API Reference

```c
// Output functions
void BeaconPrintf(int type, char* fmt, ...);
void BeaconOutput(int type, char* data, int len);
// Types: CALLBACK_OUTPUT (0), CALLBACK_OUTPUT_OEM (1), CALLBACK_ERROR (2)

// Argument parsing
void BeaconDataParse(datap* parser, char* buffer, int size);
int BeaconDataInt(datap* parser);
short BeaconDataShort(datap* parser);
int BeaconDataLength(datap* parser);
char* BeaconDataExtract(datap* parser, int* size);

// Dynamic function resolution
DECLSPEC_IMPORT FARPROC WINAPI KERNEL32$GetProcAddress(HMODULE, LPCSTR);
DECLSPEC_IMPORT HMODULE WINAPI KERNEL32$LoadLibraryA(LPCSTR);
DECLSPEC_IMPORT HMODULE WINAPI KERNEL32$GetModuleHandleA(LPCSTR);
```

## Common Pitfalls

### 1. Stack Overflows
**Problem**: Large local buffers cause crashes
```c
// WRONG - 10KB on stack
void go(char* args, int len) {
    char buffer[10240];  // Too large!
    // ...
}

// CORRECT - use heap
void go(char* args, int len) {
    HANDLE hHeap = KERNEL32$GetProcessHeap();
    char* buffer = (char*)KERNEL32$HeapAlloc(hHeap, HEAP_ZERO_MEMORY, 10240);
    if (!buffer) {
        BeaconPrintf(CALLBACK_ERROR, "Allocation failed\n");
        return;
    }
    // ... use buffer ...
    KERNEL32$HeapFree(hHeap, 0, buffer);
}
```

### 2. Uninitialized Globals
**Problem**: BOFs don't support .bss section
```c
// WRONG - uninitialized global
int g_counter;

// CORRECT - initialized to non-zero
int g_counter = 0;
```

### 3. Missing Error Checks
**Problem**: Unchecked return values cause NULL dereferences
```c
// WRONG - no error check
HANDLE hFile = KERNEL32$CreateFileW(path, ...);
KERNEL32$ReadFile(hFile, ...);  // CRASH if hFile is INVALID_HANDLE_VALUE

// CORRECT - check before use
HANDLE hFile = KERNEL32$CreateFileW(path, ...);
if (hFile == INVALID_HANDLE_VALUE) {
    BeaconPrintf(CALLBACK_ERROR, "CreateFileW failed: %d\n", KERNEL32$GetLastError());
    return;
}
KERNEL32$ReadFile(hFile, ...);
KERNEL32$CloseHandle(hFile);
```

### 4. Memory Leaks
**Problem**: Allocated memory not freed
```c
// WRONG - memory leak on error path
void go(char* args, int len) {
    HANDLE hHeap = KERNEL32$GetProcessHeap();
    char* buf1 = KERNEL32$HeapAlloc(hHeap, 0, 1024);
    char* buf2 = KERNEL32$HeapAlloc(hHeap, 0, 2048);
    
    if (some_error) {
        return;  // LEAK - buf1 and buf2 not freed!
    }
    
    KERNEL32$HeapFree(hHeap, 0, buf1);
    KERNEL32$HeapFree(hHeap, 0, buf2);
}

// CORRECT - cleanup on all paths
void go(char* args, int len) {
    HANDLE hHeap = KERNEL32$GetProcessHeap();
    char* buf1 = KERNEL32$HeapAlloc(hHeap, 0, 1024);
    char* buf2 = KERNEL32$HeapAlloc(hHeap, 0, 2048);
    
    if (some_error) {
        goto cleanup;
    }
    
    // ... main logic ...
    
cleanup:
    if (buf1) KERNEL32$HeapFree(hHeap, 0, buf1);
    if (buf2) KERNEL32$HeapFree(hHeap, 0, buf2);
}
```

### 5. String Type Mismatches
**Problem**: Using char* with LPWSTR APIs
```c
// WRONG - char* with Unicode API
HANDLE hFile = KERNEL32$CreateFileW("C:\\test.txt", ...);  // Won't compile

// CORRECT - use wide string literal
HANDLE hFile = KERNEL32$CreateFileW(L"C:\\test.txt", ...);
```

### 6. Standard Library Headers
**Problem**: Including stdio.h, stdlib.h
```c
// WRONG - standard library headers
#include <stdio.h>
#include <stdlib.h>

// CORRECT - only Windows headers and beacon.h
#include <windows.h>
#include <tlhelp32.h>
#include "beacon.h"
```

## Proper API Declaration Patterns

### String Operations (MSVCRT)
```c
DECLSPEC_IMPORT size_t CDECL MSVCRT$strlen(const char*);
DECLSPEC_IMPORT char* CDECL MSVCRT$strcpy(char*, const char*);
DECLSPEC_IMPORT int CDECL MSVCRT$strcmp(const char*, const char*);
DECLSPEC_IMPORT void* CDECL MSVCRT$memset(void*, int, size_t);
DECLSPEC_IMPORT void* CDECL MSVCRT$memcpy(void*, const void*, size_t);
```

### Memory Management (KERNEL32)
```c
DECLSPEC_IMPORT LPVOID WINAPI KERNEL32$HeapAlloc(HANDLE, DWORD, SIZE_T);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$HeapFree(HANDLE, DWORD, LPVOID);
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$GetProcessHeap(void);
```

### File Operations (KERNEL32)
```c
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateFileW(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$ReadFile(HANDLE, LPVOID, DWORD, LPDWORD, LPOVERLAPPED);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$WriteFile(HANDLE, LPCVOID, DWORD, LPDWORD, LPOVERLAPPED);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$CloseHandle(HANDLE);
```

### Wide String Conversion
```c
DECLSPEC_IMPORT int WINAPI KERNEL32$MultiByteToWideChar(UINT, DWORD, LPCCH, int, LPWSTR, int);

// Example usage
wchar_t widePath[MAX_PATH];
KERNEL32$MultiByteToWideChar(CP_UTF8, 0, narrowPath, -1, widePath, MAX_PATH);
```

## Language Conversion Patterns

### Python to BOF

**File listing:**
```python
# Python
import os
files = os.listdir("C:\\Windows")
for f in files:
    print(f)
```

```c
// BOF equivalent
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$FindFirstFileW(LPCWSTR, LPWIN32_FIND_DATAW);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$FindNextFileW(HANDLE, LPWIN32_FIND_DATAW);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$FindClose(HANDLE);

WIN32_FIND_DATAW findData;
HANDLE hFind = KERNEL32$FindFirstFileW(L"C:\\Windows\\*", &findData);
if (hFind != INVALID_HANDLE_VALUE) {
    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%ls\n", findData.cFileName);
    } while (KERNEL32$FindNextFileW(hFind, &findData));
    KERNEL32$FindClose(hFind);
}
```

### .NET to BOF

**Process enumeration:**
```csharp
// C#
using System.Diagnostics;
Process[] processes = Process.GetProcesses();
foreach (var p in processes) {
    Console.WriteLine($"{p.Id}: {p.ProcessName}");
}
```

```c
// BOF equivalent
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD, DWORD);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32FirstW(HANDLE, LPPROCESSENTRY32W);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32NextW(HANDLE, LPPROCESSENTRY32W);

HANDLE hSnapshot = KERNEL32$CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
if (hSnapshot == INVALID_HANDLE_VALUE) {
    BeaconPrintf(CALLBACK_ERROR, "CreateToolhelp32Snapshot failed\n");
    return;
}

PROCESSENTRY32W pe32;
pe32.dwSize = sizeof(PROCESSENTRY32W);

if (KERNEL32$Process32FirstW(hSnapshot, &pe32)) {
    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%d: %ls\n", 
                    pe32.th32ProcessID, pe32.szExeFile);
    } while (KERNEL32$Process32NextW(hSnapshot, &pe32));
}
KERNEL32$CloseHandle(hSnapshot);
```

## Tasks That Should NOT Be BOFs

These operations are unsuitable for BOF implementation:

1. **Long-running operations**: Blocks beacon thread indefinitely
2. **Complex .NET operations**: Requires loading CLR
3. **Heavy cryptographic operations**: May timeout or crash
4. **Large memory allocations**: Stack/heap constraints
5. **GUI operations**: No message loop available
6. **Complex exception handling**: Limited SEH support
7. **Multi-threaded operations**: Single-threaded only
8. **Operations requiring fork/spawn**: Use fork & run instead

**Alternatives:**
- **execute-assembly**: For .NET code requiring CLR
- **fork & run**: For long-running tasks
- **Standalone executables**: For complex operations with GUI

## Project Structure Standards

```
mybof/
├── entry.c          # MUST be named entry.c (MANDATORY)
├── beacon.h         # BOF API declarations
├── Makefile         # Set BOFNAME variable
├── mybof.x64.o      # Compiled x64 output
└── mybof.x86.o      # Compiled x86 output
```

**Makefile essentials:**
```makefile
BOFNAME := mybof
LIBINCLUDE := -l iphlpapi -l netapi32  # Add required libraries
```

## Common Libraries

```makefile
# Network operations
-l iphlpapi      # IP Helper API
-l netapi32      # Network management
-l ws2_32        # Winsock2

# Security and registry
-l advapi32      # Registry, security APIs

# User environment
-l userenv       # User profile APIs

# Terminal services
-l wtsapi32      # Windows Terminal Services

# WMI (use sparingly)
-l wbemuuid      # WMI APIs
```

## Debugging Tips

**Compile as EXE for testing:**
```makefile
test:
	$(CC_x64) entry.c -o mybof.exe -DTEST_MODE
```

**Add conditional compilation:**
```c
#ifdef TEST_MODE
#include <stdio.h>
int main() {
    // Test code here
    return 0;
}
#else
void go(char* args, int len) {
    // BOF code here
}
#endif
```

## External Resources

- [Cobalt Strike BOF Documentation](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/beacon-object-files_main.htm)
- [TrustedSec BOF Development Guide](https://www.trustedsec.com/blog/a-developers-introduction-to-beacon-object-files/)
- [Awesome BOF Collection](https://github.com/chryzsh/awesome-bof/)
- [TrustedSec CS-Situational-Awareness-BOF](https://github.com/trustedsec/CS-Situational-Awareness-BOF)
