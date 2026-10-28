#!/usr/bin/env python3
"""Read-only artifact gate. Static checks cannot establish all resource usefulness."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

BINARY = {'.png', '.jpg', '.jpeg', '.glb', '.wav', '.ogg', '.otf', '.ttf', '.woff2'}
# Intentional self-contained module font copies; licenses must remain alongside them.
DUPLICATE_FONT_ALLOWANCE = {'.otf', '.ttf', '.woff2'}
LARGE_BYTES = 10 * 1024 * 1024
# Reviewed runtime camera-follow map; exact compressed bytes only, changes require fresh review.
REVIEWED_LARGE = {
    'godot/modules/apprentice_yokai_king/art/arena_large.png': '2ef43b684257604de377e43115ee5c87dc7f2d8aa66de1684421523257a9a645'
}


def forbidden(name):
    p = PurePosixPath(name)
    parts = {x.lower() for x in p.parts}
    suffix = p.suffix.lower()
    if suffix in {'.mp4', '.avi', '.webm', '.mov', '.gif', '.blend', '.blend1', '.pyc', '.import', '.log'}:
        return 'preview/authoring/cache output extension'
    if parts & {'.godot', '__pycache__', '.runtime', 'node_modules', 'build', 'dist', 'exports', 'backups'}:
        return 'generated/cache/output directory'
    lower = '/' + name.lower()
    if any(x in lower for x in ('/art/source/', '/art/sources/', '/audio/source/')):
        return 'art/audio authoring input (not generic source code directories)'
    if p.parts and (p.parts[0] in {'art', 'audio'} or p.parts[0].startswith('iland-engine-version-')):
        return 'root authoring/temp directory; runtime assets belong under godot/'
    return None


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def staged_files(root):
    # Read stage-0 blob identities directly: no worktree substitution or text decoding.
    changed = set(git(root, 'diff', '--cached', '--name-only', '--diff-filter=ACMRTUXB', '-z').decode().split('\0'))
    result = {}
    for record in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if not record:
            continue
        meta, raw_name = record.split(b'\t', 1)
        mode, oid, stage = meta.decode().split()
        name = raw_name.decode()
        if stage != '0':
            raise ValueError('Unmerged index entry: ' + name)
        if name not in changed:
            continue
        if mode not in {'100644', '100755'}:
            raise ValueError('Review symlink/submodule index entry separately: ' + name)
        result[name] = git(root, 'cat-file', 'blob', oid)
    return result


def index_binaries(root):
    result = {}
    for record in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if not record: continue
        meta, raw_name = record.split(b'\t', 1)
        mode, oid, stage = meta.decode().split()
        name = raw_name.decode()
        if stage == '0' and mode in {'100644', '100755'} and PurePosixPath(name).suffix.lower() in BINARY - DUPLICATE_FONT_ALLOWANCE:
            result[name] = git(root, 'cat-file', 'blob', oid)
    return result


def tree_files(root):
    result = {}
    for p in sorted(root.rglob('*')):
        rel = p.relative_to(root)
        if '.git' in rel.parts:
            continue
        if p.is_symlink():
            raise ValueError('Symlink requires explicit review outside this gate: ' + str(rel))
        if p.is_file():
            result[rel.as_posix()] = p.read_bytes()
    return result


def inspect(files, reviewed=(), comparison_files=None):
    errors, risks, groups = [], [], {}
    for name, data in sorted(files.items()):
        reason = forbidden(name)
        if reason:
            errors.append({'path': name, 'reason': reason})
        if len(data) > LARGE_BYTES:
            risks.append({'path': name, 'reason': 'large file', 'bytes': len(data)})
    for name, data in (comparison_files if comparison_files is not None else files).items():
        suffix = PurePosixPath(name).suffix.lower()
        if suffix in BINARY - DUPLICATE_FONT_ALLOWANCE and len(data) >= 65536:
            groups.setdefault(hashlib.sha256(data).hexdigest(), []).append(name)
    for digest, names in groups.items():
        if len(names) > 1:
            risks.extend({'path': n, 'reason': 'identical binary payload', 'peers': names, 'sha256': digest} for n in names if n in files)
    approved = {name for name, digest in REVIEWED_LARGE.items() if name in files and hashlib.sha256(files[name]).hexdigest() == digest}
    pending = [risk for risk in risks if risk['path'] not in reviewed and not (risk['reason'] == 'large file' and risk['path'] in approved)]
    return {'passed': not errors and not pending, 'checked_files': len(files), 'hard_errors': errors,
            'review_risks': risks, 'exact_hash_large_allowances_used': sorted(approved), 'unreviewed_risks': pending,
            'limits': 'Not an unused-resource proof. Review dynamic loads/manifests/tests/licenses manually. No files deleted.'}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--staged', action='store_true', help='Inspect actual added/changed stage-0 Git blobs')
    mode.add_argument('--tree', type=Path, help='Inspect source candidate without Git metadata')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--reviewed', action='append', default=[], metavar='PATH', help='Acknowledge an exact manual-risk path; cannot bypass forbidden artifacts')
    args = parser.parse_args(argv)
    root = (args.tree or args.root).resolve()
    try:
        in_git = subprocess.run(['git', '-C', str(root), 'rev-parse', '--show-toplevel'], capture_output=True).returncode == 0
        use_staged = args.staged or (args.tree is None and in_git)
        report = inspect(staged_files(root) if use_staged else tree_files(root), set(args.reviewed), index_binaries(root) if use_staged else None)
        report['mode'] = 'staged-index' if use_staged else 'source-tree'
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        report = {'passed': False, 'error': str(error)}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
