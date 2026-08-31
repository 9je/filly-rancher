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
## NINE LAMPS ON A TEN POSITION RING. LIGHT_COUNT is the number of points build() walks, not
## the number of posts that end up standing: avoid_footprint() skips any position that lands
## inside the Palace's own footprint, and on this map exactly one does, so a built Strip
## reports light_count() of 9. See build() and avoid_footprint() for why the position is
## dropped rather than nudged.
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

## The marquee, in world space: just south of the Palace's door, at first floor height, facing
## the walk up from the homestead. Tied to Buildings/Palace's actual transform in ranch.tscn
## (its origin is (-10, 0, 61.6), see PALACE_MAX_RELIEF's comment in ranch.gd for why it is
## not at the Strip's own centre): x matches the Palace, z is 5.4 m south of its door.
const MARQUEE_AT := Vector3(-10.0, 5.4, 56.2)
const MARQUEE_SIZE := 0.55

const POST_COLOR := Color(0.24, 0.22, 0.28)
const LAMP_COLOR := Color(1.0, 0.86, 0.55)
const MARQUEE_COLOR := Color(1.0, 0.92, 0.62)
const LAMP_ENERGY := 2.2
const LAMP_RANGE := 16.0

var _region: RegionData = null
var _ground := Callable()
var _lights: Array[Node3D] = []
var _built := false

## The rectangle, in world XZ, no lamp may stand inside. Empty (min == max == ZERO with
## _has_avoid false) until avoid_footprint() is called; nothing is skipped in that case.
var _avoid_min := Vector2.ZERO
var _avoid_max := Vector2.ZERO
var _has_avoid := false


## Hand over the region this strip paves and a way to ask the terrain how high it is. Both
## before build(), the same contract RegionFence.configure() has.
func configure(region: RegionData, ground_sampler: Callable) -> void:
	_region = region
	_ground = ground_sampler


## A footprint, in world XZ, that no lamp may stand inside or against: `centre_xz` and
## `half_extents` (half-width, half-depth) of whatever is standing on the Strip's own
## ground; today, only Buildings/Palace. PALACE_CLEARANCE is added past those edges on
## every side. Call before build(), same as configure(); a no-op call is safe (nothing is
## skipped) so a caller with nothing to avoid can simply not call it.
##
## Not folded into configure() itself: RegionFence's contract, the one configure()
## deliberately matches, has no such thing to hand over, and every other region's fence
## never needs one. Kept as world-space XZ rather than a Building reference so this file
## does not have to know what a Building is; ranch.gd reads the Palace's own global_position
## and width/depth and hands over the rectangle, not the node.
func avoid_footprint(centre_xz: Vector2, half_extents: Vector2) -> void:
	var pad: Vector2 = half_extents + Vector2(PALACE_CLEARANCE, PALACE_CLEARANCE)
	_avoid_min = centre_xz - pad
	_avoid_max = centre_xz + pad
	_has_avoid = true


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
		if _has_avoid and x >= _avoid_min.x and x <= _avoid_max.x \
				and z >= _avoid_min.y and z <= _avoid_max.y:
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


func marquee_text() -> String:
	return CasinoSignScript.MARQUEE


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


## The sign you read on the way in. A Label3D rather than a texture so the words come from
## CasinoSign and cannot drift from the building they are advertising.
func _marquee() -> void:
	var label := Label3D.new()
	label.name = "Marquee"
	label.text = CasinoSignScript.MARQUEE
	label.font_size = 64
	label.pixel_size = MARQUEE_SIZE / 64.0
	label.modulate = MARQUEE_COLOR
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.no_depth_test = false
	add_child(label)
	label.global_position = MARQUEE_AT
	# Label3D faces +Z; the walk up from the homestead comes from Z below zero, so it turns
	# a half turn to meet the player coming north.
	label.rotation.y = PI
