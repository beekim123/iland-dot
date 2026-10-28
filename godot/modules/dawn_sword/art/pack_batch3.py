from asset_extract import *
m=json.loads((P/'manifest.json').read_text())
for actor,name in {'shield':'exec-312d39c0-3b33-4c61-ae7c-deb9593256e5.png','archer':'exec-67d83572-4f45-476d-9f95-d9edc69ab221.png','bat':'exec-5da7f225-3c6e-467f-88ee-3fb6b47695fe.png'}.items():
 shutil.copyfile(G/name,P/f'source/{actor}_actions_v1.png');parts=components(name,2);print(actor,len(parts));assert len(parts)==6
 atlas=Image.new('RGBA',(1536,1024));scale=min(420/max(im.width for _,im in parts),400/max(im.height for _,im in parts))
 for i,(b,im) in enumerate(parts):
  im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);atlas.alpha_composite(im,((i%3)*512+(512-im.width)//2,(i//3)*512+464-im.height))
 atlas.save(P/f'runtime/{actor}_atlas.png');anims={k:{'start':s,'frames':n,'fps':f,'loop':loop} for k,s,n,f,loop in [('idle',0,1,5,False),('run',1,2,10,True),('windup',3,1,8,False),('attack',4,1,8,False),('hurt',5,1,8,False)]}
 m['actors'][actor]={'file':f'runtime/{actor}_atlas.png','columns':3,'rows':2,'frame_width':512,'frame_height':512,'height':120 if actor=='bat' else 144,'anchor':[.5,464/512],'animations':anims,'status':'trial_needs_motion_review','pending':['death','attack_transitions','run_cycle_refinement']}
for id,name in {'chapter1_far':'exec-662eac47-4e0e-45da-8d65-06f62d5ab978.png','chapter1_mid':'exec-3bb53f10-8fcd-4e1b-a73b-add4fde26ad9.png'}.items():shutil.copyfile(G/name,P/f'runtime/{id}.png')
m['backgrounds'][0]={'far':'runtime/chapter1_far.png','mid':'runtime/chapter1_mid.png','composite':'runtime/chapter1.png'}
name='exec-2c0b77b7-8258-447b-b314-4e8a310d04d8.png';shutil.copyfile(G/name,P/'source/props_v1.png');im=Image.open(G/name).convert('RGBA');a=im.getchannel('A').point(lambda v:0 if v<22 else v);im.putalpha(a)
boxes={'grass_platform':(0,140,512,440),'stone_platform':(512,170,932,420),'bridge':(932,100,1350,430),'ladder':(1350,20,1536,460),'campfire':(0,500,405,950),'signpost':(410,500,710,950),'lever':(710,500,1100,950),'parchment':(1110,500,1536,950)}
m['props']={}
for id,b in boxes.items():
 part=im.crop(b);bbox=part.getchannel('A').getbbox();part=part.crop(bbox);part.save(P/f'runtime/{id}.png');m['props'][id]={'file':f'runtime/{id}.png','width':part.width,'height':part.height,'anchor':[.5,1.0]}
m['props']['grass_platform']['tile_top']=.20;m['props']['stone_platform']['tile_top']=.04;m['props']['bridge']['tile_top']=.32
m['background_status']='Chapter 1 has separate far/mid layers; chapters 2-5 are composite illustrations, near layers pending.'
(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
