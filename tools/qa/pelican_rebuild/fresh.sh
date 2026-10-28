#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA=$(mktemp -d /tmp/pelican-independent-fresh.XXXXXX)
mkdir -p "$QA/project/modules" "$QA/project/qa"
cp -a "$ROOT/godot/modules/pelican_pedal" "$QA/project/modules/"
find "$QA/project" -name '*.import' -delete
cp "$ROOT/tools/qa/pelican_rebuild/"*.gd "$QA/project/qa/"
cat > "$QA/project/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Pelican Independent QA"
run/main_scene="res://modules/pelican_pedal/main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
(cd "$QA/project" && find modules -type f ! -name '*.import' -print0 | sort -z | xargs -0 sha256sum) > "$QA/source.sha256"
for step in import independent storage lifecycle wm_close; do
 export XDG_DATA_HOME="$QA/$step/data" XDG_CONFIG_HOME="$QA/$step/config" XDG_CACHE_HOME="$QA/$step/cache"
 mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
 if [[ $step == import ]]; then
  "$GODOT" --headless --path "$QA/project" --editor --import --quit > "$QA/$step.log" 2>&1
 else
  "$GODOT" --headless --path "$QA/project" --script "res://qa/$step.gd" > "$QA/$step.log" 2>&1
 fi
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$step.log"; then
  cat "$QA/$step.log"; echo "FAIL engine error: $QA/$step.log" >&2; exit 1
 fi
 tail -n 2 "$QA/$step.log"
done
echo "PELICAN INDEPENDENT FRESH PASS $QA"
