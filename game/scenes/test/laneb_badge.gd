extends SceneTree
## P9 W3 item 32: the pen badge on a loaded save, seen from the GAMEPLAY camera with the player
## standing at the pen the way the owner walks up to it.
##   badge_as_loaded   the save's pens as they are (named ponies, no Drifters): count only
##   badge_hungry      three Drifters, one hungry: hay icon on a red ring
##   badge_full        a pen of eight, full, Drifters crowded: the badge turns gold
##   badge_two_pens    both pens in view at once, from the path between them
##   -s res://scenes/test/laneb_badge.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _drifter(kind: StringName, seed_value: int) -> PonyInstance:
	var inst := PonyInstanceScript.create(kind, 900000 + seed_value)
	inst.stock = GeneratorScript.generate(seed_value).to_dict()
	inst.happiness = 1.0
	inst.hunger = 0.1
	return inst


func _front(ranch: Node, pen: Pen, back := 6.5, swing := 0.35) -> void:
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	var at := pen.global_position + outward.rotated(Vector3.UP, swing) * (Pen.HALF_EXTENT + back)
	Boot.stand(ranch, at, pen.global_position)


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var pens: Array = Boot.pens(ranch)
	var a: Pen = pens[0]
	var b: Pen = pens[pens.size() - 1]
	_front(ranch, b)
	await Boot.shot(self, out.path_join("badge_as_loaded.png"), 40)
	print("STATE loaded ", PenReadout.badge_state(b))
	var inv: Inventory = ranch.call("_current_inventory")
	for inst in a.ponies():
		a.remove_pony(inst.uid)
	var bold: Array[PonyInstance] = []
	for i in 3:
		var d := _drifter(&"stock_bold", 4100 + i)
		d.bloom = 0.2 + 0.2 * i
		bold.append(d)
		a.add_pony(d)
	for k in 30:
		bold[0].hunger = 0.9
		await process_frame
	_front(ranch, a)
	for k in 30:
		bold[0].hunger = 0.9
		await process_frame
	print("STATE hungry ", PenReadout.badge_state(a))
	await Boot.shot(self, out.path_join("badge_hungry.png"), 2)
	for inst in b.ponies():
		b.remove_pony(inst.uid)
	b.capacity = 8
	for i in 8:
		var c := _drifter(&"stock_curious", 4200 + i)
		c.favorite_glow = 150.0
		c.bloom = 0.1 + 0.08 * i
		b.add_pony(c)
	_front(ranch, b)
	for k in 40:
		bold[0].hunger = 0.9
		await process_frame
	print("STATE full ", PenReadout.badge_state(b))
	await Boot.shot(self, out.path_join("badge_full.png"), 2)
	# From between the two pens, both badges at once.
	var mid := (a.global_position + b.global_position) * 0.5
	var away := (b.global_position - a.global_position).normalized().cross(Vector3.UP)
	Boot.stand(ranch, mid + away * 11.0, mid)
	await Boot.shot(self, out.path_join("badge_two_pens.png"), 40)
	# At the gate with ponies in the Scoop, then with it empty: the short prompts (item 36).
	_front(ranch, a, 0.6, 0.0)
	await Boot.shot(self, out.path_join("prompt_pen_in.png"), 40)
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	var beam: Node = ranch.get("player").get_node_or_null(^"MagicBeam")
	var storage = beam.get("_storage")
	while storage.peek() != null:
		storage.release()
	await Boot.shot(self, out.path_join("prompt_pen_empty.png"), 30)
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	print("LANEB_BADGE_OK")
	quit(0)
