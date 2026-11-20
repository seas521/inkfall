#!/usr/bin/env python3
"""Idempotently add only the hug group; preserve all accepted actor metadata."""
from pathlib import Path
import json, argparse
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--pack',default='artifacts/mine-heavy-hug-v1/hug-pack.json');args=parser.parse_args()
pack=json.loads((ROOT/args.pack).read_text())
p=ROOT/'scripts/actors/hood_actor_manifest.gd';lines=p.read_text().splitlines()
for i,line in enumerate(lines):
 if line.startswith('const CLIPS := '):
  d=json.loads(line.split(':= ',1)[1]);d.update({k:v['info'] for k,v in pack.items()});lines[i]='const CLIPS := '+json.dumps(d,separators=(',',':'))
 if line.startswith('const GROUPS := '):
  d=json.loads(line.split(':= ',1)[1]);d['hug']=list(pack);lines[i]='const GROUPS := '+json.dumps(d,separators=(',',':'))
p.write_text('\n'.join(lines)+'\n')
p=ROOT/'scripts/actors/hood_eye_tracks.gd';prefix,raw=p.read_text().split('const DATA := ',1);d=json.loads(raw);d.update({k:v['eyes'] for k,v in pack.items()});p.write_text(prefix+'const DATA := '+json.dumps(d,separators=(',',':'))+'\n')
p=ROOT/'scripts/actors/hood_actor_soles.gd';lines=[l for l in p.read_text().splitlines() if not any(l.lstrip().startswith(json.dumps(k)+':') for k in pack)]
s='\n'.join(lines)+'\n';end=s.rfind('}');s=s[:end]+''.join('\t'+json.dumps(k)+': '+json.dumps(v['soles'],separators=(',',':'))+',\n' for k,v in pack.items())+s[end:];p.write_text(s)
print('Registered hug group:',sum(v['info']['frames'] for v in pack.values()),'frames')
