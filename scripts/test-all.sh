#!/usr/bin/env bash
# test-all.sh — unified test runner for the claude-openproject-ops plugin.
#
# Usage:
#   bash scripts/test-all.sh              # run all tests (live tests if API available)
#   bash scripts/test-all.sh --offline    # skip live OpenProject smoke tests
#   bash scripts/test-all.sh --verbose    # show full test output (not just pass/fail)
#   bash scripts/test-all.sh --help       # print this help
#
# Phases (in order):
#   1. Offline unit/structural tests (no env needed)
#   2. JSON manifest validation
#   3. Shell syntax check (bash -n) on all .sh files
#   4. Ruby syntax check on provision.rb
#   5. SKILL.md frontmatter validation
#   6. Command .md frontmatter validation
#   7. Cross-reference checks (CLAUDE.md layout vs actual skills, commands vs skills)
#   8. .gitignore coverage for sensitive patterns
#   9. Live smoke tests (if OpenProject API reachable and not --offline)
#
# Exit 0 only if every test passes. Color output auto-detected (disable with NO_COLOR=1).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# ── flags ────────────────────────────────────────────────────────────────────
OFFLINE=0
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=1 ;;
    --verbose) VERBOSE=1 ;;
    --help|-h)
      sed -n '2,/^set -/{ /^#/s/^# \?//p }' "$0"
      exit 0 ;;
    *) echo "Unknown flag: $arg"; exit 2 ;;
  esac
done

# ── color ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
  BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BOLD=''; RESET=''
fi

# ── counters ─────────────────────────────────────────────────────────────────
TOTAL=0; PASSED=0; FAILED=0; SKIPPED=0
FAILURES=()
PASSES=()
SKIPS=()

pass() {
  TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1))
  PASSES+=("$1")
  printf "  ${GREEN}PASS${RESET}  %s" "$1"
  [[ -n "${2:-}" ]] && printf "  (%.2fs)" "$2"
  printf '\n'
}

fail() {
  TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1))
  FAILURES+=("$1")
  printf "  ${RED}FAIL${RESET}  %s" "$1"
  [[ -n "${2:-}" ]] && printf "  (%.2fs)" "$2"
  printf '\n'
}

skip() {
  TOTAL=$((TOTAL+1)); SKIPPED=$((SKIPPED+1))
  SKIPS+=("$1")
  printf "  ${YELLOW}SKIP${RESET}  %s" "$1"
  [[ -n "${2:-}" ]] && printf "  — %s" "$2"
  printf '\n'
}

# Run a test command, capture output, time it, report pass/fail.
# Usage: run_test "label" command [args...]
run_test() {
  local label="$1"; shift
  local start end elapsed output rc
  start=$(date +%s%N 2>/dev/null || date +%s)
  output=$("$@" 2>&1) && rc=0 || rc=$?
  end=$(date +%s%N 2>/dev/null || date +%s)
  # Compute elapsed in seconds (nanosecond precision if available)
  if [[ ${#start} -gt 10 ]]; then
    elapsed=$(awk "BEGIN{printf \"%.2f\", ($end - $start)/1000000000}")
  else
    elapsed=$(( end - start ))
  fi
  if [[ $rc -eq 0 ]]; then
    pass "$label" "$elapsed"
  else
    fail "$label" "$elapsed"
  fi
  if [[ $VERBOSE -eq 1 ]] && [[ -n "$output" ]]; then
    printf '%s\n' "$output" | sed 's/^/    | /'
  elif [[ $rc -ne 0 ]] && [[ -n "$output" ]]; then
    # Always show output on failure (first 20 lines)
    printf '%s\n' "$output" | head -20 | sed 's/^/    | /'
    local lines
    lines=$(printf '%s\n' "$output" | wc -l)
    [[ $lines -gt 20 ]] && printf '    | ... (%d more lines, use --verbose)\n' $((lines - 20))
  fi
}

section() {
  printf '\n%b== %s ==%b\n' "$BOLD" "$1" "$RESET"
}

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 1: Offline unit/structural tests
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 1: Offline unit & structural tests"

run_test "check-cookbook.sh" bash "$ROOT/scripts/check-cookbook.sh"
run_test "check-session-context.sh" bash "$ROOT/scripts/check-session-context.sh"
run_test "dedup-unit.sh" bash "$ROOT/skills/semantic-search/test/dedup-unit.sh"

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 2: JSON manifest validation
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 2: JSON manifest validation"

validate_json() {
  local file="$1" label="$2"
  if [[ ! -f "$file" ]]; then
    fail "$label — file missing"
    return
  fi
  # Try python3 first, fall back to jq, fall back to node
  local output rc
  if command -v python3 &>/dev/null; then
    output=$(python3 -m json.tool "$file" >/dev/null 2>&1) && rc=0 || rc=$?
  elif command -v jq &>/dev/null; then
    output=$(jq empty "$file" 2>&1) && rc=0 || rc=$?
  elif command -v node &>/dev/null; then
    output=$(node -e "JSON.parse(require('fs').readFileSync('$file','utf8'))" 2>&1) && rc=0 || rc=$?
  else
    skip "$label" "no JSON validator (python3/jq/node)"
    return
  fi
  if [[ $rc -eq 0 ]]; then
    pass "$label"
  else
    fail "$label"
    [[ -n "${output:-}" ]] && printf '    | %s\n' "$output"
  fi
}

validate_json "$ROOT/.claude-plugin/plugin.json"      "plugin.json valid JSON"
validate_json "$ROOT/.claude-plugin/marketplace.json"  "marketplace.json valid JSON"
validate_json "$ROOT/hooks/hooks.json"                 "hooks.json valid JSON"

# Also validate release-please-config.json if it exists
[[ -f "$ROOT/release-please-config.json" ]] && \
  validate_json "$ROOT/release-please-config.json" "release-please-config.json valid JSON"

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 3: Shell syntax check (bash -n) on all .sh files
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 3: Shell syntax check (bash -n)"

sh_syntax_fail=0
sh_syntax_total=0
sh_syntax_errors=""
while IFS= read -r -d '' sh_file; do
  sh_syntax_total=$((sh_syntax_total + 1))
  rel="${sh_file#"$ROOT"/}"
  if ! err=$(bash -n "$sh_file" 2>&1); then
    sh_syntax_fail=$((sh_syntax_fail + 1))
    sh_syntax_errors+="    | $rel: $err"$'\n'
  fi
done < <(find "$ROOT" -name '*.sh' -not -path '*/openproject/*' -not -path '*/.superpowers/*' -print0)

if [[ $sh_syntax_fail -eq 0 ]]; then
  pass "bash -n on $sh_syntax_total .sh files"
else
  fail "bash -n: $sh_syntax_fail/$sh_syntax_total files have syntax errors"
  [[ -n "$sh_syntax_errors" ]] && printf '%s' "$sh_syntax_errors"
fi

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 4: Ruby syntax check on provision.rb
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 4: Ruby syntax check"

PROVISION_RB="$ROOT/skills/openproject-intake/provision.rb"
if [[ ! -f "$PROVISION_RB" ]]; then
  skip "provision.rb syntax" "file not found"
elif command -v ruby &>/dev/null; then
  run_test "provision.rb syntax (ruby -c)" ruby -c "$PROVISION_RB"
elif command -v docker &>/dev/null; then
  run_test "provision.rb syntax (docker ruby)" \
    docker run --rm -v "$PROVISION_RB:/tmp/provision.rb:ro" ruby:3-alpine ruby -c /tmp/provision.rb
else
  skip "provision.rb syntax" "no ruby or docker available"
fi

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 5: SKILL.md frontmatter validation
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 5: SKILL.md frontmatter validation"

skill_fm_fail=0
skill_fm_total=0
skill_fm_errors=""
for skill_dir in "$ROOT"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"
  skill_fm_total=$((skill_fm_total + 1))

  if [[ ! -f "$skill_md" ]]; then
    skill_fm_fail=$((skill_fm_fail + 1))
    skill_fm_errors+="    | $skill_name: SKILL.md missing"$'\n'
    continue
  fi

  # Check frontmatter: must start with --- and have name + description
  first_line=$(head -1 "$skill_md")
  if [[ "$first_line" != "---" ]]; then
    skill_fm_fail=$((skill_fm_fail + 1))
    skill_fm_errors+="    | $skill_name: SKILL.md does not start with --- frontmatter"$'\n'
    continue
  fi

  # Extract frontmatter block (between first and second ---)
  frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')
  if [[ -z "$frontmatter" ]]; then
    skill_fm_fail=$((skill_fm_fail + 1))
    skill_fm_errors+="    | $skill_name: empty or unclosed frontmatter"$'\n'
    continue
  fi

  has_name=0; has_desc=0
  echo "$frontmatter" | grep -qE '^name:' && has_name=1
  echo "$frontmatter" | grep -qE '^description:' && has_desc=1

  if [[ $has_name -eq 0 ]] || [[ $has_desc -eq 0 ]]; then
    skill_fm_fail=$((skill_fm_fail + 1))
    missing=""
    [[ $has_name  -eq 0 ]] && missing+="name "
    [[ $has_desc  -eq 0 ]] && missing+="description"
    skill_fm_errors+="    | $skill_name: frontmatter missing: $missing"$'\n'
  fi
done

if [[ $skill_fm_fail -eq 0 ]]; then
  pass "SKILL.md frontmatter ($skill_fm_total skills)"
else
  fail "SKILL.md frontmatter: $skill_fm_fail/$skill_fm_total skills have issues"
  [[ -n "$skill_fm_errors" ]] && printf '%s' "$skill_fm_errors"
fi

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 6: Command .md frontmatter validation
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 6: Command .md frontmatter validation"

cmd_fm_fail=0
cmd_fm_total=0
cmd_fm_errors=""
for cmd_file in "$ROOT"/commands/*.md; do
  [[ -f "$cmd_file" ]] || continue
  cmd_name="$(basename "$cmd_file")"
  cmd_fm_total=$((cmd_fm_total + 1))

  first_line=$(head -1 "$cmd_file")
  if [[ "$first_line" != "---" ]]; then
    cmd_fm_fail=$((cmd_fm_fail + 1))
    cmd_fm_errors+="    | $cmd_name: does not start with --- frontmatter"$'\n'
    continue
  fi

  frontmatter=$(sed -n '2,/^---$/p' "$cmd_file" | sed '$d')
  if [[ -z "$frontmatter" ]]; then
    cmd_fm_fail=$((cmd_fm_fail + 1))
    cmd_fm_errors+="    | $cmd_name: empty or unclosed frontmatter"$'\n'
    continue
  fi

  has_desc=0
  echo "$frontmatter" | grep -qE '^description:' && has_desc=1
  if [[ $has_desc -eq 0 ]]; then
    cmd_fm_fail=$((cmd_fm_fail + 1))
    cmd_fm_errors+="    | $cmd_name: frontmatter missing description"$'\n'
  fi
done

if [[ $cmd_fm_fail -eq 0 ]]; then
  pass "Command frontmatter ($cmd_fm_total commands)"
else
  fail "Command frontmatter: $cmd_fm_fail/$cmd_fm_total commands have issues"
  [[ -n "$cmd_fm_errors" ]] && printf '%s' "$cmd_fm_errors"
fi

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 7: Cross-reference checks
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 7: Cross-reference checks"

# 7a. Every skill listed in CLAUDE.md layout actually exists as a directory
xref_fail=0
xref_errors=""

# Extract skill names from the CLAUDE.md layout line(s)
# The layout lists them as: pm-craft · openproject-pm · openproject-devops · ...
# The skills/ line may span multiple continuation lines (indented) before the next
# top-level entry (commands/, context/, etc.), so we grab generously with -A10
# and stop at the first non-skill line.
layout_skills=$(grep -A10 '^skills/' "$ROOT/CLAUDE.md" | \
  sed -n '/^skills\//,/^[a-z]/{ /^[a-z][a-z]*\//!p; /^skills\//p; }' | \
  tr '·' '\n' | \
  sed 's|skills/||' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | \
  grep -v '^$' | grep -v '^--$' | \
  grep -E '^[a-z][-a-z]*$')

while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  if [[ ! -d "$ROOT/skills/$skill" ]]; then
    xref_fail=$((xref_fail + 1))
    xref_errors+="    | CLAUDE.md references skill '$skill' but skills/$skill/ does not exist"$'\n'
  fi
done <<< "$layout_skills"

if [[ $xref_fail -eq 0 ]]; then
  pass "CLAUDE.md layout skills all exist ($(echo "$layout_skills" | grep -c . ) skills)"
else
  fail "CLAUDE.md layout references $xref_fail missing skills"
  printf '%s' "$xref_errors"
fi

# 7b. Every actual skill directory is listed in CLAUDE.md
xref2_fail=0
xref2_errors=""
for skill_dir in "$ROOT"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  if ! echo "$layout_skills" | grep -qx "$skill_name"; then
    xref2_fail=$((xref2_fail + 1))
    xref2_errors+="    | skills/$skill_name/ exists but not listed in CLAUDE.md layout"$'\n'
  fi
done

if [[ $xref2_fail -eq 0 ]]; then
  pass "All skill directories listed in CLAUDE.md"
else
  fail "$xref2_fail skill directories not listed in CLAUDE.md layout"
  printf '%s' "$xref2_errors"
fi

# 7c. Every command references at least one real skill in its body text
xref3_fail=0
xref3_errors=""
xref3_total=0
# Build list of actual skill names
actual_skills=()
for sd in "$ROOT"/skills/*/; do
  actual_skills+=("$(basename "$sd")")
done

for cmd_file in "$ROOT"/commands/*.md; do
  [[ -f "$cmd_file" ]] || continue
  cmd_name="$(basename "$cmd_file" .md)"
  xref3_total=$((xref3_total + 1))
  # Read command body (after frontmatter)
  body=$(sed '1,/^---$/{ /^---$/!d; d; }' "$cmd_file")
  found_skill=0
  for s in "${actual_skills[@]}"; do
    if echo "$body" | grep -q "$s"; then
      found_skill=1
      break
    fi
  done
  if [[ $found_skill -eq 0 ]]; then
    xref3_fail=$((xref3_fail + 1))
    xref3_errors+="    | $cmd_name: does not reference any known skill"$'\n'
  fi
done

if [[ $xref3_fail -eq 0 ]]; then
  pass "All $xref3_total commands reference a real skill"
else
  fail "$xref3_fail/$xref3_total commands do not reference any known skill"
  printf '%s' "$xref3_errors"
fi

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 8: .gitignore sensitive-pattern coverage
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 8: .gitignore sensitive-pattern coverage"

gitignore="$ROOT/.gitignore"
gi_fail=0
gi_errors=""

# Patterns that MUST be covered (exact lines or effective equivalents)
required_patterns=(
  '.env'           # secrets env files
  '*.secret'       # secret files
  '*.token'        # token files
  '*.pem'          # private keys
  '*.key'          # key files
  'openproject/'   # deployment workspace
  '.admin-password' # admin password
  'CLAUDE.local.md' # local instructions
)

if [[ ! -f "$gitignore" ]]; then
  fail ".gitignore missing entirely"
else
  for pat in "${required_patterns[@]}"; do
    # Check if the pattern (or a glob covering it) exists in .gitignore
    # Handle both exact and wildcard forms (e.g. **/.env covers .env)
    if grep -qF "$pat" "$gitignore" 2>/dev/null; then
      : # found
    else
      gi_fail=$((gi_fail + 1))
      gi_errors+="    | pattern not covered: $pat"$'\n'
    fi
  done

  if [[ $gi_fail -eq 0 ]]; then
    pass ".gitignore covers all ${#required_patterns[@]} sensitive patterns"
  else
    fail ".gitignore missing $gi_fail sensitive patterns"
    printf '%s' "$gi_errors"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# PHASE 9: Live smoke tests (require OpenProject API)
# ═════════════════════════════════════════════════════════════════════════════
section "Phase 9: Live smoke tests (OpenProject API)"

API_ENV="$HOME/openproject/.op-api.env"
LIVE_TESTS=(
  "backlog-refinement/test/smoke.sh"
  "delivery-metrics/test/smoke.sh"
  "delivery-reporting/test/smoke.sh"
  "openproject-intake/test/smoke.sh"
  "openproject-pm/test/smoke.sh"
  "openproject-pm/test/release-smoke.sh"
  "sprint-operations/test/smoke.sh"
  "semantic-search/test/dedup-smoke.sh"
)

if [[ $OFFLINE -eq 1 ]]; then
  for t in "${LIVE_TESTS[@]}"; do
    skip "skills/$t" "--offline flag"
  done
elif [[ ! -f "$API_ENV" ]]; then
  for t in "${LIVE_TESTS[@]}"; do
    skip "skills/$t" "~/openproject/.op-api.env not found"
  done
else
  # Source API env and probe the endpoint
  set -a; . "$API_ENV"; set +a
  api_ok=0
  if [[ -n "${OPENPROJECT_URL:-}" ]] && [[ -n "${OPENPROJECT_API_KEY:-}" ]]; then
    probe=$(curl -sf -o /dev/null -w '%{http_code}' \
      -u "apikey:$OPENPROJECT_API_KEY" \
      "$OPENPROJECT_URL/api/v3" 2>/dev/null) || probe="000"
    [[ "$probe" =~ ^2 ]] && api_ok=1
  fi

  if [[ $api_ok -eq 0 ]]; then
    for t in "${LIVE_TESTS[@]}"; do
      skip "skills/$t" "API not reachable (HTTP $probe)"
    done
  else
    # API is live — run each smoke test sequentially
    for t in "${LIVE_TESTS[@]}"; do
      test_path="$ROOT/skills/$t"
      if [[ ! -f "$test_path" ]]; then
        skip "skills/$t" "test file missing"
        continue
      fi
      run_test "skills/$t" bash "$test_path"
    done
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════════════════════
printf '\n%b══════════════════════════════════════════════════════════%b\n' "$BOLD" "$RESET"
printf '%b  TEST SUMMARY%b\n' "$BOLD" "$RESET"
printf '%b══════════════════════════════════════════════════════════%b\n' "$BOLD" "$RESET"
printf '  Total:   %d\n' "$TOTAL"
printf "  ${GREEN}Passed:  %d${RESET}\n" "$PASSED"
if [[ $FAILED -gt 0 ]]; then
  printf "  ${RED}Failed:  %d${RESET}\n" "$FAILED"
else
  printf '  Failed:  0\n'
fi
if [[ $SKIPPED -gt 0 ]]; then
  printf "  ${YELLOW}Skipped: %d${RESET}\n" "$SKIPPED"
else
  printf '  Skipped: 0\n'
fi

if [[ $FAILED -gt 0 ]]; then
  printf '\n  %bFailed tests:%b\n' "$RED" "$RESET"
  for f in "${FAILURES[@]}"; do
    printf "    ${RED}x${RESET} %s\n" "$f"
  done
fi

if [[ $SKIPPED -gt 0 ]]; then
  printf '\n  %bSkipped tests:%b\n' "$YELLOW" "$RESET"
  for s in "${SKIPS[@]}"; do
    printf "    ${YELLOW}-${RESET} %s\n" "$s"
  done
fi

printf '\n'
if [[ $FAILED -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}ALL TESTS PASSED${RESET}\n\n"
  exit 0
else
  printf "  ${RED}${BOLD}SOME TESTS FAILED${RESET}\n\n"
  exit 1
fi
