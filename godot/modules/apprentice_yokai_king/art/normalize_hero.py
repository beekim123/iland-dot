from PIL import Image
from scipy import ndimage as nd
import numpy as np,json,hashlib
from pathlib import Path
D=Path(__file__).parent
im=Image.open(D/'sources/hero-ai-original.png').convert('RGBA');light=Image.open(D/'sources/hero-light-ai-repair.png').convert('RGBA');light.save(D/'sources/hero-light-ai-repair.png')
ys=[0,222,445,655,894,1135,1336,1554,1774];names=['idle','move','light','charge','slam','dodge','hurt','defeat']; anchors=[[145,365,584,808],[140,367,584,809],[],[132,361,582,815],[118,344,555,784],[115,341,561,791],[96,275,437,617],[113,310,538,751]]; baselines=[195,416,0,880,1107,1320,1533,1740]
at=Image.new('RGBA',(1024,2048));meta=json.loads((D/'manifest.json').read_text());meta['frames']=[]
for r,name in enumerate(names):
 for c in range(4):
  xs=[0,187,357,529,700] if r==6 else ([0,201,436,622,887] if r==7 else [round(i*887/4) for i in range(5)])
  src=im;box=(xs[c],ys[r],xs[c+1],ys[r+1]);ax=anchors[r][c] if r!=2 else 0;ay=baselines[r]; scale=.76
  if r==2:
   src=light;xx=[0,485,1093,1687,2172];box=(xx[c],0,xx[c+1],724);ax=[305,765,1325,1890][c];ay=[555,552,555,560][c];scale=.35
  f=src.crop(box);a=np.array(f); labels,n=nd.label(a[:,:,3]>32);sizes=nd.sum(a[:,:,3]>32,labels,range(n+1));sizes[0]=0;keep=nd.binary_dilation(labels==np.argmax(sizes),iterations=2);a[:,:,3]=np.where(keep,a[:,:,3],0);f=Image.fromarray(a);bb=f.getbbox();f=f.crop(bb);anchor=(ax-box[0]-bb[0],ay-box[1]-bb[1]);
  scale=min(scale,112/max(1,anchor[0]),112/max(1,f.width-anchor[0]),208/max(1,anchor[1]),30/max(1,f.height-anchor[1]));f=f.resize((round(f.width*scale),round(f.height*scale)),Image.Resampling.LANCZOS);tile=Image.new('RGBA',(256,256));tile.alpha_composite(f,(round(128-anchor[0]*scale),round(220-anchor[1]*scale)));tile.save(D/f'frames/{name}-{c}.png');at.alpha_composite(tile,(c*256,r*256));meta['frames'].append({'action':name,'frame':c,'source':'hero-light-ai-repair.png' if r==2 else 'hero-ai-original.png','box':box,'foot_source':[ax,ay],'scale':scale,'sha256':hashlib.sha256(tile.tobytes()).hexdigest()})
at.save(D/'hero.png');(D/'manifest.json').write_text(json.dumps(meta,indent=2))
