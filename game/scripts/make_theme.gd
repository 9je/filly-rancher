extends SceneTree
## THE THEME IS GENERATED AND NEVER HAND EDITED. Driven by `bash tools/make_theme.sh`; not
## part of the game and never loaded by it, exactly like game/scripts/prove_atomic_save.gd.
##
## WHY A GENERATOR RATHER THAN A CHECKED IN .tres SOMEBODY EDITS. game/ui/menu_style.gd has
## been this project's style layer since the menu polish pass, every drawn panel in the game
## reads its constants directly, and a Theme resource maintained beside it by hand would be
## a second palette that agrees on the day it is written and on no day after. So the file on
## disk is output: edit menu_style.gd, run this, commit both.
##
## THE OUTPUT IS COMMITTED even though it is generated, because game/project.godot installs
## it as gui/theme/custom and a checkout that had not run this script would boot unstyled.

const MenuStyleScript := preload("res://ui/menu_style.gd")

const OUT_DIR := "res://ui/theme"
const OUT_PATH := "res://ui/theme/filly_theme.tres"


func _init() -> void:
	var theme := Theme.new()
	theme.default_font_size = MenuStyleScript.ROW_SIZE

	theme.set_stylebox(&"panel", &"PanelContainer", MenuStyleScript.panel_style())

	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"Button", MenuStyleScript.button_box(state))
	theme.set_color(&"font_color", &"Button", MenuStyleScript.COLOR_NAME)
	theme.set_color(&"font_hover_color", &"Button", MenuStyleScript.COLOR_TITLE)
	theme.set_color(&"font_pressed_color", &"Button", MenuStyleScript.COLOR_VALUE)
	theme.set_color(&"font_disabled_color", &"Button", MenuStyleScript.COLOR_TAB_OFF)
	theme.set_color(&"font_outline_color", &"Button", MenuStyleScript.OUTLINE_COLOR)
	theme.set_constant(&"outline_size", &"Button", MenuStyleScript.OUTLINE_SIZE)
	theme.set_font_size(&"font_size", &"Button", MenuStyleScript.ROW_SIZE)

	theme.set_color(&"font_color", &"Label", MenuStyleScript.COLOR_NAME)
	theme.set_color(&"font_outline_color", &"Label", MenuStyleScript.OUTLINE_COLOR)
	theme.set_constant(&"outline_size", &"Label", MenuStyleScript.OUTLINE_SIZE)

	theme.set_stylebox(&"normal", &"LineEdit", MenuStyleScript.field_box(false))
	theme.set_stylebox(&"focus", &"LineEdit", MenuStyleScript.field_box(true))
	theme.set_color(&"font_color", &"LineEdit", MenuStyleScript.COLOR_INK)
	theme.set_color(&"caret_color", &"LineEdit", MenuStyleScript.COLOR_INK)
	theme.set_font_size(&"font_size", &"LineEdit", MenuStyleScript.ROW_SIZE)

	theme.set_stylebox(&"slider", &"HSlider", MenuStyleScript.slider_box(false))
	theme.set_stylebox(&"grabber_area", &"HSlider", MenuStyleScript.slider_box(true))
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider",
		MenuStyleScript.slider_box(true))

	theme.set_stylebox(&"tab_selected", &"TabBar", MenuStyleScript.tab_box(&"selected"))
	theme.set_stylebox(&"tab_unselected", &"TabBar", MenuStyleScript.tab_box(&"unselected"))
	theme.set_stylebox(&"tab_hovered", &"TabBar", MenuStyleScript.tab_box(&"hovered"))
	theme.set_color(&"font_selected_color", &"TabBar", MenuStyleScript.COLOR_TAB_ON)
	theme.set_color(&"font_unselected_color", &"TabBar", MenuStyleScript.COLOR_TAB_OFF)
	theme.set_color(&"font_hovered_color", &"TabBar", MenuStyleScript.COLOR_TITLE)

	# THE THREE ROW BOXES AND THE TWO MATERIALS, under type names nothing in Godot owns, so a
	# menu can ask the Theme for the same box game/ui/menu_style.gd hands its drawn rows.
	theme.set_stylebox(&"panel", &"FillyRow", MenuStyleScript.row_box(false))
	theme.set_stylebox(&"panel", &"FillyRowSelected", MenuStyleScript.row_box(true))
	theme.set_stylebox(&"panel", &"FillyRowHover", MenuStyleScript.row_box_hover())
	theme.set_stylebox(&"panel", &"FillyPaper", MenuStyleScript.paper_box())
	theme.set_stylebox(&"panel", &"FillyFrame", MenuStyleScript.frame_box())

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err: int = ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("make_theme: could not write %s (%s)" % [OUT_PATH, error_string(err)])
		quit(1)
		return
	print("THEME_WRITTEN %s" % OUT_PATH)
	quit(0)
