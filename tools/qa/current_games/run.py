#!/usr/bin/env python3
"""Current registered-game integration/extraction smoke, NOT full rules or visual acceptance."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]
MODULES = ('gummy_bomber', 'bloom_skirmish', 'tide_gulp', 'beach_cleanup',
           'volcano_escape', 'pelican_pedal', 'fruit_gummy_snake', 'monkey_vine',
           'dawn_sword', 'apprentice_yokai_king', 'woodland_duel',
           'tide_lantern', 'moon_post', 'whale_bento')
HOST = ('tests/check_app.gd', 'app/tests/test_portal_rotation.gd',
        'hub/tests/test_hub.gd', 'hub/tests/test_portal_picking.gd',
        'hub/tests/test_portal_layout.gd', 'hub/catalog/tests/test_catalog.gd',
        'app/tests/test_current_game_admission.gd')
SCOPE = {
    'scope': 'current integration and extraction smoke; NOT full rules regression',
    'modules': MODULES, 'host': HOST,
    'host_window_close': 'six newest modules: process-level propagated WM close notification, not native UI',
    'save_namespace': 'production literal user:// paths confined to own game; not dynamic-write proof',
    'extracted': 'all declared modules: production extraction, exact source bytes, import, start(context), exit signal',
    'exclusions': ['full module rules/long simulations', 'process-level standalone quit',
                   'graphical/native-input/audio judgement', 'Web/user-device performance'],
    'history': 'six/seven/eight runners and ten/eleven-entry admission tests remain historical; not reused here',
}
BAD = re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL', re.M)


def snapshot(folder):
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file()
            and not any(x in p.parts for x in ('.godot', '__pycache__'))
            and p.suffix not in ('.import', '.pyc')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list', action='store_true', help='Print exact coverage without running')
    args = parser.parse_args()
    if args.list:
        print(json.dumps(SCOPE, ensure_ascii=False, indent=2))
        return
    qa = Path(tempfile.mkdtemp(prefix='sunny-current-smoke-'))
    print('CURRENT SMOKE EVIDENCE:', qa, flush=True)
    before = {top: snapshot(ROOT / top) for top in ('godot', 'tools')}
    (qa / 'source-before.json').write_text(json.dumps(before, indent=2))
    steps, error = [], None
    engine = os.environ.get('GODOT_BIN', str(ROOT.parent / 'tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))

    def run(name, command, marker=None):
        env = dict(os.environ)
        for key, sub in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
            path = qa / 'userdata' / name / sub
            path.mkdir(parents=True)
            env[key] = str(path)
        log = qa / (name + '.log')
        print('==', name, '==', flush=True)
        with log.open('w') as out:
            result = subprocess.run([str(x) for x in command], cwd=qa, env=env,
                                    stdout=out, stderr=subprocess.STDOUT, timeout=300)
        content = log.read_text(errors='replace')
        ok = result.returncode == 0 and not BAD.search(content) and (marker is None or marker in content)
        steps.append({'name': name, 'passed': bool(ok), 'exit_code': result.returncode, 'log': str(log)})
        (qa / 'steps.json').write_text(json.dumps(steps, indent=2))
        print('\n'.join(content.splitlines()[-2:]), flush=True)
        if not ok:
            raise RuntimeError(f'{name} failed: {log}')
        return content

    try:
        run('engine-version', [engine, '--version'], '4.7.2.stable.official.ed1daf0bf')
        spec = importlib.util.spec_from_file_location('extractor', ROOT / 'tools/extract_game.py')
        extractor = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(extractor)
        registered = re.findall(r'"id"\s*:\s*"([^"]+)"', (ROOT / 'godot/app/game_registry.gd').read_text())
        if set(registered) != set(MODULES) or set(extractor.GAMES) != set(MODULES):
            raise RuntimeError('Registry/extractor coverage changed: update the declared smoke matrix')
        host = qa / 'host'
        shutil.copytree(ROOT / 'godot', host, ignore=shutil.ignore_patterns('.godot', '*.import', '__pycache__', '*.pyc'))
        if snapshot(host) != before['godot']:
            raise RuntimeError('Host copy differs from frozen source')
        # Copy QA scripts so the executing probes are frozen as well.
        shutil.copytree(ROOT / 'tools', qa / 'tools', ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        run('extractor-policy', [sys.executable, qa / 'tools/qa/test_extract_game.py'])
        # Freeze extraction input before imports can generate missing .uid metadata.
        frozen = qa / 'frozen'
        frozen.mkdir()
        shutil.copytree(host, frozen / 'godot')
        run('literal-save-namespaces', [sys.executable, qa / 'tools/qa/current_games/test_namespaces.py', frozen], 'CURRENT_PRIVATE_LITERAL_NAMESPACES_PASS')
        run('host-import', [engine, '--headless', '--path', host, '--editor', '--import', '--quit'])
        for script in HOST:
            run('host-' + Path(script).stem, [engine, '--headless', '--path', host, '--script', 'res://' + script])
        for module in MODULES[8:]:
            run(module + '-host-window-close', [engine, '--headless', '--path', host, '--script', 'res://app/tests/test_host_window_close.gd', '--', module], 'HOST_WM_CLOSE_ACCEPTED: ' + module)
        for module in MODULES:
            dest = qa / 'extracted' / module
            extractor.extract_game(module, dest, frozen)
            if {p.name for p in dest.iterdir()} != {'modules', 'project.godot'} or {p.name for p in (dest / 'modules').iterdir()} != {module}:
                raise RuntimeError('Extraction includes unexpected project/sibling content: ' + module)
            if snapshot(dest / 'modules' / module) != snapshot(frozen / 'godot/modules' / module):
                raise RuntimeError('Extraction source mismatch: ' + module)
            run(module + '-import', [engine, '--headless', '--path', dest, '--editor', '--import', '--quit'])
            run(module + '-interface', [engine, '--headless', '--path', dest, '--script', qa / 'tools/qa/current_games/extracted_interface.gd'], 'CURRENT_EXTRACTED_INTERFACE_PASS: ' + module)
    except Exception as exc:
        error = str(exc)
    after = {top: snapshot(ROOT / top) for top in ('godot', 'tools')}
    (qa / 'source-after.json').write_text(json.dumps(after, indent=2))
    if before != after:
        error = 'Repository source changed during QA' + (': ' + error if error else '')
    result = {**SCOPE, 'passed': error is None, 'error': error, 'source_unchanged': before == after,
              'steps': steps, 'evidence': str(qa)}
    (qa / 'RESULT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if error:
        sys.exit(1)


if __name__ == '__main__':
    main()
