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

# Test E: focus row written as `- positions/<slug>.md` (with .md) — hook strips
#         the suffix and resolves the same file. Documented as accepted form.
test_focus_md_suffix() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  cat > "$topic/_index.md" <<'EOF'
# fixture
## 焦点子主题
- positions/foo.md
## 上次结束时的 handoff
keep going
EOF
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "fixture stance" \
    && ok "focus .md suffix: positions content injected" \
    || fail "focus .md suffix: positions content missing"
  rm -rf "$vault"
}

# Test F: focus row inside an HTML comment block — hook skips position injection
#         AND must not emit a missing-focus warning (the user has explicitly
#         opted out, not pointed at a missing file).
test_focus_commented_out() {
  local vault topic out msg
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  cat > "$topic/_index.md" <<'EOF'
# fixture
## 焦点子主题
<!--
- positions/foo
-->
## 上次结束时的 handoff
keep going
EOF
  out=$(invoke_hook "$topic")
  msg=$(invoke_hook_sysmsg "$topic")
  echo "$out" | grep -q "fixture stance" \
    && fail "commented focus: leaked position content (should NOT)" \
    || ok "commented focus: no position content injected"
  echo "$msg" | grep -q "焦点文件不存在" \
    && fail "commented focus: false missing-focus warning emitted" \
    || ok "commented focus: no false warning"
  echo "$out" | grep -q "key trait A" \
    && ok "commented focus: _profile still injected" \
    || fail "commented focus: _profile missing"
  rm -rf "$vault"
}

# Test G: multiple `- positions/X` lines under focus section — only the first
#         is taken (documented "first line is focus" contract).
test_multiple_focus_entries_takes_first() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  cat > "$topic/positions/bar.md" <<'EOF'
# Bar
## 当前立场
bar stance unique
EOF
  cat > "$topic/_index.md" <<'EOF'
# fixture
## 焦点子主题
- positions/foo
- positions/bar
## 上次结束时的 handoff
keep going
EOF
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "fixture stance" \
    && ok "multi focus: first entry (foo) injected" \
    || fail "multi focus: first entry not injected"
  echo "$out" | grep -q "bar stance unique" \
    && fail "multi focus: second entry (bar) leaked (should NOT)" \
    || ok "multi focus: second entry not injected"
  rm -rf "$vault"
}

# Test H: a `- positions/X` line outside the focus section (e.g., quoted in
#         handoff) must NOT be picked up as focus.
test_stray_positions_line_outside_focus() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  cat > "$topic/positions/leak.md" <<'EOF'
# Leak
should never be injected
EOF
  cat > "$topic/_index.md" <<'EOF'
# fixture
## 焦点子主题
- positions/foo
## 上次结束时的 handoff
- positions/leak
keep going
EOF
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "fixture stance" \
    && ok "stray line: focus (foo) still injected" \
    || fail "stray line: focus not injected"
  echo "$out" | grep -q "should never be injected" \
    && fail "stray line: leak.md content injected (should NOT)" \
    || ok "stray line: out-of-section positions ignored"
  rm -rf "$vault"
}

# Test I: missing _profile.md in personal mode — handoff + focus still work,
#         no crash, no phantom profile content.
test_personal_missing_profile() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  rm "$topic/_profile.md"
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "missing _profile: handoff still present" \
    || fail "missing _profile: handoff absent"
  echo "$out" | grep -q "fixture stance" \
    && ok "missing _profile: focus position still injected" \
    || fail "missing _profile: focus position missing"
  echo "$out" | grep -q "key trait A" \
    && fail "missing _profile: phantom profile content (should NOT)" \
    || ok "missing _profile: no profile content injected"
  rm -rf "$vault"
}

test_missing_sentinel_is_learning
test_personal_injects_profile_and_positions
test_invalid_sentinel_warns
test_personal_missing_focus_file
test_focus_md_suffix
test_focus_commented_out
test_multiple_focus_entries_takes_first
test_stray_positions_line_outside_focus
test_personal_missing_profile

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
