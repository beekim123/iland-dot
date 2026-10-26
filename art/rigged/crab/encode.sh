#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ffmpeg -y -v warning -framerate 24 -start_number 1 -i "$ROOT/frames/frame_%04d.png" -frames:v 96 -c:v libx264 -preset fast -crf 19 -pix_fmt yuv420p -movflags +faststart "$ROOT/crab_scuttle.mp4"
ffmpeg -y -v warning -framerate 24 -start_number 1 -i "$ROOT/frames/frame_%04d.png" -filter_complex "fps=12,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" -loop 0 "$ROOT/crab_scuttle.gif"
