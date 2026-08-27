extends Node3D
## Objective check that the mane and tail TRAIL the body instead of moving in lockstep.
##
## "The hair looks right now" is not something a headless run can assert, so this
## measures it. It runs one scripted manoeuvre twice, sampling the world position of the
## tip of every hair chain every physics tick:
##
##   pass 1  simulator influence 0  -> the pre-fix behaviour. Hair is welded rigidly to
##                                     the skull, so the tip is a rigid copy of the body:
##                                     lockstep, by construction.
##   pass 2  simulator influence 1  -> the fix.
##
## The manoeuvre: Twilight plays `walk` on the spot to settle the springs, then sets off
## forwards at the clip's own ground speed for one second, then stops dead. Per chain,
## the two passes' traces along the travel axis are cross-correlated to find the shift
## that lines them up: pass 2 is the same bone making the same journey, so if the springs
## work it is pass 1's trace ARRIVING LATE, and that shift in milliseconds is the
## follow-through.
##
## WHY A ONE-SHOT RAMP AND NOT THE WALK BOB. The obvious experiment -- walk on the spot
## and correlate the bob -- cannot answer the question. BODY_BOB runs at twice the gait
## frequency, i.e. one period every 10 clip frames = 25 physics ticks, so a lag is only
## identifiable modulo 25 ticks and a 19-tick trail is indistinguishable from a 6-tick
## lead. Measured that way the tail read as "-8 ticks", which was not a lead at all, just
## an alias. A single start-and-stop is aperiodic, so its correlation peak means exactly
## one thing. The bob is still worth measuring, but as amplitude and smoothness rather
## than phase: the vertical columns below report how much of the body's bob each tip
## still carries and how jittery it is.
##
## ONE ENGINE FACT THIS DEPENDS ON: a skeleton modifier's output is NOT visible to
## `get_bone_global_pose()` called from `_process`/`_physics_process`. Skeleton3D
## restores the pre-modifier pose after running its modifier stack and any later query
## recomputes global poses from that restored pose, so sampling from `_physics_process`
## reads the raw animation and reports zero difference no matter how well the springs
## work. Sample from the `skeleton_updated` signal, which fires inside the update while
## the modified pose is live. (`modification_processed` fires there too, but it reports
## the modifier's raw output *before* `influence` is blended in, so the influence=0 pass
## would not actually be a baseline.)

const PonyRigScript := preload("res://scripts/pony_rig.gd")

## Default subject. Override with `-- character=<name>` to check another pack's chains
## are found and behave; the gate itself always runs Twilight.
const CHARACTER := "twilight"
const SETTLE_TICKS := 150       # 2.5 s of walking on the spot; springs reach steady state
const TRAVEL_TICKS := 60        # 1 s of travel
const COAST_TICKS := 150        # 2.5 s standing still again, long enough for the hair to
                                # catch up and settle
const SAMPLE_TICKS := TRAVEL_TICKS + COAST_TICKS
const LAG_WINDOW := 40          # +/- ticks searched; the drive is aperiodic so this can
                                # comfortably exceed one bob period. Generous on purpose:
                                # a chain that saturates the window is not "very good at
                                # trailing", it is hair that never catches up at all.
## The bob and wobble columns are measured over the last stretch of the manoeuvre only,
## once the hair has finished swinging back from the stop -- otherwise that one-off
## settle transient swamps the 2.4 Hz bob they are meant to describe.
const BOB_WINDOW := 90
const TICK_SECONDS := 1.0 / 60.0
## Matches walk_test.gd's WALK_SPEED, itself derived from author_anims.py's STRIDE: the
## speed the walk clip actually depicts. Travelling at some other speed would be a
## different experiment rather than a wrong one, but this keeps the manoeuvre to
## something a player would really see.
const TRAVEL_SPEED := 0.66
## Assets face -Z (export_blend.py --rotate-z 180 bakes in Godot's forward convention),
## so this is "forwards" and the hair should stream out behind her.
const TRAVEL_DIRECTION := Vector3(0, 0, -1)
## A tip has to depart from its rigid path by at least this much (mean 3D distance, in
## metres, against a 2.05 m-tall pony -- 1 unit = 1 metre, docs/pipeline.md section 3)
## before a lag number means anything. Halved along with the models when they were
## normalised to metric scale, so it stays the same fraction of body height.
const MIN_DEVIATION := 0.0025

var pony: Node3D
var skeleton: Skeleton3D
var simulator: SpringBoneSimulator3D
var animation: AnimationPlayer
var tip_bones: Array[int] = []
var chain_names: Array[String] = []
var leaf_chain: Array[bool] = []

var ticks := 0
var samples: Array = []         # per chain: Array[Vector3], current pass
var rigid: Array = []           # per chain: Array[Vector3], pass 1
var simulator_on := false
var finished := false


func _ready() -> void:
	var character := CHARACTER
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("character="):
			character = arg.split("=")[1]
	print("SUBJECT ", character)
	pony = PonyRigScript.spawn(character)
	add_child(pony)
	skeleton = pony.find_child("Skeleton3D", true, false)
	simulator = skeleton.get_node_or_null(NodePath(PonyRigScript.SIMULATOR_NAME))
	assert(simulator != null, "no SpringBoneSimulator3D attached")

	# Drive the animation and the modifier stack off the physics tick so every sample is
	# exactly 1/60 s apart: the numbers below are then reproducible run to run instead of
	# depending on how fast this machine happens to spin the main loop.
	animation = pony.find_child("AnimationPlayer", true, false)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	animation.play("walk")

	_apply_overrides()
	var chains := PonyRigScript.hair_chains(skeleton)
	var branch_points := {}
	for chain in chains:
		branch_points[skeleton.get_bone_parent(chain[0])] = true
	for i in chains.size():
		var chain: PackedInt32Array = chains[i]
		var tip: int = chain[chain.size() - 1]
		var leaf: bool = not branch_points.has(tip)
		print("CHAIN %-14s root=%-14s anchor=%-12s joints=%d leaf=%s stiffness=%.2f drag=%.2f gravity=%.2f"
			% [skeleton.get_bone_name(tip), simulator.get_root_bone_name(i),
			   skeleton.get_bone_name(_body_anchor(chain[0])), simulator.get_joint_count(i),
			   leaf, simulator.get_stiffness(i), simulator.get_drag(i),
			   simulator.get_gravity(i)])
		# Every chain is measured, but only the LEAVES count towards the verdict: a chain
		# that stops at a branch point (Twilight's mane forks at DEF_Mane1-5) is an
		# interior segment, not something an audience sees swing. The interior rows are
		# printed anyway because they drive the leaves -- when a leaf misbehaves, the
		# interior chain feeding it is usually why.
		tip_bones.append(tip)
		chain_names.append(skeleton.get_bone_name(tip))
		leaf_chain.append(leaf)
	print("CHAINS ", chains.size())

	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_begin_pass(false)


## Walk up the skeleton until we leave the hair, i.e. reach a bone the clips still
## animate: DEF_Head for the mane and forelock, DEF_Hip for the tail. Reporting only.
func _body_anchor(bone: int) -> int:
	var current := skeleton.get_bone_parent(bone)
	while current >= 0 and PonyRigScript.is_hair_bone(skeleton.get_bone_name(current)):
		current = skeleton.get_bone_parent(current)
	return current


## Tuning sweep hook. With no arguments the committed PonyRig profiles are measured,
## which is what the headless gate runs. To try other values without editing tracked
## code, pass `<bone-name-substring>=stiffness,drag,gravity` after a bare `--`:
##   tools/bin/godot --headless --path game scenes/test/hair_lag_test.tscn -- \
##       mane=18,0.6,0.25 hair=18,0.6,0.25 tail=18,0.6,0.25
## `character=<name>` is handled separately, in _ready().
func _apply_overrides() -> void:
	var chains := PonyRigScript.hair_chains(skeleton)
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() != 2:
			continue
		var values := parts[1].split(",")
		if values.size() != 3:
			continue
		var hits := 0
		for i in simulator.setting_count:
			if not simulator.get_root_bone_name(i).to_lower().contains(parts[0]):
				continue
			# Route through PonyRig so the sweep exercises the same per-unit-length
			# conversion the shipped profiles get, rather than a second code path.
			PonyRigScript.configure_setting(simulator, skeleton, i, chains[i], {
				"stiffness": float(values[0]),
				"drag": float(values[1]),
				"gravity": float(values[2]),
				"radius": simulator.get_radius(i),
			})
			hits += 1
		print("OVERRIDE ", arg, " chains=", hits)


func _begin_pass(with_simulator: bool) -> void:
	simulator_on = with_simulator
	simulator.influence = 1.0 if with_simulator else 0.0
	simulator.reset()
	pony.position = Vector3.ZERO
	# Restart the clip so both passes see an identical drive, sample for sample.
	animation.seek(0.0, true)
	ticks = 0
	samples = []
	for i in tip_bones.size():
		samples.append([] as Array[Vector3])


## Runs before the skeleton's own physics-tick update (this node is the scene root and
## its notifications are delivered before its descendants'), so the pose the springs see
## and the pose sampled below both correspond to this tick's position.
func _physics_process(delta: float) -> void:
	if finished:
		return
	if ticks > SETTLE_TICKS and ticks <= SETTLE_TICKS + TRAVEL_TICKS:
		pony.position += TRAVEL_DIRECTION * TRAVEL_SPEED * delta


func _on_skeleton_updated() -> void:
	if finished:
		return
	ticks += 1
	if ticks <= SETTLE_TICKS:
		return
	for i in tip_bones.size():
		samples[i].append(_bone_origin(tip_bones[i]))
	if samples[0].size() >= SAMPLE_TICKS:
		_finish_pass()


func _bone_origin(bone: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin


func _finish_pass() -> void:
	if not simulator_on:
		rigid = samples
		_begin_pass(true)
		return
	finished = true
	_report()


## Normalised cross-correlation of two equal-length traces over a signed tick window,
## projected onto `axis`. Both are mean-subtracted first, so a constant offset -- the
## hair hanging lower once gravity is simulated, say -- costs nothing; only timing counts.
func _best_lag(reference: Array, delayed: Array, axis: Vector3) -> Dictionary:
	var best_lag := 0
	var best_corr := -2.0
	var count := reference.size() - 2 * LAG_WINDOW
	for lag in range(-LAG_WINDOW, LAG_WINDOW + 1):
		var a: Array[float] = []
		var b: Array[float] = []
		for i in count:
			a.append(reference[i + LAG_WINDOW].dot(axis))
			b.append(delayed[i + LAG_WINDOW + lag].dot(axis))
		var corr := _correlation(a, b)
		if corr > best_corr:
			best_corr = corr
			best_lag = lag
	return {"lag": best_lag, "corr": best_corr}


func _correlation(a: Array[float], b: Array[float]) -> float:
	var n := a.size()
	var mean_a := 0.0
	var mean_b := 0.0
	for i in n:
		mean_a += a[i]
		mean_b += b[i]
	mean_a /= n
	mean_b /= n
	var num := 0.0
	var da := 0.0
	var db := 0.0
	for i in n:
		var x := a[i] - mean_a
		var y := b[i] - mean_b
		num += x * y
		da += x * x
		db += y * y
	if da <= 0.0 or db <= 0.0:
		return 0.0
	return num / sqrt(da * db)


func _mean(values: Array) -> Vector3:
	var total := Vector3.ZERO
	for v in values:
		total += v
	return total / float(values.size())


## Two different "how far off the rigid path is it" numbers, which must not be conflated.
## `sag` is how far the tip's AVERAGE position moved once gravity got hold of it -- a
## static droop, which must stay small or the mane ends up hanging through the pony's
## neck. `deviation` is what is left after both traces are re-centred: the purely dynamic
## difference, i.e. the follow-through itself. An early tuning pass had gravity an order
## of magnitude too high and scored a triumphant deviation of 2.17 units, all of which
## was the tail hanging straight down like wet rope.
func _sag(a: Array, b: Array) -> float:
	return _mean(a).distance_to(_mean(b))


func _deviation(a: Array, b: Array) -> float:
	var mean_a := _mean(a)
	var mean_b := _mean(b)
	var total := 0.0
	for i in a.size():
		total += (a[i] - mean_a).distance_to(b[i] - mean_b)
	return total / float(a.size())


## Vertical peak-to-peak of the settled bob at the end of the manoeuvre.
func _bob_span(values: Array) -> float:
	var lo := INF
	var hi := -INF
	for i in range(values.size() - BOB_WINDOW, values.size()):
		lo = minf(lo, values[i].y)
		hi = maxf(hi, values[i].y)
	return hi - lo


## "Jelly" detector, over the same settled window. RMS of the trace's second
## difference (its per-tick acceleration) divided by its vertical swing: a smooth 2.4 Hz
## oscillation scores around 0.03, a chain buzzing at the tick rate an order of magnitude
## more. Confirms a lag was bought with follow-through rather than with jitter.
func _wobble(values: Array) -> float:
	var span := _bob_span(values)
	if span <= 0.0:
		return 0.0
	var total := 0.0
	for i in range(values.size() - BOB_WINDOW, values.size()):
		var d: float = values[i].y - 2.0 * values[i - 1].y + values[i - 2].y
		total += d * d
	return sqrt(total / float(BOB_WINDOW)) / span


func _report() -> void:
	var moving := 0
	var lagging := 0
	var leaves := 0
	var worst_wobble := 0.0
	for i in tip_bones.size():
		var lag := _best_lag(rigid[i], samples[i], TRAVEL_DIRECTION)
		var deviation := _deviation(rigid[i], samples[i])
		var sag := _sag(rigid[i], samples[i])
		var moves: bool = deviation >= MIN_DEVIATION
		if leaf_chain[i]:
			leaves += 1
			worst_wobble = maxf(worst_wobble, _wobble(samples[i]))
			if moves:
				moving += 1
				if lag["lag"] > 0:
					lagging += 1
		print("HAIRLAG %-12s %s trails body by %+3d ticks (%+6.1f ms) corr=%.3f | dyn_deviation=%.4f offset=%.4f | bob rigid=%.4f sim=%.4f | wobble rigid=%.3f sim=%.3f%s"
			% [chain_names[i], "leaf    " if leaf_chain[i] else "interior",
			   lag["lag"], lag["lag"] * TICK_SECONDS * 1000.0, lag["corr"],
			   deviation, sag, _bob_span(rigid[i]), _bob_span(samples[i]),
			   _wobble(rigid[i]), _wobble(samples[i]),
			   "" if moves else "  [static]"])
	print("MANOEUVRE settle=%d ticks, travel=%d ticks at %.2f m/s along %v, then %d ticks stationary"
		% [SETTLE_TICKS, TRAVEL_TICKS, TRAVEL_SPEED, TRAVEL_DIRECTION, COAST_TICKS])
	var ok := leaves > 0 and moving == leaves and lagging == leaves
	print("HAIRLAG_%s leaf_chains=%d moving=%d lagging=%d worst_wobble=%.3f"
		% ["OK" if ok else "FAIL", leaves, moving, lagging, worst_wobble])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if ok else 1)
