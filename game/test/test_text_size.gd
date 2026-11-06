extends GutTest
## TEXT SIZE (FS8.2): 100, 125 or 150 percent, saved with the settings, scaling every label the
## menus style through MenuStyle. At 150 percent the menus still fit the UI canvas, which is
## 1920x1080 at every window size (project.godot stretch mode canvas_items: a 1280x720 window
## shows the same layout scaled down).

const SettingsScript := preload("res://systems/settings.gd")
const SettingsMenuScene := preload("res://ui/settings_menu.tscn")
const MarketMenuScene := preload("res://ui/market_menu.tscn")
const ShopScript := preload("res://systems/shop.gd")
const EconomyScript := preload("res://systems/economy.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")

var _path := ""


func before_each() -> void:
	_path = "user://test_text_size_%d.cfg" % Time.get_ticks_usec()
	SettingsScript.settings_path = _path


func after_each() -> void:
	MenuStyle.text_scale = 1.0
	SettingsScript.settings_path = SettingsScript.resolve_settings_path(SaveIO.session_save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_the_size_saves_and_loads_and_old_files_get_the_default() -> void:
	var s := SettingsScript.new()
	assert_eq(s.text_size, 100, "an old settings file: the default")
	s.text_size = 150
	s.save_to(_path)
	var back := SettingsScript.new()
	back.load_from(_path)
	assert_eq(back.text_size, 150)


func test_applying_it_scales_the_labels_menus_style() -> void:
	var s := SettingsScript.new()
	s.text_size = 125
	s.apply_text()
	var l := Label.new()
	add_child_autofree(l)
	MenuStyle.style_label(l, 20, Color.WHITE)
	assert_eq(l.get_theme_font_size("font_size"), 25)
	assert_eq(MenuStyle.font_px(24), 30)


func _inside(panel: Control, vp: Rect2) -> bool:
	var r := panel.get_global_rect()
	return vp.encloses(r.grow(-1.0))


func test_at_150_percent_the_menus_fit_the_ui_canvas() -> void:
	var s := SettingsScript.new()
	s.text_size = 150
	s.apply_text()
	var sub := SubViewport.new()
	sub.size = Vector2i(1920, 1080)
	add_child_autofree(sub)
	var vp := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var menu: Node = SettingsMenuScene.instantiate()
	sub.add_child(menu)
	menu.call("open", SettingsScript.new())
	await wait_frames(4)
	var found := menu.find_children("Panel", "PanelContainer", true, false)
	var p := found[0] as Control if not found.is_empty() else null
	assert_not_null(p)
	if p != null:
		assert_true(_inside(p, vp), "the settings menu at 150%%: %s" % p.get_global_rect())
	var market: MarketMenu = MarketMenuScene.instantiate()
	sub.add_child(market)
	market.shop = ShopScript.new(EconomyScript.new(0), GemPouchScript.new(), InventoryScript.new(), [])
	market.open()
	await wait_frames(4)
	var mp := market.get_node_or_null(^"Centre/Panel") as Control
	if mp != null:
		assert_true(_inside(mp, vp), "the market at 150%%: %s" % mp.get_global_rect())


## Review 2026-11-06: only the title screen applied the saved size, so a ranch launched as the
## first scene drew every menu at 100 percent whatever the setting said.
func test_the_ranch_applies_the_saved_text_size() -> void:
	var was := MenuStyle.text_scale
	var ranch: Node = load("res://world/ranch.gd").new()
	var s := Settings.new()
	s.text_size = 150
	ranch.set("_settings", s)
	MenuStyle.text_scale = 1.0
	ranch.call("_apply_settings")
	assert_almost_eq(MenuStyle.text_scale, 1.5, 0.001)
	MenuStyle.text_scale = was
	ranch.free()
