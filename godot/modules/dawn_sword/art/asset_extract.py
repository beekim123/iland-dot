from PIL import Image
import numpy as np, scipy.ndimage as nd, json,pathlib,shutil
P=pathlib.Path(__file__).parent;G=pathlib.Path('/workspace/scratch/e3e9ec015b32/generated_images')
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
