#!/usr/bin/env bash
# Smoke test for scripts/session-start-context.sh.
# Constructs fixture topic dirs, pipes JSON via stdin, asserts JSON output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/session-start-context.sh"

PASS=0; FAIL=0
ok()   { echo "  ok   $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

mk_vault() {
  local d
  d=$(mktemp -d -t cchook.XXXXXX)
  echo "$d"
}

# Tests will be filled in by Task 8.
test_placeholder() { :; }

test_placeholder

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
