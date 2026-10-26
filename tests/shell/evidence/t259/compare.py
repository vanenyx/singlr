#!/usr/bin/env python3
"""Crop native private-session PNGs; requires Pillow, no invented UI geometry."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
p=argparse.ArgumentParser();p.add_argument('before',type=Path);p.add_argument('after',type=Path);a=p.parse_args()
out=Path(__file__).resolve().parent
font=ImageFont.truetype(str(out.parents[3]/'third_party/inter/InterVariable.ttf'),18)
canvas=Image.new('RGB',(1100,670),'#242427');d=ImageDraw.Draw(canvas)
for column,(name,folder) in enumerate([('Antes',a.before),('Después',a.after)]):
 im=Image.open(folder/'desktop-dark.png').convert('RGB'); w,h=im.size;x=column*550
 d.text((x+20,15),name,font=font,fill='white')
 # The screenshots have a 1.25 physical scale. Crop, then enlarge nearest-neighbor
 # to expose the logo's actual rasterization, without smoothing away its weight.
 logo=im.crop((0,0,180,42)).resize((450,105),Image.Resampling.NEAREST)
 canvas.paste(logo,(x+20,50))
 d.text((x+20,176),'Dock y tooltip · captura nativa',font=font,fill='white')
 canvas.paste(im.crop((w//2-250,h-190,w//2+250,h)),(x+20,210))
light=Image.open(a.after/'desktop-light.png').convert('RGB');w,h=light.size
d.text((570,425),'Modo claro',font=font,fill='white')
canvas.paste(light.crop((0,0,500,40)),(570,455))
canvas.paste(light.crop((w//2-250,h-150,w//2+250,h)),(570,505))
d.text((20,445),'Diámetro conservado; más grosor.',font=font,fill='white')
d.text((20,480),'Tooltip: 62 px → 8 px del dock',font=font,fill='white')
d.text((20,515),'Escala física de captura: 1,25×',font=font,fill='white')
canvas.save(out/'comparison.png')
