class_name WorldTone
extends Node
## THE DREAD DIAL, MADE VISIBLE. One scalar (0 cozy valley, 1 the Works at its worst) drives
## the grade on top of whatever the sky rig wrote for the hour and the weather: saturation,
## contrast, brightness, fog, the sun's color, the ambient fill, a vignette, and the
## `dread` shader global that pulls every toon material toward grey (spectral ones excepted).
## Music and ambience read the same scalar through Events.dread_changed.
##
## The "free" grade is the Rescue ending's real sunrise: warmer and more saturated than
## cozy, because the valley has never seen its own colors without the rainbow.
##
## grade() is a pure function so the whole curve is testable without a scene.

const VIGNETTE := preload("res://shaders/vignette.gdshader")

@export var environment_path: NodePath
@export var sky_rig_path: NodePath
## How fast the shown dread chases the target, per second. The reveal snaps it instead.
@export var follow_rate: float = 0.35

var target: float = 0.0
var shown: float = 0.0
var free_grade: bool = false

## The sky rig to hand multipliers to (game/world/sky_rig.gd), or null in a scene without one.
var sky_rig: Node
## Off on the Low quality preset (game/systems/settings.gd).
var volumetric_allowed: bool = true

var _env: Environment
var _vignette: ColorRect


## The grade at `d` (0..1). Keys: saturation, contrast, brightness, fog_mult, volumetric,
## sun_tint (Color), ambient_mult, vignette.
static func grade(d: float, free: bool = false) -> Dictionary:
	d = clampf(d, 0.0, 1.0)
	if free:
		return {"saturation": 1.2, "contrast": 1.02, "brightness": 1.03, "fog_mult": 0.6,
			"volumetric": 0.0, "sun_tint": Color(1.0, 0.94, 0.86), "ambient_mult": 1.05,
			"vignette": 0.0}
	# Two segments: unease (0 to 0.3) is subtle, dread (0.3 to 1) is where it falls apart.
	var u := clampf(d / 0.3, 0.0, 1.0)
	var k := clampf((d - 0.3) / 0.7, 0.0, 1.0)
	return {
		"saturation": lerpf(lerpf(1.12, 1.0, u), 0.7, k),
		"contrast": lerpf(1.0, 1.14, k),
		"brightness": lerpf(lerpf(1.0, 0.98, u), 0.86, k),
		"fog_mult": lerpf(lerpf(1.0, 1.7, u), 6.0, k),
		"volumetric": lerpf(0.0, 0.018, k),
		"sun_tint": Color(1, 1, 1).lerp(Color(0.98, 1.0, 0.9), u).lerp(Color(0.92, 0.8, 0.62), k),
		"ambient_mult": lerpf(1.0, 0.68, k),
		"vignette": lerpf(lerpf(0.0, 0.08, u), 0.5, k),
	}


func _ready() -> void:
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we != null:
		_env = we.environment
	sky_rig = get_node_or_null(sky_rig_path)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = VIGNETTE
	_vignette.material = m
	layer.add_child(_vignette)
	process_priority = 100 # After the sky rig has written the hour's values.
	var bus := get_node_or_null("/root/Events")
	if bus != null:
		bus.connect("dread_changed", set_target)
	_apply()


func set_target(d: float) -> void:
	target = clampf(d, 0.0, 1.0)


## Jump straight to `d` (the reveal's window, a scene load).
func snap(d: float) -> void:
	target = clampf(d, 0.0, 1.0)
	shown = target
	_apply()


func _process(delta: float) -> void:
	if not is_equal_approx(shown, target):
		shown = move_toward(shown, target, follow_rate * delta)
	_apply()


func _apply() -> void:
	var g := grade(shown, free_grade)
	RenderingServer.global_shader_parameter_set(&"dread", 0.0 if free_grade else shown)
	if _env != null:
		_env.adjustment_enabled = true
		_env.adjustment_saturation = g.saturation
		_env.adjustment_contrast = g.contrast
		_env.adjustment_brightness = g.brightness
		_env.volumetric_fog_enabled = float(g.volumetric) > 0.0005 and volumetric_allowed
		_env.volumetric_fog_density = g.volumetric
	# Sun color, ambient fill and fog density belong to the sky rig (it writes them for the
	# hour and the weather); the tone hands it multipliers instead of fighting it per frame.
	if sky_rig != null and sky_rig.has_method("set_tone"):
		sky_rig.call("set_tone", g)
	if _vignette != null:
		(_vignette.material as ShaderMaterial).set_shader_parameter(&"strength", g.vignette)
		_vignette.visible = float(g.vignette) > 0.001
