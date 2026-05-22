#!/usr/bin/env bash
# Smoke test for scripts/new-topic.sh.
# Spins a temp vault, invokes new-topic.sh against it, asserts file shape.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/new-topic.sh"

PASS=0; FAIL=0
ok()   { echo "  ok   $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

mk_vault() {
  local d
  d=$(mktemp -d -t ccvault.XXXXXX)
  echo "$d"
}

# Tests will be filled in by Task 6.
test_placeholder() { :; }

test_placeholder

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
