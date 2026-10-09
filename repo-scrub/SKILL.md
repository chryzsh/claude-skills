---
name: repo-scrub
description: |
  Audit a git repository for internal details before making it public.
  Searches for company names, personal identifiers, customer data,
  internal hostnames/IPs, home directory paths, and engagement artifacts.
  Reports findings by severity and offers to fix them.
---

# Repo scrub: prepare a private repository for public release

Audit every tracked file in the current git repository for content that
should not appear in a public repo. Report findings grouped by severity,
then offer to fix them.

## What to search for

Run each search category against all tracked files (`git ls-files`).
Exclude `.git/` internals. Search both the working tree and, once the
tree is clean, sample the git log for the same patterns (scrubbing the
tree is not enough if the history ships too).

### Category 1: Identity and affiliation (HIGH)

- Company or organization names, project codenames, team names
- Personal names, usernames, email addresses (outside of standard
  git author fields which the user controls separately)
- Employer-specific directory conventions (e.g. `C:\<company>_*`,
  `/home/<username>/`)

Regex seeds (case-insensitive, adapt to the repo):
```
/home/<user>/
C:\\<org>
@<domain>
```

### Category 2: Customer and engagement data (HIGH)

- Customer or target names, domains, account names that look like
  they came from a real engagement rather than a generic example
- Hostnames with non-example TLDs (`.internal`, `.corp`, `.local` are
  OK only if clearly generic; `customer-dc01.somecorp.local` is not)
- Real IP addresses from engagement environments (as opposed to
  RFC 5737 documentation ranges like 192.0.2.0/24, 198.51.100.0/24,
  203.0.113.0/24, or generic RFC 1918 examples)

### Category 3: Internal infrastructure (MEDIUM)

- Internal hostnames that identify the author's lab or environment
  (e.g. `chrisr-lab-dc01`)
- Internal tool paths, deployment scripts, or directory structures
  that reveal how the author's environment is laid out
- References to internal services, dashboards, or ticket systems

### Category 4: Process artifacts (MEDIUM)

- Code review checklists, review tracker docs, planning documents
  that contain internal review details, personal tool paths, or
  lab-specific test results
- AI/LLM tool paths (e.g. `/home/user/.claude/skills/...`) in
  committed artifacts

### Category 5: Credentials and secrets (CRITICAL)

- Hardcoded passwords, API keys, tokens (not just variable names
  like `password` in source code that handles passwords)
- Private keys, certificates
- `.env` files, credential stores

### Category 6: Git history (HIGH)

After the working tree is scrubbed, check whether the same patterns
appear in git history:
```
git log --all -p | grep -iP '<pattern>'
```
If they do, flag that the history needs rewriting (squash or
filter-repo) before the repo goes public.

## How to report findings

Group findings by severity. For each finding, state:
- **File and line** (or "git history" if only in history)
- **What it contains** (the actual string, quoted)
- **Why it's a problem** (one phrase: "company name", "engagement
  account", "personal lab hostname", etc.)
- **Suggested replacement** (a generic placeholder, or "delete")

## How to fix

After reporting, offer to apply the fixes. Follow these principles:

- Replace internal names with generic equivalents (`jsmith`,
  `dc01.corp.local`, `10.0.0.1`, `CORP\alice`, `example.local`)
- Delete files that are purely internal process artifacts (review
  checklists, planning docs) rather than scrubbing line by line
- For git history: recommend squashing to a single commit or using
  `git filter-repo` if the user wants to preserve some history
- Verify tests still pass after scrubbing

## What is NOT a finding

These are fine in a public repo and should not be flagged:

- Generic RFC 1918 addresses used illustratively (10.0.0.1,
  192.168.1.50, 10.10.10.50)
- Standard example domains (corp.local, example.local, example.com,
  contoso.com)
- Generic example usernames (alice, bob, admin, john, jsmith)
- Product names of public tools (Cobalt Strike, OC2, Sliver, etc.)
- The author's public GitHub username in `.gitmodules` or LICENSE
- Technical terms that happen to contain words like "secret",
  "password", "token" in code that handles those concepts
  (e.g. `PolicySecret`, `CredentialBlob`, `hToken`)
- Source code comments explaining what security-relevant code does
