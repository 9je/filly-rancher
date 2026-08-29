extends GutTest
## THE SKY AS ARITHMETIC, THEN AS A SCENE. game/world/sky_rig.gd turns a WorldState into
## a sun angle, a light colour, a sky gradient, a fog density and a rain count. Most of
## that is pure static maths and is checked here directly; the last few tests build a
## throwaway world with a real DirectionalLight3D and WorldEnvironment and prove the rig
## actually writes those numbers onto them.
##
## What these tests CANNOT see is whether the result looks like weather. A headless run
## has no pixels, so "night is dark" is asserted as a luminance comparison and the actual
## look is signed off by eye against the screenshots in the task report, per
## docs/testing.md's note that a structural gate cannot catch a rendering bug.
##
## Preloads by path rather than by the global class_name, per the convention documented at
## the top of game/scripts/pony_rig.gd: the class cache lives in the gitignored game/.godot/
## and a fresh clone has not built it yet.

const SkyRigScript := preload("res://world/sky_rig.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

const DAWN := WorldStateScript.Phase.DAWN
const DAY := WorldStateScript.Phase.DAY
const DUSK := WorldStateScript.Phase.DUSK
const NIGHT := WorldStateScript.Phase.NIGHT

const CLEAR := WorldStateScript.Weather.CLEAR
const RAIN := WorldStateScript.Weather.RAIN
const FOG := WorldStateScript.Weather.FOG
const STORM := WorldStateScript.Weather.STORM


# === the sun's arc ===

func test_the_sun_is_under_the_horizon_all_night() -> void:
	for p in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var elevation: float = SkyRigScript.sun_elevation_degrees(NIGHT, p)
		assert_lt(elevation, 0.0,
			"the sun must be below the horizon at night, progress %.2f gave %.2f deg" % [p, elevation])


func test_the_sun_is_high_at_the_middle_of_the_day() -> void:
	var noon: float = SkyRigScript.sun_elevation_degrees(DAY, 0.5)
	assert_almost_eq(noon, SkyRigScript.ELEVATION_NOON, 0.01,
		"mid DAY is the top of the arc")
	assert_gt(noon, 45.0, "noon must be steeply overhead, not a grazing angle")
	assert_gt(SkyRigScript.sun_elevation_degrees(DAY, 0.0), 0.0,
		"the sun is already up when DAY starts")


func test_the_arc_is_continuous_at_every_phase_boundary() -> void:
	assert_almost_eq(SkyRigScript.sun_elevation_degrees(DAWN, 1.0),
		SkyRigScript.sun_elevation_degrees(DAY, 0.0), 0.01,
		"the end of DAWN and the start of DAY are the same instant; the sun must not jump")
	assert_almost_eq(SkyRigScript.sun_elevation_degrees(DAY, 1.0),
		SkyRigScript.sun_elevation_degrees(DUSK, 0.0), 0.01,
		"the end of DAY and the start of DUSK are the same instant")
	assert_almost_eq(SkyRigScript.sun_azimuth_degrees(DAWN, 1.0),
		SkyRigScript.sun_azimuth_degrees(DAY, 0.0), 0.01,
		"the bearing must not jump either")
	assert_almost_eq(SkyRigScript.sun_azimuth_degrees(DAY, 1.0),
		SkyRigScript.sun_azimuth_degrees(DUSK, 0.0), 0.01)


func test_dawn_rises_out_of_the_ground_and_dusk_sinks_back_into_it() -> void:
	assert_lt(SkyRigScript.sun_elevation_degrees(DAWN, 0.0), 0.0,
		"DAWN opens with the sun still under the rim")
	assert_gt(SkyRigScript.sun_elevation_degrees(DAWN, 1.0), 0.0, "and ends with it up")
	assert_gt(SkyRigScript.sun_elevation_degrees(DUSK, 0.0), 0.0, "DUSK opens with it up")
	assert_lt(SkyRigScript.sun_elevation_degrees(DUSK, 1.0), 0.0, "and ends with it gone")


func test_the_bearing_runs_east_to_west_and_then_stops_for_the_night() -> void:
	var bearings: Array[float] = [
		SkyRigScript.sun_azimuth_degrees(DAWN, 0.0),
		SkyRigScript.sun_azimuth_degrees(DAY, 0.0),
		SkyRigScript.sun_azimuth_degrees(DAY, 0.5),
		SkyRigScript.sun_azimuth_degrees(DAY, 1.0),
		SkyRigScript.sun_azimuth_degrees(DUSK, 1.0),
	]
	for i in range(1, bearings.size()):
		assert_lt(bearings[i], bearings[i - 1],
			"the bearing must sweep one way across the day, step %d went backwards" % i)
	assert_almost_eq(SkyRigScript.sun_azimuth_degrees(NIGHT, 0.0),
		SkyRigScript.sun_azimuth_degrees(NIGHT, 1.0), 0.01,
		"there is no sun to sweep at night; the bearing is parked")


# === light and sky colour ===

func test_a_storm_is_darker_than_a_clear_sky_in_every_phase() -> void:
	for phase in [DAWN, DAY, DUSK, NIGHT]:
		var clear_energy: float = SkyRigScript.light_energy(phase, CLEAR)
		var storm_energy: float = SkyRigScript.light_energy(phase, STORM)
		assert_lt(storm_energy, clear_energy,
			"a storm must darken phase %d, clear %.3f vs storm %.3f"
				% [phase, clear_energy, storm_energy])


func test_every_phase_and_weather_keeps_some_light() -> void:
	for phase in [DAWN, DAY, DUSK, NIGHT]:
		for weather in [CLEAR, RAIN, FOG, STORM]:
			assert_gt(SkyRigScript.light_energy(phase, weather), 0.0,
				"phase %d weather %d went pitch black" % [phase, weather])
			assert_gt(SkyRigScript.ambient_energy(phase, weather), 0.0,
				"ambient for phase %d weather %d went pitch black" % [phase, weather])


func test_the_night_sky_is_darker_than_the_day_sky() -> void:
	var night: Color = SkyRigScript.sky_top(NIGHT, CLEAR)
	var day: Color = SkyRigScript.sky_top(DAY, CLEAR)
	assert_lt(night.get_luminance(), day.get_luminance(),
		"a clear night's zenith must be darker than a clear day's")


func test_the_horizon_is_lighter_than_the_zenith_in_every_phase() -> void:
	for phase in [DAWN, DAY, DUSK, NIGHT]:
		var top: Color = SkyRigScript.sky_top(phase, CLEAR)
		var horizon: Color = SkyRigScript.sky_horizon(phase, CLEAR)
		assert_gt(horizon.get_luminance(), top.get_luminance(),
			"phase %d: the sky must pale toward the ground, not darken" % phase)


func test_the_agreed_palette_is_the_one_that_shipped() -> void:
	# These exact values are the slice's art direction, not an implementation detail.
	# If one of them changes, the change was deliberate and this line changes with it.
	assert_eq(SkyRigScript.light_color(DAY, CLEAR), Color(1.0, 0.97, 0.91))
	assert_eq(SkyRigScript.light_color(DAWN, CLEAR), Color(1.0, 0.78, 0.60))
	assert_eq(SkyRigScript.light_color(DUSK, CLEAR), Color(1.0, 0.62, 0.45))
	assert_eq(SkyRigScript.light_color(NIGHT, CLEAR), Color(0.55, 0.62, 0.85))
	assert_almost_eq(SkyRigScript.light_energy(NIGHT, CLEAR), 0.25, 0.0001)
	assert_eq(SkyRigScript.sky_top(DAY, CLEAR), Color(0.31, 0.51, 0.76))
	assert_eq(SkyRigScript.sky_top(DAWN, CLEAR), Color(0.62, 0.55, 0.70))
	assert_eq(SkyRigScript.sky_top(DUSK, CLEAR), Color(0.58, 0.40, 0.55))
	assert_eq(SkyRigScript.sky_top(NIGHT, CLEAR), Color(0.05, 0.07, 0.15))


func test_the_weather_multipliers_are_the_agreed_ones() -> void:
	var day_clear: float = SkyRigScript.light_energy(DAY, CLEAR)
	assert_almost_eq(SkyRigScript.light_energy(DAY, RAIN), day_clear * 0.7, 0.0001)
	assert_almost_eq(SkyRigScript.light_energy(DAY, FOG), day_clear * 0.6, 0.0001)
	assert_almost_eq(SkyRigScript.light_energy(DAY, STORM), day_clear * 0.45, 0.0001)


# === fog and rain ===

func test_fog_is_the_thickest_weather_there_is() -> void:
	var densities := {
		"clear": SkyRigScript.fog_density(CLEAR),
		"rain": SkyRigScript.fog_density(RAIN),
		"fog": SkyRigScript.fog_density(FOG),
		"storm": SkyRigScript.fog_density(STORM),
	}
	for label in densities:
		if label == "fog":
			continue
		assert_lt(float(densities[label]), float(densities["fog"]),
			"%s must be thinner than fog" % label)
	assert_almost_eq(SkyRigScript.fog_density(CLEAR), 0.0011, 0.000001)
	assert_almost_eq(SkyRigScript.fog_density(RAIN), 0.004, 0.000001)
	assert_almost_eq(SkyRigScript.fog_density(FOG), 0.018, 0.000001)
	assert_almost_eq(SkyRigScript.fog_density(STORM), 0.008, 0.000001)


func test_it_only_rains_when_it_is_raining() -> void:
	assert_eq(SkyRigScript.rain_amount(CLEAR), 0, "a clear sky drops nothing")
	assert_eq(SkyRigScript.rain_amount(FOG), 0, "fog is not rain")
	assert_gt(SkyRigScript.rain_amount(RAIN), 0, "rain rains")
	assert_gt(SkyRigScript.rain_amount(STORM), SkyRigScript.rain_amount(RAIN),
		"a storm must come down harder than plain rain")


# === the rig on a real scene ===

var _world: Node3D
var _sun: DirectionalLight3D
var _world_environment: WorldEnvironment
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _rig: Node3D


## A throwaway stand in for the ranch's own lighting: one DirectionalLight3D, one
## WorldEnvironment whose Environment carries a Sky with a ProceduralSkyMaterial, and a
## SkyRig pointed at both by NodePath exactly as game/world/ranch.tscn points at them.
func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "SkyWorld"
	add_child_autofree(_world)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color(1, 0.968627, 0.905882)
	_sun.light_energy = 1.15
	_world.add_child(_sun)

	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color(0.309804, 0.505882, 0.760784)
	_sky_material.sky_horizon_color = Color(0.717647, 0.803922, 0.870588)
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 0.32
	_environment.fog_enabled = true
	_environment.fog_density = 0.0011
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "WorldEnvironment"
	_world_environment.environment = _environment
	_world.add_child(_world_environment)

	_rig = SkyRigScript.new()
	_rig.name = "SkyRig"
	_rig.sun_path = NodePath("../Sun")
	_rig.environment_path = NodePath("../WorldEnvironment")
	_world.add_child(_rig)


func _pinned_state(phase: int, weather: int) -> RefCounted:
	var state: RefCounted = WorldStateScript.new(1234)
	state.pin(phase, weather)
	return state


func test_a_pinned_night_storm_puts_the_sun_down_and_the_rain_up() -> void:
	_build_world()
	_rig.apply_immediately(_pinned_state(NIGHT, STORM))

	assert_gt(_sun.rotation_degrees.x, 0.0,
		"a positive pitch aims the light upward from below; the sun has set")
	assert_lt(_sun.light_energy, SkyRigScript.light_energy(DAY, CLEAR),
		"a stormy night must be dimmer than a clear day")
	assert_almost_eq(_environment.fog_density, SkyRigScript.fog_density(STORM), 0.000001)
	assert_almost_eq(_sky_material.sky_top_color.get_luminance(),
		SkyRigScript.sky_top(NIGHT, STORM).get_luminance(), 0.001)

	var rain: GPUParticles3D = _rig.get_node("Rain")
	assert_eq(rain.amount, SkyRigScript.rain_amount(STORM), "the storm's drop count")
	assert_true(rain.emitting, "and it is actually falling")


func test_a_pinned_clear_day_puts_the_sun_up_and_the_rain_away() -> void:
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))

	assert_lt(_sun.rotation_degrees.x, 0.0, "a pinned DAY reads as noon; the sun is up")
	assert_almost_eq(_sun.rotation_degrees.x, -SkyRigScript.ELEVATION_NOON, 0.01,
		"a pinned state has no meaningful progress, so it is read as mid phase")
	assert_almost_eq(_environment.fog_density, SkyRigScript.fog_density(CLEAR), 0.000001)

	var rain: GPUParticles3D = _rig.get_node("Rain")
	assert_false(rain.emitting, "nothing falls out of a clear sky")


func test_apply_eases_instead_of_snapping() -> void:
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))
	var clear_density: float = _environment.fog_density

	_rig.apply(_pinned_state(NIGHT, STORM))
	_rig.step(1.0)
	var stepped: float = _environment.fog_density
	assert_gt(stepped, clear_density, "one eighth of a second's worth of transition moved it")
	assert_lt(stepped, SkyRigScript.fog_density(STORM),
		"but it must not have arrived yet; TRANSITION_SECONDS is %.1f" % SkyRigScript.TRANSITION_SECONDS)

	for i in range(400):
		_rig.step(0.5)
	assert_almost_eq(_environment.fog_density, SkyRigScript.fog_density(STORM), 0.0001,
		"and it does arrive if you wait")


func test_current_targets_reports_what_was_asked_for() -> void:
	_build_world()
	_rig.apply(_pinned_state(NIGHT, STORM))
	var targets: Dictionary = _rig.current_targets()
	assert_almost_eq(float(targets["fog_density"]), SkyRigScript.fog_density(STORM), 0.000001)
	assert_eq(int(targets["rain_amount"]), SkyRigScript.rain_amount(STORM))
	assert_almost_eq(float(targets["sun_elevation"]),
		SkyRigScript.sun_elevation_degrees(NIGHT, 0.5), 0.01)


func test_a_rig_nobody_ever_applied_leaves_the_scene_exactly_as_it_found_it() -> void:
	# ranch.tscn carries a SkyRig from this task on, but game/world/ranch.gd does not
	# call apply() until a later task wires it up. Until then the rig must be furniture.
	_build_world()
	assert_almost_eq(_sun.light_energy, 1.15, 0.0001, "the scene's own sun energy stands")
	assert_almost_eq(_environment.fog_density, 0.0011, 0.000001, "and its own fog density")
	assert_eq(_sky_material.sky_top_color, Color(0.309804, 0.505882, 0.760784))
	var rain: GPUParticles3D = _rig.get_node("Rain")
	assert_false(rain.emitting, "and nothing is raining on an unwired rig")
	assert_false(_rig.is_processing(), "an unwired rig does not even tick")


func test_the_rain_follows_whoever_it_was_told_to() -> void:
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, RAIN))
	var walker := Node3D.new()
	walker.name = "Walker"
	_world.add_child(walker)
	walker.global_position = Vector3(31.0, 2.0, -17.0)

	_rig.follow(walker)
	_rig.step(0.016)
	var rain: GPUParticles3D = _rig.get_node("Rain")
	assert_almost_eq(rain.global_position.x, 31.0, 0.001, "the cloud is over her head")
	assert_almost_eq(rain.global_position.z, -17.0, 0.001)
	assert_gt(rain.global_position.y, walker.global_position.y,
		"and above her, or it is not rain")

	walker.global_position = Vector3(-8.0, 2.0, 44.0)
	_rig.step(0.016)
	assert_almost_eq(rain.global_position.x, -8.0, 0.001, "it goes where she goes")
	assert_almost_eq(rain.global_position.z, 44.0, 0.001)
