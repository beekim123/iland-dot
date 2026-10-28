"""No Blender/Godot required: python3 -m unittest discover -s tools/qa -p test_sync_resources.py -v"""
import importlib.util
import io
import wave
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sync_resources', Path(__file__).resolve().parents[1] / 'sync_resources.py')
syncer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(syncer)


def glb(label):
    body = json.dumps({'asset': {'version': '2.0'}, 'extras': label}).encode()
    body += b' ' * (-len(body) % 4)
    return struct.pack('<4sIIII', b'glTF', 2, 20 + len(body), len(body), 0x4E4F534A) + body


class ResourceSyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'docs').mkdir()
        self.items = [{'source': f'art/{n}.glb', 'destination': f'godot/{n}.glb'} for n in ('a', 'b')]
        self.original = glb('original')
        for item in self.items:
            p = self.root / item['destination']; p.parent.mkdir(exist_ok=True); p.write_bytes(self.original)
        self.active = {'revision': 'test', 'files': self.items}
        self.lock = {'revision': 'test', 'files': [{**i, 'bytes': len(self.original), 'sha256': syncer.digest(self.original)} for i in self.items]}
        (self.root / 'docs/active_asset_manifest.json').write_text(json.dumps(self.active))
        (self.root / 'docs/resource_manifest.json').write_text(json.dumps(self.lock))

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}

    def source(self, index=0, data=None):
        p = self.root / self.items[index]['source']; p.parent.mkdir(exist_ok=True); p.write_bytes(data or glb('new'))
        return p

    def assert_failure_unchanged(self, check=False):
        before = self.snapshot()
        with self.assertRaises((ValueError, OSError)):
            syncer.sync(self.root, check)
        self.assertEqual(before, self.snapshot())

    def test_fresh_clone_no_sources_no_writes(self):
        before = self.snapshot()
        syncer.sync(self.root, True); syncer.sync(self.root)
        self.assertEqual(before, self.snapshot())

    def test_matching_sources_no_writes(self):
        self.source(data=self.original)
        before = self.snapshot(); syncer.sync(self.root); syncer.sync(self.root, True)
        self.assertEqual(before, self.snapshot())

    def test_tampered_runtime_without_source_rejected(self):
        (self.root / self.items[0]['destination']).write_bytes(glb('tampered'))
        self.assert_failure_unchanged(); self.assert_failure_unchanged(True)

    def test_missing_runtime_without_source_rejected(self):
        (self.root / self.items[0]['destination']).unlink()
        self.assert_failure_unchanged(); self.assert_failure_unchanged(True)

    def test_new_source_check_rejects_without_writes(self):
        self.source(); self.assert_failure_unchanged(True)

    def test_explicit_sync_updates_hash_and_is_idempotent(self):
        src = self.source(); result = syncer.sync(self.root)
        self.assertEqual(result[0]['status'], 'copied')
        self.assertEqual(result[0]['sha256'], syncer.digest(src.read_bytes()))
        self.assertEqual((self.root / self.items[0]['destination']).read_bytes(), src.read_bytes())
        before = self.snapshot(); syncer.sync(self.root); syncer.sync(self.root, True)
        self.assertEqual(before, self.snapshot())

    def test_source_can_restore_missing_runtime(self):
        self.source(); (self.root / self.items[0]['destination']).unlink()
        syncer.sync(self.root); syncer.sync(self.root, True)

    def test_invalid_source_rejected(self):
        self.source(data=b'not glb'); self.assert_failure_unchanged()

    def test_later_error_prevents_earlier_copy(self):
        self.source(); (self.root / self.items[1]['destination']).unlink()
        self.assert_failure_unchanged()

    def test_missing_lock_entry_rejected(self):
        self.lock['files'].pop()
        (self.root / 'docs/resource_manifest.json').write_text(json.dumps(self.lock))
        self.assert_failure_unchanged()

    def test_duplicate_destinations_rejected(self):
        self.active['files'][1]['destination'] = self.items[0]['destination']
        (self.root / 'docs/active_asset_manifest.json').write_text(json.dumps(self.active))
        self.assert_failure_unchanged()

    def test_wav_integrity(self):
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as sound:
            sound.setnchannels(2); sound.setsampwidth(2); sound.setframerate(44100)
            sound.writeframes(b'\0' * 40)
        path = self.root / 'test.wav'; path.write_bytes(buffer.getvalue())
        self.assertEqual(syncer.asset_bytes(path), buffer.getvalue())
        path.write_bytes(buffer.getvalue()[:-4])
        with self.assertRaises(ValueError):
            syncer.asset_bytes(path)

    def test_check_rejects_corrupt_runtime_even_with_valid_source(self):
        self.source()
        (self.root / self.items[0]['destination']).write_bytes(glb('tampered'))
        self.assert_failure_unchanged(True)

    def test_source_path_traversal_rejected(self):
        for data in (self.active, self.lock):
            data['files'][0]['source'] = '../escape.glb'
        (self.root / 'docs/active_asset_manifest.json').write_text(json.dumps(self.active))
        (self.root / 'docs/resource_manifest.json').write_text(json.dumps(self.lock))
        self.assert_failure_unchanged()

    def test_write_failure_rolls_back_runtime(self):
        self.source(); self.source(1)
        original_write = syncer.atomic_write
        def fail_second(path, data):
            if path == self.root / self.items[1]['destination']:
                raise OSError('simulated write failure')
            original_write(path, data)
        with patch.object(syncer, 'atomic_write', fail_second):
            self.assert_failure_unchanged()

    def test_lock_write_failure_rolls_back_runtime(self):
        self.source()
        original_write = syncer.atomic_write
        def fail_lock(path, data):
            if path.name == 'resource_manifest.json':
                raise OSError('simulated lock write failure')
            original_write(path, data)
        with patch.object(syncer, 'atomic_write', fail_lock):
            self.assert_failure_unchanged()


if __name__ == '__main__':
    unittest.main()
