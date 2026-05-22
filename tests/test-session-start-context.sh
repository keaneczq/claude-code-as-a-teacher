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

# Helper: invoke hook with a fake cwd, return additionalContext text.
# Sets CC_CHAT_VAULT so the hook accepts the temp-dir cwd (the hook's
# vault-root validation otherwise rejects anything outside ~/Keane/cc-chat).
invoke_hook() {
  local cwd="$1"
  local vault
  vault=$(dirname "$cwd")
  echo "{\"cwd\":\"$cwd\"}" | CC_CHAT_VAULT="$vault" "$SCRIPT" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("hookSpecificOutput",{}).get("additionalContext",""), end="")'
}

invoke_hook_sysmsg() {
  local cwd="$1"
  local vault
  vault=$(dirname "$cwd")
  echo "{\"cwd\":\"$cwd\"}" | CC_CHAT_VAULT="$vault" "$SCRIPT" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("systemMessage",""), end="")'
}

# Build a minimal learning-mode topic fixture.
seed_learning_topic() {
  local vault="$1" name="$2"
  local topic="$vault/$name"
  mkdir -p "$topic/transcripts"
  cat > "$topic/_index.md" <<'EOF'
# fixture topic
## handoff
- last consolidated: 2026-05-20
- next: keep going on widget X
EOF
  # No .cc-mode written — exercises the missing-sentinel fallback.
  echo "$topic"
}

# Build a personal-mode topic fixture with profile + positions/foo.
seed_personal_topic() {
  local vault="$1" name="$2"
  local topic="$vault/$name"
  mkdir -p "$topic/transcripts" "$topic/positions"
  echo personal > "$topic/.cc-mode"
  cat > "$topic/_profile.md" <<'EOF'
# Profile fixture
- key trait A
- key trait B
EOF
  cat > "$topic/positions/foo.md" <<'EOF'
# Foo
## 当前立场
fixture stance
EOF
  cat > "$topic/_index.md" <<'EOF'
# fixture
## 焦点子主题
- positions/foo
## 上次结束时的 handoff
keep going
EOF
  echo "$topic"
}

# Test A: missing .cc-mode → treated as learning, output matches pre-change.
test_missing_sentinel_is_learning() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_learning_topic "$vault" "fe")
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "missing sentinel: handoff header present" \
    || fail "missing sentinel: handoff header absent"
  echo "$out" | grep -q "key trait A" \
    && fail "missing sentinel: leaked _profile content (should NOT)" \
    || ok "missing sentinel: no _profile content"
  rm -rf "$vault"
}

# Test B: .cc-mode=personal → injects _profile and positions/<focus>.
test_personal_injects_profile_and_positions() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "personal")
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "personal: handoff header present" \
    || fail "personal: handoff header absent"
  echo "$out" | grep -q "key trait A" \
    && ok "personal: _profile content injected" \
    || fail "personal: _profile content missing"
  echo "$out" | grep -q "fixture stance" \
    && ok "personal: focus positions content injected" \
    || fail "personal: focus positions content missing"
  rm -rf "$vault"
}

# Test C: invalid .cc-mode value → fallback to learning + systemMessage warning.
test_invalid_sentinel_warns() {
  local vault topic out msg
  vault=$(mk_vault)
  topic=$(seed_learning_topic "$vault" "x")
  echo bogus > "$topic/.cc-mode"
  out=$(invoke_hook "$topic")
  msg=$(invoke_hook_sysmsg "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "invalid sentinel: still emits handoff (learning fallback)" \
    || fail "invalid sentinel: no handoff emitted"
  echo "$msg" | grep -q ".cc-mode" \
    && ok "invalid sentinel: systemMessage mentions .cc-mode" \
    || fail "invalid sentinel: no warning in systemMessage"
  rm -rf "$vault"
}

# Test D: personal with missing focus positions/<x>.md → still injects profile,
#         systemMessage warns, no crash.
test_personal_missing_focus_file() {
  local vault topic out msg
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  rm "$topic/positions/foo.md"
  out=$(invoke_hook "$topic")
  msg=$(invoke_hook_sysmsg "$topic")
  echo "$out" | grep -q "key trait A" \
    && ok "missing focus: _profile still injected" \
    || fail "missing focus: _profile missing"
  echo "$msg$out" | grep -qi "positions/foo\|missing\|焦点" \
    && ok "missing focus: warning surfaced somewhere" \
    || fail "missing focus: silent — should warn"
  rm -rf "$vault"
}

test_missing_sentinel_is_learning
test_personal_injects_profile_and_positions
test_invalid_sentinel_warns
test_personal_missing_focus_file

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
