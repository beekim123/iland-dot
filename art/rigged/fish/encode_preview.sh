#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ffmpeg -y -v warning -framerate 12 -pattern_type glob -i 'frames/fish_*.png' -filter_complex '[0:v]split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' -loop 0 fish_swim.gif
ffmpeg -y -v warning -framerate 12 -pattern_type glob -i 'frames/fish_*.png' -c:v libx264 -preset fast -crf 19 -pix_fmt yuv420p -movflags +faststart fish_swim.mp4
