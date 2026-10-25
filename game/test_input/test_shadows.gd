extends "res://test_input/input_test.gd"
## PLAYTEST NOTE "Weird shadows around the map, especially on distant hills."
##
## The steward is walked (WASD, mouse look) to three spots and looks at three things through
## her own camera: the homestead close up (NEAR, under 20 m), the pens (MID, 20 to 50 m) and
## the far hills (FAR, past 50 m), at dawn, noon and dusk. Each frame is judged against the
## TRUTH, not against taste: for every sampled pixel that lands on the ground, a physics ray
## to the sun says whether that point is really in shadow, and the frame says whether it was
## DRAWN in shadow (its brightness against the same frame drawn with the sun's shadow map
## off). Then she takes one small step and the same ground points are judged again.
##
##   SPECKLE  the GATE. Isolated pixels in the drawn-shadow mask on surfaces that are smooth in
##            the shadowless frame: acne, PCSS/PCF noise put through the toon step, cascade
##            banding broken into dots. Summed over every frame, per distance band.
##   FALSE    drawn dark, really lit      -> acne, banding, a shadow nobody cast
##   MISSING  drawn lit, really shadowed  -> peter-panning, a shadow that stops at a ring
##   POPPED   a ground point that changed across three steps forward, the sun held still
##            -> a split boundary or the max-distance fade sweeping across the ground
## FALSE, MISSING and POPPED are printed for every frame as diagnostics but do not gate: the
## truth behind them is a physics ray, and the colliders are not the meshes (no collider on
## foliage under 3 m, capsules for ponies), so they carry a few percent of noise either way.
##
## WHAT IS NOT PLAYER INPUT, and why it is allowed: the hour (the world clock is set and
## pinned, standing in for a player who plays at dawn; waiting 20 game minutes per sun angle
## under the runner buys nothing) and the reference frame with the sun's shadow switched off
## (an instrument, put back before the next input). Everything the steward DOES is RealInput.
##
## --dump=<abs dir> (or FILLY_SHADOW_DUMP in the environment) writes every judged frame as PNG.

const LayersScript := preload("res://world/collision_layers.gd")

## [name, elapsed seconds on the world clock]: dawn 8 deg, noon 60 deg, dusk 8 deg.
const HOURS := [["dawn", 90.0], ["noon", 390.0], ["dusk", 720.0]]
## Bands by camera distance, metres.
const BANDS := [["near", 0.0, 20.0], ["mid", 20.0, 50.0], ["far", 50.0, 400.0]]
## Pass marks. A point is counted only where the truth is unambiguous (see _truth), so a
## clean shadow map scores near zero on every one of these.
## Speckle ceilings per band, over every frame. Measured: the shipped sun before this fix
## scored near 0.0054 / mid 0.0026 / far 0.0036; tuned, 0.0002 / 0.0008 / 0.0019.
const MAX_SPECKLE := [0.001, 0.0015, 0.0025]
const STEP := 8

var dump := ""
var sun: DirectionalLight3D
var cam: Camera3D
var failures: PackedStringArray = []
var report: PackedStringArray = []
var _dbg: Array = []
var _k := Vector2.ONE
## Judged frames that ran to the end; a script error inside one must not read as clean.
var judged := 0
var _speck_sum := PackedInt64Array([0, 0, 0, 0, 0, 0])
var _only_views: PackedStringArray = []
var _only_hours: PackedStringArray = []


func _play() -> void:
	_deadline_s = 900.0
	dump = OS.get_environment("FILLY_SHADOW_DUMP")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--views="):
			_only_views = a.substr(8).split(",")
		elif a.begins_with("--hours="):
			_only_hours = a.substr(8).split(",")
		elif a.begins_with("--dump="):
			dump = a.substr(7)
			DirAccess.make_dir_recursive_absolute(dump)
	if dump != "":
		DirAccess.make_dir_recursive_absolute(dump)
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	sun = ranch.get_node("Sun") as DirectionalLight3D
	note("sun: max=%.0f splits=%.3f/%.3f/%.3f fade=%.2f bias=%.3f nbias=%.2f blur=%.2f ang=%.2f pancake=%.1f atlas=%d soft=%d" % [
		sun.directional_shadow_max_distance, sun.directional_shadow_split_1,
		sun.directional_shadow_split_2, sun.directional_shadow_split_3,
		sun.directional_shadow_fade_start, sun.shadow_bias, sun.shadow_normal_bias,
		sun.shadow_blur, sun.light_angular_distance, sun.directional_shadow_pancake_size,
		int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")),
		int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))])
	await _settle_welcome()
	# [name, where to stand, what to look at]
	var views := [
		["near", Vector3(10.0, 0.0, 14.0), Vector3(4.0, 0.5, 4.0)],
		["mid", Vector3(6.0, 0.0, 30.0), Vector3(-14.0, 0.0, 10.0)],
		["farN", Vector3(1.5, 0.0, 30.0), Vector3(-45.0, 0.0, -70.0)],
		["farE", Vector3(10.0, 0.0, 10.0), Vector3(95.0, 0.0, -10.0)],
		["farW", Vector3(1.5, 0.0, 50.0), Vector3(-80.0, 0.0, 60.0)],
	]
	if not _only_views.is_empty():
		views = views.filter(func(v): return v[0] in _only_views)
	var hours := HOURS.duplicate()
	if not _only_hours.is_empty():
		hours = hours.filter(func(h): return h[0] in _only_hours)
	for v in views:
		if not await walk_to(v[1], 2.0, 40.0):
			note("did not quite reach %s (at %s)" % [v[0], player.global_position])
		var aim: Vector3 = v[2]
		if v[0].begins_with("far"):
			# Down at the ground out there, so the far hills fill the middle of the frame.
			aim.y = float(ranch.get("terrain").call("height_at", aim.x, aim.z)) + 1.0
		await look_at_point(aim, true, 0.03, 240)
		await frames(20)
		for h in hours:
			_set_hour(h[1])
			await frames(12)
			await _judge("%s_%s" % [v[0], h[0]])
	for r in report:
		print(r)
	var summary: PackedStringArray = []
	for bi in BANDS.size():
		var sp := float(_speck_sum[bi * 2]) / maxf(1.0, float(_speck_sum[bi * 2 + 1]))
		print("SHADOW_SPECKLE %-4s %.5f (ceiling %.4f, %d px)" % [BANDS[bi][0], sp,
			MAX_SPECKLE[bi], _speck_sum[bi * 2 + 1]])
		summary.append("%s %.5f" % [BANDS[bi][0], sp])
		if sp > MAX_SPECKLE[bi]:
			failures.append("%s speckle %.5f > %.4f" % [BANDS[bi][0], sp, MAX_SPECKLE[bi]])
	if judged != views.size() * hours.size():
		fail("only %d of %d frames were judged" % [judged, views.size() * hours.size()])
	elif failures.is_empty():
		ok("shadows clean at every distance and hour (speckle %s)" % ", ".join(summary))
	else:
		fail("%d checks failed: %s (speckle %s)" % [failures.size(), "; ".join(failures), ", ".join(summary)])


## Marigold comes over and talks on a fresh save; listen, the way a person would.
func _settle_welcome() -> void:
	var people: Node = ranch.get("people")
	var lp: Node = ranch.get("letter_panel")
	var t := 0.0
	while t < 30.0 and not bool(people.call("is_talking")):
		if bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
		await wait(0.2)
		t += 0.2
	await talk_through()
	await wait(0.5)


func _set_hour(elapsed: float) -> void:
	var w: Object = ranch.get("_world")
	w.set("_pinned", false)
	w.call("set_elapsed", elapsed)
	w.call("pin", w.call("phase"), 0)
	ranch.get("sky_rig").call("apply_immediately", w)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _lum(img: Image, p: Vector2i) -> float:
	var c := img.get_pixelv(p)
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## Is the ground point really in the sun? null when the answer is not clean: the surface
## faces away (the toon band decides that, not the shadow map), a point half a metre away
## disagrees (a shadow edge, where a texel of honest softness is no artifact), a fat ray
## grazes something the thin one missed (a collider a little smaller than its mesh), or a
## pony is anywhere near the sun line (she moves, and her capsule is not her silhouette).
func _truth(space: PhysicsDirectSpaceState3D, p: Vector3, n: Vector3, to_sun: Vector3) -> Variant:
	if n.dot(to_sun) < 0.08:
		return null
	var world := LayersScript.TERRAIN | LayersScript.PROPS | LayersScript.CANOPY
	var t1 := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := n.cross(t1)
	var first: Variant = null
	for o: Vector3 in [Vector3.ZERO, t1 * 0.5, -t1 * 0.5, t2 * 0.5, -t2 * 0.5]:
		var from := p + o + n * 0.08
		var q := PhysicsRayQueryParameters3D.create(from, from + to_sun * 250.0)
		q.collision_mask = world
		var occluded := not space.intersect_ray(q).is_empty()
		if first == null:
			first = occluded
		elif occluded != first:
			return null
	if _sphere_hits(space, p + n * 0.9, to_sun, 2.5, LayersScript.CHARACTERS):
		return null
	if not bool(first) and _sphere_hits(space, p + n * 0.7, to_sun, 0.6, world):
		return null
	return first


func _sphere_hits(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, r: float,
		mask: int) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = r
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = dir * 120.0
	q.collision_mask = mask
	var res := space.cast_motion(q)
	return res.size() == 2 and res[0] < 1.0


func _judge(tag: String) -> void:
	cam = root.get_viewport().get_camera_3d()
	var space := (ranch as Node3D).get_world_3d().direct_space_state
	var to_sun := sun.global_basis.z.normalized()
	var lit_img: Image = await _grab()
	sun.shadow_enabled = false
	await frames(3)
	var ref_img: Image = await _grab()
	sun.shadow_enabled = true
	await frames(3)
	# The ground points, their truth and their drawn state.
	var pts: Array = []
	_dbg.clear()
	var size := lit_img.get_size()
	# The canvas_items stretch: the camera speaks in the viewport's base units (1920x1080),
	# the picture is in window pixels.
	_k = root.get_viewport().get_visible_rect().size / Vector2(size)
	var hud := _hud_mask(size)
	var bodies := _body_mask(cam, size)
	var gw := size.x / STEP + 1
	var dist := PackedFloat32Array()
	dist.resize(gw * (size.y / STEP + 1))
	dist.fill(-1.0)
	for y in range(0, size.y, STEP):
		for x in range(0, size.x, STEP):
			var px := Vector2i(x, y)
			if hud[y * size.x + x] != 0:
				continue
			var on_body := bodies[y * size.x + x] != 0
			var from := cam.project_ray_origin(Vector2(px) * _k)
			var q := PhysicsRayQueryParameters3D.create(from,
				from + cam.project_ray_normal(Vector2(px) * _k) * 600.0)
			q.collision_mask = LayersScript.TERRAIN | LayersScript.PROPS | LayersScript.CANOPY \
				| LayersScript.CHARACTERS
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				_dbg.append([px, Color.WHITE])
				continue
			dist[(y / STEP) * gw + x / STEP] = (hit.position as Vector3).distance_to(from)
			var col: Object = hit.collider
			if not (col is CollisionObject3D and ((col as CollisionObject3D).collision_layer
					& LayersScript.TERRAIN) != 0):
				_dbg.append([px, Color(0.5, 0.5, 0.5)])
				continue
			if on_body:
				continue
			var p: Vector3 = hit.position
			var truth: Variant = _truth(space, p, hit.normal, to_sun)
			if truth == null:
				_dbg.append([px, Color.BLACK])
				continue
			var ref := _lum(ref_img, px)
			if ref < 0.04:
				continue
			pts.append({"p": p, "px": px, "d": p.distance_to(from), "truth": truth,
				"ref": ref, "drawn": _lum(lit_img, px) < ref * 0.85})
	# A few steps forward, the sun held still: the same ground points again.
	RI.press(&"move_forward")
	await physics(18)
	RI.release(&"move_forward")
	await frames(8)
	var moved_img: Image = await _grab()
	var cam2 := root.get_viewport().get_camera_3d()
	var bodies2 := _body_mask(cam2, size)
	for e: Dictionary in pts:
		var p: Vector3 = e.p
		if cam2.is_position_behind(p):
			continue
		var s := cam2.unproject_position(p) / _k
		var px := Vector2i(s.round())
		if px.x < 0 or px.y < 0 or px.x >= size.x or px.y >= size.y or hud[px.y * size.x + px.x] != 0 \
				or bodies2[px.y * size.x + px.x] != 0:
			continue
		var from := cam2.project_ray_origin(Vector2(px) * _k)
		var q := PhysicsRayQueryParameters3D.create(from,
			from + cam2.project_ray_normal(Vector2(px) * _k) * 600.0)
		q.collision_mask = LayersScript.TERRAIN | LayersScript.PROPS | LayersScript.CANOPY \
			| LayersScript.CHARACTERS
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(p) > 0.25 + 0.004 * float(e.d):
			continue
		e["drawn2"] = _lum(moved_img, px) < float(e.ref) * 0.85
	if dump != "":
		lit_img.save_png(dump.path_join(tag + ".png"))
		ref_img.save_png(dump.path_join(tag + "_noshadow.png"))
		moved_img.save_png(dump.path_join(tag + "_step.png"))
		_save_marks(lit_img, pts, dump.path_join(tag + "_marks.png"))
	var speck := _speckle(lit_img, ref_img, hud, dist, gw)
	for b in BANDS:
		var lit := 0
		var falsed := 0
		var shad := 0
		var missed := 0
		var both := 0
		var popped := 0
		for e: Dictionary in pts:
			if float(e.d) < b[1] or float(e.d) >= b[2]:
				continue
			if bool(e.truth):
				shad += 1
				if not bool(e.drawn):
					missed += 1
			else:
				lit += 1
				if bool(e.drawn):
					falsed += 1
			if e.has("drawn2"):
				both += 1
				if bool(e.drawn2) != bool(e.drawn):
					popped += 1
		var fr := float(falsed) / maxf(1.0, lit)
		var mr := float(missed) / maxf(1.0, shad)
		var pr := float(popped) / maxf(1.0, both)
		var bi := BANDS.find(b)
		var sp := float(speck[bi * 2]) / maxf(1.0, float(speck[bi * 2 + 1]))
		report.append("SHADOW_METRIC %-11s %-4s speckle=%6.4f (%6d px)  lit=%4d false=%5.3f  shadowed=%4d missing=%5.3f  stepped=%4d popped=%5.3f" % [
			tag, b[0], sp, int(speck[bi * 2 + 1]), lit, fr, shad, mr, both, pr])
		_speck_sum[bi * 2] += speck[bi * 2]
		_speck_sum[bi * 2 + 1] += speck[bi * 2 + 1]
	judged += 1


## 1 where a visible HUD panel, button or label covers the pixel: the HUD is drawn over the
## world in both frames, so nothing under it can be judged.
func _hud_mask(size: Vector2i) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(size.x * size.y)
	var hud := ranch.get_node_or_null(^"HUD")
	var layers: Array = []
	if hud != null:
		layers.append(hud)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n != hud:
			layers.append(n)
	for layer in layers:
		for c in layer.find_children("*", "Control", true, false):
			var ctl := c as Control
			if not ctl.is_visible_in_tree() or not (ctl is Panel or ctl is PanelContainer
					or ctl is Button or ctl is Label or ctl is TextureRect or ctl is RichTextLabel):
				continue
			var xf := ctl.get_viewport().get_screen_transform() * ctl.get_global_transform_with_canvas()
			var r := xf * Rect2(Vector2.ZERO, ctl.size)
			var r0 := Vector2i(clampi(int(r.position.x) - 3, 0, size.x), clampi(int(r.position.y) - 3, 0, size.y))
			var r1 := Vector2i(clampi(int(r.end.x) + 3, 0, size.x), clampi(int(r.end.y) + 3, 0, size.y))
			if (r1 - r0).x * (r1 - r0).y > size.x * size.y / 3:
				continue
			for y in range(r0.y, r1.y):
				for x in range(r0.x, r1.x):
					m[y * size.x + x] = 1
	return m


## 1 where a pony (or a person) is drawn: her collider is a capsule, not her silhouette, so a
## ray past her ear lands on the ground behind a pixel that shows her coat.
func _body_mask(c: Camera3D, size: Vector2i) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(size.x * size.y)
	for b in ranch.find_children("*", "CharacterBody3D", true, false):
		var body := b as Node3D
		if not body.is_visible_in_tree() or body.global_position.distance_to(c.global_position) > 120.0:
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			var vi := mi as MeshInstance3D
			if not vi.is_visible_in_tree():
				continue
			var box := vi.global_transform * vi.get_aabb()
			for k in 8:
				var corner := box.get_endpoint(k)
				if c.is_position_behind(corner):
					continue
				var sp := c.unproject_position(corner) / _k
				lo = lo.min(sp)
				hi = hi.max(sp)
		if lo.x > hi.x:
			continue
		var r0 := Vector2i(clampi(int(lo.x) - 2, 0, size.x), clampi(int(lo.y) - 2, 0, size.y))
		var r1 := Vector2i(clampi(int(hi.x) + 2, 0, size.x), clampi(int(hi.y) + 2, 0, size.y))
		for y in range(r0.y, r1.y):
			for x in range(r0.x, r1.x):
				m[y * size.x + x] = 1
	return m


## SPECKLE: the share of judged pixels whose drawn shadow state (dark against the shadowless
## frame) disagrees with at least 7 of its 8 neighbours. A real shadow is a region with an
## edge; no honest shadow is one pixel across, so an isolated pixel is acne, PCF or PCSS noise
## pushed through the toon step, or cascade banding broken into dots. Judged only where the
## shadowless frame is SMOOTH (its 3x3 brightness within 12%), so a silhouette, a fence wire
## or a pony that moved between the two frames is never mistaken for one. Per band:
## [isolated, judged] x 3, a pixel's band being the camera distance of its grid cell.
func _speckle(lit_img: Image, ref_img: Image, hud: PackedByteArray, dist: PackedFloat32Array,
		gw: int) -> PackedInt32Array:
	var w := lit_img.get_width()
	var h := lit_img.get_height()
	var a := lit_img.duplicate() as Image
	var b := ref_img.duplicate() as Image
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	var dark := PackedByteArray()
	dark.resize(w * h)
	var lum := PackedInt32Array()
	lum.resize(w * h)
	for i in w * h:
		var la := 299 * da[i * 3] + 587 * da[i * 3 + 1] + 114 * da[i * 3 + 2]
		var lb := 299 * db[i * 3] + 587 * db[i * 3 + 1] + 114 * db[i * 3 + 2]
		lum[i] = lb if hud[i] == 0 else 0
		dark[i] = 1 if la * 100 < lb * 85 else 0
	var out := PackedInt32Array()
	out.resize(6)
	for y in range(1, h - 1):
		var row := y * w
		for x in range(1, w - 1):
			var i := row + x
			var lb := lum[i]
			if lb < 10000:
				continue
			var d := dist[(y / STEP) * gw + x / STEP]
			if d < 0.0:
				continue
			var lo := lb
			var hi := lb
			var v := dark[i]
			var diff := 0
			for j: int in [i - w - 1, i - w, i - w + 1, i - 1, i + 1, i + w - 1, i + w, i + w + 1]:
				var l := lum[j]
				lo = mini(lo, l)
				hi = maxi(hi, l)
				if dark[j] != v:
					diff += 1
			if (hi - lo) * 100 >= lb * 12:
				continue
			var bi := 0 if d < 20.0 else (1 if d < 50.0 else 2)
			out[bi * 2 + 1] += 1
			if diff >= 7:
				out[bi * 2] += 1
	return out


## The judged frame with every counted point marked: green agreed, red FALSE, blue MISSING,
## yellow POPPED.
func _save_marks(img: Image, pts: Array, path: String) -> void:
	var m := img.duplicate() as Image
	for d: Array in _dbg:
		m.set_pixelv(d[0], d[1])
	_dbg.clear()
	for e: Dictionary in pts:
		var c := Color(0.1, 0.9, 0.2)
		if bool(e.truth) and not bool(e.drawn):
			c = Color(0.1, 0.3, 1.0)
		elif not bool(e.truth) and bool(e.drawn):
			c = Color(1.0, 0.1, 0.1)
		elif e.has("drawn2") and bool(e.drawn2) != bool(e.drawn):
			c = Color(1.0, 0.9, 0.0)
		var px: Vector2i = e.px
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := px + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < m.get_width() and q.y < m.get_height():
					m.set_pixelv(q, c)
	m.save_png(path)
