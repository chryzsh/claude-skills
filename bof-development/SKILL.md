---
name: bof-development
description: Develop Beacon Object Files (BOFs) for C2 frameworks. Use for creating new BOFs, converting Python/.NET to BOF, or debugging BOF issues.
---

# BOF Development

## When to Use

- Writing new BOFs from scratch for red team operations
- Converting Python/.NET code to BOF format
- Creating Makefiles for BOF compilation
- Troubleshooting BOF development issues

## Feasibility Check

**BOF-appropriate tasks:**
- Quick enumeration (processes, files, registry)
- Single API calls or short sequences
- Network reconnaissance, credential access, privilege checks

**NOT suitable for BOFs (use execute-assembly or fork & run):**
- Long-running operations (blocks beacon)
- Complex .NET requiring CLR
- Large memory allocations (>1MB stack)
- GUI operations, complex exception handling

## Project Structure

```
mybof/
├── entry.c          # MUST be named entry.c (mandatory)
├── beacon.h         # BOF API declarations
└── Makefile         # Set BOFNAME to match C2 script expectations
```

Copy templates from `assets/` directory.

## Core BOF Patterns

### Entry Point and Argument Parsing
```c
#include <windows.h>
#include "beacon.h"

void go(char* args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);

    int intArg = BeaconDataInt(&parser);
    char* strArg = BeaconDataExtract(&parser, NULL);
    wchar_t* wstrArg = (wchar_t*)BeaconDataExtract(&parser, NULL);

    // Implementation...
}
```

### Windows API Declarations
```c
// DLL$FunctionName format with DECLSPEC_IMPORT
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD, DWORD);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32FirstW(HANDLE, LPPROCESSENTRY32W);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32NextW(HANDLE, LPPROCESSENTRY32W);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$CloseHandle(HANDLE);
```

### Output Functions
```c
BeaconPrintf(CALLBACK_OUTPUT, "Result: %d\n", value);
BeaconPrintf(CALLBACK_ERROR, "Failed: %d\n", KERNEL32$GetLastError());
BeaconOutput(CALLBACK_OUTPUT, buffer, length);  // Raw binary
```

### Memory Allocation (No malloc/free!)
```c
HANDLE hHeap = KERNEL32$GetProcessHeap();
LPVOID buffer = KERNEL32$HeapAlloc(hHeap, HEAP_ZERO_MEMORY, size);
// ... use buffer ...
KERNEL32$HeapFree(hHeap, 0, buffer);
```

## Resource Management (Critical)

**For functions with 2+ resources, use the goto cleanup pattern:**

```c
void go(char* args, int len) {
    // Track what needs cleanup
    BOOL credAcquired = FALSE;
    HANDLE hFile = NULL;
    LPVOID buffer = NULL;

    // Parse args
    datap parser;
    BeaconDataParse(&parser, args, len);

    // Acquire resources - goto cleanup on failure
    SECURITY_STATUS status = SECUR32$AcquireCredentialsHandleW(...);
    if (status != SEC_E_OK) {
        BeaconPrintf(CALLBACK_ERROR, "AcquireCreds failed: %d\n", status);
        goto cleanup;
    }
    credAcquired = TRUE;

    buffer = KERNEL32$HeapAlloc(KERNEL32$GetProcessHeap(), HEAP_ZERO_MEMORY, 4096);
    if (!buffer) {
        BeaconPrintf(CALLBACK_ERROR, "HeapAlloc failed\n");
        goto cleanup;
    }

    // ... use resources ...

    BeaconPrintf(CALLBACK_OUTPUT, "Success\n");

cleanup:
    // Free in REVERSE order of acquisition
    if (buffer) KERNEL32$HeapFree(KERNEL32$GetProcessHeap(), 0, buffer);
    if (credAcquired) SECUR32$FreeCredentialsHandle(&hCred);
    return;
}
```

**Common cleanup functions:**
| Resource Type | Cleanup Function |
|--------------|------------------|
| Heap memory | `KERNEL32$HeapFree()` |
| File/process handles | `KERNEL32$CloseHandle()` |
| Registry keys | `ADVAPI32$RegCloseKey()` |
| Credential handles | `SECUR32$FreeCredentialsHandle()` |
| Security contexts | `SECUR32$DeleteSecurityContext()` |
| LDAP connections | `WLDAP32$ldap_unbind_s()` |

See [references/code-examples.md](references/code-examples.md) for full SSPI/LDAP cleanup example.

## Critical Pitfalls

1. **Stack overflow**: Variables >4KB trigger `__chkstk_ms` (unresolvable). Use heap allocation.
2. **Deep recursion**: Avoid - convert to iterative with explicit stack/queue.
3. **NULL dereference**: Always check pointers before use, especially output buffers.
4. **Resource leaks**: Use goto cleanup pattern for multi-resource functions.
5. **Wrong format specifiers**: `%d` for SECURITY_STATUS, `%u` for DWORD, `%S` for wide strings.

## Makefile Setup

1. Set `BOFNAME` to match C2 script expectations (produces `name.x64.o`, `name.x86.o`)
2. Add required libraries to `LIBINCLUDE`:
   - `-l iphlpapi` - Network interfaces
   - `-l netapi32` - Network management
   - `-l advapi32` - Registry/security APIs
   - `-l wtsapi32` - Terminal services

## Build and Validate

```bash
make all      # Compile BOF object files
make lint     # Validate with boflint (REQUIRED before testing)
make test     # Compile as .exe for local debugging
make check    # Static analysis
```

**Fix lint errors before testing.** Common issues:
- `undefined symbol` → Missing DECLSPEC_IMPORT or wrong DFR format
- `___chkstk_ms` → Stack variable too large, use heap
- `exception handling` → Remove try/catch, use explicit error handling

## Workflow Summary

1. Assess feasibility (is this BOF-appropriate?)
2. Copy templates from `assets/`
3. Set `BOFNAME` in Makefile
4. Implement `go()` function with proper patterns
5. `make all && make lint`
6. Test in C2 framework
7. Run `bof-code-review` skill before deployment

## References

- [references/code-examples.md](references/code-examples.md) - Extended examples (SSPI, conversion patterns)
- [references/bof-best-practices.md](references/bof-best-practices.md) - API reference, troubleshooting
- [references/goto-cleanup-example.c](references/goto-cleanup-example.c) - Full cleanup pattern
- [Awesome BOF Collection](https://github.com/chryzsh/awesome-bof/) - Community examples
