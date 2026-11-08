extends GutTest
## THE THEME IS GENERATED, AND THIS IS WHAT KEEPS IT HONEST. game/scripts/make_theme.gd
## reads game/ui/menu_style.gd and writes game/ui/theme/filly_theme.tres. Two files that
## agree today and drift tomorrow is the exact failure this project already had once: ten
## .tscn files each carrying their own copy of one StyleBoxFlat. So the resource on disk is
## compared against the constants it was generated from, every run.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const PaperPaintScript := preload("res://ui/paper_paint.gd")


func test_the_theme_resource_is_on_disk_and_loads() -> void:
	assert_true(ResourceLoader.exists(MenuStyleScript.THEME_PATH),
		"run bash tools/make_theme.sh")
	var theme: Theme = MenuStyleScript.theme_resource()
	assert_not_null(theme, "the generated theme has to load as a Theme")


func test_the_project_installs_the_theme_for_every_control() -> void:
	assert_eq(String(ProjectSettings.get_setting("gui/theme/custom", "")),
		MenuStyleScript.THEME_PATH,
		"project.godot must install the theme, or nothing inherits it")


func test_every_button_state_is_styled_and_they_are_not_the_same_box() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	var seen: Array = []
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var box: StyleBox = theme.get_stylebox(state, &"Button")
		# P8 S5: the kit's painted pills, one picture per state.
		assert_true(box is StyleBoxTexture, "Button/%s is not a kit surface" % state)
		seen.append((box as StyleBoxTexture).texture)
	assert_eq(seen.size(), 4)
	for i in range(1, seen.size()):
		assert_ne(seen[i], seen[0], "a hover state that looks like normal is not a state")


func test_the_slider_and_the_tab_bar_are_styled() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	for pair: Array in [["slider", "HSlider"], ["grabber_area", "HSlider"],
			["tab_selected", "TabBar"], ["tab_unselected", "TabBar"],
			["tab_hovered", "TabBar"]]:
		var box := theme.get_stylebox(StringName(pair[0]), StringName(pair[1]))
		assert_true(box is StyleBoxFlat or box is StyleBoxTexture,
			"%s/%s is unstyled" % [pair[1], pair[0]])


func test_the_panel_in_the_theme_is_the_panel_menu_style_hands_out() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	var box := theme.get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
	assert_not_null(box)
	assert_eq(box.texture.resource_path, MenuStyleScript.panel_style().texture.resource_path,
		"the theme and menu_style.gd have drifted; re-run bash tools/make_theme.sh")


func test_the_row_boxes_ride_along_so_a_drawn_row_and_a_themed_row_match() -> void:
	var theme: Theme = MenuStyleScript.theme_resource()
	for pair: Array in [[&"FillyRow", MenuStyleScript.row_box(false)],
			[&"FillyRowSelected", MenuStyleScript.row_box(true)],
			[&"FillyRowHover", MenuStyleScript.row_box_hover()]]:
		var box: StyleBoxFlat = theme.get_stylebox(&"panel", pair[0]) as StyleBoxFlat
		assert_not_null(box, "%s is missing from the theme" % pair[0])
		assert_eq(box.bg_color, (pair[1] as StyleBoxFlat).bg_color, String(pair[0]))


func test_the_paper_menu_style_names_is_the_paper_the_stationery_kit_draws() -> void:
	# ONE PAPER, TWO READERS. paper_paint.gd draws letters by hand and the theme styles the
	# panel behind them; if these two ever disagree the letter sits on a sheet of a slightly
	# different white and every screenshot shows it.
	assert_eq(MenuStyleScript.COLOR_PAPER, PaperPaintScript.PAPER)
	assert_eq(MenuStyleScript.COLOR_PAPER_EDGE, PaperPaintScript.PAPER_EDGE)
	assert_eq(MenuStyleScript.COLOR_INK, PaperPaintScript.INK)


func test_the_wooden_frame_is_a_real_border_and_not_a_hairline() -> void:
	# P8 S5: the kit's painted wood, its frame wide enough to read as a frame.
	var frame := MenuStyleScript.frame_box() as StyleBoxTexture
	assert_not_null(frame.texture)
	assert_gte(frame.texture_margin_left, 32.0)
