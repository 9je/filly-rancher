extends "res://test_input/input_test.gd"
## fixed-fps: 144
## PLAYTEST NOTE "The camera showed under the terrain in places." (docs/playtest_fixes/camera.md)
##
## A fresh game, played from the title screen. The pony is walked with real keys (W held, the
## mouse steering) to every kind of ground the map has -- the flat yard, the steepest slope,
## the highest hill top, the deepest hollow, building walls, building ramps and interiors,
## under trees, through the town, the Palace, and the invisible wall at the map's edge -- and
## at every stop the camera is swept with the mouse through a full turn of yaw and its full
## pitch range (both ends, including looking UP, which swings the lens low behind her), at
## the widest, the default and the tightest zoom (mouse wheel / zoom keys).
##
## 144 FRAMES A SECOND, NOT 60 (the header line above; tools/run_input_tests.sh reads it). The
## owner's monitor draws more frames than the 60 Hz physics tick, and the mouse turns the
## camera on every one of them. A 60 fps run draws exactly one frame per tick and hides
## everything that happens between ticks. Mouse motion is sent on every RENDERED frame here,
## the way a real mouse reports it.
##
## EVERY RENDERED FRAME, from a watcher node that runs after every other node's _process (so
## what is checked is exactly what is about to be drawn), the active camera must be:
##   * at least CLEARANCE above the ground's RENDERED surface under it -- the triangle the
##     terrain mesh actually draws there, not the smooth height_at() it was sampled from;
##   * with all four corners of its near plane above that surface too (a lens above the grass
##     whose near plane dips into it still shows the underside of the world);
##   * inside the map (outside it there is no ground at all, only the void under it);
##   * not inside any building or prop collider (point query on PROPS | CANOPY), and with no
##     collider cutting its near plane (a ball as big as the near plane's corners);
##   * not THROUGH anything: the rig's own two legs (pivot -> mount, mount -> lens) must not
##     cross the world.
## The test only READS the game to check it; everything it DOES goes through RealInput.

const TerrainScript := preload("res://world/terrain.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const CLEARANCE := 0.2
const YAW_STEPS := 12
## Where the frames are photographed (see _grab_pending()), when the env var is set.
var _shot_dir := OS.get_environment("FILLY_CAM_SHOT_DIR")
## A picture of the frame just drawn is wanted under this name (see _grab_pending()).
var _grab := ""
## stop name -> lowest lens clearance seen there, for the pictures.
var _lowest: Dictionary = {}
var _grabbed_at: Dictionary = {}
var _walled: Dictionary = {}

var terrain: Node3D
var _stop := "boot"
var _checking := false
var _frames := 0
var _bad_frames := 0
## stop name -> {count, worst: {clearance, kind, pos, yaw, pitch, zoom, arm}}
var _by_stop: Dictionary = {}
var _kinds: Dictionary = {}
var _printed_by: Dictionary = {}
## Game seconds, summed from the frame deltas by the watcher.
var _game_t := 0.0


func _play() -> void:
	_deadline_s = 4000.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	terrain = ranch.get_node("Terrain")
	# Runs after every other node's _process, so it sees exactly the transforms this frame is
	# about to be drawn with. (Not RenderingServer.frame_pre_draw: with the project's threaded
	# renderer that fires on the render thread, a frame late and part way through the game
	# thread's next frame.)
	var watcher := _Watcher.new()
	watcher.test = self
	watcher.process_priority = 1 << 30
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(watcher)
	_checking = true

	# Mouse-look must actually turn the camera, or the whole sweep is a no-op.
	await _clear_ui()
	var yaw0 := rig.global_rotation.y
	for i in 10:
		RI.look(Vector2(20, 0))
		await process_frame
	await process_frame
	var turned := absf(wrapf(rig.global_rotation.y - yaw0, -PI, PI))
	note("mouse look check: mouse_mode=%d, 200 px turned the camera %.3f rad (fps %d, physics %d Hz)" % [
		Input.mouse_mode, turned, Engine.get_frames_per_second(), Engine.physics_ticks_per_second])
	if not check(turned > 0.3, "mouse look does not turn the camera (mouse_mode %d)" % Input.mouse_mode):
		return

	var stops := _stops()
	for stop: Dictionary in stops:
		_stop = stop.name
		note("-> %s at (%.1f, %.1f) ground %.2f" % [stop.name, stop.at.x, stop.at.y,
			_surface(stop.at.x, stop.at.y)])
		# Travel looking up half the time: the lens swings low behind her across every slope.
		await _set_pitch(rig.PITCH_MAX_DEG if stops.find(stop) % 2 == 0 else -20.0)
		for w: Vector2 in stop.get("path", []):
			await _travel(Vector3(w.x, 0.0, w.y))
		await _travel(Vector3(stop.at.x, 0.0, stop.at.y))
		if stop.has("push"):
			await _push(Vector3(stop.push.x, 0.0, stop.push.y))
		note("   at %s %s" % [stop.name, player.global_position.snapped(Vector3.ONE * 0.01)])
		# FILLY_CAM_STOPS=a,b,... sweeps only those stops (the route is still walked in full):
		# for re-taking a few pictures without the whole forty minutes.
		var only := OS.get_environment("FILLY_CAM_STOPS")
		if only == "" or stop.name in only.split(","):
			await _sweep()

	_checking = false
	note("checked %d frames, %d bad" % [_frames, _bad_frames])
	for k: String in _kinds:
		note("  kind %s: %d frames" % [k, _kinds[k]])
	for s: String in _by_stop:
		var w: Dictionary = _by_stop[s].worst
		note("  stop %s: %d bad frames; worst %s clearance %.3f cam %s yaw %.0f pitch %.1f zoom %.1f arm %.2f" % [
			s, _by_stop[s].count, w.kind, w.clearance, w.pos, w.yaw, w.pitch, w.zoom, w.arm])
	for s: String in _lowest:
		note("  lowest lens over the ground at %s: %.3f m" % [s, _lowest[s]])
	if _bad_frames > 0:
		fail("%d of %d frames had the camera under or inside the world (at %s)" % [
			_bad_frames, _frames, ", ".join(_by_stop.keys())])
	else:
		ok("%d frames at %d stops, the camera never went under the terrain or into a building" % [
			_frames, stops.size()])


# --- the route ---------------------------------------------------------------------------

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _stops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hub := Vector2(0.0, 7.0)
	out.append({"name": "yard", "at": hub})
	# Building walls, ramps and interiors. Every leg goes back out to the open yard in front of
	# the door first, so the route never asks her to walk through a building.
	for bname: String in ["Barn", "Farmhouse", "Market", "Depot"]:
		var b := ranch.get_node_or_null("Buildings/" + bname) as Node3D
		if b == null:
			continue
		var xf := b.global_transform
		var foot: float = b.call("apron_foot_z")
		var dz: float = float(b.get("depth")) * 0.5
		var sx: float = float(b.get("width")) * 0.5 + 1.6
		var front := _flat(xf * Vector3(0, 0, foot + 5.0))
		var door := _flat(xf * Vector3(0, 0, foot + 0.8))
		out.append({"name": bname + "_ramp", "at": _flat(xf * Vector3(0, 0, foot - 1.3)),
			"path": [hub, front, door]})
		out.append({"name": bname + "_inside", "at": _flat(xf * Vector3(0, 0, -dz * 0.3)),
			"push": _flat(xf * Vector3(0.4, 0, -dz - 2.0))})
		if bname == "Barn" or bname == "Depot":
			# Out of the door and round the side to the back, pressed against the rear wall.
			var corner_front := _flat(xf * Vector3(sx, 0, foot + 1.5))
			var corner_back := _flat(xf * Vector3(sx, 0, -dz - 1.6))
			out.append({"name": bname + "_back_wall", "at": _flat(xf * Vector3(0, 0, -dz - 1.0)),
				"path": [door, front, corner_front, corner_back],
				"push": _flat(xf * Vector3(0, 0, 0))})
			out.append({"name": bname + "_side_wall", "at": _flat(xf * Vector3(sx - 0.6, 0, 0)),
				"path": [corner_back], "push": _flat(xf * Vector3(0, 0, 0))})
			out.append({"name": bname + "_out", "at": front, "path": [corner_front]})
		else:
			out.append({"name": bname + "_out", "at": front, "path": [door]})
	out.append({"name": "yard_again", "at": hub})
	var tree := _nearest_tree(hub)
	if tree != Vector2.INF:
		out.append({"name": "under_tree", "at": tree + (hub - tree).normalized() * 1.2, "push": tree})
	# The town row on the north road, and a wall of it.
	out.append({"name": "town_road", "at": Vector2(1.5, 43.0), "path": [hub, Vector2(1.5, 12.0)]})
	out.append({"name": "town_wall", "at": Vector2(10.5, 43.0), "push": Vector2(15.0, 43.0)})
	out.append({"name": "palace_front", "at": Vector2(-4.0, 54.0), "path": [Vector2(1.5, 50.0)],
		"push": Vector2(-10.0, 61.6)})
	# Terrain extremes, found from the ground's own height function, outside fenced regions.
	var ext := _terrain_extremes()
	out.append({"name": "hill_top", "at": ext.high, "path": [Vector2(1.5, 50.0)]})
	out.append({"name": "steepest_slope", "at": ext.steep, "path": [Vector2(1.5, 30.0)]})
	out.append({"name": "valley", "at": ext.low})
	var edge := _edge_point()
	out.append({"name": "map_edge", "at": edge * 0.97, "push": edge * 1.05})
	var tree2 := _nearest_tree(edge)
	if tree2 != Vector2.INF and tree2.distance_to(edge) < 60.0:
		out.append({"name": "under_tree_far", "at": tree2 + (edge - tree2).normalized() * 1.2,
			"push": tree2})
	return out


func _terrain_extremes() -> Dictionary:
	var regions: Object = terrain.get("regions")
	var best := {"high": Vector2.ZERO, "low": Vector2.ZERO, "steep": Vector2.ZERO}
	var hi := -INF
	var lo := INF
	var st := -INF
	var x := -96.0
	while x <= 96.0:
		var z := -96.0
		while z <= 96.0:
			var p := Vector2(x, z)
			var clear := true
			if regions != null:
				for o: Vector2 in [Vector2.ZERO, Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
					if regions.call("region_at", p + o) != null:
						clear = false
			if clear:
				var h: float = terrain.call("height_at", x, z)
				var n: Vector3 = terrain.call("normal_at", x, z)
				if h > hi:
					hi = h
					best.high = p
				if h < lo:
					lo = h
					best.low = p
				if 1.0 - n.y > st:
					st = 1.0 - n.y
					best.steep = p
			z += 4.0
		x += 4.0
	note("terrain extremes: high %.2f at %s, low %.2f at %s, steepest %.1f deg at %s" % [
		hi, best.high, lo, best.low, rad_to_deg(acos(1.0 - st)), best.steep])
	return best


## A point on the map's edge, outside every region, on the highest ground along it -- where
## the boundary wall stands lowest above the ground.
func _edge_point() -> Vector2:
	var regions: Object = terrain.get("regions")
	var best := Vector2(100, 0)
	var hi := -INF
	var e := TerrainScript.HALF - 1.0
	var t := -90.0
	while t <= 90.0:
		for p: Vector2 in [Vector2(e, t), Vector2(-e, t), Vector2(t, e), Vector2(t, -e)]:
			if regions != null and regions.call("region_at", p * 0.9) != null:
				continue
			var h: float = terrain.call("height_at", p.x, p.y)
			if h > hi:
				hi = h
				best = p
		t += 6.0
	note("map edge: highest ground %.2f at %s" % [hi, best])
	return best


func _nearest_tree(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for n in ranch.get_node("Props").find_children("*", "StaticBody3D", true, false):
		if not n.has_meta(&"canopy"):
			continue
		var p := _flat((n as Node3D).global_position)
		var d := p.distance_to(from)
		if d < bd:
			bd = d
			best = p
	return best


# --- acting (RealInput only) -------------------------------------------------------------

func _clear_ui() -> void:
	var people: Node = ranch.get("people")
	var lp: Node = ranch.get("letter_panel")
	for i in 6:
		var busy := false
		if lp != null and bool(lp.call("is_open")):
			busy = true
			await click(lp.call("close_button_node"))
			await wait(0.3)
		if people != null and bool(people.call("is_talking")):
			busy = true
			await talk_through()
			await wait(0.3)
		if not busy:
			return


## One mouse nudge toward `point`, the way a person tracks where they are walking.
func _steer(point: Vector3) -> void:
	var sens: float = rig.get("mouse_sensitivity")
	var cam: Camera3D = rig.call("get_camera")
	var d := point - cam.global_position
	var err := wrapf(atan2(-d.x, -d.z) - rig.global_rotation.y, -PI, PI)
	RI.look(Vector2(clampf(-err / sens * 0.2, -60, 60), 0))


## Walk (W held, steering with the mouse) to `point`; back off and sidestep when blocked.
func _travel(point: Vector3, max_s := 60.0) -> void:
	await _clear_ui()
	var t0 := _game_time()
	var last := player.global_position
	var still_since := t0
	var side := 1
	var next_note := t0 + 8.0
	RI.press(&"move_forward")
	while _game_time() - t0 < max_s:
		var flat := Vector2(point.x - player.global_position.x, point.z - player.global_position.z)
		if flat.length() < 1.2:
			break
		_steer(point)
		await process_frame
		var now := _game_time()
		if player.global_position.distance_to(last) > 0.05:
			last = player.global_position
			still_since = now
		if now > next_note:
			next_note = now + 8.0
			note("   walking to %s: at %s, %.1f m to go" % [_flat(point),
				player.global_position.snapped(Vector3.ONE * 0.1), flat.length()])
			RI.release(&"move_forward")
			await _clear_ui()
			RI.press(&"move_forward")
		if now - still_since > 0.75:
			RI.release(&"move_forward")
			await _hold(&"move_back", 0.3)
			await _hold(&"move_right" if side > 0 else &"move_left", 0.7)
			side = -side
			still_since = _game_time()
			RI.press(&"move_forward")
	RI.release(&"move_forward")
	await physics(4)


## Keep walking into whatever is between her and `point` (a wall, a trunk, the edge of the
## world) for a second and a half, steering at it.
func _push(point: Vector3) -> void:
	RI.press(&"move_forward")
	var t0 := _game_time()
	while _game_time() - t0 < 1.5:
		_steer(point)
		await process_frame
	RI.release(&"move_forward")
	await physics(4)


func _hold(action: StringName, secs: float) -> void:
	RI.press(action)
	await wait(secs)
	RI.release(action)


func _game_time() -> float:
	return _game_t


## Mouse up or down until the look pitch reaches `target_deg`, one nudge per rendered frame.
func _set_pitch(target_deg: float) -> void:
	var sens: float = rig.get("mouse_sensitivity")
	var inv := -1.0 if bool(rig.get("invert_look")) else 1.0
	for i in 240:
		var err: float = target_deg - float(rig.call("get_look_pitch_degrees"))
		if absf(err) < 0.5:
			return
		# Mouse up (negative relative.y) looks up. At most ~5 degrees a frame, a brisk flick.
		var px := clampf(-deg_to_rad(err) / sens * inv, -25.0, 25.0)
		RI.look(Vector2(0, px))
		await process_frame


## Mouse wheel / zoom keys until the rig's rest length is `target`.
func _set_zoom(target: float) -> void:
	for i in 24:
		var z: float = rig.call("get_zoom_distance")
		if absf(z - target) < 0.26:
			return
		var action := &"zoom_out" if z < target else &"zoom_in"
		RI.press(action)
		await frames(2)
		RI.release(action)
		await frames(2)


func _sweep() -> void:
	var sens: float = rig.get("mouse_sensitivity")
	for zoom: float in [rig.SPRING_MAX, rig.SPRING_DEFAULT, rig.SPRING_MIN]:
		await _set_zoom(zoom)
		for yi in YAW_STEPS:
			# A turn of 1/YAW_STEPS, swept over a few frames rather than in one jump.
			for k in 6:
				RI.look(Vector2((TAU / YAW_STEPS) / sens / 6.0, 0))
				await process_frame
			# Full pitch range both ways, lingering at each end.
			await _set_pitch(rig.PITCH_MIN_DEG)
			await frames(4)
			await _set_pitch(rig.PITCH_MAX_DEG)
			await frames(8)
	await _set_zoom(rig.SPRING_DEFAULT)


## THE FRAME ITSELF, NOT A RE-POSED SHOT OF IT. The fault this test exists for lasts a frame
## or two (see camera_rig.gd, LENS_RADIUS): put the mouse back where it was and the arm has
## long since caught up. So _check_frame() marks the frame, and the next one grabs what the
## viewport just drew. Per stop, two pictures, each overwritten as the stop goes on:
##   <stop>.png       the frame with the LOWEST lens over the ground at this stop (under the
##                    ground before the fix; just the lowest the camera got after it);
##   <stop>_wall.png  the first frame at this stop whose lens was in or through a collider.
func _grab_pending() -> void:
	if _grab == "" or _shot_dir == "":
		_grab = ""
		return
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	img.save_png(_shot_dir.path_join("%s.png" % _grab))
	_grab = ""


# --- checking (reads only) ---------------------------------------------------------------

class _Watcher extends Node:
	var test: Object

	func _process(d: float) -> void:
		test.set("_game_t", float(test.get("_game_t")) + d)
		test.call("_check_frame")


## The height the terrain MESH draws at world XZ: the same 2 m grid and the same diagonal
## split terrain.gd's _build_mesh() uses ([i01, i00, i10] and [i11, i01, i10]).
func _surface(x: float, z: float) -> float:
	var c := TerrainScript.CELL
	var gx := (x + TerrainScript.HALF) / c
	var gz := (z + TerrainScript.HALF) / c
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := gx - ix
	var fz := gz - iz
	var x0 := -TerrainScript.HALF + ix * c
	var z0 := -TerrainScript.HALF + iz * c
	var h00: float = terrain.call("height_at", x0, z0)
	var h10: float = terrain.call("height_at", x0 + c, z0)
	var h01: float = terrain.call("height_at", x0, z0 + c)
	var h11: float = terrain.call("height_at", x0 + c, z0 + c)
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fx) * (h01 - h11) + (1.0 - fz) * (h10 - h11)


func _is_trimesh(body: CollisionObject3D) -> bool:
	for c in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is ConcavePolygonShape3D:
			return true
	return false


func _leg_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var rq := PhysicsRayQueryParameters3D.create(from, to,
		LayersScript.WORLD | LayersScript.CANOPY, [player.get_rid()])
	rq.hit_back_faces = true
	return space.intersect_ray(rq)


func _check_frame() -> void:
	_grab_pending()
	if not _checking or ranch == null or not is_instance_valid(ranch):
		return
	var cam := root.get_viewport().get_camera_3d()
	if cam == null:
		return
	_frames += 1
	var p := cam.global_position
	var kind := ""
	var clearance := p.y - _surface(p.x, p.z)
	if absf(p.x) > TerrainScript.HALF or absf(p.z) > TerrainScript.HALF:
		kind = "outside_map"
	elif clearance < 0.0:
		kind = "under_terrain"
	elif clearance < CLEARANCE:
		kind = "too_close_to_ground"
	if kind == "":
		var vp_size := root.get_viewport().get_visible_rect().size
		for corner: Vector2 in [Vector2.ZERO, Vector2(vp_size.x, 0), Vector2(0, vp_size.y), vp_size]:
			var q := cam.project_position(corner, cam.near)
			if q.y < _surface(q.x, q.z):
				kind = "near_plane_under_terrain"
				break
	var space := cam.get_world_3d().direct_space_state
	if kind == "":
		var pq := PhysicsPointQueryParameters3D.new()
		pq.position = p
		pq.collision_mask = LayersScript.PROPS | LayersScript.CANOPY
		# Only SOLID shapes have an inside. A tree's or a town house's collider is a trimesh
		# cut off at a height (props.gd, _add_low_collision()), an open shell whose "inside"
		# Jolt guesses by counting crossings and gets wrong next to the cut: the first run of
		# this test flagged a lens plainly outside a trunk, the trunk drawn from outside in its
		# own picture. A lens touching a trimesh is still caught, by the near-plane ball below.
		for hit: Dictionary in space.intersect_point(pq, 4):
			if not _is_trimesh(hit.collider as CollisionObject3D):
				kind = "inside_%s" % (hit.collider as Node).name
				break
	if kind == "":
		# The near plane must not cut a collider: a ball round the lens as big as the near
		# plane's own corners reach.
		var ball := SphereShape3D.new()
		ball.radius = cam.project_position(Vector2.ZERO, cam.near).distance_to(p)
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = ball
		sq.transform = Transform3D(Basis(), p)
		sq.collision_mask = LayersScript.PROPS | LayersScript.CANOPY
		var touching := space.intersect_shape(sq, 4)
		if not touching.is_empty():
			kind = "near_plane_in_%s" % (touching[0].collider as Node).name
	var legs := ""
	if cam == rig.call("get_camera"):
		# The rig's own two legs: out to the mount (the arm's) and mount -> lens (the shoulder
		# offset's). Geometry across either means the lens went THROUGH something. The arm leg
		# may start at her head or, when her head is under an eave the capsule walks beneath,
		# at the middle of her body: the lens must be reachable from one of them.
		var mount: Node3D = cam.get_parent()
		var body_centre := player.global_position + Vector3(0, 0.65, 0)
		var arm_hit := _leg_hit(space, rig.global_position, mount.global_position)
		if not arm_hit.is_empty() and not _leg_hit(space, body_centre, mount.global_position).is_empty():
			legs += " arm_leg_hits:%s@%.2f" % [(arm_hit.collider as Node).name,
				(arm_hit.position as Vector3).distance_to(rig.global_position)]
			if kind == "":
				kind = "through_%s" % (arm_hit.collider as Node).name
		var lens_hit := _leg_hit(space, mount.global_position, p)
		if not lens_hit.is_empty():
			legs += " shoulder_leg_hits:%s@%.2f" % [(lens_hit.collider as Node).name,
				(lens_hit.position as Vector3).distance_to(mount.global_position)]
			if kind == "":
				kind = "through_%s" % (lens_hit.collider as Node).name
	if _shot_dir != "" and _grab == "":
		if lowest_here and clearance < float(_grabbed_at.get(_stop, INF)) - 0.03:
			_grabbed_at[_stop] = clearance
			_grab = _stop
		elif (kind.begins_with("inside") or kind.begins_with("through") or kind.begins_with("near_plane_in")) \
				and not _walled.has(_stop):
			_walled[_stop] = kind
			_grab = _stop + "_wall"
			note("   picture %s_wall: %s cam %s" % [_stop, kind, p.snapped(Vector3.ONE * 0.01)])
	if kind == "":
		return
	_bad_frames += 1
	_kinds[kind] = int(_kinds.get(kind, 0)) + 1
	var rec := {"clearance": clearance, "kind": kind, "pos": p.snapped(Vector3.ONE * 0.01),
		"yaw": rad_to_deg(rig.global_rotation.y), "pitch": float(rig.call("get_look_pitch_degrees")),
		"zoom": float(rig.call("get_zoom_distance")), "arm": float(rig.call("get_arm_distance"))}
	var s: Dictionary = _by_stop.get(_stop, {"count": 0, "worst": {}})
	s.count += 1
	if s.worst.is_empty() or rec.clearance < s.worst.clearance:
		s.worst = rec
	_by_stop[_stop] = s
	# The first few of each kind of fault at each stop, so one noisy kind cannot hide another.
	var key := "%s|%s" % [_stop, kind]
	if int(_printed_by.get(key, 0)) < 3:
		_printed_by[key] = int(_printed_by.get(key, 0)) + 1
		var arm: SpringArm3D = rig.get_node("SpringArm3D")
		note("BAD [%s] %s cam %s ground %.3f clearance %.3f player %s yaw %.0f pitch %.1f zoom %.1f arm %.2f arm_hit %.2f lens_offset %s%s" % [
			_stop, kind, rec.pos, _surface(p.x, p.z), clearance,
			player.global_position.snapped(Vector3.ONE * 0.01), rec.yaw, rec.pitch, rec.zoom,
			rec.arm, arm.get_hit_length(), cam.position.snapped(Vector3.ONE * 0.01), legs])
