from pathlib import Path
import shutil,json
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[3]
PROJECT=HERE/'godot_validation'
PROJECT.mkdir(exist_ok=True)
(PROJECT/'project.godot').write_text('config_version=5\n[application]\nconfig/name="BWAR Art Slice D Validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=800\n',encoding='utf-8')
files=list((REPO/'assets/models/towers/art_slice_d').glob('*.glb'))
files += list((REPO/'assets/models/towers/art_slice_d').glob('*.glb.import'))
files += [REPO/'assets/models/towers/art_slice_d/import_visual.gd']
files += [REPO/'tools/assets/solid_mesh_baker.gd',REPO/'assets/materials/solid_color.tres']
files += list((REPO/'assets/shaders').glob('solid_color*'))
for p in files:
    target=PROJECT/p.relative_to(REPO);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
for target in (PROJECT/'assets/models/towers/art_slice_d').glob('*.glb.import'):
    text=target.read_text(encoding='utf-8')
    text=text.replace('meshes/generate_lods=true','meshes/generate_lods=false').replace('meshes/ensure_tangents=true','meshes/ensure_tangents=false')
    text=text.replace('animation/fps=30','animation/fps=24').replace('import_script/path=""','import_script/path="res://assets/models/towers/art_slice_d/import_visual.gd"')
    target.write_text(text,encoding='utf-8')
shutil.copyfile(HERE/'validate.gd',PROJECT/'validate.gd')
shutil.copyfile(HERE/'manifest.json',PROJECT/'manifest.json')
print(PROJECT)
