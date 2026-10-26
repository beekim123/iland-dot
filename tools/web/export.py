#!/usr/bin/env python3
"""Reproducible staged Godot 4.7.2 Web export; desktop settings are untouched."""
import hashlib,json,os,shutil,subprocess,tempfile,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BIN=Path(os.environ['GODOT_BIN']).resolve()
TEMPLATE=Path(os.environ['GODOT_WEB_TEMPLATE']).resolve()
EXPECTED='33a52b6d9b1ce32d3683caaa3ea4b997a3f84c76a92a2e4a98a115b46da55d887854c9ef49bbf3b45b9629938110837978132c3a8cda26d278eb020bd6a9b8ea'
def digest(p,algo='sha256'): return hashlib.new(algo,p.read_bytes()).hexdigest()
assert digest(TEMPLATE,'sha512')==EXPECTED,'Unverified template'
DEST=ROOT/'build/web'; DEST.mkdir(parents=True,exist_ok=True)
NAME='sunny-shell-island-web'; PACKAGE=DEST/NAME
stage=Path(tempfile.mkdtemp(prefix='staging-',dir=DEST)); project=stage/'project'
env=dict(os.environ,XDG_CONFIG_HOME=str(stage/'config'),XDG_DATA_HOME=str(stage/'data'),XDG_CACHE_HOME=str(stage/'cache'))
logs=[]
def run(args):
 p=subprocess.run([str(BIN),*args],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
 logs.append(p.stdout); (DEST/'export.log').write_text('\n'.join(logs))
 if p.returncode or any(e in p.stdout for e in ['SCRIPT ERROR:','\nERROR:','Parse Error:']): raise RuntimeError(p.stdout[-6000:])
 return p.stdout.strip()
try:
 version=run(['--headless','--version']); assert version.startswith('4.7.2.')
 template_dir=Path(env['XDG_DATA_HOME'])/'godot/export_templates/4.7.2.stable'; template_dir.mkdir(parents=True)
 shutil.copy(TEMPLATE,template_dir/'web_nothreads_release.zip')
 shutil.copy(TEMPLATE,template_dir/'web_nothreads_debug.zip') # Release-only build; satisfy editor preset availability checks.
 shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot'))
 sources=[{'path':str(p.relative_to(project)),'sha256':digest(p)} for p in sorted(project.rglob('*')) if p.is_file()]
 cfg=project/'project.godot'; cfg.write_text(cfg.read_text().replace('[rendering]','[rendering]\ntextures/vram_compression/import_etc2_astc=true').replace('[audio]','[audio]\ngeneral/default_playback_type.web=0'))
 shutil.copy(ROOT/'tools/web/shell.html',project/'web_shell.html')
 (project/'export_presets.cfg').write_text(f'''[preset.0]
name="Web"
platform="Web"
runnable=true
advanced_options=false
export_path="../web/index.html"
export_filter="all_resources"
include_filter="*.json,*.txt,*.md"
exclude_filter="tests/*,**/tools/*,**/*.py,web_shell.html"
script_export_mode=2
[preset.0.options]
custom_template/debug="{TEMPLATE}"
custom_template/release="{TEMPLATE}"
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/export_icon=false
html/custom_html_shell="res://web_shell.html"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=false
''')
 run(['--headless','--path',str(project),'--editor','--quit'])
 candidate=stage/NAME; candidate.mkdir()
 run(['--headless','--path',str(project),'--export-release','Web',str(candidate/'index.html')])
 for name in ['README.md','serve.py','start.command']: shutil.copy(ROOT/'tools/web'/name,candidate/name)
 (candidate/'start.command').chmod(0o755)
 licenses=candidate/'licenses'; licenses.mkdir()
 shutil.copy(ROOT/'tools/web/GODOT-LICENSE.txt',licenses/'GODOT-LICENSE.txt')
 for p in (ROOT/'godot').rglob('*'):
  if p.is_file() and p.name in ['OFL.txt','SOURCE.txt']:
   dst=licenses/p.relative_to(ROOT/'godot'); dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy(p,dst)
 (candidate/'source-manifest.json').write_text(json.dumps(sources,indent=2)+'\n')
 manifest={'engine':version,'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sourceNotes':'island audio enumeration fix included; source-manifest hashes authoritative','templateSha512':EXPECTED,'threads':False,'webPlaybackType':'Stream','browserGameplayVerified':False,'files':[{'path':str(p.relative_to(candidate)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(candidate.rglob('*')) if p.is_file()]}
 (candidate/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 if PACKAGE.exists(): shutil.rmtree(PACKAGE)
 shutil.move(candidate,PACKAGE)
 archive=DEST/(NAME+'.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in sorted(PACKAGE.rglob('*')):
   if p.is_file(): z.write(p,NAME+'/'+str(p.relative_to(PACKAGE)))
 with zipfile.ZipFile(archive) as z: assert z.testzip() is None
 result={'archive':str(archive),'bytes':archive.stat().st_size,'sha256':digest(archive),'stagingProject':str(project),'browserGameplayVerified':False}
 (DEST/'export-manifest.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result,indent=2))
except Exception:
 print('Staging retained:',stage); raise
