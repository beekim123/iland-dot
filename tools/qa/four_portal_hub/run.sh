#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/four-portal-independent.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
printf 'Independent four-portal QA: %s\n' "$QA"
"$GODOT" --version | tee "$QA/version.log"
if [ "$#" -eq 0 ]; then set -- rotation catalog_input pagination host_lifecycle paged_host; fi
for test in "$@"; do
 export XDG_DATA_HOME="$QA/$test/data" XDG_CONFIG_HOME="$QA/$test/config" XDG_CACHE_HOME="$QA/$test/cache"
 mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
 timeout 180 "$GODOT" --headless --path "$ROOT/godot" --script "$ROOT/tools/qa/four_portal_hub/$test.gd" 2>&1 | tee "$QA/$test.log"
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$test.log"; then
  echo "FAIL: engine errors in $test" >&2; exit 1
 fi
done
printf 'Independent requested suites PASS: %s\n' "$*"
printf 'Evidence: %s\n' "$QA"
