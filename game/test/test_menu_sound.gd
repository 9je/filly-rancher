extends GutTest
## The UI tick kit, and the rule that keeps it the only audio decision under game/ui/.
##
## THE SOURCE SCAN AT THE BOTTOM is the load bearing test in this file. Six forwarders are
## easy to write and easy to bypass, and a menu that reaches past them for Sound.play() with
## an id of its own is exactly the drift this kit exists to prevent.
##
## test_the_six_forwarders_exist_and_run RUNS THIS SUITE'S SCRIPT UNDER GUT, which boots a
## real SceneTree with Sound registered, so MenuStyle's forwarders resolve the autoload
## through Engine.get_main_loop() exactly as they do in the game; see menu_style.gd's own
## comment on why they cannot reach it by the bare identifier.

const MenuStyleScript := preload("res://ui/menu_style.gd")
const SoundScript := preload("res://systems/sound.gd")

const UI_DIR := "res://ui/"
## menu_style.gd is the kit itself, so it is the one file allowed to name a UI id.
const KIT := "menu_style.gd"
## The banner the kit's own six forwarders live under. test_no_new_ui_line_carries_a_dash
## slices the file here: everything above the banner is older code this slice did not
## write, and some of those pre existing comments carry the house dash.
const KIT_BANNER := "# --- the menu tick kit"


func test_the_six_forwarders_exist_and_run() -> void:
	MenuStyleScript.tick_move()
	MenuStyleScript.tick_confirm()
	MenuStyleScript.tick_back()
	MenuStyleScript.tick_open()
	MenuStyleScript.tick_denied()
	MenuStyleScript.tick_page()
	assert_true(true, "six forwarders ran without an error")


func test_every_ui_id_the_kit_names_is_in_the_library() -> void:
	for id: StringName in [&"ui_move", &"ui_confirm", &"ui_back", &"ui_open", &"ui_denied",
			&"ui_page"]:
		assert_true(SoundScript.LIBRARY.has(id), "'%s' is not in LIBRARY" % id)
		var entry: Dictionary = SoundScript.LIBRARY[id]
		assert_eq(StringName(entry.get("bus", &"")), SoundScript.BUS_UI)


func test_no_menu_names_a_ui_sound_id_behind_the_kit() -> void:
	var offenders: Array[String] = []
	for name: String in DirAccess.get_files_at(UI_DIR):
		if not name.ends_with(".gd") or name == KIT:
			continue
		var text: String = FileAccess.get_file_as_string(UI_DIR + name)
		for id: String in ["ui_move", "ui_confirm", "ui_back", "ui_open", "ui_denied",
				"ui_page"]:
			if text.contains("&\"%s\"" % id):
				offenders.append("%s names %s" % [name, id])
	assert_eq(offenders, [] as Array[String],
		"menus call MenuStyle.tick_*(); only menu_style.gd may name a UI id")


func test_no_menu_constructs_a_generator() -> void:
	# The standing rule, re-asserted here because this slice adds calls under game/ui/ and
	# a variation decision is exactly the thing somebody would be tempted to make locally.
	var offenders: Array[String] = []
	for name: String in DirAccess.get_files_at(UI_DIR):
		if not name.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string(UI_DIR + name)
		if text.contains("RandomNumberGenerator") or text.contains("randi(") \
				or text.contains("randf("):
			offenders.append(name)
	assert_eq(offenders, [] as Array[String], "no RNG may live under game/ui/")


func test_no_new_ui_line_carries_a_dash_of_either_kind() -> void:
	var kit: String = FileAccess.get_file_as_string(UI_DIR + KIT)
	var banner_at: int = kit.find(KIT_BANNER)
	assert_gt(banner_at, -1, "the menu tick kit banner is missing from menu_style.gd")
	var new_lines: String = kit.substr(banner_at)
	for line: String in new_lines.split("\n"):
		if line.strip_edges().begins_with("# ---"):
			continue
		assert_false(line.contains("--"), "menu_style.gd line carries a double hyphen: %s" % line)
		assert_false(line.contains(char(0x2014)), "menu_style.gd line carries an em dash")
