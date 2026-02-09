---
name: bof-pe-development
description: Develop BOF-PE (Beacon Object File Portable Executable) files for C2 frameworks. Use when creating BOF-PEs from scratch, converting traditional BOFs to BOF-PE format, or building post-exploitation tools that need full C++ support, exception handling, or standalone execution capability. BOF-PE enables the same executable to run standalone or within a C2 environment while using the Beacon API.
---

# BOF-PE Development

## Overview

BOF-PE is a next-generation design for Beacon Object Files using fully-linked PE executables instead of COFF object files. Unlike traditional BOFs, BOF-PEs support full C++ (STL, templates, exceptions), standard Windows API imports, multiple source files, and standalone execution.

## Template Selection

Choose the template based on requirements:

| Template | Size | Use Case |
|----------|------|----------|
| **tiny-pe** | ~3KB | Minimal footprint, no CRT, closest to traditional BOF |
| **c-pe** | ~180KB | Standard C with CRT, uses normal headers and sprintf/strcpy |
| **cpp-pe** | ~400KB | Full C++ with STL, exceptions, std::format, std::chrono |

**Decision guide:**
- Size critical, simple functionality → `tiny-pe`
- Need standard C library functions → `c-pe`
- Need C++ features, STL, or exceptions → `cpp-pe`

## Core Pattern

Every BOF-PE follows this structure:

```cpp
#include <beacon.h>

// Export entry point - name doesn't matter, just needs to be exported
extern "C" __declspec(dllexport) void go(const char* data, int len) {
    // Initialize CRT if running under C2 (not standalone)
    BEACON_INIT;

    // Parse arguments
    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);
    const char* str_arg = BeaconDataExtract(&args, nullptr);
    int int_arg = BeaconDataInt(&args);

    // Do work...

    // Output results
    BeaconPrintf(CALLBACK_OUTPUT, "Result: %s\n", result);
}

// Enable standalone execution with argument format string
BEACON_MAIN("zi", go)  // "z" = string, "i" = int
```

## Argument Format Strings

Used in `BEACON_MAIN(fmt, entry)` for standalone argument parsing:

| Format | Type | Description |
|--------|------|-------------|
| `z` | `char*` | Null-terminated string |
| `Z` | `wchar_t*` | Wide (UTF-16) string |
| `s` | `short` | 2-byte integer |
| `i` | `int` | 4-byte integer |
| `b` | `char*, int` | Binary data (length-prefixed) |

Example: `BEACON_MAIN("zis", go)` expects string, int, short arguments.

## Key Macros

- **`BEACON_INIT`** - Call at start of `go()`. Initializes CRT when running under C2.
- **`BEACON_MAIN(fmt, entry)`** - Declares main() in .discard section for standalone execution.
- **`BEACON_DISCARD`** - Mark functions to be discarded during C2 loading.

## Exception Handling (cpp-pe only)

```cpp
extern "C" __declspec(dllexport) void go(const char* data, int len) {
    BEACON_INIT;

    try {
        datap args = {0};
        BeaconDataParse(&args, (char*)data, len);
        riskyOperation(BeaconDataExtract(&args, nullptr));
    }
    catch (const std::exception& ex) {
        BeaconPrintf(CALLBACK_ERROR, "Error: %s\n", ex.what());
    }
}
```

## Output Functions

```cpp
// Formatted output (most common)
BeaconPrintf(CALLBACK_OUTPUT, "Found %d items\n", count);

// Error output
BeaconPrintf(CALLBACK_ERROR, "Failed: %s\n", errorMsg);

// Raw binary output
BeaconOutput(CALLBACK_OUTPUT, buffer, bufferLen);
```

## Windows API Usage

Unlike traditional BOFs, use standard imports:

```cpp
// BOF-PE - standard imports work
#include <windows.h>
HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);

// Traditional BOF - required MODULE$Function syntax
// DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateFileA(...);
```

## References

- **[Beacon API Reference](references/beacon-api.md)** - Full API documentation
- **[Template Details](references/templates.md)** - Template-specific patterns and examples
- **[Building BOF-PEs](references/building.md)** - CMake build instructions
