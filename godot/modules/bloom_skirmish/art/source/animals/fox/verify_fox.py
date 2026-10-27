"""Static embedded GLB and animation-interface checks; no Blender dependency."""
from pathlib import Path
import json, struct, hashlib
HERE=Path(__file__).resolve().parent
MODEL=HERE.parents[2]/'models'/'animals'/'fox'

def read(path):
    raw=path.read_bytes();magic,version,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and length==len(raw)
    n,t=struct.unpack_from('<II',raw,12);assert t==0x4e4f534a
    g=json.loads(raw[20:20+n]);n2,t2=struct.unpack_from('<II',raw,20+n);assert t2==0x004e4942
    return g,raw[28+n:28+n+n2]

def validate(team):
    path=MODEL/f'fox_{team}.glb';g,buf=read(path);nodes=g['nodes'];byname={n['name']:i for i,n in enumerate(nodes)}
    root=nodes[byname['AthleteRoot']]
    required={'Body','Head','ArmL','ArmR','LegL','LegR','Weapon'}
    assert {nodes[i]['name'] for i in root['children']}==required
    for part,child in [('ArmL','Forearm'),('ArmR','Forearm'),('LegL','Shin'),('LegR','Shin')]:
        assert any(nodes[i]['name'].startswith(child) for i in nodes[byname[part]]['children'])
    weapon=nodes[byname['Weapon']];muzzle=nodes[byname['Muzzle']]
    assert byname['Muzzle'] in weapon['children']
    for a,b in zip(weapon['translation'],[.31,.60923076923,-.29]):assert abs(a-b)<1e-6
    for a,b in zip(muzzle['translation'],[0,.04,-.51]):assert abs(a-b)<1e-6
    assert all('uri' not in b for b in g['buffers']) and not g.get('images')
    tris=sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives'])
    assert tris<40000 and len(g['meshes'])<=25
    translations={}
    def walk(i,offset):
        nd=nodes[i];assert 'rotation' not in nd and 'matrix' not in nd
        t=tuple(a+b for a,b in zip(offset,nd.get('translation',[0,0,0])));translations[i]=t
        for c in nd.get('children',[]):walk(c,t)
    walk(byname['AthleteRoot'],[0,0,0]);lo=[1e6]*3;hi=[-1e6]*3;geometry=hashlib.sha256()
    for i,node in enumerate(nodes):
        if 'mesh' not in node:continue
        for primitive in g['meshes'][node['mesh']]['primitives']:
            acc=g['accessors'][primitive['attributes']['POSITION']]
            for j in range(3):lo[j]=min(lo[j],acc['min'][j]+translations[i][j]);hi[j]=max(hi[j],acc['max'][j]+translations[i][j])
            view=g['bufferViews'][acc['bufferView']];start=view.get('byteOffset',0)+acc.get('byteOffset',0);stride=view.get('byteStride',12)
            for k in range(acc['count']):geometry.update(buf[start+k*stride:start+k*stride+12])
    assert abs(lo[1])<1e-6,(lo,hi)
    assert 1.4<hi[1]<=1.65,(lo,hi)
    return {'team':team,'mesh_count':len(g['meshes']),'triangles':tris,'material_count':len(g['materials']),'bounds_min':lo,'bounds_max':hi,'all_buffers_embedded':True,'external_images':0,'required_hierarchy':'PASS','fixed_muzzle':'PASS','geometry_sha256':geometry.hexdigest(),'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
if __name__=='__main__':
    reports=[validate(t) for t in ['blue','orange']]
    assert reports[0]['geometry_sha256']==reports[1]['geometry_sha256'],'Team variants changed animal geometry'
    result={'checks':'PASS','same_animal_geometry_across_teams':True,'variants':reports}
    (HERE/'validation.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
