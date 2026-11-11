extends SceneTree
## P9 W3 item 30: watch the grand pen for a while from the player's camera and log each penned
## body's skeleton root-bone tilt, to catch a pony lying on her side.
##   -s res://scenes/test/laneb_pen_watch.gd -- --out=<dir> [--frames=<n>] [--every=<frames>]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var frames := 1800
var every := 300


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--every="):
			every = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _bone_tilt(b: Node3D) -> String:
	var sk := b.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return "nosk"
	var worst := 0.0
	var worst_name := ""
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) != -1:
			continue
		var g := sk.global_transform * sk.get_bone_global_pose(i)
		for j in sk.get_bone_count():
			var n := sk.get_bone_name(j).to_lower()
			if n.contains("spine") or n.contains("hips") or n.contains("pelvis") or n.contains("root") or n.contains("body"):
				var gj := sk.global_transform * sk.get_bone_global_pose(j)
				var t := rad_to_deg(gj.basis.y.normalized().angle_to(g.basis.y.normalized()))
				if t > worst:
					worst = t
					worst_name = sk.get_bone_name(j)
	var root_up := (sk.global_transform * sk.get_bone_global_pose(0)).basis
	return "root=%s up=%s worst=%s %.0f" % [sk.get_bone_name(0), root_up.y.normalized(), worst_name, worst]


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var pens: Array = Boot.pens(ranch)
	var pen: Pen = pens[pens.size() - 1]
	var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
	var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
	var at := pen.global_position + outward * (Pen.HALF_EXTENT + 2.0) + outward.cross(Vector3.UP) * 2.5
	for f in frames:
		if f % every == 0:
			Boot.stand(ranch, at, pen.global_position)
			for p: Pen in pens:
				for inst in p.ponies():
					var b := p.body_for(inst.uid)
					if b == null:
						continue
					var anim := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
					print("F%d %s %s anim=%s %s" % [f, p.name, inst.display_name(),
						anim.current_animation if anim else "-", _bone_tilt(b)])
			await Boot.shot(self, out.path_join("watch_%04d.png" % f), 2)
		await process_frame
	print("LANEB_WATCH_OK")
	quit(0)
