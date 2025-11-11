# BOF Development Best Practices

## Overview

This reference contains best practices, common patterns, and pitfalls for developing Beacon Object Files (BOFs) for Cobalt Strike and other C2 frameworks.

## Core BOF Concepts

### BOF Structure
- BOFs are position-independent code (PIC) compiled as object files (.o)
- Entry point is typically `go()` function
- Must use Beacon APIs for output/memory management
- No standard library functions (printf, malloc, etc.)

### Memory Management
- Use `BeaconDataParse()` to parse input arguments
- Use `BeaconOutput()` for standard output
- Use `BeaconPrintf()` for formatted output
- Avoid stack-based buffers when possible; use heap allocation via MSVCRT or kernel32
- BOFs execute in-process; crashes kill the beacon

### Common Pitfalls
1. **Stack size limitations**: BOFs have limited stack space (~1MB), large buffers cause crashes
2. **String literals**: Use wide strings for Windows APIs that expect LPWSTR
3. **Error handling**: Always check return values and handle errors gracefully
4. **Memory leaks**: Clean up allocated memory before returning
5. **API compatibility**: Not all Windows APIs work well in BOF context
6. **Thread safety**: BOFs run in beacon's thread; avoid operations that could deadlock

## BOF API Functions

### Beacon Output Functions
```c
void BeaconPrintf(int type, char* fmt, ...);
void BeaconOutput(int type, char* data, int len);
```

Types: `CALLBACK_OUTPUT` (0), `CALLBACK_OUTPUT_OEM` (1), `CALLBACK_ERROR` (2)

### Beacon Data Parsing
```c
void BeaconDataParse(datap* parser, char* buffer, int size);
int BeaconDataInt(datap* parser);
short BeaconDataShort(datap* parser);
int BeaconDataLength(datap* parser);
char* BeaconDataExtract(datap* parser, int* size);
```

### Dynamic Function Resolution
```c
DECLSPEC_IMPORT FARPROC WINAPI GetProcAddress(HMODULE, LPCSTR);
DECLSPEC_IMPORT HMODULE WINAPI LoadLibraryA(LPCSTR);
DECLSPEC_IMPORT HMODULE WINAPI GetModuleHandleA(LPCSTR);
```

## Windows API Patterns for BOFs

### Safe String Handling
```c
// Use MSVCRT functions for string operations
DECLSPEC_IMPORT size_t CDECL strlen(const char*);
DECLSPEC_IMPORT char* CDECL strcpy(char*, const char*);
DECLSPEC_IMPORT int CDECL strcmp(const char*, const char*);
DECLSPEC_IMPORT void* CDECL memset(void*, int, size_t);
DECLSPEC_IMPORT void* CDECL memcpy(void*, const void*, size_t);
```

### Memory Allocation
```c
// Prefer kernel32 for memory allocation
DECLSPEC_IMPORT LPVOID WINAPI HeapAlloc(HANDLE, DWORD, SIZE_T);
DECLSPEC_IMPORT BOOL WINAPI HeapFree(HANDLE, DWORD, LPVOID);
DECLSPEC_IMPORT HANDLE WINAPI GetProcessHeap();

// Example usage
HANDLE hHeap = GetProcessHeap();
LPVOID buffer = HeapAlloc(hHeap, HEAP_ZERO_MEMORY, size);
// ... use buffer ...
HeapFree(hHeap, 0, buffer);
```

### Wide String Conversion
```c
// For APIs requiring LPWSTR
DECLSPEC_IMPORT int WINAPI MultiByteToWideChar(UINT, DWORD, LPCCH, int, LPWSTR, int);

// Example
wchar_t wideStr[256];
MultiByteToWideChar(CP_UTF8, 0, narrowStr, -1, wideStr, 256);
```

## Language-Specific Conversion Patterns

### Python to BOF Conversion

**Key considerations:**
1. Python's dynamic typing → Static C types
2. Python's automatic memory management → Manual allocation/deallocation
3. Python standard library → Windows API equivalents
4. Error handling: try/except → Return code checking

**Common conversions:**
- `os.listdir()` → `FindFirstFileW()` / `FindNextFileW()`
- `open()` / `read()` → `CreateFileW()` / `ReadFile()`
- `socket` operations → Winsock2 APIs
- `subprocess` → `CreateProcessW()`
- String operations → MSVCRT or custom implementations

**Example pattern:**
```python
# Python
import os
files = os.listdir("C:\\Windows")
for f in files:
    print(f)
```

```c
// BOF equivalent
WIN32_FIND_DATAW findData;
HANDLE hFind = FindFirstFileW(L"C:\\Windows\\*", &findData);
if (hFind != INVALID_HANDLE_VALUE) {
    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%ls\n", findData.cFileName);
    } while (FindNextFileW(hFind, &findData));
    FindClose(hFind);
}
```

### .NET to BOF Conversion

**Key considerations:**
1. .NET BCL → Windows API equivalents
2. Managed code → Unmanaged C
3. CLR types → Native types
4. Some .NET operations cannot be done in BOF context

**Common conversions:**
- `System.IO.File` → Win32 File APIs
- `System.Diagnostics.Process` → Process APIs
- `System.Net` → Winsock2
- `System.Security` operations → Native security APIs
- Registry operations → RegOpenKeyEx, RegQueryValueEx, etc.

**Limitations:**
- Cannot load/execute .NET assemblies directly from BOF
- No access to CLR runtime
- Complex .NET-specific operations need alternative approaches

**Example pattern:**
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
HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
PROCESSENTRY32W pe32;
pe32.dwSize = sizeof(PROCESSENTRY32W);

if (Process32FirstW(hSnapshot, &pe32)) {
    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%d: %ls\n", 
                    pe32.th32ProcessID, pe32.szExeFile);
    } while (Process32NextW(hSnapshot, &pe32));
}
CloseHandle(hSnapshot);
```

## Tasks That Cannot Be Done as BOFs

Some operations are not suitable for BOF implementation:

1. **Long-running operations**: BOFs block the beacon thread
2. **Complex .NET operations**: Requires loading CLR or execute-assembly
3. **Operations requiring elevated context switches**: Better as standalone executables
4. **Heavy cryptographic operations**: May timeout or crash
5. **Large memory allocations**: Stack/heap limitations
6. **GUI operations**: No message loop in BOF context
7. **Operations requiring complex exception handling**: Limited SEH support

For these scenarios, consider:
- Execute-assembly for .NET code
- Fork & run for long-running tasks
- Post-exploitation modules
- Standalone executables

## Resources

### Essential Reading
- [Cobalt Strike BOF Documentation](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/beacon-object-files_main.htm)
- [A Developer's Guide to Beacon Object Files](https://www.cobaltstrike.com/blog/a-developers-guide-to-beacon-object-files/)
- [trustedsec BOF Development](https://www.trustedsec.com/blog/a-developers-introduction-to-beacon-object-files/)

### Code Examples & Libraries
- [Awesome BOF Collection](https://github.com/chryzsh/awesome-bof/)
- [BOF Template Repository](https://github.com/Cobalt-Strike/bof_template)
- [trustedsec CS-Situational-Awareness-BOF](https://github.com/trustedsec/CS-Situational-Awareness-BOF)
- [ajpc500 BOFs](https://github.com/ajpc500/BOFs)
- [outflanknl C2-Tool-Collection](https://github.com/outflanknl/C2-Tool-Collection)

### Common Header Files
Most BOFs need these common includes:
- `windows.h` - Core Windows types and APIs
- `tlhelp32.h` - Process/thread enumeration
- `winternl.h` - NT internal structures
- `iphlpapi.h` - Network interface APIs
- `lm.h` - Network management
- `wincrypt.h` - Cryptography APIs
