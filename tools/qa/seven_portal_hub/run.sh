#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BIN="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/seven-independent.XXXXXX)"
echo "Evidence: $QA"
mkdir -p "$QA/version"/{data,config,cache}
XDG_DATA_HOME="$QA/version/data" XDG_CONFIG_HOME="$QA/version/config" XDG_CACHE_HOME="$QA/version/cache" "$BIN" --version | tee "$QA/version.log"
mkdir -p "$QA/host"/{data,config,cache}
XDG_DATA_HOME="$QA/host/data" XDG_CONFIG_HOME="$QA/host/config" XDG_CACHE_HOME="$QA/host/cache" timeout 180 "$BIN" --headless --path "$ROOT/godot" --script "$ROOT/tools/qa/seven_portal_hub/incremental.gd" 2>&1 | tee "$QA/host.log"
if grep -E 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL' "$QA/host.log"; then exit 1; fi
python3 "$ROOT/tools/extract_game.py" fruit_gummy_snake "$QA/extracted"
mkdir -p "$QA/import"/{data,config,cache}
XDG_DATA_HOME="$QA/import/data" XDG_CONFIG_HOME="$QA/import/config" XDG_CACHE_HOME="$QA/import/cache" timeout 180 "$BIN" --headless --path "$QA/extracted" --editor --import --quit 2>&1 | tee "$QA/import.log"
for test in test_xyz test_camera test_storage test_runtime test_interface test_detach; do
 mkdir -p "$QA/$test"/{data,config,cache}
 XDG_DATA_HOME="$QA/$test/data" XDG_CONFIG_HOME="$QA/$test/config" XDG_CACHE_HOME="$QA/$test/cache" timeout 900 "$BIN" --headless --path "$QA/extracted" --script "res://modules/fruit_gummy_snake/tests/$test.gd" 2>&1 | tee "$QA/$test.log"
done
for test in intro kinematics navigation replay_growth collision_fixtures storage input_lifecycle standalone_exit intro_target long_camera; do
 name="independent_$test"; mkdir -p "$QA/$name"/{data,config,cache}
 XDG_DATA_HOME="$QA/$name/data" XDG_CONFIG_HOME="$QA/$name/config" XDG_CACHE_HOME="$QA/$name/cache" timeout 900 "$BIN" --headless --audio-driver Dummy --path "$QA/extracted" --script "$ROOT/tools/qa/fruit_gummy_snake/underwater/$test.gd" 2>&1 | tee "$QA/$name.log"
done
if grep -E 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL' "$QA"/*.log; then exit 1; fi
printf 'SEVEN MODULE INCREMENTAL + PRODUCTION EXTRACTED XYZ AUTHOR/INDEPENDENT PASS: %s\n' "$QA"
