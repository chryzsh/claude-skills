# Building BOF-PEs

Instructions for building BOF-PE projects with CMake.

## Prerequisites

- CMake 3.18+
- One of: MSVC, Clang (recommended), or MinGW
- Windows SDK (for Windows headers)

## Recommended Compilers

| Compiler | x64 SEH | x86 SEH | Recommendation |
|----------|---------|---------|----------------|
| **Clang** | Yes | Yes | Recommended for cross-compilation |
| **MSVC** | Yes | Yes | Best Windows native option |
| **MinGW** | Yes | No* | Avoid for x86 if exceptions needed |

*MinGW uses DWARF/SJLJ for x86 exceptions, not SEH.

## Project Structure

```
my-bof-pe/
├── CMakeLists.txt
├── beacon/
│   ├── beacon.h
│   ├── beacon.cpp
│   └── CMakeLists.txt
├── src/
│   └── main.cpp
└── build/
```

## Root CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.18)
project(my-bof-pe)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Architecture-specific linker script
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(LINK_SCRIPT ${CMAKE_SOURCE_DIR}/link.ld)
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(LINK_SCRIPT ${CMAKE_SOURCE_DIR}/link32.ld)
endif()

include_directories(${CMAKE_SOURCE_DIR}/beacon/)

add_subdirectory(beacon)
add_subdirectory(src)

install(TARGETS beacon my-bof-pe DESTINATION "")
```

## BOF-PE CMakeLists.txt (src/)

### tiny-pe (no CRT)
```cmake
add_executable(my-bof-pe main.cpp)

target_link_libraries(my-bof-pe beacon)

# No CRT - custom entry point
if(MSVC OR (CMAKE_CXX_COMPILER_ID STREQUAL "Clang"))
    target_link_options(my-bof-pe PRIVATE
        /NODEFAULTLIB
        /ENTRY:entry
        /SUBSYSTEM:CONSOLE
    )
else()
    target_link_options(my-bof-pe PRIVATE
        -nostdlib
        -e entry
        -Wl,--subsystem,console
    )
endif()

target_link_libraries(my-bof-pe kernel32 user32)
```

### c-pe (with CRT)
```cmake
add_executable(my-bof-pe main.cpp)

target_link_libraries(my-bof-pe beacon)

if(MSVC OR (CMAKE_CXX_COMPILER_ID STREQUAL "Clang"))
    # Static CRT linkage
    set_property(TARGET my-bof-pe PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

    target_link_options(my-bof-pe PRIVATE
        /SUBSYSTEM:CONSOLE
    )
endif()
```

### cpp-pe (full C++)
```cmake
add_executable(my-bof-pe main.cpp)

target_link_libraries(my-bof-pe beacon)

if(MSVC OR (CMAKE_CXX_COMPILER_ID STREQUAL "Clang"))
    set_property(TARGET my-bof-pe PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

    target_link_options(my-bof-pe PRIVATE
        /SUBSYSTEM:CONSOLE
    )

    # Enable C++20 features
    target_compile_features(my-bof-pe PRIVATE cxx_std_20)
endif()
```

## Beacon Library CMakeLists.txt

```cmake
add_library(beacon SHARED beacon.cpp)

target_compile_definitions(beacon PRIVATE BUILD_BEACON)

if(MSVC OR (CMAKE_CXX_COMPILER_ID STREQUAL "Clang"))
    set_property(TARGET beacon PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
```

## Building with MSVC

```cmd
mkdir build
cd build
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
cmake --install . --config Release --prefix dist
```

For x86:
```cmd
cmake -G "Visual Studio 17 2022" -A Win32 ..
```

## Building with Clang (Cross-compilation)

From Linux with Clang targeting Windows:

```bash
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=../clang-msvc.cmake \
      -DCMAKE_BUILD_TYPE=Release ..
cmake --build .
cmake --install . --prefix dist
```

Example toolchain file (clang-msvc.cmake):
```cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_C_COMPILER_TARGET x86_64-pc-windows-msvc)
set(CMAKE_CXX_COMPILER_TARGET x86_64-pc-windows-msvc)
```

## Linker Scripts

The `.discard` section must be configured to be removed during C2 loading. This is handled by linker scripts:

**link.ld (x64):**
```
SECTIONS
{
    .discard : { *(.discard) *(.discard_data) }
}
```

## Running

### Standalone
```cmd
# Requires beacon.dll in same directory
my-bof-pe.exe arg1 123 arg3
```

### With POC Loader (simulates C2)
```cmd
loader.exe my-bof-pe.exe zi "string_arg" 123
```

## Debugging

### Visual Studio
1. Set my-bof-pe as startup project
2. Project Properties → Debugging → Command Arguments
3. F5 to debug with breakpoints

### Standalone Testing
The beacon.dll compatibility layer outputs to stdout, making testing easy:
```cmd
my-bof-pe.exe testarg
# Output appears in console
```

## Common Build Issues

**Unresolved external symbol `__scrt_initialize_crt`**
- Ensure static CRT linkage with `MSVC_RUNTIME_LIBRARY "MultiThreaded"`

**Entry point not found**
- For tiny-pe: verify `/ENTRY:entry` or `-e entry` is set
- For c-pe/cpp-pe: verify `BEACON_MAIN` macro is present

**beacon.dll not found at runtime**
- Copy beacon.dll to same directory as executable
- Or add beacon/ directory to PATH
