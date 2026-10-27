#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/bloom-window-close-qa.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
for mode in standalone host_bloom host_hub host_gummy; do
 timeout 12s "$GODOT" --headless --audio-driver Dummy --path "$ROOT/godot" --verbose --script "$ROOT/tools/qa/bloom_skirmish/window_close.gd" -- "--close-mode=$mode" >"$QA/$mode.log" 2>&1
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$mode.log"; then
  cat "$QA/$mode.log"; echo "FAIL ordinary close cleanup: $mode" >&2; exit 1
 fi
 grep "BLOOM WINDOW CLOSE $mode HANDLED" "$QA/$mode.log"
done
printf 'BLOOM WINDOW CLOSE PASS all four modes; logs retained at %s\n' "$QA"
