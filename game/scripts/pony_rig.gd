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

## Per-chain tuning, first matching entry wins. Cartoon-pony brief: the hair should
## visibly trail the body's bob, and settle without wobbling like jelly.
##  - `stiffness` pulls a joint back toward its animated rest direction (higher =
##    tighter to the skull, less lag).
##  - `drag` bleeds off velocity (higher = less overshoot/ringing, deader hair).
##  - `gravity` is a constant downward pull.
##  - `radius` is the collision radius; nothing collides yet (no SpringBoneCollision3D
##    nodes are attached), it only matters if Phase 1 adds body collision to stop the
##    mane clipping through the neck on hard turns.
##
## STIFFNESS AND GRAVITY HERE ARE PER UNIT OF BONE LENGTH, not the raw values handed to
## the engine. Godot's spring solver adds `stiffness * delta` as an absolute
## displacement of the joint's tail and then renormalises the segment to its own length,
## so the ANGULAR restoring force a joint feels is `stiffness * delta / length`: at one
## fixed stiffness a long bone is far floppier than a short one. These rigs vary 5x in
## segment length within a single character (Twilight's forelock segments are ~0.11 m,
## her tail's are 0.17-0.57), and Fluttershy's hair is longer again, so a raw number that
## suits the forelock leaves the tail behaving like wet rope: measured, the tail tip's
## swing collapsed from 0.088 to 0.010 m and its phase fell ~250 degrees behind the body
## -- not follow-through, just decoupled. Multiplying by each joint's own rest length
## (see `_configure_setting`) makes one profile behave the same on every chain of every
## character, which is the whole point of a name-pattern-driven rig.
##
## THE SAME PROPERTY MAKES THE WHOLE PROFILE SCALE-INVARIANT, which is why normalizing
## the ponies to 1 unit = 1 metre (Phase 1A task 1, `export_blend.py --scale 0.5`)
## needed no re-tuning of the numbers below. Both the spring force and the gravity the
## solver applies are absolute displacements scaled here by the chain's mean segment
## length, and the inertia term is a position difference, so halving the model halves
## every term in the integrator and the solution is exactly half the old one at every
## timestep -- same angles, same timing. Measured, not assumed: after the rescale
## `hair_lag_test` reported every chain's trail identical to the tick (+40/+19/+9/+5),
## every correlation identical to three decimals, and every displacement column exactly
## half its previous value. Segment lengths in this file are metres; the packs' own
## figures are twice them.
##
## HOW THESE NUMBERS WERE PICKED. `scenes/test/hair_lag_test.gd` measures, per chain,
## how many milliseconds the tip trails the body through a start-and-stop, plus how much
## of the body's bob it still carries, how far gravity has dragged its rest position, and
## how jittery it is. The values below came out of a sweep of roughly a dozen
## combinations across stiffness 3-20 and drag 0.5-0.9, judged against: every chain must
## trail (not lead, not sit rigid), the tips must not buzz, and the static droop must
## stay small. At stiffness 20 the forelock went effectively rigid (0 ms, no
## follow-through at all); at stiffness 3-5 the mane decoupled and kept travelling for
## most of a second after she stopped; drag below ~0.6 let the mane amplify the bob 3x,
## which is the "wobbling like jelly" failure mode. 8 / 0.78 is the plateau where all six
## leaf chains trail and nothing buzzes.
##
## The tail differs only in carrying more gravity and a wider collision radius: it is
## heavier and hangs rather than flicking. Its measured trail is shorter than the mane's
## because it is anchored on the hip, which moves less than the head.
const PROFILES: Array[Dictionary] = [
	{"match": ["tail"], "stiffness": 8.0, "drag": 0.78, "gravity": 0.28, "radius": 0.08},
	{"match": ["mane", "hair", "forelock", "fringe"],
	 "stiffness": 8.0, "drag": 0.78, "gravity": 0.22, "radius": 0.06},
]

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
	for i in chains.size():
		var chain: PackedInt32Array = chains[i]
		sim.set_root_bone_name(i, skeleton.get_bone_name(chain[0]))
		sim.set_end_bone_name(i, skeleton.get_bone_name(chain[chain.size() - 1]))
		# Without an extended tip the *last* bone in the chain is only an endpoint and
		# never rotates -- i.e. the very tip of the mane, the part with the most visible
		# swing, would stay rigid. Extending adds a virtual joint past it, pointed the
		# way the bone already points.
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
		sim.set_end_bone_length(i, _tip_length(skeleton, chain))
		configure_setting(sim, skeleton, i, chain,
			_profile_for(skeleton.get_bone_name(chain[0])))
	return sim


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
		index: int, chain: PackedInt32Array, profile: Dictionary) -> void:
	var scale := _mean_segment(skeleton, chain)
	sim.set_stiffness(index, profile["stiffness"] * scale)
	sim.set_gravity(index, profile["gravity"] * scale)
	sim.set_drag(index, profile["drag"])
	sim.set_radius(index, profile["radius"])


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
## to be inferred: reuse the length of the segment leading into it, i.e. that bone's own
## offset from its parent. These hair chains are close to evenly segmented, so the tip
## comes out the right size, and -- unlike a half-length guess -- it leaves a one-bone
## chain with the same mean segment length as a long one, which matters because
## `configure_setting` scales stiffness by exactly that mean.
static func _tip_length(skeleton: Skeleton3D, chain: PackedInt32Array) -> float:
	return skeleton.get_bone_rest(chain[chain.size() - 1]).origin.length()


static func _profile_for(bone_name: String) -> Dictionary:
	var lowered := bone_name.to_lower()
	for profile in PROFILES:
		for pattern in profile["match"]:
			if lowered.contains(pattern):
				return profile
	return PROFILES[PROFILES.size() - 1]
