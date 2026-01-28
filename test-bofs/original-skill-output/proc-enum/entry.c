/**
 * Process Enumeration BOF
 *
 * Enumerates all running processes and outputs their PID and process name.
 * Uses the CreateToolhelp32Snapshot API for process enumeration.
 *
 * Usage: No arguments required
 * Output: "PID: process_name" for each running process
 */

#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include "beacon.h"

#ifdef BOF

/**
 * BOF entry point - enumerates all running processes
 *
 * @param args  Not used (no arguments required)
 * @param len   Not used (no arguments required)
 */
void go(char* args, int len) {
    HANDLE hSnapshot = NULL;
    PROCESSENTRY32W pe32;
    DWORD processCount = 0;

    /* Create a snapshot of all processes in the system */
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        BeaconPrintf(CALLBACK_ERROR, "Failed to create process snapshot. Error: %lu\n", GetLastError());
        return;
    }

    /* Initialize the size of the structure before use */
    memset(&pe32, 0, sizeof(PROCESSENTRY32W));
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    /* Get the first process from the snapshot */
    if (!Process32FirstW(hSnapshot, &pe32)) {
        BeaconPrintf(CALLBACK_ERROR, "Failed to get first process. Error: %lu\n", GetLastError());
        goto cleanup;
    }

    BeaconPrintf(CALLBACK_OUTPUT, "Process Enumeration Results:\n");
    BeaconPrintf(CALLBACK_OUTPUT, "============================\n");

    /* Iterate through all processes in the snapshot */
    do {
        BeaconPrintf(CALLBACK_OUTPUT, "%lu: %S\n", pe32.th32ProcessID, pe32.szExeFile);
        processCount++;
    } while (Process32NextW(hSnapshot, &pe32));

    BeaconPrintf(CALLBACK_OUTPUT, "============================\n");
    BeaconPrintf(CALLBACK_OUTPUT, "Total processes: %lu\n", processCount);

cleanup:
    /* Clean up the snapshot handle */
    if (hSnapshot != NULL && hSnapshot != INVALID_HANDLE_VALUE) {
        CloseHandle(hSnapshot);
    }
}

#else

/* Test harness for local execution */
int main(int argc, char** argv) {
    printf("Test mode - Process Enumeration BOF\n");
    printf("This BOF takes no arguments.\n");
    printf("Run in Cobalt Strike to enumerate processes.\n");

    /* For testing, we can call the Windows APIs directly */
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        printf("Failed to create snapshot. Error: %lu\n", GetLastError());
        return 1;
    }

    PROCESSENTRY32W pe32;
    memset(&pe32, 0, sizeof(PROCESSENTRY32W));
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (!Process32FirstW(hSnapshot, &pe32)) {
        printf("Failed to get first process. Error: %lu\n", GetLastError());
        CloseHandle(hSnapshot);
        return 1;
    }

    printf("Process Enumeration Results:\n");
    printf("============================\n");

    DWORD count = 0;
    do {
        printf("%lu: %S\n", pe32.th32ProcessID, pe32.szExeFile);
        count++;
    } while (Process32NextW(hSnapshot, &pe32));

    printf("============================\n");
    printf("Total processes: %lu\n", count);

    CloseHandle(hSnapshot);
    return 0;
}

#endif
