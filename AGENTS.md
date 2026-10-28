# Repository rules

These rules apply to the entire repository and every commit.

## Before every commit: review unnecessary files

1. Inspect the **actual staged index**, including added and modified files, not only the working tree. Run `python3 tools/check_commit_assets.py --staged` after staging and again if staging changes.
2. Keep game code, runtime assets/configuration, necessary build/validation tools, test fixtures, short usage instructions and required licenses. Do not commit preview videos/GIFs, `.godot`/cache/build outputs, Blender authoring files, original art batches or production intermediates. Keep any needed backup outside this repository.
3. Review large files, identical binary payloads and resource references before committing. Explain necessary duplication (for example independently extractable modules). Consider dynamic loaders, manifests, fallback assets, tests and licenses. **A missing grep match is not proof that a file is unused. Never delete automatically.**
4. The script hard-fails clear forbidden artifacts; it reports size/duplicate risks but cannot prove every file useful. All reported risks require manual review. For a justified risk, pass `--reviewed PATH` for each exact reported path; this acknowledges only that risk, never overrides a hard prohibition. Record a short reason in the commit/PR. Any changed staged set must be rechecked.
5. Do not commit while the gate fails or reference/necessity review remains unresolved. Run relevant tests after cleanup. Do not rewrite old acceptance evidence or Git history to conceal changed content.

Without Git metadata, validate a prepared source tree with `python3 tools/check_commit_assets.py --tree /path/to/tree`. `tools/test_all.sh` invokes the read-only gate before its existing tests. No hook is automatically installed.

Current layout intentionally keeps per-module font copies for standalone extraction and immutable QA fixtures. Prior runtime-only cleanup manually reviewed manifest/dynamic references; it does not exempt future files from this rule.

The only large-file exception is the exact SHA256-pinned `godot/modules/apprentice_yokai_king/art/arena_large.png`: it is the dynamically loaded camera-follow runtime map, reviewed during the runtime-only cleanup. Different bytes require fresh review. The script records when this exception is used.
