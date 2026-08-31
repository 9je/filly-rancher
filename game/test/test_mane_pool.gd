extends GutTest
## THE CURATED DONOR POOL, checked one model at a time against everything the base model
## already promises. The owner, 2026-08-31: every pony has the same mane, because all three
## hidden stock records and the player all point at pokeypierce.glb.
##
## THIS FILE IS THE GATE ON THE POOL. There are no spare models on disk (all 43 converted
## .glb are some named character's), so a donor is always a rig somebody else also wears,
## and the only thing that makes one safe to draw at random is that it tints, animates and
## stands like the base. A model that fails any check below is removed from
## StockPalette.MANE_STYLES, not accommodated.
##
## Skips whole, not partly, on a checkout with no converted assets (docs/ci.md section 4).

const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PropsScript := preload("res://world/props.gd")

## Every clip the crowd and the player actually play. Gait picks between them by speed.
const REQUIRED_CLIPS: Array[StringName] = [&"idle", &"walk", &"gallop"]

## How far a donor's standing height may differ from the base model's, as a ratio. Tight
## enough to reject a filly rig or one carrying a hat, loose enough not to care about a
## mane a few centimetres taller.
const HEIGHT_BAND := 0.15

var _built: Array[Node3D] = []


func after_each() -> void:
	for node in _built:
		if is_instance_valid(node):
			node.free()
	_built = []


func _stock_record() -> PonyData:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	return registry.by_id(StockPaletteScript.IDS[0])


func _build(path: String) -> Node3D:
	var data: PonyData = _stock_record()
	if data == null or not ResourceLoader.exists(path):
		return null
	var node: Node3D = PonyVisualsScript.build(data, path)
	if node != null:
		_built.append(node)
	return node


func test_the_pool_has_a_few_styles_and_the_base_model_is_the_first_of_them() -> void:
	assert_gte(StockPaletteScript.mane_style_count(), 4, "a pool of one is what we had")
	assert_lte(StockPaletteScript.mane_style_count(), 6, "curated, not the whole roster")
	assert_eq(StockPaletteScript.mane_style_path(0),
		"res://assets/converted/ponies/pokeypierce.glb",
		"index 0 must stay the shipped base, or every existing save changes pony")


func test_an_index_out_of_range_wraps_like_every_other_palette_row() -> void:
	var n: int = StockPaletteScript.mane_style_count()
	assert_eq(StockPaletteScript.mane_style_path(n), StockPaletteScript.mane_style_path(0))
	assert_eq(StockPaletteScript.mane_style_path(-1),
		StockPaletteScript.mane_style_path(n - 1))


func test_every_style_has_a_label_a_person_can_read() -> void:
	for i in StockPaletteScript.mane_style_count():
		var label: String = StockPaletteScript.mane_style_label(i)
		assert_false(label.is_empty())
		assert_false(label.contains("--") or label.contains("—"), label)
		assert_false(label.contains("res://"), "a file path is not a label: %s" % label)


func test_every_model_in_the_pool_exists_and_builds() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	for i in StockPaletteScript.mane_style_count():
		var path: String = StockPaletteScript.mane_style_path(i)
		assert_true(ResourceLoader.exists(path), "%s is not on disk" % path)
		assert_not_null(_build(path), "%s did not build" % path)


func test_every_model_in_the_pool_carries_the_clips_the_game_plays() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	for i in StockPaletteScript.mane_style_count():
		var path: String = StockPaletteScript.mane_style_path(i)
		var node: Node3D = _build(path)
		if node == null:
			continue
		var anim := node.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) \
			as AnimationPlayer
		assert_not_null(anim, "%s has no AnimationPlayer" % path)
		for clip: StringName in REQUIRED_CLIPS:
			assert_true(anim.has_animation(clip), "%s has no '%s' clip" % [path, clip])


## THE CHECK THAT MADE THE POOL CURATED RATHER THAN "every model in the directory".
## StockTint matches SURFACE NAMES (body, hair, tail, eyeball_l, eyeball_r); a rig exported
## with different names recolours into nothing and stands in the field wearing somebody
## else's cutie mark.
func test_every_model_in_the_pool_takes_the_tint_on_every_surface_the_base_does() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	for i in StockPaletteScript.mane_style_count():
		var path: String = StockPaletteScript.mane_style_path(i)
		var node: Node3D = _build(path)
		if node == null:
			continue
		var touched: int = StockTintScript.apply_colors(node,
			Color.RED, Color.BLUE, Color.GREEN)
		assert_gt(touched, 0, "%s: the tint reached no surface at all" % path)
		for surface: StringName in [&"body", &"hair", &"tail", &"eyeball_l"]:
			assert_not_null(StockTintScript.override_of(node, surface),
				"%s has no '%s' surface for the tint to land on" % [path, surface])


## A filly rig, or one carrying a hat or a cape, stands a different height, and a crowd of
## ponies at three different heights reads as a bug rather than as variety.
func test_every_model_in_the_pool_stands_about_as_tall_as_the_base() -> void:
	if _stock_record() == null or not ResourceLoader.exists(
			StockPaletteScript.mane_style_path(0)):
		pass_test("no converted assets on this machine")
		return
	var base: Node3D = _build(StockPaletteScript.mane_style_path(0))
	if base == null:
		pass_test("no converted assets on this machine")
		return
	add_child(base)
	var base_height: float = PropsScript.world_aabb(base).size.y
	assert_gt(base_height, 0.5, "sanity: the base model has a height")
	for i in range(1, StockPaletteScript.mane_style_count()):
		var path: String = StockPaletteScript.mane_style_path(i)
		var node: Node3D = _build(path)
		if node == null:
			continue
		add_child(node)
		var h: float = PropsScript.world_aabb(node).size.y
		assert_almost_eq(h / base_height, 1.0, HEIGHT_BAND,
			"%s stands %.3f m against the base's %.3f m" % [path, h, base_height])


func test_draw_look_stays_inside_the_pool_and_is_deterministic() -> void:
	var palette: StockPalette = StockPaletteScript.load_stock()
	var a := RandomNumberGenerator.new()
	a.seed = 1234
	var b := RandomNumberGenerator.new()
	b.seed = 1234
	assert_eq(palette.draw_look(a), palette.draw_look(b), "same seed, same pony")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen := {}
	for i in 200:
		var look: Dictionary = palette.draw_look(rng)
		assert_between(int(look["mane_style"]), 0,
			StockPaletteScript.mane_style_count() - 1)
		seen[int(look["mane_style"])] = true
	assert_eq(seen.size(), StockPaletteScript.mane_style_count(),
		"two hundred draws must reach every style, or the crowd is still one mane")
