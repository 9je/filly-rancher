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
	"houses": [Vector3(8, 2.5, -20), Vector3(1.5, 3.5, -35.5)],
	"hill": [Vector3(6, 3, -2), Vector3(-10, 6, 61.6)],
	"pens": [Vector3(-14, 3.2, 4), Vector3(-29, 0.6, 16)],
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
## --small: 960x540, about a third of the cost on the software renderer.
var small := false
var _extra := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--views="):
			views = Array(a.substr(8).split(","))
		elif a == "--small":
			small = true
		elif a.begins_with("--times="):
			times = Array(a.substr(8).split(","))
		elif a.begins_with("--cams="):
			# Extra lenses: name:x,y,z,tx,ty,tz;name2:... (each also added to --views).
			for c: String in a.substr(7).split(";"):
				var kv := c.split(":")
				var n := PackedFloat64Array(Array(kv[1].split(",")).map(func(v: String) -> float: return float(v)))
				_extra[kv[0]] = [Vector3(n[0], n[1], n[2]), Vector3(n[3], n[4], n[5])]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	if small:
		root.get_window().size = Vector2i(960, 540)
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
		var lamps: Node = ranch.get_node_or_null(^"NightLights")
		if lamps != null:
			lamps.call("set_level", 0.0 if t == "day" else 1.0)
		for v: String in views:
			if v == "pony":
				var at := player.global_position
				var fwd := -(player.get("visuals") as Node3D).global_basis.z
				cam.global_position = at + fwd * 3.2 + Vector3(1.2, 1.7, 0)
				cam.look_at(at + Vector3(0, 1.1, 0))
			else:
				var lens: Array = _extra[v] if _extra.has(v) else VIEWS[v]
				cam.global_position = lens[0]
				cam.look_at(lens[1])
			cam.current = true
			await Boot.frames(self, 30)
			await Boot.shot(self, out, "%s_%s" % [v, t])
			n += 1
	print("LOOK_WORLD_OK %d" % n)
	quit(0)
