"""Headless Blender: import a Source-engine .mdl via SourceIO, export glTF.
Usage: blender -b -P tools/convert_mdl.py -- --mdl pony.mdl --out probe.glb

Output convention: tier-c probe output goes to game/assets/converted/probe/, NOT
game/assets/converted/ponies/. The ponies/ folder is the tier-a character set that
scenes/test/model_gallery.gd globs and that docs/pipeline.md §3 validates with
--require-anims; a tier-c model (which ships zero animations) dropped in there
fails that loop and inflates GALLERY_OK's count.

Requires the SourceIO addon installed + enabled by tools/setup_env.sh (which also
registers tools/bin/blender_scripts as an extra script-search root and persists that
plus the addon's enabled flag into the user's userpref.blend, so no extra flags/env
vars are needed here -- see the comment block in setup_env.sh for why).

Notes from the tier-c probe (Task 6):
- bpy.ops.sourceio.mdl does NOT take `filepath=`. On Blender 4.1+ its execute()
  reads self.directory + self.files (a list of {"name": <filename>} dicts) via
  ImportOperatorHelper.get_directory() -- filepath alone leaves self.directory empty
  and the importer finds nothing.
- SourceIO's ContentManager auto-discovers the sibling "Materials" tree next to
  "Models" (Source-engine content-root convention) and resolves VMT/VTF materials
  from it automatically -- no manual content-root configuration was needed for the
  SFM pack's "SFM Ready Compiled Files/{Models,Materials}/..." layout, including
  across the models-vs-actual-folder case mismatch (mdl references
  "models\\VA_MLP\\maudpie\\", the on-disk folder is "VA_MLP/MaudPie").
- Source-inch-to-meter scaling is already baked into vertex data on import (checked:
  object.scale stays (1,1,1) and imported mesh/armature dimensions come out in a
  sane meters range, e.g. ~0.9m tall pony). The brief's suggested extra
  0.0254-and-apply scale step was NOT needed for this SourceIO version/model and
  was intentionally omitted -- adding it would have made the model 40x too small.
- A single .mdl imports ALL bodygroup variants (alternate ears/hooves/heads etc.)
  as separate mesh objects, not just the "default" combination a game would show.
  This script exports everything it finds; picking the intended bodygroup subset
  per-model is left as manual follow-up (see task-6-report.md verdict).
- This script is deliberately a thin probe, NOT the tier-a pipeline: it applies
  neither export_blend.py's rebuild_materials_for_gltf() (unnecessary -- SourceIO
  builds Principled-BSDF materials the glTF exporter already understands) nor its
  `--rotate-z 180` facing fix. Consequence: the probe's output faces *backwards*
  relative to the converted tier-a ponies, so it would moonwalk if a scene drove it
  with Node3D.look_at(). Fine for a structural probe; anything promoting a tier-c
  model to a real character needs the same 180-degree yaw baked in (see
  docs/pipeline.md §6).
"""
import argparse, os, sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--mdl", required=True)
p.add_argument("--out", required=True)
args = p.parse_args(argv)

mdl_path = os.path.abspath(args.mdl)
mdl_dir = os.path.dirname(mdl_path) + os.sep
mdl_name = os.path.basename(mdl_path)

bpy.ops.wm.read_homefile(use_empty=True)

result = bpy.ops.sourceio.mdl(directory=mdl_dir, files=[{"name": mdl_name}])
if result != {"FINISHED"}:
    print(f"MDL_IMPORT_FAILED {result}")
    sys.exit(1)

for img in bpy.data.images:               # Source textures arrive as VTF-decoded images; pack them
    if img.source == "FILE":
        img.pack()

bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB",
                          export_animations=True, export_skins=True, export_yup=True)
print(f"MDL_EXPORT_OK {args.out}")
