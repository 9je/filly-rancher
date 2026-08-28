"""Make a ReVAmped-SFM pony rig present the tier-a rig's ANIMATION INTERFACE.

Imported by `tools/export_blend.py --mdl-in`; see docs/pipeline.md section 5b.

WHAT PROBLEM THIS SOLVES. `tools/author_anims.py` authors `idle`/`walk`/`gallop`
against six handles -- `CON_Root`, `CON_Belly`, `DEF_Head` and the four `IK_*Hoof.*`
world-space foot targets -- and solves the legs with Blender IK against whatever
geometry the rig actually has. Those handles are the ONLY thing it needs; the rest of
the tier-a skeleton is irrelevant to it. The SFM ponies share zero bone names with
tier a (`Pelvis`/`Chest1`/`Head`/`LeftShoulder`... against `DEF_Chest1`/`DEF_Head`...)
and, more importantly, ship no IK layer at all: a Source `.mdl` skeleton is 74 plain
FK transforms. So this module BUILDS that interface on top of the imported rig --
a root, a belly control the whole body hangs off, a head alias, and four IK hoof
targets with real IK chains behind them -- and then `author_anims.author()` runs
completely unchanged and solves the same gait against the SFM pony's own legs.

WHY NOT TRANSFER THE TIER-A CLIPS (the "retargeting" answer). Measured, not assumed
(docs/pipeline.md section 5b carries the table): the two skeletons are the same
TOPOLOGY -- quadruped, four legs, three segments each -- but not the same PROPORTIONS.
Tier a's front leg splits 0.229 m / 0.305 m between its two IK-chain bones; the SFM
pony's splits 0.114 / 0.198 / 0.074 across three, i.e. its "hand" is a pastern where
tier a's lower leg is a cannon. Copying tier a's baked per-bone ROTATIONS onto those
bones puts the hoof somewhere else, and specifically it changes how far a planted hoof
travels per stride -- which is the one number `game/systems/gait.gd` matches to stop
the pony skating. Authoring against the target rig's own geometry keeps `STRIDE` at
the metre it claims to be, for free, on every rig family.

WHAT IS AND IS NOT PER CHARACTER. Nothing here is. Verified across six models
(Pinkie Pie, Rarity, Maud Pie, Derpy Hooves, Applebloom, Shining Armor): the pack
shares a 70-bone core skeleton whose body and leg bones sit at IDENTICAL rest
positions to four decimal places on every character -- `Chest2` at z=0.4676,
`LeftShoulder` at z=0.4314, front leg span 0.3650, rear 0.4161, on all six, filly and
stallion alike. Only hair/tail/wing/accessory chains and the head mesh differ. That is
the same "one core rig, cosmetic chains diverge" story tier a has, so one authored
clip set covers the whole pack.
"""
import math

import bpy
from mathutils import Vector

# --- The interface author_anims.py expects. These names are deliberately the tier-a
# ones: the point is that author_anims sees the same handles whatever family the rig
# came from, so there is no second copy of the gait code and no per-family branch in it.
ROOT = "CON_Root"
BELLY = "CON_Belly"
HEAD_ALIAS = "DEF_Head"

# --- The SFM side of the mapping. (canonical IK target, chain end bone, bones in the
# IK chain from the end bone upwards). The chain lengths are NOT the same as tier a's
# and that is the whole point -- see the module docstring.
#
# FRONT: the chain has to include `*Shoulder` (the scapula). Excluding it -- which is
# what tier a does, its `DEF_Shoulder` sits outside the IK chain -- leaves a two-segment
# chain from `*Forearm` measuring 0.337 against a rest reach of 0.337, i.e. exactly
# 100.0% extended and singular, so the solver has no bend direction at all. With the
# shoulder in, the chain is 0.451 against 0.4366, 96.8% extended, which is the same
# comfortable-but-tight band tier a's front leg sits in (98.8%).
#
# REAR: `*Thigh` is deliberately left OUT, matching tier a, so the haunch stays put and
# only the hock articulates. 0.394 of chain against 0.375 of reach, 95.2%.
LEGS = [
    ("IK_FrontHoof.L", "IK_FrontEnd.L", "LeftHand",
     ["LeftHand", "LeftForearm", "LeftShoulder"]),
    ("IK_FrontHoof.R", "IK_FrontEnd.R", "RightHand",
     ["RightHand", "RightForearm", "RightShoulder"]),
    ("IK_RearHoof.L", "IK_RearEnd.L", "LeftFoot",
     ["LeftFoot", "LeftLeg2", "LeftLeg1"]),
    ("IK_RearHoof.R", "IK_RearEnd.R", "RightFoot",
     ["RightFoot", "RightLeg2", "RightLeg1"]),
]

## The bone the whole body hangs off, which BELLY is spliced above.
BODY_ROOT = "Pelvis"
## The real head bone HEAD_ALIAS drives.
HEAD_BONE = "Head"
## The neck HEAD_ALIAS is parented to, so it inherits exactly what the real head does.
HEAD_PARENT = "Neck"

## Every bone this module needs to find. Checked up front so a model outside the
## ReVAmped family fails by name here rather than by producing a pony that stands still.
REQUIRED = sorted({BODY_ROOT, HEAD_BONE, HEAD_PARENT}
                  | {b for _t, _e, _p, chain in LEGS for b in chain}
                  | {parent for _t, _e, parent, _c in LEGS})

# --- Bodygroup pruning.
#
# A single Source `.mdl` imports EVERY bodygroup variant as a separate mesh object, so a
# raw import is a pony wearing three pairs of ears and three sets of hooves stacked
# inside each other. Which one a game would show is a bodygroup index the .mdl carries
# and SourceIO does not apply, so the choice has to be made here.
#
# Expressed as (path fragment identifying the group, substring of the variant to KEEP).
# The fragment has NO leading slash on purpose: the pack files its bodyparts under
# `bodyparts/<x>/<group>/` but its manes, tails and accessories at the TOP level
# (`manes/mane_pinkie.dmx`), so a leading-slash fragment silently matched nothing for
# exactly the three groups that most needed a rule.
# Pattern-driven and not a per-character table: every model in the pack lays its
# bodyparts out under the same `bodyparts/<x>/<group>/` tree, so these three rules cover
# all 47 of them, and a model that simply has no wings just skips that rule.
#
# A `None` preference means "no variant is the obvious default, take the first
# alphabetically" -- which is deterministic, and for the mane/tail groups lands on the
# `*_1` / plain-named style rather than an alternate-universe one (Starlight Glimmer
# ships four manes: `mane_Glimmer_1`, `mane_Glimmer_2`, `mane_Glimmer_EQG` and a
# `Glimmer_Beanie`, and without a rule here all four export stacked inside each other).
# An empty preference (`""` handled below as "keep nothing") drops the group entirely.
BODYGROUPS = [
    ("ears/", "ears_normal"),        # vs pony_ears_bat, pony_ears_movie
    ("hooves/", "hooves_regular"),   # vs hooves_kirin, hooves_messy
    ("wings/", "_closed"),           # vs *_spread -- a walking pony has folded wings
    ("manes/", "mane"),              # vs a beanie/hat filed under manes/
    ("tails/", "tail"),
    # The eye "lens" is a Source refraction overlay: a shell over the eyeball whose
    # material is a bare grey Principled with no texture and no wired alpha, because the
    # effect lives entirely in the shader. glTF cannot carry that, so exporting it puts
    # an opaque grey disc over each eye. Dropped -- the eyeball underneath is a real
    # textured surface and reads correctly on its own.
    ("eyelenses/", ""),
    # Accessories are Source bodygroups whose default index is the blank one -- a hat, a
    # helmet, a bow. Dropped so a character ships her own silhouette rather than whatever
    # props the pack's author happened to model; Maud Pie would otherwise arrive in her
    # rock-farm helmet. This is the one BODYGROUPS entry that is a judgement call rather
    # than a default: flip it to `None` to keep them all if a future roster wants props.
    ("accessories/", ""),
]


## The roughness every Source material is flattened to. 0.5 is not a taste call: it is
## what the tier-a packs already export (every material in twilight.glb ships
## `roughnessFactor 0.5`), so the two rig families light identically and a mixed herd
## reads as one herd. See flatten_source_materials for why the pack's own exponent maps
## cannot supply this number.
ROUGHNESS_FLAT = 0.5


def flatten_source_materials(rebuild_fallback):
    """Make SourceIO's materials survive the trip through glTF. Returns a summary.

    THE DEFECT THIS FIXES, WHICH EVERY STRUCTURAL GATE WAS GREEN THROUGH. SourceIO's
    `vertexlitgeneric` graph wires the Source `$phongexponenttexture` -- a specular
    exponent map -- into the Principled BSDF's **Metallic** input. Source has no
    metalness channel at all; that texture's red channel is a gloss exponent and its
    other channels are rim/albedo-tint masks. Exported to glTF and lit in Godot, a
    metallic-1.0 surface has no diffuse response, so the pony renders as a BLACK MIRROR:
    a glossy black silhouette with coloured specular streaks, ears and mane and hooves
    all the same void. `validate_gltf.py` said `materials=10 textured=True`, the model
    loaded, the skeleton was right and the walk played -- exactly the class of bug
    docs/pipeline.md section 7 exists to warn about, caught the first time a frame was
    rendered.

    THE SECOND HALF OF THE SAME DEFECT, WHICH THE FIRST PASS AT THIS TALKED ITSELF OUT
    OF. This used to unwire Metallic and leave Roughness alone, reasoning that
    "inverting the phong exponent into roughness is a defensible reading of the same
    texture, and it is what makes a hoof read as harder than a coat". Both halves of
    that are false in this pipeline, and a render showed it: Pinkie Pie's coat came out
    near-white with a wet plastic sheen on every character in the pack.

      * NOTHING INVERTS ANYTHING. The exponent map goes into Roughness as an image, and
        glTF's metallicRoughness texture is a fixed channel packing -- GREEN is
        roughness. So the number Godot lights the pony with is the exponent map's GREEN
        channel, which in Source is the albedo-tint mask (RED is the exponent). On this
        pack that channel is 15/255 everywhere, i.e. roughness 0.06: a mirror. Measured
        on the shipped `common/body_exponent` and `common/phongexponenttexture`:
        min 15, max 89, mean 15.2, identical on all three converted characters.
      * THERE IS NO HOOF/COAT DISTINCTION TO LOSE. Same measurement -- the map is a
        constant to within a handful of pixels, and every material in the pack points at
        one of those two shared `common/` maps anyway.

    A near-mirror surface adds a broad white specular lobe on top of the albedo, which
    is invisible on a saturated mane and ruinous on a pale coat: Pinkie's body texture is
    (237, 181, 203) and rendered at (233, 198, 221) -- green and blue lifted ~18 counts
    each and red pulled down, i.e. albedo plus white.

    Source's own answer to this is `$phongfresnelranges`/`$phongboost`, which confine
    that lobe to grazing angles; glTF carries no equivalent, and Godot ignores the
    `KHR_materials_specular` factor the exporter does write. So there is no reading of
    the exponent map that survives the trip, and the honest thing is to drop it and pick
    a roughness -- ROUGHNESS_FLAT, the same 0.5 the tier-a ponies already ship, so a
    Source pony and a Blender pony standing in the same field are lit alike.

    So: unwire Metallic AND Roughness, keep the normal map, and force OPAQUE on anything
    whose alpha is not genuinely wired, which is the same rule the tier-a rebuild applies
    and for the same reason: SourceIO hands every material over as HASHED and the
    exporter turns that into a blended alphaMode on geometry that is meant to be solid.

    Materials whose Material Output is NOT fed by a Principled are SourceIO's procedural
    eye shaders (`ADD_SHADER`/`MIX_SHADER` stacks doing parallax iris refraction from
    `!EYE_LOC` attributes). glTF has no way to express those, so they are handed to
    `rebuild_fallback` -- export_blend.py's own resolver -- which walks the shader mixers
    and pulls out the iris texture as a flat base colour. A flat iris is a real fidelity
    loss and is recorded as such in docs/pipeline.md section 5b.
    """
    repaired, rewired, delegated = [], [], []
    for mat in bpy.data.materials:
        node_tree = mat.node_tree
        if not mat.use_nodes or node_tree is None:
            continue
        out = next((n for n in node_tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None or not out.inputs["Surface"].links:
            continue
        shader = out.inputs["Surface"].links[0].from_node
        base_texture = _source_basetexture(node_tree)
        if shader.type != "BSDF_PRINCIPLED":
            if base_texture is None:
                rebuild_fallback(mat)
                delegated.append(mat.name)
                continue
            shader = node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            node_tree.links.new(shader.outputs["BSDF"], out.inputs["Surface"])
            rewired.append(mat.name)
        base_color = shader.inputs["Base Color"]
        if base_texture is not None and not (
                base_color.links and base_color.links[0].from_node.type == "TEX_IMAGE"):
            # Source blends `$basetexture` with `$color2`/detail maps through a Mix, and
            # glTF has no way to carry a mix: the exporter drops the texture entirely and
            # ships a flat baseColorFactor, which is how the hooves and eyebrows came out
            # untextured. `$basetexture` IS the base colour by the Source shader system's
            # own definition, so wire it straight in.
            for link in list(base_color.links):
                node_tree.links.remove(link)
            node_tree.links.new(base_texture.outputs["Color"], base_color)
            if mat.name not in rewired:
                rewired.append(mat.name)
        for socket_name, value in (("Metallic", 0.0), ("Roughness", ROUGHNESS_FLAT)):
            socket = shader.inputs[socket_name]
            for link in list(socket.links):
                node_tree.links.remove(link)
            socket.default_value = value
        if not shader.inputs["Alpha"].links:
            for attr, value in (("blend_method", "OPAQUE"),
                                ("surface_render_method", "DEFERRED")):
                if hasattr(mat, attr):
                    try:
                        setattr(mat, attr, value)
                    except TypeError:
                        pass    # enum not available in this Blender build
        repaired.append(mat.name)
    print(f"SOURCE_MATERIALS repaired={len(repaired)} {sorted(repaired)} "
          f"rewired={len(rewired)} {sorted(rewired)} "
          f"delegated={len(delegated)} {sorted(delegated)}")
    return repaired, rewired, delegated


## Source material parameters that can carry a surface's colour, best first. `$iris`
## only ever appears in an eye material, where it is the coloured part and
## `$basetexture` is the blank sclera -- taking the sclera there gives a pony with two
## plain white eyes, which is what the first render of this actually produced.
_COLOUR_PARAMS = ("$iris", "$basetexture")


def _source_basetexture(node_tree):
    """The image node carrying a SourceIO material's surface colour, or None.

    SourceIO labels every node it creates with the Source material parameter it came
    from, so this is a name lookup and not a guess. Case-insensitive because the pack's
    own VMTs spell it both `$basetexture` and `$Basetexture` and SourceIO passes the
    spelling through.
    """
    for param in _COLOUR_PARAMS:
        for node in node_tree.nodes:
            if (node.type == "TEX_IMAGE" and node.image is not None
                    and node.name.lower().startswith(param)):
                return node
    return None


## How far a bone may move when the animation interface is spliced in and nothing is
## keyed. Zero would be defensible -- all three shipped characters currently measure
## 0.000000 m / 0.0000 deg -- but the four IK chains re-solve every frame and a
## numerical solver is entitled to land NEAR its own starting pose rather than exactly
## on it, so the gate is set at a millimetre and a quarter degree: far below anything a
## person could see in a frame, far above float noise.
REST_TOLERANCE_M = 1.0e-3
REST_TOLERANCE_DEG = 0.25


def check_rest_pose_preserved(arm):
    """Fail if `adapt()` moved the model. Returns ((bone, metres), (bone, degrees)).

    THE DEFECT THIS EXISTS FOR. Building the interface must be invisible: with no
    Action assigned, a pony that has been through `adapt()` has to stand in exactly the
    pose the .mdl shipped. The first version of this module did not, and nothing caught
    it -- `new_bone()` zeroes `roll`, and the `DEF_Head` alias is the one new bone that
    is a TWIN of an existing one, so zeroing its roll left it 89.999 deg about its own
    Y axis away from the `Head` bone it drives. `COPY_TRANSFORMS` (world space) then
    imposed that 90 deg on the head on every frame of every clip, and the exported pony
    galloped with her head cranked over her shoulder. Every structural gate was green:
    the bone count was right, the clips existed, the hooves planted. Only a rendered
    frame showed it, and only because someone looked.

    So the invariant is asserted here, in the units a person judges it in, rather than
    left for a render to catch: every bone that existed before `adapt()` must still
    evaluate to its own rest matrix afterwards.
    """
    bpy.context.view_layer.update()
    evaluated = arm.evaluated_get(bpy.context.evaluated_depsgraph_get())
    # The two maxima are tracked INDEPENDENTLY, not as one "worst bone". A pure
    # rotation about a bone's own head -- which is exactly the defect this was written
    # for -- displaces that bone by nothing at all, so any single ranking that sorts on
    # distance first would let a 90 deg twist hide behind a bone that had drifted a
    # tenth of a millimetre.
    moved_worst = ("<none>", 0.0)
    turned_worst = ("<none>", 0.0)
    for bone in arm.data.bones:
        pose_bone = evaluated.pose.bones.get(bone.name)
        if pose_bone is None:
            continue
        delta = bone.matrix_local.inverted() @ pose_bone.matrix
        moved = delta.to_translation().length
        turned = math.degrees(delta.to_quaternion().angle)
        if moved > moved_worst[1]:
            moved_worst = (bone.name, moved)
        if turned > turned_worst[1]:
            turned_worst = (bone.name, turned)
    print(f"SFM_RIG_REST_DRIFT moved={moved_worst[1]:.6f}m ({moved_worst[0]}) "
          f"turned={turned_worst[1]:.4f}deg ({turned_worst[0]})")
    if moved_worst[1] > REST_TOLERANCE_M or turned_worst[1] > REST_TOLERANCE_DEG:
        raise SystemExit(
            f"sfm_rig.adapt() moved the rig off its own rest pose: "
            f"{moved_worst[0]!r} is {moved_worst[1]:.6f} m from where the .mdl put it "
            f"and {turned_worst[0]!r} is {turned_worst[1]:.4f} deg off "
            f"(limits {REST_TOLERANCE_M} m / {REST_TOLERANCE_DEG} deg). The interface "
            f"must be invisible until a clip drives it -- see "
            f"sfm_rig.check_rest_pose_preserved.")
    return moved_worst, turned_worst


def _armature(objects=None):
    arms = [o for o in (objects or bpy.data.objects) if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit(f"expected exactly one armature after the .mdl import, got "
                         f"{sorted(o.name for o in arms)}")
    return arms[0]


def prune_bodygroups():
    """Delete the bodygroup variants a game would not show. Returns the kept names."""
    for fragment, keep_token in BODYGROUPS:
        group = sorted((o for o in bpy.data.objects
                        if o.type == "MESH" and fragment in o.name.lower()),
                       key=lambda o: o.name.lower())
        if not group:
            continue
        if keep_token == "":
            keep = []
        elif keep_token is None:
            keep = group[:1]
        else:
            # Tested against the FILE NAME, not the whole path: the group fragment is
            # itself a directory name, so `"mane" in "manes/Glimmer_Beanie.dmx"` is true
            # and the beanie won the mane group on the first run of this.
            keep = [o for o in group
                    if keep_token in o.name.lower().rsplit("/", 1)[-1]]
            if not keep:
                # Never silently drop a whole body part: keep the first alphabetically
                # and say so, so a pack that renamed its variants loses a choice, not a
                # leg.
                keep = group[:1]
                print(f"WARNING: no {fragment} variant matching {keep_token!r}; keeping "
                      f"{keep[0].name!r} of {[o.name for o in group]}", flush=True)
            elif len(keep) > 1 and fragment in ("manes/", "tails/"):
                # Several styles all legitimately named `mane_*`; the group has no
                # "default" marker, so take the first alphabetically -- deterministic,
                # and on this pack it lands on the plain/`_1` style.
                keep = keep[:1]
        for obj in group:
            if obj not in keep:
                bpy.data.objects.remove(obj, do_unlink=True)
        print(f"BODYGROUP {fragment} kept {[o.name for o in keep]}")
    return sorted(o.name for o in bpy.data.objects if o.type == "MESH")


def prune_dead_hair_bones(arm):
    """Delete hair bones no surviving mesh weights to. Returns the deleted names.

    Bones are NOT per bodygroup in a Source `.mdl` -- one skeleton carries the chains
    for every mane and tail variant the model ships -- so after `prune_bodygroups()`
    has chosen one hairstyle, the chains belonging to the others are still there,
    weighted by nothing. Left alone they are invisible but not harmless: `PonyRig`
    discovers hair chains by BONE NAME, so it would build and simulate spring chains for
    a hairdo that is not in the file. Starlight Glimmer is the case in point -- her
    alternate `mane_Glimmer_EQG` style brings fourteen `DEF_HairBack*`/`DEF_HairStray*`
    bones that the mane she actually ships never touches.

    Only prunes a bone whose whole subtree is also dead, so this can never orphan a live
    chain, and only ever touches bones the secondary-motion patterns already claim.
    """
    import author_anims

    live = set()
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if not any(m.type == "ARMATURE" and m.object is arm for m in obj.modifiers):
            continue
        names = [g.name for g in obj.vertex_groups]
        for vert in obj.data.vertices:
            for g in vert.groups:
                if g.weight > 0.0:
                    live.add(names[g.group])

    def subtree_dead(bone):
        return (author_anims.is_secondary_motion_bone(bone.name)
                and bone.name not in live
                and all(subtree_dead(c) for c in bone.children))

    dead = sorted(b.name for b in arm.data.bones if subtree_dead(b))
    if dead:
        if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        arm.hide_viewport = False
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for name in dead:
            arm.data.edit_bones.remove(arm.data.edit_bones[name])
        bpy.ops.object.mode_set(mode="OBJECT")
    print(f"SFM_RIG_DEAD_HAIR_BONES {len(dead)} removed: {dead}")
    return dead


def _ground_z(arm):
    """Lowest vertex of everything skinned to `arm` -- the plane the hooves stand on."""
    zs = [(obj.matrix_world @ v.co).z
          for obj in bpy.data.objects if obj.type == "MESH"
          for v in obj.data.vertices]
    if not zs:
        raise SystemExit("no meshes imported; cannot locate the hoof plane")
    return min(zs)


def adapt(arm=None):
    """Build the canonical animation interface on an imported ReVAmped SFM rig.

    Idempotent-ish only in the sense that it refuses to run twice: a second call would
    splice a second belly above the first. Returns the armature object.
    """
    arm = arm or _armature()
    if arm.matrix_world != arm.matrix_world.Identity(4):
        raise SystemExit(f"armature {arm.name!r} is not at the world origin; every "
                         f"coordinate below is armature-local and assumes it is")
    missing = [b for b in REQUIRED if b not in arm.data.bones]
    if missing:
        raise SystemExit(
            f"{arm.name!r} is not a ReVAmped-family SFM pony rig: missing bones "
            f"{missing}. See tools/sfm_rig.py's LEGS/BODY_ROOT mapping.")
    if ROOT in arm.data.bones:
        raise SystemExit(f"{arm.name!r} already carries {ROOT!r}; adapt() must run once")

    prune_dead_hair_bones(arm)
    ground = _ground_z(arm)
    # Rest positions are read BEFORE edit mode opens: entering edit mode invalidates
    # `data.bones`, and reading heads out of edit_bones mid-edit while reparenting is a
    # good way to read a value something else has already moved.
    rest = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}

    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    arm.hide_viewport = False
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones

    def new_bone(name, head, tail, parent, roll=0.0):
        # ROLL IS A PARAMETER AND NOT A CONSTANT 0. A Blender bone's orientation is
        # (head, tail, roll), and roll is the whole third of it: two bones sharing a
        # head and a tail can still be a quarter turn apart about their own axis. It
        # does not matter for the bones here that are nobody's twin -- CON_Root,
        # CON_Belly, the IK end-effectors and the IK targets are all read for their
        # POSITION -- but DEF_Head is a twin of `Head` by construction, and zeroing its
        # roll is what put an SFM pony's head 90 deg over her shoulder in every clip.
        # See check_rest_pose_preserved.
        bone = eb.new(name)
        bone.head = head
        bone.tail = tail
        bone.roll = roll
        bone.parent = parent
        bone.use_connect = False
        bone.use_deform = False   # nothing weights to a control bone
        return bone

    # CON_Root: a world-space anchor at the origin that nothing ever animates. The four
    # hoof targets hang off it, which is what makes them genuine WORLD-space foot
    # targets -- move the belly and the body travels while the hooves stay planted.
    # One metre long along +Y purely so it is visible in a viewport; nothing reads it.
    root = new_bone(ROOT, Vector((0.0, 0.0, ground)), Vector((0.0, 1.0, ground)), None)

    # CON_Belly: spliced between CON_Root and the pelvis, so translating it moves the
    # entire body -- barrel, neck, head, and the tops of all four legs -- exactly as
    # tier a's CON_Belly does. Points +Z; author_anims converts its intended
    # armature-space offsets through the bone's own rest axes either way.
    pelvis_head, _pelvis_tail = rest[BODY_ROOT]
    belly = new_bone(BELLY, pelvis_head.copy(),
                     pelvis_head + Vector((0.0, 0.0, 0.15)), root)
    eb[BODY_ROOT].parent = belly
    eb[BODY_ROOT].use_connect = False

    # DEF_Head: a control twin of the real head bone, sharing its rest exactly, driven
    # onto it by COPY_TRANSFORMS below. This is the tier-a rig's own idiom (every DEF_
    # leg bone there is driven by an FK_/IK_ twin the same way) and it means
    # author_anims can key `DEF_Head` on any rig family without that family having to
    # NAME a bone DEF_Head -- and without renaming a bone the mesh is skinned to.
    #
    # "Sharing its rest exactly" INCLUDES THE ROLL, which is the whole third of a bone's
    # orientation and the one part `head`/`tail` do not carry. SourceIO gives every bone
    # on these rigs the same 19 mm stub tail and encodes the Source bone's real rotation
    # in the roll -- `Head` imports at roll -89.9994 deg -- so an alias built from its
    # head and tail alone is a quarter turn away from it about its own axis, and the
    # COPY_TRANSFORMS below (world space) hands that quarter turn to the head on every
    # evaluated frame. That is not a subtle error: it is the head cranked back over the
    # shoulders in idle, walk and gallop alike, on every character in the pack.
    head_head, head_tail = rest[HEAD_BONE]
    new_bone(HEAD_ALIAS, head_head.copy(), head_tail.copy(), eb[HEAD_PARENT],
             roll=eb[HEAD_BONE].roll)

    # Four IK end-effectors and their targets.
    #
    # WHY AN EXTRA END BONE. Blender IK drives the TAIL of the last bone in the chain
    # onto the target. Source bones carry no length -- SourceIO gives every one of them
    # the same 0.0191 stub -- so a Source rig's leg has no bone whose tail is the hoof,
    # and constraining the existing foot bone would ask the solver to put a point 19 mm
    # from the ankle onto the ground. So each leg gets one real end-effector bone,
    # running from the last real leg bone's head straight down to the hoof plane, which
    # is both the chain's true reach and the thing that should meet the floor.
    for target_name, end_name, parent_name, _chain in LEGS:
        parent_head, _ = rest[parent_name]
        toe = Vector((parent_head.x, parent_head.y, ground))
        new_bone(end_name, parent_head.copy(), toe, eb[parent_name])
        # The target sits exactly where the end-effector's tail rests, so the rig is
        # already at its own IK solution before a single key is authored -- no constant
        # pull, and the rest pose that ships is the rest pose the artist built.
        # Pointing down mirrors tier a's IK_*Hoof bones.
        new_bone(target_name, toe, toe + Vector((0.0, 0.0, -0.1)), root)

    bpy.ops.object.mode_set(mode="OBJECT")

    con = arm.pose.bones[HEAD_BONE].constraints.new("COPY_TRANSFORMS")
    con.target = arm
    con.subtarget = HEAD_ALIAS

    chains = []
    for target_name, end_name, _parent, chain in LEGS:
        ik = arm.pose.bones[end_name].constraints.new("IK")
        ik.target = arm
        ik.subtarget = target_name
        # +1 for the end-effector itself, which is chain member zero.
        ik.chain_count = len(chain) + 1
        ik.use_tail = True
        ik.use_stretch = False
        ik.use_rotation = False
        chains.append(f"{end_name}<-{target_name}[{ik.chain_count}]")

    # How much slack each solved chain has at rest, printed so a rig whose legs are
    # geometrically singular (see LEGS) is visible in the export log rather than as a
    # knee that pops one frame in six. `end_name`'s rest is not in `rest` -- it was
    # created above -- so its length is recomputed from the same two points.
    reach = {}
    for target_name, end_name, parent_name, chain in LEGS:
        heads = [rest[b][0] for b in chain]        # chain[0] is the end bone's parent
        toe = Vector((heads[0].x, heads[0].y, ground))
        span = (toe - heads[0]).length + sum(
            (heads[i] - heads[i + 1]).length for i in range(len(heads) - 1))
        reach[target_name] = (span, (toe - heads[-1]).length)

    check_rest_pose_preserved(arm)

    print(f"SFM_RIG_ADAPTED bones={len(arm.data.bones)} ground_z={ground:.4f} "
          f"chains={chains}")
    for name, (span, straight) in sorted(reach.items()):
        print(f"SFM_RIG_CHAIN {name} length={span:.4f} rest_reach={straight:.4f} "
              f"extended={100.0 * straight / span:.1f}%")
    return arm


def withers_scale(arm=None, target_withers=1.163):
    """The --scale factor that puts this rig at the tier-a family's withers height.

    Reported, never applied here -- `export_blend.py --scale` owns the rescale, and the
    shipped factor is a fixed round number (2.0) rather than whatever this returns on
    the day, for exactly the reason tier a uses a fixed 0.5: a power of two is an
    exponent shift rather than a rounding. This exists so the next person can CHECK that
    number instead of inheriting it.

    Withers = the top of the back, the same reference docs/pipeline.md section 3
    measured tier a with (a pony's bounding box is dominated by ears, horn and mane, not
    by the animal). Taken as the highest point of the BARREL mesh alone -- the pack
    splits a pony across several bodygroup meshes and the barrel is exactly the one that
    ends at the back. Slicing a vertical slab above the shoulder joint instead, which is
    the more literal reading of "withers", does not work on these models: the head mesh
    carries the neck and overlaps that slab, so the slab measures the top of the neck
    (and, once the mane is in it, the top of the hairdo) rather than the back.
    """
    arm = arm or _armature()
    ground = _ground_z(arm)
    barrel = [o for o in bpy.data.objects
              if o.type == "MESH" and "/bodies/" in o.name.lower()]
    if not barrel:
        return None
    withers = max((o.matrix_world @ v.co).z
                  for o in barrel for v in o.data.vertices) - ground
    return target_withers / withers if withers > 0.0 else None
