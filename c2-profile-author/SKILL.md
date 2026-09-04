---
name: c2-profile-author
description: Author, review, or modify Cobalt Strike 4.12+ malleable C2 profiles with Beacon Booster compatibility, opsec hardening, and cross-profile separation for multi-actor simulation. Use when (1) creating new C2 profiles, (2) auditing/reviewing existing profiles for c2lint errors or opsec gaps, (3) theming profiles to mimic specific cloud/SaaS traffic, (4) comparing profiles for cross-attribution risk, or (5) fixing c2lint validation failures.
---

# CS 4.12 Malleable C2 Profile Author

## Modes

- `create <theme>` - Create a new profile themed as a service (e.g., "cloudflare", "slack", "teams")
- `review <file>` - Audit a profile for c2lint errors, opsec gaps, Beacon Booster issues
- `theme <file> <new-theme>` - Re-theme an existing profile
- `diff <file1> <file2>` - Check two profiles for cross-attribution indicators

No argument? Ask what the user needs.

## Upstream Reference Profile

The official CS reference profile (updated each release) lives at:
https://github.com/Cobalt-Strike/Malleable-C2-Profiles/blob/master/normal/reference.profile

**Freshness check**: Before creating or reviewing profiles, verify that the local reference in `references/profiles/` matches the target CS version. When upgrading CS, fetch the latest upstream reference and diff it against the previous local reference for new, renamed, or removed options and changed defaults.

## Profiles Are Version-Sensitive

Malleable C2 grammar and defaults change between Cobalt Strike releases. Removed options cause a hard c2lint error such as `Error: invalid option for <.stage>`; they are not silently ignored.

When upgrading CS:

1. Fetch the latest upstream reference profile.
2. Diff it against the previous local reference in `references/profiles/`.
3. Look for lines marked `# Removed in X.Y`; these options break older profiles on the new release.
4. Record removed or renamed options in [references/c2-profile-constraints.md](references/c2-profile-constraints.md) under a release-specific section.

Known removals:

- **CS 4.13**: `stage.rdll_loader` and `stage.smartinject` were removed. `PrependLoader` is now the only reflective loader and is implicit; smart inject is baseline behavior.

## Workflow

### Create

1. **Check reference freshness** - Compare local reference profile against upstream if CS version has changed
2. Read [references/c2-profile-constraints.md](references/c2-profile-constraints.md) for hard constraints and opsec baseline
3. Read [references/traffic-themes.md](references/traffic-themes.md) for theme patterns
4. Read example profiles in [references/profiles/](references/profiles/) to match quality and structure
5. If other profiles exist in the project, read them and consult [references/cross-profile-separation.md](references/cross-profile-separation.md)
6. Write the profile following block order, constraints, and Beacon Booster checklist
7. Self-review against the checklist below before delivering

### Review

1. Read the profile
2. Read [references/c2-profile-constraints.md](references/c2-profile-constraints.md)
3. Check every item in the review checklist
4. Report findings as **FAIL** (c2lint rejects), **WARN** (opsec/Booster), **INFO** (suggestion)

### Diff

1. Read both profiles
2. Read [references/cross-profile-separation.md](references/cross-profile-separation.md)
3. Fill in the differentiation checklist table
4. Flag any shared values that should differ

## Top 7 Errors (most common, hardest to spot)

1. **strrep too long** - `"beacon.dll"` is 10 chars. Always count before writing.
2. **Pipe names < 3 hashes** - Every pipe template (pipename, pipename_stager, post-ex.pipename) needs >= 3 `#`. Check each comma-separated entry independently.
3. **`parameter` as output terminator** - Never use `parameter` inside `output {}` in http-post. Use `uri-append`, `print`, or `header`.
4. **`ALL` instead of `All`** in beacon_gate - case-sensitive, capital first letter only.
5. **Stager URI + params >= 80 bytes** - Total line length, not just the URI path.
6. **Wrong allocator for drip loading** - `VirtualAlloc` (stage) and `VirtualAllocEx` (inject) required. `MapViewOfFile`/`NtMapViewOfSection` silently ignore drip loading.
7. **`tasks_proxy_max_size` >= `tasks_max_size`** - Proxy max must be strictly less. Use 104857600 / 94371840.

## Profile Block Order

```
# Header comment
# Global settings (sample_name, data_jitter, host_stage, sleeptime, jitter, pipes, ssh, tcp)
dns-beacon {}
http-config {}
https-certificate {}
http-stager {}
set useragent
http-get {}
http-post {}
http-beacon {}
stage {}
process-inject {}
post-ex {}
```

## Beacon Booster Required Settings

```
# stage {}
sleep_mask "true", cleanup "true", syscall_method "Indirect"
allocator "VirtualAlloc"   # required for drip loading
rdll_use_driploading "true"
beacon_gate { Comms; }     # NOT All - see below
# No transform-obfuscate, no prepend/append in stage transforms

# beacon_gate does obfuscated calls, NOT syscalls.
# All = Core APIs use obfuscated calls instead of indirect syscalls,
#        which gets caught by CrowdStrike/S1 hooks.
# Comms = only masks HTTP APIs; Core APIs use syscall_method "Indirect"
#          to bypass EDR userland hooks. This is the optimal combo.

# process-inject {}
allocator "VirtualAllocEx"  # required for drip loading
use_driploading "true", startrwx "false", userwx "false"
bof_reuse_memory "true", min_alloc "16384"

# post-ex {}
spawnto != rundll32.exe
```

## Standard Global Settings

```
tasks_max_size "104857600"        # 100MB - avoid task size errors
tasks_proxy_max_size "94371840"   # ~90MB - MUST be < tasks_max_size
```

## Review Checklist

1. URI lengths <= 63 bytes (stager URI + params < 80)
2. All strrep replacements <= original length
3. All pipe names have >= 3 `#` per comma-separated template
4. No `parameter` terminators inside `output {}` blocks
5. `beacon_gate` uses `All` not `ALL`
6. Allocator matches drip loading (`VirtualAlloc` stage, `VirtualAllocEx` inject)
7. `tasks_proxy_max_size` < `tasks_max_size`
8. No transform-obfuscate / no prepend|append in stage transforms
9. All Beacon Booster required settings present
10. All opsec defaults changed (host_stage, ssh_banner, pipes, tcp_port, UA, cert, jitter)
11. obfuscate, stomppe, userwx false, startrwx false
12. Safe spawnto, unique post-ex pipes, obfuscate true
13. Theme consistency (headers, URIs, UA, cert, cookies match one service)
14. Cross-profile separation (if multiple profiles exist)

## Output Format

**Creating**: Complete `.profile` file with header comment, 4-space block indentation, minimal comments.

**Reviewing**: Structured report with FAIL/WARN/INFO severity levels.

## Reference Files

- [references/c2-profile-constraints.md](references/c2-profile-constraints.md) - All c2lint rules, Beacon Booster checklist, opsec baseline, strrep lengths, allocator compatibility, DoH config
- [references/cross-profile-separation.md](references/cross-profile-separation.md) - Multi-actor separation rules and differentiation checklist table
- [references/traffic-themes.md](references/traffic-themes.md) - Theme selection, anatomy of a convincing theme, examples for Exchange/OneDrive/GA/Cloudflare
- [references/beacon-booster-guide.txt](references/beacon-booster-guide.txt) - Full Beacon Booster documentation (UDRLs, sleepmasks, YARA bypasses, Update Config)
- [references/profiles/](references/profiles/) - Production profiles and upstream reference:
  - `reference.412.profile` - Official CS 4.12 reference (upstream baseline)
  - `reference_mod_412.profile` - Hardened Azure/API theme (aco-a scenario)
  - `ganalytics_412.profile` - Google Analytics theme
  - `cloudflare_412.profile` - Cloudflare CDN/API theme
  - `m365_exchange_412.profile` - Exchange Online/Outlook theme (fenix-a)
  - `onedrive_sync_412.profile` - OneDrive/SharePoint sync theme (fenix-b)
