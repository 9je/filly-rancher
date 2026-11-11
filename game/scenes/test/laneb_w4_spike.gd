extends SceneTree
## P9 W4 item 71: Spike's wave (the clip he plays when she comes up or asks for a tip), from the
## gameplay camera in front of him, a frame every 0.25 s; plus his clip list.
##   -s res://scenes/test/laneb_w4_spike.gd -- --out=<dir> [--clip=wave]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var clip := "wave"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--clip="):
			clip = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var spike: Node3D = ranch.get_node(^"Spike")
	var at := spike.global_position + Vector3(-1.2, 0.0, 2.6)
	Boot.stand(ranch, at, spike.global_position)
	var rig: Node = ranch.get("player").get_node(^"CameraPivot/CameraRig")
	rig.call("add_zoom_delta", 1.4 - float(rig.call("get_zoom_distance")))
	for i in 60:
		await process_frame
	var ap: AnimationPlayer = spike.call("animation_player")
	print("CLIPS ", ap.get_animation_list())
	var sk: Skeleton3D = spike.find_child("Skeleton3D", true, false)
	var names := []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if "Arm" in n or "Hand" in n or "arm" in n or "hand" in n:
			names.append(n)
	print("BONES ", names)
	ap.play(clip, 0.1)
	for k in 8:
		await Boot.shot(self, out.path_join("%s_%02d.png" % [clip, k]), 15)
	var imgs: Array[Image] = []
	for k in 8:
		var im := Image.load_from_file(out.path_join("%s_%02d.png" % [clip, k]))
		im = im.get_region(Rect2i(500, 100, 600, 700))
		im.resize(300, 350)
		imgs.append(im)
	var sheet := Image.create(1200, 700, false, imgs[0].get_format())
	for k in 8:
		sheet.blit_rect(imgs[k], Rect2i(0, 0, 300, 350), Vector2i((k % 4) * 300, (k / 4) * 350))
	sheet.save_png(out.path_join("sheet_%s.png" % clip))
	print("SPIKE_OK")
	quit()
