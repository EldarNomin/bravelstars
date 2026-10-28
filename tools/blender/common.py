"""Shared geometry, palette and validation for the A-01 environment models."""

import math

import bpy


# STYLE.md lists sRGB hex colors; Blender and glTF base-color factors use linear RGB.
STYLE_HEX = {
    "ground": "7D6B58", "wood": "965A38", "stone": "3E444C",
    "bush": "2D6A4F", "water": "2A8794", "amber": "F6AD55",
    "team_a": "2B6CB0", "team_b": "C53030",
}


def style_color(name, brightness=1.0):
    value = STYLE_HEX[name]
    channels = [min(int(value[i:i + 2], 16) / 255.0 * brightness, 1.0) for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return (*linear, 1.0)


PALETTE = {
    "sand": style_color("ground"), "sand_detail": style_color("ground", 0.78),
    "wood": style_color("wood"), "wood_frame": style_color("wood", 0.65),
    "wood_light": style_color("wood", 1.25),
    "stone": style_color("stone"), "stone_light": style_color("stone", 1.35),
    "metal": style_color("stone", 0.65),
    "bush": style_color("bush"), "bush_light": style_color("bush", 1.25),
    "bush_dark": style_color("bush", 0.65),
    "water": style_color("water"), "water_light": style_color("water", 1.30),
    "fur": style_color("ground", 1.75), "skin": style_color("ground", 1.50),
    "cloth_lynx": style_color("bush", 0.45), "cloth_anvil": style_color("stone", 0.55),
    "cloth_shishka": style_color("wood", 0.45), "amber": style_color("amber"),
    "team_a": style_color("team_a"), "team_b": style_color("team_b"),
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
