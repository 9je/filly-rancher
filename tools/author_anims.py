"""Author `idle` + `walk` Actions onto a CreatorOfPony-family pony rig, headlessly.

Imported by `tools/export_blend.py --anims`; also runnable standalone for debugging:

    tools/bin/blender/blender -b <file>.blend -P tools/author_anims.py -- --object TS_Rig

WHY THIS EXISTS (see task-7-report.md): none of the five CreatorOfPony packs ship a
single character Action (`bpy.data.actions` holds only `CameraAxisAction`, a camera
orbit helper), and no community Action library for this rig family survives on a
loginless, curl-reachable host. So the walk/idle clips are authored here, in script,
so they are reproducible and re-runnable against every pack rather than being a
hand-posed .blend nobody can regenerate.

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
    """
    height = rig_height(arm)
    low, high = METRIC_RIG_HEIGHT_RANGE
    if not low <= height <= high:
        raise SystemExit(
            f"rig {arm.name!r} measures {height:.4f} units tall, outside the metric "
            f"range {METRIC_RIG_HEIGHT_RANGE}. This module's STRIDE/LIFT/BODY_* "
            f"constants are metres (1 unit = 1 metre); author them onto an "
            f"un-normalised rig and the gait will not match the model. Pass "
            f"`--scale {2.05 / height:.3g}` (or thereabouts -- that is what puts this "
            f"rig at the tier-a family's 2.05 m hoof-to-horn height, i.e. ~1.2 m at "
            f"the withers) to tools/export_blend.py; the tier-a packs use --scale 0.5. "
            f"See docs/pipeline.md section 3."
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


STANCE_FRACTION = 0.5   # half the cycle planted, half swinging (see _foot_offset)


def implied_ground_speed(fps):
    """Ground speed in metres/second that the walk clip depicts.

    A planted hoof travels STRIDE backwards relative to the body over the stance
    phase, so a body moving at exactly this speed keeps its hooves stuck to the
    ground. Note the divisor is the *stance* duration, not the full cycle: with
    diagonal pairs, each hoof is only planted for half the cycle, and dividing by
    the whole cycle understates the depicted speed by 2x. Any consumer scene that
    translates a pony while playing `walk` must use this speed or she will skate.
    """
    cycle_seconds = WALK_FRAMES / float(fps)
    return STRIDE / (cycle_seconds * STANCE_FRACTION)


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
    actions = [build_idle(arm), build_walk(arm)]
    excluded = secondary_motion_bones(arm)
    print(f"SECONDARY_MOTION_BONES {len(excluded)} excluded from bake: {excluded}")
    fps = bpy.context.scene.render.fps
    print(f"WALK_IMPLIED_SPEED {implied_ground_speed(fps):.4f} m/s "
          f"(stride={STRIDE} frames={WALK_FRAMES} fps={fps})")
    # Leaving `walk` as the active action is deliberate: Blender's glTF exporter in
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
