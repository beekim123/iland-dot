#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
BIN="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/xyz-independent-sim.XXXXXX)"
mkdir -p "$QA/project/modules/fruit_gummy_snake"
cp "$ROOT/godot/modules/fruit_gummy_snake/"{sim,store}.gd "$QA/project/modules/fruit_gummy_snake/"
printf 'config_version=5\n' > "$QA/project/project.godot"
(cd "$QA/project/modules/fruit_gummy_snake" && sha256sum sim.gd store.gd) > "$QA/source_before.sha256"
for TEST in intro kinematics navigation replay_growth collision_fixtures storage; do
 mkdir -p "$QA/$TEST"/{data,config,cache}
 XDG_DATA_HOME="$QA/$TEST/data" XDG_CONFIG_HOME="$QA/$TEST/config" XDG_CACHE_HOME="$QA/$TEST/cache" "$BIN" --headless --path "$QA/project" --script "$ROOT/tools/qa/fruit_gummy_snake/underwater/$TEST.gd" 2>&1 | tee "$QA/$TEST/log"
done
if grep -E 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL' "$QA"/*/log; then exit 1; fi
(cd "$ROOT/godot/modules/fruit_gummy_snake" && sha256sum sim.gd store.gd) > "$QA/source_after.sha256"
diff -u "$QA/source_before.sha256" "$QA/source_after.sha256"
echo "INDEPENDENT XYZ SIM PASS $QA"
