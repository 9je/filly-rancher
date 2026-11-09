extends SceneTree
## THE DECK ON ONE SHEET (Fable AAA round 1: the court cards). Every rank of hearts at the
## table's own card size, then the twelve court cards large, so the royals are judged in
## seconds without opening the casino.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/card_sheet.gd -- --out=/abs/dir
const PaintScript := preload("res://ui/casino_paint.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	var bg := ColorRect.new()
	bg.color = PaintScript.FELT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	for r: int in 13:
		_card(r, Vector2(16.0 + r * 120.0, 16.0), 1.0)
	for i: int in 12:
		_card((i / 3) * 13 + 10 + i % 3, Vector2(16.0 + i * 131.0, 190.0), 1.3)
	for i: int in 4:
		_card([10, 24, 38, 39][i], Vector2(40.0 + i * 360.0, 400.0), 3.4)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("card_sheet.png"))
	print("CARD_SHEET_OK")
	quit()


func _card(card: int, at: Vector2, k: float) -> void:
	var c := Control.new()
	c.position = at
	c.scale = Vector2(k, k)
	c.draw.connect(func() -> void:
		PaintScript.draw_card(c, Rect2(Vector2.ZERO, Vector2(96.0, 134.0)),
			MenuStyleScript.title_font(), card, true))
	root.add_child(c)
