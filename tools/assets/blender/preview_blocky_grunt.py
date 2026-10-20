"""Make a studio preview and save the editable Blender source through MCP."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Windows/Desktop/begins-with-a-road')
ASSET = ROOT/'assets/models/enemies/blocky_grunt'
scene = bpy.data.scenes['Blocky Grunt Studio']
bpy.context.window.scene = scene
scene.frame_set(1)
studio = bpy.data.collections.new('Preview - Camera Lights Ground')
scene.collection.children.link(studio)


def choose(rna, prop, desired):
    return next(i.identifier for i in rna.bl_rna.properties[prop].enum_items
                if i.identifier.casefold() == desired.casefold())


def point_at(obj, point):
    obj.rotation_euler = (Vector(point)-obj.location).to_track_quat('-Z', 'Y').to_euler()


def area(name, location, power, size, color):
    kind = next(i.identifier for i in bpy.types.Light.bl_rna.properties['type'].enum_items if i.identifier.casefold() == 'area')
    light = bpy.data.lights.new(name, kind)
    light.energy = power
    light.shape = choose(light, 'shape', 'disk')
    light.size = size
    light.color = color
    obj = bpy.data.objects.new(name, light)
    studio.objects.link(obj)
    obj.location = location
    point_at(obj, (0, 0, 0.30))
    return obj


area('Preview - Key', (-1.0, 1.8, 2.0), 95, 1.25, (1.0, 0.90, 0.80))
area('Preview - Fill', (1.4, 0.5, 1.1), 50, 1.4, (0.78, 0.88, 1.0))
area('Preview - Rim', (0.5, -1.6, 1.8), 110, 1.0, (1.0, 0.97, 0.89))
world = bpy.data.worlds.new('Blocky Grunt Soft Sky')
world.use_nodes = True
background = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
background.inputs['Color'].default_value = (0.58, 0.67, 0.75, 1.0)
background.inputs['Strength'].default_value = 0.28
scene.world = world

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.003))
floor = bpy.context.object
floor.name = 'Preview - Ground'
for collection in list(floor.users_collection):
    collection.objects.unlink(floor)
studio.objects.link(floor)
mat = bpy.data.materials.new('Preview - Pale Sage')
mat.use_nodes = True
shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
shader.inputs['Base Color'].default_value = (0.56, 0.63, 0.62, 1)
shader.inputs['Roughness'].default_value = 1.0
floor.data.materials.append(mat)

camera = bpy.data.cameras.new('Preview - Orthographic Camera')
camera.type = choose(camera, 'type', 'ortho')
camera.ortho_scale = 1.03
obj = bpy.data.objects.new('Preview - Camera', camera)
studio.objects.link(obj)
obj.location = (1.05, 1.85, 1.15)
point_at(obj, (-0.045, 0.025, 0.328))
scene.camera = obj
scene.render.resolution_x = 1000
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = choose(scene.render.image_settings, 'file_format', 'png')
scene.render.filepath = str(ROOT/'reports/assets/blocky_grunt.png')
scene.render.film_transparent = False
(ROOT/'reports').mkdir(exist_ok=True)

# Start in a useful modelling view when the .blend is opened.
bpy.ops.object.select_all(action='DESELECT')
for character in scene.collection.children:
    if character.name.startswith('Blocky Grunt - Character'):
        for part in character.objects:
            part.select_set(True)
bpy.context.view_layer.objects.active = bpy.data.objects['BlockyGrunt']
for screen in bpy.data.screens:
    for editor in screen.areas:
        if editor.type == 'VIEW_3D':
            editor.spaces.active.region_3d.view_rotation = obj.rotation_euler.to_quaternion()
            editor.spaces.active.region_3d.view_distance = 1.25
            editor.spaces.active.region_3d.view_location = (-0.045, 0.025, 0.328)
            editor.spaces.active.overlay.show_overlays = False
bpy.ops.wm.save_as_mainfile(filepath=str(ASSET/'source/blocky_grunt.blend'), copy=True)
bpy.ops.render.render(write_still=True)
print('PREVIEW_READY', scene.render.filepath)
