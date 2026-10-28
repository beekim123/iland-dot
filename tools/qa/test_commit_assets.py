#!/usr/bin/env python3
"""Gate self-tests; no Godot, no repository mutation, temporary Git indexes."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location('gate', Path(__file__).parents[1] / 'check_commit_assets.py')
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)


class AssetGateTests(unittest.TestCase):
    def test_runtime_and_fixture_allowed(self):
        self.assertTrue(gate.inspect({'godot/modules/game/main.gd': b'code', 'source/main.py': b'code', 'tests/fixtures/baseline.json': b'{}', 'fonts/OFL.txt': b'license'})['passed'])

    def test_hard_artifacts_cannot_be_acknowledged(self):
        for name in ['preview.mp4', 'preview.gif', 'art/original.png', 'godot/.godot/imported/a.ctex', 'build/export.zip', 'a.blend', 'godot/modules/x/art/source/raw.png', 'x/__pycache__/a.pyc']:
            self.assertFalse(gate.inspect({name: b'x'}, [name])['passed'], name)

    def test_large_requires_review(self):
        files = {'runtime/large.bin': b'x' * (gate.LARGE_BYTES + 1)}
        self.assertFalse(gate.inspect(files)['passed'])
        self.assertTrue(gate.inspect(files, files)['passed'])

    def test_duplicate_against_unchanged_index(self):
        old = {'old.png': b'x' * 65536}
        new = {'new.png': b'x' * 65536}
        self.assertFalse(gate.inspect(new, comparison_files=old | new)['passed'])
        self.assertTrue(gate.inspect(new, ['new.png'], old | new)['passed'])

    def test_tree_without_git(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'main.gd').write_text('code')
            self.assertTrue(gate.inspect(gate.tree_files(root))['passed'])
            (root / 'preview.webm').write_bytes(b'video')
            self.assertFalse(gate.inspect(gate.tree_files(root))['passed'])

    def test_staged_blob_not_clean_worktree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            p = root / 'asset.png'; p.write_bytes(b'x' * (gate.LARGE_BYTES + 1))
            subprocess.run(['git', '-C', str(root), 'add', 'asset.png'], check=True)
            p.write_bytes(b'clean small working tree')
            staged = gate.staged_files(root)
            self.assertGreater(len(staged['asset.png']), gate.LARGE_BYTES)
            self.assertFalse(gate.inspect(staged)['passed'])
            p = root / 'preview.mp4'; p.write_bytes(b'video')
            subprocess.run(['git', '-C', str(root), 'add', 'preview.mp4'], check=True)
            p.unlink()
            self.assertFalse(gate.inspect(gate.staged_files(root))['passed'])


if __name__ == '__main__': unittest.main()
