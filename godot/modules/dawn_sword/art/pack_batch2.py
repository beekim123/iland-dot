from PIL import Image
import numpy as np, scipy.ndimage as nd, json,pathlib,shutil
P=pathlib.Path(__file__).parent;G=pathlib.Path('/workspace/scratch/e3e9ec015b32/generated_images');m=json.loads((P/'manifest.json').read_text())
def components(name,rows):
 im=Image.open(G/name).convert('RGBA');a=np.array(im)[:,:,3];lab,n=nd.label(a>40);out=[]
 for i,s in enumerate(nd.find_objects(lab)):
  if (lab[s]==i+1).sum()<1200:continue
  y,x=s;b=(max(0,x.start-2),max(0,y.start-2),min(im.width,x.stop+2),min(im.height,y.stop+2));part=im.crop(b)
  aa=np.array(part);mask=lab[b[1]:b[3],b[0]:b[2]]==i+1;mask=nd.binary_dilation(mask,iterations=2);aa[:,:,3]=np.where(mask & (aa[:,:,3]>=18),aa[:,:,3],0);part=Image.fromarray(aa)
  out.append((b,part))
 # order by rows using vertical centers to handle kneeling/death drawings
 out.sort(key=lambda v:(min(rows-1,int(((v[0][1]+v[0][3])/2)/im.height*rows)),v[0][0]))
 return out
sources={'princess':'exec-f3afaf42-eda4-4620-99bd-78de7f8e719c.png','bandit':'exec-ee6be6cb-b083-490a-ba98-e4ff38e7384d.png','dragon':'exec-7f7c6e80-b1f1-4ef1-aa4e-407f1383afc2.png'}
def anim(s,n,f=9,loop=False):return {'start':s,'frames':n,'fps':f,'loop':loop}
for actor,name in sources.items():
 shutil.copyfile(G/name,P/f'source/{actor}_actions_v1.png');parts=components(name,3);assert len(parts)==9,(actor,len(parts))
 atlas=Image.new('RGBA',(1536,1536));scale=.92 if actor=='dragon' else .9
 for i,(b,im) in enumerate(parts):
  im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);atlas.alpha_composite(im,((i%3)*512+(512-im.width)//2,(i//3)*512+464-im.height))
 atlas.save(P/f'runtime/{actor}_atlas.png')
 anims={'idle':anim(0,1),'run':anim(1,2,10,True),'windup':anim(3,1),'attack':anim(4,2,10),'hurt':anim(6,1),'death':anim(7,2,6)}
 if actor=='princess':anims={'idle':anim(0,2,4,True),'interact':anim(2,1),'run':anim(3,3,10,True),'rescued':anim(6,2,6)}
 if actor=='dragon':anims={'idle':anim(0,1),'windup':anim(1,1),'attack':anim(2,1),'claw':anim(3,2),'hurt':anim(5,1),'fly':anim(6,2,6,True),'breath':anim(8,1)}
 m['actors'][actor]={'file':f'runtime/{actor}_atlas.png','columns':3,'rows':3,'frame_width':512,'frame_height':512,'height':330 if actor=='dragon' else 144,'anchor':[.5,464/512],'animations':anims,'status':'trial_needs_motion_review','pending':['full_cycles','transition_frames'],'source_bounds':[list(b) for b,_ in parts]}
# Repack original hero into generous 512px cells, then add intact corrected attack/death art.
name='exec-d05d0285-7a5d-4b86-8599-f6b10e13dbbd.png';shutil.copyfile(G/name,P/'source/hero_combat_v2.png');parts=components(name,4);assert len(parts)==12
old=Image.open(P/'runtime/hero_atlas.png');atlas=Image.new('RGBA',(3072,3072))
for i in range(24):atlas.alpha_composite(old.crop(((i%6)*256,(i//6)*256,(i%6+1)*256,(i//6+1)*256)),((i%6)*512+128,(i//6)*512+232))
for k,(b,im) in enumerate(parts):
 i=24+k;im=im.resize((round(im.width*.78),round(im.height*.78)),Image.Resampling.LANCZOS);atlas.alpha_composite(im,((i%6)*512+(512-im.width)//2,(i//6)*512+464-im.height))
atlas.save(P/'runtime/hero_atlas_v2.png');h=m['actors']['hero'];h.update(file='runtime/hero_atlas_v2.png',rows=6,frame_width=512,frame_height=512,height=224,anchor=[.5,464/512],pivot=[256,464]);h['animations'].update(attack1=anim(24,2,9),attack2=anim(27,3,12),attack3=anim(30,3,12),death=anim(33,3,6));h['pending']=[x for x in h['pending'] if x!='attack3'];h['notes']=['Attack1 final generated frame clipped at source canvas: excluded; 2-frame attack still needs recovery.','Attack2, attack3 and death replaced with intact isolated components.','Run gait requires improvement; do not call animation set final.'];(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
