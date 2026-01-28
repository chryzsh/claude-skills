#include <windows.h>
#include <tlhelp32.h>
#include "beacon.h"

/**
 * Process Enumeration BOF
 *
 * Enumerates all running processes and outputs their PID and process name.
 * Uses CreateToolhelp32Snapshot API for process enumeration.
 *
 * Arguments: None
 * Output: PID: ProcessName for each running process
 */

#ifdef BOF

void go(char* args, int len) {
    HANDLE hSnapshot = NULL;
    PROCESSENTRY32W pe32;

    // Create snapshot of all processes
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        BeaconPrintf(CALLBACK_ERROR, "CreateToolhelp32Snapshot failed: %u\n", GetLastError());
        return;
    }

    // Initialize structure size (required by API)
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    // Get first process
    if (!Process32FirstW(hSnapshot, &pe32)) {
        BeaconPrintf(CALLBACK_ERROR, "Process32FirstW failed: %u\n", GetLastError());
        goto cleanup;
    }

    // Output header
    BeaconPrintf(CALLBACK_OUTPUT, "Process Enumeration Results:\n");
    BeaconPrintf(CALLBACK_OUTPUT, "----------------------------\n");

    // Enumerate all processes
    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%u: %S\n", pe32.th32ProcessID, pe32.szExeFile);
    } while (Process32NextW(hSnapshot, &pe32));

    BeaconPrintf(CALLBACK_OUTPUT, "----------------------------\n");
    BeaconPrintf(CALLBACK_OUTPUT, "Process enumeration complete.\n");

cleanup:
    if (hSnapshot != NULL && hSnapshot != INVALID_HANDLE_VALUE) {
        CloseHandle(hSnapshot);
    }
    return;
}

#else
// Test harness for local execution
#include <stdio.h>

int main(int argc, char** argv) {
    HANDLE hSnapshot = NULL;
    PROCESSENTRY32W pe32;

    // Create snapshot of all processes
    hSnapshot = KERNEL32$CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        printf("CreateToolhelp32Snapshot failed: %lu\n", KERNEL32$GetLastError());
        return 1;
    }

    // Initialize structure size (required by API)
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    // Get first process
    if (!KERNEL32$Process32FirstW(hSnapshot, &pe32)) {
        printf("Process32FirstW failed: %lu\n", KERNEL32$GetLastError());
        KERNEL32$CloseHandle(hSnapshot);
        return 1;
    }

    // Output header
    printf("Process Enumeration Results:\n");
    printf("----------------------------\n");

    // Enumerate all processes
    do {
        wprintf(L"%u: %s\n", pe32.th32ProcessID, pe32.szExeFile);
    } while (KERNEL32$Process32NextW(hSnapshot, &pe32));

    printf("----------------------------\n");
    printf("Process enumeration complete.\n");

    KERNEL32$CloseHandle(hSnapshot);
    return 0;
}
#endif
