"""Contact sheets of the exported clips, three heroes and five times per clip."""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from build_heroes import HEROES  # noqa: E402
from common import reset_scene, style_color  # noqa: E402
from hero_animations import FRAMES  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_clip(clip, duration):
    reset_scene()
    scene = bpy.context.scene
    scene.render.fps = 24
    for row, hero in enumerate(HEROES):
        before = set(scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/heroes" / f"{hero}.glb"))
        imported = [obj for obj in scene.objects if obj not in before]
        rig = next(obj for obj in imported if obj.type == "ARMATURE")
        for track in rig.animation_data.nla_tracks:
            track.mute = True
        selected = next(track.strips[0].action for track in rig.animation_data.nla_tracks
                        if track.strips[0].name.split(".")[0] == clip)
        rig.animation_data.action = selected
        mesh = next(obj for obj in imported if obj.type == "MESH" and any(
            mod.type == "ARMATURE" and mod.object == rig for mod in obj.modifiers))
        for column in range(5):
            frame = duration * column / 4
            scene.frame_set(int(frame), subframe=frame % 1)
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            static_mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                                          depsgraph=bpy.context.evaluated_depsgraph_get())
            obj = bpy.data.objects.new(f"{hero}_{column}", static_mesh)
            scene.collection.objects.link(obj)
            obj.matrix_world = mesh.matrix_world.copy()
            obj.location += Vector(((2 - column) * 1.7, (1 - row) * 2.1, 0))
        for obj in imported:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.05))
    ground_mat = bpy.data.materials.new("ground")
    ground_mat.diffuse_color = style_color("ground")
    bpy.context.object.data.materials.append(ground_mat)
    bpy.ops.object.camera_add(location=(0, 10, 14.9))
    camera = bpy.context.object
    point_at(camera, (0, 0, 0.6))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 9.2
    scene.camera = camera
    label_mat = bpy.data.materials.new("labels")
    label_mat.diffuse_color = (0.9, 0.9, 0.9, 1)
    def label(text, x, y, size=0.16):
        curve = bpy.data.curves.new(text, type="FONT")
        curve.body = text
        curve.align_x = "CENTER"
        curve.size = size
        obj = bpy.data.objects.new(text, curve)
        scene.collection.objects.link(obj)
        obj.parent = camera
        obj.location = (x, y, -1)
        obj.show_in_front = True
        obj.data.materials.append(label_mat)
    label(clip.upper(), 0, 3.5, 0.25)
    for column in range(5):
        label(f"{column * 25}%", (column - 2) * 1.7, 3.1)
    for row, hero in enumerate(reversed(HEROES)):
        label(hero.upper(), -4.15, 1.82 - row * 1.87, 0.13)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.studio_light = "paint.sl"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1500
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(SCRIPT_DIR / f"animation_{clip}.png")
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {scene.render.filepath}")


for clip, duration in FRAMES.items():
    render_clip(clip, duration)
