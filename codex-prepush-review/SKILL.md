---
name: codex-prepush-review
description: Run OpenAI Codex locally to review changes before pushing
---

# Codex Pre-Push Review

Use this skill when instructed by the user, typically when finished implementing work and ready to push.

## Purpose

Run OpenAI Codex locally to review changes introduced by a specific commit. Use Codex as a review partner -- evaluate its findings critically and push back where you disagree. Iterate until you reach consensus.

## When to use

When instructed by the user. Invoke with: `/codex-prepush-review <commit-ref>`

Where `<commit-ref>` is a git commit hash, branch name, or ref (e.g. `HEAD`, `abc1234`, `feature-branch`).

## Workflow

1. Run `~/.claude/skills/codex-prepush-review/run.sh <commit-ref>` to get Codex's initial review.
2. Read Codex's findings carefully. For each item, decide whether you agree or disagree based on the actual code.
3. If you disagree with any finding, run the script again with a modified prompt (via a follow-up `codex exec`) that explains your counterargument and asks Codex to reconsider.
4. Repeat for 3-4 iterations or until you and Codex reach consensus on all points.
5. Present the final consolidated review to the user, noting:
   - Items both you and Codex agree are issues
   - Items where you disagreed and the resolution
   - Your own additional findings (if any)

## Review categories

1. Blockers (must-fix before push)
2. Important (should-fix)
3. Nits (optional)
4. Missing tests (specific test cases)
5. Questions for the author (only if truly needed)

## Guidelines

- Be an active reviewer, not a passive relay. Read the diff yourself and form your own opinion before deferring to Codex.
- Push back on false positives. If Codex flags something that isn't actually a problem, say so and explain why.
- Acknowledge when Codex catches something you missed.
- The goal is consensus through constructive disagreement, not rubber-stamping.
