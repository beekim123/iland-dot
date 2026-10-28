from PIL import Image
import numpy as np
from scipy import ndimage as nd
from pathlib import Path
D=Path(__file__).parent
src=D/'sources/enemies-ai-background-removal-attempt.png'
im=Image.open(src).convert('RGBA'); im.save(D/'sources/enemies-ai-background-removal-attempt.png')
raw=np.array(im); ink=raw[:,:,:3].max(axis=2)<65; ink=nd.binary_closing(ink,iterations=2); mask=nd.binary_fill_holes(ink); raw[:,:,3]=nd.binary_dilation(mask,iterations=1).astype('uint8')*255; im=Image.fromarray(raw)
ids=['grunt','shield','spring','bubble','sleeper','boss']; ys=[0,256,490,775,1024,1234,1536]
preview=Image.new('RGBA',(1024,1536))
for r,name in enumerate(ids):
 atlas=Image.new('RGBA',(1024,256))
 for c in range(4):
  xs=[0,250,480,768,1024] if r==5 else ([0,250,505,745,1024] if r in [1,4] else [0,256,512,768,1024])
  p=im.crop((xs[c],ys[r],xs[c+1],ys[r+1])); a=np.array(p)
  labels,n=nd.label(a[:,:,3]>0); sizes=nd.sum(a[:,:,3]>0,labels,range(n+1));sizes[0]=0; a[:,:,3]=(labels==np.argmax(sizes)).astype('uint8')*255
  if r==1 and c==2: a[214:,:,3]=0
  p=Image.fromarray(a);p=p.crop(p.getbbox());scale=min(210/p.height,220/p.width)
  p=p.resize((round(p.width*scale),round(p.height*scale)),Image.Resampling.LANCZOS);f=Image.new('RGBA',(256,256));f.alpha_composite(p,((256-p.width)//2,220-p.height));atlas.alpha_composite(f,(c*256,0));preview.alpha_composite(f,(c*256,r*256))
  if c==0:f.save(D/(name+'.png'))
 atlas.save(D/(name+'-strip.png'))
Image.open(D/'grunt.png').save(D/'elite.png');preview.save(D/'enemies-preview.png')
