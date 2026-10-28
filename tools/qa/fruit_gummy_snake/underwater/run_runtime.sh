#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
BIN="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/xyz-runtime-independent.XXXXXX)"
mkdir -p "$QA/project/modules" "$QA/import"/{data,config,cache}
cp -a "$ROOT/godot/modules/fruit_gummy_snake" "$QA/project/modules/"
find "$QA/project" -type f -name '*.import' -delete
find "$QA/project" -type d -name '__pycache__' -prune -exec rm -rf {} +
cat > "$QA/project/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="FruitIndependentAudit"
run/main_scene="res://modules/fruit_gummy_snake/main.tscn"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
PROJECT
manifest(){ (cd "$1" && find . -type f ! -name '*.import' ! -name '*.pyc' | sort | xargs sha256sum); }
manifest "$QA/project/modules/fruit_gummy_snake" > "$QA/source_before.sha256"
XDG_DATA_HOME="$QA/import/data" XDG_CONFIG_HOME="$QA/import/config" XDG_CACHE_HOME="$QA/import/cache" "$BIN" --headless --path "$QA/project" --editor --import 2>&1 | tee "$QA/import/log"
for TEST in input_lifecycle standalone_exit preview intro_target long_camera; do
 mkdir -p "$QA/$TEST"/{data,config,cache}
 ARGS=(); if [ "$TEST" = preview ]; then ARGS=(-- --snake-preview); fi
 XDG_DATA_HOME="$QA/$TEST/data" XDG_CONFIG_HOME="$QA/$TEST/config" XDG_CACHE_HOME="$QA/$TEST/cache" "$BIN" --headless --audio-driver Dummy --path "$QA/project" --script "$ROOT/tools/qa/fruit_gummy_snake/underwater/$TEST.gd" "${ARGS[@]}" 2>&1 | tee "$QA/$TEST/log"
done
if grep -E 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL' "$QA"/*/log; then exit 1; fi
manifest "$ROOT/godot/modules/fruit_gummy_snake" > "$QA/source_after.sha256"
diff -u "$QA/source_before.sha256" "$QA/source_after.sha256"
printf 'FRESH XYZ RUNTIME PASS %s\n' "$QA"
