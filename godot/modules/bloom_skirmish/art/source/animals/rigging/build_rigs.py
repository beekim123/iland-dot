"""Real skinned animal rigs. Blender 4.3.2; authored geometry is never overwritten.
Reproduce: blender -b --python build_rigs.py -- --species otter --team blue
Coordinates below are Blender Z-up; godot() converts authored Y-up locations.
Actual mesh vertex weights + Armature modifiers, no rigid-parent substitute.
"""
import bpy, bmesh, sys, math, json, hashlib, argparse
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
HERE=Path(__file__).resolve().parent
ART=HERE.parents[2]
TAU=math.tau

def g(p): return Vector((p[0],-p[2],p[1]))
def god(p): return [p.x,p.z,-p.y]
def clamp(x,a=0.,b=1.): return max(a,min(b,x))
def smooth(x): x=clamp(x);return x*x*(3-2*x)
def mix(a,b,t):return a+(b-a)*t

def components(me):
    adj=[[] for v in me.vertices]
    for e in me.edges:
        a,b=e.vertices;adj[a].append(b);adj[b].append(a)
    seen=set();out=[]
    for start in range(len(adj)):
        if start in seen:continue
        seen.add(start);todo=[start];part=[]
        while todo:
            i=todo.pop();part.append(i)
            for j in adj[i]:
                if j not in seen:seen.add(j);todo.append(j)
        out.append(part)
    return out

def palette_to_pbr(obj):
    attr=obj.data.color_attributes.get('Col')
    if not attr:return
    slots={};mats=[];face_ids=[]
    for poly in obj.data.polygons:
        c=tuple(round(x,6) for x in attr.data[poly.loop_start].color)
        if c not in slots:
            key='PBR preserved fox palette '+'_'.join(f'{v:.6f}' for v in c[:3])
            m=bpy.data.materials.get(key)
            if m is None:
                m=bpy.data.materials.new(key);m.use_nodes=True;m.diffuse_color=c
                bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=c;bs.inputs['Roughness'].default_value=.66
            slots[c]=len(mats);mats.append(m)
        face_ids.append(slots[c])
    obj.data.materials.clear()
    for m in mats:obj.data.materials.append(m)
    for poly,index in zip(obj.data.polygons,face_ids):poly.material_index=index
    obj.data.color_attributes.remove(attr)

def rotation_between(a,b):
    if a.length<1e-7 or b.length<1e-7:return Quaternion()
    return a.normalized().rotation_difference(b.normalized())

def ik2(start,target,l1,l2,pref):
    v=target-start;dist=v.length;d=v.normalized()
    # Reach is guaranteed by small body poses. Clamp only roundoff at full extension.
    dist=clamp(dist,abs(l1-l2)+1e-5,l1+l2-1e-5)
    x=(l1*l1-l2*l2+dist*dist)/(2*dist)
    h=math.sqrt(max(0,l1*l1-x*x))
    bend=pref-start;perp=bend-d*bend.dot(d)
    if perp.length<1e-5:
        perp=Vector((0,1,0))-d*d.y
    perp.normalize()
    return start+d*x+perp*h

def closest_path(p,path):
    best=(1e9,0.)
    for i,(a,b) in enumerate(zip(path,path[1:])):
        v=b-a;t=clamp((p-a).dot(v)/max(v.length_squared,1e-8));q=a+v*t
        if (p-q).length_squared<best[0]:best=((p-q).length_squared,i+t)
    return best[1]

class Rig:
 def __init__(self,species,team):
    self.species,self.team=species,team
    self.src=ART/'source'/'animals'/species/f'{species}_{team}.blend'
    self.out=ART/'models'/'animals'/'rigged'/species;self.out.mkdir(parents=True,exist_ok=True)
    self.work=HERE/species;self.work.mkdir(parents=True,exist_ok=True)
    self.source_hash=hashlib.sha256(self.src.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(self.src));self.scene=bpy.context.scene
    self.root=bpy.data.objects['AthleteRoot'];self.weapon=bpy.data.objects['Weapon']
    self.meshes=[o for o in self.root.children_recursive if o.type=='MESH' and o.parent!=self.weapon]
    self.roles={o.name:o.parent.name for o in self.meshes}
    self.side={}
    self.joints={};self.rest={};self.bones={};self.parents={};self.weight_stats={}
    # Bake the approved holding pose into the bind geometry before making bones.
    if species!='raccoon':
        for side,a,f in [('R',.50,.70),('L',.20,.35)]:
            arm=bpy.data.objects['Arm'+side];arm.rotation_euler.x=a
            if side=='L':arm.rotation_euler.y=-.09
            next(o for o in arm.children if o.name.startswith('Forearm')).rotation_euler.x=f
    bpy.context.view_layer.update()
    self.headpos=bpy.data.objects['Head'].matrix_world.translation.copy()
    self.bodypos=bpy.data.objects['Body'].matrix_world.translation.copy()
    self.limbs={}
    for side in ['L','R']:
        arm=bpy.data.objects['Arm'+side];fore=next(o for o in arm.children if o.type=='EMPTY' and o.name.startswith('Forearm'))
        leg=bpy.data.objects['Leg'+side];shin=next(o for o in leg.children if o.type=='EMPTY' and o.name.startswith('Shin'))
        if species in ['otter','rabbit']:palmlocal=(0,-.069,-.015)
        elif species=='fox':palmlocal=(.025,-.26,.08) if side=='R' else (0,-.195,-.026)
        else:palmlocal=(.046,-.164,-.173) if side=='R' else (-.009,-.123,-.031)
        shoulder=arm.matrix_world.translation.copy();elbow=fore.matrix_world.translation.copy();palm=fore.matrix_world@g(palmlocal)
        hip=leg.matrix_world.translation.copy();knee=shin.matrix_world.translation.copy()
        # Ankle lies within the original hindpaw, well above the sole plane.
        ankle=Vector((knee.x,knee.y,.083 if species=='raccoon' else .068 if species=='otter' else .075))
        self.limbs[side]={'shoulder':shoulder,'elbow':elbow,'palm':palm,'hip':hip,'knee':knee,'ankle':ankle,
          'armrot':fore.matrix_world.to_quaternion(),'handdir':fore.matrix_world.to_quaternion()@g((0,-.065,-.025))}
        for o in self.meshes:
            if o.parent in [arm,fore,leg,shin]:self.side[o.name]=side
    for o in self.meshes:
        # Converted source surfaces are already evaluated, but preserve any remaining modifiers.
        bpy.context.view_layer.objects.active=o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        mat=o.matrix_world.copy();o.data.transform(mat);o.parent=self.root;o.matrix_world=Matrix.Identity(4)
        palette_to_pbr(o)
    for o in self.weapon.children_recursive:
        if o.type=='MESH':palette_to_pbr(o)
    # Remove old anatomical Empty pivots. Their transforms are baked, not animated.
    keep={self.root,self.weapon,*self.meshes,*self.weapon.children_recursive}
    for o in list(self.root.children_recursive):
        if o not in keep and o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
    for o in list(bpy.context.scene.objects):
        if o.type in {'CAMERA','LIGHT'}:bpy.data.objects.remove(o,do_unlink=True)
    self.make_skeleton();self.skin();self.add_grip();self.add_aim_nozzle();self.animate();self.save()

 def addbone(self,name,head,tail,parent=None):
    e=self.arm.data.edit_bones.new(name);e.head=head;e.tail=tail
    if (e.tail-e.head).length<.005:e.tail=e.head+Vector((0,0,.05))
    if parent:e.parent=self.arm.data.edit_bones[parent]
    e.use_deform=True;e.inherit_scale='NONE';self.rest[name]=(e.head.copy(),e.tail.copy());self.parents[name]=parent

 def make_skeleton(self):
    a=bpy.data.armatures.new(f'{self.species}_DeformSkeleton');self.arm=bpy.data.objects.new('CharacterRig',a);bpy.context.collection.objects.link(self.arm);self.arm.parent=self.root
    self.arm.show_in_front=True;bpy.context.view_layer.objects.active=self.arm;self.arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    hipheight=sum(l['hip'].z for l in self.limbs.values())*.5
    self.pelvis=g((0,hipheight+.055,.025));self.neck=g((0,self.headpos.z-.20,.0))
    self.addbone('Root',g((0,0,0)),g((0,.15,0)))
    self.addbone('Pelvis',self.pelvis,g((0,.62,.015)),'Root')
    self.addbone('Spine',g((0,.62,.015)),g((0,.81,.015)),'Pelvis')
    self.addbone('Chest',g((0,.81,.015)),self.neck,'Spine')
    self.addbone('Head',self.neck,self.headpos+g((0,.13,0)),'Chest')
    for side,l in self.limbs.items():
        self.addbone('UpperArm.'+side,l['shoulder'],l['elbow'],'Chest')
        self.addbone('Forearm.'+side,l['elbow'],l['palm'],'UpperArm.'+side)
        self.addbone('Hand.'+side,l['palm'],l['palm']+l['handdir'],'Forearm.'+side)
        self.addbone('Thigh.'+side,l['hip'],l['knee'],'Pelvis')
        self.addbone('Shin.'+side,l['knee'],l['ankle'],'Thigh.'+side)
        self.addbone('Foot.'+side,l['ankle'],l['ankle']+g((0,0,-.13)),'Shin.'+side)
    if self.species=='otter':ps=[(0,.45,.145),(-.045,.32,.42),(-.16,.22,.68),(-.34,.19,.90)]
    elif self.species=='fox':ps=[(0,.48,.15),(-.30,.64,.43),(-.58,.93,.43),(-.61,1.25,.21)]
    elif self.species=='raccoon':ps=[(0,.51,.205),(-.19,.55,.52),(-.49,.72,.57),(-.55,.99,.465)]
    else:ps=[(0,.535,.19),(0,.535,.28),(0,.535,.39)]
    self.tailpath=[g(p) for p in ps]
    for i in range(len(ps)-1):self.addbone('Tail.%02d'%(i+1),self.tailpath[i],self.tailpath[i+1],'Pelvis' if i==0 else 'Tail.%02d'%i)
    self.earpaths={}
    for side,s in [('L',-1),('R',1)]:
        if self.species=='otter':ps=[(s*.245,self.headpos.z+.13,.0),(s*.277,self.headpos.z+.205,.0),(s*.28,self.headpos.z+.239,.0)]
        elif self.species=='raccoon':ps=[(s*.207,self.headpos.z+.18,.0),(s*.25,self.headpos.z+.275,.0),(s*.24,self.headpos.z+.33,.0)]
        elif self.species=='fox':ps=[(s*.205,self.headpos.z+.23,.025),(s*.245,self.headpos.z+.36,.025),(s*.285,self.headpos.z+.49,.025)]
        else:ps=[(s*.155,self.headpos.z+.22,.0),(s*.19,self.headpos.z+.46,.02),(s*.22,self.headpos.z+.72,.04)]
        self.earpaths[side]=[g(p) for p in ps]
        self.addbone('EarBase.'+side,self.earpaths[side][0],self.earpaths[side][1],'Head')
        self.addbone('EarTip.'+side,self.earpaths[side][1],self.earpaths[side][2],'EarBase.'+side)
    bpy.ops.object.mode_set(mode='OBJECT');self.arm.select_set(False)
    self.restmat={b.name:b.matrix_local.copy() for b in self.arm.data.bones}

 def setweights(self,obj,idx,w):
    w={k:v for k,v in w.items() if v>1e-5};total=sum(w.values())
    for name,val in w.items():
        vg=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name);vg.add([idx],val/total,'REPLACE')

 def skin(self):
    for o in self.meshes:
        role=self.roles[o.name];side=self.side.get(o.name);blend=0;tailverts=0;earverts=0
        for comp in components(o.data):
            pts=[o.data.vertices[i].co for i in comp];c=sum(pts,Vector())/len(pts)
            mins=Vector([min(v[k] for v in pts) for k in range(3)]);maxs=Vector([max(v[k] for v in pts) for k in range(3)])
            is_tail=(role=='Body' and ((-mins.y>.48 and c.x<-.08) if self.species!='rabbit' else (c.y<-.20 and c.z<.61 and maxs.z<.67 and abs(c.x)<.10 and len(comp)>150)))
            is_ear=role=='Head' and ((abs(c.x)>.19 and mins.z>self.headpos.z+.06 and maxs.z>self.headpos.z+.20) if self.species in ['otter','raccoon'] else (abs(c.x)>.10 and maxs.z>self.headpos.z+.36 and mins.z>self.headpos.z+.16))
            for idx in comp:
                p=o.data.vertices[idx].co;w={}
                if is_tail:
                    t=closest_path(p,self.tailpath);n=len(self.tailpath)-1
                    # Centers of each deform segment, blended across adjacent joints.
                    q=clamp(t-.5,0,n-1);lo=int(q);hi=min(n-1,lo+1);f=smooth(q-lo)
                    w={'Tail.%02d'%(lo+1):1-f};w['Tail.%02d'%(hi+1)]=w.get('Tail.%02d'%(hi+1),0)+f
                    rootblend=1-smooth(t/.45)
                    if rootblend>0:w={k:v*(1-.35*rootblend) for k,v in w.items()};w['Pelvis']=.35*rootblend
                    tailverts+=1
                elif is_ear:
                    s='L' if c.x<0 else 'R';path=self.earpaths[s];t=closest_path(p,path)
                    f=smooth((t-.45)/.8);root=smooth(t/.5)
                    w={'Head':1-root,'EarBase.'+s:root*(1-f),'EarTip.'+s:root*f};earverts+=1
                elif role=='Body':
                    # Back-mounted hard tank stays one bone; fur + fitted vest have real torso skin weights.
                    if c.y<-.16 and c.z>.47 and not (len(comp)>700 and maxs.z-mins.z>.45):w={'Chest':1}
                    else:
                        z=p.z
                        if z<.64:
                            t=smooth((z-.45)/.23);w={'Pelvis':1-t,'Spine':t}
                        else:
                            t=smooth((z-.64)/.24);w={'Spine':1-t,'Chest':t}
                elif role=='Head':w={'Head':1}
                elif role.startswith('Arm'):
                    l=self.limbs[side];v=l['elbow']-l['shoulder'];t=(p-l['shoulder']).dot(v)/v.length_squared
                    f=smooth((t-.65)/.60);w={'UpperArm.'+side:1-f,'Forearm.'+side:f}
                elif role.startswith('Forearm'):
                    l=self.limbs[side];v=l['palm']-l['elbow'];t=(p-l['elbow']).dot(v)/v.length_squared
                    f=smooth((t-.50)/.40);root=(1-smooth((t+.25)/.55))*.35
                    w={'UpperArm.'+side:root,'Forearm.'+side:(1-root)*(1-f),'Hand.'+side:(1-root)*f}
                elif role.startswith('Leg'):
                    l=self.limbs[side];v=l['knee']-l['hip'];t=(p-l['hip']).dot(v)/v.length_squared
                    f=smooth((t-.65)/.65);w={'Thigh.'+side:1-f,'Shin.'+side:f}
                elif role.startswith('Shin'):
                    l=self.limbs[side];v=l['ankle']-l['knee'];t=(p-l['knee']).dot(v)/v.length_squared
                    f=smooth((t-.45)/.5);root=(1-smooth((t+.25)/.55))*.35
                    w={'Thigh.'+side:root,'Shin.'+side:(1-root)*(1-f),'Foot.'+side:(1-root)*f}
                    # Preserve broad animal paw volume: the paw/sole/toes are rigid foot
                    # islands; the actual ankle surface above them carries joint blends.
                    if c.z<l['ankle'].z+.025 or (maxs.z<l['ankle'].z+.065 and c.y>l['ankle'].y+.05):w={'Foot.'+side:1}
                else:raise RuntimeError(role)
                self.setweights(o,idx,w)
                if sum(v>0.001 for v in w.values())>=2:blend+=1
        mod=o.modifiers.new('Actual weighted skeletal deformation','ARMATURE');mod.object=self.arm;mod.use_deform_preserve_volume=True
        o['rigged_skin']=True;o['source_surface']=role;o.name=role.replace('.001','R')+'_Skinned'
        self.weight_stats[o.name]={'vertices':len(o.data.vertices),'multi_bone_vertices':blend,'tail_vertices':tailverts,'ear_vertices':earverts,'weights_normalized':True}

 def add_grip(self):
    grip=bpy.data.objects.new('GunGrip',None);bpy.context.collection.objects.link(grip);grip.parent=self.weapon
    grip.location=self.weapon.matrix_world.inverted()@self.limbs['R']['palm']
    grip['description']='Right palm center. Runtime aim IK target; Weapon rotates around fixed Muzzle.'

 def add_aim_nozzle(self):
    # Authorized animal-specific swivel: original receiver/grip/barrel remain fixed.
    # A compact rear hemispherical bowl rotates about the exact physical muzzle;
    # its spherical envelope keeps the fixed barrel inside the joint at steep pitch.
    removed=0
    for ob in list(self.weapon.children_recursive):
        if ob.type!='MESH':continue
        inv=self.weapon.matrix_world.inverted()@ob.matrix_world
        delete=[]
        for comp in components(ob.data):
            center=sum((inv@ob.data.vertices[i].co for i in comp),Vector())/len(comp)
            if center.y>.415:delete.extend(comp)
        if delete:
            bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
            bmesh.ops.delete(bm,geom=[bm.verts[i] for i in delete],context='VERTS');bm.to_mesh(ob.data);bm.free();removed+=len(delete)
    pivot=bpy.data.objects.new('AimNozzle',None);bpy.context.collection.objects.link(pivot);pivot.parent=self.weapon;pivot.location=g((0,.04,-.51))
    pivot['purpose']='Runtime pitch-only swivel; Muzzle sibling and GunGrip never translate.'
    def material(name,hexcolor,rough=.4,metal=.0):
        m=bpy.data.materials.new(name);m.use_nodes=True
        rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)];linear=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb]
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*linear,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal;m.diffuse_color=(*linear,1);return m
    graphite=material('Swivel graphite joint','28343D',.48,.12)
    accent=material('Swivel '+self.team+' team lip','2864F0' if self.team=='blue' else 'F78B30',.28,.15)
    inner=material('Swivel recessed bore','111B24',.72)
    # Coordinates local to pivot in Godot convention, then converted to Blender.
    verts=[];faces=[];mids=[];segments=32;rings=9;radius=.083
    for i in range(rings+1):
        theta=(math.pi/2)*(i/rings)
        r=radius*math.sin(theta);z=radius*math.cos(theta)
        for j in range(segments):
            a=TAU*j/segments;verts.append(g((r*math.cos(a),r*math.sin(a),z)))
    for i in range(rings):
        for j in range(segments):faces.append((i*segments+j,i*segments+(j+1)%segments,(i+1)*segments+(j+1)%segments,(i+1)*segments+j));mids.append(0)
    # The mouth plane stays exactly at the original physical emitter.
    base=len(verts)
    for r,z in [(radius,.004),(radius,-.003),(.043,-.003),(.043,.035)]:
        for j in range(segments):
            a=TAU*j/segments;verts.append(g((r*math.cos(a),r*math.sin(a),z)))
    for k in range(3):
        for j in range(segments):faces.append((base+k*segments+j,base+k*segments+(j+1)%segments,base+(k+1)*segments+(j+1)%segments,base+(k+1)*segments+j));mids.append(1 if k<2 else 2)
    faces.append(tuple(base+3*segments+j for j in range(segments)));mids.append(2)
    me=bpy.data.meshes.new('Short spherical pitch nozzle original authored geometry');me.from_pydata(verts,[],faces);me.update()
    obj=bpy.data.objects.new('AimNozzle_Surface',me);bpy.context.collection.objects.link(obj);obj.parent=pivot
    for m in [graphite,accent,inner]:me.materials.append(m)
    for face,mi in zip(me.polygons,mids):face.material_index=mi;face.use_smooth=True
    bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    self.nozzle_report={'removed_original_front_vertices':removed,'pivot_godot_local':[0,.04,-.51],'radius':radius,'geometry':'compact rear hemisphere + annular open mouth; fixed original barrel enters spherical envelope','weapon_and_grip_fixed':True,'muzzle_fixed':True}

 def mat_segment(self,name,head,tail):
    rh,rt=self.rest[name];rot=rotation_between(rt-rh,tail-head).to_matrix().to_4x4();m=rot@self.restmat[name];m.translation=head
    # Keep every bone scale exactly one. Breathing is Chest translation through
    # blended torso weights, avoiding nonuniform-inherit compensation differences
    # between Blender and glTF/Godot's immutable-track optimization.
    return m

 def animate(self):
    self.scene.render.fps=30;self.scene.frame_start=1;self.motion_stats={}
    self.arm.animation_data_create()
    for name,duration in [('idle',2.),('run',.6),('spray',.8),('dash',.5),('hit',.5),('celebration',1.6),('pod',.8),('respawn',1.),('defeat',1.2)]:
        count=round(duration*30);action=bpy.data.actions.new(name);self.arm.animation_data.action=action
        stats={'frames':count+1,'duration':duration,'max_right_grip_error':0.,'min_foot_height':1e9,'max_arm_reach_excess':0.,'max_foot_reach_excess':0.,'max_right_arm_reach_excess':0.,'max_actual_right_grip_error':0.,'max_lower_limb_joint_gap':0.,'max_torso_attenuation':0.,'max_requested_free_hand_reach_excess':0.}
        for frame in range(count+1):
            t=frame/count;phase=TAU*t
            self.scene.frame_set(frame+1)
            idle=math.sin(phase);bob=-.012+.004*idle;lean=.008*math.sin(phase);sway=.005*math.sin(phase);breath=.006*idle
            if name=='run':
                bob=-.060+.012*(1-math.cos(2*phase));lean=-.075;sway=.018*math.sin(phase);breath=.002*math.sin(2*phase)
                contact=1.0/3.0
                halfphase=t%.5
                if halfphase<contact:bob=-.055+.008*math.sin(math.pi*halfphase/contact)
                else:bob=-.055+.034*math.sin(math.pi*(halfphase-contact)/(.5-contact))
                sway=.012*math.sin(phase)
            elif name=='spray':bob=-.012+.003*math.sin(phase*4);lean=-.028-.014*math.sin(phase*4);sway=.004*math.sin(phase);breath=.003*math.sin(phase)
            elif name=='dash':bob=-.045*math.sin(math.pi*t)**2;lean=-.13*math.sin(math.pi*t)**2;sway=0;breath=0
            elif name=='hit':bob=-.03*math.sin(math.pi*t)**2;lean=.10*math.sin(math.pi*t)*math.exp(-2*t);sway=.035*math.sin(phase)*math.exp(-2*t);breath=0
            elif name=='celebration':bob=-.012+.018*(1-math.cos(phase*2));lean=-.025*math.sin(phase);sway=.04*math.sin(phase);breath=.008*math.sin(phase)
            elif name=='pod':bob=-.055*math.sin(math.pi*t)**2-.012;lean=-.11*math.sin(math.pi*t)**2;sway=-.012*math.sin(math.pi*t);breath=0
            elif name=='respawn':bob=-.012-.075*(1-t)**2;lean=-.10*(1-t);sway=.015*math.sin(phase)*(1-t);breath=.004*math.sin(phase)
            elif name=='defeat':bob=-.012-.08*smooth(t);lean=-.055*smooth(t);sway=-.025*smooth(t);breath=-.005*smooth(t)
            # Fox/raccoon source hocks are nearly fully straight at bind; keep a
            # 4 mm soft knee reserve during backward hit and dash recovery.
            if self.species in ['fox','raccoon'] and name in ['hit','dash']:bob-=.004
            # Rotation about pelvis, small torso compression; arm/foot endpoints solved independently.
            body=Matrix.Translation(self.pelvis+Vector((sway,0,bob)))@Matrix.Rotation(lean,4,'X')@Matrix.Rotation(sway*.8,4,'Y')@Matrix.Translation(-self.pelvis)
            # A short animal arm must never stretch to hide an unreachable pose.
            # Attenuate the whole torso motion toward a safe compact ready pose instead.
            rl=self.limbs['R'];reach=(rl['elbow']-rl['shoulder']).length+(rl['palm']-rl['elbow']).length-.002
            safe=Matrix.Translation((0,0,-.012))
            if ((body@rl['shoulder']+Vector((0,0,breath)))-rl['palm']).length>reach:
                low,high=0.,1.
                for _ in range(20):
                    mid=(low+high)*.5;candidate=safe.lerp(body,mid)
                    if ((candidate@rl['shoulder']+Vector((0,0,breath*mid)))-rl['palm']).length<=reach:low=mid
                    else:high=mid
                body=safe.lerp(body,low);breath*=low;stats['max_torso_attenuation']=max(stats['max_torso_attenuation'],1-low)
            desired={'Root':self.restmat['Root'].copy()}
            for bn in ['Pelvis','Spine','Chest']:
                rh,rt=self.rest[bn];hh=body@rh;tt=body@rt
                if bn=='Spine':tt.z+=breath
                if bn=='Chest':hh.z+=breath;tt.z+=breath
                desired[bn]=self.mat_segment(bn,hh,tt)
            chest_delta=desired['Chest']@self.restmat['Chest'].inverted()
            pelvis_delta=desired['Pelvis']@self.restmat['Pelvis'].inverted()
            head_delta=chest_delta@Matrix.Translation(self.neck)@Matrix.Rotation(.012*math.sin(phase+.3),4,'X')@Matrix.Rotation(.018*math.sin(phase),4,'Z')@Matrix.Translation(-self.neck)
            desired['Head']=head_delta@self.restmat['Head']
            for side,l in self.limbs.items():
                shoulder=chest_delta@l['shoulder'];target=l['palm'].copy()
                if side=='L':
                    target=chest_delta@target
                    if name=='run':target.y+=.065*math.sin(phase+math.pi);target.z+=.015*math.cos(phase)
                    elif name=='spray':target+=Vector((.04,.045,.025))*(.5-.5*math.cos(phase))
                    elif name=='celebration':target+=Vector((-.055,0,.19))*(.5-.5*math.cos(phase))
                    elif name=='hit':target.y-=.025*math.sin(math.pi*t)
                    elif name=='pod':target+=Vector((.025,.08,-.10))*math.sin(math.pi*t)**2
                    elif name=='respawn':target+=Vector((-.03,0,.06))*(1-t)
                    elif name=='defeat':target+=Vector((-.015,-.015,-.025))*smooth(t)
                l1=(l['elbow']-l['shoulder']).length;l2=(l['palm']-l['elbow']).length
                if side=='L':stats['max_requested_free_hand_reach_excess']=max(stats['max_requested_free_hand_reach_excess'],(target-shoulder).length-l1-l2)
                if side=='R':stats['max_right_arm_reach_excess']=max(stats['max_right_arm_reach_excess'],(target-shoulder).length-l1-l2)
                # Free hand has gentle reach limit; fixed weapon hand must remain in reach.
                if side=='L':
                    distance=(target-shoulder).length
                    if distance>l1+l2-.001 or distance<abs(l1-l2)+.001:
                        target=shoulder+(target-shoulder).normalized()*clamp(distance,abs(l1-l2)+.001,l1+l2-.001)
                stats['max_arm_reach_excess']=max(stats['max_arm_reach_excess'],(target-shoulder).length-l1-l2)
                elbow=ik2(shoulder,target,l1,l2,chest_delta@l['elbow'])
                desired['UpperArm.'+side]=self.mat_segment('UpperArm.'+side,shoulder,elbow)
                desired['Forearm.'+side]=self.mat_segment('Forearm.'+side,elbow,target)
                desired['Hand.'+side]=self.restmat['Hand.'+side].copy();desired['Hand.'+side].translation=target
                if side=='L':desired['Hand.'+side]=chest_delta@self.restmat['Hand.'+side];desired['Hand.'+side].translation=target
                else:
                    stats['max_right_grip_error']=max(stats['max_right_grip_error'],(target-l['palm']).length)
                    endpoint=desired['Forearm.R']@self.restmat['Forearm.R'].inverted()@self.rest['Forearm.R'][1]
                    stats['max_actual_right_grip_error']=max(stats['max_actual_right_grip_error'],(endpoint-target).length)
                hip=pelvis_delta@l['hip'];foot=l['ankle'].copy();lift=0
                if name=='run':
                    p=(t+(0 if side=='L' else .5))%1
                    # Stance goes backward at constant speed, swing returns with eased lift.
                    stride=4.6*.2/(2.6*1.3)*.5
                    contact=1.0/3.0
                    if p<contact:foot.y+=stride*(1-2*p/contact)
                    else:q=(p-contact)/(1-contact);foot.y+=stride*(-math.cos(math.pi*q));lift=({'rabbit':.12,'raccoon':.09}.get(self.species,.10))*math.sin(math.pi*q);foot.z+=lift
                elif name=='dash':foot.y+=(.06 if side=='L' else -.06)*math.sin(math.pi*t)**2
                elif name=='celebration':foot.z+=.018*(1-math.cos(phase*2));lift=.018*(1-math.cos(phase*2))
                ll1=(l['knee']-l['hip']).length;ll2=(l['ankle']-l['knee']).length
                excess=(foot-hip).length-ll1-ll2;stats['max_foot_reach_excess']=max(stats['max_foot_reach_excess'],excess)
                # Short chibi legs need a modest stance width/stride, no elastic limb stretch.
                if excess>-.001:
                    vec=foot-hip;maxhorizontal=math.sqrt(max(.0001,(ll1+ll2-.001)**2-vec.z**2));hor=Vector((vec.x,vec.y,0))
                    if hor.length>maxhorizontal:hor=hor.normalized()*maxhorizontal;foot.x=hip.x+hor.x;foot.y=hip.y+hor.y
                knee=ik2(hip,foot,ll1,ll2,l['knee']+Vector((0,.12,-.02)))
                desired['Thigh.'+side]=self.mat_segment('Thigh.'+side,hip,knee)
                desired['Shin.'+side]=self.mat_segment('Shin.'+side,knee,foot)
                end=desired['Shin.'+side]@self.restmat['Shin.'+side].inverted()@self.rest['Shin.'+side][1]
                stats['max_lower_limb_joint_gap']=max(stats['max_lower_limb_joint_gap'],(end-foot).length)
                desired['Foot.'+side]=self.restmat['Foot.'+side].copy();desired['Foot.'+side].translation=foot
                stats['min_foot_height']=min(stats['min_foot_height'],lift)
            # Multi-link tail follow-through, preserves the original animal outline.
            parentdelta=pelvis_delta
            for i in range(len(self.tailpath)-1):
                bn='Tail.%02d'%(i+1);rh,rt=self.rest[bn]
                amp=.075 if self.species=='rabbit' else .10 if name=='run' else .055
                rot=Matrix.Rotation(amp*math.sin(phase-i*.8),4,'Z')@Matrix.Rotation(amp*.3*math.sin(phase-i*.7),4,'X')
                delta=parentdelta@Matrix.Translation(rh)@rot@Matrix.Translation(-rh)
                desired[bn]=delta@self.restmat[bn];parentdelta=delta
            for side,s in [('L',-1),('R',1)]:
                parentdelta=head_delta
                for i,prefix in enumerate(['EarBase.','EarTip.']):
                    bn=prefix+side;rh,rt=self.rest[bn];amp=.10 if self.species=='rabbit' else .045
                    rot=Matrix.Rotation(amp*math.sin(phase-.6-i*.8+s*.3),4,'X')@Matrix.Rotation(s*amp*.4*math.sin(phase-i*.6),4,'Y')
                    delta=parentdelta@Matrix.Translation(rh)@rot@Matrix.Translation(-rh);desired[bn]=delta@self.restmat[bn];parentdelta=delta
            # Absolute pose matrices are baked to standard transform tracks in parent order.
            for bn in self.rest:
                pb=self.arm.pose.bones[bn];pb.rotation_mode='QUATERNION';pb.matrix=desired[bn]
                bpy.context.view_layer.update()
                for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(prop,frame=frame+1,group=bn)
        for fc in action.fcurves:
            for kp in fc.keyframe_points:kp.interpolation='LINEAR'
        action.use_fake_user=True
        track=self.arm.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);strip.name=name;strip.action_frame_start=1;strip.action_frame_end=count+1
        # Tracks are muted in source; exporter ACTIONS includes all compatible bone actions.
        track.mute=True
        self.motion_stats[name]=stats
    self.arm.animation_data.action=bpy.data.actions['idle'];self.scene.frame_set(1)

 def save(self):
    self.root['species']=self.species;self.root['team']=self.team;self.root['actual_skinning']=True;self.root['rig_version']='1.0'
    self.root['muzzle_contract']='fixed rest physical (.403,.884,-1.04) at scale1.3/rootY.04'
    self.scene.frame_start=1;self.scene.frame_end=61
    bpy.ops.object.select_all(action='DESELECT')
    for o in [self.root]+list(self.root.children_recursive):o.select_set(True)
    bpy.context.view_layer.objects.active=self.arm
    path=self.out/f'{self.species}_{self.team}_rigged.glb'
    temp_path=path.with_name(path.stem+'_pending.glb')
    bpy.ops.export_scene.gltf(filepath=str(temp_path),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_optimize_animation_size=False,export_frame_range=False,export_anim_slide_to_zero=True,export_rest_position_armature=True,export_def_bones=True,export_materials='EXPORT')
    temp_path.replace(path)
    bpy.ops.wm.save_as_mainfile(filepath=str(self.work/f'{self.species}_{self.team}_rigged.blend'),compress=True)
    report={'species':self.species,'team':self.team,'source_blend_sha256':self.source_hash,'source_preserved':True,'rigged_glb':str(path.relative_to(ART)),'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bones':list(self.rest),'weighted_meshes':self.weight_stats,'motion':self.motion_stats,'right_palm_bind_godot':god(self.limbs['R']['palm']),'right_arm':{k:god(self.limbs['R'][k]) for k in ['shoulder','elbow','palm']},'muzzle_physical':[.403,.884,-1.04],'weapon_independent':True,'palette_converted_to_pbr':self.species=='fox','aim_nozzle':self.nozzle_report,'run_gait':{'cycle_seconds':.6,'half_stride':4.6*.2/(2.6*1.3)*.5,'stance_fraction':1.0/3.0,'reference_playback_speed':2.6,'reference_world_speed':4.6,'swing_lift':{'rabbit':.12,'raccoon':.09}.get(self.species,.10)}}
    (self.work/f'{self.species}_{self.team}_rig_report.json').write_text(json.dumps(report,indent=2));print('RIGGED_RESULT',json.dumps(report))

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    p=argparse.ArgumentParser();p.add_argument('--species',choices=['otter','fox','raccoon','rabbit'],default='otter');p.add_argument('--team',choices=['blue','orange','both'],default='both');a=p.parse_args(args)
    for team in (['blue','orange'] if a.team=='both' else [a.team]):Rig(a.species,team)
