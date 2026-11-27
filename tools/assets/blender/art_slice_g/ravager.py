"""Siege Behemoth (ravager) for the Art Slice G enemy look: a shaggy war mammoth
carrying a wooden howdah with a hooded gunner, red saddle cloth and leather straps.

    python ravager.py [out_dir]      writes ravager.glb (default assets/models/enemies/art_g)

Blender axes (Z up, +Y = front) converted to glTF like gltf_writer. Every part is
one mesh with per-face vertex colours (COLOR_0, linear), which is what
tools/assets/build_enemy_art_g.gd and the shared enemy material expect. Moving
parts are separate nodes with their pivot as origin: LegFL/LegFR/LegBL/LegBR at
the hips, Tail at its root; everything else is Body.
Then run in Godot: tools/assets/build_enemy_art_g.gd -- --only=ravager
"""
import json
import math
import random
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import style  # noqa: E402
from gltf_writer import conv, newell  # noqa: E402

REPO = HERE.parents[3]
COL = {
    'fur_dark': '#8E3E22', 'fur': '#B2532C', 'fur_light': '#C8693A', 'skin': '#A85634', 'skin_dark': '#7C3A24',
    'tusk': '#E9DCB8', 'tusk_shade': '#CDBE98', 'nail': '#D4C29C', 'eye': '#1C1816',
    'cloth': '#C2372E', 'cloth_dark': '#8E2622', 'strap': '#7A5234', 'buckle': '#C89A50',
    'wood': '#A8723E', 'wood_dark': '#7E5230', 'wood_light': '#C08A4C',
    'hood': '#C2372E', 'hood_dark': '#8E2622', 'face': '#D9A47A', 'leather': '#6B4226', 'tunic': '#7E4E2E',
    'bow': '#7B5230', 'string': '#EDE4CC', 'arrow': '#9B7A50', 'fletch': '#E4DAC2', 'iron': '#4A4E52',
}
RNG = random.Random(11)


# ------------------------------------------------------------------ geometry
class Part:
    def __init__(self, name, pivot=(0, 0, 0)):
        self.name, self.pivot = name, pivot
        self.faces = []        # (points[], colour key)

    def poly(self, pts, colour, outward_from=None):
        pts = [tuple(p) for p in pts]
        if outward_from is not None:
            n = newell(pts)
            c = [sum(p[i] for p in pts) / len(pts) for i in range(3)]
            d = [c[i] - outward_from[i] for i in range(3)]
            if n[0] * d[0] + n[1] * d[1] + n[2] * d[2] < 0:
                pts = pts[::-1]
        self.faces.append((pts, colour))

    def geo(self, geo, colour, offset=(0, 0, 0)):
        verts, faces = geo
        for f in faces:
            self.faces.append(([tuple(verts[i][k] + offset[k] for k in range(3)) for i in f], colour))


def ring_pts(centre, u, v, rx, ry, sides, jag=0.0, phase=0.0):
    pts = []
    for i in range(sides):
        a = phase + i * math.tau / sides
        k = 1.0 + (jag if i % 2 else -jag * 0.4)
        pts.append(tuple(centre[j] + (u[j] * math.cos(a) * rx + v[j] * math.sin(a) * ry) * k for j in range(3)))
    return pts


def tube(part, rings, colours, cap0=True, cap1=True):
    """rings: list of (centre, point list) with equal counts; colours per band (cycled)."""
    n = len(rings[0][1])
    for r in range(len(rings) - 1):
        (c0, a), (c1, b) = rings[r], rings[r + 1]
        mid = [(c0[i] + c1[i]) / 2 for i in range(3)]
        col = colours[r % len(colours)]
        for i in range(n):
            j = (i + 1) % n
            part.poly([a[i], a[j], b[j], b[i]], col if not callable(col) else col(r, i), mid)
    if cap0:
        part.poly(rings[0][1], colours[0] if not callable(colours[0]) else colours[0](0, 0),
                  [rings[0][0][i] * 2 - rings[1][0][i] for i in range(3)])
    if cap1:
        last = rings[-1]
        part.poly(last[1], colours[-1] if not callable(colours[-1]) else colours[-1](0, 0),
                  [last[0][i] * 2 - rings[-2][0][i] for i in range(3)])


def loft_y(part, sections, sides, colours, jag=0.0, cap0=True, cap1=True):
    """sections: (y, rx, rz, cz); rings around the Y axis (the beast's length)."""
    rings = []
    for k, (y, rx, rz, cz) in enumerate(sections):
        rings.append(((0, y, cz), ring_pts((0, y, cz), (1, 0, 0), (0, 0, 1), rx, rz, sides, jag, (k % 2) * math.pi / sides)))
    tube(part, rings, colours, cap0, cap1)


def frame(d):
    l = math.sqrt(sum(c * c for c in d)) or 1
    d = [c / l for c in d]
    up = (0, 0, 1) if abs(d[2]) < .9 else (1, 0, 0)
    u = [d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0]]
    lu = math.sqrt(sum(c * c for c in u))
    u = [c / lu for c in u]
    v = [d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0]]
    return u, v


def path_tube(part, points, radii, sides, colours, cap1=True):
    rings = []
    for k, p in enumerate(points):
        a = points[max(0, k - 1)]
        b = points[min(len(points) - 1, k + 1)]
        u, v = frame([b[i] - a[i] for i in range(3)])
        rings.append((p, ring_pts(p, u, v, radii[k], radii[k], sides)))
    tube(part, rings, colours, True, cap1)


def tufts(part, centre, rx, ry, z, count, length, width, colours, tilt=0.35, arc=(0, math.tau)):
    """A fringe of downward fur points around an ellipse (the shaggy hem)."""
    for i in range(count):
        a = arc[0] + (arc[1] - arc[0]) * (i + .5) / count
        ca, sa = math.cos(a), math.sin(a)
        base = (centre[0] + rx * ca, centre[1] + ry * sa, z)
        t = (-sa, ca, 0)
        out = (ca, sa, 0)
        ln = length * RNG.uniform(.75, 1.2)
        w = width * RNG.uniform(.85, 1.15)
        p1 = tuple(base[j] + t[j] * w / 2 for j in range(3))
        p2 = tuple(base[j] - t[j] * w / 2 for j in range(3))
        p3 = tuple(base[j] - out[j] * w * .5 + (0, 0, .02)[j] for j in range(3))
        tip = (base[0] + out[0] * ln * tilt, base[1] + out[1] * ln * tilt, z - ln)
        c = colours[i % len(colours)]
        cen = [(p1[j] + p2[j] + p3[j] + tip[j]) / 4 for j in range(3)]
        for f in ([p1, p2, tip], [p2, p3, tip], [p3, p1, tip], [p1, p3, p2]):
            part.poly(f, c, cen)


def box(part, centre, size, colour, rot_z=0.0):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    c, s = math.cos(rot_z), math.sin(rot_z)
    def p(x, y, z): return (centre[0] + x * c - y * s, centre[1] + x * s + y * c, centre[2] + z)
    v = [p(x, y, z) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
    for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        part.poly([v[i] for i in f], colour, centre)


def beam(part, a, b, w, colour):
    u, v = frame([b[i] - a[i] for i in range(3)])
    pts = []
    for p in (a, b):
        for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            pts.append(tuple(p[i] + (u[i] * su + v[i] * sv) * w / 2 for i in range(3)))
    cen = [(a[i] + b[i]) / 2 for i in range(3)]
    for f in ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        part.poly([pts[i] for i in f], colour, cen)


# ------------------------------------------------------------------ the beast
FUR = ['fur', 'fur_dark', 'fur_light', 'fur']
HIP_Z = .86


def body():
    b = Part('Body')
    # Torso: high shoulder hump, sloping rump, jagged fur sections.
    loft_y(b, [(-.86, .2, .22, 1.0), (-.74, .38, .4, 1.02), (-.45, .5, .5, 1.06), (-.05, .55, .56, 1.12),
               (.32, .54, .62, 1.2), (.58, .46, .56, 1.22), (.74, .3, .4, 1.2)], 14, FUR, jag=.06)
    # Shaggy hem under the belly and flanks.
    tufts(b, (0, -.05), .5, .72, .7, 30, .24, .16, ['fur_dark', 'fur', 'fur_dark'])
    tufts(b, (0, -.05), .44, .66, .96, 22, .2, .15, ['fur', 'fur_light'], tilt=.5)
    # Head with domed brow, cheeks and a fur mane over the neck.
    loft_y(b, [(.62, .26, .3, 1.2), (.78, .3, .36, 1.24), (.95, .27, .34, 1.22), (1.08, .19, .26, 1.14), (1.14, .12, .16, 1.08)],
           12, ['fur', 'fur_light', 'skin', 'skin'], jag=.04)
    tufts(b, (0, .66), .3, .14, 1.42, 9, .16, .12, ['fur_light', 'fur'], tilt=.9, arc=(.2, math.pi - .2))
    tufts(b, (0, .82), .31, .2, 1.1, 10, .18, .11, ['fur_dark', 'fur'], tilt=.2, arc=(-math.pi * .9, -math.pi * .1))
    for sx in (-1, 1):
        # Ears: small flat flaps.
        b.poly([(sx * .27, .74, 1.36), (sx * .44, .7, 1.3), (sx * .45, .7, 1.12), (sx * .3, .74, 1.08)], 'skin', (0, .9, 1.2))
        b.poly([(sx * .27, .72, 1.36), (sx * .44, .68, 1.3), (sx * .45, .68, 1.12), (sx * .3, .72, 1.08)], 'skin_dark', (0, .5, 1.2))
        box(b, (sx * .2, 1.0, 1.32), (.06, .05, .045), 'eye')
        box(b, (sx * .2, .98, 1.375), (.12, .06, .03), 'fur_dark')     # stern brow
        # Tusks: long ivory curves sweeping forward, out and up.
        pts = [(sx * .14, 1.05, 1.02), (sx * .19, 1.25, .9), (sx * .25, 1.45, .9), (sx * .28, 1.6, 1.0), (sx * .26, 1.7, 1.15), (sx * .21, 1.74, 1.28)]
        path_tube(b, pts, [.065, .06, .052, .04, .028, .01], 6, ['tusk', 'tusk', 'tusk_shade', 'tusk', 'tusk'])
    # Trunk: segmented, hanging forward then curling up; dark tip.
    trunk = [(0, 1.12, 1.08), (0, 1.24, .9), (0, 1.36, .78), (0, 1.5, .76), (0, 1.6, .86), (0, 1.64, .98)]
    path_tube(b, trunk, [.13, .115, .1, .085, .075, .07], 8, ['skin', 'skin_dark', 'skin', 'skin_dark', 'skin'])
    # Tail stub sits on the Tail part.
    # Saddle cloth over the back: top panel and two pointed side panels.
    top = 1.64
    for sx in (-1, 1):
        side = [(sx * .5, -.32, 1.48), (sx * .5, .34, 1.52), (sx * .57, .34, 1.12), (sx * .58, .01, .98), (sx * .57, -.32, 1.1)]
        b.poly(side, 'cloth', (0, 0, 1.2))
        b.poly([(p[0] - sx * .025, p[1], p[2]) for p in side], 'cloth_dark', (sx * 2, 0, 1.2))
        hem = [(sx * .585, -.33, 1.1), (sx * .595, .01, .96), (sx * .585, .35, 1.12)]
        for a, c in zip(hem, hem[1:]):
            beam(b, a, c, .035, 'cloth_dark')
    b.poly([(-.5, -.32, 1.48), (.5, -.32, 1.48), (.5, .34, 1.52), (-.5, .34, 1.52)], 'cloth', (0, 0, 0))
    # Leather girth straps with brass buckles.
    for y in (-.2, .22):
        ring = [(math.cos(a) * .6, y, 1.12 + math.sin(a) * .62) for a in [i * math.tau / 14 for i in range(14)]]
        for a, c in zip(ring, ring[1:] + ring[:1]):
            beam(b, a, c, .06, 'strap')
        for sx in (-1, 1):
            box(b, (sx * .6, y, .98), (.04, .1, .1), 'buckle')
            box(b, (sx * .615, y, .98), (.02, .06, .06), 'strap')
    # Howdah: plank floor, corner posts with caps, rails and X braces.
    floor = 1.55
    box(b, (0, 0, floor), (.7, .72, .06), 'wood_dark')
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(b, (sx * .32, sy * .33, floor + .2), (.07, .07, .4), 'wood')
            box(b, (sx * .32, sy * .33, floor + .42), (.1, .1, .05), 'wood_light')
    for z in (floor + .1, floor + .34):
        for sx in (-1, 1):
            beam(b, (sx * .32, -.33, z), (sx * .32, .33, z), .045, 'wood_light' if z > floor + .2 else 'wood')
            beam(b, (-.32, sx * .33, z), (.32, sx * .33, z), .045, 'wood_light' if z > floor + .2 else 'wood')
    for sx in (-1, 1):
        beam(b, (sx * .325, -.3, floor + .12), (sx * .325, 0, floor + .32), .03, 'wood_dark')
        beam(b, (sx * .325, .3, floor + .12), (sx * .325, 0, floor + .32), .03, 'wood_dark')
        beam(b, (-.3, sx * .335, floor + .12), (0, sx * .335, floor + .32), .03, 'wood_dark')
        beam(b, (.3, sx * .335, floor + .12), (0, sx * .335, floor + .32), .03, 'wood_dark')
    first = len(b.faces)
    gunner(b, floor + .03)
    # Stand the rider a little larger than life so the rider reads from the game camera.
    k, origin = 1.25, (0, -.02, floor + .03)
    b.faces[first:] = [([tuple(origin[i] + (p[i] - origin[i]) * k for i in range(3)) for p in pts], c) for pts, c in b.faces[first:]]
    return b


def gunner(b, z0):
    """Hooded gunner standing in the howdah, long gun aimed toward the front."""
    cx, cy = 0, -.02
    # Body: tunic torso and belt (legs hidden by the rails).
    for k, (h0, h1, r, c) in enumerate([(0, .3, .14, 'tunic'), (.3, .34, .15, 'leather'), (.34, .58, .14, 'tunic')]):
        rings = []
        for h in (h0, h1):
            p = (cx, cy, z0 + h)
            rings.append((p, ring_pts(p, (1, 0, 0), (0, 1, 0), r, r * .8, 8)))
        tube(b, rings, [c])
    # Cloak hanging down the back, hood with a dark face opening.
    b.poly([(-.17, cy - .1, z0 + .6), (.17, cy - .1, z0 + .6), (.2, cy - .2, z0 + .08), (-.2, cy - .2, z0 + .08)], 'hood', (0, cy + 1, z0))
    b.poly([(-.17, cy - .11, z0 + .6), (.17, cy - .11, z0 + .6), (.2, cy - .21, z0 + .08), (-.2, cy - .21, z0 + .08)], 'hood_dark', (0, cy - 1, z0))
    head = (cx, cy + .02, z0 + .7)
    loft_rings = []
    for h, r in ((-.1, .13), (0, .14), (.08, .12), (.16, .06), (.2, .01)):
        p = (head[0], head[1] - h * .35, head[2] + h)
        loft_rings.append((p, ring_pts(p, (1, 0, 0), (0, 1, 0), r, r, 8)))
    tube(b, loft_rings, ['hood', 'hood', 'hood_dark', 'hood'])
    box(b, (cx, cy + .14, z0 + .68), (.13, .04, .12), 'face')
    box(b, (cx, cy + .16, z0 + .64), (.1, .02, .04), 'tunic')          # beard
    # Long gun shouldered and aimed forward: right hand on the stock at the cheek,
    # left hand under the barrel. Its muzzle is the sabotage shot's origin
    # (SabotageAbility.beam_origin in assets/data/troops/ravager.tres).
    stock_butt = (-.08, cy + .04, z0 + .6)
    lock = (-.02, cy + .3, z0 + .62)
    muzzle = (.03, cy + .86, z0 + .6)
    beam(b, stock_butt, lock, .07, 'wood')
    box(b, (-.05, cy + .2, z0 + .57), (.05, .1, .06), 'wood_dark')                   # grip
    box(b, (-.015, cy + .32, z0 + .65), (.05, .08, .04), 'iron')                      # lock plate
    beam(b, lock, muzzle, .045, 'iron')
    beam(b, (-.02, cy + .3, z0 + .6), (.02, cy + .62, z0 + .58), .055, 'wood')       # fore-stock
    box(b, muzzle, (.08, .05, .08), 'iron')                                           # flared muzzle
    box(b, (.03, cy + .87, z0 + .6), (.05, .02, .05), 'eye')                          # bore
    beam(b, (.12, cy + .02, z0 + .52), (.03, cy + .48, z0 + .56), .07, 'tunic')       # left arm under the barrel
    beam(b, (-.12, cy + .02, z0 + .52), (-.06, cy + .22, z0 + .6), .07, 'tunic')      # right arm to the grip
    box(b, (.03, cy + .5, z0 + .56), (.07, .07, .07), 'face')
    box(b, (-.06, cy + .24, z0 + .6), (.06, .06, .06), 'face')
    # Bandolier across the chest with a powder horn and a shot pouch at the hip.
    beam(b, (-.13, cy + .1, z0 + .58), (.13, cy + .1, z0 + .1), .04, 'leather')
    for k in range(4):
        box(b, (-.07 + .05 * k, cy + .125, z0 + .48 - .09 * k), (.03, .02, .04), 'buckle')
    beam(b, (.15, cy + .02, z0 + .24), (.2, cy + .02, z0 + .08), .06, 'tusk')
    box(b, (-.15, cy + .02, z0 + .18), (.08, .07, .09), 'leather')


def leg(name, x, y, r):
    p = Part(name, (x, y, HIP_Z))
    # Shaggy pillar: fur upper, bare lower shin, round foot with toenails.
    rings = []
    for z, rr, jag in ((.08, r * 1.15, .0), (-.25, r * 1.1, .08), (-.5, r * 1.0, .08), (-.68, r * .92, 0), (-.8, r * .95, 0), (-HIP_Z, r * 1.05, 0)):
        c = (0, 0, z)
        rings.append((c, ring_pts(c, (1, 0, 0), (0, 1, 0), rr, rr, 8, jag)))
    tube(p, rings, ['fur', 'fur_dark', 'fur', 'skin', 'skin_dark'])
    tufts(p, (0, 0), r * 1.05, r * 1.05, -.42, 9, .2, .1, ['fur_dark', 'fur'], tilt=.35)
    tufts(p, (0, 0), r * .95, r * .95, -.62, 9, .14, .09, ['fur', 'fur_light'], tilt=.35)
    for a in (-.6, 0, .6):
        box(p, (math.sin(a) * r * .95, math.cos(a) * r * .95, -HIP_Z + .045), (.06, .05, .07), 'nail', rot_z=-a)
    return p


def tail():
    t = Part('Tail', (0, -.84, 1.12))
    path_tube(t, [(0, 0, 0), (0, -.08, -.14), (0, -.1, -.3)], [.04, .035, .03], 5, ['skin'])
    tufts(t, (0, -.1), .03, .03, -.28, 5, .14, .06, ['fur_dark'], tilt=.2)
    return t


def model():
    parts = [body(), tail()]
    for name, x, y, r in (('LegFL', -.3, .42, .17), ('LegFR', .3, .42, .17), ('LegBL', -.3, -.48, .16), ('LegBR', .3, -.48, .16)):
        parts.append(leg(name, x, y, r))
    return parts


# ------------------------------------------------------------------ GLB with vertex colours
def write(parts, path):
    blob = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data), 'target': target})
        blob.extend(data)
        return len(views) - 1

    for part in parts:
        pos, nor, col, idx = [], [], [], []
        for pts, ckey in part.faces:
            n = conv(newell(pts))
            l = math.sqrt(sum(c * c for c in n)) or 1
            n = [c / l for c in n]
            rgb = style.lin(COL[ckey])
            base = len(pos)
            for p in pts:
                pos.append(conv(p))   # part geometry is already local to its pivot
                nor.append(n)
                col.append(rgb + [1.0])
            for k in range(1, len(pts) - 1):
                idx += [base, base + k, base + k + 1]
        lo = [min(p[i] for p in pos) for i in range(3)]
        hi = [max(p[i] for p in pos) for i in range(3)]
        a = len(accessors)
        accessors.append({'bufferView': view(b''.join(struct.pack('<3f', *p) for p in pos), 34962), 'componentType': 5126,
                          'count': len(pos), 'type': 'VEC3', 'min': lo, 'max': hi})
        accessors.append({'bufferView': view(b''.join(struct.pack('<3f', *n) for n in nor), 34962), 'componentType': 5126,
                          'count': len(nor), 'type': 'VEC3'})
        accessors.append({'bufferView': view(b''.join(struct.pack('<4f', *c) for c in col), 34962), 'componentType': 5126,
                          'count': len(col), 'type': 'VEC4'})
        accessors.append({'bufferView': view(b''.join(struct.pack('<I', i) for i in idx), 34963), 'componentType': 5125,
                          'count': len(idx), 'type': 'SCALAR'})
        meshes.append({'name': part.name, 'primitives': [{'attributes': {'POSITION': a, 'NORMAL': a + 1, 'COLOR_0': a + 2},
                                                          'indices': a + 3, 'material': 0}]})
        node = {'name': part.name, 'mesh': len(meshes) - 1}
        t = conv(part.pivot)
        if any(abs(v) > 1e-9 for v in t):
            node['translation'] = list(t)
        nodes.append(node)
    while len(blob) % 4:
        blob.append(0)
    gltf = {'asset': {'version': '2.0', 'generator': 'BWAR ravager.py'}, 'scene': 0,
            'scenes': [{'name': 'Scene', 'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': meshes,
            'materials': [{'name': 'Ravager', 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0, 'roughnessFactor': .9}}],
            'accessors': accessors, 'bufferViews': views, 'buffers': [{'byteLength': len(blob)}]}
    j = json.dumps(gltf, separators=(',', ':')).encode()
    j += b' ' * ((-len(j)) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 28 + len(j) + len(blob))
    out += struct.pack('<I4s', len(j), b'JSON') + j + struct.pack('<I4s', len(blob), b'BIN\0') + bytes(blob)
    Path(path).write_bytes(out)
    return sum(len(p.faces) for p in parts)


if __name__ == '__main__':
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / 'assets/models/enemies/art_g'
    out.mkdir(parents=True, exist_ok=True)
    print('ravager faces', write(model(), out / 'ravager.glb'))
