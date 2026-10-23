extends SceneTree
## THE HUMAN-PACED BOT (tools/pacing.sh, and the FIRST_10_MINUTES recording): a fresh save
## played the way a person plays it, through the person's own verbs. It walks (a navmesh
## baked from the world's colliders, so it goes round fences instead of into them), turns the
## camera to look where it is going, sneaks up on a pony, holds the Scoop on her until she is
## secured, presses E at the prompts, reads what people say at a reading pace, and shops from
## a list when it can afford the next thing. Nothing is teleported, forced or granted.
##
## Run headless with --fixed-fps 60 and the play clock (GameState.play_seconds) is simulated
## real time, so the Novelty log it leaves is a pacing measurement; run windowed under Movie
## Maker and the same play is a recording.
##
##   tools/bin/godot --headless --fixed-fps 60 --audio-driver Dummy --path game \
##       -s res://scenes/test/human_bot.gd -- [--minutes=75] [--pacing=../PACING.md] [--seed=7]
##
## Prints BOT_OK (and PACING_OK / PACING_FAILED with --pacing) when the run is over.

const RANCH := "res://world/ranch.tscn"
const BootIntentScript := preload("res://world/boot_intent.gd")
const InteractionScript := preload("res://world/interaction.gd")
const NoveltyScript := preload("res://systems/novelty.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")

## Human pacing: reading speed (characters a second), a think before each menu choice, and
## the turn rate of the camera.
const READ_CPS := 22.0
const THINK := Vector2(0.6, 1.6)
const TURN_DEG_S := 150.0
const RUN_ARRIVE := 1.4
const CATCH_RANGE := 6.5
const SNEAK_RANGE := 11.0

var minutes := 75.0
var pacing_path := ""
var seed_value := 7
var video := false
var ranch: Node
var player: CharacterBody3D
var rig: Node3D
var gs: Node
var rng := RandomNumberGenerator.new()

# The virtual controller, driven every physics frame by _control().
var _path: PackedVector3Array = []
var _path_i := 0
var _arrived := true
var _look_at := Vector3.INF
var _aim := false
var _sneak := false
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _unstick_t := 0.0
var _unstick_dir := 1.0
var _stuck_count := 0
var _nav_map: RID
var _nav_region: NavigationRegion3D
var _nav_dirty := false
var _log: Array[String] = []
var _done := false
var _sighted_only := false
var _palace_visits := 0
var _last_palace := -9999.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = float(a.substr(10))
		elif a.begins_with("--pacing="):
			pacing_path = a.substr(9)
		elif a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a == "--video":
			video = true
	rng.seed = seed_value
	_run.call_deferred()


func _run() -> void:
	BootIntentScript.bot = true
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file(RANCH)
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and ranch.get("player") != null and i > 30:
			break
	player = ranch.get("player")
	rig = player.get_camera_pivot().get_node("CameraRig")
	gs = root.get_node("GameState")
	await _bake_nav()
	physics_frame.connect(_control)
	await _brain()
	_finish()


# --- the clock -------------------------------------------------------------------------

func _t() -> float:
	return float(gs.get("play_seconds"))


func _say(s: String) -> void:
	var line := "BOT %s %s" % [NoveltyScript.clock(_t()), s]
	print(line)
	_log.append(line)


func _wait(seconds: float) -> void:
	var until := _t() + seconds
	while _t() < until:
		await process_frame


func _think() -> void:
	await _wait(rng.randf_range(THINK.x, THINK.y))


# --- the navmesh -------------------------------------------------------------------------

func _bake_nav() -> void:
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "BotNav"
	ranch.add_child(_nav_region)
	await _rebake()


func _rebake() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.55
	nm.agent_height = 1.3
	nm.agent_max_climb = 0.45
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.3
	nm.cell_height = 0.2
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# The ground and everything solid on it (terrain | props); never characters, triggers or the
	# pen gates a person walks through.
	nm.geometry_collision_mask = (1 << 0) | (1 << 1)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, ranch)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	_nav_region.navigation_mesh = nm
	_nav_map = _nav_region.get_navigation_map()
	for i in 3:
		await physics_frame
	_nav_dirty = false


func _path_to(to: Vector3) -> PackedVector3Array:
	if not _nav_map.is_valid():
		return PackedVector3Array([to])
	var from := player.global_position
	var p := NavigationServer3D.map_get_path(_nav_map, from, to, true)
	if p.is_empty():
		return PackedVector3Array([to])
	return p


# --- the virtual controller --------------------------------------------------------------

func _control() -> void:
	if _done or not is_instance_valid(player) or rig == null:
		return
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var cam: Camera3D = rig.call("get_camera")
	# Where to look: the aim point when aiming, else a little way along the path.
	var look := _look_at
	var walking := not _arrived and _path_i < _path.size()
	if walking and not _aim:
		look = _lookahead()
	if look != Vector3.INF and cam != null:
		var from := cam.global_position if _aim else player.global_position
		var d := look - from
		var yaw_t := atan2(-d.x, -d.z)
		var err := wrapf(yaw_t - rig.global_rotation.y, -PI, PI)
		var rate := deg_to_rad(TURN_DEG_S) * dt
		var step := clampf(err * (1.0 - exp(-7.0 * dt)) * 1.6, -rate, rate)
		rig.call("add_look_delta", -step, 0.0)
		var flat := Vector2(d.x, d.z).length()
		var pitch_t := rad_to_deg(atan2(d.y, maxf(flat, 0.01))) if _aim else -10.0
		var pe := pitch_t - float(rig.call("get_look_pitch_degrees"))
		rig.call("add_look_delta", 0.0, -deg_to_rad(clampf(pe * 0.12, -2.5, 2.5)))
	# Walking.
	if walking:
		var target := _path[_path_i]
		var to := target - player.global_position
		to.y = 0.0
		var last := _path_i == _path.size() - 1
		if to.length() < (RUN_ARRIVE if last else 0.9):
			_path_i += 1
			if _path_i >= _path.size():
				_stop()
				return
		var fwd := -rig.global_basis.z
		fwd.y = 0.0
		var facing := fwd.normalized().dot(to.normalized()) if to.length() > 0.01 else 1.0
		var strength := clampf((facing - 0.2) / 0.6, 0.15, 1.0)
		if _unstick_t > 0.0:
			_unstick_t -= dt
			Input.action_press(&"move_right" if _unstick_dir > 0.0 else &"move_left", 1.0)
			Input.action_press(&"move_forward", 0.6)
		else:
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			Input.action_press(&"move_forward", strength)
		_press_sneak(_sneak)
		# Stuck on something the navmesh did not know: step sideways and hop.
		_stuck_t += dt
		if _stuck_t > 1.2:
			if player.global_position.distance_to(_last_pos) < 0.35:
				_unstick_t = 0.7
				_unstick_dir = -_unstick_dir
				_stuck_count += 1
			else:
				_stuck_count = 0
			_stuck_t = 0.0
			_last_pos = player.global_position
		# Up on something (a fence top, a crate): hop down toward the walkable ground.
		if _nav_map.is_valid() and Engine.get_physics_frames() % 30 == 0:
			var ground := NavigationServer3D.map_get_closest_point(_nav_map, player.global_position)
			if player.global_position.y - ground.y > 0.9 and player.is_on_floor():
				Input.action_press(&"jump")
			else:
				Input.action_release(&"jump")
	else:
		Input.action_release(&"move_forward")


func _lookahead() -> Vector3:
	var at := player.global_position
	var left := 3.0
	var i := _path_i
	var p := at
	while i < _path.size():
		var seg := _path[i] - p
		seg.y = 0.0
		if seg.length() >= left:
			return p + seg.normalized() * left + Vector3(0, 0.8, 0)
		left -= seg.length()
		p = _path[i]
		i += 1
	return _path[_path.size() - 1] + Vector3(0, 0.8, 0)


func _press_sneak(on: bool) -> void:
	if on:
		Input.action_press(&"sneak")
	else:
		Input.action_release(&"sneak")


func _stop() -> void:
	_arrived = true
	_path = PackedVector3Array()
	_path_i = 0
	Input.action_release(&"move_forward")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")


## Walk to `to` (re-pathing as it goes). Returns whether she got within `arrive`.
func _walk(to: Vector3, arrive: float = RUN_ARRIVE, timeout: float = 90.0) -> bool:
	if _nav_dirty:
		await _rebake()
	_aim = false
	var t0 := _t()
	var repath := 0.0
	_path = _path_to(to)
	_path_i = 0
	_arrived = false
	while _t() - t0 < timeout:
		await physics_frame
		var gap := Vector2(player.global_position.x - to.x, player.global_position.z - to.z).length()
		if gap <= arrive:
			_stop()
			return true
		repath += 1.0 / 60.0
		if _arrived or repath > 3.0:
			repath = 0.0
			_path = _path_to(to)
			_path_i = 0
			_arrived = false
	_stop()
	if OS.has_environment("BOT_DEBUG"):
		var near := NavigationServer3D.map_get_closest_point(_nav_map, to)
		_say("walk failed at %s to %s (navmesh nearest %s, path %d)" % [player.global_position.snapped(Vector3.ONE * 0.1),
			to.snapped(Vector3.ONE * 0.1), near.snapped(Vector3.ONE * 0.1), _path_to(to).size()])
	return false


## Get to where E does `kind` (and, for TALK, to `subject`): walk to `at`, and if the prompt
## is somebody else's, try standing on other sides of it. Returns whether the prompt is right.
func _approach(kind: int, at: Vector3, arrive: float, subject: String = "") -> bool:
	await _walk(at, arrive)
	for i in 7:
		await _wait(0.25)
		var act: Dictionary = ranch.call("current_interaction")
		if int(act.get("kind", 0)) == kind and (subject == "" or str(act.get("subject", "")) == subject):
			return true
		if OS.has_environment("BOT_DEBUG"):
			_say("approach %d wants kind %d, prompt %s at %s" % [i, kind, act, player.global_position.snapped(Vector3.ONE * 0.1)])
		var ang := TAU * float(i) / 6.0 + rng.randf() * 0.5
		var spot := at + Vector3(cos(ang), 0, sin(ang)) * maxf(arrive * 0.8, 1.0)
		await _walk(spot, 0.45, 5.0)
	return false


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await process_frame
	Input.action_release(action)
	await process_frame


# --- what is where -------------------------------------------------------------------

func _people() -> Node:
	return ranch.get("people")


func _node_pos(path: NodePath) -> Vector3:
	var n := ranch.get_node_or_null(path) as Node3D
	return n.global_position if n != null else Vector3.INF


func _bag() -> Storage:
	var beam: Node3D = player.get_magic_beam()
	return beam.get_storage() if beam != null else null


func _beam() -> Node:
	return player.get_magic_beam()


func _story() -> Story:
	return gs.get("story")


func _bits() -> int:
	return int(gs.get("bits"))


func _slots() -> Array:
	return ranch.call("_plot_slots")


func _pens() -> Array:
	var out: Array = []
	for s in _slots():
		var pen := (s as Node).call("get_built") as Node
		if pen != null and pen.has_method("ponies"):
			out.append(pen)
	return out


func _menu_open() -> bool:
	return not bool(ranch.call("_no_other_menu_open"))


# --- the brain -------------------------------------------------------------------------

## The player's loop: whatever a person would do next, by priority, until the clock is up.
func _brain() -> void:
	await _creator()
	var end := minutes * 60.0
	while _t() < end:
		await _tend_menus()
		if await _talk_to_news():
			continue
		if await _read_mail():
			continue
		if await _build_first_pen():
			continue
		if await _build_more_pens():
			continue
		if await _pen_the_bag():
			continue
		if await _deliver_extras():
			continue
		if await _shop():
			continue
		if await _visit_palace():
			continue
		if await _hunt(_sighted()):
			continue
		if await _hunt():
			continue
		await _wander()


## The creator: a person spends a minute here. Try a few coats and manes, then go.
func _creator() -> void:
	var cs: Node = ranch.get("creation_screen")
	for i in 120:
		await process_frame
		if cs != null and bool(cs.call("is_open")):
			break
	if cs == null or not bool(cs.call("is_open")):
		return
	# A person spends a minute or two here: trying coats, manes, a style and the eyes, going
	# back on a couple, then a long look before saying yes.
	_say("the creator")
	await _wait(3.0)
	for i in 6:
		await _wait(rng.randf_range(1.5, 3.5))
		cs.call("cycle_coat", 1 + rng.randi() % 3)
	for i in 4:
		await _wait(rng.randf_range(1.5, 3.0))
		cs.call("cycle_mane", 1)
	for i in 3:
		await _wait(rng.randf_range(2.0, 4.0))
		cs.call("cycle_mane_style", 1)
	for i in 2:
		await _wait(rng.randf_range(1.5, 3.0))
		cs.call("cycle_eyes", 1)
	await _wait(rng.randf_range(6.0, 10.0))
	cs.call("confirm")
	await _wait(1.0)


## A letter on screen gets read, a talk box gets read through.
func _tend_menus() -> void:
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		await _wait(6.0 + rng.randf() * 4.0)
		lp.call("close")
		await _think()


func _talk_to_news() -> bool:
	var p := _people()
	if p == null:
		return false
	var best: StringName = &""
	var best_d := INF
	for id: StringName in p.get("npcs"):
		if not bool(p.call("has_news", id)):
			continue
		var n: Node3D = p.call("npc", id)
		if n == null:
			continue
		var d := n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = id
	if best == &"":
		return false
	var who: Node3D = p.call("npc", best)
	_say("walks over to talk to %s" % best)
	await _walk(who.global_position, 2.2)
	_look_at = who.global_position + Vector3(0, 1.0, 0)
	await _wait(0.6)
	var want := str(who.get("def").display_name) if who.get("def") != null else ""
	var act: Dictionary = ranch.call("current_interaction")
	var tries := 0
	while tries < 4 and (int(act.get("kind", 0)) != InteractionScript.Kind.TALK or str(act.get("subject", "")) != want):
		tries += 1
		# Somebody else is nearer and the prompt is theirs: go round to her far side.
		var away := who.global_position - player.global_position
		away.y = 0.0
		var side := who.global_position + away.normalized().rotated(Vector3.UP, rng.randf_range(-1.2, 1.2)) * 1.1
		await _walk(side, 0.5, 5.0)
		_look_at = who.global_position + Vector3(0, 1.0, 0)
		await _wait(0.4)
		act = ranch.call("current_interaction")
	if OS.has_environment("BOT_DEBUG"):
		_say("talk prompt %s, %.1f m" % [act, who.global_position.distance_to(player.global_position)])
	await _tap(&"interact")
	await _read_conversation()
	_look_at = Vector3.INF
	return true


func _read_conversation() -> void:
	var p := _people()
	var guard := 0
	while bool(p.call("is_talking")) and guard < 60:
		guard += 1
		var box: Node = p.get("talk_box")
		var runner: Object = p.get("runner")
		var line := ""
		if runner != null:
			line = str((runner.call("current") as Dictionary).get("text", ""))
		await _wait(maxf(1.4, line.length() / READ_CPS) if line != "" else 2.6)
		if not bool(p.call("is_talking")):
			break
		if runner != null and bool(runner.call("has_choices")):
			await _think()
			box.emit_signal("chose", 0)
		else:
			box.call("_accept")
			if bool(box.call("is_revealing")):
				box.call("_accept")


func _read_mail() -> bool:
	var box: Node = ranch.call("get_mailbox")
	if box == null or not bool(box.call("is_flag_up")):
		return false
	_say("checks the mailbox")
	if not await _approach(InteractionScript.Kind.MAILBOX, box.global_position, 1.8):
		await _wait(3.0)
		return true
	_look_at = box.global_position + Vector3(0, 0.8, 0)
	await _wait(0.4)
	await _tap(&"interact")
	_look_at = Vector3.INF
	await _wait(0.5)
	var guard := 0
	var pm: Node = ranch.get("pause_menu")
	while pm != null and bool(pm.call("is_open")) and guard < 6:
		guard += 1
		await _wait(5.0 + rng.randf() * 3.0)
		if pm.call("open_letter_id") != &"":
			# A letter that asks something (the Survey): pick an answer, the first one.
			if not (pm.call("reply_rows") as Array).is_empty():
				await _think()
				pm.call("confirm")
				_say("answers the letter")
				await _wait(1.0)
			pm.call("close_letter")
		else:
			pm.call("close")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		await _wait(6.0)
		lp.call("close")
	return true


func _build_first_pen() -> bool:
	if not _pens().is_empty() or not _story().has_flag("met_fennel"):
		return false
	var slot: Node3D = _slots()[0]
	_say("builds the first pen")
	if not await _approach(InteractionScript.Kind.PLOT_BUILD, slot.global_position + slot.global_basis.z * 4.5, 0.6):
		_say("no build prompt at the plot")
		await _wait(4.0)
		return true
	await _wait(0.5)
	await _tap(&"interact")
	await _wait(0.8)
	var bm: Node = ranch.get("build_menu")
	if bm != null and bool(bm.call("is_open")):
		await _think()
		bm.call("confirm")
		await _wait(1.0)
		if bool(bm.call("is_open")):
			bm.call("close")
	_nav_dirty = true
	return true


## When every pen is full, build on the next empty plot: a Big Pen if it is affordable.
func _build_more_pens() -> bool:
	if _pens().is_empty() or _pen_with_room() != null:
		return false
	var empty: Node3D = null
	for slot: Node3D in _slots():
		if slot.call("get_built") == null:
			empty = slot
			break
	if empty == null:
		return false
	var want_big := _bits() >= 150 + 40
	_say("builds another pen (%s)" % ("Big Pen" if want_big else "Paddock"))
	if not await _approach(InteractionScript.Kind.PLOT_BUILD, empty.global_position + empty.global_basis.z * 4.5, 0.6):
		await _wait(3.0)
		return true
	await _tap(&"interact")
	await _wait(0.8)
	var bm: Node = ranch.get("build_menu")
	if bm != null and bool(bm.call("is_open")):
		await _think()
		if want_big:
			for i in 3:
				var plot: PlotData = bm.call("selected_plot")
				if plot != null and plot.id == &"pen_large":
					break
				bm.call("move_selection", 1)
		bm.call("confirm")
		await _wait(1.0)
		if bool(bm.call("is_open")):
			bm.call("close")
	_nav_dirty = true
	return true


func _owns(gear: StringName) -> bool:
	return bool(ranch.call("_owns", gear)) or (gs.get("unlocks") as Array).has(String(gear))


func _tools() -> Node:
	return ranch.get("tools")


func _pen_with_room() -> Node:
	for pen in _pens():
		if not bool(pen.call("is_full")):
			return pen
	return null


func _pen_the_bag() -> bool:
	var bag := _bag()
	if bag == null or bag.count() == 0:
		return false
	# A person carries a few before walking back, unless the bag is full.
	if bag.count() < 3 and not bag.is_full() and _wild_near(30.0) != null:
		return false
	var pen := _pen_with_room()
	if pen == null:
		return false
	var slot: Node3D = (pen as Node).get_parent() as Node3D
	if _owns(&"scoop_launcher") and await _launch_into(slot):
		return true
	_say("pens %d from the bag" % bag.count())
	var gate: Vector3 = slot.global_position + slot.global_basis.z * 4.4
	await _walk(gate, 1.2)
	var guard := 0
	while bag.count() > 0 and not bool(pen.call("is_full")) and guard < 12:
		guard += 1
		var act: Dictionary = ranch.call("current_interaction")
		if int(act.get("kind", 0)) != InteractionScript.Kind.PEN_MOVE_IN:
			await _walk(slot.global_position + slot.global_basis.z * 3.6, 0.6, 6.0)
		await _tap(&"interact")
		await _wait(0.7 + rng.randf() * 0.5)
	return true


## The Scoop Launcher: from a spot with the pen in sight, aim and press E for each pony.
func _launch_into(slot: Node3D) -> bool:
	var bag := _bag()
	var d := player.global_position.distance_to(slot.global_position)
	if d > 22.0:
		var toward := (player.global_position - slot.global_position)
		toward.y = 0.0
		await _walk(slot.global_position + toward.normalized() * 14.0, 3.0, 30.0)
	_aim = true
	var sent := 0
	var guard := 0
	while bag.count() > 0 and guard < 10:
		guard += 1
		var pen: Node = slot.call("get_built")
		if pen == null or bool(pen.call("is_full")):
			break
		_look_at = slot.global_position + Vector3(0, 0.3, 0)
		await _wait(0.6 + rng.randf() * 0.4)
		var hud := ranch.get_node_or_null(^"HUD")
		var prompt := str(hud.call("prompt_text")) if hud != null else ""
		if not "launch" in prompt:
			break
		await _tap(&"interact")
		sent += 1
		await _wait(0.5)
	_aim = false
	_look_at = Vector3.INF
	if sent > 0:
		_say("launched %d into the pen" % sent)
	return sent > 0


## Ponies past what the pens can Bloom go to the Depot: the money, and the story.
func _deliver_extras() -> bool:
	if not _story().has_flag("depot_explained"):
		return false
	var bag := _bag()
	var pens_full := _pen_with_room() == null
	var extra := 0
	for pen in _pens():
		for inst: PonyInstance in pen.call("ponies"):
			if not inst.is_marked() and _not_close_to_bloom(inst):
				extra += 1
	if not (pens_full and (bag.count() >= 3 or extra >= 2)):
		return false
	var depot := _node_pos(^"Buildings/Depot")
	_say("takes ponies to the Depot")
	if not await _approach(InteractionScript.Kind.DEPOT, depot, 3.2):
		return true
	await _wait(0.5)
	await _tap(&"interact")
	await _wait(1.0)
	var dm: Node = ranch.call("get_depot_menu")
	if dm == null or not bool(dm.call("is_open")):
		return true
	var sent := 0
	var guard := 0
	while guard < 8:
		guard += 1
		var rows: Array = dm.call("deliver_rows")
		var pick := -1
		for i in rows.size():
			var r: Dictionary = rows[i]
			if bool(r.get("stock", false)) and not bool(r.get("marked", false)):
				pick = i
				break
		if pick < 0 or sent >= 3:
			break
		await _think()
		dm.call("move_selection", pick - int(dm.call("selected_index")))
		dm.call("confirm")
		if bool(dm.call("is_confirming")):
			dm.call("confirm")
		sent += 1
		await _wait(1.0)
	await _think()
	dm.call("close")
	_say("delivered %d" % sent)
	return true


func _not_close_to_bloom(inst: PonyInstance) -> bool:
	return inst.bloom < 0.6


## The shopping list, in the order a person would want things.
const WISHLIST: Array[StringName] = [&"hay", &"gallop_shoes", &"steward_monocle",
	&"bigger_saddlebag", &"permit_orchard", &"scoop_launcher", &"pony_whistle", &"gem_chute",
	&"long_beam", &"permit_lake", &"depot_cart", &"permit_nightmeadow", &"permit_everfree"]


func _next_buy() -> ShopItem:
	var shop: Object = ranch.call("get_shop")
	if shop == null:
		return null
	for id in WISHLIST:
		var item: ShopItem = null
		var mm: Node = ranch.call("get_market_menu")
		for it: ShopItem in (mm.get("_all_items") as Array):
			if it.id == id and bool(shop.call("listed", it)):
				item = it
		if item == null:
			continue
		if item.kind != ShopItemScript.Kind.CARE and bool(shop.call("owns_gear", item.id)):
			continue
		if item.kind == ShopItemScript.Kind.PERMIT and bool(shop.call("owns_permit", item.permit_zone)):
			continue
		if item.kind == ShopItemScript.Kind.CARE and _pantry() >= 6:
			continue
		return item
	return null


func _pantry() -> int:
	var inv: Object = gs.get("inventory")
	if inv == null:
		return 99
	var n := 0
	for food in [&"hay", &"carrot", &"apple", &"daisy", &"daffodil"]:
		n += int(inv.call("count", food))
	return n


func _shop() -> bool:
	var item := _next_buy()
	var gems: Object = gs.get("gems")
	var gem_count := int(gems.call("total")) if gems != null and gems.has_method("total") else 0
	if (item == null or _bits() + gem_count * 5 < item.cost) and gem_count < 25:
		return false
	_say("goes to the market")
	if not await _approach(InteractionScript.Kind.MARKET, _node_pos(^"Buildings/Market"), 3.4):
		return true
	await _wait(0.4)
	await _tap(&"interact")
	await _wait(1.0)
	var mm: Node = ranch.call("get_market_menu")
	if mm == null or not bool(mm.call("is_open")):
		return true
	await _think()
	mm.call("sell_everything")
	await _wait(1.0)
	item = _next_buy()
	if item != null and _bits() >= item.cost:
		mm.call("set_tab", 1)
		await _think()
		var rows: Array = mm.call("buy_rows")
		var at := -1
		for i in rows.size():
			if (rows[i] as ShopItem).id == item.id:
				at = i
		if at >= 0:
			mm.call("move_selection", at - int(mm.call("selected_index")))
			await _think()
			mm.call("confirm")
			_say("buys %s" % item.display_name)
			_nav_dirty = true
	await _think()
	mm.call("close")
	return true


func _wild_near(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	var spawner: Node = ranch.get("spawner")
	for p: Node3D in spawner.call("get_spawned"):
		# Not one already in the Scoop (HELD) or walking off the map (LEAVING).
		if not is_instance_valid(p) or int(p.get("state")) >= 5:
			continue
		var d := p.global_position.distance_to(player.global_position)
		if d < best_d and _reachable(p.global_position):
			best_d = d
			best = p
	return best


func _reachable(at: Vector3) -> bool:
	if not _nav_map.is_valid():
		return true
	var near := NavigationServer3D.map_get_closest_point(_nav_map, at)
	return Vector2(near.x - at.x, near.z - at.z).length() < 2.5


## The canon pony Tumble just pointed out, if she is still out there.
func _sighted() -> Node3D:
	var h: Node = ranch.get("happenings")
	if h == null:
		return null
	var p: Node3D = h.get("sighting")
	if p == null or not is_instance_valid(p) or int(p.get("state")) >= 5 or not _reachable(p.global_position):
		return null
	return p


## Find a pony (or go after `target`), creep up, hold the Scoop on her until she is secured.
func _hunt(target: Node3D = null) -> bool:
	var bag := _bag()
	if bag == null or bag.is_full() or not _story().has_flag("has_scoop"):
		return false
	if target == null and _sighted_only:
		return false
	var pony := target if target != null else _wild_near(70.0)
	if pony == null:
		return false
	_say("goes after a pony %.0f m away" % pony.global_position.distance_to(player.global_position))
	var t0 := _t()
	var treated := false
	var whistled := false
	while _t() - t0 < 40.0 and is_instance_valid(pony):
		var d := pony.global_position.distance_to(player.global_position)
		if d <= CATCH_RANGE:
			break
		if d > 22.0 and _owns(&"gallop_shoes") and _tools() != null:
			await _tap(&"gallop")
		# A treat from a little way off brings her over, calm.
		if not treated and d < 12.0 and _owns(&"treat_pouch") and _pantry() > 0:
			_aim = true
			_look_at = pony.global_position
			await _wait(0.5)
			await _tap(&"treat")
			treated = true
			_aim = false
			await _wait(1.0)
			continue
		# She bolted: the whistle stops her.
		if not whistled and int(pony.get("state")) == 3 and _owns(&"pony_whistle") and d < 14.0:
			await _tap(&"whistle")
			whistled = true
		_sneak = d < SNEAK_RANGE and not treated
		await _walk(pony.global_position, CATCH_RANGE - 0.5, 4.0)
	_sneak = false
	if not is_instance_valid(pony) or pony.global_position.distance_to(player.global_position) > CATCH_RANGE + 1.0:
		return true
	_aim = true
	_look_at = pony.global_position + Vector3(0, 0.6, 0)
	var beam := _beam()
	var aim_t := 0.0
	while aim_t < 2.5 and is_instance_valid(pony):
		_look_at = pony.global_position + Vector3(0, 0.6, 0)
		await physics_frame
		aim_t += 1.0 / 60.0
		if bool(beam.call("has_target")) and aim_t > 0.35:
			break
	if not is_instance_valid(pony):
		_aim = false
		return true
	Input.action_press(&"beam")
	var hold := 0.0
	var caught := false
	while hold < 4.0:
		await physics_frame
		hold += 1.0 / 60.0
		if is_instance_valid(pony):
			_look_at = pony.global_position + Vector3(0, 0.6, 0)
		if bool(beam.call("is_holding")) and bool(beam.call("is_secured")):
			await _wait(rng.randf_range(0.08, 0.25))
			caught = true
			break
		if not bool(beam.call("is_holding")) and hold > 1.2:
			break
	Input.action_release(&"beam")
	_aim = false
	_look_at = Vector3.INF
	await _wait(0.4)
	_say("caught one (bag %d)" % bag.count() if caught else "she got away")
	return true


## The Palace, once it has opened: chips at the Cage, a few spins at the slots. A person
## goes the night it opens and now and then after.
func _visit_palace() -> bool:
	if not _story().has_flag("palace_open") or _bits() < 120:
		return false
	if _palace_visits > 0 and _t() - _last_palace < 20.0 * 60.0:
		return false
	_palace_visits += 1
	_last_palace = _t()
	var palace := _node_pos(^"Buildings/Palace")
	_say("heads for the Palace")
	if not await _approach(InteractionScript.Kind.PALACE, palace, 4.6):
		return true
	await _wait(0.4)
	await _tap(&"interact")
	await _wait(1.2)
	var cm: Node = ranch.get("casino_menu")
	if cm == null or not bool(cm.call("is_open")):
		return true
	await _wait(2.5)
	cm.call("set_tab", 1)
	await _think()
	cm.call("move_selection", -int(cm.call("selected_index")))
	cm.call("confirm")
	await _wait(1.0)
	cm.call("set_tab", 0)
	await _think()
	var rows: Dictionary = (cm.get_script() as Script).get_script_constant_map().get("Row", {})
	var slots_row := int(rows.get("SLOTS", 0))
	cm.call("move_selection", slots_row - int(cm.call("selected_index")))
	cm.call("confirm")
	await _wait(1.2)
	var sm: Node = ranch.get("slots_menu")
	if sm != null and bool(sm.call("is_open")):
		for i in 6:
			await _wait(rng.randf_range(1.0, 2.2))
			sm.call("confirm")
			var g := 0
			while bool(sm.call("animating")) and g < 600:
				g += 1
				await process_frame
		await _wait(1.5)
		sm.call("close")
		_say("played the slots")
	await _think()
	if bool(cm.call("is_open")):
		cm.call("close")
	return true


## Nothing pressing: walk somewhere with ponies, the way a person roams.
func _wander() -> void:
	var spawner: Node = ranch.get("spawner")
	var spots: Array = []
	for p: Node3D in spawner.call("get_spawned"):
		if is_instance_valid(p) and _reachable(p.global_position):
			spots.append(p.global_position)
	if spots.is_empty():
		await _wait(2.0)
		return
	var to: Vector3 = spots[rng.randi() % spots.size()]
	await _walk(to, 8.0, 25.0)
	await _wait(rng.randf_range(0.5, 2.0))


# --- the end -----------------------------------------------------------------------------

func _finish() -> void:
	_done = true
	_stop()
	var nov: Novelty = gs.get("novelty")
	var horizon := _t()
	print("BOT_OK %s" % NoveltyScript.clock(horizon))
	if pacing_path != "":
		var md := NoveltyScript.markdown(nov.entries, horizon, {"bot seed": seed_value,
			"catches": int(_story().get_var("catches", 0)), "deliveries": _story().deliveries,
			"blooms": int(_story().get_var("blooms", 0)), "bits": _bits()})
		var f := FileAccess.open(pacing_path, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
			f.close()
		var a := NoveltyScript.analyse(nov.entries, horizon)
		print("PACING_%s %s" % ["OK" if a.ok else "FAILED", "; ".join(a.failures)])
	quit(0)
