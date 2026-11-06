extends SceneTree
## THE THREE TABLES, PHOTOGRAPHED. Opens each casino game on its own over a dark backdrop
## (no ranch, so a shot takes seconds), puts it in the states worth looking at (idle, mid
## animation, a win, a bust), and saves a PNG of each at every text size the settings offer.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/casino_shot.gd \
##     -- --out=/abs/dir [--game=wheel|slots|blackjack|all] [--scales=1.0,1.25,1.5]
const MenuStyleScript := preload("res://ui/menu_style.gd")
const WheelScript := preload("res://systems/wheel.gd")
const RoundScript := preload("res://systems/blackjack_round.gd")

var out := ""
var game := "all"
var scales: Array[float] = [1.0, 1.25, 1.5]
var chips := 1205


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--game="):
			game = a.substr(7)
		elif a.begins_with("--scales="):
			scales.clear()
			for part in a.substr(9).split(","):
				scales.append(float(part))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	var rect := ColorRect.new()
	rect.color = Color(0.20, 0.10, 0.24)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	root.add_child(layer)


func _menu(path: String) -> CanvasLayer:
	var menu: CanvasLayer = (load(path) as PackedScene).instantiate()
	root.add_child(menu)
	menu.set("can_open", func() -> bool: return true)
	menu.set("chips_provider", func() -> int: return chips)
	menu.call("open")
	return menu


func _shot(name: String, frames: int = 4) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("CASINOSHOT ", name)


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	_backdrop()
	for s: float in scales:
		MenuStyleScript.text_scale = s
		var tag := "%d" % roundi(s * 100.0)
		if game == "all" or game == "wheel":
			await _wheel(tag)
		if game == "all" or game == "slots":
			await _slots(tag)
		if game == "all" or game == "blackjack":
			await _blackjack(tag)
	print("CASINOSHOT_OK")
	quit()


func _wheel(tag: String) -> void:
	chips = 1205
	var menu: CanvasLayer = _menu("res://ui/wheel_menu.tscn")
	await _shot("wheel_%s_idle" % tag)
	menu.call("set_chip", 1)
	menu.call("add_bet", 0)
	menu.call("add_bet", 1)
	menu.call("add_bet", 1)
	menu.call("set_chip", 0)
	menu.call("add_bet", 4)
	menu.call("focus_on", &"spin")
	await _shot("wheel_%s_bets" % tag)
	var three: int = WheelScript.LAYOUT.find(WheelScript.Tier.THREE)
	chips = 1205 - 160 + 400
	menu.call("show_spin", three, 400, 160)
	for i in 50:
		await process_frame
	await _shot("wheel_%s_spinning" % tag, 1)
	menu.get("_tween").custom_step(WheelMenu.SPIN_SECONDS - 0.8 + 0.3)
	await _shot("wheel_%s_win" % tag, 3)
	menu.call("finish_animation")
	menu.queue_free()
	await process_frame


func _slots(tag: String) -> void:
	chips = 205
	var menu: CanvasLayer = _menu("res://ui/slots_menu.tscn")
	await _shot("slots_%s_idle" % tag)
	menu.call("set_stake_index", 1)
	chips = 205 - 50
	menu.call("show_spin", [0, 2, 1] as Array[int], 0, 50)
	for i in 30:
		await process_frame
	await _shot("slots_%s_spinning" % tag, 1)
	menu.call("finish_animation")
	await _shot("slots_%s_loss" % tag)
	chips = 155 - 50 + 200
	menu.call("show_spin", [1, 1, 1] as Array[int], 200, 50)
	menu.get("_tween").custom_step(2.0)
	await _shot("slots_%s_win" % tag, 3)
	menu.call("finish_animation")
	menu.queue_free()
	await process_frame


## A REAL HAND from the real round code, pushed the way ranch.gd pushes it.
func _blackjack(tag: String) -> void:
	chips = 500
	var menu: CanvasLayer = _menu("res://ui/blackjack_menu.tscn")
	await _shot("blackjack_%s_idle" % tag)
	var hand: RefCounted = _find_hand(func(h) -> bool:
		if h.is_settled():
			return false
		h.stand()
		return h.dealer_total() > 21)
	chips = 450
	menu.call("show_hand", hand.view(), 0, 50)
	menu.call("finish_animation")
	await _shot("blackjack_%s_decide" % tag)
	hand.stand()
	chips = 450 + hand.payout()
	menu.call("show_hand", hand.view(), hand.payout(), 50)
	menu.call("finish_animation")
	await _shot("blackjack_%s_dealer_busts" % tag)
	menu.call("set_tab", 1)
	await _shot("blackjack_%s_rules" % tag)
	menu.call("set_tab", 0)
	menu.queue_free()
	await process_frame


func _find_hand(want: Callable) -> RefCounted:
	for seed_value in range(1, 5000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if want.call(RoundScript.deal(rng, 50)):
			rng.seed = seed_value
			return RoundScript.deal(rng, 50)
	return null
