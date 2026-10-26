"""Independent read-only Blender and glTF skeletal audit.
Run: blender -b asset.blend -t 1 -P tools/rigging_audit.py -- --glb asset.glb --out report.json
No source asset is written. Mesh deformation is measured after cancelling rigid transforms.
"""
import argparse, json, math, re, struct, sys
from pathlib import Path
import bpy

p=argparse.ArgumentParser(); p.add_argument('--glb'); p.add_argument('--out',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
report={'blend':bpy.data.filepath,'armatures':[],'meshes':[],'actions':[], 'failures':[], 'notes':[]}
scene=bpy.context.scene
arms=[o for o in scene.objects if o.type=='ARMATURE']
if not arms: report['failures'].append('No Armature object')
for arm in arms:
    bones={b.name for b in arm.data.bones}
    report['armatures'].append({'name':arm.name,'bones':len(bones),'bone_names':sorted(bones),'active_action':arm.animation_data.action.name if arm.animation_data and arm.animation_data.action else None})
for act in bpy.data.actions:
    curves=list(act.fcurves)
    channels=sorted({m.group(1) for f in curves for m in [re.search(r'pose\.bones\["(.+?)"\]',f.data_path)] if m})
    report['actions'].append({'name':act.name,'frame_range':list(act.frame_range),'fcurves':len(curves),'keyframes':sum(len(c.keyframe_points) for c in curves),'animated_bones':channels})
if not report['actions']: report['failures'].append('No actions')
for obj in scene.objects:
    if obj.type!='MESH': continue
    mods=[m for m in obj.modifiers if m.type=='ARMATURE' and m.object]
    if not mods: continue
    arm=mods[0].object; bones={b.name for b in arm.data.bones}
    names={g.index:g.name for g in obj.vertex_groups}
    unweighted=0; maxerr=0.; blended=0; used=set()
    for v in obj.data.vertices:
        entries=[g for g in v.groups if names.get(g.group) in bones and g.weight>1e-7]
        sm=sum(g.weight for g in entries)
        if sm<1e-6: unweighted+=1
        else: maxerr=max(maxerr,abs(sm-1.))
        if len(entries)>1: blended+=1
        used.update(names[g.group] for g in entries)
    rec={'name':obj.name,'vertices':len(obj.data.vertices),'armature':arm.name,'unweighted':unweighted,'max_weight_sum_error':maxerr,'blended_vertices':blended,'weighted_bones':sorted(used),'deformation':[]}
    if unweighted: report['failures'].append(f'{obj.name}: {unweighted} unweighted vertices')
    if maxerr>0.002: report['failures'].append(f'{obj.name}: weights not normalized ({maxerr})')
    ad=arm.animation_data
    active=ad.action if ad else None
    acts=[]
    acts=[act for act in bpy.data.actions if any('pose.bones' in c.data_path for c in act.fcurves)]
    if not acts and active: acts=[active]
    for act in acts:
        if not ad: arm.animation_data_create(); ad=arm.animation_data
        previous=ad.action
        ad.action=act
        lo,hi=act.frame_range
        frames=[lo,lo+(hi-lo)*.23,lo+(hi-lo)*.51,lo+(hi-lo)*.77,hi]
        arrays=[]
        for fr in frames:
            scene.frame_set(int(fr), subframe=fr-int(fr)); bpy.context.view_layer.update()
            eo=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()); me=eo.to_mesh()
            step=max(1,len(me.vertices)//180)
            coords=[v.co.copy() for v in list(me.vertices)[::step]][:180]
            arrays.append(coords); eo.to_mesh_clear()
        if arrays and arrays[0]:
            ref=arrays[0]; pair_indices=[(i,(i*37+13)%len(ref)) for i in range(len(ref))]
            ref_dist=[(ref[i]-ref[j]).length for i,j in pair_indices]
            max_nonrigid=0.; max_local=0.
            for coords in arrays[1:]:
                if len(coords)!=len(ref): continue
                max_local=max(max_local,max((v-w).length for v,w in zip(ref,coords)))
                max_nonrigid=max(max_nonrigid,max(abs((coords[i]-coords[j]).length-d) for (i,j),d in zip(pair_indices,ref_dist)))
            rec['deformation'].append({'action':act.name,'frames':frames,'max_local_vertex_change':max_local,'max_pair_distance_change':max_nonrigid,'nonrigid_deformation_detected':max_nonrigid>1e-5})
        ad.action=previous
    report['meshes'].append(rec)
if not report['meshes']: report['failures'].append('No meshes with Armature modifiers')
report['summary']={'armatures':len(arms),'skinned_meshes':len(report['meshes']),'vertices':sum(x['vertices'] for x in report['meshes']),'blended_vertices':sum(x['blended_vertices'] for x in report['meshes']),'nonrigid_meshes':[x['name'] for x in report['meshes'] if any(d['nonrigid_deformation_detected'] for d in x['deformation'])]}
if not report['summary']['nonrigid_meshes']: report['failures'].append('No sampled non-rigid weighted deformation detected')

if a.glb:
    data=Path(a.glb).read_bytes(); magic,version,total=struct.unpack_from('<III',data)
    if magic!=0x46546c67 or version!=2 or total!=len(data): raise ValueError('Invalid GLB header')
    pos=12; doc=None; binary=b''
    while pos<len(data):
        size,kind=struct.unpack_from('<II',data,pos);pos+=8;chunk=data[pos:pos+size];pos+=size
        if kind==0x4e4f534a: doc=json.loads(chunk.decode('utf-8'))
        elif kind==0x004e4942: binary=chunk
    ctypes={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
    widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    def accessor(index):
        acc=doc['accessors'][index]; view=doc['bufferViews'][acc['bufferView']]; code,sz=ctypes[acc['componentType']]; w=widths[acc['type']]
        offset=view.get('byteOffset',0)+acc.get('byteOffset',0); stride=view.get('byteStride',sz*w)
        out=[struct.unpack_from('<'+code*w,binary,offset+i*stride) for i in range(acc['count'])]
        if acc.get('normalized') and acc['componentType']!=5126:
            div={5120:127,5121:255,5122:32767,5123:65535,5125:4294967295}[acc['componentType']]
            out=[tuple(max(-1,x/div) for x in row) for row in out]
        return out
    jointnodes={j for skin in doc.get('skins',[]) for j in skin['joints']}
    animations=[]
    for anim in doc.get('animations',[]):
        channels=anim.get('channels',[]); animj={c['target']['node'] for c in channels if c['target'].get('node') in jointnodes}
        varying=[]; times=[]; max_loop_delta=0.0
        for channel in channels:
            if channel['target'].get('node') not in jointnodes: continue
            sampler=anim['samplers'][channel['sampler']]
            rows=accessor(sampler['output']); times.extend(x[0] for x in accessor(sampler['input']))
            if rows:
                delta=max(abs(x-y) for x,y in zip(rows[0],rows[-1]))
                if channel['target']['path']=='rotation': delta=min(delta,max(abs(x+y) for x,y in zip(rows[0],rows[-1])))
                max_loop_delta=max(max_loop_delta,delta)
            span=max((max(col)-min(col)) for col in zip(*rows)) if rows else 0.0
            if span>1e-6: varying.append({'node':channel['target']['node'],'path':channel['target']['path'],'span':span})
        animations.append({'name':anim.get('name'), 'channels':len(channels),'animated_joint_nodes':len(animj),'varying_joint_channels':varying,'duration_seconds':max(times)-min(times) if times else 0,'max_joint_loop_delta':max_loop_delta})
        if not varying: report['failures'].append('GLB animation has no changing joint outputs: '+str(anim.get('name')))
    primitives=[]
    for node in doc.get('nodes',[]):
        if 'mesh' not in node or 'skin' not in node: continue
        skin=doc['skins'][node['skin']]
        for prim in doc['meshes'][node['mesh']]['primitives']:
            at=prim['attributes']; missing=[k for k in ['JOINTS_0','WEIGHTS_0'] if k not in at]
            if missing: report['failures'].append(f'GLB {node.get("name")}: missing {missing}');continue
            ws=accessor(at['WEIGHTS_0']); js=accessor(at['JOINTS_0'])
            if 'WEIGHTS_1' in at:
                extra=accessor(at['WEIGHTS_1']); ws=[tuple(x)+tuple(y) for x,y in zip(ws,extra)]
                extra=accessor(at['JOINTS_1']);js=[tuple(x)+tuple(y) for x,y in zip(js,extra)]
            err=max(abs(sum(w)-1) for w in ws); bad=sum(any(j>=len(skin['joints']) for j,w in zip(jj,ww) if w>1e-7) for jj,ww in zip(js,ws))
            primitives.append({'name':node.get('name'),'vertices':len(ws),'weight_sum_max_error':err,'invalid_joint_vertices':bad})
            if err>.002 or bad:report['failures'].append(f'GLB invalid weights/joints: {node.get("name")}')
    report['glb']={'path':a.glb,'bytes':len(data),'skins':len(doc.get('skins',[])),'joint_nodes':len(jointnodes),'animations':animations,'skinned_primitives':primitives,'external_uris':[x['uri'] for typ in ['buffers','images'] for x in doc.get(typ,[]) if x.get('uri')]}
    if not jointnodes or not primitives or not any(x['animated_joint_nodes'] for x in animations): report['failures'].append('GLB lacks real animated skin')
Path(a.out).write_text(json.dumps(report,indent=2))
print('RIGGING_AUDIT',json.dumps({'summary':report['summary'],'failures':report['failures'],'out':a.out}))
