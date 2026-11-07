"""Run with Blender -b -P tools/unity/export_models.py. Keeps original geometry/rigs."""
import hashlib
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'unity/Assets/Resources/Models'
receipts = []
for source in sorted((ROOT / 'assets/models').glob('*/*.glb')):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    # glTF import creates bone-display helper meshes; they are not part of the asset.
    helpers = {bone.custom_shape for obj in bpy.context.scene.objects if obj.type == 'ARMATURE'
               for bone in obj.pose.bones if bone.custom_shape is not None}
    helpers.update(obj for obj in bpy.context.scene.objects
                   if any(c.name.startswith('glTF_not_exported') for c in obj.users_collection))
    for helper in helpers:
        bpy.data.objects.remove(helper, do_unlink=True)
    # glTF stores linear factors; Unity's FBX material importer expects sRGB colors.
    for material in bpy.data.materials:
        rgba = material.diffuse_color
        srgb = tuple(c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055 for c in rgba[:3]) + (rgba[3],)
        material.diffuse_color = srgb
        if material.use_nodes:
            material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = srgb
    target = OUT / source.parent.name / (source.stem + '.fbx')
    target.parent.mkdir(parents=True, exist_ok=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    actions = sorted(a.name for a in bpy.data.actions)
    bpy.ops.export_scene.fbx(
        filepath=str(target), use_selection=False, object_types={'MESH', 'ARMATURE', 'EMPTY'},
        axis_forward='-Z', axis_up='Y', apply_scale_options='FBX_SCALE_UNITS',
        add_leaf_bones=False, bake_anim=bool(actions), bake_anim_use_all_actions=True,
        bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0.0,
        mesh_smooth_type='FACE', use_mesh_modifiers=True, path_mode='STRIP')
    receipts.append(dict(source=str(source.relative_to(ROOT)).replace('\\', '/'),
                         sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                         output=str(target.relative_to(ROOT)).replace('\\', '/'),
                         triangles=tris, actions=actions))
(OUT / 'conversion.json').write_text(json.dumps(receipts, indent=2) + '\n')
print(f'UNITY_MODELS_EXPORTED: {len(receipts)}')
