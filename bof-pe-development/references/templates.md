# BOF-PE Template Reference

Detailed guidance for each BOF-PE template type.

## tiny-pe Template

**Size:** ~3KB
**Use case:** Minimal footprint, no CRT dependencies, closest to traditional BOF

### Characteristics
- No C runtime library linked
- No standard library functions (printf, malloc, strcpy, etc.)
- Must use Windows API directly for all operations
- Custom entry point (no argc/argv parsing)
- Smallest possible size

### Template
```cpp
#include <beacon.h>
#include <windows.h>

// Use Windows API directly - no CRT functions available
extern "C" __declspec(dllexport) void go(const char* data, int len) {
    // Parse arguments
    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);

    // Do work using only Windows API and Beacon API
    BeaconPrintf(CALLBACK_OUTPUT, "Hello from tiny-pe\n");
}

// Custom entry point - no main() with argc/argv
extern "C" BEACON_DISCARD void entry() {
    BeaconInvokeStandalone(0, nullptr, nullptr, go);
}
```

### When to Use
- Size is critical (stealth, limited bandwidth)
- Simple functionality that doesn't need string manipulation
- Direct Windows API operations only
- Converting existing minimal BOFs

### Limitations
- No sprintf, strcpy, malloc, free, etc.
- Must parse command line manually via GetCommandLineW() for standalone args
- No exception handling

---

## c-pe Template

**Size:** ~180KB
**Use case:** Standard C development with CRT, normal headers work

### Characteristics
- Static CRT linkage (ucrt)
- Standard C library available (stdio.h, string.h, stdlib.h)
- Normal main() with argc/argv via BEACON_MAIN macro
- Familiar C development workflow

### Template
```cpp
#include <beacon.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

extern "C" __declspec(dllexport) void go(const char* data, int len) {
    BEACON_INIT;

    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);
    const char* name = BeaconDataExtract(&args, nullptr);
    int count = BeaconDataInt(&args);

    // Standard C library functions work
    char buffer[256];
    sprintf_s(buffer, sizeof(buffer), "Hello %s, count: %d", name, count);

    BeaconPrintf(CALLBACK_OUTPUT, "%s\n", buffer);
}

BEACON_MAIN("zi", go)
```

### When to Use
- Need standard C string/memory functions
- Converting existing C code to BOF-PE
- Moderate size acceptable
- No need for C++ features

### Available Functions
- stdio.h: printf, sprintf, sscanf, fopen, fread, etc.
- string.h: strcpy, strcat, strlen, memcpy, memset, etc.
- stdlib.h: malloc, free, atoi, atof, etc.
- All Windows API functions

---

## cpp-pe Template

**Size:** ~400KB (80KB minimal with just exceptions)
**Use case:** Full C++ development with STL and exceptions

### Characteristics
- Full C++ runtime
- STL containers and algorithms (vector, string, map, etc.)
- Exception handling (try/catch)
- Modern C++ features (C++20)
- Templates and classes with virtual functions

### Template
```cpp
#include <beacon.h>
#include <string>
#include <vector>
#include <format>
#include <exception>
#include <stdexcept>

void performOperation(const std::string& target) {
    if (target.empty()) {
        throw std::invalid_argument("Target cannot be empty");
    }
    // Complex operations with STL...
}

extern "C" __declspec(dllexport) void go(const char* data, int len) {
    BEACON_INIT;

    try {
        datap args = {0};
        BeaconDataParse(&args, (char*)data, len);
        const char* target = BeaconDataExtract(&args, nullptr);

        std::string result = std::format("Processing: {}", target);
        BeaconOutput(CALLBACK_OUTPUT, result.data(), result.length());

        performOperation(target);

        BeaconPrintf(CALLBACK_OUTPUT, "Operation completed\n");
    }
    catch (const std::exception& ex) {
        BeaconPrintf(CALLBACK_ERROR, "Error: %s\n", ex.what());
    }
}

BEACON_MAIN("z", go)
```

### When to Use
- Complex tools requiring data structures
- Error handling via exceptions preferred
- Converting existing C++ code
- Need std::string, std::vector, std::map, etc.
- Code maintainability over size

### Available Features
- All STL containers: vector, map, set, unordered_map, etc.
- std::string, std::wstring
- std::format (C++20)
- std::chrono for time operations
- std::filesystem for path operations
- Exception handling (try/catch/throw)
- RAII patterns with smart pointers
- Templates and virtual functions

### Reducing Size
For minimal C++ with just exceptions (~80KB):
```cpp
#include <beacon.h>
#include <exception>

extern "C" __declspec(dllexport) void go(const char* data, int len) {
    BEACON_INIT;
    try {
        // Minimal C++ code
    }
    catch (const std::exception& ex) {
        BeaconPrintf(CALLBACK_ERROR, "%s\n", ex.what());
    }
}
BEACON_MAIN("", go)
```

---

## Migration from Traditional BOF

### Before (Traditional BOF)
```c
#include <windows.h>
#include "beacon.h"

DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateFileA(...);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$ReadFile(...);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$CloseHandle(HANDLE);
#define CreateFileA KERNEL32$CreateFileA
#define ReadFile KERNEL32$ReadFile
#define CloseHandle KERNEL32$CloseHandle

void go(char* args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);
    char* path = BeaconDataExtract(&parser, NULL);

    HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL,
                           OPEN_EXISTING, 0, NULL);
    // ... rest of BOF
}
```

### After (BOF-PE c-pe)
```cpp
#include <beacon.h>
#include <windows.h>

extern "C" __declspec(dllexport) void go(const char* data, int len) {
    BEACON_INIT;

    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);
    const char* path = BeaconDataExtract(&args, nullptr);

    // Standard Windows API - no DFR macros needed
    HANDLE h = CreateFileA(path, GENERIC_READ, 0, NULL,
                           OPEN_EXISTING, 0, NULL);
    // ... rest of code
}

BEACON_MAIN("z", go)
```

### Key Differences
1. Add `extern "C" __declspec(dllexport)` to entry function
2. Add `BEACON_INIT` at start of entry function
3. Add `BEACON_MAIN(fmt, entry)` at end for standalone support
4. Remove all DFR/DECLSPEC_IMPORT declarations
5. Use standard Windows headers directly
