"""Render the three troop variants together, then save the Blender source."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Windows/Desktop/begins-with-a-road')
DEST = ROOT/'assets/models/enemies/blocky_troops'
scene = bpy.data.scenes.new('Troops - Lineup')
bpy.context.window.scene = scene
scene.world = bpy.data.scenes['Blocky Grunt Studio'].world
scene.frame_set(1)
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 25

for kind, x in [('Soldier', 0.74), ('Quickfeet', 0), ('Heavy', -0.80)]:
    obj = bpy.data.objects.new(kind+' Preview', None)
    obj.instance_type = next(i.identifier for i in obj.bl_rna.properties['instance_type'].enum_items if i.identifier.casefold() == 'collection')
    obj.instance_collection = bpy.data.collections[kind+' - Character']
    scene.collection.objects.link(obj)
    obj.location.x = x


def point_at(obj, point):
    obj.rotation_euler = (Vector(point)-obj.location).to_track_quat('-Z', 'Y').to_euler()


def area(name, location, power, size, colour):
    light_type = next(i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items if i.identifier.casefold() == 'area')
    light = bpy.data.lights.new(name, light_type)
    light.energy = power
    light.size = size
    light.color = colour
    obj = bpy.data.objects.new(name, light)
    scene.collection.objects.link(obj)
    obj.location = location
    point_at(obj, (0, 0, 0.32))


area('Troops Key', (-2.5, 3.0, 3.7), 380, 3.0, (1.0, 0.91, 0.82))
area('Troops Fill', (2.8, 1.0, 2.5), 200, 3.0, (0.80, 0.88, 1.0))
area('Troops Rim', (1.5, -2.8, 3.4), 350, 2.0, (1.0, 0.97, 0.89))
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.003))
floor = bpy.context.object
floor.name = 'Troops Preview Ground'
floor.data.materials.append(bpy.data.materials['Preview - Pale Sage'])
camera = bpy.data.cameras.new('Troops Preview Camera')
camera.type = next(i.identifier for i in camera.bl_rna.properties['type'].enum_items if i.identifier.casefold() == 'ortho')
camera.ortho_scale = 2.62
cam = bpy.data.objects.new('Troops Preview Camera', camera)
scene.collection.objects.link(cam)
cam.location = (1.25, 4.6, 2.3)
point_at(cam, (0.02, 0, 0.31))
scene.camera = cam

text_mat = bpy.data.materials.new('Troop Preview Labels')
text_mat.use_nodes = True
shader = next(n for n in text_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
shader.inputs['Base Color'].default_value = (0.065, 0.12, 0.14, 1)
shader.inputs['Roughness'].default_value = 1
fonts = list((ROOT/'assets/fonts').rglob('*Medium.ttf'))
font = bpy.data.fonts.load(str(fonts[0])) if fonts else None
for title, x in [('SOLDIER', 0.74), ('QUICKFEET', 0), ('HEAVY', -0.76)]:
    text = bpy.data.curves.new(title+' Label', 'FONT')
    text.body = title
    text.size = 0.07
    text.align_x = next(i.identifier for i in text.bl_rna.properties['align_x'].enum_items if i.identifier.casefold() == 'center')
    if font:
        text.font = font
    obj = bpy.data.objects.new(title+' Label', text)
    scene.collection.objects.link(obj)
    obj.location = (x, 0.32, 0.005)
    obj.rotation_euler = cam.rotation_euler
    text.materials.append(text_mat)

scene.render.resolution_x = 1600
scene.render.resolution_y = 850
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = next(i.identifier for i in scene.render.image_settings.bl_rna.properties['file_format'].enum_items if i.identifier.casefold() == 'png')
scene.render.filepath = str(ROOT/'reports/assets/blocky_troops.png')
scene.render.film_transparent = False
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.overlay.show_overlays = False
            space.region_3d.view_rotation = cam.rotation_euler.to_quaternion()
            space.region_3d.view_location = (0.02, 0, 0.31)
            space.region_3d.view_distance = 3.3
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'source/blocky_troops.blend'), copy=True)
print('TROOP_PREVIEW_READY', scene.render.filepath)
