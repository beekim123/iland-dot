#!/usr/bin/env python3
"""Eight-game host admission increment; old seven unchanged, not a full eight aggregate."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,tempfile,importlib.util,sys,time
ROOT=Path(__file__).resolve().parents[3]
ID='monkey_vine'
OLD=('gummy_bomber','bloom_skirmish','tide_gulp','beach_cleanup','volcano_escape','pelican_pedal','fruit_gummy_snake')
AUTHOR=('tests/test_rules_route.gd','tests/test_rules_invariants.gd','tests/test_rules_bonus.gd','art/character/test_rig.gd','ui/tests/presentation_test.gd')
AUDITS=('rules','boundaries','storage','runtime','viewport_route','rig','ui_layout','bonus','human_viewport','biomes')
BAD=re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL',re.M)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def files(root):return {str(p.relative_to(root)):sha(p) for p in sorted(root.rglob('*')) if p.is_file() and not any(x in p.parts for x in ('.godot','__pycache__','evidence')) and p.suffix not in ('.import','.pyc')}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--baseline',required=True);parser.add_argument('--monkey-manifest',required=True);a=parser.parse_args()
 baseline=json.loads(Path(a.baseline).read_text());old={p:h for p,h in baseline.items() if any(p.startswith('godot/modules/'+m+'/') for m in OLD) and not p.endswith(('.import','.pyc'))}
 actual_old={f'godot/modules/{m}/'+p:h for m in OLD for p,h in files(ROOT/'godot/modules'/m).items()};assert old==actual_old,'Previously accepted seven modules differ; cannot reuse acceptance'
 monkey=json.loads(Path(a.monkey_manifest).read_text());expected={p.removeprefix('modules/'+ID+'/'):h for p,h in monkey.items() if p.startswith('modules/'+ID+'/') and not p.endswith('.import')};assert files(ROOT/'godot/modules'/ID)==expected,'Monkey differs from independent final freeze'
 qa=Path(tempfile.mkdtemp(prefix='eight-increment.'));print('EIGHT INCREMENT QA',qa,flush=True)
 before={p:files(ROOT/p) for p in ('godot','tools')};(qa/'source-before.json').write_text(json.dumps(before,indent=2));(qa/'seven-unchanged.json').write_text(json.dumps(old,indent=2));(qa/'monkey-source.json').write_text(json.dumps(expected,indent=2))
 records=[];error=None;g=os.environ.get('GODOT_BIN',str(ROOT.parent/'tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))
 def run(name,args):
  env=dict(os.environ);data=qa/'userdata'/name
  for key,sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
   path=data/sub;path.mkdir(parents=True);env[key]=str(path)
  log=qa/(name+'.log');print('==',name,'==',flush=True);start=time.monotonic()
  with log.open('w') as out:r=subprocess.run([str(x) for x in args],cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=600)
  text=log.read_text();ok=r.returncode==0 and BAD.search(text) is None
  if name.startswith('fresh-standalone-'):
   profiles=list(data.rglob('games/monkey_vine/profile.json'));ok=ok and len(profiles)==1 and json.loads(profiles[0].read_text()).get('schema')==1
  records.append({'name':name,'clean':ok,'code':r.returncode,'seconds':round(time.monotonic()-start,2)});(qa/'steps.json').write_text(json.dumps(records,indent=2));print('\n'.join(text.splitlines()[-3:]),flush=True)
  assert ok,'Failed '+name+': '+str(log)
 def gd(name,script,project=ROOT/'godot',extra=()):run(name,[g,'--headless','--path',project,'--script',script,*extra])
 try:
  run('version',[g,'--version']);assert '4.7.2.stable.official.ed1daf0bf' in (qa/'version.log').read_text()
  run('host-import',[g,'--headless','--path',ROOT/'godot','--editor','--import','--quit'])
  for path in ['tests/check_app.gd','app/tests/test_portal_rotation.gd','hub/tests/test_hub.gd','hub/tests/test_portal_layout.gd','hub/catalog/tests/test_catalog.gd']:gd('host-'+Path(path).stem,'res://'+path)
  run('extractor-policy',[sys.executable,ROOT/'tools/qa/test_extract_game.py'])
  spec=importlib.util.spec_from_file_location('extractor',ROOT/'tools/extract_game.py');ex=importlib.util.module_from_spec(spec);spec.loader.exec_module(ex)
  dest=qa/'standalone';ex.extract_game(ID,dest,ROOT)
  assert {p.name for p in dest.iterdir()}=={'modules','project.godot'} and {p.name for p in (dest/'modules').iterdir()}=={ID}
  assert files(dest/'modules'/ID)==expected
  run('fresh-import',[g,'--headless','--path',dest,'--editor','--import','--quit'])
  # Host integration is exercised by 48 real exits and independent UI routes.
  # Module rules/rig suites execute once on the production-extracted project.
  for label,project in [('fresh',dest)]:
   for test in AUTHOR:gd(label+'-'+Path(test).stem,'res://modules/'+ID+'/'+test,project)
   for test in AUDITS:gd(label+'-independent-'+test,ROOT/'tools/qa/monkey_vine'/('audit_'+test+'.gd'),project)
  gd('fresh-input-consumption',ROOT/'tools/qa/eight_games/test_monkey_input_consumption.gd',dest)
  for mode in ('request_exit','wm_close'):gd('fresh-standalone-'+mode,ROOT/'tools/qa/monkey_vine/audit_standalone.gd',dest,('--',mode))
  tests=list((ROOT/'tools/qa/eight_portal_hub').glob('*.gd'));assert tests,'Missing independent eight-host QA'
  for test in sorted(tests):gd('independent-host-'+test.stem,test)
 except Exception as exc:error=str(exc)
 after={p:files(ROOT/p) for p in ('godot','tools')};(qa/'source-after.json').write_text(json.dumps(after,indent=2))
 if before!=after:error='Source changed during increment'+(': '+error if error else '')
 result={'passed':error is None,'error':error,'scope':'eight-module admission incremental regression, NOT all-eight full aggregate','seven_module_files_unchanged':len(old),'monkey_source_files':len(expected),'steps':len(records),'source_unchanged':before==after,'qa':str(qa),'reused':'unchanged seven modules prior acceptance; no old full-rule rerun','excluded':'bonus_search witness generator; native/Web/performance; broad timing robustness not claimed'}
 (qa/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
 if error:sys.exit(1)
if __name__=='__main__':main()
