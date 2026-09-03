extends GutTest
## THE BOARD THAT REPLACED THE PARAGRAPH IN THE AIR.
##
## WHAT WAS THERE. Buildings/Palace/Sign was a Label3D carrying eleven lines of published
## house edges at pixel_size 0.0032 and font_size 48, which is a cap height of about 0.15 m
## per line and roughly 1.7 m of unbacked text stack hanging 2.1 m up and 4.1 m out from the
## Palace. The owner, 2026-09-01: "the note on the casino looks very poor". It was also a
## paragraph nobody can read from a distance and nobody needs to read while standing outside
## a door.
##
## WHAT IS THERE NOW. A board with a trim, sized off the Palace's own width, carrying two
## FITTED lines: a headline and one sentence pointing inside. The eleven lines live on the
## casino lobby's House rules page, which is one of the six things the player sees the moment
## she walks in; game/scenes/test/casino_test.gd asserts them there.
##
## FITTED IS THE WHOLE POINT and it is what this file checks. game/world/strip.gd's
## _marquee_label() sizes a Label3D's width in the same pixel units its font_size is in, and
## sets the wrap mode with it, because either one alone does nothing. A label whose width was
## left at zero is a label that ignores its board, which is the defect that put a 66 character
## marquee across a 14 metre building in the first place.

const LobbySignScript := preload("res://world/lobby_sign.gd")

const BOARD_WIDTH := 3.6
const BOARD_HEIGHT := 1.1


func _built() -> LobbySign:
	var sign_node: LobbySign = LobbySignScript.new()
	add_child_autofree(sign_node)
	sign_node.build(BOARD_WIDTH, BOARD_HEIGHT, Vector3(0.0, 0.0, 1.0),
		LobbySignScript.HEADLINE, LobbySignScript.SUBLINE)
	return sign_node


func test_the_board_and_its_trim_are_standing_behind_the_letters() -> void:
	var sign_node: LobbySign = _built()
	assert_not_null(sign_node.get_node_or_null(^"Board"),
		"unbacked letters in the air is the thing this replaced")
	assert_not_null(sign_node.get_node_or_null(^"Trim"))
	assert_eq(sign_node.board_size(), Vector2(BOARD_WIDTH, BOARD_HEIGHT))


func test_both_lines_are_fitted_to_the_board_rather_than_free_floating() -> void:
	var sign_node: LobbySign = _built()
	for path: NodePath in [^"Headline", ^"Subline"]:
		var label := sign_node.get_node_or_null(path) as Label3D
		assert_not_null(label, "%s is missing" % path)
		assert_gt(label.pixel_size, 0.0)
		assert_almost_eq(label.width * label.pixel_size, BOARD_WIDTH, 0.001,
			"%s is not fitted to the board's width" % path)
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD,
			"a width with no wrap mode does nothing")
		assert_eq(label.billboard, BaseMaterial3D.BILLBOARD_DISABLED,
			"a sign on a board does not turn to face you")


## NOTHING ON THIS BOARD SITS BELOW ITS OWN ORIGIN. ranch.gd's seating check measures the
## BOTTOM of the world AABB of every MeshInstance3D under a building against the height the
## building was seated at, so a sign hanging below the Palace's local y = 0 would drag that
## bottom down and fail the gate on a correctly placed building.
func test_nothing_on_the_board_hangs_below_the_signs_own_origin() -> void:
	var sign_node: LobbySign = _built()
	for child in sign_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box: AABB = mesh.get_aabb()
		assert_gte(mesh.position.y + box.position.y, -0.001,
			"%s hangs below the sign's origin" % mesh.name)


func test_neither_line_carries_a_dash() -> void:
	for line: String in LobbySignScript.lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains("—"), "'%s' carries an em dash" % line)
		assert_false(line.is_empty())
