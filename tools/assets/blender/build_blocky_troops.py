"""Build three editable troop variants from the live Blocky Grunt collection."""
import bpy
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path('D:/Windows/Desktop/begins-with-a-road')
DEST = ROOT/'assets/models/enemies/blocky_troops'
DEST.mkdir(parents=True, exist_ok=True)
(DEST/'source').mkdir(exist_ok=True)
(DEST/'source/.gdignore').write_text('', encoding='utf-8')
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
original = bpy.data.collections['Blocky Grunt - Character']
original_scene = bpy.context.scene
original_scene.frame_set(1)


def colour_material(name, hex_colour):
    rgb = [int(hex_colour[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgba = tuple(c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4 for c in rgb)+(1.0,)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = rgba
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = rgba
    node.inputs['Roughness'].default_value = 0.8
    return mat


def paint(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.material_index = 0


def box(name, dimensions, at, mat, parent, collection, radius=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    paint(obj, mat)
    bevel = obj.modifiers.new('Rounded block edges', 'BEVEL')
    bevel.width = min(radius, min(dimensions)*0.45)
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in obj.data.polygons:
        face.use_smooth = True
    normals = obj.modifiers.new('Broad flat faces', 'WEIGHTED_NORMAL')
    normals.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=normals.name)
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj


def resize(obj, factors):
    obj.data.transform(Matrix.Diagonal((*factors, 1.0)))
    obj.data.update()


def move(obj, delta):
    obj.location += Vector(delta)


def set_world(obj, at):
    world = obj.matrix_world.copy()
    world.translation = Vector(at)
    obj.matrix_world = world
    bpy.context.view_layer.update()


def delete_matching(parts, prefix):
    for key in list(parts):
        if key.startswith(prefix):
            bpy.data.objects.remove(parts.pop(key), do_unlink=True)


variants = {}
for kind in ['soldier', 'quickfeet', 'heavy']:
    title = kind.title()
    scene = bpy.data.scenes.new(title+' - Editable')
    scene.world = original_scene.world
    scene.render.fps = 24
    scene.frame_start = 1
    scene.frame_end = 25
    collection = bpy.data.collections.new(title+' - Character')
    scene.collection.children.link(collection)
    parts = {}
    mapping = {}
    for source in original.objects:
        clone = source.copy()
        if source.data:
            clone.data = source.data.copy()
        if source.animation_data and source.animation_data.action:
            clone.animation_data.action = source.animation_data.action.copy()
        collection.objects.link(clone)
        clone.name = title+'_'+source.name
        parts[source.name] = clone
        mapping[source] = clone
    for source, clone in mapping.items():
        if source.parent in mapping:
            clone.parent = mapping[source.parent]
    bpy.context.window.scene = scene
    scene.frame_set(1)
    bpy.context.view_layer.update()
    root, body = parts['BlockyGrunt'], parts['Body']
    root.name = title
    root['troop'] = kind
    root['forward'] = 'Blender +Y; Godot -Z'
    red = parts['Coat'].data.materials[0]
    red_dark = parts['Coat_Hem'].data.materials[0]
    iron = parts['Helmet_Cap'].data.materials[0]
    iron_edge = parts['Helmet_Brow'].data.materials[0]
    leather = parts['Belt'].data.materials[0]
    brass = parts['Buckle'].data.materials[0]
    ivory = parts['Spear_Blade'].data.materials[0]
    shadow = parts['Visor'].data.materials[0]

    if kind in ['soldier', 'quickfeet']:
        delete_matching(parts, 'Shield_')

    if kind == 'quickfeet':
        delete_matching(parts, 'Spear_')
        khaki = colour_material('Quickfeet - Khaki Shirt', 'b7a77b')
        khaki_dark = colour_material('Quickfeet - Khaki Cuffs', '998862')
        for key in ['Coat', 'Sleeve_L', 'Sleeve_R', 'Collar']:
            paint(parts[key], khaki)
        for key in ['Cuff_L', 'Cuff_R']:
            paint(parts[key], khaki_dark)
        for key in ['Greave_L', 'Greave_R']:
            paint(parts[key], red)
        paint(parts['Coat_Hem'], red)
        box(title+'_Overall_Bib', (0.178, 0.015, 0.112), (0, 0.101, 0.282), red, body, collection, 0.005)
        for side in [-1, 1]:
            x = side*0.066
            box(title+'_Front_Suspender', (0.028, 0.014, 0.103), (x, 0.103, 0.373), red, body, collection, 0.004)
            box(title+'_Back_Suspender', (0.028, 0.014, 0.196), (x, -0.102, 0.323), red, body, collection, 0.004)
            box(title+'_Shoulder_Suspender', (0.029, 0.205, 0.014), (x, 0, 0.422), red, body, collection, 0.004)
            box(title+'_Suspender_Button', (0.012, 0.009, 0.012), (x, 0.113, 0.333), brass, body, collection, 0.003)
        arm = parts['Arm_R']
        box(title+'_Knife_Grip', (0.024, 0.026, 0.067), (0.174, 0.078, 0.270), leather, arm, collection, 0.004)
        box(title+'_Knife_Guard', (0.063, 0.031, 0.014), (0.174, 0.078, 0.307), iron, arm, collection, 0.004)
        blade_verts = [(0.156, 0.071, 0.314), (0.192, 0.071, 0.314), (0.185, 0.071, 0.386), (0.170, 0.071, 0.421),
                       (0.156, 0.085, 0.314), (0.192, 0.085, 0.314), (0.185, 0.085, 0.386), (0.170, 0.085, 0.421)]
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        mesh = bpy.data.meshes.new(title+' Knife Blade')
        mesh.from_pydata(blade_verts, [], faces)
        mesh.update()
        blade = bpy.data.objects.new(title+'_Knife_Blade', mesh)
        collection.objects.link(blade)
        paint(blade, ivory)
        world = blade.matrix_world.copy()
        blade.parent = arm
        blade.matrix_world = world
        root.scale = (0.76, 0.85, 1.0)

    if kind == 'heavy':
        delete_matching(parts, 'Spear_')
        resize(parts['Coat'], (1.40, 1.32, 1.26))
        move(parts['Coat'], (0, 0, 0.045))
        for key in ['Belt', 'Coat_Hem']:
            resize(parts[key], (1.20, 1.22, 1.0))
        move(parts['Buckle'], (0, 0.024, 0))
        for key, obj in parts.items():
            if key.startswith('Helmet_') or key in ['Face', 'Visor', 'Collar']:
                move(obj, (0, 0, 0.090))
                resize(obj, (1.15, 1.12, 1.10))
        for side, suffix in [(-1, 'L'), (1, 'R')]:
            set_world(parts['Arm_'+suffix], (side*0.235, 0, 0.432))
            set_world(parts['Leg_'+suffix], (side*0.086, 0, 0.193))
            for key in ['Sleeve_'+suffix, 'Cuff_'+suffix, 'Hand_'+suffix]:
                resize(parts[key], (1.30, 1.22, 1.15))
            paint(parts['Sleeve_'+suffix], iron)
            paint(parts['Cuff_'+suffix], iron_edge)
            resize(parts['Greave_'+suffix], (1.18, 1.12, 1.0))
            resize(parts['Boot_'+suffix], (1.15, 1.12, 1.0))
            arm = parts['Arm_'+suffix]
            box(title+'_Pauldron_'+suffix, (0.171, 0.268, 0.111), (side*0.243, 0, 0.470), iron, arm, collection, 0.016)
            box(title+'_Pauldron_Rim_'+suffix, (0.181, 0.275, 0.025), (side*0.243, 0, 0.418), iron_edge, arm, collection, 0.006)
            box(title+'_Bracer_'+suffix, (0.113, 0.132, 0.098), (side*0.240, 0.010, 0.329), iron, arm, collection, 0.012)
        bpy.context.view_layer.update()
        box(title+'_Breastplate', (0.333, 0.046, 0.205), (0, 0.139, 0.382), iron, body, collection, 0.017)
        box(title+'_Backplate', (0.324, 0.036, 0.214), (0, -0.137, 0.379), iron, body, collection, 0.015)
        for z in [0.280, 0.315]:
            box(title+'_Abdominal_Plate', (0.308, 0.043, 0.039), (0, 0.139, z), iron_edge, body, collection, 0.008)
        box(title+'_Chest_Red_Stripe', (0.046, 0.012, 0.169), (0, 0.165, 0.390), red_dark, body, collection, 0.004)
        box(title+'_Helmet_Jaw', (0.249, 0.047, 0.099), (0, 0.126, 0.548), iron, body, collection, 0.012)
        box(title+'_Helmet_Neck_Guard', (0.258, 0.052, 0.104), (0, -0.112, 0.550), iron, body, collection, 0.012)
        for side in [-1, 1]:
            box(title+'_Helmet_Side_Armor', (0.039, 0.171, 0.144), (side*0.126, 0.009, 0.579), iron, body, collection, 0.010)
        set_world(parts['Visor'], (0, 0.151, 0.612))
        resize(parts['Visor'], (1.55, 1.0, 1.0))
        shield_center = parts['Shield_Rim'].matrix_world.translation.copy()
        transform = Matrix.Translation(shield_center) @ Matrix.Diagonal((1.20, 1.15, 1.25, 1.0)) @ Matrix.Translation(-shield_center)
        for key, obj in parts.items():
            if key.startswith('Shield_'):
                obj.data.transform(obj.matrix_world.inverted() @ transform @ obj.matrix_world)
                obj.data.update()
                if key == 'Shield_Rim':
                    paint(obj, iron)
                elif key == 'Shield_Face' or key.startswith('Shield_Plank'):
                    paint(obj, iron_edge)
        box(title+'_Shield_Central_Band', (0.039, 0.014, 0.264), (-0.280, 0.220, 0.350), red_dark, parts['Arm_L'], collection, 0.005)

    # Rebuild each copy's walk independently, retaining the source grunt's rig.
    animated = [body, parts['Leg_L'], parts['Leg_R'], parts['Arm_L'], parts['Arm_R']]
    for obj in animated:
        obj.animation_data_clear()
    stride = 0.42 if kind == 'quickfeet' else (0.23 if kind == 'heavy' else 0.30)
    arm_swing = 0.20 if kind == 'quickfeet' else (0.065 if kind == 'heavy' else 0.14)
    for frame in range(1, 26, 2):
        phase = (frame-1)/24*math.tau
        for key, sign in [('Leg_L', 1), ('Leg_R', -1), ('Arm_L', -1), ('Arm_R', 1)]:
            part = parts[key]
            part.rotation_euler.x = sign*math.sin(phase)*(stride if key.startswith('Leg') else arm_swing)
            part.keyframe_insert(data_path='rotation_euler', frame=frame, group='Walk')
        body.location.z = (0.005 if kind == 'quickfeet' else 0.003)*(1-math.cos(phase*2))*0.5
        body.keyframe_insert(data_path='location', frame=frame, group='Walk')
    for obj in animated:
        obj.animation_data.action.name = title+'_Walk_'+obj.name
    scene.frame_set(1)
    bpy.context.view_layer.update()
    variants[kind] = dict(scene=scene, collection=collection, root=root, parts=parts)
    points = [o.matrix_world @ Vector(v) for o in collection.objects if o.type == 'MESH' for v in o.bound_box]
    print('BUILT', kind, 'meshes', sum(o.type == 'MESH' for o in collection.objects), 'height', round(max(p.z for p in points), 3))

for kind, variant in variants.items():
    bpy.context.window.scene = variant['scene']
    namespace = {
        'EXPORT_ASSET_DIRECTORY': str(DEST/kind),
        'EXPORT_FILE_STEM': kind,
        'EXPORT_SOURCE_COLLECTION': variant['collection'],
        'EXPORT_SCENE_NAME': kind.title()+' - Game Export',
    }
    exec(compile((ROOT/'tools/assets/blender/export_blocky_grunt.py').read_text(encoding='utf-8'), 'export_blocky_grunt.py', 'exec'), namespace)
    variant['export_scene'] = namespace['export_scene']
print('TROOP_VARIANTS_READY')
