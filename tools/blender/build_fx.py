"""Create low-poly projectiles, loot and team structures in the STYLE palette."""

import argparse
import math
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from common import box, material, mesh_objects, reset_scene  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent
PROJECTILES = ("lynx_bullet", "anvil_pellet", "pinecone", "pinecone_super", "loot_shard")
STRUCTURES = ("safe_blue", "safe_red", "mine")
ASSETS = PROJECTILES + STRUCTURES


def cone(name, location, radius1, radius2, depth, color, vertices=8, along_y=False):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2,
                                   depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    if along_y:
        obj.rotation_euler.x = -math.pi / 2
    obj.data.materials.append(material(color))
    return obj


def gem(name, location, scale, color):
    vertices = [(0, 0, 1), (1, 0, 0), (0, 1, 0), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]
    faces = [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
             (5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location, obj.scale = location, scale
    obj.data.materials.append(material(color))
    return obj


def pinecone(size):
    cone("pinecone_body", (0, 0, 0), size * 0.42, size * 0.25, size, "wood", 8)
    cone("pinecone_tip", (0, 0, size * 0.55), size * 0.25, 0, size * 0.22, "wood_light", 8)
    for index in range(6):
        angle = index * math.tau / 6
        gem(f"scale_{index}", (size * 0.34 * math.cos(angle), size * 0.34 * math.sin(angle), 0),
            (size * 0.12, size * 0.12, size * 0.16), "wood_light")


def make_safe(team):
    color = "team_a" if team == "blue" else "team_b"
    box("base", (0.98, 0.86, 0.12), (0, 0, 0.06), "metal")
    box("case", (0.88, 0.78, 0.78), (0, 0, 0.51), "stone")
    box("door", (0.70, 0.06, 0.62), (0, 0.41, 0.51), color)
    box("lid", (0.98, 0.88, 0.12), (0, 0, 0.96), "metal")
    for x in (-0.38, 0.38):
        box(f"edge_{x}", (0.08, 0.08, 0.80), (x, 0.43, 0.52), "stone_light")
    # Circle versus diamond adds a shape cue in addition to team colour.
    if team == "blue":
        cone("team_circle", (0, 0.455, 0.52), 0.14, 0.14, 0.035, "amber", 12, True)
    else:
        box("team_diamond", (0.22, 0.035, 0.22), (0, 0.455, 0.52), "amber", 45)


def make_mine():
    box("mine_plinth", (1.2, 1.2, 0.14), (0, 0, 0.07), "stone")
    box("mine_floor", (0.86, 0.86, 0.06), (0, 0, 0.17), "metal")
    for side in (-1, 1):
        box(f"rail_x_{side}", (1.15, 0.12, 0.12), (0, side * 0.48, 0.19), "wood_frame")
        box(f"rail_y_{side}", (0.12, 0.84, 0.12), (side * 0.48, 0, 0.19), "wood_frame")
        box(f"post_{side}", (0.12, 0.12, 0.64), (side * 0.48, -0.38, 0.46), "wood")
    box("crossbeam", (1.08, 0.14, 0.12), (0, -0.38, 0.78), "wood_frame")
    gem("ore_large", (0, 0, 0.34), (0.21, 0.21, 0.30), "amber")
    gem("ore_small", (0.28, -0.12, 0.25), (0.11, 0.11, 0.17), "wood_light")


def make_asset(name):
    if name == "lynx_bullet":
        cone("bullet_body", (0, 0.06, 0), 0.07, 0.07, 0.28, "wood_light", along_y=True)
        cone("bullet_tip", (0, 0.25, 0), 0.07, 0, 0.10, "amber", along_y=True)
        tail = cone("glowing_trail", (0, -0.26, 0), 0.0, 0.06, 0.36, "amber", along_y=True)
        shader = tail.data.materials[0].node_tree.nodes.get("Principled BSDF")
        shader.inputs["Emission Color"].default_value = tail.data.materials[0].diffuse_color
        shader.inputs["Emission Strength"].default_value = 1.0
    elif name == "anvil_pellet":
        gem("pellet", (0, 0, 0), (0.10, 0.10, 0.10), "stone_light")
    elif name in ("pinecone", "pinecone_super"):
        pinecone(0.32 if name == "pinecone" else 0.60)
    elif name == "loot_shard":
        gem("loot_shard", (0, 0, 0), (0.18, 0.18, 0.27), "amber")
    elif name in ("safe_blue", "safe_red"):
        make_safe(name.split("_")[1])
    else:
        make_mine()


def build(name, output):
    reset_scene()
    make_asset(name)
    objects = mesh_objects()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(objects) > 1:
        bpy.ops.object.join()
    bpy.context.object.name = name
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                              use_selection=True, export_yup=True)
    print(f"Built {name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/models/fx")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name in ASSETS:
        build(name, args.output_dir)


if __name__ == "__main__":
    main()
