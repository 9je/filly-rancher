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

## The direction the player walks in from on the shipped map, in WORLD terms. ranch.tscn
## stands Buildings/Palace yawed half a turn, so its outward axis is world minus Z and the
## approach comes up the z axis toward it.
const APPROACH := Vector3(0.0, 0.0, -1.0)

## Every yaw the parent building might be stood at, in degrees. The half turn is the one
## ranch.tscn actually uses and the one the blank gold slab shipped under.
const PARENT_YAWS: Array[float] = [0.0, 90.0, 180.0, -90.0, 37.0]


func _built() -> LobbySign:
	var sign_node: LobbySign = LobbySignScript.new()
	add_child_autofree(sign_node)
	sign_node.build(BOARD_WIDTH, BOARD_HEIGHT, Vector3(0.0, 0.0, 1.0),
		LobbySignScript.HEADLINE, LobbySignScript.SUBLINE)
	return sign_node


## A sign hung under a building yawed `yaw_deg`, told to face APPROACH in world terms. This
## is the shape ranch.gd builds it in: the node is a child of the Building, it carries no yaw
## of its own, and the facing it is handed is a world vector off the Building's basis.
func _built_under_a_building_yawed(yaw_deg: float) -> LobbySign:
	var building := Node3D.new()
	add_child_autofree(building)
	building.rotation.y = deg_to_rad(yaw_deg)
	var sign_node: LobbySign = LobbySignScript.new()
	building.add_child(sign_node)
	sign_node.build(BOARD_WIDTH, BOARD_HEIGHT, APPROACH,
		LobbySignScript.HEADLINE, LobbySignScript.SUBLINE)
	return sign_node


## How far a mesh's frontmost corner reaches along `direction`, in WORLD space. Taken off the
## eight corners of the world AABB rather than off the node's origin, because what occludes
## what is decided by the near FACE of a slab, not by its centre: the Trim is thicker than
## the Board and a centre only comparison would call the right order on the wrong evidence.
func _front_reach(mesh: MeshInstance3D, direction: Vector3) -> float:
	var box: AABB = mesh.get_aabb()
	var xform: Transform3D = mesh.global_transform
	var reach: float = -INF
	for i in range(8):
		reach = maxf(reach, (xform * box.get_endpoint(i)).dot(direction))
	return reach


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


## THE BUG THIS FILE COULD NOT SEE, AND THE ONE THE OWNER WOULD HAVE. Every earlier test here
## built the sign straight onto the test root facing world plus Z: the single configuration
## in which local space and world space coincide, so a build() that used a WORLD facing as a
## LOCAL offset and a LOCAL yaw passed cleanly while the shipped Palace, yawed half a turn,
## put its gold Trim in front of the Board and both lines and turned the letters around to
## face inside the building. So this asks the question in WORLD space, under a parent yawed
## the way ranch.tscn stands the Palace, and under four other yaws for good measure: along
## the approach, the letters must be in front of the board and the board in front of the
## trim, and the letters must actually be looking back down the approach.
func test_the_board_assembles_front_to_back_under_a_yawed_building() -> void:
	for yaw_deg: float in PARENT_YAWS:
		var sign_node: LobbySign = _built_under_a_building_yawed(yaw_deg)
		var trim := sign_node.get_node(^"Trim") as MeshInstance3D
		var board := sign_node.get_node(^"Board") as MeshInstance3D
		var trim_reach: float = _front_reach(trim, APPROACH)
		var board_reach: float = _front_reach(board, APPROACH)
		assert_gt(board_reach, trim_reach,
			"at yaw %.0f the trim stands in front of the board and hides it" % yaw_deg)
		for path: NodePath in [^"Headline", ^"Subline"]:
			var label := sign_node.get_node(path) as Label3D
			var depth: float = label.global_position.dot(APPROACH)
			assert_gt(depth, board_reach,
				"at yaw %.0f %s is buried in the board" % [yaw_deg, path])
			var looks: Vector3 = label.global_transform.basis * Vector3(0.0, 0.0, 1.0)
			assert_gt(looks.dot(APPROACH), 0.99,
				"at yaw %.0f %s has its back to the approach" % [yaw_deg, path])
			assert_eq(label.double_sided, false,
				"a one sided label must be the side the player is on")


## BOTH GAP TESTS MEASURE ALONG APPROACH WITH _front_reach()/dot(), NOT RAW .position.z, FOR
## THE SAME REASON test_the_board_assembles_front_to_back_under_a_yawed_building ABOVE ALREADY
## DOES. At yaw 0.0 the building carries no rotation, so build()'s own facing-to-local
## conversion leaves _local_facing equal to APPROACH itself, i.e. world minus Z: a raw
## `.position.z + size.z * 0.5` reads the WRONG side of a box whose local facing points into
## minus Z, and would silently grade the assembly's back instead of its front. Projecting onto
## the real approach direction is the only measurement that stays correct regardless of which
## way local_facing happens to point.
func test_the_trim_and_the_board_are_never_within_a_hair_of_coplanar() -> void:
	var sign_node: LobbySign = _built_under_a_building_yawed(0.0)
	var trim := sign_node.get_node(^"Trim") as MeshInstance3D
	var board := sign_node.get_node(^"Board") as MeshInstance3D
	var trim_front: float = _front_reach(trim, APPROACH)
	var board_front: float = _front_reach(board, APPROACH)
	assert_gt(board_front - trim_front, LobbySignScript.STANDOFF - 0.001,
		"the board's face must stand clear of the trim's, or the two z fight")


func test_the_headline_stands_clear_of_the_board_it_is_written_on() -> void:
	var sign_node: LobbySign = _built_under_a_building_yawed(0.0)
	var board := sign_node.get_node(^"Board") as MeshInstance3D
	var headline := sign_node.get_node(^"Headline") as Label3D
	var board_front: float = _front_reach(board, APPROACH)
	var headline_reach: float = headline.global_position.dot(APPROACH)
	assert_gt(headline_reach - board_front, LobbySignScript.STANDOFF - 0.001,
		"unlit letters lying on a panel flicker against it")


func test_neither_line_carries_a_dash() -> void:
	for line: String in LobbySignScript.lines():
		assert_false(line.contains("--"), "'%s' carries a double hyphen" % line)
		assert_false(line.contains("—"), "'%s' carries an em dash" % line)
		assert_false(line.is_empty())
