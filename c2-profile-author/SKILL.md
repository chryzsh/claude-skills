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

## Workflow

### Create

1. Read [references/c2-profile-constraints.md](references/c2-profile-constraints.md) for hard constraints and opsec baseline
2. Read [references/traffic-themes.md](references/traffic-themes.md) for theme patterns
3. If other profiles exist in the project, read them and consult [references/cross-profile-separation.md](references/cross-profile-separation.md)
4. Write the profile following block order, constraints, and Beacon Booster checklist
5. Self-review against the checklist below before delivering

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
rdll_use_driploading "true", beacon_gate { All; }
# No transform-obfuscate, no prepend/append in stage transforms

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

- [references/c2-profile-constraints.md](references/c2-profile-constraints.md) - All c2lint rules, Beacon Booster checklist, opsec baseline, strrep lengths, allocator compatibility
- [references/cross-profile-separation.md](references/cross-profile-separation.md) - Multi-actor separation rules and differentiation checklist table
- [references/traffic-themes.md](references/traffic-themes.md) - Theme selection, anatomy of a convincing theme, examples for Exchange/OneDrive/GA/Cloudflare
