extends GutTest
## A SIGN STEPS ASIDE FOR THE LENS. The overnight bot review (2026-10-26) found the third-
## person camera behind a shop sign at every door it walked up to: the board beside the
## Depot's door filled the screen, its letters a metre high and out of focus. A sign fades
## out as the camera comes within NEAR_M of it and is solid again past FAR_M.

const PlaceSignScript := preload("res://world/place_sign.gd")

var _cam: Camera3D
var _sign: Node3D


func before_each() -> void:
	_cam = Camera3D.new()
	add_child_autofree(_cam)
	_cam.make_current()
	_sign = PlaceSignScript.new()
	add_child_autofree(_sign)
	_sign.call("build", "Depot", PlaceSign.Icon.CRATE, 2.4, 0.75, 0.0, true)


func _fade_at(distance: float) -> float:
	_cam.global_position = _sign.global_position + Vector3(0, 0, distance)
	_sign.call("update_fade", _cam)
	return float(_sign.call("fade"))


func test_solid_from_across_the_plaza() -> void:
	assert_eq(_fade_at(8.0), 0.0)


func test_almost_gone_with_the_lens_against_it() -> void:
	assert_gt(_fade_at(0.6), 0.8)


func test_every_part_of_the_board_fades_together() -> void:
	_fade_at(0.6)
	var parts := _sign.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(parts.size(), 2)
	for g: GeometryInstance3D in parts:
		assert_gt(g.transparency, 0.8, "%s still solid in front of the lens" % g.name)


func test_the_fade_is_smooth_between() -> void:
	var a := _fade_at(2.8)
	var b := _fade_at(2.0)
	var c := _fade_at(1.3)
	assert_true(a < b and b < c, "%.2f, %.2f, %.2f should rise as the lens comes in" % [a, b, c])


## IN THE WAY IS GONE, AT ANY DISTANCE (feel pass 2026-10-26: at the pen's gate the Pens board
## stood between the camera and her, two metres off, half faded: a grey sheet across the
## middle of the screen while she penned a pony). A board on the line from the lens to the
## one she is playing goes nearly all the way, however far off the lens is.
func test_a_board_between_the_lens_and_her_goes_nearly_all_the_way() -> void:
	var her := Node3D.new()
	add_child_autofree(her)
	her.global_position = _sign.global_position + Vector3(0, -1.0, -2.0)
	PlaceSignScript.subject = her
	_cam.global_position = _sign.global_position + Vector3(0, 0.3, 2.5)
	_sign.call("update_fade", _cam)
	assert_gt(float(_sign.call("fade")), 0.9, "she is behind it: it gets out of the way")
	her.global_position = _sign.global_position + Vector3(6.0, -1.0, -2.0)
	_sign.call("update_fade", _cam)
	assert_lt(float(_sign.call("fade")), 0.5, "off to one side it only fades by distance")
	PlaceSignScript.subject = null
