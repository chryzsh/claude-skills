---
name: c2-profile-author
description: Author, review, or modify Cobalt Strike 4.13 malleable C2 profiles with Beacon Booster compatibility, opsec hardening, and cross-profile separation for multi-actor simulation. Sub-profiles inherit a shared hardening baseline (reference_mod_413.profile) and differ only in theme/separation. Use when (1) creating new C2 profiles, (2) auditing/reviewing existing profiles for c2lint errors or opsec gaps, (3) theming profiles to mimic specific cloud/SaaS traffic, (4) comparing profiles for cross-attribution risk, or (5) fixing c2lint validation failures.
---

# CS 4.13 Malleable C2 Profile Author

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

- **CS 4.13**: `stage.rdll_loader`, `stage.smartinject`, and `stage.name` were removed. `PrependLoader` is now the only reflective loader and is implicit; smart inject is baseline behavior. `post-ex.smartinject` remains valid.

## Workflow

### Create

1. **Check reference freshness** - Compare local reference profile against upstream if CS version has changed
2. Read [references/profile-baseline.md](references/profile-baseline.md) - names which blocks are baseline (copy from `~/opt/c2/redteam-infra/profiles/reference_mod_413.profile`) vs theme/separation (build per sub-profile)
3. Read [references/c2-profile-constraints.md](references/c2-profile-constraints.md) for hard constraints and opsec baseline
4. Read [references/traffic-themes.md](references/traffic-themes.md) for theme patterns
5. Read `~/opt/c2/redteam-infra/profiles/reference_mod_413.profile` and one existing sub-profile (`cloudflare_413`, `m365_exchange_413`, etc.) from that same directory to match structure
6. If other profiles exist in the project, read them and consult [references/cross-profile-separation.md](references/cross-profile-separation.md)
7. Write the sub-profile into `~/opt/c2/redteam-infra/profiles/`: copy the baseline hardening blocks verbatim, build the theme layer against `traffic-themes.md`, vary the separation knobs
8. Self-review against the checklist below before delivering

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
beacon_gate { All; }       # baseline - MDE default; flip to Comms for CS/S1
# No transform-obfuscate, no prepend/append in stage transforms

# beacon_gate — pick by target EDR:
#
# Baseline: beacon_gate { All; }
#   MDE / Defender for Endpoint is the most common target in our engagements.
#   Booster's MDE hardening scanner flags anything less than All as a red mark
#   and auto-upgrades the config. Every profile in the set (reference_mod_413
#   and its sub-profiles) ships with All for this reason.
#
# Fallback: beacon_gate { Comms; }
#   CrowdStrike Falcon and SentinelOne hook obfuscated calls. All would route
#   Core APIs (VirtualAlloc, VirtualProtect, ...) through those hooked paths.
#   With Comms only, Core APIs fall through to syscall_method "Indirect" and
#   bypass userland hooks. Flip only for confirmed CS/S1 targets.

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
killdate "YYYYMMDD"               # engagement end date - beacon self-expires
```

`killdate` is mandatory ops hygiene: any beacon still calling home after engagement end is unauthorized access. Booster auto-injects it if missing; set it in the profile so a stale build can't outlive the engagement.

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
15. `killdate` set to engagement end date (YYYYMMDD)
16. `beacon_gate` matches target EDR (`All` for MDE default; `Comms` for CS/S1)

## Output Format

**Creating**: Complete `.profile` file with header comment, 4-space block indentation, minimal comments.

**Reviewing**: Structured report with FAIL/WARN/INFO severity levels.

## Reference Files

- [references/c2-profile-constraints.md](references/c2-profile-constraints.md) - All c2lint rules, Beacon Booster checklist, opsec baseline, strrep lengths, allocator compatibility, DoH config
- [references/cross-profile-separation.md](references/cross-profile-separation.md) - Multi-actor separation rules and differentiation checklist table
- [references/traffic-themes.md](references/traffic-themes.md) - Theme selection, anatomy of a convincing theme, examples for Exchange/OneDrive/GA/Cloudflare
- [references/beacon-booster-guide.txt](references/beacon-booster-guide.txt) - Full Beacon Booster documentation (UDRLs, sleepmasks, YARA bypasses, Update Config)
- [references/profile-baseline.md](references/profile-baseline.md) - Which blocks are baseline (must match `reference_mod_413`) vs theme/separation (must vary per sub-profile). Read before creating or editing any 4.13 profile.
- [references/profiles/](references/profiles/) - Upstream CS reference only:
  - `reference.413.profile` - Official CS 4.13 reference (upstream baseline, do not edit)

## Operational Profiles Live Elsewhere

Operational profiles are NOT stored in this skill. The canonical library lives at `~/opt/c2/redteam-infra/profiles/` (private repo), where the ansible plays read them for CS teamserver deploy:

- `reference_mod_413.profile` - **Azure Function redirector baseline** - hardening source of truth for all sub-profiles
- `cloudflare_413.profile` - Cloudflare CDN/API sub-profile
- `ganalytics_413.profile` - Google Analytics sub-profile
- `m365_exchange_413.profile` - Exchange Online/Outlook sub-profile (fenix-a)
- `onedrive_sync_413.profile` - OneDrive/SharePoint sync sub-profile (fenix-b)

This skill is the specification (structure, opsec constraints, baseline-vs-theme model); `~/opt/c2/redteam-infra/profiles/` is the implementation (values, killdates, engagement tuning). When creating or reviewing profiles, cross-reference both surfaces: read `references/profile-baseline.md` for the structural spec, then look at `~/opt/c2/redteam-infra/profiles/reference_mod_413.profile` for the canonical baseline in use.
