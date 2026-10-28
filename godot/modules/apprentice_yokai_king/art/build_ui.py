from PIL import Image
from pathlib import Path
D=Path(__file__).parent
im=Image.open(D/'sources/ui-ai-original.png');names=['wind_core','wind_step','wind_return','thunder_core','thunder_chain','thunder_charge','quake_core','quake_slow','quake_echo','fast_handle','elastic_head','round_roll','card_panel','title_panel','score_panel','heart'];ys=[0,350,650,951,1254]
for i,n in enumerate(names):
 r,c=divmod(i,4);xs=[0,338,635,1002,1254] if r==3 else [0,330,630,930,1254];f=im.crop((xs[c],ys[r],xs[c+1],ys[r+1]));f=f.crop(f.getbbox());f.thumbnail((256,256),Image.Resampling.LANCZOS);f.save(D/'ui'/(n+'.png'))
