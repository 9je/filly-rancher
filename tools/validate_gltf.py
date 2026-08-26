"""Sanity-check an exported .glb: mesh present, rigged, textured, lists animations.
Usage: python3 tools/validate_gltf.py file.glb [--require-anims]
Exits non-zero on failure. No deps beyond stdlib (parses GLB's JSON chunk).
"""
import json, struct, sys

path = sys.argv[1]
require_anims = "--require-anims" in sys.argv
with open(path, "rb") as f:
    magic, _ver, _length = struct.unpack("<4sII", f.read(12))
    assert magic == b"glTF", "not a GLB file"
    chunk_len, chunk_type = struct.unpack("<II", f.read(8))
    assert chunk_type == 0x4E4F534A, "first chunk not JSON"
    gltf = json.loads(f.read(chunk_len))

meshes = gltf.get("meshes", [])
skins = gltf.get("skins", [])
anims = [a.get("name", f"anim{i}") for i, a in enumerate(gltf.get("animations", []))]
mats = gltf.get("materials", [])
textured = any("baseColorTexture" in m.get("pbrMetallicRoughness", {}) for m in mats)

print(f"meshes={len(meshes)} skins={len(skins)} materials={len(mats)} "
      f"textured={textured} animations={anims}")
ok = bool(meshes) and bool(skins)
if require_anims:
    ok = ok and bool(anims)
sys.exit(0 if ok else f"VALIDATION FAILED for {path}")
