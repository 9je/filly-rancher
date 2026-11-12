class_name RegionDressing
extends Node3D
## THE REGIONS, DRESSED (MISSION.md: "never ship primitive environments"; the visual review
## of 2026-10-23 found each region was a fenced disc of tinted grass with a few ponies in
## it). Each region gets the scenery its name promises, scattered from a fixed seed so every
## machine and every save sees the same valley:
##
##   The Everfree Edge   a dark wood: tall pines and dark oaks thick round the rim, a few in
##                       the clearing, toadstools, fallen logs, stumps, mossy rocks
##   The Night Meadow    a moonflower field (the purple ones glow a little), long grass, a
##                       ring of standing stones in the middle
##   The Lake            lily pads on the water, reeds and flat stones round the shore, a
##                       canoe pulled up on the bank, a jetty of planks
##   The Orchard         rows of apple trees with lanes between, baskets, crates, hay
##
## Kenney's Nature Kit (CC0, game/assets/models/nature/) plus the project's own converted
## Sweet Apple Acres props, all restyled through ToonStyler with the leaves recoloured from
## Kenney's teal to the show's greens. Small things go in MultiMeshes (one draw per kind, not
## one per flower); trunks and big stones get a collider so nopony walks through them.

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const PropsScript := preload("res://world/props.gd")
const NATURE := "res://assets/models/nature/"

## SIZES ARE IN PONY HEIGHTS NOW, NOT IN SCALE FACTORS (SCALE.md, docs/playtest_fixes/scale.md).
## Every tree and standing stone used to be drawn at a random multiple of its OWN model's size,
## and the Nature Kit's models are not one size: a pineTallB at 6.2x stood 5.4 pony heights and
## a fat oak at 4.2x stood 1.9, in the same wood. A tree is now asked for by the height it
## should stand (a random draw inside its row's range, in PH) and scaled to that off its own
## measured height, so every tree on the map lands inside SCALE.md's tree row whatever model
## it is. Kept as Vector2(min, max) per planting so each region still has its own character.
const PH: float = PropsScript.PONY_HEIGHT
const EVERFREE_RIM_PH := Vector2(2.6, 3.6)
const EVERFREE_OUTER_PH := Vector2(2.8, 3.9)
const EVERFREE_INNER_PH := Vector2(2.3, 3.1)
const MEADOW_TREE_PH := Vector2(2.4, 3.3)
const LAKE_TREE_PH := Vector2(2.3, 3.0)
## The Night Meadow's ring: a little over a pony, every stone, whichever of the five it is.
const STANDING_STONE_PH := Vector2(1.05, 1.35)

## Leaf and grass greens, by how dark the source material was meant to be.
const GREEN := Color(0.42, 0.66, 0.3)
const GREEN_DARK := Color(0.2, 0.36, 0.2)
const GREEN_EVERFREE := Color(0.16, 0.3, 0.2)
## NO LEAF TINT AT ALL, and every placing function's default. Color() is opaque BLACK, and _parts()
## tints a part whenever the colour's alpha is above zero, so a prop placed without a green had
## every "leaf" or "grass" material painted black: the lake's canoe (its hull is Kenney's
## leafsFall) and the mossy tops of its shore stones were the black wedges by the water
## (playtest 2026-11-05 item 61, the PS batch check).
const NO_TINT := Color(0, 0, 0, 0)
const WOOD := Color(0.4, 0.27, 0.18)
## THE LAKE'S EDGE, REDONE (P8 S7, playtest 2026-11-08 item 55: "reeds and grass by the lake are
## sharp shards; dock planks are flat dark slabs"; docs/aaa-review-2026-11-08.md 2.14: "reeds as
## crossed cards with a painted texture, a dock with real planks"). The shore's reeds were the
## Nature Kit's flat plants blown up three to four and a half times, which made every facet a
## blade-sized shard; they are now clumps of painted reeds on two crossed cards (REED_CARD, its
## texture drawn here). The jetty was five 2 m tiles laid end on end in the kit's dark dirt
## colour; it is now planks laid across the jetty with a finger's gap between them, in weathered
## timber, on pilings, and it is one walkable deck to the player instead of five posts.
const REED_CARD := "reed_card"
const REED_HEIGHT := Vector2(1.0, 1.55)
const DOCK_WOOD := Color(0.68, 0.53, 0.37)
const DOCK_PLANK_PITCH := 0.34
const DOCK_LENGTH := 6.4
const DOCK_WIDTH := 1.9
const STONE := Color(0.55, 0.57, 0.62)

var height_at: Callable = func(_x: float, _z: float) -> float: return 0.0
## A lake's water height, by region id (the ranch knows it from Terrain.build_water).
var water_y: Dictionary = {}

var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## dress_paced()'s dry run: true while the placements only write down what they would load.
var _dry := false
var _wanted: Dictionary = {}


## Dress every region in `regions` (RegionData).
func dress(regions: Array) -> void:
	# The same body as dress_paced(), with no pace: it never awaits, so it runs to the end
	# inside this call. call() by name because the parser insists a function that CAN await
	# is always awaited, and every existing caller of dress() is synchronous.
	call(&"dress_paced", regions, Callable())


## dress(), handing a frame back between the pieces of work: `await pace.call(done, total)`
## after each region and each batch (the ranch's boot behind the loading screen,
## docs/playtest_fixes/loading.md). An invalid pace is dress() exactly.
func dress_paced(regions: Array, pace: Callable) -> void:
	# PACED, THE MODELS ARE WARMED FIRST, one per step. A region's first use of a model is
	# the expensive part (load, instance, copy and restyle its meshes; a second or more for a
	# whole region), and it happens deep inside one placement, so a dry run of the same
	# placements (_dry: nothing is placed, only what they would need is written down, and the
	# seed is set again for the real run, so the valley is the one dress() builds) lists the
	# models, and each is warmed in a step of its own.
	var warm: Array = []
	if pace.is_valid():
		_dry = true
		for r: RegionData in regions:
			_dress_region(r)
		_dry = false
		warm = _wanted.values()
		_wanted.clear()
	var keys_hint := 24
	var total := warm.size() + regions.size() + keys_hint
	var done := 0
	for w: Array in warm:
		if String(w[0]).begins_with("res://"):
			_scene_parts(w[0])
		else:
			_parts(w[0], w[1], w[2])
		done += 1
		await pace.call(done, total)
	for r: RegionData in regions:
		_dress_region(r)
		done += 1
		if pace.is_valid():
			await pace.call(done, total)
	var keys: Array = _batches.keys()
	for i in keys.size():
		_flush_one(keys[i])
		if pace.is_valid():
			await pace.call(done + int(float(keys_hint) * float(i + 1) / float(keys.size())), total)
	_batches.clear()


func _dress_region(r: RegionData) -> void:
	_rng.seed = hash(String(r.id)) * 7 + 11
	match r.id:
		&"everfree":
			_everfree(r)
		&"nightmeadow":
			_night_meadow(r)
		&"lake":
			_lake(r)
		&"orchard":
			_orchard(r)


# --- the regions ----------------------------------------------------------------------

func _everfree(r: RegionData) -> void:
	var trees := ["tree_pineTallA_detailed", "tree_pineTallB_detailed", "tree_pineTallC_detailed",
		"tree_oak_dark", "tree_default_dark", "tree_fat_darkh", "tree_thin_dark", "tree_pineRoundC"]
	# Thick round the rim (the wood the clearing is cut out of), thinner inside.
	for i in 54:
		var a := TAU * float(i) / 54.0 + _rng.randf_range(-0.05, 0.05)
		var d := r.radius * _rng.randf_range(0.78, 1.3)
		_tree(r, trees[_rng.randi() % trees.size()], a, d, _ph(EVERFREE_RIM_PH), GREEN_EVERFREE)
	for i in 40:
		var a2 := TAU * float(i) / 40.0 + 0.07
		_tree(r, trees[_rng.randi() % trees.size()], a2, r.radius * _rng.randf_range(1.3, 1.7), _ph(EVERFREE_OUTER_PH), GREEN_EVERFREE)
	for i in 14:
		_tree(r, trees[_rng.randi() % trees.size()], _rng.randf() * TAU, r.radius * _rng.randf_range(0.3, 0.72),
			_ph(EVERFREE_INNER_PH), GREEN_EVERFREE)
	_scatter(r, ["mushroom_redGroup", "mushroom_tanGroup", "mushroom_red", "mushroom_redTall"], 34, 0.1, 0.95, Vector2(2.6, 4.0))
	_scatter(r, ["log", "log_large", "stump_old", "stump_oldTall"], 12, 0.25, 0.9, Vector2(2.6, 3.6), true)
	_scatter(r, ["rock_largeA", "rock_largeC", "rock_tallB"], 8, 0.3, 0.95, Vector2(2.2, 3.4), true)
	_scatter(r, ["plant_bushLarge", "plant_bushDetailed", "grass_large"], 50, 0.2, 1.05, Vector2(2.6, 4.2), false, GREEN_EVERFREE)


func _night_meadow(r: RegionData) -> void:
	_scatter(r, ["flower_purpleA", "flower_purpleB", "flower_purpleC"], 150, 0.05, 0.98, Vector2(2.8, 4.2), false, GREEN_DARK, true)
	_scatter(r, ["flower_yellowA", "flower_yellowB", "flower_redA"], 60, 0.05, 0.98, Vector2(2.6, 3.8), false, GREEN_DARK)
	_scatter(r, ["grass", "grass_leafs", "grass_large"], 110, 0.0, 1.0, Vector2(2.8, 4.6), false, GREEN_DARK)
	# The standing stones, in a ring round the middle of the meadow.
	var stones := ["stone_tallA", "stone_tallB", "stone_tallC", "stone_tallD", "stone_tallE"]
	for i in 9:
		var a := TAU * float(i) / 9.0
		_place(r, stones[i % stones.size()], a, 5.5, STANDING_STONE_PH * PH, true, NO_TINT, false, true, true)
	for i in 22:
		_tree(r, ["tree_pineRoundC", "tree_pineTallB_detailed"][_rng.randi() % 2], _rng.randf() * TAU, r.radius * _rng.randf_range(0.95, 1.4), _ph(MEADOW_TREE_PH), GREEN_DARK)


func _lake(r: RegionData) -> void:
	var wy: float = water_y.get(r.id, height_at.call(r.centre.x, r.centre.y))
	var water_r := r.radius * 0.7
	# Lily pads ON the water, so they sit at its height rather than on the basin floor.
	for i in 26:
		var a := _rng.randf() * TAU
		var d := water_r * sqrt(_rng.randf_range(0.05, 0.85))
		var at := Vector3(r.centre.x + cos(a) * d, wy + 0.03, r.centre.y + sin(a) * d)
		_add(["lily_large", "lily_small"][_rng.randi() % 2], Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.8, 2.8)), at), false, GREEN)
	# Reeds and flat stones along the shore. The reeds are card clumps (REED_CARD), drawn with
	# the same five draws per clump the kit's plants took, so everything after them on this
	# seed still stands where it stood.
	for i in 70:
		var a := _rng.randf() * TAU
		var d := water_r * _rng.randf_range(0.92, 1.12)
		var pick := _rng.randi() % 3
		var h := lerpf(REED_HEIGHT.x, REED_HEIGHT.y, inverse_lerp(3.0, 4.6, _rng.randf_range(3.0, 4.6)))
		var yaw := _rng.randf() * TAU
		var rx := r.centre.x + cos(a) * d
		var rz := r.centre.y + sin(a) * d
		var ry := maxf(float(height_at.call(rx, rz)), wy - 0.25)
		# The short kind is a little squatter and wider: a clump, not a copy.
		var squat := 1.25 if pick == 1 else 1.0
		_add(REED_CARD, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(h * 0.75 * squat, h / squat, h * 0.75 * squat)),
			Vector3(rx, ry - 0.04, rz)), false)
	for i in 18:
		_place(r, ["rock_smallFlatA", "rock_smallFlatB", "rock_smallA"][_rng.randi() % 3], _rng.randf() * TAU,
			water_r * _rng.randf_range(0.95, 1.25), Vector2(1.4, 2.2), false, GREEN)
	# A canoe on the bank, and a short jetty of planks out over the water.
	var jetty_a := 0.6
	# The canoe's collider is its hull, low and long, not a 2.4 m post in its middle that
	# stopped the player a stride short of a boat (item 26).
	var canoe := _place(r, "canoe", jetty_a + 0.35, water_r * 1.08, Vector2(3.2, 3.2), false, NO_TINT)
	if not _dry:
		var cs := canoe.basis.get_scale().x
		_box_collider(Transform3D(Basis(Vector3.UP, canoe.basis.orthonormalized().get_euler().y), canoe.origin
			+ Vector3(0.0, 0.3, 0.0)), Vector3(0.3 * cs, 0.6, 1.15 * cs))
	_jetty(r, wy, water_r, jetty_a)
	for i in 8:
		_tree(r, ["tree_default_dark", "tree_oak_dark", "tree_fat_darkh"][_rng.randi() % 3], _rng.randf() * TAU,
			r.radius * _rng.randf_range(1.0, 1.3), _ph(LAKE_TREE_PH), GREEN)


## The jetty: planks across it from a pace up the bank out over the water, on pilings, with
## one flat deck collider at the planks' top so she walks out on it and nothing snags.
func _jetty(r: RegionData, wy: float, water_r: float, jetty_a: float) -> void:
	var out := Vector2(cos(jetty_a), sin(jetty_a))
	var start := water_r * 1.04 + 0.8
	var deck_y := wy + 0.28
	var n := int(DOCK_LENGTH / DOCK_PLANK_PITCH)
	for k in n:
		var d := start - (float(k) + 0.5) * DOCK_PLANK_PITCH
		var p := r.centre + out * d
		var y := maxf(deck_y, float(height_at.call(p.x, p.y)) + 0.06)
		# path_wood is 1 m by 0.51 m: across the jetty, a plank's width along it.
		var plank := Basis(Vector3.UP, -jetty_a + PI * 0.5).scaled(Vector3(DOCK_WIDTH, 1.8, 0.58))
		_add("path_wood", Transform3D(plank, Vector3(p.x, y - 0.09, p.y)), false)
	# Pilings at the corners and the middle, from the bed up through the deck.
	var side := Vector2(-out.y, out.x) * (DOCK_WIDTH * 0.5 + 0.06)
	for f: float in [0.15, 0.55, 0.95]:
		for s: float in [-1.0, 1.0]:
			var q := r.centre + out * (start - DOCK_LENGTH * f) + side * s
			var bed := float(height_at.call(q.x, q.y))
			var tall := deck_y + 0.18 - bed
			if tall <= 0.05:
				continue
			_add("stump_round", Transform3D(Basis().scaled(Vector3(0.62, tall / 0.206, 0.62)),
				Vector3(q.x, bed - 0.02, q.y)), false)
	if _dry:
		return
	var mid := r.centre + out * (start - DOCK_LENGTH * 0.5)
	_box_collider(Transform3D(Basis(Vector3.UP, -jetty_a + PI * 0.5), Vector3(mid.x, deck_y - 0.2, mid.y)),
		Vector3(DOCK_WIDTH, 0.4, DOCK_LENGTH))


## A solid box at `xf` (its origin the box's middle), on the props layer.
func _box_collider(xf: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	body.set_meta(&"step_surface", &"hoof_wood")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_transform = xf


## Two crossed cards with a clump of painted reeds on them (REED_CARD): 1 m tall and 1 m wide
## at scale 1, standing on their foot. The texture is drawn here: tapered blades in two greens,
## darker at the root, and a few bulrush heads.
static func _reed_card_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ang := PI * 0.25 + PI * 0.5 * k
		var dx := Vector3(cos(ang), 0.0, sin(ang)) * 0.5
		var q: Array[Vector3] = [-dx, dx, dx + Vector3.UP, -dx + Vector3.UP]
		var uv: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var n := dx.cross(Vector3.UP).normalized()
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uv[i])
			st.add_vertex(q[i])
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _reed_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh.surface_set_material(0, mat)
	return mesh


static func _reed_texture() -> ImageTexture:
	const W := 96
	const H := 160
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.45, 0.25, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1171
	var light := Color(0.47, 0.66, 0.31)
	var dark := Color(0.24, 0.40, 0.2)
	for b in 15:
		var x0 := rng.randf_range(W * 0.25, W * 0.75)
		var lean := rng.randf_range(-0.35, 0.35) * W
		var top := rng.randf_range(0.05, 0.4) * H
		var w0 := rng.randf_range(2.2, 3.6)
		var col := light.lerp(dark, rng.randf())
		for y in range(int(top), H):
			var t := (float(y) - top) / (H - top)
			var x := x0 + lean * pow(1.0 - t, 2.0)
			var w := w0 * (0.15 + 0.85 * t)
			var c := col.darkened(0.35 * t)
			for xi in range(int(x - w), int(x + w) + 1):
				if xi >= 0 and xi < W:
					img.set_pixel(xi, y, Color(c, 1.0))
	# Bulrush heads on three straight stalks.
	for h in 3:
		var sx := int(rng.randf_range(W * 0.3, W * 0.7))
		var hy := int(rng.randf_range(0.04, 0.18) * H)
		for y in range(hy, H):
			for xi in [sx, sx + 1]:
				img.set_pixel(xi, y, Color(0.36, 0.5, 0.26, 1.0))
		for y in range(hy + 4, hy + 22):
			for xi in range(sx - 2, sx + 4):
				img.set_pixel(xi, y, Color(0.42, 0.27, 0.16, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _orchard(r: RegionData) -> void:
	var tree := "res://assets/converted/props/mlp_apple_tree.glb"
	if not ResourceLoader.exists(tree):
		return
	# Rows across the orchard, a lane down the middle for the ponies.
	for row in range(-2, 3):
		for col in range(-3, 4):
			if col == 0:
				continue
			var x := r.centre.x + float(col) * 5.2 + _rng.randf_range(-0.4, 0.4)
			var z := r.centre.y + float(row) * 6.0 + _rng.randf_range(-0.4, 0.4)
			if Vector2(x - r.centre.x, z - r.centre.y).length() > r.radius * 0.86:
				continue
			_scene(tree, Vector3(x, float(height_at.call(x, z)), z), _rng.randf() * TAU,
				_mlp_scale(tree), true)
	for p in ["res://assets/converted/props/mlp_basket.glb", "res://assets/converted/props/mlp_crate.glb",
			"res://assets/converted/props/saa_hay_pile.glb"]:
		if not ResourceLoader.exists(p):
			continue
		for i in 3:
			var a := _rng.randf() * TAU
			var d := r.radius * _rng.randf_range(0.25, 0.8)
			var x := r.centre.x + cos(a) * d
			var z := r.centre.y + sin(a) * d
			_scene(p, Vector3(x, float(height_at.call(x, z)), z), _rng.randf() * TAU, _mlp_scale(p), false)


# --- placing ---------------------------------------------------------------------------

## A height in metres, drawn inside a range given in pony heights. One RNG draw, the same
## count the old scale draw made, so every tree still stands where it always stood.
func _ph(range_ph: Vector2) -> float:
	return _rng.randf_range(range_ph.x, range_ph.y) * PH


## THE ORCHARD'S CONVERTED PROPS AT THE SCALE THE REST OF THE MAP STANDS THEM AT. They were
## placed at 1.0, the model's raw converted size, while props.gd stands the very same files at
## MLP_SCALE times SCALE_FIX: the orchard's apple trees came out at 1.5 PH beside 2.6 PH apple
## trees on the walk up to it, and its baskets at 7 cm.
func _mlp_scale(path: String) -> float:
	return PropsScript.scale_for({"file": path.get_file(), "family": PropsScript.FAMILY_MLP})


## ONE TREE FAMILY (P9 item 59; the owner: "low-poly blocks, soft show-style trees with purple
## trunks, lollipop trees: pick one"). The regions asked for the Kenney kit's faceted oaks and
## pines while the valley round the ranch stands the show-style Sweet Apple Acres trees (props.gd).
## Each kit name now maps to the SAA tree of the same build (a pine or thin tree to the narrow
## one, a round oak to the wide one; the Everfree's thin and fat dark trees to the dead pair,
## its spooky note), placed with the SAME random draws so nothing else on the seed moves.
const SAA_TREE := {
	"tree_pineTallA_detailed": "saa_tree_narrow", "tree_pineTallB_detailed": "saa_tree_narrow",
	"tree_pineTallC_detailed": "saa_tree_narrow", "tree_pineRoundC": "saa_tree_narrow",
	"tree_oak_dark": "saa_tree_wide", "tree_default_dark": "saa_tree_wide",
	"tree_fat_darkh": "saa_tree_dead_wide", "tree_thin_dark": "saa_tree_dead_narrow",
}
const SAA_DIR := "res://assets/converted/props/"
## In the Lake's and the Night Meadow's woods a "dead" kit name stays a living tree.
const SAA_LIVING := {"saa_tree_dead_wide": "saa_tree_wide", "saa_tree_dead_narrow": "saa_tree_narrow"}


## THE EVERFREE'S RIM TOWARD TOWN IS LIVING (review 2026-11-11: its dead trees stood among
## the green ones behind the pens). The gloom starts as you walk in, not at the town's edge.
func _faces_town(r: RegionData, a: float, d: float) -> bool:
	var to_town := (Vector2.ZERO - r.centre).normalized()
	return d > r.radius * 0.5 and Vector2(cos(a), sin(a)).dot(to_town) > 0.35


## A tree `h` metres tall, whichever model it is.
func _tree(r: RegionData, model: String, a: float, d: float, h: float, leaves: Color) -> void:
	var saa: String = SAA_TREE.get(model, "")
	if saa != "" and (r.id != &"everfree" or _faces_town(r, a, d)):
		saa = SAA_LIVING.get(saa, saa)
	var path := SAA_DIR + saa + ".glb"
	if saa == "" or not ResourceLoader.exists(path):
		_place(r, model, a, d, Vector2(h, h), true, leaves, false, false, true)
		return
	# The same two draws _place() makes (its scale, then its yaw), in the same order.
	_rng.randf_range(h, h)
	var yaw := _rng.randf() * TAU
	var x := r.centre.x + cos(a) * d
	var z := r.centre.y + sin(a) * d
	var at := Vector3(x, float(height_at.call(x, z)) - 0.03, z)
	if _dry:
		_wanted[path] = [path]
		return
	var box := _tree_box(path)
	var s := h / box.size.y if box.size.y > 0.01 else 1.0
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	placements.append({"model": saa, "at": at})
	for part: Array in _tree_parts(path):
		var key := path + "|" + str(part[2])
		if not _batches.has(key):
			_batches[key] = {"mesh": part[0], "xf": [], "shadow": bool(part[3])}
		(_batches[key].xf as Array).append(xf * (part[1] as Transform3D))
	# The trunk stops her and the ponies; the crown stops only the camera (item 60: the lens
	# sank into the Everfree's leaves and the screen went dark green with bright seams).
	_collider(Transform3D(Basis().scaled(Vector3.ONE * 1.6 * s), at))
	var crown := _tree_crown(path)
	if crown.size.y > 0.01:
		var body := StaticBody3D.new()
		body.collision_layer = LayersScript.CANOPY
		body.collision_mask = 0
		body.set_meta(&"canopy", true)
		var shape := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.5 * minf(crown.size.x, crown.size.z) * s
		shape.shape = ball
		body.add_child(shape)
		add_child(body)
		body.global_transform = Transform3D(Basis(), xf * crown.get_center())


## A show-style tree's meshes with its canopy swelled over its branches (props.gd's own look):
## [[mesh, local transform, index, casts a shadow, is the canopy], ...].
func _tree_parts(path: String) -> Array:
	var key := "tree|" + path
	if _meshes.has(key):
		return _meshes[key]
	var out: Array = []
	var node: Node3D = (load(path) as PackedScene).instantiate()
	PropsScript._swell_canopy(node)
	var i := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var mesh := mi.mesh.duplicate() as Mesh
		for sidx in mesh.get_surface_count():
			var src := mi.get_active_material(sidx)
			if src is StandardMaterial3D and ToonStylerScript.shading_enabled:
				mesh.surface_set_material(sidx, ToonStylerScript.to_toon(src as StandardMaterial3D,
					ToonStylerScript.PRESETS[&"foliage"]))
			elif src != null:
				mesh.surface_set_material(sidx, src)
		out.append([mesh, _relative(node, mi), i,
			mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, mi.name == &"Canopy"])
		i += 1
	node.free()
	_meshes[key] = out
	return out


func _tree_box(path: String) -> AABB:
	var box := AABB()
	var first := true
	for part: Array in _tree_parts(path):
		var b: AABB = (part[1] as Transform3D) * (part[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The leaves' box (the swelled canopy), or none for a bare tree.
func _tree_crown(path: String) -> AABB:
	for part: Array in _tree_parts(path):
		if bool(part[4]):
			return (part[1] as Transform3D) * (part[0] as Mesh).get_aabb()
	return AABB()


func _scatter(r: RegionData, models: Array, n: int, inner: float, outer: float, scale: Vector2,
		solid: bool = false, leaves: Color = NO_TINT, glow: bool = false) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var d := r.radius * sqrt(_rng.randf_range(inner * inner, outer * outer))
		_place(r, models[_rng.randi() % models.size()], a, d, scale, solid, leaves, glow)


## `scale` is a range of scale factors, or with `by_height` a range of HEIGHTS in metres that
## the model is scaled to off its own measured height (see the PH constants above).
func _place(r: RegionData, model: String, a: float, d: float, scale: Vector2, solid: bool = false,
		leaves: Color = NO_TINT, glow: bool = false, face_centre: bool = false,
		by_height: bool = false) -> Transform3D:
	var x := r.centre.x + cos(a) * d
	var z := r.centre.y + sin(a) * d
	var y := float(height_at.call(x, z))
	var s := _rng.randf_range(scale.x, scale.y)
	if by_height:
		var native := _native_height(model, leaves, glow)
		s = s / native if native > 0.001 else 1.0
	var yaw := -a + PI * 0.5 if face_centre else _rng.randf() * TAU
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, y - 0.03, z))
	_add(model, xf, solid, leaves, glow)
	return xf


func _add(model: String, xf: Transform3D, solid: bool, leaves: Color = NO_TINT, glow: bool = false) -> void:
	if _dry:
		_wanted["%s|%s|%s" % [model, str(leaves), str(glow)]] = [model, leaves, glow]
		return
	var parts: Array = _parts(model, leaves, glow)
	for part: Array in parts:
		var key := "%s|%s|%s" % [model, str(leaves), str(glow)] + "|" + str(part[2])
		if not _batches.has(key):
			_batches[key] = {"mesh": part[0], "xf": [], "shadow": solid}
		(_batches[key].xf as Array).append(xf * (part[1] as Transform3D))
	if solid:
		_collider(xf)


## A model's own height at scale 1, off the same parts it is drawn from.
func _native_height(model: String, leaves: Color, glow: bool) -> float:
	# dress_paced()'s dry run loads nothing (the size is not needed to list the model).
	if _dry:
		return 1.0
	var lo := INF
	var hi := -INF
	for part: Array in _parts(model, leaves, glow):
		var box: AABB = (part[1] as Transform3D) * (part[0] as Mesh).get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	return hi - lo if hi > lo else 0.0


## A model's meshes, toon-restyled once: [[mesh, local transform, index], ...].
func _parts(model: String, leaves: Color, glow: bool) -> Array:
	var key := "%s|%s|%s" % [model, str(leaves), str(glow)]
	if _meshes.has(key):
		return _meshes[key]
	var out: Array = []
	if model == REED_CARD:
		out.append([_reed_card_mesh(), Transform3D.IDENTITY, 0])
		_meshes[key] = out
		return out
	var path := NATURE + model + ".glb"
	if not ResourceLoader.exists(path):
		_meshes[key] = out
		return out
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var i := 0
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var mesh := mi.mesh.duplicate() as Mesh
		for sidx in mesh.get_surface_count():
			var src := mesh.surface_get_material(sidx) as StandardMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as StandardMaterial3D
			var lname := String(src.resource_name).to_lower()
			if leaves.a > 0.0 and ("leaf" in lname or "grass" in lname or "green" in lname or "plant" in lname):
				mat.albedo_color = leaves.lerp(leaves * src.albedo_color.v * 1.4, 0.25)
			# Kenney's bark and stone are pale enough to read pink under the toon light: the
			# show's trunks are a warm brown, its rocks a cool grey.
			if "inner" in lname:
				mat.albedo_color = Color(0.8, 0.66, 0.48)
			elif model == "path_wood":
				# Weathered planks, a board or two a shade darker (the kit's dirtDark).
				mat.albedo_color = DOCK_WOOD * (0.82 if "dark" in lname else 1.0)
			elif "wood" in lname or "bark" in lname or "trunk" in lname or "log" in lname or "dirt" in lname:
				mat.albedo_color = WOOD.lerp(WOOD * 1.25, clampf(src.albedo_color.v - 0.5, 0.0, 1.0))
			elif "stone" in lname or "rock" in lname:
				mat.albedo_color = STONE * lerpf(0.85, 1.05, src.albedo_color.v)
			if glow and ("flower" in lname or "purple" in lname or "petal" in lname):
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 0.6
			mesh.surface_set_material(sidx, ToonStylerScript.to_toon(mat, ToonStylerScript.PRESETS[&"foliage"])
				if ToonStylerScript.shading_enabled else mat)
		out.append([mesh, _relative(inst, mi), i])
		i += 1
	inst.free()
	_meshes[key] = out
	return out


func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _collider(xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.16 * xf.basis.get_scale().x
	cyl.height = 2.4
	shape.shape = cyl
	shape.position = Vector3(0, 1.2, 0)
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(Basis(), xf.origin)


## A whole converted scene (the Sweet Apple Acres props), styled the way props.gd styles them,
## and BATCHED like the kit's pieces: an orchard of whole scenes was 500 separate shadow
## casters, a third of every frame's draws (scenes/test/perf.gd exp=casters).
func _scene(path: String, at: Vector3, yaw: float, s: float, solid: bool) -> void:
	if _dry:
		_wanted[path] = [path]
		return
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	placements.append({"model": path.get_file().get_basename(), "at": at})
	for part: Array in _scene_parts(path):
		var key := path + "|" + str(part[2])
		if not _batches.has(key):
			_batches[key] = {"mesh": part[0], "xf": [], "shadow": true}
		(_batches[key].xf as Array).append(xf * (part[1] as Transform3D))
	if solid:
		_collider(Transform3D(Basis().scaled(Vector3.ONE * 1.6 * s), at))
	else:
		# ANYTHING TALLER THAN A KNEE IS A THING (PT2; playtest 2026-11-05: a pony spawned inside
		# a haystack). A non-tree scene stands a collider the size of its own footprint, so the
		# spawner's prop check, the hooves and the player all meet it.
		var box := _scene_box(path)
		if box.size.y * s > KNEE_HEIGHT:
			_bulk_collider(at, Vector2(box.size.x, box.size.z) * s, box.size.y * s)


## Every whole scene this dressing stood: {model, at}. For the tests that walk the valley.
var placements: Array = []

## Taller than this (metres) and a region's prop scene is solid.
const KNEE_HEIGHT := 0.45


## A converted scene's bounds at scale 1, off the parts it is drawn from.
func _scene_box(path: String) -> AABB:
	var box := AABB()
	var first := true
	for part: Array in _scene_parts(path):
		var b: AABB = (part[1] as Transform3D) * (part[0] as Mesh).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## An upright cylinder over a prop's footprint: radius from its narrower side (a round hay
## pile, a square crate), so a pony can stand close beside one without hitting air.
func _bulk_collider(at: Vector3, size: Vector2, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(0.2, minf(size.x, size.y) * 0.45)
	cyl.height = maxf(0.5, height)
	shape.shape = cyl
	shape.position = Vector3(0, cyl.height * 0.5, 0)
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(Basis(), at)


## A converted scene's meshes with ToonStyler's foliage look baked into them, once per path.
func _scene_parts(path: String) -> Array:
	if _meshes.has(path):
		return _meshes[path]
	var out: Array = []
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var i := 0
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var mesh := mi.mesh.duplicate() as Mesh
		for sidx in mesh.get_surface_count():
			var src := mi.get_active_material(sidx)
			if src is StandardMaterial3D and ToonStylerScript.shading_enabled:
				mesh.surface_set_material(sidx, ToonStylerScript.to_toon(src as StandardMaterial3D,
					ToonStylerScript.PRESETS[&"foliage"]))
			elif src != null:
				mesh.surface_set_material(sidx, src)
		out.append([mesh, _relative(inst, mi), i])
		i += 1
	inst.free()
	_meshes[path] = out
	return out


## One MultiMeshInstance3D per (model, mesh): a field of flowers is one draw, not a hundred.
func _flush_one(key: String) -> void:
	var b: Dictionary = _batches[key]
	var xfs: Array = b.xf
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = b.mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Dress_" + key.get_slice("|", 0)
	# What this batch IS, for anyone measuring the valley (test_input/test_scale.gd): the
	# model it draws, and the batch group its sibling parts share (every part of one model
	# holds the same instances in the same order, so instance i of each is one placement).
	mmi.set_meta(&"dress_model", key.get_slice("|", 0).get_file().get_basename())
	mmi.set_meta(&"dress_group", key.substr(0, key.rfind("|")))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(b.shadow) \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not bool(b.shadow):
		mmi.visibility_range_end = 110.0
	add_child(mmi)
