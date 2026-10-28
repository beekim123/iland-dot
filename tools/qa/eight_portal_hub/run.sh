#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BIN="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/eight-independent.XXXXXX)"
mkdir -p "$QA"/{data,config,cache}
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
echo "Eight-module INCREMENTAL evidence: $QA"
"$BIN" --version | tee "$QA/version.log"
timeout 180 "$BIN" --headless --path "$ROOT/godot" --script "$ROOT/tools/qa/eight_portal_hub/incremental.gd" 2>&1 | tee "$QA/incremental.log"
if grep -E 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL' "$QA/incremental.log"; then exit 1; fi
