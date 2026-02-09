/**
 * BOF-PE C Template
 *
 * Standard C BOF-PE with CRT support (~180KB).
 * stdio.h, string.h, stdlib.h available.
 */

#include <beacon.h>
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// Entry point - exported for C2 loader to find
extern "C" __declspec(dllexport) void go(const char* data, int len) {
    // Initialize CRT when running under C2
    BEACON_INIT;

    // Parse arguments
    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);

    // TODO: Extract arguments as needed
    // const char* target = BeaconDataExtract(&args, nullptr);
    // int value = BeaconDataInt(&args);

    // TODO: Implement functionality
    // Standard C library functions available
    char buffer[256];
    sprintf_s(buffer, sizeof(buffer), "Hello from BOF-PE (c)");

    BeaconPrintf(CALLBACK_OUTPUT, "%s\n", buffer);
}

// Standalone execution support
// Format string: z=string, i=int, s=short, b=binary, Z=wstring
BEACON_MAIN("", go)
