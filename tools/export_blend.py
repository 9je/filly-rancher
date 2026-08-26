"""Headless Blender: export a .blend (or one collection/object in it) to glTF.
Usage: blender -b file.blend -P tools/export_blend.py -- --out out.glb [--object Twilight]
                                                        [--anims] [--rotate-z 180]

Prop variant (Task 8): for a source FBX prop instead of an already-open .blend,
run with no .blend argument and pass --fbx-in:
  blender -b -P tools/export_blend.py -- --fbx-in prop.fbx --out prop.glb
This imports the FBX into the (empty) default scene before the rest of the
pipeline below runs unchanged -- material rebuild, pack_all, export.
"""
import argparse, os, sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--object", default=None, help="only export this object + its armature/children")
p.add_argument("--anims", action="store_true",
               help="author 'idle' + 'walk' Actions onto the rig before exporting "
                    "(see tools/author_anims.py); the packs ship none of their own")
p.add_argument("--rotate-z", type=float, default=0.0, metavar="DEG",
               help="yaw the exported root this many degrees about +Z before export")
p.add_argument("--fbx-in", default=None, metavar="PATH",
               help="import this FBX into the current (normally empty) scene before "
                    "doing anything else -- lets this script convert a standalone FBX "
                    "prop without a pre-authored .blend to open it from")
args = p.parse_args(argv)

if args.fbx_in:
    # --- Quirk (Task 8): `blender -b` with no .blend argument opens Blender's
    # default startup scene (a Cube + Camera + Light), not an empty one. Since
    # nothing below restricts export to a selection unless --object is also
    # passed, exporting after the FBX import would include that leftover
    # default Cube alongside the real prop -- it did, silently, the first time
    # this ran: `kenney_survival_structure.glb` came out with two meshes, an
    # untextured 2x2x2 "Cube" plus the real "structure" mesh, and it still
    # passed `validate_gltf.py --props` (meshes>=1) without anyone noticing
    # until a rendered frame showed a flat grey box sitting on the real prop.
    # Fix: snapshot what's in the scene before importing, then delete exactly
    # those pre-existing objects afterward -- whatever the FBX import added is
    # the only thing that survives. Safe because this .blend is never saved.
    _pre_import_objects = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=args.fbx_in)
    for obj in _pre_import_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

# --- Quirk: CreatorOfPony / MythicSpeed reupload packs (2015-era Blender Internal
# files opened in Blender 4.2) never got their materials migrated to Principled BSDF.
# They use hand-built Diffuse/Glossy/Fresnel/Velvet node graphs (see e.g. "Base_Body":
# Fresnel-mixed Glossy+Velvet+Diffuse, with the color feeding the Diffuse BSDF several
# hops upstream of Material Output). The glTF exporter only recognizes a Principled
# BSDF wired straight into Material Output's Surface socket, so these materials
# silently export with textured=False even though the colors are right there. Fix
# generically and in-script (not by hand): for every material, add a fresh Principled
# BSDF, resolve the material's real base color into it, and reconnect it to Material
# Output.
#
# The naive version of this (Task 4) took "the first Image Texture node in the
# material" as the base color, which is wrong in two ways that only became visible
# once something actually rendered the result (Task 7):
#
#  1. DECAL COMPOSITES. Twilight's body has no body texture at all -- the pack ships
#     only Eye.png and TS_CutieMark.png. `Base_Body` is a solid lavender RGB with the
#     cutie mark alpha-composited on top: Diffuse.Color <- Mix(Factor=CutieMark.Alpha,
#     A=RGB(0.638,0.347,0.768), B=CutieMark.Color). Grabbing "the first image" made the
#     cutie-mark decal the base color of the entire pony AND wired its mostly-zero
#     alpha into Principled Alpha, so the whole body exported invisible -- everything
#     but a floating cutie mark, mane and eyes. The alpha on a decal image is a mask
#     for where the decal applies, not surface transparency, and must never become
#     material alpha.
#  2. NODE-GROUP MATERIALS. The Hair_* materials are a single "Hair" node group whose
#     color lives in an unlinked group input (deep purple, 0.133/0.026/0.254). The old
#     fallback only scanned for a top-level Diffuse/Emission node, found none, and
#     defaulted to 0.8 grey -- which is why the mane and tail rendered off-white.
#
# So instead of guessing from node order, walk backwards from Material Output's
# Surface socket through the shader mixers to find the material's principal color-
# bearing shader, then resolve that shader's color input. Alpha is wired only when an
# image is the *direct* base color (Base_Iris/Base_Eye, where the eye texture's
# transparent surround is genuine transparency), never when it was reached through a
# Mix. Materials whose alpha we did not wire are forced to blend_method OPAQUE: these
# files come out of the 2015->4.2 conversion with every material set to HASHED, which
# the exporter turns into a blended alphaMode for geometry that is meant to be solid.
#
# KNOWN LIMITATION: glTF cannot express the body's color-plus-decal mix in one
# material, so the exported body keeps its lavender base color and loses the cutie
# mark. Restoring it means baking the mix down to a body texture (Cycles bake over the
# existing UVs) -- worth doing in Phase 1, out of scope for the Phase 0 spike.

# Preference order when several color-bearing shaders feed one Material Output. The
# rim/spec helpers these materials pile on (Glossy, Sheen/Velvet, Fresnel) carry no
# useful base color, so Diffuse/Principled wins over them.
_SHADER_PRIORITY = {
    "BSDF_PRINCIPLED": 0, "BSDF_DIFFUSE": 1, "EMISSION": 2,
    "GROUP": 3, "BSDF_TOON": 4, "BSDF_SHEEN": 5, "BSDF_VELVET": 5,
}
_COLOR_FILTERS = ("CURVE_RGB", "GAMMA", "BRIGHTCONTRAST", "HUE_SAT", "INVERT")
_DEFAULT_COLOR = (0.8, 0.8, 0.8, 1.0)


def _principal_shader(out):
    """Walk back from Material Output through shader mixers to the best color source.

    Returns (shader_node_or_None, saw_transparent_bsdf).
    """
    seen, found, transparent = set(), [], False
    stack = [link.from_node for link in out.inputs["Surface"].links]
    while stack:
        node = stack.pop()
        if node.name in seen:
            continue
        seen.add(node.name)
        if node.type in ("MIX_SHADER", "ADD_SHADER"):
            for sock in node.inputs:
                stack.extend(link.from_node for link in sock.links)
        elif node.type == "BSDF_TRANSPARENT":
            transparent = True
        elif node.type in _SHADER_PRIORITY:
            found.append(node)
    found.sort(key=lambda n: _SHADER_PRIORITY[n.type])
    return (found[0] if found else None), transparent


def _color_socket(node):
    """The socket carrying a shader node's (or node group's) base color."""
    if node is None:
        return None
    if node.type == "GROUP":
        return next((i for i in node.inputs if i.type == "RGBA"), None)
    for name in ("Base Color", "Color"):
        if name in node.inputs:
            return node.inputs[name]
    return None


def _mix_base_socket(node):
    """The 'underneath' input of a Mix node -- the layer a decal sits on top of.

    Blender 4.x Mix nodes carry float/vector/color variants all named A and B, so
    select by socket type rather than by name.
    """
    rgba = [i for i in node.inputs if i.type == "RGBA"]
    named = [i for i in rgba if i.name in ("A", "Color1")]
    return (named or rgba or [None])[0]


def _resolve_color(socket, depth=0):
    """Resolve a color socket to ('image', tex_node) or ('solid', rgba).

    Third element says whether we passed through a Mix, i.e. whether any image we
    landed on is a decal layer rather than the surface's own texture.
    """
    if socket is None or depth > 8:
        return "solid", _DEFAULT_COLOR, False
    if not socket.links:
        try:
            return "solid", tuple(socket.default_value), False
        except TypeError:
            return "solid", _DEFAULT_COLOR, False
    src = socket.links[0].from_node
    if src.type == "TEX_IMAGE" and src.image:
        return "image", src, False
    if src.type == "RGB":
        return "solid", tuple(src.outputs[0].default_value), False
    if src.type in ("MIX", "MIX_RGB"):
        kind, value, _ = _resolve_color(_mix_base_socket(src), depth + 1)
        return kind, value, True
    if src.type in _COLOR_FILTERS and "Color" in src.inputs:
        return _resolve_color(src.inputs["Color"], depth + 1)
    if src.type == "GROUP":
        return _resolve_color(_color_socket(src), depth + 1)
    return "solid", _DEFAULT_COLOR, False


def _set_opaque(mat, opaque):
    """Force the material's blend mode; these files arrive uniformly HASHED."""
    for attr, value in (("blend_method", "OPAQUE" if opaque else "HASHED"),
                        ("surface_render_method", "DEFERRED" if opaque else "DITHERED")):
        if hasattr(mat, attr):
            try:
                setattr(mat, attr, value)
            except TypeError:
                pass  # enum not available in this Blender build


def rebuild_materials_for_gltf():
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        nt = mat.node_tree
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None or "Surface" not in out.inputs:
            continue

        shader, saw_transparent = _principal_shader(out)
        kind, value, via_mix = _resolve_color(_color_socket(shader))
        principled = nt.nodes.new("ShaderNodeBsdfPrincipled")
        wired_alpha = False

        if kind == "image":
            nt.links.new(value.outputs["Color"], principled.inputs["Base Color"])
            if not via_mix:
                try:
                    if value.image.depth in (32, 128) and "Alpha" in value.outputs:
                        nt.links.new(value.outputs["Alpha"], principled.inputs["Alpha"])
                        wired_alpha = True
                except (RuntimeError, ReferenceError):
                    pass  # image not loadable (missing file) -- base color is enough
        else:
            color = tuple(value)[:4]
            if len(color) == 3:
                color += (1.0,)
            principled.inputs["Base Color"].default_value = color

        # A material built purely from a Transparent BSDF (e.g. "Base_Transparent")
        # is deliberately invisible -- don't resurrect it as opaque grey.
        if shader is None and saw_transparent:
            principled.inputs["Alpha"].default_value = 0.0
            wired_alpha = True

        nt.links.new(principled.outputs["BSDF"], out.inputs["Surface"])
        _set_opaque(mat, not wired_alpha)
        print(f"MAT {mat.name}: shader={shader.type if shader else None} "
              f"color={'texture:' + value.image.name if kind == 'image' else kind} "
              f"decal_mix={via_mix} alpha={'wired' if wired_alpha else 'opaque'}")


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
    target = None
    keep = set(bpy.data.objects)
    use_selection = False

# --- These packs ship zero character Actions (only a `CameraAxisAction` camera-orbit
# helper), so there is nothing for `export_animations` to emit unless we author clips
# first. --anims builds a walk loop + idle sway on the rig in-script; see
# tools/author_anims.py for why it drives the IK hoof targets rather than the DEF_ or
# FK_ bones, and why authoring beats hand-posing a .blend.
if args.anims:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import author_anims

    armature = next((o for o in ([target] if target else []) + sorted(keep, key=lambda o: o.name)
                     if o is not None and o.type == "ARMATURE"), None)
    author_anims.author(armature)

# --- Quirk: the rig faces -Y in Blender, which `export_yup` maps to +Z in glTF --
# the glTF "front" convention. Godot keeps glTF's axes but its Node3D.look_at() aims
# -Z at the target, so an unrotated pony walks backwards down her own path. Yawing
# the exported root 180 degrees bakes Godot's forward convention into the asset,
# which keeps consumer scenes free of per-model fudge rotations.
# Without --object there is no single root to yaw (a whole-scene export has no one
# "the model" object), so the flag is a no-op -- say so out loud rather than letting
# a caller believe the rotation was applied.
if args.rotate_z and target is None:
    print(f"WARNING: --rotate-z {args.rotate_z} ignored -- it needs --object to pick "
          f"a root to rotate; export is unrotated", file=sys.stderr)
if args.rotate_z and target is not None:
    target.rotation_mode = "XYZ"
    target.rotation_euler.z += args.rotate_z * 3.141592653589793 / 180.0

export_kwargs = dict(
    filepath=args.out,
    export_format="GLB",
    use_selection=use_selection,
    export_apply=True,           # apply modifiers except armatures
    export_animations=True,
    export_skins=True,
    export_yup=True,
)
# --- These two must stay gated on --anims. `export_bake_animation` means "force
# exporting animation on every object", so with it on an armature that has no Action
# still emits a full baked clip named after the object -- a 423-channel animation
# called "TS_Rig" that holds the rest pose and animates nothing. That silently broke
# the no-anims contract (a plain Task-4-style export used to yield animations=[]) and,
# worse, made `validate_gltf.py --require-anims` pass vacuously on a model with no
# real clips. Only ask for baking when we have actually authored something to bake.
if args.anims:
    export_kwargs.update(
        export_animation_mode="ACTIONS",  # one glTF animation per Action, named after it
        export_bake_animation=True,       # bake the IK solve into the DEF_ bone tracks
    )

bpy.ops.export_scene.gltf(**export_kwargs)
print(f"EXPORT_OK {args.out}")
