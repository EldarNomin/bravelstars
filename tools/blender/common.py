"""Shared geometry, palette and validation for the A-01 environment models."""

import math

import bpy


# Temporary colors from src/view/debug/debug_match.gd; replace after STYLE.md is approved.
PALETTE = {
    "sand": (0.82, 0.76, 0.60, 1.0),
    "sand_detail": (0.69, 0.62, 0.47, 1.0),
    "wood": (0.60, 0.40, 0.25, 1.0),
    "wood_frame": (0.39, 0.23, 0.12, 1.0),
    "wood_light": (0.72, 0.50, 0.31, 1.0),
    "stone": (0.35, 0.35, 0.40, 1.0),
    "stone_light": (0.46, 0.47, 0.51, 1.0),
    "metal": (0.19, 0.22, 0.27, 1.0),
    "bush": (0.20, 0.65, 0.25, 1.0),
    "bush_light": (0.32, 0.75, 0.30, 1.0),
    "bush_dark": (0.12, 0.42, 0.17, 1.0),
    "water": (0.20, 0.45, 0.85, 1.0),
    "water_light": (0.43, 0.68, 0.95, 1.0),
}

# (maximum x/y/z span, minimum z, maximum z); Blender coordinates are metres, Z is up.
ASSET_RULES = {
    "floor": ((1.0, 1.0, 0.06), 0.0, 0.06),
    "wall": ((1.0, 1.0, 1.0), 0.0, 1.0),
    "hard_wall": ((1.0, 1.0, 1.2), 0.0, 1.2),
    "bush_01": ((1.0, 1.0, 0.75), 0.0, 0.75),
    "bush_02": ((1.0, 1.0, 0.75), 0.0, 0.75),
    "water": ((1.0, 1.0, 0.04), -0.04, 0.0),
    "debris_01": ((1.0, 1.0, 0.5), 0.0, 0.5),
    "debris_02": ((1.0, 1.0, 0.5), 0.0, 0.5),
    "debris_03": ((1.0, 1.0, 0.5), 0.0, 0.5),
    "debris_04": ((1.0, 1.0, 0.5), 0.0, 0.5),
}
MAX_TRIANGLES = 300
TOLERANCE = 0.0001


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name=name)
    mat.diffuse_color = PALETTE[name]
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = PALETTE[name]
    principled.inputs["Roughness"].default_value = 0.85
    return mat


def box(name, size, center, color, rotation_y=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    obj.rotation_euler.y = math.radians(rotation_y)
    obj.data.materials.append(material(color))
    return obj


def leaf(name, center, scale, color, angle=0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler.z = math.radians(angle)
    obj.data.materials.append(material(color))
    return obj


def mesh_objects():
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def validate(name, objects):
    if name not in ASSET_RULES or not objects:
        raise ValueError(f"{name}: unknown asset or no mesh objects")
    bpy.context.view_layer.update()
    triangles = 0
    points = []
    for obj in objects:
        if obj.type != "MESH" or not obj.data.materials:
            raise ValueError(f"{name}: {obj.name} is not a materialized mesh")
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        points.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
    lower = [min(point[i] for point in points) for i in range(3)]
    upper = [max(point[i] for point in points) for i in range(3)]
    spans = [upper[i] - lower[i] for i in range(3)]
    maximum, min_z, max_z = ASSET_RULES[name]
    if triangles <= 0 or triangles > MAX_TRIANGLES:
        raise ValueError(f"{name}: {triangles} triangles, allowed 1..{MAX_TRIANGLES}")
    if any(spans[i] > maximum[i] + TOLERANCE for i in range(3)):
        raise ValueError(f"{name}: span {spans} exceeds {maximum}")
    if lower[2] < min_z - TOLERANCE or upper[2] > max_z + TOLERANCE:
        raise ValueError(f"{name}: z bounds {lower[2]:.4f}..{upper[2]:.4f} invalid")
    if name == "water" and upper[2] >= 0:
        raise ValueError(f"{name}: water must stay below the ground plane")
    if name != "water" and abs(lower[2]) > TOLERANCE:
        raise ValueError(f"{name}: base must touch the ground at z=0")
    if lower[0] < -0.5 - TOLERANCE or upper[0] > 0.5 + TOLERANCE:
        raise ValueError(f"{name}: x bounds outside cell around origin")
    if lower[1] < -0.5 - TOLERANCE or upper[1] > 0.5 + TOLERANCE:
        raise ValueError(f"{name}: y bounds outside cell around origin")
    if name in {"floor", "wall", "hard_wall", "water"}:
        if abs(spans[0] - 1.0) > TOLERANCE or abs(spans[1] - 1.0) > TOLERANCE:
            raise ValueError(f"{name}: expected a full 1x1 metre cell")
    if name in {"wall", "hard_wall"} and abs(upper[2] - max_z) > TOLERANCE:
        raise ValueError(f"{name}: wall height must be {max_z} m")
    if name.startswith("bush_") and not 0.55 <= upper[2] <= 0.75:
        raise ValueError(f"{name}: bush height must be around 0.7 m")
    print(f"{name}: {triangles} triangles, span {[round(v, 4) for v in spans]}, "
          f"z={lower[2]:.4f}..{upper[2]:.4f}")
    return triangles
