class_name PonyRig
extends RefCounted
## Runtime rig setup shared by every pony, applied to a freshly instantiated .glb.
## Static-only helper -- never instantiated; consumers `preload()` this file rather
## than relying on the `class_name` global, because the global class cache lives in the
## gitignored `.godot/` and a fresh clone has not built it yet.
##
## WHY THIS IS A SCRIPT AND NOT A HAND-EDITED SCENE. `game/assets/converted/` is
## gitignored: the .glb files are regenerated from `assets_raw/` on every machine by
## `tools/export_blend.py` (docs/pipeline.md section 3). Anything hand-added inside an
## imported .glb's node tree -- or into its .import sidecar -- evaporates on the next
## regeneration or the next fresh clone. So the SpringBoneSimulator3D that gives the
## mane and tail their follow-through is *built in code, at spawn time*, from tracked
## source. Phase 1 spawns a pony with `PonyRig.spawn("twilight")` (or drops a
## `scenes/characters/pony.tscn` and sets `character`) and gets correct hair for free;
## nobody has to remember a manual step.
##
## THE OTHER HALF OF THE FIX LIVES IN THE EXPORTER. The clips must not keyframe these
## bones. An AnimationPlayer track and a SkeletonModifier3D write the same bone pose
## and the animation wins, so a rest-pose track on DEF_Mane1-3 -- which is exactly what
## the exporter's bake-every-bone mode emits -- silently overwrites the simulation
## every frame. `tools/author_anims.py`'s SECONDARY_MOTION_PATTERNS is the matching
## exclusion list; the two must agree. See docs/pipeline.md section 6.

## Bone-name substrings identifying secondary-motion (hair) chains, matched
## case-insensitively. Keep in sync with SECONDARY_MOTION_PATTERNS in
## tools/author_anims.py -- that list decides which bones ship unkeyframed, this one
## decides which bones get simulated, and a bone in one list but not the other either
## goes limp (keyframed but simulated: animation wins, no follow-through) or freezes
## (excluded but not simulated: hair welded to the skull).
const HAIR_PATTERNS: Array[String] = ["mane", "tail", "hair", "forelock", "fringe"]

## The CreatorOfPony rigs carry two parallel copies of every hair chain: `DEF_*`,
## which the hair mesh's vertex groups actually weight to, and `CON_*`, an animator
## control layer that in the source .blend drove spline-IK curves. Those curves do not
## survive glTF, so after export the CON_ bones deform nothing at all -- verified by
## decoding the exported mesh's JOINTS_0/WEIGHTS_0: 100% of TS_Hair's weight sits on
## DEF_Head plus DEF_Mane*/DEF_Hair*/DEF_Tail*, and exactly 0% on any CON_ bone.
## Simulating them would burn time and produce nothing visible, so prefer the deform
## layer when it exists and fall back to whatever matched if a future rig has no DEF_.
const DEFORM_PREFIX := "DEF_"

## Per-chain tuning, first matching entry wins on the chain root's bone name. Cartoon-
## pony brief: the hair should visibly trail the body's bob, and settle without wobbling
## like jelly.
##  - `stiffness` pulls a joint back toward its animated rest direction (higher =
##    tighter to the skull, less trail).
##  - `drag` bleeds off velocity (higher = less overshoot/ringing, deader hair).
##  - `gravity` is a constant downward pull.
##  - `radius` is the collision radius. Nothing collides yet -- no SpringBoneCollision3D
##    nodes are attached -- so it is currently inert; it matters once Phase 1 adds body
##    collision to stop the mane clipping through the neck on hard turns.
##
## ALL FOUR ARE PER UNIT OF BONE LENGTH, not the raw values handed to the engine.
## Godot's spring solver adds `stiffness * delta` as an absolute displacement of the
## joint's tail and then renormalises the segment to its own length, so the ANGULAR
## restoring force a joint feels is `stiffness * delta / length`: at one fixed stiffness a
## long bone is far floppier than a short one. These rigs vary 5x in segment length within
## a single character (Twilight's forelock segments are ~0.11 m, her tail's 0.17-0.57) and
## Fluttershy's hair is longer again, so a raw number that suits the forelock leaves the
## tail behaving like wet rope: measured, the tail tip's swing collapsed from 0.088 to
## 0.010 m and its phase fell ~250 degrees behind the body -- not follow-through, just
## decoupled. `configure_setting` multiplies by the chain's mean segment length so one
## profile behaves the same on every chain of every character, which is the whole point of
## a name-pattern-driven rig.
##
## `radius` is scaled here too, and that is a deliberate correction rather than symmetry
## for its own sake. Godot applies radius as a raw absolute length during collision
## resolution with no normalisation of any kind, so an unscaled value silently stopped
## being scale-invariant the moment Phase 1A halved every model -- a radius tuned at pack
## scale is 2x too fat on a metre-scale pony. Nothing reads it today, which is exactly why
## it had to be fixed now: the next session to attach collision shapes would have
## inherited a wrong number while reading a comment promising the profile was
## scale-invariant. The values below therefore mean "strand radius per unit of segment
## length" and work out at roughly 0.020 m for a mane lock and 0.031 m for a tail lock on
## the shipped 1.163 m-withers ponies. Unverified against actual collision -- when Phase 1
## adds SpringBoneCollision3D shapes, check these before trusting them.
##
## SCALE INVARIANCE. With all four scaled by segment length, normalizing the ponies to
## 1 unit = 1 metre (Phase 1A task 1, `export_blend.py --scale 0.5`) needs no re-tuning.
## The spring force and the gravity the solver applies are absolute displacements scaled
## here by the chain's mean segment length, and the inertia term is a position difference,
## so halving the model halves every term in the integrator and the solution is exactly
## half the old one at every timestep -- same angles, same timing. Measured, not assumed:
## after the rescale `hair_lag_test` reported every chain's trail identical to the tick,
## every correlation identical to three decimals, and every displacement column exactly
## half its previous value. Segment lengths quoted in this file are metres.
##
## HOW THESE NUMBERS WERE PICKED. `scenes/test/hair_lag_test.gd` measures, per chain, how
## many milliseconds the tip trails the body through a start-and-stop, how much of the
## body's bob it still carries, how much swing it adds beyond a rigid extension of its own
## anchor, and how jittery it is. Bob retention is the number that decides whether the
## hair reads as attached; correlation lag on its own is not, and an earlier revision of
## this file shipped values that scored a fine-looking "+667 ms trail" while the mane root
## kept 14% of the head's bob -- a detached wig. The current values come from a sweep of
## ~20 combinations across stiffness 8-40 and drag 0.55-0.96 judged on all four metrics at
## once. Landmarks from that sweep, all measured on Twilight:
##
##  - mane 8 / drag 0.78: mane root keeps 14% of the bob and its correlation never peaks
##    inside the search window -- decoupled, and the "trail" is unmeasurable.
##  - mane 16-32 / drag 0.78-0.80: the 5-joint mane chain resonates, 112%-147% retention.
##  - drag 0.55-0.6 anywhere: the mane amplifies the bob up to 3x -- the jelly failure.
##  - mane 22 / drag 0.96: 105% retention, a clean interior correlation peak at +15 ticks,
##    prominence 0.51. High drag is what suppresses the resonance without stiffening the
##    chain into rigidity.
##  - forelock at the mane's stiffness goes rigid (0 ms trail); it is a short light chain
##    of bangs and wants roughly half. Hence its own entry -- `DEF_Hair*` is a different
##    bone-name pattern from `DEF_Mane*`, so this costs no per-character data.
##  - tail 20+: leads rather than trails; tail 10: root down to 34%. 14 sits between.
##
## The tail also carries more gravity and a wider radius: it is heavier and hangs rather
## than flicking. Its measured trail is shorter than the mane's because it is anchored on
## the hip, which moves less than the head.
const PROFILES: Array[Dictionary] = [
	{"match": ["tail"],
	 "stiffness": 14.0, "drag": 0.88, "gravity": 0.28, "radius": 0.15},
	{"match": ["mane"],
	 "stiffness": 22.0, "drag": 0.96, "gravity": 0.22, "radius": 0.12},
	{"match": ["hair", "forelock", "fringe"],
	 "stiffness": 10.0, "drag": 0.86, "gravity": 0.22, "radius": 0.12},
]

## Stiffness multiplier applied once per spring stage stacked above a chain (depth 1 is a
## chain whose root hangs off a bone inside another chain, because SpringBoneSimulator3D
## settings must be straight lines and a forked lock of hair has to be cut up).
##
## 1.0 -- i.e. no correction -- and that is a measured result, not an omission. Twilight's
## DEF_Mane1-6 and DEF_Mane3-2 swing 175% and 201% of the body's bob, which looks like a
## branch chain resonating on top of an already-swinging anchor, and this constant existed
## to stiffen it out. It does not work, because that is not what is happening: re-running
## the manoeuvre with those chains pinned at 100000x stiffness -- unable to flex at all
## relative to their anchor -- still leaves them at 186% and 204%. The swing is lever
## geometry. The mane's follow-through is a ROTATION of DEF_Mane1-5, and a point further
## out along the strand traces a proportionally bigger arc; a rigid extension does it too.
## No stiffness or drag removes it without removing the follow-through itself.
##
## Kept as a named constant, at the value the evidence supports, so the next person to
## look at those 200% numbers finds the experiment already done. `hair_lag_test.gd`'s
## `self_gain` column is the metric that actually isolates a chain's own springiness
## (0.91-0.95 for these two, i.e. they add nothing of their own), and its `stacked=<x>`
## override re-runs the pinning experiment on demand.
const STACKED_CHAIN_STIFFNESS := 1.0

## Chain length, in joints, that PROFILES' stiffness is calibrated for -- and the exponent
## by which a LONGER chain's stiffness is raised. Together: a chain of `n` joints gets
## `stiffness * max(1, n / SPAN_REFERENCE_JOINTS) ** SPAN_EXPONENT`.
##
## WHY. `configure_setting` already normalises by segment LENGTH (see PROFILES), which
## makes one profile behave the same on a long bone and a short one. It does nothing about
## how MANY of them are strung together, and that is a second, independent multiplier on
## how far the tip ends up from where it should be. Each joint in a spring chain lags its
## parent by some small angle; the tip's displacement is the sum of every one of those
## angles multiplied by its own distance out to the tip, so for a chain of n roughly equal
## segments the tip error grows like n squared even though each joint is behaving
## identically. Twilight's longest chain is 5 joints and Rainbow Dash's is 4 -- the whole
## sweep in PROFILES was run inside that band. **Fluttershy's are 8, 8 and 10**, and at 10
## joints the same per-joint lag puts her tail tip four times further out of place.
##
## That is exactly what the owner saw. On a screenshot of Fluttershy galloping, her mane
## and tail streamed straight out horizontally behind her, a full body length of hair
## flying like a flag: "fluttershy hair flowing crazy", and, on the mechanism, "there's
## some hair gravity that looks weird -- I like the direction but poor implementation."
## The measurements agreed and nobody had read them that way: her forelock tip sat
## `offset=0.236 m` out of place on a 1.16 m-withers pony and its correlation never peaked
## inside the search window at all -- the signature of hair that never catches up, which
## docs/notes-hair-sim.md section 10.1 had already named for Twilight's mane.
##
## ONE-SIDED ON PURPOSE -- `max(1, ...)`, so this only ever STIFFENS. Below the reference
## the correction would slacken chains that are already measured good, and Twilight's
## certified `HAIRLAG_OK` tuning is built out of 1-to-5-joint chains: the whole of her rig
## and the whole of Rainbow Dash's sit at or under the reference and come out bit-identical
## to before this constant existed. The defect being fixed lives entirely at the long end,
## and this is the smallest change that reaches it.
##
## Gravity is deliberately NOT scaled alongside. The static droop a chain settles into is
## the ratio of gravity to stiffness, so raising stiffness alone pulls the droop back in
## proportion -- one knob for both halves of the defect (hair flung out while moving, hair
## hanging too far out while still) instead of two that have to be kept in step.
##
## THE EXPONENT IS 2.5 AND THE GEOMETRY ABOVE ONLY PREDICTS 2 -- the extra half is
## empirical and is flagged as such. Swept at 1.0 / 1.5 / 2.0 / 2.5 / 3.0 through
## `hair_lag_test.gd`'s new `span=<ref>,<exp>` hook AND rendered at each through
## `scenes/test/visual_review.tscn` (`mode=motion clip=gallop`, against the `tag=rigid`
## reference), because the gate alone cannot answer this: it only ever drives a 0.66 m/s
## walk ramp and the defect is at the player's 4.0 m/s gallop. At 2.0 Fluttershy's mane is
## still swept back over her spine; at 2.5 it hangs and trails; at 3.0 she is
## indistinguishable from the rigid reference, i.e. the follow-through is gone. The reason
## the joint count alone falls short is that her SEGMENTS are ~1.5x longer than the
## reference chain's too, so her chains are 3x Twilight's in metres as well as 2x in
## joints -- a length-based reference would model that exactly but would give up the
## scale-invariance section 9 of docs/notes-hair-sim.md paid for. See section 11 there.
const SPAN_REFERENCE_JOINTS := 5
const SPAN_EXPONENT := 2.5

const SIMULATOR_NAME := "HairSpring"
const PONY_DIR := "res://assets/converted/ponies/"


## Load `<character>.glb`, instantiate it and give it working hair. The one call
## Phase 1 needs.
static func spawn(character: String) -> Node3D:
	var scene: PackedScene = load(PONY_DIR + character + ".glb")
	if scene == null:
		push_error("PonyRig: no such pony '%s' in %s" % [character, PONY_DIR])
		return null
	var pony: Node3D = scene.instantiate()
	attach_hair_simulation(pony)
	return pony


## Build and attach the mane/tail SpringBoneSimulator3D under `pony`'s Skeleton3D.
## Idempotent: calling it twice on the same instance is a no-op. Returns the
## simulator, or null if the model has no skeleton or no hair chains.
static func attach_hair_simulation(pony: Node3D) -> SpringBoneSimulator3D:
	var skeleton: Skeleton3D = pony.find_child("Skeleton3D", true, false)
	if skeleton == null:
		push_warning("PonyRig: %s has no Skeleton3D, no hair simulation attached" % pony.name)
		return null
	var existing := skeleton.get_node_or_null(NodePath(SIMULATOR_NAME))
	if existing is SpringBoneSimulator3D:
		return existing

	var chains := hair_chains(skeleton)
	if chains.is_empty():
		push_warning("PonyRig: %s has no hair bones matching %s" % [pony.name, HAIR_PATTERNS])
		return null

	var sim := SpringBoneSimulator3D.new()
	sim.name = SIMULATOR_NAME
	# Parent it BEFORE configuring: a SkeletonModifier3D resolves bone *names* to bone
	# indices against `get_skeleton()`, which is null until it is in the tree, so a
	# simulator configured first and parented second silently ends up with unresolved
	# chains and does exactly nothing.
	skeleton.add_child(sim)
	sim.setting_count = chains.size()
	var depths := chain_depths(skeleton, chains)
	for i in chains.size():
		var chain: PackedInt32Array = chains[i]
		sim.set_root_bone_name(i, skeleton.get_bone_name(chain[0]))
		sim.set_end_bone_name(i, skeleton.get_bone_name(chain[chain.size() - 1]))
		# Without an extended tip the *last* bone in the chain is only an endpoint and
		# never rotates -- i.e. the very tip of the mane, the part with the most visible
		# swing, would stay rigid. Extending adds a virtual joint past it, pointed the
		# way the bone itself points.
		#
		# PLUS_Y, not FROM_PARENT. Blender puts a bone's own axis along +Y and the glTF
		# export preserves it: measured across all three packs, every genuine hair segment
		# direction (a child bone's rest offset, in its parent's frame) has
		# dot(offset, +Y) = 1.0000 exactly -- 13 segments on Twilight, 15 on Rainbow Dash,
		# 23 on Fluttershy. FROM_PARENT agrees with that everywhere EXCEPT the bones this
		# rig branches on, where the rest offset is a detour across to a separate lock of
		# hair rather than a step along one: Rainbow Dash's DEF_Tail2 offset points 46 deg
		# off its own bone axis (dot 0.691), DEF_Tail4 43 deg, DEF_Mane2 34 deg. Since a
		# one-bone chain has no other joint, that direction IS the whole simulated axis for
		# it, so FROM_PARENT had those chains swinging across the hair instead of along it.
		# 10 of Twilight's and Rainbow Dash's 27 chains are one-bone; this is the difference
		# between them working and not.
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SpringBoneSimulator3D.BONE_DIRECTION_PLUS_Y)
		sim.set_end_bone_length(i, _tip_length(skeleton, chain))
		configure_setting(sim, skeleton, i, chain,
			profile_for(skeleton.get_bone_name(chain[0])), depths[i])
	return sim


## How many simulated chains sit between each chain and the animated skeleton. 0 means
## the chain hangs directly off a bone the clips still drive (DEF_Head, DEF_Hip); 1 means
## its root's parent is inside another hair chain, so its anchor is itself a spring.
static func chain_depths(skeleton: Skeleton3D, chains: Array) -> PackedInt32Array:
	var owner_chain := {}
	for i in chains.size():
		for bone in chains[i]:
			owner_chain[bone] = i
	var depths := PackedInt32Array()
	depths.resize(chains.size())
	for i in chains.size():
		var depth := 0
		var bone: int = chains[i][0]
		# Walk up chain roots until one is anchored on a bone no chain owns. Bounded by
		# the chain count, so a malformed cycle cannot hang the spawn.
		while depth < chains.size():
			var parent := skeleton.get_bone_parent(bone)
			if not owner_chain.has(parent):
				break
			depth += 1
			bone = chains[owner_chain[parent]][0]
		depths[i] = depth
	return depths


## Write one PROFILES entry onto simulator setting `index`, converting its per-unit-
## length stiffness and gravity into the absolute values Godot wants by scaling with the
## chain's mean segment length. Split out so a tuning sweep
## (scenes/test/hair_lag_test.gd) can re-apply a candidate profile to a live simulator
## without duplicating the conversion and measuring the wrong thing.
##
## Uses the whole-chain setters, NOT `set_individual_config` + `set_joint_stiffness`,
## even though per-joint values would follow each segment's own length exactly. A
## simulator's joint array does not exist until it is inside the scene tree
## (`get_joint_count()` is 0 beforehand, and every `set_joint_*` call is dropped), and
## `spawn()` deliberately configures the pony BEFORE the caller adds it to the tree so
## there is no window where a pony is visible with unsimulated hair. Worse, once the
## joints are created on tree entry they come up at the engine defaults, so a simulator
## flagged individual ends up ignoring the shared values too -- stiffness 1.0, drag 0.0,
## hair like a whip. Measured and confirmed, not guessed. Chain-mean scaling keeps the
## configuration in the setters that survive, and within one chain the segments are
## close enough (Twilight's tail: 0.17 / 0.23 / 0.21 m) for the difference not to show.
static func configure_setting(sim: SpringBoneSimulator3D, skeleton: Skeleton3D,
		index: int, chain: PackedInt32Array, profile: Dictionary, depth: int = 0,
		stacked_factor: float = STACKED_CHAIN_STIFFNESS,
		span_reference: int = SPAN_REFERENCE_JOINTS,
		span_exponent: float = SPAN_EXPONENT) -> void:
	var scale := _mean_segment(skeleton, chain)
	sim.set_stiffness(index, profile["stiffness"] * scale
		* span_factor(chain.size(), span_reference, span_exponent)
		* pow(stacked_factor, depth))
	sim.set_gravity(index, profile["gravity"] * scale)
	sim.set_drag(index, profile["drag"])
	sim.set_radius(index, profile["radius"] * scale)


## Stiffness multiplier for a chain of `joints` joints -- see SPAN_REFERENCE_JOINTS.
## 1.0 for anything at or under the reference, so it can only ever stiffen.
static func span_factor(joints: int, reference: int = SPAN_REFERENCE_JOINTS,
		exponent: float = SPAN_EXPONENT) -> float:
	if reference <= 0 or joints <= reference:
		return 1.0
	return pow(float(joints) / float(reference), exponent)


## Local-space offset from a chain's end bone to the virtual tip the simulator extends
## past it (`BONE_DIRECTION_FROM_PARENT`, `_tip_length` long) -- i.e. the actual end of
## that lock of hair.
##
## Exposed because anything measuring this rig has to sample the tip, and sampling the
## end bone's global-pose ORIGIN instead is a trap: a bone's origin is placed entirely by
## its ancestors, and its own rotation moves only what hangs off it. The end bone has
## nothing hanging off it, so for a ONE-bone chain the origin is a point that chain's
## simulation cannot move at all -- change its stiffness by 3x and the sampled trace does
## not shift by a float. `scenes/test/hair_lag_test.gd` measured exactly that before this
## was noticed.
## Must stay in step with the `BONE_DIRECTION_PLUS_Y` passed to the simulator above: this
## is the same virtual tip, so it is +Y in the end bone's own frame, one segment long.
static func tip_offset(skeleton: Skeleton3D, chain: PackedInt32Array) -> Vector3:
	return Vector3.UP * _tip_length(skeleton, chain)


## Mean rest length of the chain's segments. glTF bones carry no length of their own,
## only an offset from their parent, so a segment's length is the next bone's offset --
## plus the extended virtual tip for the last one.
static func _mean_segment(skeleton: Skeleton3D, chain: PackedInt32Array) -> float:
	var total := _tip_length(skeleton, chain)
	for j in range(1, chain.size()):
		total += skeleton.get_bone_rest(chain[j]).origin.length()
	return total / float(chain.size())


## Group every simulated hair bone into linear parent->child chains.
##
## A chain starts at a hair bone whose parent is not a hair bone (mane and tail roots,
## hanging off DEF_Head / DEF_Hip) or whose parent has more than one hair child (a
## branch point -- Twilight's DEF_Mane1-5 forks into DEF_Mane1-6 and DEF_Mane3-1). It
## then follows single-child links until the bone runs out of hair children or forks
## again. That partition is exactly what SpringBoneSimulator3D wants: its settings take
## a root and an end bone on one unbroken ancestor line, and no bone may appear in two
## settings or the two would fight over its pose every frame.
static func hair_chains(skeleton: Skeleton3D) -> Array:
	var hair := _hair_bones(skeleton)
	var hair_children := {}
	for bone in hair:
		hair_children[bone] = PackedInt32Array()
	for bone in hair:
		var parent := skeleton.get_bone_parent(bone)
		if hair_children.has(parent):
			hair_children[parent].append(bone)

	var chains: Array = []
	for bone in hair:
		var parent := skeleton.get_bone_parent(bone)
		var is_start: bool = not hair_children.has(parent) or hair_children[parent].size() > 1
		if not is_start:
			continue
		var chain := PackedInt32Array([bone])
		var current := bone
		while hair_children[current].size() == 1:
			current = hair_children[current][0]
			chain.append(current)
		chains.append(chain)
	return chains


## True for any bone belonging to a secondary-motion chain, on any rig layer.
static func is_hair_bone(bone_name: String) -> bool:
	var lowered := bone_name.to_lower()
	for pattern in HAIR_PATTERNS:
		if lowered.contains(pattern):
			return true
	return false


static func _hair_bones(skeleton: Skeleton3D) -> PackedInt32Array:
	var matched := PackedInt32Array()
	var deform := PackedInt32Array()
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		if not is_hair_bone(bone_name):
			continue
		matched.append(bone)
		if bone_name.begins_with(DEFORM_PREFIX):
			deform.append(bone)
	return deform if not deform.is_empty() else matched


## Length of the virtual joint appended past the chain's end bone. glTF bones carry no
## length of their own, only an offset from their parent, so the end bone's "length" has
## to be inferred.
##
## For a chain of two or more bones the end bone's parent IS the previous bone in the
## chain, so its rest offset is genuinely the last segment's length, and reusing it for
## the tip is right: these chains are close to evenly segmented.
##
## For a ONE-BONE chain that reasoning collapses, and an earlier version of this file got
## it wrong. A single bone's rest offset measures the gap from its parent's head to its
## own head -- where the chain *starts*, not how long it is -- and for a chain that
## branches off mid-hair that gap is a whole detour. Twilight's `DEF_Tail4` forks off
## `DEF_Tail1-5` 0.564 m away while her real tail segments are ~0.21 m, so it was handed
## a 2.7x oversized "segment" and, through `configure_setting`'s length scaling, 2.7x its
## neighbours' stiffness. Rainbow Dash's fanned tail has 8 such chains out of 19, which is
## why several of hers would not resolve to a clean trail at all. Fall back to the
## character's median hair segment instead: a one-bone lock of hair is, to a good
## approximation, one segment long, whatever detour its bone origin sits at.
static func _tip_length(skeleton: Skeleton3D, chain: PackedInt32Array) -> float:
	if chain.size() == 1:
		return _median_hair_segment(skeleton)
	return skeleton.get_bone_rest(chain[chain.size() - 1]).origin.length()


## Median length of the character's genuine hair segments -- every hair bone whose parent
## is also a hair bone, whose rest offset is therefore a real bone-to-bone span. Median
## rather than mean so one long branch detour cannot drag the estimate. Falls back to the
## whole skeleton's median bone offset for a hypothetical rig whose hair is all one-bone
## chains, so this never returns 0 and collapses a spring to nothing.
static func _median_hair_segment(skeleton: Skeleton3D) -> float:
	var segments: Array[float] = []
	for bone in _hair_bones(skeleton):
		var parent := skeleton.get_bone_parent(bone)
		if parent >= 0 and is_hair_bone(skeleton.get_bone_name(parent)):
			segments.append(skeleton.get_bone_rest(bone).origin.length())
	if segments.is_empty():
		for bone in skeleton.get_bone_count():
			var offset := skeleton.get_bone_rest(bone).origin.length()
			if offset > 0.0:
				segments.append(offset)
	if segments.is_empty():
		return 1.0
	segments.sort()
	return segments[segments.size() / 2]


## The PROFILES entry governing a chain rooted at `bone_name`. Public so a tuning
## sweep can re-apply the shipped profile after trying a candidate.
static func profile_for(bone_name: String) -> Dictionary:
	var lowered := bone_name.to_lower()
	for profile in PROFILES:
		for pattern in profile["match"]:
			if lowered.contains(pattern):
				return profile
	return PROFILES[PROFILES.size() - 1]
