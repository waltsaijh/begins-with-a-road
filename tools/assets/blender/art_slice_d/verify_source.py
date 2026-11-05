"""Blender: repeat-build stability, source preservation and door clearance."""
from pathlib import Path
import bpy, importlib.util, hashlib, json, subprocess
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('slice_d',HERE/'build.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def counts():
    return {kind:sum(x.name.startswith(m.P) for x in getattr(bpy.data,kind)) for kind in ['scenes','collections','objects','meshes','materials','actions']}
original=json.loads((HERE/'manifest.json').read_text())
for item in original.values():assert hashlib.sha256((m.REPO/item['source']).read_bytes()).hexdigest()==item['source_sha256']
m.build();first=counts();geometry=json.loads((HERE/'manifest.json').read_text())
m.CLIPS.clear();m.MODELS.clear();m.REST.clear();m.MANIFEST.clear()
m.build();second=counts()
assert first==second,(first,second)
assert geometry==json.loads((HERE/'manifest.json').read_text())
c=m.MODELS['barracks'];s=bpy.data.scenes[m.P+'barracks'];bpy.context.window.scene=s
m.select(c,'barracks','open_close')
doors=[o for o in c.objects if 'DoorLeaf' in m.name(o)]
others=[o for o in c.objects if o.type=='MESH' and o not in doors]
collisions=[]
def tree(o):
    return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons],all_triangles=False)
for f in range(1,74):
    s.frame_set(f);bpy.context.view_layer.update()
    for door in doors:
        a=tree(door)
        for other in others:
            if a.overlap(tree(other)):collisions.append([f,door.name,other.name])
    if tree(doors[0]).overlap(tree(doors[1])):collisions.append([f,'door','door'])
assert not collisions,collisions[:10]
report={'repeat_counts_first':first,'repeat_counts_second':second,'manifest_equal':True,'source_hashes_unchanged':True,'door_wall_surface_intersections':collisions,'door_frames_checked':73}
(HERE/'source-check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for key in m.IDS:
    r=subprocess.run([bpy.app.binary_path,'--background',str(HERE/key/'model.blend'),'--python',str(HERE/'build.py'),'--','--finalize-file'],capture_output=True,text=True)
    assert 'FINALIZED' in r.stdout,r.stdout+r.stderr
print('SOURCE_CHECK_PASS '+json.dumps(report),flush=True)
