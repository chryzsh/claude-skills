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

With GCC, a plain `BeaconGetStopJobEvent != nullptr` check on a dllimport function is optimized away. GCC assumes a function address is never NULL, so under a C2 without the async API the BOF calls a NULL pointer. This was confirmed in disassembly. Read the address through a volatile local:

```cpp
static HANDLE GetStopEvent() {
    decltype(&BeaconGetStopJobEvent) volatile fn = &BeaconGetStopJobEvent;
    return fn != nullptr ? fn() : nullptr;
}
```

Guard `BeaconWakeup` the same way if it can run on that error path. NetSPI BOFscale's socksportfwd uses the plain check, so do not copy that part. The C form is in [references/bof.md](references/bof.md).

## Thread and Lifecycle Rules

- **Wait on the stop event, not Sleep.** Use `WaitForSingleObject` or `WaitForMultipleObjects` with the stop event in the handle set. A `Sleep` loop cannot react to a stop request until it wakes.
- **Never close the stop event handle.** The C2 owns it.
- **Call BeaconWakeup only when there is output to deliver.** Each call forces an early check-in.
- **Batch output per event.** Build one buffer per event or per wait cycle and send it in one call, instead of many small `BeaconPrintf` calls.
- **Release every resource before the entry point returns.** Handles, subscriptions, heap memory, COM objects. The C2 frees the BOF after the entry returns, and any callback still registered then points into freed memory.
- **Expect a thread the C2 created.** It has not joined a COM apartment. If you use COM, call `CoInitializeEx` yourself, and call `CoUninitialize` only if it returned `S_OK` or `S_FALSE`.
- **Callbacks arrive on other threads.** APIs such as `EvtSubscribe` call back on threads the BOF did not create. Queue output from the callback and drain it on the BOF thread, or protect shared output with a lock.
- **Impersonation may not carry over.** A token applied with `make_token` or `steal_token` may not apply to the C2's async thread, so network authentication may silently use the beacon's base identity. This is not verified per C2. Test it if the BOF touches the network.
- **Fail clearly without the async API.** A BOF that requires async must detect the API and print a clear error when it is missing.

## Checklist

Do:
- Get the stop event through the volatile guard and exit with an error if it is NULL.
- Put the stop event in every wait.
- Send one output batch per event, then call `BeaconWakeup`.
- Unregister callbacks and subscriptions before freeing anything they use.
- Use a lock or a queue for any state shared with callback threads.
- Test the stop path and the missing-API path, not only the event path.

Don't:
- Use `Sleep` as the main loop delay.
- Call `CloseHandle` on the stop event.
- Call `BeaconWakeup` on every loop iteration.
- Call `BeaconPrintf` from a callback thread without a lock, unless the C2 documents that it is safe.
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
- The runtime looks for `<base_binary_name>.x64.o` and `.x86.o`, so install BOF-PE builds under that name too.

## Reference Implementations

- Adaptix C2 `beacon_functions.cpp`: keeps a per-job stop event in thread-local context, and buffers output from async threads per job under a lock.
- NetSPI BOFscale socksportfwd: an async BOF-PE. Its OC2 script uses `bof_type=BOFType.ASYNC`.
- [chryzsh/BOF-PE async branch](https://github.com/chryzsh/BOF-PE/tree/async): `beacon/beacon.h` with the async API and the MinGW exit fix, and `samples/procwatch`, an async BOF-PE that reports process start and exit.
