---
name: bof-development
description: Develop Beacon Object Files (BOFs) for red team operations. Use when creating new BOFs from scratch, converting Python or .NET code to BOF format, generating Makefiles for BOF compilation, or debugging BOF implementations. Handles Windows API integration, memory management, and cross-architecture compilation (x86/x64).
---

# BOF Development

This skill provides guidance and resources for developing Beacon Object Files (BOFs) for Cobalt Strike and compatible C2 frameworks.

## When to Use This Skill

Use this skill when:
- Writing new BOFs from scratch for red team operations
- Converting Python code to BOF format
- Converting .NET code to BOF format
- Creating Makefiles for BOF compilation
- Troubleshooting BOF development issues
- Implementing Windows API calls in BOF context

## Core Workflow

### Step 1: Understand Requirements and Feasibility

Before starting BOF development, assess if the task is suitable for BOF implementation:

**BOF-appropriate tasks:**
- Quick enumeration operations (processes, files, registry)
- Single API calls or short sequences
- Network reconnaissance
- Credential access operations
- Privilege checks
- Small data collection tasks

**NOT suitable for BOFs:**
- Long-running operations (blocks beacon)
- Complex .NET operations requiring CLR
- Large memory allocations (>1MB stack)
- Operations with complex exception handling
- GUI operations
- Tasks requiring fork/spawn

If the task is not BOF-appropriate, recommend alternatives (execute-assembly, fork & run, standalone executable).

### Step 2: Design the BOF

Determine:
1. **Input arguments**: What parameters does the BOF need?
2. **Windows APIs required**: Which APIs accomplish the task?
3. **Libraries to link**: What .lib files are needed? (e.g., iphlpapi, netapi32, advapi32)
4. **Output format**: How should results be presented?
5. **Error handling**: What failure modes need handling?

### Step 3: Create Project Structure

Generate a standard BOF project structure:

```
mybof/
├── entry.c          (main BOF code - MUST be named entry.c)
├── beacon.h         (BOF API declarations)
└── Makefile         (compilation rules)
```

**CRITICAL NAMING AND STRUCTURE CONVENTIONS:**

1. **Source file naming**: The main BOF source file MUST ALWAYS be named `entry.c`
   - This is the mandatory standard across all BOF projects
   - The Makefile template expects `entry.c`
   - Makes project structure consistent and predictable
   - **NO EXCEPTIONS** - always use `entry.c`

2. **Output directory**: Compiled BOF files MUST ALWAYS go to `dist/` folder
   - The Makefile is configured to output to `dist/` directory
   - After compilation: `dist/<bofname>.x64.o` and `dist/<bofname>.x86.o`
   - This is the standard location C2 frameworks expect

3. **Output .o file naming**: The compiled BOF files MUST match the name expected by C2 scripts
   - **The BOFNAME in Makefile determines the output filename**
   - Example: `BOFNAME := curl` produces `curl.x64.o` and `curl.x86.o`
   - Example: `BOFNAME := cookie-monster-bof` produces `cookie-monster-bof.x64.o`
   - Verify naming matches OC2/Cobalt Strike script expectations BEFORE compiling

4. **Standard project structure**:
   ```
   mybof/
   ├── entry.c          (main BOF code - always entry.c)
   ├── beacon.h         (BOF API declarations)
   ├── Makefile         (set BOFNAME variable)
   └── dist/            (created during compilation)
       ├── mybof.x64.o
       └── mybof.x86.o
   ```

Use the templates from `assets/` directory:
- `assets/entry.c.template` - Basic BOF entry point
- `assets/beacon.h.template` - Common BOF API declarations
- `assets/Makefile.template` - Standard Makefile for mingw-w64

### Step 4: Implement BOF Logic

When writing BOF code:

1. **Start with includes and declarations**
```c
#include <windows.h>
#include <tlhelp32.h>  // For process enumeration
#include "beacon.h"

// Declare Windows APIs with DECLSPEC_IMPORT
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD, DWORD);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32FirstW(HANDLE, LPPROCESSENTRY32W);
```

2. **Parse arguments in go() function**
```c
void go(char* args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);
    
    // Parse each argument in order
    int pid = BeaconDataInt(&parser);
    char* processName = BeaconDataExtract(&parser, NULL);
```

3. **Implement core logic with proper error handling**
```c
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        BeaconPrintf(CALLBACK_ERROR, "Failed to create snapshot: %d\n", GetLastError());
        return;
    }
    
    // ... implementation ...
    
    CloseHandle(hSnapshot);
}
```

4. **Use Beacon APIs for output**
```c
BeaconPrintf(CALLBACK_OUTPUT, "Found %d processes\n", count);
BeaconPrintf(CALLBACK_ERROR, "Operation failed: %d\n", error);
```

### Step 5: Create Makefile

Copy and customize `assets/Makefile.template`:

1. **Set `BOFNAME` to match your desired output filename** (CRITICAL)
   - Example: `BOFNAME := curl` produces `curl.x64.o` and `curl.x86.o`
   - This name MUST match the `base_binary_name` in your OC2 Python script
   - Choose carefully - this determines how C2 frameworks reference your BOF

2. Add required libraries to `LIBINCLUDE` (e.g., `-l iphlpapi`)

3. Adjust `COMINCLUDE` path if using a common headers directory

4. **OUTPUT_DIR is preset to `dist/`** - do not change unless absolutely necessary
   - All BOFs should compile to `dist/` for consistency
   - Template already configured correctly

Common library includes:
- `-l iphlpapi` - Network interfaces (IP Helper API)
- `-l netapi32` - Network management
- `-l advapi32` - Registry and security APIs
- `-l userenv` - User environment
- `-l wtsapi32` - Terminal services
- `-l wbemuuid` - WMI (use with caution)

### Step 6: Compile and Test

```bash
# Compile BOF object files
make all

# Compile as executable for local testing
make test

# Run static analysis
make check

# Clean build artifacts
make clean
```

Test the BOF:
1. Load into Cobalt Strike or compatible C2
2. Execute with test arguments
3. Verify output and error handling
4. Test edge cases

## Language Conversion Patterns

### Converting Python to BOF

**Read the reference first**: `references/bof-best-practices.md` contains detailed conversion patterns.

Key steps:
1. Identify Python standard library usage
2. Map to equivalent Windows APIs
3. Convert dynamic typing to static C types
4. Replace automatic memory management with manual allocation
5. Handle errors explicitly (no exceptions)

**Common mappings:**
- File operations → `CreateFileW()`, `ReadFile()`, `WriteFile()`
- Directory listing → `FindFirstFileW()`, `FindNextFileW()`
- Process operations → `CreateToolhelp32Snapshot()`, `Process32FirstW()`
- Network operations → Winsock2 APIs
- Registry operations → `RegOpenKeyEx()`, `RegQueryValueEx()`

### Converting .NET to BOF

**Read the reference first**: `references/bof-best-practices.md` contains detailed conversion patterns.

Key considerations:
1. .NET BCL methods → Win32 API equivalents
2. Managed memory → Unmanaged memory with manual allocation
3. CLR types → Native Windows types
4. Some operations cannot be done in BOF (require execute-assembly)

**Common mappings:**
- `System.IO.File` → Win32 File APIs
- `System.Diagnostics.Process` → Process enumeration APIs
- `System.Security` → Native security APIs
- `System.Net` → Winsock2
- Registry classes → RegOpenKeyEx family

**Limitations:**
- Cannot load/execute .NET assemblies from BOF
- No CLR runtime access
- Complex .NET operations need alternative approaches

## Best Practices

**Always refer to**: `references/bof-best-practices.md` for comprehensive best practices.

Key principles:
1. **Memory safety**: Use heap allocation for large buffers, check bounds
2. **Error handling**: Always check API return values
3. **Resource cleanup**: Free memory and close handles before returning
4. **Stack awareness**: BOFs have ~1MB stack limit
5. **API selection**: Prefer well-tested Windows APIs
6. **Testing**: Compile as .exe first for easier debugging

## Reference Resources

**Primary reference**: `references/bof-best-practices.md`

Contains:
- BOF API function reference
- Windows API patterns for BOFs
- Python-to-BOF conversion details
- .NET-to-BOF conversion details
- Common pitfalls and solutions
- Memory management patterns
- Links to external resources (Awesome BOF, blog posts, example repositories)

**External resource hub**: [Awesome BOF Collection](https://github.com/chryzsh/awesome-bof/)
- Extensive list of existing BOFs for reference
- Links to BOF development guides
- Community-contributed examples

## Troubleshooting

**Beacon crashes on BOF execution:**
- Check stack usage (large local buffers)
- Verify all pointers are valid before dereferencing
- Ensure proper error handling on API calls
- Look for memory leaks or double-frees

**Compilation errors:**
- Verify all required libraries in `LIBINCLUDE`
- Check API declarations match Windows SDK
- Ensure proper include paths in Makefile

**BOF runs but produces no output:**
- Verify `BeaconPrintf()` or `BeaconOutput()` calls
- Check callback type (CALLBACK_OUTPUT vs CALLBACK_ERROR)
- Ensure BOF isn't returning early due to errors

**Linker errors about undefined references:**
- Add required library to `LIBINCLUDE` in Makefile
- Verify API is declared with `DECLSPEC_IMPORT`
- Check library name spelling (case-sensitive)

## Quick Reference

**Start new BOF:**
1. Copy templates from `assets/`
2. Customize Makefile (BOFNAME, LIBINCLUDE)
3. Implement `go()` function in entry.c
4. Run `make all` to compile
5. Test in C2 framework

**Convert Python/C# to BOF:**
1. Read conversion patterns in `references/bof-best-practices.md`
2. Map stdlib/BCL functions to Windows APIs
3. Convert to C with manual memory management
4. Test thoroughly

**Debug compilation issues:**
1. Run `make test` to compile as executable
2. Run locally to test logic
3. Use `make check` for static analysis
4. Check `references/bof-best-practices.md` for common issues
