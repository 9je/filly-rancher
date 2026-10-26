extends GutTest
## The "!" news bubble over a townspony with something to say (world/people.gd). Seen in the
## round 2 catch-card evidence: a townspony beside the camera wore a bubble that filled a
## quarter of the screen, its 96 px texture blown up into blocks. Up close she can see who is
## talking already, so the bubble fades out within a few metres, and its texture is smooth.

const PeopleScript := preload("res://world/people.gd")


func _material() -> StandardMaterial3D:
	var marker: Node3D = PeopleScript.news_marker()
	autofree(marker)
	for c in marker.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			return mi.material_override
	if marker is MeshInstance3D and (marker as MeshInstance3D).material_override is StandardMaterial3D:
		return (marker as MeshInstance3D).material_override
	return null


func test_bubble_fades_out_close_to_the_camera() -> void:
	var m := _material()
	assert_not_null(m, "the bubble has a material")
	assert_eq(m.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA, "fades by distance")
	assert_true(m.distance_fade_min_distance >= 2.0, "gone within 2 m of the lens")
	assert_true(m.distance_fade_max_distance > m.distance_fade_min_distance, "a fade, not a pop")


func test_bubble_is_smoothly_filtered() -> void:
	var m := _material()
	assert_not_null(m)
	assert_eq(m.texture_filter, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "no blocky pixels")
	assert_true(m.albedo_texture.get_image().has_mipmaps(), "mipmaps to filter between")
