"""Check reported dark inner-knee creases are overlapping closed surfaces, not open joints."""
import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent

def components(mesh):
 adj=[[] for v in mesh.vertices]
 for e in mesh.edges:
  a,b=e.vertices;adj[a].append(b);adj[b].append(a)
 seen=set();out=[]
 for start in range(len(adj)):
  if start in seen:continue
  todo=[start];seen.add(start);part=[]
  while todo:
   i=todo.pop();part.append(i)
   for j in adj[i]:
    if j not in seen:seen.add(j);todo.append(j)
  out.append(part)
 return out

def contains(tree,p):
 votes=[]
 for direction in [Vector((1,.137,.213)).normalized(),Vector((.219,1,.181)).normalized(),Vector((.131,.193,1)).normalized()]:
  count=0;q=p.copy()
  for _ in range(128):
   hit,n,i,d=tree.ray_cast(q,direction,100)
   if hit is None:break
   count+=1;q=hit+direction*.00001
  votes.append(count%2==1)
 return sum(votes)>=2,votes

report=[]
for species in ['otter','rabbit']:
 bpy.ops.wm.open_mainfile(filepath=str(HERE/species/f'{species}_blue_rigged.blend'));rig=bpy.data.objects['CharacterRig'];rig.animation_data.action=bpy.data.actions['run']
 for frame in [5,14]:
  bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
  for side in ['L','R']:
   point=rig.pose.bones['Shin.'+side].head.copy();entry={'species':species,'frame':frame,'side':side,'joint':list(point),'surfaces':[]}
   for name in ['Leg'+side+'_Skinned','Shin_Skinned' if side=='L' else 'ShinR_Skinned']:
    ob=bpy.data.objects[name];ev=ob.evaluated_get(deps);me=ev.to_mesh();verts=[ev.matrix_world@v.co for v in me.vertices];inside=[]
    for comp in components(me):
     ids=set(comp);faces=[list(p.vertices) for p in me.polygons if p.vertices[0] in ids]
     if len(faces)<10:continue
     tree=BVHTree.FromPolygons(verts,faces,all_triangles=False);yes,votes=contains(tree,point)
     if yes:
      closest=tree.find_nearest(point);inside.append({'component_vertices':len(comp),'joint_inside_votes':votes,'minimum_clearance':closest[3]})
    entry['surfaces'].append({'mesh':name,'closed_components_containing_joint':inside});ev.to_mesh_clear()
   entry['overlap_at_joint']=all(s['closed_components_containing_joint'] for s in entry['surfaces']);report.append(entry)
assert all(e['overlap_at_joint'] for e in report),report
(HERE/'knee_overlap_validation.json').write_text(json.dumps({'status':'PASS','method':'Actual evaluated run mesh component BVH ray parity, three directions, at anatomical knee shared point. Both upper-leg and ankle closed surfaces contain the point: a nonzero overlap, not background-through joint separation.','samples':report},indent=2));print('KNEE_OVERLAP_PASS',json.dumps(report))
