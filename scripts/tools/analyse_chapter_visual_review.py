"""Analyse each frame of chapter_visual_v55_review.gd; requires numpy, Pillow and ffmpeg.
Usage: python analyse_chapter_visual_review.py <capture directory>
Readback is linear HDR; convert to display sRGB before quantizing.
Frame differences flag candidates for visual review, not proof of a defect.
"""
from pathlib import Path
import numpy as np,json,subprocess,sys
from PIL import Image,ImageDraw
p=Path(sys.argv[1]).resolve()
rows=json.loads((p/'frames.json').read_text()); out=p/'analysis';out.mkdir(exist_ok=True)
video=subprocess.Popen(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s','640x360','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',str(out/'chapter-sweep.mp4')],stdin=subprocess.PIPE)
metrics=[];previous=None;segments={}
for row in rows:
 i=row['frame'];a=np.fromfile(p/f'{i:05d}.frame',dtype='<f2').reshape(360,640,3 if rows[0]['format']==14 else 4).astype(np.float32)[:,:,:3];a=np.clip(a,0,1)
 rgb=np.rint(np.where(a<=.0031308,12.92*a,1.055*a**(1/2.4)-.055)*255).astype('uint8')
 video.stdin.write(rgb.tobytes());seg=row['segment'];segments.setdefault(seg,[]).append(i)
 luma=rgb.mean(2)/255;diff=0 if previous is None or rows[i-1]['segment']!=seg else float(np.abs(luma-previous).mean());previous=luma
 metrics.append({'frame':i,'segment':seg,'mean':float(luma.mean()),'diff':diff,'black_fraction':float((luma<.018).mean())})
video.stdin.close();video.wait()
def frame(i):
 a=np.fromfile(p/f'{i:05d}.frame',dtype='<f2').reshape(360,640,3 if rows[0]['format']==14 else 4).astype(np.float32)[:,:,:3];a=np.clip(a,0,1)
 return Image.fromarray(np.rint(np.where(a<=.0031308,12.92*a,1.055*a**(1/2.4)-.055)*255).astype('uint8'))
for seg,indices in segments.items():
 selected=[indices[int(k*(len(indices)-1)/7)] for k in range(8)]
 sheet=Image.new('RGB',(1280,4*390),'#141414');d=ImageDraw.Draw(sheet)
 for k,i in enumerate(selected):
  x=(k%2)*640;y=(k//2)*390;sheet.paste(frame(i),(x,y));d.text((x+8,y+362),f'{seg} / frame {i}',fill='white')
 sheet.save(out/f'{seg}.jpg',quality=92)
flagged=sorted((m for m in metrics if m['diff']>0),key=lambda m:m['diff'],reverse=True)[:20]
for m in flagged[:8]:frame(m['frame']).save(out/f"flag-{m['frame']:05d}.png")
(out/'metrics.json').write_text(json.dumps({'frames':len(rows),'metrics':metrics,'largest_differences':flagged},indent=2))
print(json.dumps({'frames':len(rows),'segments':list(segments),'largest_differences':flagged[:12]},indent=2))
