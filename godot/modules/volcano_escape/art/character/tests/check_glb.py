import json,struct,pathlib,math
root=pathlib.Path(__file__).resolve().parents[1];b=(root/'otter.glb').read_bytes();size=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+size]);raw=b[28+size:]
def acc(i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];fmt={5126:'f',5123:'H',5121:'B',5125:'I'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];step=v.get('byteStride',struct.calcsize(fmt)*n);off=v.get('byteOffset',0)+a.get('byteOffset',0);return [struct.unpack_from('<'+fmt*n,raw,off+j*step) for j in range(a['count'])]
tri=weighted=blended=zero=wrong=0;lo=[1e9]*3;hi=[-1e9]*3
assert len(d['skins'])==1
bones=len(d['skins'][0]['joints']);assert bones==14
ibm=acc(d['skins'][0]['inverseBindMatrices']);assert len(ibm)==bones and all(math.isfinite(v) for matrix in ibm for v in matrix)
parents={child:i for i,node in enumerate(d['nodes']) for child in node.get('children',[])}
for joint in d['skins'][0]['joints']:
 if d['nodes'][joint]['name']!='root':assert parents[joint] in d['skins'][0]['joints']
for animation in d['animations']:
 for sampler in animation['samplers']:
  assert all(math.isfinite(v) for frame in acc(sampler['output']) for v in frame)
for mesh in d['meshes']:
 assert len(mesh['primitives'])<=8
 for p in mesh['primitives']:
  a=p['attributes'];ps=acc(a['POSITION']);ns=acc(a['NORMAL']);ids=[x[0] for x in acc(p['indices'])] if 'indices' in p else list(range(len(ps)))
  for xyz in ps:
   for k,x in enumerate(xyz):assert math.isfinite(x);lo[k]=min(lo[k],x);hi[k]=max(hi[k],x)
  for w,js in zip(acc(a['WEIGHTS_0']),acc(a['JOINTS_0'])):
   assert all(math.isfinite(x) and x>=0 for x in w) and abs(sum(w)-1)<.001
   assert all(0<=j<bones for j in js);weighted+=1;blended+=sum(x>.001 for x in w)>1
  for i in range(0,len(ids),3):
   ix=ids[i:i+3];u=[ps[ix[1]][k]-ps[ix[0]][k] for k in range(3)];v=[ps[ix[2]][k]-ps[ix[0]][k] for k in range(3)];cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];area=sum(x*x for x in cross);zero+=area<1e-20
   normal=[sum(ns[j][k] for j in ix) for k in range(3)];wrong+=sum(x*y for x,y in zip(cross,normal))< -1e-10;tri+=1
assert tri<=6000 and zero==0 and wrong==0,(tri,zero,wrong)
assert blended>350
clips={a['name'] for a in d['animations']};assert {'idle','walk','shelter','interact','hurt','victory'}<=clips,clips
report=dict(triangles=tri,surfaces=len(d['meshes'][0]['primitives']),bones=bones,weighted_vertices=weighted,blended_vertices=blended,zero_area=zero,wrong_winding=wrong,bounds=[lo,hi],animations=sorted(clips))
print(json.dumps(report,indent=2));(root/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
