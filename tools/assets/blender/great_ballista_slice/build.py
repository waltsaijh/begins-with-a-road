"""Great Ballista art slice. Run in Blender's Python; no third-party packages.

Live MCP: exec(compile(Path(PATH).read_text(encoding='utf-8'), PATH, 'exec'),
               {'__name__': '__main__', 'BWAR_ACTION': 'build'})
Rebuild and save normal blend files: blender --background --python build.py -- --build --finalize-all
Background previews: blender --background model.blend --python build.py -- --render
Only BWAR_GB_* datablocks are owned. Unrelated scenes/objects are untouched.
"""
from pathlib import Path
import bpy
import bmesh
import math
import json
import sys
from mathutils import Vector

HERE = Path(__file__).resolve().parent if '__file__' in globals() else Path(r'D:/games/begins-with-a-road-routing/tools/assets/blender/great_ballista_slice')
PREFIX = 'BWAR_GB_'
PREVIEW = HERE / 'previews'
EXPORTS = HERE / 'exports'
VARIANTS = [('A', 'MINIMAL'), ('B', 'STRUCTURAL'), ('C', 'DETAILED')]
FOOTPRINT = [(0, 0), (0, 1), (1, 1)]
IVORY = '#D5CEC0'
DARK = '#424C50'
FLOOR = '#A6B6BC'
MATERIALS = {}


def linear(hex_color):
    h = hex_color.lstrip('#')
    rgb = [int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb) + (1,)


def material(key, color):
    m = bpy.data.materials.new(PREFIX + key)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = linear(color)
    p.inputs['Roughness'].default_value = .88
    p.inputs['Metallic'].default_value = 0
    m.diffuse_color = linear(color)
    return m


def clean_owned():
    # Never use select-all/delete or remove orphans from the user's file.
    for s in list(bpy.data.scenes):
        if s.name.startswith(PREFIX):
            bpy.data.scenes.remove(s)
    for o in list(bpy.data.objects):
        if o.name.startswith(PREFIX):
            bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        if c.name.startswith(PREFIX):
            bpy.data.collections.remove(c)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                       bpy.data.lights, bpy.data.curves, bpy.data.worlds):
        for block in list(datablocks):
            if block.name.startswith(PREFIX) and block.users == 0:
                datablocks.remove(block)


def collection(name):
    return bpy.data.collections.new(PREFIX + name)


def empty(col, name, parent=None, at=(0, 0, 0)):
    o = bpy.data.objects.new(PREFIX + name, None)
    col.objects.link(o)
    o.parent = parent
    o.location = at
    o.empty_display_size = .07
    return o


def mesh(col, name, verts, faces, mat, parent=None, bevel=0):
    data = bpy.data.meshes.new(PREFIX + name + '_mesh')
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    o = bpy.data.objects.new(PREFIX + name, data)
    col.objects.link(o)
    o.parent = parent
    data.materials.append(mat)
    if bevel:
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel,
                        segments=1, clamp_overlap=True)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
        bm.free()
        data.update()
    return o


def prism(col, name, polygon, bottom, top, mat, parent=None, bevel=0):
    n = len(polygon)
    vs = [(x, y, z) for z in (bottom, top) for x, y in polygon]
    fs = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    fs.extend((i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n))
    return mesh(col, name, vs, fs, mat, parent, bevel)


def box(col, name, at, dims, mat, parent=None, bevel=0):
    x, y, z = at
    a, b, c = (v / 2 for v in dims)
    return prism(col, name, [(x-a,y-b),(x+a,y-b),(x+a,y+b),(x-a,y+b)],
                 z-c, z+c, mat, parent, bevel)


def beam(col, name, start, end, width, mat, parent=None, depth=None):
    a, b = Vector(start), Vector(end)
    length = (b-a).length
    o = box(col, name, (0,0,0), (width, depth or width, length), mat, parent)
    o.location = (a+b)/2
    o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return o


def cylinder(col, name, at, radius, length, mat, parent=None, axis='Z', sides=8):
    pts = [(radius*math.cos(i*2*math.pi/sides), radius*math.sin(i*2*math.pi/sides)) for i in range(sides)]
    o = prism(col, name, pts, -length/2, length/2, mat, parent)
    o.location = at
    if axis == 'X':
        o.rotation_euler[1] = math.pi/2
    elif axis == 'Y':
        o.rotation_euler[0] = math.pi/2
    return o


def arm(col, name, side, parent, detail):
    # Same silhouette stations in all three models; width stays inside one cell.
    poly = [(side*x,y) for x,y in [(0.055,.015),(.24,.095),(.49,.325),(.465,.425),(.205,.245),(.055,.185)]]
    return prism(col, name, poly, .665, .795, MATERIALS['ivory'], parent, .009 if detail == 2 else 0)


def arrow(col, name, x, y, z, length, parent, detail=0):
    m = MATERIALS['dark']
    beam(col, name+'_shaft', (x,y-length/2,z), (x,y+length/2-.10,z), .026, m, parent)
    prism(col, name+'_head', [(x-.055,y+length/2-.14),(x+.055,y+length/2-.14),(x,y+length/2)], z-.018, z+.018, m, parent)
    if detail:
        # Fletching is functional; no painted markings or ornamental bands.
        prism(col, name+'_fletching', [(x-.045,y-length/2),(x+.045,y-length/2),(x+.025,y-length/2+.14),(x-.025,y-length/2+.14)], z-.014,z+.014,m,parent)


def make_model(letter, detail):
    col = collection(letter+'_MODEL')
    root = empty(col, letter+'_GreatBallista')
    root['footprint_godot'] = json.dumps(FOOTPRINT)
    root['forward_blender'] = '+Y'
    root['forward_godot'] = '-Z'
    root['logical_anchor'] = '(0,0)'
    root['art_slice_only'] = True
    base = empty(col, letter+'_FixedBase', root)
    weapon = empty(col, letter+'_WeaponMount', root)
    loader = empty(col, letter+'_LoadingBay', root)
    ivory, dark = MATERIALS['ivory'], MATERIALS['dark']
    chamfer = .022 if detail == 2 else 0
    # A long load-bearing sled, not a repeated floor/platform under every tile.
    box(col, letter+'_Chassis', (0,-.5,.12), (.76,1.78,.24), ivory, base, chamfer)
    for s in (-1,1):
        box(col, letter+f'_Support{s}', (s*.23,-.06,.405), (.135,.34,.33), ivory, base, chamfer*.65)
        box(col, letter+f'_RearSupport{s}', (s*.23,-1.04,.34), (.135,.25,.20), ivory, base, chamfer*.65)
    if detail == 0:
        box(col, letter+'_SingleTrack', (0,-.48,.59), (.235,1.87,.14), ivory, weapon)
    else:
        for s in (-1,1):
            box(col, letter+f'_OpenTrack{s}', (s*.085,-.48,.59), (.09,1.87,.14), ivory, weapon, .01 if detail == 2 else 0)
        # Lower surface of an actual open channel, not a dark overlay on a box.
        box(col, letter+'_ChannelBed', (0,-.48,.508), (.25,1.87,.032), ivory, weapon)
    box(col, letter+'_BowSaddle', (0,.08,.625), (.46,.23,.09), ivory, weapon, chamfer*.6)
    for s in (-1,1):
        arm(col, letter+f'_BowLimb{s}', s, weapon, detail)
        beam(col, letter+f'_BowString{s}', (s*.467,.375,.735), (0,-.69,.735), .010, dark, weapon)
    arrow(col, letter+'_ReadyBolt', 0, -.35,.71,1.68,weapon,detail > 0)
    box(col, letter+'_Latch', (0,-.69,.70), (.13,.12,.09), ivory, weapon, chamfer*.5)
    if detail == 0:
        box(col, letter+'_Winch', (0,-1.16,.405), (.36,.19,.16), ivory, base)
    else:
        cylinder(col, letter+'_WinchDrum', (0,-1.15,.40), .095,.32,dark,base,'X',8)
        for s in (-1,1):
            cylinder(col,letter+f'_WinchFlange{s}',(s*.18,-1.15,.40),.14,.055,ivory,base,'X',8)
            cylinder(col,letter+f'_LimbSocket{s}',(s*.185,.09,.72),.10,.16,ivory,weapon,'Z',8)
        beam(col,letter+'_TensionLink',(0,-1.13,.46),(0,-.73,.70),.025,dark,weapon)
        beam(col,letter+'_Crank',( .23,-1.15,.40),(.23,-1.25,.55),.045,ivory,base)
        beam(col,letter+'_CrankGrip',(.23,-1.25,.55),(.34,-1.25,.55),.045,dark,base)
    # Low functional ammunition rack in the third cell; same envelope in A/B/C.
    box(col,letter+'_RackFoot',(1,-1,.08),(.58,.66,.16),ivory,loader,chamfer)
    if detail == 0:
        box(col,letter+'_Rack',(1,-1,.22),(.50,.44,.15),ivory,loader)
    else:
        for y in (-1.21,-.79):
            box(col,letter+f'_RackCradle{y}',(1,y,.22),(.50,.06,.15),ivory,loader,chamfer*.5)
        for x in (.78,1.22):
            box(col,letter+f'_RackSide{x}',(x,-1,.17),(.06,.44,.08),ivory,loader,chamfer*.5)
    for i,x in enumerate((.84,1,1.16)):
        arrow(col,letter+f'_ReserveBolt{i}',x,-1,.315,.54,loader,detail > 0)
    if detail == 2:
        # Actual fork gap and visible transverse joint, no micro-rivets.
        cylinder(col,letter+'_FrontAxle',(0,-.06,.48),.058,.64,dark,base,'X',8)
        for s in (-1,1):
            cylinder(col,letter+f'_AxleCollar{s}',(s*.32,-.06,.48),.085,.045,ivory,base,'X',8)
            # Two cheeks with open space between: structural thickness is real.
            box(col,letter+f'_LatchCheek{s}',(s*.087,-.69,.72),(.035,.17,.10),ivory,weapon,.006)
        # Paired bearing cheeks leave a real open gap around the rear winch.
        for s in (-1,1):
            box(col,letter+f'_RearBearing{s}',(s*.22,-1.15,.295),(.09,.30,.11),ivory,base,.009)
    empty(col,letter+'_Muzzle',weapon,(0,.49,.71))
    empty(col,letter+'_WeaponUpgradeSocket',root,(0,-.48,.52))
    return col, root


def configure_scene(name):
    s = bpy.data.scenes.new(PREFIX+name)
    s.unit_settings.system = 'METRIC'
    s.unit_settings.scale_length = 1
    # Preserve default renderer rather than assume an enum from another release.
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.render.film_transparent = False
    s.render.fps = 24
    if hasattr(s, 'eevee') and hasattr(s.eevee, 'taa_render_samples'):
        s.eevee.taa_render_samples = 64
    s.world = bpy.data.worlds.new(PREFIX+name+'_World')
    s.world.use_nodes = True
    bg = next(n for n in s.world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = linear('#B7C7D0')
    bg.inputs['Strength'].default_value = .65
    return s


def make_camera(scene, col, focus, azimuth=30, height=3.45, resolution=(1000,900)):
    data = bpy.data.cameras.new(PREFIX+scene.name+'_Camera')
    data.type = 'ORTHO'
    camera = bpy.data.objects.new(data.name,data)
    col.objects.link(camera)
    a, e = math.radians(azimuth), math.radians(45)
    target = Vector(focus)
    camera.location = target+Vector((math.sin(a)*math.cos(e),-math.cos(a)*math.cos(e),math.sin(e)))*35
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera = camera
    scene.render.resolution_x,scene.render.resolution_y = resolution
    # Match vertical world span explicitly using camera.view_frame.
    data.ortho_scale = height
    frame = data.view_frame(scene=scene)
    data.ortho_scale *= height/(max(p.y for p in frame)-min(p.y for p in frame))
    camera['vertical_span'] = height
    return camera


def stage(scene, name):
    col = collection(name+'_PREVIEW')
    scene.collection.children.link(col)
    box(col,name+'_Backdrop',(0,0,-.065),(200,200,.1),MATERIALS['floor'])
    ld = bpy.data.lights.new(PREFIX+name+'_Sun','SUN')
    ld.energy = 2.1
    ld.angle = math.radians(12)
    ld.color = (1,.9411765,.8470588)
    light = bpy.data.objects.new(ld.name,ld)
    col.objects.link(light)
    # Godot sunlight -basis.z converted to Blender coordinate system.
    direction = Vector((.42261827,.5198368,-.74240386))
    light.rotation_euler = direction.to_track_quat('-Z','Y').to_euler()
    return col


def label(col, scene, text, x, y, size, color=None):
    data = bpy.data.curves.new(PREFIX+scene.name+'_'+text,'FONT')
    data.body = text
    data.size = size
    data.align_x = 'CENTER'
    obj = bpy.data.objects.new(data.name,data)
    col.objects.link(obj)
    camera = scene.camera
    obj.rotation_euler = camera.rotation_euler
    # Camera-aligned annotations sit in front of the model; never exported.
    obj.location = camera.location + camera.rotation_euler.to_matrix()@Vector((x,y,-30))
    data.materials.append(color or MATERIALS['ink'])
    return obj


def asset_scene(letter, title, model_col):
    scene = configure_scene(letter+'_'+title)
    scene.collection.children.link(model_col)
    preview = stage(scene,letter)
    make_camera(scene,preview,(.35,-.50,.35),height=3.35,resolution=(1100,1000))
    label(preview,scene,letter+'  /  '+title,0,1.31,.13)
    label(preview,scene,'GREAT BALLISTA   -   1 x 2 + LOADING BAY',0,-1.43,.052)
    return scene


def instance(col,name,model_col,at):
    obj = empty(col,name,at=at)
    obj.instance_type = 'COLLECTION'
    obj.instance_collection = model_col
    return obj


def build_comparison(models,azimuth=30):
    name='Comparison' if azimuth==30 else f'Comparison_{azimuth}'
    s = configure_scene(name)
    col = stage(s,name)
    make_camera(s,col,(.35,-.5,.35),azimuth=azimuth,height=3.6,resolution=(2100,900))
    right = Vector((math.cos(math.radians(azimuth)),math.sin(math.radians(azimuth)),0))
    for (letter,title),(model_col,_),shift in zip(VARIANTS,models,(-2.65,0,2.65)):
        instance(col,letter+'_Display',model_col,right*shift)
        label(col,s,letter+'  /  '+title,shift,1.39,.145)
    label(col,s,f'GREAT BALLISTA   /   GEOMETRY DENSITY STUDY   /   AZIMUTH {azimuth}',0,1.64,.075)
    label(col,s,'SAME FOOTPRINT   -   SAME PROPORTIONS   -   SAME MATERIALS   -   SAME ORTHOGRAPHIC VIEW',0,-1.58,.061)
    return s


def build_game_scale(models):
    s = configure_scene('GameScale')
    col = stage(s,'GameScale')
    make_camera(s,col,(0,0,0),height=18.5,resolution=(1280,800))
    for (letter,title),(model_col,_),shift in zip(VARIANTS,models,(-5,0,5)):
        # Layout translations are along camera-right, so scale and view match.
        right=Vector((math.cos(math.radians(30)),math.sin(math.radians(30)),0))
        instance(col,letter+'_GameDisplay',model_col,right*shift)
        label(col,s,letter+'  /  '+title,shift,1.55,.24)
    # Quiet maze-like context, display geometry only; not exported with models.
    roadmat=MATERIALS['road']
    for y in (-3,3):
        box(col,'ContextRoad'+str(y),(0,y,-.009),(16,.64,.028),roadmat)
    for x in (-7,7):
        box(col,'ContextTurn'+str(x),(x,0,-.009),(.64,6,.028),roadmat)
    label(col,s,'GAME SCALE / ORTHO HEIGHT 18.5 / 1280 x 800 / NO IMAGE RESIZING',0,6.7,.25)
    return s


def statistics(col):
    verts=[]
    tris=0
    meshes=0
    for o in col.objects:
        if o.type != 'MESH':
            continue
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        meshes += 1
        verts.extend(o.matrix_world@v.co for v in o.data.vertices)
    lo=[min(v[i] for v in verts) for i in range(3)]
    hi=[max(v[i] for v in verts) for i in range(3)]
    return {'triangles':tris,'mesh_objects':meshes,'materials':2,'bounds_min':lo,'bounds_max':hi,'size':[hi[i]-lo[i] for i in range(3)]}


def export_model(scene,col,letter):
    prior=bpy.context.window.scene if bpy.context.window else None
    if bpy.context.window:
        bpy.context.window.scene=scene
    for o in scene.objects:
        o.select_set(False)
    for o in col.objects:
        o.select_set(True)
    options=dict(filepath=str(EXPORTS/f'great_ballista_{letter.lower()}.glb'),
                 export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,
                 export_apply=True,export_animations=False,export_cameras=False,
                 export_lights=False,export_skins=False,export_morph=False,
                 export_normals=True,export_tangents=False,export_texcoords=False,
                 export_extras=True,export_materials='EXPORT')
    properties=bpy.ops.export_scene.gltf.get_rna_type().properties
    for key,value in options.items():
        if key not in properties:
            raise RuntimeError('Missing required glTF setting: '+key)
        prop=properties[key]
        if prop.type=='ENUM':
            identifiers=[item.identifier for item in prop.enum_items]
            if key=='export_format' and not identifiers:
                # Dynamic enum callbacks are not exposed through enum_items.
                import io_scene_gltf2
                identifiers=[item[0] for item in io_scene_gltf2.get_format_items(None,bpy.context)]
            if value not in identifiers:
                raise RuntimeError('Unsupported glTF enum: '+key+'='+str(value))
    bpy.ops.export_scene.gltf(**options)
    if prior is not None:
        bpy.context.window.scene=prior


def build():
    HERE.mkdir(parents=True,exist_ok=True)
    PREVIEW.mkdir(exist_ok=True)
    EXPORTS.mkdir(exist_ok=True)
    previous_scene=bpy.context.window.scene if bpy.context.window else None
    unrelated=[(o.name,o.type,tuple(o.location)) for o in bpy.data.objects if not o.name.startswith(PREFIX)]
    clean_owned()
    MATERIALS.clear()
    for key,color in [('ivory',IVORY),('dark',DARK),('floor',FLOOR),('ink','#34454D'),('road','#CAB99A')]:
        MATERIALS[key]=material(key,color)
    models=[make_model(letter,i) for i,(letter,_) in enumerate(VARIANTS)]
    scenes=[asset_scene(letter,title,model[0]) for (letter,title),model in zip(VARIANTS,models)]
    compare=build_comparison(models)
    directions=[build_comparison(models,angle) for angle in (120,210,300)]
    games=build_game_scale(models)
    if bpy.context.window:
        bpy.context.window.scene=compare
    bpy.context.view_layer.update()
    stats={letter:statistics(model[0]) for (letter,_),model in zip(VARIANTS,models)}
    for (letter,_),scene,(col,root) in zip(VARIANTS,scenes,models):
        export_model(scene,col,letter)
        bpy.data.libraries.write(str(EXPORTS/f'great_ballista_{letter.lower()}.blend'),{scene},fake_user=True)
    bpy.data.libraries.write(str(HERE/'model.blend'),set(scenes+[compare,games]+directions),fake_user=True)
    info={'blender':bpy.app.version_string,'footprint_godot':FOOTPRINT,'anchor':[0,0],
          'facing_godot':'-Z','facing_blender':'+Y','materials':{'ivory':IVORY,'dark':DARK},
          'camera':{'elevation':45,'azimuth':30,'portrait_vertical_span':3.35,'comparison_vertical_span':3.6,'game_vertical_span':18.5},
          'models':stats,'original_objects_unchanged':unrelated==[(o.name,o.type,tuple(o.location)) for o in bpy.data.objects if not o.name.startswith(PREFIX)]}
    (HERE/'inspection.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
    print('BWAR_BUILD '+json.dumps(info))
    if bpy.context.window:
        bpy.context.window.scene=compare
        for area in bpy.context.screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.type='MATERIAL'
    return info


def render_scene(scene,filename):
    scene.render.filepath=str(PREVIEW/filename)
    bpy.ops.render.render(write_still=True,scene=scene.name)
    print('BWAR_RENDER '+filename,flush=True)


def render():
    PREVIEW.mkdir(exist_ok=True)
    for letter,title in VARIANTS:
        render_scene(bpy.data.scenes[PREFIX+letter+'_'+title],letter.lower()+'_'+title.lower()+'.png')
    render_scene(bpy.data.scenes[PREFIX+'Comparison'],'comparison.png')
    game=bpy.data.scenes[PREFIX+'GameScale']
    render_scene(game,'game_scale.png')
    # Same game pixel density at farthest allowed zoom.
    render_game_far()
    # Each board uses camera-right layout at its azimuth; labels stay readable.
    for angle in (120,210,300):
        render_scene(bpy.data.scenes[PREFIX+f'Comparison_{angle}'],f'comparison_direction_{angle}.png')
    print('BWAR_RENDER_COMPLETE',flush=True)


def render_game_far():
    game=bpy.data.scenes[PREFIX+'GameScale']
    camera=game.camera
    old_scale=camera.data.ortho_scale
    title=next(o for o in game.objects if o.type=='FONT' and o.data.body.startswith('GAME SCALE'))
    old_title=title.data.body
    try:
        camera.data.ortho_scale=old_scale/.6
        title.data.body=old_title.replace('18.5','30.8333')
        render_scene(game,'game_scale_farthest.png')
    finally:
        camera.data.ortho_scale=old_scale
        title.data.body=old_title


def finalize_file():
    """Turn an isolated scene library into a normal, immediately openable file.

    Run only in a background subprocess opening a generated file. The live
    user's original file is never passed to this function.
    """
    path=Path(bpy.data.filepath).resolve()
    expected={HERE/'model.blend'} | {EXPORTS/f'great_ballista_{x.lower()}.blend' for x,_ in VARIANTS}
    if path not in {p.resolve() for p in expected}:
        raise RuntimeError('Refusing to finalize a non-slice file: '+str(path))
    target=bpy.data.scenes.get(PREFIX+'Comparison')
    if target is None:
        target=next(s for s in bpy.data.scenes if s.name.startswith(PREFIX))
    bpy.context.window.scene=target
    for s in list(bpy.data.scenes):
        if not s.name.startswith(PREFIX) and len(s.objects)==0:
            bpy.data.scenes.remove(s)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.type='MATERIAL'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print('BWAR_FINALIZE '+str(path),flush=True)


def finalize_all():
    import subprocess
    paths=[HERE/'model.blend']+[EXPORTS/f'great_ballista_{x.lower()}.blend' for x,_ in VARIANTS]
    for path in paths:
        proc=subprocess.run([bpy.app.binary_path,'--background',str(path),'--python',str(HERE/'build.py'),'--','--finalize-file'],capture_output=True,text=True)
        if proc.returncode or 'BWAR_FINALIZE' not in proc.stdout:
            raise RuntimeError(proc.stdout+'\n'+proc.stderr)
        print(proc.stdout[proc.stdout.index('BWAR_FINALIZE'):].splitlines()[0],flush=True)


if __name__ == '__main__':
    action=globals().get('BWAR_ACTION')
    if action=='build' or '--build' in sys.argv:
        build()
    elif action=='render' or '--render' in sys.argv:
        render()
    elif '--render-farthest' in sys.argv:
        render_game_far()
    elif '--finalize-file' in sys.argv:
        finalize_file()
    if '--finalize-all' in sys.argv:
        finalize_all()
