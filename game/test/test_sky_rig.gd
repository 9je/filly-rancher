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


func test_a_stormy_night_keeps_the_ambient_that_makes_it_playable() -> void:
	# 0.70 base x 0.7 night-only floor = 0.49, and both terms are load bearing. The 0.70 is
	# PHASE_AMBIENT_ENERGY[NIGHT]; the 0.7 is NIGHT_WEATHER_FLOOR standing in for a storm's
	# own 0.45, which applied on top of the darkest phase takes the fill past the point
	# where the ranch is legible. 0.49 lands on about 0.122 of effective ambient luminance
	# and the ranch stops being playable below roughly 0.12, so this is the darkest a night
	# is allowed to get. It is a ruling, not a taste, and nothing else in the suite pins it:
	# the ordering tests are about light_energy and sky luminance, and both hold at any
	# ambient at all.
	assert_almost_eq(SkyRigScript.ambient_energy(NIGHT, STORM), 0.49, 0.001,
		"a stormy night's ambient is 0.70 base x 0.7 night-only floor = 0.49")


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
	assert_eq(SkyRigScript.light_color(DAWN, CLEAR), Color(1.0, 0.84, 0.68))
	assert_eq(SkyRigScript.light_color(DUSK, CLEAR), Color(1.0, 0.62, 0.45))
	assert_eq(SkyRigScript.light_color(NIGHT, CLEAR), Color(0.55, 0.62, 0.85))
	assert_almost_eq(SkyRigScript.light_energy(NIGHT, CLEAR), 0.38, 0.0001)
	assert_eq(SkyRigScript.sky_top(DAY, CLEAR), Color(0.31, 0.51, 0.76))
	assert_eq(SkyRigScript.sky_top(DAWN, CLEAR), Color(0.50, 0.62, 0.88))
	assert_eq(SkyRigScript.sky_top(DUSK, CLEAR), Color(0.58, 0.40, 0.55))
	assert_eq(SkyRigScript.sky_top(NIGHT, CLEAR), Color(0.06, 0.08, 0.18))


func test_rain_and_a_storm_are_greyer_and_darker_than_the_clear_sky_of_the_same_hour() -> void:
	# The defect this is here for: the horizon used to be the zenith times a per channel
	# ratio, which CLAMPED for a clear sky and did not for a wet one, so a rainy dawn came
	# back more colourful than a clear dawn and the weather read backwards. Both halves are
	# asserted, at every hour, because either one alone can hold while the sky still looks
	# wrong: paler but not duller is haze, duller but not paler is nightfall.
	for phase in [DAWN, DAY, DUSK, NIGHT]:
		var clear_top: Color = SkyRigScript.sky_top(phase, CLEAR)
		var clear_horizon: Color = SkyRigScript.sky_horizon(phase, CLEAR)
		for weather in [RAIN, STORM]:
			var top: Color = SkyRigScript.sky_top(phase, weather)
			var horizon: Color = SkyRigScript.sky_horizon(phase, weather)
			assert_lt(top.get_luminance(), clear_top.get_luminance(),
				"phase %d weather %d: the zenith must darken, not brighten" % [phase, weather])
			assert_lt(horizon.get_luminance(), clear_horizon.get_luminance(),
				"phase %d weather %d: the horizon must darken too" % [phase, weather])
			assert_lt(top.s, clear_top.s,
				"phase %d weather %d: the zenith must lose colour" % [phase, weather])
			assert_lt(horizon.s, clear_horizon.s,
				"phase %d weather %d: the horizon must lose colour" % [phase, weather])


func test_the_blue_hours_never_turn_warm_under_weather() -> void:
	# "A rainy sky must read cooler, never warmer." Stated as a comparison against the same
	# hour's clear sky, that claim cannot be made to hold and should not be asserted: any
	# desaturation of a BLUE sky raises red relative to blue by arithmetic, so a grey rainy
	# noon is always warmer THAN A CLEAR NOON on a red minus blue reading, whatever greys
	# are chosen. What can be asserted, and what actually broke, is the absolute version:
	# DAY and NIGHT are the blue hours, and no weather may tip them over into red. The old
	# ratio did exactly that (a rainy day's horizon came out (0.71, 0.59, 0.52), a sunset in
	# the middle of the afternoon), and this fails on it.
	for phase in [DAY, NIGHT]:
		for weather in [CLEAR, RAIN, FOG, STORM]:
			var top: Color = SkyRigScript.sky_top(phase, weather)
			var horizon: Color = SkyRigScript.sky_horizon(phase, weather)
			assert_lt(top.r, top.b,
				"phase %d weather %d: the zenith went warm" % [phase, weather])
			assert_lt(horizon.r, horizon.b,
				"phase %d weather %d: the horizon went warm" % [phase, weather])


func test_the_horizon_never_clamps_a_channel() -> void:
	# A channel sitting at exactly 1.0 is the fingerprint of the ratio this replaced: the
	# value ran off the top of the gamut and was cut off there, which is what flattened a
	# clear dawn into a white wash and what made CLEAR the only weather that clipped.
	for phase in [DAWN, DAY, DUSK, NIGHT]:
		for weather in [CLEAR, RAIN, FOG, STORM]:
			var horizon: Color = SkyRigScript.sky_horizon(phase, weather)
			for channel in [horizon.r, horizon.g, horizon.b]:
				assert_lt(channel, 1.0,
					"phase %d weather %d clamped a channel at white" % [phase, weather])


func test_the_ground_half_of_the_sky_goes_dark_at_night() -> void:
	# ProceduralSkyMaterial paints below the skyline as well as above it, and the rig used
	# to drive only the half above. ranch.tscn authors the half below as daylight grass, so
	# every night shot had a bright green band running the whole way round the horizon under
	# a near black zenith.
	var night: Color = SkyRigScript.ground_horizon(NIGHT, CLEAR)
	assert_lt(night.get_luminance(), 0.1, "a night ground band must be genuinely dark")
	assert_lt(night.get_luminance(), SkyRigScript.ground_horizon(DAY, CLEAR).get_luminance(),
		"and darker than the same band by day")
	assert_gt(night.b, night.g, "and blue, which is what moonlight on grass looks like")
	assert_lt(SkyRigScript.ground_bottom(NIGHT, CLEAR).get_luminance(),
		night.get_luminance(), "straight down is darker still than the band at the rim")


func test_the_night_is_strictly_darker_than_the_day_in_every_driven_value() -> void:
	# Weather scales both hours by the same factor, so this has to hold in all four of them
	# or one of the weather tables has quietly stood the clock on its head.
	#
	# AMBIENT ENERGY IS DELIBERATELY NOT ON THIS LIST, and used to be. Energy is only half of
	# an ambient: the Environment multiplies it by ambient_light_color, and since ruling 18
	# the rig drives that colour too. The night's fill colour is a dim blue moonlight and the
	# day's is a bright skylight, so the same amount of light on screen needs a much larger
	# number at night. With NIGHT_WEATHER_FLOOR holding a stormy night at 0.49 against a
	# stormy day's 0.144, asserting an ordering on the multiplier alone would be asserting
	# that a night is darker by comparing two numbers that are not in the same units. What
	# reaches the eye is asserted here on light_energy and on sky_top luminance instead, and
	# the fill light's own colour is ordered in
	# test_the_night_fills_its_shadows_with_blue_moonlight below.
	for weather in [CLEAR, RAIN, FOG, STORM]:
		assert_lt(SkyRigScript.light_energy(NIGHT, weather),
			SkyRigScript.light_energy(DAY, weather), "sunlight, weather %d" % weather)
		assert_lt(SkyRigScript.sky_top(NIGHT, weather).get_luminance(),
			SkyRigScript.sky_top(DAY, weather).get_luminance(), "zenith, weather %d" % weather)
		assert_lt(SkyRigScript.sky_horizon(NIGHT, weather).get_luminance(),
			SkyRigScript.sky_horizon(DAY, weather).get_luminance(), "horizon, weather %d" % weather)
		assert_lt(SkyRigScript.ground_horizon(NIGHT, weather).get_luminance(),
			SkyRigScript.ground_horizon(DAY, weather).get_luminance(),
			"ground band, weather %d" % weather)
		assert_lt(SkyRigScript.ground_bottom(NIGHT, weather).get_luminance(),
			SkyRigScript.ground_bottom(DAY, weather).get_luminance(),
			"ground below, weather %d" % weather)


func test_the_night_fills_its_shadows_with_blue_moonlight() -> void:
	# The Environment takes 65% of its ambient colour from this and only 35% from the sky, so
	# this is the colour a player actually sees in the shadows. It has to be blue, or a night
	# reads as an underexposed day, and it has to be darker than the day's or the phases are
	# the wrong way round in the one value that is not the energy.
	var night: Color = SkyRigScript.ambient_light_color(NIGHT, CLEAR)
	var day: Color = SkyRigScript.ambient_light_color(DAY, CLEAR)
	assert_gt(night.b, night.r,
		"moonlight is blue: got r %.3f b %.3f" % [night.r, night.b])
	assert_lt(night.get_luminance(), day.get_luminance(),
		"and dimmer than the daylight skylight it replaces")
	for weather in [CLEAR, RAIN, FOG, STORM]:
		assert_lt(SkyRigScript.ambient_light_color(NIGHT, weather).get_luminance(),
			SkyRigScript.ambient_light_color(DAY, weather).get_luminance(),
			"fill colour, weather %d" % weather)


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
	assert_almost_eq(SkyRigScript.fog_density(FOG), 0.010, 0.000001)
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
	# ranch.tscn's own daylight grass, so a test that says the rig repaints the ground half
	# is repainting the same green the ranch actually ships.
	_sky_material.ground_bottom_color = Color(0.219608, 0.294118, 0.196078)
	_sky_material.ground_horizon_color = Color(0.415686, 0.529412, 0.34902)
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# ranch.tscn's own split and its own hand authored fill colour, so a test that says the
	# rig repaints the ambient is repainting the same daylight blue the ranch ships. Read
	# off the rig's own constant rather than typed again: the split is the rig's contract
	# (see AMBIENT_SKY_CONTRIBUTION), and a copy of it here would quietly disagree the day
	# somebody retuned it.
	_environment.ambient_light_sky_contribution = SkyRigScript.AMBIENT_SKY_CONTRIBUTION
	_environment.ambient_light_color = Color(0.729412, 0.803922, 0.878431)
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


func test_the_rig_paints_the_ground_half_of_the_sky_too() -> void:
	# The pure test above says what the colours should be; this says they actually reach the
	# material. A rig that computed a dark blue ground band and never wrote it would pass
	# every arithmetic test in this file and still leave the green band on screen.
	_build_world()
	var daylight_grass: Color = _sky_material.ground_horizon_color
	_rig.apply_immediately(_pinned_state(NIGHT, CLEAR))

	assert_almost_eq(_sky_material.ground_horizon_color.get_luminance(),
		SkyRigScript.ground_horizon(NIGHT, CLEAR).get_luminance(), 0.001,
		"the band under the skyline is the rig's, not the scene's")
	assert_almost_eq(_sky_material.ground_bottom_color.get_luminance(),
		SkyRigScript.ground_bottom(NIGHT, CLEAR).get_luminance(), 0.001,
		"and so is the colour straight down")
	assert_lt(_sky_material.ground_horizon_color.get_luminance(),
		daylight_grass.get_luminance() * 0.5,
		"a night ground band must be nothing like the daylight grass it replaced")

	# And the fill light, which is the other half of the same fix: a rig that darkened the
	# ground half of the sky without also writing a moonlight ambient would leave exactly the
	# unplayable night this ruling exists to undo.
	var wanted: Color = SkyRigScript.ambient_light_color(NIGHT, CLEAR)
	assert_almost_eq(_environment.ambient_light_color.r, wanted.r, 0.001,
		"the fill light's red reached the Environment")
	assert_almost_eq(_environment.ambient_light_color.g, wanted.g, 0.001,
		"and its green")
	assert_almost_eq(_environment.ambient_light_color.b, wanted.b, 0.001,
		"and its blue, which is the one that makes it moonlight")
	assert_almost_eq(_environment.ambient_light_energy,
		SkyRigScript.ambient_energy(NIGHT, CLEAR), 0.001,
		"and the energy it is multiplied by")


func test_the_rig_pins_the_ambient_split_its_own_energies_assume() -> void:
	# Every number in PHASE_AMBIENT_ENERGY is arithmetic done against a 35/65 split between
	# the sky and the fill colour, so the split is the rig's to write and not the scene's to
	# choose. This Environment is put back to the engine's own defaults first (all of the
	# ambient sampled off the sky) because that is the failure worth catching: at NIGHT the
	# sky is a zenith of luminance 0.04, so a scene saved that way blacks the ranch out
	# while every pure test in this file goes on passing.
	_build_world()
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	_environment.ambient_light_sky_contribution = 1.0

	_rig.apply_immediately(_pinned_state(NIGHT, CLEAR))

	assert_eq(_environment.ambient_light_source, Environment.AMBIENT_SOURCE_SKY,
		"the ambient is mixed from the sky and the fill colour, which is what the split means")
	assert_almost_eq(_environment.ambient_light_sky_contribution,
		SkyRigScript.AMBIENT_SKY_CONTRIBUTION, 0.0001,
		"and only AMBIENT_SKY_CONTRIBUTION of it comes off the sky")


func test_a_pinned_clear_day_puts_the_sun_up_and_the_rain_away() -> void:
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))

	assert_lt(_sun.rotation_degrees.x, 0.0, "a pinned DAY reads as noon; the sun is up")
	assert_almost_eq(_sun.rotation_degrees.x, -SkyRigScript.ELEVATION_NOON, 0.01,
		"a pinned state has no meaningful progress, so it is read as mid phase")
	assert_almost_eq(_environment.fog_density, SkyRigScript.fog_density(CLEAR), 0.000001)

	var rain: GPUParticles3D = _rig.get_node("Rain")
	assert_false(rain.emitting, "nothing falls out of a clear sky")


func test_a_transition_is_a_ramp_that_actually_arrives() -> void:
	# TRANSITION_SECONDS is a duration, not a decay constant: half of it must land strictly
	# between the two skies and all of it must land EXACTLY on the target, not merely near
	# it. Lerping the current value toward the target every frame passes the "near it" test
	# and fails this one, which is the whole point of asserting equality here.
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))
	var clear_density: float = _environment.fog_density

	_rig.apply(_pinned_state(NIGHT, STORM))
	assert_eq(_environment.fog_density, clear_density,
		"apply() only aims the rig; nothing moves until the first step()")

	_rig.step(SkyRigScript.TRANSITION_SECONDS * 0.5)
	var halfway: float = _environment.fog_density
	assert_gt(halfway, clear_density, "half a ramp has left the clear sky behind")
	assert_lt(halfway, SkyRigScript.fog_density(STORM), "and has not arrived at the storm")

	_rig.step(SkyRigScript.TRANSITION_SECONDS * 0.5)
	# Read the arrival off the rig, not off the light: Environment.fog_density and
	# DirectionalLight3D.light_energy are 32 bit float properties, so a value that IS exact
	# comes back off them a rounding error away from the double it went in as.
	var arrived: Dictionary = _rig.current_values()
	assert_eq(float(arrived["fog_density"]), SkyRigScript.fog_density(STORM),
		"a full TRANSITION_SECONDS of steps lands exactly on the target")
	assert_eq(float(arrived["light_energy"]), SkyRigScript.light_energy(NIGHT, STORM),
		"and lands the light exactly too, not a rounding error short")
	assert_almost_eq(_environment.fog_density, SkyRigScript.fog_density(STORM), 0.0000001,
		"and the scene has it, to whatever precision a float property can hold")


func test_an_arrived_transition_stops_ticking() -> void:
	_build_world()
	_rig.apply(_pinned_state(NIGHT, STORM))
	assert_true(_rig.is_processing(), "a rig mid ramp has work to do")
	_rig.step(SkyRigScript.TRANSITION_SECONDS)
	assert_false(_rig.is_processing(),
		"once it has arrived and nothing is being followed there is nothing left to do")


func test_reapplying_mid_ramp_carries_on_from_where_the_sky_actually_is() -> void:
	# The failure this guards against: re-photographing _from from the OLD transition's
	# start (or not re-photographing at all) makes the light jump backward to a phase it
	# has already left, which reads as a flicker.
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))
	_rig.apply(_pinned_state(NIGHT, STORM))
	_rig.step(SkyRigScript.TRANSITION_SECONDS * 0.5)
	var before: float = _sun.light_energy
	var before_color: Color = _sun.light_color

	_rig.apply(_pinned_state(DUSK, RAIN))
	assert_eq(_sun.light_energy, before, "the second apply must not move the light at all")
	assert_eq(_sun.light_color, before_color, "nor its colour")

	_rig.step(0.001)
	assert_almost_eq(_sun.light_energy, before, 0.01,
		"and the first step of the new ramp must leave from where the sky actually was")

	_rig.step(SkyRigScript.TRANSITION_SECONDS)
	assert_eq(float(_rig.current_values()["light_energy"]),
		SkyRigScript.light_energy(DUSK, RAIN), "the restarted ramp still arrives exactly")


func test_the_first_apply_eases_out_of_the_scenes_own_sky() -> void:
	# A fresh rig has never been told what the sky looks like, so without reading the
	# scene's hand lit values at _ready() the first transition of a session has no start
	# point and snaps. It must ramp out of the sun the scene was saved with.
	_build_world()
	var scene_energy: float = _sun.light_energy
	var night_energy: float = SkyRigScript.light_energy(NIGHT, STORM)

	_rig.apply(_pinned_state(NIGHT, STORM))
	_rig.step(0.5)
	assert_lt(_sun.light_energy, scene_energy,
		"half a second in, the light has started to fall away from the scene's own 1.15")
	assert_gt(_sun.light_energy, night_energy,
		"but it is nowhere near the stormy night yet; it must not have snapped")


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


# === sleeping and waking ===
#
# The rig turns its own _process off once its ramp has arrived and there is nothing left to
# carry, which is worth a third of a frame on a ranch that spends most of its cycle in a
# clear sky. It is also the kind of optimisation that quietly breaks a feature: a rig that
# went to sleep and did not wake up is a sky that stopped, and it looks exactly like a sky
# that had nothing to do. These three say when it sleeps and that both ways back up work.

func test_a_clear_sky_stops_ticking_even_with_somebody_to_follow() -> void:
	_build_world()
	var walker := Node3D.new()
	walker.name = "Walker"
	_world.add_child(walker)
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))
	_rig.follow(walker)
	assert_true(_rig.is_processing(), "follow() turns the rig on to place the cloud")

	_rig.step(0.016)
	assert_false(_rig.is_processing(),
		"but a clear sky has no cloud to carry, so an arrived rig goes back to furniture")


func test_apply_wakes_a_sleeping_rig_and_the_ramp_actually_runs() -> void:
	_build_world()
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))
	assert_false(_rig.is_processing(), "an arrived rig with nobody to follow is asleep")
	var day_energy: float = _sun.light_energy

	_rig.apply(_pinned_state(NIGHT, STORM))
	assert_true(_rig.is_processing(), "apply() is one of the two things that wake it")

	_rig.step(SkyRigScript.TRANSITION_SECONDS * 0.5)
	assert_lt(_sun.light_energy, day_energy,
		"and the ramp runs; a rig that woke without ramping is a sky that still stopped")


func test_a_shower_starting_on_a_sleeping_rig_puts_the_cloud_overhead_at_once() -> void:
	# The worst version of the sleep bug: the rig is asleep under a clear sky, the weather
	# turns, and the cloud spends the eight second ramp sitting wherever the player was
	# standing when it last rained. It cannot, because the drop count is the one target that
	# SNAPS at the start of a ramp rather than crawling, so the emitter is live on frame one
	# and step() asks for the follow AFTER the write that raised it.
	_build_world()
	var walker := Node3D.new()
	walker.name = "Walker"
	_world.add_child(walker)
	walker.global_position = Vector3(12.0, 0.0, -30.0)
	_rig.apply_immediately(_pinned_state(DAY, CLEAR))
	_rig.follow(walker)
	_rig.step(0.016)
	assert_false(_rig.is_processing(), "asleep under a clear sky, with a walker to follow")

	_rig.apply(_pinned_state(DAY, RAIN))
	assert_true(_rig.is_processing(), "a shower wakes it")
	_rig.step(0.016)

	var rain: GPUParticles3D = _rig.get_node("Rain")
	assert_eq(rain.amount, SkyRigScript.rain_amount(RAIN),
		"the drop count snaps on the first frame of the ramp rather than crawling")
	assert_true(rain.emitting, "so the shower is falling from that same frame")
	assert_almost_eq(rain.global_position.x, 12.0, 0.001,
		"and the very first step has the cloud over her head, not one frame behind her")
	assert_almost_eq(rain.global_position.z, -30.0, 0.001)


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
