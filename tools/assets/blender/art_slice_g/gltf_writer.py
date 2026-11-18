"""Minimal GLB writer for style.Model trees (no bpy needed).

Produces the same node hierarchy, names and flat-shaded solid-colour materials
that Blender's glTF exporter would, so Godot imports both identically.
Usage: python gltf_writer.py [out_dir]   (writes <asset>.glb for every tower)
"""
import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import style  # noqa: E402

C = [[1, 0, 0], [0, 0, 1], [0, -1, 0]]       # Blender (Z up) -> glTF (Y up)


def conv(p):
    return (p[0], p[2], -p[1])


def quat(R):
    tr = R[0][0] + R[1][1] + R[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        return ((R[2][1] - R[1][2]) / s, (R[0][2] - R[2][0]) / s, (R[1][0] - R[0][1]) / s, s / 4)
    if R[0][0] > R[1][1] and R[0][0] > R[2][2]:
        s = math.sqrt(1 + R[0][0] - R[1][1] - R[2][2]) * 2
        return (s / 4, (R[0][1] + R[1][0]) / s, (R[0][2] + R[2][0]) / s, (R[2][1] - R[1][2]) / s)
    if R[1][1] > R[2][2]:
        s = math.sqrt(1 + R[1][1] - R[0][0] - R[2][2]) * 2
        return ((R[0][1] + R[1][0]) / s, s / 4, (R[1][2] + R[2][1]) / s, (R[0][2] - R[2][0]) / s)
    s = math.sqrt(1 + R[2][2] - R[0][0] - R[1][1]) * 2
    return ((R[0][2] + R[2][0]) / s, (R[1][2] + R[2][1]) / s, s / 4, (R[1][0] - R[0][1]) / s)


def newell(pts):
    n = [0.0, 0.0, 0.0]
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])
    d = math.sqrt(sum(c * c for c in n)) or 1.0
    return [c / d for c in n]


def write(model, path):
    blob = bytearray()
    views, accessors, meshes, materials, nodes = [], [], [], [], []
    mat_index = {}

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data), 'target': target})
        blob.extend(data)
        return len(views) - 1

    def material(key):
        if key not in mat_index:
            mat_index[key] = len(materials)
            materials.append({'name': f'BWAR_G_{key}', 'pbrMetallicRoughness': {
                'baseColorFactor': style.lin(style.PALETTE[key]) + [1.0], 'metallicFactor': 0.0,
                'roughnessFactor': 0.9}})
        return mat_index[key]

    def mesh(node):
        verts, faces = node.geo
        pos, nor, idx = [], [], []
        for face in faces:
            pts = [verts[i] for i in face]
            n = conv(newell(pts))
            base = len(pos)
            for p in pts:
                pos.append(conv(p))
                nor.append(n)
            for k in range(1, len(pts) - 1):
                idx += [base, base + k, base + k + 1]
        pdata = b''.join(struct.pack('<3f', *p) for p in pos)
        ndata = b''.join(struct.pack('<3f', *n) for n in nor)
        idata = b''.join(struct.pack('<I', i) for i in idx)
        lo = [min(p[i] for p in pos) for i in range(3)]
        hi = [max(p[i] for p in pos) for i in range(3)]
        accessors.append({'bufferView': add_view(pdata, 34962), 'componentType': 5126, 'count': len(pos),
                          'type': 'VEC3', 'min': lo, 'max': hi})
        accessors.append({'bufferView': add_view(ndata, 34962), 'componentType': 5126, 'count': len(nor), 'type': 'VEC3'})
        accessors.append({'bufferView': add_view(idata, 34963), 'componentType': 5125, 'count': len(idx), 'type': 'SCALAR'})
        a = len(accessors)
        meshes.append({'name': node.name + '_mesh', 'primitives': [{
            'attributes': {'POSITION': a - 3, 'NORMAL': a - 2}, 'indices': a - 1, 'material': material(node.mat)}]})
        return len(meshes) - 1

    index = {id(n): i for i, n in enumerate(model.nodes)}
    for n in model.nodes:
        R = style.euler_matrix(*n.rot)
        Rg = style.matmul(style.matmul(C, R), [list(r) for r in zip(*C)])
        entry = {'name': n.name}
        t = conv(n.loc)
        if any(abs(v) > 1e-9 for v in t):
            entry['translation'] = list(t)
        q = quat(Rg)
        if abs(q[3] - 1) > 1e-9:
            entry['rotation'] = list(q)
        if n.scale != (1, 1, 1):
            entry['scale'] = [n.scale[0], n.scale[2], n.scale[1]]
        if n.geo is not None:
            entry['mesh'] = mesh(n)
        kids = [index[id(c)] for c in model.nodes if c.parent is n]
        if kids:
            entry['children'] = kids
        nodes.append(entry)
    while len(blob) % 4:
        blob.append(0)
    gltf = {'asset': {'version': '2.0', 'generator': 'BWAR art_slice_g gltf_writer'}, 'scene': 0,
            'scenes': [{'name': 'Scene', 'nodes': [index[id(r)] for r in model.roots()]}],
            'nodes': nodes, 'meshes': meshes, 'materials': materials, 'accessors': accessors,
            'bufferViews': views, 'buffers': [{'byteLength': len(blob)}]}
    j = json.dumps(gltf, separators=(',', ':')).encode()
    j += b' ' * ((-len(j)) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 28 + len(j) + len(blob))
    out += struct.pack('<I4s', len(j), b'JSON') + j + struct.pack('<I4s', len(blob), b'BIN\0') + bytes(blob)
    Path(path).write_bytes(out)


if __name__ == '__main__':
    import towers
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / 'exports'
    out.mkdir(parents=True, exist_ok=True)
    for asset, build in towers.BUILDERS.items():
        model = build()
        write(model, out / f'{asset}.glb')
        print(asset, towers.check(model))
