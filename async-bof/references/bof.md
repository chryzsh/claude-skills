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

The C++ form (`decltype(...) volatile fn`) was confirmed in disassembly. For this C form, the example below was compiled with `x86_64-w64-mingw32-gcc -Os`, and `objdump -dr` shows the `__imp_BeaconGetStopJobEvent` slot loaded and tested before the call. Check the disassembly again after you build with other flags or compilers.

How a COFF loader without the async API treats the unresolved symbol depends on the loader. Some may refuse to load the BOF, others may resolve it to NULL. The guard only helps in the second case. This is not verified per loader.

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

For APIs that call back on their own threads (for example `EvtSubscribe` with a callback, or thread pool waits), do not write output from the callback directly. Push the event into a buffer protected by a lock, or a queue, and signal a second event. The BOF thread waits on both the stop event and that event with `WaitForMultipleObjects`, drains the buffer, sends one batch, and calls `BeaconWakeup`. Unregister the callback before freeing the buffer.
