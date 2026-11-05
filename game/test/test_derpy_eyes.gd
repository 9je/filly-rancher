extends GutTest
## DERPY'S EYES (owner 2026-11-05: "make sure derpy has her silly crossed eyes"). Her eye
## textures only nudge one iris up and one down; with the show's bigger iris that read as
## two ordinary eyes. ToonStyler.CROSS_EYED rolls each of her eyes its own way through the
## eye shader's `gaze`, and nobody else's.

const PonyScene := preload("res://actors/pony/pony.tscn")
const EYE_SHADER := preload("res://shaders/pony_eye.gdshader")


var _was_shading := true


func before_each() -> void:
	_was_shading = ToonStyler.shading_enabled
	ToonStyler.shading_enabled = true


func after_each() -> void:
	ToonStyler.shading_enabled = _was_shading


func _eye_gazes(id: String) -> Array[Vector2]:
	var pony: Node3D = PonyScene.instantiate()
	add_child_autofree(pony)
	pony.call("setup", load("res://data/ponies/%s.tres" % id))
	var out: Array[Vector2] = []
	for mi: MeshInstance3D in pony.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is ShaderMaterial and (m as ShaderMaterial).shader == EYE_SHADER:
				var g: Variant = (m as ShaderMaterial).get_shader_parameter(&"gaze")
				out.append(g if g is Vector2 else Vector2.ZERO)
	return out


func test_derpy_s_eyes_each_look_their_own_way() -> void:
	var g := _eye_gazes("derpyhooves")
	assert_eq(g.size(), 2, "both eyeballs wear the eye shader")
	if g.size() != 2:
		return
	assert_gt(g[0].length(), 0.03)
	assert_gt(g[1].length(), 0.03)
	assert_lt(g[0].y * g[1].y, 0.0, "one rolls up, the other down")


func test_everyone_else_looks_straight() -> void:
	for g: Vector2 in _eye_gazes("lyra"):
		assert_eq(g, Vector2.ZERO)
