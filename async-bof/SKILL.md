---
name: async-bof
description: Async BOFs and async BOF-PEs, which run as a stoppable job on their own C2 thread using BeaconGetStopJobEvent and BeaconWakeup (Outflank async BOF spec, OC2 BOFType.ASYNC). Use this skill first, before or together with bof-development or bof-pe-development, whenever a BOF or BOF-PE must be async, run as a job, keep running, or report events over time, such as a BOF that should monitor, watch, wait for, or listen for something (new processes, file or share changes, event log entries, network connections) while the beacon keeps working. Also use it to convert an existing BOF or BOF-PE to async, to stop a BOF job cleanly, or to check which C2s support async BOFs. Not for one-shot BOFs that run and return.
---

# Async BOF Development

An async BOF runs on a thread the C2 creates, so the beacon keeps checking in while the BOF waits for events. This skill covers the parts that differ from a normal BOF: the two async API functions, thread and lifecycle rules, and testing.

For format basics, use the other skills:
- Plain COFF BOF (entry `go`, `MODULE$Function` imports): `bof-development`
- BOF-PE (linked PE, `BEACON_INIT`, `BEACON_MAIN`): `bof-pe-development`

Then read the matching reference here:
- [references/bof.md](references/bof.md): plain COFF async BOF example and notes
- [references/bof-pe.md](references/bof-pe.md): async BOF-PE specifics, including the MinGW exit crash
- [references/testing.md](references/testing.md): how to test standalone and under a C2

## The Spec

Source: Outflank, [Async BOFs: Wake me up before you go go](https://www.outflank.nl/blog/2025/07/16/async-bofs-wake-me-up-before-you-go-go/).

The spec adds two functions to `beacon.h`:

```c
DECLSPEC_IMPORT void BeaconWakeup();
DECLSPEC_IMPORT HANDLE BeaconGetStopJobEvent();
```

- The C2 runs the BOF entry point on its own thread.
- `BeaconGetStopJobEvent` returns a per-job event. The C2 signals it when the operator stops the job.
- `BeaconWakeup` makes the implant check in early, so output is delivered before the next sleep ends.

## Basic Shape

```c
HANDLE stop = BeaconGetStopJobEvent();   // via the volatile guard below
if (!stop) { BeaconPrintf(CALLBACK_ERROR, "async BOF API not available\n"); return; }

/* set up resources */
for (;;) {
    DWORD w = WaitForSingleObject(stop, 5000);   // or WaitForMultipleObjects
    if (w != WAIT_TIMEOUT) break;                 // stopped, or error
    /* check for events, collect output */
    if (have_output) { BeaconPrintf(CALLBACK_OUTPUT, "%s", batch); BeaconWakeup(); }
}
/* release every resource, then return */
```

## Detecting the Async API (GCC)

With GCC, a plain `BeaconGetStopJobEvent != nullptr` check on a dllimport function is optimized away. GCC assumes a function address is never NULL, so if the loader leaves the import NULL, the BOF calls a NULL pointer. This was confirmed in disassembly, and GCC warns about it with `-Waddress` ("the comparison will always evaluate as 'true'"). Read the address through a volatile local:

```cpp
static HANDLE GetStopEvent() {
    decltype(&BeaconGetStopJobEvent) volatile fn = &BeaconGetStopJobEvent;
    return fn != nullptr ? fn() : nullptr;
}
```

Guard `BeaconWakeup` the same way if it can run on that error path. NetSPI BOFscale's socksportfwd uses the plain check, so do not copy that part. The C form is in [references/bof.md](references/bof.md).

What each check covers:
- **Address guard.** Covers a loader that runs the BOF with the import set to NULL. The BOF-PE proof-of-concept loader does this. The COFF loaders checked from source (trustedsec and Sliver COFFLoader, Havoc Demon, Adaptix) refuse to run a BOF with an unknown `Beacon*` import, and Cobalt Strike documents the same for unresolved functions. Under those, the operator sees a load error, not the BOF's message. Per-loader sources are in [references/bof.md](references/bof.md).
- **NULL handle check.** Covers a C2 that has the API but runs the BOF as a normal task. Adaptix returns NULL from `BeaconGetStopJobEvent` on a thread with no async job context. This is the case most BOFs hit in practice, so always check the returned handle.

## Thread and Lifecycle Rules

- **Wait on the stop event, not Sleep.** Use `WaitForSingleObject` or `WaitForMultipleObjects` with the stop event in the handle set. A `Sleep` loop cannot react to a stop request until it wakes.
- **Never close the stop event handle.** The C2 owns it.
- **Call BeaconWakeup only when there is output to deliver.** Each call forces an early check-in.
- **Batch output per event.** Build one buffer per event or per wait cycle and send it in one call, instead of many small `BeaconPrintf` calls.
- **Release every resource before the entry point returns.** Handles, subscriptions, heap memory, COM objects. The C2 frees the BOF after the entry returns, and any callback still registered then points into freed memory.
- **Expect a thread the C2 created.** It has not joined a COM apartment. If you use COM, call `CoInitializeEx` yourself, and call `CoUninitialize` only if it returned `S_OK` or `S_FALSE`.
- **Callbacks arrive on other threads.** APIs such as `EvtSubscribe` call back on threads the BOF did not create. Do not call Beacon output functions there. Queue the data under a lock and print it from the BOF thread. See "Output From Other Threads" below.
- **Impersonation may not carry over.** A token applied with `make_token` or `steal_token` may not apply to the C2's async thread, so network authentication may silently use the beacon's base identity. This is not verified per C2. Test it if the BOF touches the network.
- **Fail clearly without the async API.** A BOF that requires async must detect the API and print a clear error when it is missing.

## Output From Other Threads

Call `BeaconPrintf`, `BeaconOutput`, and `BeaconGetStopJobEvent` only from the thread the C2 started for the BOF. Evidence from Adaptix C2 (beacon agent, commit `e99535c`):
- The job context is thread-local: `__declspec(thread) AsyncBofContext* tls_CurrentBofContext` (`Boffer.cpp:7`). Only the C2's async thread sets it (`Boffer.cpp:108`).
- `BofOutputToTask` sends output to the job only if that thread-local context is set (`beacon_functions.cpp:17-30`, `48-51`). On a callback thread it is NULL, so output goes to the global synchronous BOF buffer instead, with no lock and with the global `bofTaskId`.
- That global buffer exists only after a synchronous BOF has run (`bof_loader.cpp:30-34`). `bofTaskId` is 0 between tasks, or the ID of an unrelated synchronous BOF that is running (`bof_loader.cpp:316`, `360`). The buffer is sent and cleared only when a synchronous BOF finishes (`Commander.cpp:364-373`).
- Result: output from a callback thread is dropped (no buffer yet), held until some unrelated BOF finishes and then sent under the wrong task ID, or written while the main thread writes the same buffer.
- `BeaconGetStopJobEvent` on a callback thread returns NULL for the same reason (`beacon_functions.cpp:478-484`).
- `BeaconWakeup` only calls `SetEvent` on a global event (`beacon_functions.cpp:472-476`, `Boffer.cpp:360-364`), so it works from any thread. Still call it from the BOF thread after printing, so the wakeup follows the output.

Other implementations: the standalone `beacon.dll` in chryzsh/BOF-PE async locks console output (`beacon/beacon.cpp:188`), so a callback-thread print works there and a standalone test does not show the Adaptix problem. trustedsec COFFLoader appends output to a global buffer with `realloc` and no lock (`beacon_compatibility.c:258-280`).

## Checklist

Do:
- Get the stop event on the BOF thread, through the volatile guard, and exit with an error if the handle is NULL.
- Put the stop event in every wait.
- Send one output batch per event, then call `BeaconWakeup`.
- Unregister callbacks and subscriptions before freeing anything they use.
- Use a lock or a queue for any state shared with callback threads.
- Test the stop path and the missing-API path, not only the event path.

Don't:
- Use `Sleep` as the main loop delay.
- Call `CloseHandle` on the stop event.
- Call `BeaconWakeup` on every loop iteration.
- Call `BeaconPrintf` or `BeaconOutput` from a thread the C2 did not start, even with your own lock. In Adaptix the job context is thread-local, so that output is dropped or sent under the wrong task. Queue it and print from the BOF thread.
- Rely on a plain `!= NULL` check of an imported function under GCC.
- Assume `make_token` or `steal_token` applies to the async thread.

## C2 Support

Per an Outflank developer:

| C2 | Status |
|----|--------|
| Outflank C2 (OC2) | Supported |
| Cobalt Strike | Current 4.x async implementation lacks the two functions. Expected in the next release |
| Nighthawk | Reported to follow the spec |
| Havoc Pro | Reported to follow the spec |
| Adaptix C2 | Reported to follow the spec |
| Conquest | Reported to follow the spec |

OC2 notes:
- The `.s1.py` script sets `bof_type=BOFType.ASYNC`.
- Name the script `<name>_bof.s1.py`. OC2 does not load `<name>.s1.py`, logs no error, and the command shows as "Command not found".
- Run the BOF through its script command, which sends `exec_bof_async`. Plain `exec_bof` runs it sync, and OC2 then fails with "BOF-PE unable to resolve function BeaconGetStopJobEvent from beacon.dll".
- The runtime looks for `<base_binary_name>.x64.o` and `.x86.o`, so install BOF-PE builds under that name too.

## Reference Implementations

- Adaptix C2 `beacon_functions.cpp` and `Boffer.cpp`: keeps the per-job stop event and output buffer in a thread-local context, set only on the C2's async thread. Output from that thread is buffered per job under a lock.
- NetSPI BOFscale socksportfwd: an async BOF-PE. Its OC2 script uses `bof_type=BOFType.ASYNC`.
- [chryzsh/BOF-PE async branch](https://github.com/chryzsh/BOF-PE/tree/async): `beacon/beacon.h` with the async API and the MinGW exit fix, and `samples/procwatch`, an async BOF-PE that reports process start and exit.
