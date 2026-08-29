class_name SkyRig
extends Node3D
## THE SKY, DRIVEN BY THE CLOCK. game/systems/world_state.gd says what time it is and what
## the weather is doing; this node is the only thing that turns that answer into photons.
## It moves the ranch's DirectionalLight3D along an arc, retints its light, repaints the
## ProceduralSkyMaterial's two colours, thickens the WorldEnvironment's fog and turns a
## GPUParticles3D of falling streaks on and off.
##
## THE MAPPING IS PURE AND STATIC, the scene writing is not. Every question of the form
## "what colour is a stormy dusk" is a static function of (phase, weather) with no node in
## sight, so game/test/test_sky_rig.gd can check the whole palette without a viewport, and
## so the HUD or a future indoor scene can ask the same question without owning a sky.
## apply() only decides which answers to walk toward.
##
## NOTHING SNAPS. A phase flip is a discontinuity in the clock but must not be one on
## screen, so apply() sets a target and step() eases every value toward it at
## delta / TRANSITION_SECONDS per frame. apply_immediately() is the exception, for boot and
## for gates, where there is no previous sky to ease away from.
##
## AN UNWIRED RIG IS FURNITURE. This node sits in game/world/ranch.tscn from the moment it
## exists, but processing is off until somebody calls apply(), apply_immediately() or
## follow(). Until then it touches nothing: the scene's own hand authored sun, sky and fog
## stand exactly as they were saved.
##
## Preloaded BY PATH by its consumers, never by this `class_name`, per the convention
## documented at the top of game/scripts/pony_rig.gd.

const WorldStateScript := preload("res://systems/world_state.gd")

## How long a full sky change takes. Long enough that a phase flip reads as the light
## changing rather than as a cut, short enough that a player who pins the weather from a
## debug gate is not left waiting.
const TRANSITION_SECONDS := 8.0

## THE ARC, IN DEGREES ABOVE THE HORIZON. DAWN lifts the sun out of the ground, DAY carries
## it up to ELEVATION_NOON and back down, DUSK drops it, NIGHT parks it well under so the
## directional light rakes upward and contributes nothing but its moonish tint.
const ELEVATION_HORIZON_DIP := -4.0
const ELEVATION_DAY_EDGE := 20.0
const ELEVATION_NOON := 60.0
const ELEVATION_NIGHT := -12.0

## THE BEARING, IN DEGREES OF YAW. It sweeps one way across DAWN, DAY and DUSK (east to
## west) and is parked at the western value all night, because there is no sun up there to
## move and a rotating moonlight would read as a bug.
const AZIMUTH_EAST := 90.0
const AZIMUTH_DAY_START := 45.0
const AZIMUTH_DAY_END := -45.0
const AZIMUTH_WEST := -90.0

## Indexed by WorldState.Phase.
const PHASE_LIGHT_COLORS: Array[Color] = [
	Color(1.0, 0.78, 0.60),
	Color(1.0, 0.97, 0.91),
	Color(1.0, 0.62, 0.45),
	Color(0.55, 0.62, 0.85),
]
## DAY's 1.15 is the value game/world/ranch.tscn was hand lit at, so a clear noon looks
## exactly like the ranch always has and every other hour is measured against it.
const PHASE_LIGHT_ENERGY: Array[float] = [0.62, 1.15, 0.58, 0.25]
const PHASE_SKY_TOP: Array[Color] = [
	Color(0.62, 0.55, 0.70),
	Color(0.31, 0.51, 0.76),
	Color(0.58, 0.40, 0.55),
	Color(0.05, 0.07, 0.15),
]
## DAY's 0.32 is likewise ranch.tscn's own ambient_light_energy.
const PHASE_AMBIENT_ENERGY: Array[float] = [0.24, 0.32, 0.22, 0.10]

## THE HORIZON IS THE ZENITH, PALED. ranch.tscn's hand picked pair (top 0.309804,
## 0.505882, 0.760784 against horizon 0.717647, 0.803922, 0.870588) is a per channel ratio,
## not an offset: the red end lifts more than twice as much as the blue end, which is what
## makes the band near the ground read as haze instead of as a lighter shade of the same
## sky. Every other phase's horizon is that same ratio applied to its own zenith, so DAWN
## and DUSK inherit the ranch's atmosphere for free.
const HORIZON_RATIO := Vector3(2.31649, 1.58913, 1.14433)

## Indexed by WorldState.Weather. Energy is multiplied, so the phase decides the hour and
## the weather decides how much of that hour gets through the cloud.
const WEATHER_ENERGY_SCALE: Array[float] = [1.0, 0.7, 0.6, 0.45]
## How far the light's colour is dragged toward WEATHER_TINTS.
const WEATHER_TINT_BLEND: Array[float] = [0.0, 0.35, 0.45, 0.55]
const WEATHER_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.72, 0.78, 0.86),
	Color(0.82, 0.85, 0.88),
	Color(0.62, 0.66, 0.78),
]
## Weather flattens the sky toward its own grey and then darkens it. Working from the
## zenith's OWN luminance rather than from a fixed grey is what keeps a foggy midnight
## dark: a fixed pale grey would have lit the night sky up brighter than a clear noon.
const WEATHER_SKY_DESATURATION: Array[float] = [0.0, 0.55, 0.75, 0.60]
const WEATHER_SKY_DARKEN: Array[float] = [1.0, 0.75, 0.85, 0.55]

const WEATHER_FOG_DENSITY: Array[float] = [0.0011, 0.004, 0.018, 0.008]
## Drops alive at once. Rain is a wash of streaks around the player, not a simulation of a
## storm front, so these are tuned to read from the camera's usual distance and no further.
const WEATHER_RAIN_AMOUNT: Array[int] = [0, 600, 0, 1400]

## Never let the world go absolutely black; a stormy night still has to be playable.
const MIN_LIGHT_ENERGY := 0.06
const MIN_AMBIENT_ENERGY := 0.05

## The rain column: a 14 by 14 metre box of emitters one metre thick, RAIN_HEIGHT above
## whoever follow() was given, falling at RAIN_GRAVITY for RAIN_LIFETIME seconds.
const RAIN_HEIGHT := 9.0
const RAIN_BOX_EXTENTS := Vector3(7.0, 0.5, 7.0)
const RAIN_GRAVITY := Vector3(0.0, -18.0, 0.0)
const RAIN_LIFETIME := 1.2
const RAIN_DROP_SIZE := Vector3(0.02, 0.5, 0.02)
const RAIN_COLOR := Color(0.72, 0.80, 0.92, 0.55)

const KEY_SUN_ELEVATION := "sun_elevation"
const KEY_SUN_AZIMUTH := "sun_azimuth"
const KEY_LIGHT_ENERGY := "light_energy"
const KEY_LIGHT_COLOR := "light_color"
const KEY_SKY_TOP := "sky_top"
const KEY_SKY_HORIZON := "sky_horizon"
const KEY_AMBIENT_ENERGY := "ambient_energy"
const KEY_FOG_DENSITY := "fog_density"
const KEY_RAIN_AMOUNT := "rain_amount"

## Left empty to fall back to a sibling search; ranch.tscn sets both explicitly.
@export var sun_path: NodePath
@export var environment_path: NodePath

var _sun: DirectionalLight3D
var _world_environment: WorldEnvironment
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _rain: GPUParticles3D
var _follow_target: Node3D

## What the sky is being asked to become, and where it has actually got to. Both are keyed
## by the KEY_* constants above; floats are eased with lerpf and Colors with Color.lerp.
var _targets := {}
var _current := {}
var _has_targets := false
## The last count actually written to the emitter, so an unchanged sky does not restart the
## particle system every frame (setting `amount` reallocates it).
var _rain_written := -1


func _ready() -> void:
	_resolve_nodes()
	_ensure_rain()
	set_process(false)


# === the pure mapping ===

## Degrees above the horizon. Negative is below it. Continuous across every phase boundary,
## which game/test/test_sky_rig.gd asserts: the end of DAWN and the start of DAY are the
## same instant and the sun may not jump between them.
static func sun_elevation_degrees(phase: int, progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if phase == WorldStateScript.Phase.DAWN:
		return lerpf(ELEVATION_HORIZON_DIP, ELEVATION_DAY_EDGE, p)
	if phase == WorldStateScript.Phase.DAY:
		if p <= 0.5:
			return lerpf(ELEVATION_DAY_EDGE, ELEVATION_NOON, p * 2.0)
		return lerpf(ELEVATION_NOON, ELEVATION_DAY_EDGE, (p - 0.5) * 2.0)
	if phase == WorldStateScript.Phase.DUSK:
		return lerpf(ELEVATION_DAY_EDGE, ELEVATION_HORIZON_DIP, p)
	return ELEVATION_NIGHT


## Degrees of yaw, decreasing east to west across the lit phases and parked at night.
static func sun_azimuth_degrees(phase: int, progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if phase == WorldStateScript.Phase.DAWN:
		return lerpf(AZIMUTH_EAST, AZIMUTH_DAY_START, p)
	if phase == WorldStateScript.Phase.DAY:
		return lerpf(AZIMUTH_DAY_START, AZIMUTH_DAY_END, p)
	if phase == WorldStateScript.Phase.DUSK:
		return lerpf(AZIMUTH_DAY_END, AZIMUTH_WEST, p)
	return AZIMUTH_WEST


static func light_energy(phase: int, weather: int) -> float:
	var base: float = PHASE_LIGHT_ENERGY[_phase_index(phase)]
	return maxf(MIN_LIGHT_ENERGY, base * WEATHER_ENERGY_SCALE[_weather_index(weather)])


static func light_color(phase: int, weather: int) -> Color:
	var base: Color = PHASE_LIGHT_COLORS[_phase_index(phase)]
	var w := _weather_index(weather)
	return base.lerp(WEATHER_TINTS[w], WEATHER_TINT_BLEND[w])


static func sky_top(phase: int, weather: int) -> Color:
	var base: Color = PHASE_SKY_TOP[_phase_index(phase)]
	var w := _weather_index(weather)
	var grey := base.get_luminance()
	var flattened := base.lerp(Color(grey, grey, grey), WEATHER_SKY_DESATURATION[w])
	var darken: float = WEATHER_SKY_DARKEN[w]
	return Color(flattened.r * darken, flattened.g * darken, flattened.b * darken)


static func sky_horizon(phase: int, weather: int) -> Color:
	var top := sky_top(phase, weather)
	return Color(
		minf(1.0, top.r * HORIZON_RATIO.x),
		minf(1.0, top.g * HORIZON_RATIO.y),
		minf(1.0, top.b * HORIZON_RATIO.z))


static func ambient_energy(phase: int, weather: int) -> float:
	var base: float = PHASE_AMBIENT_ENERGY[_phase_index(phase)]
	return maxf(MIN_AMBIENT_ENERGY, base * WEATHER_ENERGY_SCALE[_weather_index(weather)])


static func fog_density(weather: int) -> float:
	return WEATHER_FOG_DENSITY[_weather_index(weather)]


## Drops alive at once. FOG is deliberately dry: it is a thickness, not a downpour.
static func rain_amount(weather: int) -> int:
	return WEATHER_RAIN_AMOUNT[_weather_index(weather)]


static func _phase_index(phase: int) -> int:
	return clampi(phase, 0, PHASE_LIGHT_COLORS.size() - 1)


static func _weather_index(weather: int) -> int:
	return clampi(weather, 0, WEATHER_ENERGY_SCALE.size() - 1)


# === driving a scene ===

## Ease the sky toward whatever `state` currently says, over TRANSITION_SECONDS.
##
## A PINNED STATE HAS NO MEANINGFUL phase_progress(): pin() sets the phase without moving
## the clock, so its progress still reads wherever the clock happened to be. A pinned
## reading is therefore taken as mid phase (0.5), which makes a pinned DAY read as noon.
func apply(state: WorldState) -> void:
	if state == null:
		return
	_set_targets_from(state)
	set_process(true)


## The same, with no transition. For boot, where there is no previous sky to ease from, and
## for gates, which must not have to spin frames to see the answer.
func apply_immediately(state: WorldState) -> void:
	if state == null:
		return
	_set_targets_from(state)
	_current = _targets.duplicate(true)
	_write_to_scene()
	set_process(true)


## What the rig is walking toward, for gates and for the HUD. A copy; editing it changes
## nothing.
func current_targets() -> Dictionary:
	return _targets.duplicate(true)


## The rain follows one node, normally the player: the emitter is a small box overhead, not
## a lid over the whole 220 metre map, so it has to travel with whoever is being rained on.
func follow(target: Node3D) -> void:
	_follow_target = target
	_track_follow()
	set_process(true)


func _process(delta: float) -> void:
	step(delta)


## Advance the eased transition by `delta`. _process() calls this every frame; tests and
## gates call it directly rather than waiting on real frames.
func step(delta: float) -> void:
	_track_follow()
	if not _has_targets:
		return
	var weight := clampf(delta / TRANSITION_SECONDS, 0.0, 1.0)
	for key in _targets:
		var target_value: Variant = _targets[key]
		if not _current.has(key):
			_current[key] = target_value
			continue
		if key == KEY_RAIN_AMOUNT:
			# A drop count cannot be half changed: the emitter reallocates on any change,
			# so it switches at the start of the transition rather than crawling.
			_current[key] = target_value
			continue
		if target_value is Color:
			var from_color: Color = _current[key]
			_current[key] = from_color.lerp(target_value, weight)
		else:
			var from_value: float = float(_current[key])
			_current[key] = lerpf(from_value, float(target_value), weight)
	_write_to_scene()


func _set_targets_from(state: WorldState) -> void:
	var phase: int = state.phase()
	var weather: int = state.weather()
	var progress: float = 0.5
	if not state.is_pinned():
		progress = state.phase_progress()
	_targets = {
		KEY_SUN_ELEVATION: sun_elevation_degrees(phase, progress),
		KEY_SUN_AZIMUTH: sun_azimuth_degrees(phase, progress),
		KEY_LIGHT_ENERGY: light_energy(phase, weather),
		KEY_LIGHT_COLOR: light_color(phase, weather),
		KEY_SKY_TOP: sky_top(phase, weather),
		KEY_SKY_HORIZON: sky_horizon(phase, weather),
		KEY_AMBIENT_ENERGY: ambient_energy(phase, weather),
		KEY_FOG_DENSITY: fog_density(weather),
		KEY_RAIN_AMOUNT: rain_amount(weather),
	}
	_has_targets = true


func _write_to_scene() -> void:
	if _sun == null or _environment == null:
		_resolve_nodes()
	if _sun != null:
		_sun.rotation_degrees = Vector3(
			-float(_current.get(KEY_SUN_ELEVATION, ELEVATION_DAY_EDGE)),
			float(_current.get(KEY_SUN_AZIMUTH, AZIMUTH_DAY_START)),
			0.0)
		_sun.light_energy = float(_current.get(KEY_LIGHT_ENERGY, 1.0))
		_sun.light_color = _current.get(KEY_LIGHT_COLOR, _sun.light_color)
	var horizon: Color = _current.get(KEY_SKY_HORIZON, Color.WHITE)
	if _environment != null:
		_environment.ambient_light_energy = float(_current.get(KEY_AMBIENT_ENERGY, 0.32))
		_environment.fog_density = float(_current.get(KEY_FOG_DENSITY, WEATHER_FOG_DENSITY[0]))
		# The fog is lit by the same air the horizon band is, so it takes that colour and
		# a night fog goes dark instead of glowing white in the dark.
		_environment.fog_light_color = horizon
	if _sky_material != null:
		_sky_material.sky_top_color = _current.get(KEY_SKY_TOP, _sky_material.sky_top_color)
		_sky_material.sky_horizon_color = horizon
	_write_rain()


func _write_rain() -> void:
	if _rain == null:
		_ensure_rain()
	if _rain == null:
		return
	var wanted: int = int(_current.get(KEY_RAIN_AMOUNT, 0))
	if wanted != _rain_written:
		_rain_written = wanted
		# GPUParticles3D refuses an amount of zero, so a dry sky keeps one unused drop and
		# is switched off by `emitting` instead.
		_rain.amount = maxi(1, wanted)
	_rain.emitting = wanted > 0


func _track_follow() -> void:
	if _rain == null or _follow_target == null or not is_instance_valid(_follow_target):
		return
	if not _follow_target.is_inside_tree() or not _rain.is_inside_tree():
		return
	_rain.global_position = _follow_target.global_position + Vector3(0.0, RAIN_HEIGHT, 0.0)


func _resolve_nodes() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun == null:
		_sun = _find_sibling("DirectionalLight3D") as DirectionalLight3D
	_world_environment = get_node_or_null(environment_path) as WorldEnvironment
	if _world_environment == null:
		_world_environment = _find_sibling("WorldEnvironment") as WorldEnvironment
	_environment = null
	_sky_material = null
	if _world_environment != null:
		_environment = _world_environment.environment
	if _environment != null and _environment.sky != null:
		_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial


## A rig whose exported paths were left empty still finds the scene's lighting, so a test
## world or a spare scene can drop the node in without wiring anything.
func _find_sibling(type_name: String) -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child.is_class(type_name):
			return child
	return null


## The emitter is authored here rather than in the scene file so a rig built in code gets
## exactly the same rain as ranch.tscn's, and so the one set of numbers is the one that
## ships. ranch.tscn carries only a bare, silent GPUParticles3D named Rain for this to find.
func _ensure_rain() -> void:
	if _rain != null and is_instance_valid(_rain):
		return
	var found := get_node_or_null(NodePath("Rain")) as GPUParticles3D
	if found == null:
		found = GPUParticles3D.new()
		found.name = "Rain"
		add_child(found)
	_rain = found

	var drop := BoxMesh.new()
	drop.size = RAIN_DROP_SIZE
	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = RAIN_COLOR
	drop.material = drop_material

	var process_material := ParticleProcessMaterial.new()
	process_material.gravity = RAIN_GRAVITY
	process_material.direction = Vector3(0.0, -1.0, 0.0)
	process_material.spread = 0.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 2.5
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = RAIN_BOX_EXTENTS
	process_material.scale_min = 0.85
	process_material.scale_max = 1.35

	_rain.draw_pass_1 = drop
	_rain.process_material = process_material
	_rain.lifetime = RAIN_LIFETIME
	# A drop's whole life is a fall, so the column has to be pre filled or the first second
	# of every shower is empty sky.
	_rain.preprocess = RAIN_LIFETIME
	_rain.local_coords = false
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The emitter box is small but the drops leave it; without a generous bound the whole
	# shower pops out of existence as the camera turns.
	_rain.visibility_aabb = AABB(Vector3(-12.0, -22.0, -12.0), Vector3(24.0, 30.0, 24.0))
	_rain.amount = 1
	_rain.emitting = false
	_rain_written = 0
	_track_follow()
