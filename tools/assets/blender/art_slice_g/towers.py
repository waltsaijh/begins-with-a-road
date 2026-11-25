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


BUILDERS = {'sentry': sentry, 'ballista': ballista, 'barracks': barracks, 'mortar': mortar,
            'crossfire': crossfire, 'broadside': broadside}


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
