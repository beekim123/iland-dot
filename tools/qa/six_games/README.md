# Six-admitted-game frozen regression

Run `GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/test_all.sh`.
`tools/test_all.sh --list` prints the declared suite coverage without execution.
Requires the exact approved `4.7.2.stable.official.ed1daf0bf` engine.

The runner snapshots all admitted `godot/` source/assets and executable/config
inputs under `tools/`, before and after testing. It rejects any changed included
input. Import metadata, caches, generated evidence and non-executable tools
Markdown are excluded. The disabled, independently developed
`godot/modules/fruit_gummy_snake/` and `tools/qa/fruit_gummy_snake/` are explicitly
excluded. The island registry still contains its disabled listing.

The host tests run in a byte-identical isolated project copy without Snake;
each process has separate temporary XDG data/config/cache. All six modules run
their available author tests. Existing Gummy/Bloom/Tide and rebuilt Pelican
independent suites, five four-door/catalog host suites, and Bloom application
window-close modes are also included. Then the **production extractor** makes
six new projects with no sibling modules, byte-checks each before first import,
and repeats autostart/leave, author and available independent tests. Extracted
Bloom also repeats actual close-notification/process-termination coverage.

Beach Cleanup and Volcano Escape have author tests, including fresh extraction,
but their historical independent suites were not recovered. This runner does
not substitute or claim them. A green aggregate is not graphical quality,
native OS input, Web compatibility, or performance acceptance.

Every run retains its `/tmp/sunny-six-frozen.*` path, per-step logs and isolated
user data, source manifests, extraction manifests, `steps.json` and `RESULT.json`.
Do not call an unfinished, interrupted, or source-changing run a frozen pass.
