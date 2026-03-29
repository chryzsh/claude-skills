# Cross-Profile Separation for Multi-Actor Simulation

When running multiple profiles that must not be attributable to the same operator, threat actor, or CS teamserver, every correlated indicator must differ.

## Table of Contents
- [Must Differ Between Profiles](#must-differ-between-profiles)
- [Can Share (Low Correlation)](#can-share-low-correlation)
- [Differentiation Checklist](#differentiation-checklist)

---

## Must Differ Between Profiles

### Network Indicators
- All URIs (http-get, http-post, http-stager)
- User-Agent string
- Server response headers and content type
- Cookie/metadata prefix and encoding scheme (base64 vs base64url vs netbios)
- TLS certificate fields (CN, O, OU, L, ST)
- Sleep time and jitter values
- `data_jitter` value
- `data_required_length` range
- `tasks_max_size` and `tasks_proxy_max_size`

### DNS Indicators
- DNS beacon subdomain prefixes (beacon, get_A, get_AAAA, get_TXT, put_metadata, put_output)
- DNS beacon subdomain suffixes
- `dns_stager_subhost`
- DoH server (`cloudflare-dns.com` vs `dns.google`)
- DoH user-agent

### Named Pipes
- `pipename`
- `pipename_stager`
- `ssh_pipename`
- `post-ex.pipename`

### Host Indicators
- `sample_name`
- `ssh_banner`
- `tcp_port`
- Spawn-to process (post-ex.spawnto_x86, spawnto_x64)
- `stringw` value

### Binary Indicators
- `strrep` replacement strings (stage transforms)
- `strrepex` replacement strings (post-ex transforms)
- `compile_time`
- `entry_point`

### Injection Indicators
- `allocator` choice (vary `VirtualAllocEx` vs `NtMapViewOfSection`)
- `bof_allocator` choice (vary `VirtualAlloc` vs `MapViewOfFile` vs `HeapAlloc`)
- NOP sleds in `process-inject.transform-x86` (`\x90\x90` vs `\x90\x90\x90\x90`)
- `execute {}` block order (shuffle the methods)
- `dripload_delay` values

---

## Can Share (Low Correlation)

These are best-practice settings many hardened profiles use. Sharing them has low attribution risk:

```
host_stage "false"
userwx "false"
startrwx "false"
obfuscate "true"
sleep_mask "true"
cleanup "true"
stomppe "true"
beacon_gate { All; }
syscall_method "Indirect"
bof_reuse_memory "true"
```

---

## Differentiation Checklist

Use this checklist when creating a new profile alongside existing ones. For each row, verify the new profile uses a **different value** from every existing profile:

| Category | Setting | Profile A | Profile B | New Profile |
|---|---|---|---|---|
| Theme | service mimicked | | | |
| Network | http-get URI | | | |
| Network | http-post URI | | | |
| Network | http-stager URIs | | | |
| Network | User-Agent | | | |
| Network | Server header | | | |
| Network | Cookie prefix | | | |
| Network | metadata encoding | | | |
| TLS | CN | | | |
| TLS | O, OU | | | |
| Timing | sleeptime | | | |
| Timing | jitter | | | |
| Timing | data_jitter | | | |
| DNS | subdomain prefixes | | | |
| DNS | dns_stager_subhost | | | |
| DNS | DoH server | | | |
| Pipes | pipename | | | |
| Pipes | pipename_stager | | | |
| Pipes | ssh_pipename | | | |
| Pipes | post-ex pipename | | | |
| Host | spawnto | | | |
| Host | ssh_banner | | | |
| Host | tcp_port | | | |
| Binary | stringw | | | |
| Binary | strrep replacements | | | |
| Binary | strrepex replacements | | | |
| Binary | compile_time | | | |
| Binary | entry_point | | | |
| Inject | allocator | | | |
| Inject | bof_allocator | | | |
| Inject | NOP sled | | | |
| Inject | execute order | | | |
| Inject | dripload_delay | | | |
