#!/usr/bin/env python3
"""Frozen six-admitted-module regression; inactive Snake is explicitly excluded.

All runtime suites run against a byte-identical isolated copy, so concurrent
work on the disabled Snake module cannot accidentally join this acceptance.
This does not replace graphical/native-input, Web or performance acceptance.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, re, shutil, subprocess, sys, tempfile, time
ROOT = Path(__file__).resolve().parents[3]
MODULES = ('gummy_bomber','bloom_skirmish','tide_gulp','beach_cleanup','volcano_escape','pelican_pedal')
AUTHOR = {
 'gummy_bomber':['tests/test_sim.gd','tests/test_runtime.gd','tests/test_save_schema.gd'],
 'bloom_skirmish':['art/validate_art.gd','tests/test_sim.gd','tests/test_runtime.gd','tests/test_storage.gd'],
 'tide_gulp':['tests/test_sim.gd','tests/test_runtime.gd','tests/test_storage.gd','art/tide_art_contract_check.gd','ui/test_ui_audio.gd'],
 'beach_cleanup':['tests/test_sim.gd','tests/test_runtime.gd','tests/test_storage.gd','art/environment/test_environment.gd','art/vehicle/test_model.gd','ui/test_interface.gd'],
 'volcano_escape':['tests/test_sim.gd','tests/test_runtime.gd','tests/test_storage.gd','art/environment/test_environment.gd','art/character/tests/test_character.gd','ui/test_hud.gd','ui/test_route_map.gd','ui/test_hud_detach.gd'],
 'pelican_pedal':['tests/test_sim.gd','tests/test_routes.gd','tests/test_edges.gd','tests/test_input.gd','tests/test_runtime.gd','tests/test_storage.gd','tests/test_world.gd','art/test_assets.gd'],
}
INDEPENDENT = {
 'gummy_bomber':['independent','lifecycle','storage'],
 'bloom_skirmish':['independent','lifecycle','storage','perspective','liquid','hud','skin_runtime','animal_runtime','standalone'],
 'tide_gulp':['resource_probe','independent','lifecycle','storage'],
 'pelican_rebuild':['independent','storage','lifecycle','wm_close'],
}
HOST = ['tests/check_scene.gd','tests/check_app.gd','app/tests/test_portal_rotation.gd','hub/tests/test_hub.gd','hub/tests/test_portal_picking.gd','hub/tests/test_portal_layout.gd','hub/catalog/tests/test_catalog.gd']
BAD = re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use',re.M)

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def runtime_files(folder):
 return {str(p.relative_to(folder)):digest(p) for p in sorted(folder.rglob('*')) if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts and p.suffix not in ('.import','.pyc')}
def source_snapshot():
 result={}
 for top in ('godot','tools'):
  for p in sorted((ROOT/top).rglob('*')):
   rel=p.relative_to(ROOT)
   if not p.is_file() or '.godot' in rel.parts or '__pycache__' in rel.parts or p.suffix in ('.import','.pyc'):continue
   if str(rel).startswith(('godot/modules/fruit_gummy_snake/','tools/qa/fruit_gummy_snake/')):continue
   if top=='tools':
    if 'evidence' in rel.parts or p.suffix not in ('.gd','.uid','.py','.sh','.json','.toml','.cfg','.txt','.yaml','.yml'):continue
   if p.is_symlink(): raise RuntimeError(f'Unexpected source symlink: {rel}')
   result[str(rel)]=digest(p)
 return result

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--list',action='store_true',help='Print declared coverage without running')
 args=parser.parse_args()
 if args.list:
  print(json.dumps({'modules':MODULES,'host':HOST,'author':AUTHOR,'independent':INDEPENDENT,'four_portal':['rotation','catalog_input','pagination','host_lifecycle','paged_host'],'bloom_window_close':['standalone','host_bloom','host_hub','host_gummy'],'fresh':list(MODULES),'exclusions':['inactive fruit_gummy_snake','unrecovered old Beach/Volcano independent suites','graphical/native/Web/performance']},indent=2));return
 godot=os.environ.get('GODOT_BIN',str(ROOT.parent/'tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))
 qa=Path(tempfile.mkdtemp(prefix='sunny-six-frozen-'))
 print(f'SIX-GAME QA {qa}',flush=True)
 print('EXCLUDED: inactive fruit_gummy_snake; historical Beach/Volcano independent suites are not present and not claimed.',flush=True)
 before=source_snapshot();(qa/'source-before.json').write_text(json.dumps(before,indent=2))
 # Legacy check_scene writes ../docs/runtime_checks.json; retain that contract
 # inside QA instead of mutating the repository or its test oracle.
 (qa/'docs').mkdir()
 project=qa/'host'
 def ignored(path,names):
  excluded={x for x in names if x in ('.godot','__pycache__') or x.endswith(('.import','.pyc'))}
  if Path(path)==ROOT/'godot/modules': excluded.add('fruit_gummy_snake')
  return excluded
 shutil.copytree(ROOT/'godot',project,ignore=ignored)
 original={str(p.relative_to(ROOT/'godot')):digest(p) for p in (ROOT/'godot').rglob('*') if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts and p.suffix not in ('.import','.pyc') and 'fruit_gummy_snake' not in p.relative_to(ROOT/'godot').parts}
 assert runtime_files(project)==original,'Isolated six-module host copy is not byte-identical'
 records=[]
 def execute(name,cmd,project_path=None):
  data=qa/'userdata'/name
  for child in ('data','config','cache'):(data/child).mkdir(parents=True,exist_ok=True)
  env=dict(os.environ,XDG_DATA_HOME=str(data/'data'),XDG_CONFIG_HOME=str(data/'config'),XDG_CACHE_HOME=str(data/'cache'))
  log=qa/(name+'.log');log.parent.mkdir(parents=True,exist_ok=True)
  print(f'== {name} ==',flush=True);started=time.monotonic()
  with log.open('w') as f:
   completed=subprocess.run([str(x) for x in cmd],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
  content=log.read_text(errors='replace')
  for line in content.splitlines()[-4:]:print(line,flush=True)
  ok=completed.returncode==0 and BAD.search(content) is None
  records.append({'name':name,'exit_code':completed.returncode,'clean':ok,'seconds':round(time.monotonic()-started,2),'log':str(log),'project':str(project_path) if project_path else None})
  (qa/'steps.json').write_text(json.dumps(records,indent=2))
  if not ok:raise RuntimeError(f'Failed {name}; inspect {log}')
 def run(name,script,where=project):execute(name,[godot,'--headless','--path',where,'--script',script],where)
 failure=None
 try:
  execute('engine-version',[godot,'--version'])
  version=(qa/'engine-version.log').read_text()
  assert '4.7.2.stable.official.ed1daf0bf' in version,'Exact approved engine is required'
  execute('host-import',[godot,'--headless','--path',project,'--editor','--import','--quit'],project)
  execute('extractor-policy',[sys.executable,ROOT/'tools/qa/test_extract_game.py'])
  for name,script,extra in [
   ('bloom-assets','tools/qa/bloom_skirmish/assets.py',[]),
   ('bloom-font','godot/modules/bloom_skirmish/ui/subset_font.py',['--check']),
   ('bloom-skin','tools/qa/bloom_skirmish/skin_assets.py',[]),
   ('bloom-palette','tools/qa/bloom_skirmish/skin_palette.py',['--json',str(qa/'fox-palette.json')]),
   ('tide-assets','tools/qa/tide_gulp/assets.py',[]),
   ('pelican-skin','tools/qa/pelican_rebuild/skin.py',[])]:execute(name,[sys.executable,ROOT/script,*extra])
  for script in HOST:
   if not (project/script).is_file():raise RuntimeError('Required host suite missing: '+script)
   run('host-'+Path(script).stem,'res://'+script)
  for module,scripts in AUTHOR.items():
   for script in scripts:run('author-'+module+'-'+Path(script).stem,'res://modules/'+module+'/'+script)
  for module,scripts in INDEPENDENT.items():
   for script in scripts:run('independent-'+module+'-'+script,ROOT/'tools/qa'/module/(script+'.gd'))
  for mode in ('standalone','host_bloom','host_hub','host_gummy'):
   execute('bloom-window-close-'+mode,[godot,'--headless','--path',project,'--script',ROOT/'tools/qa/bloom_skirmish/window_close.gd','--','--close-mode='+mode],project)
  for test in ('rotation','catalog_input','pagination','host_lifecycle','paged_host'):
   run('independent-host-'+test,ROOT/'tools/qa/four_portal_hub'/(test+'.gd'))
  # Real production extractor, byte checks BEFORE first import, all six modules.
  spec=importlib.util.spec_from_file_location('six_extractor',ROOT/'tools/extract_game.py');extractor=importlib.util.module_from_spec(spec);spec.loader.exec_module(extractor)
  for module in MODULES:
   dest=qa/'fresh'/module
   extractor.extract_game(module,dest,ROOT)
   assert {p.name for p in dest.iterdir()}=={'modules','project.godot'}
   assert {p.name for p in (dest/'modules').iterdir()}=={module}
   project_text=(dest/'project.godot').read_text()
   application_name=lambda text:re.search(r'config/name="([^"]+)"',text).group(1)
   assert application_name(project_text)!=application_name((ROOT/'godot/project.godot').read_text()),'Standalone shares host save identity'
   assert 'res://modules/'+module+'/main.tscn' in project_text
   assert not list(dest.rglob('*.import')) and not list(dest.rglob('.godot'))
   expected=runtime_files(ROOT/'godot/modules'/module)
   assert runtime_files(dest/'modules'/module)==expected,'Fresh source bytes differ: '+module
   (qa/(module+'-fresh-source.json')).write_text(json.dumps(expected,indent=2))
   execute('fresh-'+module+'-import',[godot,'--headless','--path',dest,'--editor','--import','--quit'],dest)
   run('fresh-'+module+'-boot',ROOT/'tools/qa/six_games/standalone_boot.gd',dest)
   for script in AUTHOR[module]:run('fresh-'+module+'-'+Path(script).stem,'res://modules/'+module+'/'+script,dest)
   independent_name='pelican_rebuild' if module=='pelican_pedal' else module
   for script in INDEPENDENT.get(independent_name,[]):run('fresh-independent-'+module+'-'+script,ROOT/'tools/qa'/independent_name/(script+'.gd'),dest)
   if module=='tide_gulp':
    execute('fresh-tide-assets',[sys.executable,ROOT/'tools/qa/tide_gulp/assets.py','--module',dest/'modules/tide_gulp'])
   if module=='bloom_skirmish':
    execute('fresh-bloom-window-close',[godot,'--headless','--path',dest,'--script',ROOT/'tools/qa/bloom_skirmish/window_close.gd','--','--close-mode=standalone'],dest)
   print('FRESH EXTRACTED MODULE PASS '+module,flush=True)
 except Exception as exc:
  failure=str(exc);print('AGGREGATE FAILURE: '+failure,flush=True)
 finally:
  after=source_snapshot();(qa/'source-after.json').write_text(json.dumps(after,indent=2))
  changes=sorted(k for k in set(before)|set(after) if before.get(k)!=after.get(k))
  if changes:failure='Source changed during QA: '+', '.join(changes);print(failure,flush=True)
  result={'passed':failure is None,'error':failure,'qa_root':str(qa),'frozen_source_files':len(before),'source_unchanged':not changes,'completed_steps':len(records),'modules':MODULES,'excluded':['godot/modules/fruit_gummy_snake','tools/qa/fruit_gummy_snake','tool evidence/logs/non-executable Markdown'],'missing_historical_independent':['beach_cleanup','volcano_escape'],'graphical_web_performance':'not assessed'}
  (qa/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
 if failure:sys.exit(1)
 print('SIX-MODULE FROZEN AGGREGATE PASS; graphical/Web/performance remain separate.',flush=True)
if __name__=='__main__':main()
