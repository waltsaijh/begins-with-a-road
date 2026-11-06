"""Tower-family geometry/staging helpers adapted from the existing Ballista art slice.
Imported by build.py; no modeling or deletion happens on import.
"""
from pathlib import Path
import bpy
import bmesh
import math
import json
import sys
from mathutils import Vector

HERE = Path(__file__).resolve().parent
PREFIX = 'BWAR_TF_'
PREVIEW = HERE / 'previews'
EXPORTS = HERE / 'exports'
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
    options=dict(filepath=str(EXPORTS/f'{letter.lower()}.glb'),
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
