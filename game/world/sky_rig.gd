class_name SkyRig
extends Node3D
## THE SKY, DRIVEN BY THE CLOCK. game/systems/world_state.gd says what time it is and what
## the weather is doing; this node is the only thing that turns that answer into photons.
## It moves the ranch's DirectionalLight3D along an arc, retints its light, repaints all
## four of the ProceduralSkyMaterial's colours (both halves of the sky, not just the half
## above the skyline), sets the WorldEnvironment's ambient fill colour and energy, thickens
## its fog and turns a GPUParticles3D of falling streaks on and off.
##
## THE MAPPING IS PURE AND STATIC, the scene writing is not. Every question of the form
## "what colour is a stormy dusk" is a static function of (phase, weather) with no node in
## sight, so game/test/test_sky_rig.gd can check the whole palette without a viewport, and
## so the HUD or a future indoor scene can ask the same question without owning a sky.
## apply() only decides which answers to walk toward.
##
## NOTHING SNAPS. A phase flip is a discontinuity in the clock but must not be one on
## screen, so apply() photographs the sky as it stands, sets a target, and step() walks a
## ramp from the one to the other in exactly TRANSITION_SECONDS of delta.
## apply_immediately() is the exception, for boot and for gates, where there is no previous
## sky to ease away from.
##
## AN UNWIRED RIG IS FURNITURE. This node sits in game/world/ranch.tscn from the moment it
## exists, but processing is off until somebody calls apply(), apply_immediately() or
## follow(). Until then it touches nothing: the scene's own hand authored sun, sky and fog
## stand exactly as they were saved.
##
## Preloaded BY PATH by its consumers, never by this `class_name`, per the convention
## documented at the top of game/scripts/pony_rig.gd.

const WorldStateScript := preload("res://systems/world_state.gd")

## How long a full sky change takes, and it means it: the transition is a ramp on a 0 to 1
## clock advanced by delta / TRANSITION_SECONDS, so after this many seconds of step() the
## sky is exactly on its target and stops. (Lerping the CURRENT value toward the target by
## that same fraction every frame, which is what this used to do, is exponential decay: it
## is 63% of the way after eight seconds and never actually arrives. The name promised a
## duration, so the code now owes one.) Long enough that a phase flip reads as the light
## changing rather than as a cut, short enough that a player who pins the weather from a
## debug gate is not left waiting.
const TRANSITION_SECONDS := 8.0

## The ramp is smoothstepped rather than linear, so the sky leaves and arrives gently and
## the two ends of a transition do not read as corners.
const USE_SMOOTHSTEP := true

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
## NIGHT's 0.38 is a playability number, not an art one. At 0.25 a stormy night scaled
## down to 0.11 and the ranch stopped being legible: a player who cannot see a pony cannot
## catch one. It stays far under every lit phase, which is what the ordering tests assert.
const PHASE_LIGHT_ENERGY: Array[float] = [0.62, 1.15, 0.58, 0.38]
const PHASE_SKY_TOP: Array[Color] = [
	Color(0.62, 0.55, 0.70),
	Color(0.31, 0.51, 0.76),
	Color(0.58, 0.40, 0.55),
	Color(0.06, 0.08, 0.18),
]
## HOW MUCH OF THE FINISHED AMBIENT IS SAMPLED OFF THE SKY, the rest coming off
## ambient_light_color. Every energy number below is arithmetic done against THIS split, so
## it is not the scene's to choose: _write_to_scene() writes it, and AMBIENT_SOURCE_SKY with
## it, onto whatever Environment it is pointed at. A scene saved with the engine default
## (1.0, all of it off the sky) would take the whole ambient off a night zenith of luminance
## 0.04 and black the ranch out, and nothing in a headless gate can see that happen.
const AMBIENT_SKY_CONTRIBUTION := 0.35

## DAY's 0.32 is likewise ranch.tscn's own ambient_light_energy. NIGHT's 0.70 is not an art
## number at all, it is the answer to an arithmetic one. Ambient is what fills the shadows
## the moon does not reach, and the Environment mixes its ambient from two sources: 35% off
## the sky (which at night is a zenith of luminance 0.04) and 65% off ambient_light_color
## (the moonlight below, luminance 0.36 once a storm has greyed it). The effective ambient
## luminance is therefore about 0.249 per unit of energy at NIGHT/STORM, and the ranch stops
## being playable below roughly 0.12 of it. 0.70 x 0.70 = 0.49 lands on 0.122. Anything
## smaller is a night a player cannot catch a pony in.
##
## IT IS THE NIGHT'S BASE, NOT A FLOOR UNDER IT, and the night is the one phase whose
## ordering against the day is NOT defined here: see the note on NIGHT_WEATHER_FLOOR.
const PHASE_AMBIENT_ENERGY: Array[float] = [0.24, 0.32, 0.22, 0.70]

## THE COLOUR OF THE FILL LIGHT, which is a separate question from how much of it there is.
## ranch.tscn's Environment now takes only 35% of its ambient colour off the sky and 65% off
## this, so these four are what actually lifts the shadows: a warm low sun at DAWN and DUSK,
## a cool skylight at DAY, and at NIGHT a moonlight that is deliberately blue, because a
## night lit by a neutral grey reads as an underexposed day rather than as moonlight.
##
## WHY THE SPLIT MOVED. It used to be 85% sky, which was fine only while the sky's lower
## hemisphere was accidentally daylight grass. Driving that half correctly (see
## GROUND_HORIZON_DARKEN) removed the accidental fill and left all four NIGHT cells of the
## sky sheet too dark to play in. The fix is to stop asking a night sky to be a lamp.
const PHASE_AMBIENT_COLORS: Array[Color] = [
	Color(0.86, 0.78, 0.74),
	Color(0.80, 0.86, 0.94),
	Color(0.82, 0.68, 0.64),
	Color(0.48, 0.56, 0.80),
]
## How far the fill light is dragged toward the same cloud the sky is mixed with, so an
## overcast hour fills its shadows with cloud light rather than with its own clear sky. It is
## the sky's cloud, phase scaled by _cloud_light(), not the raw grey. CLEAR is zero for the
## same reason WEATHER_SKY_MIX's is: its entry in WEATHER_SKY_GREY is a white placeholder
## that no weather ever actually hangs in the air.
const WEATHER_AMBIENT_MIX: Array[float] = [0.0, 0.4, 0.4, 0.4]

## THE HORIZON IS THE ZENITH, TINTED TOWARD ITS OWN HOUR. Each phase names the colour its
## band near the ground is pulled toward and HORIZON_BLEND says how far.
##
## WHY NOT A RATIO. This used to be the zenith multiplied by a per channel ratio taken off
## ranch.tscn's hand picked pair (2.32, 1.59, 1.14), and that ratio CLAMPED: a clear dawn's
## 0.62 red multiplied to 1.44, came back as 1.0, and the whole sky flattened to a near
## white wash. Worse, only CLEAR clamped, because rain and fog shrink the zenith first, so
## a rainy dawn came out more colourful than a clear one and the weather read backwards.
## A tint the sky is LERPED toward cannot leave the gamut, so nothing clamps, every phase
## keeps its own hour at the horizon, and CLEAR stays the cleanest sky there is.
const HORIZON_TINT: Array[Color] = [
	Color(0.96, 0.80, 0.66),
	Color(0.78, 0.87, 0.95),
	Color(0.92, 0.62, 0.50),
	Color(0.10, 0.12, 0.22),
]
const HORIZON_BLEND := 0.65

## THE GROUND HALF OF THE SKY, which is the horizon band darkened twice over: once for the
## band just under the skyline and again for straight down.
##
## IT HAS TO BE DRIVEN OR NIGHT GLOWS GREEN. ProceduralSkyMaterial paints a lower
## hemisphere as well as an upper one, ranch.tscn authors it as daylight grass
## (0.416, 0.529, 0.349), and a rig that wrote only the two sky colours left that green at
## full daylight brightness under a near black zenith: a bright green band ran the whole way
## round the horizon of every night shot. It leaked into the lighting too, since the scene's
## ambient used to take 85% of its colour from the sky. That share is now 35%, and the rest
## is PHASE_AMBIENT_COLORS below.
const GROUND_HORIZON_DARKEN := 0.55
const GROUND_BOTTOM_DARKEN := 0.30

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
## Weather mixes the sky toward its own grey and then darkens what is left. Both halves
## matter and they do different jobs: the mix drains the hour's colour out, the darken is
## what keeps rain and storm strictly dimmer than the clear sky of the same phase (the mix
## alone would have brightened a blue noon, because its grey is lighter than the sky it
## replaces).
##
## MIXING TOWARD A FIXED GREY, not toward the colour's own luminance. A luminance flatten
## keeps the hue and only drains it, which is why a rainy day used to come back pink rather
## than grey. The greys are cool on purpose: RAIN and STORM are cold weather and must never
## read warmer than the hour they fell on. CLEAR's entry is never used (its weight is zero)
## and is white only so the array has no hole in it.
const WEATHER_SKY_GREY: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.52, 0.56, 0.62),
	Color(0.72, 0.74, 0.77),
	Color(0.36, 0.38, 0.43),
]
const WEATHER_SKY_MIX: Array[float] = [0.0, 0.55, 0.60, 0.70]
const WEATHER_SKY_DARKEN: Array[float] = [1.0, 0.75, 0.85, 0.55]

## FOG's 0.010 is what a fog is FOR: the ranch reduced to a silhouette, not deleted. At
## 0.018 the barn, the fences and every tree past the yard were gone from a shot taken 45 m
## out, which is not weather, it is a wall.
const WEATHER_FOG_DENSITY: Array[float] = [0.0011, 0.004, 0.010, 0.008]
## Drops alive at once. Rain is a wash of streaks around the player, not a simulation of a
## storm front, so these are tuned to read from the camera's usual distance and no further.
const WEATHER_RAIN_AMOUNT: Array[int] = [0, 600, 0, 1400]

## Never let the world go absolutely black; a stormy night still has to be playable.
const MIN_LIGHT_ENERGY := 0.06
const MIN_AMBIENT_ENERGY := 0.05

## HOW MUCH OF THE NIGHT'S AMBIENT A STORM IS ALLOWED TO TAKE. Weather scales ambient the
## same way it scales sunlight, but a storm's 0.45 applied on top of a night that is already
## the darkest phase takes the fill light past the point where the ranch is legible. At
## night, and only at night, the multiplier is floored here: a stormy night gets 0.70 of its
## base rather than 0.45.
##
## THIS IS WHY "NIGHT IS DARKER THAN DAY" IS NOT AN AMBIENT CLAIM. With this floor a stormy
## night's ambient energy (0.49) is above a stormy day's (0.144), and that is correct and
## intended: ambient energy multiplies a colour, and the night's fill colour is a dim blue
## moonlight while the day's is a bright skylight. The ordering that means anything on
## screen is asserted on light_energy and on sky_top luminance, which hold in every weather.
const NIGHT_WEATHER_FLOOR := 0.7

## The rain column: a 14 by 14 metre box of emitters one metre thick, RAIN_HEIGHT above
## whoever follow() was given, falling at RAIN_GRAVITY for RAIN_LIFETIME seconds.
##
## THE 7 m HALF EXTENT IS THE CAMERA'S NUMBER, not a look. game/actors/player/camera_rig.gd
## pulls its spring arm out to SPRING_MAX, 6.5 m behind the player, so a column any narrower
## than that would have its upwind edge inside the frame at full zoom: the player would be
## looking at the seam where the rain starts. 7 m clears the fully zoomed out camera with
## half a metre to spare and costs nothing else, since the drop count is fixed and a wider
## box only spreads the same drops thinner.
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
const KEY_GROUND_HORIZON := "ground_horizon"
const KEY_GROUND_BOTTOM := "ground_bottom"
const KEY_AMBIENT_ENERGY := "ambient_energy"
const KEY_AMBIENT_COLOR := "ambient_color"
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

## Where the sky was when the transition started, what it is being asked to become, and
## where it has actually got to. All three are keyed by the KEY_* constants above; floats
## are ramped with lerpf and Colors with Color.lerp.
##
## _from IS SNAPSHOTTED, not recomputed. That is what makes a second apply() in the middle
## of a transition continuous: it rephotographs wherever the sky has actually reached and
## ramps on from there, so the light never jumps back to a phase it already left.
var _from := {}
var _targets := {}
var _current := {}
var _has_targets := false
## The transition clock, 0 at the start of a ramp and 1 when it has arrived. Starts at 1
## because a rig nobody has applied anything to has nowhere to be going.
var _t := 1.0
## The last count actually written to the emitter, so an unchanged sky does not restart the
## particle system every frame (setting `amount` reallocates it). It is also the answer to
## "is it raining right now", which is what decides whether the cloud has to be carried
## around and therefore whether the rig has any reason to tick once its ramp has arrived.
var _rain_written := -1
## Whether AMBIENT_SKY_CONTRIBUTION and AMBIENT_SOURCE_SKY have been put on the Environment.
## Both are constants, so they are written on the first write that actually finds an
## Environment and never again: re-asserting them every frame is a setter call that can
## never change anything.
var _ambient_contract_written := false
## Whether _write_to_scene() has already re-searched the scene for a sun and an Environment
## it could not find at _ready(). ONE retry, not one per frame: the search walks the parent's
## children, and a rig whose scene has neither would otherwise re-walk it and re-complain
## sixty times a second for the rest of the session.
var _resolve_retried := false


func _ready() -> void:
	_resolve_nodes()
	_ensure_rain()
	_seed_from_scene()
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
	return _weathered(PHASE_SKY_TOP[_phase_index(phase)], phase, weather)


static func sky_horizon(phase: int, weather: int) -> Color:
	var p := _phase_index(phase)
	return _weathered(PHASE_SKY_TOP[p].lerp(HORIZON_TINT[p], HORIZON_BLEND), phase, weather)


## The band of the sky's LOWER hemisphere just under the skyline. Read off the horizon so
## the two sides of the rim are the same weather, then darkened, because ground is ground
## whatever hour it is.
static func ground_horizon(phase: int, weather: int) -> Color:
	return _scaled(sky_horizon(phase, weather), GROUND_HORIZON_DARKEN)


## And straight down, darker still.
static func ground_bottom(phase: int, weather: int) -> Color:
	return _scaled(sky_horizon(phase, weather), GROUND_BOTTOM_DARKEN)


## One base colour put through one weather: mixed toward that weather's cloud, then dimmed.
static func _weathered(base: Color, phase: int, weather: int) -> Color:
	var w := _weather_index(weather)
	return _scaled(base.lerp(cloud_colour(phase, weather), WEATHER_SKY_MIX[w]),
		WEATHER_SKY_DARKEN[w])


## THE CLOUD THIS WEATHER HANGS IN THIS HOUR. WEATHER_SKY_GREY is a daylight cloud, and a
## daylight cloud pasted over a midnight zenith LIFTS it: mixing 0.55 of a 0.56 luminance
## grey into a 0.08 luminance night sky made a rainy midnight three times brighter than a
## clear one, which is the wrong way round and is not what any of these numbers mean. So
## the grey is lit by the hour it is hanging in, measured against noon, which leaves DAWN
## and DAY on exactly the authored grey and darkens the cloud as the light goes.
##
## FOG IS ALLOWED TO BE THE PALE ONE. Rain and storm come out strictly darker than the
## clear sky of the same phase at every hour; fog is a whiteout by definition and only has
## to stay the thickest, which is a fog DENSITY claim and is asserted separately.
static func cloud_colour(phase: int, weather: int) -> Color:
	return _scaled(WEATHER_SKY_GREY[_weather_index(weather)], _cloud_light(phase))


## How much of noon's light reaches this phase's cloud, as a fraction of noon's own zenith
## brightness, never more than all of it.
static func _cloud_light(phase: int) -> float:
	var noon: float = PHASE_SKY_TOP[WorldStateScript.Phase.DAY].get_luminance()
	if noon <= 0.0:
		return 1.0
	return minf(1.0, PHASE_SKY_TOP[_phase_index(phase)].get_luminance() / noon)


## Multiply the three channels and leave alpha alone.
static func _scaled(colour: Color, factor: float) -> Color:
	return Color(colour.r * factor, colour.g * factor, colour.b * factor)


static func ambient_energy(phase: int, weather: int) -> float:
	var p := _phase_index(phase)
	var base: float = PHASE_AMBIENT_ENERGY[p]
	var scale: float = WEATHER_ENERGY_SCALE[_weather_index(weather)]
	if p == WorldStateScript.Phase.NIGHT:
		scale = maxf(scale, NIGHT_WEATHER_FLOOR)
	return maxf(MIN_AMBIENT_ENERGY, base * scale)


## THE COLOUR THE SHADOWS ARE FILLED WITH. The hour picks it and the weather drags it toward
## whatever cloud is hanging in that hour, so a rainy dusk fills with grey rather than with
## its own salmon sky. Written to Environment.ambient_light_color, which is 65% of the
## finished ambient; the other 35% the Environment samples off the sky itself.
static func ambient_light_color(phase: int, weather: int) -> Color:
	var p := _phase_index(phase)
	var w := _weather_index(weather)
	return PHASE_AMBIENT_COLORS[p].lerp(cloud_colour(phase, weather), WEATHER_AMBIENT_MIX[w])


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

## RAMP THE SKY TOWARD WHATEVER `state` SAYS, ARRIVING IN EXACTLY TRANSITION_SECONDS.
## Photographs the sky as it currently stands into _from, records the target, and restarts
## the transition clock at zero; step() then walks a smoothstepped ramp between the two and
## lands exactly on the target, at which point the rig stops processing. Writes nothing
## itself, so the sky does not move until the first step().
##
## CALLING THIS AGAIN MID RAMP IS CONTINUOUS: the new _from is wherever the sky has actually
## reached, not where the last transition started, so a weather flip during a phase flip
## bends the light rather than snapping it back.
##
## A PINNED STATE HAS NO MEANINGFUL phase_progress(): pin() sets the phase without moving
## the clock, so its progress still reads wherever the clock happened to be. A pinned
## reading is therefore taken as mid phase (0.5), which makes a pinned DAY read as noon.
func apply(state: WorldState) -> void:
	if state == null:
		return
	_from = _current.duplicate(true)
	_set_targets_from(state)
	# A rig whose scene had nothing to photograph (no sun, no environment) starts the ramp
	# already at the target for those keys rather than ramping from a made up value.
	for key in _targets:
		if not _from.has(key):
			_from[key] = _targets[key]
	_t = 0.0
	set_process(true)


## The same, with no transition. Three callers, and the third is the one that is easy to
## forget: boot, where there is no previous sky to ease from; gates, which must not have to
## spin frames to see the answer; and A MID-SESSION LOAD. game/world/ranch.gd calls this from
## _rebuild_world_state(), which is connected to GameState.state_loaded, because a load
## REPLACES the clock rather than moving it. The hour on the other side of it is not
## somewhere the sky was travelling to, it is a different save; ramping eight seconds into
## it would show the player the hour they just left.
func apply_immediately(state: WorldState) -> void:
	if state == null:
		return
	_set_targets_from(state)
	_from = _targets.duplicate(true)
	_current = _targets.duplicate(true)
	_t = 1.0
	_write_to_scene()
	_track_follow()
	# Already arrived, so the only reason left to tick is a rain cloud with somebody to
	# follow. A load into a clear sky leaves the rig as furniture until the next apply().
	set_process(_needs_ticks())


## What the rig is walking toward, for gates and for the HUD. A copy; editing it changes
## nothing.
func current_targets() -> Dictionary:
	return _targets.duplicate(true)


## Where the ramp has actually got to, at full double precision. The scene's own properties
## are the truth for rendering but they are 32 bit floats, so a gate that needs to prove the
## ramp landed EXACTLY on its target has to read it here rather than off the light.
func current_values() -> Dictionary:
	return _current.duplicate(true)


## The rain follows one node, normally the player: the emitter is a small box overhead, not
## a lid over the whole 220 metre map, so it has to travel with whoever is being rained on.
func follow(target: Node3D) -> void:
	_follow_target = target
	_track_follow()
	set_process(true)


func _process(delta: float) -> void:
	step(delta)


## Advance the transition by `delta` and write the result to the scene. _process() calls
## this every frame; tests and gates call it directly rather than waiting on real frames.
##
## The clock only ever moves forward and stops dead at 1, where the sky is snapped exactly
## onto its targets rather than left a rounding error short of them. Once it has arrived
## there is nothing left to interpolate, so the rig stops processing unless it still has a
## rain cloud to carry around. A CLEAR sky counts as nothing to carry: see _needs_ticks().
## The next apply() or follow() turns processing back on.
func step(delta: float) -> void:
	if _has_targets and _t < 1.0:
		_advance(delta)
	# AFTER the write, not before it: the frame a shower starts is the frame _write_rain()
	# first raises the drop count, and a follow asked for ahead of that would leave the
	# cloud one frame behind the player it just started raining on.
	_track_follow()
	if (not _has_targets or _t >= 1.0) and not _needs_ticks():
		set_process(false)


## One step of the ramp itself, split out of step() so that step()'s own job (carry the
## cloud, decide whether there is another frame's work) reads as the three lines it is.
func _advance(delta: float) -> void:
	_t = minf(_t + maxf(0.0, delta) / TRANSITION_SECONDS, 1.0)
	if _t >= 1.0:
		_current = _targets.duplicate(true)
	else:
		var eased := _t
		if USE_SMOOTHSTEP:
			eased = _t * _t * (3.0 - 2.0 * _t)
		for key in _targets:
			var target_value: Variant = _targets[key]
			var from_value: Variant = _from.get(key, target_value)
			if key == KEY_RAIN_AMOUNT:
				# A drop count cannot be half changed: the emitter reallocates on any
				# change, so it switches at the start of the ramp rather than crawling.
				_current[key] = target_value
				continue
			if target_value is Color:
				var from_color: Color = from_value
				_current[key] = from_color.lerp(target_value, eased)
			else:
				_current[key] = lerpf(float(from_value), float(target_value), eased)
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
		KEY_GROUND_HORIZON: ground_horizon(phase, weather),
		KEY_GROUND_BOTTOM: ground_bottom(phase, weather),
		KEY_AMBIENT_ENERGY: ambient_energy(phase, weather),
		KEY_AMBIENT_COLOR: ambient_light_color(phase, weather),
		KEY_FOG_DENSITY: fog_density(weather),
		KEY_RAIN_AMOUNT: rain_amount(weather),
	}
	_has_targets = true


## The dread grade's multipliers (game/world/world_tone.gd grade()): sun_tint, ambient_mult,
## fog_mult. Empty means none; the hour and the weather are untouched either way, the tone
## only scales what they wrote.
var _tone: Dictionary = {}


func set_tone(g: Dictionary) -> void:
	_tone = g
	_write_to_scene()


## INDOORS: THE SKY STAYS OUTSIDE. While the player is in the Spectra Palace's hall (a sealed
## room under the map, game/world/palace_interior.gd) the sun is put out, the rain stops
## following her, the fog thins to nothing and the ambient fill is the room's own warm rose
## rather than whatever hour it is outside. The hour and the weather keep ramping underneath
## (_current is untouched), so stepping back out finds the sky exactly where it has got to.
## The dread grade still applies: the Palace is in the same valley as everything else.
const INDOOR_AMBIENT_ENERGY := 0.42
const INDOOR_AMBIENT_COLOR := Color(1.0, 0.9, 0.86)
var _indoors := false


func set_indoors(on: bool) -> void:
	if on == _indoors:
		return
	_indoors = on
	_write_to_scene()


func is_indoors() -> bool:
	return _indoors


func _write_to_scene() -> void:
	if (_sun == null or _environment == null) and not _resolve_retried:
		# A rig can be built in code and wired to its siblings AFTER _ready() has run, so
		# the search is worth one more go the first time somebody actually asks for a sky.
		# It is not worth a third: past that the scene has no lighting for this rig to
		# drive, which is a wiring mistake and is said once, here, rather than per frame.
		_resolve_retried = true
		_resolve_nodes()
		if _sun == null:
			push_error("SkyRig '%s' found no DirectionalLight3D; the sun will not move."
				% [name])
		if _environment == null:
			push_error(("SkyRig '%s' found no WorldEnvironment; the sky, the ambient fill "
				+ "and the fog will not be written.") % [name])
	if _sun != null:
		_sun.rotation_degrees = Vector3(
			-float(_current.get(KEY_SUN_ELEVATION, ELEVATION_DAY_EDGE)),
			float(_current.get(KEY_SUN_AZIMUTH, AZIMUTH_DAY_START)),
			0.0)
		_sun.light_energy = float(_current.get(KEY_LIGHT_ENERGY, 1.0))
		_sun.light_color = (_current.get(KEY_LIGHT_COLOR, _sun.light_color) as Color) \
			* (_tone.get("sun_tint", Color.WHITE) as Color)
	var horizon: Color = _current.get(KEY_SKY_HORIZON, Color.WHITE)
	if _environment != null:
		if not _ambient_contract_written:
			# THE SPLIT THE ENERGY NUMBERS WERE COMPUTED AGAINST, pinned here rather than
			# trusted to whoever saved the scene. Written once, on the first write that
			# found an Environment; see AMBIENT_SKY_CONTRIBUTION and _ambient_contract_written.
			_ambient_contract_written = true
			_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			_environment.ambient_light_sky_contribution = AMBIENT_SKY_CONTRIBUTION
		_environment.ambient_light_energy = float(_current.get(KEY_AMBIENT_ENERGY, 0.32)) \
			* float(_tone.get("ambient_mult", 1.0))
		# The fill light's own colour, which is most of the ambient: the scene asks the sky
		# for only 35% of it, so a night sky at luminance 0.04 can no longer black the ranch
		# out on its own.
		_environment.ambient_light_color = _current.get(
			KEY_AMBIENT_COLOR, _environment.ambient_light_color)
		_environment.fog_density = float(_current.get(KEY_FOG_DENSITY, WEATHER_FOG_DENSITY[0])) \
			* float(_tone.get("fog_mult", 1.0))
		# The fog is lit by the same air the horizon band is, so it takes that colour and
		# a night fog goes dark instead of glowing white in the dark.
		_environment.fog_light_color = horizon
		if _indoors:
			_environment.ambient_light_energy = INDOOR_AMBIENT_ENERGY \
				* float(_tone.get("ambient_mult", 1.0))
			_environment.ambient_light_color = INDOOR_AMBIENT_COLOR
			_environment.fog_density = 0.0
	if _sun != null and _indoors:
		_sun.light_energy = 0.0
	if _sky_material != null:
		_sky_material.sky_top_color = _current.get(KEY_SKY_TOP, _sky_material.sky_top_color)
		_sky_material.sky_horizon_color = horizon
		# The lower hemisphere as well. See GROUND_HORIZON_DARKEN for the green band this
		# is here to stop.
		_sky_material.ground_horizon_color = _current.get(
			KEY_GROUND_HORIZON, _sky_material.ground_horizon_color)
		_sky_material.ground_bottom_color = _current.get(
			KEY_GROUND_BOTTOM, _sky_material.ground_bottom_color)
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
	# Guarded the same way `amount` is, and for a smaller version of the same reason:
	# assigning `emitting` restarts the emission, so a clear sky that reassigned false every
	# frame would be doing a pointless server call sixty times a second forever.
	var falling := wanted > 0 and not _indoors
	# The drops already in the air go too: indoors is a roof, not a slow fade.
	if _rain.visible == _indoors:
		_rain.visible = not _indoors
	if _rain.emitting != falling:
		_rain.emitting = falling


## Carry the rain cloud over whoever follow() was given. Does nothing at all while the sky
## is dry: an emitter holding its one unused drop with `emitting` false has nothing on
## screen to keep overhead, so moving it every frame of every clear day is a global_position
## write (and the transform propagation under it) bought for nothing. The write comes back
## the moment the drop count does, because _write_rain() raises _rain_written before the
## follow is asked for again.
func _track_follow() -> void:
	if _rain == null or _rain_written <= 0:
		return
	if _follow_target == null or not is_instance_valid(_follow_target):
		return
	if not _follow_target.is_inside_tree() or not _rain.is_inside_tree():
		return
	_rain.global_position = _follow_target.global_position + Vector3(0.0, RAIN_HEIGHT, 0.0)


## Has this rig any reason to be handed another frame? Only two: a ramp still walking, and
## a cloud that is actually raining on somebody it has to stay above. A clear sky with a
## follow target arrived at its targets is furniture again until the next apply() or
## follow(), both of which turn processing back on.
func _needs_ticks() -> bool:
	return _follow_target != null and is_instance_valid(_follow_target) and _rain_written > 0


## READ THE SKY THE SCENE WAS HAND LIT WITH, so the very first apply() has somewhere to
## ramp FROM. Without this, _current is empty on a fresh rig and the first transition has no
## start point, which made the opening phase of a session snap instead of dawning.
##
## This READS the scene and never writes to it: an unwired rig that nobody ever applies
## anything to still leaves the hand authored sun, sky and fog exactly as they were saved.
## Rain is seeded at zero because the emitter ships silent.
func _seed_from_scene() -> void:
	if _sun != null:
		_current[KEY_SUN_ELEVATION] = -_sun.rotation_degrees.x
		# THE SEEDED BEARING IS WRAPPED FIRST AND THEN CLAMPED, in that order and for two
		# different reasons. Wrapped, because rotation_degrees is not normalised and a sun
		# saved at 315 deg means the same direction as one saved at -45 but would ramp the
		# long way round the compass to reach it. Clamped, because the rig's own arc never
		# leaves [AZIMUTH_WEST, AZIMUTH_EAST]: a hand authored yaw outside that range is a
		# bearing no phase of this sky ever asks for, so the first transition of the session
		# would open by sweeping further than any sun in this game moves in a whole day.
		# Clamping loses a little of the authored angle; sweeping 180 deg through dawn loses
		# the shot. (ranch.tscn's own sun seeds at about -49 deg and is untouched by both.)
		_current[KEY_SUN_AZIMUTH] = clampf(
			wrapf(_sun.rotation_degrees.y, -180.0, 180.0), AZIMUTH_WEST, AZIMUTH_EAST)
		_current[KEY_LIGHT_ENERGY] = _sun.light_energy
		_current[KEY_LIGHT_COLOR] = _sun.light_color
	if _environment != null:
		_current[KEY_AMBIENT_ENERGY] = _environment.ambient_light_energy
		_current[KEY_AMBIENT_COLOR] = _environment.ambient_light_color
		_current[KEY_FOG_DENSITY] = _environment.fog_density
	if _sky_material != null:
		_current[KEY_SKY_TOP] = _sky_material.sky_top_color
		_current[KEY_SKY_HORIZON] = _sky_material.sky_horizon_color
		_current[KEY_GROUND_HORIZON] = _sky_material.ground_horizon_color
		_current[KEY_GROUND_BOTTOM] = _sky_material.ground_bottom_color
	_current[KEY_RAIN_AMOUNT] = 0


## Find the scene's sun, Environment and sky material. Called once at _ready() and at most
## once more, from the first _write_to_scene() that needs something _ready() did not find;
## _resolve_retried is what stops it becoming a per frame scene search.
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
