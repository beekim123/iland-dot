# Current eight-game integration/extraction smoke

Run `tools/test_all.sh --list` for the declared matrix, then `tools/test_all.sh`.
Set `GODOT_BIN` if the exact `4.7.2.stable.official.ed1daf0bf` executable is not in
the default sibling tools directory. Every subprocess uses separate XDG data,
config and cache directories; Godot imports operate on temporary copies.

Coverage:
- Registry and production extractor IDs match all eight declared modules.
- Host lifecycle (48 actual exits, eight games, both entry routes), portal
  rotation/picking/layout and catalogue tests.
- Production extraction of every module, no sibling/host files, byte comparison,
  resource import, explicit `start(context)` and exactly one public exit signal.
- Original `godot/` and `tools/` source hashes unchanged across the run.

This is **not** full rules regression, process-level standalone autostart/quit,
long-run stability, graphical/native-input, subjective audio, Web or device
performance acceptance. The extracted interface probe intentionally behaves as a
minimal host with no island; standalone process shutdown needs its separate QA.

The runner prints its temporary evidence directory and writes `RESULT.json`,
per-step logs, and before/after hashes there. Missing markers, engine errors,
nonzero exits, timeouts or source changes fail the run. It does not reuse old
passing logs, baseline hashes or acceptance claims. Do not edit source during a
run; a concurrent edit deliberately invalidates the frozen-source result.

Historical `six_games`, `seven_games`, `eight_games` and portal admission runners
remain unchanged. In particular the six-game runner removes the snake while the
current host requires eight games: run it only with its historical source
baseline, never as current acceptance. Historical acceptance documents retain
their original scope rather than being rewritten as eight-game results.
