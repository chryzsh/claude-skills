# Async Plain COFF BOF

Use this with the `bof-development` skill. Everything there still applies: entry `go`, `MODULE$Function` imports, no CRT, goto cleanup.

## Declarations

Add the two async functions to `beacon.h`:

```c
DECLSPEC_IMPORT void BeaconWakeup(void);
DECLSPEC_IMPORT HANDLE BeaconGetStopJobEvent(void);
```

## Volatile Guard in C

The GCC problem is the same as in C++: a plain `BeaconGetStopJobEvent != NULL` check is optimized away because GCC assumes a function address is never NULL. In C, read the address through a volatile function pointer:

```c
static HANDLE GetStopEvent(void) {
    HANDLE (*volatile fn)(void) = &BeaconGetStopJobEvent;
    return fn != NULL ? fn() : NULL;
}

static void Wakeup(void) {
    void (*volatile fn)(void) = &BeaconWakeup;
    if (fn != NULL) fn();
}
```

`HANDLE (*volatile fn)(void)` is a volatile-qualified pointer to a function, which is valid C. It compiles without warnings under `-std=c99 -Wall -Wextra -pedantic`.

Disassembly check: the guard was built as a COFF object (`-c`, the way BOFs are built) with MinGW GCC 15 (`x86_64-w64-mingw32-gcc` and `i686-w64-mingw32-gcc`, each at `-O2` and `-Os`). In all four builds, `objdump -dr` shows the `__imp_BeaconGetStopJobEvent` slot loaded, tested, and skipped when NULL, before the call. x86_64 `-O2`:

```
mov    0x0(%rip),%rax        IMAGE_REL_AMD64_REL32  __imp_BeaconGetStopJobEvent
mov    %rax,0x20(%rsp)
mov    0x20(%rsp),%rax
test   %rax,%rax
je     <error path>
call   *%rax
```

i686 shows the same shape with `dir32 __imp__BeaconGetStopJobEvent`. A plain `BeaconGetStopJobEvent != NULL ? BeaconGetStopJobEvent() : NULL` in the same file compiles to a bare `jmp *__imp_BeaconGetStopJobEvent` with no test, and GCC warns `the comparison will always evaluate as 'true'` (`-Waddress`). Treat that warning as a bug. Check the disassembly again if you change compiler.

### What the Guard Covers

The guard tests the slot the loader filled in. It helps only if the loader runs the BOF with that slot set to NULL. COFF loaders checked from source:

| Loader | Unknown `__imp_Beacon*` import | Source |
|--------|--------------------------------|--------|
| trustedsec COFFLoader | Refuses to run. `process_symbol` returns NULL, the loader stops before `go`. The message is a `DEBUG_PRINT` only | `COFFLoader.c:131-175`, `386-391` (commit `edfa763`) |
| Sliver COFFLoader (sliverarmory) | Refuses to run, same code | `COFFLoader.c:421-425` (commit `28e4981`) |
| Havoc Demon CoffeeLdr (open source) | Refuses to run. Sends `SYMBOL_NOT_FOUND` with the symbol name, then `COULD_NO_RUN`. Has no async API | `src/core/CoffeeLdr.c:102-120`, `232-238`, `471-474`, `764-787` (commit `c84f775`) |
| Adaptix C2 beacon agent | Resolves both async functions. An unknown `Beacon*` name fails with `BOF_ERROR_SYMBOL` and the BOF does not run | `bof_loader.cpp:86-87`, `98-131`, `223-228` (commit `e99535c`) |
| Cobalt Strike | Documented for Dynamic Function Resolution: "Cobalt Strike will refuse to execute the BOF and tell you which function it couldn't resolve." Unknown `Beacon*` names are not documented | [CS user guide, Dynamic Function Resolution](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/beacon-object-files_dynamic-func-resolution.htm) |

So for a plain COFF BOF:
- No checked loader resolves a missing Beacon import to NULL. Under a C2 without the async API, expect a load error that names `BeaconGetStopJobEvent`, not your own error message.
- The common runtime case is a C2 that has the API but runs the BOF as a normal, synchronous task. Adaptix then returns NULL from `BeaconGetStopJobEvent`, because the thread has no async job context (`beacon_functions.cpp:478-484`). The `if (!stop)` check on the returned handle covers this case, not the address guard.
- Keep the guard anyway. It costs a few instructions and covers a loader that writes NULL for an unknown import. The BOF-PE proof-of-concept loader does this (see [bof-pe.md](bof-pe.md)).

## Example: Watch a Path

This example waits on the stop event, checks every 5 seconds whether a path exists, and reports when that changes. It calls `BeaconWakeup` only on a change.

**Status: untested.** It compiles with MinGW but has not been run under a C2 or loader. Lint it and test it before use.

```c
#include <windows.h>
#include "beacon.h"

DECLSPEC_IMPORT void BeaconWakeup(void);
DECLSPEC_IMPORT HANDLE BeaconGetStopJobEvent(void);

DECLSPEC_IMPORT DWORD WINAPI KERNEL32$WaitForSingleObject(HANDLE, DWORD);
DECLSPEC_IMPORT DWORD WINAPI KERNEL32$GetFileAttributesW(LPCWSTR);
DECLSPEC_IMPORT DWORD WINAPI KERNEL32$GetLastError(void);

#define POLL_MS 5000

static HANDLE GetStopEvent(void) {
    HANDLE (*volatile fn)(void) = &BeaconGetStopJobEvent;
    return fn != NULL ? fn() : NULL;
}

static void Wakeup(void) {
    void (*volatile fn)(void) = &BeaconWakeup;
    if (fn != NULL) fn();
}

static BOOL PathExists(const wchar_t* path) {
    return KERNEL32$GetFileAttributesW(path) != INVALID_FILE_ATTRIBUTES;
}

void go(char* args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);
    wchar_t* path = (wchar_t*)BeaconDataExtract(&parser, NULL);
    if (!path || !path[0]) {
        BeaconPrintf(CALLBACK_ERROR, "usage: pathwatch <path>\n");
        return;
    }

    /* Do not close this handle. The C2 owns it. */
    HANDLE stop = GetStopEvent();
    if (!stop) {
        BeaconPrintf(CALLBACK_ERROR, "async BOF API not available in this C2; run as an async job\n");
        return;
    }

    BOOL last = PathExists(path);
    BeaconPrintf(CALLBACK_OUTPUT, "watching %S (exists=%d)\n", path, last);
    Wakeup();

    for (;;) {
        DWORD w = KERNEL32$WaitForSingleObject(stop, POLL_MS);
        if (w == WAIT_OBJECT_0) break;
        if (w != WAIT_TIMEOUT) {
            BeaconPrintf(CALLBACK_ERROR, "wait failed: %u\n", KERNEL32$GetLastError());
            break;
        }

        BOOL now = PathExists(path);
        if (now != last) {
            BeaconPrintf(CALLBACK_OUTPUT, "%S %s\n", path, now ? "created" : "removed");
            Wakeup();
            last = now;
        }
    }

    BeaconPrintf(CALLBACK_OUTPUT, "stopped\n");
}
```

Notes:
- The example holds no resources, so there is no cleanup block. If you add handles or heap memory, use the goto cleanup pattern from `bof-development` and free everything before `go` returns.
- The argument is one wide string. Pack it as `Z` in the C2 script.
- For OC2, set `bof_type=BOFType.ASYNC` in the `.s1.py` script.

## Event Sources Other Than Polling

For APIs that call back on their own threads (for example `EvtSubscribe` with a callback, or thread pool waits), do not call `BeaconPrintf` or `BeaconOutput` from the callback. In Adaptix that output does not reach the job (see "Output From Other Threads" in SKILL.md). Push the event into a buffer protected by a lock, or a queue, and signal a second event. The BOF thread waits on both the stop event and that event with `WaitForMultipleObjects`, drains the buffer, sends one batch, and calls `BeaconWakeup`. Unregister the callback before freeing the buffer.
