"""Validate exported assets and compare reconstructed GLBs with the committed pack."""

import argparse
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from build_fx import ASSETS, PROJECTILES  # noqa: E402
from common import mesh_objects, reset_scene  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def snapshot(path, name):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = mesh_objects()
    if len(meshes) != 1:
        raise ValueError(f"{name}: expected one mesh, got {len(meshes)}")
    mesh = meshes[0]
    mesh.data.calc_loop_triangles()
    count = len(mesh.data.loop_triangles)
    limit = 100 if name in PROJECTILES else 800
    if not 0 < count <= limit:
        raise ValueError(f"{name}: {count} triangles, limit {limit}")
    materials = {}
    for mat in mesh.data.materials:
        if not mat or not mat.use_nodes or any(node.type == "TEX_IMAGE" for node in mat.node_tree.nodes):
            raise ValueError(f"{name}: missing material or unexpected texture")
        shader = mat.node_tree.nodes.get("Principled BSDF")
        materials[mat.name] = list(shader.inputs["Base Color"].default_value)
        materials[mat.name + "_emission"] = list(shader.inputs["Emission Color"].default_value)
    vertices = [list(mesh.matrix_world @ vertex.co) for vertex in mesh.data.vertices]
    if not vertices:
        raise ValueError(f"{name}: empty mesh")
    spans = [max(p[i] for p in vertices) - min(p[i] for p in vertices) for i in range(3)]
    if any(span <= 0 or span > 1.5 for span in spans):
        raise ValueError(f"{name}: invalid dimensions {spans}")
    if name not in PROJECTILES and abs(min(p[2] for p in vertices)) > 0.001:
        raise ValueError(f"{name}: structure is not on the floor")
    print(f"FX {name}: {count} triangles, dimensions {[round(s, 3) for s in spans]}")
    return {
        "vertices": vertices,
        "faces": [(list(face.vertices), mesh.data.materials[face.material_index].name)
                  for face in mesh.data.polygons],
        "materials": materials,
    }


def equal(a, b, path):
    if isinstance(a, (float, int)) and isinstance(b, (float, int)):
        if abs(a - b) > 0.0001:
            raise ValueError(f"{path}: {a} != {b}")
    elif isinstance(a, dict) and isinstance(b, dict):
        if a.keys() != b.keys():
            raise ValueError(f"{path}: keys differ")
        for key in a:
            equal(a[key], b[key], f"{path}.{key}")
    elif isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        if len(a) != len(b):
            raise ValueError(f"{path}: lengths differ")
        for index, (left, right) in enumerate(zip(a, b)):
            equal(left, right, f"{path}[{index}]")
    elif a != b:
        raise ValueError(f"{path}: {a} != {b}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=ROOT / "assets/models/fx")
    parser.add_argument("--compare-dir", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for folder in (args.input_dir, args.compare_dir):
        if folder and {p.name for p in folder.glob("*.glb")} != {f"{n}.glb" for n in ASSETS}:
            raise ValueError(f"Unexpected GLB set in {folder}")
    for name in ASSETS:
        asset = snapshot(args.input_dir / f"{name}.glb", name)
        if args.compare_dir:
            equal(asset, snapshot(args.compare_dir / f"{name}.glb", name), name)


if __name__ == "__main__":
    main()
