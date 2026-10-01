#!/usr/bin/env python3
"""Generate the code-native LockIn icon at all Apple and extension sizes."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, math
root=Path(__file__).resolve().parents[1]
n=1024
im=Image.new('RGBA',(n,n),(0,0,0,0)); d=ImageDraw.Draw(im)
d.rounded_rectangle((64,64,960,960),radius=205,fill=(41,39,73))
d.arc((213,213,811,811),-88,225,fill=(147,139,255),width=48)
a=math.radians(225); x=512+299*math.cos(a); y=512+299*math.sin(a)
d.ellipse((x-24,y-24,x+24,y+24),fill=(147,139,255))
d.arc((400,330,624,564),180,360,fill=(247,245,255),width=42)
d.rounded_rectangle((359,470,665,692),radius=50,fill=(247,245,255))
d.ellipse((491,541,533,583),fill=(77,68,156)); d.rounded_rectangle((502,563,522,610),radius=10,fill=(77,68,156))
d.ellipse((491,189,533,231),fill=(247,245,255))
asset=root/'Assets.xcassets/AppIcon.appiconset'; asset.mkdir(parents=True,exist_ok=True)
images=[]
for size in [16,32,128,256,512]:
 for scale in [1,2]:
  name=f'icon_{size}x{size}@{scale}x.png'; im.resize((size*scale,size*scale),Image.Resampling.LANCZOS).save(asset/name)
  images.append({'idiom':'mac','size':f'{size}x{size}','scale':f'{scale}x','filename':name})
(asset/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2))
(root/'Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
p=root/'BrowserExtensions/Shared/icons';p.mkdir(exist_ok=True)
for size in [16,32,48,128,256]: im.resize((size,size),Image.Resampling.LANCZOS).save(p/f'{size}.png')
print('Generated app and extension icons.')
