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

# Test 1: default mode (no flag) → learning, with .cc-mode written
test_default_mode() {
  local vault topic
  vault=$(mk_vault)
  CC_CHAT_VAULT="$vault" "$SCRIPT" demo-default "Demo Default" >/dev/null
  topic="$vault/demo-default"

  [[ -f "$topic/.cc-mode" ]]                         && ok ".cc-mode written" \
                                                     || fail ".cc-mode missing"
  [[ "$(cat "$topic/.cc-mode")" == "learning" ]]     && ok ".cc-mode contains 'learning'" \
                                                     || fail ".cc-mode wrong: $(cat "$topic/.cc-mode")"
  [[ -f "$topic/CLAUDE.md" ]]                        && ok "topic CLAUDE.md deployed" \
                                                     || fail "topic CLAUDE.md missing"
  [[ -d "$topic/concepts" ]]                         && ok "concepts/ created (learning)" \
                                                     || fail "concepts/ missing"
  [[ -f "$topic/_map.md" ]] && grep -q "Demo Default" "$topic/_map.md" \
                                                     && ok "_map title substituted" \
                                                     || fail "_map title not substituted"
  rm -rf "$vault"
}

# Test 2: --mode personal → personal artifacts only
test_personal_mode() {
  local vault topic
  vault=$(mk_vault)
  CC_CHAT_VAULT="$vault" "$SCRIPT" --mode personal personal "Personal" >/dev/null
  topic="$vault/personal"

  [[ "$(cat "$topic/.cc-mode")" == "personal" ]]     && ok "personal: .cc-mode=personal" \
                                                     || fail "personal: wrong .cc-mode"
  [[ -f "$topic/_profile.md" ]]                      && ok "personal: _profile.md created" \
                                                     || fail "personal: _profile.md missing"
  [[ -d "$topic/positions" ]]                        && ok "personal: positions/ created" \
                                                     || fail "personal: positions/ missing"
  [[ ! -d "$topic/concepts" ]]                       && ok "personal: concepts/ NOT created" \
                                                     || fail "personal: concepts/ wrongly created"
  [[ ! -d "$topic/chapters" ]]                       && ok "personal: chapters/ NOT created" \
                                                     || fail "personal: chapters/ wrongly created"
  grep -q "Personal" "$topic/_profile.md"            && ok "personal: _profile title substituted" \
                                                     || fail "personal: _profile title not substituted"
  [[ -f "$topic/_map.md" ]] && grep -q "Personal" "$topic/_map.md" \
                                                     && ok "personal: _map.md created + title substituted" \
                                                     || fail "personal: _map.md missing or title not substituted"
  [[ -f "$topic/_index.md" ]]                        && ok "personal: _index.md created" \
                                                     || fail "personal: _index.md missing"
  [[ ! -d "$topic/examples" ]]                       && ok "personal: examples/ NOT created" \
                                                     || fail "personal: examples/ wrongly created"
  [[ ! -d "$topic/refs" ]]                           && ok "personal: refs/ NOT created" \
                                                     || fail "personal: refs/ wrongly created"
  [[ ! -d "$topic/questions" ]]                      && ok "personal: questions/ NOT created" \
                                                     || fail "personal: questions/ wrongly created"
  rm -rf "$vault"
}

# Test 3: invalid --mode → script exits non-zero, no topic created
test_invalid_mode() {
  local vault rc
  vault=$(mk_vault)
  set +e
  CC_CHAT_VAULT="$vault" "$SCRIPT" --mode bogus x "X" >/dev/null 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]]                                    && ok "invalid mode: exits non-zero ($rc)" \
                                                     || fail "invalid mode: exited 0"
  [[ ! -d "$vault/x" ]]                              && ok "invalid mode: no topic dir created" \
                                                     || fail "invalid mode: topic dir created"
  rm -rf "$vault"
}

# Test 4: --mode placed after positional args → script rejects it (Fix 1 guard)
test_mode_after_slug_rejected() {
  local vault rc
  vault=$(mk_vault)
  set +e
  CC_CHAT_VAULT="$vault" "$SCRIPT" foo "Foo" --mode personal >/dev/null 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]]                                    && ok "extra arg: exits non-zero ($rc)" \
                                                     || fail "extra arg: exited 0 (silent ignore)"
  [[ ! -d "$vault/foo" ]]                            && ok "extra arg: no topic dir created" \
                                                     || fail "extra arg: topic dir created"
  rm -rf "$vault"
}

test_default_mode
test_personal_mode
test_invalid_mode
test_mode_after_slug_rejected

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
