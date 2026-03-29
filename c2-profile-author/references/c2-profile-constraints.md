# Cobalt Strike 4.12 Malleable C2 - Hard Constraints & Opsec Baseline

## Table of Contents
- [c2lint Hard Constraints](#c2lint-hard-constraints)
- [Beacon Booster Compatibility](#beacon-booster-compatibility)
- [Opsec Baseline](#opsec-baseline)
- [Profile Block Order & Syntax](#profile-block-order--syntax)
- [CS 4.12 Features](#cs-412-features)
- [Complete strrep Length Reference](#complete-strrep-length-reference)

---

## c2lint Hard Constraints

Violations in this section cause c2lint rejection or silent runtime failures.

### URI Length

All URIs must be **<= 63 bytes**:
- `http-get { set uri }`
- `http-post { set uri }`
- `http-stager { set uri_x86 }` and `{ set uri_x64 }`

**http-stager has a stricter combined limit**: URI + all `parameter` entries must total **< 80 bytes**.

Example that fails:
```
# URI = 29 bytes, but with parameters "realm=office365.com&whr=office365.com" = 66+ bytes total
set uri_x86 "/owa/auth/logon.aspx";
parameter "realm" "office365.com";
parameter "whr" "office365.com";
```
Keep stager URIs short and parameters minimal.

### strrep Replacement Length

`strrep "original" "replacement"` performs an **in-place binary overwrite**. The replacement string must be **<= the length of the original**. CS cannot expand the DLL.

| Original String | Max Length | Example Valid Replacement |
|---|---|---|
| `"ReflectiveLoader"` | 16 | `"SyncProvider"` (12) |
| `"beacon.x64.dll"` | 14 | `"filesync64.dl"` (13) |
| `"beacon.dll"` | 10 | `"fsync.dll"` (9) |
| `"is alive."` | 9 | `"is sync."` (8) |
| `"Scanner module is complete"` | 26 | `"Upload finished"` (15) |

**Always count characters before writing strrep.** This is the single most common profile error.

### Transform + Recover Rules

Every `output {}` block needs a data terminator that CS can recover server-side.

**Safe terminators for http-post client `output {}`**: `uri-append`, `print`, `header "name"`

**NEVER use `parameter "name"` as terminator inside `output {}` blocks** in http-post. This causes `NegativeArraySizeException` in c2lint and transform+recover failures at runtime.

`parameter` is fine as a **static decorator outside** output/metadata/id blocks:
```
client {
    parameter "v" "1";        # OK - outside output block
    output {
        mask;
        base64url;
        uri-append;           # OK - safe terminator
    }
}
```

### beacon_gate Syntax

Group keywords are **case-sensitive** with capital first letter:
- `All` (Comms + Core + Cleanup)
- `Comms` (InternetOpenA, InternetConnectA)
- `Core` (VirtualAlloc, VirtualProtect, etc.)
- `Cleanup` (ExitThread via Sleepmask)

**`ALL` (all caps) is invalid** and will fail to compile.

Individual APIs use PascalCase: `VirtualAlloc;`, `InternetConnectA;`, `VirtualProtect;`

### Allocator + Drip Loading

| Block | Drip Loading Setting | Required Allocator | Incompatible Allocator |
|---|---|---|---|
| `stage {}` | `rdll_use_driploading "true"` | `allocator "VirtualAlloc"` | `MapViewOfFile` (silently ignored) |
| `process-inject {}` | `use_driploading "true"` | `allocator "VirtualAllocEx"` | `NtMapViewOfSection` (silently ignored) |

c2lint warns but does not error on mismatch. Drip loading silently does nothing with the wrong allocator.

### General Syntax

- Every statement inside a block ends with `;`
- String values always double-quoted
- Comments use `#`
- `set` keyword for settings, bare keywords for directives

---

## Beacon Booster Compatibility

Beacon Booster UDRLs (Tower Loader, Lucky Strike) and sleepmasks require:

### MUST NOT include in stage transforms

- `stage.transform-obfuscate {}` - omit entirely or leave at defaults
- `prepend` or `append` in `stage.transform-x86 {}` or `stage.transform-x64 {}`
- `set image_size_x86` or `set image_size_x64`
- Any PE header modifications that alter the RAW DLL structure

### Safe in stage transforms

- `strrep` - string replacements (don't change structure)
- `stringw` - adding wide strings

### Required Settings Checklist

These must all be present for Beacon Booster's "Update Config" to pass:

```
# stage {}
set sleep_mask "true";
set cleanup "true";
set syscall_method "Indirect";
set rdll_use_driploading "true";
beacon_gate { All; }           # at minimum Comms

# process-inject {}
set use_driploading "true";
set startrwx "false";
set userwx "false";
set bof_reuse_memory "true";
set min_alloc "16384";

# post-ex {}
set spawnto_x64 "%windir%\\sysnative\\dllhost.exe";   # anything except rundll32.exe
set spawnto_x86 "%windir%\\syswow64\\dllhost.exe";    # anything except rundll32.exe
```

---

## Opsec Baseline

These defaults **must** be changed from stock values:

| Setting | Default (bad) | Recommended |
|---|---|---|
| `host_stage` | `"true"` | `"false"` |
| `ssh_banner` | `"Cobalt Strike 4.x"` | Realistic SSH banner |
| `sample_name` | `"Test Profile"` | Descriptive name |
| `pipename` | `msagent_###` | Unique pattern |
| `pipename_stager` | `status_##` | Unique pattern |
| `tcp_port` | `4444` | Any other port |
| `useragent` | IE11/Trident | Modern Chrome/Edge UA |
| `https-certificate CN` | `localhost` | Matching domain |
| `https-certificate O` | `FooCorp` | Matching org |
| `jitter` | `"0"` | `"20"` - `"50"` |
| `data_jitter` | `"0"` | `"40"` - `"80"` |

### Memory & Injection Opsec

```
# stage {}
set obfuscate "true";       # obfuscate import table and headers
set userwx "false";         # no RWX for beacon DLL
set stomppe "true";         # stomp PE headers after load

# process-inject {}
set startrwx "false";       # RW initial, not RWX
set userwx "false";         # no RWX at runtime
```

### Post-Ex Opsec

**spawnto** - avoid these (flagged):
- `rundll32.exe` (default, heavily signatured)
- `WerFault.exe` (increasingly flagged)

Good choices:
- `dllhost.exe`
- `wmiprvse.exe -Embedding`
- `RuntimeBroker.exe`
- `SearchProtocolHost.exe`
- `backgroundTaskHost.exe`

**pipename** - use unique patterns, not `msrpc_####`

**obfuscate** - always `"true"`

---

## Profile Block Order & Syntax

Standard block ordering:
```
# 1. Header comment (theme, version, compatibility, scenario)
# 2. Global settings
set sample_name "...";
set data_jitter "...";
set host_stage "false";
set sleeptime "...";
set jitter "...";
set pipename "...";
set pipename_stager "...";
set ssh_banner "...";
set ssh_pipename "...";
set tcp_port "...";

# 3. dns-beacon {}
# 4. http-config {}
# 5. https-certificate {}
# 6. http-stager {}
# 7. set useragent
# 8. http-get {}
# 9. http-post {}
# 10. http-beacon {}
# 11. stage {}
# 12. process-inject {}
# 13. post-ex {}
```

---

## CS 4.12 Features

New/changed in 4.12 vs 4.11:
- `stage.rdll_use_driploading` - drip loading for reflective loader
- `stage.rdll_dripload_delay` - delay between drip load chunks (ms)
- `process-inject.use_driploading` - drip loading for process injection
- `process-inject.dripload_delay` - delay for injection drip loading (ms)
- `stage.copy_pe_header` - changed default behavior
- `stage.rdll_loader` - `StompLoader` no longer supported, `PrependLoader` only
- `stage.transform-obfuscate` - rc4 key length max corrected to 128
- `stage.stringw` - uncommented by default in reference

---

## Complete strrep Length Reference

When writing `strrep`, always verify: `len(replacement) <= len(original)`.

Quick character counting trick: type out the string and count. Include all characters between the quotes.

Common mistakes:
- `"beacon.dll"` is 10 chars, NOT 14 (that's `"beacon.x64.dll"`)
- `"is alive."` is 9 chars (includes the period)
- Replacement `".dll"` extension adds 4 chars to the base name
