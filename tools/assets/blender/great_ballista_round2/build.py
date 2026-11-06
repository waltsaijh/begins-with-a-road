"""C Detailed: two-color and restrained attack study, isolated from round one.

Requires the sibling great_ballista_slice source script and C .blend.
MCP: exec this file with __name__='__main__', BWAR_ACTION='build', __file__ set.
CLI: blender --background --python build.py -- --build --finalize
     blender --background model.blend --python build.py -- --render
"""
from pathlib import Path
import importlib.util
import bpy
import math
import json
import re
import sys
import subprocess
import hashlib
from mathutils import Vector

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'great_ballista_slice'
PREFIX='BWAR_GB2_'
PREVIEWS=HERE/'previews'
RAW=HERE.parents[3]/'.godot/test-results/modeling/great_ballista_round2'
MAIN='#DFD9CE'
DARK='#465155'
KEYS=[(1,'IDLE'),(26,'WIND-UP'),(32,'FIRE'),(47,'RECOVER'),(59,'RELOAD'),(72,'IDLE / RETURN')]

spec=importlib.util.spec_from_file_location('bwar_round1_helpers',SOURCE/'build.py')
h=importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
h.PREFIX=PREFIX
h.HERE=HERE
h.PREVIEW=PREVIEWS


def clean():
    # Helper owns only BWAR_GB2_, never the prior round or user's file.
    h.clean_owned()
    for action in list(bpy.data.actions):
        if action.name.startswith(PREFIX) and action.users==0:
            bpy.data.actions.remove(action)


def append_c():
    previous_mats=set(bpy.data.materials)
    with bpy.data.libraries.load(str(SOURCE/'exports/great_ballista_c.blend')) as (src,dst):
        dst.collections=['BWAR_GB_C_MODEL']
    col=dst.collections[0]
    col.name=PREFIX+'MODEL'
    for o in col.objects:
        old=re.sub(r'\.\d{3}$','',o.name)
        o.name=old.replace('BWAR_GB_C_',PREFIX)
        if o.data:
            o.data.name=o.name+'_mesh'
        if o.type=='MESH':
            old_dark=any('dark' in m.name for m in o.data.materials if m)
            o.data.materials.clear()
            o.data.materials.append(h.MATERIALS['dark' if old_dark or 'ChannelBed' in o.name else 'ivory'])
    for m in list(bpy.data.materials):
        if m not in previous_mats and not m.name.startswith(PREFIX) and m.users==0:
            bpy.data.materials.remove(m)
    return col


def obj(name):
    return bpy.data.objects[PREFIX+name]


def parent_keep(o,parent):
    world=o.matrix_world.copy()
    o.parent=parent
    o.matrix_world=world


def clone_static(col,name,white=False):
    result=h.collection(name)
    mapping={}
    worlds={o:o.matrix_world.copy() for o in col.objects}
    for o in col.objects:
        copy=o.copy()
        copy.name=PREFIX+name+'_'+o.name.removeprefix(PREFIX)
        copy.animation_data_clear()
        result.objects.link(copy)
        mapping[o]=copy
        if white and o.type=='MESH':
            copy.data=o.data.copy()
            copy.data.name=copy.name+'_mesh'
            copy.data.materials.clear()
            copy.data.materials.append(h.MATERIALS['ivory'])
    for o,c in mapping.items():
        c.parent=mapping.get(o.parent)
        c.matrix_world=worlds[o]
    return result


def key(o,path,frame):
    o.keyframe_insert(data_path=path,frame=frame,group='Attack preview')
    if o.animation_data and o.animation_data.action:
        o.animation_data.action.name=PREFIX+o.name.removeprefix(PREFIX)+'_Attack'


def lerp_points(frame,points):
    for i in range(len(points)-1):
        a,v=points[i];b,w=points[i+1]
        if frame<=b:
            t=max(0,min(1,(frame-a)/(b-a)))
            # Smooth timing for draw/recovery; the release uses short segments.
            t=t*t*(3-2*t)
            return v+(w-v)*t
    return points[-1][1]


def place_line(o,start,end,original_length):
    a,b=Vector(start),Vector(end)
    o.location=(a+b)/2
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    o.scale.z=(b-a).length/original_length


def animate(scene,col):
    scene.frame_set(1)
    bpy.context.view_layer.update()
    mount=obj('WeaponMount')
    slider=h.empty(col,'Slider',mount)
    bolt=h.empty(col,'BoltCarrier',mount)
    for name in ('Latch','LatchCheek1','LatchCheek-1'):
        parent_keep(obj(name),slider)
    for o in list(col.objects):
        if o.name.startswith(PREFIX+'ReadyBolt'):
            parent_keep(o,bolt)
    pivots={}
    for side in (-1,1):
        pivot=h.empty(col,'LimbPivot'+str(side),mount,(side*.185,.09,.72))
        bpy.context.view_layer.update()
        parent_keep(obj('BowLimb'+str(side)),pivot)
        pivots[side]=pivot
    scene.frame_start=1
    scene.frame_end=72
    scene.render.fps=24
    for frame,title in [(1,'Idle'),(9,'Wind-up'),(29,'Hold'),(30,'Fire'),(34,'Recover'),(55,'Reload'),(65,'Idle')]:
        scene.timeline_markers.new(title,frame=frame)
    # Read local mesh length, not the world AABB of the rotated string.
    original_lengths={s:max(v.co.z for v in obj('BowString'+str(s)).data.vertices)-min(v.co.z for v in obj('BowString'+str(s)).data.vertices) for s in (-1,1)}
    link=obj('TensionLink')
    link_length=max(v.co.z for v in link.data.vertices)-min(v.co.z for v in link.data.vertices)
    draw_keys=[(1,0),(8,0),(26,.24),(29,.24),(32,-.10),(35,.015),(43,0),(72,0)]
    flex_keys=[(1,0),(8,0),(26,5),(29,5),(32,-1.5),(37,.35),(44,0),(72,0)]
    recoil_keys=[(1,0),(29,0),(32,-.07),(35,-.055),(48,0),(72,0)]
    for frame in range(1,73):
        draw=lerp_points(frame,draw_keys)
        flex=lerp_points(frame,flex_keys)
        recoil=lerp_points(frame,recoil_keys)
        mount.location.y=recoil
        mount.rotation_euler.x=0
        slider.location.y=-draw
        for side,pivot in pivots.items():
            pivot.rotation_euler.z=-side*math.radians(flex)
            # Small lateral compliance under the socket cover keeps the
            # flexed limb inside the original one-cell weapon envelope.
            pivot.location.x=side*(.185-.012*max(flex,0)/5)
        if frame<=29:
            bolt.location=(0,-draw,0)
        elif frame<=39:
            bolt.location=(0,-.24+(frame-29)*.43,0)
        else:
            bolt.location=(0,0,0)
        # Preview-only replenishment: no loading character or new FX system.
        visible=frame<=39 or frame>=59
        for o in col.objects:
            if o.name.startswith(PREFIX+'ReadyBolt'):
                o.hide_render=not visible
                o.hide_viewport=not visible
                key(o,'hide_render',frame)
                key(o,'hide_viewport',frame)
        for o in [mount,slider,bolt,*pivots.values()]:
            key(o,'location',frame)
            key(o,'rotation_euler',frame)
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for side,pivot in pivots.items():
            # Limb endpoint, transformed about its actual socket pivot.
            anchor=Vector((side*.185,.09,.72))
            tip=Vector((side*.467,.375,.735))
            endpoint=Vector(pivot.location)+pivot.rotation_euler.to_matrix()@(tip-anchor)
            start=Vector((0,-.69-draw,.735))
            string=obj('BowString'+str(side))
            place_line(string,endpoint,start,original_lengths[side])
            for path in ('location','rotation_euler','scale'):
                key(string,path,frame)
        # Winch link follows the draw block, instead of floating behind it.
        place_line(link,(0,-1.13-recoil,.46),(0,-.73-draw,.70),link_length)
        for path in ('location','rotation_euler','scale'):
            key(link,path,frame)
    scene.frame_set(1)
    bpy.context.view_layer.update()


def scene_with_model(name,col,angle=30,height=3.35,res=(1100,1000),title=None):
    scene=h.configure_scene(name)
    scene.frame_end=72
    scene.render.fps=24
    scene.collection.children.link(col)
    preview=h.stage(scene,name)
    h.make_camera(scene,preview,(.35,-.5,.35),azimuth=angle,height=height,resolution=res)
    if title:
        h.label(preview,scene,title,0,height*.40,height*.035)
    return scene,preview


def build():
    HERE.mkdir(parents=True,exist_ok=True)
    PREVIEWS.mkdir(exist_ok=True)
    RAW.mkdir(parents=True,exist_ok=True)
    before={o.name:tuple(v for row in o.matrix_world for v in row) for o in bpy.data.objects if not o.name.startswith(PREFIX)}
    clean()
    h.MATERIALS.clear()
    for k,c in [('ivory',MAIN),('dark',DARK),('floor','#A6B6BC'),('ink','#34454D'),('road','#CAB99A')]:
        h.MATERIALS[k]=h.material(k,c)
    model=append_c()
    hero,hero_col=scene_with_model('Hero',model,title='GREAT BALLISTA / C / TWO-COLOR STUDY')
    bpy.context.window.scene=hero
    bpy.context.view_layer.update()
    white=clone_static(model,'WhiteControl',white=True)
    alt,_=scene_with_model('Alternate',model,angle=120,title='C / FUNCTIONAL COLOR / AZIMUTH 120')
    close,close_col=scene_with_model('Attack',model,height=4.25,res=(900,800))
    h.label(close_col,close,'GREAT BALLISTA / ATTACK STUDY',0,1.77,.12)
    h.label(close_col,close,'IDLE',0,-1.82,.095).name=PREFIX+'ClosePhase'
    # Match source camera elevation/azimuth, then preserve the real game span.
    game,game_col=scene_with_model('Game',model,height=18.5,res=(1280,800))
    h.label(game_col,game,'GAME SCALE / HEIGHT 18.5 / 1280 x 800',0,6.1,.23)
    h.label(game_col,game,'IDLE',0,-2.25,.23).name=PREFIX+'GamePhase'
    for y in (-2,2):
        h.box(game_col,'RoadH'+str(y),(0,y,-.009),(8,.64,.028),h.MATERIALS['road'])
    for x in (-3,3):
        h.box(game_col,'RoadV'+str(x),(x,0,-.009),(.64,4,.028),h.MATERIALS['road'])
    compare=h.configure_scene('ColorComparison')
    comp_col=h.stage(compare,'ColorComparison')
    h.make_camera(compare,comp_col,(.35,-.5,.35),height=3.65,resolution=(1800,1000))
    right=Vector((math.cos(math.radians(30)),math.sin(math.radians(30)),0))
    h.instance(comp_col,'WhiteDisplay',white,right*-1.55)
    h.instance(comp_col,'ColorDisplay',model,right*1.55)
    h.label(comp_col,compare,'WHITE CONTROL',-1.55,1.40,.13)
    h.label(comp_col,compare,'FUNCTIONAL TWO-COLOR',1.55,1.40,.13)
    h.label(comp_col,compare,'SAME C GEOMETRY / SAME LIGHT / SAME CAMERA',0,-1.55,.065)
    bpy.context.window.scene=hero
    animate(hero,model)
    scenes=[hero,alt,close,game,compare]
    for s in scenes:
        s.frame_set(1)
    bpy.context.window.scene=hero
    bpy.context.view_layer.update()
    stats=h.statistics(model)
    stats.update({'source_sha256':hashlib.sha256((SOURCE/'exports/great_ballista_c.blend').read_bytes()).hexdigest(),
                  'materials':{'main':MAIN,'functional_dark':DARK},
                  'animation':{'frames':72,'fps':24,'draw_units':.24,'upper_recoil_units':.07,'max_limb_flex_degrees':5,'reload_frame':59},
                  'non_round2_objects_unchanged':before=={o.name:tuple(v for row in o.matrix_world for v in row) for o in bpy.data.objects if not o.name.startswith(PREFIX)}})
    (HERE/'inspection.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(HERE/'model.blend'),set(scenes),fake_user=True)
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
    print('BWAR2_BUILD '+json.dumps(stats))


def phase(frame):
    return 'IDLE' if frame<9 or frame>=65 else 'WIND-UP' if frame<29 else 'FIRE' if frame<34 else 'RECOVER' if frame<55 else 'RELOAD'


def render_one(scene,frame,path,phase_label=None):
    bpy.context.window.scene=scene
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    if phase_label:
        bpy.data.objects[PREFIX+phase_label].data.body=phase(frame)
    scene.render.filepath=str(path)
    bpy.ops.render.render(scene=scene.name,write_still=True)


def render_stills():
    PREVIEWS.mkdir(exist_ok=True)
    for name,file in [('Hero','static_30.png'),('Alternate','static_120.png'),('ColorComparison','color_comparison.png'),('Game','game_scale.png')]:
        render_one(bpy.data.scenes[PREFIX+name],1,PREVIEWS/file)
        print('BWAR2_STILL '+file,flush=True)
    close=bpy.data.scenes[PREFIX+'Attack']
    close.render.resolution_x=720
    close.render.resolution_y=640
    for frame,name in KEYS:
        render_one(close,frame,PREVIEWS/f'key_{frame:02d}.png','ClosePhase')
    print('BWAR2_STILLS_COMPLETE',flush=True)


def render_animation():
    for name,label,out in [('Attack','ClosePhase','close'),('Game','GamePhase','game')]:
        s=bpy.data.scenes[PREFIX+name]
        if name=='Attack':
            s.render.resolution_x=720
            s.render.resolution_y=640
        folder=RAW/out
        folder.mkdir(parents=True,exist_ok=True)
        # Full 3-second timing, sampled at 12 fps for a compact lossless APNG.
        for frame in range(1,73,2):
            render_one(s,frame,folder/f'{frame:03d}.png',label)
        print('BWAR2_ANIMATION_FRAMES '+out,flush=True)


def finalize_file():
    if Path(bpy.data.filepath).resolve()!=(HERE/'model.blend').resolve():
        raise RuntimeError('Not a round-two generated file')
    bpy.context.window.scene=bpy.data.scenes[PREFIX+'Hero']
    for s in list(bpy.data.scenes):
        if not s.name.startswith(PREFIX) and not len(s.objects):
            bpy.data.scenes.remove(s)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.shading.type='MATERIAL'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'model.blend'))
    print('BWAR2_FINALIZED',flush=True)


if __name__=='__main__':
    if globals().get('BWAR_ACTION')=='build' or '--build' in sys.argv:
        build()
    elif '--render-stills' in sys.argv:
        render_stills()
    elif '--render-animation' in sys.argv:
        render_animation()
    elif '--finalize-file' in sys.argv:
        finalize_file()
    if '--finalize' in sys.argv:
        subprocess.run([bpy.app.binary_path,'--background',str(HERE/'model.blend'),'--python',str(HERE/'build.py'),'--','--finalize-file'],check=True)
