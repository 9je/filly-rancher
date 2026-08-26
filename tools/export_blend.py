"""Headless Blender: export a .blend (or one collection/object in it) to glTF.
Usage: blender -b file.blend -P tools/export_blend.py -- --out out.glb [--object Twilight]
"""
import argparse, sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--object", default=None, help="only export this object + its armature/children")
args = p.parse_args(argv)

# --- Quirk: CreatorOfPony / MythicSpeed reupload packs (2015-era Blender Internal
# files opened in Blender 4.2) never got their materials migrated to Principled BSDF.
# They use hand-built Diffuse/Glossy/Fresnel/Velvet node graphs (see e.g. "Base_Body":
# Fresnel-mixed Glossy+Velvet+Diffuse, with the Image Texture feeding the Diffuse BSDF
# several hops upstream of Material Output). The glTF exporter only recognizes a
# Principled BSDF wired straight into Material Output's Surface socket, so these
# materials silently export with textured=False even though the textures are right
# there. Fix generically and in-script (not by hand): for every material, add a fresh
# Principled BSDF, wire the first Image Texture node's Color (and Alpha, if present)
# straight into it, and reconnect it to Material Output. Materials with no image
# texture (solid colors like Base_Black/Base_Mouth/BG) fall back to whatever solid
# color their existing Diffuse/Emission node was using, so they still look right.
def rebuild_materials_for_gltf():
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        nt = mat.node_tree
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None or "Surface" not in out.inputs:
            continue
        img_node = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image), None)
        principled = nt.nodes.new("ShaderNodeBsdfPrincipled")
        if img_node is not None:
            nt.links.new(img_node.outputs["Color"], principled.inputs["Base Color"])
            try:
                if img_node.image.depth in (32, 128) and "Alpha" in img_node.outputs:
                    nt.links.new(img_node.outputs["Alpha"], principled.inputs["Alpha"])
            except (RuntimeError, ReferenceError):
                pass  # image not loadable (missing file) -- base color link is enough
        else:
            color = (0.8, 0.8, 0.8, 1.0)
            for n in nt.nodes:
                if n.type in ("BSDF_DIFFUSE", "EMISSION") and "Color" in n.inputs:
                    color = n.inputs["Color"].default_value[:]
                    break
            principled.inputs["Base Color"].default_value = color
        nt.links.new(principled.outputs["BSDF"], out.inputs["Surface"])


rebuild_materials_for_gltf()

# --- Quirk: textures ship as loose PNGs next to the .blend (not packed into it).
# Blender resolves those relative paths fine regardless of our cwd, but packing
# them in-memory before export removes any ambiguity and matches the brief's
# documented fallback for texture-mapping failures.
bpy.ops.file.pack_all()

if args.object:
    target = bpy.data.objects.get(args.object)
    if target is None:
        names = sorted(o.name for o in bpy.data.objects)
        sys.exit(f"object {args.object!r} not found; scene has: {names}")
    keep = {target} | set(target.children_recursive)
    for mod in getattr(target, "modifiers", []):
        if mod.type == "ARMATURE" and mod.object:
            keep |= {mod.object} | set(mod.object.children_recursive)
    # --- Quirk: these rigged character files lock the body meshes' viewport
    # selectability (outliner's "Disable Selection" toggle / hide_select=True) so
    # animators can't accidentally drag a mesh instead of a bone. obj.select_set()
    # silently no-ops on a hide_select object -- it doesn't raise, it just leaves
    # the object unselected, so the exporter's use_selection export ends up with
    # only the (selectable) armature and zero meshes. Since we never save this
    # .blend back to disk, it's safe to unlock selection on everything we intend
    # to export before selecting it.
    for obj in keep:
        obj.hide_select = False
    for obj in bpy.data.objects:
        obj.select_set(obj in keep)
    use_selection = True
else:
    use_selection = False

bpy.ops.export_scene.gltf(
    filepath=args.out,
    export_format="GLB",
    use_selection=use_selection,
    export_apply=True,           # apply modifiers except armatures
    export_animations=True,
    export_skins=True,
    export_yup=True,
)
print(f"EXPORT_OK {args.out}")
