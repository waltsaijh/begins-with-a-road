"""Assemble actual Blender frames; copy verified Godot outputs; no image synthesis."""
from pathlib import Path
import importlib.util,json,struct,zlib,shutil,zipfile
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[3]
RAW=REPO/'.godot/test-results/modeling/art_slice_d'
sp=importlib.util.spec_from_file_location('png_media',HERE/'media.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
clips=json.loads((HERE/'clips.json').read_text());gallery=['# Art Slice D','', '[規格與接入說明](model-spec.md)','', '![統一上色](previews/Family7.2.png)','']
media_report={}
for key,entries in clips.items():
    out=HERE/key/'previews';frames=sorted((RAW/key).glob('*.png'));m.apng(frames,out/'animation.png',12)
    media_report[key]={'frames':len(frames),'fps':12,'preview_seconds':len(frames)/12,'source':'Blender render'}
    gallery += ['## '+key.replace('_',' ').title(),'',f'[Blender]({key}/model.blend) · [Python]({key}/build.py)','',f'![動畫]({key}/previews/animation.png)','']
    for title in entries:
        files=sorted(p for p in out.glob(title+'_*.png') if p.stem.rsplit('_',1)[-1].isdigit())
        assert 5<=len(files)<=6,(key,title,files)
        # The 25-frame clips share their final recovery sample with frame 25.
        # Repeat that settled pose as the sixth panel; never invent a new pose.
        if len(files)==5:files.append(files[-1])
        images=[m.decode(p) for p in files];w,h,c=images[0][:3];raw=bytearray()
        for row in range(2):
            for y in range(h):
                raw.append(0)
                for col in range(3):raw.extend(images[row*3+col][3][y])
        header=struct.pack('>IIBBBBB',w*3,h*2,8,6 if c==4 else 2,0,0,0)
        with (out/(title+'_keyframes.png')).open('wb') as f:
            f.write(m.SIGNATURE+m.chunk(b'IHDR',header))
            for kind,payload in images[0][4][1:]:
                if kind==b'IDAT':break
                f.write(m.chunk(kind,payload))
            f.write(m.chunk(b'IDAT',zlib.compress(raw,6))+m.chunk(b'IEND',b''))
        gallery += [f'[{title} 關鍵影格]({key}/previews/{title}_keyframes.png)','']
    (HERE/key/'build.py').write_text('''"""Rebuild the six-asset source set, including this tower; preserves prior rounds.
All implementation and source dependencies are documented in ../model-spec.md.
"""
from pathlib import Path
import runpy,sys
p=Path(__file__).resolve().parent.parent/'build.py'
sys.argv=[str(p),'--','--build','--finalize']
runpy.run_path(str(p),run_name='__main__')
''',encoding='utf-8')
(HERE/'preview-gallery.md').write_text('\n'.join(gallery),encoding='utf-8')
(HERE/'media-check.json').write_text(json.dumps(media_report,indent=2),encoding='utf-8')
project=HERE/'godot_validation'
for n in ['godot-check.json','godot-baked-check.json','bake-check.json']:
    shutil.copyfile(project/n,HERE/n)
for n in ['godot_family.png','godot_game_scale.png']:shutil.copyfile(project/n,HERE/'previews'/n)
src=project/'assets/models/towers/art_slice_d';dst=REPO/'assets/models/towers/art_slice_d'
for p in src.rglob('*'):
    if p.is_file() and (p.suffix in ['.res','.tscn','.import']):
        target=dst/p.relative_to(src);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
print('ASSEMBLED',media_report)
