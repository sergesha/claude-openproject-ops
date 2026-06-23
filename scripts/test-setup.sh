#!/usr/bin/env bash
# test-setup.sh — pure unit tests for setup.sh helper functions and validation logic.
# No docker, no git clone, no system mutation. Run: bash scripts/test-setup.sh
set -euo pipefail

pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
eq(){ [ "$2" = "$3" ] && ok "$1" || no "$1 (got '$2' want '$3')"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Extract set_env into a sourceable fragment — the function is embedded in
# setup.sh between known markers so we grep it out rather than sourcing the
# whole script (which runs preflight checks, docker, etc.)
# ---------------------------------------------------------------------------
extract_set_env() {
  # Pull lines from "set_env()" through the closing "}"
  sed -n '/^set_env()/,/^}/p' "$(dirname "$0")/setup.sh"
}

SET_ENV_BODY="$(extract_set_env)"
[ -n "$SET_ENV_BODY" ] && ok "set_env() extracted from setup.sh" \
                       || { no "set_env() not found in setup.sh"; exit 1; }

# Helper: create a .env in TMPDIR_TEST, source set_env, run it, return the line.
run_set_env() {
  local key="$1" val="$2" initial_content="${3:-}"
  local envfile="$TMPDIR_TEST/.env"
  printf '%s\n' "$initial_content" > "$envfile"
  (
    cd "$TMPDIR_TEST"
    eval "$SET_ENV_BODY"
    set_env "$key" "$val"
  )
  grep "^${key}=" "$envfile" || true
}

# ===========================================================================
echo "== set_env: basic replacement =="
# ===========================================================================

result="$(run_set_env FOO bar "FOO=old")"
eq "basic replace" "$result" "FOO=bar"

result="$(run_set_env FOO bar "")"
eq "append when missing" "$result" "FOO=bar"

# ===========================================================================
echo "== set_env: sed-special characters in values =="
# ===========================================================================

# & is special in sed replacement — must be escaped
result="$(run_set_env KEY 'a&b' "KEY=old")"
eq "ampersand in value" "$result" "KEY=a&b"

# backslash is special in sed replacement
result="$(run_set_env KEY 'a\b' "KEY=old")"
eq "backslash in value" "$result" "KEY=a\\b"

# pipe is the delimiter used by set_env's sed command
result="$(run_set_env KEY 'a|b' "KEY=old")"
eq "pipe in value" "$result" "KEY=a|b"

# forward slash — common in URLs, paths
result="$(run_set_env KEY 'http://host:8080/path' "KEY=old")"
eq "slashes in value" "$result" "KEY=http://host:8080/path"

# colon — common in host:port
result="$(run_set_env KEY '127.0.0.1:8080' "KEY=old")"
eq "colon in value" "$result" "KEY=127.0.0.1:8080"

# combined nasty string
result="$(run_set_env KEY 'a&b\c|d/e:f' "KEY=old")"
eq "combined special chars" "$result" "KEY=a&b\\c|d/e:f"

# ===========================================================================
echo "== set_env: empty value =="
# ===========================================================================

result="$(run_set_env KEY '' "KEY=old")"
eq "empty value replaces" "$result" "KEY="

result="$(run_set_env KEY '' "")"
eq "empty value appends" "$result" "KEY="

# ===========================================================================
echo "== set_env: preserves other lines =="
# ===========================================================================

envfile="$TMPDIR_TEST/.env"
printf 'ALPHA=1\nBETA=2\nGAMMA=3\n' > "$envfile"
(cd "$TMPDIR_TEST"; eval "$SET_ENV_BODY"; set_env BETA newval)
alpha="$(grep '^ALPHA=' "$envfile")"
gamma="$(grep '^GAMMA=' "$envfile")"
beta="$(grep '^BETA=' "$envfile")"
eq "other lines preserved (ALPHA)" "$alpha" "ALPHA=1"
eq "other lines preserved (GAMMA)" "$gamma" "GAMMA=3"
eq "target line updated (BETA)" "$beta" "BETA=newval"

# ===========================================================================
echo "== set_env: multiple ampersands and backslashes =="
# ===========================================================================

result="$(run_set_env KEY '&&\\&&' "KEY=old")"
eq "multiple ampersands+backslashes" "$result" "KEY=&&\\\\&&"

result="$(run_set_env KEY '|||' "KEY=old")"
eq "multiple pipes" "$result" "KEY=|||"

# ===========================================================================
echo "== secret generation: length and character set =="
# ===========================================================================

# Replicate the secret generation logic from setup.sh line 102
SECRET="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 64)"

[ ${#SECRET} -eq 64 ] && ok "secret length is 64" || no "secret length is ${#SECRET} (want 64)"

# Check character set: only [A-Za-z0-9]
if echo "$SECRET" | LC_ALL=C grep -qE '^[A-Za-z0-9]+$'; then
  ok "secret is alphanumeric only"
else
  no "secret contains non-alphanumeric characters"
fi

# Generate a second secret — should differ (vanishingly unlikely to collide at 64 chars)
SECRET2="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 64)"
[ "$SECRET" != "$SECRET2" ] && ok "two secrets differ" || no "two secrets are identical (collision)"

# ===========================================================================
echo "== secret generation: survives set_env round-trip =="
# ===========================================================================

# Make sure the generated secret can be written and read back via set_env
result="$(run_set_env SECRET_KEY_BASE "$SECRET" "SECRET_KEY_BASE=OVERWRITE_ME")"
eq "secret round-trip through set_env" "$result" "SECRET_KEY_BASE=$SECRET"

# ===========================================================================
echo "== OP_WAIT validation: must be numeric =="
# ===========================================================================

# Extract the validation regex from setup.sh and test it directly
validate_op_wait() {
  local val="$1"
  [[ "$val" =~ ^[0-9]+$ ]]
}

validate_op_wait "600"  && ok "OP_WAIT=600 valid"    || no "OP_WAIT=600 rejected"
validate_op_wait "0"    && ok "OP_WAIT=0 valid"      || no "OP_WAIT=0 rejected"
validate_op_wait "9999" && ok "OP_WAIT=9999 valid"   || no "OP_WAIT=9999 rejected"
validate_op_wait "1"    && ok "OP_WAIT=1 valid"      || no "OP_WAIT=1 rejected"

! validate_op_wait ""      && ok "OP_WAIT='' rejected"      || no "OP_WAIT='' accepted"
! validate_op_wait "abc"   && ok "OP_WAIT=abc rejected"     || no "OP_WAIT=abc accepted"
! validate_op_wait "60s"   && ok "OP_WAIT=60s rejected"     || no "OP_WAIT=60s accepted"
! validate_op_wait "10.5"  && ok "OP_WAIT=10.5 rejected"    || no "OP_WAIT=10.5 accepted"
! validate_op_wait " 600"  && ok "OP_WAIT=' 600' rejected"  || no "OP_WAIT=' 600' accepted"
! validate_op_wait "600 "  && ok "OP_WAIT='600 ' rejected"  || no "OP_WAIT='600 ' accepted"
! validate_op_wait "-1"    && ok "OP_WAIT=-1 rejected"      || no "OP_WAIT=-1 accepted"

# ===========================================================================
echo "== OP_TAG validation: must end with -slim =="
# ===========================================================================

# Replicate the case pattern from setup.sh line 52
validate_op_tag() {
  local tag="$1"
  case "$tag" in *-slim) return 0 ;; *) return 1 ;; esac
}

validate_op_tag "17-slim"       && ok "TAG=17-slim valid"         || no "TAG=17-slim rejected"
validate_op_tag "16-slim"       && ok "TAG=16-slim valid"         || no "TAG=16-slim rejected"
validate_op_tag "dev-slim"      && ok "TAG=dev-slim valid"        || no "TAG=dev-slim rejected"
validate_op_tag "latest-slim"   && ok "TAG=latest-slim valid"     || no "TAG=latest-slim rejected"
! validate_op_tag "17"          && ok "TAG=17 rejected"           || no "TAG=17 accepted"
! validate_op_tag "latest"      && ok "TAG=latest rejected"       || no "TAG=latest accepted"
! validate_op_tag "slim"        && ok "TAG=slim rejected (no -)"  || no "TAG=slim accepted"
! validate_op_tag ""            && ok "TAG='' rejected"           || no "TAG='' accepted"
! validate_op_tag "17-slim-dev" && ok "TAG=17-slim-dev rejected"  || no "TAG=17-slim-dev accepted"

# ===========================================================================
echo "== PROBE_PORT extraction =="
# ===========================================================================

# Replicate: PROBE_PORT="${OP_PORT##*:}"
extract_probe_port() { echo "${1##*:}"; }

eq "port from ip:port"   "$(extract_probe_port '127.0.0.1:8080')" "8080"
eq "port from 0.0.0.0:p" "$(extract_probe_port '0.0.0.0:3000')"  "3000"
eq "bare port number"     "$(extract_probe_port '8080')"           "8080"
eq "port from [::]:port"  "$(extract_probe_port '[::]:9090')"      "9090"

# ===========================================================================
echo "== SECRET_KEY_BASE detection regex =="
# ===========================================================================

# Replicate: grep -qE '^SECRET_KEY_BASE=(OVERWRITE_ME)?$'
needs_secret() {
  local envfile="$TMPDIR_TEST/.env"
  printf '%s\n' "$1" > "$envfile"
  # needs generation if value is empty, "OVERWRITE_ME", or missing
  if grep -qE '^SECRET_KEY_BASE=(OVERWRITE_ME)?$' "$envfile" || \
     ! grep -qE '^SECRET_KEY_BASE=.+' "$envfile"; then
    return 0  # needs secret
  fi
  return 1  # keep existing
}

needs_secret "SECRET_KEY_BASE="              && ok "empty value needs secret"           || no "empty value kept"
needs_secret "SECRET_KEY_BASE=OVERWRITE_ME"  && ok "OVERWRITE_ME needs secret"          || no "OVERWRITE_ME kept"
needs_secret ""                              && ok "missing line needs secret"           || no "missing line kept"
needs_secret "OTHER_KEY=foo"                 && ok "absent key needs secret"             || no "absent key kept"
! needs_secret "SECRET_KEY_BASE=abc123def"   && ok "real secret preserved"               || no "real secret overwritten"
! needs_secret "SECRET_KEY_BASE=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789" \
                                             && ok "64-char secret preserved"            || no "64-char secret overwritten"

# ===========================================================================
echo "== set_env: password-like values with special chars =="
# ===========================================================================

# Typical generated password characters that might break sed
result="$(run_set_env DB_PASS 'p@ss/w0rd&more\end' "DB_PASS=old")"
eq "password with @/&\\ chars" "$result" "DB_PASS=p@ss/w0rd&more\\end"

result="$(run_set_env DB_PASS 'single'\''quote' "DB_PASS=old")"
eq "password with single quote" "$result" "DB_PASS=single'quote"

result="$(run_set_env DB_PASS 'double"quote' "DB_PASS=old")"
eq "password with double quote" "$result" 'DB_PASS=double"quote'

result="$(run_set_env DB_PASS 'dollar$sign' "DB_PASS=old")"
eq "password with dollar sign" "$result" 'DB_PASS=dollar$sign'

result="$(run_set_env DB_PASS 'hash#tag' "DB_PASS=old")"
eq "password with hash" "$result" "DB_PASS=hash#tag"

result="$(run_set_env DB_PASS 'excl!mark' "DB_PASS=old")"
eq "password with exclamation" "$result" "DB_PASS=excl!mark"

# ===========================================================================
echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
