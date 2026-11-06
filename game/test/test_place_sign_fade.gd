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


func test_gone_with_the_lens_against_it() -> void:
	assert_eq(_fade_at(0.6), 1.0)


func test_every_part_of_the_board_goes_together() -> void:
	_fade_at(0.6)
	var parts := _sign.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(parts.size(), 2)
	for g: GeometryInstance3D in parts:
		assert_false(g.visible, "%s still drawn in front of the lens" % g.name)


## NEVER HALF THERE, AND NO FLICKER (PT7; playtest 2026-11-05: "basically all signs flicker",
## the fingerpost's boards dark). A half faded board showed its dark frame through its paper,
## and a board on the edge of the fade flipped as the camera breathed. A board is solid or it
## is gone, and once gone it comes back only well clear: SHOW_M, not HIDE_M.
func test_a_board_is_solid_or_gone_never_between() -> void:
	for d: float in [0.3, 0.8, 1.2, 1.6, 2.0, 2.6, 3.4, 6.0]:
		var f := _fade_at(d)
		assert_true(f == 0.0 or f == 1.0, "at %.1f m the board is %.2f faded" % [d, f])


func test_the_way_back_is_further_out_than_the_way_in() -> void:
	assert_eq(_fade_at(0.8), 1.0, "close: gone")
	assert_eq(_fade_at(PlaceSign.HIDE_M + 0.1), 1.0, "just past where it went: still gone")
	assert_eq(_fade_at(PlaceSign.SHOW_M + 0.1), 0.0, "well clear: back")
	for g: GeometryInstance3D in _sign.find_children("*", "GeometryInstance3D", true, false):
		assert_eq(g.transparency, 0.0, "%s is drawn solid, never see-through" % g.name)


func test_the_lettering_stands_clear_of_the_paper() -> void:
	# The z-fight that flickered the white face through the letters at a distance.
	for l: Label3D in _sign.find_children("*", "Label3D", true, false):
		assert_gte(absf(l.position.z), 0.075, "the lettering is at least 15 mm off the 60 mm face")


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
	assert_eq(float(_sign.call("fade")), 1.0, "she is behind it: it gets out of the way")
	her.global_position = _sign.global_position + Vector3(6.0, -1.0, -2.0)
	_sign.call("update_fade", _cam)
	_sign.call("update_fade", _cam)
	assert_eq(float(_sign.call("fade")), 0.0, "off to one side and 2.5 m off, it is back")
	PlaceSignScript.subject = null
