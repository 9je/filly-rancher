extends Node3D
## LAMPLIGHT AFTER DARK (P8 S4; docs/aaa-review-2026-11-08.md 2.1: "night is an underexposed
## day"). Night in the reference games is readable because lamps and doors are the brightest
## things on screen. A warm porch lamp hangs over every building's front door, with a small
## glowing bulb the glow picks up; lit through DUSK and NIGHT, out by day, and eased between
## so a phase change never snaps. Self-driven off the ranch's WorldState, so the ranch script
## needs no hook.

const WorldStateScript := preload("res://systems/world_state.gd")
const LAMP_COLOR := Color(1.0, 0.78, 0.5)
const LAMP_ENERGY := 1.5
const LAMP_RANGE := 6.5
const BULB_EMISSION := 5.0
const FADE_SECONDS := 4.0
## How often the phase is looked at; a phase lasts minutes.
const POLL_SECONDS := 0.5

var _lamps: Array[OmniLight3D] = []
var _bulbs: Array[StandardMaterial3D] = []
var _level := 0.0
var _want := 0.0
var _poll := 0.0


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var buildings := get_parent().get_node_or_null(^"Buildings")
	if buildings == null:
		return
	for b: Node in buildings.get_children():
		if not (b is Node3D) or b.get("depth") == null or b.get("wall_height") == null:
			continue
		var n := b as Node3D
		var depth := float(n.get("depth"))
		var h := clampf(float(n.get("wall_height")) * 0.55, 2.6, 4.2)
		var at := n.global_position + n.global_basis.z * (depth * 0.5 + 0.35) + Vector3.UP * h
		var lamp := OmniLight3D.new()
		lamp.name = "PorchLamp_" + n.name
		lamp.light_color = LAMP_COLOR
		lamp.omni_range = LAMP_RANGE
		lamp.omni_attenuation = 1.8
		lamp.shadow_enabled = false
		lamp.light_energy = 0.0
		add_child(lamp)
		lamp.global_position = at
		_lamps.append(lamp)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.7)
		mat.emission_enabled = true
		mat.emission = LAMP_COLOR
		mat.emission_energy_multiplier = 0.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material = mat
		bulb.mesh = sphere
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bulb)
		bulb.global_position = at
		_bulbs.append(mat)
	_poll = 0.0
	_read_phase()
	_level = _want
	_write()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		_read_phase()
	if is_equal_approx(_level, _want):
		return
	_level = move_toward(_level, _want, delta / FADE_SECONDS)
	_write()


func _read_phase() -> void:
	var w: Object = get_parent().get("_world")
	if w == null:
		return
	var p := int(w.call("phase"))
	_want = 1.0 if p == WorldStateScript.Phase.DUSK or p == WorldStateScript.Phase.NIGHT else 0.0


## Lit at `level` (0 day, 1 full night), now. For renders and tests.
func set_level(level: float) -> void:
	_want = level
	_level = level
	_write()


func _write() -> void:
	for l in _lamps:
		l.light_energy = LAMP_ENERGY * _level
		l.visible = _level > 0.001
	for m in _bulbs:
		m.emission_energy_multiplier = BULB_EMISSION * _level
		m.albedo_color = Color(0.55, 0.5, 0.45).lerp(Color(1.0, 0.9, 0.7), _level)
