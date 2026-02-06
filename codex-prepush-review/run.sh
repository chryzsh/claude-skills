#!/usr/bin/env bash

# codex-prepush-review
#
# Usage:
#   ./run.sh <commit-ref>
#
# Example:
#   ./run.sh HEAD
#   ./run.sh abc1234
#

set -euo pipefail

COMMIT_REF="${1:-HEAD}"

# Verify the commit ref is valid
if ! git rev-parse --verify "$COMMIT_REF" >/dev/null 2>&1; then
  echo "Error: '$COMMIT_REF' is not a valid git commit reference" >&2
  exit 1
fi

RESOLVED_SHA="$(git rev-parse "$COMMIT_REF")"

PROMPT=$(
  cat <<EOF
Run git show $RESOLVED_SHA to see the changes in this commit, then review them.

Goal: find likely bugs, missing edge cases, type-safety issues, security issues, and missing tests.

Be strict on correctness; avoid large refactors unless necessary.

Output format:

1) Blockers (must-fix before push)

2) Important (should-fix)

3) Nits (optional)

4) Missing tests (specific test cases)

5) Questions for the author (only if truly needed)

EOF
)

RAW_OUT="$(mktemp -t codex-prepush-review.XXXXXX)"

codex exec --json "$PROMPT" | awk -v f="$RAW_OUT" '{
  print > f
  c++
  printf "\rlines: %d", c > "/dev/stderr"
} END { print "" > "/dev/stderr" }'

cat "$RAW_OUT" | jq -r 'select(.type=="item.completed" and .item.type=="agent_message") | .item.text'
