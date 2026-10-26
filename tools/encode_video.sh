#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES="$ROOT/art/previews/runtime/gif_frames_v4"
OUT="$ROOT/art/previews/runtime/sunny_shell_island_motion_v4.mp4"
test -f "$FRAMES/capture.json"
ffmpeg -y -v warning -framerate 12 -i "$FRAMES/frame_%03d.png" \
 -i "$ROOT/audio/export/sunny_shell_island_loop.wav" -i "$ROOT/audio/export/ocean_ambience_loop.wav" \
 -filter_complex "[0:v]scale=960:-2:flags=lanczos,format=yuv420p[v];[1:a]volume=0.46016[m];[2:a]volume=0.16327[o];[m][o]amix=inputs=2:normalize=0,afade=t=in:st=0:d=0.25,afade=t=out:st=9.5:d=0.5[a]" \
 -map "[v]" -map "[a]" -t 10 -c:v libx264 -crf 20 -preset fast -c:a aac -b:a 160k -movflags +faststart "$OUT"
ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate -of json "$OUT" > "$ROOT/art/previews/runtime/mp4_v4_qa.json"
cat "$ROOT/art/previews/runtime/mp4_v4_qa.json"
