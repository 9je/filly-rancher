extends GutTest
## The "!" news bubble over a townspony with something to say (world/people.gd). Seen in the
## round 2 catch-card evidence: a townspony beside the camera wore a bubble that filled a
## quarter of the screen, its 96 px texture blown up into blocks; round 2 of the Fable review
## saw it again, ~150 px and faded, at the screen's edge. Now its material (ui/world_marker.gd)
## shrinks it inside a few metres, so on screen it is never bigger than it is there, fades it
## out beside the lens, and its texture is smooth.

const PeopleScript := preload("res://world/people.gd")
const WorldMarkerScript := preload("res://ui/world_marker.gd")


func _material() -> ShaderMaterial:
	var marker: Node3D = PeopleScript.news_marker()
	autofree(marker)
	for c in marker.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.material_override is ShaderMaterial:
			return mi.material_override
	return null


func test_bubble_fades_out_close_to_the_camera() -> void:
	var m := _material()
	assert_not_null(m, "the bubble has its marker material")
	assert_true(float(m.get_shader_parameter(&"fade_from")) >= 1.0, "gone within a metre of the lens")
	assert_true(float(m.get_shader_parameter(&"fade_to")) > float(m.get_shader_parameter(&"fade_from")),
		"a fade, not a pop")


func test_bubble_never_grows_past_its_size_at_the_near_distance() -> void:
	# On screen a quad's size goes as scale / distance: inside NEAR_SIZE that is constant.
	var near := WorldMarkerScript.NEAR_SIZE
	var at_near := WorldMarkerScript.scale_at(near) / near
	for d: float in [0.5, 1.0, 2.0, 4.0, near]:
		assert_almost_eq(WorldMarkerScript.scale_at(d) / d, at_near, 0.0001, "%.1f m" % d)
	assert_lt(WorldMarkerScript.scale_at(20.0) / 20.0, at_near, "smaller far off, as the world is")


func test_bubble_is_smoothly_filtered() -> void:
	var m := _material()
	assert_not_null(m)
	var tex: Texture2D = m.get_shader_parameter(&"tex")
	assert_not_null(tex)
	assert_true(tex.get_image().has_mipmaps(), "mipmaps to filter between")
	assert_true(m.shader.code.contains("filter_linear_mipmap"), "sampled smoothly")
