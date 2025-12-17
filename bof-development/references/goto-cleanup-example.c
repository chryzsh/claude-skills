/**
 * Goto Cleanup Pattern Example
 *
 * This example demonstrates the proper resource management pattern
 * for BOFs with multiple resources that need cleanup.
 *
 * Based on lessons learned from:
 * https://github.com/trustedsec/CS-Situational-Awareness-BOF/pull/141
 */

#define SECURITY_WIN32
#include <windows.h>
#include <security.h>
#include <winldap.h>
#include "beacon.h"

// Windows API declarations
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

/**
 * Example BOF demonstrating proper resource cleanup with goto pattern
 *
 * This function:
 * 1. Acquires multiple resources (credentials, LDAP connection, memory)
 * 2. Uses boolean flags to track what needs cleanup
 * 3. Uses goto cleanup on all error paths
 * 4. Cleans up resources in reverse order of acquisition
 */
void go(char* args, int len) {
    // ============================================
    // STEP 1: Declare resource tracking variables
    // ============================================
    BOOL credHandleAcquired = FALSE;
    BOOL contextInitialized = FALSE;
    LDAP* pLdapConnection = NULL;
    LPVOID buffer = NULL;

    CredHandle hCredential;
    CtxtHandle securityContext;
    SecBuffer outputBuffer = {0, SECBUFFER_TOKEN, NULL};
    SecBufferDesc output = {SECBUFFER_VERSION, 1, &outputBuffer};

    // ============================================
    // STEP 2: Parse arguments
    // ============================================
    datap parser;
    BeaconDataParse(&parser, args, len);
    char* dcName = BeaconDataExtract(&parser, NULL);

    // Convert to wide string (simplified for example)
    wchar_t wDcName[256];
    // ... conversion code ...

    // ============================================
    // STEP 3: Acquire resources with error handling
    // ============================================

    // Acquire credential handle
    TimeStamp tsExpiry;
    SECURITY_STATUS status = SECUR32$AcquireCredentialsHandleW(
        NULL,
        L"NTLM",
        SECPKG_CRED_OUTBOUND,
        NULL,
        NULL,
        NULL,
        NULL,
        &hCredential,
        &tsExpiry
    );

    if (status != SEC_E_OK) {
        BeaconPrintf(CALLBACK_ERROR, "AcquireCredentialsHandleW failed: %d\n", status);
        goto cleanup;  // Jump to cleanup - no resources to free yet
    }
    credHandleAcquired = TRUE;  // Mark for cleanup

    // Initialize LDAP connection
    pLdapConnection = WLDAP32$ldap_initW(wDcName, 389);
    if (pLdapConnection == NULL) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_initW failed\n");
        goto cleanup;  // Will free credential handle
    }

    // Set LDAP options
    const int version = LDAP_VERSION3;
    ULONG result = WLDAP32$ldap_set_optionW(pLdapConnection, LDAP_OPT_VERSION, (void*)&version);
    if (result != LDAP_SUCCESS) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_set_optionW failed: %u\n", result);
        goto cleanup;  // Will free credential handle and LDAP connection
    }

    // Connect to LDAP server
    result = WLDAP32$ldap_connect(pLdapConnection, NULL);
    if (result != LDAP_SUCCESS) {
        BeaconPrintf(CALLBACK_ERROR, "ldap_connect failed: %u\n", result);
        goto cleanup;
    }

    // Allocate buffer for operations
    HANDLE hHeap = KERNEL32$GetProcessHeap();
    buffer = KERNEL32$HeapAlloc(hHeap, HEAP_ZERO_MEMORY, 4096);
    if (buffer == NULL) {
        BeaconPrintf(CALLBACK_ERROR, "HeapAlloc failed\n");
        goto cleanup;
    }

    // ============================================
    // STEP 4: Use resources with proper loop control
    // ============================================

    // CORRECT: Use API return value for loop control
    do {
        status = SECUR32$InitializeSecurityContextW(
            &hCredential,
            contextInitialized ? &securityContext : NULL,
            L"ldap/dc.example.com",
            ISC_REQ_ALLOCATE_MEMORY | ISC_REQ_MUTUAL_AUTH,
            0,
            SECURITY_NATIVE_DREP,
            NULL,
            0,
            &securityContext,
            &output,
            NULL,
            NULL
        );

        if (status == SEC_E_OK) {
            // Authentication complete
            contextInitialized = TRUE;
            break;
        } else if (status == SEC_I_CONTINUE_NEEDED) {
            // Mark context as initialized for next iteration
            contextInitialized = TRUE;

            // CRITICAL: Check pointer before dereferencing
            PSecBuffer ticket = output.pBuffers;
            if (ticket == NULL || ticket->pvBuffer == NULL) {
                BeaconPrintf(CALLBACK_ERROR, "No output buffer allocated\n");
                goto cleanup;
            }

            // Send ticket to server and get response
            // ... LDAP bind operations ...

        } else {
            // Error occurred
            BeaconPrintf(CALLBACK_ERROR, "InitializeSecurityContextW failed: %d\n", status);
            goto cleanup;
        }

    } while (status == SEC_I_CONTINUE_NEEDED);

    // ============================================
    // STEP 5: Success - perform actual operation
    // ============================================
    BeaconPrintf(CALLBACK_OUTPUT, "Successfully authenticated to %s\n", dcName);
    // ... perform LDAP operations ...

    // ============================================
    // STEP 6: Cleanup (always executed)
    // ============================================
cleanup:
    // Free resources in REVERSE order of acquisition

    // Free output buffer from InitializeSecurityContextW
    if (outputBuffer.pvBuffer) {
        SECUR32$FreeContextBuffer(outputBuffer.pvBuffer);
    }

    // Free heap buffer
    if (buffer) {
        KERNEL32$HeapFree(hHeap, 0, buffer);
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

/**
 * BAD EXAMPLE - DON'T DO THIS
 *
 * This shows the WRONG way to handle resources with early returns.
 * This code has multiple resource leak paths.
 */
void go_bad_example(char* args, int len) {
    CredHandle hCredential;
    LDAP* pLdapConnection = NULL;

    // Acquire credential handle
    SECURITY_STATUS status = SECUR32$AcquireCredentialsHandleW(
        NULL, L"NTLM", SECPKG_CRED_OUTBOUND,
        NULL, NULL, NULL, NULL,
        &hCredential, NULL
    );

    if (status != SEC_E_OK) {
        BeaconPrintf(CALLBACK_ERROR, "Failed\n");
        return;  // OK - no resources acquired yet
    }

    // Initialize LDAP
    pLdapConnection = WLDAP32$ldap_initW(L"dc.example.com", 389);
    if (pLdapConnection == NULL) {
        BeaconPrintf(CALLBACK_ERROR, "Failed\n");
        return;  // BUG: Leaks hCredential!
    }

    // Do some operation
    ULONG result = WLDAP32$ldap_connect(pLdapConnection, NULL);
    if (result != LDAP_SUCCESS) {
        BeaconPrintf(CALLBACK_ERROR, "Failed\n");
        return;  // BUG: Leaks both hCredential and pLdapConnection!
    }

    // Wrong loop control - arbitrary counter instead of API status
    int count = 0;
    do {
        if (count > 5) {
            BeaconPrintf(CALLBACK_ERROR, "Stuck in loop\n");
            return;  // BUG: Leaks resources!
        }
        count++;
        // ... operations ...
    } while (1);

    // This cleanup is never reached in error cases
    WLDAP32$ldap_unbind_s(pLdapConnection);
    SECUR32$FreeCredentialsHandle(&hCredential);
}
