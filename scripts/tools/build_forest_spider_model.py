"""Keep Polyfork's authored animation on its official long/thin-leg remix."""
import copy
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/polyfork/spider-v1'
def read(name):
    blob = (OUT / name).read_bytes()
    length = struct.unpack_from('<I', blob, 12)[0]
    return json.loads(blob[20:20+length]), blob[28+length:]
variant, mesh = read('garden-orb-weaver-needle-variant.glb')
original, motion = read('garden-orb-weaver-original.glb')
blob = bytearray(mesh)
while len(blob) % 4: blob.append(0)
base = len(blob)
blob.extend(motion)
view_base = len(variant['bufferViews'])
accessor_base = len(variant['accessors'])
for v in original['bufferViews']:
    v = copy.deepcopy(v); v['buffer']=0; v['byteOffset']=v.get('byteOffset',0)+base
    variant['bufferViews'].append(v)
for a in original['accessors']:
    a=copy.deepcopy(a); a['bufferView']+=view_base
    variant['accessors'].append(a)
names={n.get('name'): i for i,n in enumerate(variant['nodes']) if n.get('name')}
variant['animations']=[]
for animation in original['animations']:
    a=copy.deepcopy(animation)
    for sampler in a['samplers']:
        sampler['input']+=accessor_base;sampler['output']+=accessor_base
    for c in a['channels']:
        old=original['nodes'][c['target']['node']]
        c['target']['node']=names[old['name']]
        new=variant['nodes'][c['target']['node']]
        if c['target']['path']!='translation': continue
        delta=[n-o for n,o in zip(new.get('translation',[0,0,0]),old.get('translation',[0,0,0]))]
        sampler=a['samplers'][c['sampler']]
        accessor=copy.deepcopy(variant['accessors'][sampler['output']])
        view=variant['bufferViews'][accessor['bufferView']]
        offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
        values=[struct.unpack_from('<3f',blob,offset+i*view.get('byteStride',12)) for i in range(accessor['count'])]
        while len(blob)%4:blob.append(0)
        start=len(blob)
        for v in values:blob.extend(struct.pack('<3f',*(x+d for x,d in zip(v,delta))))
        accessor['bufferView']=len(variant['bufferViews']);accessor['byteOffset']=0
        for key in ['min','max']:
            if key in accessor:accessor[key]=[x+d for x,d in zip(accessor[key],delta)]
        variant['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(values)*12})
        sampler['output']=len(variant['accessors']);variant['accessors'].append(accessor)
    variant['animations'].append(a)
variant['buffers']=[{'byteLength':len(blob)}]
variant.setdefault('asset',{})['extras']={'credit':'Garden orb weaver by Polyfork, CC BY 4.0','changes':'Official long-leg variant plus needle-leg/abdomen derivative documented in hunter-rig.json; authored Walk/Run retargeted with new rest translations.'}
encoded=json.dumps(variant,separators=(',',':')).encode()
encoded+=b' '*((-len(encoded))%4)
blob+=b'\0'*((-len(blob))%4)
(OUT/'garden-orb-weaver-animated.glb').write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(blob))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(blob),b'BIN\0')+blob)
print('Merged official geometry variant with Walk / Idle / Run and adjusted rest translations')
