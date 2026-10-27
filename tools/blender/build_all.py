"""Generate the A-01 low-poly environment pack without external assets."""

import argparse
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from common import ASSET_RULES, box, leaf, material, mesh_objects, reset_scene, validate  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def make_floor():
    box("sand", (1, 1, 0.05), (0, 0, 0.025), "sand")
    box("sand_mark_01", (0.20, 0.035, 0.005), (-0.20, 0.18, 0.0525), "sand_detail")
    box("sand_mark_02", (0.15, 0.025, 0.005), (0.20, -0.18, 0.0525), "sand_detail")


def make_wall():
    box("wood_core", (0.90, 0.90, 0.90), (0, 0, 0.45), "wood")
    for side in (-1, 1):
        for z in (0.05, 0.95):
            box(f"front_frame_{side}_{z}", (1.0, 0.05, 0.10), (0, side * 0.475, z), "wood_frame")
            box(f"side_frame_{side}_{z}", (0.05, 0.90, 0.10), (side * 0.475, 0, z), "wood_frame")
        for x in (-0.45, 0.45):
            box(f"front_post_{side}_{x}", (0.10, 0.05, 0.80), (x, side * 0.475, 0.50), "wood_frame")
        box(f"diagonal_{side}", (0.80, 0.04, 0.07), (0, side * 0.48, 0.50), "wood_light", -45)


def make_hard_wall():
    box("stone_base", (1.0, 1.0, 0.12), (0, 0, 0.06), "metal")
    box("stone_body", (1.0, 1.0, 0.88), (0, 0, 0.56), "stone")
    box("stone_cap", (1.0, 1.0, 0.18), (0, 0, 1.09), "metal")
    for x in (-0.30, 0.30):
        for y in (-0.30, 0.30):
            box(f"cap_stud_{x}_{y}", (0.12, 0.12, 0.02), (x, y, 1.19), "stone_light")


def make_bush(variant):
    box("bush_base", (0.24, 0.24, 0.10), (0, 0, 0.05), "bush_dark")
    positions = [(-0.22, -0.20), (0.22, -0.20), (-0.22, 0.20), (0.22, 0.20)]
    if variant == 2:
        positions = [(-0.22, -0.12), (0.22, -0.17), (-0.18, 0.20), (0.19, 0.20)]
    for i, (x, y) in enumerate(positions):
        leaf(f"lower_{i}", (x, y, 0.28), (0.31, 0.31, 0.28),
             "bush" if i % 2 else "bush_dark", 0 if variant == 1 else 25)
    leaf("center", (0, 0, 0.35), (0.36, 0.36, 0.35), "bush", 12 * variant)
    left_y = 0.02 if variant == 1 else -0.10
    right_y = 0.04 if variant == 1 else 0.12
    leaf("crown_left", (-0.17, left_y, 0.40), (0.27, 0.28, 0.29), "bush_light", 15 * variant)
    leaf("crown_right", (0.18, right_y, 0.40), (0.28, 0.27, 0.29), "bush", 20 * variant)


def make_water():
    box("water", (1, 1, 0.02), (0, 0, -0.03), "water")
    for i, (x, y, width) in enumerate(((-0.22, -0.22, 0.24), (0.15, 0.05, 0.28), (-0.05, 0.30, 0.18))):
        box(f"ripple_{i}", (width, 0.025, 0.005), (x, y, -0.0175), "water_light")


def make_debris(index):
    sizes = [(0.42, 0.15, 0.10), (0.32, 0.20, 0.14), (0.26, 0.13, 0.19), (0.38, 0.10, 0.08)]
    width, depth, height = sizes[index - 1]
    outline = [
        (-width * 0.5, -depth * 0.5), (width * 0.32, -depth * 0.5),
        (width * 0.5, -depth * 0.08), (width * 0.28, depth * 0.5),
        (-width * 0.5, depth * 0.5),
    ]
    vertices = [(x, y, 0) for x, y in outline]
    vertices += [(x, y, height * (0.65 if i == 2 else 1.0)) for i, (x, y) in enumerate(outline)]
    faces = [(4, 3, 2, 1, 0), (5, 6, 7, 8, 9)]
    faces += [(i, (i + 1) % 5, (i + 1) % 5 + 5, i + 5) for i in range(5)]
    mesh = bpy.data.meshes.new(f"wood_fragment_{index}")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(f"wood_fragment_{index}", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material("wood" if index % 2 else "wood_frame"))


def build(name):
    if name == "floor":
        make_floor()
    elif name == "wall":
        make_wall()
    elif name == "hard_wall":
        make_hard_wall()
    elif name.startswith("bush_"):
        make_bush(int(name[-2:]))
    elif name == "water":
        make_water()
    elif name.startswith("debris_"):
        make_debris(int(name[-2:]))
    else:
        raise ValueError(f"Unknown asset {name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/models/env")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name in ASSET_RULES:
        reset_scene()
        build(name)
        objects = mesh_objects()
        validate(name, objects)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        # Keep the exported scene origin at the cell centre and avoid many mesh nodes per tile.
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.ops.object.join()
        bpy.context.object.name = name
        validate(name, [bpy.context.object])
        destination = args.output_dir / f"{name}.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(destination), export_format="GLB", use_selection=True,
            export_yup=True, export_apply=True, export_animations=False,
        )
        if not destination.is_file() or destination.stat().st_size == 0:
            raise RuntimeError(f"Export did not create {destination}")
    print(f"Built {len(ASSET_RULES)} GLB models in {args.output_dir}")


if __name__ == "__main__":
    main()
