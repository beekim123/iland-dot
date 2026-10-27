"""Validate actual exported raccoon GLB bytes without Blender dependencies."""
import json, struct
from pathlib import Path

HERE=Path(__file__).resolve().parent
OUT=HERE.parents[2]/'models'/'animals'/'raccoon'

def load(path):
    raw=path.read_bytes()
    magic,version,size=struct.unpack_from('<III',raw)
    assert (magic,version,size)==(0x46546c67,2,len(raw))
    n,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4E4F534A
    return json.loads(raw[20:20+n]),len(raw)

def validate(team):
    path=OUT/f'raccoon_{team}.glb'
    data,size=load(path);nodes=data['nodes']
    root=next(n for n in nodes if n['name']=='AthleteRoot')
    assert {nodes[i]['name'] for i in root['children']}=={'Body','Head','ArmL','ArmR','LegL','LegR','Weapon'}
    for name,child in [('ArmL','Forearm'),('ArmR','Forearm'),('LegL','Shin'),('LegR','Shin')]:
        n=next(n for n in nodes if n['name']==name)
        assert any(nodes[i]['name'].split('.')[0]==child for i in n['children'])
    weapon=next(n for n in nodes if n['name']=='Weapon')
    muzzle=next(n for n in nodes if n['name']=='Muzzle')
    assert nodes.index(muzzle) in weapon['children']
    assert all(abs(a-b)<1e-6 for a,b in zip(weapon['translation'],(.31,.60923076923,-.29)))
    assert all(abs(a-b)<1e-6 for a,b in zip(muzzle['translation'],(0,.04,-.51)))
    assert all('uri' not in x for x in data.get('buffers',[])+data.get('images',[]))
    assert not data.get('images')
    triangles=sum(data['accessors'][p['indices']]['count']//3 for m in data['meshes'] for p in m['primitives'])
    assert triangles<40000 and len(data['meshes'])<=25
    glass=next(m for m in data['materials'] if 'Translucent' in m['name'])
    assert glass['alphaMode']=='BLEND'
    natural={m['name']:m['pbrMetallicRoughness']['baseColorFactor'] for m in data['materials'] if m['name'].startswith('Raccoon')}
    summary={'team':team,'bytes':size,'mesh_nodes':len(data['meshes']),'triangles':triangles,
             'primitives':sum(len(m['primitives']) for m in data['meshes']),
             'materials':len(data['materials']),'self_contained':True,
             'hierarchy_valid':True,'muzzle_contract_valid':True,'translucent_tank':True}
    return summary,natural

if __name__=='__main__':
    blue,blue_natural=validate('blue');orange,orange_natural=validate('orange')
    assert blue_natural==orange_natural
    result={'blue':blue,'orange':orange,'natural_fur_and_mask_identical_across_teams':True}
    (HERE/'glb_validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
