import bpy, bmesh, json, math
from pathlib import Path
p=Path(__file__).parent
terrain=bpy.data.objects['Cove terrain • single continuous sculpted solid']
bm=bmesh.new();bm.from_mesh(terrain.data)
result={'terrain':{'vertices':len(bm.verts),'edges':len(bm.edges),'faces':len(bm.faces),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-10 for f in bm.faces),'z_min':min(v.co.z for v in bm.verts),'z_max':max(v.co.z for v in bm.verts)},'all_mesh_coordinates_finite':all(math.isfinite(c) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices for c in v.co),'camera':{'orthographic':bpy.context.scene.camera.data.type=='ORTHO','scale':bpy.context.scene.camera.data.ortho_scale},'render':{'samples':bpy.context.scene.cycles.samples,'denoising':bpy.context.scene.cycles.use_denoising},'fine_wood_grain_objects':len([o for o in bpy.data.objects if 'grain ' in o.name and 'Pier board' in o.name])}
bm.free();(p/'landscape_qa.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
