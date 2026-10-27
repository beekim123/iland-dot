"""Independent GLB structure/material/coordinate validation. Python 3, no deps."""
import json, math, struct
from pathlib import Path
HERE=Path(__file__).resolve().parent
OUT=HERE.parents[2]/'models'/'animals'/'otter'
EXPECTED={'Body','Head','ArmL','ArmR','LegL','LegR','Weapon'}

def near(a,b,tol=1e-6):return all(abs(x-y)<tol for x,y in zip(a,b))
def rx(p,a):
    x,y,z=p;return x,y*math.cos(a)-z*math.sin(a),y*math.sin(a)+z*math.cos(a)
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def nodechild(ns,p,prefix):return next(ns[i] for i in p.get('children',[]) if ns[i].get('name','').startswith(prefix))
results=[];allmats=[]
for team in ['blue','orange']:
    p=OUT/f'otter_{team}.glb';b=p.read_bytes()
    assert b[:4]==b'glTF';assert struct.unpack_from('<I',b,4)[0]==2
    assert struct.unpack_from('<I',b,8)[0]==len(b)
    n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);ns=j['nodes']
    root=next(x for x in ns if x.get('name')=='AthleteRoot')
    direct={ns[i]['name'] for i in root['children']};assert direct==EXPECTED,direct
    for name in ['ArmL','ArmR']:
        arm=nodechild(ns,root,name);fore=nodechild(ns,arm,'Forearm')
        assert near(arm['translation'],((-.257 if name=='ArmL' else .257),.862,-.005))
        if name=='ArmR':
            grip=nodechild(ns,fore,'Grip');assert near(grip['translation'],(0,-.069,-.015))
            grip_global=add(arm['translation'],rx(add(fore['translation'],rx(grip['translation'],.7)),.5))
            assert near(grip_global,(.285,.7485609181420063,-.16260254607757396))
    for name in ['LegL','LegR']:nodechild(ns,nodechild(ns,root,name),'Shin')
    weapon=nodechild(ns,root,'Weapon');muzzle=nodechild(ns,weapon,'Muzzle')
    weapon_grip=nodechild(ns,weapon,'Grip');assert near(add(weapon['translation'],weapon_grip['translation']),grip_global)
    assert near(weapon['translation'],(.31,.60923076923,-.29));assert near(muzzle['translation'],(0,.04,-.51))
    physical_muzzle=add((0,.04,0),tuple(x*1.3 for x in add(weapon['translation'],muzzle['translation'])))
    assert near(physical_muzzle,(.403,.884,-1.04))
    triangles=sum(j['accessors'][prim['indices']]['count']//3 for m in j['meshes'] for prim in m['primitives'])
    assert len(j['meshes'])==11;assert triangles<40000
    assert len(j['buffers'])==1 and 'uri' not in j['buffers'][0]
    assert not j.get('images') and not j.get('textures')
    materials={m['name']:m['pbrMetallicRoughness']['baseColorFactor'] for m in j['materials']};allmats.append(materials)
    r={'file':str(p.relative_to(HERE.parents[2])),'bytes':len(b),'mesh_count':len(j['meshes']),'triangle_count':triangles,'root_children':sorted(direct),'right_grip_idle':grip_global,'physical_muzzle':physical_muzzle,'embedded_only':True,'hierarchy_pass':True}
    results.append(r)
changed=[]
for name in allmats[0]:
    if allmats[0][name]!=allmats[1][name]:changed.append(name)
assert set(changed)=={'Cobalt or orange team accent','Visible team liquid'},changed
report={'status':'PASS','teams':results,'team_variant_changed_materials':changed,'natural_fur_identical_across_teams':True,'grip_check':'The right front paw center exactly matches the animal-specific transverse rear/top U grip in common idle pose (+0.50 arm X, +0.70 forearm X). No human hanging pistol handle; natural high short forepaws retained.','external_assets':False}
(HERE/'validation_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
