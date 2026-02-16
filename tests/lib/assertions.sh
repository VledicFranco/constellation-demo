#!/usr/bin/env bash
# Shared assertion functions for test scripts

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS_COUNT=$((PASS_COUNT+1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo -e "  ${GREEN}PASS${NC}: $desc"
    PASS_COUNT=$((PASS_COUNT+1))
  else
    echo -e "  ${RED}FAIL${NC}: $desc"
    echo "    Expected to contain: $needle"
    echo "    Got: $haystack"
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi
}

assert_http_status() {
  local desc="$1" url="$2" expected="$3"
  local actual
  actual=$(curl -s -o /dev/null -w '%{http_code}' "$url")
  assert_eq "$desc" "$expected" "$actual"
}

assert_json_field() {
  local desc="$1" json="$2" field="$3" expected="$4"
  local actual
  actual=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null)
  assert_eq "$desc" "$expected" "$actual"
}

skip_test() {
  local desc="$1" reason="$2"
  echo -e "  ${YELLOW}SKIP${NC}: $desc ($reason)"
  SKIP_COUNT=$((SKIP_COUNT+1))
}

print_summary() {
  echo ""
  echo "================================"
  echo -e "Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}, ${YELLOW}$SKIP_COUNT skipped${NC}"
  echo "================================"
  [ $FAIL_COUNT -eq 0 ] || return 1
}
