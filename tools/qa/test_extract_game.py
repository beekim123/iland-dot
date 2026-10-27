#!/usr/bin/env python3
"""Extractor policy regression; fixture modules avoid needing a display or Godot."""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

SPEC = importlib.util.spec_from_file_location('extract_game', Path(__file__).parents[1] / 'extract_game.py')
extractor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(extractor)


class ExtractionTests(unittest.TestCase):
    def setUp(self):
        self.scratch = TemporaryDirectory(prefix='sunny-extractor-test-')
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.repo = self.root / 'repo'
        for game_id in extractor.GAMES:
            module = self.module(game_id)
            module.mkdir(parents=True)
            (module / 'main.tscn').write_text('[gd_scene format=3]\n[node name="Game" type="Node"]\n')
            (module / 'fonts').mkdir()
            (module / 'fonts/OFL.txt').write_text('Fixture license, must be copied verbatim.\n')
            (module / 'art').mkdir()
            (module / 'art/README.md').write_text('Fixture provenance and generation instructions.\n')
        # Files which must not accompany a game, even when they exist in the source project.
        (self.repo / 'godot/app').mkdir()
        (self.repo / 'godot/app/private.txt').write_text('Host-only fixture')

    def module(self, game_id='bloom_skirmish'):
        return self.repo / 'godot/modules' / game_id

    def extract(self, game_id='bloom_skirmish', destination=None):
        return extractor.extract_game(game_id, destination or self.root / 'standalone', self.repo)

    def test_both_module_ids_titles_and_licenses(self):
        for game_id, title in extractor.GAMES.items():
            with self.subTest(game_id=game_id):
                dest = self.extract(game_id, self.root / game_id)
                module = dest / 'modules' / game_id
                self.assertEqual((module / 'fonts/OFL.txt').read_bytes(), (self.module(game_id) / 'fonts/OFL.txt').read_bytes())
                self.assertTrue((module / 'art/README.md').is_file())
                self.assertIn(f'config/name="{title}"', (dest / 'project.godot').read_text())
                self.assertIn(f'run/main_scene="res://modules/{game_id}/main.tscn"', (dest / 'project.godot').read_text())
                self.assertEqual(set(p.name for p in dest.iterdir()), {'modules', 'project.godot'})
                self.assertEqual([p.name for p in (dest / 'modules').iterdir()], [game_id])

    def test_unknown_id_and_missing_entry_rejected_before_copy(self):
        with self.assertRaisesRegex(ValueError, 'Unknown game ID'):
            self.extract('snake')
        (self.module() / 'main.tscn').unlink()
        with self.assertRaisesRegex(ValueError, 'entry main.tscn is missing'):
            self.extract()
        self.assertFalse((self.root / 'standalone').exists())

    def test_existing_directory_never_overwritten(self):
        self.extract()
        keep = self.root / 'standalone/user-work.txt'
        keep.write_text('Do not overwrite me')
        with self.assertRaisesRegex(ValueError, 'must not exist'):
            self.extract()
        self.assertEqual(keep.read_text(), 'Do not overwrite me')

    def test_destination_inside_module_rejected(self):
        with self.assertRaisesRegex(ValueError, 'inside the source module'):
            self.extract(destination=self.module() / 'nested-copy')
        self.assertFalse((self.module() / 'nested-copy').exists())

    def test_external_and_path_traversal_references_rejected(self):
        for resource_path in ['res://hub/private.gd', 'res://modules/gummy_bomber/game.gd',
                              'res://modules/bloom_skirmish/../gummy_bomber/game.gd',
                              'res://modules/bloom_skirmish/../../../outside.gd']:
            with self.subTest(resource_path=resource_path):
                (self.module() / 'invalid.gd').write_text(f'const BAD = preload("{resource_path}")\n')
                with self.assertRaisesRegex(ValueError, 'External dependency'):
                    self.extract()
                self.assertFalse((self.root / 'standalone').exists())

    def test_internal_reference_allowed_and_import_cache_excluded(self):
        (self.module() / 'safe.gd').write_text('const MAIN = "res://modules/bloom_skirmish/main.tscn"\n')
        (self.module() / '.godot').mkdir()
        (self.module() / '.godot/cache').write_text('generated')
        (self.module() / 'fake.png.import').write_text('generated')
        dest = self.extract()
        self.assertTrue((dest / 'modules/bloom_skirmish/safe.gd').is_file())
        self.assertFalse((dest / 'modules/bloom_skirmish/.godot').exists())
        self.assertFalse((dest / 'modules/bloom_skirmish/fake.png.import').exists())

    def test_symbolic_links_rejected(self):
        (self.module() / 'outside').symlink_to(self.repo / 'godot/app', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.extract()
        self.assertFalse((self.root / 'standalone').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
