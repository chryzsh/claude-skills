# Testing Async BOFs

Test three paths for every async BOF:
1. **Event path**: the BOF detects the event, sends output, and wakes the beacon.
2. **Stop path**: the BOF exits cleanly when the stop event is signaled, and releases all resources.
3. **Missing-API path**: under a C2 or loader without the async API, the BOF prints a clear error and returns, instead of crashing.

## Standalone BOF-PE with beacon.dll

The standalone `beacon.dll` in [chryzsh/BOF-PE async](https://github.com/chryzsh/BOF-PE/tree/async):
- signals the stop event on Ctrl+C or Ctrl+Break
- prints a `[wakeup]` marker each time the BOF calls `BeaconWakeup`

Check that `[wakeup]` appears once per batch of output, not once per loop iteration.

### Without a console (WinRM)

A WinRM session has no console, so you cannot press Ctrl+C. Use a small harness that:
1. starts the BOF-PE in a new process group (`CREATE_NEW_PROCESS_GROUP`)
2. waits for it to run for a while and trigger events
3. sends `CTRL_BREAK_EVENT` to that process group with `GenerateConsoleCtrlEvent`
4. collects the output and exit code

Copy the harness and the BOF-PE to the test host over SMB and run them by path.

### Defender

Defender quarantines `beacon.dll` as `VirTool:Win64/MeterBof.A` when it loads, even with real-time protection off. Add an exclusion for the test folder before the test and remove it afterwards.

## Under the C2

Testing under the C2 avoids `beacon.dll` entirely and runs the BOF on the real C2 thread. This is the only way to check:
- whether `make_token` or `steal_token` impersonation applies to the async thread (test network access with and without it)
- how the C2 handles output from the async thread and the stop command
- that the host process stays up after the job stops and at process exit (for MinGW BOF-PEs, see the exit crash in [bof-pe.md](bof-pe.md))

## Example Results

`samples/procwatch` in [chryzsh/BOF-PE async](https://github.com/chryzsh/BOF-PE/tree/async) was tested on Windows 11 build 26100 for:
- process start and exit detection
- `BeaconWakeup` calls
- stop through Ctrl+C and Ctrl+Break
- the missing-API error path
