#!/usr/bin/env python3
"""Fresh isolated audit. Never imports into the shared development project."""
import hashlib,json,os,pathlib,shutil,subprocess,tempfile,time
project=pathlib.Path(__file__).resolve().parents[3]
binary=project.parent/'tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
out=pathlib.Path(tempfile.mkdtemp(prefix='monkey-independent-final-'))
source={}
for path in sorted(project.rglob('*')):
 if path.is_file() and not any(x in path.parts for x in ['.godot','.git','__pycache__','evidence']):
  rel=path.relative_to(project)
  if rel.parts[0] not in ['modules','tools','project.godot']:continue
  dest=out/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,dest)
  source[str(rel)]=hashlib.sha256(path.read_bytes()).hexdigest()
(out/'SOURCE_SHA256.json').write_text(json.dumps(source,indent=2))
base=os.environ.copy();base.update(XDG_CACHE_HOME=str(out/'cache'),XDG_CONFIG_HOME=str(out/'config'))
results=[]
def run(name,args):
 env=base.copy();env['XDG_DATA_HOME']=str(out/('userdata-'+name))
 started=time.time()
 p=subprocess.run([str(binary),'--headless','--path',str(out),*args],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 log=p.stdout.decode(errors='replace');(out/(name+'.log')).write_text(log)
 errors=[s for s in log.splitlines() if 'SCRIPT ERROR:' in s or s.startswith('ERROR:') or s.startswith('FAIL ')]
 if name.startswith('standalone_'):
  profiles=list((out/('userdata-'+name)).rglob('games/monkey_vine/profile.json'))
  if len(profiles)!=1:errors.append('standalone did not create exactly one namespaced save')
  elif json.loads(profiles[0].read_text()).get('schema')!=1:errors.append('standalone saved unexpected schema')
 result=dict(name=name,exit_code=p.returncode,seconds=round(time.time()-started,2),errors=errors,pass_=p.returncode==0 and not errors)
 results.append(result);print(json.dumps(result),flush=True)
run('fresh_import',['--editor','--import'])
for name in ['rules','boundaries','storage','runtime','viewport_route','rig','ui_layout','bonus','human_viewport','biomes']:
 run(name,['--script',f'res://tools/qa/monkey_vine/audit_{name}.gd'])
for mode in ['request_exit','wm_close']:
 run('standalone_'+mode,['--script','res://tools/qa/monkey_vine/audit_standalone.gd','--',mode])
(out/'RESULT.json').write_text(json.dumps({'results':results,'source_files':len(source),'pass':all(r['pass_'] for r in results)},indent=2))
print('EVIDENCE='+str(out))
raise SystemExit(0 if all(r['pass_'] for r in results) else 1)
