extends SceneTree
## P9 W3 (items 30, 32): the pens as the owner walks up to them on a loaded save. The player
## stands outside each pen's gate and the GAMEPLAY camera (not a probe camera) frames it.
## Prints every penned body's tilt so a pony lying on her side shows as a number too.
##   -s res://scenes/test/laneb_pen.gd -- --out=<dir> [--wait=<seconds>]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var wait := 6.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--wait="):
			wait = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _tilts(pens: Array, tag: String) -> void:
	for pen: Pen in pens:
		for inst in pen.ponies():
			var b := pen.body_for(inst.uid)
			if b == null:
				continue
			var vis := b.get("visuals") as Node3D
			var up := vis.global_transform.basis.y.normalized() if vis != null else Vector3.UP
			var tilt := rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
			var anim := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
			print("TILT %s %s %s tilt=%.1f anim=%s state=%s pos=%s" % [tag, pen.name, inst.display_name(),
				tilt, anim.current_animation if anim else "-", b.get("state"), b.global_position])


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var pens: Array = Boot.pens(ranch)
	_tilts(pens, "boot")
	var t := 0.0
	while t < wait:
		await process_frame
		t += 1.0 / 60.0
	_tilts(pens, "later")
	var i := 0
	for pen: Pen in pens:
		var side: int = posmod(int(round(pen.gate_yaw_degrees / 90.0)), 4)
		var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
		var at := pen.global_position + outward * (Pen.HALF_EXTENT + 3.5)
		Boot.stand(ranch, at, pen.global_position)
		await Boot.shot(self, out.path_join("pen_%d.png" % i), 40)
		i += 1
	print("LANEB_PEN_OK")
	quit(0)
