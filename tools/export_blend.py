"""Headless Blender: export a .blend (or one collection/object in it) to glTF.
Usage: blender -b file.blend -P tools/export_blend.py -- --out out.glb [--object Twilight]
                                                        [--anims] [--rotate-z 180]

Prop variant (Task 8): for a source FBX prop instead of an already-open .blend,
run with no .blend argument and pass --fbx-in:
  blender -b -P tools/export_blend.py -- --fbx-in prop.fbx --out prop.glb
This imports the FBX into the (empty) default scene before the rest of the
pipeline below runs unchanged -- material rebuild, pack_all, export.
"""
import argparse, json, os, struct, sys
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


# --- Quirk (hair defect, Task 10): the mane/tail mesh is skinned to a SECOND,
# viewport-DISABLED armature, and was silently exporting unskinned.
#
# Every CreatorOfPony pack ships two armatures: the character rig (`TS_Rig`) and a
# hair-physics rig (`TS_RigPhysics`, a child object of it) that carries duplicate,
# identically-named copies of the DEF_Mane*/DEF_Hair*/DEF_Tail* chains plus SPLINE_IK
# constraints driven by curve objects. The hair mesh (`TS_Hair`, and on Rainbow Dash
# also a separate `Tail`) binds its ARMATURE modifier to that physics rig, not to the
# character rig. The physics rig has `hide_viewport=True`, so it is absent from the
# evaluated depsgraph -- and `export_apply=True` exports *against the depsgraph*, so
# the exporter never saw it. The result passed every structural gate (`meshes=17
# skins=1 textured=True`) while the mane and tail exported with **no skin at all**,
# rigidly parented to the rig root: the body bobbed and the head nodded and the hair
# just sat there. That is the "hair bobbing out of sync with the pony" defect.
#
# Fix generically rather than per-character: for any mesh we intend to export whose
# armature is not the primary rig, rebind it onto the primary rig -- but only when
# every one of its vertex groups names a bone that actually exists there. Vertex
# groups bind by name, and the duplicated hair bones' rest matrices agree with the
# primary rig's to <5e-5 on all three packs (checked before relying on it), so the
# rebind is exact, not an approximation. If a vertex group has no counterpart, leave
# the mesh alone and say so loudly -- a half-rebound mesh would collapse to the origin.
#
# Deliberately NOT fixed by clearing `hide_viewport` on the physics rig: that would
# export a second skeleton with duplicate bone names (Godot would get two Skeleton3Ds
# for one character) and would also drag in every other hidden object in these packs
# (`Base_Wings`, `TS_MeshCageWings`, the `*Physics` curve helpers), changing the
# documented mesh counts.
def rebind_secondary_armatures(primary, meshes):
    """Point meshes skinned to a non-primary armature at `primary` instead."""
    rebound = []
    for obj in sorted(meshes, key=lambda o: o.name):
        if obj.type != "MESH":
            continue
        for mod in obj.modifiers:
            if mod.type != "ARMATURE" or mod.object is None or mod.object is primary:
                continue
            missing = [g.name for g in obj.vertex_groups if g.name not in primary.data.bones]
            if missing:
                print(f"WARNING: not rebinding {obj.name!r} from {mod.object.name!r} to "
                      f"{primary.name!r} -- vertex groups absent there: {missing}",
                      file=sys.stderr)
                continue
            secondary = mod.object
            mod.object = primary
            # Reparent to the primary rig while preserving world placement:
            # world = parent.matrix_world @ matrix_parent_inverse @ matrix_basis.
            world = obj.matrix_world.copy()
            obj.parent = primary
            obj.matrix_parent_inverse = primary.matrix_world.inverted()
            obj.matrix_basis = world
            rebound.append(obj.name)
            print(f"REBIND {obj.name} armature {secondary.name} -> {primary.name} "
                  f"(vertex_groups={len(obj.vertex_groups)})")
    return rebound


# --- Keeping mane/tail bones OUT of the baked clips.
#
# `export_bake_animation=True` means "sample every bone of the armature on every
# frame", which is what makes the IK hoof solve ship (see the note further down) --
# but it also emits a constant, rest-pose track for every cosmetic hair bone. Those
# constant tracks are not harmless: in Godot an AnimationPlayer track and a
# SkeletonModifier3D both write the same bone pose, so a rest-pose track on
# DEF_Mane1-3 overwrites the SpringBoneSimulator3D's output every single frame and
# the hair simulation appears to do nothing whatsoever.
#
# The exporter offers no per-bone animation filter (`export_def_bones` filters bones
# out of the *skeleton*, which would break skinning, and the optimizer's
# `export_optimize_animation_keep_anim_armature=False` only drops channels that
# happen to be constant -- an accident of the data, not a stated rule). So filter at
# the one place the exporter decides whether a bone gets a channel:
# `gather_sampled_bone_channel` already returns None for "no need to animate this
# node", and its caller already handles that, so returning None early is on a
# supported path rather than a structural hack. Which bones are excluded comes from
# author_anims.SECONDARY_MOTION_PATTERNS -- one name-pattern list, no per-character
# data. The post-export check below turns this into a hard contract: if a future
# Blender version renames the hook, the import fails loudly here, and if a channel
# ever slips through anyway the export fails after writing.
def exclude_secondary_motion_from_bake(is_excluded):
    """Patch the glTF exporter to emit no animation channel for excluded bones."""
    try:
        from io_scene_gltf2.blender.exp.animation.sampled.armature import armature_channels
    except ImportError as exc:  # pragma: no cover - version guard
        raise SystemExit(
            "cannot install the secondary-motion animation filter: the glTF exporter's "
            f"armature_channels module moved in this Blender build ({exc}). Without it "
            "the mane/tail bones would ship rest-pose tracks that override Godot's "
            "SpringBoneSimulator3D -- see docs/pipeline.md section 6."
        )
    original = armature_channels.gather_sampled_bone_channel
    filtered_bones = set()

    def gather_sampled_bone_channel(armature_uuid, bone, channel, *rest, **kwargs):
        if is_excluded(bone):
            filtered_bones.add(bone)
            return None
        return original(armature_uuid, bone, channel, *rest, **kwargs)

    armature_channels.gather_sampled_bone_channel = gather_sampled_bone_channel
    return filtered_bones


def gltf_json(path):
    """The JSON chunk of a .glb, as a dict."""
    with open(path, "rb") as fh:
        blob = fh.read()
    offset = 12  # magic, version, length
    while offset < len(blob):
        length, kind = struct.unpack_from("<II", blob, offset)
        offset += 8
        if kind == 0x4E4F534A:  # 'JSON'
            return json.loads(blob[offset:offset + length])
        offset += length
    raise SystemExit(f"{path}: no JSON chunk")


def assert_no_secondary_motion_tracks(path, is_excluded):
    """Fail the export if any clip keyframes a bone Godot is meant to simulate."""
    doc = gltf_json(path)
    names = [n.get("name", "") for n in doc.get("nodes", [])]
    leaked = sorted({names[c["target"]["node"]]
                     for anim in doc.get("animations", [])
                     for c in anim["channels"]
                     if "node" in c["target"] and is_excluded(names[c["target"]["node"]])})
    if leaked:
        raise SystemExit(
            f"{path}: {len(leaked)} secondary-motion bones still carry animation "
            f"tracks {leaked[:8]}... -- they would override Godot's spring bones"
        )
    animated = {c["target"]["node"] for anim in doc.get("animations", [])
                for c in anim["channels"] if "node" in c["target"]}
    print(f"SECONDARY_MOTION_UNKEYED animated_nodes={len(animated)} "
          f"clips={[a.get('name') for a in doc.get('animations', [])]}")


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
    # Rebind the hair mesh off the hidden physics rig before anything selects or
    # exports it -- see rebind_secondary_armatures() for why it would otherwise
    # export unskinned. `keep` is already computed, so the reparent it performs
    # cannot change what gets exported, only what the hair is bound to.
    if target.type == "ARMATURE":
        rebind_secondary_armatures(target, keep)
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
    filtered_bones = exclude_secondary_motion_from_bake(author_anims.is_secondary_motion_bone)

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
if args.anims:
    print(f"SECONDARY_MOTION_FILTERED {len(filtered_bones)} bones: "
          f"{sorted(filtered_bones)}")
    assert_no_secondary_motion_tracks(args.out, author_anims.is_secondary_motion_bone)
print(f"EXPORT_OK {args.out}")
