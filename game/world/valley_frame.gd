class_name ValleyFrame
extends Node3D
## THE EDGES OF HAYBROOK VALE: the ring of green hills around the playable square, the
## Prism Works on its cloud above the northern ridge, and the Haybrook Rainbow pouring out
## of it across the sky (STORY.md section 1). All three are seen from everywhere and none
## can be reached on foot; the Works is visited only through its lift.
##
## `set_brightness` is the delivery feedback (clue 1): each pony sent up makes it a little
## brighter. `set_bands` is the Rescue path's progress bar: each pylon cut takes one away.

const RIM := "res://assets/models/valley_rim.glb"
const WORKS := "res://assets/models/prism_works.glb"
const RAINBOW_SHADER := preload("res://shaders/rainbow.gdshader")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

## Where the Works floats (ranch space) and how big.
const WORKS_AT := Vector3(34.0, 58.0, -236.0)
const WORKS_SCALE := 1.5
## The rainbow's two feet: the Works' spout, and the north-western hills, so it stands as one
## great arch across the northern sky from wherever you are in the valley.
const RAINBOW_FROM := Vector3(52.0, 92.0, -228.0)
const RAINBOW_TO := Vector3(-215.0, -8.0, -110.0)
const RAINBOW_LIFT := 95.0
const RAINBOW_WIDTH := 36.0
const RAINBOW_SEGMENTS := 96

var rainbow: MeshInstance3D
var _rainbow_mat: ShaderMaterial


func _ready() -> void:
	_stand(RIM, Vector3(0, -3.0, 0), 1.0, &"building")
	_stand(WORKS, WORKS_AT, WORKS_SCALE, &"building")
	_build_rainbow()


func _stand(path: String, at: Vector3, s: float, category: StringName) -> void:
	if not ResourceLoader.exists(path):
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.position = at
	inst.scale = Vector3.ONE * s
	add_child(inst)
	ToonStylerScript.style(inst, category)
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## An arc through RAINBOW_FROM and RAINBOW_TO bulging RAINBOW_LIFT up at its middle, as a
## flat band facing the valley's centre.
func _build_rainbow() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := (RAINBOW_TO - RAINBOW_FROM).cross(Vector3.UP).normalized()
	for i in range(RAINBOW_SEGMENTS + 1):
		var t := float(i) / RAINBOW_SEGMENTS
		var p := _arc(t)
		var p2 := _arc(minf(t + 0.001, 1.0))
		var tangent := (p2 - p).normalized() if t < 1.0 else (p - _arc(t - 0.001)).normalized()
		var across := tangent.cross(side).normalized()
		var inner := p - across * RAINBOW_WIDTH * 0.5
		var outer := p + across * RAINBOW_WIDTH * 0.5
		st.set_uv(Vector2(t, 1.0))
		st.add_vertex(inner)
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(outer)
	for i in range(RAINBOW_SEGMENTS):
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	rainbow = MeshInstance3D.new()
	rainbow.name = "Rainbow"
	rainbow.mesh = st.commit()
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rainbow_mat = ShaderMaterial.new()
	_rainbow_mat.shader = RAINBOW_SHADER
	rainbow.material_override = _rainbow_mat
	rainbow.extra_cull_margin = 400.0
	add_child(rainbow)


func _arc(t: float) -> Vector3:
	var p := RAINBOW_FROM.lerp(RAINBOW_TO, t)
	p.y += sin(t * PI) * RAINBOW_LIFT
	return p


## 1.0 is the opening valley; every delivery nudges it up, capped well short of glare.
func set_brightness(b: float) -> void:
	if _rainbow_mat != null:
		_rainbow_mat.set_shader_parameter(&"brightness", clampf(b, 0.4, 2.2))


func set_bands(n: int) -> void:
	if _rainbow_mat != null:
		_rainbow_mat.set_shader_parameter(&"bands", clampi(n, 0, 7))
		rainbow.visible = n > 0


## Brightness for `deliveries` ponies sent up so far.
static func brightness_for(deliveries: int) -> float:
	return 1.0 + 0.06 * float(deliveries)
