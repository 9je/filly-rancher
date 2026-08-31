extends GutTest
## The mark on the model. Structural: headless renders nothing, so this asserts the nodes,
## the texture and where in the world they sit.

const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

var _model: Node3D = null


func after_each() -> void:
	if _model != null and is_instance_valid(_model):
		_model.free()
	_model = null


func _base_model() -> Node3D:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	if data == null or not ResourceLoader.exists(data.model_path):
		return null
	return PonyVisualsScript.build(data)


func test_a_mark_lands_on_both_flanks() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	var mark: Image = MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED)
	assert_eq(CutieMarkScript.apply(_model, mark), 2, "a pony has two flanks")
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	assert_eq(decals.size(), 2)
	for decal in decals:
		assert_not_null(decal.texture_albedo, "the mark is the decal's albedo")
		assert_eq(decal.texture_albedo.get_image().get_width(), MarkPaintScript.SIZE)


func test_the_two_flanks_are_on_opposite_sides_of_the_barrel() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.HEART, Color.RED))
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	var xs: Array[float] = []
	for decal in decals:
		xs.append(_model.to_local(decal.global_position).x)
	xs.sort()
	assert_lt(xs[0], 0.0, "one flank is on the left")
	assert_gt(xs[1], 0.0, "and one on the right")
	assert_almost_eq(absf(xs[0]), absf(xs[1]), 0.01, "and they are the same distance out")


func test_applying_twice_replaces_the_mark_rather_than_stacking_decals() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED))
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.GEM, Color.BLUE))
	assert_eq(CutieMarkScript.decals_of(_model).size(), 2, "still two flanks, not four")


func test_a_blank_mark_leaves_a_blank_flank() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	assert_eq(CutieMarkScript.apply(_model, MarkPaintScript.blank()), 0,
		"a pony who drew nothing has a blank flank, which is a real look")
	assert_eq(CutieMarkScript.decals_of(_model).size(), 0)


func test_clear_takes_the_mark_off_again() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED))
	CutieMarkScript.clear(_model)
	assert_eq(CutieMarkScript.decals_of(_model).size(), 0)


func test_a_null_model_is_refused() -> void:
	assert_eq(CutieMarkScript.apply(null, MarkPaintScript.blank()), 0)
