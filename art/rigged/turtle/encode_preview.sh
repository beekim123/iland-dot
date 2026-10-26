#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
test -f "$D/draft_frames/frame_047.png"
ffmpeg -y -v error -framerate 12 -i "$D/draft_frames/frame_%03d.png" -vf 'hqdn3d=2:1.5:3:2.25' -frames:v 48 -c:v libx264 -preset fast -crf 19 -pix_fmt yuv420p -movflags +faststart "$D/turtle_swim_preview.mp4"
ffmpeg -y -v error -framerate 12 -i "$D/draft_frames/frame_%03d.png" -filter_complex '[0:v]hqdn3d=2:1.5:3:2.25,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' -frames:v 48 -loop 0 "$D/turtle_swim_preview.gif"
