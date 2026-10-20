"""Run after build_blocky_grunt.py in the same Blender MCP session."""
import bpy
import json
import math
import struct
import zlib
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/Windows/Desktop/begins-with-a-road')
ASSET = Path(globals().get('EXPORT_ASSET_DIRECTORY', ROOT / 'assets/models/enemies/blocky_grunt'))
FILE_STEM = globals().get('EXPORT_FILE_STEM', 'blocky_grunt')
ASSET.mkdir(parents=True, exist_ok=True)
studio = bpy.context.scene
source_collection = globals().get('EXPORT_SOURCE_COLLECTION')
if source_collection is None:
    source_collection = next(c for c in studio.collection.children if c.name.startswith('Blocky Grunt - Character'))
export_scene = bpy.data.scenes.new(globals().get('EXPORT_SCENE_NAME', 'Blocky Grunt - Game Export'))
export_scene.render.fps = 24
export_scene.frame_start = 1
export_scene.frame_end = 25
copied = {}
for obj in source_collection.objects:
    clone = obj.copy()
    if obj.data:
        clone.data = obj.data.copy()
    export_scene.collection.objects.link(clone)
    copied[obj] = clone
for source, clone in copied.items():
    if source.parent in copied:
        clone.parent = copied[source.parent]
    clone.name = source.name+' - Export'
bpy.context.window.scene = export_scene
export_scene.frame_set(1)

mat = bpy.data.materials.new(FILE_STEM+' Palette')
mat.use_nodes = True
shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
shader.inputs['Roughness'].default_value = 0.85
shader.inputs['Metallic'].default_value = 0.0
# A tiny atlas also works around Godot 4.7 dropping the vertex-colour material flag.
colours = []
for obj in export_scene.objects:
    if obj.type == 'MESH':
        for source_mat in obj.data.materials:
            node = next(n for n in source_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            rgba = tuple(round(v, 6) for v in node.inputs['Base Color'].default_value)
            if rgba not in colours:
                colours.append(rgba)
assert len(colours) <= 16
size = 64
def srgb8(value):
    return round(255*(12.92*value if value <= 0.0031308 else 1.055*value**(1/2.4)-0.055))
rows = []
for y in range(size):
    row = bytearray()
    for x in range(size):
        index = (y//16)*4+x//16
        rgba = colours[index] if index < len(colours) else (1, 1, 1, 1)
        row.extend([srgb8(v) for v in rgba[:3]]+[255])
    rows.append(b'\0'+row)
def chunk(kind, payload):
    return struct.pack('>I', len(payload))+kind+payload+struct.pack('>I', zlib.crc32(kind+payload)&0xffffffff)
atlas_path = ASSET/'palette.png'
atlas_path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b''))
texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(atlas_path), check_existing=True)
texture.image.reload()
texture.interpolation = next(i.identifier for i in texture.bl_rna.properties['interpolation'].enum_items if i.identifier.casefold() == 'closest')
mat.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
mesh_parents = {}
for obj in list(export_scene.objects):
    if obj.type != 'MESH':
        continue
    mesh = obj.data
    for old in list(mesh.uv_layers):
        mesh.uv_layers.remove(old)
    uv = mesh.uv_layers.new(name='PaletteUV')
    for poly in mesh.polygons:
        material = mesh.materials[poly.material_index]
        node = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        rgba = tuple(round(v, 6) for v in node.inputs['Base Color'].default_value)
        slot = colours.index(rgba)
        center = ((slot % 4+0.5)/4, 1-(slot//4+0.5)/4)
        for index in poly.loop_indices:
            uv.data[index].uv = center
    mesh.materials.clear()
    mesh.materials.append(mat)
    for poly in mesh.polygons:
        poly.material_index = 0
    mesh_parents.setdefault(obj.parent, []).append(obj)

# One mesh per moving group, one shared palette material.
for parent, objects in mesh_parents.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = parent.name.replace(' - Export', '')+'_Mesh'

rna = bpy.ops.export_scene.gltf.get_rna_type()
options = {
    'filepath': str(ASSET/(FILE_STEM+'.glb')),
    'use_selection': True,
    'use_active_scene': True,
    'export_animations': True,
    'export_frame_range': True,
    'export_force_sampling': True,
    'export_anim_scene_split_object': False,
    'export_extras': True,
    'export_cameras': False,
    'export_lights': False,
}
mode_values = [i.identifier for i in rna.properties['export_animation_mode'].enum_items]
options['export_animation_mode'] = next(v for v in mode_values if v.casefold() == 'scene')
print('Export format default:', rna.properties['export_format'].default)
for obj in export_scene.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(**{k:v for k,v in options.items() if k in rna.properties})

# Godot recognizes -loop during import; glTF itself has no loop flag.
import struct
glb_path = ASSET/(FILE_STEM+'.glb')
data = glb_path.read_bytes()
json_size, json_type = struct.unpack_from('<II', data, 12)
gltf = json.loads(data[20:20+json_size])
tail = bytearray(data[20+json_size:])
adjusted_inputs = set()
for animation in gltf.get('animations', []):
    animation['name'] = 'Walk-loop'
    animation.setdefault('extras', {})['loop'] = True
    for sampler in animation['samplers']:
        index = sampler['input']
        if index in adjusted_inputs:
            continue
        adjusted_inputs.add(index)
        accessor = gltf['accessors'][index]
        view = gltf['bufferViews'][accessor['bufferView']]
        offset = 8+view.get('byteOffset', 0)+accessor.get('byteOffset', 0)
        stride = view.get('byteStride', 4)
        start_time = struct.unpack_from('<f', tail, offset)[0]
        for frame in range(accessor['count']):
            time = struct.unpack_from('<f', tail, offset+frame*stride)[0]
            struct.pack_into('<f', tail, offset+frame*stride, time-start_time)
        accessor['min'] = [0.0]
        accessor['max'] = [accessor['max'][0]-start_time]
new_json = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
new_json += b' '*((-len(new_json)) % 4)
glb_path.write_bytes(struct.pack('<4sII', b'glTF', 2, 20+len(new_json)+len(tail))+struct.pack('<II',len(new_json),json_type)+new_json+tail)

triangles = 0
for obj in export_scene.objects:
    if obj.type == 'MESH':
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
print('Game export:', len(gltf.get('meshes', [])), 'meshes;', len(gltf.get('materials', [])), 'material;', triangles, 'triangles')
print('Animations:', [(a['name'], len(a['channels'])) for a in gltf.get('animations', [])])

bpy.context.window.scene = studio
studio.frame_set(1)
print('EXPORT_READY', glb_path)
