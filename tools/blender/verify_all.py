"""Re-import generated GLBs and check the actual exported meshes and materials."""

import argparse
import sys
from pathlib import Path

import bpy

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from common import ASSET_RULES, mesh_objects, reset_scene, validate  # noqa: E402

ROOT = SCRIPT_DIR.parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=ROOT / "assets/models/env")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    expected = {f"{name}.glb" for name in ASSET_RULES}
    actual = {path.name for path in args.input_dir.glob("*.glb")}
    if actual != expected:
        raise ValueError(f"GLB files differ: missing={expected - actual}, unexpected={actual - expected}")
    for name in ASSET_RULES:
        reset_scene()
        bpy.ops.import_scene.gltf(filepath=str(args.input_dir / f"{name}.glb"))
        objects = mesh_objects()
        validate(name, objects)
        for obj in objects:
            for mat in obj.data.materials:
                if mat is None or not mat.use_nodes:
                    raise ValueError(f"{name}: missing imported PBR material")
                if any(node.type == "TEX_IMAGE" for node in mat.node_tree.nodes):
                    raise ValueError(f"{name}: external or embedded texture is not allowed")
    print(f"Verified {len(ASSET_RULES)} imported GLBs")


if __name__ == "__main__":
    main()
