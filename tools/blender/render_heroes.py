"""Render the exported GLBs from the gameplay angle and from the front."""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from common import reset_scene, style_color  # noqa: E402
from build_heroes import HEROES  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=ROOT / "assets/models/heroes")
    parser.add_argument("--output-dir", type=Path, default=SCRIPT_DIR)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    reset_scene()
    for index, name in enumerate(HEROES):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(args.input_dir / f"{name}.glb"))
        imported = [obj for obj in bpy.context.scene.objects if obj not in before]
        x = (index - 1) * 1.45
        for obj in imported:
            if obj.parent is None:
                obj.location.x += x
    bpy.context.scene.frame_set(1)

    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.03))
    ground = bpy.context.object
    ground.name = "preview_ground"
    ground_mat = bpy.data.materials.new("preview_ground")
    ground_mat.diffuse_color = style_color("ground")
    ground.data.materials.append(ground_mat)

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.studio_light = "paint.sl"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    args.output_dir.mkdir(parents=True, exist_ok=True)

    label_mat = bpy.data.materials.new("preview_label")
    label_mat.diffuse_color = (0.9, 0.9, 0.9, 1.0)
    for index, name in enumerate(HEROES):
        curve = bpy.data.curves.new(f"label_{name}", type="FONT")
        curve.body = name.upper()
        curve.align_x = "CENTER"
        curve.size = 0.17
        label = bpy.data.objects.new(f"label_{name}", curve)
        bpy.context.collection.objects.link(label)
        label.parent = camera
        label.location = ((1 - index) * 1.45, -0.85, -1.0)
        label.show_in_front = True
        label.data.materials.append(label_mat)

    for label, location, scale in (
        ("front", (0, 7.5, 1.0), 4.9),
        ("top55", (0, 5.0, 7.74), 4.9),
    ):
        camera.location = location
        camera.data.ortho_scale = scale
        point_at(camera, (0, 0, 0.65))
        scene.render.filepath = str(args.output_dir / f"heroes_{label}.png")
        bpy.ops.render.render(write_still=True)
        print(f"Rendered {scene.render.filepath}")


if __name__ == "__main__":
    main()
