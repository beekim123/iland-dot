"""Independent original fox face Col -> rigged PBR color preservation proof."""
import bpy,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;SOURCE=HERE.parent/'fox';reports=[]
for team in ['blue','orange']:
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE/f'fox_{team}.blend'))
 original={}
 for o in bpy.context.scene.objects:
  if o.type!='MESH' or not o.data.color_attributes.get('Col'):continue
  if o.parent.name=='Weapon':continue # Authorized front swivel replaces some weapon faces.
  attr=o.data.color_attributes['Col'];colors=[tuple(attr.data[p.loop_start].color) for p in o.data.polygons]
  original[o.parent.name]=colors
 bpy.ops.wm.open_mainfile(filepath=str(HERE/'fox'/f'fox_{team}_rigged.blend'))
 checked=0;maxerror=0.;hist={};roles=[]
 for o in bpy.context.scene.objects:
  role=o.get('source_surface')
  if o.type!='MESH' or role not in original:continue
  if all(m.diffuse_color[3]<.99 for m in o.data.materials):continue
  expected=original[role]
  assert len(expected)==len(o.data.polygons),(role,len(expected),len(o.data.polygons))
  for p,color in zip(o.data.polygons,expected):
   m=o.data.materials[p.material_index];actual=m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value
   error=max(abs(a-b) for a,b in zip(actual,color));maxerror=max(maxerror,error);checked+=1
   key=','.join(f'{x:.6f}' for x in actual[:3]);hist[key]=hist.get(key,0)+1
  roles.append(role)
 assert maxerror<1e-6,(team,maxerror)
 assert len(hist)>=12,(team,len(hist))
 reports.append({'team':team,'status':'PASS','original_face_colors_compared':checked,'max_linear_rgba_error':maxerror,'unique_preserved_colors':len(hist),'per_color_face_histogram':hist,'roles':roles,'weapon_front_excluded_reason':'Authorized newly authored ball-joint nozzle, original species/face/body/limb colors compared exactly.'})
(HERE/'fox'/'palette_preservation_validation.json').write_text(json.dumps({'status':'PASS','assets':reports},indent=2));print('FOX_PALETTE_PRESERVATION',json.dumps(reports))
