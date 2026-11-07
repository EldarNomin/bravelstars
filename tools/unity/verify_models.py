"""Reject stale conversions and Blender helper geometry in the FBX receipts."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
receipts = json.loads((ROOT / 'unity/Assets/Resources/Models/conversion.json').read_text())
sources = {str(p.relative_to(ROOT)).replace('\\', '/') for p in (ROOT / 'assets/models').glob('*/*.glb')}
assert {r['source'] for r in receipts} == sources, 'Model inventory differs from source'
for receipt in receipts:
    source = (ROOT / receipt['source']).read_bytes()
    assert source[:4] == b'glTF', f"LFS asset not downloaded: {receipt['source']}"
    assert hashlib.sha256(source).hexdigest() == receipt['sha256'], f"Stale model: {receipt['source']}"
    length = struct.unpack_from('<I', source, 12)[0]
    gltf = json.loads(source[20:20 + length])
    triangles = sum(gltf['accessors'][p['indices']]['count'] // 3 for m in gltf['meshes'] for p in m['primitives'])
    assert triangles == receipt['triangles'], f"Export contains extra geometry: {receipt['source']}"
    animations = sorted(a['name'] for a in gltf.get('animations', []))
    assert animations == receipt['actions'], f"Animation inventory differs: {receipt['source']}"
    output = ROOT / receipt['output']
    assert output.is_file() and output.read_bytes().startswith(b'Kaydara FBX Binary'), f'Missing FBX: {output}'
print(f"MODEL_SOURCE_PARITY_PASSED {len(receipts)} models; geometry counts, animations, source hashes")
