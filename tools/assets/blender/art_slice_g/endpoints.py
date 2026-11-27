"""Art Slice G endpoints: the player's 3x3 castle (Goal) and the enemy camp (Start).

    python endpoints.py            -> assets/models/endpoints/castle.glb, camp.glb
    then: godot --headless --path . --script res://tools/assets/build_endpoints_g.gd

Blender axes like towers.py: Z up, +Y = front. The castle's gate and the camp's tent
door face +Y; scripts/map/terrain/endpoint_visual.gd turns +Y toward the road at run
time. Origin = centre of the endpoint cell at the road surface.

Castle: the goal cell plus its 8 neighbours (TowerMap keeps the ring free of towers
and roads), except the road cell in front of the gate, which stays a normal road tile
that the gatehouse arches over. Camp: fits inside its one road cell, leaving the
middle and front of the cell clear for the spawning troops.
"""
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from style import (Model, PALETTE, box, cprism, cyl_z, cone_z, merge, move, rot_z, rect, octagon,  # noqa: E402
                   pyramid, prism_xz, prism_yz, ring_prism, voussoirs, side_frame, pennant, beam, ico,
                   wall_rect, wall_ring, moss)

PALETTE.update({'crystal': '#8FD3DB', 'crystal_light': '#C9F0F2', 'roof': '#A4573C', 'roof_dark': '#7A3F2C',
                'tent': '#E6D3B3', 'tent_stripe': '#C04A34', 'tent_shade': '#4A3326', 'tent_shade_light': '#CDB896', 'bedroll': '#7A6E62',
                'ash': '#4A4440', 'ember': '#E07A32'})
R90 = math.pi / 2


def lamp(m, parent, name, at):
    """Night light hook (endpoint_visual.gd puts a flame and a light here)."""
    m.empty(name + 'Lamp', parent, at)


def wall_torch(m, parent, name, at, yaw):
    x, y, z = at
    m.mesh(name + 'Bracket', move(rot_z(merge(box(.025, .07, .025, .004, (0, .035, 0)),
                                              box(.025, .025, .05, .004, (0, .065, .02))), yaw), (x, y, z)), 'iron', parent)
    m.mesh(name + 'Cup', move(rot_z(cone_z(.022, .04, .045, .09, 6), yaw), (x, y, z)), 'iron_light', parent,
           (-math.sin(yaw) * .065, math.cos(yaw) * .065, 0))
    lamp(m, parent, name, (x - math.sin(yaw) * .065, y + math.cos(yaw) * .065, z + .1))


def crenels(m, parent, name, x0, y0, x1, y1, z, step=.2, size=.1, mat='stone_light'):
    n = max(1, int(round(math.hypot(x1 - x0, y1 - y0) / step)))
    pieces = []
    for i in range(n + 1):
        t = i / n
        if i % 2 == 0:
            pieces.append(box(size, size, .1, .012, (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + .05)))
    m.mesh(name, merge(*pieces), mat, parent)


def castle():
    m = Model('castle', 5)
    root = m.empty('Model')
    # floating island under the whole 3x3 (sides match the sky-island road tiles)
    m.mesh('IslandLip', cprism(rect(3.0, 3.0), -.03, 0.0, .01), 'moss', root)
    m.mesh('IslandBand', cprism(rect(3.0, 3.0), -.175, -.03, .01), 'stone_mid', root)
    m.mesh('IslandSeam', cprism(rect(2.98, 2.98), -.19, -.175), 'stone_dark', root)
    m.mesh('IslandBase', cprism(rect(3.0, 3.0), -.37, -.19, .02), 'grout', root)
    for i, (r, z0, z1) in enumerate(((1.25, -.62, -.37), (.95, -.9, -.62), (.6, -1.18, -.9), (.28, -1.4, -1.18))):
        m.mesh(f'Rock{i}', cprism(octagon(r), z0, z1, .03), 'stone_dark' if i % 2 else 'grout', root)
    # courtyard floor around the gate road (the road tile itself fills x[-.5,.5], y[.5,1.5])
    floor = merge(cprism(rect(.95, 2.9, -.975, 0), 0, .02), cprism(rect(.95, 2.9, .975, 0), 0, .02),
                  cprism(rect(1.0, 1.95, 0, -.475), 0, .02))
    m.mesh('Courtyard', floor, 'stone_light', root)
    # curtain walls: the sentry tower's block-coursed stone (style.wall_rect), with the
    # gate opening in the front (+Y) wall over the road cell
    courses = [(0, .2), (.2, .4), (.4, .58)]
    wall_rect(m, root, 'Curtain', (0, 0), 1.36, 1.36, courses, .1, openings={1: (.44, .5)})
    m.mesh('CurtainCornice', merge(*[cprism(r, .58, .64, .012) for r in (
        rect(2.96, .2, 0, -1.36), rect(.2, 2.96, -1.36, 0), rect(.2, 2.96, 1.36, 0),
        rect(1.06, .2, -.95, 1.36), rect(1.06, .2, .95, 1.36))]), 'stone_light', root)
    for k, ((x0, y0), (x1, y1)) in enumerate((((-1.36, -1.36), (1.36, -1.36)), ((-1.36, -1.36), (-1.36, 1.36)),
                                              ((1.36, -1.36), (1.36, 1.36)), ((-1.36, 1.36), (-.5, 1.36)),
                                              ((.5, 1.36), (1.36, 1.36)))):
        crenels(m, root, f'Crenels{k}', x0, y0, x1, y1, .64)
    for th, spots in ((0, [(.6, .14, .1), (-.5, .3, .08)]), (math.pi, [(.2, .12, .11)]), (-R90, [(-.7, .13, .09), (.4, .4, .07)])):
        moss(m, root, f'Moss{int(math.degrees(th)) % 360}', th, 1.42, spots)
    # corner towers: coursed octagons with red conical roofs
    tower_courses = [(0, .2), (.2, .4), (.4, .6), (.6, .8), (.8, 1.0)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            n = f'Tower{sx}{sy}'.replace('-', 'm')
            c = (sx * 1.25, sy * 1.25)
            at = (c[0], c[1], 0)
            m.mesh(n + 'Core', cprism(octagon(.26), 0, 1.0), 'grout', root, at)
            wall_ring(m, root, n + 'Wall', .27, 8, tower_courses, .08, centre=c)
            m.mesh(n + 'Cornice', ring_prism(octagon(.37), octagon(.25), 1.0, 1.08, .01), 'stone_light', root, at)
            m.mesh(n + 'Roof', cone_z(.4, .02, 1.08, 1.64, 8), 'roof', root, at)
            m.mesh(n + 'RoofRim', cprism(octagon(.4), 1.06, 1.1), 'roof_dark', root, at)
            m.mesh(n + 'Cap', cyl_z(.03, 1.62, 1.68, 6), 'brass', root, at)
            pennant(m, root, n + 'Flag', (c[0], c[1], 1.66), .22, 'flag_sentry')
    # gatehouse over the road: two coursed square towers and an arch
    for sx in (-1, 1):
        n = f'Gate{sx}'.replace('-', 'm')
        c = (sx * .66, 1.38)
        m.mesh(n + 'Core', cprism(rect(.3, .32, *c), 0, .9), 'grout', root)
        wall_rect(m, root, n + 'Wall', c, .17, .18, [(0, .22), (.22, .45), (.45, .68), (.68, .9)], .07)
        m.mesh(n + 'Cornice', cprism(rect(.42, .44, *c), .9, .96, .01), 'stone_light', root)
        m.mesh(n + 'Merlons', merge(*[box(.1, .1, .1, .012, (c[0] + dx, c[1] + dy, 1.01)) for dx in (-.15, .15) for dy in (-.16, .16)]),
               'stone_light', root)
    m.mesh('GateLintel', cprism(rect(1.0, .3, 0, 1.38), .66, .9, .01), 'stone_light', root)
    m.mesh('GateArch', merge(*voussoirs(.36, .5, 9, .3, (.09, .08))), 'stone_mid', root, (0, 1.38, 0))
    m.mesh('GateCrenels', merge(*[box(.1, .1, .1, .012, (x, 1.38, .95)) for x in (-.3, 0, .3)]), 'stone_light', root)
    m.mesh('Portcullis', merge(*[box(.02, .02, .2, 0, (x, 1.42, .74)) for x in (-.3, -.15, 0, .15, .3)],
                               box(.66, .02, .02, 0, (0, 1.42, .68))), 'iron', root)
    k = -.17   # banner over the gate: rectangle plus two tail points (prisms must be convex)
    m.mesh('GateBanner', merge(prism_xz([(-.14, 0), (.14, 0), (.14, k), (-.14, k)], -.006, .006),
                               prism_xz([(-.14, k), (0, k), (-.14, -.22)], -.006, .006),
                               prism_xz([(0, k), (.14, k), (.14, -.22)], -.006, .006)), 'flag_sentry', root, (0, 1.545, .88))
    m.mesh('GateBannerTrim', box(.3, .016, .02, 0, (0, 1.548, .88)), 'brass', root)
    for sx in (-1, 1):
        wall_torch(m, root, f'GateTorch{sx}'.replace('-', 'm'), (sx * .66, 1.6, .5), 0)
    # keep on the goal cell (coursed like the sentry), door facing the gate
    m.mesh('KeepCore', cprism(rect(.7, .7), 0, 1.3), 'grout', root)
    wall_rect(m, root, 'Keep', (0, 0), .38, .38, [(0, .22), (.22, .44), (.44, .66), (.66, .88), (.88, 1.1), (1.1, 1.3)],
              .08, openings={1: (.15, .38)})
    m.mesh('KeepCornice', cprism(rect(.96, .96), 1.3, 1.38, .012), 'stone_light', root)
    crenels(m, root, 'KeepCrenelsF', -.44, .44, .44, .44, 1.38, .17, .11)
    crenels(m, root, 'KeepCrenelsB', -.44, -.44, .44, -.44, 1.38, .17, .11)
    crenels(m, root, 'KeepCrenelsL', -.44, -.27, -.44, .27, 1.38, .17, .11)
    crenels(m, root, 'KeepCrenelsR', .44, -.27, .44, .27, 1.38, .17, .11)
    loc, rot = side_frame(R90, .43, 0)
    m.mesh('KeepDoorArch', merge(*voussoirs(.17, .38, 7, .07, (.06, .05))), 'stone_light', root, loc, rot)
    m.mesh('KeepDoor', box(.3, .02, .38, 0, (0, .34, .19)), 'bore', root)
    for i, th in enumerate((0, math.pi, -R90)):
        loc2, rot2 = side_frame(th, .455, .95, 0)
        m.mesh(f'KeepSlit{i}', box(.05, .05, .15), 'bore', root, loc2, rot2)
    wall_torch(m, root, 'KeepTorch', (.3, .46, .5), 0)
    # the goal crystal crowning the keep
    m.mesh('CrystalHolder', merge(cyl_z(.16, 1.38, 1.45, 8, .01), cone_z(.14, .05, 1.45, 1.55, 8)), 'brass', root)
    m.mesh('Crystal', merge(cone_z(.13, 0, 1.75, 2.15, 6), move(cone_z(.13, 0, 0, -.2, 6), (0, 0, 1.75))),
           'crystal', root)
    m.mesh('CrystalCore', merge(cone_z(.06, 0, 1.8, 2.02, 6)), 'crystal_light', root)
    pennant(m, root, 'KeepFlag', (-.36, -.36, 1.38), .5, 'flag_sentry')
    return m


def camp():
    """A-frame tent with its door on the front gable (troops spawn inside and walk out
    toward the road), red trim, tied-back curtains, bedrolls, corner stakes, a pennant on
    the ridge pole and two standing torches flanking the door."""
    m = Model('camp', 9)
    root = m.empty('Model')
    W, H, Y0, Y1, T = .37, .44, -.36, .24, .025   # half width, ridge height, back / front, canvas thickness
    for sx in (-1, 1):
        side = [(sx * W, 0), (sx * (W - T * 1.3), 0), (0, H - T * 1.6), (0, H)]
        m.mesh(f'Canvas{sx}'.replace('-', 'm'), _slope(side, Y0, Y1), 'tent', root)
    m.mesh('BackGable', prism_xz([(-W, 0), (W, 0), (0, H)], Y0, Y0 + .02), 'tent', root)
    m.mesh('Inside', merge(prism_xz([(-W + .05, 0), (W - .05, 0), (0, H - .07)], Y0 + .025, Y0 + .03),
                           cprism(rect(2 * W - .06, Y1 - Y0 - .04, 0, (Y0 + Y1) / 2), 0, .004)), 'tent_shade', root)
    # front gable: canvas panels framing a triangular doorway, flaps tied back over them
    DW, DH = .16, .34
    m.mesh('DoorShadow', prism_xz([(-DW, 0), (DW, 0), (0, DH)], Y1 - .06, Y1 - .05), 'tent_shade', root)
    door_trim = [beam((sx * DW, Y1 + .008, 0), (0, Y1 + .008, DH), .03, .016) for sx in (-1, 1)]
    m.mesh('DoorTrim', merge(*door_trim), 'tent_stripe', root)
    for sx in (-1, 1):
        n = f'{sx}'.replace('-', 'm')
        panel = [(sx * W, 0), (sx * DW, 0), (0, DH), (0, H)]
        m.mesh('FrontGable' + n, prism_xz(panel, Y1 - .02, Y1), 'tent', root)
        flap = [(sx * .02, DH - .02), (sx * (DW + .02), 0), (sx * (DW + .13), 0)]
        m.mesh('Flap' + n, prism_xz(flap, Y1, Y1 + .014), 'tent_shade_light', root)
        m.mesh('FlapTie' + n, box(.06, .02, .025, .004, (sx * (DW + .06), Y1 + .016, .12)), 'tent_stripe', root)
    for sx in (-1, 1):
        m.mesh(f'Bedroll{sx}'.replace('-', 'm'), merge(box(.12, .26, .03, .01, (sx * .12, Y0 + .2, .015)),
                                                       box(.12, .05, .05, .015, (sx * .12, Y0 + .07, .03))), 'bedroll', root)
    # red trim: ridge and the four sloped edges
    trim = [box(.05, Y1 - Y0 + .06, .04, .006, (0, (Y0 + Y1) / 2, H + .005))]
    for y in (Y0, Y1):
        for sx in (-1, 1):
            trim.append(beam((sx * (W + .005), y, 0), (0, y, H + .01), .045, .02))
    m.mesh('Trim', merge(*trim), 'tent_stripe', root)
    m.mesh('RidgeEnds', merge(box(.045, .05, .045, .008, (0, Y1 + .04, H + .005)), box(.045, .05, .045, .008, (0, Y0 - .04, H + .005))),
           'wood', root)
    # pennant on the ridge pole
    m.mesh('FlagPole', cyl_z(.014, H, H + .3, 6), 'wood', root, (0, Y1 - .04, 0))
    m.mesh('FlagCap', box(.03, .03, .03, .006, (0, Y1 - .04, H + .31)), 'wood_dark', root)
    m.mesh('Flag', prism_xz([(0, 0), (.22, -.06), (0, -.12)], -.006, .006), 'tent_stripe', root, (.014, Y1 - .04, H + .29))
    # corner stakes with red ties
    stakes = []
    ties = []
    for sx in (-1, 1):
        for y in (Y0 + .02, Y1 - .02):
            stakes.append(box(.03, .03, .1, .006, (sx * (W + .03), y, .05)))
            ties.append(box(.045, .045, .025, .006, (sx * (W + .03), y, .03)))
    m.mesh('Stakes', merge(*stakes), 'wood', root)
    m.mesh('StakeTies', merge(*ties), 'tent_stripe', root)
    # standing torches in front of the door (lit at dusk / night)
    for sx in (-1, 1):
        n = f'Torch{sx}'.replace('-', 'm')
        x, y = sx * .3, .4
        m.mesh(n + 'Post', cyl_z(.02, 0, .3, 6), 'wood_dark', root, (x, y, 0))
        m.mesh(n + 'Band', cyl_z(.026, .22, .24, 6), 'iron', root, (x, y, 0))
        m.mesh(n + 'Bowl', cone_z(.03, .055, .3, .35, 6), 'iron', root, (x, y, 0))
        lamp(m, root, n, (x, y, .4))
    return m


def _slope(poly, y0, y1):
    """A tent side: the x/z outline extruded along Y (front to back)."""
    return prism_xz(poly, y0, y1)


if __name__ == '__main__':
    import gltf_writer
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parents[3] / 'assets' / 'models' / 'endpoints'
    out.mkdir(parents=True, exist_ok=True)
    for build in (castle, camp):
        model = build()
        gltf_writer.write(model, out / f'{model.asset}.glb')
        tris = 0
        for n in model.nodes:
            if n.geo is not None: tris += sum(len(f) - 2 for f in n.geo[1])
        print(model.asset, 'triangles', tris)
