class_name LobbySign
extends Node3D
## THE BOARD BESIDE THE PALACE DOOR, and the thing it replaced.
##
## WHAT IT REPLACED. Buildings/Palace/Sign was a Label3D carrying all eleven lines of
## CasinoSign.lines() at pixel_size 0.0032 and font_size 48: a cap height of about 0.15 m per
## line, roughly 1.7 m of unbacked text hanging in the air 2.1 m up and 4.1 m out from the
## Palace's local origin. It was the single worst piece of floating text in the game and it is
## the one the owner named: "the note on the casino looks very poor".
##
## WHERE THE ELEVEN LINES WENT, AND WHY THE PROMISE IS KEPT. game/systems/casino_sign.gd's
## whole ethical position is that the odds on the sign are the real ones and that it ASKS EACH
## GAME what its edge is. None of that changed: CasinoSign.lines() is untouched, it still
## derives all four numbers from Slots.house_edge(), Wheel.house_edge(), Blackjack.house_edge()
## and RaceCard.TAKEOUT, and CasinoMenu's sign_provider still calls it. The eleven lines are
## drawn on the lobby's House rules page, reachable from the picker the player sees the moment
## she walks in. THE EDGES BECAME MORE VISIBLE, NOT LESS: they were a distant paragraph
## outside a door and they are now a page inside the building that the lobby points at.
##
## FITTED, THE SAME WAY THE MARQUEE IS. game/world/strip.gd's _marquee_label() is the method
## this copies: the label's width is set in the same pixel units its font_size is in, together
## with the wrap mode, because either one alone does nothing, and the yaw comes from the
## facing rather than from a hard coded half turn that reads correctly only for a building
## standing the way ranch.tscn happens to stand this one.
##
## NOTHING HERE HANGS BELOW LOCAL y = 0. ranch.gd's seating check measures the bottom of every
## MeshInstance3D under a building; a board reaching below the Palace's origin would drag that
## bottom down and fail the gate on a correctly placed building.

const HEADLINE := "House rules"
const SUBLINE := "every edge we keep, printed inside"

## Board and trim colours, lifted from game/world/strip.gd's marquee so the two signs on this
## one building are obviously the same signwriter's work.
const BOARD_COLOR := Color(0.16, 0.07, 0.20)
const TRIM_COLOR := Color(0.98, 0.86, 0.45)
const TEXT_COLOR := Color(1.0, 0.92, 0.62)
const TRIM := 0.08
const THICKNESS := 0.10

## The headline's cap height as a fraction of the board, and the subline's as a fraction of
## the headline. Strip.MARQUEE_HEADLINE_FRACTION's and MARQUEE_SPONSOR_SCALE's numbers, for
## the same reason: they were arrived at by looking at a rendered board.
const HEADLINE_FRACTION := 0.34
const SUBLINE_SCALE := 0.55
const FONT_SIZE := 96

var _size := Vector2.ZERO
var _facing := Vector3(0.0, 0.0, 1.0)
## The same direction expressed in THIS node's own space, which is the space every child
## position and child yaw below is written in. See build() for why the two are not the same
## vector on the shipped Palace.
var _local_facing := Vector3(0.0, 0.0, 1.0)


static func lines() -> Array[String]:
	return [HEADLINE, SUBLINE]


func board_size() -> Vector2:
	return _size


## Stand the board. `facing` is the direction the letters look IN WORLD SPACE, normally the
## building's own outward axis; `board_width` and `board_height` are metres.
func build(board_width: float, board_height: float, facing: Vector3,
		headline: String, subline: String) -> void:
	_size = Vector2(board_width, board_height)
	var flat := Vector3(facing.x, 0.0, facing.z)
	_facing = flat.normalized() if flat.length_squared() > 0.0 else Vector3(0.0, 0.0, 1.0)

	# TWO SPACES, CONVERTED ONCE, HERE. `facing` arrives in WORLD space (ranch.gd derives it
	# from the Palace's own basis) but every child below is positioned and yawed in THIS
	# node's space, and this node hangs under Buildings/Palace, which ranch.tscn stands yawed
	# half a turn. Using the world vector directly as a local offset and a local yaw is what
	# put the gold Trim in FRONT of the Board and both lines, and left the letters' own plus Z
	# pointing away from the approach with double_sided off: a blank gold slab beside the door.
	# Converting once and building everything off the converted vector keeps the assembly
	# correct for ANY yaw the building is stood at, which is the same promise the yaw itself
	# was written to keep. orthonormalized() so a scaled parent cannot skew the direction, and
	# global_transform is final at this point because ranch.gd adds the child and sets its
	# position before calling build().
	var converted: Vector3 = global_transform.basis.orthonormalized().inverse() * _facing
	converted.y = 0.0
	_local_facing = converted.normalized() if converted.length_squared() > 0.0 \
		else Vector3(0.0, 0.0, 1.0)

	# The whole assembly's vertical anchor sits TRIM above local y = 0, so the Trim slab
	# (which extends TRIM past the board's own edge on every side, including the bottom) never
	# dips below the sign's own origin. See the class comment: ranch.gd's seating check reads
	# the bottom of every MeshInstance3D under a Building, and a mesh hanging below y = 0 here
	# would drag the Palace's measured AABB down past its seat.
	var anchor: float = board_height * 0.5 + TRIM
	_slab("Trim", Vector3(board_width + TRIM * 2.0, board_height + TRIM * 2.0, THICKNESS),
		Vector3(0.0, anchor, 0.0), TRIM_COLOR)
	_slab("Board", Vector3(board_width, board_height, THICKNESS * 0.6),
		Vector3(0.0, anchor, 0.0) + _local_facing * 0.03, BOARD_COLOR)

	var headline_height: float = board_height * HEADLINE_FRACTION
	_label("Headline", headline, headline_height,
		Vector3(0.0, anchor + board_height * 0.18, 0.0) + _local_facing * 0.07)
	_label("Subline", subline, headline_height * SUBLINE_SCALE,
		Vector3(0.0, anchor - board_height * 0.20, 0.0) + _local_facing * 0.07)


func _slab(slab_name: String, size: Vector3, at: Vector3, colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = slab_name
	mesh.mesh = box
	add_child(mesh)
	mesh.position = at
	mesh.rotation.y = atan2(_local_facing.x, _local_facing.z)


## One line, `cap_height` metres tall, FITTED to the board's width. Label3D's own text faces
## its local plus Z, so the yaw that points that at the facing is atan2(x, z) of the facing
## AS SEEN IN THE PARENT'S SPACE, which is the space rotation.y is written in.
func _label(label_name: String, text: String, cap_height: float, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = FONT_SIZE
	var pixel: float = cap_height / float(FONT_SIZE)
	label.pixel_size = pixel
	# Set together with the wrap mode; either one alone does nothing.
	label.width = _size.x / pixel
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = TEXT_COLOR
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	add_child(label)
	label.position = at
	label.rotation.y = atan2(_local_facing.x, _local_facing.z)
