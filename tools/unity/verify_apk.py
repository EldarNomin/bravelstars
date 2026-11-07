"""Validate ABI, IL2CPP and 16 KB native-library alignment in the built APK."""
import argparse
import hashlib
import json
import struct
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('apk', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
libraries = []
with zipfile.ZipFile(args.apk) as archive, args.apk.open('rb') as raw:
    entries = [i for i in archive.infolist() if i.filename.startswith('lib/') and i.filename.endswith('.so')]
    assert any(i.filename == 'lib/arm64-v8a/libil2cpp.so' for i in entries), 'IL2CPP missing'
    assert {i.filename.split('/')[1] for i in entries} == {'arm64-v8a'}, 'Unexpected ABI'
    for entry in entries:
        data = archive.read(entry)
        assert data[:5] == b'\x7fELF\x02' and struct.unpack_from('<H', data, 18)[0] == 183, f'Not ARM64 ELF: {entry.filename}'
        phoff = struct.unpack_from('<Q', data, 32)[0]
        phsize, phcount = struct.unpack_from('<HH', data, 54)
        alignments = [struct.unpack_from('<Q', data, phoff + i * phsize + 48)[0]
                      for i in range(phcount) if struct.unpack_from('<I', data, phoff + i * phsize)[0] == 1]
        assert alignments and min(alignments) >= 16384, f'ELF is not 16 KB aligned: {entry.filename}'
        if entry.compress_type == zipfile.ZIP_STORED:
            raw.seek(entry.header_offset + 26)
            name_length, extra_length = struct.unpack('<HH', raw.read(4))
            offset = entry.header_offset + 30 + name_length + extra_length
            assert offset % 16384 == 0, f'ZIP native data is not 16 KB aligned: {entry.filename}'
        libraries.append({'path': entry.filename, 'elf_alignment': min(alignments)})
receipt = {'apk': args.apk.name, 'bytes': args.apk.stat().st_size,
           'sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(), 'libraries': libraries}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt, indent=2))
print('APK_NATIVE_CHECKS_PASSED')
