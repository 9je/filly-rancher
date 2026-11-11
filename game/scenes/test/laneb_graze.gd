extends SceneTree
## P9 W3 item 30 diagnosis: every penned pony on the loaded save, frozen in a clip (default
## graze), seen side-on from 3 m. A pony lying on her side shows plainly here.
##   -s res://scenes/test/laneb_graze.gd -- --out=<dir> [--clip=graze]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var clip := "graze"


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
	var cam := Camera3D.new()
	ranch.add_child(cam)
	for pen: Pen in Boot.pens(ranch):
		for inst in pen.ponies():
			var b := pen.body_for(inst.uid) as Node3D
			if b == null:
				continue
			b.process_mode = Node.PROCESS_MODE_DISABLED
			var anim := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
			anim.process_mode = Node.PROCESS_MODE_ALWAYS
			if anim.has_animation(clip):
				anim.play(clip)
				anim.seek(0.5, true)
			var vis := b.get("visuals") as Node3D
			var fwd := -vis.global_transform.basis.z
			var side := fwd.cross(Vector3.UP).normalized()
			cam.global_position = b.global_position + side * 3.2 + Vector3.UP * 1.2
			cam.look_at(b.global_position + Vector3.UP * 0.7)
			cam.make_current()
			await Boot.shot(self, out.path_join("%s_%s.png" % [clip, inst.display_name().replace(" ", "_")]), 6)
			b.process_mode = Node.PROCESS_MODE_INHERIT
	print("LANEB_GRAZE_OK")
	quit(0)
