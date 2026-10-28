"""Deterministic extraction only: never draws character art."""
from PIL import Image
import json, pathlib
P=pathlib.Path(__file__).parent
im=Image.open(P/'source/hero_actions_v1.png').convert('RGBA')
a=im.getchannel('A');a=a.point(lambda v:0 if v<18 else v);im.putalpha(a)
# Fixed source-cell extraction, common scale, foot-baseline translation.
out=Image.new('RGBA',(1536,1024));bounds=[]
for i in range(24):
 x,y=(i%6)*256,(i//6)*256
 tile=im.crop((x,y,x+256,y+256)); bbox=tile.getchannel('A').point(lambda v:255 if v>40 else 0).getbbox()
 if bbox:
  part=tile.crop(bbox);part=part.resize((round(part.width*.86),round(part.height*.86)),Image.Resampling.LANCZOS)
  out.alpha_composite(part,(x+(256-part.width)//2,y+232-part.height));bounds.append(list(bbox))
out.save(P/'runtime/hero_atlas.png')
def anim(start,count,fps=10,loop=False):return dict(start=start,frames=count,fps=fps,loop=loop)
animations={'idle':anim(0,2,5,True),'run':anim(2,4,12,True),'jump':anim(6,2,9),'fall':anim(8,1,8),'attack1':anim(9,3,12),'guard':anim(12,2,8),'roll':anim(14,3,12),'hurt':anim(17,2,10),'death':anim(19,2,6),'attack2':anim(21,3,12)}
manifest={'version':1,'provenance':{'method':'OpenAI built-in image_gen AI-assisted 2D illustration; not a claim of human hand drawing','date':'2026-10-28'},'actors':{'hero':{'file':'runtime/hero_atlas.png','columns':6,'rows':4,'frame_width':256,'frame_height':256,'height':112,'anchor':[.5,232/256],'pivot':[128,232],'animations':animations,'status':'trial_needs_runtime_review','pending':['attack3','air_attack','land','parry','heal','dawn','climb','interact'],'notes':['4 run drawings are distinct but gait loop requires motion QA.','Death prone source touches neighboring cell; needs repair before acceptance.','All frames use common scale and sole baseline; attack1 slash extends close to source cell edge.']}},'backgrounds':['runtime/chapter1.png'],'background_status':'chapter1 composite illustration available; independent parallax layers pending','extraction':{'hero_source_bounds':bounds}}
(P/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
