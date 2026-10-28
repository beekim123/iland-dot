#!/usr/bin/env python3
"""Explicit local-export sync, or read-only verification of committed runtime assets."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import wave


def digest(data):
    return hashlib.sha256(data).hexdigest()


def asset_bytes(path):
    data = path.read_bytes()
    if path.suffix == '.glb':
        if len(data) < 20 or struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
            raise ValueError(f'Invalid GLB header: {path}')
        offset = 12
        first = True
        while offset < len(data):
            if offset + 8 > len(data):
                raise ValueError(f'Truncated GLB chunk: {path}')
            size, kind = struct.unpack_from('<II', data, offset)
            offset += 8
            if size % 4 or offset + size > len(data):
                raise ValueError(f'Invalid GLB chunk: {path}')
            if first:
                if kind != 0x4E4F534A:
                    raise ValueError(f'Missing GLB JSON: {path}')
                json.loads(data[offset:offset + size])
                first = False
            offset += size
    elif path.suffix == '.wav':
        with wave.open(io.BytesIO(data), 'rb') as sound:
            expected = sound.getnframes() * sound.getnchannels() * sound.getsampwidth()
            if not expected or len(sound.readframes(sound.getnframes())) != expected:
                raise ValueError(f'Empty or truncated WAV: {path}')
    else:
        raise ValueError(f'Unsupported asset format: {path}')
    return data


def local_path(root, name):
    path = Path(name)
    if path.is_absolute() or '..' in path.parts or not name:
        raise ValueError(f'Unsafe manifest path: {name}')
    result = root / path
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'Path escapes project: {name}')
    return result


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def sync(root, check=False):
    root = Path(root)
    manifest_path = root / 'docs/resource_manifest.json'
    old_manifest_bytes = manifest_path.read_bytes()
    locked = json.loads(old_manifest_bytes)
    active = json.loads((root / 'docs/active_asset_manifest.json').read_text())
    key = lambda item: (item['source'], item['destination'])
    entries = active['files']
    keys = [key(item) for item in entries]
    lock_keys = [key(item) for item in locked['files']]
    if (len(set(keys)) != len(keys) or len(set(lock_keys)) != len(lock_keys)
            or len({item['destination'] for item in entries}) != len(entries)
            or set(keys) != set(lock_keys) or active['revision'] != locked['revision']):
        raise ValueError('Active/locked manifest sets or revisions disagree (or duplicate destination)')
    sources = {item['source'] for item in entries}
    if sources & {item['destination'] for item in entries}:
        raise ValueError('Source and destination paths overlap')
    locks = {key(item): item for item in locked['files']}
    changes, report, records = [], [], []
    # Preflight every item before writing anything; retain snapshots for rollback.
    for item in entries:
        src = local_path(root, item['source'])
        dst = local_path(root, item['destination'])
        previous = dst.read_bytes() if dst.is_file() else None
        lock = locks[key(item)]
        source = asset_bytes(src) if src.is_file() else None
        if src.exists() and not src.is_file():
            raise ValueError(f'Source is not a regular file: {src}')
        if check or source is None:
            if previous is None:
                raise ValueError(f'Missing runtime asset: {dst}')
            if len(previous) != lock['bytes'] or digest(previous) != lock['sha256']:
                raise ValueError(f'Runtime hash/size mismatch: {dst}')
            if check and source is not None and source != previous:
                raise ValueError(f'Unsynced local export: {src}; run explicit sync after review')
            current = previous
            record = lock  # Never bless modified runtime bytes when source is missing.
            status = 'runtime_verified'
        else:
            current = source
            record = {**item, 'sha256': digest(current), 'bytes': len(current)}
            status = 'unchanged' if previous == current else 'copied'
            if previous != current:
                changes.append((dst, current, previous))
        records.append(record)
        report.append({**record, 'status': status, 'previous_sha256': lock['sha256']})
    new_manifest = {**locked, 'files': records}
    # Preserve byte-identical lock file on fresh clones / no-op runs.
    new_bytes = (json.dumps(new_manifest, indent=2) + '\n').encode() if new_manifest != locked else old_manifest_bytes
    if not check:
        written = []
        try:
            for dst, current, previous in changes:
                atomic_write(dst, current)
                written.append((dst, previous))
            if new_bytes != old_manifest_bytes:
                atomic_write(manifest_path, new_bytes)
        except Exception:
            for dst, previous in reversed(written):
                if previous is None:
                    dst.unlink(missing_ok=True)
                else:
                    atomic_write(dst, previous)
            raise
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify runtime hashes and detect unsynced local exports; never write')
    args = parser.parse_args()
    try:
        print(json.dumps(sync(Path(__file__).resolve().parents[1], args.check), indent=2))
    except (OSError, ValueError, KeyError, TypeError, wave.Error) as error:
        print(f'Resource sync failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
