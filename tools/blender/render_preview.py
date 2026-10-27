"""Render a contact sheet from the exported GLBs, not the source meshes."""

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from common import ASSET_RULES, reset_scene  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def label(text, x, y):
    curve = bpy.data.curves.new(name=f"label_{text}", type="FONT")
    curve.body = text.upper()
    curve.align_x = "CENTER"
    curve.size = 0.20
    obj = bpy.data.objects.new(f"label_{text}", curve)
    bpy.context.collection.objects.link(obj)
    obj.location = (x, y - 0.76, -0.045)
    mat = bpy.data.materials.get("preview_text")
    if not mat:
        mat = bpy.data.materials.new("preview_text")
        mat.diffuse_color = (0.11, 0.12, 0.16, 1.0)
    obj.data.materials.append(mat)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=ROOT / "assets/models/env")
    parser.add_argument("--output", type=Path, default=SCRIPT_DIR / "preview.png")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    reset_scene()
    names = list(ASSET_RULES)
    for index, name in enumerate(names):
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(args.input_dir / f"{name}.glb"))
        imported = [obj for obj in bpy.context.scene.objects if obj not in before]
        x = (index % 5 - 2) * 1.65
        y = (0.5 - index // 5) * 2.35
        # Move only roots: imported GLB children inherit their parent transform.
        for obj in imported:
            if obj.parent is None:
                obj.location.x += x
                obj.location.y += y
        label(name, x, y)

    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.06))
    ground = bpy.context.object
    ground.name = "preview_ground"
    mat = bpy.data.materials.new("preview_ground")
    mat.diffuse_color = (0.78, 0.80, 0.82, 1.0)
    ground.data.materials.append(mat)

    bpy.ops.object.camera_add(location=(0, -10.7, 12.2))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 9.5
    point_at(camera, (0, 0, 0.2))
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(args.output)
    bpy.ops.render.render(write_still=True)
    if not args.output.is_file() or args.output.stat().st_size == 0:
        raise RuntimeError(f"Render did not create {args.output}")
    print(f"Rendered imported GLBs to {args.output}")


if __name__ == "__main__":
    main()
