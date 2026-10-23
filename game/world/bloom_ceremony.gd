class_name BloomCeremony
extends RefCounted
## THE BLOOM, ACTED OUT: she rears, a burst of star sparkles in her own mane colors goes up
## around her, her body squashes and stretches, and the chime plays (STORY.md beat 1.5).
## Static and fire-and-forget: everything it makes frees itself.

const SPARKLE_LIFETIME := 1.6


static func play(body: Node3D) -> void:
	if body == null or not body.is_inside_tree():
		return
	if body.has_method("play_action"):
		body.call("play_action", &"rear")
	var colors: Array[Color] = [Color(1, 0.92, 0.5), Color(1, 0.7, 0.85), Color(0.7, 0.9, 1)]
	if body.has_method("look"):
		var look: PonyLook = body.call("look")
		colors = [look.mane.lightened(0.25), look.mane2.lightened(0.3), Color(1, 0.96, 0.7)]
	var root := body.get_tree().current_scene
	if root == null:
		return
	var burst := sparkles(colors)
	root.add_child(burst)
	burst.global_position = body.global_position + Vector3(0, 1.1, 0)
	burst.emitting = true
	body.get_tree().create_timer(SPARKLE_LIFETIME + 0.5).timeout.connect(burst.queue_free)
	var visuals := body.get_node_or_null("Visuals") as Node3D
	if visuals != null:
		var base := visuals.scale
		var t := body.create_tween()
		t.tween_property(visuals, "scale", base * Vector3(1.08, 0.9, 1.08), 0.08)
		t.tween_property(visuals, "scale", base * Vector3(0.94, 1.1, 0.94), 0.12)
		t.tween_property(visuals, "scale", base, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sound := body.get_node_or_null("/root/Sound")
	if sound != null:
		sound.call("play_at", &"bloom_fanfare" if sound.call("has_sound", &"bloom_fanfare") else &"capture_success",
			body.global_position)


## A one-shot burst of flat star quads in `colors`, rising and fading: the show's sparkle.
static func sparkles(colors: Array[Color]) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = 46
	p.lifetime = SPARKLE_LIFETIME
	p.explosiveness = 0.92
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -1.4, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, colors[0])
	grad.set_color(1, Color(colors[colors.size() - 1], 0.0))
	grad.add_point(0.5, colors[1 % colors.size()])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = star_texture()
	quad.material = mat
	p.draw_pass_1 = quad
	return p


static var _star: Texture2D


## A soft four-pointed sparkle, drawn once.
static func star_texture() -> Texture2D:
	if _star != null:
		return _star
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var d := absf(u) * absf(v) * 6.0 + (u * u + v * v) * 0.6
			var a := clampf(1.0 - d * 2.2, 0.0, 1.0)
			a = maxf(a, clampf(1.0 - sqrt(u * u + v * v) * 3.2, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_star = ImageTexture.create_from_image(img)
	return _star
