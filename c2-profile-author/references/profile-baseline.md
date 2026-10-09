# Profile Baseline: reference_mod_413

`reference_mod_413.profile` is the hardening baseline for Cobalt Strike 4.13 profiles fronted by an Azure Function redirector. Every themed sub-profile shares the hardening layer with this file and differs only in the HTTP theme and cross-profile-separation values.

**Where profiles live.** Operational profiles belong in a separate private repo alongside your teamserver deployment automation. This skill contains only methodology (constraints, checklists, this baseline spec) and the upstream CS reference.

**Rule of thumb**: if it protects the beacon (allocator, syscalls, obfuscation, memory perms, drip loading, kill switches), it comes from the baseline. If it shapes what the traffic *looks like* or distinguishes this operator from another, it's theme-specific.

**Path convention throughout this doc:** unqualified `reference_mod_413.profile` refers to your operational copy of the baseline profile.

---

## Baseline blocks — copy verbatim from `reference_mod_413.profile`

Any drift in this list is a bug. When updating the hardening posture, edit `reference_mod_413.profile` first, then propagate to every sub-profile in one commit.

### Global settings

```
set host_stage "false";
set smb_frame_header "";
set tcp_frame_header "";
set headers_remove "";
set steal_token_access_mask "11";
set tasks_max_size "104857600";
set tasks_proxy_max_size "94371840";
set tasks_dns_proxy_max_size "71680";
```

**Do NOT add `set killdate` here or anywhere else in the profile.** It's not a malleable C2 option and c2lint rejects it at every scope. Killdate is applied by Beacon Booster's Update Config to the compiled `.bin`, or by Aggressor Script at teamserver runtime.

### `stage {}` — hardening core

Copy the entire block from `reference_mod_413.profile` except the four items listed under "Theme/separation" below.

Baseline settings (fixed):

```
set checksum "0";
set data_store_size "16";
set copy_pe_header       "true";
set eaf_bypass           "true";
set rdll_use_syscalls    "true";
set rdll_use_driploading "true";
set allocator            "VirtualAlloc";
set cleanup              "true";
set magic_pe             "PE";
set obfuscate            "true";
set sleep_mask           "true";
set syscall_method       "Indirect";
set stomppe              "true";
set userwx               "false";

beacon_gate {
  Comms;                            # Comms + syscall_method "Indirect" is optimal (never All)
}
```

### `process-inject {}` — hardening core

Baseline settings (fixed):

```
set allocator        "VirtualAllocEx";
set use_driploading  "true";
set min_alloc        "16384";
set startrwx         "false";
set userwx           "false";
set bof_allocator    "VirtualAlloc";
set bof_reuse_memory "true";

transform-x64 {
    # empty in baseline; per-profile prepend is allowed for separation
}

execute {
    ObfSetThreadContext;
    CreateThread "ntdll.dll!RtlUserThreadStart";
    SetThreadContext;
    NtQueueApcThread-s;
    NtQueueApcThread;
    CreateRemoteThread;
    RtlCreateUserThread;
}
```

### `post-ex {}` — hardening core (not pipe/spawn)

Baseline settings (fixed):

```
set obfuscate     "true";
set smartinject   "true";
set amsi_disable  "true";
set keylogger     "GetAsyncKeyState";
set cleanup       "true";
```

`spawnto_x86`, `spawnto_x64`, `pipename`, and `transform-x86 / transform-x64` are theme/separation — see below.

---

## Theme / separation — MUST differ per profile

These are the seams that make one operator distinguishable from another and each profile plausible for its target service. Never copy these values between profiles.

### Global identity

| Setting | Purpose | Example values |
|---|---|---|
| `sample_name` | Human-readable profile label | "Microsoft Telemetry Agent", "Cloudflare Worker Runtime" |
| `pipename` | SMB beacon peer-to-peer pipe | Must be plausible for the theme |
| `pipename_stager` | Stager pipe | Must be plausible for the theme |
| `ssh_pipename` | Post-ex SSH pipe | Must be unique per profile |
| `ssh_banner` | SSH server banner | Different OS/version per profile |
| `sleeptime` | Beacon sleep in ms | Vary 25000-45000 |
| `jitter` | Sleep jitter percent | Vary 33-50 |
| `data_jitter` | Response padding | Vary 48-72 |
| `tcp_port` | TCP beacon port | Unique per profile |

### HTTP theme (entire blocks — theme-specific)

All of these blocks are shaped by the impersonated service and must be built per profile against `references/traffic-themes.md`:

- `dns-beacon { }` — DNS labels, subhost, DoH server and DoH UA
- `http-config { }` — server headers, Server value, custom headers
- `https-certificate { }` — CN, O, OU, L, ST matching the impersonated service
- `http-stager { }` — URIs, parameters, response body prepend/append
- `set useragent` — matching a plausible client for the service
- `http-get { }` — URI, headers, metadata format, cookie name
- `http-post { }` — URI, headers, output/id format
- `http-beacon { }` — `data_required_length` varied (e.g. 128-384, 192-448, 256-512)

### Stage separation knobs (differ per profile, still within baseline shape)

| Setting | Baseline in reference_mod | Vary per profile |
|---|---|---|
| `rdll_dripload_delay` | `"100"` | 100 or 150 |
| `compile_time` | fixed | random plausible date |
| `entry_point` | fixed | random plausible offset |
| `stringw` | fixed | theme-matching decoy string |
| `transform-x86 strrep` / `transform-x64 strrep` | fixed | theme-matching module name replacements |

### Process-inject separation knobs

| Setting | Baseline in reference_mod | Vary per profile |
|---|---|---|
| `dripload_delay` | `"100"` | 100 or 150 |
| `transform-x86 prepend` | `"\x90\x90"` | 2 or 4 NOP-equivalent bytes (or omit entirely) |
| `execute {}` ordering | fixed | one-line reorder of `NtQueueApcThread-s` / `SetThreadContext` |

### Post-ex separation knobs

| Setting | Vary per profile |
|---|---|
| `spawnto_x86`, `spawnto_x64` | dllhost.exe, RuntimeBroker.exe, wmiprvse.exe -Embedding, SearchProtocolHost.exe, backgroundTaskHost.exe — unique per profile |
| `pipename` | Theme-plausible, unique per profile |
| `transform-x86 strrepex/strrep` | Theme-plausible replacement strings |

---

## Sub-profile creation checklist

When creating a new themed sub-profile from this baseline:

1. Copy `reference_mod_413.profile` as the starting point.
2. Replace the file header with the new theme identifier and target scenario.
3. Rewrite the global identity block (sample_name, pipes, ssh_banner, tcp_port, sleeptime, jitter, data_jitter).
4. Rewrite the entire HTTP theme layer (dns-beacon, http-config, https-certificate, http-stager, useragent, http-get, http-post, http-beacon).
5. Vary the stage separation knobs (dripload_delay, compile_time, entry_point, stringw, transform strrep values).
6. Vary the process-inject separation knobs (dripload_delay, transform prepend, execute ordering).
7. Vary the post-ex separation knobs (spawnto, pipename, transform strrepex/strrep).
8. Confirm every baseline setting above still matches `reference_mod_413.profile` verbatim.
9. Run c2lint; run the diff against every other profile in the set.

## Baseline update workflow

When the hardening posture changes (new CS release, new Booster requirement, new EDR target):

1. Edit `reference_mod_413.profile` first.
2. Update this document if the baseline vs theme split changed.
3. Propagate the baseline change to every sub-profile in the same commit.
4. Run c2lint on every profile.

## YARA rule mitigation via profile strreps — DON'T TRY

**Empirically ineffective in CS 4.13 with `host_stage "false"` and stageless `.csrl` exports.**

We tried this — added two length-preserving strreps in `stage.transform-x86 {}` and `stage.transform-x64 {}` to defeat two rules that share `printf` format strings:

```
strrep "%s as %s\\%s: %d" "%s at %s\\%s: %d"
strrep "%02d/%02d/%02d %02d:%02d:%02d" "%02d.%02d.%02d %02d.%02d.%02d"
```

Target rules: `HKTL_Win_CobaltStrike` (Volexity, `all of them`) and `Windows_Trojan_CobaltStrike_3dc22d14` (Elastic, `all of them`). Break either shared string and both rules should die.

**Deployed via `./run_cs_profile_refresh.sh skatt-q3` (c2lint passed, container restarted, active.profile SHA verified against repo). Result: zero change in Booster's YARA panel.** All five rules still triggered pre-boost with every string still matching. Both parsers we tried on the exported `.csrl` and `.bin` (`1768.py` and `CobaltStrikeParser`) failed even to locate the standard stageless-beacon layout — the file is wrapped by something (Booster-independent) before the classic CS beacon body starts. `strings` on the export shows nothing meaningful either way. We couldn't verify from disk whether the strreps applied to the packed beacon.

Definitive proof would require detonation + memory dump + `strings` on the unpacked process memory — not worth it. The practical conclusion:

**Rely on Beacon Booster's UDRL/sleepmask for YARA-rule bypass at runtime.** Profile-side `stage.transform` strreps are effective for *theme-fingerprint* changes (`ReflectiveLoader` → `WorkerInit`, `beacon.x64.dll` → `clrjit.dll`) — those visibly affect cross-profile separation and impersonation posture — but do not appear to reach the exported artifact in a way that changes what a YARA scanner sees. If you need YARA-rule coverage without Booster, the fix is at the loader layer (custom UDRL, sleepmask, or beacon repacker), not at the profile.

### YARA rules seen triggering pre-boost on our current baseline (all defeated post-boost by Booster)

| Rule | Author | Match kind | Fixable via profile? |
|---|---|---|---|
| `Windows_Trojan_CobaltStrike_663fc95d` | Elastic | 32-byte x64 function-prologue code pattern | No — needs UDRL |
| `Windows_Trojan_CobaltStrike_3dc22d14` | Elastic | 2 printf format strings, `all of them` | No — strrep didn't reach export |
| `CodeX_CobaltStrike_sleepmask` | CodeX | ~50-byte sleep-mask function prologue | No — needs custom sleepmask |
| `HKTL_Win_CobaltStrike` | Volexity | 6 strings + 1 hex HTTP header, `all of them` | No — strrep didn't reach export |
| `MALW_cobaltrike` | Felix Bilstein | 16 opcode patterns, 7-of-16 threshold | No — needs UDRL |

Rule sources archived alongside the operational profiles for reference.
