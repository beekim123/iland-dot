#!/usr/bin/env python3
"""Seven-game admission increment, never an all-seven full aggregate claim."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,tempfile,importlib.util,sys,time
ROOT=Path(__file__).resolve().parents[3]
ID='fruit_gummy_snake'
OLD=('gummy_bomber','bloom_skirmish','tide_gulp','beach_cleanup','volcano_escape','pelican_pedal')
AUTHOR=('test_xyz','test_camera','test_storage','test_runtime','test_interface','test_detach')
WATER=('intro','kinematics','replay_growth','collision_fixtures','storage','input_lifecycle','standalone_exit','preview','intro_target')
BAD=re.compile(r'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use|^FAIL',re.M)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def files(root):return {str(p.relative_to(root)):sha(p) for p in sorted(root.rglob('*')) if p.is_file() and not any(x in p.parts for x in ('.godot','__pycache__','evidence')) and p.suffix not in ('.import','.pyc')}
def verified_reuse():
 evidence=ROOT/'tools/qa/fruit_gummy_snake/underwater/evidence/intro_final'
 def manifest(path):
  rows={}
  for line in path.read_text().splitlines():
   digest,name=line.split(None,1);rows[name.strip().removeprefix('./')]=digest
  return rows
 current=files(ROOT/'godot/modules'/ID)
 pre=manifest(evidence/'runtime/source_before.sha256');post=manifest(evidence/'runtime/source_post_documentation.sha256')
 assert current==post,'Current complete water module differs from final reviewed source manifest; reuse forbidden'
 changes=[p for p in set(pre)|set(post) if pre.get(p)!=post.get(p)]
 assert changes==['QA.md'],'Only explicitly documented QA.md change may differ from tested snapshot'
 pure=manifest(evidence/'sim/source_before.sha256')
 assert pure==manifest(evidence/'sim/source_after.sha256')
 assert all(current.get(p)==h for p,h in pure.items()),'Pure simulation bytes differ; reuse forbidden'
 reused={}
 for name,relative,marker in [('navigation','sim/navigation.txt','9372432 checks; 0 failures'),('long_camera','runtime/long_camera.txt','312512 checks; 0 failures')]:
  path=evidence/relative;text=path.read_text();assert marker in text and BAD.search(text) is None
  reused[name]={'log':str(path),'log_sha256':sha(path),'reason':'Unchanged exact module bytes; prior final independent acceptance, not rerun this increment'}
 return {'tests':reused,'module_files':current,'tested_manifest':str(evidence/'runtime/source_before.sha256'),'accepted_documentation_only_change':changes,'current_manifest':str(evidence/'runtime/source_post_documentation.sha256')}
def main():
 a=argparse.ArgumentParser();a.add_argument('--baseline',required=True);args=a.parse_args()
 baseline=json.loads(Path(args.baseline).read_text());qa=Path(tempfile.mkdtemp(prefix='seven-increment.'));print('SEVEN INCREMENT QA',qa,flush=True)
 old={p:h for p,h in baseline.items() if any(p.startswith('godot/modules/'+m+'/') for m in OLD)}
 assert all((ROOT/p).is_file() and sha(ROOT/p)==h for p,h in old.items()),'Previously accepted module changed'
 before={str(p):files(ROOT/p) for p in ('godot','tools')};(qa/'source-before.json').write_text(json.dumps(before,indent=2));(qa/'six-module-baseline.json').write_text(json.dumps(old,indent=2))
 reuse=verified_reuse();(qa/'reused-evidence.json').write_text(json.dumps(reuse,indent=2))
 records=[];error=None;g=os.environ.get('GODOT_BIN',str(ROOT.parent/'tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'))
 def run(name,argv):
  env=dict(os.environ);data=qa/'userdata'/name
  for key,sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
   path=data/sub;path.mkdir(parents=True);env[key]=str(path)
  log=qa/(name+'.log');print('==',name,'==',flush=True);start=time.monotonic()
  with log.open('w') as out:r=subprocess.run([str(x) for x in argv],cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=600)
  text=log.read_text();ok=r.returncode==0 and BAD.search(text) is None
  records.append({'name':name,'clean':ok,'code':r.returncode,'seconds':round(time.monotonic()-start,2)});(qa/'steps.json').write_text(json.dumps(records,indent=2));print('\n'.join(text.splitlines()[-3:]),flush=True)
  assert ok,'Failed '+name+': '+str(log)
 def gd(name,script,project=ROOT/'godot',extra=()):run(name,[g,'--headless','--path',project,'--script',script,*extra])
 try:
  run('version',[g,'--version']);assert '4.7.2.stable.official.ed1daf0bf' in (qa/'version.log').read_text()
  run('host-import',[g,'--headless','--path',ROOT/'godot','--editor','--import','--quit'])
  for path in ['tests/check_app.gd','app/tests/test_portal_rotation.gd','hub/tests/test_hub.gd','hub/tests/test_portal_layout.gd','hub/catalog/tests/test_catalog.gd']:gd('host-'+Path(path).stem,'res://'+path)
  run('extractor-policy',[sys.executable,ROOT/'tools/qa/test_extract_game.py'])
  spec=importlib.util.spec_from_file_location('extractor',ROOT/'tools/extract_game.py');extract=importlib.util.module_from_spec(spec);spec.loader.exec_module(extract)
  dest=qa/'standalone';extract.extract_game(ID,dest,ROOT)
  assert {p.name for p in dest.iterdir()}=={'modules','project.godot'} and {p.name for p in (dest/'modules').iterdir()}=={ID}
  assert files(dest/'modules'/ID)==files(ROOT/'godot/modules'/ID)
  run('fresh-import',[g,'--headless','--path',dest,'--editor','--import','--quit'])
  for label,project in [('host',ROOT/'godot'),('fresh',dest)]:
   run(label+'-assets',[sys.executable,project/'modules'/ID/'tests/check_assets.py'])
   for test in AUTHOR:gd(label+'-'+test,'res://modules/'+ID+'/tests/'+test+'.gd',project)
   for test in WATER:gd(label+'-independent-'+test,ROOT/'tools/qa/fruit_gummy_snake/underwater'/(test+'.gd'),project,('--','--snake-preview') if test=='preview' else ())
  # Independent host author owns its files; fail rather than omit missing suite.
  tests=list((ROOT/'tools/qa/seven_portal_hub').glob('*.gd'));assert tests,'Missing independent seven-host QA'
  for test in sorted(tests):gd('independent-host-'+test.stem,test)
 except Exception as exc:error=str(exc)
 after={str(p):files(ROOT/p) for p in ('godot','tools')};(qa/'source-after.json').write_text(json.dumps(after,indent=2))
 if before!=after:error='Source changed during increment'+(': '+error if error else '')
 result={'passed':error is None,'error':error,'scope':'seven-module admission incremental regression, NOT all-seven full aggregate','six_module_files_unchanged':len(old),'steps':len(records),'source_unchanged':before==after,'qa':str(qa),'reused_evidence':str(qa/'reused-evidence.json'),'excluded':'old planar Snake QA; repeated old six full rules; repeated exact-hash final navigation/camera; native/Web/performance'}
 (qa/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
 if error:sys.exit(1)
if __name__=='__main__':main()
