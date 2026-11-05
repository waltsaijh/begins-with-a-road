"""Five static towers. Blender Python only. --build --finalize --render.
Each asset's build.py calls this shared deterministic builder with --asset.
Only BWAR_TF_ data are owned; existing user data and Ballista source are preserved.
"""
from pathlib import Path
import bpy, bmesh, math, json, sys, importlib.util, subprocess, hashlib
from mathutils import Vector
HERE=Path(__file__).resolve().parent
PREFIX='BWAR_TF_'
sp=importlib.util.spec_from_file_location('family_geometry',HERE/'geometry.py')
h=importlib.util.module_from_spec(sp); sp.loader.exec_module(h)
h.PREFIX=PREFIX
IDS=['watchtower','barracks','mortar','crossfire','broadside_airship']
TITLES=['WATCHTOWER','BARRACKS','MORTAR','CROSSFIRE','BROADSIDE AIRSHIP']
CELLS={'watchtower':[(0,0)],'barracks':[(0,0)],'mortar':[(0,0),(-1,0),(-1,1),(0,1)],'crossfire':[(0,0),(1,0),(0,-1),(1,-1)],'broadside_airship':[(0,0),(0,1)]}
CENTERS={'watchtower':(0,0),'barracks':(0,0),'mortar':(-.5,-.5),'crossfire':(.5,.5),'broadside_airship':(0,-.5)}
MODEL={}

class Builder:
    def __init__(self,key):
        self.key=key; self.col=h.collection(key+'_MODEL')
        self.root=h.empty(self.col,key+'_Model')
        self.root['footprint_godot']=json.dumps(CELLS[key]); self.root['forward_godot']='-Z'; self.root['art_slice_only']=True
        self.root['anchor']='(0,0,0)'; self.root['animation']='none'
        self.cx,self.cy=CENTERS[key]
        self.base=self.group('FixedBase'); self.p=self.base
    def group(self,n,parent=None,at=(0,0,0)):
        return h.empty(self.col,self.key+'_'+n,parent or self.root,at)
    def box(self,n,at,dims,dark=False,bevel=.015):
        return h.box(self.col,self.key+'_'+n,(at[0]+self.cx,at[1]+self.cy,at[2]),dims,h.MATERIALS['dark' if dark else 'ivory'],self.p,bevel)
    def cyl(self,n,at,r,length,dark=False,axis='Z',sides=12):
        return h.cylinder(self.col,self.key+'_'+n,(at[0]+self.cx,at[1]+self.cy,at[2]),r,length,h.MATERIALS['dark' if dark else 'ivory'],self.p,axis,sides)
    def beam(self,n,a,b,width,dark=False):
        a=Vector(a)+Vector((self.cx,self.cy,0)); b=Vector(b)+Vector((self.cx,self.cy,0))
        return h.beam(self.col,self.key+'_'+n,a,b,width,h.MATERIALS['dark' if dark else 'ivory'],self.p)
    def prism(self,n,poly,lo,hi,dark=False,bevel=.012):
        return h.prism(self.col,self.key+'_'+n,[(x+self.cx,y+self.cy) for x,y in poly],lo,hi,h.MATERIALS['dark' if dark else 'ivory'],self.p,bevel)
    def marker(self,n,at,parent=None):
        return self.group(n,parent or self.p,(at[0]+self.cx,at[1]+self.cy,at[2]))
    def tube(self,n,a,b,r,inner,sides=12):
        # Closed annular shell, actual bore walls and recessed breech; no black face decal.
        a=Vector(a)+Vector((self.cx,self.cy,0)); b=Vector(b)+Vector((self.cx,self.cy,0))
        length=(b-a).length; vs=[]
        for z,rr in [(0,r),(length,r),(length,inner),(.07,inner)]:
            vs.extend((rr*math.cos(i*math.tau/sides),rr*math.sin(i*math.tau/sides),z) for i in range(sides))
        fs=[]
        for band in range(3):
            for i in range(sides):
                j=(i+1)%sides; fs.append((band*sides+i,band*sides+j,(band+1)*sides+j,(band+1)*sides+i))
        fs.extend([tuple(reversed(range(sides))),tuple(range(3*sides,4*sides))])
        o=h.mesh(self.col,self.key+'_'+n,vs,fs,h.MATERIALS['ivory'],self.p)
        o.data.materials.append(h.MATERIALS['dark'])
        for poly in o.data.polygons:
            if 2*sides<=poly.index<3*sides or poly.index==3*sides+1: poly.material_index=1
        o.location=a; o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        return o
    def finish(self):
        # Set useful mechanical pivots without moving any authored geometry.
        bpy.context.view_layer.update()
        targets={'watchtower':{'AimPivot':(0,0,1.25)},'mortar':{'AimPivot':(0,0,.29),'RecoilAssembly':(0,-.03,.60)},'broadside_airship':{'Airship':(0,0,.74)}}.get(self.key,{})
        for name,at in targets.items():
            obj=next(o for o in self.col.objects if o.name==PREFIX+self.key+'_'+name)
            # Model collections are not linked to a scene yet; use parent-local transforms.
            delta=Vector((at[0]+self.cx,at[1]+self.cy,at[2]))
            parent_origin=Vector((0,0,0)) if obj.parent==self.root else obj.parent.location
            newloc=delta-parent_origin
            shift=newloc-obj.location
            obj.location=newloc
            for child in obj.children: child.location-=shift
        return self.col

def watchtower():
    b=Builder('watchtower')
    b.box('Foot',(0,0,.075),(.60,.62,.15),bevel=.035)
    for x in [-.18,.18]:
        for y in [-.18,.18]:
            b.beam(f'Leg{x}{y}',(x*1.35,y*1.35,.12),(x,y,1.12),.085)
    for y in [-.18,.18]: b.beam('CrossBrace'+str(y),(-.22,y,.29),(.18,y,1.02),.055)
    b.box('Landing',(0,0,1.12),(.68,.66,.13),bevel=.025)
    for x in [-.30,.30]: b.box('Parapet'+str(x),(x,0,1.29),(.08,.60,.23))
    b.box('RearGuard',(0,-.28,1.29),(.54,.08,.23))
    b.cyl('Turntable',(0,0,1.25),.17,.16,True)
    aim=b.group('AimPivot'); b.p=aim
    b.box('WeaponStock',(0,.04,1.40),(.13,.62,.12))
    b.prism('Bow',[(-.27,.16),(-.24,.23),(0,.14),(.24,.23),(.27,.16),(0,.06)],1.40,1.46)
    b.beam('String',(-.24,.19,1.44),(0,-.18,1.44),.012,True)
    b.beam('StringRight',(.24,.19,1.44),(0,-.18,1.44),.012,True)
    b.beam('Bolt',(0,-.20,1.48),(0,.40,1.48),.025,True)
    b.marker('ArrowRelease',(0,.40,1.48),aim)
    b.marker('UpgradeSocket',(0,0,1.30),aim)
    return b.finish()

def barracks():
    b=Builder('barracks')
    b.box('Foundation',(0,0,.075),(.88,.86,.15),bevel=.03)
    # Front has a genuine doorway and internal chamber, not a painted rectangle.
    for x in [-.31,.31]: b.box('Wall'+str(x),(x,0,.36),(.20,.78,.48),bevel=.022)
    b.box('BackWall',(0,-.30,.36),(.44,.18,.48),bevel=.022)
    for x in [-.275,.275]: b.box('GatePier'+str(x),(x,.32,.34),(.25,.16,.44))
    b.box('Lintel',(0,.32,.60),(.80,.18,.15))
    b.box('Ceiling',(0,0,.64),(.82,.80,.12),bevel=.025)
    b.box('RecessFloor',(0,.04,.16),(.38,.60,.025),True,0)
    b.box('InnerGate',(0,-.19,.37),(.38,.045,.37),True,.005)
    for x in [-.34,.34]:
        for y in [-.31,.31]: b.box('CornerGuard'+str((x,y)),(x,y,.78),(.20,.22,.22))
    for x in [-.36,.36]: b.box('SideParapet'+str(x),(x,0,.73),(.12,.40,.12))
    b.box('BackParapet',(0,-.34,.73),(.50,.12,.12))
    b.marker('DeploymentExit',(0,.46,.18)); b.marker('UpgradeSocket',(0,0,.70))
    return b.finish()

def mortar():
    b=Builder('mortar')
    poly=[(-.89,-.60),(-.60,-.89),(.60,-.89),(.89,-.60),(.89,.60),(.60,.89),(-.60,.89),(-.89,.60)]
    b.prism('LoadBearingBed',poly,0,.24,bevel=.035)
    b.cyl('Bearing',(0,0,.29),.62,.14,True)
    for x in [-.54,.54]:
        b.box('TrunnionCheek'+str(x),(x,-.03,.48),(.24,.72,.48),bevel=.05)
        b.cyl('Trunnion'+str(x),(x,-.03,.60),.15,.28,True,'X')
    aim=b.group('AimPivot'); recoil=b.group('RecoilAssembly',aim); b.p=recoil
    b.tube('ShortBore',(0,-.31,.45),(0,.22,1.05),.37,.265)
    b.marker('Muzzle0',(0,.22,1.05))
    b.p=b.base
    for x in [-.72,.72]: b.box('GroundBrace'+str(x),(x,.48,.27),(.24,.55,.24),bevel=.035)
    b.marker('UpgradeSocket',(0,-.45,.35),aim)
    return b.finish()

def crossfire():
    b=Builder('crossfire')
    # A single cross-shaped load path leaves the four corners as negative space.
    poly=[(-.29,-.90),(.29,-.90),(.29,-.29),(.90,-.29),(.90,.29),(.29,.29),(.29,.90),(-.29,.90),(-.29,.29),(-.90,.29),(-.90,-.29),(-.29,-.29)]
    b.prism('CruciformFoot',poly,0,.19,bevel=.025)
    b.cyl('CentralCore',(0,0,.42),.36,.46,sides=8)
    b.cyl('HubCap',(0,0,.70),.30,.14,sides=8)
    for i,(dx,dy) in enumerate([(0,1),(1,0),(0,-1),(-1,0)]):
        b.p=b.base
        b.box('ArmSaddle'+str(i),(dx*.59,dy*.59,.30),(.33 if dx==0 else .60,.60 if dx==0 else .33,.22))
        pivot=b.group('RecoilAssembly'+str(i)); b.p=pivot
        b.tube('RadialLauncher'+str(i),(dx*.24,dy*.24,.52),(dx*.93,dy*.93,.52),.145,.095,sides=8)
        b.marker('Muzzle'+str(i),(dx*.93,dy*.93,.52))
    b.marker('UpgradeSocket',(0,0,.77),b.root)
    return b.finish()

def broadside_airship():
    b=Builder('broadside_airship')
    for y in [-.52,.52]:
        b.box('DockFoot'+str(y),(0,y,.065),(.58,.26,.13),bevel=.03)
        b.box('DockCradle'+str(y),(0,y,.21),(.30,.18,.20))
    ship=b.group('Airship'); b.p=ship
    # Faceted boat hull: tapered prow and stern, deep keel; suspended from a rigid lifting envelope.
    sections=[(-.89,.05,.51),(-.68,.28,.43),(.48,.29,.43),(.90,.015,.62)]
    verts=[]
    for y,w,z in sections: verts.extend([(b.cx-w,b.cy+y,.74),(b.cx-w*.62,b.cy+y,z),(b.cx+w*.62,b.cy+y,z),(b.cx+w,b.cy+y,.74)])
    faces=[(3,2,1,0)]
    for j in range(len(sections)-1):
        for i in range(4): faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
    faces.append(tuple(range(12,16)))
    h.mesh(b.col,b.key+'_FacetedHull',verts,faces,h.MATERIALS['ivory'],ship)
    b.prism('Deck',[(-.25,-.69),(.25,-.69),(.28,.48),(0,.88),(-.28,.48)],.735,.79,bevel=.012)
    b.box('Bridge',(0,-.39,.88),(.30,.34,.20),bevel=.025)
    b.box('BridgeWindow',(0,-.211,.90),(.21,.025,.055),True,.005)
    # Narrow lifted envelope keeps total width including cannon tips within one cell.
    vs=[]; rings=[(-.82,.035),(-.62,.23),(-.30,.30),(.32,.30),(.64,.22),(.83,.025)]
    for y,r in rings:
        for i in range(8):
            t=i*math.tau/8; vs.append((b.cx+r*math.cos(t),b.cy+y,1.36+r*.82*math.sin(t)))
    fs=[tuple(reversed(range(8)))]
    for j in range(len(rings)-1):
        for i in range(8): fs.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
    fs.append(tuple(range(40,48)))
    h.mesh(b.col,b.key+'_LiftingHull',vs,fs,h.MATERIALS['ivory'],ship)
    for x in [-.21,.21]:
        for y in [-.46,.40]: b.beam('Suspension'+str((x,y)),(x,y,.77),(x,y,1.18),.035,True)
    # Vertical stern rudder and restrained stabilizers provide a clear vehicle orientation.
    b.box('TailFin',(0,-.73,1.37),(.035,.23,.50),bevel=.008)
    b.box('TailPlane',(0,-.70,1.34),(.78,.18,.04),bevel=.008)
    recoil=b.group('RecoilAssembly',ship)
    for side in [-1,1]:
        bank=b.group('Port' if side<0 else 'Starboard',recoil); bank['side']=side; b.p=bank
        for i,y in enumerate([-.50,0,.48]):
            b.tube('Cannon'+str((side,i)),(side*.22,y,.75),(side*.48,y,.75),.075,.045,sides=8)
            b.marker('Muzzle'+str((side,i)),(side*.48,y,.75))
    b.marker('UpgradeSocket',(0,-.35,.99),ship)
    return b.finish()

def init():
    h.clean_owned()
    for blocks in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights,bpy.data.curves,bpy.data.worlds):
        for block in list(blocks):
            if block.name.startswith(PREFIX):
                block.use_fake_user=False
                if block.users==0: blocks.remove(block)
    for k,color in [('ivory','#DFD9CE'),('dark','#465155'),('floor','#A6B6BC'),('ink','#34464E'),('road','#BCA77B')]: h.MATERIALS[k]=h.material(k,color)

def scenes_for(key,col):
    result=[]; cx,cy=CENTERS[key]
    for view,angle,span,res in [('front',30,3.5,(1100,1000)),('rear',210,3.5,(1100,1000)),('game',30,18.5,(1280,800))]:
        s=h.configure_scene(key+'_'+view); s.collection.children.link(col); p=h.stage(s,key+'_'+view)
        h.make_camera(s,p,(cx,cy,.65),angle,span,res)
        if view=='game':
            for x in range(-5,6): h.box(p,key+'road'+str(x),(cx+x,cy-2,-.008),(.98,.66,.025),h.MATERIALS['road'])
            h.label(p,s,TITLES[IDS.index(key)]+' / 1 GRID = 1 UNIT / ORTHO 18.5',0,6.5,.24)
        else:
            h.label(p,s,TITLES[IDS.index(key)],0,1.43,.13)
            h.label(p,s,'SAME SCALE / 45 DEG ELEVATION / '+str(angle)+' DEG AZIMUTH',0,-1.53,.055)
        s['output']=str(HERE/key/'previews'/f'{view}.png'); result.append(s)
    return result

def stats(col,key):
    bpy.context.view_layer.update(); st=h.statistics(col); bad=0; nonman=0
    cells=CELLS[key]
    for o in col.objects:
        if o.type!='MESH': continue
        bm=bmesh.new(); bm.from_mesh(o.data); nonman+=sum(not e.is_manifold for e in bm.edges); bm.free()
        for v in o.data.vertices:
            q=o.matrix_world@v.co
            if not any(abs(q.x-x)<=.50001 and abs(-q.y-z)<=.50001 for x,z in cells): bad+=1
    st.update(footprint=cells,outside_footprint_vertices=bad,nonmanifold_edges=nonman)
    assert bad==0,(key,bad,st)
    assert nonman==0,(key,nonman)
    return st

def export(s,col,key):
    h.EXPORTS=HERE/key
    # Reuse RNA-validated exporter options.
    h.export_model(s,col,key)

def reference():
    source=HERE.parent/'great_ballista_slice/exports/great_ballista_c.glb'
    oldm=set(bpy.data.materials)
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source))
    c=h.collection('GreatBallista_REFERENCE')
    for o in set(bpy.data.objects)-before:
        c.objects.link(o)
        for oc in list(o.users_collection):
            if oc!=c: oc.objects.unlink(o)
    print('REFERENCE LINKED',flush=True)
    for o in c.objects:
        o.name=PREFIX+'Reference_'+o.name
        if o.data: o.data.name=PREFIX+'Reference_'+o.data.name
        if o.type=='MESH':
            dark=any('dark' in m.name for m in o.data.materials) or 'ChannelBed' in o.name
            o.data.materials.clear(); o.data.materials.append(h.MATERIALS['dark' if dark else 'ivory'])
    print('REFERENCE READY',flush=True)
    for mat in list(bpy.data.materials):
        if mat not in oldm and mat.users==0: bpy.data.materials.remove(mat)
    return c

def comparison(models,angle=30,span=7.2,name='family'):
    print('COMPARISON '+name,flush=True)
    s=h.configure_scene(name); p=h.stage(s,name); h.make_camera(s,p,(0,0,.5),angle,span,(2100,1200) if span<10 else (1280,800))
    a=math.radians(angle); right=Vector((math.cos(a),math.sin(a),0)); back=Vector((-math.sin(a),math.cos(a),0))
    for i,(key,col) in enumerate(models):
        cx,cy=CENTERS.get(key,(.35,-.5)); x=(-3.15,0,3.15)[i%3]; row=1.85 if i<3 else -1.85
        at=right*x+back*(row/ .7071)-Vector((cx,cy,0))
        o=h.empty(p,key+'_Display',at=at); o.instance_type='COLLECTION'; o.instance_collection=col
        h.label(p,s,key.replace('_',' ').upper(),x,row-1.27,.115 if span<10 else .20)
    h.label(p,s,'BEGINS WITH A ROAD / TOWER FAMILY / TRUE RELATIVE SCALE',0,span*.445,.14 if span<10 else .24)
    s['output']=str(HERE/'previews'/f'{name}.png'); return s

def build(only=None):
    init(); allsc=[]; report={}; models=[]
    for key in IDS:
        if only and key!=only: continue
        path=HERE/key; (path/'previews').mkdir(parents=True,exist_ok=True)
        col=globals()[key](); ss=scenes_for(key,col); bpy.context.window.scene=ss[0]; bpy.context.view_layer.update()
        report[key]=stats(col,key); export(ss[0],col,key)
        bpy.data.libraries.write(str(path/'model.blend'),set(ss),fake_user=True)
        allsc+=ss; models.append((key,col))
    if not only:
        ref=reference(); models.insert(0,('great_ballista',ref))
        (HERE/'previews').mkdir(exist_ok=True)
        for angle in [30,120,210,300]: allsc.append(comparison(models,angle,name='family' if angle==30 else 'family_'+str(angle)))
        allsc.append(comparison(models,30,18.5,'game_scale'))
        allsc.append(comparison(models,30,30.833333,'game_farthest'))
        if bpy.app.background:
            bpy.context.window.scene=bpy.data.scenes[PREFIX+'family']
            for s in list(bpy.data.scenes):
                if not s.name.startswith(PREFIX):
                    for o in list(s.objects): bpy.data.objects.remove(o,do_unlink=True)
                    bpy.data.scenes.remove(s)
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'model.blend'))
        # Blender 5.2.3 crashes writing a scene library containing collection instances.
        # Combined file is saved by the isolated background build, never over the live file.
    (HERE/('inspection_'+only+'.json' if only else 'inspection.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    bpy.context.window.scene=next((s for s in allsc if s.name==PREFIX+'family'),allsc[0])
    print('FAMILY_BUILD '+json.dumps(report),flush=True)

def finalize():
    path=Path(bpy.data.filepath).resolve()
    assert path.parent==HERE or path.parent.parent==HERE
    target=bpy.data.scenes.get(PREFIX+'family') or next(s for s in bpy.data.scenes if s.name.startswith(PREFIX))
    bpy.context.window.scene=target
    for s in list(bpy.data.scenes):
        if not s.name.startswith(PREFIX) and not s.objects: bpy.data.scenes.remove(s)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D': area.spaces.active.region_3d.view_perspective='CAMERA'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path)); print('FAMILY_FINALIZED',flush=True)

def finalize_all(only=None):
    paths=[HERE/key/'model.blend' for key in IDS if not only or only==key]
    if not only: paths.append(HERE/'model.blend')
    for p in paths:
        r=subprocess.run([bpy.app.binary_path,'--background',str(p),'--python',str(HERE/'build.py'),'--','--finalize-file'],capture_output=True,text=True)
        if 'FAMILY_FINALIZED' not in r.stdout: raise RuntimeError(r.stdout+r.stderr)
        print('SAVED '+str(p),flush=True)

def render():
    for s in bpy.data.scenes:
        if s.name.startswith(PREFIX) and 'output' in s:
            bpy.context.window.scene=s; bpy.context.view_layer.update(); s.render.filepath=s['output']; bpy.ops.render.render(write_still=True)
            print('RENDERED '+s['output'],flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    only=args[args.index('--asset')+1] if '--asset' in args else None
    if globals().get('BWAR_ACTION')=='build' or '--build' in args: build(only)
    if '--finalize-file' in args: finalize()
    if '--finalize' in args: finalize_all(only)
    if '--render' in args: render()
