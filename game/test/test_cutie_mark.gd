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


## THE 2026-08-31 PLAYTEST BUG. A Decal samples its albedo across its own local XZ plane
## with V = 0 at the TOP of the image, so the drawing's own "up" is the decal's MINUS Z
## axis. The shipped basis passed +Y as that column, which pointed image up at world DOWN,
## and it was left handed besides, which mirrored the drawing. A flip plus a mirror is a
## half turn, and a half turn is why a heart drawn point down came back point up.
func test_the_drawing_lands_right_way_up_on_both_flanks() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	assert_eq(decals.size(), 2)
	for decal in decals:
		assert_gt(CutieMarkScript.image_up(decal).dot(Vector3.UP), 0.99,
			"the top of the canvas must point at the sky on %s" % decal.name)


func test_neither_flank_mirrors_the_drawing() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	for decal in CutieMarkScript.decals_of(_model):
		assert_false(CutieMarkScript.is_mirrored(decal),
			"%s is showing the drawing back to front" % decal.name)


func test_the_projection_runs_from_the_flank_into_the_pony() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	for decal in CutieMarkScript.decals_of(_model):
		var out_local: Vector3 = _model.global_transform.basis.inverse() \
			* CutieMarkScript.image_out(decal)
		var side: float = signf(_model.to_local(decal.global_position).x)
		assert_gt(out_local.x * side, 0.99,
			"%s must face out of the flank it is on, so it projects inward" % decal.name)


func test_the_top_of_the_canvas_sits_higher_on_the_barrel_than_the_bottom() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	for decal in CutieMarkScript.decals_of(_model):
		var top: Vector3 = CutieMarkScript.image_point_to_world(decal, 0.5, 0.0)
		var bottom: Vector3 = CutieMarkScript.image_point_to_world(decal, 0.5, 1.0)
		assert_gt(top.y, bottom.y, "%s has the canvas upside down" % decal.name)
		assert_almost_eq(top.y - bottom.y, decal.size.z, 0.001,
			"the canvas spans the decal's own depth along the barrel")


## THE RIGHT FLANK REPEATS THE DRAWING RATHER THAN MIRRORING IT, and that is a decision
## rather than an accident: a mark you cannot read from one side is not a cutie mark. So
## the same image coordinate lands on the same side of the pony's own body on neither
## flank, and on the same side of the VIEWER on both, which is what is_mirrored() asks.
func test_the_two_flanks_read_the_same_way_round_from_outside() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine")
		return
	add_child_autofree(_model)
	CutieMarkScript.apply(_model, MarkPaintScript.orientation_probe())
	var decals: Array[Decal] = CutieMarkScript.decals_of(_model)
	assert_eq(decals.size(), 2)
	for decal in decals:
		var left_edge: Vector3 = CutieMarkScript.image_point_to_world(decal, 0.0, 0.5)
		var offset: Vector3 = left_edge - decal.global_position
		assert_lt(offset.dot(CutieMarkScript.image_right(decal)), 0.0,
			"the left of the canvas is on the left as seen from outside %s" % decal.name)
