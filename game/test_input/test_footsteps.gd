extends "res://test_input/input_test.gd"
## PLAYTEST NOTE: "The running sound is noisy and bad." A fresh save, played from the title
## with the keyboard and mouse only: run (W held) and walk (W + Shift) along the dirt path
## out of the homestead and across the meadow beside it, and listen to every hoofstep the
## game plays on the way.
##
## WHAT IT ASSERTS, every step the Sound autoload played for the player's hooves:
##   1. ON A FOOTFALL. A footfall is the moment one of the four visible hooves reaches the
##      bottom of its stride: a local minimum of that hoof bone's height in the skeleton
##      (IK_FrontEnd.L/R, IK_RearEnd.L/R -- the hoof tips the leg chains end in), read off
##      the live skeleton every frame, which is the solved pose the player actually sees.
##      Every step must sit within ALIGN_S of one, and nearly every footfall
##      (COVERAGE_MIN) must have a step within ALIGN_S of it.
##   2. VARIED. Pitch and volume both change from step to step, within a small range.
##   3. THE RIGHT SURFACE. The sample set matches the ground under her, judged by this test
##      from the world itself: a ray down onto the Terrain, and the painted path's own
##      polyline (Terrain.PATH_POINTS) and width -- dirt on the path, grass well off it.
##   4. CLEAN. None of the old noisy hoofstep files plays, and every sample that does play
##      passes tools/audio_audit.py (peak, clipping, noise floor, loudness).
## It reads the game (the skeleton, the Sound pool, the ground) and acts only through
## RealInput.

const ALIGN_S := 0.040
var _was_on_floor := true
const COVERAGE_MIN := 0.85
const OLD_FILES := [
	"res://assets/audio/world/hoofsteps_grass_1.wav", "res://assets/audio/world/hoofsteps_grass_2.wav",
	"res://assets/audio/world/hoofsteps_grass_3.wav", "res://assets/audio/world/hoofsteps_grass_4.wav",
	"res://assets/audio/world/hoofsteps_hard_1.wav", "res://assets/audio/world/hoofsteps_hard_2.wav",
	"res://assets/audio/world/hoofsteps_hard_3.wav", "res://assets/audio/world/hoofsteps_hard_4.wav"]
const HOOVES := ["IK_FrontEnd.L", "IK_FrontEnd.R", "IK_RearEnd.L", "IK_RearEnd.R"]
const MOVING_CLIPS := [&"walk", &"gallop", &"trot"]

var _frame := 0
var _recording := false
var _sound: Node = null
var _last_next_3d := 0
var _skeleton: Skeleton3D = null
var _bones: Array[int] = []
## One row per recorded frame: {t, moving, clip, ys: [4 floats]}.
var _frames: Array[Dictionary] = []
## One row per hoofstep played: {t, path, pitch, volume_db, truth, clip}.
var _steps: Array[Dictionary] = []
var _last_clip: StringName = &""
var _clip_since := 0.0
var _problems: PackedStringArray = []


func _play() -> void:
	_deadline_s = 420.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	_sound = root.get_node_or_null(^"/root/Sound")
	if not check(_sound != null, "no Sound autoload"):
		return
	var sks := player.find_children("*", "Skeleton3D", true, false)
	if not check(not sks.is_empty(), "the player has no skeleton"):
		return
	_skeleton = sks[0]
	for b: String in HOOVES:
		_bones.append(_skeleton.find_bone(b))
	if not check(not _bones.has(-1), "a hoof bone is missing: %s" % [_bones]):
		return
	_last_next_3d = int(_sound.get("_next_3d"))
	process_frame.connect(_sample)
	note("spawned at %s" % player.global_position)

	# The route, all through RealInput. Running is W alone (RUN_SPEED); walking is W + Shift.
	await _leg(Vector3(1.5, 0, 13.0), false, false)          # onto the path's south end
	await _leg(Vector3(1.5, 0, 36.0), true, false)           # RUN on dirt
	await _leg(Vector3(1.5, 0, 28.0), true, true)            # WALK on dirt
	await _leg(Vector3(13.0, 0, 30.0), false, false)         # off into the meadow
	await _leg(Vector3(13.0, 0, 16.0), true, false)          # RUN on grass
	await _leg(Vector3(13.0, 0, 22.0), true, true)           # WALK on grass
	process_frame.disconnect(_sample)
	_judge()


## Walk or run to `to`; `record` marks whether this leg's steps are judged.
func _leg(to: Vector3, record: bool, sneak: bool) -> void:
	await _clear_talk()
	_recording = record
	var t := 0.0
	while t < 40.0:
		var flat := Vector2(to.x - player.global_position.x, to.z - player.global_position.z)
		if flat.length() < 1.2:
			break
		await walk_to(to, 1.2, 4.0, sneak)
		t += 4.0
		if bool(ranch.get("people").call("is_talking")):
			_recording = false
			await _clear_talk()
			_recording = record
	_recording = false
	await physics(10)


func _clear_talk() -> void:
	var people: Node = ranch.get("people")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		await click(lp.call("close_button_node"))
	if bool(people.call("is_talking")):
		note("a conversation opened; reading it")
		await talk_through()


func _sample() -> void:
	_frame += 1
	var t := _frame / 60.0
	var anim: AnimationPlayer = player.call("get_animation_player")
	var clip: StringName = anim.current_animation if anim != null else &""
	if clip != _last_clip:
		_last_clip = clip
		_clip_since = t
	var speed: float = player.call("get_ground_speed")
	var moving: bool = _recording and player.is_on_floor() and speed > 0.6 \
		and MOVING_CLIPS.has(clip) and t - _clip_since > 0.3
	var ys: Array[float] = []
	for b in _bones:
		ys.append(_skeleton.get_bone_global_pose(b).origin.y)
	# In a gait clip at all, slow or not, recorded or not: her settle steps as she stops
	# (FS4.2) are footfalls on screen too, played on after her body has slowed under the
	# "moving" line, and a judged step may sit at either edge of a recorded leg.
	var gait: bool = player.is_on_floor() and MOVING_CLIPS.has(clip)
	_frames.append({"t": t, "moving": moving, "gait": gait, "clip": clip, "ys": ys, "speed": speed,
		"floor": player.is_on_floor()})
	# Every 3D one shot the Sound autoload started since last frame: its pool cursor moved.
	var next: int = int(_sound.get("_next_3d"))
	var pool: Array = _sound.get("_pool_3d")
	var i := _last_next_3d
	var guard := 0
	while i != next and guard < pool.size():
		var voice: AudioStreamPlayer3D = pool[i]
		var path: String = voice.stream.resource_path if voice.stream != null else ""
		if path.contains("hoof") and _recording:
			# A step on the frame she comes down from the air is her landing, not a stride's
			# footfall: not judged against the stride (it is what she sounds like landing).
			_steps.append({"t": t, "path": path, "pitch": voice.pitch_scale,
				"volume_db": voice.volume_db, "truth": _ground_truth(), "clip": clip,
				"moving": moving and _was_on_floor})
		i = (i + 1) % pool.size()
		guard += 1
	_last_next_3d = next
	_was_on_floor = player.is_on_floor()


## What is under her, by this test's own reading of the world.
func _ground_truth() -> String:
	var from := player.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, 0b11)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "air"
	if hit.collider is Terrain:
		var p := Vector2(player.global_position.x, player.global_position.z)
		var d := Terrain.path_distance(p)
		if d <= Terrain.PATH_HALF_WIDTH - 0.2:
			return "dirt"
		if d >= Terrain.PATH_HALF_WIDTH + Terrain.PATH_EDGE_SOFTNESS + 0.3:
			return "grass"
		return "edge"
	if hit.collider is Building:
		return "wood"
	return "other"


## Footfalls: per hoof, a local minimum of its height with a real swing around it, in frames
## where she is moving, or with `any_gait` wherever a gait clip plays.
func _footfalls(any_gait := false) -> Array[float]:
	var out: Array[float] = []
	var n := _frames.size()
	for h in HOOVES.size():
		for k in range(4, n - 4):
			var f: Dictionary = _frames[k]
			if not bool(f.get("gait" if any_gait else "moving", false)):
				continue
			# At a run only the front hooves sound (player.gd, owner playtest 2026-10-25).
			if h >= 2 and String(f.clip) == "gallop":
				continue
			var y: float = f.ys[h]
			var lo := true
			var hi := y
			for j in range(-4, 5):
				if j == 0:
					continue
				var yj: float = _frames[k + j].ys[h]
				# strictly lower than what comes before, no higher than what follows: the
				# FIRST frame of the bottom, which is the touchdown.
				if (j < 0 and yj <= y) or (j > 0 and yj < y):
					lo = false
				hi = maxf(hi, yj)
			if lo and hi - y > 0.012:
				out.append(float(f.t))
	out.sort()
	return out


func _judge() -> void:
	var falls := _footfalls()
	# A step is judged against every footfall on screen, the settle steps included.
	var all_falls := _footfalls(true)

	# FOOTSTEP_DUMP=<file> writes every frame and step for offline reading.
	var dump := OS.get_environment("FOOTSTEP_DUMP")
	if dump != "":
		var f := FileAccess.open(dump, FileAccess.WRITE)
		for row in _frames:
			f.store_line("F %.4f %s %s %.2f %s %s" % [row.t, row.clip, row.moving, row.speed, row.floor, row.ys])
		for s in _steps:
			f.store_line("S %.4f %s %s %s" % [s.t, s.clip, s.moving, String(s.path).get_file()])
		for t in falls:
			f.store_line("L %.4f" % t)
		for t in all_falls:
			f.store_line("G %.4f" % t)
		f.close()
	var judged: Array[Dictionary] = []
	for s in _steps:
		if bool(s.moving):
			judged.append(s)
	note("recorded %d frames, %d footfalls, %d hoofsteps (%d while moving)"
		% [_frames.size(), falls.size(), _steps.size(), judged.size()])
	if judged.size() < 20 or falls.size() < 20:
		fail("too little to judge: %d steps, %d footfalls" % [judged.size(), falls.size()])
		return

	# 1. alignment, both ways
	var off := 0
	var worst := 0.0
	var sum := 0.0
	for s in judged:
		var d := _nearest(all_falls, float(s.t))
		sum += d
		worst = maxf(worst, d)
		if d > ALIGN_S:
			off += 1
			if off <= 12:
				note("off by %.0f ms: a %s step at %.3f s (%s)"
					% [d * 1000.0, s.clip, float(s.t), String(s.path).get_file()])
	note("step to nearest footfall: mean %.1f ms, worst %.1f ms, %d of %d over %d ms"
		% [sum / judged.size() * 1000.0, worst * 1000.0, off, judged.size(), int(ALIGN_S * 1000)])
	if off > 0:
		_problems.append("%d of %d hoofsteps land more than %d ms from any footfall (worst %.0f ms)"
			% [off, judged.size(), int(ALIGN_S * 1000), worst * 1000.0])
	var step_times: Array[float] = []
	for s in judged:
		step_times.append(float(s.t))
	var covered := 0
	for f in falls:
		if _nearest(step_times, f) <= ALIGN_S:
			covered += 1
	var coverage := float(covered) / falls.size()
	note("footfalls with a hoofstep within %d ms: %d of %d (%.0f%%)"
		% [int(ALIGN_S * 1000), covered, falls.size(), coverage * 100.0])
	if coverage < COVERAGE_MIN:
		_problems.append("only %.0f%% of footfalls make a sound (want %.0f%%)"
			% [coverage * 100.0, COVERAGE_MIN * 100.0])

	# 2. variation
	var pmin := INF
	var pmax := -INF
	var vmin := INF
	var vmax := -INF
	for s in judged:
		pmin = minf(pmin, float(s.pitch))
		pmax = maxf(pmax, float(s.pitch))
		vmin = minf(vmin, float(s.volume_db))
		vmax = maxf(vmax, float(s.volume_db))
	note("pitch %.3f..%.3f, volume %.2f..%.2f dB" % [pmin, pmax, vmin, vmax])
	if pmax - pmin < 0.02 or pmin < 0.85 or pmax > 1.15:
		_problems.append("pitch range %.3f..%.3f is not a slight variation" % [pmin, pmax])
	if vmax - vmin < 0.5 or vmax - vmin > 6.0:
		_problems.append("volume range %.2f..%.2f dB is not a slight variation" % [vmin, vmax])

	# 3. surface
	var by_truth: Dictionary = {}
	var wrong := 0
	for s in judged:
		var truth: String = s.truth
		if truth != "grass" and truth != "dirt" and truth != "wood":
			continue
		by_truth[truth] = int(by_truth.get(truth, 0)) + 1
		if not String(s.path).get_file().contains("_%s_" % truth):
			wrong += 1
			if wrong <= 3:
				note("on %s she played %s" % [truth, String(s.path).get_file()])
	note("steps by ground: %s, %d with the wrong sample set" % [by_truth, wrong])
	if int(by_truth.get("grass", 0)) < 8 or int(by_truth.get("dirt", 0)) < 8:
		_problems.append("not enough steps on both surfaces to judge: %s" % [by_truth])
	if wrong > 0:
		_problems.append("%d steps played another surface's sample set" % wrong)

	# 4. clean samples
	var played: Dictionary = {}
	for s in _steps:
		played[s.path] = true
	note("samples played: %s" % [played.keys().map(func(p: String) -> String: return p.get_file())])
	for p: String in played.keys():
		if OLD_FILES.has(p):
			_problems.append("the old noisy sample %s still plays" % p.get_file())
	var audit := _audit(played.keys())
	if audit != "":
		_problems.append(audit)

	if _problems.is_empty():
		ok("%d hoofsteps on %d footfalls, all aligned, varied, on the right surface and clean"
			% [judged.size(), falls.size()])
	else:
		fail(" | ".join(_problems))


func _nearest(sorted: Array[float], t: float) -> float:
	var best := INF
	for x in sorted:
		best = minf(best, absf(x - t))
	return best


## tools/audio_audit.py over every sample that played. "" when all pass.
func _audit(paths: Array) -> String:
	var repo := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var args := PackedStringArray(["-I", repo.path_join("tools/audio_audit.py")])
	for p: String in paths:
		args.append(ProjectSettings.globalize_path(p))
	var out: Array = []
	var rc := OS.execute("python3", args, out, true)
	var text: String = "\n".join(PackedStringArray(out))
	for line in text.split("\n"):
		if line.begins_with("FAIL") or line.begins_with("AUDIO_AUDIT"):
			note("audit: " + line.strip_edges())
	if rc != 0:
		return "the samples that played fail tools/audio_audit.py (exit %d)" % rc
	return ""
