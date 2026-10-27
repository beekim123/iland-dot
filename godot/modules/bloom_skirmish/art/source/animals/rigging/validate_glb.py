"""Independent binary inspection of embedded glTF skin/animation payloads."""
import json,struct,hashlib,sys,math
from pathlib import Path
HERE=Path(__file__).resolve().parent;ART=HERE.parents[2]
COMP={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
SIZE={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def inspect(path):
 data=path.read_bytes();assert data[:4]==b'glTF';jl=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+jl]);offset=20+jl;bl,bt=struct.unpack_from('<II',data,offset);binary=data[offset+8:offset+8+bl]
 def array(idx):
  a=doc['accessors'][idx];v=doc['bufferViews'][a['bufferView']];fmt,size=COMP[a['componentType']];n=SIZE[a['type']];stride=v.get('byteStride',n*size);off=v.get('byteOffset',0)+a.get('byteOffset',0)
  return [struct.unpack_from('<'+fmt*n,binary,off+i*stride) for i in range(a['count'])]
 skins=doc.get('skins',[]);assert len(skins)==1;jn=set(skins[0]['joints']);assert len(jn)>=23
 weighted=multi=0;deform_joints=set();maxsum=0
 for node in doc['nodes']:
  if 'skin' not in node:continue
  for prim in doc['meshes'][node['mesh']]['primitives']:
   a=prim['attributes'];assert 'JOINTS_0'in a and 'WEIGHTS_0'in a
   ws=array(a['WEIGHTS_0']);js=array(a['JOINTS_0']);weighted+=len(ws)
   for w,j in zip(ws,js):
    assert all(math.isfinite(v) and v>=0 for v in w);maxsum=max(maxsum,abs(sum(w)-1));multi+=sum(v>.01 for v in w)>1
    deform_joints.update(jj for ww,jj in zip(w,j) if ww>.01)
 anims={}
 for anim in doc.get('animations',[]):
  varying=0;targeted=set();dt=0;loops=[]
  for c in anim['channels']:
   s=anim['samplers'][c['sampler']];ts=array(s['input']);vs=array(s['output']);targeted.add(c['target']['node']);dt=max(dt,ts[-1][0]);varying+=any(any(abs(a-b)>1e-6 for a,b in zip(vs[0],row)) for row in vs[1:]);loops.append(max(abs(a-b) for a,b in zip(vs[0],vs[-1])))
  assert targeted<=jn and varying>0
  anims[anim['name']]={'duration':dt,'joint_channels':len(anim['channels']),'varying_joint_channels':varying,'max_endpoint_difference':max(loops)}
 required={'idle','run','spray','dash','hit','celebration','pod','respawn','defeat'};assert required<=set(anims)
 for n in ['idle','run','spray','celebration']:assert anims[n]['max_endpoint_difference']<1e-4,(n,anims[n])
 assert multi>100 and maxsum<1e-5
 assert all('uri' not in b for b in doc.get('buffers',[]))
 report={'file':str(path.relative_to(ART)),'sha256':hashlib.sha256(data).hexdigest(),'status':'PASS','bytes':len(data),'joint_count':len(jn),'weighted_vertices':weighted,'multi_bone_vertices_over_1_percent':multi,'influential_joint_count':len(deform_joints),'max_weight_sum_error':maxsum,'clips':anims,'embedded_only':True}
 return report
if __name__=='__main__':
 paths=sorted((ART/'models'/'animals'/'rigged').glob('*/*_rigged.glb'))
 reports=[inspect(p) for p in paths];(HERE/'glb_validation.json').write_text(json.dumps({'status':'PASS','assets':reports},indent=2));print(json.dumps(reports,indent=2))
