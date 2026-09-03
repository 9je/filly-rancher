class_name Strip
extends Node3D
## THE PAVED STRIP at the north edge of the map: a ring of lamps and a marquee, and the
## ground the Spectra Palace stands on.
##
## WHAT IS HERE AND WHAT IS NOT. The grey ground is the region's own grass colours
## (game/data/regions/strip.tres, read by game/world/terrain.gd like every other region's).
## The Palace itself is a Building under $Buildings, seated and counted with the barn and the
## Depot, because it is a building. This node owns only the scenery that makes the place read
## as somewhere at night: a ring of lamp posts and one lit marquee facing the walk up from
## the homestead.
##
## EIGHT LAMPS ON A TEN POSITION RING. LIGHT_COUNT is the number of points build() walks, not
## the number of posts that end up standing: avoid_footprint() skips any position that lands
## inside an excluded rectangle, and on this map two do -- one inside the Palace's own walls,
## and one inside its door apron, which reaches Building.DOOR_APRON_RUN past those walls and
## caught a lamp PALACE_CLEARANCE alone did not (a lamp standing in the doorway, found and
## fixed in the look pass's own review) -- so a built Strip reports light_count() of 8. See
## build() and avoid_footprint() for why a position is dropped rather than nudged.
##
## ITS CHILDREN ARE DELIBERATELY NOT COUNTED AS PROPS. ranch.gd's prop census is
## Props.expected_count() plus the Buildings children, and lamp posts are under neither. A
## lamp is scenery; the gate has no claim to make about it, and adding a ring of them to a
## count every doc in the repo names would be churn for nothing.
##
## BUILT IN CODE AND NOT IN THE SCENE FILE, for the reason game/world/region_fence.gd gives:
## the ground does not exist until Terrain.build() has run, and a lamp post authored in
## ranch.tscn would be a lamp post hanging at y = 0 over a map with real relief in it.
##
## THE LIGHTS CAST NO SHADOWS, unlike Building's interior fill. A lamp post out in the open
## has nothing to leak through, and a ring of shadow casting omnis on a heightfield is a bill
## this map does not need to pay for a decorative glow.

const LayersScript := preload("res://world/collision_layers.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")

const REGION_ID := &"strip"

## Lamps, and the ring they stand on. The ring sits inside the region rim and outside the
## track's far lane, so the track is lit from around its edge. Centred on the REGION, not
## on Buildings/Palace: the Palace sits off centre (see PALACE_MAX_RELIEF's comment in
## ranch.gd), so one point on this ring falls inside its footprint; avoid_footprint()
## below is what keeps a post from standing in the wall.
const LIGHT_COUNT := 10
const LIGHT_RING_RADIUS := 21.0
const POST_HEIGHT := 4.2
const POST_THICKNESS := 0.18

## Extra clearance kept past whatever AABB avoid_footprint() is handed, on top of that
## footprint's own half-width and half-depth. Bigger than the roof's own eave overhang
## (Building.eave_overhang, 0.45 m by default) so a kept lamp reads as placed on purpose
## rather than as a near miss.
const PALACE_CLEARANCE := 1.5

## THE MARQUEE BOARD, sized and placed from the PALACE'S OWN MEASUREMENTS rather than typed
## as world coordinates. mount_marquee() is handed the front face of the building, its half
## extents and its ridge height by ranch.gd, off the live node; every number below is a
## fraction or an offset applied to those. The pair could drift before, and did: a hand
## typed MARQUEE_AT sat at y = 5.4 on a building whose ridge is at 4.6.
##
## WIDTH is a fraction of the building's own width, so the board is always visibly narrower
## than the wall behind it. TOP_GAP is how far its top edge stays UNDER the ridge, which is
## the "mounted clear of the roofline" the report asked for. STANDOFF is how far in front of
## the wall it hangs, far enough that the two never fight for pixels.
const MARQUEE_WIDTH_FRACTION := 0.62
const MARQUEE_HEIGHT := 1.60
const MARQUEE_TOP_GAP := 0.35
const MARQUEE_STANDOFF := 0.55
const MARQUEE_BOARD_COLOR := Color(0.16, 0.07, 0.20)
const MARQUEE_TRIM_COLOR := Color(0.98, 0.86, 0.45)
const MARQUEE_TRIM := 0.10

## The headline fills this much of the board's height; the sponsor line under it is
## SPONSOR_SCALE of that. Both are a FRACTION OF THE BOARD, which is what "fitted text"
## means: change the board and the letters follow it.
const MARQUEE_HEADLINE_FRACTION := 0.34
const MARQUEE_SPONSOR_SCALE := 0.55

## Font size the Label3Ds are rasterised at. Only the ratio font_size * pixel_size is a
## physical size; this is picked high so the glyphs stay crisp on a board a player walks up
## to, and pixel_size is then derived from it.
const MARQUEE_FONT_SIZE := 96

const POST_COLOR := Color(0.24, 0.22, 0.28)
const LAMP_COLOR := Color(1.0, 0.86, 0.55)
const MARQUEE_COLOR := Color(1.0, 0.92, 0.62)
const LAMP_ENERGY := 2.2
const LAMP_RANGE := 16.0

## TEN BULBS ROUND THE MARQUEE TRIM, as ONE MultiMeshInstance3D: ten instances and one draw
## call. With glow on (the Environment gains it in the look pass) they bloom gently at dusk
## and night, which is the whole point of a marquee.
##
## NOT IN _lights, DELIBERATELY. Strip.light_count() answers how many LAMP POSTS are standing
## on the ring, the strip gate asserts it is LIGHT_COUNT minus the two skipped clear of the
## Palace (its walls, and since the look pass its door apron), and a bulb rail counted among
## them would break that check for a reason that has nothing to do with lamp posts.
const MARQUEE_BULBS := 10
const MARQUEE_BULB_RADIUS := 0.055

## One soft wash on the board's own face. shadow_enabled off for the reason this file already
## gives about its lamp ring: a light out in the open has nothing to leak through, and a
## shadow map on it is a cost with no picture attached.
##
## RANGE AND ANGLE ARE A HARD CUTOFF, NOT A SUGGESTION, AND THAT IS THE POINT. The headline
## and sponsor labels are `shaded = false` (unlit, always readable off their own modulate) and
## the ten bulbs are emissive, so this light's entire job is keeping the board's own dark panel
## and gold trim from reading as a black hole -- it was never what makes the marquee "read as
## lit". At the old 38 degrees and 6.0 m, aimed back at the board's dead centre from 2.2 m out
## and 1.1 m up, MEASURED (not guessed) against the built scene: the closest point on the
## Palace's own DoorApron was only 1.03 m from this light, because the door, its apron and the
## sign above it all sit on the same wall centreline. Godot's spot_range is a hard sphere and
## the apron was well inside it either way, so the fix could not be range or angle ALONE --
## the board's own bottom edge (2.65 m up) sits BELOW the apron's own top edge (2.92 m up), so
## any cone wide enough to reach the board's centre from straight out front necessarily swept
## through the apron's own airspace on the way, at any angle or range that still lit the board.
##
## AIMED HIGH INSTEAD. Aiming at the board's UPPER portion (0.7 m above its own centre, close
## to the headline) rather than its dead centre lets the light sit high enough, and its aim
## tilt down gently enough, that its cone's own lower edge never dips as far as the apron's own
## airspace -- verified by sampling the built DoorApron's, the Floor's and the board's own
## meshes directly (a throwaway probe script, not eyeballed): 0 of 961 sample points anywhere
## on the apron's six faces or the Floor's own top face fall inside this cone at these numbers,
## while roughly a third of the board's own face still does (down from about two fifths at the
## old numbers -- a real loss, paid for keeping the door apron out of the beam entirely rather
## than merely dimmer).
const MARQUEE_WASH_ENERGY := 2.4
const MARQUEE_WASH_ANGLE := 36.0
const MARQUEE_WASH_RANGE := 3.0

var _region: RegionData = null
var _ground := Callable()
var _lights: Array[Node3D] = []
var _built := false

var _marquee_centre := Vector3.ZERO
## The way the board looks, flat and unit length. A Building's door is in its local plus Z
## gable end, so this is that axis put through the building's own basis by ranch.gd; the
## default is the unturned axis, for a Strip nobody has mounted a sign on.
var _marquee_facing := Vector3(0.0, 0.0, 1.0)
var _marquee_size := Vector2.ZERO
var _marquee_ceiling := 0.0
var _has_marquee := false

## The rectangles, in world XZ, no lamp may stand inside. Empty until avoid_footprint() is
## called; nothing is skipped in that case. EACH CALL ADDS ONE MORE RECTANGLE rather than
## replacing the last one -- see avoid_footprint()'s own comment for why the Palace's own
## footprint and its door apron are now two separate calls rather than one shape wide enough
## to cover both (which would also exclude ground on the building's BACK side that no lamp
## was ever standing on).
var _avoid_rects: Array[Rect2] = []


## Hand over the region this strip paves and a way to ask the terrain how high it is. Both
## before build(), the same contract RegionFence.configure() has.
func configure(region: RegionData, ground_sampler: Callable) -> void:
	_region = region
	_ground = ground_sampler


## A footprint, in world XZ, that no lamp may stand inside or against: `centre_xz` and
## `half_extents` (half-width, half-depth) of whatever is standing on the Strip's own
## ground -- a building's own walls, or (since the door apron joined this rule) something
## that only projects past them. PALACE_CLEARANCE is added past those edges on every side.
## Call before build(), same as configure(); safe to call zero, one or several times, and
## each call ADDS one more excluded rectangle rather than replacing the last, which is what
## lets a caller hand over a building's walls and its door apron as two separate rectangles
## instead of forcing one shape to cover both (see ranch.gd's own two calls for the Palace).
##
## Not folded into configure() itself: RegionFence's contract, the one configure()
## deliberately matches, has no such thing to hand over, and every other region's fence
## never needs one. Kept as world-space XZ rather than a Building reference so this file
## does not have to know what a Building is; ranch.gd reads the Palace's own global_position,
## width, depth and door apron reach straight off the live node and hands over the
## rectangles, not the node.
func avoid_footprint(centre_xz: Vector2, half_extents: Vector2) -> void:
	var pad: Vector2 = half_extents + Vector2(PALACE_CLEARANCE, PALACE_CLEARANCE)
	_avoid_rects.append(Rect2(centre_xz - pad, pad * 2.0))


## WHERE THE SIGN GOES, in the building's own terms. `front_centre` is the middle of the
## Palace's front wall in world space, `out_dir` the direction its door faces (flat, unit
## length), `half_extents` its half width and half depth, and `ridge_y` the world height of
## its ridge. Call before build(), same contract as configure() and avoid_footprint(); an
## unmounted Strip simply stands no marquee, which is a Strip with no building on it.
##
## KEPT AS PLAIN NUMBERS rather than as a Building reference, for the reason
## avoid_footprint() gives: this file does not have to know what a Building is, and
## ranch.gd reads the live node's own width, depth and ridge_height so a re sited or
## re proportioned Palace moves its own sign.
##
## OUT_DIR IS HANDED IN RATHER THAN ASSUMED. This file used to hang the board at
## `front_centre.z - MARQUEE_STANDOFF` and turn its letters by exactly PI, which is world
## minus Z written down twice: correct only because ranch.tscn happens to turn the Palace a
## half turn, and silently wrong for any other angle, including the one a later re siting
## would use. ranch.gd derives the direction from the building's own basis, the same way
## _stand_one() derives where an attendant stands, and hands it over.
func mount_marquee(front_centre: Vector3, out_dir: Vector3, half_extents: Vector2,
		ridge_y: float) -> void:
	var facing: Vector3 = Vector3(out_dir.x, 0.0, out_dir.z)
	if facing.length_squared() <= 0.0:
		# A degenerate direction is a caller bug, not a reason to stand no sign: fall back
		# on the way every Building's own door faces before it is turned.
		facing = Vector3(0.0, 0.0, 1.0)
	_marquee_facing = facing.normalized()
	var board_width: float = half_extents.x * 2.0 * MARQUEE_WIDTH_FRACTION
	_marquee_size = Vector2(board_width, MARQUEE_HEIGHT)
	_marquee_ceiling = ridge_y - MARQUEE_TOP_GAP
	_marquee_centre = Vector3(front_centre.x, _marquee_ceiling - MARQUEE_HEIGHT * 0.5,
		front_centre.z) + _marquee_facing * MARQUEE_STANDOFF
	_has_marquee = true


## The direction the board's face looks in, flat and unit length. Whatever mount_marquee()
## was handed, or the unturned default before it is called.
func marquee_facing() -> Vector3:
	return _marquee_facing


func marquee_board_size() -> Vector2:
	return _marquee_size


func marquee_board_centre() -> Vector3:
	return _marquee_centre


func marquee_top_y() -> float:
	return _marquee_centre.y + _marquee_size.y * 0.5


## What the board says, top line first. Read out of CasinoSign so the sign outside cannot
## drift from the sign in the lobby.
func marquee_lines() -> Array[String]:
	return [CasinoSignScript.marquee_headline(), CasinoSignScript.marquee_sponsor()]


## Stand the lamps and hang the marquee. Idempotent. One lamp per ring position, unless
## avoid_footprint() was called and a position lands inside it, in which case that one is
## skipped rather than moved: a gap in the ring exactly where a wall already blocks the view
## from outside reads as intentional, and nudging a post risks landing it somewhere else
## that clips something else instead.
func build() -> void:
	if _built or _region == null:
		return
	_built = true
	for i in LIGHT_COUNT:
		var angle: float = TAU * float(i) / float(LIGHT_COUNT)
		var x: float = _region.centre.x + cos(angle) * LIGHT_RING_RADIUS
		var z: float = _region.centre.y + sin(angle) * LIGHT_RING_RADIUS
		var blocked := false
		for rect: Rect2 in _avoid_rects:
			if rect.has_point(Vector2(x, z)):
				blocked = true
				break
		if blocked:
			continue
		_lights.append(_lamp("Lamp%d" % i, Vector3(x, _y(x, z), z)))
	_marquee()


func light_count() -> int:
	return _lights.size()


## Every built lamp's own world position, for a caller (the ranch gate) that wants to
## confirm none of them stands inside or against something else; see avoid_footprint().
func light_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l in _lights:
		out.append(l.global_position)
	return out


func _y(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else 0.0


## One post with a lamp on top. The post has collision so the player cannot stand inside it;
## the lamp does not, because a light is not a thing.
func _lamp(lamp_name: String, base: Vector3) -> Node3D:
	var post := StaticBody3D.new()
	post.name = lamp_name
	post.collision_layer = LayersScript.PROPS
	post.collision_mask = 0
	add_child(post)
	post.global_position = base

	var box := BoxMesh.new()
	box.size = Vector3(POST_THICKNESS, POST_HEIGHT, POST_THICKNESS)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = POST_COLOR
	mat.roughness = 0.8
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = "Post"
	mesh.mesh = box
	mesh.position = Vector3(0.0, POST_HEIGHT * 0.5, 0.0)
	post.add_child(mesh)

	var shape := BoxShape3D.new()
	shape.size = box.size
	var collider := CollisionShape3D.new()
	collider.name = "PostCol"
	collider.shape = shape
	collider.position = mesh.position
	post.add_child(collider)

	var light := OmniLight3D.new()
	light.name = "Lamp"
	light.position = Vector3(0.0, POST_HEIGHT, 0.0)
	light.light_color = LAMP_COLOR
	light.light_energy = LAMP_ENERGY
	light.omni_range = LAMP_RANGE
	light.omni_attenuation = 0.9
	light.shadow_enabled = false
	post.add_child(light)
	return post


## THE SIGN YOU READ ON THE WAY IN: a backing board with a trim edge, the headline fitted
## across it, and the sponsor line under it in smaller letters.
##
## FITTED MEANS THE TEXT IS TOLD HOW WIDE IT MAY BE. Label3D.width is a wrapping width in
## the same pixel units font_size is in, so setting it to the board's width in pixels and
## turning autowrap on is what actually stops a long line running off the edge; the old
## marquee set neither and rendered about 18 m of text across a 14 m building. pixel_size
## is then the board's real width divided by that same pixel width, so one number converts
## the whole thing and the letters cannot end up a different size from the board.
func _marquee() -> void:
	if not _has_marquee:
		return
	var board := MeshInstance3D.new()
	board.name = "MarqueeBoard"
	var box := BoxMesh.new()
	box.size = Vector3(_marquee_size.x, _marquee_size.y, 0.12)
	box.material = _flat_material(MARQUEE_BOARD_COLOR)
	board.mesh = box
	add_child(board)
	board.global_position = _marquee_centre

	var trim := MeshInstance3D.new()
	trim.name = "MarqueeTrim"
	var trim_box := BoxMesh.new()
	trim_box.size = Vector3(_marquee_size.x + MARQUEE_TRIM * 2.0,
		_marquee_size.y + MARQUEE_TRIM * 2.0, 0.08)
	trim_box.material = _flat_material(MARQUEE_TRIM_COLOR)
	trim.mesh = trim_box
	add_child(trim)
	trim.global_position = _marquee_centre + _marquee_facing * 0.03

	var lines: Array[String] = marquee_lines()
	var headline_height: float = _marquee_size.y * MARQUEE_HEADLINE_FRACTION
	_marquee_label("MarqueeHeadline", lines[0], headline_height,
		_marquee_centre + Vector3(0.0, _marquee_size.y * 0.20, 0.0)
			+ _marquee_facing * 0.09)
	_marquee_label("MarqueeSponsor", lines[1],
		headline_height * MARQUEE_SPONSOR_SCALE,
		_marquee_centre + Vector3(0.0, -_marquee_size.y * 0.24, 0.0)
			+ _marquee_facing * 0.09)
	_marquee_bulbs()
	_marquee_wash()


## One line of the sign, `cap_height` metres tall, fitted to the board's width and hung at
## `at`. Faces the walk up to the door, whichever way the building has been turned: Label3D's
## own text faces its local plus Z, so the yaw that points that at _marquee_facing is
## atan2(x, z) of the facing itself. A hard coded half turn read correctly only for a
## building standing exactly the way ranch.tscn happens to stand this one.
func _marquee_label(label_name: String, text: String, cap_height: float,
		at: Vector3) -> void:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = MARQUEE_FONT_SIZE
	var pixel: float = cap_height / float(MARQUEE_FONT_SIZE)
	label.pixel_size = pixel
	# The width the text may occupy, in the same pixel units font_size is in. Set together
	# with the wrap mode; either one alone does nothing.
	label.width = _marquee_size.x / pixel
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = MARQUEE_COLOR
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.no_depth_test = false
	add_child(label)
	label.global_position = at
	label.rotation.y = atan2(_marquee_facing.x, _marquee_facing.z)


func _flat_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func marquee_bulb_count() -> int:
	return MARQUEE_BULBS


## Ten emissive spheres spaced round the trim's perimeter, built as one MultiMesh so the whole
## rail is one draw call.
func _marquee_bulbs() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = MARQUEE_BULB_RADIUS
	sphere.height = MARQUEE_BULB_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARQUEE_TRIM_COLOR
	mat.emission_enabled = true
	mat.emission = MARQUEE_TRIM_COLOR
	mat.emission_energy_multiplier = 2.2
	sphere.material = mat

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	multi.instance_count = MARQUEE_BULBS

	var half := Vector2(_marquee_size.x * 0.5 + MARQUEE_TRIM * 0.5,
		_marquee_size.y * 0.5 + MARQUEE_TRIM * 0.5)
	var right := Vector3(-_marquee_facing.z, 0.0, _marquee_facing.x)
	for i in MARQUEE_BULBS:
		# Round the rim: five across the top and five across the bottom, which is the shape a
		# marquee's bulb rail actually has.
		var across: float = -1.0 + 2.0 * (float(i % 5) / 4.0)
		var up: float = 1.0 if i < 5 else -1.0
		var at: Vector3 = _marquee_centre + right * (half.x * across) \
			+ Vector3(0.0, half.y * up, 0.0) + _marquee_facing * 0.06
		multi.set_instance_transform(i, Transform3D(Basis(), at))

	var node := MultiMeshInstance3D.new()
	node.name = "MarqueeBulbs"
	node.multimesh = multi
	add_child(node)


func _marquee_wash() -> void:
	var light := SpotLight3D.new()
	light.name = "MarqueeWash"
	light.light_color = LAMP_COLOR
	light.light_energy = MARQUEE_WASH_ENERGY
	light.spot_range = MARQUEE_WASH_RANGE
	light.spot_angle = MARQUEE_WASH_ANGLE
	light.shadow_enabled = false
	add_child(light)
	# 2.0 m out and 1.4 m up, aimed 0.7 m ABOVE the board's own centre rather than at it: see
	# MARQUEE_WASH_RANGE's own comment for the measured geometry this keeps the beam out of.
	light.global_position = _marquee_centre + _marquee_facing * 2.0 + Vector3(0.0, 1.4, 0.0)
	light.look_at(_marquee_centre + Vector3(0.0, 0.7, 0.0), Vector3.UP)
