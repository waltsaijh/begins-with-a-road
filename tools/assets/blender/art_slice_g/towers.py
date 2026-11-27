"""Art Slice G: six towers in the chunky low-poly medieval style.

Every builder returns a style.Model whose functional nodes match what
scripts/towers/imported_tower_visual.gd expects (AimPivot, RecoilAssembly,
Muzzle*, FixedBase, LoadBearingBed, DoorLeft/Right, LoadingBay ...).
Blender axes: Z up, +Y = front / firing direction. Footprints match Art Slice D.
"""
import math
from style import (Model, PALETTE, box, cprism, cyl_x, cyl_y, cyl_z, cone_z, ico, move, rot_z, rot_x, rot_y,
                   merge, prism_xz, prism_yz, rect, octagon, ngon, arch, beam, voussoirs, pyramid,
                   wall_ring, wall_rect, ring_prism, side_frame, moss, pennant, world, apply, T8)

R90 = math.pi / 2


def scaled(geo, k):
    v, f = geo
    return [(x * k[0], y * k[1], z * k[2]) for x, y, z in v], f

FOOTPRINTS = {
    'sentry': [(0, 0)], 'barracks': [(0, 0)],
    'mortar': [(0, 0), (-1, 0), (-1, -1), (0, -1)],
    'crossfire': [(0, 0), (1, 0), (0, 1), (1, 1)],
    'ballista': [(0, 0), (0, -1), (1, -1)],
    'broadside': [(0, 0), (0, -1)],
}


def planks(m, parent, prefix, cx, cy, half_x, half_y, z0, z1, along='y', width=.14, clip=None):
    """Plank floor; clip(x, y) -> max half length for rounded floors."""
    n = 0
    a = -half_x + width / 2 if along == 'y' else -half_y + width / 2
    limit = half_x if along == 'y' else half_y
    while a <= limit - width / 2 + 1e-6:
        length = 2 * (half_y if along == 'y' else half_x)
        if clip:
            length = 2 * clip(a)
        if length > .05:
            w, d = (width - .01, length) if along == 'y' else (length, width - .01)
            at = (cx + a, cy + m.rng.uniform(-.008, .008), (z0 + z1) / 2 - m.rng.uniform(0, .005)) if along == 'y' \
                else (cx + m.rng.uniform(-.008, .008), cy + a, (z0 + z1) / 2 - m.rng.uniform(0, .005))
            m.mesh(f'{prefix}{n}', box(w, d, z1 - z0, .008), 'wood_light' if n % 2 else 'wood', parent, at)
        a += width
        n += 1


def arched_door(m, parent, prefix, theta, apothem, half, z0, spring, t=0.0, solid=True):
    loc, rot = side_frame(theta, apothem, 0, t)
    if solid:
        m.mesh(prefix + 'Frame', prism_xz(arch(half + .055, z0, spring), -.03, .03, .015), 'stone_light', parent, loc, rot)
        loc2, _ = side_frame(theta, apothem + .03, 0, t)
        m.mesh(prefix + 'Door', prism_xz(arch(half, z0, spring), -.02, .02, .008), 'wood', parent, loc2, rot)
        for n, z in enumerate((z0 + .09, spring - .02)):
            loc3, _ = side_frame(theta, apothem + .052, z, t)
            m.mesh(f'{prefix}Band{n}', box(half * 1.85, .014, .022), 'iron', parent, loc3, rot)
        loc4, _ = side_frame(theta, apothem + .055, (z0 + spring) / 2, t + half * .45)
        m.mesh(prefix + 'Ring', box(.026, .02, .026), 'iron_light', parent, loc4, rot)
    m.mesh(prefix + 'Arch', merge(*voussoirs(half + .03, spring, 7, .07)), 'stone_light', parent, loc, rot)
    for sgn in (-1, 1):
        m.mesh(f'{prefix}Jamb{sgn}', box(.075, .07, spring - z0, .01, (sgn * (half + .03), 0, (z0 + spring) / 2)),
               'stone_mid', parent, loc, rot)


def slit(m, parent, name, theta, apothem, z, t=0.0, h=.14):
    loc, rot = side_frame(theta, apothem, z, t)
    m.mesh(name, box(.045, .05, h), 'bore', parent, loc, rot)
    loc2, _ = side_frame(theta, apothem + .005, z + h / 2 + .02, t)
    m.mesh(name + 'Lintel', box(.11, .045, .035, .008), 'stone_light', parent, loc2, rot)


# =================================================================== SENTRY
def sentry():
    m = Model('sentry', 11)
    root = m.empty('Model')
    base = m.empty('FixedBase', root)
    m.mesh('Plinth', cprism(rect(.92, .92), 0, .08, .025), 'stone_dark', base)
    m.mesh('Core', cprism(rect(.6, .6), .08, 1.0), 'grout', base)
    courses = [(.08, .27), (.27, .46), (.46, .64), (.64, .82), (.82, 1.0)]
    wall_rect(m, base, 'Wall', (0, 0), .30, .30, courses, openings={1: (.15, .40)})
    arched_door(m, base, 'Door', R90, .37, .095, .08, .27)
    for i, theta in enumerate((0, math.pi, R90)):
        slit(m, base, f'Slit{i}', theta, .375, .70 if i < 2 else .74)
    m.mesh('Cornice', cprism(rect(.86, .86), 1.0, 1.08, .025), 'stone_light', base)
    corbels = []
    for i in range(4):
        for t in (-.22, 0, .22):
            loc, rot = side_frame(i * R90, .39, .965, t)
            corbels.append(move(rot_z(box(.07, .06, .07, .01), rot[2]), loc))
    m.mesh('Corbels', merge(*corbels), 'stone_mid', base)
    k = 0
    for sx in (-1, 0, 1):
        for sy in (-1, 0, 1):
            if sx == 0 and sy == 0:
                continue
            h = .15 + m.rng.uniform(-.01, .02)
            w = .17 if sx and sy else .13
            m.mesh(f'Merlon{k}', box(w, w if sx and sy else .11, h, .02), 'stone_light' if k % 3 else 'stone_mid', base,
                   (sx * .345, sy * .345, 1.08 + h / 2), (0, 0, math.radians(m.rng.uniform(-3, 3))))
            k += 1
    planks(m, base, 'Deck', 0, 0, .29, .29, 1.07, 1.10)
    m.mesh('Post', cyl_z(.05, 1.08, 1.22, 8), 'iron', base)
    m.mesh('Turntable', cyl_z(.12, 1.10, 1.14, 8, .01), 'wood_dark', base)
    for theta, spots in ((0, [(.1, .13, .1), (-.15, .9, .07)]), (math.pi, [(-.12, .14, .11)]),
                         (R90, [(.24, .13, .08)]), (-R90, [(.05, .5, .08), (-.18, .13, .1)])):
        moss(m, base, f'Moss{int(math.degrees(theta)) % 360}', theta, .395, spots, (.43, .08))
    pennant(m, base, 'Pennant', (-.38, -.38, 1.08), .42, 'flag_sentry')
    # weapon -------------------------------------------------------------
    aim = m.empty('AimPivot', root, (0, 0, 1.25))
    for sgn in (-1, 1):
        m.mesh(f'Yoke{sgn}', box(.035, .10, .22, .01, (sgn * .085, 0, .06)), 'wood_dark', aim)
    m.mesh('YokeBase', box(.21, .11, .04, .01, (0, 0, -.06)), 'wood_dark', aim)
    m.mesh('PivotPin', cyl_x(.022, -.11, .11, 6), 'iron_light', aim, (0, 0, .12))
    m.empty('UpgradeSocket', aim, (0, 0, .05))
    recoil = m.empty('RecoilAssembly', aim)
    m.mesh('Stock', box(.09, .60, .07, .015, (0, .05, .20)), 'wood', recoil)
    m.mesh('Butt', box(.12, .14, .11, .02, (0, -.27, .18)), 'wood_dark', recoil)
    m.mesh('Bands', merge(box(.10, .025, .08, 0, (0, -.12, .20)), box(.10, .025, .08, 0, (0, .22, .20))), 'iron', recoil)
    m.mesh('Riser', box(.13, .06, .10, .012, (0, .30, .21)), 'wood_dark', recoil)
    tips = []
    for sgn in (-1, 1):
        a, b = (sgn * .05, .30, .22), (sgn * .31, .22, .22)
        m.mesh(f'Limb{sgn}', beam(a, b, .045, .05), 'iron_light', recoil)
        m.mesh(f'LimbCap{sgn}', box(.04, .04, .06, .008, b), 'brass', recoil)
        tips.append(b)
    nock = (0, .02, .225)
    m.mesh('String', merge(beam(tips[0], nock, .012), beam(tips[1], nock, .012)), 'rope', recoil)
    m.mesh('Bolt', cyl_y(.014, .02, .42, 6), 'wood_light', recoil, (0, 0, .245))
    m.mesh('BoltHead', cone_z(.03, 0, 0, .07, 4), 'iron', recoil, (0, .42, .245), (-R90, 0, 0))
    m.mesh('Fletch', merge(box(.06, .06, .008, 0, (0, .05, .245)), box(.008, .06, .06, 0, (0, .05, .245))), 'canvas', recoil)
    m.empty('ArrowRelease', recoil, (0, .40, .23))
    return m


# =================================================================== BARRACKS
def barracks():
    m = Model('barracks', 23)
    root = m.empty('Model')
    base = m.empty('FixedBase', root)
    m.mesh('Plinth', cprism(rect(.94, .94), 0, .08, .025), 'stone_dark', base)
    # core with a doorway tunnel cut out of the front
    m.mesh('CoreBack', cprism(rect(.68, .46, 0, -.11), .08, .66), 'grout', base)
    for sgn in (-1, 1):
        m.mesh(f'CoreSide{sgn}', cprism(rect(.15, .23, sgn * .265, .235), .08, .66), 'grout', base)
    m.mesh('CoreLintel', cprism(rect(.38, .23, 0, .235), .58, .66), 'grout', base)
    m.mesh('Tunnel', box(.36, .02, .50, 0, (0, .135, .33)), 'bore', base)
    m.mesh('Step', box(.32, .30, .10, .015, (0, .30, .13)), 'stone_mid', base)
    courses = [(.08, .27), (.27, .46), (.46, .66)]
    wall_rect(m, base, 'Wall', (0, 0), .34, .34, courses, openings={1: (.20, .58)})
    loc, rot = side_frame(R90, .41, 0)
    m.mesh('DoorArch', merge(*voussoirs(.215, .38, 7, .08)), 'stone_light', base, loc, rot)
    for sgn in (-1, 1):
        m.mesh(f'Jamb{sgn}', box(.07, .08, .30, .01, (sgn * .215, 0, .23)), 'stone_mid', base, loc, rot)
    for i, theta in enumerate((0, math.pi, -R90)):
        slit(m, base, f'Slit{i}', theta, .415, .42)
    m.mesh('Cornice', cprism(rect(.9, .9), .66, .73, .025), 'stone_light', base)
    k = 0
    for sx in (-1, 0, 1):
        for sy in (-1, 0, 1):
            if sx == 0 and sy == 0:
                continue
            h = .14 + m.rng.uniform(-.01, .02)
            w = .16 if sx and sy else .12
            m.mesh(f'Merlon{k}', box(w, w if sx and sy else .10, h, .02), 'stone_light' if k % 3 else 'stone_mid', base,
                   (sx * .36, sy * .36, .73 + h / 2), (0, 0, math.radians(m.rng.uniform(-3, 3))))
            k += 1
    planks(m, base, 'Deck', 0, 0, .31, .31, .71, .74)
    # wooden lookout with a red-brown pyramid roof
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.mesh(f'RoofPost{sx}{sy}', box(.06, .06, .28, .01, (sx * .19, sy * .19, .88)), 'wood_dark', base)
    m.mesh('RoofRail', merge(*[box(.44, .04, .04, .006, (0, sy * .19, .84)) for sy in (-1, 1)],
                              *[box(.04, .44, .04, .006, (sx * .19, 0, .84)) for sx in (-1, 1)]), 'wood_dark', base)
    m.mesh('RoofRim', cprism(rect(.62, .62), 1.0, 1.05, .015), 'wood_dark', base)
    m.mesh('Roof', pyramid(.60, .60, 1.05, 1.36), 'wood', base)
    m.mesh('RoofCap', cyl_z(.035, 1.33, 1.39, 6), 'brass', base)
    pennant(m, base, 'Pennant', (0, 0, 1.38), .20, 'flag_barracks')
    for theta, spots in ((0, [(.15, .13, .1)]), (math.pi, [(-.1, .13, .11), (.18, .55, .07)]),
                         (R90, [(.32, .13, .08)]), (-R90, [(-.15, .13, .1)])):
        moss(m, base, f'Moss{int(math.degrees(theta)) % 360}', theta, .425, spots, (.45, .08))
    m.mesh('Shield', cprism(ngon(.06, 6, 0), 0, .02, .006), 'flag_barracks', base, (0, .456, .695), (-R90, 0, 0))
    m.empty('DeploymentExit', base, (0, .46, .18))
    m.empty('UpgradeSocket', base, (0, 0, .70))
    for side, name in ((-1, 'DoorLeft'), (1, 'DoorRight')):
        hinge = m.empty(name, root, (side * .135, .235, .35))
        m.mesh(f'DoorLeaf{side}', box(.126, .025, .34, .006, (-side * .064, 0, 0)), 'wood', hinge)
        m.mesh(f'DoorBand{side}', merge(box(.12, .012, .02, 0, (-side * .064, .016, .1)),
                                        box(.12, .012, .02, 0, (-side * .064, .016, -.1))), 'iron', hinge)
    return m


# =================================================================== MORTAR
def mortar():
    m = Model('mortar', 7)
    C = (-.5, -.5)
    root = m.empty('Model')
    bed = m.empty('LoadBearingBed', root, (C[0], C[1], 0))
    m.mesh('Plinth', cprism(octagon(.94), 0, .08, .025), 'stone_dark', bed)
    m.mesh('Core', cprism(octagon(.80), .08, .56), 'grout', bed)
    door = 3
    wall_ring(m, bed, 'Wall', .80, 8, [(.08, .24), (.24, .40), (.40, .56)], openings={door: (.20, .56)})
    theta = door * math.pi / 4
    arched_door(m, bed, 'Door', theta, .855, .135, .08, .32)
    for i in (1, 5, 7):
        slit(m, bed, f'Slit{i}', i * math.pi / 4, .86, .32)
    # one mitred coping ring (was eight straight beams crossing at the corners)
    m.mesh('Cornice', ring_prism(octagon(.92), octagon(.76), .56, .64, .02), 'stone_light', bed)
    for i in range(8):
        th = i * math.pi / 4
        h = .16 + m.rng.uniform(-.01, .02)
        loc, rot = side_frame(th, .855, .64 + h / 2)
        m.mesh(f'Merlon{i}', box(.27, .14, h, .022), 'stone_light' if i % 3 else 'stone_mid', bed, loc,
               (0, 0, rot[2] + math.radians(m.rng.uniform(-2.5, 2.5))))
    planks(m, bed, 'Plank', 0, 0, .70, .76, .52, .58, clip=lambda x: min(.76, math.sqrt(max(0, .80 ** 2 - x * x))))
    spots = {0: [(.2, .12, .11)], 1: [(-.06, .50, .08)], 2: [(-.14, .12, .12), (.22, .48, .06)], 3: [(.27, .13, .1)],
             4: [(.12, .48, .08)], 5: [(.15, .28, .07)], 6: [(.05, .14, .09)], 7: [(-.2, .13, .12)]}
    for i, sp in spots.items():
        moss(m, bed, f'Moss{i}', i * math.pi / 4, .877, sp, (.885, .08))
    a = math.radians(200)
    for n, (dx, dy, dz) in enumerate([(-.065, -.04, 0), (.065, -.04, 0), (0, .07, 0), (0, 0, .1)]):
        m.mesh(f'Shot{n}', ico(.068), 'iron', bed, (.6 * math.cos(a) + dx, .6 * math.sin(a) + dy, .646 + dz))
    a = math.radians(60)
    m.mesh('Crate', box(.17, .17, .15, .012), 'wood_light', bed, (.6 * math.cos(a), .6 * math.sin(a), .655), (0, 0, .35))
    m.mesh('CrateBand', box(.18, .18, .03), 'wood_dark', bed, (.6 * math.cos(a), .6 * math.sin(a), .655), (0, 0, .35))
    pennant(m, bed, 'Pennant', side_frame(5 * math.pi / 4, .855, .82)[0], .36, 'flag_mortar')
    # rotating carriage (FixedBase rotates with the rotor; its far chocks stay on the bed)
    susp = m.empty('Suspension', root)
    fb = m.empty('FixedBase', susp)
    F = .58
    at = lambda x, y, z: (C[0] + x, C[1] + y, F + z)
    m.mesh('TurntableRing', cprism(octagon(.47), 0, .03, .008), 'iron', fb, at(0, 0, 0))
    m.mesh('Turntable', cprism(octagon(.43), .03, .08, .012), 'wood_dark', fb, at(0, 0, 0))
    cheek = [(-.30, .08), (.28, .08), (.22, .26), (.12, .44), (-.10, .44), (-.22, .30), (-.30, .18)]
    for sgn in (-1, 1):
        x0, x1 = (.245, .315) if sgn > 0 else (-.315, -.245)
        m.mesh(f'Cheek{sgn}', prism_yz(cheek, x0, x1, .014), 'wood', fb, at(0, 0, 0))
        m.mesh(f'TrunnionCap{sgn}', box(.09, .13, .04, .006), 'iron_light', fb, at(sgn * .28, 0, .455))
        m.mesh(f'Bolts{sgn}', merge(*[box(.02, .03, .03, 0, (sgn * .32, y, z)) for y, z in ((-.2, .16), (.16, .16), (-.04, .30))]),
               'iron', fb, at(0, 0, 0))
    m.mesh('RearBeam', box(.50, .08, .08, .01), 'wood_dark', fb, at(0, -.24, .14))
    m.mesh('FrontBeam', box(.50, .07, .07, .01), 'wood_dark', fb, at(0, .20, .125))
    for sgn in (-1, 1):   # bed stops: beyond the 0.65 reach, split off as non-rotating BedStops in game
        m.mesh(f'Chock{sgn}', box(.08, .14, .05, .01), 'iron', fb, at(sgn * .74, 0, .025))
    aim = m.empty('AimPivot', susp, at(0, 0, .38))
    m.mesh('Trunnion', cyl_x(.055, -.34, .34, 8), 'iron_light', aim)
    m.empty('UpgradeSocket', aim, (0, -.45, -.32))
    recoil = m.empty('RecoilAssembly', aim, (0, 0, 0), (math.radians(48.5), 0, 0))
    m.mesh('BreechKnob', cyl_y(.10, -.27, -.17, 10, .01), 'iron', recoil)
    m.mesh('Chamber', cyl_y(.215, -.18, .07, 12, .018), 'iron', recoil)
    m.mesh('Body', cyl_y(.185, .06, .31, 12, .01), 'iron', recoil)
    m.mesh('Band', cyl_y(.205, .11, .16, 12, .008), 'iron_light', recoil)
    m.mesh('MuzzleRing', cyl_y(.232, .30, .40, 12, .015), 'iron_light', recoil)
    m.mesh('Bore', cyl_y(.15, .24, .405, 12), 'bore', recoil)
    m.empty('Muzzle0', recoil, (0, .41, 0))
    return m


# =================================================================== CROSSFIRE
def crossfire():
    m = Model('crossfire', 31)
    C = (.5, .5)
    root = m.empty('Model')
    base = m.empty('FixedBase', root, (C[0], C[1], 0))
    m.mesh('Plinth', cprism(octagon(.95), 0, .08, .025), 'stone_dark', base)
    m.mesh('Core', cprism(octagon(.62), .08, .36), 'grout', base)
    wall_ring(m, base, 'Wall', .62, 8, [(.08, .22), (.22, .36)], openings={2: (.12, .36)}, phase=0)
    arched_door(m, base, 'Door', R90, .68, .09, .08, .20)
    m.mesh('Cornice', ring_prism(octagon(.74), octagon(.57), .36, .42, .018), 'stone_light', base)
    for i in (1, 3, 5, 7):
        a = i * math.pi / 4
        m.mesh(f'Buttress{i}', box(.16, .22, .26, .02), 'stone_mid', base, (.80 * math.cos(a), .80 * math.sin(a), .21),
               (0, 0, a - R90))
        m.mesh(f'ButtressCap{i}', box(.18, .24, .05, .015), 'stone_light', base, (.80 * math.cos(a), .80 * math.sin(a), .365),
               (0, 0, a - R90))
    for i, sp in {0: [(.15, .12, .09)], 4: [(-.1, .12, .1)], 6: [(.2, .13, .08)], 3: [(0, .14, .07)]}.items():
        moss(m, base, f'Moss{i}', i * math.pi / 4, .705, sp)
    # rotating turret
    turret = m.empty('Turret', root, (C[0], C[1], 0))
    m.mesh('Ring', cprism(octagon(.50), .42, .45, .008), 'iron', turret)
    m.mesh('Deck', cprism(octagon(.46), .45, .52, .012), 'wood_dark', turret)
    m.mesh('Hub', cyl_z(.22, .52, .72, 8, .015), 'wood', turret)
    m.mesh('HubBands', merge(cyl_z(.232, .55, .58, 8), cyl_z(.232, .66, .69, 8)), 'iron', turret)
    m.mesh('HubRoof', cone_z(.27, .05, .72, .90, 8), 'wood_dark', turret)
    m.mesh('HubCap', cyl_z(.05, .89, .94, 6), 'brass', turret)
    pennant(m, turret, 'Pennant', (0, 0, .93), .22, 'flag_crossfire')
    for i, yaw in enumerate((0, -R90, math.pi, R90)):
        rec = m.empty(f'RecoilAssembly{i}', root)
        def place(geo, yaw=yaw):
            return move(rot_z(geo, yaw), (C[0], C[1], 0))
        m.mesh(f'RadialLauncher{i}', place(cyl_y(.07, .26, .84, 10, .01)), 'iron', rec, (0, 0, .62))
        m.mesh(f'LauncherRing{i}', place(merge(cyl_y(.092, .76, .86, 10, .012), cyl_y(.085, .40, .46, 10, .01))),
               'iron_light', rec, (0, 0, .62))
        m.mesh(f'LauncherBore{i}', place(cyl_y(.045, .80, .865, 8)), 'bore', rec, (0, 0, .62))
        m.mesh(f'Cradle{i}', place(merge(box(.20, .30, .08, .012, (0, .42, .555)),
                                         box(.04, .22, .12, .008, (-.08, .42, .60)),
                                         box(.04, .22, .12, .008, (.08, .42, .60)))), 'wood', rec)
        d = [(0, 1), (1, 0), (0, -1), (-1, 0)][i]
        m.empty(f'Muzzle{i}', rec, (C[0] + d[0] * .90, C[1] + d[1] * .90, .62), (0, 0, yaw))
    m.empty('UpgradeSocket', root, (C[0], C[1], .77))
    return m


# =================================================================== BALLISTA
BALLISTA = {'pivot': (.13, .20, .72), 'tip': (.33, -.07), 'nock': (0, .13, .72), 'draw': .36}


def ballista():
    m = Model('ballista', 41)
    root = m.empty('Model')
    base = m.empty('FixedBase', root)
    cy = -.5
    m.mesh('Plinth', cprism(rect(.92, 1.92, 0, cy), 0, .08, .025), 'stone_dark', base)
    m.mesh('Core', cprism(rect(.64, 1.64, 0, cy), .08, .40), 'grout', base)
    wall_rect(m, base, 'Wall', (0, cy), .32, .82, [(.08, .24), (.24, .40)], openings={1: (.12, .40)})
    loc, rot = side_frame(R90, .89, 0, 0)
    arched_door(m, base, 'Door', R90, cy + .89, .085, .08, .22)
    for i, (theta, t) in enumerate(((0, -.3), (0, .3), (math.pi, -.3), (math.pi, .3))):
        slit(m, base, f'Slit{i}', theta, .395, .27, t + cy * (1 if theta == 0 else -1), .11)
    m.mesh('Cornice', cprism(rect(.88, 1.88, 0, cy), .40, .46, .022), 'stone_light', base)
    for k, (x, y) in enumerate([(-.36, -1.36), (.36, -1.36), (-.36, .36), (.36, .36), (-.36, -.5), (.36, -.5), (0, -1.36)]):
        h = .13 + m.rng.uniform(-.01, .02)
        m.mesh(f'Merlon{k}', box(.15, .15, h, .02), 'stone_light' if k % 3 else 'stone_mid', base, (x, y, .46 + h / 2),
               (0, 0, math.radians(m.rng.uniform(-3, 3))))
    for sgn in (-1, 1):
        m.mesh(f'Rail{sgn}', box(.08, 1.50, .08, .012, (sgn * .15, -.48, .50)), 'wood_dark', base)
    for y in (-1.10, -.55, .05):
        m.mesh(f'Sleeper{int(y * 100)}', box(.44, .07, .05, .008, (0, y, .485)), 'wood_dark', base)
    for theta, spots in ((0, [(.3, .13, .1), (-.4, .13, .08)]), (math.pi, [(.1, .13, .11)]), (-R90, [(0, .13, .09)])):
        moss(m, base, f'Moss{int(math.degrees(theta)) % 360}', theta, (.40 if abs(math.sin(theta)) < .5 else 1.40),
             [(t + (cy * (1 if theta == 0 else -1) if abs(math.sin(theta)) < .5 else 0), z, r) for t, z, r in spots])
    pennant(m, base, 'Pennant', (-.36, -1.36, .60), .32, 'flag_ballista')
    # weapon -------------------------------------------------------------
    mount = m.empty('WeaponMount', root)
    m.mesh('Stock', box(.16, 1.42, .08, .015, (0, -.48, .60)), 'wood', mount)
    m.mesh('StockBands', merge(*[box(.17, .03, .09, 0, (0, y, .60)) for y in (-1.0, -.55, -.10)]), 'iron', mount)
    m.mesh('Head', box(.26, .14, .16, .02, (0, .25, .68)), 'wood_dark', mount)
    m.mesh('HeadPlate', box(.28, .05, .05, .008, (0, .32, .76)), 'iron_light', mount)
    m.mesh('Track', box(.05, 1.0, .02, 0, (0, -.30, .655)), 'wood_light', mount)
    px, py, pz = BALLISTA['pivot']
    tx, ty = BALLISTA['tip']
    for sgn in (-1, 1):
        piv = m.empty(f'LimbPivot{sgn}', mount, (sgn * px, py, pz))
        m.mesh(f'BowLimb{sgn}', merge(beam((0, 0, 0), (sgn * tx, ty, 0), .05, .07)), 'wood', piv)
        m.mesh(f'LimbTipCap{sgn}', box(.05, .05, .08, .01, (sgn * tx, ty, 0)), 'iron_light', piv)
        m.mesh(f'LimbBand{sgn}', box(.06, .06, .08, .008, (sgn * .02, -.005, 0)), 'iron', piv)
        m.empty(f'LimbTip{sgn}', piv, (sgn * tx, ty, 0))
    slider = m.empty('Slider', mount)
    nx, ny, nz = BALLISTA['nock']
    m.mesh('Sled', box(.13, .14, .06, .012, (0, ny - .08, .69)), 'wood_light', slider)
    m.mesh('Claw', box(.07, .05, .05, .008, (0, ny - .015, .72)), 'iron', slider)
    m.empty('Nock', slider, (nx, ny, nz))
    # bow strings: StringAim sits on the limb tip and turns toward the nock; its
    # child BowString is a unit bar along +Y that is only stretched along its own
    # axis. Keeping rotation and non-uniform scale on separate nodes stops the
    # animation mixer from applying the stretch on the wrong axis.
    for sgn in (-1, 1):
        tip = (sgn * (px + tx), py + ty, pz)
        d = (nx - tip[0], ny - tip[1])
        L = math.hypot(*d)
        aim = m.empty(f'StringAim{sgn}', mount, tip, (0, 0, math.atan2(-d[0], d[1])))
        m.mesh(f'BowString{sgn}', box(.014, 1.0, .014, 0, (0, .5, 0)), 'rope', aim, (0, 0, 0), (0, 0, 0), (1, L, 1))
    bolt = m.empty('BoltCarrier', mount)
    m.mesh('BoltShaft', cyl_y(.022, ny - .02, .40, 6), 'wood_light', bolt, (0, 0, .725))
    m.mesh('BoltHead', cone_z(.045, 0, 0, .085, 4), 'iron', bolt, (0, .40, .725), (-R90, 0, 0))
    m.mesh('BoltFletch', merge(box(.09, .08, .01, 0, (0, ny + .03, .725)), box(.01, .08, .09, 0, (0, ny + .03, .725))),
           'flag_ballista', bolt)
    link = m.empty('TensionLink', mount, (0, -1.08, .66))
    m.mesh('WinchDrum', cyl_x(.07, -.12, .12, 8, .01), 'wood_dark', link)
    m.mesh('WinchSpokes', merge(cyl_x(.10, -.15, -.12, 8), cyl_x(.10, .12, .15, 8),
                                box(.02, .26, .03, 0, (-.135, 0, 0)), box(.02, .03, .26, 0, (-.135, 0, 0)),
                                box(.02, .26, .03, 0, (.135, 0, 0)), box(.02, .03, .26, 0, (.135, 0, 0))), 'iron_light', link)
    m.mesh('WinchPosts', merge(box(.04, .08, .16, .008, (-.17, -1.08, .58)), box(.04, .08, .16, .008, (.17, -1.08, .58))),
           'wood_dark', mount)
    m.empty('Muzzle', mount, (0, .49, .71))
    m.empty('WeaponUpgradeSocket', root, (0, -.48, .52))
    # loading bay on the side cell ----------------------------------------
    bay = m.empty('LoadingBay', root)
    m.mesh('BayPad', cprism(rect(.86, .86, 1, -1), 0, .07, .02), 'stone_dark', bay)
    m.mesh('BaySlab', cprism(rect(.74, .74, 1, -1), .07, .11, .015), 'stone_light', bay)
    for sgn in (-1, 1):
        m.mesh(f'RackEnd{sgn}', box(.05, .32, .26, .01, (1 + sgn * .26, -.95, .24)), 'wood_dark', bay)
    m.mesh('RackBars', merge(box(.56, .04, .04, .006, (1, -.95, .20)), box(.56, .04, .04, .006, (1, -.95, .32))), 'wood', bay)
    for k in range(3):
        y = -1.03 + k * .08
        m.mesh(f'SpareBolt{k}', cyl_x(.02, .70, 1.30, 6), 'wood_light', bay, (0, y, .36 + k * .006))
        m.mesh(f'SpareHead{k}', cone_z(.035, 0, 0, .08, 4), 'iron', bay, (1.30, y, .36 + k * .006), (0, R90, 0))
    m.mesh('BayCrate', box(.20, .20, .18, .014), 'wood_light', bay, (1.20, -1.27, .20), (0, 0, .3))
    m.mesh('BayCrateBand', box(.21, .21, .035), 'wood_dark', bay, (1.20, -1.27, .20), (0, 0, .3))
    m.mesh('BayBarrel', cyl_z(.09, .11, .33, 8, .012), 'wood', bay, (.80, -1.28, 0))
    m.mesh('BayBarrelHoops', merge(cyl_z(.096, .15, .17, 8), cyl_z(.096, .27, .29, 8)), 'iron', bay, (.80, -1.28, 0))
    m.mesh('BayMoss', cprism([(0, 0), (.12, .02), (.1, .09), (.01, .08)], .11, .12), 'moss_light', bay, (.70, -.78, 0))
    return m


# =================================================================== BROADSIDE AIRSHIP
def broadside():
    m = Model('broadside', 53)
    root = m.empty('Model')
    base = m.empty('FixedBase', root)
    cy = -.5
    m.mesh('Plinth', cprism(rect(.92, 1.92, 0, cy), 0, .08, .025), 'stone_dark', base)
    m.mesh('Slab', cprism(rect(.82, 1.82, 0, cy), .08, .14, .02), 'stone_light', base)
    for k, (x, y) in enumerate([(-.33, -1.33), (.33, -1.33), (-.33, .33), (.33, .33)]):
        m.mesh(f'Bollard{k}', cprism(octagon(.07), .14, .34, .015), 'stone_mid', base, (x, y, 0))
        m.mesh(f'BollardCap{k}', cprism(octagon(.085), .34, .38, .012), 'stone_light', base, (x, y, 0))
        m.mesh(f'RopeCoil{k}', cyl_z(.06, .14, .18, 8), 'rope', base, (x + (.12 if x < 0 else -.12), y, 0))
    m.mesh('Mast', cyl_z(.045, .14, .60, 6), 'wood_dark', base, (0, .30, 0))
    m.mesh('MastArm', box(.05, .22, .04, .006, (0, .22, .58)), 'wood_dark', base)
    m.mesh('Crates', merge(box(.18, .18, .16, .014, (.24, -.75, .22)), box(.14, .14, .12, .012, (.28, -.55, .20))), 'wood_light', base)
    m.mesh('Moss', merge(cprism([(0, 0), (.14, .02), (.12, .1), (.02, .09)], .14, .152)), 'moss_light', base, (-.38, -.9, 0))
    ship = m.empty('Airship', root, (0, cy, .74))
    hull_top = [(-.27, -.70), (.27, -.70), (.29, .30), (.17, .66), (0, .82), (-.17, .66), (-.29, .30)]
    hull_mid = [(-.20, -.62), (.20, -.62), (.21, .28), (.12, .58), (0, .70), (-.12, .58), (-.21, .28)]
    keel = [(-.09, -.50), (.09, -.50), (.09, .30), (0, .50), (-.09, .30)]
    m.mesh('HullUpper', cprism(hull_top, -.08, .06, .02), 'wood', ship)
    m.mesh('HullLower', cprism(hull_mid, -.18, -.08, .02), 'wood_dark', ship)
    m.mesh('Keel', cprism(keel, -.25, -.18, .015), 'wood_dark', ship)
    m.mesh('Stripe', cprism([(x * 1.01, y) for x, y in hull_top], -.035, -.005), 'flag_broadside', ship)
    m.mesh('Deck', cprism([(x * .88, y * .92) for x, y in hull_top], .06, .075), 'wood_light', ship)
    m.mesh('Rail', merge(*[box(.03, .03, .06, .005, (x * .96, y * .98, .10)) for x, y in hull_top]), 'wood_dark', ship)
    m.mesh('Cabin', box(.30, .26, .16, .02, (0, -.42, .155)), 'wood', ship)
    m.mesh('CabinRoof', box(.36, .32, .04, .012, (0, -.42, .255)), 'wood_dark', ship)
    m.mesh('Tail', merge(box(.03, .20, .24, .01, (0, -.80, .12)), box(.24, .14, .03, .008, (0, -.78, .02))), 'wood_dark', ship)
    m.mesh('Propeller', merge(box(.30, .02, .05, .006, (0, -.74, -.05)), box(.05, .02, .30, .006, (0, -.74, -.05))), 'brass', ship)
    # balloon envelope: faceted ellipsoid with identity bands
    m.mesh('Envelope', scaled(ico(1.0, 1), (.36, .80, .27)), 'canvas', ship, (0, -.02, .60))
    for n, y in enumerate((-.40, 0.0, .40)):
        k = math.sqrt(max(0.0, 1 - (y / .80) ** 2))
        m.mesh(f'EnvelopeBand{n}', scaled(cyl_y(1.0, -.5, .5, 12), (.37 * k, .05, .28 * k)),
               'flag_broadside' if n == 1 else 'rope', ship, (0, y - .02, .60))
    m.mesh('EnvelopeFin', merge(box(.02, .22, .18, .006, (0, -.84, .66)), box(.20, .22, .02, .006, (0, -.84, .60))), 'canvas', ship)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.mesh(f'Rope{sx}{sy}', beam((sx * .20, sy * .40, .07), (sx * .26, sy * .30, .42), .012), 'rope', ship)
    pennant(m, ship, 'Pennant', (0, .66, .07), .22, 'flag_broadside')
    m.empty('UpgradeSocket', ship, (0, -.15, -.49))
    recoil = m.empty('RecoilAssembly', ship, (0, -cy, -.74))
    for side, bank_name in ((-1, 'Port'), (1, 'Starboard')):
        bank = m.empty(bank_name, recoil)
        for k, y in enumerate((-1.0, -.5, -.02)):
            gun = m.empty(f'{bank_name}Gun{k + 1}', bank)
            m.mesh(f'Cannon({side}, {k})', cyl_x(.055, side * .20, side * .44, 8, .008), 'iron', gun, (0, y, .75))
            m.mesh(f'CannonRing({side}, {k})', cyl_x(.07, side * .40, side * .46, 8, .01), 'iron_light', gun, (0, y, .75))
            m.mesh(f'CannonBore({side}, {k})', cyl_x(.035, side * .43, side * .465, 6), 'bore', gun, (0, y, .75))
            m.empty(f'Muzzle({side}, {k})', gun, (side * .48, y, .75), (0, 0, -side * R90))
    return m


# =================================================================== UPGRADE LEVELS
# Upgrade looks, switched by scripts/towers/body_visual.gd set_level(): a node named
# Level<N> shows from tower level N on, Below<N> only below level N (Level2/Below3Fort
# = Lv.2 only). Built after each tower and without m.rng, so the base model is unchanged.
#   Lv.2 fortress: dark stone body, light merlons/cornice, brass trim band, battered
#        corner feet with rivets, identity banners.
#   Lv.3 royal: near-black stone, gold cornice, black merlons with gold pyramid caps,
#        crimson banners edged in gold, gold studs, gold-capped feet, tall standard.
def _node(m, name):
    full = m.full(name)
    return next(n for n in m.nodes if n.name == full)


def _extent(node):
    xs, ys, zs = zip(*node.geo[0])
    return max(xs) - min(xs), max(ys) - min(ys), max(zs)


def _short(n):
    return n.name.split('__')[-1]


def _group(m, name, parent):
    """Empty inserted right after its parent (the node list must stay parent-first)."""
    g = m.empty(name, parent)
    m.nodes.remove(g)
    m.nodes.insert(m.nodes.index(parent) + 1, g)
    return g


def banner(m, parent, prefix, theta, apothem, top, t=0.0, w=.15, h=.24, mat='flag_sentry', centre=(0, 0),
           rod='iron', edge=None):
    loc, rot = side_frame(theta, apothem, top, t)
    loc = (loc[0] + centre[0], loc[1] + centre[1], loc[2])
    k = -h * .78   # rectangle plus two tail points (prisms must be convex)
    cloth = merge(prism_xz([(-w / 2, 0), (w / 2, 0), (w / 2, k), (-w / 2, k)], -.006, .006),
                  prism_xz([(-w / 2, k), (0, k), (-w / 2, -h)], -.006, .006),
                  prism_xz([(0, k), (w / 2, k), (w / 2, -h)], -.006, .006))
    m.mesh(prefix + 'Cloth', cloth, mat, parent, loc, rot)
    m.mesh(prefix + 'Rod', merge(box(w + .06, .022, .022, .004, (0, 0, .006)),
                                 box(.022, .05, .022, .004, (-w / 2 - .02, -.025, .006)),
                                 box(.022, .05, .022, .004, (w / 2 + .02, -.025, .006))), rod, parent, loc, rot)
    if edge:
        e = .014
        m.mesh(prefix + 'Edge', merge(prism_xz([(-w / 2 - e, 0), (-w / 2, 0), (-w / 2, -h), (-w / 2 - e, -h)], -.009, .009),
                                      prism_xz([(w / 2, 0), (w / 2 + e, 0), (w / 2 + e, -h), (w / 2, -h)], -.009, .009),
                                      prism_xz([(-w / 2, k + e / 2), (w / 2, k + e / 2), (w / 2, k - e / 2), (-w / 2, k - e / 2)],
                                               .006, .01)), edge, parent, loc, rot)
    return loc, rot, h


def emblem(m, parent, name, placed, size=.04, mat='brass'):
    loc, rot, h = placed
    diamond = [(0, size), (size * .8, 0), (0, -size), (-size * .8, 0)]
    m.mesh(name, prism_xz([(x, z - h * .42) for x, z in diamond], .006, .016), mat, parent, loc, rot)


FORT = {'stone_light': 'fort_light', 'stone_mid': 'fort_mid', 'stone_dark': 'fort_dark', 'grout': 'fort_grout',
        'slate': 'fort_dark'}
ROYAL = {'stone_light': 'royal_light', 'stone_mid': 'royal_mid', 'stone_dark': 'royal_dark', 'grout': 'royal_grout',
         'slate': 'royal_dark'}
DARKEN = ('Wall', 'Core', 'Plinth', 'Buttress', 'Corbels', 'DoorJamb', 'Jamb', 'Step', 'Bollard', 'BayPad')
TRIM = ('Merlon', 'Cornice', 'ButtressCap', 'BollardCap')


def rivet_ring(m, parent, name, plinth, mat):
    pts = sorted({(round(x, 3), round(y, 3)) for x, y, z in plinth.geo[0]})
    cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
    ring = sorted(pts, key=lambda p: math.atan2(p[1] - cy, p[0] - cx))
    hull = [ring[0]]
    for p in ring[1:]:
        if math.dist(p, hull[-1]) > .06:
            hull.append(p)
    zs = [z for _, _, z in plinth.geo[0]]
    zm = (min(zs) + max(zs)) / 2
    rivets = []
    for i, a in enumerate(hull):
        b = hull[(i + 1) % len(hull)]
        k = max(1, int(math.dist(a, b) / .2))
        for j in range(k):
            t = (j + .5) / k
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            nx, ny = x - cx, y - cy; d = math.hypot(nx, ny) or 1
            rivets.append(box(.028, .028, .028, 0, (x + nx / d * .004, y + ny / d * .004, zm)))
    m.mesh(name, merge(*rivets), mat, parent, plinth.loc, plinth.rot)


def fortress(m, parent, lv2, lv3, band=None):
    """Swap the stone for both upgrade looks. Returns the Lv.2-only group."""
    below2, below3 = _group(m, 'Below2', parent), _group(m, 'Below3', parent)
    only2 = _group(m, 'Below3Fort', lv2)
    plinth = None
    for n in list(m.nodes):
        short = _short(n)
        if n.parent is not parent or n.geo is None or n.mat not in FORT:
            continue
        if short.startswith(TRIM):
            # light trim: kept through Lv.2, replaced at Lv.3 (gold cornice / black merlons)
            n.parent = below3
            mat = 'gold' if short.startswith('Cornice') else ROYAL[n.mat]
            m.mesh('Royal' + short, n.geo, mat, lv3, n.loc, n.rot, n.scale)
        elif short.startswith(DARKEN):
            n.parent = below2
            m.mesh('Fort' + short, n.geo, FORT[n.mat], only2, n.loc, n.rot, n.scale)
            m.mesh('Royal' + short, n.geo, ROYAL[n.mat], lv3, n.loc, n.rot, n.scale)
            if short == 'Plinth':
                plinth = n
    if band:
        m.mesh('TrimBand', ring_prism(band[0], band[1], band[2], band[3], .004), 'brass', only2)
        m.mesh('GoldBand', ring_prism(band[0], band[1], band[2], band[3], .004), 'gold', lv3)
    if plinth is not None:
        rivet_ring(m, only2, 'Rivets', plinth, 'iron_light')
        rivet_ring(m, lv3, 'GoldRivets', plinth, 'gold')
    return only2


def frustum(w0, d0, w1, d1, z0, z1):
    """Box tapering from w0 x d0 at z0 to w1 x d1 at z1 (a battered foot)."""
    v = [(x, y, z0) for x, y in rect(w0, d0)] + [(x, y, z1) for x, y in rect(w1, d1)]
    f = [(3, 2, 1, 0), (4, 5, 6, 7)] + [(i, (i + 1) % 4, (i + 1) % 4 + 4, i + 4) for i in range(4)]
    return v, f


def foot(m, parent, name, at, yaw, size=(.26, .26), top=(.17, .17), z=(.08, .34), faces=((1, 0), (0, 1)),
         mats=('fort_dark', 'stone_light', 'iron_light')):
    """Battered corner foot with a cap and studs on its outward faces (local directions)."""
    (w0, d0), (w1, d1), (z0, z1) = size, top, z
    body, cap, stud = mats
    m.mesh(name, frustum(w0, d0, w1, d1, z0, z1), body, parent, at, (0, 0, yaw))
    m.mesh(name + 'Cap', cprism(rect(w1 + .03, d1 + .03), z1, z1 + .035, .01), cap, parent, at, (0, 0, yaw))
    if cap == 'gold':
        m.mesh(name + 'Point', pyramid(w1 + .01, d1 + .01, z1 + .035, z1 + .035 + min(w1, d1) * .55), 'gold', parent, at,
               (0, 0, yaw))
    studs = []
    for fx, fy in faces:
        for zz in (z0 + (z1 - z0) * .3, z0 + (z1 - z0) * .7):
            k = (zz - z0) / (z1 - z0)
            hw, hd = (w0 + (w1 - w0) * k) / 2, (d0 + (d1 - d0) * k) / 2
            for t in (-.3, .3):
                at2 = (fx * (hw + .005), t * hd, zz) if fx else (t * hw, fy * (hd + .005), zz)
                studs.append(box(.03, .03, .03, 0, at2))
    m.mesh(name + 'Rivets', merge(*studs), stud, parent, at, (0, 0, yaw))


ROYAL_FOOT = ('royal_dark', 'gold', 'gold')


def feet(m, only2, lv3, spots, **kw):
    """spots = [(name, at, yaw, faces)]: the same foot in Lv.2 and Lv.3 dress."""
    for name, at, yaw, faces in spots:
        foot(m, only2, name, at, yaw, faces=faces, **kw)
        foot(m, lv3, 'Royal' + name, at, yaw, faces=faces, mats=ROYAL_FOOT, **kw)


def corner_spots(half_x, half_y, cy=0.0):
    return [(f'Foot{sx}{sy}'.replace('-', 'm'), (sx * half_x, cy + sy * half_y, 0), 0, ((sx, 0), (0, sy)))
            for sx in (-1, 1) for sy in (-1, 1)]


def radial_spots(angles, r):
    return [(f'Foot{i}', (r * math.cos(a), r * math.sin(a), 0), a - R90, ((0, 1), (1, 0), (-1, 0)))
            for i, a in enumerate(angles)]


def gold_caps(m, merlons, lv3):
    """Black merlons at Lv.3 wear a gold pyramid cap (the Royal copy carries the body)."""
    for n in merlons:
        w, d, top = _extent(n)
        at = (n.loc[0], n.loc[1], n.loc[2] + top)
        m.mesh(_short(n) + 'Crown', merge(cprism(rect(w + .02, d + .02), 0, .03, .006),
                                          pyramid(w * .9, d * .9, .03, .03 + min(w, d) * .55)), 'gold', lv3, at, n.rot)


def gold_studs(m, lv3, name, poly, z, centre=(0, 0), skip=(), spacing=.15):
    """A row of gold studs around a wall outline (poly, CCW), skipping edge indices."""
    p = ccw_poly(poly)
    studs = []
    for i in range(len(p)):
        if i in skip:
            continue
        a, b = p[i], p[(i + 1) % len(p)]
        L = math.dist(a, b)
        n = max(1, int(L / spacing))
        nx, ny = b[1] - a[1], a[0] - b[0]; d = math.hypot(nx, ny); nx, ny = nx / d, ny / d
        for j in range(n):
            t = (j + .5) / n
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            studs.append(move(rot_x_to(nx, ny), (x + centre[0], y + centre[1], z)))
    if studs:
        m.mesh(name, merge(*studs), 'gold', lv3)


def ccw_poly(poly):
    a = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    return list(poly) if a > 0 else list(reversed(poly))


def rot_x_to(nx, ny):
    """Small 4-sided gold spike pointing along (nx, ny) in the ground plane."""
    spike = rot_x(cone_z(.024, 0, 0, .045, 4), -R90)   # now points +Y
    return rot_z(spike, math.atan2(ny, nx) - R90)


def royal_banners(m, lv3, specs, mat='crimson'):
    for name, args in specs:
        placed = banner(m, lv3, name, *args, mat=mat, rod='gold', edge='gold')
        emblem(m, lv3, name + 'Emblem', placed, args[4] * .28, 'gold')


def standard(m, parent, prefix, at, height, mat, facing=0.0):
    """Tall Lv.3 flag: thicker pole, gold finial and a wide swallow-tail banner."""
    x, y, z = at
    m.mesh(prefix + 'Pole', cyl_z(.024, 0, height, 6), 'royal_dark', parent, (x, y, z))
    m.mesh(prefix + 'Finial', merge(cyl_z(.04, height, height + .03, 6), cone_z(.03, 0, height + .03, height + .1, 6)),
           'gold', parent, (x, y, z))
    flag = [(0, 0), (.30, 0), (.24, -.10), (.30, -.20), (0, -.20)]
    m.mesh(prefix + 'Flag', merge(prism_xz(flag[:3] + [(0, -.10)], -.009, .009),
                                  prism_xz([(0, -.10), (.24, -.10), (.30, -.20), (0, -.20)], -.009, .009)),
           mat, parent, (x + .02, y, z + height - .03), (0, 0, facing))
    m.mesh(prefix + 'FlagTrim', prism_xz([(0, 0), (.30, 0), (.30, -.025), (0, -.025)], -.011, .011), 'gold', parent,
           (x + .02, y, z + height - .03), (0, 0, facing))
    m.empty(prefix + 'Beacon', parent, (x, y, z + height + .14))   # lit at dusk / night (imported_tower_visual.gd)


# ---- weapons: Lv.2 steel-shod, Lv.3 black and gold; mortar / crossfire barrels grow thicker
WEAPON2 = {'wood': 'wood_dark', 'wood_light': 'wood', 'iron': 'steel', 'iron_light': 'steel_light'}
WEAPON3 = {'wood': 'royal_mid', 'wood_light': 'royal_light', 'wood_dark': 'royal_dark', 'iron': 'gold',
           'iron_light': 'gold', 'brass': 'gold', 'canvas': 'crimson', 'flag_ballista': 'crimson'}


def variants(m, parent, nodes, lv2, lv3):
    """Swap meshes directly under `parent` (an animated assembly is fine: the groups ride
    on it). lv2 / lv3(node) -> (geo, mat, scale). Group names carry a letter tag only, so
    set_level() still reads the level number from them."""
    m.weapon_tag = getattr(m, 'weapon_tag', 0) + 1
    t = chr(64 + m.weapon_tag)
    b2 = _group(m, f'Below2W{t}', parent)
    l3 = _group(m, f'Level3W{t}', parent)
    l2 = _group(m, f'Level2W{t}', parent)
    o2 = _group(m, f'Below3W{t}', l2)
    for n in nodes:
        n.parent = b2
        for group, fn, suffix in ((o2, lv2, 'Lv2'), (l3, lv3, 'Lv3')):
            geo, mat, scale = fn(n)
            m.mesh(_short(n) + suffix, geo, mat, group, n.loc, n.rot, scale)


def restyle(m, parent, skip=()):
    nodes = [n for n in m.nodes if n.parent is parent and n.geo is not None and not _short(n).startswith(skip)]
    variants(m, parent, nodes, lambda n: (n.geo, WEAPON2.get(n.mat, n.mat), n.scale),
             lambda n: (n.geo, WEAPON3.get(n.mat, n.mat), n.scale))


# ---- night lamps: wall torches (always modelled); imported_tower_visual.gd lights a
# flame and a warm OmniLight3D at every "Lamp" node when the level's time of day asks.
def torch(m, parent, name, theta, apothem, z, t=0.0):
    loc, rot = side_frame(theta, apothem, z, t)
    m.mesh(name + 'Bracket', merge(box(.025, .07, .025, .004, (0, .035, 0)), box(.025, .025, .05, .004, (0, .065, .02))),
           'iron', parent, loc, rot)
    m.mesh(name + 'Cup', move(cone_z(.022, .04, .045, .09, 6), (0, .065, 0)), 'iron_light', parent, loc, rot)
    cup, _ = side_frame(theta, apothem + .07, z + .10, t)
    m.empty(name + 'Lamp', parent, cup)


def lamp_post(m, parent, name, at):
    x, y, z = at
    m.mesh(name + 'Post', cyl_z(.015, 0, .10, 6), 'iron', parent, (x, y, z))
    m.mesh(name + 'Cage', merge(cprism(rect(.06, .06), .10, .115), cprism(rect(.05, .05), .17, .19, .004),
                                pyramid(.05, .05, .19, .22)), 'iron', parent, (x, y, z))
    m.empty(name + 'Lamp', parent, (x, y, z + .14))


def _merlons(m, parent, prefix='Merlon'):
    return [n for n in m.nodes if n.geo is not None and _short(n).startswith(prefix) and
            (n.parent is parent or (n.parent is not None and n.parent.parent is parent and _short(n.parent) == 'Below3'))]


def levels_sentry(m):
    base = _node(m, 'FixedBase')
    lv2, lv3 = m.empty('Level2', base), m.empty('Level3', base)
    only2 = fortress(m, base, lv2, lv3, (rect(.80, .80), rect(.70, .70), .90, .935))
    faces = (0, math.pi, -R90)
    for i, theta in enumerate(faces):
        banner(m, only2, f'Banner{i}', theta, .41, .60, mat='flag_sentry')
    royal_banners(m, lv3, [(f'RoyalBanner{i}', (theta, .41, .60, 0, .15, .24)) for i, theta in enumerate(faces)])
    feet(m, only2, lv3, corner_spots(.35, .35), z=(.08, .40))
    gold_caps(m, _merlons(m, base), lv3)
    gold_studs(m, lv3, 'Studs', rect(.76, .76), .82)
    for k, theta in enumerate((0, R90, math.pi, -R90)):   # two torches at Lv.1, two more from Lv.2
        torch(m, base if k % 2 == 0 else lv2, f'Torch{k}', theta, .38, .50, .2)
    standard(m, lv3, 'Standard', (.36, .36, 1.08), .62, 'flag_sentry', math.pi)
    # crossbow: yoke, stock, limbs, bolt (the string stays rope)
    for part in ('AimPivot', 'RecoilAssembly'):
        restyle(m, _node(m, part), skip=('String',))


def levels_mortar(m):
    bed = _node(m, 'LoadBearingBed')
    lv2, lv3 = m.empty('Level2', bed), m.empty('Level3', bed)
    only2 = fortress(m, bed, lv2, lv3, (octagon(.875), octagon(.78), .505, .54))
    for i in (0, 2, 4, 6):
        banner(m, only2, f'Banner{i}', i * math.pi / 4, .90, .54, 0, .20, .26, 'flag_mortar')
    royal_banners(m, lv3, [(f'RoyalBanner{i}', (i * math.pi / 4, .90, .54, 0, .20, .26)) for i in (0, 2, 4, 6)])
    feet(m, only2, lv3, radial_spots([math.pi / 8 + i * math.pi / 4 for i in range(8)], .86),
         size=(.22, .24), top=(.14, .15), z=(.08, .36))
    gold_caps(m, _merlons(m, bed), lv3)
    for k in (1, 3, 5, 7):
        torch(m, bed if k in (1, 5) else lv2, f'Torch{k}', k * math.pi / 4, .86, .40, .22)
    standard(m, lv3, 'Standard', side_frame(math.pi / 4, .855, .80)[0], .55, 'flag_mortar', math.pi)
    # thicker barrel: the tube flares (Lv.2 x1.2, Lv.3 x1.4 across the bore axis, local Y);
    # the chamber between the cheeks only grows a little. Gold rings at Lv.3.
    rec = _node(m, 'RecoilAssembly')
    def _barrel(n, k):
        k = 1 + (k - 1) * (.3 if _short(n) in ('Chamber', 'BreechKnob') else 1)
        return (k, 1, k)
    gold = ('Band', 'MuzzleRing')
    variants(m, rec, [n for n in m.nodes if n.parent is rec and n.geo is not None],
             lambda n: (n.geo, n.mat, _barrel(n, 1.2)),
             lambda n: (n.geo, 'gold' if _short(n) in gold else n.mat, _barrel(n, 1.4)))


def levels_crossfire(m):
    base = _node(m, 'FixedBase')
    lv2, lv3 = m.empty('Level2', base), m.empty('Level3', base)
    only2 = fortress(m, base, lv2, lv3, (octagon(.695), octagon(.60), .305, .335))
    for i in (0, 4, 6):
        banner(m, only2, f'Banner{i}', i * math.pi / 4, .71, .35, 0, .14, .19, 'flag_crossfire')
    royal_banners(m, lv3, [(f'RoyalBanner{i}', (i * math.pi / 4, .71, .35, 0, .14, .19)) for i in (0, 4, 6)])
    feet(m, only2, lv3, radial_spots([i * math.pi / 4 for i in (1, 3, 5, 7)], .84),
         size=(.24, .26), top=(.17, .21), z=(.08, .20))
    gold_caps(m, _merlons(m, base, 'ButtressCap'), lv3)
    for k in (0, 2, 4, 6):
        torch(m, base if k in (0, 4) else lv2, f'Torch{k}', k * math.pi / 4, .67, .22, .17)
    for i in (1, 5):
        a = i * math.pi / 4
        standard(m, lv3, f'Standard{i}', (.98 * math.cos(a), .98 * math.sin(a), .08), .95, 'flag_crossfire', a + math.pi)
    # thicker launchers (rebuilt at a larger radius around their own axis), gold rings at Lv.3
    C = (.5, .5)
    for i, yaw in enumerate((0, -R90, math.pi, R90)):
        rec = _node(m, f'RecoilAssembly{i}')
        def place(geo, yaw=yaw):
            return move(rot_z(geo, yaw), (C[0], C[1], 0))
        def thick(n, k, gold, place=place):
            short = _short(n)
            if short.startswith('RadialLauncher'):
                return place(cyl_y(.07 * k, .26, .84, 10, .01)), n.mat, n.scale
            if short.startswith('LauncherRing'):
                return (place(merge(cyl_y(.092 * k, .76, .86, 10, .012), cyl_y(.085 * k, .40, .46, 10, .01))),
                        'gold' if gold else n.mat, n.scale)
            if short.startswith('LauncherBore'):
                return place(cyl_y(.045 * k, .80, .865, 8)), n.mat, n.scale
            return n.geo, n.mat, n.scale
        variants(m, rec, [n for n in m.nodes if n.parent is rec and n.geo is not None],
                 lambda n, thick=thick: thick(n, 1.2, False), lambda n, thick=thick: thick(n, 1.4, True))


def levels_ballista(m):
    base = _node(m, 'FixedBase')
    lv2, lv3 = m.empty('Level2', base), m.empty('Level3', base)
    cy = -.5
    only2 = fortress(m, base, lv2, lv3, (rect(.82, 1.82, 0, cy), rect(.72, 1.72, 0, cy), .34, .375))
    spots = ((0, .41, cy), (math.pi, .41, -cy), (-R90, 1.41, 0))
    for i, (theta, ap, t) in enumerate(spots):
        banner(m, only2, f'Banner{i}', theta, ap, .38, t, .16, .22, 'flag_ballista')
    royal_banners(m, lv3, [(f'RoyalBanner{i}', (theta, ap, .38, t, .16, .22)) for i, (theta, ap, t) in enumerate(spots)])
    feet(m, only2, lv3, corner_spots(.35, .85, cy), size=(.24, .24), top=(.16, .16), z=(.08, .30))
    gold_caps(m, _merlons(m, base), lv3)
    for k, (theta, ap, t) in enumerate(((R90, .385, -.19), (R90, .385, .19), (0, .38, .1), (math.pi, .38, 1.1),
                                        (-R90, 1.38, 0))):
        torch(m, base if k in (0, 1, 4) else lv2, f'Torch{k}', theta, ap, .26, t)
    standard(m, lv3, 'Standard', (.36, -1.36, .46), .58, 'flag_ballista', math.pi)
    # bow and bolt: stock, limbs, slider, winch, bolt (strings stay rope; they are animated)
    for part in ('WeaponMount', 'Slider', 'BoltCarrier', 'TensionLink', 'LimbPivot-1', 'LimbPivot1'):
        restyle(m, _node(m, part), skip=('BowString',))


def _swap_out(m, parent, name):
    """Move every mesh directly under `parent` into a Below<N> group (hidden from level N)."""
    g = _group(m, name, parent)
    for n in list(m.nodes):
        if n.parent is parent and n.geo is not None:
            n.parent = g
    return g


def tunnel_block(m, g, prefix, half, depth_front, top, mat, door_half=.17, back=.12):
    """Square storey with the barracks doorway tunnel (doors hang at y = .235)."""
    m.mesh(prefix + 'Back', cprism(rect(2 * half, half + back, 0, (back - half) / 2), .08, top, .015), mat, g)
    w = half - door_half
    for sx in (-1, 1):
        m.mesh(f'{prefix}Side{sx}', cprism(rect(w, depth_front - back, sx * (door_half + w / 2), (depth_front + back) / 2),
                                            .08, top, .012), mat, g)
    m.mesh(prefix + 'Lintel', cprism(rect(2 * door_half, depth_front - back, 0, (depth_front + back) / 2), .52, top),
           mat, g)
    m.mesh(prefix + 'Tunnel', box(2 * door_half, .01, .46, 0, (0, back + .006, .31)), 'bore', g)


def door_arch(m, g, prefix, front, mat='stone_light'):
    loc, rot = side_frame(R90, front + .005, 0)
    m.mesh(prefix + 'Arch', merge(*voussoirs(.20, .34, 7, .07)), mat, g, loc, rot)
    for sgn in (-1, 1):
        m.mesh(f'{prefix}Jamb{sgn}', box(.07, .07, .27, .01, (sgn * .20, 0, .21)), mat, g, loc, rot)


def window(m, g, name, at, yaw, w=.09, h=.13, frame='wood_dark'):
    m.mesh(name + 'Frame', box(w + .035, .016, h + .035, .004), frame, g, at, (0, 0, yaw))
    m.mesh(name, box(w, .022, h), 'bore', g, at, (0, 0, yaw))


def barracks_house(m, g):
    """Lv.2: two-storey guild hall - dark stone ground floor, timbered plaster upper floor,
    gabled roof with gold edge boards, a balcony over the gate and crimson banners."""
    m.mesh('L2Plinth', cprism(rect(.94, .94), 0, .08, .025), 'fort_dark', g)
    tunnel_block(m, g, 'L2Ground', .39, .36, .56, 'fort_mid')
    for sx in (-1, 1):   # inset blocks on the side walls
        for r, z in enumerate((.15, .29, .43)):
            for c, y in enumerate((-.25, 0.0, .25)):
                yy = y + (.06 if r % 2 else -.06)
                m.mesh(f'L2Block{sx}{r}{c}'.replace('-', 'm'), box(.014, .2, .1, .004), 'fort_light', g, (sx * .392, yy, z))
    door_arch(m, g, 'L2Gate', .36)
    m.mesh('L2Upper', cprism(rect(.82, .76), .56, .84, .01), 'plaster', g)
    m.mesh('L2BeamLow', ring_prism(rect(.85, .79), rect(.80, .74), .56, .60, .004), 'wood_dark', g)
    m.mesh('L2BeamTop', ring_prism(rect(.85, .79), rect(.80, .74), .80, .84, .004), 'wood_dark', g)
    posts = [box(.045, .045, .2, 0, (sx * .41, sy * .38, .70)) for sx in (-1, 1) for sy in (-1, 1)]
    posts += [box(.04, .02, .2, 0, (x, sy * .385, .70)) for x in (-.14, .14) for sy in (-1, 1)]
    posts += [box(.02, .04, .2, 0, (sx * .415, y, .70)) for y in (-.13, .13) for sx in (-1, 1)]
    m.mesh('L2Posts', merge(*posts), 'wood_dark', g)
    for sx in (-1, 1):
        for i, y in enumerate((-.26, 0.0, .26)):
            window(m, g, f'L2Win{sx}{i}'.replace('-', 'm'), (sx * .415, y, .70), R90)
    window(m, g, 'L2BalconyDoor', (0, .385, .69), 0, .13, .2)
    # balcony over the gate
    m.mesh('L2Balcony', box(.52, .12, .035, .006, (0, .42, .575)), 'wood', g)
    rail = [box(.03, .03, .09, 0, (x, .465, .64)) for x in (-.24, -.08, .08, .24)]
    rail += [box(.54, .025, .025, 0, (0, .465, .685))]
    rail += [box(.025, .10, .025, 0, (sx * .25, .415, .685)) for sx in (-1, 1)]
    m.mesh('L2Rail', merge(*rail), 'wood_dark', g)
    m.mesh('L2BalconyPosts', merge(*[box(.04, .04, .5, .006, (sx * .25, .46, .32)) for sx in (-1, 1)]), 'wood_dark', g)
    m.mesh('L2BalconyTrim', box(.54, .012, .02, 0, (0, .483, .555)), 'gold', g)
    # gabled roof, ridge front-to-back
    a = math.atan2(.32, .46)
    for sx in (-1, 1):
        m.mesh(f'L2Roof{sx}', box(.60, .92, .045, .008), 'wood', g, (sx * .235, 0, 1.02), (0, sx * a, 0))
        m.mesh(f'L2RoofRows{sx}', merge(*[box(.012, .92, .012, 0, (x, 0, .028)) for x in (-.15, -.03, .09, .21)]),
               'wood_dark', g, (sx * .235, 0, 1.02), (0, sx * a, 0))
        for sy in (-1, 1):
            m.mesh(f'L2Edge{sx}{sy}'.replace('-', 'm'), beam((sx * .49, sy * .465, .81), (0, sy * .465, 1.19), .035, .03),
                   'gold', g)
        m.mesh(f'L2Eave{sx}', box(.03, .93, .03, 0, (sx * .485, 0, .815)), 'gold', g)
    m.mesh('L2Gable', merge(prism_xz([(-.41, .84), (.41, .84), (0, 1.13)], .37, .38),
                            prism_xz([(-.41, .84), (.41, .84), (0, 1.13)], -.38, -.37),
                            cprism(rect(.80, .74), .84, .86)), 'plaster', g)
    m.mesh('L2Ridge', box(.05, .96, .05, .006, (0, 0, 1.18)), 'wood_dark', g)
    window(m, g, 'L2GableWin', (0, .385, .96), 0, .1, .1)
    pennant(m, g, 'L2Pennant', (0, .40, 1.19), .2, 'flag_barracks')
    for k, t in enumerate((-.28, .28)):
        placed = banner(m, g, f'L2Banner{k}', R90, .375, .48, t, .1, .2, 'crimson', rod='gold', edge='gold')
        emblem(m, g, f'L2Emblem{k}', placed, .03, 'gold')


def barracks_keep(m, g, royal=True):
    """Two-tier keep. Lv.3 (royal): black stone base with gold quoins, studs and a
    crenellated walk, a pale stone tower with gold bands and a roofed lookout on top.
    Lv.2 (royal=False): the same keep in dark grey stone with brass trim and iron studs,
    a shorter tower and an open timber roof on posts instead of the lookout."""
    P = 'L3' if royal else 'L2'
    base, body, dark = ('royal_dark', 'royal_mid', 'royal_dark') if royal else ('fort_dark', 'fort_mid', 'fort_dark')
    trim = 'gold' if royal else 'brass'
    studs_mat = 'gold' if royal else 'iron_light'
    flag = 'crimson' if royal else 'flag_barracks'
    top = .98 if royal else .90
    m.mesh(P + 'Plinth', cprism(rect(.96, .96), 0, .08, .025), base, g)
    tunnel_block(m, g, P + 'Ground', .44, .44, .56, body)
    door_arch(m, g, P + 'Gate', .44)
    m.mesh(P + 'Keystone', box(.07, .03, .08, .006, (0, .455, .555)), trim, g)
    m.mesh(P + 'Band', ring_prism(rect(.92, .92), rect(.86, .86), .54, .58, .004), trim, g)
    m.mesh(P + 'Walk', cprism(rect(.86, .86), .56, .585), dark, g)
    m.mesh(P + 'Quoins', merge(*[box(.035, .035, .46, 0, (sx * .443, sy * .443, .31)) for sx in (-1, 1) for sy in (-1, 1)]),
           trim if royal else 'fort_light', g)
    studs = []
    for sx in (-1, 1):
        for z in (.2, .38):
            for y in (-.3, -.1, .1, .3):
                studs.append(box(.012, .035, .035, 0, (sx * .447, y, z)))
    for z in (.2, .38):
        for x in (-.3, -.1, .1, .3):
            studs.append(box(.035, .012, .035, 0, (x, -.447, z)))
    m.mesh(P + 'Studs', merge(*studs), studs_mat, g)
    spots = [(sx * .40, sy * .40) for sx in (-1, 1) for sy in (-1, 1)] + [(0, -.40), (.40, 0), (-.40, 0), (0, .40)]
    m.mesh(P + 'Merlons', merge(*[box(.12, .12, .12, .015, (x, y, .64)) for x, y in spots]), 'stone_light', g)
    if royal:
        m.mesh(P + 'MerlonCaps', merge(*[move(pyramid(.08, .08, 0, .05), (x, y, .70)) for x, y in spots[:4]]), 'gold', g)
    # pale tower
    m.mesh(P + 'Tower', cprism(rect(.50, .50), .58, top, .012), 'stone_light', g)
    m.mesh(P + 'Courses', merge(*[ring_prism(rect(.512, .512), rect(.49, .49), z, z + .012) for z in (.70, .82) if z < top - .05]),
           'stone_mid', g)
    for i, theta in enumerate((0, math.pi, -R90)):
        loc, rot = side_frame(theta, .255, .78)
        m.mesh(f'{P}Slit{i}', box(.05, .02, .13), 'bore', g, loc, rot)
        m.mesh(f'{P}SlitFrame{i}', box(.085, .014, .165, .004), trim if royal else 'stone_mid', g,
               side_frame(theta, .251, .78)[0], rot)
    placed = banner(m, g, P + 'Banner', R90, .265, top - .04, 0, .16, .26, flag, rod=trim, edge='gold' if royal else None)
    emblem(m, g, P + 'Emblem', placed, .045, trim)
    m.mesh(P + 'TowerBand', ring_prism(rect(.56, .56), rect(.49, .49), top - .02, top + .02, .004), trim, g)
    tops = [(sx * .24, sy * .24) for sx in (-1, 1) for sy in (-1, 1)] + [(0, .24), (0, -.24), (.24, 0), (-.24, 0)]
    m.mesh(P + 'TopMerlons', merge(*[box(.10, .10, .10, .012, (x, y, top + .07)) for x, y in tops]), 'stone_light', g)
    if royal:
        m.mesh(P + 'Lookout', cprism(rect(.32, .32), 1.0, 1.17, .01), 'royal_dark', g)
        for i, theta in enumerate((0, R90, math.pi, -R90)):
            loc, rot = side_frame(theta, .162, 1.085)
            for t in (-.065, .065):
                l2, _ = side_frame(theta, .162, 1.085, t)
                m.mesh(f'L3LookWin{i}{"ab"[t > 0]}', box(.05, .02, .06), 'bore', g, l2, rot)
                m.mesh(f'L3LookWinFrame{i}{"ab"[t > 0]}', box(.07, .012, .08, .003), 'gold', g,
                       side_frame(theta, .158, 1.085, t)[0], rot)
        roof_z = 1.17
    else:
        # open timber roof on four posts, like the Lv.1 lookout
        m.mesh('L2RoofPosts', merge(*[box(.045, .045, .2, .006, (sx * .14, sy * .14, top + .12)) for sx in (-1, 1)
                                      for sy in (-1, 1)]), 'wood_dark', g)
        roof_z = top + .22
    m.mesh(P + 'RoofRim', cprism(rect(.44, .44), roof_z, roof_z + .03, .01), 'wood_dark', g)
    m.mesh(P + 'Roof', pyramid(.42, .42, roof_z + .03, roof_z + .25), 'wood', g)
    m.mesh(P + 'RoofCap', cyl_z(.03, roof_z + .23, roof_z + .28, 6), trim, g)
    if royal:
        m.empty(P + 'Beacon', g, (0, 0, roof_z + .5))
    pennant(m, g, P + 'Pennant', (0, 0, roof_z + .27), .2, 'flag_barracks')


def levels_barracks(m):
    base = _node(m, 'FixedBase')
    lv2, lv3 = m.empty('Level2', base), m.empty('Level3', base)
    _swap_out(m, base, 'Below2')
    only2 = _group(m, 'Below3Hall', lv2)
    barracks_keep(m, only2, royal=False)
    barracks_keep(m, lv3)
    for k, theta in enumerate((0, R90, math.pi, -R90)):
        torch(m, base if k % 2 == 0 else lv2, f'Torch{k}', theta, .39, .42, .27)


def _envelope(m, g, name, at, r, bands, nose=None):
    m.mesh(name, scaled(ico(1.0, 1), r), 'canvas', g, at)
    for n, (y, mat) in enumerate(bands):
        k = math.sqrt(max(0.0, 1 - (y / r[1]) ** 2))
        m.mesh(f'{name}Band{n}', scaled(cyl_y(1.0, -.5, .5, 12), (r[0] * 1.02 * k, .035, r[2] * 1.02 * k)), mat, g,
               (at[0], at[1] + y, at[2]))
    if nose:
        m.mesh(name + 'Nose', cone_z(r[0] * .45, 0, 0, .1, 8), nose, g, (at[0], at[1] + r[1] * .94, at[2]), (-R90, 0, 0))


def ship_raft(m, g):
    """Lv.2: twin-envelope gunboat - flat dark hull with gold rails, deck crates, stern propeller."""
    m.mesh('L2HullLow', cprism(rect(.58, 1.36, 0, -.06), -.20, -.04, .025), 'fort_dark', g)
    m.mesh('L2HullHigh', cprism(rect(.64, 1.46, 0, -.06), -.06, .05, .015), 'fort_mid', g)
    m.mesh('L2Stripe', ring_prism(rect(.655, 1.475, 0, -.06), rect(.62, 1.44, 0, -.06), -.025, -.005), 'gold', g)
    m.mesh('L2Deck', cprism(rect(.58, 1.40, 0, -.06), .05, .07), 'wood_light', g)
    m.mesh('L2Rail', ring_prism(rect(.66, 1.48, 0, -.06), rect(.60, 1.42, 0, -.06), .07, .105, .004), 'gold', g)
    m.mesh('L2Crates', merge(box(.13, .13, .10, .012, (.15, .30, .12)), box(.11, .11, .09, .01, (-.13, -.05, .115)),
                             box(.12, .12, .10, .012, (.12, -.42, .12))), 'wood_light', g)
    for sx in (-1, 1):
        _envelope(m, g, f'L2Envelope{sx}', (sx * .21, -.05, .52), (.19, .72, .18),
                  [(-.48, 'gold'), (-.22, 'flag_broadside'), (.08, 'flag_broadside'), (.40, 'gold')])
        for y in (-.35, .30):
            m.mesh(f'L2Strut{sx}{int(y * 100)}'.replace('-', 'm'), beam((sx * .25, y, .07), (sx * .21, y, .37), .03),
                   'wood_dark', g)
    m.mesh('L2PropPost', box(.05, .05, .22, .006, (0, -.72, .18)), 'wood_dark', g)
    m.mesh('L2PropShaft', cyl_y(.022, -.86, -.72, 6), 'iron', g, (0, 0, .28))
    m.mesh('L2PropHub', cyl_y(.05, -.92, -.85, 8, .008), 'gold', g, (0, 0, .28))
    for k in range(4):
        m.mesh(f'L2Blade{k}', box(.07, .02, .22, .006, (0, 0, .13)), 'wood', g, (0, -.89, .28), (0, k * R90 + .5, 0))
    m.mesh('L2Mast', cyl_z(.02, .07, .30, 6), 'wood_dark', g, (0, .55, 0))
    pennant(m, g, 'L2Pennant', (0, .55, .30), .16, 'flag_broadside')


def ship_galleon(m, g):
    """Lv.3: armoured sky galleon - black hull with gold strakes, stern castle with
    windows, one great envelope and two outrigger envelopes with gold noses."""
    hull = [(-.33, -.78), (.33, -.78), (.36, .20), (.24, .62), (0, .84), (-.24, .62), (-.36, .20)]
    sc = lambda k, ky=1.0: [(x * k, y * ky) for x, y in hull]
    m.mesh('L3Keel', cprism(sc(.55, .9), -.30, -.20, .015), 'royal_dark', g)
    m.mesh('L3HullLow', cprism(sc(.85, .96), -.20, -.08, .02), 'royal_dark', g)
    m.mesh('L3HullMid', cprism(sc(1.0), -.08, .04, .015), 'royal_mid', g)
    m.mesh('L3StrakeLow', cprism(sc(1.02, 1.01), -.095, -.075), 'gold', g)
    m.mesh('L3HullTop', cprism(sc(1.0), .04, .10, .012), 'royal_light', g)
    m.mesh('L3Deck', cprism(sc(.9, .94), .10, .115), 'wood_light', g)
    m.mesh('L3RailGold', ring_prism(sc(1.03, 1.015), sc(.95, .97), .10, .13, .004), 'gold', g)
    m.mesh('L3Ram', cone_z(.07, 0, 0, .12, 6), 'gold', g, (0, .80, -.04), (-R90, 0, 0))
    # stern castle
    m.mesh('L3Castle', cprism(rect(.60, .30, 0, -.62), .10, .34, .015), 'royal_mid', g)
    m.mesh('L3CastleRail', ring_prism(rect(.64, .34, 0, -.62), rect(.58, .28, 0, -.62), .34, .37, .004), 'gold', g)
    m.mesh('L3Cabin', cprism(rect(.30, .18, 0, -.66), .37, .50, .01), 'royal_dark', g)
    m.mesh('L3CabinRoof', cprism(rect(.36, .24, 0, -.66), .50, .54, .01), 'wood_dark', g)
    for i, x in enumerate((-.18, 0.0, .18)):
        window(m, g, f'L3SternWin{i}', (x, -.775, .23), 0, .07, .08, 'gold')
    for sx in (-1, 1):
        for i, y in enumerate((-.70, -.55)):
            window(m, g, f'L3SideWin{sx}{i}'.replace('-', 'm'), (sx * .302, y, .23), R90, .06, .07, 'gold')
        window(m, g, f'L3CabinWin{sx}'.replace('-', 'm'), (sx * .152, -.66, .435), R90, .05, .05, 'gold')
    pennant(m, g, 'L3Pennant', (0, -.66, .54), .26, 'flag_broadside')
    # crimson hull banners between the gun ports
    for k, (theta, t) in enumerate(((0, .25), (math.pi, -.25))):
        placed = banner(m, g, f'L3HullBanner{k}', theta, .325, .07, t, .11, .16, 'crimson', rod='gold', edge='gold')
        emblem(m, g, f'L3HullEmblem{k}', placed, .03, 'gold')
    # envelopes
    _envelope(m, g, 'L3Envelope', (0, -.02, .74), (.30, .80, .26),
              [(-.55, 'gold'), (-.30, 'flag_broadside'), (0.0, 'flag_broadside'), (.30, 'flag_broadside'), (.55, 'gold')],
              'gold')
    for sx in (-1, 1):
        _envelope(m, g, f'L3Side{sx}', (sx * .355, .05, .27), (.13, .48, .13),
                  [(-.25, 'flag_broadside'), (.20, 'gold')], 'gold')
        for y in (-.30, .35):
            m.mesh(f'L3Strut{sx}{int(y * 100)}'.replace('-', 'm'), beam((sx * .18, y, .12), (sx * .13, y, .52), .03),
                   'wood_dark', g)
            m.mesh(f'L3Arm{sx}{int(y * 100)}'.replace('-', 'm'), beam((sx * .30, y, .11), (sx * .355, y, .16), .03),
                   'gold', g)


def levels_broadside(m):
    ship = _node(m, 'Airship')
    lv2, lv3 = m.empty('Level2Ship', ship), m.empty('Level3Ship', ship)
    _swap_out(m, ship, 'Below2Ship')
    ship_raft(m, _group(m, 'Below3Ship', lv2))
    ship_galleon(m, lv3)
    base = _node(m, 'FixedBase')
    fortress(m, base, m.empty('Level2Dock', base), m.empty('Level3Dock', base))
    dock2 = _node(m, 'Level2Dock')
    for k, (x, y) in enumerate(((-.33, .33), (.33, .33), (-.33, -1.33), (.33, -1.33))):
        lamp_post(m, base if k < 2 else dock2, f'DockLamp{k}', (x, y, .38))


LEVELS = {'sentry': levels_sentry, 'ballista': levels_ballista, 'barracks': levels_barracks, 'mortar': levels_mortar,
          'crossfire': levels_crossfire, 'broadside': levels_broadside}


def _with_levels(build, name):
    def run():
        m = build()
        LEVELS[name](m)
        return m
    return run


BUILDERS = {'sentry': sentry, 'ballista': ballista, 'barracks': barracks, 'mortar': mortar,
            'crossfire': crossfire, 'broadside': broadside}
BUILDERS = {k: _with_levels(v, k) for k, v in BUILDERS.items()}


def check(model):
    cells = FOOTPRINTS[model.asset]
    tris, outside, below, hi = 0, 0, 0, 0.0
    for n in model.nodes:
        if n.geo is None:
            continue
        M = world(n)
        verts, faces = n.geo
        tris += sum(len(f) - 2 for f in faces)
        for p in verts:
            q = apply(M, p)
            hi = max(hi, q[2])
            below += q[2] < -1e-4
            outside += not any(abs(q[0] - cx) <= .5001 and abs(q[1] - cy) <= .5001 for cx, cy in cells)
    return {'triangles': tris, 'nodes': len(model.nodes), 'outside_footprint': outside, 'below_floor': below,
            'height': round(hi, 3)}
