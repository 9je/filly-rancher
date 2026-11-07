extends SceneTree
## ITEM 3 RENDER: the creator's mark step with three stamps placed, sized and turned, and the
## pony on the turntable wearing the mark.
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func _drag(c: Control, a: Vector2, b: Vector2) -> void:
	c.call("press_at", a)
	for i in range(1, 9):
		c.call("drag_to", a.lerp(b, float(i) / 8.0))
	c.call("end_stroke")


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	for i in 90:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	cs.call("set_step", 1)
	for i in 10:
		await process_frame
	var canvas: Control = cs.call("canvas")
	var w: float = canvas.size.x
	cs.call("set_ink", 1)
	cs.call("stamp_symbol", &"talent:music")
	_drag(canvas, Vector2(w * 0.5, w * 0.5), Vector2(w * 0.34, w * 0.4))
	cs.call("set_ink", 4)
	cs.call("stamp_symbol", &"shape:star")
	var h: Dictionary = canvas.call("handle_points", 1)
	_drag(canvas, h.scale, h.scale - Vector2(w * 0.12, w * 0.12))
	_drag(canvas, Vector2(w * 0.5, w * 0.5), Vector2(w * 0.68, w * 0.36))
	cs.call("set_ink", 2)
	cs.call("stamp_symbol", &"shape:moon")
	h = canvas.call("handle_points", 2)
	var c: Vector2 = h.centre
	_drag(canvas, h.rotate, c + Vector2(-w * 0.2, -w * 0.1))
	_drag(canvas, Vector2(w * 0.5, w * 0.5), Vector2(w * 0.55, w * 0.72))
	await _shot("creator_stamps")
	var img: Image = canvas.call("image")
	img.resize(512, 512, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join("canvas_image.png"))
	print("STAMPS ", canvas.call("stamps"))
	print("HANDLES ", canvas.get_node_or_null(^"Handles"), " size ", (canvas.get_node(^"Handles") as Control).size, " sel ", canvas.call("selected"))
	var model: Node3D = cs.get("_model")
	print("MODEL ", model, " decals ", CutieMark.decals_of(model).size() if model != null else -1)
	for d in CutieMark.decals_of(model):
		print("DECAL ", d.name, " at ", d.global_position.snapped(Vector3.ONE*0.01), " size ", d.size, " scale ", d.global_basis.get_scale().snapped(Vector3.ONE*0.01))
	print("MODELSCALE ", model.global_basis.get_scale(), " aabb ", Props.world_aabb(model))
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.layers & CutieMark.MARK_LAYER:
			print("BODY ", mi.name, " layers ", mi.layers, " aabb ", (mi.global_transform * mi.get_aabb()))
	var tt := cs.get_node_or_null(^"Layout/Stage/Viewport/SubViewport/Turntable") as Node3D
	if tt != null:
		tt.set_process(false)
		tt.rotation.y = deg_to_rad(-90.0)
		cs.set("_drag_rest", 999.0)
	await _shot("creator_stamps_flank", 30)
	var sv := cs.get_node_or_null(^"Layout/Stage/Viewport/SubViewport") as SubViewport
	if sv != null:
		sv.get_texture().get_image().save_png(out.path_join("turntable_raw.png"))
		print("SUBVIEWPORT size ", sv.size, " cam ", sv.get_camera_3d(), " cam mask ", sv.get_camera_3d().cull_mask if sv.get_camera_3d() else -1)
	cs.call("surprise", 7)
	await _shot("creator_surprise_flank", 30)
	if sv != null:
		sv.get_texture().get_image().save_png(out.path_join("turntable_surprise_raw.png"))
	quit(0)
