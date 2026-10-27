"""Build three original, skinned frontier heroes with a shared skeleton and idle."""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from common import box, material, reset_scene  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent
HEROES = ("lynx", "anvil", "shishka")
BONES = ("root", "spine", "head_bone", "arm.L", "arm.R", "leg.L", "leg.R")


def armature():
    bpy.ops.object.armature_add(enter_editmode=True)
    rig = bpy.context.object
    rig.name = "HeroRig"
    bones = rig.data.edit_bones
    for bone in list(bones):
        bones.remove(bone)
    specs = (
        ("root", (0, 0, 0), (0, 0, 0.25), None),
        ("spine", (0, 0, 0.25), (0, 0, 0.82), "root"),
        ("head_bone", (0, 0, 0.82), (0, 0, 1.14), "spine"),
        ("arm.L", (-0.24, 0, 0.72), (-0.31, 0.18, 0.52), "spine"),
        ("arm.R", (0.24, 0, 0.72), (0.31, 0.18, 0.52), "spine"),
        ("leg.L", (-0.14, 0, 0.25), (-0.14, 0, 0.05), "root"),
        ("leg.R", (0.14, 0, 0.25), (0.14, 0, 0.05), "root"),
    )
    for name, head, tail, parent in specs:
        bone = bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def part(obj, bone):
    if bone == "head":
        bone = "head_bone"
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def block(name, size, pos, color, bone, angle=0.0):
    return part(box(name, size, pos, color, angle), bone)


def orb(name, pos, scale, color, bone, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material(color))
    return part(obj, bone)


def cone(name, pos, radius1, radius2, depth, color, bone, vertices=8):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=pos,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(color))
    return part(obj, bone)


def barrel(name, x, y, z, length, radius, color, bone):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=length, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler.x = math.pi / 2.0
    obj.data.materials.append(material(color))
    return part(obj, bone)


def torso(name, lower, upper, depth, bottom, top, color):
    vertices = [
        (-lower / 2, -depth / 2, bottom), (lower / 2, -depth / 2, bottom),
        (lower / 2, depth / 2, bottom), (-lower / 2, depth / 2, bottom),
        (-upper / 2, -depth / 2, top), (upper / 2, -depth / 2, top),
        (upper / 2, depth / 2, top), (-upper / 2, depth / 2, top),
    ]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
             (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(color))
    return part(obj, "spine")


def legs(foot_width, separation, color):
    for side, bone in ((-1, "leg.L"), (1, "leg.R")):
        x = side * separation
        block(f"boot_{bone}", (foot_width, 0.29, 0.12), (x, 0.03, 0.06), "metal", bone)
        block(f"leg_{bone}", (foot_width * 0.8, 0.18, 0.24), (x, -0.01, 0.24), color, bone)


def face(width, height, z):
    block("face", (width, 0.055, height), (0, 0.175, z), "skin", "head")
    for side in (-1, 1):
        block(f"eye_{side}", (0.035, 0.018, 0.035), (side * width * 0.25, 0.211, z + 0.01),
              "metal", "head")


def lynx():
    legs(0.18, 0.13, "cloth_lynx")
    torso("long_coat", 0.36, 0.48, 0.27, 0.30, 0.80, "cloth_lynx")
    block("coat_belt", (0.42, 0.30, 0.07), (0, 0, 0.47), "wood_frame", "spine")
    for side, bone in ((-1, "arm.L"), (1, "arm.R")):
        block(f"sleeve_{bone}", (0.13, 0.18, 0.32), (side * 0.28, 0.02, 0.61), "cloth_lynx", bone)
        orb(f"glove_{bone}", (side * 0.28, 0.15, 0.49), (0.075, 0.075, 0.075), "wood", bone, 1)
    cone("pointed_hood", (0, 0, 1.02), 0.235, 0.035, 0.42, "cloth_lynx", "head", 6)
    face(0.25, 0.18, 0.96)
    for side in (-1, 1):
        cone(f"ear_tuft_{side}", (side * 0.13, -0.035, 1.21), 0.058, 0.0, 0.18, "fur", "head", 5)
    block("scarf", (0.30, 0.29, 0.075), (0, -0.01, 0.80), "fur", "spine")
    block("scarf_tail", (0.09, 0.25, 0.05), (-0.10, -0.20, 0.70), "fur", "spine", -12)
    block("rifle_stock", (0.085, 0.33, 0.085), (0.20, 0.17, 0.76), "wood_light", "arm.R")
    barrel("long_barrel", 0.20, 0.47, 0.79, 0.44, 0.027, "metal", "arm.R")
    block("rifle_sight", (0.045, 0.08, 0.04), (0.20, 0.29, 0.83), "amber", "arm.R")
    return (0.20, 0.69, 0.79), 1.37


def anvil():
    legs(0.25, 0.18, "cloth_anvil")
    torso("armored_coat", 0.58, 0.70, 0.37, 0.27, 0.80, "cloth_anvil")
    block("chest_plate", (0.48, 0.07, 0.32), (0, 0.21, 0.61), "stone_light", "spine")
    block("iron_collar", (0.60, 0.39, 0.09), (0, 0, 0.82), "metal", "spine")
    for side, bone in ((-1, "arm.L"), (1, "arm.R")):
        block(f"shoulder_{bone}", (0.18, 0.37, 0.19), (side * 0.36, 0, 0.77), "stone_light", bone)
        block(f"arm_{bone}", (0.16, 0.22, 0.32), (side * 0.34, 0.03, 0.55), "cloth_anvil", bone)
        orb(f"glove_{bone}", (side * 0.32, 0.18, 0.44), (0.09, 0.09, 0.09), "wood", bone, 1)
    orb("head", (0, 0, 1.00), (0.18, 0.17, 0.19), "skin", "head")
    cone("helmet", (0, 0, 1.13), 0.22, 0.16, 0.15, "metal", "head")
    block("helmet_rim", (0.46, 0.34, 0.06), (0, 0, 1.07), "stone_light", "head")
    face(0.24, 0.16, 0.98)
    block("gun_stock", (0.27, 0.27, 0.14), (0, 0.25, 0.72), "wood", "arm.R")
    for side in (-1, 1):
        barrel(f"short_barrel_{side}", side * 0.075, 0.48, 0.78, 0.33, 0.065, "metal", "arm.R")
    return (0, 0.65, 0.78), 1.30


def shishka():
    legs(0.20, 0.14, "cloth_shishka")
    orb("round_coat", (0, 0, 0.51), (0.30, 0.24, 0.34), "cloth_shishka", "spine")
    block("coat_belt", (0.50, 0.38, 0.07), (0, 0, 0.44), "wood_frame", "spine")
    for side, bone in ((-1, "arm.L"), (1, "arm.R")):
        orb(f"sleeve_{bone}", (side * 0.28, 0.02, 0.60), (0.115, 0.12, 0.19), "cloth_shishka", bone)
        orb(f"glove_{bone}", (side * 0.30, 0.16, 0.47), (0.075, 0.075, 0.075), "fur", bone, 1)
    orb("backpack", (0, -0.28, 0.61), (0.27, 0.20, 0.33), "wood", "spine")
    block("pack_band", (0.39, 0.06, 0.07), (0, -0.46, 0.65), "wood_light", "spine")
    for x in (-0.15, 0.0, 0.15):
        cone(f"pinecone_{x}", (x, -0.28, 0.92), 0.075, 0.015, 0.16, "wood_light", "spine", 6)
    orb("round_hat", (0, 0, 1.03), (0.23, 0.20, 0.17), "fur", "head")
    block("hat_band", (0.45, 0.34, 0.075), (0, 0, 0.98), "wood_frame", "head")
    for side in (-1, 1):
        block(f"ear_flap_{side}", (0.08, 0.18, 0.18), (side * 0.22, 0, 0.91), "fur", "head")
    face(0.23, 0.15, 0.95)
    block("sling_handle", (0.07, 0.27, 0.07), (0.12, 0.35, 0.76), "wood_light", "arm.R")
    for side in (-1, 1):
        block(f"sling_fork_{side}", (0.06, 0.20, 0.06), (0.12 + side * 0.08, 0.48, 0.80),
              "wood_light", "arm.R")
    orb("sling_cone", (0.12, 0.50, 0.81), (0.09, 0.09, 0.10), "amber", "arm.R", 1)
    return (0.12, 0.59, 0.81), 1.30


def marker(rig, name, location, bone):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    empty.parent = rig
    empty.parent_type = "BONE"
    empty.parent_bone = bone
    bpy.context.view_layer.update()
    empty.matrix_world = Matrix.Translation(Vector(location))
    return empty


def add_idle(rig):
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = 0, 36
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.new("idle")
    for frame, breath in ((0, 0.0), (18, 1.0), (36, 0.0)):
        for bone, axis, amount in (("spine", 0, 2.0), ("head_bone", 0, -1.0), ("arm.R", 1, 1.5)):
            pose = rig.pose.bones[bone]
            pose.rotation_mode = "XYZ"
            pose.rotation_euler[axis] = math.radians(amount * breath)
            pose.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone)
    for curve in rig.animation_data.action.fcurves:
        curve.modifiers.new(type="CYCLES")
    scene.frame_set(0)


def build_hero(name, destination):
    reset_scene()
    rig = armature()
    muzzle, head_height = {"lynx": lynx, "anvil": anvil, "shishka": shishka}[name]()
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = f"{name}_mesh"
    mesh.parent = rig
    modifier = mesh.modifiers.new(name="HeroSkin", type="ARMATURE")
    modifier.object = rig
    marker(rig, "muzzle", muzzle, "arm.R")
    marker(rig, "head", (0, 0, head_height), "head_bone")
    add_idle(rig)
    bpy.ops.object.select_all(action="SELECT")
    destination.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(destination / f"{name}.glb"), export_format="GLB", use_selection=True,
        export_yup=True, export_animations=True, export_animation_mode="ACTIONS", export_frame_range=True,
    )
    print(f"Built {name} with skeleton and idle")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/models/heroes")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name in HEROES:
        build_hero(name, args.output_dir)


if __name__ == "__main__":
    main()
