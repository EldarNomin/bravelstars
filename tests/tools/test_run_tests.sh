#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
temp_dir="$(mktemp -d)"
trap 'rm -f "$temp_dir/godot" "$temp_dir/calls"; rmdir "$temp_dir"' EXIT

cat > "$temp_dir/godot" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALL_LOG"
if [[ "$*" == *--import* ]]; then
  exit "${IMPORT_EXIT:-0}"
fi
exit "${TEST_EXIT:-0}"
EOF
chmod +x "$temp_dir/godot"
export CALL_LOG="$temp_dir/calls"

check_exit() {
  local expected="$1" actual=0
  shift
  "$@" || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected exit %s, got %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

check_exit 37 env IMPORT_EXIT=37 bash tools/run_tests.sh "$temp_dir/godot"
[[ "$(wc -l < "$CALL_LOG")" -eq 1 ]]
check_exit 38 env TEST_EXIT=38 bash tools/run_tests.sh "$temp_dir/godot"
check_exit 0 bash tools/run_tests.sh "$temp_dir/godot"
printf 'Test runner propagates import and test failures.\n'
