extends MeshInstance3D
## THE PAINTED HORIZON round the camera (Fable AAA round 1, #1 and #2; shaders/sky_dome.gdshader).
## Follows the active camera so the mountains stay at the horizon wherever the player walks,
## and every frame takes its light, haze and cloud colour from the sky rig, so dusk paints the
## range pink and night sinks it into the navy under the stars.

const WorldStateScript := preload("res://systems/world_state.gd")
const SkyRigScript := preload("res://world/sky_rig.gd")
const RADIUS := 340.0
## How much of the night's stars each phase shows: dawn, day, dusk, night.
const STARS: Array[float] = [0.15, 0.0, 0.25, 1.0]
const EASE_SECONDS := 6.0
## Clouds cross the whole ring in about this many seconds.
const DRIFT_SECONDS := 2400.0

var sky_rig: Node = null
var _mat: ShaderMaterial
var _stars := 0.0
var _drift := 0.0


func _ready() -> void:
	if sky_rig == null and get_parent() != null:
		sky_rig = get_parent().get_node_or_null(^"SkyRig")
	var s := SphereMesh.new()
	s.radius = RADIUS
	s.height = RADIUS * 2.0
	s.radial_segments = 64
	s.rings = 32
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sky_dome.gdshader")
	_mat.render_priority = -100
	_mat.set_shader_parameter(&"band", load("res://assets/sky/skyband.png"))
	_mat.set_shader_parameter(&"clouds", load("res://assets/sky/clouds.png"))
	var el := deg_to_rad(SkyRigScript.MOON_ELEVATION)
	var az := deg_to_rad(SkyRigScript.MOON_AZIMUTH)
	# The light's own bearing, turned round: the moon is where the moonlight comes from.
	var basis := Basis.from_euler(Vector3(-el, az, 0.0))
	_mat.set_shader_parameter(&"moon_dir", basis.z)
	s.material = _mat
	mesh = s
	# The sun is painted by the dome (shaders/sky_dome.gdshader); the light only lights.
	var sun := _sun()
	if sun != null:
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	_tick(0.0, true)


func _process(delta: float) -> void:
	_tick(delta, false)


func _tick(delta: float, snap: bool) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		global_position = cam.global_position
	if sky_rig == null:
		return
	var v: Dictionary = sky_rig.call("current_values")
	var horizon: Color = v.get(SkyRigScript.KEY_SKY_HORIZON, Color(0.8, 0.9, 1.0))
	var lc: Color = v.get(SkyRigScript.KEY_LIGHT_COLOR, Color.WHITE)
	var energy := float(v.get(SkyRigScript.KEY_LIGHT_ENERGY, 1.0))
	var fog := float(v.get(SkyRigScript.KEY_FOG_DENSITY, 0.0011))
	var lit := clampf(energy * 0.85 + 0.2, 0.3, 1.1)
	_mat.set_shader_parameter(&"horizon", horizon)
	_mat.set_shader_parameter(&"light", Color(lc.r * lit, lc.g * lit, lc.b * lit))
	_mat.set_shader_parameter(&"haze", clampf(0.22 + fog * 60.0, 0.22, 0.88))
	_mat.set_shader_parameter(&"cloud_tint", Color.WHITE.lerp(lc, 0.45) * clampf(energy + 0.25, 0.35, 1.0))
	_mat.set_shader_parameter(&"cloud_alpha", clampf(1.2 - fog * 40.0, 0.5, 1.0))
	var want := 0.0
	var world: Object = get_parent().get("_world") if get_parent() != null else null
	if world != null:
		want = STARS[clampi(int(world.call("phase")), 0, 3)]
	_stars = want if snap else move_toward(_stars, want, delta / EASE_SECONDS)
	_mat.set_shader_parameter(&"stars", _stars)
	var sun := _sun()
	if sun != null:
		var to_sun := sun.global_basis.z
		_mat.set_shader_parameter(&"sun_dir", to_sun)
		# By day only (at night the light is the moon's), faded under the horizon and in murk.
		var show := clampf(1.0 - _stars * 1.4, 0.0, 1.0) * smoothstep(-0.06, 0.04, to_sun.y)
		_mat.set_shader_parameter(&"sun_show", show * clampf(1.3 - fog * 60.0, 0.0, 1.0))
	_drift = fmod(_drift + delta / DRIFT_SECONDS, 1.0)
	_mat.set_shader_parameter(&"drift", _drift)


func _sun() -> DirectionalLight3D:
	return get_parent().get_node_or_null(^"Sun") as DirectionalLight3D if get_parent() != null else null
