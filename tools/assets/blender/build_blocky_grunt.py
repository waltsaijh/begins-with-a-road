"""Run inside Blender through MCP; builds an editable, rounded block grunt."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Windows/Desktop/begins-with-a-road')
ASSET = ROOT / 'assets/models/enemies/blocky_grunt'
ASSET.mkdir(parents=True, exist_ok=True)
(ASSET / 'source').mkdir(exist_ok=True)
(ASSET / 'source/.gdignore').write_text('', encoding='utf-8')

scene = bpy.data.scenes.new('Blocky Grunt Studio')
bpy.context.window.scene = scene
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 25
collection = bpy.data.collections.new('Blocky Grunt - Character')
scene.collection.children.link(collection)


def enum_value(rna, prop, wanted):
    values = {item.identifier.casefold(): item.identifier
              for item in rna.bl_rna.properties[prop].enum_items}
    for candidate in wanted:
        if candidate.casefold() in values:
            return values[candidate.casefold()]
    raise ValueError((prop, list(values)))


def material(name, hex_color, metallic=0.0, roughness=0.8):
    rgb = [int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgba = tuple(c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
                 for c in rgb) + (1.0,)
    mat = bpy.data.materials.new('BG - '+name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = rgba
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Metallic'].default_value = metallic
    return mat


palette = {
    'coat': material('Terracotta Coat', 'a16459'),
    'coat_dark': material('Coat Seams', '704b4c'),
    'coat_light': material('Collar and Cuffs', 'b17a6b'),
    'iron': material('Blue Grey Iron', '465361', 0.15, 0.65),
    'iron_edge': material('Helmet Rim', '63717a', 0.15, 0.65),
    'skin': material('Warm Sand Face', 'c8b596'),
    'leather': material('Dark Leather', '594c43'),
    'wood': material('Shield Wood', '896b50'),
    'wood_light': material('Shield Planks', '9b7f5e'),
    'wood_edge': material('Shield Rim', '6d5542'),
    'brass': material('Buckle and Rivets', 'aa9469', 0.25),
    'ivory': material('Spear Blade', 'e0d5b9', 0.10, 0.6),
    'shadow': material('Visor Shadow', '303c43'),
}


def rehome(obj):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def parent_keep(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def pivot(name, at, parent=None):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = at
    obj.empty_display_size = 0.035
    bpy.context.view_layer.update()
    if parent:
        parent_keep(obj, parent)
    return obj


def finish(obj, name, mat, radius, parent):
    obj.name = name
    rehome(obj)
    obj.data.materials.append(palette[mat])
    bevel = obj.modifiers.new('Small soft corners', 'BEVEL')
    bevel.width = radius
    bevel.segments = 3
    bevel.limit_method = enum_value(bevel, 'limit_method', ['angle'])
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    normal = obj.modifiers.new('Keep broad faces flat', 'WEIGHTED_NORMAL')
    normal.keep_sharp = True
    normal.weight = 50
    bpy.ops.object.modifier_apply(modifier=normal.name)
    bpy.context.view_layer.update()
    parent_keep(obj, parent)
    return obj


root = pivot('BlockyGrunt', (0, 0, 0))
root['description'] = 'Rounded block infantry based on the prototype red grunt'
root['forward'] = 'Blender +Y; exported Godot -Z'
root['nominal_height_m'] = 0.64
body = pivot('Body', (0, 0, 0), root)
left_leg = pivot('Leg_L', (-0.069, 0, 0.193), body)
right_leg = pivot('Leg_R', (0.069, 0, 0.193), body)
left_arm = pivot('Arm_L', (-0.169, 0, 0.375), body)
right_arm = pivot('Arm_R', (0.169, 0, 0.375), body)


def block(name, size, at, mat, radius=0.008, parent=body):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, min(radius, min(size)*0.45), parent)


# Broad cuboid forms: the bevel is confined to the edges, without subdivision.
block('Coat', (0.266, 0.191, 0.238), (0, 0, 0.300), 'coat', 0.018)
block('Coat_Hem', (0.258, 0.188, 0.040), (0, 0, 0.196), 'coat_dark', 0.008)
block('Belt', (0.270, 0.198, 0.029), (0, 0, 0.216), 'leather', 0.007)
block('Buckle', (0.045, 0.014, 0.037), (0, 0.104, 0.216), 'brass', 0.004)
block('Collar', (0.145, 0.140, 0.024), (0, 0, 0.420), 'coat_dark', 0.006)
block('Face', (0.218, 0.195, 0.183), (0, 0.012, 0.493), 'skin', 0.022)
block('Helmet_Cap', (0.243, 0.229, 0.090), (0, 0, 0.571), 'iron', 0.018)
block('Helmet_Brow', (0.250, 0.027, 0.029), (0, 0.115, 0.541), 'iron_edge', 0.006)
block('Helmet_Back', (0.228, 0.033, 0.091), (0, -0.097, 0.523), 'iron', 0.010)
for side in [-1, 1]:
    block('Helmet_Cheek_'+str(side), (0.026, 0.093, 0.069), (side*0.109, -0.038, 0.518), 'iron', 0.006)
block('Visor', (0.122, 0.012, 0.025), (0, 0.111, 0.506), 'shadow', 0.004)
block('Helmet_Red_Crest', (0.091, 0.154, 0.042), (0, -0.002, 0.623), 'coat', 0.008)

for side, leg, arm, suffix in [(-1, left_leg, left_arm, 'L'), (1, right_leg, right_arm, 'R')]:
    block('Greave_'+suffix, (0.090, 0.100, 0.145), (side*0.069, 0, 0.133), 'iron', 0.012, leg)
    block('Boot_'+suffix, (0.101, 0.147, 0.071), (side*0.069, 0.018, 0.0355), 'leather', 0.013, leg)
    block('Sleeve_'+suffix, (0.097, 0.124, 0.103), (side*0.170, 0, 0.354), 'coat', 0.014, arm)
    block('Cuff_'+suffix, (0.081, 0.086, 0.025), (side*0.174, 0.008, 0.300), 'coat_dark', 0.005, arm)
    block('Hand_'+suffix, (0.075, 0.083, 0.079), (side*0.174, 0.014, 0.260), 'skin', 0.014, arm)

# Rounded square shield: thick silhouette and a simple central red boss.
block('Shield_Rim', (0.244, 0.059, 0.262), (-0.214, 0.103, 0.293), 'wood_edge', 0.023, left_arm)
block('Shield_Face', (0.211, 0.019, 0.229), (-0.214, 0.138, 0.293), 'wood', 0.018, left_arm)
for x in [-0.070, 0.0, 0.070]:
    block('Shield_Plank_'+str(x), (0.061, 0.007, 0.207), (-0.214+x, 0.150, 0.293), 'wood_light' if x == 0 else 'wood', 0.004, left_arm)
block('Shield_Boss', (0.067, 0.032, 0.067), (-0.214, 0.166, 0.293), 'coat', 0.012, left_arm)
for x in [-0.082, 0.082]:
    for z in [-0.090, 0.090]:
        block('Shield_Rivet', (0.012, 0.010, 0.012), (-0.214+x, 0.153, 0.293+z), 'brass', 0.004, left_arm)

# Slight forward lean, as on the source grunt's spear.
a = Vector((0.176, -0.037, 0.136))
b = Vector((0.176, 0.127, 0.601))
shaft = block('Spear_Shaft', (0.018, 0.018, (b-a).length), (a+b)*0.5, 'wood_light', 0.003, right_arm)
shaft.rotation_mode = enum_value(shaft, 'rotation_mode', ['quaternion'])
shaft.rotation_quaternion = (b-a).to_track_quat('Z', 'Y')
direction = (b-a).normalized()
base = b-direction*0.010
tip = b+direction*0.082
across = Vector((0.033, 0, 0))
depth = Vector((0, 0.013, 0))
verts = [base-across, base+across, base+depth, base-depth, tip]
faces = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (0, 3, 1, 2)]
mesh = bpy.data.meshes.new('Spear Blade Geometry')
mesh.from_pydata(verts, [], faces)
mesh.update()
blade = bpy.data.objects.new('Spear_Blade', mesh)
collection.objects.link(blade)
blade.data.materials.append(palette['ivory'])
parent_keep(blade, right_arm)

# Rigid limb animation needs no skinning and remains editable in the source.
for frame in range(1, 26, 2):
    phase = (frame-1)/24*math.tau
    for limb, sign, amplitude in [(left_leg, 1, 0.30), (right_leg, -1, 0.30), (left_arm, -1, 0.10), (right_arm, 1, 0.14)]:
        limb.rotation_euler.x = sign*math.sin(phase)*amplitude
        limb.keyframe_insert(data_path='rotation_euler', frame=frame, group='Walk')
    body.location.z = 0.004*(1-math.cos(phase*2))*0.5
    body.keyframe_insert(data_path='location', frame=frame, group='Walk')
for obj in [body, left_leg, right_leg, left_arm, right_arm]:
    obj.animation_data.action.name = 'Walk_'+obj.name
scene.timeline_markers.new('Walk', frame=1)
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root

points = [obj.matrix_world @ Vector(corner) for obj in collection.objects if obj.type == 'MESH' for corner in obj.bound_box]
bounds = [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]
print('Built', len(collection.objects), 'objects; mesh triangles', sum(len(o.data.polygons) for o in collection.objects if o.type == 'MESH'))
print('World bounds:', bounds)
print('Blender version:', bpy.app.version_string)
print('glTF options:', [p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties if 'animation' in p.identifier or p.identifier in ['export_format', 'use_selection']])
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.overlay.show_overlays = False
            area.spaces.active.shading.color_type = enum_value(area.spaces.active.shading, 'color_type', ['material'])
            area.spaces.active.region_3d.view_distance = 1.25
            area.spaces.active.region_3d.view_location = (0, 0, 0.33)
