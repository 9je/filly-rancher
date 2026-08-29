extends Node3D
## Task 6 verification scene for the wild pony actor (game/actors/pony/pony.gd).
##
## A ground plane, a herd drawn from a SEEDED SpawnTable, and a stand-in for the player
## that spends the first half of the run far away and the second half standing in the
## middle of the herd. Two phases, because the two halves of "the world feels alive" are
## different claims and a single phase would let a broken one hide behind the other:
##
##   ROUTINE (frames 1..REACTION_FRAME, player 20 m away): every pony must actually get
##     somewhere under her own steam, stay on the plane, stay at ground level, and never
##     hold a state that is not in the enum. Nobody may react -- there is nothing to
##     react to yet, so a pony in FLEE here is a detection bug.
##
##   REACTION (frames REACTION_FRAME..TOTAL_FRAMES, player at the herd's centre): every
##     SHY pony must reach FLEE and be playing `gallop` while she does it, every CURIOUS
##     pony must reach APPROACH, and no BOLD pony may enter either -- BOLD ignoring the
##     player is a claim about what does NOT happen, so it needs its own check.
##
## WHY THIS GATE CAN FAIL, which is the part worth writing down. This project has
## shipped gates that passed while measuring nothing three times now (a harness that
## passed with zero tests, a hair metric that read a search-window boundary, a probe
## inert to the parameter it swept), so every check here is written against something
## that can actually go wrong:
##
##   * "every pony moved" fails if the state machine stops stepping at all.
##   * The personality checks fail if reaction_state() is rewired, if DetectionArea
##     stops detecting, or if the reaction states stop being entered -- and the BOLD
##     check fails in the opposite direction, if reactions start firing for everyone.
##   * "SHY ponies gallop while fleeing" fails if FLEE stops using the flee speed --
##     wiring it back to the wander speed (a plausible refactor slip) drops Fluttershy to
##     0.50 m/s and the check goes red on all three of her.
##     It does NOT, however, catch removing flee_speed_for()'s lower clamp. That was
##     tried: with today's roster the slowest pony's scaled flee speed is 2.48 m/s, which
##     is already above the gallop handover, so the clamp is inert here and the gate
##     stayed green. Written down rather than quietly enjoyed, because "this gate covers
##     the clamp" would be exactly the overclaim the list above exists to avoid. The
##     clamp is pinned instead by test_flee_speed_always_lands_in_the_gallop_band_with_
##     no_skate in game/test/test_pony.gd, which feeds it base_speeds the roster does not
##     currently contain (0.0, 0.5) and fails immediately when the floor is removed.
##   * "nobody left the plane / left ground level" fails if the leash breaks or gravity
##     stops holding her down -- a pony sinking through the floor still "moves".
##   * PERSONALITY COVERAGE is itself a check. Everything in the reaction phase is
##     quantified over "every SHY pony", "every CURIOUS pony", "every BOLD pony"; if the
##     seeded draw happened to contain none of one kind, those clauses would be
##     vacuously true and this gate would pass while measuring nothing. So the draw is
##     asserted to contain all three before any of them is trusted. The seed those draws
##     come from is SEARCHED FOR rather than fixed (see SEED below), because a fixed seed
##     rots: every character added to the roster reshuffles the draw, and a seed that
##     covered all three personalities last month covers two this month. The coverage
##     checks stayed; what changed is what they catch. They no longer go red every time
##     somebody adds a pony, which was a chore rather than a bug. They go red if NO seed
##     in the search window covers all three, which would mean the roster itself had lost
##     a personality.
##   * DETECTION GEOMETRY is asserted too, for the same reason: at the moment the player
##     arrives, every pony must actually be inside HER OWN notice radius of him
##     (Pony.notice_radius_for, which since the second playtest differs by personality --
##     a SHY pony sees 2 m further than the others). Without that, "no BOLD pony reacted"
##     could be passing because no pony could see anything. The stand-in is not a Player
##     and cannot answer is_sneaking(), so he counts as running here, which is the case
##     these radii are the widest for and therefore the one this geometry has to clear.
##
## OFFSCREEN RENDERING (`xvfb-run tools/bin/godot --path game --audio-driver Dummy
## scenes/test/wild_ponies.tscn -- --screenshot-dir=<path>`, NOT `--headless` --
## `--audio-driver Dummy` is required explicitly here, see capture_test.gd's header for
## why): runs the same two phases and additionally saves PNGs of the herd wandering, a SHY pony
## mid-gallop away from the player, and a CURIOUS pony walking up to him. Every
## assertion above is about numbers; whether she is facing the way she is running, and
## whether her hooves are on the ground rather than through it, is not something a
## number in this file can see.

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const SpawnTableScript := preload("res://systems/spawn_table.gd")
const GaitScript := preload("res://systems/gait.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## Base of the seed SEARCH, not the seed the herd is drawn from.
##
## FOUND RATHER THAN CHOSEN, because a fixed seed rots. _spawn_herd() tries SEED,
## SEED + 1, ... up to SEED_SEARCH_LIMIT candidates and keeps the first whose SPAWN_COUNT
## draws contain all three personalities; whichever it settles on is printed as
## `WILD seed=<n> tried=<k>` and is what every wander target in the run derives from, so
## the herd is still byte-identical between two runs on the same roster.
##
## This constant used to name the seed itself: the nearest one whose six draws covered all
## three personalities against a seven-character roster. Then the roster grew past six,
## the same number drew four SHY ponies and two BOLD ones, and the
## CURIOUS clauses in _finish() had nothing to quantify over. That is the shape of the
## problem: the draw depends on the whole roster, so ANY character added anywhere invalidates
## the choice, and pinning a number here just schedules a red gate for whoever adds the next
## pony. Searching costs a few thousand arithmetic operations at spawn time and cannot rot.
const SEED := 20260802

## How many consecutive seeds the search will try before giving up. Deliberately far past
## the point of futility: covering draws are common (the printed `tried=` says how many
## this roster actually needed), so exhausting this window would not mean bad luck, it
## would mean the roster no longer contains one of the three personalities at all. That is
## a data bug, and the check in _finish() names it as one rather than looping forever.
const SEED_SEARCH_LIMIT := 500

## Ponies drawn from the table. Enough for the draw to plausibly cover three
## personalities, few enough that they are not permanently shoulder to shoulder.
const SPAWN_COUNT := 6

## The numbers below are load-bearing rather than decorative: a pony spawns
## SPAWN_RING_RADIUS from the origin and strays at most ROAM_RADIUS from her spawn point,
## so nobody is ever further than 6.5 m from the origin (2.0 + 4.0, plus half a metre of
## braking overshoot past the leash), comfortably inside every personality's notice radius
## (12 m, or 14 m for a SHY pony, against 5 m when these were chosen) of a player standing
## there. That is what makes "every pony can see him in the reaction phase" true by
## construction rather than by luck; the run asserts it anyway.
##
## ROAM_RADIUS WENT 2.0 -> 4.0, and the reason is the leash rather than the roster. The
## leash ramps outward motion down to nothing across the last Pony.LEASH_BAND_* metres of a
## territory, which on a 2 m territory is the outer 0.3 m, and a pony spooked out near her
## own boundary spends the WHOLE flee inside that ramp. Sweetie Belle did exactly that: she
## fled at 1.98 m/s against a 2.72 m/s flee speed, played `walk` the entire time, and took
## this gate red on an engine behaving exactly as designed. The fix belongs to the scene,
## not to the leash, whose continuity is pinned by its own tests: give her somewhere to
## run. Four metres of territory leaves 3.4 m of undamped ground between her spawn point
## and the ramp, and at the pony's 8 m/s^2 acceleration she needs about 0.46 m of it to
## reach full flee speed. The tight ring was originally justified by wanting the herd
## legible in one screenshot; SPAWN_RING_RADIUS is what actually controls that and is
## unchanged, and the two shots that matter for gait are framed on a single pony anyway.
const SPAWN_RING_RADIUS := 2.0
const ROAM_RADIUS := 4.0

const TOTAL_FRAMES := 300
const REACTION_FRAME := 180

## Where the stand-in player waits during the routine phase: far enough that no pony can
## notice him, near enough to stay on the ground plane.
##
## MOVED OUT TWICE NOW, and the arithmetic is why rather than taste. What is being held
## constant across both moves is THREE AND A HALF METRES of slack between the closest a
## pony can get to him and the radius at which she would notice him. Two things eat that
## slack: the widest notice radius, which went 5 -> 12 (first retune) -> 14 for a SHY pony
## (Pony.SHY_NOTICE_BONUS, second retune), and the furthest a pony can be from the origin,
## which went 4.5 m -> 6.5 m when ROAM_RADIUS was widened above.
##
## At 20 m against a 4.5 m reach the closest approach was 15.5 m against a 14 m radius:
## one and a half metres, thin enough that a wander target near the edge plus a braking
## overshoot could spook a pony this scene asserts is unspooked, and the gate would go red
## on a build behaving perfectly. 22 m bought the slack back; the wider territory spent it
## again, so he waits at 24 m, where the closest approach is 17.5 m once more.
## wild_ponies.tscn carries the same number, see below.
##
## wild_ponies.tscn ALSO places him here, and that is load-bearing rather than
## redundant. He originally sat at the origin in the scene and was moved out here in
## _ready(), which is too late: the physics server's first broadphase pass still saw him
## overlapping every DetectionArea, so on frame 2 every SHY and CURIOUS pony fired her
## reaction at a player who was already 20 m away, and the "a freshly spawned pony always
## wanders first" guarantee was spent on a wander that lasted one frame. Ponies that then
## drew GRAZE stood still for the entire routine phase and the gate went red. Starting
## him out here means there is never an overlap to mis-report.
const PLAYER_FAR := Vector3(0.0, 0.1, 24.0)

## Where he stands for the reaction phase.
const PLAYER_NEAR := Vector3(0.0, 0.1, 0.0)

## Half-width of the ground plane. A pony outside this has left the world.
const GROUND_HALF := 30.0
## Metres of slack at the plane's edge -- her capsule, plus a little.
const EDGE_MARGIN := 1.0
## How far a pony's origin (the bottom of her capsule) may sit off the hoof plane.
## Catches both sinking through the floor and floating above it.
const MAX_GROUND_OFFSET := 0.05

## Ground distance each pony must cover during the routine phase. Set against the
## slowest thing on the roster: Fluttershy's 3.0 base_speed ambles at 0.495 m/s, and the
## worst routine draw leaves her idling and grazing for most of the 3 s phase, so this
## has to be a low bar. It is not a weak check -- it is the check that a frozen state
## machine fails, and the failure proof in the task report shows it going red.
const MIN_ROUTINE_TRAVEL := 0.25

## Frames at which the offscreen run saves a PNG. Chosen against the physics, not
## picked round: 220 is 40 frames (0.67 s) after the player arrives, which at the pony's
## 8 m/s^2 acceleration is comfortably past the 0.4 s a SHY pony needs to reach her full
## flee speed -- capturing her at frame 185 would show a gallop clip on a pony barely
## moving, which is precisely the kind of picture that proves nothing.
## 03a and 03b are six frames apart on purpose: two stills of the same galloping pony
## are the only way to see from screenshots that the clip is ADVANCING rather than
## holding a pose, which is a real failure mode here (a clip missing from
## project.godot's [importer_defaults] loop list plays once and freezes, and no gate in
## this file would notice -- `current_animation` still reads `gallop`).
const CAPTURES := {
	120: "01_herd_wandering",
	150: "02_wander_close",
	220: "03a_flee_shy",
	226: "03b_flee_shy",
	240: "04_approach_curious",
	270: "05_herd_reacting",
}

@onready var camera: Camera3D = $Camera3D
@onready var stand_in: CharacterBody3D = $PlayerStandIn

var _ponies: Array[CharacterBody3D] = []
var _screenshot_dir := ""

# Per-pony records, index-aligned with _ponies.
var _last_pos: Array[Vector3] = []
var _routine_travel: Array[float] = []
var _max_origin_distance: Array[float] = []
var _max_ground_offset: Array[float] = []
var _max_speed: Array[float] = []
var _routine_states: Array[Dictionary] = []
var _reaction_states: Array[Dictionary] = []
var _flee_clips: Array[Dictionary] = []
var _flee_max_speed: Array[float] = []
var _all_states: Dictionary = {}
var _invalid_states: Array[int] = []
var _detection_distance_at_arrival: Array[float] = []

# What the seed search settled on. Printed as `WILD seed=<n> tried=<k>` and, when the
# search failed, checked in _finish().
var _seed_used: int = SEED
var _seed_tried: int = 0
var _seed_found: bool = false


func _ready() -> void:
	GateWatchdogScript.arm(self, "WILD", 60.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]

	_spawn_herd()
	stand_in.global_position = PLAYER_FAR

	if _ponies.is_empty():
		push_error("wild_ponies: no ponies spawned -- nothing to verify")
		print("WILD_FAILED count=0 states=<none>")
		get_tree().quit(1)
		return

	await _run()


## Draw SPAWN_COUNT ponies from a seeded SpawnTable over the ranch roster and place them
## on a ring around the origin, using the first seed at or after SEED whose draws cover
## all three personalities.
##
## The search is a loop over _draw_herd(), which is the whole of the drawing: the herd
## that spawns is literally the array the search approved, not a re-derivation from the
## winning seed that could drift away from what was tested. See SEED for why the seed is
## searched for rather than written down.
##
## The registry's dictionary order comes from DirAccess, i.e. from the filesystem, which
## is not guaranteed to be stable across machines -- and SpawnTable walks its entries in
## order when it resolves a roll. Sorting by id is what makes "seeded" actually mean
## reproducible rather than reproducible-on-this-disk.
##
## The `String(...)` casts are load-bearing and must not be "simplified" away. PonyData.id
## is a StringName, and StringName's `<` operator compares the two names' INTERNAL
## POINTERS, not their text -- it exists to give hash maps a cheap total order, and the
## order it gives depends on the addresses the engine happened to intern the names at.
## Sorting on it produced a herd that was reproducible within a run and different between
## runs: the headless gate drew a BOLD pony in slot 4 and the offscreen render, same seed,
## same roster, drew a SHY one. Casting to String compares the text, which is what
## "sorted by id" was supposed to mean.
func _spawn_herd() -> void:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var entries := registry.by_zone(&"ranch")
	entries.sort_custom(func(a: PonyData, b: PonyData) -> bool:
		return String(a.id) < String(b.id))

	var draws: Array[PonyData] = []
	for offset in range(SEED_SEARCH_LIMIT):
		_seed_tried = offset + 1
		_seed_used = SEED + offset
		draws = _draw_herd(entries, _seed_used)
		if _covers_all_personalities(draws):
			_seed_found = true
			break

	print("WILD seed=%d tried=%d" % [_seed_used, _seed_tried])
	if not _seed_found:
		# Spawn the last draw anyway and let _finish() report the failure. Quitting here
		# would throw away every other measurement in the run, and the coverage checks
		# below already say precisely what went wrong.
		push_error("wild_ponies: no seed in [%d, %d] drew all three personalities" % [
			SEED, SEED + SEED_SEARCH_LIMIT - 1])

	for i in range(SPAWN_COUNT):
		var data: PonyData = draws[i]
		if data == null:
			push_error("wild_ponies: SpawnTable.draw() returned null for slot %d" % i)
			continue

		var angle := TAU * float(i) / float(SPAWN_COUNT)
		var pony: CharacterBody3D = PonyScene.instantiate()
		pony.name = "Pony%d_%s" % [i, data.id]
		pony.position = Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_RING_RADIUS
		pony.roam_radius = ROAM_RADIUS

		# Each pony gets her own generator, seeded from the herd seed plus her slot, so
		# the whole scene is reproducible AND no two ponies pick the same wander targets
		# in lockstep.
		var pony_rng := RandomNumberGenerator.new()
		pony_rng.seed = _seed_used + i * 7919
		pony.set_rng(pony_rng)

		add_child(pony)
		pony.setup(data)
		_ponies.append(pony)

		_last_pos.append(pony.global_position)
		_routine_travel.append(0.0)
		_max_origin_distance.append(0.0)
		_max_ground_offset.append(0.0)
		_max_speed.append(0.0)
		_routine_states.append({})
		_reaction_states.append({})
		_flee_clips.append({})
		_flee_max_speed.append(0.0)
		_detection_distance_at_arrival.append(INF)


## The SPAWN_COUNT draws `herd_seed` produces against `entries`, in order, nulls included
## so the caller can report a broken table the same way it always did.
func _draw_herd(entries: Array[PonyData], herd_seed: int) -> Array[PonyData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = herd_seed
	var table := SpawnTableScript.new(entries, rng)
	var drawn: Array[PonyData] = []
	for i in range(SPAWN_COUNT):
		drawn.append(table.draw())
	return drawn


## True when `drawn` contains at least one SHY, one BOLD and one CURIOUS pony. This is
## exactly the condition _finish() checks per personality, which is the point: a draw that
## fails it makes every per-personality clause in this gate vacuous.
func _covers_all_personalities(drawn: Array[PonyData]) -> bool:
	var seen: Dictionary = {}
	for data: PonyData in drawn:
		if data != null:
			seen[data.personality] = true
	return (seen.has(PonyDataScript.Personality.SHY)
		and seen.has(PonyDataScript.Personality.BOLD)
		and seen.has(PonyDataScript.Personality.CURIOUS))


func _run() -> void:
	for frame in range(1, TOTAL_FRAMES + 1):
		await get_tree().physics_frame

		if frame == REACTION_FRAME:
			stand_in.global_position = PLAYER_NEAR
			# Sampled BEFORE any pony has had a chance to move away, so this records how
			# far each of them was when the player showed up -- the number the "everyone
			# could actually see him" check needs.
			for i in range(_ponies.size()):
				var offset: Vector3 = _ponies[i].global_position - PLAYER_NEAR
				_detection_distance_at_arrival[i] = Vector2(offset.x, offset.z).length()

		_sample(frame)

		if _screenshot_dir != "" and CAPTURES.has(frame):
			await _capture(CAPTURES[frame], frame)

	_finish()


func _sample(frame: int) -> void:
	var in_routine := frame < REACTION_FRAME
	for i in range(_ponies.size()):
		var pony: CharacterBody3D = _ponies[i]
		var pos: Vector3 = pony.global_position
		var step := Vector2(pos.x - _last_pos[i].x, pos.z - _last_pos[i].z).length()
		_last_pos[i] = pos

		if in_routine:
			_routine_travel[i] += step

		_max_origin_distance[i] = maxf(_max_origin_distance[i], Vector2(pos.x, pos.z).length())
		_max_ground_offset[i] = maxf(_max_ground_offset[i], absf(pos.y))
		_max_speed[i] = maxf(_max_speed[i], pony.get_ground_speed())

		var state: int = pony.state
		if state < 0 or state >= PonyScript.State.size():
			if not state in _invalid_states:
				_invalid_states.append(state)
			continue

		_all_states[state] = true
		if in_routine:
			_routine_states[i][state] = true
		else:
			_reaction_states[i][state] = true

		# What a fleeing pony is actually doing, recorded only while she is fleeing.
		# Together these are the check that flee_speed_for()'s lower clamp still holds.
		#
		# The clip set legitimately contains `idle` and `walk` as well as `gallop`: she
		# accelerates from a standstill at 8 m/s^2 and passes through both bands on the
		# way up, which is correct and is why "she never plays `walk` while fleeing"
		# would be a wrong assertion (it was, on the first draft of this gate, and it
		# failed for a pony behaving perfectly). What must hold is that she GETS to the
		# gallop band and stays there -- so the clip set must contain `gallop`, and her
		# top speed while fleeing must be in the gallop band rather than merely on the
		# way to it.
		if state == PonyScript.State.FLEE:
			_flee_max_speed[i] = maxf(_flee_max_speed[i], pony.get_ground_speed())
			var anim: AnimationPlayer = pony.get_animation_player()
			if anim != null:
				_flee_clips[i][anim.current_animation] = true


func _finish() -> void:
	var checks := {}
	var personalities := {}

	for i in range(_ponies.size()):
		var pony: CharacterBody3D = _ponies[i]
		var data: PonyData = pony.get_data()
		var who := "%s(%s)" % [pony.name, _personality_name(data.personality)]
		personalities[data.personality] = true

		print("WILD %s travel=%.3f max_r=%.2f max_dy=%.4f max_speed=%.2f routine=%s reaction=%s flee_clips=%s" % [
			who, _routine_travel[i], _max_origin_distance[i], _max_ground_offset[i],
			_max_speed[i], _state_list(_routine_states[i]), _state_list(_reaction_states[i]),
			"%s@%.2f" % [
				"+".join(PackedStringArray(_flee_clips[i].keys())), _flee_max_speed[i]
			] if not _flee_clips[i].is_empty() else "-",
		])

		checks["%s moved under her own steam" % who] = _routine_travel[i] >= MIN_ROUTINE_TRAVEL
		checks["%s stayed on the ground plane" % who] = _max_origin_distance[i] <= GROUND_HALF - EDGE_MARGIN
		checks["%s stayed at ground level" % who] = _max_ground_offset[i] <= MAX_GROUND_OFFSET
		checks["%s never outran an authored clip" % who] = _max_speed[i] <= GaitScript.TOP_SKATE_FREE_SPEED + 0.01
		checks["%s did not react before the player arrived" % who] = (
			not _routine_states[i].has(PonyScript.State.FLEE)
			and not _routine_states[i].has(PonyScript.State.APPROACH)
		)
		checks["%s was never held (nothing held her)" % who] = not _reaction_states[i].has(PonyScript.State.HELD)
		checks["%s was inside her own notice radius of the player" % who] = (
			_detection_distance_at_arrival[i]
			<= PonyScript.notice_radius_for(data.personality, false)
		)

		match data.personality:
			PonyDataScript.Personality.SHY:
				checks["%s fled" % who] = _reaction_states[i].has(PonyScript.State.FLEE)
				checks["%s galloped while fleeing" % who] = _flee_clips[i].has("gallop")
				checks["%s fled at a gallop-band speed" % who] = (
					_flee_max_speed[i] >= GaitScript.GALLOP_HANDOVER_SPEED
				)
			PonyDataScript.Personality.CURIOUS:
				checks["%s approached" % who] = _reaction_states[i].has(PonyScript.State.APPROACH)
				checks["%s did not flee" % who] = not _reaction_states[i].has(PonyScript.State.FLEE)
			PonyDataScript.Personality.BOLD:
				checks["%s ignored the player" % who] = (
					not _reaction_states[i].has(PonyScript.State.FLEE)
					and not _reaction_states[i].has(PonyScript.State.APPROACH)
				)

	# Without all three personalities in the draw, the per-personality clauses above are
	# quantified over an empty set and this gate measures nothing. See the class comment.
	# The seed search exists to make these hold; these checks are what says it worked, and
	# they are kept separate from the search's own check because they are testing the
	# ponies that actually spawned rather than the array the search approved.
	checks["the seed search found a covering draw"] = _seed_found
	for personality in [PonyDataScript.Personality.SHY, PonyDataScript.Personality.BOLD,
			PonyDataScript.Personality.CURIOUS]:
		checks["the seeded draw covers %s" % _personality_name(personality)] = personalities.has(personality)

	checks["every pony held a valid state on every frame"] = _invalid_states.is_empty()
	checks["the herd wandered"] = _all_states.has(PonyScript.State.WANDER)
	# GRAZE is deliberately NOT required here. The routine phase is three seconds, a
	# freshly spawned pony always wanders first, and Fluttershy needs about four seconds
	# to amble to a wander target at 0.495 m/s -- so whether a graze happens at all in
	# this window is down to which targets the seed drew, and asserting on it would be
	# asserting on the seed rather than on the behaviour. GRAZE is covered instead by
	# game/test/test_pony.gd, which forces the routine choice and can therefore check it
	# every run rather than when the dice cooperate.

	var all_ok := true
	for label in checks:
		if not checks[label]:
			push_error("wild_ponies: FAILED check -- %s" % label)
			all_ok = false
	if not _invalid_states.is_empty():
		push_error("wild_ponies: invalid state values observed: %s" % str(_invalid_states))

	var summary := "count=%d states=%s" % [_ponies.size(), _state_list(_all_states)]
	# Only ever print the OK marker when every check actually held.
	print(("WILD_OK " if all_ok else "WILD_FAILED ") + summary)
	get_tree().quit(0 if all_ok else 1)


## Comma-separated State names, in enum order, for the keys of a {state: true} set.
func _state_list(seen: Dictionary) -> String:
	var names := PackedStringArray()
	for value in range(PonyScript.State.size()):
		if seen.has(value):
			names.append(PonyScript.state_name(value))
	return ",".join(names) if not names.is_empty() else "<none>"


func _personality_name(value: int) -> String:
	return PonyDataScript.Personality.keys()[value]


# --- offscreen capture --------------------------------------------------------------

## Frame the camera on whatever this capture is about, let the renderer catch up, and
## save a PNG. Never called headless (there is nothing to render).
func _capture(shot_name: String, frame: int) -> void:
	match shot_name:
		"02_wander_close":
			# Above the herd looking down, or the neighbours stand in front of the
			# subject -- six ponies inside a 4 m circle is a crowd, not a portrait.
			_frame_on(_pick(PonyScript.State.WANDER), 6.5, 2.6, 55.0)
		"03a_flee_shy", "03b_flee_shy":
			# Square side-on and low, which is the only angle a gait is legible from.
			_frame_on(_pick_by_personality(PonyDataScript.Personality.SHY), 4.5, 1.0, 90.0)
		"04_approach_curious":
			# Three-quarter front, so the shot shows her walking INTO frame toward the
			# player rather than her hindquarters.
			_frame_on(_pick_by_personality(PonyDataScript.Personality.CURIOUS), 4.5, 1.3, 55.0)
		_:
			_frame_wide()

	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir.path_join("%s.png" % shot_name)
	image.save_png(path)

	# Dumped alongside every shot so the picture and the numbers can be compared: a pony
	# whose printed heading disagrees with which way she visibly faces is exactly the
	# paper-correct-but-visually-wrong bug this whole capture pass exists to catch.
	print("SCREENSHOT_SAVED %s frame=%d" % [path, frame])
	for pony in _ponies:
		var anim: AnimationPlayer = pony.get_animation_player()
		print("  %s state=%s speed=%.2f clip=%s scale=%.2f pos=(%.2f, %.3f, %.2f) yaw=%.1f" % [
			pony.name, PonyScript.state_name(pony.state), pony.get_ground_speed(),
			anim.current_animation if anim != null else "-",
			anim.speed_scale if anim != null else 0.0,
			pony.global_position.x, pony.global_position.y, pony.global_position.z,
			rad_to_deg(pony.get_node("Visuals").rotation.y),
		])


## Wide shot that contains the whole herd and the stand-in.
func _frame_wide() -> void:
	camera.global_position = Vector3(9.0, 6.0, 9.0)
	camera.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)


## A view of one pony from `angle_deg` around her DIRECTION OF TRAVEL: 0 degrees puts the
## camera in her path looking back at her face, 90 degrees is square side-on, 180 is
## directly behind her. Framing relative to her velocity rather than to a world axis is
## the point -- if the model's yaw ever disagreed with the direction she is actually
## moving, a shot composed this way shows her sideways or backwards, whereas a fixed
## camera would just show a pony and leave the disagreement invisible.
func _frame_on(pony: CharacterBody3D, distance: float, height: float, angle_deg: float) -> void:
	if pony == null:
		_frame_wide()
		return
	var heading := Vector3(pony.velocity.x, 0.0, pony.velocity.z)
	if heading.length_squared() < 0.01:
		heading = -pony.get_node("Visuals").global_transform.basis.z
	heading = heading.normalized()
	var offset := heading.rotated(Vector3.UP, deg_to_rad(angle_deg)) * distance
	camera.global_position = pony.global_position + offset + Vector3(0.0, height, 0.0)
	camera.look_at(pony.global_position + Vector3(0.0, 0.7, 0.0), Vector3.UP)


func _pick(state: int) -> CharacterBody3D:
	for pony in _ponies:
		if state < 0 or pony.state == state:
			return pony
	return _ponies[0] if not _ponies.is_empty() else null


func _pick_by_personality(personality: int) -> CharacterBody3D:
	for pony in _ponies:
		var data: PonyData = pony.get_data()
		if data != null and data.personality == personality:
			return pony
	return null
