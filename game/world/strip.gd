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
const MARQUEE_HEIGHT := 1.10
const MARQUEE_TOP_GAP := 0.35
## Metres from the ground at the Palace's front to the marquee's lower edge: above the third
## person camera's head as she climbs the steps.
const MARQUEE_CLEARANCE := 4.6
const MARQUEE_STANDOFF := 0.55
const MARQUEE_BOARD_COLOR := Color(0.16, 0.07, 0.20)
const MARQUEE_TRIM_COLOR := Color(0.98, 0.86, 0.45)
const MARQUEE_TRIM := 0.10

## HOW FAR EACH LAYER OF THE SIGN STANDS IN FRONT OF THE ONE BEHIND IT.
##
## THE BUG THIS CLOSES. The trim slab is 0.08 deep hung 0.03 in front of a 0.12 deep board:
## the trim's front face landed at +0.07 and the board's at +0.06, one centimetre apart
## across two full sized quads, which is two surfaces fighting for the same pixels at every
## distance a player looks at this sign from. Five centimetres is small enough that nobody
## reads it as a design change and large enough that the depth buffer is never asked to
## choose. game/world/lobby_sign.gd's STANDOFF is the same number for the same reason.
const MARQUEE_STANDOFF_LAYER := 0.05

## THE ARCH OVER THE BOARD: how many segments it is drawn from and how far it rises above
## the board's own top edge.
##
## A MARQUEE IS AN ARCH WITH BULBS ROUND IT. What stood here was a flat slab with a Label3D
## in front of it and five bulbs along the top and five along the bottom, which is a notice
## board with lights on it. Twelve segments, each sized to its own true chord of the board's
## own ellipse (see _marquee_arch()), reads as a smooth curve at the distance the walk up to
## the door actually offers, rather than the fan of straight struts a fixed circular sweep
## drew here before.
const MARQUEE_ARCH_SEGMENTS := 12

## THE BUDGET, NOT THE BARE AMPLITUDE. _marquee_arch() below shrinks the ellipse's own
## amplitude so the BUILT mesh's real worst corner -- centre plus the segment's own rotated
## half length, plus the box's own half thickness on the other two axes -- lands at or under
## marquee_top_y() + MARQUEE_ARCH_RISE, not merely the bare curve. A box drawn CENTRED on a
## curve sticks up past that curve by roughly its own half thickness even where the curve is
## dead flat, so building the curve at the full nominal amplitude and only then measuring
## would already be over budget before any segment even tilts -- which is exactly the numbers
## a reviewer found by hand once the previous circular-sweep formula's own overshoot was
## accounted for (see _marquee_arch()'s own comment). 0.30 here is the budget MARQUEE_TOP_GAP
## (0.35) leaves under the ridge, not the curve's own visible rise.
const MARQUEE_ARCH_RISE := 0.30
const MARQUEE_ARCH_THICKNESS := 0.16
## A hair over 1.0 so neighbouring segments' own end caps overlap rather than leave a hairline
## gap at the joint between two straight chords of a curve.
const MARQUEE_ARCH_OVERLAP := 1.04

## HEADROOM KEPT BELOW MARQUEE_ARCH_RISE ITSELF, on top of whatever _marquee_arch() already
## shrinks the ellipse's own amplitude by to respect that rise. MARQUEE_ARCH_RISE (0.30) was
## picked so marquee_top_y() + MARQUEE_ARCH_RISE lands EXACTLY at ridge_y - 0.05 given
## MARQUEE_TOP_GAP (0.35): a builder that saturates the rise budget therefore also saturates
## the roof's own safety margin, converging to within fractions of a millimetre of the ridge
## rather than clearing it by anything a person would call real daylight. This is subtracted
## from the rise before _marquee_arch() solves for the built peak, so the peak this sign
## actually ships with sits comfortably under BOTH lines rather than exactly on either.
const MARQUEE_ARCH_SAFETY_MARGIN := 0.08

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

## THE BULB RAIL, as ONE MultiMeshInstance3D so the whole ring is one draw call. With glow on
## (the Environment gains it in the look pass) they bloom gently at dusk and night, which is
## the whole point of a marquee.
##
## NOT IN _lights, DELIBERATELY. Strip.light_count() answers how many LAMP POSTS are standing
## on the ring, the strip gate asserts it is LIGHT_COUNT minus the two skipped clear of the
## Palace (its walls, and since the look pass its door apron), and a bulb rail counted among
## them would break that check for a reason that has nothing to do with lamp posts.
##
## EIGHTEEN, ROUND THE ARCH AND ALONG THE BOARD'S FOOT. Ten in two straight rows was the
## board's shape; a marquee's rail follows its own outline, which here is nine segments of
## arch plus nine along the bottom edge under them.
const MARQUEE_BULBS := 18
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
## The arch's own built peak, in world Y, set by _marquee_arch() from the same per-segment
## transforms it hands the actual nodes -- see marquee_arch_peak_y().
var _marquee_arch_peak_y := 0.0

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
	# ABOVE THE DOOR, NOT ACROSS IT (owner playtest 2026-10-25: "weird sign you gotta walk
	# through to get in"). Hung under the ridge, its lower edge sat at 3.6 m in front of the
	# steps, and the third person camera behind a pony climbing them passed straight through
	# it. Lifted so its lower edge clears MARQUEE_CLEARANCE over the ground the steps start on.
	_marquee_ceiling = maxf(ridge_y - MARQUEE_TOP_GAP,
		front_centre.y + MARQUEE_CLEARANCE + MARQUEE_HEIGHT)
	_marquee_centre = Vector3(front_centre.x, _marquee_ceiling - MARQUEE_HEIGHT * 0.5,
		front_centre.z) + _marquee_facing * MARQUEE_STANDOFF
	_has_marquee = true


## Metres from the FLOOR OF THE DOORWAY (the top of the Palace's plinth, where her hooves are
## as she goes in) to the board's lower edge, once the Palace has been seated: over the 3.06 m
## doors and over the third person camera behind a pony on the top step (about 2.4 m over that
## floor at the default pitch), and no higher, so the board stays on the frieze under the
## model's own pink sign.
const MARQUEE_DOOR_CLEARANCE := 3.3


## HANG IT AGAIN, OVER THE SEATED DOOR (2026-10-26). The Strip is built, marquee and all, while
## the Palace still stands at y = 0; ranch.gd seats every building afterwards, and the Palace
## rises nearly three metres onto its plinth (Building.seat_ground(), Building.FLOOR_TOP). The
## board is the Strip's, not the Palace's, so it stayed where it was hung: its lower edge 1.7 m
## over the floor of the doorway, which is the "weird sign you gotta walk through to get in"
## the round 2 fix measured from the wrong ground. ranch.gd calls this after the seating loop
## with the seated numbers, and every marquee node moves by the same amount. Returns how far.
func rehang_marquee(door_floor_y: float, ridge_y: float) -> float:
	if not _has_marquee:
		return 0.0
	var ceiling: float = maxf(ridge_y - MARQUEE_TOP_GAP,
		door_floor_y + MARQUEE_DOOR_CLEARANCE + MARQUEE_HEIGHT)
	var dy: float = ceiling - _marquee_ceiling
	_marquee_ceiling = ceiling
	_marquee_centre.y += dy
	if absf(dy) < 0.0001:
		return 0.0
	for c: Node in get_children():
		if c is Node3D and String(c.name).begins_with("Marquee"):
			(c as Node3D).global_position.y += dy
	return dy


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
	_paving()


## THE STRIP IS PAVED, NOT GREY GRASS (PT7; playtest 2026-11-05: the Strip "looks like shit",
## a flat grey field with a few machines on it). Flagstones in the foundations' own stonework
## shader, laid over the region's ground a few centimetres up and following it, the track's
## oval and the Palace's own footprint left open. Drawing only: the ground under it is still
## what everything walks on.
const PAVING_LIFT := 0.035
const PAVING_STEP := 1.5
const PAVING_TRACK := Rect2(-25.0, 72.0, 50.0, 16.0)


func _paving() -> void:
	var r: float = _region.radius * 0.97
	var c := Vector2(_region.centre.x, _region.centre.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(ceil(r * 2.0 / PAVING_STEP))
	for ix in n:
		for iz in n:
			var x0 := c.x - r + float(ix) * PAVING_STEP
			var z0 := c.y - r + float(iz) * PAVING_STEP
			var mid := Vector2(x0 + PAVING_STEP * 0.5, z0 + PAVING_STEP * 0.5)
			if mid.distance_to(c) > r or PAVING_TRACK.has_point(mid) or _avoided(mid):
				continue
			var q: Array[Vector3] = []
			for corner: Vector2 in [Vector2(x0, z0), Vector2(x0 + PAVING_STEP, z0),
					Vector2(x0 + PAVING_STEP, z0 + PAVING_STEP), Vector2(x0, z0 + PAVING_STEP)]:
				q.append(Vector3(corner.x, _y(corner.x, corner.y) + PAVING_LIFT, corner.y))
			for i: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Paving"
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/stonework.gdshader")
	mat.set_shader_parameter(&"pattern", 0)
	mat.set_shader_parameter(&"base", Color(0.76, 0.69, 0.62))
	mat.set_shader_parameter(&"joint", Color(0.55, 0.48, 0.44))
	mat.set_shader_parameter(&"block_w", 1.1)
	mat.set_shader_parameter(&"block_h", 0.55)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY


func _avoided(p: Vector2) -> bool:
	for rect: Rect2 in _avoid_rects:
		if rect.has_point(p):
			return true
	return false


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

	# THE LAMP YOU SEE BY DAY (overnight review, 2026-10-26: by day the ring was ten bare
	# dark sticks, the light on top being invisible until dusk). A stepped foot, a gold
	# collar, a warm globe that glows, and a cap over it, in the Palace's gold.
	var gold := StandardMaterial3D.new()
	gold.albedo_color = MARQUEE_TRIM_COLOR
	gold.metallic = 0.5
	gold.roughness = 0.4
	var foot := MeshInstance3D.new()
	foot.name = "Foot"
	var fm := CylinderMesh.new()
	fm.top_radius = POST_THICKNESS * 0.9
	fm.bottom_radius = POST_THICKNESS * 1.6
	fm.height = 0.5
	fm.material = mat
	foot.mesh = fm
	foot.position = Vector3(0.0, 0.25, 0.0)
	post.add_child(foot)
	var collar := MeshInstance3D.new()
	collar.name = "Collar"
	var cm := CylinderMesh.new()
	cm.top_radius = POST_THICKNESS * 0.9
	cm.bottom_radius = POST_THICKNESS * 0.9
	cm.height = 0.14
	cm.material = gold
	collar.mesh = cm
	collar.position = Vector3(0.0, POST_HEIGHT - 0.05, 0.0)
	post.add_child(collar)
	var globe := MeshInstance3D.new()
	globe.name = "Globe"
	var gm := SphereMesh.new()
	gm.radius = 0.32
	gm.height = 0.64
	var glow := StandardMaterial3D.new()
	glow.albedo_color = LAMP_COLOR
	glow.emission_enabled = true
	glow.emission = LAMP_COLOR
	glow.emission_energy_multiplier = 1.6
	gm.material = glow
	globe.mesh = gm
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	globe.position = Vector3(0.0, POST_HEIGHT + 0.3, 0.0)
	post.add_child(globe)
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.38
	pm.height = 0.3
	pm.material = gold
	cap.mesh = pm
	cap.position = Vector3(0.0, POST_HEIGHT + 0.72, 0.0)
	post.add_child(cap)

	var light := OmniLight3D.new()
	light.name = "Lamp"
	light.position = Vector3(0.0, POST_HEIGHT + 0.3, 0.0)
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
	trim.global_position = _marquee_centre - _marquee_facing * MARQUEE_STANDOFF_LAYER

	var lines: Array[String] = marquee_lines()
	var headline_height: float = _marquee_size.y * MARQUEE_HEADLINE_FRACTION
	_marquee_label("MarqueeHeadline", lines[0], headline_height,
		_marquee_centre + Vector3(0.0, _marquee_size.y * 0.20, 0.0)
			+ _marquee_facing * (MARQUEE_STANDOFF_LAYER * 2.0))
	_marquee_label("MarqueeSponsor", lines[1],
		headline_height * MARQUEE_SPONSOR_SCALE,
		_marquee_centre + Vector3(0.0, -_marquee_size.y * 0.24, 0.0)
			+ _marquee_facing * (MARQUEE_STANDOFF_LAYER * 2.0))
	_marquee_arch()
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


func marquee_arch_segments() -> int:
	return MARQUEE_ARCH_SEGMENTS


## The highest point the arch's own BUILT geometry actually reaches, in world Y -- every
## segment's own centre plus its own rotated half-length and half-thickness, the same
## per-segment transforms _marquee_arch() hands the real nodes, not a bare identity over two
## constants. Set by _marquee_arch(); 0.0 before a marquee is mounted.
##
## EXPOSED RATHER THAN READ BACK OFF THE NODES THEMSELVES, for a test's sake rather than this
## file's own: a MultiMesh's instance transforms are RenderingServer state, and the headless
## dummy driver this project's own test runs are required to use never allocates that buffer
## -- get_instance_transform() reads back all zeroes there even immediately after
## set_instance_transform() wrote real numbers, confirmed against the same code under a real
## Vulkan context, where the readback is correct. _marquee_arch() below therefore builds plain
## MeshInstance3D children instead, whose own global_transform carries no such gap, so
## test_strip.gd can and does recompute this same number independently off the live nodes and
## check it against this accessor rather than trust it blindly.
func marquee_arch_peak_y() -> float:
	return _marquee_arch_peak_y


## THE GOLD ARCH THAT CROWNS THE BOARD, as a handful of straight MeshInstance3D segments
## whose own endpoints sit ON the board's true ellipse and whose own long axis is turned to
## that ellipse's own tangent -- not a circle's. Boxes rather than a torus for _slab()'s reason
## in building.gd: Godot's own winding is used rather than re-derived, and a hand wound curve
## that came out inside out would be an invisible hole rather than a visible mistake.
##
## PLAIN NODES, NOT ONE MULTIMESH. See marquee_arch_peak_y()'s own comment: a MultiMesh's
## instance data cannot be read back under this suite's headless runner, so the geometry a
## test can actually check has to live in ordinary node transforms instead. Twelve boxes is
## still one draw call each rather than one call for the whole rail, which this sign's own
## marquee -- a handful of segments, built once, never rebuilt at runtime -- does not need to
## economise against the way a whole ring of lamps or bulbs does.
##
## THE ELLIPSE, NOT THE CIRCLE, AND WHY THAT WAS THE ACTUAL BUG. The board this arch crowns is
## roughly fifteen times wider than the arch is tall (half width ~4.4 m against a ~0.3 m rise),
## so it is a very flat, wide ellipse, not a circle. The version that shipped first swept nine
## EQUAL-LENGTH boxes through equal steps of a CIRCULAR angle and rotated each by that same
## bare angle: a circle's tangent turns at a constant rate with angle, but this ellipse's own
## tangent barely turns at all except right at the crown, so segments away from the crown were
## rotated tens of degrees steeper than the surface they were meant to follow -- a reviewer
## measured the built result at ridge_y + 0.29 m to as much as ridge_y + 0.55 m depending on
## which segment is checked (see test_strip.gd's own test for the full derivation), read on
## screen as a sunburst of diverging struts rather than an arch. Each segment here instead
## takes its own two ENDPOINTS directly off the ellipse at the angles that bound it (so the
## chord never drifts from the curve, whatever its length), and its rotation off the ellipse's
## own derivative (half_x*sin(theta), amplitude*cos(theta)) at its midpoint -- the tangent an
## ellipse actually has, not a circle's stand-in for one.
##
## THE RISE BUDGET COVERS THE WHOLE BUILT SHAPE, NOT JUST THE CURVE'S OWN LINE THROUGH IT. A
## box drawn CENTRED on a curve sticks up past that curve by roughly half its own thickness
## even where the curve is dead flat, so building the ellipse at the full nominal
## MARQUEE_ARCH_RISE amplitude and only then measuring would already be over budget before any
## segment even tilts. This builds once at the nominal amplitude, measures the true overshoot
## analytically off the same per-segment transforms it would hand the nodes, and -- only if
## that overshoot is positive -- shrinks the amplitude by exactly that much and rebuilds once
## more. The residual left by treating that shrink as a flat offset (rather than re-solving
## the trig exactly) is second order in a quantity already under a decimetre, well inside the
## test's own 0.01 m tolerance against marquee_arch_peak_y().
func _marquee_arch() -> void:
	var root := Node3D.new()
	root.name = "MarqueeArch"
	add_child(root)

	var span: float = _marquee_size.x + MARQUEE_TRIM * 2.0
	var half_x: float = span * 0.5
	var right := Vector3(-_marquee_facing.z, 0.0, _marquee_facing.x)
	var up := Vector3(0.0, 1.0, 0.0)
	var base_y: float = _marquee_centre.y + _marquee_size.y * 0.5

	# THE CEILING SOLVED AGAINST IS RISE MINUS THE SAFETY MARGIN, not RISE itself: see
	# MARQUEE_ARCH_SAFETY_MARGIN's own comment for why saturating RISE saturates the roof's
	# own clearance line too, at these constants.
	var ceiling: float = MARQUEE_ARCH_RISE - MARQUEE_ARCH_SAFETY_MARGIN
	var amplitude: float = ceiling
	var segments: Array = _arch_segments(amplitude, half_x, right, up)
	var local_peak: float = _arch_local_peak(segments)
	var overshoot: float = local_peak - ceiling
	if overshoot > 0.0:
		amplitude = maxf(ceiling - overshoot, 0.05)
		segments = _arch_segments(amplitude, half_x, right, up)
		local_peak = _arch_local_peak(segments)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARQUEE_TRIM_COLOR
	mat.metallic = 0.45
	mat.roughness = 0.35

	for seg in segments:
		var box := BoxMesh.new()
		box.size = Vector3(seg["length"] as float, MARQUEE_ARCH_THICKNESS, MARQUEE_ARCH_THICKNESS)
		box.material = mat
		var mesh := MeshInstance3D.new()
		mesh.name = "ArchSegment%d" % (seg["index"] as int)
		mesh.mesh = box
		root.add_child(mesh)
		mesh.global_position = _marquee_centre + (seg["mid"] as Vector3) \
			+ Vector3(0.0, base_y - _marquee_centre.y, 0.0) \
			+ _marquee_facing * MARQUEE_STANDOFF_LAYER
		mesh.global_transform.basis = seg["basis"]

	_marquee_arch_peak_y = base_y + local_peak


## Per-segment placement data for _marquee_arch(), against the ellipse's own PARAMETER theta
## in [0, PI] (theta = 0 and PI its two ground level ends, PI/2 its crown) at the given
## amplitude -- the same numbers back both node placement and the peak measurement
## _marquee_arch() rescales against, so the two can never silently disagree.
func _arch_segments(amplitude: float, half_x: float, right: Vector3, up: Vector3) -> Array:
	var result: Array = []
	var step: float = PI / float(MARQUEE_ARCH_SEGMENTS)
	for i in MARQUEE_ARCH_SEGMENTS:
		var theta0: float = float(i) * step
		var theta1: float = float(i + 1) * step
		var theta_mid: float = (theta0 + theta1) * 0.5
		var p0: Vector3 = right * (-cos(theta0) * half_x) + up * (sin(theta0) * amplitude)
		var p1: Vector3 = right * (-cos(theta1) * half_x) + up * (sin(theta1) * amplitude)
		var mid: Vector3 = (p0 + p1) * 0.5
		# A hair over the true chord so neighbouring segments' end caps overlap rather than
		# leave a hairline gap at the joint; baked in here, once, so the box _marquee_arch()
		# builds and the half-length _arch_local_peak() measures are the same number rather
		# than two that could quietly drift apart.
		var length: float = (p1 - p0).length() * MARQUEE_ARCH_OVERLAP
		# THE ELLIPSE'S OWN TANGENT: d/dtheta of (-half_x*cos(theta), amplitude*sin(theta)),
		# not a circle's radius-normal. See _marquee_arch()'s own comment for why the two
		# differ enormously on a curve this flat.
		var tangent: Vector3 = right * (half_x * sin(theta_mid)) \
			+ up * (amplitude * cos(theta_mid))
		var x_axis: Vector3 = tangent.normalized()
		var y_axis: Vector3 = _marquee_facing.cross(x_axis).normalized()
		var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
		result.append({
			"index": i,
			"mid": mid,
			"length": length,
			"basis": Basis(x_axis, y_axis, z_axis),
		})
	return result


## The highest point, measured from the arch's own datum (the board's top edge, y = 0 in this
## local reckoning) that ANY segment's own half extents reach: half its length along its own
## tangent, plus half the box's own thickness along each of its other two axes, projected onto
## world Y -- the standard oriented-box-to-AABB formula, run on the exact same segment data
## _marquee_arch() hands the real nodes.
func _arch_local_peak(segments: Array) -> float:
	var half_thickness: float = MARQUEE_ARCH_THICKNESS * 0.5
	var peak: float = -INF
	for seg in segments:
		var basis: Basis = seg["basis"]
		var half_length: float = (seg["length"] as float) * 0.5
		var extent_y: float = absf(basis.x.y) * half_length \
			+ absf(basis.y.y) * half_thickness \
			+ absf(basis.z.y) * half_thickness
		peak = maxf(peak, (seg["mid"] as Vector3).y + extent_y)
	return peak


## Emissive spheres spaced round the arch and along the board's foot, built as one MultiMesh
## so the whole rail is one draw call. See _marquee_arch()'s own comment: this is the outline
## a marquee's bulb rail actually follows, not two straight rows across a slab.
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

	var right := Vector3(-_marquee_facing.z, 0.0, _marquee_facing.x)
	var half_span: float = _marquee_size.x * 0.5 + MARQUEE_TRIM * 0.5
	var base_y: float = _marquee_centre.y + _marquee_size.y * 0.5
	var lower_y: float = _marquee_centre.y - _marquee_size.y * 0.5 - MARQUEE_TRIM * 0.5
	for i in MARQUEE_BULBS:
		# The first half ride the arch; the second half run the board's own foot under them,
		# which is the outline a marquee's rail actually follows.
		var at: Vector3
		var half_count: int = MARQUEE_BULBS / 2
		if i < half_count:
			var t: float = (float(i) + 0.5) / float(half_count)
			var angle: float = PI * t
			at = _marquee_centre + right * (-cos(angle) * half_span) \
				+ Vector3(0.0, (base_y - _marquee_centre.y)
					+ sin(angle) * MARQUEE_ARCH_RISE, 0.0)
		else:
			var t: float = -1.0 + 2.0 * (float(i - half_count) / float(half_count - 1))
			at = _marquee_centre + right * (half_span * t) \
				+ Vector3(0.0, lower_y - _marquee_centre.y, 0.0)
		at += _marquee_facing * (MARQUEE_STANDOFF_LAYER * 1.6)
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
