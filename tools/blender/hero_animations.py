"""In-place hero actions. One unit is one metre; the game moves the root."""

import math

import bpy
from mathutils import Quaternion, Vector

FPS = 24
FRAMES = {"idle": 36, "run": 18, "attack": 7, "super": 12, "death": 18}
SPEED = {"lynx": 2.3, "anvil": 2.6, "shishka": 2.3}


def pose(rig, bone, frame, rotation=(0, 0, 0), translation=(0, 0, 0)):
    part = rig.pose.bones[bone]
    rest_inverse = rig.data.bones[bone].matrix_local.to_3x3().inverted()
    part.rotation_mode = "QUATERNION"
    q = Quaternion()
    for axis, angle in zip(((1, 0, 0), (0, 1, 0), (0, 0, 1)), rotation):
        q @= Quaternion(rest_inverse @ Vector(axis), math.radians(angle))
    part.rotation_quaternion = q
    part.location = rest_inverse @ Vector(translation)
    part.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone)
    part.keyframe_insert(data_path="location", frame=frame, group=bone)


def action(rig, name):
    rig.animation_data.action = bpy.data.actions.new(name)
    return rig.animation_data.action


def run_leg(rig, name, frame, speed, shift):
    phase = (frame + shift) % 18
    # Five frames of ground contact; the moving scene advances exactly this distance.
    contact = 5
    distance = speed * contact / FPS
    if phase <= contact:
        progress = phase / contact
        y = distance * (0.5 - progress)
        lift = 0.0
    else:
        progress = (phase - contact) / (18 - contact)
        y = distance * (-0.5 + progress)
        lift = 0.12 * math.sin(math.pi * progress)
    angle = math.degrees(math.asin(max(-0.95, min(0.95, y / 0.27))))
    # Position the rigid boot after rotation: the grounded sole stays still in world space.
    pose(rig, name, frame, (angle, 0, 0))
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    mesh = next(obj for obj in rig.children if obj.type == "MESH")
    group = mesh.vertex_groups[name].index
    indices = [v.index for v in mesh.data.vertices if (mesh.matrix_world @ v.co).z < 0.13
               and any(g.group == group for g in v.groups)]
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    deformed = evaluated.to_mesh()
    points = [evaluated.matrix_world @ deformed.vertices[index].co for index in indices]
    evaluated.to_mesh_clear()
    center_y = sum(point.y for point in points) / len(points)
    bottom_z = min(point.z for point in points)
    pose(rig, name, frame, (angle, 0, 0), (0, 0.03 + y - center_y, lift - bottom_z))


def add_animations(rig, hero):
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 0, 36
    rig.animation_data_create()
    for name, end in FRAMES.items():
        current = action(rig, name)
        # Key a neutral baseline for every bone so switching actions cannot inherit a previous pose.
        for bone in rig.pose.bones:
            pose(rig, bone.name, 0)
            pose(rig, bone.name, end)
        frames = range(end + 1) if name == "run" else (0, end // 3, 2 * end // 3, end)
        for frame in frames:
            t = frame / end
            if name == "idle":
                breath = math.sin(math.pi * t) ** 2
                pose(rig, "spine", frame, (2 * breath, 0, 0))
                pose(rig, "head_bone", frame, (-breath, 0, 0))
                pose(rig, "arm.R", frame, (0, 1.5 * breath, 0))
            elif name == "run":
                run_leg(rig, "leg.L", frame, SPEED[hero], 0)
                run_leg(rig, "leg.R", frame, SPEED[hero], 9)
                pose(rig, "spine", frame, (-7, 0, 2 * math.sin(4 * math.pi * t)))
                pose(rig, "arm.L", frame, (12 * math.cos(2 * math.pi * t), 0, 0))
                pose(rig, "arm.R", frame, (-6 * math.cos(2 * math.pi * t), 0, 0))
            elif name == "attack":
                amount = (0, 1, 0.45, 0)[list(frames).index(frame)]
                if hero == "shishka":
                    pose(rig, "arm.R", frame, (105 * amount, 0, -15 * amount))
                    pose(rig, "spine", frame, (10 * amount, 0, 0))
                else:
                    kick = 22 if hero == "lynx" else 32
                    pose(rig, "arm.R", frame, (kick * amount, 0, 0))
                    pose(rig, "spine", frame, (kick * 0.35 * amount, 0, 0))
            elif name == "super":
                amount = (0, 0.65, 1, 0)[list(frames).index(frame)]
                if hero == "anvil":
                    pose(rig, "spine", frame, (-38 * amount, 0, -18 * amount))
                    pose(rig, "arm.L", frame, (-30 * amount, 0, -25 * amount))
                elif hero == "lynx":
                    pose(rig, "arm.R", frame, (38 * amount, 0, 0))
                    pose(rig, "spine", frame, (16 * amount, 0, 0))
                else:
                    pose(rig, "arm.R", frame, (135 * amount, 0, -30 * amount))
                    pose(rig, "arm.L", frame, (70 * amount, 0, 25 * amount))
                    pose(rig, "spine", frame, (18 * amount, 0, 0))
            else:
                amount = (0, 0.2, 0.8, 1)[list(frames).index(frame)]
                pose(rig, "root", frame, (-82 * amount, 0, 0), (0, 0, 0.02 * amount))
                pose(rig, "arm.L", frame, (0, 0, -35 * amount))
                pose(rig, "arm.R", frame, (0, 0, 35 * amount))
        for curve in current.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = "LINEAR"
            if name in ("idle", "run"):
                curve.modifiers.new(type="CYCLES")
    rig.animation_data.action = bpy.data.actions["idle"]
    scene.frame_set(0)
