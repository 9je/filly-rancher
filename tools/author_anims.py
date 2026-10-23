"""Author `idle` + `walk` + `gallop` Actions onto a CreatorOfPony-family pony rig.

Imported by `tools/export_blend.py --anims`; also runnable standalone for debugging:

    tools/bin/blender/blender -b <file>.blend -P tools/author_anims.py -- --object TS_Rig

WHY THIS EXISTS (see task-7-report.md): none of the five CreatorOfPony packs ship a
single character Action (`bpy.data.actions` holds only `CameraAxisAction`, a camera
orbit helper), and no community Action library for this rig family survives on a
loginless, curl-reachable host. So the walk/idle clips are authored here, in script,
so they are reproducible and re-runnable against every pack rather than being a
hand-posed .blend nobody can regenerate.

WHY THERE IS A SECOND LOCOMOTION CLIP. `walk` depicts 0.66 m/s and cannot be made
to depict more: its STRIDE is already near the front chain's geometric ceiling
(see BODY_CROUCH below), so the only lever left is the CYCLE. `gallop` is that
lever -- the same 0.275 m stride ridden through a stance six times shorter, which
is 3.30 m/s, and which is a genuinely different gait (asymmetric four-beat with a
suspension phase) rather than a walk played fast. See build_gallop().

WHY IK TARGETS AND NOT DEF_/FK_ BONES. On this rig every `DEF_*Leg*`/`DEF_*Hoof*`
bone carries two `COPY_TRANSFORMS` constraints -- from its `FK_` twin and then from
its `IK_` twin -- both at influence 1.0. Last constraint wins, so the rig is
permanently in IK mode and keyframing either the DEF_ bones or the FK_ chain is
silently discarded at evaluation time. The real handles are the four IK hoof targets
(`IK_FrontHoof.L/R`, `IK_RearHoof.L/R`), which are parented straight to `CON_Root`
rather than to their legs -- i.e. genuine world-space foot targets, which is exactly
what a quadruped gait wants. The glTF exporter's armature sampling then bakes the
resolved DEF_ bone transforms, so the IK solve is what ships.

BONE-LOCAL MATH. `pose_bone.location` is expressed along the bone's own rest axes,
not in armature space, and these hoof bones point straight down, so a naive
`location.z += lift` would shove the foot sideways. Every bone this script animates
is parented (directly or via `CON_Root`, which is left at rest) to an unanimated
parent, so a bone's armature-space offset is exactly `bone.matrix_local.to_3x3() @
location`; `_to_bone_space()` inverts that to turn an intended armature-space delta
into the pose value. Same trick for rotation axes.

SCALE. `export_blend.py --scale` runs BEFORE this module, so the rig arrives already
normalised and every length constant here is in metres (1 unit = 1 metre, see
docs/pipeline.md section 3). Every measurement quoted in this file's comments is
post-scale; the source .blend's own numbers are twice them, because the tier-a packs
are authored at ~2x life size. `_require_metric_rig()` enforces the ordering.

ORIENTATION. The rig faces -Y in Blender (head at y=-0.53, rump at y=+0.49), which
`export_yup` turns into +Z in glTF. Godot's `look_at()` aims -Z at the target, so an
unrotated export moonwalks. `export_blend.py --rotate-z 180` is the fix; it lives
there rather than here because it is an export-orientation concern, not an animation
concern.

SECONDARY MOTION IS NOT AUTHORED HERE. Mane/tail/forelock chains are deliberately
left out of every clip and out of the export bake -- see SECONDARY_MOTION_PATTERNS
below and docs/pipeline.md section 6.
"""
import math

import bpy
from mathutils import Quaternion, Vector

# --- Secondary-motion (hair) bone chains ------------------------------------
# Bones matching any of these substrings must carry NO keyframes in the exported
# clips. They are driven at runtime instead, by a Godot SpringBoneSimulator3D that
# `game/scripts/pony_rig.gd` attaches to every pony -- that is what makes the mane
# and tail lag the body's bob (follow-through/overlap) instead of snapping with it.
#
# This exclusion is load-bearing, not cosmetic: an AnimationPlayer track and a
# SkeletonModifier3D both write the same bone pose, and the animation is applied
# after the modifier's input is captured, so ANY keyframe on these bones -- even a
# constant one holding the rest pose, which is exactly what the exporter's
# "bake every bone every frame" mode emits -- overwrites the simulation every frame
# and makes the spring bones look like they do nothing at all.
#
# Matched case-insensitively as substrings of the whole bone name, so it catches
# every rig layer at once (`DEF_Mane1-3`, `CON_Tail2`, `FK_Hair4-1`, ...).
# Deliberately a name-pattern list and NOT a per-character bone list: the whole
# tier-a family (Twilight, Rainbow Dash, Fluttershy, plus the downloaded-but-not-yet
# -converted Applejack and Rarity) shares the same DEF_Mane*/DEF_Tail*/DEF_Hair*
# naming, and so will any future pack from it. Adding a character needs no edit
# here; adding a rig family with different hair naming needs one new substring.
SECONDARY_MOTION_PATTERNS = ("mane", "tail", "hair", "forelock", "fringe")


def is_secondary_motion_bone(name):
    """True if `name` is a mane/tail/hair bone that must stay out of the bake."""
    lowered = name.lower()
    return any(pattern in lowered for pattern in SECONDARY_MOTION_PATTERNS)


def secondary_motion_bones(arm):
    """Every bone on `arm` excluded from the animation bake, sorted by name."""
    return sorted(b.name for b in arm.data.bones if is_secondary_motion_bone(b.name))

# --- Canonical bone names. Verified (task-7 Step 1) to be present and identically
# named on all three tier-a rigs -- twilight/rainbowdash/fluttershy share a 93-bone
# core skeleton with a 100% intersection; only hair/mane/tail/wing chains diverge.
# So this same script authors the same clips on any pack in the family unchanged.
ROOT = "CON_Root"
BELLY = "CON_Belly"
HEAD = "DEF_Head"
# (bone name, gait phase offset). Diagonal pairs move together: front-left with
# rear-right, front-right with rear-left.
FEET = [
    ("IK_FrontHoof.L", 0.0),
    ("IK_RearHoof.R", 0.0),
    ("IK_FrontHoof.R", 0.5),
    ("IK_RearHoof.L", 0.5),
]
# Every clip keyframes every bone in this set, even the ones it holds still. A pose
# bone's basis is shared state: a clip that simply omits a channel does not reset it,
# it inherits whatever the previously-built clip left behind, both while authoring and
# in the exporter's per-Action bake. That is not hypothetical -- it is exactly how the
# idle first came out with the hooves frozen half a stride apart.
ANIMATED = [BELLY, HEAD] + [name for name, _ in FEET]

# --- EVERY LENGTH BELOW IS IN METRES, because 1 unit = 1 metre is this project's
# convention (docs/pipeline.md section 3) and `export_blend.py --scale` has already
# normalised the rig by the time author() runs. The source packs are authored at ~2x
# life size, so a pony reaches the authoring code at --scale 0.5 and every constant
# here is exactly half what it was when these clips were first tuned against the
# packs' native units. Ratios -- and therefore the gait, the IK margins and all the
# reasoning below -- are unchanged: a uniform scale leaves every angle alone.
# `_require_metric_rig()` refuses to author onto an un-normalised rig rather than
# silently baking a stride the model does not have.

WALK_FRAMES = 20        # loop length; clips start at frame 0, so frame WALK_FRAMES
                        # (20) is the seam and repeats frame 0
# Fore/aft hoof travel per stride, in metres. This is the number that sets how fast
# the clip says she is moving, so it is also what a consumer scene has to match to
# avoid foot skate -- see IMPLIED_SPEED below and WALK_SPEED in
# scenes/test/walk_test.gd. 0.15 (the first pass) was a mincing shuffle for a model
# whose front leg chain is 0.533 long; 0.275 is roughly half a leg length per step,
# which reads as a walk and still clears full extension by a comfortable margin
# (worst-case reach over the cycle is 0.520 at mid-stance, and that peak is set by
# the body bob, not by STRIDE). It is also close to the geometric ceiling: the chain
# runs out of reach not far above this, which is why the clip depicts a deliberate
# 0.66 m/s walk rather than a brisker one -- see implied_ground_speed().
STRIDE = 0.275
LIFT = 0.08             # swing-phase hoof clearance
BODY_BOB = 0.0225       # vertical body oscillation, twice per gait cycle
BODY_PITCH = math.radians(2.5)

# --- The front IK chain is 0.229 + 0.305 = 0.533 long but its rest shoulder-to-hoof
# distance is 0.527, i.e. the rig stands with only 0.006 of bend left in the front
# legs. Swinging a hoof half a stride fore or aft needs sqrt(0.527^2 + 0.075^2) =
# 0.532, so the solver reaches full extension right at the stance extremes and the
# knee pops -- visible in the baked curve as DEF_FrontUpperLeg snapping back toward
# zero for a single frame at t=0.5. Dropping the body a few centimetres restores the
# bend margin (sqrt(0.497^2 + 0.075^2) = 0.503) and the pop disappears. Rear legs have
# 0.035 of slack already (they carry a hock) and never needed this.
BODY_CROUCH = 0.045

IDLE_FRAMES = 48        # 2 s at 24 fps
IDLE_BOB = 0.009
IDLE_CROUCH = 0.015     # same reason: keeps the idle bob's high point off full extension
IDLE_HEAD_NOD = math.radians(1.8)

# --- GALLOP -----------------------------------------------------------------------
# A gallop is not a fast walk, and on THIS rig it cannot be one. The front IK chain is
# 0.5334 long against a 0.5269 rest reach (98.77% extended, measured -- see author()),
# so the stride cannot grow: the walk's 0.275 m is already close to what the geometry
# allows once the body bob is accounted for. The lever that IS available is the cycle.
#
#   speed = stride / (cycle_seconds * stance_fraction)
#
# `gallop` keeps the walk's 0.275 m stride and cuts the *stance* from half a 0.833 s
# cycle (0.417 s) to one sixth of a 0.5 s cycle (0.083 s). Same ground covered per
# footfall, five times less time to cover it: 0.66 -> 3.30 m/s. 0.083 s of contact is
# also about what a real galloping horse's limb actually gets, so this is the honest
# way round rather than a trick.
#
# GAIT AUTHORED: a transverse gallop on the LEFT lead -- four separate beats in the
# order right-hind, left-hind, right-fore, left-fore, with the leading (left) foreleg
# landing last and reaching furthest forward, and TWO airborne phases: a short
# "gathered" one after the hinds leave and before the fores land, and a long
# "extended" one after the leading fore leaves. That is a real quadruped gallop's
# footfall pattern, and it is what makes this clip read as a different gait rather
# than a sped-up walk: the walk's two diagonal pairs are gone, replaced by four
# asymmetric beats and 42% of the cycle with nothing on the ground.
GALLOP_FRAMES = 12          # 0.5 s at 24 fps -> a 2 Hz stride rate, which is what a
                            # real horse gallops at. Twelve frames is also the
                            # smallest cycle that still puts every footfall and
                            # lift-off event exactly on a sampled frame (see
                            # GALLOP_FEET), so the exporter's per-frame bake captures
                            # the contacts instead of interpolating past them.
GALLOP_STRIDE = 0.275       # deliberately identical to STRIDE: the whole point is
                            # that the cycle changed, not the reach.
GALLOP_STANCE_FRACTION = 1.0 / 6.0   # two of the twelve frames planted per hoof
GALLOP_SWING_FRACTION = 1.0 - GALLOP_STANCE_FRACTION

# Swing shaping. A galloping limb snaps forward (protraction) and then hangs, reaching,
# waiting for the ground -- it does not drift forward at a constant rate for the whole
# 5/6 of the cycle it is airborne, which is what a linear return would look like and
# which reads as floating. So the fore/aft return is a smoothstep compressed into the
# first GALLOP_PROTRACTION of the swing, and the hoof then holds its forward position
# while it descends onto the ground.
GALLOP_PROTRACTION = 0.75
GALLOP_LIFT = 0.11          # swing clearance; higher than the walk's 0.08 because the
                            # legs fold up under the body during suspension

# Body. One oscillation per cycle (a gallop has one suspension, unlike the walk's two
# diagonal footfalls), highest during the extended suspension and lowest through the
# forelimb stance -- which is both what the animal does and what keeps the near-
# singular front chain furthest from full extension exactly when its hoof is most
# fore/aft. GALLOP_CROUCH is bigger than the walk's for the same reason it exists
# there: bend margin in the front legs.
GALLOP_CROUCH = 0.055
GALLOP_BOB = 0.035
GALLOP_BOB_PEAK = 0.80      # cycle fraction at which the body rides highest
                            # (mid-way through the extended suspension)
# Pitch. Positive rotation about +X is rump-up/nose-down for this rig (the rig faces
# -Y). Peak nose-down is timed to the forelimb stance, nose-up to the hind drive and
# the gathered suspension -- the pitching a gallop is read by.
GALLOP_PITCH = math.radians(5.0)
GALLOP_PITCH_PHASE = 0.21   # sin() peaks a quarter cycle later, i.e. at t=0.46,
                            # the middle of the two forelimb stances
GALLOP_HEAD_NOD = math.radians(4.0)
GALLOP_HEAD_LAG = 0.08      # the head follows the body's pitch a beat late

# Hind hooves sit 0.2075 m BEHIND the hip joint at rest (the hock's zig-zag), so unlike
# the front legs -- whose hoof hangs almost straight down -- the rear chain runs out of
# reach asymmetrically: swinging a hind hoof backwards costs far more extension than
# swinging it forwards. Planting the hind feet further under the body for the whole
# clip re-centres their excursion inside the chain's comfortable range, and is also
# exactly what a galloping quadruped does with its hindquarters.
GALLOP_REAR_REACH = 0.06

# (bone, cycle fraction at which this hoof touches down). Transverse gallop, left lead:
# right-hind, left-hind, right-fore, left-fore. Every value is a multiple of 1/12 so it
# lands on a sampled frame. With a 1/6 stance the ground-contact map is
#   RH [0.000, 0.167]  LH [0.083, 0.250] | gathered suspension [0.250, 0.333]
#   RF [0.333, 0.500]  LF [0.417, 0.583] | extended suspension [0.583, 1.000]
GALLOP_FEET = [
    ("IK_RearHoof.R", 0.0 / 12.0),
    ("IK_RearHoof.L", 1.0 / 12.0),
    ("IK_FrontHoof.R", 4.0 / 12.0),
    ("IK_FrontHoof.L", 5.0 / 12.0),
]

# --- Metric-rig guard. The tier-a packs measure 4.10 units from hoof plane to horn
# tip in their own units and 2.05 after --scale 0.5; the window is wide enough for any
# plausible pony pack and narrow enough that an un-normalised rig cannot slip through.
METRIC_RIG_HEIGHT_RANGE = (0.5, 3.0)

FORWARD = Vector((0.0, -1.0, 0.0))   # rig faces -Y in Blender
UP = Vector((0.0, 0.0, 1.0))
SIDE = Vector((1.0, 0.0, 0.0))


def rig_height(arm):
    """Hoof plane to highest bone tip, in the units the rig currently measures in."""
    zs = []
    for bone in arm.data.bones:
        zs.append((arm.matrix_world @ bone.head_local).z)
        zs.append((arm.matrix_world @ bone.tail_local).z)
    return max(zs) - min(zs)


def _require_metric_rig(arm):
    """Refuse to author metre-sized clips onto a rig that is not metre-sized.

    Every length constant in this module is metres. Nothing downstream fails loudly
    when they are applied to a rig in some other unit -- the export still succeeds,
    every structural gate still passes, and the only symptom is a pony mincing or
    lunging through a stride that does not match her legs. So check it here.

    THIS DELIBERATELY BREAKS `--anims` WITHOUT `--scale`, which used to work. It is
    not a compromise made to get a loud error: once STRIDE became metric, that
    combination could no longer reproduce its old output *at all* -- measured, it
    emits a rig at pack scale whose hooves travel exactly half the stride its legs
    want, and prints a WALK_IMPLIED_SPEED a consumer scene would then match, giving
    2x foot skate. The only choice was between failing here and shipping that
    silently. See docs/pipeline.md section 3.
    """
    height = rig_height(arm)
    low, high = METRIC_RIG_HEIGHT_RANGE
    if not low <= height <= high:
        raise SystemExit(
            f"rig {arm.name!r} measures {height:.4f} units tall, outside the metric "
            f"range {METRIC_RIG_HEIGHT_RANGE}. This module's STRIDE/LIFT/BODY_* "
            f"constants are metres (1 unit = 1 metre); author them onto an "
            f"un-normalised rig and the gait will not match the model.\n"
            f"  Fix: add `--scale 0.5` to the tools/export_blend.py command -- that is "
            f"the factor for every CreatorOfPony/MythicSpeed tier-a pack, and using the "
            f"same one for all of them is what keeps the family comparable.\n"
            f"  Only if this really is a differently-sized pack, the factor that would "
            f"put THIS rig at the tier-a family's 2.05 m hoof-to-horn height (~1.2 m at "
            f"the withers) is about {2.05 / height:.2g}.\n"
            f"  See docs/pipeline.md section 3."
        )
    print(f"METRIC_RIG_OK height={height:.4f}")


def _require(arm, names):
    missing = [n for n in names if n not in arm.pose.bones]
    if missing:
        raise SystemExit(
            f"rig {arm.name!r} is not a CreatorOfPony-family rig: missing bones {missing}"
        )


def _to_bone_space(pbone, delta):
    """Armature-space vector -> the bone's local (rest-axis) space."""
    return pbone.bone.matrix_local.to_3x3().inverted() @ delta


def _set_offset(pbone, delta):
    pbone.location = _to_bone_space(pbone, delta)


def _set_rotation(pbone, axis, angle):
    local_axis = _to_bone_space(pbone, axis)
    if local_axis.length == 0.0:
        return
    pbone.rotation_quaternion = Quaternion(local_axis.normalized(), angle)


def _new_action(arm, name):
    """Fresh Action bound to `arm`, replacing any same-named leftover."""
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True   # survive the exporter's orphan purge
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    return action


def _rest(arm, names):
    for name in names:
        pbone = arm.pose.bones[name]
        pbone.location = (0.0, 0.0, 0.0)
        pbone.rotation_mode = "QUATERNION"
        pbone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)


def _foot_offset(phase_t):
    """Hoof offset (armature space) at normalised gait time `phase_t` in [0,1).

    First half is stance: hoof planted, travelling backwards under the body.
    Second half is swing: hoof lifts and carries forward again.
    """
    if phase_t < 0.5:
        u = phase_t / 0.5
        ahead = STRIDE * (0.5 - u)          # +half-stride -> -half-stride
        lift = 0.0
    else:
        u = (phase_t - 0.5) / 0.5
        ahead = STRIDE * (u - 0.5)          # -half-stride -> +half-stride
        # Raised-cosine rather than sin(pi*u): it leaves and re-meets the ground with
        # zero vertical velocity, so lift-off and touchdown don't put a corner in the
        # knee-bend curve the way a half-sine's non-zero end slope does.
        lift = LIFT * 0.5 * (1.0 - math.cos(2.0 * math.pi * u))
    return FORWARD * ahead + UP * lift


def build_walk(arm):
    """20-frame diagonal-pair walk loop driven through the IK hoof targets."""
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, "walk")

    for i in range(WALK_FRAMES + 1):        # inclusive: last frame repeats the first
        frame = i                           # start at 0: a clip starting at frame 1
                                            # exports a leading 1/fps hold that shows
                                            # up as a stutter once Godot loops it
        t = (i % WALK_FRAMES) / WALK_FRAMES

        for name, phase in FEET:
            pbone = arm.pose.bones[name]
            _set_offset(pbone, _foot_offset((t + phase) % 1.0))
            pbone.keyframe_insert("location", frame=frame, group=name)

        # Hold the head at rest explicitly -- see ANIMATED's note on why every clip
        # keys every bone any sibling clip touches.
        head = arm.pose.bones[HEAD]
        head.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        head.keyframe_insert("rotation_quaternion", frame=frame, group=HEAD)

        # Two body bobs per gait cycle -- one per diagonal-pair footfall -- plus a
        # small pitch so she nods into the stride instead of gliding flat. The bob is
        # -cos so the body rides highest at mid-stance (hoof directly underneath) and
        # lowest at the stance/swing changeover, which is both what a real quadruped
        # does and what keeps the front chain furthest from full extension exactly
        # when the hoof is at its most fore/aft.
        belly = arm.pose.bones[BELLY]
        # Both bob and pitch run at twice the gait frequency -- once per diagonal-pair
        # footfall. Pitching at 1x (the first pass) gave the two diagonal pairs
        # different body attitudes even though their hoof paths are mirror images, so
        # one side rode closer to full extension than the other: at STRIDE=0.55 the
        # front-right chain reached 99.2% of its length and the knee started popping
        # again, while front-left sat at 95.6%. At 2x both pairs see the same body.
        _set_offset(belly, UP * (-BODY_BOB * math.cos(4.0 * math.pi * t) - BODY_CROUCH))
        _set_rotation(belly, SIDE, BODY_PITCH * math.sin(4.0 * math.pi * t))
        belly.keyframe_insert("location", frame=frame, group=BELLY)
        belly.keyframe_insert("rotation_quaternion", frame=frame, group=BELLY)

    _rest(arm, ANIMATED)
    return action


def _smoothstep(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def _gallop_foot_offset(since_contact, rear):
    """Hoof offset (armature space) `since_contact` of a cycle after touchdown."""
    u = since_contact % 1.0
    if u < GALLOP_STANCE_FRACTION:
        # Stance: planted, so it must travel backwards at EXACTLY the ground speed the
        # clip claims. Linear, and keyed on every frame, so the bake samples it exactly
        # -- any curvature here is in-clip foot skate no consumer can compensate for.
        s = u / GALLOP_STANCE_FRACTION
        ahead = GALLOP_STRIDE * (0.5 - s)
        lift = 0.0
    else:
        s = (u - GALLOP_STANCE_FRACTION) / GALLOP_SWING_FRACTION
        # Protract fast, then hang and reach (see GALLOP_PROTRACTION).
        ahead = GALLOP_STRIDE * (_smoothstep(s / GALLOP_PROTRACTION) - 0.5)
        # Same raised cosine as the walk: leaves and re-meets the ground with zero
        # vertical velocity, so touchdown puts no corner in the knee-bend curve.
        lift = GALLOP_LIFT * 0.5 * (1.0 - math.cos(2.0 * math.pi * s))
    offset = FORWARD * ahead + UP * lift
    if rear:
        offset += FORWARD * GALLOP_REAR_REACH
    return offset


def build_gallop(arm):
    """12-frame asymmetric four-beat gallop with two suspension phases.

    Read the GALLOP_* constant block above first -- it carries the gait's design and
    the geometry that forces it. The short version: same stride as the walk, one sixth
    of the stance, 3.30 m/s instead of 0.66.
    """
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, "gallop")

    for i in range(GALLOP_FRAMES + 1):      # inclusive: last frame repeats the first
        frame = i                           # start at 0, same reason as build_walk
        t = (i % GALLOP_FRAMES) / GALLOP_FRAMES

        for name, contact in GALLOP_FEET:
            pbone = arm.pose.bones[name]
            _set_offset(pbone, _gallop_foot_offset(t - contact, name.startswith("IK_Rear")))
            pbone.keyframe_insert("location", frame=frame, group=name)

        belly = arm.pose.bones[BELLY]
        _set_offset(belly, UP * (
            GALLOP_BOB * math.cos(2.0 * math.pi * (t - GALLOP_BOB_PEAK)) - GALLOP_CROUCH))
        _set_rotation(belly, SIDE,
                      GALLOP_PITCH * math.sin(2.0 * math.pi * (t - GALLOP_PITCH_PHASE)))
        belly.keyframe_insert("location", frame=frame, group=BELLY)
        belly.keyframe_insert("rotation_quaternion", frame=frame, group=BELLY)

        # DEF_Head is CHILD_OF CON_Root at influence 1.0, so it is held level against
        # the body unless keyed. Give it the body's own pitch, a beat late, so she
        # drives her head into the stride instead of gliding along on a gyro-stabilised
        # neck -- the single most obvious tell that a run cycle is faked.
        head = arm.pose.bones[HEAD]
        _set_rotation(head, SIDE, GALLOP_HEAD_NOD * math.sin(
            2.0 * math.pi * (t - GALLOP_PITCH_PHASE - GALLOP_HEAD_LAG)))
        head.keyframe_insert("rotation_quaternion", frame=frame, group=HEAD)

    _rest(arm, ANIMATED)
    return action


def build_idle(arm):
    """Slow breathing sway: body rise/fall plus a barely-there head nod."""
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, "idle")

    # Six keys around the loop is enough for a sine this slow; Bezier interpolation
    # fills in the rest, and key 0 == key IDLE_FRAMES keeps the loop seamless.
    steps = 6
    for i in range(steps + 1):
        frame = round(i * IDLE_FRAMES / steps)
        t = (i % steps) / steps

        belly = arm.pose.bones[BELLY]
        _set_offset(belly, UP * (IDLE_BOB * math.sin(2.0 * math.pi * t) - IDLE_CROUCH))
        belly.keyframe_insert("location", frame=frame, group=BELLY)

        # DEF_Head is CHILD_OF CON_Root at influence 1.0 (the rig stabilises the head
        # against body motion), so it needs its own key to move at all.
        head = arm.pose.bones[HEAD]
        _set_rotation(head, SIDE, IDLE_HEAD_NOD * math.sin(2.0 * math.pi * t + math.pi / 3))
        head.keyframe_insert("rotation_quaternion", frame=frame, group=HEAD)

        # Plant all four hooves at their rest position for the whole clip. Without
        # these keys the idle inherits whatever the walk left in the IK targets and
        # Twilight "stands" frozen mid-stride, hooves splayed half a stride apart.
        for name, _phase in FEET:
            pbone = arm.pose.bones[name]
            pbone.location = (0.0, 0.0, 0.0)
            pbone.keyframe_insert("location", frame=frame, group=name)

    _rest(arm, ANIMATED)
    return action


# --- v1 clips: every pose a pony needs for gameplay and story beats --------------------
#
# Built from KEYED POSES rather than per-frame maths: each clip is a short list of
# (frame, pose) keys and Bezier interpolation does the in-betweens, which is how a hand
# animator would block them. A pose is: the body (forward and up offset, pitch), the head
# (pitch, yaw, roll), and any hooves that leave their rest spot (forward, up). Hooves not
# named stay planted at rest. Signs, measured on the rig: +pitch about SIDE tips the nose
# DOWN, +yaw about UP turns the head to the pony's own right (+X).
#
# Face, ears, tail and wings are not keyed here: the face is layered at runtime by
# game/actors/pony/pony_face.gd and hair is spring-simulated.

FRONT_L, FRONT_R = "IK_FrontHoof.L", "IK_FrontHoof.R"
REAR_L, REAR_R = "IK_RearHoof.L", "IK_RearHoof.R"
ALL_FEET = [FRONT_L, FRONT_R, REAR_L, REAR_R]


# The v1 pose distances below were blocked against a 1 m leg-height reference; the SFM
# donors measure about 2.16 m tall after export_blend.py's --scale 2.0 (legs about 0.9 m),
# so every pose distance is multiplied by this. Angles are unaffected.
POSE_SCALE = 2.0


def _pose(arm, frame, body=(0.0, 0.0), pitch=0.0, head=(0.0, 0.0, 0.0), feet=None):
    """Key every animated bone at `frame`. body=(forward, up); pitch radians;
    head=(pitch, yaw, roll) radians; feet={bone: (forward, up)}. Distances are in the
    1 m reference and scaled by POSE_SCALE."""
    feet = feet or {}
    belly = arm.pose.bones[BELLY]
    _set_offset(belly, (FORWARD * body[0] + UP * body[1]) * POSE_SCALE)
    _set_rotation(belly, SIDE, pitch)
    if pitch == 0.0:
        belly.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    belly.keyframe_insert("location", frame=frame, group=BELLY)
    belly.keyframe_insert("rotation_quaternion", frame=frame, group=BELLY)
    hb = arm.pose.bones[HEAD]
    q = Quaternion((1.0, 0.0, 0.0, 0.0))
    for axis, angle in ((UP, head[1]), (SIDE, head[0]), (FORWARD, head[2])):
        if angle != 0.0:
            local = _to_bone_space(hb, axis)
            if local.length > 0.0:
                q = q @ Quaternion(local.normalized(), angle)
    hb.rotation_quaternion = q
    hb.keyframe_insert("rotation_quaternion", frame=frame, group=HEAD)
    for name in ALL_FEET:
        pb = arm.pose.bones[name]
        f, u = feet.get(name, (0.0, 0.0))
        _set_offset(pb, (FORWARD * f + UP * u) * POSE_SCALE)
        pb.keyframe_insert("location", frame=frame, group=name)


def _clip(arm, name, keys):
    """keys: [(frame, pose_kwargs)]. The last key should repeat the first for loops."""
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, name)
    for frame, kw in keys:
        _pose(arm, frame, **kw)
    _rest(arm, ANIMATED)
    return action


D = math.radians


def build_trot(arm):
    """16-frame two-beat trot: diagonal pairs, a short suspension, more bounce than the
    walk. Same stride geometry as the walk so the gait handover stays skate-free."""
    _require(arm, ANIMATED)
    _rest(arm, ANIMATED)
    action = _new_action(arm, "trot")
    frames = TROT_FRAMES
    for i in range(frames + 1):
        t = (i % frames) / frames
        for name, phase in FEET:
            u = (t + phase) % 1.0
            if u < TROT_STANCE:
                s = u / TROT_STANCE
                ahead, lift = TROT_STRIDE * (0.5 - s), 0.0
            else:
                s = (u - TROT_STANCE) / (1.0 - TROT_STANCE)
                ahead = TROT_STRIDE * (_smoothstep(s) - 0.5)
                lift = TROT_LIFT * 0.5 * (1.0 - math.cos(2.0 * math.pi * s))
            pb = arm.pose.bones[name]
            _set_offset(pb, FORWARD * ahead + UP * lift)
            pb.keyframe_insert("location", frame=i, group=name)
        belly = arm.pose.bones[BELLY]
        _set_offset(belly, UP * (TROT_BOB * math.cos(4.0 * math.pi * t) - TROT_CROUCH))
        _set_rotation(belly, SIDE, D(2.0) * math.sin(4.0 * math.pi * t))
        belly.keyframe_insert("location", frame=i, group=BELLY)
        belly.keyframe_insert("rotation_quaternion", frame=i, group=BELLY)
        head = arm.pose.bones[HEAD]
        _set_rotation(head, SIDE, D(3.0) * math.sin(4.0 * math.pi * (t - 0.08)))
        head.keyframe_insert("rotation_quaternion", frame=i, group=HEAD)
    _rest(arm, ANIMATED)
    return action


TROT_FRAMES = 16
TROT_STANCE = 0.42
# Longer than the walk's: 0.5 m over a 0.28 s stance is about 1.79 m/s, the middle of the
# walk (0.66) to gallop (3.30) band, which is where game/systems/gait.gd hands over.
TROT_STRIDE = 0.5
TROT_LIFT = 0.12
TROT_BOB = 0.03
TROT_CROUCH = 0.05


def build_jump(arm):
    """One-shot 22 frames: anticipation crouch, push off, tucked air, a squash on landing.
    The ARC itself comes from the character controller; the clip is the body's shape."""
    tuck = {FRONT_L: (0.06, 0.16), FRONT_R: (0.06, 0.16), REAR_L: (-0.04, 0.12), REAR_R: (-0.04, 0.12)}
    reach = {FRONT_L: (0.1, 0.05), FRONT_R: (0.1, 0.05), REAR_L: (-0.08, 0.02), REAR_R: (-0.08, 0.02)}
    return _clip(arm, "jump", [
        (0, dict()),
        (4, dict(body=(0.0, -0.09), pitch=D(-4), head=(D(6), 0, 0))),
        (7, dict(body=(0.03, 0.04), pitch=D(-10), head=(D(-8), 0, 0), feet=reach)),
        (12, dict(body=(0.0, 0.02), pitch=D(-2), head=(D(-4), 0, 0), feet=tuck)),
        (17, dict(body=(0.0, -0.02), pitch=D(6), head=(D(4), 0, 0), feet=reach)),
        (19, dict(body=(0.0, -0.08), pitch=D(2), head=(D(10), 0, 0))),
        (22, dict()),
    ])


def build_graze(arm):
    """Loop, 48 frames: head down to the grass, two little nibbles, a chew."""
    ff = {FRONT_L: (0.06, 0.0), FRONT_R: (0.02, 0.0)}
    down = dict(body=(0.05, -0.08), pitch=D(16), head=(D(62), 0, 0), feet=ff)
    nib = dict(body=(0.05, -0.085), pitch=D(16), head=(D(68), D(4), 0), feet=ff)
    nib2 = dict(body=(0.05, -0.085), pitch=D(16), head=(D(67), D(-4), 0), feet=ff)
    chew = dict(body=(0.05, -0.08), pitch=D(15), head=(D(58), 0, D(2)), feet=ff)
    return _clip(arm, "graze", [
        (0, down), (10, nib), (16, down), (26, nib2), (32, down), (40, chew), (48, down),
    ])


SIT_FEET = {REAR_L: (0.2, 0.0), REAR_R: (0.2, 0.0), FRONT_L: (0.03, 0.0), FRONT_R: (0.03, 0.0)}


def build_sit(arm):
    """Loop, 48 frames: haunches down, front legs straight, breathing."""
    a = dict(body=(0.05, -0.16), pitch=D(-30), head=(D(22), 0, 0), feet=SIT_FEET)
    b = dict(body=(0.05, -0.155), pitch=D(-29), head=(D(20), D(3), 0), feet=SIT_FEET)
    return _clip(arm, "sit", [(0, a), (24, b), (48, a)])


LIE_FEET = {FRONT_L: (-0.12, 0.05), FRONT_R: (-0.1, 0.05), REAR_L: (0.2, 0.03), REAR_R: (0.18, 0.03)}


def build_lie(arm):
    """Loop, 48 frames: lying down, legs folded under, head up, breathing."""
    a = dict(body=(0.0, -0.3), pitch=D(-2), head=(D(-6), 0, 0), feet=LIE_FEET)
    b = dict(body=(0.0, -0.295), pitch=D(-2), head=(D(-4), D(2), 0), feet=LIE_FEET)
    return _clip(arm, "lie", [(0, a), (24, b), (48, a)])


def build_sleep(arm):
    """Loop, 72 frames: lying, head tucked down on the forelegs, slow breaths."""
    a = dict(body=(0.0, -0.31), pitch=D(0), head=(D(52), D(18), D(8)), feet=LIE_FEET)
    b = dict(body=(0.0, -0.3), pitch=D(-1), head=(D(49), D(18), D(8)), feet=LIE_FEET)
    return _clip(arm, "sleep", [(0, a), (36, b), (72, a)])


def build_startle(arm):
    """One-shot 14 frames: a little jump straight up, head snaps up, then braced."""
    up = {n: (0.0, 0.06) for n in ALL_FEET}
    return _clip(arm, "startle", [
        (0, dict()),
        (3, dict(body=(-0.02, 0.07), pitch=D(-6), head=(D(-18), 0, 0), feet=up)),
        (7, dict(body=(-0.02, -0.06), pitch=D(-3), head=(D(-12), 0, 0))),
        (14, dict(body=(-0.01, -0.03), pitch=D(-2), head=(D(-8), 0, 0))),
    ])


def build_cower(arm):
    """Loop, 24 frames: crouched low, weight back, head ducked, a small tremble."""
    feet = {FRONT_L: (0.04, 0.0), FRONT_R: (0.04, 0.0)}
    a = dict(body=(-0.06, -0.16), pitch=D(6), head=(D(30), 0, 0), feet=feet)
    b = dict(body=(-0.055, -0.165), pitch=D(6.5), head=(D(31), D(2), 0), feet=feet)
    c = dict(body=(-0.06, -0.158), pitch=D(5.5), head=(D(29), D(-2), 0), feet=feet)
    return _clip(arm, "cower", [(0, a), (6, b), (12, a), (18, c), (24, a)])


def build_hop(arm):
    """Loop, 14 frames: a happy little bounce on all four hooves."""
    air = {n: (0.0, 0.1) for n in ALL_FEET}
    return _clip(arm, "hop", [
        (0, dict(body=(0.0, -0.06), head=(D(4), 0, 0))),
        (4, dict(body=(0.0, 0.08), pitch=D(-4), head=(D(-10), 0, 0), feet=air)),
        (7, dict(body=(0.0, 0.1), pitch=D(-2), head=(D(-8), 0, 0), feet=air)),
        (10, dict(body=(0.0, -0.02), head=(D(2), 0, 0))),
        (14, dict(body=(0.0, -0.06), head=(D(4), 0, 0))),
    ])


def build_struggle(arm):
    """Loop, 12 frames: held in the Scoop, hooves kicking at the air, head shaking."""
    k1 = {FRONT_L: (0.08, 0.12), FRONT_R: (-0.02, 0.04), REAR_L: (-0.06, 0.03), REAR_R: (0.04, 0.12)}
    k2 = {FRONT_L: (-0.02, 0.04), FRONT_R: (0.08, 0.12), REAR_L: (0.04, 0.12), REAR_R: (-0.06, 0.03)}
    return _clip(arm, "struggle", [
        (0, dict(pitch=D(-6), head=(D(-10), D(14), 0), feet=k1)),
        (6, dict(pitch=D(-4), head=(D(-6), D(-14), 0), feet=k2)),
        (12, dict(pitch=D(-6), head=(D(-10), D(14), 0), feet=k1)),
    ])


def build_talk(arm):
    """Loop, 24 frames: small emphatic head bobs and tilts while speaking."""
    return _clip(arm, "talk", [
        (0, dict(head=(D(0), 0, 0))),
        (6, dict(head=(D(5), D(3), D(3)))),
        (12, dict(head=(D(-2), D(-2), 0))),
        (18, dict(head=(D(4), D(-4), D(-3)))),
        (24, dict(head=(D(0), 0, 0))),
    ])


def build_nod(arm):
    """One-shot 16 frames: two nods, yes."""
    return _clip(arm, "nod", [
        (0, dict()), (4, dict(head=(D(16), 0, 0))), (7, dict(head=(D(-2), 0, 0))),
        (10, dict(head=(D(12), 0, 0))), (16, dict()),
    ])


def build_shake(arm):
    """One-shot 18 frames: a head shake, no."""
    return _clip(arm, "shake", [
        (0, dict()), (4, dict(head=(D(4), D(-20), 0))), (8, dict(head=(D(4), D(20), 0))),
        (12, dict(head=(D(4), D(-14), 0))), (18, dict()),
    ])


def build_sad(arm):
    """Loop, 48 frames: head low, body sagging, slow breaths."""
    a = dict(body=(0.0, -0.04), pitch=D(3), head=(D(32), 0, 0))
    b = dict(body=(0.0, -0.05), pitch=D(3.5), head=(D(34), D(-3), 0))
    return _clip(arm, "sad", [(0, a), (24, b), (48, a)])


def build_laugh(arm):
    """Loop, 16 frames: head tipped back, the body bouncing with it."""
    a = dict(body=(0.0, -0.02), pitch=D(-3), head=(D(-16), 0, D(4)))
    b = dict(body=(0.0, 0.0), pitch=D(-5), head=(D(-22), 0, D(-4)))
    return _clip(arm, "laugh", [(0, a), (4, b), (8, a), (12, b), (16, a)])


def build_rear(arm):
    """One-shot 30 frames: up on the hind legs, forelegs pawing, and down. The Bloom."""
    up = {FRONT_L: (0.08, 0.3), FRONT_R: (0.05, 0.27), REAR_L: (0.03, 0.0), REAR_R: (0.03, 0.0)}
    up2 = {FRONT_L: (0.05, 0.27), FRONT_R: (0.08, 0.3), REAR_L: (0.03, 0.0), REAR_R: (0.03, 0.0)}
    return _clip(arm, "rear", [
        (0, dict()),
        (5, dict(body=(-0.04, -0.06), pitch=D(4), head=(D(8), 0, 0))),
        (12, dict(body=(-0.08, 0.1), pitch=D(-34), head=(D(8), 0, 0), feet=up)),
        (17, dict(body=(-0.08, 0.11), pitch=D(-36), head=(D(6), 0, 0), feet=up2)),
        (22, dict(body=(-0.07, 0.09), pitch=D(-32), head=(D(10), 0, 0), feet=up)),
        (27, dict(body=(0.0, -0.05), pitch=D(2), head=(D(6), 0, 0))),
        (30, dict()),
    ])


def build_look(arm):
    """One-shot 72 frames: a curious look around, left, right, and back."""
    return _clip(arm, "look", [
        (0, dict()), (14, dict(head=(D(-6), D(-38), D(-6)))), (30, dict(head=(D(-6), D(-38), D(-6)))),
        (44, dict(head=(D(-4), D(36), D(5)))), (60, dict(head=(D(-4), D(36), D(5)))), (72, dict()),
    ])


V1_BUILDERS = [build_trot, build_jump, build_graze, build_sit, build_lie, build_sleep,
               build_startle, build_cower, build_hop, build_struggle, build_talk, build_nod,
               build_shake, build_sad, build_laugh, build_rear, build_look]


STANCE_FRACTION = 0.5   # half the cycle planted, half swinging (see _foot_offset)


def implied_ground_speed(fps, stride=STRIDE, frames=WALK_FRAMES,
                         stance_fraction=STANCE_FRACTION):
    """Ground speed in metres/second that a locomotion clip depicts.

    A planted hoof travels `stride` backwards relative to the body over the stance
    phase, so a body moving at exactly this speed keeps its hooves stuck to the
    ground. Note the divisor is the *stance* duration, not the full cycle: with the
    walk's diagonal pairs each hoof is only planted for half the cycle, and dividing
    by the whole cycle understates the depicted speed by 2x. Any consumer scene that
    translates a pony while playing a locomotion clip must use this speed or she will
    skate; game/systems/gait.gd is the runtime home for both numbers.

    Defaults describe `walk`; pass the GALLOP_* constants for `gallop`.
    """
    cycle_seconds = frames / float(fps)
    return stride / (cycle_seconds * stance_fraction)


def author(arm):
    """Create both clips. Returns them in export order."""
    if arm is None or arm.type != "ARMATURE":
        raise SystemExit(f"--anims needs an armature object, got {arm!r}")
    _require_metric_rig(arm)
    # --- Determinism: force the LEGACY IK solver for the bake.
    #
    # These packs ship `pose.ik_solver = 'ITASC'` (iterative damped least squares,
    # precision 0.005, SDLS). The front IK chain is 1.0668 long against a 1.0537 rest
    # reach -- 98.8% extended, only 0.0131 of slack -- so the knee's bend direction is
    # very nearly under-determined and iTaSC's damping picks whichever solution it
    # lands in first. That was a sleeping problem until export_blend.py started
    # rebinding the hair mesh onto this rig, which perturbed depsgraph evaluation
    # enough to wake it: Fluttershy's idle then flipped a front knee in roughly one
    # export in six (33 degrees on DEF_LowerFrontLeg), i.e. the same .blend produced
    # different .glb files run to run. A pipeline whose whole premise is "assets are
    # regenerated per machine from tracked scripts" cannot have that.
    #
    # LEGACY is Blender's non-iterative solver and is reproducible. It is not a
    # compromise on quality here: every baked channel agrees with the iTaSC solve to
    # within 0.0028 of a quaternion component (~0.3 degrees), front legs included --
    # measured, not assumed -- and 4/4 then 3x3 consecutive exports came out
    # byte-identical. The .blend is never saved back, so this only affects our bake.
    arm.pose.ik_solver = "LEGACY"
    # Guard the exclusion from the *authoring* side too: if a future clip ever keys a
    # mane/tail bone directly, say so here rather than letting the export-side filter
    # quietly throw the keys away and leave the author wondering why nothing moved.
    clashes = [n for n in ANIMATED if is_secondary_motion_bone(n)]
    if clashes:
        raise SystemExit(
            f"ANIMATED includes secondary-motion bones {clashes}; those are simulated "
            f"in Godot (SpringBoneSimulator3D) and must not be keyframed here"
        )
    actions = [build_idle(arm), build_walk(arm), build_gallop(arm)]
    actions += [b(arm) for b in V1_BUILDERS]
    excluded = secondary_motion_bones(arm)
    print(f"SECONDARY_MOTION_BONES {len(excluded)} excluded from bake: {excluded}")
    fps = bpy.context.scene.render.fps
    print(f"WALK_IMPLIED_SPEED {implied_ground_speed(fps):.4f} m/s "
          f"(stride={STRIDE} frames={WALK_FRAMES} fps={fps})")
    print(f"GALLOP_IMPLIED_SPEED "
          f"{implied_ground_speed(fps, GALLOP_STRIDE, GALLOP_FRAMES, GALLOP_STANCE_FRACTION):.4f}"
          f" m/s (stride={GALLOP_STRIDE} frames={GALLOP_FRAMES} "
          f"stance={GALLOP_STANCE_FRACTION:.4f} fps={fps})")
    # Leaving the last-built action as the active one is deliberate: Blender's exporter
    # its default ACTIONS mode still needs a bound animation_data block on the object
    # to consider it animatable at all.
    print("ANIMS_AUTHORED", [a.name for a in actions])
    return actions


if __name__ == "__main__":
    import argparse
    import sys

    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--object", required=True, help="armature object to animate")
    args = p.parse_args(argv)
    author(bpy.data.objects.get(args.object))
