"""Art Slice G shared style kit: palette, chamfered low-poly primitives, model tree.

Pure Python (no bpy). All coordinates use Blender conventions: Z up, +Y is the
tower's front/firing direction, 1 unit = 1 map cell. Consumed by:
  - build_blender.py  (Blender: editable .blend files, previews, official GLB)
  - gltf_writer.py    (plain Python GLB writer used for quick in-game checks)
"""
import math
import random

PALETTE = {
    'stone_light': '#CBCAC2', 'stone_mid': '#B3B2AA', 'stone_dark': '#878883',
    'grout': '#8E8E87', 'slate': '#74756F',
    'wood': '#9C5A3A', 'wood_light': '#B87650', 'wood_dark': '#6F3E2A',
    'iron': '#3E4549', 'iron_light': '#646C70', 'bore': '#1C1F21', 'brass': '#B8934A',
    'moss': '#6C9A42', 'moss_light': '#8DB653',
    'canvas': '#E6DCC4', 'rope': '#B59A6A',
    # one identity pennant colour per tower (matches the card accents)
    'flag_sentry': '#648A82', 'flag_ballista': '#537B9A', 'flag_barracks': '#B78C58',
    'flag_mortar': '#A96F61', 'flag_crossfire': '#887BA6', 'flag_broadside': '#648EA0',
}
T8 = math.tan(math.pi / 8)


def lin(hex_color):
    h = hex_color.lstrip('#')
    rgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]


# ------------------------------------------------------------------ 2D helpers
def area(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
               for i in range(len(poly))) / 2


def ccw(poly):
    return list(poly) if area(poly) > 0 else list(reversed(poly))


def rect(w, h, cx=0.0, cy=0.0):
    return [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]


def ngon(radius, sides, phase=None):
    phase = math.pi / sides if phase is None else phase
    return [(radius * math.cos(phase + 2 * math.pi * i / sides), radius * math.sin(phase + 2 * math.pi * i / sides))
            for i in range(sides)]


def octagon(apothem):
    """Octagon whose eight sides face 0, 45, 90 ... degrees."""
    return ngon(apothem / math.cos(math.pi / 8), 8, math.pi / 8)


def arch(half, z0, spring, steps=8):
    pts = [(-half, z0), (half, z0)]
    for i in range(steps + 1):
        a = math.pi * i / steps
        pts.append((half * math.cos(a), spring + half * math.sin(a)))
    return pts


def hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def blob(rng, r, n=7, squash=1.0):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-.25, .25)
        rr = r * rng.uniform(.72, 1.12)
        pts.append((rr * math.cos(a), rr * math.sin(a) * squash))
    return hull(pts)


# ------------------------------------------------------------------ 3D geometry
def _unit(x, y):
    d = math.hypot(x, y)
    return (x / d, y / d)


def cprism(poly, z0, z1, b=0.0):
    """Convex polygon prism along Z with a one-segment chamfer of size b on every edge."""
    p = ccw(poly)
    n = len(p)
    if b > 0:
        edges = [math.dist(p[i], p[(i + 1) % n]) for i in range(n)]
        b = min(b, min(edges) * .45, (z1 - z0) * .45)
    if b <= 1e-6:
        v = [(x, y, z0) for x, y in p] + [(x, y, z1) for x, y in p]
        f = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
        f += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        return v, f
    ring, cap = [], []
    for i in range(n):
        v0, v1, v2 = p[i - 1], p[i], p[(i + 1) % n]
        a = _unit(v0[0] - v1[0], v0[1] - v1[1])
        c = _unit(v2[0] - v1[0], v2[1] - v1[1])
        ring += [(v1[0] + a[0] * b, v1[1] + a[1] * b), (v1[0] + c[0] * b, v1[1] + c[1] * b)]
        e0 = _unit(v1[0] - v0[0], v1[1] - v0[1])
        e1 = _unit(v2[0] - v1[0], v2[1] - v1[1])
        n0, n1 = (-e0[1], e0[0]), (-e1[1], e1[0])          # inward normals (CCW polygon)
        k = b / (1 + n0[0] * n1[0] + n0[1] * n1[1])
        cap.append((v1[0] + (n0[0] + n1[0]) * k, v1[1] + (n0[1] + n1[1]) * k))
    m = 2 * n
    v = [(x, y, z0) for x, y in cap]                 # 0..n-1      bottom cap
    v += [(x, y, z0 + b) for x, y in ring]           # n..n+m-1    lower ring
    v += [(x, y, z1 - b) for x, y in ring]           # n+m..       upper ring
    v += [(x, y, z1) for x, y in cap]                # n+2m..      top cap
    QB, RB, RT, QT = 0, n, n + m, n + 2 * m
    f = [tuple(QB + i for i in reversed(range(n))), tuple(QT + i for i in range(n))]
    for j in range(m):
        f.append((RB + j, RB + (j + 1) % m, RT + (j + 1) % m, RT + j))
    for i in range(n):
        A, B, An = 2 * i, 2 * i + 1, (2 * i + 2) % m
        f.append((RT + B, RT + An, QT + (i + 1) % n, QT + i))
        f.append((RT + A, RT + B, QT + i))
        f.append((RB + B, QB + i, QB + (i + 1) % n, RB + An))
        f.append((RB + A, QB + i, RB + B))
    return v, f


def _remap(geo, fn, flip):
    v, f = geo
    v = [fn(*p) for p in v]
    if flip:
        f = [tuple(reversed(face)) for face in f]
    return v, f


def prism_xz(poly, y0, y1, b=0.0):
    """Polygon drawn in X/Z, extruded along Y."""
    return _remap(cprism(poly, y0, y1, b), lambda x, y, z: (x, z, y), True)


def prism_yz(poly, x0, x1, b=0.0):
    """Polygon drawn in Y/Z, extruded along X."""
    return _remap(cprism(poly, x0, x1, b), lambda x, y, z: (z, x, y), False)


def box(w, d, h, b=0.0, at=(0, 0, 0)):
    return move(cprism(rect(w, d), -h / 2, h / 2, b), at)


def cyl_z(r, z0, z1, sides=10, b=0.0):
    return cprism(ngon(r, sides), z0, z1, b)


def cyl_y(r, y0, y1, sides=10, b=0.0):
    return prism_xz(ngon(r, sides), y0, y1, b)


def cyl_x(r, x0, x1, sides=10, b=0.0):
    return prism_yz(ngon(r, sides), x0, x1, b)


def cone_z(r0, r1, z0, z1, sides=8):
    p0, p1 = ngon(r0, sides), ngon(max(r1, 1e-4), sides)
    v = [(x, y, z0) for x, y in p0] + [(x, y, z1) for x, y in p1]
    n = sides
    f = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    f += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return v, f


def pyramid(w, d, z0, z1, apex=(0, 0)):
    base = rect(w, d)
    v = [(x, y, z0) for x, y in base] + [(apex[0], apex[1], z1)]
    f = [(3, 2, 1, 0)] + [(i, (i + 1) % 4, 4) for i in range(4)]
    return v, f


def ico(r, subdivide=1):
    t = (1 + 5 ** .5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
         (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
         (8, 6, 7), (9, 8, 1)]
    for _ in range(subdivide):
        cache, nf = {}, []

        def mid(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                cache[key] = len(v)
                v.append(tuple((v[a][k] + v[b][k]) / 2 for k in range(3)))
            return cache[key]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = nf
    v = [tuple(r * x / math.sqrt(sum(c * c for c in p)) for x in p) for p in v]
    return v, f


def move(geo, d):
    v, f = geo
    return [(x + d[0], y + d[1], z + d[2]) for x, y, z in v], f


def rot_z(geo, angle):
    c, s = math.cos(angle), math.sin(angle)
    v, f = geo
    return [(x * c - y * s, x * s + y * c, z) for x, y, z in v], f


def rot_x(geo, angle):
    c, s = math.cos(angle), math.sin(angle)
    v, f = geo
    return [(x, y * c - z * s, y * s + z * c) for x, y, z in v], f


def merge(*geos):
    v, f = [], []
    for gv, gf in geos:
        off = len(v)
        v += list(gv)
        f += [tuple(i + off for i in face) for face in gf]
    return v, f


# ------------------------------------------------------------------ model tree
class Node:
    def __init__(self, name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), geo=None, mat=None, scale=(1, 1, 1)):
        self.name, self.parent = name, parent
        self.loc, self.rot, self.scale = tuple(loc), tuple(rot), tuple(scale)
        self.geo, self.mat = geo, mat


class Model:
    """Node list in parent-before-child order. Names become BWAR_G_<asset>__<name>."""

    def __init__(self, asset, seed=7):
        self.asset = asset
        self.nodes = []
        self.names = set()
        self.rng = random.Random(seed)

    def full(self, name):
        return f'BWAR_G_{self.asset}__{name}'

    def _add(self, node):
        assert node.name not in self.names, node.name
        self.names.add(node.name)
        self.nodes.append(node)
        return node

    def empty(self, name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
        return self._add(Node(self.full(name), parent, loc, rot))

    def mesh(self, name, geo, mat, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        assert mat in PALETTE, mat
        return self._add(Node(self.full(name), parent, loc, rot, geo, mat, scale))

    def roots(self):
        return [n for n in self.nodes if n.parent is None]

    def children(self, node):
        return [n for n in self.nodes if n.parent is node]


# ------------------------------------------------------------------ transforms
def euler_matrix(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Y = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Z = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return matmul(Z, matmul(Y, X))


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(len(b))) for j in range(len(b[0]))] for i in range(len(a))]


def world(node):
    """4x4 world matrix of a node (Blender space)."""
    R = euler_matrix(*node.rot)
    S = node.scale
    M = [[R[i][0] * S[0], R[i][1] * S[1], R[i][2] * S[2], node.loc[i]] for i in range(3)] + [[0, 0, 0, 1]]
    return matmul(world(node.parent), M) if node.parent else M


def apply(M, p):
    return tuple(M[i][0] * p[0] + M[i][1] * p[1] + M[i][2] * p[2] + M[i][3] for i in range(3))


# ------------------------------------------------------------------ shared kit
def rot_y(geo, angle):
    c, s = math.cos(angle), math.sin(angle)
    v, f = geo
    return [(x * c + z * s, y, -x * s + z * c) for x, y, z in v], f


def beam(a, b, w, h=None):
    """Box of width w (and height h) running from point a to point b."""
    d = [b[i] - a[i] for i in range(3)]
    L = math.sqrt(sum(c * c for c in d))
    geo = box(w, L, h or w)
    geo = rot_x(geo, math.atan2(d[2], math.hypot(d[0], d[1])))
    geo = rot_z(geo, math.atan2(-d[0], d[1]))
    return move(geo, [(a[i] + b[i]) / 2 for i in range(3)])


def voussoirs(radius, spring, count=7, depth=.06, size=(.085, .07)):
    """Stones of an arch, drawn in local X/Z (wall plane), centred on y=0."""
    parts = []
    for k in range(count):
        a = math.pi * k / (count - 1)
        geo = box(size[0], depth, size[1], .01)
        geo = rot_y(geo, -(a + math.pi / 2))
        parts.append(move(geo, (radius * math.cos(a), 0, spring + radius * math.sin(a))))
    return parts


def wall_side(m, parent, prefix, theta, apothem, length, courses, thick=.08, opening=None,
              bevel=.018, light=.65, centre=(0, 0), index=0):
    """One straight wall of stone block courses. Local tangent t runs along the wall.
    opening = (half_width, top_z): a doorway kept clear of blocks."""
    rng = m.rng
    usable = length - .06
    c, sn = math.cos(theta), math.sin(theta)
    for j, (z0, z1) in enumerate(courses):
        fracs = [.5, .5] if (index + j) % 2 == 0 else [.28, .44, .28]
        if usable < .45:
            fracs = [1.0] if (index + j) % 2 == 0 else [.5, .5]
        if usable > 1.2:
            n = max(2, round(usable / .32))
            fracs = [1 / n] * n if (index + j) % 2 == 0 else [.5 / n] + [1 / n] * (n - 1) + [.5 / n]
        spans, t = [], -usable / 2
        for fr in fracs:
            spans.append((t, t + fr * usable))
            t += fr * usable
        if opening and z0 < opening[1]:
            half = opening[0]
            clipped = []
            for a, b in spans:
                for lo, hi in ((a, min(b, -half)), (max(a, half), b)):
                    if hi - lo > .05:
                        clipped.append((lo, hi))
            spans = clipped
        for k, (a, b) in enumerate(spans):
            mid_t = (a + b) / 2
            blen = (b - a) - .022 - rng.uniform(0, .02)
            th = thick + rng.uniform(-.01, .014)
            height = (z1 - z0) - .022 - rng.uniform(0, .014)
            ap = apothem + th / 2 - .006
            loc = (centre[0] + ap * c - sn * mid_t, centre[1] + ap * sn + c * mid_t,
                   (z0 + z1) / 2 + rng.uniform(-.004, .004))
            rot = (math.radians(rng.uniform(-1.5, 1.5)), math.radians(rng.uniform(-1.5, 1.5)),
                   theta - math.pi / 2 + math.radians(rng.uniform(-1.5, 1.5)))
            col = 'stone_light' if rng.random() < light else 'stone_mid'
            m.mesh(f'{prefix}_{j}_{k}', box(blen, th, height, bevel), col, parent, loc, rot)


def wall_ring(m, parent, prefix, apothem, sides, courses, thick=.08, openings=None, phase=0.0, **kw):
    """Block courses around a regular polygon; side k faces phase + k*360/sides.
    openings = {side_index: (half_width, top_z)}"""
    step = 2 * math.pi / sides
    length = 2 * (apothem + thick * .5) * math.tan(math.pi / sides)
    for i in range(sides):
        wall_side(m, parent, f'{prefix}{i}', phase + i * step, apothem, length, courses, thick,
                  (openings or {}).get(i), index=i, **kw)


def wall_rect(m, parent, prefix, centre, half_x, half_y, courses, thick=.08, openings=None, **kw):
    """Block courses around a rectangle. Sides: 0=+X, 1=+Y (front), 2=-X, 3=-Y."""
    dims = [(0.0, half_x, 2 * half_y + thick), (math.pi / 2, half_y, 2 * half_x + thick),
            (math.pi, half_x, 2 * half_y + thick), (3 * math.pi / 2, half_y, 2 * half_x + thick)]
    for i, (theta, ap, length) in enumerate(dims):
        wall_side(m, parent, f'{prefix}{i}', theta, ap, length, courses, thick,
                  (openings or {}).get(i), centre=centre, index=i, **kw)


def side_frame(theta, apothem, z=0.0, t=0.0):
    """(loc, rot) for a feature on polygon side `theta`; local +Y faces outward, local X runs along the wall."""
    c, s = math.cos(theta), math.sin(theta)
    return (apothem * c - s * t, apothem * s + c * t, z), (0, 0, theta - math.pi / 2)


def moss(m, parent, prefix, theta, apothem, spots, foot_ledge=None):
    """Moss patches on a wall face; spots = [(tangent, z, radius)]."""
    for n, (t, z, r) in enumerate(spots):
        loc, rot = side_frame(theta, apothem, z, t)
        m.mesh(f'{prefix}_{n}', prism_xz(blob(m.rng, r * .85, squash=.6), 0, .012),
               'moss' if n % 2 else 'moss_light', parent, loc, rot)
        if foot_ledge is not None and z < .2:
            ap, ztop = foot_ledge
            loc, rot = side_frame(theta, ap, 0, t)
            m.mesh(f'{prefix}F_{n}', cprism(blob(m.rng, r * .8, squash=.3), ztop, ztop + .012), 'moss', parent, loc, rot)


def pennant(m, parent, prefix, at, height, flag_mat, facing=0.0):
    """Wooden pole with a small swallow-tail flag in the tower's identity colour."""
    x, y, z = at
    m.mesh(prefix + 'Pole', cyl_z(.018, 0, height, 6), 'wood_dark', parent, (x, y, z))
    m.mesh(prefix + 'Knob', cyl_z(.03, 0, .035, 6), 'brass', parent, (x, y, z + height))
    flag = [(0, 0), (.20, .01), (.15, -.055), (.20, -.12), (0, -.11)]
    m.mesh(prefix + 'Flag', prism_xz(flag, -.008, .008), flag_mat, parent,
           (x + .015, y, z + height - .02), (0, 0, facing))
