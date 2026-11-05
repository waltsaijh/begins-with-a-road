"""Blender background geometry, GLB roundtrip and deterministic rebuild checks."""
from pathlib import Path
import bpy, json, importlib.util, hashlib
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sp=importlib.util.spec_from_file_location('family_build',HERE/'build.py')
m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
source=HERE.parent/'great_ballista_slice/exports/great_ballista_c.blend'
before_source=hashlib.sha256(source.read_bytes()).hexdigest()
baseline=json.loads((HERE/'inspection.json').read_text())
def inventory():
    return {kind:sum(x.name.startswith(m.PREFIX) for x in getattr(bpy.data,kind)) for kind in ['objects','meshes','materials','collections','scenes']}
old=inventory()
# The main scene is intentionally isolated; no user's original scene is rebuilt here.
host=bpy.data.scenes.new('VerificationHost'); bpy.context.window.scene=host
m.build()
new=inventory()
assert old==new,(old,new)
assert json.loads((HERE/'inspection.json').read_text())==baseline
assert hashlib.sha256(source.read_bytes()).hexdigest()==before_source
result={'repeat_counts_before':old,'repeat_counts_after':new,'repeat_geometry_equal':True,'ballista_source_unchanged':True,'roundtrip':{}}
for key in m.IDS:
    c=bpy.data.collections[m.PREFIX+key+'_MODEL']
    root=next(o for o in c.objects if o.parent is None)
    assert tuple(root.location)==(0,0,0) and tuple(root.scale)==(1,1,1)
    bad=0; duplicate=0
    for o in c.objects:
        assert o.animation_data is None
        assert o.matrix_world.determinant()>0
        if o.type!='MESH': continue
        o.data.calc_loop_triangles(); seen=set()
        for t in o.data.loop_triangles:
            bad+=t.area<1e-10
            signature=tuple(sorted(tuple(round(v,7) for v in o.data.vertices[i].co) for i in t.vertices))
            duplicate+=signature in seen; seen.add(signature)
    assert bad==duplicate==0
    s=bpy.data.scenes.new('Roundtrip_'+key); bpy.context.window.scene=s
    oldobjs=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(HERE/key/(key+'.glb')))
    bpy.context.view_layer.update()
    loaded=set(bpy.data.objects)-oldobjs
    pts=[o.matrix_world@v.co for o in loaded if o.type=='MESH' for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)]; hi=[max(v[i] for v in pts) for i in range(3)]
    error=max(abs(a-b) for a,b in zip(lo+hi,baseline[key]['bounds_min']+baseline[key]['bounds_max']))
    assert error<1e-5,(key,error)
    assert all(o.type in {'EMPTY','MESH'} for o in loaded)
    result['roundtrip'][key]={'bounds_max_error':error,'degenerate_triangles':bad,'duplicate_triangles_within_mesh':duplicate,'positive_determinants':True,'root_identity':True}
    for o in loaded: bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.scenes.remove(s)
(HERE/'validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('FAMILY_VERIFY '+json.dumps(result),flush=True)
