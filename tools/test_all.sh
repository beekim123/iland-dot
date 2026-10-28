#!/usr/bin/env bash
# Exact-engine, source-frozen regression for the six admitted modules.
# In-progress fruit_gummy_snake is intentionally excluded; see --list coverage.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/tools/qa/six_games/aggregate.py" "$@"
