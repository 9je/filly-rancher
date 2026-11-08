extends SceneTree
## P8 S4 EVIDENCE: the world's look at fixed views and times, for the lighting reset (docs/
## aaa-review-2026-11-08.md 2.1). A new game; five fixed lenses (the plaza from above, the
## farmhouse front, the long view to the Palace hill, the pens, the player close) at day, dusk,
## night and night in rain. Writes <view>_<time>.png; run before and after a look change and
## set the two side by side.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/look_world.gd -- --out=/abs/dir [--views=plaza,hill] [--times=day,night]
const Boot := preload("res://scenes/test/ps_boot.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const VIEWS := {
	"plaza": [Vector3(0, 8, 16), Vector3(0, 1, -8)],
	"houses": [Vector3(4, 2.4, -5), Vector3(1, 3.5, -18.5)],
	"hill": [Vector3(6, 3, -2), Vector3(-10, 6, 61.6)],
	"pens": [Vector3(-4, 3.2, 5), Vector3(-14, 0.6, 15)],
}
const TIMES := {
	"day": [WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR],
	"dusk": [WorldStateScript.Phase.DUSK, WorldStateScript.Weather.CLEAR],
	"night": [WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.CLEAR],
	"nightrain": [WorldStateScript.Phase.NIGHT, WorldStateScript.Weather.RAIN],
}
var out := ""
var views: Array = VIEWS.keys() + ["pony"]
var times: Array = TIMES.keys()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--views="):
			views = Array(a.substr(8).split(","))
		elif a.begins_with("--times="):
			times = Array(a.substr(8).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.frames(self, 60)
	var player: Node3D = ranch.get("player")
	var cam := Camera3D.new()
	cam.fov = 60.0
	ranch.add_child(cam)
	var n := 0
	for t: String in times:
		var w: Object = ranch.get("_world")
		w.call("pin", TIMES[t][0], TIMES[t][1])
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
		for v: String in views:
			if v == "pony":
				var at := player.global_position
				var fwd := -(player.get("visuals") as Node3D).global_basis.z
				cam.global_position = at + fwd * 3.2 + Vector3(1.2, 1.7, 0)
				cam.look_at(at + Vector3(0, 1.1, 0))
			else:
				cam.global_position = VIEWS[v][0]
				cam.look_at(VIEWS[v][1])
			cam.current = true
			await Boot.frames(self, 30)
			await Boot.shot(self, out, "%s_%s" % [v, t])
			n += 1
	print("LOOK_WORLD_OK %d" % n)
	quit(0)
