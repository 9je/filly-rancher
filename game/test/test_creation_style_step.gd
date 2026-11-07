extends GutTest
## THE CREATOR'S FINISHING TOUCHES (PS7, playtest 2026-11-05 item 6: "More customisation").
## A fourth step with four rows of picture cards: a coat marking, its colour, an eye shape and
## something to wear. Each pick lands on the look and on the pony on the turntable at once,
## the keyboard reaches every row, the step fits a 1080 screen, and confirm carries them out.

const CreationScreenScene := preload("res://ui/creation_screen.tscn")
const PlayerLookScript := preload("res://systems/player_look.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const AccessoriesScript := preload("res://systems/accessories.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")

var _screen: CreationScreen = null
var _was_shading := true


func before_each() -> void:
	_was_shading = ToonStyler.shading_enabled
	ToonStyler.shading_enabled = true
	_screen = CreationScreenScene.instantiate()
	add_child_autofree(_screen)
	_screen.open(PlayerLookScript.default_look())
	_screen.set_step(CreationScreen.Step.STYLE)


func after_each() -> void:
	ToonStyler.shading_enabled = _was_shading
	get_tree().paused = false


func _grid(name: String) -> SwatchGrid:
	return _screen.find_child(name, true, false) as SwatchGrid


func test_the_step_shows_four_rows_of_picture_cards() -> void:
	var palette: StockPalette = StockPaletteScript.load_player()
	var rows := {"MarkingGrid": 5, "MarkingColourGrid": palette.coats.size() + 1,
		"EyeShapeGrid": 3, "WearGrid": AccessoriesScript.count() + 1}
	for n: String in rows:
		var g := _grid(n)
		assert_not_null(g, n)
		if g == null:
			continue
		assert_true(g.is_visible_in_tree(), "%s shows on this step" % n)
		assert_eq(g.cell_count(), int(rows[n]), n)
	for n: String in ["MarkingGrid", "EyeShapeGrid", "WearGrid"]:
		var g := _grid(n)
		if g == null:
			continue
		for i in g.cell_count():
			assert_not_null(g.cell(i).icon, "%s card %d is a picture" % [n, i])
	_screen.set_step(CreationScreen.Step.LOOK)
	assert_false(_grid("WearGrid").is_visible_in_tree(), "and only on this step")


func _coat_marking(model: Node3D) -> int:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.get_shader_parameter(&"marking") != null and int(m.get_shader_parameter(&"marking")) > 0:
				return int(m.get_shader_parameter(&"marking"))
	return 0


func test_each_card_lands_on_the_look_and_the_turntable_pony() -> void:
	_grid("MarkingGrid").cell(PonyLookScript.Marking.BLAZE).pressed.emit()
	assert_eq(_screen.look().marking, PonyLookScript.Marking.BLAZE)
	assert_eq(_coat_marking(_screen.model()), PonyLookScript.Marking.BLAZE, "the turntable pony has it")
	_grid("MarkingColourGrid").cell(3).pressed.emit()
	assert_eq(_screen.look().marking_colour, 2, "card 0 is white, then the coat colours")
	_grid("MarkingColourGrid").cell(0).pressed.emit()
	assert_eq(_screen.look().marking_colour, -1)
	_grid("EyeShapeGrid").cell(PonyLookScript.EyeShape.SLEEPY).pressed.emit()
	assert_eq(_screen.look().eye_shape, PonyLookScript.EyeShape.SLEEPY)
	_grid("WearGrid").cell(1).pressed.emit()
	assert_eq(_screen.look().accessory, 0, "card 0 is nothing, then the pieces")
	var sk: Skeleton3D = _screen.model().find_children("*", "Skeleton3D", true, false)[0]
	assert_not_null(sk.get_node_or_null(NodePath(AccessoriesScript.NODE_NAME)), "she wears it on the turntable")
	_grid("WearGrid").cell(0).pressed.emit()
	assert_eq(_screen.look().accessory, -1)
	assert_null(sk.get_node_or_null(NodePath(AccessoriesScript.NODE_NAME)), "and takes it off")


func test_confirm_carries_the_finishing_touches_out() -> void:
	_grid("MarkingGrid").cell(PonyLookScript.Marking.SOCKS).pressed.emit()
	_grid("EyeShapeGrid").cell(PonyLookScript.EyeShape.ALMOND).pressed.emit()
	_grid("WearGrid").cell(3).pressed.emit()
	watch_signals(_screen)
	assert_true(_screen.confirm())
	var out: PlayerLook = get_signal_parameters(_screen, "confirmed")[0]
	assert_eq(out.marking, PonyLookScript.Marking.SOCKS)
	assert_eq(out.eye_shape, PonyLookScript.EyeShape.ALMOND)
	assert_eq(out.accessory, 2)


func test_the_keyboard_reaches_every_row() -> void:
	var seen: Array[StringName] = []
	for i in 8:
		seen.append(_screen.kb_region())
		_screen.switch_region(1)
	for r: StringName in [&"marking", &"marking_colour", &"eye_shape", &"wear"]:
		assert_true(r in seen, "%s is a cursor stop" % r)


func test_the_step_fits_a_1080_screen_and_has_a_tab() -> void:
	await wait_frames(2)
	var col := _screen.find_child("Column", true, false) as Control
	assert_lt(col.get_combined_minimum_size().y, 1000.0)
	var tab := _screen.find_child("StepStyle", true, false) as Button
	assert_not_null(tab)
	assert_eq(tab.text, CreationScreen.STEP_STYLE_LABEL)
	for t: String in [CreationScreen.STEP_STYLE_LABEL, CreationScreen.MARKING_LABEL,
			CreationScreen.MARKING_COLOUR_LABEL, CreationScreen.EYE_SHAPE_LABEL, CreationScreen.WEAR_LABEL]:
		assert_true(t in _screen.drawn_lines(), t)
