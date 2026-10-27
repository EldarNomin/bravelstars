"""Render actual GLBs from above at the game's camera angle."""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from build_fx import PROJECTILES, ROOT, STRUCTURES  # noqa: E402
from common import reset_scene, style_color  # noqa: E402


def render(names, filename, factor, gap, width):
    reset_scene()
    for index, name in enumerate(names):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models/fx" / f"{name}.glb"))
        imported = [obj for obj in bpy.context.scene.objects if obj not in before]
        for obj in imported:
            if obj.parent is None:
                obj.location.x = ((len(names) - 1) / 2 - index) * gap
                obj.location.z = 0.6 if factor > 1 else 0
                obj.scale *= factor
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.03))
    mat = bpy.data.materials.new("ground")
    mat.diffuse_color = style_color("ground")
    bpy.context.object.data.materials.append(mat)
    bpy.ops.object.camera_add(location=(0, 8, 12.03))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.6)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = width
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.studio_light = "paint.sl"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    label_mat = bpy.data.materials.new("labels")
    label_mat.diffuse_color = (0.9, 0.9, 0.9, 1)
    for index, name in enumerate(names):
        curve = bpy.data.curves.new(name, type="FONT")
        curve.body, curve.align_x, curve.size = name.upper().replace("_", " "), "CENTER", width * 0.022
        label = bpy.data.objects.new(name + "_label", curve)
        scene.collection.objects.link(label)
        label.parent = camera
        label.location = ((index - (len(names) - 1) / 2) * gap, -width * 0.15, -1)
        label.show_in_front = True
        label.data.materials.append(label_mat)
    scene.render.filepath = str(SCRIPT_DIR / filename)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {scene.render.filepath}")


render(PROJECTILES, "fx_projectiles.png", 2.0, 1.55, 8.4)
render(STRUCTURES, "fx_structures.png", 1.0, 1.8, 6.0)
