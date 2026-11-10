extends SceneTree
## THE PALACE'S FACES, BAKED ONCE (Fable AAA round 5: "blackjack, the wheel and racing read as
## flat web panels"). The Spectra Palace's hall is built on its own (no ranch), and its
## blackjack dealer and its wheel host are photographed from their own seeded bodies in the
## counter portraits' studio (scenes/test/counter_portraits.gd), framed on the head bone, then
## written to game/assets/ui/portraits/<id>.png for the tables to show as a bust over the felt.
## The hall's staff are seeded (palace_interior.gd), so the picture is the pony standing at
## the table on every visit. Rerun after a model change.
##   godot --display-driver wayland --path game -s res://scenes/test/casino_portraits.gd -- --out=/abs/dir
const PalaceInteriorScript := preload("res://world/palace_interior.gd")
const CatchCardScript := preload("res://ui/catch_card.gd")
const Counter := preload("res://scenes/test/counter_portraits.gd")
## [file id, the staff node's name prefix]
const CAST := [["palace_dealer", "Dealer"], ["palace_host", "WheelHost"]]
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var hall: Node3D = PalaceInteriorScript.new()
	root.add_child(hall)
	hall.call("build", "res://data/ponies")
	hall.visible = false
	for i in 10:
		await process_frame
	var dest := ProjectSettings.globalize_path("res://assets/ui/portraits")
	DirAccess.make_dir_recursive_absolute(dest)
	var studio: Array = Counter._studio_in(root)
	var vp: SubViewport = studio[0]
	var stage: Node3D = studio[1]
	var cam: Camera3D = studio[2]
	var staff := hall.get_node(^"Staff")
	for who: Array in CAST:
		var body: Node3D = null
		for n in staff.get_children():
			if String(n.name).begins_with(String(who[1])) and n.get_child_count() > 0:
				body = n.get_child(0) as Node3D
				break
		if body == null:
			print("PORTRAIT no body for ", who[0])
			continue
		for c in stage.get_children():
			c.free()
		var copy := body.duplicate(0) as Node3D
		copy.transform = Transform3D.IDENTITY
		stage.add_child(copy)
		await Counter.frame_and_shoot(self, copy, cam)
		var img := vp.get_texture().get_image()
		img.save_png(dest.path_join(String(who[0]) + ".png"))
		img.save_png(out.path_join(String(who[0]) + ".png"))
		print("PORTRAIT ", who[0], " ", img.get_size())
	print("CASINO_PORTRAITS_OK")
	quit()
