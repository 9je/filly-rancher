extends SceneTree
## The kit's darkest families in the valley's own light, beside a family that needs no lift
## (FS2.3): one row with ToonStyler's FAMILY_LIFT, one without. Writes lifted.png, unlifted.png.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/look_sheet.gd -- --out=/abs/dir
const BootIntentScript := preload("res://world/boot_intent.gd")
const ToonStylerScript := preload("res://systems/toon_styler.gd")
const FILES := ["saa_corn_plant.glb", "school_swingframe.glb", "saa_dead_tree_large.glb",
	"saa_tree_dead_wide.glb", "school_picnic_table.glb", "mlp_apple_tree_bare.glb", "mlp_bush.glb",
	"saa_tree_wide.glb", "mlp_apple_tree.glb"]
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 600)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	ranch.get_node(^"HUD").visible = false
	for i in 30:
		await process_frame
	paused = false
	# Each family where the valley put it, framed from 7 m, with its lift and without.
	var props: Node = ranch.get_node(^"Props")
	var cam := Camera3D.new()
	ranch.add_child(cam)
	cam.fov = 50.0
	cam.current = true
	root.get_window().size = Vector2i(480, 360)
	for file: String in FILES:
		var inst: Node3D = null
		for c: Node in props.get_children():
			if c.scene_file_path.get_file() == file:
				inst = c
				break
		if inst == null:
			print("LOOK none placed: ", file)
			continue
		var box := _aabb(inst)
		var mid: Vector3 = inst.global_position + Vector3(0, box.size.y * inst.scale.y * 0.5, 0)
		var back := maxf(7.0, box.size.y * inst.scale.y * 1.6)
		cam.global_position = mid + Vector3(back * 0.6, back * 0.25, back * 0.8)
		cam.look_at(mid)
		for pass_i in 2:
			_bare(inst)
			ToonStylerScript.style(inst, ToonStylerScript.category_for(file), null,
				ToonStylerScript.lift_for(file) if pass_i == 0 else 1.0)
			for i in 12:
				await process_frame
			root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [
				file.get_basename(), "lifted" if pass_i == 0 else "unlifted"]))
		_bare(inst)
		ToonStylerScript.style(inst, ToonStylerScript.category_for(file), null,
			ToonStylerScript.lift_for(file))
	print("LOOK_OK")
	quit()


## Back to the imported materials, so style() converts them again.
func _bare(n: Node) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, null)


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).get_aabb()
		b = (m as MeshInstance3D).transform * b
		box = b if first else box.merge(b)
		first = false
	return box
