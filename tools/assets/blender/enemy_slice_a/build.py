"""Build one editable .blend and animated GLB per troop. Run inside Blender."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[3]
OUTPUT = PROJECT / "assets/models/enemies/slice_a"
sys.path.insert(0, str(SOURCE.parent / "art_slice_g"))
import style as g

# Shared tower neutrals, with one muted livery family for each troop.
COLORS = dict(g.PALETTE, linen="#C6B9A3", umber="#533F39", boot="#4C4541",
              tabard="#9F6259", lake="#617D87", fern="#788367", ochre="#A07A48",
              claret="#704855", garnet="#A34F59", hide="#78695A", smoke="#716F75",
              membrane="#63817C", wingbone="#435D5A", plate="#747982", trim="#B7A88B")
PERIOD = dict(soldier=24, rook=33, scout=16, bomber=29, bloodmage=38,
              winged=21, rats=13, quickfeet=11, heavy=36)


def rings(levels, sides=8):
    # Tapered, offset elliptical sections give cloth, helmets and beasts their profiles.
    vertices = []
    for z, rx, ry, cy in levels:
        vertices.extend((rx*x, cy+ry*y, z) for x, y in g.ngon(1, sides))
    faces = [tuple(reversed(range(sides)))]
    for ring in range(len(levels)-1):
        for i in range(sides):
            a = ring*sides+i
            b = ring*sides+(i+1) % sides
            faces.append((a, b, b+sides, a+sides))
    faces.append(tuple(range(len(vertices)-sides, len(vertices))))
    return vertices, faces


def taper(start, end, base, tip):
    direction = Vector(end)-Vector(start)
    rotation = direction.to_track_quat('Z','Y')
    verts, faces = g.cone_z(base,tip,0,direction.length,5)
    return [rotation @ Vector(v)+Vector(start) for v in verts], faces


def dome(rx, ry, height):
    return rings([(height*math.sin(a),rx*max(.04,math.cos(a)),
                   ry*max(.04,math.cos(a)),0) for a in (0,.34,.69,1.04,1.36,math.pi/2)],16)


def shield_surface(width, height, depth, thickness):
    """A bowed heater shield. Both layers taper toward the lower point."""
    verts = []
    for back in (0, -thickness):
        for z, breadth in [(-.53,.05),(-.35,.60),(-.11,.92),(.36,1),(.48,.91)]:
            for i in range(9):
                t = (i-4)/4
                verts.append((t*breadth*width/2,back + depth*(1-t*t*breadth*breadth),
                              height*(z+.035*(1-t*t) if z>.4 else z)))
    faces = []
    for i in range(4):
        for j in range(8):
            a = i*9+j
            face = (a,a+9,a+10,a+1)
            faces.extend([face,tuple(v+45 for v in reversed(face))])
    edge = list(range(9))+[17,26,35,44]+list(range(43,35,-1))+[27,18,9]
    for i,a in enumerate(edge):
        b = edge[(i+1)%len(edge)]
        faces.append((a,b,b+45,a+45))
    return verts,faces


class Part:
    """One rigid object per moving group. Coordinates are local to its hinge."""
    def __init__(self, unit, name, pivot, parent):
        self.obj = bpy.data.objects.new("Levy_" + unit.key + "_" + name, None)
        unit.scene.collection.objects.link(self.obj)
        self.obj.parent = parent
        self.obj.location = pivot
        self.base = Vector(pivot)
        self.vertices, self.faces, self.indices, self.materials = [], [], [], []
        self.unit = unit
        self.label = name
        self.smooth_faces = []
        unit.parts.append(self)

    def add(self, geo, color, at=(0, 0, 0), smooth=False):
        vertices, faces = g.move(geo, at)
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(offset+i for i in face) for face in faces)
        if color not in self.materials:
            self.materials.append(color)
        self.indices.extend([self.materials.index(color)]*len(faces))
        self.smooth_faces.extend([smooth and len(face)<=4 for face in faces])

    def box(self, at, size, color, bevel=.009):
        self.add(g.box(*size, bevel), color, at)

    def beam(self, start, end, width, color, depth=None):
        self.add(g.beam(start, end, width, depth), color)

    def finish(self):
        if not self.vertices:
            return
        mesh = bpy.data.meshes.new(self.obj.name + "_mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        # Blender cannot change an Empty to a mesh. Replace its temporary hinge.
        old = self.obj
        self.obj = bpy.data.objects.new(old.name + "_geo", mesh)
        self.unit.scene.collection.objects.link(self.obj)
        self.obj.parent, self.obj.location = old.parent, old.location.copy()
        for child in list(old.children):
            child.parent = self.obj
        name = old.name
        bpy.data.objects.remove(old, do_unlink=True)
        self.obj.name = name
        for color in self.materials:
            mesh.materials.append(self.unit.material(color))
        for face, index, smooth in zip(mesh.polygons, self.indices, self.smooth_faces):
            face.material_index = index
            face.use_smooth = smooth


class Unit:
    def __init__(self, key):
        self.key = key
        # Godot recognizes the glTF animation's "-loop" suffix at import.
        self.scene = bpy.data.scenes.new("Walk-loop")
        self.scene.render.fps = 24
        self.scene.frame_start, self.scene.frame_end = 0, PERIOD[key]
        self.mats, self.parts, self.motion = {}, [], []
        self.root = bpy.data.objects.new("Levy_" + key.title(), None)
        self.scene.collection.objects.link(self.root)
        self.root.empty_display_size = .05

    def material(self, name):
        if name not in self.mats:
            mat = bpy.data.materials.new(self.key + "_" + name)
            mat.use_nodes = True
            color = (*g.lin(COLORS[name]), 1)
            mat.diffuse_color = color
            bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = color
            bsdf.inputs["Roughness"].default_value = .87
            self.mats[name] = mat
        return self.mats[name]

    def part(self, name, at=(0, 0, 0), parent=None):
        return Part(self, name, at, parent.obj if parent else self.root)

    def swing(self, part, axis, amplitude, phase=0, bias=0):
        self.motion.append((part, "rotation_euler", axis,
                            lambda t: bias+amplitude*math.sin(t+phase)))

    def lift(self, part, height, phase=0, beats=2):
        self.motion.append((part, "location", 2, lambda t: part.base.z +
                            height*(1-math.cos(beats*t+phase))*.5))

    def save(self):
        for part in self.parts:
            part.finish()
        for frame in range(self.scene.frame_end+1):
            t = math.tau*frame/PERIOD[self.key]
            for part, field, axis, sample in self.motion:
                getattr(part.obj, field)[axis] = sample(t)
                part.obj.keyframe_insert(data_path=field, index=axis, frame=frame)
        self.scene.frame_set(0)
        self.store_track("Walk-loop")
        if self.key in ("bloodmage","bomber"):
            self.author_gesture()
        bpy.data.libraries.write(str(SOURCE / (self.key+".blend")), {self.scene},
                                 fake_user=True, compress=True)
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (self.key+".glb")),
            use_active_scene=True, export_format="GLB", export_animations=True,
            export_animation_mode="NLA_TRACKS", export_frame_range=False,
            export_texcoords=False, export_tangents=False)
        print(self.key, len(self.parts), "groups,", PERIOD[self.key], "frames")

    def store_track(self, name):
        for part in self.parts:
            data = part.obj.animation_data
            if not data or not data.action:
                continue
            action, slot = data.action, data.action_slot
            data.action = None
            track = data.nla_tracks.new()
            track.name = name
            strip = track.strips.new(name,0,action)
            strip.action_slot = slot
            track.mute = name != "Walk-loop"

    def author_gesture(self):
        # All joints have explicit local poses so the feet stay planted throughout.
        mage = self.key == "bloodmage"
        timing = [0,.2,.45,.64,.84,1]
        pitch = [0,.67,2.12,2.22,1.04,0] if mage else [0,-.38,-1.10,2.02,1.22,0]
        for part in self.parts:
            obj = part.obj
            for frame,t in enumerate(timing):
                obj.location = part.base
                obj.rotation_euler = (0,0,0)
                if part.label == "ArmR":
                    obj.rotation_euler.x = pitch[frame]
                    obj.rotation_euler.y = (-.28 if mage else .46)*math.sin(math.pi*t)
                    obj.location.z += .018*math.sin(math.pi*t)
                if part.label == "Staff":
                    obj.rotation_euler.x = -pitch[frame]*.93
                if part.label == "Coat":
                    obj.rotation_euler.z = (.08 if mage else -.34)*math.sin(math.pi*t*2)
                if part.label == "ArmL":
                    obj.rotation_euler.x = -.63*math.sin(math.pi*t)
                obj.keyframe_insert(data_path="location", frame=round(t*48))
                obj.keyframe_insert(data_path="rotation_euler", frame=round(t*48))
        if not mage:
            hand = next(p.obj for p in self.parts if p.label=="ArmR")
            pot = next(p.obj for p in self.parts if p.label=="ClayFlask")
            for frame in range(10,49):
                self.scene.frame_set(frame)
                if frame <= 31:
                    grip = pot.parent.matrix_world.inverted() @ hand.matrix_world
                    location = grip @ Vector((0,.034,-.218))
                    rotation = grip.to_euler()
                    release = location.copy()
                else:
                    # Local preview arc. Godot aims this same flask at the actual tower.
                    flight = (frame-31)/17
                    location = release+Vector((0,1.5*flight,.35*flight+2.4*flight*(1-flight)))
                    rotation.x = flight*math.tau
                pot.location, pot.rotation_euler = location, rotation
                pot.keyframe_insert(data_path="location", frame=frame)
                pot.keyframe_insert(data_path="rotation_euler", frame=frame)
        self.store_track("Cast" if mage else "Throw")
        # A muted action leaves unkeyed walking channels at their last assigned
        # value in Blender. Restore the belt socket and all other rest transforms.
        for part in self.parts:
            part.obj.location = part.base
            part.obj.rotation_euler = (0,0,0)
        self.scene.frame_set(0)


def humanoid(u):
    k = u.key
    # Hip, shoulders, head size and limb gauge establish different body masses.
    hip, shoulder, width, head, gauge, cloth = {
        "soldier": (.27,.52,.27,.137,.085,"tabard"),
        "rook": (.355,.72,.46,.168,.144,"lake"),
        "scout": (.24,.45,.21,.108,.067,"fern"),
        "bomber": (.22,.45,.32,.134,.095,"ochre"),
        "bloodmage": (.29,.63,.23,.111,.065,"claret"),
        "heavy": (.40,.86,.55,.186,.163,"smoke")
    }[k]
    body = u.part("Coat", (0,0,hip+.009))
    h = shoulder-hip
    u.lift(body, {"heavy":.021,"scout":.032,"bloodmage":.009}.get(k,.017))
    body.add(rings([(-.055,width*.58,.115,0), (.03,width*.49,.10,0),
                    (h-.04,width*.59,.125,.012), (h,width*.44,.103,.017)]), cloth)
    body.box((0,0,.066), (width*.98,.204,.039), "boot")
    if k in ("scout","bomber"):
        body.beam((-width*.43,.096,.06),(width*.43,.107,h-.012),.033,"umber")
    neck_y = .054 if k in ("scout","bomber") else .015
    face_z = h+.106
    body.add(rings([(-head*.75,head*.62,head*.62,0),(-.018,head*.89,head*.87,.012),
                    (head*.57,head*.89,head*.78,0)]),"linen",(0,neck_y,face_z))
    for sign, side in [(-1,"L"),(1,"R")]:
        leg = u.part("Boot"+side,(sign*width*.28,0,-.012),body)
        length = hip-.012
        leg.box((0,0,-length*.41),(gauge,gauge*1.13,length*.79), "slate")
        leg.box((0,.018,-length+.052),(gauge*1.18,gauge*1.68,.096),"boot")
        amplitude = {"scout":.60,"rook":.28,"heavy":.32,"bloodmage":.17}.get(k,.43)
        u.swing(leg,0,sign*amplitude)
        length = h*.80
        arm = u.part("Arm"+side,(sign*(width*.51+.018),.007,h-.02),body)
        if k == "heavy":
            grip = (-sign*.045,.184,-length*.70-sign*.035)
            arm.beam((0,0,-.036),(0,.02,-length*.65),gauge,cloth)
            arm.beam((0,.02,-length*.65),grip,gauge*.74,"iron_light")
            arm.box(grip,(.084,.088,.083),"boot")
        else:
            arm.box((0,0,-length*.43),(gauge*1.08,gauge*1.18,length),cloth)
            arm.box((0,.022,-length),(gauge,gauge,.078),"linen")
        u.swing(arm,0,-sign*(.09 if k in ("rook","heavy","bloodmage") else .28))
        if k == "heavy":
            arm.add(dome(.15,.146,.141),"plate",(0,0,-.01),smooth=True)
            arm.add(rings([(-.073,.14,.133,0),(-.029,.155,.148,0)],12),"iron_light",smooth=True)
            arm.add(rings([(-.088,.134,.126,0),(-.074,.143,.137,0)],12),"trim")
        if side == "R":
            hand = arm
    hat_at = (0,neck_y,face_z+.018)
    if k in ("soldier","rook","heavy"):
        body.add(dome(head*1.08,head*1.13,head*1.10),"iron_light",hat_at,smooth=True)
        body.add(rings([(-.014,head*1.11,head*1.16,0),(.015,head*1.11,head*1.16,0)],16),"trim",hat_at)
        # Wool surcoat flares over the mail skirt, with a pointed heraldic apron.
        body.add(rings([(-.105,width*.61,.135,0),(.086,width*.50,.111,0)],12),cloth)
        body.add(g.prism_xz([(-width*.24,.06),(width*.24,.06),(width*.21,-.12),(0,-.158),
                             (-width*.21,-.12)],.109,.14),cloth)
        body.add(g.prism_xz([(-.019,.038),(.019,.038),(.014,-.11),(0,-.132),(-.014,-.11)],
                            .141,.148),"trim")
    if k == "soldier":
        body.add(rings([(-.032,.191,.186,0),(-.022,.188,.183,0),(.022,.146,.150,0)],16),
                 "iron_light",hat_at,smooth=True)
        hand.beam((0,.032,-.32),(0,.062,.285),.023,"wood")
        hand.add(g.prism_xz([(-.031,0),(0,.105),(.031,0),(0,-.034)],.048,.073),"iron_light",(0,0,.285))
        hand.add(g.prism_yz([(.052,.266),(-.116,.248),(-.07,.223),(-.127,.196),(.052,.20)],-.01,.01),"tabard")
        arm_l = next(p for p in u.parts if p.label=="ArmL")
        arm_l.add(shield_surface(.194,.254,.036,.025),"wood_dark",(0,.081,-.126))
        arm_l.add(shield_surface(.166,.221,.032,.012),"tabard",(0,.095,-.123))
    elif k == "rook":
        shield = u.part("Pavise",(-.012,.172,.19),body)
        shield.add(shield_surface(.73,.94,.097,.047),"trim",smooth=True)
        shield.add(shield_surface(.685,.874,.093,.018),"lake",(0,.016,.008),smooth=True)
        # Raised ivory gate on the bowed face. The base uses the same arch vocabulary.
        for sign in (-1,1):
            shield.beam((sign*.08,.111,-.14),(sign*.08,.111,.074),.033,"canvas")
            shield.beam((sign*.08,.111,.074),(0,.117,.15),.035,"canvas")
        body.add(rings([(-.093,.168,.166,0),(.0,.182,.179,0)],16),"iron",hat_at,smooth=True)
        body.add(g.prism_xz([(-.022,.014),(.022,.014),(.018,-.092),(0,-.116),(-.018,-.092)],
                            .149,.18),"trim",hat_at)
        u.swing(shield,1,.044)
    elif k == "scout":
        body.add(rings([(0,.126,.127,0),(.038,.124,.128,0),(.15,.046,.055,-.05),
                        (.172,.012,.015,-.125)],7),"fern",hat_at)
        cape = u.part("SplitMantle",(0,-.083,h+.005),body)
        cape.add(rings([(-.235,.16,.027,-.075),(-.05,.124,.025,-.015),(0,.096,.018,0)],6),"fern")
        u.swing(cape,0,.16,-.8,.08)
        hand.add(g.prism_yz([(.02,-.19),(.17,-.16),(.204,-.12),(.05,-.13)],-.014,.014),"iron_light")
    elif k == "bomber":
        keg = u.part("PowderKeg",(0,-.153,.18),body)
        keg.add(rings([(-.19,.116,.106,0),(-.125,.149,.139,0),(.14,.15,.14,0),
                       (.197,.12,.115,0)]),"wood")
        for z in (-.115,.125):
            keg.add(rings([(z-.019,.153,.145,0),(z+.019,.153,.145,0)]),"iron")
        keg.beam((0,0,.19),(.045,-.018,.256),.032,"rope")
        u.swing(keg,1,.115,-.45)
        # The alchemist's liripipe hood, scalloped mantle and ceramic belt flasks.
        body.add(rings([(-.052,.195,.141,-.01),(.018,.161,.12,-.01),(.10,.109,.094,0)],12),
                 "ochre",(0,0,h-.015),smooth=True)
        body.add(rings([(-.061,.142,.139,-.014),(.019,.158,.145,-.014),
                        (.132,.103,.103,-.036),(.168,.032,.051,-.105),
                        (.152,.015,.025,-.185)],12),"ochre",hat_at,smooth=True)
        body.add(rings([(-.067,.077,.028,.124),(.004,.102,.040,.126),(.052,.074,.029,.122)],10),
                 "umber",hat_at,smooth=True)
        grip = Euler((-.38,.46*math.sin(.2*math.pi),0)).to_matrix() @ Vector((0,.034,-.218))
        pot = u.part("ClayFlask",hand.base+Vector((0,0,.018*math.sin(.2*math.pi)))+grip,body)
        pot.add(rings([(-.047,.036,.035,0),(-.026,.060,.057,0),(.020,.062,.059,0),
                       (.047,.025,.025,0),(.067,.022,.022,0)],12),"wood_light",smooth=True)
        pot.add(rings([(.052,.026,.026,0),(.069,.026,.026,0)],12),"rope")
        body.beam((.125,-.085,.095),(.187,-.075,.012),.023,"umber")
        body.beam((.187,-.075,.012),(.169,-.005,.074),.022,"umber")
        body.add(rings([(-.054,.042,.039,0),(.01,.054,.048,0),(.056,.021,.021,0)],10),
                 "wood_light",(-.155,.067,.065),smooth=True)
    elif k == "bloodmage":
        body.add(rings([(-.255,.164,.14,-.017),(-.19,.148,.115,0),(.15,.10,.093,0)]),"claret")
        body.add(rings([(0,.154,.139,0),(.075,.12,.115,0),(.20,.064,.067,-.022),
                        (.31,.007,.009,-.065)],7),"claret",hat_at)
        staff = u.part("Staff",(.032,.059,-h*.80),hand)
        staff.add(taper((0,0,-.47+h*.80),(0,0,.26+h*.80),.018,.024),"wood_dark")
        gem = u.part("StaffCrystal",(0,0,.236+h*.80),staff)
        gem.add(rings([(0,.027,.027,0),(.076,.071,.061,0),(.19,.008,.008,0)],6),"garnet")
    elif k == "heavy":
        body.add(rings([(.075,.22,.169,0),(.19,.268,.194,.003),(h-.08,.294,.21,.013),
                        (h+.036,.19,.154,.007)],16),"plate",smooth=True)
        body.add(rings([(-.029,.249,.172,0),(.046,.234,.169,0),(.076,.21,.16,0)],14),"iron_light",smooth=True)
        body.add(rings([(-.087,.177,.178,.012),(-.038,.199,.204,.016),(.028,.201,.198,.014)],16),
                 "iron",hat_at,smooth=True)
        body.add(rings([(-.112,.124,.145,.015),(-.068,.184,.197,.027),(-.030,.192,.21,.027)],16),
                 "iron_light",hat_at,smooth=True)
        # A swept feather crest, front ridge and articulated cloth fauld.
        crest_at = (0,neck_y,face_z+head*.95)
        body.add(g.prism_yz([(.063,.006),(.05,.062),(-.04,.133),(-.16,.145),
                            (-.242,.088),(-.144,.084),(-.205,.046),(-.074,.058),(-.017,.014)],
                            -.026,.026,.005),"tabard",crest_at)
        body.add(g.prism_xz([(-.017,.036),(.017,.036),(.019,-.089),(0,-.124),(-.019,-.089)],
                            .180,.205),"trim",hat_at)
        textile = [(-.097,.06),(.097,.06),(.094,-.152),(.026,-.198),
                   (0,-.158),(-.035,-.207),(-.097,-.156)]
        body.add(g.prism_xz(textile,.173,.19,.003),"claret")
        body.beam((-.070,.193,-.10),(0,.194,-.145),.018,"trim")
        body.beam((0,.194,-.145),(.070,.193,-.10),.018,"trim")
        hammer = u.part("Maul",(0,.222,h-.245),body)
        hammer.beam((.34,0,-.086),(-.374,0,.099),.053,"wood_dark")
        hammer.box((-.365,0,.102),(.158,.246,.18),"iron",.028)
        for y in (-.122,.122):
            hammer.box((-.365,y,.102),(.167,.042,.19),"iron_light",.01)
        u.swing(hammer,0,.115,-.63)


def beast(u):
    if u.key == "winged":
        body = u.part("FlightBody",(0,0,.08))
        u.lift(body,.061,beats=1)
        body.add(rings([(-.066,.064,.118,0),(.028,.091,.154,0),(.105,.053,.086,0)]),"wingbone")
        body.add(g.ico(.076), "membrane",(0,.114,.088))
        for sign, side in [(-1,"L"),(1,"R")]:
            body.add(g.pyramid(.056,.052,.124,.227,(sign*.019,-.019)), "wingbone",(sign*.045,.116,0))
            wing = u.part("Wing"+side,(sign*.06,-.008,.072),body)
            # A folded fan converges at the wrist. Each membrane panel has a raised ridge.
            outline=[(0,.074,.007),(.193,.128,.092),(.425,.078,.142),(.338,-.025,.083),
                     (.295,-.140,.052),(.205,-.086,.045),(.128,-.176,.003),(.074,-.088,.004),(0,-.103,-.015)]
            verts=[(sign*x,y,z) for x,y,z in outline]+[(sign*.165,.021,.105)]
            n=len(outline)
            verts += [(x,y,z-.014) for x,y,z in verts]
            faces=[]
            for i in range(n):
                j=(i+1)%n
                faces.extend([(n,j,i),(2*n+1,i+n+1,j+n+1),(i,j,j+n+1,i+n+1)])
            if sign<0: faces=[tuple(reversed(f)) for f in faces]
            wing.add((verts,faces),"membrane")
            wing.beam((0,.072,0),(sign*.193,.126,.092),.023,"wingbone")
            wing.beam((sign*.193,.126,.092),(sign*.411,.077,.14),.018,"wingbone")
            u.swing(wing,1,sign*.50)
        body.beam((0,-.10,.014),(0,-.25,.002),.039,"wingbone")
        return
    mice = u.key == "rats"
    origins = [(0,0,0)]
    for i,(x,y,z) in enumerate(origins):
        prefix = "Mouse"+str(i+1) if mice else "Hound"
        phase = i*2.1
        scale = .55 if mice else 1.0
        mass = u.part(prefix,(x,y,.091 if mice else .27))
        u.lift(mass,.014 if mice else .038,phase,beats=1)
        def shape(levels, color):
            mass.add(rings([tuple(v*scale for v in row) for row in levels],12),color,smooth=True)
        fur = ["hide","smoke","umber"][i] if mice else "hide"
        if mice:
            shape([(-.091,.074,.151,0),(-.03,.111,.229,-.013),(.063,.115,.21,-.023),
                   (.119,.075,.145,-.028)],fur)
        else:
            # Sections perpendicular to the spine give the flank a tucked waist.
            verts,faces = rings([(-.26,.047,.067,.012),(-.207,.10,.106,.022),
                                 (-.080,.077,.066,.049),(.06,.095,.119,.012),
                                 (.157,.095,.13,.024),(.222,.063,.085,.045)],14)
            mass.add(([(vx,along,height) for vx,height,along in verts],
                      [tuple(reversed(f)) for f in faces]),fur,smooth=True)
        shape([(.019,.064,.080,.176),(.099,.090,.093,.20),(.171,.065,.068,.174)],fur)
        shape([(.027,.042,.042,.282),(.072,.063,.09,.251),(.108,.051,.061,.236)],fur)
        if not mice:
            mass.add(taper((0,.275,.066),(0,.393,.058),.058,.030),fur)
            mass.box((0,.388,.059),(.053,.042,.041),"boot",.008)
        for sign in (-1,1):
            at=(sign*.063*scale,.16*scale,.145*scale)
            if mice:
                mass.add(rings([(-.028,.048,.023,0),(.031,.062,.025,0),(.074,.035,.016,-.014)],7),"trim",at)
            else:
                mass.add(g.pyramid(.082,.077,0,.112,(sign*.026,-.026)),"boot",at)
        if not mice:
            mass.add(rings([(.074,.095,.081,.167),(.113,.099,.082,.169)],12),"umber",smooth=True)
            for sign in (-1,1):
                mass.beam((sign*.068,.152,.126),(sign*.09,.06,-.038),.027,"ochre")
            mass.add(g.prism_xz([(-.035,.018),(.035,.018),(.028,-.021),(0,-.048),(-.028,-.021)],
                                .246,.256),"brass",(0,0,.070))
            # A narrow livery blanket follows the arch of the back and drops
            # to a point on each flank. Leave the waist and limbs exposed.
            for side in (-1,1):
                points = [(side*.002,-.15,.128),(side*.061,-.14,.118),
                          (side*.091,-.115,.057),(side*.087,-.045,.008),
                          (side*.095,.017,.069),(side*.066,.042,.122),
                          (side*.002,.044,.134)]
                faces = [(0,1,5,6),(1,2,4,5),(2,3,4)]
                # Double-sided thickness with outward-facing triangles/quads.
                if side < 0: faces = [tuple(reversed(f)) for f in faces]
                lower = [(x*.97,y,z-.008) for x,y,z in points]
                panels = faces+[tuple(v+7 for v in reversed(f)) for f in faces]
                for i in range(7):
                    j = (i+1)%7
                    edge = (j,i,i+7,j+7)
                    panels.append(edge if side>0 else tuple(reversed(edge)))
                mass.add((points+lower,panels),"lake")
                mass.beam((side*.094,-.10,.058),(side*.090,-.045,.020),.012,"trim")
        for sign,side in [(-1,"L"),(1,"R")]:
            for front,end in [(1,"Fore"),(-1,"Hind")]:
                leg = u.part(prefix+end+side,(sign*.068*scale,front*.133*scale,-.035*scale),mass)
                length = (.084 if mice else .262)-.035*scale
                knee=(0,(-.035 if front>0 else .044)*scale,-length*.48)
                foot=(0,.013*scale,-length+.023*scale)
                leg.add(taper((0,0,0),knee,.035*scale,.026*scale),fur,smooth=True)
                leg.add(taper(knee,foot,.025*scale,.016*scale),"boot",smooth=True)
                leg.box((0,.029*scale,-length+.022*scale),(.050*scale,.079*scale,.037*scale),"boot",.003)
                u.swing(leg,0,.56 if mice else .91,phase+(0 if front>0 else math.pi)+sign*.55)
        tail=u.part(prefix+"Tail",(0,(-.17 if mice else -.23)*scale,.032*scale),mass)
        bend = (.031*scale,-.122*scale,.042*scale)
        radius = (.021 if mice else .047)*scale
        tail.add(taper((0,0,0),bend,radius,radius*.72),fur)
        tail.add(taper(bend,(.069*scale,-.237*scale,.095*scale),radius*.72,.005*scale),"umber")
        u.swing(tail,2,.32,phase-.6)


def build(key):
    previous = bpy.context.window.scene
    u = Unit(key)
    bpy.context.window.scene = u.scene
    try:
        (beast if key in ("rats","quickfeet","winged") else humanoid)(u)
        u.save()
    finally:
        bpy.context.window.scene = previous
        # Remove only data created by this build, including actions from these objects.
        objects = list(u.scene.objects)
        actions = {strip.action for o in objects if o.animation_data
                   for track in o.animation_data.nla_tracks for strip in track.strips}
        actions.update(o.animation_data.action for o in objects if o.animation_data and o.animation_data.action)
        meshes = [o.data for o in objects if o.type=="MESH"]
        for obj in objects:
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(u.scene)
        for data, pool in [(meshes,bpy.data.meshes),(u.mats.values(),bpy.data.materials),(actions,bpy.data.actions)]:
            for item in data:
                if item.users == 0:
                    pool.remove(item)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for key in PERIOD:
        build(key)

