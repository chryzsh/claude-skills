# BOF Code Examples

Extended code examples for BOF development patterns.

## SSPI/LDAP Authentication with Full Cleanup

This example demonstrates proper resource management for complex multi-resource operations:

```c
#define SECURITY_WIN32
#include <windows.h>
#include <security.h>
#include <winldap.h>
#include "beacon.h"

// API Declarations
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$AcquireCredentialsHandleW(
    LPWSTR, LPWSTR, ULONG, PLUID, PVOID, SEC_GET_KEY_FN, PVOID, PCredHandle, PTimeStamp);
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$InitializeSecurityContextW(
    PCredHandle, PCtxtHandle, SEC_WCHAR*, ULONG, ULONG, ULONG,
    PSecBufferDesc, ULONG, PCtxtHandle, PSecBufferDesc, PULONG, PTimeStamp);
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$FreeCredentialsHandle(PCredHandle);
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$DeleteSecurityContext(PCtxtHandle);
DECLSPEC_IMPORT SECURITY_STATUS WINAPI SECUR32$FreeContextBuffer(PVOID);

DECLSPEC_IMPORT LDAP* WINAPI WLDAP32$ldap_initW(PWCHAR, ULONG);
DECLSPEC_IMPORT ULONG WINAPI WLDAP32$ldap_unbind_s(LDAP*);
DECLSPEC_IMPORT ULONG WINAPI WLDAP32$ldap_set_optionW(LDAP*, int, const void*);
DECLSPEC_IMPORT ULONG WINAPI WLDAP32$ldap_connect(LDAP*, PLDAP_TIMEVAL);

DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$GetProcessHeap();
DECLSPEC_IMPORT LPVOID WINAPI KERNEL32$HeapAlloc(HANDLE, DWORD, SIZE_T);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$HeapFree(HANDLE, DWORD, LPVOID);

void go(char* args, int len) {
    // Resource tracking variables
    BOOL credHandleAcquired = FALSE;
    BOOL contextInitialized = FALSE;
    LDAP* pLdapConnection = NULL;
    LPVOID buffer = NULL;

    CredHandle hCredential;
    CtxtHandle securityContext;
    SecBuffer outputBuffer = {0, SECBUFFER_TOKEN, NULL};
    SecBufferDesc output = {SECBUFFER_VERSION, 1, &outputBuffer};

    // Parse arguments
    datap parser;
    BeaconDataParse(&parser, args, len);
    char* dcName = BeaconDataExtract(&parser, NULL);

    // Acquire credential handle
    TimeStamp tsExpiry;
    SECURITY_STATUS status = SECUR32$AcquireCredentialsHandleW(
        NULL, L"NTLM", SECPKG_CRED_OUTBOUND,
        NULL, NULL, NULL, NULL,
        &hCredential, &tsExpiry);
    if (status != SEC_E_OK) {
        BeaconPrintf(CALLBACK_ERROR, "AcquireCredentialsHandleW failed: %d\n", status);
        goto cleanup;
    }
    credHandleAcquired = TRUE;

    // Initialize LDAP connection
    pLdapConnection = WLDAP32$ldap_initW(L"dc.example.com", 389);
    if (pLdapConnection == NULL) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_initW failed\n");
        goto cleanup;
    }

    // Set LDAP options
    const int version = LDAP_VERSION3;
    ULONG result = WLDAP32$ldap_set_optionW(pLdapConnection, LDAP_OPT_VERSION, (void*)&version);
    if (result != LDAP_SUCCESS) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_set_optionW failed: %u\n", result);
        goto cleanup;
    }

    // Connect
    result = WLDAP32$ldap_connect(pLdapConnection, NULL);
    if (result != LDAP_SUCCESS) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_connect failed: %u\n", result);
        goto cleanup;
    }

    // Allocate buffer
    HANDLE hHeap = KERNEL32$GetProcessHeap();
    buffer = KERNEL32$HeapAlloc(hHeap, HEAP_ZERO_MEMORY, 4096);
    if (buffer == NULL) {
        BeaconPrintf(CALLBACK_ERROR, "HeapAlloc failed\n");
        goto cleanup;
    }

    // Authentication loop - use API return value for control
    do {
        status = SECUR32$InitializeSecurityContextW(
            &hCredential,
            contextInitialized ? &securityContext : NULL,
            L"ldap/dc.example.com",
            ISC_REQ_ALLOCATE_MEMORY | ISC_REQ_MUTUAL_AUTH,
            0, SECURITY_NATIVE_DREP,
            NULL, 0,
            &securityContext, &output, NULL, NULL);

        if (status == SEC_E_OK) {
            contextInitialized = TRUE;
            break;
        } else if (status == SEC_I_CONTINUE_NEEDED) {
            contextInitialized = TRUE;
            // Check pointer before dereferencing
            PSecBuffer ticket = output.pBuffers;
            if (ticket == NULL || ticket->pvBuffer == NULL) {
                BeaconPrintf(CALLBACK_ERROR, "No output buffer allocated\n");
                goto cleanup;
            }
            // ... send to server, get response ...
        } else {
            BeaconPrintf(CALLBACK_ERROR, "InitializeSecurityContextW failed: %d\n", status);
            goto cleanup;
        }
    } while (status == SEC_I_CONTINUE_NEEDED);

    BeaconPrintf(CALLBACK_OUTPUT, "Successfully authenticated to %s\n", dcName);

cleanup:
    // Free in REVERSE order of acquisition
    if (outputBuffer.pvBuffer) SECUR32$FreeContextBuffer(outputBuffer.pvBuffer);
    if (buffer) KERNEL32$HeapFree(hHeap, 0, buffer);
    if (contextInitialized) SECUR32$DeleteSecurityContext(&securityContext);
    if (credHandleAcquired) SECUR32$FreeCredentialsHandle(&hCredential);
    if (pLdapConnection) WLDAP32$ldap_unbind_s(pLdapConnection);
    return;
}
```

## Preprocessor Helper Macros

Simplify common patterns with these macros:

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

## Python to BOF Conversion Example

**Python (directory listing):**
```python
import os
files = os.listdir("C:\\Windows")
for f in files:
    print(f)
```

**BOF equivalent:**
```c
#include <windows.h>
#include "beacon.h"

DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$FindFirstFileW(LPCWSTR, LPWIN32_FIND_DATAW);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$FindNextFileW(HANDLE, LPWIN32_FIND_DATAW);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$FindClose(HANDLE);

void go(char* args, int len) {
    WIN32_FIND_DATAW findData;
    HANDLE hFind = KERNEL32$FindFirstFileW(L"C:\\Windows\\*", &findData);

    if (hFind == INVALID_HANDLE_VALUE) {
        BeaconPrintf(CALLBACK_ERROR, "FindFirstFileW failed: %d\n", KERNEL32$GetLastError());
        return;
    }

    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%ls\n", findData.cFileName);
    } while (KERNEL32$FindNextFileW(hFind, &findData));

    KERNEL32$FindClose(hFind);
}
```

## .NET to BOF Conversion Example

**C# (process enumeration):**
```csharp
using System.Diagnostics;
Process[] processes = Process.GetProcesses();
foreach (var p in processes) {
    Console.WriteLine($"{p.Id}: {p.ProcessName}");
}
```

**BOF equivalent:**
```c
#include <windows.h>
#include <tlhelp32.h>
#include "beacon.h"

DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD, DWORD);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32FirstW(HANDLE, LPPROCESSENTRY32W);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32NextW(HANDLE, LPPROCESSENTRY32W);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$CloseHandle(HANDLE);

void go(char* args, int len) {
    HANDLE hSnapshot = KERNEL32$CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        BeaconPrintf(CALLBACK_ERROR, "CreateToolhelp32Snapshot failed\n");
        return;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (KERNEL32$Process32FirstW(hSnapshot, &pe32)) {
        do {
            BeaconPrintf(CALLBACK_OUTPUT, "%d: %ls\n", pe32.th32ProcessID, pe32.szExeFile);
        } while (KERNEL32$Process32NextW(hSnapshot, &pe32));
    }

    KERNEL32$CloseHandle(hSnapshot);
}
```

## Common API Mappings

| Python/C# | BOF Windows API |
|-----------|-----------------|
| `os.listdir()` | `FindFirstFileW()` / `FindNextFileW()` |
| `open()` / `read()` | `CreateFileW()` / `ReadFile()` |
| `socket` | Winsock2 APIs |
| `subprocess` | `CreateProcessW()` |
| `Process.GetProcesses()` | `CreateToolhelp32Snapshot()` |
| `Registry.GetValue()` | `RegOpenKeyExW()` / `RegQueryValueExW()` |
| `Environment.GetEnvironmentVariable()` | `GetEnvironmentVariableW()` |
