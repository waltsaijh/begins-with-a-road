"""Art Slice D. Existing geometry + functional palette + rigid TRS animation.
blender --background --python build.py -- --build --finalize
blender --background model.blend --python build.py -- --render
Only BWAR_D_ data are owned. No formal gameplay references are changed.
"""
from pathlib import Path
import bpy,math,json,sys,importlib.util,struct,subprocess,re,hashlib
from mathutils import Vector
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[3]
OUT=REPO/'assets/models/towers/art_slice_d'
RAW=REPO/'.godot/test-results/modeling/art_slice_d'
P='BWAR_D_'
spec=importlib.util.spec_from_file_location('d_geometry',HERE/'geometry.py')
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h);h.PREFIX=P
IDS=['great_ballista','watchtower','barracks','mortar','crossfire','broadside_airship']
CENTERS=[(.35,-.5),(0,0),(0,0),(-.5,-.5),(.5,.5),(0,-.5)]
CELLS=[[(0,0),(0,1),(1,1)],[(0,0)],[(0,0)],[(0,0),(-1,0),(-1,1),(0,1)],[(0,0),(1,0),(0,-1),(1,-1)],[(0,0),(0,1)]]
MATS={};CLIPS={};MODELS={};REST={};MANIFEST={}
def name(o):return o.name.split('__',1)[-1]
def get(c,n):return next(o for o in c.objects if name(o)==n)
def group(c,key,n,parent=None,at=(0,0,0)):
    o=bpy.data.objects.new(P+key+'__'+n,None);c.objects.link(o);o.parent=parent;o.location=at;return o
def keep(o,parent):
    bpy.context.view_layer.update();w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
def keyframe(o,frame):
    for path in ['location','rotation_euler','scale']:o.keyframe_insert(data_path=path,frame=frame)
def interp(f,points):
    for (a,v),(b,w) in zip(points,points[1:]):
        if f<=b:
            t=max(0,min(1,(f-a)/(b-a)));return v+(w-v)*t*t*(3-2*t)
    return points[-1][1]
def load_model(key):
    if key=='great_ballista':path=HERE.parent/'great_ballista_round2/model.blend';cn='BWAR_GB2_MODEL';old='BWAR_GB2_'
    else:path=HERE.parent/'tower_family'/key/'model.blend';cn='BWAR_TF_'+key+'_MODEL';old='BWAR_TF_'+key+'_'
    before=set(bpy.data.actions);before_mats=set(bpy.data.materials)
    with bpy.data.libraries.load(str(path)) as (src,dst):dst.collections=[cn]
    c=dst.collections[0];c.name=P+key+'_MODEL'
    for o in c.objects:
        n=re.sub(r'\.\d{3}$','',o.name).removeprefix(old)
        o.name=P+key+'__'+n
        if o.data:o.data.name=o.name+'_mesh'
    for a in set(bpy.data.actions)-before:a.name=P+key+'_SOURCE_'+a.name
    for mat in set(bpy.data.materials)-before_mats:mat.name=P+key+'_SOURCE_'+mat.name
    return c,path
def colors(c):
    for o in c.objects:
        if o.type!='MESH':continue
        n=name(o)
        prior=[m.name.lower() for m in o.data.materials]
        oldslots=list(o.data.materials);assign=[]
        for old in oldslots:
            dark='dark' in old.name.lower()
            role='dark' if dark or any(x in n for x in ['ChannelBed','String','Bolt','Window','InnerGate','RecessFloor']) else 'main'
            if role=='main' and any(x in n for x in ['Foot','Foundation','Chassis','LoadBearingBed','CruciformFoot','Dock','TrunnionCheek','Landing','AxleCollar','Saddle','RearSupport']):role='structure'
            if 'Latch'==n or n.startswith('DoorLeaf'):role='accent'
            assign.append(MATS[role])
        indices=[p.material_index for p in o.data.polygons]
        o.data.materials.clear()
        for mat in assign:o.data.materials.append(mat)
        for poly,index in zip(o.data.polygons,indices):poly.material_index=index
def stash_rest(c):
    for o in c.objects:REST[o.name]=(o.location.copy(),o.rotation_euler.copy(),o.scale.copy())
def reset(c):
    for o in c.objects:
        if o.animation_data:o.animation_data.action=None
        if o.name in REST:o.location,o.rotation_euler,o.scale=[x.copy() for x in REST[o.name]]
def clip(c,key,title,frames,objects,fn):
    reset(c)
    for o in objects:o.animation_data_create();o.animation_data.action=None
    for f in range(1,frames+1):
        fn(f)
        for o in objects:keyframe(o,f)
    acts={}
    for o in objects:
        a=o.animation_data.action;a.name=P+key+'__'+title+'__'+name(o);a.use_fake_user=True
        acts[o.name]=a.name
    CLIPS.setdefault(key,{})[title]={'frames':frames,'actions':acts}
    reset(c)
def ballista(s,c):
    # Sample the approved round-two actions rather than redesigning their timing.
    bpy.context.window.scene=s
    animated=[o for o in c.objects if o.animation_data and o.animation_data.action]
    samples={o.name:[] for o in animated if not name(o).startswith('ReadyBolt')}
    for f in range(1,73):
        s.frame_set(f);bpy.context.view_layer.update()
        for o in animated:
            if o.name in samples:samples[o.name].append((o.location.copy(),o.rotation_euler.copy(),o.scale.copy()))
    s.frame_set(1);bpy.context.view_layer.update()
    for o in c.objects:o.animation_data_clear();o.hide_render=False;o.hide_viewport=False
    stash_rest(c)
    bolt=get(c,'BoltCarrier')
    def apply(f):
        for n,ss in samples.items():
            o=bpy.data.objects[n];o.location,o.rotation_euler,o.scale=[v.copy() for v in ss[f-1]]
        if 40<=f<=58:bolt.scale=(.001,.001,.001)
    clip(c,'great_ballista','attack',72,[bpy.data.objects[n] for n in samples],apply)
    root=next(o for o in c.objects if o.parent is None)
    if not any(name(o)=='Muzzle' for o in c.objects):group(c,'great_ballista','Muzzle',get(c,'WeaponMount'),(0,.49,.71))
    stash_rest(c)
def prepare(c,key):
    root=next(o for o in c.objects if o.parent is None)
    if key=='watchtower':
        pivot=get(c,'AimPivot'); recoil=group(c,key,'RecoilAssembly',pivot)
        for o in list(pivot.children):
            if o!=recoil and name(o)!='UpgradeSocket':keep(o,recoil)
    if key=='barracks':
        # 0.30-wide entrance. Both leaves swing outward from a recessed hinge line.
        for side in [-1,1]:
            hinge=group(c,key,'DoorLeft' if side<0 else 'DoorRight',root,(side*.135,.235,.35))
            leaf=h.box(c,key+'__DoorLeaf'+str(side),(-side*.064,0,0),(.126,.025,.34),MATS['accent'],hinge,.006)
            leaf.name=P+key+'__DoorLeaf'+str(side)
    if key=='mortar':
        bed=group(c,key,'Suspension',root)
        for o in list(root.children):
            if o!=bed:keep(o,bed)
    if key=='broadside_airship':
        for side,bankname in [(-1,'Port'),(1,'Starboard')]:
            bank=get(c,bankname)
            for i in range(3):
                gun=get(c,'Cannon'+str((side,i)));pivot=group(c,key,bankname+'Gun'+str(i+1),bank)
                keep(gun,pivot);keep(get(c,'Muzzle'+str((side,i))),pivot)
    stash_rest(c)
    if key=='watchtower':
        o=get(c,'RecoilAssembly');r=o.location.copy()
        clip(c,key,'fire',25,[o],lambda f:setattr(o,'location',r+Vector((0,-interp(f,[(1,0),(5,0),(7,.065),(11,.045),(25,0)]),0))))
    elif key=='barracks':
        left=get(c,'DoorLeft');right=get(c,'DoorRight')
        def doors(f):
            ang=math.radians(interp(f,[(1,0),(7,0),(23,82),(43,82),(65,0),(73,0)]))
            left.rotation_euler.z=ang;right.rotation_euler.z=-ang
        clip(c,key,'open_close',73,[left,right],doors)
    elif key=='mortar':
        o=get(c,'RecoilAssembly');bed=get(c,'Suspension');r=o.location.copy();br=bed.location.copy()
        def mortar(f):
            t=interp(f,[(1,0),(7,0),(9,1),(14,.75),(37,0)])
            o.location=r+Vector((0,-.055,-.062))*t;bed.location=br+Vector((0,0,-.018*t))
        # Base stays in contact; only upper supports settle, not the floor contact mesh.
        keep(get(c,'LoadBearingBed'),root)
        stash_rest(c);clip(c,key,'fire',37,[o,bed],mortar)
    elif key=='crossfire':
        for i,(dx,dy,direction) in enumerate([(0,1,'north'),(1,0,'east'),(0,-1,'south'),(-1,0,'west')]):
            o=get(c,'RecoilAssembly'+str(i));r=o.location.copy()
            clip(c,key,'fire_'+direction,25,[o],lambda f,o=o,r=r,dx=dx,dy=dy:setattr(o,'location',r-Vector((dx,dy,0))*interp(f,[(1,0),(5,0),(7,.085),(11,.055),(25,0)])))
    elif key=='broadside_airship':
        for side,bank in [(-1,'Port'),(1,'Starboard')]:
            guns=[get(c,bank+'Gun'+str(i+1)) for i in range(3)];rests=[o.location.copy() for o in guns]
            def fire(f,guns=guns,rests=rests,side=side):
                for i,(o,r) in enumerate(zip(guns,rests)):
                    t=interp(f-i*2,[(1,0),(5,0),(7,.055),(12,.035),(27,0)])
                    o.location=r+Vector((-side*t,0,0))
            clip(c,key,'fire_'+bank.lower(),33,guns,fire)
    reset(c)
def select(c,key,title):
    reset(c)
    for n,a in CLIPS[key][title]['actions'].items():
        o=bpy.data.objects[n];o.animation_data_create();o.animation_data.action=bpy.data.actions[a]
    bpy.context.view_layer.update()
def orient_muzzles(c,key):
    for o in c.objects:
        n=name(o)
        if not ('Muzzle' in n or 'ArrowRelease' in n):continue
        direction=(0,1,0)
        if key=='mortar':direction=(0,.53,.60)
        elif key=='crossfire':direction=[(0,1,0),(1,0,0),(0,-1,0),(-1,0,0)][int(n[-1])]
        elif key=='broadside_airship':direction=(-1 if '(-1,' in n else 1,0,0)
        o.rotation_euler=Vector(direction).to_track_quat('Y','Z').to_euler()
        o['forward_godot']=list(Vector((direction[0],direction[2],-direction[1])).normalized())
    stash_rest(c)
def glb_read(path):
    raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);off=20+n;size=struct.unpack_from('<I',raw,off)[0];return g,raw[off+8:off+8+size]
def merge(files,dest):
    g,bb=glb_read(files[0]);blob=bytearray(bb)
    for path in files[1:]:
        gg,data=glb_read(path);mapping={};access={}
        for ani in gg.get('animations',[]):
            for sm in ani['samplers']:
                for field in ['input','output']:
                    old=sm[field]
                    if old not in access:
                        a=dict(gg['accessors'][old]);vi=a['bufferView']
                        if vi not in mapping:
                            v=dict(gg['bufferViews'][vi]);start=v.get('byteOffset',0);chunk=data[start:start+v['byteLength']]
                            while len(blob)%4:blob.append(0)
                            v['byteOffset']=len(blob);v['buffer']=0;blob.extend(chunk);mapping[vi]=len(g['bufferViews']);g['bufferViews'].append(v)
                        a['bufferView']=mapping[vi];access[old]=len(g['accessors']);g['accessors'].append(a)
                    sm[field]=access[old]
            names={n.get('name'):i for i,n in enumerate(g['nodes'])}
            for ch in ani['channels']:ch['target']['node']=names[gg['nodes'][ch['target']['node']]['name']]
            g.setdefault('animations',[]).append(ani)
    while len(blob)%4:blob.append(0)
    g['buffers'][0]['byteLength']=len(blob);j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
    raw=struct.pack('<4sII',b'glTF',2,28+len(j)+len(blob))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(blob),b'BIN\0')+blob
    dest.write_bytes(raw)
def export(s,c,key):
    bpy.context.window.scene=s;files=[]
    for o in s.objects:o.select_set(False)
    for o in c.objects:o.select_set(True)
    for title in CLIPS[key]:
        select(c,key,title);s.frame_start=1;s.frame_end=CLIPS[key][title]['frames'];s.frame_set(1)
        path=RAW/(key+'_'+title+'.glb')
        opts=dict(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name=title,export_force_sampling=True,export_frame_range=True,export_optimize_animation_size=False,export_skins=False,export_morph=False,export_cameras=False,export_lights=False,export_texcoords=False,export_normals=True,export_extras=True)
        props=bpy.ops.export_scene.gltf.get_rna_type().properties
        opts['export_anim_slide_to_zero']=True
        assert all(k in props for k in opts)
        bpy.ops.export_scene.gltf(**opts);files.append(path)
    merge(files,OUT/(key+'.glb'))
    select(c,key,next(iter(CLIPS[key])));s.frame_set(1)
def scene(key,c):
    s=h.configure_scene(key);s.render.fps=24;s.collection.children.link(c);p=h.stage(s,key)
    cx,cy=CENTERS[IDS.index(key)];h.make_camera(s,p,(cx,cy,.65),210,3.5,(720,640));h.label(p,s,key.replace('_',' ').upper(),0,1.42,.11)
    return s
def validate(s,c,key):
    data={};bpy.context.window.scene=s
    for title,info in CLIPS[key].items():
        select(c,key,title);s.frame_set(1);bpy.context.view_layer.update();first={o.name:o.matrix_local.copy() for o in c.objects};outside=0;below=0
        for f in range(1,info['frames']+1):
            s.frame_set(f);bpy.context.view_layer.update()
            for o in c.objects:
                if o.type!='MESH' or (key=='great_ballista' and name(o).startswith('ReadyBolt')):continue
                for v in o.data.vertices:
                    p=o.matrix_world@v.co
                    outside+=not any(abs(p.x-x)<=.5001 and abs(-p.y-z)<=.5001 for x,z in CELLS[IDS.index(key)])
                    below+=p.z<-.0001
        end=max(abs(o.matrix_local[i][j]-first[o.name][i][j]) for o in c.objects for i in range(4) for j in range(4))
        assert end<1e-5,(key,title,end)
        assert outside==0,(key,title,outside)
        assert below==0,(key,title,below)
        data[title]={'frames':info['frames'],'seconds':(info['frames']-1)/24,'reset_error':end,'body_outside_footprint_samples':outside,'below_floor_samples':below}
    select(c,key,next(iter(CLIPS[key])));s.frame_set(1);return data
def family(models,span=7.2,angle=210):
    s=h.configure_scene('Family'+str(span));p=h.stage(s,'Family'+str(span));h.make_camera(s,p,(0,0,.5),angle,span,(1800,1100) if span<10 else (1280,800));a=math.radians(angle)
    right=Vector((math.cos(a),math.sin(a),0));back=Vector((-math.sin(a),math.cos(a),0))
    for i,(key,c) in enumerate(models.items()):
        x=[-3.15,0,3.15][i%3];row=1.85 if i<3 else -1.85;cx,cy=CENTERS[i]
        o=h.empty(p,key+'Display',at=right*x+back*row/.7071-Vector((cx,cy,0)));o.instance_type='COLLECTION';o.instance_collection=c
        h.label(p,s,key.replace('_',' ').upper(),x,row-1.27,.11)
    h.label(p,s,'ART SLICE D / FUNCTIONAL COLOR',0,span*.44,.14)
    return s
def build():
    HERE.mkdir(exist_ok=True);OUT.mkdir(parents=True,exist_ok=True);RAW.mkdir(parents=True,exist_ok=True)
    if all(s.name.startswith(P) for s in bpy.data.scenes):
        bpy.context.window.scene=bpy.data.scenes.new('_SliceDRebuildHost')
    h.clean_owned()
    for blocks in (bpy.data.materials,bpy.data.meshes,bpy.data.actions):
        for block in list(blocks):
            if block.name.startswith(P):block.use_fake_user=False
            if block.name.startswith(P) and block.users==0:blocks.remove(block)
    for k,color in [('main','#D7D2C6'),('structure','#AAAFA8'),('dark','#48575C'),('accent','#B77C57'),('floor','#A6B6BC'),('ink','#34464E')]:
        MATS[k]=h.material(k,color)
        MATS[k].use_backface_culling=True
    h.MATERIALS.update(floor=MATS['floor'],ink=MATS['ink'])
    scenes=[]
    for key in IDS:
        path=HERE/key;(path/'previews').mkdir(parents=True,exist_ok=True)
        c,source=load_model(key);s=scene(key,c);bpy.context.window.scene=s;s.frame_set(1);bpy.context.view_layer.update()
        if key=='great_ballista':ballista(s,c)
        else:prepare(c,key)
        orient_muzzles(c,key);colors(c);MODELS[key]=c
        for mat in list(bpy.data.materials):
            if mat.name.startswith(P+key+'_SOURCE_'):
                mat.use_fake_user=False
                if mat.users==0:bpy.data.materials.remove(mat)
        tests=validate(s,c,key);export(s,c,key)
        (path/'clips.json').write_text(json.dumps(CLIPS[key],indent=2),encoding='utf-8')
        MANIFEST[key]={'source':str(source.relative_to(REPO)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'footprint':CELLS[IDS.index(key)],'clips':tests,'geometry':h.statistics(c),'muzzles':{name(o):list(o.matrix_world.translation) for o in c.objects if 'Muzzle' in name(o) or 'ArrowRelease' in name(o)}}
        MANIFEST[key]['geometry']['materials']=len({mat for o in c.objects if o.type=='MESH' for mat in o.data.materials})
        bpy.data.libraries.write(str(path/'model.blend'),{s},fake_user=True);scenes.append(s)
    for span in [7.2,18.5,30.833333]:scenes.append(family(MODELS,span,210 if span<10 else 30))
    (HERE/'clips.json').write_text(json.dumps(CLIPS,indent=2),encoding='utf-8');(HERE/'manifest.json').write_text(json.dumps(MANIFEST,indent=2),encoding='utf-8')
    if bpy.app.background:
        bpy.context.window.scene=scenes[-3]
        for s in list(bpy.data.scenes):
            if not s.name.startswith(P):
                for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
                bpy.data.scenes.remove(s)
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'model.blend'))
    print('SLICE_D_BUILT '+json.dumps(MANIFEST),flush=True)
def finalize_file():
    path=Path(bpy.data.filepath).resolve();assert path.parent==HERE or path.parent.parent==HERE
    bpy.context.window.scene=next(s for s in bpy.data.scenes if s.name.startswith(P))
    for s in list(bpy.data.scenes):
        if not s.name.startswith(P) and not s.objects:bpy.data.scenes.remove(s)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path));print('FINALIZED',flush=True)
def render():
    CLIPS.update(json.loads((HERE/'clips.json').read_text()))
    for key in IDS:
        s=bpy.data.scenes[P+key];c=bpy.data.collections[P+key+'_MODEL'];bpy.context.window.scene=s;s.frame_set(1);bpy.context.view_layer.update();stash_rest(c)
        for title,info in CLIPS[key].items():
            select(c,key,title)
            folder=HERE/key/'previews'
            for f in [1,7,9,17,25,info['frames']]:
                if key=='great_ballista':break
                if key=='barracks':break
                s.frame_set(min(f,info['frames']));s.render.filepath=str(folder/(title+f'_{f:02d}.png'));bpy.ops.render.render(write_still=True)
            if key in ['great_ballista','barracks']:
                for f in ([1,26,32,47,59,72] if key=='great_ballista' else [1,15,23,43,57,73]):
                    s.frame_set(f);s.render.filepath=str(folder/(title+f'_{f:02d}.png'));bpy.ops.render.render(write_still=True)
        select(c,key,next(iter(CLIPS[key])));s.frame_set(1);s.render.filepath=str(HERE/key/'previews/static.png');bpy.ops.render.render(write_still=True)
    (HERE/'previews').mkdir(exist_ok=True)
    for s in bpy.data.scenes:
        if s.name.startswith(P+'Family'):
            bpy.context.window.scene=s;s.frame_set(1);s.render.filepath=str(HERE/'previews'/(s.name.removeprefix(P)+'.png'));bpy.ops.render.render(write_still=True)
def render_animation():
    CLIPS.update(json.loads((HERE/'clips.json').read_text()))
    for key in IDS:
        s=bpy.data.scenes[P+key];c=bpy.data.collections[P+key+'_MODEL'];bpy.context.window.scene=s;s.frame_set(1);bpy.context.view_layer.update();stash_rest(c)
        s.render.resolution_x=640;s.render.resolution_y=560
        label=next(o for o in s.objects if o.type=='FONT')
        folder=RAW/key;folder.mkdir(exist_ok=True);index=0
        for title,info in CLIPS[key].items():
            select(c,key,title);label.data.body=key.replace('_',' ').upper()+' / '+title.upper()
            for f in range(1,info['frames']+1,2):
                s.frame_set(f);bpy.context.view_layer.update();s.render.filepath=str(folder/f'{index:03d}.png');bpy.ops.render.render(write_still=True);index+=1
        print('ANIMATION_RENDERED '+key+' '+str(index),flush=True)
if __name__=='__main__':
    if '--build' in sys.argv or globals().get('BWAR_ACTION')=='build':build()
    if '--finalize-file' in sys.argv:finalize_file()
    if '--finalize' in sys.argv:
        for key in IDS:
            r=subprocess.run([bpy.app.binary_path,'--background',str(HERE/key/'model.blend'),'--python',str(HERE/'build.py'),'--','--finalize-file'],capture_output=True,text=True)
            assert 'FINALIZED' in r.stdout,r.stdout+r.stderr
    if '--render' in sys.argv:render()
    if '--render-anim' in sys.argv:render_animation()
