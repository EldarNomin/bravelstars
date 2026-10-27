"""Check the exported hero geometry, skin, sockets and breathing animation."""

import argparse
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from build_heroes import BONES, HEROES  # noqa: E402
from common import reset_scene  # noqa: E402
from hero_animations import FRAMES, SPEED  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def check(condition, message):
    if not condition:
        raise ValueError(message)


def validate(name):
    objects = list(bpy.context.scene.objects)
    rigs = [obj for obj in objects if obj.type == "ARMATURE"]
    check(len(rigs) == 1, f"{name}: expected one armature")
    rig = rigs[0]
    check(set(rig.data.bones.keys()) == set(BONES), f"{name}: skeleton names differ")
    parents = {"root": None, "spine": "root", "head_bone": "spine", "arm.L": "spine",
               "arm.R": "spine", "leg.L": "root", "leg.R": "root"}
    for bone, parent in parents.items():
        actual = rig.data.bones[bone].parent
        check((actual.name if actual else None) == parent, f"{name}: parent of {bone}")
    meshes = [obj for obj in objects if obj.type == "MESH" and any(
        mod.type == "ARMATURE" and mod.object == rig for mod in obj.modifiers)]
    check(len(meshes) == 1, f"{name}: expected one skinned mesh")
    mesh = meshes[0]
    mesh.data.calc_loop_triangles()
    triangles = len(mesh.data.loop_triangles)
    check(0 < triangles <= 1500, f"{name}: {triangles} triangles")
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = bpy.data.actions.get("idle")
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
    lower = [min(point[i] for point in points) for i in range(3)]
    upper = [max(point[i] for point in points) for i in range(3)]
    spans = [upper[i] - lower[i] for i in range(3)]
    check(0.0 <= lower[2] + 0.001 and abs(lower[2]) < 0.001, f"{name}: feet above floor")
    check(1.15 <= spans[2] <= 1.35, f"{name}: height {spans[2]}")
    check(0.3 <= spans[0] <= (0.901 if name == "anvil" else 0.801), f"{name}: width {spans[0]}")
    check(spans[1] <= 1.5, f"{name}: depth {spans[1]}")
    for vertex in mesh.data.vertices:
        check(abs(sum(group.weight for group in vertex.groups) - 1.0) < 0.001,
              f"{name}: vertex {vertex.index} has invalid skin weights")
    for bone in BONES[1:]:
        group = mesh.vertex_groups.get(bone)
        check(group is not None and any(any(g.group == group.index and g.weight > 0
                  for g in vertex.groups) for vertex in mesh.data.vertices), f"{name}: unweighted {bone}")
    for socket, bone in (("head", "head_bone"), ("muzzle", "arm.R")):
        marker = bpy.data.objects.get(socket)
        check(marker is not None and marker.type == "EMPTY" and marker.parent == rig
              and marker.parent_type == "BONE" and marker.parent_bone == bone,
              f"{name}: invalid {socket}")
        position = marker.matrix_world.translation
        if socket == "muzzle":
            check(0.7 <= position.z <= 0.9 and position.y > 0, f"{name}: invalid muzzle position")
        else:
            check(position.z > upper[2], f"{name}: head marker below model")
    action = rig.animation_data.action if rig.animation_data else None
    check(action is not None and action.name == "idle", f"{name}: missing idle")
    check(abs((action.frame_range[1] - action.frame_range[0]) / 24 - 1.5) < 0.01,
          f"{name}: idle duration")
    def evaluated_points(frame):
        bpy.context.scene.frame_set(frame)
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        result = [evaluated.matrix_world @ v.co for v in evaluated.to_mesh().vertices]
        evaluated.to_mesh_clear()
        return result
    start, middle, end = (evaluated_points(frame) for frame in (0, 18, 36))
    check(max((a - b).length for a, b in zip(start, middle)) > 0.001, f"{name}: idle does not deform mesh")
    check(max((a - b).length for a, b in zip(start, end)) < 0.001, f"{name}: idle does not close")
    for clip, duration in FRAMES.items():
        action = bpy.data.actions.get(clip)
        check(action is not None and abs(action.frame_range[1] - action.frame_range[0] - duration) < 0.01,
              f"{name}: missing or invalid {clip}")
        rig.animation_data.action = action
        start, middle = (evaluated_points(frame) for frame in (0, duration // 2))
        check(max((a - b).length for a, b in zip(start, middle)) > 0.005, f"{name}: {clip} is static")
        if clip in ("idle", "run"):
            end = evaluated_points(duration)
            check(max((a - b).length for a, b in zip(start, end)) < 0.001, f"{name}: {clip} does not close")
    rig.animation_data.action = bpy.data.actions["run"]
    for bone, first in (("leg.L", 0), ("leg.R", 9)):
        group = mesh.vertex_groups[bone].index
        indices = [v.index for v in mesh.data.vertices if (mesh.matrix_world @ v.co).z < 0.13
                   and any(g.group == group for g in v.groups)]
        anchors = []
        for frame in range(first, first + 6):
            points = evaluated_points(frame)
            boot = [points[index] for index in indices]
            anchors.append(sum(point.y for point in boot) / len(boot) + SPEED[name] * (frame - first) / 24)
            check(abs(min(point.z for point in boot)) < 0.003, f"{name}: {bone} below/above floor")
        check(max(anchors) - min(anchors) < 0.003, f"{name}: {bone} slides during contact")
    rig.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(0)
    print(f"HERO {name}: {triangles} triangles, dimensions {[round(x, 3) for x in spans]}, 5 animated clips")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=ROOT / "assets/models/heroes")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    check({p.name for p in args.input_dir.glob("*.glb")} == {f"{n}.glb" for n in HEROES},
          "Hero GLB set differs")
    for name in HEROES:
        reset_scene()
        bpy.ops.import_scene.gltf(filepath=str(args.input_dir / f"{name}.glb"))
        validate(name)


if __name__ == "__main__":
    main()
