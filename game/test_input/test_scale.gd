extends "res://test_input/input_test.gd"
## PLAYTEST NOTE "Some house models are the same size as ponies. Scaling is inconsistent
## everywhere." (docs/playtest_fixes/scale.md). A fresh save, started from the real title
## screen with the mouse; then every asset standing in the world is measured by its
## world-space bounding box and held against SCALE.md's table, in pony heights (PH).
##
## 1 PH is MEASURED here, not typed: the player's own rendered body (hoof to ear/horn tip) in
## the world, the same pony every building is judged against on screen.
##
## The table is read from SCALE.md at the repo root (its "category" table and its "asset"
## table), so the doc and the test cannot disagree. Every visible piece of world geometry
## that no row of the asset table claims is an offence too ("unmapped"): a new prop cannot
## dodge the check by not being listed.
##
## The test only LOOKS at the world after booting it with RealInput; it changes nothing.

const PropsScript := preload("res://world/props.gd")
const BuildingScript := preload("res://world/building.gd")

var ph := 0.0
var categories: Dictionary = {}   # name -> {min, max, min_w}
var patterns: Array = []          # [[glob, category], ...] in table order
var rows: Array = []              # measured records
var _covered: Dictionary = {}     # node -> true: geometry a collector has already measured


func _play() -> void:
	_deadline_s = 400.0
	if not _read_table():
		return
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	# Let the world finish standing up (dressing, the valley, the people).
	await wait(3.0)
	ph = PropsScript.world_aabb(player.get("visuals")).size.y
	note("1 PH = %.3f m (the player's rendered height)" % ph)
	if not check(ph > 1.0 and ph < 4.0, "could not measure the pony: %.3f m" % ph):
		return
	_collect()
	_judge()


# --- SCALE.md -------------------------------------------------------------------------

func _read_table() -> bool:
	var path := ProjectSettings.globalize_path("res://").path_join("../SCALE.md")
	var f := FileAccess.open(path, FileAccess.READ)
	if not check(f != null, "SCALE.md not found at %s" % path):
		return false
	var mode := ""
	for raw in f.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("|"):
			mode = ""
			continue
		var cells: Array = []
		for c in line.trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(c.strip_edges().replace("`", ""))
		if cells.is_empty() or (cells[0] as String).begins_with("---") or (cells[0] as String).begins_with(":--"):
			continue
		if cells[0] == "category" and cells.size() >= 4:
			mode = "cat"
			continue
		if cells[0] == "asset" and cells.size() >= 2:
			mode = "asset"
			continue
		if mode == "cat":
			categories[cells[0]] = {"min": _num(cells[1]), "max": _num(cells[2]),
				"min_w": _num(cells[3]) if cells.size() > 3 else NAN}
		elif mode == "asset":
			patterns.append([cells[0], cells[1]])
	for p: Array in patterns:
		if not check(categories.has(p[1]), "SCALE.md maps '%s' to unknown category '%s'" % p):
			return false
	return check(categories.size() > 0 and patterns.size() > 0, "SCALE.md has no tables")


func _num(s: String) -> float:
	return NAN if s == "-" or s == "" else float(s)


func _category(asset: String) -> String:
	for p: Array in patterns:
		if asset.match(p[0]):
			return p[1]
	return ""


# --- measuring -------------------------------------------------------------------------

func _add(asset: String, where: String, height: float, width := NAN, box := AABB()) -> void:
	rows.append({"asset": asset, "where": where, "h": height, "w": width, "box": box})


func _cover(n: Node) -> void:
	_covered[n] = true


func _collect() -> void:
	var props: Node = ranch.get_node_or_null(^"Props")
	if props != null:
		for p: Node3D in props.call("get_placed"):
			var file: String = String(props.call("entry_of", p).get("file", p.name)).get_basename()
			var pb := PropsScript.world_aabb(p)
			_add(file, "Props (%.0f, %.0f)" % [p.global_position.x, p.global_position.z],
				pb.size.y, NAN, pb)
			_cover(p)
		for s: Node in props.call("get_skirts"):
			_cover(s)
	var buildings: Node = ranch.get_node_or_null(^"Buildings")
	for b: Node in (buildings.get_children() if buildings != null else []):
		if b is BuildingScript:
			_building(b)
		elif b is Node3D:
			_add(String(b.name).to_snake_case(), "Buildings/%s" % b.name,
				PropsScript.world_aabb(b).size.y)
			_cover(b)
	var regions: Node = ranch.get_node_or_null(^"Regions")
	for r: Node in (regions.get_children() if regions != null else []):
		if String(r.name).begins_with("Fence_"):
			var hinge := r.get_node_or_null(^"GateHinge") as Node3D
			if hinge != null:
				_add("region_fence", "Regions/%s gate" % r.name, PropsScript.world_aabb(hinge).size.y)
			_cover(r)
		elif r.name == &"Dressing":
			_dressing(r)
		elif String(r.name).begins_with("Water_"):
			_cover(r)
	var strip: Node = ranch.get_node_or_null(^"Strip")
	for s: Node in (strip.get_children() if strip != null else []):
		if s.name == &"Track":
			_track(s)
		elif String(s.name).begins_with("Lamp"):
			_add("strip_lamp", "Strip/%s" % s.name, PropsScript.world_aabb(s).size.y)
			_cover(s)
		elif String(s.name).begins_with("Marquee"):
			_cover(s)
	if strip != null and strip.get_node_or_null(^"MarqueeBoard") != null:
		_add("strip_marquee", "Strip/MarqueeBoard",
			PropsScript.world_aabb(strip.get_node(^"MarqueeBoard")).size.y)
	var plots: Node = ranch.get_node_or_null(^"Plots")
	for slot: Node in (plots.get_children() if plots != null else []):
		for c: Node in slot.get_children():
			if c.name == &"PlotMarks":
				_oriented(c, "plot_stake", "Plots/%s" % slot.name)
			elif c is Node3D and not (c is CollisionShape3D):
				_add(String(c.name).to_snake_case(), "Plots/%s/%s" % [slot.name, c.name],
					PropsScript.world_aabb(c).size.y)
				_cover(c)
	var spike := ranch.get_node_or_null(^"Spike") as Node3D
	if spike != null:
		_add("spike", "Spike", PropsScript.world_aabb(spike).size.y)
		_cover(spike)
	var frame: Node = ranch.get_node_or_null(^"ValleyFrame")
	for v: Node in (frame.get_children() if frame != null else []):
		if v is Node3D and v.name != &"Rainbow":
			_add(String(v.name).rstrip("0123456789"), "ValleyFrame/%s" % v.name,
				PropsScript.world_aabb(v).size.y)
		_cover(v)
	var act3: Node = ranch.get_node_or_null(^"Act3World")
	for a: Node in (act3.get_children() if act3 != null else []):
		if a is Node3D and not (a is CharacterBody3D):
			_add(String(a.name).rstrip("0123456789_").to_snake_case(), "Act3World/%s" % a.name,
				PropsScript.world_aabb(a).size.y)
		_cover(a)
	# Characters are the yardstick, not the thing measured; the sky, the ground and the UI are
	# not assets standing in the world.
	for skip in [^"Player", ^"Spawner", ^"People", ^"Attendants", ^"Terrain", ^"SkyRig",
			^"CaptureCamera", ^"HUD"]:
		var n := ranch.get_node_or_null(skip)
		if n != null:
			_cover(n)
	_unmapped_sweep()


## A Building: its worn model (or its own shell), and its doorway as the player meets it --
## the clear opening from the plinth's top board to the lintel, between the two front walls.
func _building(b: Node3D) -> void:
	_cover(b)
	var file: String = String(b.get("model_file")).get_file().get_basename()
	var model := b.get_node_or_null(^"Model") as Node3D
	var h: float = PropsScript.world_aabb(model).size.y if model != null \
		else PropsScript.world_aabb(b).size.y
	_add(file if file != "" else "shell_" + String(b.name).to_snake_case(),
		"Buildings/%s" % b.name, h, NAN, PropsScript.world_aabb(b))
	# The doorway, off the shell's own boxes (they stand, hidden or not, as the collision a
	# pony actually walks through): clear height from the top of the Floor slab she stands on
	# to the underside of the Lintel, clear width between the two front walls' inner faces.
	var floor_m := b.get_node_or_null(^"Floor") as MeshInstance3D
	var lintel := b.get_node_or_null(^"Lintel") as MeshInstance3D
	var left := b.get_node_or_null(^"WallFrontL") as MeshInstance3D
	var right := b.get_node_or_null(^"WallFrontR") as MeshInstance3D
	if float(b.get("door_width")) > 0.001 and floor_m != null and lintel != null \
			and left != null and right != null:
		var clear_h := PropsScript.world_aabb(lintel).position.y - PropsScript.world_aabb(floor_m).end.y
		var lb := left.mesh.get_aabb()
		var rb := right.mesh.get_aabb()
		var clear_w := (right.position.x + rb.position.x) - (left.position.x + lb.end.x)
		_add("door", "Buildings/%s door" % b.name, clear_h,
			absf(clear_w) * b.global_basis.get_scale().x)
	for c: Node in b.get_children():
		if c.name == &"LobbySign":
			_add("lobby_sign", "Buildings/%s/LobbySign" % b.name, PropsScript.world_aabb(c).size.y)


## The race track: its rails and their posts (fence), the finish wire's posts and the lane
## gate posts (structure and marker). The dirt and the painted lines are ground paint that
## follows the terrain, not something standing on it.
func _track(track: Node) -> void:
	_cover(track)
	for c: Node in track.get_children():
		if not (c is StaticBody3D):
			continue
		var asset := "race_rail"
		if c.name == &"Wire":
			asset = "race_wire_post"
		elif c.name == &"GatePosts":
			asset = "race_gate_post"
		_oriented(c, asset, "Strip/Track/%s" % c.name)


## Things laid along the ground (a race rail that climbs a hill, a stake row): each mesh's own
## box, upright, so the slope it follows is not read as its height.
func _oriented(root: Node, asset: String, where: String) -> void:
	_cover(root)
	var best := 0.0
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var box := m.mesh.get_aabb()
		var hgt := box.size.y * m.global_basis.get_scale().y
		# A flat painted mark (a lane line, the checker) is ground paint, not a standing thing.
		if hgt < 0.05:
			continue
		best = maxf(best, hgt)
	if best > 0.0:
		_add(asset, where, best)


## The regions' scattered dressing: MultiMeshes, one per (model, mesh part). Every instance
## of a model is the union of its parts' boxes at the same instance index.
func _dressing(root: Node) -> void:
	_cover(root)
	var groups: Dictionary = {}
	for mmi: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		var g: String = String(mmi.get_meta(&"dress_group", mmi.name))
		if not groups.has(g):
			groups[g] = {"model": String(mmi.get_meta(&"dress_model", mmi.name)), "parts": []}
		(groups[g].parts as Array).append(mmi)
	for g: String in groups:
		var parts: Array = groups[g].parts
		var count: int = (parts[0] as MultiMeshInstance3D).multimesh.instance_count
		for i in count:
			var box := AABB()
			var first := true
			for mmi: MultiMeshInstance3D in parts:
				var mm := mmi.multimesh
				if i >= mm.instance_count:
					continue
				var xf: Transform3D = mmi.global_transform * mm.get_instance_transform(i)
				var local := mm.mesh.get_aabb()
				for k in 8:
					var c: Vector3 = xf * local.get_endpoint(k)
					if first:
						box = AABB(c, Vector3.ZERO)
						first = false
					else:
						box = box.expand(c)
			var at := box.get_center()
			_add(String(groups[g].model), "Dressing (%.0f, %.0f)" % [at.x, at.z], box.size.y)


## Anything visible in the world that no collector above measured.
func _unmapped_sweep() -> void:
	var seen: Dictionary = {}
	for n in ranch.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or g is GPUParticles3D or g is CPUParticles3D:
			continue
		# A SubViewport's own little world (the creator's stage) is not the valley.
		if g.get_viewport() != ranch.get_viewport():
			continue
		var cur: Node = g
		var covered := false
		while cur != null and cur != ranch:
			if _covered.has(cur):
				covered = true
				break
			cur = cur.get_parent()
		if covered:
			continue
		var path := String(ranch.get_path_to(g))
		var top := path.get_slice("/", 0) + "/" + path.get_slice("/", 1)
		if seen.has(top):
			continue
		seen[top] = true
		rows.append({"asset": "", "where": "unmapped: " + top, "h": NAN, "w": NAN})


# --- judging ---------------------------------------------------------------------------

func _judge() -> void:
	var bad: Array[String] = []
	var per_asset: Dictionary = {}
	var report := PackedStringArray()
	report.append("1 PH = %.3f m" % ph)
	for r: Dictionary in rows:
		var asset: String = r.asset
		var cat := _category(asset) if asset != "" else ""
		var line := ""
		var ok_row := true
		if cat == "":
			ok_row = false
			line = "%s  %s  NO CATEGORY" % [asset if asset != "" else "?", r.where]
		else:
			var c: Dictionary = categories[cat]
			var h: float = r.h / ph
			ok_row = (is_nan(c.min) or h >= c.min) and (is_nan(c.max) or h <= c.max)
			var wtxt := ""
			if not is_nan(r.w):
				var w: float = r.w / ph
				wtxt = " w=%.2f" % w
				if not is_nan(c.min_w) and w < c.min_w:
					ok_row = false
			line = "%s [%s] h=%.2f PH (%.2f m)%s want %s..%s%s  %s" % [asset, cat, h, r.h,
				wtxt, _fmt(c.min), _fmt(c.max),
				"" if is_nan(c.min_w) else " w>=%.2f" % c.min_w, r.where]
		var rb: AABB = r.get("box", AABB())
		if rb.size != Vector3.ZERO:
			line += "  box x %.1f..%.1f z %.1f..%.1f" % [rb.position.x, rb.end.x, rb.position.z, rb.end.z]
		report.append(("ok   " if ok_row else "BAD  ") + line)
		var key: String = asset if asset != "" else r.where
		if not per_asset.has(key):
			per_asset[key] = {"n": 0, "bad": 0, "lo": INF, "hi": -INF, "cat": cat, "w": INF}
		var pa: Dictionary = per_asset[key]
		pa.n += 1
		if not is_nan(r.h):
			pa.lo = minf(pa.lo, r.h / ph)
			pa.hi = maxf(pa.hi, r.h / ph)
		if not is_nan(r.w):
			pa.w = minf(pa.w, r.w / ph)
		if not ok_row:
			pa.bad += 1
	for key: String in per_asset:
		var pa: Dictionary = per_asset[key]
		print("SCALE_ASSET %-28s %-14s n=%3d bad=%3d h=%.2f..%.2f PH%s" % [key, pa.cat, pa.n,
			pa.bad, pa.lo, pa.hi, "" if pa.w == INF else " w>=%.2f" % pa.w])
		if pa.bad > 0:
			if pa.cat == "":
				bad.append("%s (unmapped)" % key)
			else:
				var c: Dictionary = categories[pa.cat]
				bad.append("%s %s %.2f-%.2f PH not in %s-%s%s" % [key, pa.cat, pa.lo, pa.hi,
					_fmt(c.min), _fmt(c.max), "" if pa.w == INF else " w %.2f" % pa.w])
	_write_report(report)
	note("measured %d placements of %d assets" % [rows.size(), per_asset.size()])
	if bad.is_empty():
		ok("%d placements of %d assets all within SCALE.md (1 PH = %.2f m)"
			% [rows.size(), per_asset.size(), ph])
	else:
		fail("%d of %d assets off SCALE.md (1 PH = %.2f m): %s"
			% [bad.size(), per_asset.size(), ph, "; ".join(bad)])


func _fmt(v: float) -> String:
	return "-" if is_nan(v) else "%.2f" % v


func _write_report(lines: PackedStringArray) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/playtest_evidence/scale")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("test_scale_report.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
