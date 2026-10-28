#!/usr/bin/env python3
"""Fresh standalone extraction/import/lifecycle checks; all output stays outside source."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('extract_game', ROOT / 'tools/extract_game.py')
EXTRACTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXTRACTOR)
TESTS = {
    'gummy_bomber': ['test_runtime', 'test_sim', 'test_save_schema', 'test_exit'],
    'bloom_skirmish': ['test_runtime', 'test_storage', 'test_sim'],
    'tide_gulp': ['test_runtime', 'test_storage', 'test_sim'],
    'beach_cleanup': ['test_runtime', 'test_storage', 'test_sim'],
    'volcano_escape': ['test_runtime', 'test_storage', 'test_sim'],
    'pelican_pedal': ['test_runtime', 'test_storage', 'test_sim', 'test_standalone_exit'],
    'fruit_gummy_snake': ['test_runtime', 'test_storage', 'test_xyz', 'test_camera', 'test_interface', 'test_detach'],
    'monkey_vine': ['test_rules_route', 'test_rules_bonus', 'test_rules_invariants'],
}
ERRORS = re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL', re.M)


def check_game(game_id, output, godot):
    work = output / game_id
    work.mkdir()
    project = EXTRACTOR.extract_game(game_id, work / 'project', ROOT)
    leave = 'request_exit' if game_id == 'monkey_vine' else 'leave_game'
    started = 'started' if game_id == 'monkey_vine' else 'has_started'
    # This probe is test-only, written to the extracted copy, never the source module.
    (project / 'standalone_probe.gd').write_text(f'''extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://modules/{game_id}/main.tscn").instantiate()
    root.add_child(game); current_scene = game
    for frame in 120: await process_frame
    if not game.{started}:
        printerr("FAIL standalone did not start"); quit(1); return
    print("STANDALONE START PASS; requesting normal exit")
    game.{leave}()
    await create_timer(4).timeout
    printerr("FAIL standalone did not close itself"); quit(1)
''')
    commands = [('import', ['--editor', '--import', '--quit']),
                ('startup_exit', ['--script', 'res://standalone_probe.gd'])]
    commands += [(test, ['--script', f'res://modules/{game_id}/tests/{test}.gd']) for test in TESTS[game_id]]
    if game_id == 'gummy_bomber':
        commands.append(('test_exit_standalone', ['--script', 'res://modules/gummy_bomber/tests/test_exit.gd', '--', 'standalone']))
    results = []
    for label, arguments in commands:
        env = os.environ.copy()
        env['GODOT_SILENCE_ROOT_WARNING'] = '1'
        for kind in ('DATA', 'CONFIG', 'CACHE'):
            path = work / label / kind.lower()
            path.mkdir(parents=True)
            env[f'XDG_{kind}_HOME'] = str(path)
        try:
            run = subprocess.run([str(godot), '--headless', '--path', str(project), *arguments],
                                 capture_output=True, text=True, env=env, timeout=240)
            status, log = run.returncode, run.stdout + run.stderr
        except subprocess.TimeoutExpired as error:
            status, log = 124, str(error.stdout) + str(error.stderr)
        (work / f'{label}.log').write_text(log)
        issues = [line for line in log.splitlines() if ERRORS.search(line)]
        if label == 'startup_exit' and 'STANDALONE START PASS; requesting normal exit' not in log:
            issues.append('Missing standalone startup marker')
        passed = status == 0 and not issues
        results.append({'step': label, 'returncode': status, 'passed': passed, 'issues': issues})
        print(game_id, label, 'PASS' if passed else 'FAIL', flush=True)
    result = {'game': game_id, 'project': str(project), 'checks': results}
    (work / 'result.json').write_text(json.dumps(result, indent=2))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path, help='Godot 4.7.2 executable')
    parser.add_argument('--output', type=Path, help='New directory outside the source tree')
    parser.add_argument('--jobs', type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    try:
        version = subprocess.run([str(args.godot.resolve()), '--version'], capture_output=True,
                                 text=True, timeout=15, check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError) as error:
        parser.error(f'Cannot verify Godot version: {error}')
    if version != '4.7.2.stable.official.ed1daf0bf':
        parser.error(f'Requires Godot 4.7.2.stable.official.ed1daf0bf; got {version!r}')
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='iland-standalone-'))
    if output.is_relative_to(ROOT):
        parser.error('Output must be outside the source tree')
    if args.output:
        output.mkdir(parents=True, exist_ok=False)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda game: check_game(game, output, args.godot.resolve()), TESTS))
    (output / 'matrix.json').write_text(json.dumps(results, indent=2))
    print('Evidence:', output)
    return 0 if all(check['passed'] for result in results for check in result['checks']) else 1


if __name__ == '__main__':
    raise SystemExit(main())
