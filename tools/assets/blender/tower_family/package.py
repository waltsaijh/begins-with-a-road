"""Create per-asset entry scripts, inspect GLB contents, and package this art slice.
Run with standard Python after Blender build/render. No third-party packages.
"""
from pathlib import Path
import json,struct,zipfile,hashlib
HERE=Path(__file__).resolve().parent
ids=['watchtower','barracks','mortar','crossfire','broadside_airship']
report={}
gallery=['# 防禦塔家族預覽','', '[完整設計與尺寸規格](model-spec.md)','', '![全塔比較](previews/family.png)','', '![反向比較](previews/family_210.png)','', '所有近景採相同尺度；遊戲圖為1280×800、正交跨度18.5，未裁切放大。','']
for key in ids:
    gallery += ['## '+key.replace('_',' ').title(),'',f'[Blender](<{key}/model.blend>) · [GLB](<{key}/{key}.glb>) · [Python](<{key}/build.py>)','',f'![30度](<{key}/previews/front.png>)','',f'![210度](<{key}/previews/rear.png>)','',f'[遊戲正交尺度](<{key}/previews/game.png>)','']
    (HERE/key/'build.py').write_text('''"""Build this tower with Blender --background --python build.py.
Shared modeling implementation lives in ../build.py and ../geometry.py.
"""
from pathlib import Path
import importlib.util
p=Path(__file__).resolve().parent.parent/'build.py'
s=importlib.util.spec_from_file_location('bwar_family',p)
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
m.build(%r)
m.finalize_all(%r)
'''%(key,key),encoding='utf-8')
    raw=(HERE/key/(key+'.glb')).read_bytes()
    magic,version,total=struct.unpack_from('<4sII',raw)
    size,kind=struct.unpack_from('<II',raw,12)
    gltf=json.loads(raw[20:20+size]); assert magic==b'glTF' and version==2 and total==len(raw)
    assert not gltf.get('animations') and not gltf.get('skins') and not gltf.get('images') and not gltf.get('textures') and not gltf.get('cameras')
    assert len(gltf['materials'])==2
    assert all('uri' not in x for x in gltf['buffers'])
    assert all('BWAR_TF_'+key in n.get('name','') for n in gltf['nodes'])
    tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
    vertices=sum(gltf['accessors'][p['attributes']['POSITION']]['count'] for m in gltf['meshes'] for p in m['primitives'])
    surfaces=sum(len(m['primitives']) for m in gltf['meshes'])
    report[key]={'triangles':tris,'export_vertices':vertices,'mesh_count':len(gltf['meshes']),'surfaces':surfaces,'materials':2,'nodes':len(gltf['nodes']),'animations':0,'textures':0,'external_dependencies':0,'sha256':hashlib.sha256(raw).hexdigest()}
(HERE/'glb-check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(HERE/'preview-gallery.md').write_text('\n'.join(gallery),encoding='utf-8')
source=HERE.parent/'great_ballista_slice/exports/great_ballista_c.glb'
(HERE/'reference-check.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'note':'Existing GLB imported only into comparison; no regeneration or source edits.'},indent=2),encoding='utf-8')
with zipfile.ZipFile(HERE.parent/'tower_family.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in HERE.rglob('*'):
        if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.blend1': z.write(p,p.relative_to(HERE.parent))
    z.write(source,source.relative_to(HERE.parent)); z.write(HERE.parent/'.gdignore','.gdignore')
with zipfile.ZipFile(HERE.parent/'tower_family.zip') as z: assert z.testzip() is None
print(json.dumps(report,indent=2)); print('ZIP CRC PASS')
