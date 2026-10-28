"""Read exported GLB buffers and audit actual indices, positions and surfaces."""
import json,struct,math
from pathlib import Path
base=Path(__file__).resolve().parent
results={}
for path in [base/'cart_model.glb',*sorted((base.parent/'trash').glob('*.glb'))]:
 raw=path.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
 assert magic==0x46546c67 and version==2 and length==len(raw)
 n,typ=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+n]);off=20+n
 bn,bt=struct.unpack_from('<II',raw,off);blob=raw[off+8:off+8+bn]
 def values(index):
  a=doc['accessors'][index];b=doc['bufferViews'][a['bufferView']];offset=b.get('byteOffset',0)+a.get('byteOffset',0)
  fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']];components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
  size=struct.calcsize('<'+fmt*components);stride=b.get('byteStride',size)
  return [struct.unpack_from('<'+fmt*components,blob,offset+i*stride) for i in range(a['count'])]
 triangles=surfaces=0
 for mesh in doc['meshes']:
  for primitive in mesh['primitives']:
   surfaces+=1;pos=values(primitive['attributes']['POSITION']);ind=[i[0] for i in values(primitive['indices'])]
   assert len(ind)%3==0 and min(ind)>=0 and max(ind)<len(pos)
   assert all(math.isfinite(x) for p in pos for x in p)
   assert 'COLOR_0' in primitive['attributes']
   assert all(len(set(ind[i:i+3]))==3 for i in range(0,len(ind),3))
   for i in range(0,len(ind),3):
    a,b,c=[pos[j] for j in ind[i:i+3]]
    u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
    cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
    assert sum(x*x for x in cross)>1e-18,(path.name,i,'zero-area triangle')
   triangles+=len(ind)//3
 results[path.name]={'triangles':triangles,'surfaces':surfaces,'indices_valid':True,'finite_positions':True,'vertex_palette':True,'zero_area_triangles':0}
(base/'export_audit.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
