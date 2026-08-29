extends Node
## THE WORLD GATE. Proves the whole of slice 4's clock in one run, on the real ranch: a
## fresh world opens at dawn with the clock on zero, two minutes of play carry it into day
## and nine more into dusk, the sky rig is aimed at whichever hour the clock is actually on
## rather than at whichever hour it booted in, the weather at every phase of a cycle is the
## one WorldState.weather_for() says that seed rolls, the HUD is repeating the clock's own
## words, a save carries the elapsed seconds out to disk and a reload resumes the same hour
## in the same weather, and a pinned stormy night thickens the fog and turns the rain on.
##
## WHY A GATE AND NOT ONLY UNIT TESTS. game/test/test_world_state.gd proves the arithmetic
## and game/test/test_sky_rig.gd proves the palette, both without a scene. Neither can see
## the wire between them: a rig that is never handed the state, a HUD label nobody pushes
## to, a save that writes every other field, or a load that restores GameState.world_time
## into an object no longer driving the sky, all pass every unit test in the suite and all
## leave the player with a sky that stopped. That wire is the whole of what this file
## measures, and it can only be measured against a ranch that actually booted.
##
## THE RANCH IS HOSTED HERE, not launched. world/ranch.tscn is instanced under this scene,
## so ranch.gd runs with _hosted true: it arms no watchdog of its own, it does not quit the
## process out from under this driver, it never reads the player's save, and it hands its
## own verdict over as gate_report_finished(all_ok). This gate waits for that signal rather
## than polling for a symptom of it, and folds the ranch's answer into its own. Same
## scaffold as scenes/test/market_test.gd and scenes/test/region_test.gd.
##
## THE CLOCK IS READ THROUGH ranch.get_world_state(), NEVER OFF THE `RANCH world` LINE.
## ranch.gd's own report REBUILDS the world state part way through printing, on purpose (a
## rig still holding boot's state would pass a naive check and be wrong the moment a save
## loaded), so the object this gate drives is the one that exists AFTER the report has
## finished. Parsing that printed line would be reading a clock that has since been
## replaced.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const SkyRigScript := preload("res://world/sky_rig.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

const SLOT := 6  # a scratch slot; a hosted ranch reads no slot at all, so nothing collides

## How close a float has to land to count. Elapsed seconds are compared at millisecond
## scale; fog densities are four decimal places apart at their closest (0.0011 clear
## against 0.004 rain), so they get a tighter window.
const TIME_EPSILON := 0.001
const DENSITY_EPSILON := 0.000001
const ENERGY_EPSILON := 0.0001

var _checks: Dictionary = {}
var _duplicates: Array[String] = []
var _ranch: Ranch = null


## Record one check's verdict under `label`. A repeated label is a check that never ran:
## the second verdict would silently overwrite the first and the total would come out one
## short, so a collision is recorded and fails the gate in _finish(). Same rule as
## market_test.gd's and region_test.gd's _set_check() and ranch.gd's own.
##
## The loser is kept under a suffixed key rather than dropped: a run with a duplicate still
## reports BOTH verdicts, so the collision costs you the label rather than the measurement.
func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = ok
		return
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "WORLD", 120.0)
	var ranch := $Ranch as Ranch
	_ranch = ranch

	# The ranch's boot awaits inside its own _ready(), so it has already yielded by the
	# time this line runs and the connection lands before the verdict is emitted.
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	# Untyped on purpose, the way region_test.gd reads it: the autoload's script carries no
	# class_name, so a `Node` annotation here would refuse every property below at parse
	# time.
	var state = get_node("/root/GameState")
	var world: WorldState = ranch.get_world_state()
	_set_check("the ranch built a world clock", world != null)
	var rig: Node3D = ranch.sky_rig
	var rig_wired: bool = rig != null and rig.has_method("current_targets") \
		and not rig.call("current_targets").is_empty()
	_set_check("the sky rig is in the scene and has been aimed at something", rig_wired)
	if world == null or not rig_wired:
		_finish()
		return

	var world_seed: int = state.world_seed

	# --- the hour a fresh ranch opens on -------------------------------------------------
	# ranch.gd's report rebuilt the state from GameState.world_time a moment ago, so this
	# is a genuinely fresh clock and not the one boot happened to leave lying about.
	_set_check("a fresh clock reads zero", absf(world.elapsed()) < TIME_EPSILON)
	_set_check("a fresh clock reads dawn", world.phase() == WorldStateScript.Phase.DAWN)
	_set_check("the sky is aimed at dawn's own light",
		_targets_match(WorldStateScript.Phase.DAWN, world.weather()))
	var dawn_elevation := _target_elevation()
	var weather_seen: Array[int] = [world.weather()]
	var phases_seen: Array[int] = [world.phase()]
	_print_clock(world, "opened")

	# --- two minutes of play, and it is day ----------------------------------------------
	# advance_world() is the ranch's own public tick, the same call _physics_process() makes
	# every frame, so this is the clock moving the way play moves it rather than a test
	# reaching in and setting a field.
	ranch.advance_world(_phase_length(WorldStateScript.Phase.DAWN))
	world = ranch.get_world_state()
	_set_check("two minutes of play carry the clock into day",
		world.phase() == WorldStateScript.Phase.DAY)
	_set_check("the sky followed the clock into day",
		_targets_match(WorldStateScript.Phase.DAY, world.weather()))
	var day_elevation := _target_elevation()
	_set_check("the sun is aimed higher at day than it was at dawn",
		day_elevation > dawn_elevation)
	weather_seen.append(world.weather())
	phases_seen.append(world.phase())
	print("WORLD sun elevation dawn=%.1f day=%.1f degrees" % [dawn_elevation, day_elevation])
	_print_clock(world, "advanced")

	# --- nine more, and it is dusk --------------------------------------------------------
	ranch.advance_world(_phase_length(WorldStateScript.Phase.DAY))
	world = ranch.get_world_state()
	_set_check("nine more minutes carry the clock into dusk",
		world.phase() == WorldStateScript.Phase.DUSK)
	_set_check("the sky followed the clock into dusk",
		_targets_match(WorldStateScript.Phase.DUSK, world.weather()))
	weather_seen.append(world.weather())
	phases_seen.append(world.phase())
	_print_clock(world, "advanced")

	# --- the HUD is repeating the clock ----------------------------------------------------
	# Asked of the LABEL rather than of the ranch, because an unwired world line is a blank
	# line at the bottom of the Bag box and looks exactly like a HUD with nothing to say.
	var hud := ranch.get_node_or_null(^"HUD")
	var hud_line: String = ""
	if hud != null and hud.has_method("get_world_line"):
		hud_line = hud.get_world_line()
	_set_check("the HUD line is the clock's own words", hud_line == world.describe())
	print("WORLD hud line='%s' describe='%s'" % [hud_line, world.describe()])

	# --- the weather of a whole cycle, against the static function --------------------------
	# The point is that nothing SIMULATES weather: it is a pure function of the seed, the
	# cycle and the phase, so a player who quits in a storm comes back to the same storm.
	# Four stops around one cycle, each compared against what weather_for() says that stop
	# should have been, catches both halves of that claim going wrong: a live state that
	# rolled its own dice, and a static function that drifted from what the world uses.
	ranch.advance_world(_phase_length(WorldStateScript.Phase.DUSK))
	world = ranch.get_world_state()
	weather_seen.append(world.weather())
	phases_seen.append(world.phase())
	_print_clock(world, "advanced")

	var expected_weather: Array[int] = []
	for phase in range(WorldStateScript.PHASE_SECONDS.size()):
		expected_weather.append(WorldStateScript.weather_for(world_seed, 0, phase))
	print("WORLD weather cycle=0 lived=%s table=%s"
		% [_weather_list(weather_seen), _weather_list(expected_weather)])
	# ANTI-VACUITY FIRST: comparing weather at four stops proves nothing if the four stops
	# were all the same phase, which is what a clock that stopped ticking would look like.
	_set_check("the cycle really visited all four phases",
		phases_seen == [WorldStateScript.Phase.DAWN, WorldStateScript.Phase.DAY,
			WorldStateScript.Phase.DUSK, WorldStateScript.Phase.NIGHT])
	_set_check("the weather at every phase of the cycle is the one the seed says",
		weather_seen == expected_weather)

	# And one stop past the end of it, because cycle_index() is the only argument to
	# weather_for() that the clock itself has to work out.
	ranch.advance_world(_phase_length(WorldStateScript.Phase.NIGHT))
	world = ranch.get_world_state()
	_set_check("the clock rolls into the next cycle", world.cycle_index() == 1)
	_set_check("the next cycle's dawn has the weather that cycle's numbers say",
		world.weather() == WorldStateScript.weather_for(world_seed, 1, world.phase()))
	_print_clock(world, "rolled over")

	# --- the save carries the hour --------------------------------------------------------
	# save_to_slot() pulls the live clock in through the `world_sync` Callable ranch.gd
	# registered at boot, so this writes the second the session is actually on, not the
	# second GameState was last told about.
	var elapsed_before: float = world.elapsed()
	var phase_before: int = world.phase()
	var weather_before: int = world.weather()
	var clock_before: WorldState = world
	_set_check("the save lands", state.save_to_slot(SLOT))
	var raw: Dictionary = SaveIOScript.load(SLOT)
	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	_set_check("the file carries a world_time", raw.has("world_time"))
	_set_check("the file's world_time is the second the session was on",
		absf(float(raw.get("world_time", -1.0)) - elapsed_before) < TIME_EPSILON)
	print("WORLD save elapsed=%.1f file_world_time=%s path=%s"
		% [elapsed_before, str(raw.get("world_time", "MISSING")), path])

	# NOTHING BELOW REBUILDS THE CLOCK BY HAND. load_from_slot() emits state_loaded,
	# ranch.gd connected _rebuild_world_state() to it at boot, and that is the chain under
	# test: a load that restored world_time into GameState but left the old WorldState
	# driving the sky would put the player back in an hour her file does not say.
	state.reset()
	ranch.rebind_economy()
	_set_check("a reset takes the saved clock back to zero", absf(state.world_time) < TIME_EPSILON)
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	var reloaded: WorldState = ranch.get_world_state()
	_set_check("loading a save built a new clock", reloaded != null and reloaded != clock_before)
	if reloaded == null:
		_finish()
		return
	_set_check("the reloaded clock resumes at the same second",
		absf(reloaded.elapsed() - elapsed_before) < TIME_EPSILON)
	_set_check("the reloaded clock resumes in the same phase", reloaded.phase() == phase_before)
	_set_check("the reloaded clock resumes in the same weather",
		reloaded.weather() == weather_before)
	print("WORLD reload elapsed=%.1f phase=%s weather=%s"
		% [reloaded.elapsed(), WorldStateScript.phase_name(reloaded.phase()).to_upper(),
			WorldStateScript.weather_name(reloaded.weather()).to_upper()])

	# --- a stormy night, on demand ---------------------------------------------------------
	# The one pair the sheet is hardest to read and the one a player is most likely to meet
	# at the wrong end of a bug: fog that does not thicken, or rain that never starts. Driven
	# through a SEPARATE pinned state and apply_immediately() rather than by winding the live
	# clock round to it, because pinning is exactly what a screenshot run does and a gate
	# should not have to spin an eight second ramp to see an answer.
	var pinned: WorldState = WorldStateScript.new(world_seed, 0.0)
	pinned.pin(WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.STORM)
	rig.call("apply_immediately", pinned)
	var world_environment := ranch.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	var rain := ranch.get_node_or_null(^"SkyRig/Rain") as GPUParticles3D
	var sun := ranch.get_node_or_null(^"Sun") as DirectionalLight3D
	_set_check("the ranch has an environment, a rain emitter and a sun",
		world_environment != null and world_environment.environment != null
			and rain != null and sun != null)
	if world_environment == null or world_environment.environment == null \
			or rain == null or sun == null:
		_finish()
		return
	var environment: Environment = world_environment.environment
	var storm_fog: float = SkyRigScript.fog_density(WorldStateScript.Weather.STORM)
	var storm_drops: int = SkyRigScript.rain_amount(WorldStateScript.Weather.STORM)
	print("WORLD night storm fog=%.5f (asked %.5f) rain amount=%d emitting=%s sun elevation=%.1f"
		% [environment.fog_density, storm_fog, rain.amount, rain.emitting,
			-sun.rotation_degrees.x])
	_set_check("a pinned stormy night thickens the fog to the storm's density",
		absf(environment.fog_density - storm_fog) < DENSITY_EPSILON)
	_set_check("a pinned stormy night is foggier than a clear one",
		storm_fog > SkyRigScript.fog_density(WorldStateScript.Weather.CLEAR))
	_set_check("a pinned stormy night turns the rain on", rain.emitting)
	_set_check("the rain is asked for a storm's worth of drops", rain.amount == storm_drops)
	# The half of "it is night" a person judges a screenshot by: no sun above the horizon.
	_set_check("the sun is parked below the horizon at night",
		-sun.rotation_degrees.x < 0.0)

	# --- cleanup ---------------------------------------------------------------------------
	# The backup as well as the save. A second run of this gate finds the first run's file
	# still there, and commit() copies it aside before renaming over it, so a gate that
	# swept up only slot_<n>.json would leave a slot_<n>.json.bak behind in the player's own
	# user:// directory from then on.
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIOScript.backup_path(SLOT)))
	_finish()


## How many seconds `phase` lasts, read out of WorldState's own table rather than typed out
## again, so a retuned cycle moves this gate with it instead of leaving it asserting a phase
## boundary that no longer exists.
func _phase_length(phase: int) -> float:
	return WorldStateScript.PHASE_SECONDS[phase]


## Whether the rig is walking toward the sky (phase, weather) asks for. Compared against
## SkyRig's own pure mapping, which is the only definition of "the right sky" there is;
## checking the numbers rather than a name is also what makes a rig that was handed a stale
## state fail, since a stale state produces a consistent set of wrong numbers.
##
## NOT `current_targets()["phase"]`: SkyRig's target dictionary is exactly the nine KEY_*
## values it interpolates between frames and carries no phase of its own, deliberately, so
## that step() can lerp every entry in it without special cases. ranch.gd's own
## _sky_rig_matches_world() asks the same question the same way.
func _targets_match(phase: int, weather: int) -> bool:
	var targets: Dictionary = _ranch.sky_rig.call("current_targets")
	if targets.is_empty():
		return false
	var energy := float(targets.get(SkyRigScript.KEY_LIGHT_ENERGY, -1.0))
	var fog := float(targets.get(SkyRigScript.KEY_FOG_DENSITY, -1.0))
	var light: Color = targets.get(SkyRigScript.KEY_LIGHT_COLOR, Color.BLACK)
	var top: Color = targets.get(SkyRigScript.KEY_SKY_TOP, Color.BLACK)
	var drops := int(targets.get(SkyRigScript.KEY_RAIN_AMOUNT, -1))
	return absf(energy - SkyRigScript.light_energy(phase, weather)) < ENERGY_EPSILON \
		and absf(fog - SkyRigScript.fog_density(weather)) < DENSITY_EPSILON \
		and light.is_equal_approx(SkyRigScript.light_color(phase, weather)) \
		and top.is_equal_approx(SkyRigScript.sky_top(phase, weather)) \
		and drops == SkyRigScript.rain_amount(weather)


## Degrees the rig is currently aiming the sun at, above the horizon.
func _target_elevation() -> float:
	var targets: Dictionary = _ranch.sky_rig.call("current_targets")
	return float(targets.get(SkyRigScript.KEY_SUN_ELEVATION, 0.0))


func _weather_list(values: Array[int]) -> String:
	var names: Array[String] = []
	for value in values:
		names.append(WorldStateScript.weather_name(value).to_upper())
	return "[%s]" % ", ".join(names)


func _print_clock(world: WorldState, what: String) -> void:
	print("WORLD clock %s elapsed=%.1f cycle=%d phase=%s weather=%s"
		% [what, world.elapsed(), world.cycle_index(),
			WorldStateScript.phase_name(world.phase()).to_upper(),
			WorldStateScript.weather_name(world.weather()).to_upper()])


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("world_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("world_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("WORLD_OK " if all_ok else "WORLD_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
