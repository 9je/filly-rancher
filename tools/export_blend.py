"""Headless Blender: export a .blend (or one collection/object in it) to glTF.
Usage: blender -b file.blend -P tools/export_blend.py -- --out out.glb [--object Twilight]
                                                        [--anims] [--rotate-z 180]
                                                        [--scale 0.5]

Prop variant (Task 8): for a source FBX prop instead of an already-open .blend,
run with no .blend argument and pass --fbx-in:
  blender -b -P tools/export_blend.py -- --fbx-in prop.fbx --out prop.glb
This imports the FBX into the (empty) default scene before the rest of the
pipeline below runs unchanged -- material rebuild, pack_all, export.
"""
import argparse, json, os, struct, sys
import bpy
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--object", default=None, help="only export this object + its armature/children")
p.add_argument("--anims", action="store_true",
               help="author 'idle' + 'walk' Actions onto the rig before exporting "
                    "(see tools/author_anims.py); the packs ship none of their own")
p.add_argument("--rotate-z", type=float, default=0.0, metavar="DEG",
               help="yaw the exported root this many degrees about +Z before export")
p.add_argument("--scale", type=float, default=1.0, metavar="FACTOR",
               help="uniformly rescale everything being exported by FACTOR, baked into "
                    "the geometry and the rig (not left on a root node). The project "
                    "convention is 1 unit = 1 metre and the tier-a pony packs are "
                    "authored ~2x that, so characters export with --scale 0.5 -- see "
                    "docs/pipeline.md section 3. 1.0 (the default) touches nothing")
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


# --- Normalizing model scale (Task 1, Phase 1A): 1 Godot unit = 1 metre.
#
# The CreatorOfPony packs are authored at roughly 2x life size (Twilight's withers --
# the top of her back above the shoulder joint, the conventional way to state a horse's
# height -- measure 2.337 units against a hoof plane at 0.010, and a show pony is ~1.2 m
# there). Rather than build every map and physics constant around that, the factor is
# baked into the asset at export time, once, by this function.
#
# WHY NOT `obj.scale = k` AND LEAVE IT ON THE ROOT. Two reasons. The glTF exporter would
# emit a root node with a non-unit scale, so the .glb's *internal* units would still be
# the pack's -- every bone rest, every animation translation, every value a consumer
# reads out of Skeleton3D would be in 2x units while the world around it is metric, and
# anything later parented under that root (a collision shape, a saddle, a particle
# emitter) would silently inherit the scale. And `bpy.ops.object.transform_apply` is not
# the fix either: applying a scale to a parent leaves its children at their original
# size (Blender rewrites their parent inverse to compensate), which would put a
# full-size mesh on a half-size skeleton.
#
# So bake the similarity directly. Every mesh/armature/curve datablock is scaled about
# its own origin, and every object's placement inside the hierarchy is conjugated by the
# same scale -- which, for a uniform factor, leaves rotations untouched and multiplies
# translations by the factor, so the product down any parent chain comes out at exactly
# FACTOR x the original world position.
#
# THE PARTS THAT DO NOT FOLLOW THE GEOMETRY. A handful of constraint and modifier
# settings are lengths in the rig's own units and are stored, not derived, so scaling
# the geometry alone leaves them behind:
#   * CHILD_OF `inverse_matrix` (bone-level on DEF_Neck1/DEF_Neck2/DEF_Head, which is
#     how this rig stabilises the head against body motion -- its translation is 5.17
#     units on Twilight, so leaving it unscaled tears the head off the neck in the bake);
#   * STRETCH_TO `rest_length` (DEF_Tongue1/2 deform the tongue; the VIS_*Knee helpers
#     do not export but are scaled anyway for consistency);
#   * SHRINKWRAP `offset` (0.0015-0.002, holding the iris and eye highlights off the
#     eyeball surface) and MIRROR `merge_threshold`.
# The IK constraints' `distance` is deliberately NOT in that list: all four are
# `ik_type='COPY_POSE'`, where the field is unused.
#
# That list covers what these packs actually use, and it is a list, so it can be
# incomplete for a future pack. `_extent()` below is the backstop for the geometry and
# the hierarchy: the exported selection's bounding box is measured before and after, and
# a box that did not scale by exactly the requested factor is a hard failure rather than
# a subtly wrong asset. It reads base mesh data, so it deliberately does NOT claim to
# cover the constraint/modifier list above -- that was checked the only way it can be,
# end to end: exporting Twilight at 1.0 and at 0.5 and decoding both, every baked
# animation translation in the scaled file is the unscaled one halved to within 3.5e-6
# and every rotation is unchanged to within 2.0e-5 of a quaternion component. Re-run
# that comparison if this list ever has to grow.
_SCALED_CONSTRAINT_ATTRS = ("rest_length",)
_SCALED_MODIFIER_ATTRS = {"SHRINKWRAP": ("offset",), "MIRROR": ("merge_threshold",),
                          "SOLIDIFY": ("thickness",)}


def _extent(objects):
    """World-space bounding box of every mesh in `objects`, as (min, max) tuples."""
    bpy.context.view_layer.update()
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for obj in objects:
        if obj.type != "MESH":
            continue
        matrix = obj.matrix_world
        for vert in obj.data.vertices:
            world = matrix @ vert.co
            for axis in range(3):
                lo[axis] = min(lo[axis], world[axis])
                hi[axis] = max(hi[axis], world[axis])
    return tuple(lo), tuple(hi)


def apply_uniform_scale(objects, factor):
    """Bake a uniform scale of `factor` into `objects`' data, placement and rig."""
    before_lo, before_hi = _extent(objects)
    matrix = Matrix.Scale(factor, 4)
    scaled_data = set()
    for obj in sorted(objects, key=lambda o: o.name):
        data = obj.data
        key = None if data is None else data.as_pointer()
        if key is not None and key not in scaled_data and hasattr(data, "transform"):
            try:
                data.transform(matrix, shape_keys=True)
            except TypeError:
                data.transform(matrix)   # armatures/curves take no shape_keys argument
            scaled_data.add(key)
        for attr in ("matrix_basis", "matrix_parent_inverse"):
            placement = getattr(obj, attr).copy()
            placement.translation *= factor
            setattr(obj, attr, placement)
        holders = [obj]
        if obj.type == "ARMATURE":
            holders += list(obj.pose.bones)
        for holder in holders:
            for con in holder.constraints:
                if hasattr(con, "inverse_matrix"):
                    inverse = con.inverse_matrix.copy()
                    inverse.translation *= factor
                    con.inverse_matrix = inverse
                for attr in _SCALED_CONSTRAINT_ATTRS:
                    if hasattr(con, attr):
                        setattr(con, attr, getattr(con, attr) * factor)
        for mod in obj.modifiers:
            for attr in _SCALED_MODIFIER_ATTRS.get(mod.type, ()):
                if hasattr(mod, attr):
                    setattr(mod, attr, getattr(mod, attr) * factor)

    after_lo, after_hi = _extent(objects)
    size_before = [hi - lo for lo, hi in zip(before_lo, before_hi)]
    size_after = [hi - lo for lo, hi in zip(after_lo, after_hi)]
    for axis, (was, now) in enumerate(zip(size_before, size_after)):
        if was > 1e-6 and abs(now / was - factor) > 1e-4:
            raise SystemExit(
                f"--scale {factor}: axis {axis} of the exported selection scaled by "
                f"{now / was:.6f}, not {factor} -- something in this .blend holds a "
                f"length that did not follow the geometry (see _SCALED_CONSTRAINT_ATTRS "
                f"/ _SCALED_MODIFIER_ATTRS in tools/export_blend.py)"
            )
    print(f"SCALED factor={factor} datablocks={len(scaled_data)} "
          f"objects={len(objects)} size={tuple(round(v, 4) for v in size_after)} "
          f"(was {tuple(round(v, 4) for v in size_before)})")


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

# Rescale BEFORE authoring clips, never after: --anims solves IK against whatever the
# rig measures at that moment and bakes the result, and author_anims.py's length
# constants (STRIDE, LIFT, BODY_BOB, ...) are metres. Rescaling afterwards would leave
# the clip depicting a stride the model no longer has. Also before --rotate-z, though
# that one is only for tidiness: a uniform scale and a rotation commute.
if args.scale != 1.0:
    apply_uniform_scale(keep, args.scale)

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
