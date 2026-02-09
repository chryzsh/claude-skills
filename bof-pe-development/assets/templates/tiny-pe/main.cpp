/**
 * BOF-PE Tiny Template
 *
 * Minimal BOF-PE with no CRT dependencies (~3KB).
 * Use only Windows API and Beacon API functions.
 */

#include <beacon.h>
#include <windows.h>

// Entry point - exported for C2 loader to find
extern "C" __declspec(dllexport) void go(const char* data, int len) {
    // Parse arguments
    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);

    // TODO: Extract arguments as needed
    // const char* target = BeaconDataExtract(&args, nullptr);
    // int value = BeaconDataInt(&args);

    // TODO: Implement functionality using Windows API only
    BeaconPrintf(CALLBACK_OUTPUT, "Hello from BOF-PE (tiny)\n");
}

// Custom entry point for standalone execution
// No argc/argv - parse GetCommandLineW() if args needed
extern "C" BEACON_DISCARD void entry() {
    BeaconInvokeStandalone(0, nullptr, nullptr, go);
}
