"""Independent GLB binary skin/animation check (not visual quality acceptance)."""
import json, pathlib, struct
root=pathlib.Path(__file__).resolve().parents[3]
for name in ('pelican_rider','first_person_rig'):
 p=root/'godot/modules/pelican_pedal/art/models'/f'{name}.glb'
 b=p.read_bytes(); n,_=struct.unpack_from('<II',b,12); j=json.loads(b[20:20+n]); binary=b[28+n:]
 def accessor(i):
  a=j['accessors'][i];v=j['bufferViews'][a['bufferView']]
  types={5126:'f',5123:'H',5121:'B'};sizes={'SCALAR':1,'VEC3':3,'VEC4':4}
  fmt='<'+types[a['componentType']]*sizes[a['type']];sz=struct.calcsize(fmt)
  offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',sz)
  return [struct.unpack_from(fmt,binary,offset+k*stride) for k in range(a['count'])]
 assert len(j['skins'])==1 and len(j['skins'][0]['joints'])>=12
 mixed=0;total=0;influenced=set()
 for mesh in j['meshes']:
  for pr in mesh['primitives']:
   attr=pr['attributes'];weights=accessor(attr['WEIGHTS_0']);joints=accessor(attr['JOINTS_0'])
   for w,ids in zip(weights,joints):
    total+=1;assert abs(sum(w)-1)<.002
    mixed+=sum(x>.001 for x in w)>1
    influenced.update(i for i,x in zip(ids,w) if x>.001)
 assert mixed>10 and len(influenced)>8
 changes={}
 for a in j['animations']:
  changed=0
  for s in a['samplers']:
   values=accessor(s['output']);changed+=any(v!=values[0] for v in values)
  changes[a['name']]=changed
 assert set(changes)>={'idle','pedal','steer_left','steer_right','brake'} and all(v>0 for v in changes.values())
 print(f'{name}: {total} skinned vertices, {mixed} blended, {len(influenced)} influencing bones, changing animation samplers {changes}; PASS')
