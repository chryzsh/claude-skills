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

### Compilation
- C (C99), Windows x64 and x86; no CRT linking, no exception handling
- MinGW: `x86_64-w64-mingw32-gcc -c bof.c -o bof.o -masm=intel -Wall`
- MSVC: `cl.exe /c /GS- /O2 bof.c` (`/GS-` disables buffer security
  checks; never pass `/MD` or `/MT`)

### API selection
- Prefer native NT APIs over high-level Win32 when stealth matters
- Avoid CreateRemoteThread and VirtualAllocEx unless necessary
- Use indirect syscalls only for highly monitored functions (advanced)

### Common Pitfalls
1. **Stack size limitations**: Functions with stack variables >4KB trigger `__chkstk_ms` which BOF loaders cannot resolve. Use heap allocation (`HeapAlloc`) for large buffers instead of stack arrays.
2. **Deep recursion**: Avoid recursive functions - they consume stack rapidly. Convert recursive algorithms to iterative using explicit stack/queue data structures. See [trustedsec common utilities](https://github.com/trustedsec/CS-Situational-Awareness-BOF/tree/master/src/common) for stack/queue implementations.
3. **String literals**: Use wide strings for Windows APIs that expect LPWSTR
4. **Error handling**: Always check return values and handle errors gracefully
5. **Memory leaks**: Clean up allocated memory before returning
6. **API compatibility**: Not all Windows APIs work well in BOF context
7. **Thread safety**: BOFs run in beacon's thread; avoid operations that could deadlock
8. **Unsigned underflow in loop bounds**: `DWORD`/`ULONG` subtraction wraps to ~4 billion when subtrahend > value. Rewrite `i < val - N` as `i + N < val` (safe by construction).
9. **RPC/MIDL memory mismatch**: Memory from RPC/IDL stubs (e.g., `IDL_DRSBind`) must use `MIDL_user_free()`, not `MSVCRT$free()`. Declare: `extern void __RPC_USER MIDL_user_free(void*);`

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
DECLSPEC_IMPORT LPVOID WINAPI KERNEL32$HeapAlloc(HANDLE, DWORD, SIZE_T);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$HeapFree(HANDLE, DWORD, LPVOID);
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$GetProcessHeap();

// Example usage
HANDLE hHeap = KERNEL32$GetProcessHeap();
LPVOID buffer = KERNEL32$HeapAlloc(hHeap, HEAP_ZERO_MEMORY, size);
// ... use buffer ...
KERNEL32$HeapFree(hHeap, 0, buffer);
```

### Preprocessor Helper Macros

These macros simplify common BOF patterns and reduce boilerplate:

```c
// Memory allocation shortcuts
#define intAlloc(size) KERNEL32$HeapAlloc(KERNEL32$GetProcessHeap(), HEAP_ZERO_MEMORY, size)
#define intRealloc(ptr, size) (ptr) ? KERNEL32$HeapReAlloc(KERNEL32$GetProcessHeap(), HEAP_ZERO_MEMORY, ptr, size) : intAlloc(size)
#define intFree(ptr) if(ptr) { KERNEL32$HeapFree(KERNEL32$GetProcessHeap(), 0, ptr); ptr = NULL; }

// COM object cleanup
#define SAFE_RELEASE(ptr) if(ptr) { (ptr)->lpVtbl->Release(ptr); ptr = NULL; }

// BSTR cleanup (for COM/WMI)
#define SAFE_SYS_FREE(bstr) if(bstr) { OLEAUT32$SysFreeString(bstr); bstr = NULL; }

// Error checking with goto
#define CHECK_RETURN_FAIL(hr, label) if(FAILED(hr)) { BeaconPrintf(CALLBACK_ERROR, "HRESULT: 0x%08X\n", hr); goto label; }
#define CHECK_RETURN_FAIL_BOOL(result, label) if(!(result)) { BeaconPrintf(CALLBACK_ERROR, "Error: %u\n", KERNEL32$GetLastError()); goto label; }
```

**Usage example:**
```c
void go(char* args, int len) {
    LPVOID buffer = NULL;
    IWbemLocator* pLocator = NULL;

    buffer = intAlloc(4096);
    if (!buffer) goto cleanup;

    HRESULT hr = OLEAUT32$CoCreateInstance(&CLSID_WbemLocator, ...);
    CHECK_RETURN_FAIL(hr, cleanup);

    // ... use resources ...

cleanup:
    SAFE_RELEASE(pLocator);
    intFree(buffer);
    return;
}
```

### Goto Cleanup Pattern

**Critical for multi-resource functions.** This pattern ensures all resources are freed on every exit path.

**Basic Pattern:**
```c
void go(char* args, int len) {
    // Resource tracking flags
    BOOL resourceAcquired = FALSE;
    HANDLE hResource = NULL;
    LPVOID buffer = NULL;

    // Acquire resources
    hResource = SomeAPI();
    if (!hResource) {
        BeaconPrintf(CALLBACK_ERROR, "Failed to acquire resource\n");
        goto cleanup;
    }
    resourceAcquired = TRUE;

    buffer = KERNEL32$HeapAlloc(KERNEL32$GetProcessHeap(), HEAP_ZERO_MEMORY, 1024);
    if (!buffer) {
        BeaconPrintf(CALLBACK_ERROR, "Failed to allocate memory\n");
        goto cleanup;
    }

    // Use resources
    // ... implementation ...

    BeaconPrintf(CALLBACK_OUTPUT, "Success\n");

cleanup:
    // Free in reverse order of acquisition
    if (buffer) {
        KERNEL32$HeapFree(KERNEL32$GetProcessHeap(), 0, buffer);
    }
    if (resourceAcquired) {
        FreeResource(hResource);
    }
    return;
}
```

**Common SSPI/Security Cleanup:**
```c
// Security API declarations for cleanup
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$FreeCredentialsHandle(PCredHandle);
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$DeleteSecurityContext(PCtxtHandle);
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$FreeContextBuffer(PVOID);

// LDAP cleanup
DECLSPEC_IMPORT ULONG WINAPI WLDAP32$ldap_unbind_s(LDAP*);

// Example with SSPI resources
void go(char* args, int len) {
    BOOL credHandleAcquired = FALSE;
    BOOL contextInitialized = FALSE;
    LDAP* pLdapConnection = NULL;
    CredHandle hCredential;
    CtxtHandle securityContext;
    SecBuffer outputBuffer = {0, SECBUFFER_TOKEN, NULL};

    // Acquire credential handle
    SECURITY_STATUS status = SECUR32$AcquireCredentialsHandleW(
        NULL, L"NTLM", SECPKG_CRED_OUTBOUND,
        NULL, NULL, NULL, NULL,
        &hCredential, NULL);
    if (status != SEC_E_OK) {
        BeaconPrintf(CALLBACK_ERROR, "AcquireCredentialsHandleW failed: %d\n", status);
        goto cleanup;
    }
    credHandleAcquired = TRUE;

    // Initialize LDAP connection
    pLdapConnection = WLDAP32$ldap_initW(L"dc.example.com", 389);
    if (!pLdapConnection) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_initW failed\n");
        goto cleanup;
    }

    // Initialize security context
    status = SECUR32$InitializeSecurityContextW(
        &hCredential, NULL, L"ldap/dc.example.com",
        ISC_REQ_ALLOCATE_MEMORY, 0, SECURITY_NATIVE_DREP,
        NULL, 0, &securityContext, &outputBuffer, NULL, NULL);
    if (status != SEC_E_OK && status != SEC_I_CONTINUE_NEEDED) {
        BeaconPrintf(CALLBACK_ERROR, "InitializeSecurityContextW failed: %d\n", status);
        goto cleanup;
    }
    contextInitialized = TRUE;

    // ... use resources ...

cleanup:
    // Free context buffer if allocated
    if (outputBuffer.pvBuffer) {
        SECUR32$FreeContextBuffer(outputBuffer.pvBuffer);
    }
    // Delete security context
    if (contextInitialized) {
        SECUR32$DeleteSecurityContext(&securityContext);
    }
    // Free credential handle
    if (credHandleAcquired) {
        SECUR32$FreeCredentialsHandle(&hCredential);
    }
    // Unbind LDAP connection
    if (pLdapConnection) {
        WLDAP32$ldap_unbind_s(pLdapConnection);
    }
    return;
}
```

**CRITICAL: Loop Control with API Return Values**

Don't use arbitrary counters for authentication loops - use actual API return values:

```c
// WRONG - arbitrary counter
int count = 0;
do {
    if (count > 5) {
        BeaconPrintf(CALLBACK_ERROR, "Stuck in loop\n");
        break;
    }
    count++;
    status = SECUR32$InitializeSecurityContextW(...);
} while (1);

// CORRECT - use API return value
do {
    status = SECUR32$InitializeSecurityContextW(...);
    if (status == SEC_E_OK) {
        // Authentication complete
        break;
    } else if (status == SEC_I_CONTINUE_NEEDED) {
        // Continue with server response
        // ... send to server, get response ...
    } else {
        // Error - log and cleanup
        BeaconPrintf(CALLBACK_ERROR, "InitializeSecurityContextW failed: %d\n", status);
        goto cleanup;
    }
} while (status == SEC_I_CONTINUE_NEEDED);
```

**NULL Checks Before Dereferencing:**

Always check pointers before dereferencing, especially with output buffers:

```c
// WRONG - crashes if InitializeSecurityContextW fails
SecBufferDesc output = {SECBUFFER_VERSION, 1, &secbufPointer};
status = SECUR32$InitializeSecurityContextW(..., &output, ...);
PSecBuffer ticket = output.pBuffers;
if (ticket->pvBuffer == NULL) { ... }  // May crash here

// CORRECT - check pointer first
SecBufferDesc output = {SECBUFFER_VERSION, 1, &secbufPointer};
status = SECUR32$InitializeSecurityContextW(..., &output, ...);
if (status != SEC_E_OK && status != SEC_I_CONTINUE_NEEDED) {
    BeaconPrintf(CALLBACK_ERROR, "Failed: %d\n", status);
    goto cleanup;
}
PSecBuffer ticket = output.pBuffers;
if (ticket == NULL || ticket->pvBuffer == NULL) {
    BeaconPrintf(CALLBACK_ERROR, "No output buffer allocated\n");
    goto cleanup;
}
```

**Format Specifier Correctness:**

Match printf format specifiers to variable types:

```c
// Common types and their specifiers
SECURITY_STATUS status;  // LONG - use %d or %ld
DWORD value;             // unsigned long - use %u or %lu
ULONG result;            // unsigned long - use %u or %lu
char* str;               // narrow string - use %s
wchar_t* wstr;           // wide string - use %S or %ls
HANDLE handle;           // pointer - use %p

// WRONG
SECURITY_STATUS status = SECUR32$InitializeSecurityContextW(...);
BeaconPrintf(CALLBACK_ERROR, "Failed: %S\n", status);  // %S is for wide strings!

// CORRECT
BeaconPrintf(CALLBACK_ERROR, "Failed: %d\n", status);
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
