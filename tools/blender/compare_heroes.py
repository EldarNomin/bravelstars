"""Compare rebuilt and committed GLBs by imported content, allowing float noise."""

import argparse
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from build_heroes import BONES, HEROES  # noqa: E402
from common import reset_scene  # noqa: E402
from verify_heroes import validate  # noqa: E402
from hero_animations import FRAMES  # noqa: E402


def snapshot(path, name):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    validate(name)
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and any(
        modifier.type == "ARMATURE" and modifier.object == rig for modifier in obj.modifiers))
    materials = {}
    for material in mesh.data.materials:
        shader = material.node_tree.nodes.get("Principled BSDF")
        materials[material.name] = list(shader.inputs["Base Color"].default_value)
    result = {
        "bones": {bone: [list(row) for row in rig.data.bones[bone].matrix_local] for bone in BONES},
        "weights": [[(mesh.vertex_groups[group.group].name, group.weight)
                     for group in vertex.groups] for vertex in mesh.data.vertices],
        "faces": [(list(face.vertices), mesh.data.materials[face.material_index].name)
                  for face in mesh.data.polygons],
        "materials": materials,
        "frames": {},
    }
    for clip, duration in FRAMES.items():
        rig.animation_data.action = bpy.data.actions[clip]
        result["frames"][clip] = []
        for frame in (0, duration // 3, 2 * duration // 3, duration):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            points = [list(evaluated.matrix_world @ v.co) for v in evaluated.to_mesh().vertices]
            evaluated.to_mesh_clear()
            result["frames"][clip].append({
                "vertices": points,
                "sockets": {socket: list(bpy.data.objects[socket].matrix_world.translation)
                            for socket in ("head", "muzzle")},
            })
    return result


def equal(a, b, path="root"):
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
    parser.add_argument("--rebuilt", type=Path, required=True)
    parser.add_argument("--committed", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for name in HEROES:
        rebuilt = snapshot(args.rebuilt / f"{name}.glb", name)
        committed = snapshot(args.committed / f"{name}.glb", name)
        equal(rebuilt, committed, name)
        print(f"Equivalent imported content: {name}")


if __name__ == "__main__":
    main()
