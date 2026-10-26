import bpy,os,json,sys,math
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__));variant='tern' if '--tern' in sys.argv else 'gull';OUT=os.path.join(OUT,variant)
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'bird_rigged.blend'))
a=next(o for o in bpy.data.objects if o.type=='ARMATURE');a.location=(0,0,0)
mesh=[o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
report={'variant':variant,'forward_godot':'+Z','up_godot':'+Y','actions':{}}
for name in ['Fly','Glide']:
 a.animation_data.action=bpy.data.actions[name];points=[];endpoints=[]
 for f in range(1,98,2):
  bpy.context.scene.frame_set(f);dg=bpy.context.evaluated_depsgraph_get();pp=[]
  for o in mesh:
   e=o.evaluated_get(dg);me=e.to_mesh();pp.extend(e.matrix_world@v.co for v in me.vertices);e.to_mesh_clear()
  points.extend(pp)
  if f in [1,97]:endpoints.append(pp)
 lo=[min(p[k] for p in points) for k in range(3)];hi=[max(p[k] for p in points) for k in range(3)]
 report['actions'][name]={'min_blender':lo,'max_blender':hi,'dimensions':[hi[k]-lo[k] for k in range(3)],'loop_max_vertex_delta':max((p-q).length for p,q in zip(*endpoints))}
# High-angle spread-wing proof, distinct from flapping portrait.
a.animation_data.action=bpy.data.actions['Glide'];a.location.z=1.15;s=bpy.context.scene;s.frame_set(1);s.cycles.samples=16
cam=s.camera;cam.location=(2.3,-4.5,4.8);cam.rotation_euler=(Vector((0,0,1.65))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.3
s.render.filepath=os.path.join(OUT,'bird_glide.png');bpy.ops.render.render(write_still=True)
json.dump(report,open(os.path.join(OUT,'motion_bounds.json'),'w'),indent=2);print(json.dumps(report))
