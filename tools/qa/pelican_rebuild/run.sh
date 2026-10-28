#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/pelican-independent-final.XXXXXX)"
for test in independent storage lifecycle wm_close; do
 mkdir -p "$QA/$test"/{data,config,cache}
 XDG_DATA_HOME="$QA/$test/data" XDG_CONFIG_HOME="$QA/$test/config" XDG_CACHE_HOME="$QA/$test/cache" "$GODOT" --headless --path "$ROOT/godot" --script "$ROOT/tools/qa/pelican_rebuild/$test.gd" 2>&1 | tee "$QA/$test.log"
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$test.log"; then
  echo "FAIL engine error: $QA/$test.log" >&2; exit 1
 fi
done
printf 'PELICAN INDEPENDENT PASS %s\n' "$QA"
