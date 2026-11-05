extends GutTest
## SPIKE, ANIMATED (world/spike_actor.gd). He stood frozen in his rig's pose: the converted
## PonySFM model ships no clips. home-equestria's Spike carries 24 (owner 2026-11-05, "maybe some
## better models if we could use them"), so he idles, waves when she comes up to the mailbox,
## and breathes his fire when a letter arrives.

const SpikeScript := preload("res://world/spike_actor.gd")


func _spike() -> SpikeActor:
	var s: SpikeActor = SpikeScript.new()
	add_child_autofree(s)
	return s


func test_he_wears_the_animated_model_and_idles() -> void:
	var s := _spike()
	var anim: AnimationPlayer = s.animation_player()
	assert_not_null(anim, "the animated Spike is in")
	if anim == null:
		return
	assert_eq(anim.current_animation, "idle")
	assert_true(anim.is_playing())


func test_he_waves_once_when_she_comes_up_and_goes_back_to_idling() -> void:
	var s := _spike()
	var who := Node3D.new()
	add_child_autofree(who)
	s.player = who
	who.global_position = s.global_position + Vector3(0, 0, 20)
	s._process(0.1)
	assert_eq(s.animation_player().current_animation, "idle", "too far to wave")
	who.global_position = s.global_position + Vector3(0, 0, 3)
	s._process(0.1)
	assert_eq(s.animation_player().current_animation, "wave")
	s.animation_player().animation_finished.emit(&"wave")
	assert_eq(s.animation_player().current_animation, "idle")
	s._process(0.1)
	assert_eq(s.animation_player().current_animation, "idle", "one wave while she stays")


func test_a_letter_is_his_fire() -> void:
	var s := _spike()
	s.letter_arrived()
	assert_eq(s.animation_player().current_animation, "fire")


func test_his_eyes_wear_his_own_iris() -> void:
	ToonStyler.shading_enabled = true
	var s := _spike()
	var eyes := 0
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as ShaderMaterial
			if m != null and m.shader == preload("res://shaders/spike_eye.gdshader"):
				assert_not_null(m.get_shader_parameter(&"iris_texture"))
				eyes += 1
	ToonStyler.shading_enabled = DisplayServer.get_name() != "headless"
	assert_eq(eyes, 2)
