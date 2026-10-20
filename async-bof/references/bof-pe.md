# Async BOF-PE

Use this with the `bof-pe-development` skill. The `go` export, `BEACON_INIT`, and `BEACON_MAIN` work as described there.

## Imports and Language Features

- Beacon API imports come from `beacon.dll` through the compat layer, so `BeaconGetStopJobEvent` and `BeaconWakeup` are normal imports declared in `beacon.h`.
- C++ exceptions are available.
- MinGW `try`/`catch` catches C++ exceptions only. It does not catch access violations. To catch those, build with clang-cl or MSVC and `/EHa`.

## Volatile Guard

Use the volatile guard from SKILL.md for `BeaconGetStopJobEvent`, and for `BeaconWakeup` if it can run on the missing-API error path. The plain `!= nullptr` check is removed by GCC.

The guard matters more for BOF-PEs than for COFF BOFs. The proof-of-concept loader in chryzsh/BOF-PE async writes the result of `GetProcAddress(beacon.dll, name)` into the import slot with no NULL check (`loader/mappedmodule.cpp:64`, `102`). Non-beacon imports do fail on NULL. A C2 BOF-PE loader built the same way runs the BOF with the slot set to NULL.

## MinGW Exit Crash

MinGW BOF-PEs crash the host process at exit unless you handle this.

Cause:
1. `BEACON_INIT` calls `__main`, which registers `__do_global_dtors` with `atexit`.
2. libstdc++ statics register destructors the same way.
3. MinGW forwards these registrations to the CRT's process-wide exit table.
4. The C2 frees the image after `go` returns. At process exit, the CRT calls the registered destructors, which are now in freed memory.

Fix used in [chryzsh/BOF-PE async](https://github.com/chryzsh/BOF-PE/tree/async) (`beacon/beacon.h`):
- In `BEACON_INIT`, before calling `__main`, point the image's `atexit` import (`__imp__crt_atexit`) at a local stub. On msvcrt-linked builds that slot is the `atexit` import.

Limits:
- Static destructors never run under a C2. Do not put required cleanup in static destructors. Clean up explicitly before `go` returns.
- `_onexit` registrations are not covered by this fix.
- MSVC and clang-cl builds with the static CRT keep the exit table inside the image and are not affected.

## Structure

```cpp
#include <windows.h>
#include <beacon.h>

static HANDLE GetStopEvent() {
    decltype(&BeaconGetStopJobEvent) volatile fn = &BeaconGetStopJobEvent;
    return fn != nullptr ? fn() : nullptr;
}

static void Wakeup() {
    decltype(&BeaconWakeup) volatile fn = &BeaconWakeup;
    if (fn != nullptr) fn();
}

extern "C" __declspec(dllexport) void go(const char* data, int len) {
    BEACON_INIT;

    HANDLE stop = GetStopEvent();
    if (!stop) {
        BeaconPrintf(CALLBACK_ERROR, "async BOF API not available in this C2\n");
        return;
    }

    // Set up the event source. Keep ownership local so everything is
    // released before go returns. Static destructors do not run under a C2.

    for (;;) {
        DWORD w = WaitForSingleObject(stop, 1000);
        if (w != WAIT_TIMEOUT) break;
        // Collect events into one buffer, send once, then Wakeup().
    }

    // Release every resource here.
}

BEACON_MAIN("", go)  // "" = no arguments; one format char per argument, e.g. "Zi"
```

`BEACON_MAIN(fmt, go)` only affects standalone runs: it defines `main`, which passes `fmt` to `BeaconInvokeStandalone` (`beacon/beacon.h:244-250`). Under a C2, the C2 packs the arguments. From the source of `GetPackedArguments` (`common/standalone.cpp:96-142`) and `BeaconInvokeStandalone` (`beacon/beacon.cpp:305-318`), with an empty format string:
- No arguments: `go` runs with an empty buffer and `len` 0.
- One or more arguments: it prints `Not enough arguments to satisfy BOF packed args with definition` (the check is `argc-1 > strlen(fmt)`, so the message really means too many), does not call `go`, and the process exits with 0.

The skeleton above, with `BEACON_MAIN("", go)`, builds with the branch's MinGW x64 toolchain and exports `go`. The runtime behavior is from source only and was not run on Windows. If the BOF takes arguments, set one format character per argument (`z`, `Z`, `i`, `s`, `b`).

For a complete working sample, see `samples/procwatch` in [chryzsh/BOF-PE async](https://github.com/chryzsh/BOF-PE/tree/async). It reports process start and exit and was tested on Windows 11 build 26100. See [testing.md](testing.md).

## OC2 Packaging

- The OC2 runtime looks for `<base_binary_name>.x64.o` and `<base_binary_name>.x86.o`. Install the BOF-PE build under that name, even though it is a PE.
- In the `.s1.py` script, set `bof_type=BOFType.ASYNC`. NetSPI BOFscale socksportfwd is an example.
