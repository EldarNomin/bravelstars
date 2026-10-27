"""Exercise failure paths for geometry constraints used by the CI builder."""

import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, material, mesh_objects, reset_scene, validate  # noqa: E402


def expect_failure(name, message):
    try:
        validate(name, mesh_objects())
    except ValueError as error:
        if message not in str(error):
            raise AssertionError(f"Expected {message!r}, got {error!r}") from error
        print(f"Validation rejected {name}: {error}")
        return
    raise AssertionError(f"Validation unexpectedly accepted {name}: {message}")


reset_scene()
box("floor", (1.0, 1.0, 0.05), (0, 0, 0.025), "sand")
validate("floor", mesh_objects())

reset_scene()
box("oversized_wall", (1.1, 1.0, 1.0), (0, 0, 0.5), "wood")
expect_failure("wall", "exceeds")

reset_scene()
box("floating_debris", (0.3, 0.2, 0.1), (0, 0, 0.2), "wood")
expect_failure("debris_01", "base must touch")

reset_scene()
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.3, location=(0, 0, 0.3))
bpy.context.object.data.materials.append(material("bush"))
expect_failure("bush_01", "triangles")

reset_scene()
bpy.ops.mesh.primitive_cube_add()
expect_failure("floor", "not a materialized mesh")

print("Validation rejected oversized, floating, over-budget and unmaterialized meshes")
