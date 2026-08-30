extends GutTest
## The one recolour pipeline, proved against the real base model.

const StockTintScript := preload("res://systems/stock_tint.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

var _model: Node3D = null


func after_each() -> void:
	if _model != null and is_instance_valid(_model):
		_model.free()
	_model = null


## The base model, or null on an assetless checkout (game/assets/converted/ is gitignored,
## see docs/ci.md section 4). Every test below skips rather than fails without it.
func _base_model() -> Node3D:
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var data: PonyData = registry.by_id(StockPaletteScript.IDS[0])
	if data == null or not ResourceLoader.exists(data.model_path):
		return null
	return PonyVisualsScript.build(data)


func test_surface_roles_are_matched_by_material_name() -> void:
	assert_eq(StockTintScript.role_of(&"body"), StockTintScript.Role.COAT)
	assert_eq(StockTintScript.role_of(&"wings"), StockTintScript.Role.COAT)
	assert_eq(StockTintScript.role_of(&"hair"), StockTintScript.Role.MANE)
	assert_eq(StockTintScript.role_of(&"tail"), StockTintScript.Role.MANE)
	assert_eq(StockTintScript.role_of(&"eyeball_l"), StockTintScript.Role.EYE)
	assert_eq(StockTintScript.role_of(&"eyeball_r"), StockTintScript.Role.EYE)
	assert_eq(StockTintScript.role_of(&"teeth"), StockTintScript.Role.NONE)
	assert_eq(StockTintScript.role_of(&"horn"), StockTintScript.Role.NONE)


func test_the_tint_lands_on_the_coat_the_mane_and_the_eyes() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	var coat := Color(0.20, 0.60, 0.95)
	var mane := Color(0.95, 0.35, 0.10)
	var eyes := Color(0.35, 0.80, 0.45)
	var touched: int = StockTintScript.apply_colors(_model, coat, mane, eyes)
	assert_gt(touched, 0, "at least one surface must be recoloured")
	assert_eq(StockTintScript.override_of(_model, &"body").albedo_color, coat)
	assert_eq(StockTintScript.override_of(_model, &"hair").albedo_color, mane)
	assert_eq(StockTintScript.override_of(_model, &"tail").albedo_color, mane)
	assert_eq(StockTintScript.override_of(_model, &"eyeball_l").albedo_color, eyes)


func test_a_coat_override_drops_the_texture_and_keeps_the_normal_map() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	StockTintScript.apply_colors(_model, Color.RED, Color.BLUE, Color.GREEN)
	var body: StandardMaterial3D = StockTintScript.override_of(_model, &"body")
	assert_null(body.albedo_texture, "the flat coat texture is replaced by a flat colour")
	var eye: StandardMaterial3D = StockTintScript.override_of(_model, &"eyeball_l")
	assert_not_null(eye.albedo_texture, "the eye keeps its iris art and is only modulated")


func test_untinted_surfaces_get_no_override_at_all() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	StockTintScript.apply_colors(_model, Color.RED, Color.BLUE, Color.GREEN)
	assert_null(StockTintScript.override_of(_model, &"teeth"),
		"a surface with no role is left exactly as the artist made it")


func test_applying_twice_replaces_rather_than_stacks() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	StockTintScript.apply_colors(_model, Color.RED, Color.BLUE, Color.GREEN)
	StockTintScript.apply_colors(_model, Color.BLACK, Color.WHITE, Color.GRAY)
	assert_eq(StockTintScript.override_of(_model, &"body").albedo_color, Color.BLACK)


func test_apply_reads_the_triple_through_the_palette() -> void:
	_model = _base_model()
	if _model == null:
		pass_test("no converted assets on this machine; nothing to tint")
		return
	var palette: StockPalette = StockPaletteScript.load_stock()
	var triple := {"coat": 1, "mane": 2, "eyes": 0}
	StockTintScript.apply(_model, palette, triple)
	assert_eq(StockTintScript.override_of(_model, &"body").albedo_color, palette.coat_at(1))
	assert_eq(StockTintScript.override_of(_model, &"hair").albedo_color, palette.mane_at(2))


func test_a_null_model_is_refused_rather_than_crashing() -> void:
	assert_eq(StockTintScript.apply_colors(null, Color.RED, Color.BLUE, Color.GREEN), 0)
