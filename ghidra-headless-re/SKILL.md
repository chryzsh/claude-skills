# Ghidra headless reverse engineering

Analyze a Windows PE binary for security-relevant behavior using Ghidra headless mode and a custom export script. No GUI needed.

## When to use

When you have a Windows binary (service, DLL, driver) and need to understand what it does: what APIs it calls, what paths/pipes/registry keys it touches, and whether any code paths are exploitable.

## Prerequisites

- Ghidra 11.3+ installed (`ghidra-analyzeHeadless` on PATH)
- The `ExportAll.java` script from this skill's `scripts/` directory
- The binary to analyze, accessible on the local filesystem

## Procedure

### 1. Run headless Ghidra

Create a temporary project directory and output directory, then run:

```bash
ghidra-analyzeHeadless /tmp/ghidra-project proj_name \
    -import /path/to/binary.exe \
    -scriptPath /path/to/ghidra-headless-re/scripts \
    -postScript ExportAll.java /tmp/ghidra-out
```

This runs full auto-analysis (function identification, type propagation, decompilation) and exports three files:

- `<name>-imports.txt`: all external API imports with addresses
- `<name>-strings.txt`: all defined strings (ASCII and Unicode) with addresses
- `<name>-decompiled.c`: full decompiled C for every non-thunk function

For subsequent binaries in the same project, use `-process` instead of `-import`:

```bash
ghidra-analyzeHeadless /tmp/ghidra-project proj_name \
    -process another_binary.exe \
    -scriptPath /path/to/ghidra-headless-re/scripts \
    -postScript ExportAll.java /tmp/ghidra-out
```

### 2. Triage from imports

Read the imports file first. Flag dangerous APIs by category:

**Process creation** (potential code execution as another user):
- `ShellExecuteW`, `ShellExecuteExW`
- `CreateProcessW`, `CreateProcessAsUserW`, `CreateProcessWithTokenW`
- `WinExec`

**DLL loading** (potential DLL hijack):
- `LoadLibraryW`, `LoadLibraryExW`, `LoadLibraryA`

**Token and privilege** (confirms elevated context):
- `OpenProcessToken`, `DuplicateTokenEx`, `SetTokenInformation`
- `WTSQueryUserToken`, `ImpersonateLoggedOnUser`
- `AdjustTokenPrivileges`

**IPC** (potential input from untrusted callers):
- `CreateNamedPipeW`, `ConnectNamedPipe`, `CreatePipe`
- `CreateFileMappingW`, `MapViewOfFile`, `OpenFileMappingW`
- `ReadFile` (on pipes or shared memory)

**Registry and config** (path or value sources):
- `RegOpenKeyExW`, `RegQueryValueExW`
- `GetPrivateProfileStringW`, `GetPrivateProfileIntW`

**Service control** (handler structure):
- `RegisterServiceCtrlHandlerW`, `RegisterServiceCtrlHandlerExW`

### 3. Trace from imports to behavior

For each dangerous import, search the decompiled C for all call sites. Trace each argument back to its source. The question is always: **can an unprivileged user control the data that reaches this API?**

Sources to check:
- Service start arguments (passed via `ServiceMain` argc/argv)
- Named pipe input (if the pipe DACL allows unprivileged writers)
- Shared memory (if the section DACL allows unprivileged writers)
- Registry keys under HKCU or HKLM keys writable by Users
- INI/config files in user-writable directories
- Process enumeration (caller can create processes with chosen names/paths)
- Environment variables

### 4. For Windows services specifically

Trace the service control handler:

1. Find `RegisterServiceCtrlHandlerW` or `RegisterServiceCtrlHandlerExW` in the decompiled C.
2. The second argument is the handler function pointer. Read that function.
3. Map each control code to its behavior:
   - Standard codes: 1 (STOP), 2 (PAUSE), 3 (CONTINUE), 4 (INTERROGATE), etc.
   - User-defined codes: 128-255. These are the interesting ones for LPE.
4. For each user-defined code, trace what the handler does. Flag any code path that creates processes, loads DLLs, or reads from user-controllable sources.

Also check the service DACL (outside Ghidra, via `sc.exe sdshow <service>`). If standard users can send user-defined control codes (`SERVICE_USER_DEFINED_CONTROL` / `CR` in SDDL) to a SYSTEM service, and the handler does something dangerous with those codes, that's the LPE.

### 5. Write the analysis report

Structure the report as:

```
# Binary analysis: <filename>

## Overview
Size, function count, what the binary appears to do.

## Dangerous imports
Table: API | Call sites | Data source | User-controllable?

## Service control handler
Map of control codes to behavior. Flag exploitable paths.

## Risk assessment
CRITICAL / HIGH / MEDIUM / LOW with one-line justification.

## Exploitation path (if any)
Step-by-step from unprivileged user to code execution.
```

## Tips

- Ghidra's decompiler output uses auto-generated names (`FUN_140001234`, `DAT_140005678`). Trace by address, not by name.
- For large binaries (1000+ functions), start with the service entry point (`ServiceMain` or `wWinMain`) and follow the call graph rather than reading all functions.
- The export script decompiles with a 30-second timeout per function. Complex functions may be truncated.
- If a binary uses C++ with vtables, the decompiled output may show indirect calls through function pointers. Trace the vtable initialization to find the actual target.
