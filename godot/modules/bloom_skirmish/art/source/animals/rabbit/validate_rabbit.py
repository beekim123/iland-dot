"""Independent GLB structure/material/coordinate validation. Python 3, no deps."""
import json, math, struct, hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
OUT=HERE.parents[2]/'models'/'animals'/'rabbit'
EXPECTED={'Body','Head','ArmL','ArmR','LegL','LegR','Weapon'}

def near(a,b,tol=1e-6):return all(abs(x-y)<tol for x,y in zip(a,b))
def rx(p,a):
    x,y,z=p;return x,y*math.cos(a)-z*math.sin(a),y*math.sin(a)+z*math.cos(a)
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def nodechild(ns,p,prefix):return next(ns[i] for i in p.get('children',[]) if ns[i].get('name','').startswith(prefix))
results=[];allmats=[]
for team in ['blue','orange']:
    p=OUT/f'rabbit_{team}.glb';b=p.read_bytes()
    assert b[:4]==b'glTF';assert struct.unpack_from('<I',b,4)[0]==2
    assert struct.unpack_from('<I',b,8)[0]==len(b)
    n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);ns=j['nodes']
    root=next(x for x in ns if x.get('name')=='AthleteRoot')
    direct={ns[i]['name'] for i in root['children']};assert direct==EXPECTED,direct
    for name in ['ArmL','ArmR']:
        arm=nodechild(ns,root,name);fore=nodechild(ns,arm,'Forearm')
        assert near(arm['translation'],((-.257 if name=='ArmL' else .257),.875,-.005))
        if name=='ArmR':
            grip=nodechild(ns,fore,'Grip');assert near(grip['translation'],(0,-.069,-.015))
            grip_global=add(arm['translation'],rx(add(fore['translation'],rx(grip['translation'],.7)),.5))
            assert near(grip_global,(.285,.7615609181420063,-.16260254607757396))
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
    # Independently inspect exported vertex buffers and world-space bounds.
    bin_len,bin_kind=struct.unpack_from('<II',b,20+n)
    assert bin_kind==0x004e4942
    raw=b[28+n:28+n+bin_len]
    translations={}
    def walk(i,parent):
        node=ns[i];assert 'matrix' not in node and 'rotation' not in node
        translations[i]=add(parent,node.get('translation',(0,0,0)))
        for child in node.get('children',[]):walk(child,translations[i])
    walk(ns.index(root),(0,0,0))
    lo=[float('inf')]*3;hi=[float('-inf')]*3;geo=hashlib.sha256()
    for i,node in enumerate(ns):
        if 'mesh' not in node:continue
        for prim in j['meshes'][node['mesh']]['primitives']:
            acc=j['accessors'][prim['attributes']['POSITION']]
            assert acc['type']=='VEC3' and acc['componentType']==5126
            for axis in range(3):
                lo[axis]=min(lo[axis],acc['min'][axis]+translations[i][axis])
                hi[axis]=max(hi[axis],acc['max'][axis]+translations[i][axis])
            view=j['bufferViews'][acc['bufferView']]
            start=view.get('byteOffset',0)+acc.get('byteOffset',0);stride=view.get('byteStride',12)
            for k in range(acc['count']):geo.update(raw[start+k*stride:start+k*stride+12])
    assert abs(lo[1])<1e-6,(lo,hi)
    assert 1.90<hi[1]<1.95,(lo,hi)
    r={'bounds_min_godot':lo,'bounds_max_godot':hi,'geometry_sha256':geo.hexdigest(),'glb_sha256':hashlib.sha256(b).hexdigest(),'file':str(p.relative_to(HERE.parents[2])),'bytes':len(b),'mesh_count':len(j['meshes']),'triangle_count':triangles,'root_children':sorted(direct),'right_grip_idle':grip_global,'physical_muzzle':physical_muzzle,'embedded_only':True,'hierarchy_pass':True}
    results.append(r)
assert results[0]['geometry_sha256']==results[1]['geometry_sha256']
changed=[]
for name in allmats[0]:
    if allmats[0][name]!=allmats[1][name]:changed.append(name)
assert set(changed)=={'Cobalt or orange team accent','Visible team liquid'},changed
report={'status':'PASS','teams':results,'team_variant_changed_materials':changed,'natural_fur_identical_across_teams':True,'geometry_identical_across_teams':True,'grip_check':'The right front paw center exactly matches the animal-specific transverse rear/top U grip in common idle pose (+0.50 arm X, +0.70 forearm X). No human hanging pistol handle; natural high short forepaws retained.','external_assets':False}
(HERE/'validation_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
