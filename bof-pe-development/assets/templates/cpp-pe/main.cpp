/**
 * BOF-PE C++ Template
 *
 * Full C++ BOF-PE with STL and exceptions (~400KB).
 * std::string, std::vector, std::format, exceptions available.
 */

#include <beacon.h>
#include <windows.h>
#include <string>
#include <vector>
#include <format>
#include <exception>
#include <stdexcept>

// Helper function example
void performOperation(const std::string& target) {
    if (target.empty()) {
        throw std::invalid_argument("Target cannot be empty");
    }

    // TODO: Implement operation
    auto result = std::format("Processing: {}", target);
    BeaconOutput(CALLBACK_OUTPUT, result.data(), static_cast<int>(result.length()));
}

// Entry point - exported for C2 loader to find
extern "C" __declspec(dllexport) void go(const char* data, int len) {
    // Initialize CRT when running under C2
    BEACON_INIT;

    try {
        // Parse arguments
        datap args = {0};
        BeaconDataParse(&args, (char*)data, len);

        // TODO: Extract arguments as needed
        const char* target = BeaconDataExtract(&args, nullptr);
        // int value = BeaconDataInt(&args);

        // TODO: Implement functionality
        if (target) {
            performOperation(target);
        } else {
            BeaconPrintf(CALLBACK_OUTPUT, "Hello from BOF-PE (cpp)\n");
        }

    } catch (const std::exception& ex) {
        BeaconPrintf(CALLBACK_ERROR, "Error: %s\n", ex.what());
    }
}

// Standalone execution support
// Format string: z=string, i=int, s=short, b=binary, Z=wstring
BEACON_MAIN("z", go)
