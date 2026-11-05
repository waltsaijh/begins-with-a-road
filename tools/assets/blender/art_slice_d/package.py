"""Validate deliverables and package the six assets with their source dependencies."""
from pathlib import Path
import json,struct,hashlib,zipfile,re,binascii
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[3]
assets=REPO/'assets/models/towers/art_slice_d'
manifest=json.loads((HERE/'manifest.json').read_text())
clips=json.loads((HERE/'clips.json').read_text())
media=json.loads((HERE/'media-check.json').read_text())
for report in ['godot-check.json','godot-baked-check.json']:
    assert json.loads((HERE/report).read_text())['failures']==[]
check={}
for key in manifest:
    for p in [HERE/key/'model.blend',HERE/key/'build.py',HERE/key/'previews/static.png',assets/(key+'_visual.tscn'),assets/(key+'.glb.import')]:assert p.is_file(),p
    path=assets/(key+'.glb');raw=path.read_bytes();magic,version,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and length==len(raw)
    g=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
    assert {a['name'] for a in g['animations']}==set(clips[key])
    assert not any(g.get(k) for k in ['images','textures','skins','cameras'])
    assert all('uri' not in b for b in g['buffers'])
    assert all(not m.get('doubleSided',False) for m in g['materials'])
    assert (HERE/'godot_validation/assets/models/towers/art_slice_d'/path.name).read_bytes()==raw
    for derived in (assets/(key+'_meshes')).glob('*.res'):
        verified=HERE/'godot_validation/assets/models/towers/art_slice_d'/(key+'_meshes')/derived.name
        assert derived.read_bytes()==verified.read_bytes()
    data=(HERE/key/'previews/animation.png').read_bytes();off=8;count=0;seq=[];declared=0
    while off<len(data):
        size=struct.unpack_from('>I',data,off)[0];kind=data[off+4:off+8];payload=data[off+8:off+8+size]
        assert binascii.crc32(kind+payload)&0xffffffff==struct.unpack_from('>I',data,off+8+size)[0]
        if kind==b'acTL':declared=struct.unpack_from('>I',payload)[0]
        if kind==b'fcTL':count+=1
        if kind in [b'fcTL',b'fdAT']:seq.append(struct.unpack_from('>I',payload)[0])
        off+=size+12
    assert count==declared==media[key]['frames'];assert seq==list(range(len(seq)))
    check[key]={'clips':list(clips[key]),'materials':len(g['materials']),'meshes':len(g['meshes']),'surfaces':sum(len(m['primitives']) for m in g['meshes']),'glb_sha256':hashlib.sha256(raw).hexdigest(),'apng_crc_sequence_pass':True,'frames':count}
    source=REPO/manifest[key]['source'];assert hashlib.sha256(source.read_bytes()).hexdigest()==manifest[key]['source_sha256']
# Check all local markdown references in the deliverable documents.
for doc in [HERE/'model-spec.md',HERE/'preview-gallery.md']:
    for href in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
        if not href.startswith(('http:','https:','#')):assert (doc.parent/href.strip('<>')).exists(),(doc,href)
(HERE/'delivery-check.json').write_text(json.dumps(check,indent=2),encoding='utf-8')
paths=set()
for folder in [HERE,assets]:
    for p in folder.rglob('*'):
        if p.is_file() and not any(x in p.parts for x in ['.godot','__pycache__']) and p.suffix not in ['.blend1','.pyc']:paths.add(p)
for item in manifest.values():paths.add(REPO/item['source'])
paths.add(HERE.parent/'.gdignore')
destination=HERE.parent/'art_slice_d.zip'
with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(paths):z.write(p,p.relative_to(REPO))
with zipfile.ZipFile(destination) as z:assert z.testzip() is None
print('DELIVERY_PASS',len(paths),'files',destination.stat().st_size,'bytes')
