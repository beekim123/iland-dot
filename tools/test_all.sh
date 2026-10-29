#!/usr/bin/env bash
# Current eleven-game integration/extraction smoke, not a full rules regression.
# Use --list for exact coverage. Historical admission runners remain under tools/qa/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tools/check_commit_assets.py" --root "$ROOT"
exec python3 "$ROOT/tools/qa/current_games/run.py" "$@"
