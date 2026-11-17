"""Build the Art Slice G towers in Blender from towers.py (same data the game uses).

    blender --background --factory-startup --python build_blender.py [-- sentry mortar ...]

Writes, for each tower:
  blend/<tower>.blend                         editable Blender file
  previews/<tower>.png                        quick render
  assets/models/towers/art_slice_g/<tower>.glb (only with --export; then rerun
  tools/assets/build_art_slice_g.gd in Godot to refresh the game visuals)
Edit towers.py / style.py to change designs; edits made by hand in a .blend are
not read back by the game pipeline.
"""
import bpy
import math
import sys
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(HERE))
import style    # noqa: E402
import towers   # noqa: E402

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
EXPORT = '--export' in ARGS
ONLY = [a for a in ARGS if not a.startswith('--')]


def material(key):
    name = 'BWAR_G_' + key
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    color = style.lin(style.PALETTE[key]) + [1.0]
    try:
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Roughness'].default_value = .9
        bsdf.inputs['Metallic'].default_value = 0
    except Exception:
        pass
    m.diffuse_color = color
    return m


def build(model):
    col = bpy.data.collections.new('BWAR_G_' + model.asset)
    bpy.context.scene.collection.children.link(col)
    objects = {}
    for n in model.nodes:
        data = None
        if n.geo is not None:
            data = bpy.data.meshes.new(n.name + '_mesh')
            data.from_pydata([tuple(v) for v in n.geo[0]], [], [tuple(f) for f in n.geo[1]])
            data.validate()
            data.update()
            data.materials.append(material(n.mat))
        o = bpy.data.objects.new(n.name, data)
        if data is None:
            o.empty_display_size = .06
        col.objects.link(o)
        if n.parent is not None:
            o.parent = objects[id(n.parent)]
        o.location, o.rotation_euler, o.scale = n.loc, n.rot, n.scale
        objects[id(n)] = o
    return col


def stage(asset):
    scene = bpy.context.scene
    for engine in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.view_settings.view_transform = 'Standard'
    scene.render.resolution_x, scene.render.resolution_y = 900, 800
    world = bpy.data.worlds.new('BWAR_G_World')
    try:
        world.use_nodes = True
        bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
        bg.inputs['Color'].default_value = style.lin('#B7C7D0') + [1.0]
        bg.inputs['Strength'].default_value = .7
    except Exception:
        world.color = style.lin('#B7C7D0')
    scene.world = world
    stage_col = bpy.data.collections.new('BWAR_G_STAGE')
    scene.collection.children.link(stage_col)
    me = bpy.data.meshes.new('BWAR_G_Ground')
    me.from_pydata([(-20, -20, -.002), (20, -20, -.002), (20, 20, -.002), (-20, 20, -.002)], [], [(0, 1, 2, 3)])
    me.materials.append(material('stone_dark'))
    stage_col.objects.link(bpy.data.objects.new('BWAR_G_Ground', me))
    sun = bpy.data.lights.new('BWAR_G_Sun', 'SUN')
    sun.energy, sun.angle, sun.color = 3.2, math.radians(10), (1, .95, .87)
    so = bpy.data.objects.new('BWAR_G_Sun', sun)
    stage_col.objects.link(so)
    so.rotation_euler = (math.radians(42), math.radians(-20), math.radians(35))
    cells = towers.FOOTPRINTS[asset]
    cx = sum(c[0] for c in cells) / len(cells)
    cy = sum(c[1] for c in cells) / len(cells)
    cam = bpy.data.cameras.new('BWAR_G_Camera')
    cam.type, cam.ortho_scale = 'ORTHO', 3.0
    co = bpy.data.objects.new('BWAR_G_Camera', cam)
    stage_col.objects.link(co)
    a, e = math.radians(210), math.radians(40)
    from mathutils import Vector
    focus = Vector((cx, cy, .6))
    co.location = focus + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * 20
    co.rotation_euler = (focus - co.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = co


def main():
    (HERE / 'blend').mkdir(exist_ok=True)
    (HERE / 'previews').mkdir(exist_ok=True)
    for asset, builder in towers.BUILDERS.items():
        if ONLY and asset not in ONLY:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        model = builder()
        build(model)
        print(asset, towers.check(model), flush=True)
        if EXPORT:
            bpy.ops.export_scene.gltf(filepath=str(REPO / 'assets/models/towers/art_slice_g' / f'{asset}.glb'),
                                      export_format='GLB', use_selection=False, export_yup=True,
                                      export_apply=False, export_cameras=False, export_lights=False)
        stage(asset)
        bpy.context.scene.render.filepath = str(HERE / 'previews' / f'{asset}.png')
        bpy.ops.render.render(write_still=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'blend' / f'{asset}.blend'))
    print('BUILD_OK', flush=True)


try:
    main()
except Exception:
    traceback.print_exc()
    sys.exit(1)
