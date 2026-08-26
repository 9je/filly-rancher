"""Sanity-check an exported .glb: mesh present, rigged, textured, lists animations.
Usage: python3 tools/validate_gltf.py file.glb [--require-anims] [--props]
Exits non-zero on failure. No deps beyond stdlib (parses GLB's JSON chunk).

--props: validate as a static (unrigged) prop instead of a character -- gates
on meshes>=1 only, without requiring a skin. Static Sketchfab/Kenney/Quaternius
props never ship a skin, so the default `meshes and skins` gate would fail
every one of them; --props is the mode Task 8 (map-props probe) uses.

Argument parsing is argparse, deliberately, not a hand-rolled `"--flag" in
sys.argv` scan: the scan silently ignored anything it didn't recognise, so a
typo (`--require-anim`, singular) disabled the animation gate instead of
failing, and this script would exit 0 on an unanimated model. argparse rejects
unknown flags. The printed line format and exit-code semantics (0 pass,
non-zero fail) are quoted by docs/pipeline.md and other scripts -- keep both
exactly as they are.
"""
import argparse, json, struct, sys

# allow_abbrev=False: argparse otherwise accepts any unambiguous *prefix* of a flag,
# so `--require-anim` would be silently accepted as `--require-anims`. Near-misses
# should be rejected, not guessed at -- this is a gate, and quietly reinterpreting a
# mistyped gate flag is exactly the failure mode being fixed here.
p = argparse.ArgumentParser(description="Structural validation of a .glb export.",
                            allow_abbrev=False)
p.add_argument("path", help="path to the .glb file to validate")
p.add_argument("--require-anims", action="store_true",
               help="also require at least one animation clip")
p.add_argument("--props", action="store_true",
               help="validate as a static prop (meshes>=1, no skin required)")
args = p.parse_args()

path = args.path
require_anims = args.require_anims
props_mode = args.props

try:
    f = open(path, "rb")
except OSError as exc:
    sys.exit(f"VALIDATION FAILED for {path}: {exc.strerror}")
with f:
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
ok = bool(meshes) if props_mode else bool(meshes) and bool(skins)
if require_anims:
    ok = ok and bool(anims)
sys.exit(0 if ok else f"VALIDATION FAILED for {path}")
