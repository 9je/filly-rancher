extends "res://test_input/input_test.gd"
## THE REAL-INPUT PLAYTHROUGH (tools/playthrough_input.sh). A NEW game, from the title
## screen, played to one ending by a bot that has a keyboard and a mouse and nothing else:
##
##   WASD, Shift (sneak), Space (jump)        RealInput.press/release, from the InputMap
##   the camera                               mouse motion while the cursor is captured
##                                            (the look_* keys only if it is not)
##   the Scoop                                the right mouse button, held
##   E, the number keys, the arrow keys,      key events: talk, menus, letters, holds
##   Enter and Escape
##
## Every ACTION goes through RealInput (Input.parse_input_event). The bot READS the game the
## way a person reads the screen -- where a pony is and what colour she is, what the prompt
## says, which row a menu has selected, which story flags are set, where a Collector's
## lantern is pointing -- and never WRITES it: no set_flag, no menu method that changes
## state, no --factory-fast, no teleport, no scene change of its own. Time passes only by
## playing: there is no bed, so a night or a collection day is waited for by working the
## ranch until it comes.
##
## The brain (navmesh walking, aiming, pacing) is the human-paced bot's
## (scenes/test/human_bot.gd, which now runs this file in its pacing mode).
##
##   ... -s res://test_input/playthrough_input.gd -- --ending=lights_out [--seed=7]
##   ... -s res://scenes/test/human_bot.gd -- --minutes=70 --pacing=/abs/PACING.md
##
## Prints PLAYTHROUGH_OK <ending> <game time> (or PLAYTHROUGH_FAILED <why>), and exits 0
## only when the asked-for ending is the one that played.

const InteractionScript := preload("res://world/interaction.gd")
const NoveltyScript := preload("res://systems/novelty.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const PathRulesScript := preload("res://systems/path_rules.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const EndingsScript := preload("res://systems/endings.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const LedgerScript := preload("res://systems/ledger.gd")

## Human pacing: a think before each menu choice, and the turn rate of the camera.
const THINK := Vector2(0.5, 1.2)
const TURN_DEG_S := 170.0
const RUN_ARRIVE := 1.4
const CATCH_RANGE := 6.5
const SNEAK_RANGE := 11.0

var want := ""
var minutes := 0.0
var pacing_path := ""
var seed_value := 7
## Characters a second she reads at. The pacing run reads like a person; a playthrough reads
## a little faster (it is still reading every line, at the talk box's own pace).
var read_cps := 30.0
var rng := RandomNumberGenerator.new()

var gs: Node
var factory: Node = null

# The virtual controller, run every physics frame by _control().
var _clock := 0.0
var _path: PackedVector3Array = []
var _path_i := 0
var _arrived := true
## How close the current walk wants to get: the controller only calls the last waypoint
## reached inside this (it used to stop 1.4 m short of every target, whatever the walk asked).
var _arrive_r := RUN_ARRIVE
var _look_at := Vector3.INF
var _aim := false
var _sneak := false
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _unstick_t := 0.0
var _unstick_dir := 1.0
var _held: Dictionary = {}
var _nav_map: RID
var _nav_region: RID
var _nav_dirty := false
var _nav_scene: Node = null
var _mouse_ok := true
var _mouse_warned := false

var _log: Array[String] = []
var _bugs: Array[String] = []
var _build_fails: Dictionary = {}
var _held_since := -1.0
var _held_name := ""
var _depot_rest_until := -1.0
var _last_market := -9999.0
var _market_fails := 0
var _ending_seen := ""
var _epilogue_done := false
var _aftermath_ok := false
var _milestones: Array[String] = []
var _t_start_ms := 0
var _last_status := -999.0
## DEV ONLY: Continue the save in FILLY_TEST_SAVE_DIR instead of a new game. Still played by
## input from the title screen on, but a continued run is not a playthrough from a new game,
## so it never prints PLAYTHROUGH_OK (it prints PLAYTHROUGH_DEV_OK).
var _continued := false
## DEV ONLY: stop (exit 3) at the first milestone whose text contains this.
var _stop_at := ""
## --log=<path>: every line the bot prints, also written (and flushed) here, so a long run can
## be watched while it plays (stdout to a file is only flushed at exit).
var _log_file: FileAccess = null


func _play() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ending="):
			want = a.substr(9)
		elif a.begins_with("--minutes="):
			minutes = float(a.substr(10))
		elif a.begins_with("--pacing="):
			pacing_path = a.substr(9)
		elif a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--deadline="):
			_deadline_s = float(a.substr(11))
		elif a.begins_with("--log="):
			_log_file = FileAccess.open(a.substr(6), FileAccess.WRITE)
		elif a.begins_with("--stop-at="):
			_stop_at = a.substr(10)
		elif a == "--continue":
			_continued = true
		elif a.begins_with("--read-cps="):
			read_cps = float(a.substr(11))
	if minutes > 0.0 and want == "":
		read_cps = 22.0
	elif not (StringName(want) in EndingsScript.ALL):
		_finish_fail("--ending= one of %s (or --minutes= for a pacing run)" % [EndingsScript.ALL])
		return
	rng.seed = seed_value
	if _deadline_s == 600.0:
		_deadline_s = 6.0 * 3600.0 if minutes <= 0.0 else minutes * 60.0 + 900.0
	_t_start_ms = Time.get_ticks_msec()
	physics_frame.connect(_control)
	if _continued:
		if not await _boot_continue():
			return
	elif not await boot_new_game():
		return
	gs = root.get_node("GameState")
	await _attach(ranch)
	_say("mouse mode %d (captured is %d)" % [Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])
	if not _continued:
		await _creator()
	await _brain()


func _boot_continue() -> bool:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(10)
	if not await click_text("Continue"):
		return false
	var t := 0.0
	while t < 60.0:
		var s := current_scene
		if s != null and s.get("people") != null and s.get("player") != null:
			ranch = s
			break
		await wait(0.1)
		t += 0.1
	if ranch == null:
		fail("Continue never reached the ranch")
		return false
	player = ranch.get("player")
	rig = player.call("get_camera_pivot").get_node("CameraRig")
	_milestone("DEV: continued a save (this run does not count)")
	return true


# --- the clock and the log -------------------------------------------------------------

func _t() -> float:
	return _clock


func _clock_text(s: float) -> String:
	return "%d:%02d:%02d" % [int(s) / 3600, (int(s) / 60) % 60, int(s) % 60]


func _say(s: String) -> void:
	var line := "BOT %s %s" % [_clock_text(_t()), s]
	_out(line)
	_log.append(line)


func _out(line: String) -> void:
	print(line)
	if _log_file != null:
		_log_file.store_line(line)
		_log_file.flush()


func _milestone(s: String) -> void:
	var line := "%s  %s  (wall %ds)" % [_clock_text(_t()), s, (Time.get_ticks_msec() - _t_start_ms) / 1000]
	_milestones.append(line)
	_out("PLAYTHROUGH_STEP %s" % line)
	if _stop_at != "" and s.contains(_stop_at) and not _done:
		_out(_summary())
		_out("PLAYTHROUGH_DEV_STOP at '%s'" % s)
		_done = true
		_release_moves()
		quit(3)


## A thing a person could not do, or the game did wrong, seen while playing.
func _bug(s: String) -> void:
	if s in _bugs:
		return
	_bugs.append(s)
	_out("PLAYTHROUGH_BUG %s %s" % [_clock_text(_t()), s])


func _wait(seconds: float) -> void:
	var until := _t() + seconds
	while _t() < until:
		await physics_frame


func _think() -> void:
	await _wait(rng.randf_range(THINK.x, THINK.y))


# --- the hands: every one of these is an InputEvent -------------------------------------

func _hold(action: StringName, on: bool) -> void:
	if bool(_held.get(action, false)) == on:
		return
	_held[action] = on
	if on:
		RI.press(action)
	else:
		RI.release(action)


func _release_moves() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump",
			&"sneak", &"look_left", &"look_right", &"look_up", &"look_down", &"gallop"]:
		_hold(a, false)


func _press(action: StringName, frames_held := 3) -> void:
	_hold(action, true)
	await physics(frames_held)
	await process_frame
	_hold(action, false)
	await physics(2)
	await process_frame


## A key that is not an action of its own (the talk box's number keys).
func _press_key(k: Key) -> void:
	RI.key(k, true)
	await physics(3)
	RI.key(k, false)
	await physics(2)


## Turn the camera by what add_look_delta() would take (radians), the way a hand does it:
## mouse motion while the cursor is captured. If it is not captured (and no menu holds the
## screen) the look keys turn it instead, and that is noted once.
func _turn(dyaw: float, dpitch: float) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_hold(&"look_left", false)
		_hold(&"look_right", false)
		_hold(&"look_up", false)
		_hold(&"look_down", false)
		var sens: float = rig.get("mouse_sensitivity")
		if absf(dyaw) > 1e-5 or absf(dpitch) > 1e-5:
			RI.look(Vector2(dyaw / sens, dpitch / sens))
		return
	if _menu() != "" or (factory == null and not _ranch_ok()):
		for a: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
			_hold(a, false)
		return
	if not _mouse_warned:
		_mouse_warned = true
		_bug("the cursor was not captured with no menu open (mode %d); turning with the look keys" % Input.mouse_mode)
	# add_look_delta(+) turns right (yaw goes down): look_right; pitch + looks down.
	_hold(&"look_right", dyaw > 0.004)
	_hold(&"look_left", dyaw < -0.004)
	_hold(&"look_down", dpitch > 0.004)
	_hold(&"look_up", dpitch < -0.004)


# --- the eyes: reading only -------------------------------------------------------------

func _story() -> Story:
	return gs.get("story") if gs != null else null


func _path_name() -> String:
	return StoryV1Script.path(_story())


func _people() -> Node:
	if factory != null and is_instance_valid(factory):
		return factory.get("people")
	return ranch.get("people") if _ranch_ok() else null


func _ranch_ok() -> bool:
	return ranch != null and is_instance_valid(ranch) and ranch.is_inside_tree()


func _node_pos(path: NodePath) -> Vector3:
	var n := ranch.get_node_or_null(path) as Node3D
	return n.global_position if n != null else Vector3.INF


func _bag() -> Storage:
	var beam: Node = player.call("get_magic_beam") if player != null and is_instance_valid(player) else null
	return beam.call("get_storage") if beam != null else null


func _beam() -> Node:
	return player.call("get_magic_beam")


func _bits() -> int:
	return int(gs.get("bits"))


func _slots() -> Array:
	return ranch.call("plot_slots")


func _pens() -> Array:
	var out: Array = []
	for s in _slots():
		var pen := (s as Node).call("get_built") as Node
		if pen != null and pen.has_method("ponies"):
			out.append(pen)
	return out


func _menu() -> String:
	return str(ranch.call("blocking_menu")) if _ranch_ok() else ""


func _interaction() -> Dictionary:
	return ranch.call("current_interaction")


func _prompt() -> String:
	var hud: Node = null
	if factory != null and is_instance_valid(factory):
		hud = factory.get("hud")
	elif _ranch_ok():
		hud = ranch.get_node_or_null(^"HUD")
	return str(hud.call("prompt_text")) if hud != null and hud.has_method("prompt_text") else ""


func _world() -> WorldState:
	return ranch.call("get_world_state") if _ranch_ok() else null


func _is_night() -> bool:
	var w := _world()
	return w != null and (w.phase() == WorldStateScript.Phase.NIGHT or w.phase() == WorldStateScript.Phase.DUSK)


## Seconds of play until the next dusk (0 if it is dusk or night now).
func _until_night() -> float:
	var w := _world()
	if w == null or _is_night():
		return 0.0
	var t := fposmod(w.elapsed(), WorldStateScript.CYCLE_SECONDS)
	var dusk_at: float = WorldStateScript.PHASE_SECONDS[0] + WorldStateScript.PHASE_SECONDS[1]
	return maxf(0.0, dusk_at - t)


## Seconds of night left (0 by day).
func _night_left() -> float:
	var w := _world()
	if w == null or not _is_night():
		return 0.0
	return WorldStateScript.CYCLE_SECONDS - fposmod(w.elapsed(), WorldStateScript.CYCLE_SECONDS)


func _coat_of_stock(stock: Dictionary) -> Color:
	if stock.is_empty():
		return Color.WHITE
	return PonyLookScript.from_dict(stock).coat


func _coat_of_body(p: Node) -> Color:
	if p == null or not p.has_method("get_stock"):
		return Color.WHITE
	return _coat_of_stock(p.call("get_stock"))


func _pantry_count(food: StringName) -> int:
	var inv: Object = gs.get("inventory")
	return int(inv.call("count", food)) if inv != null else 0


# --- the navmesh ------------------------------------------------------------------------
# Baked from the scene's colliders into the bot's own navigation map, so it adds nothing to
# the game's scene tree: a map in the NavigationServer only the bot reads.

func _bake_nav(scene: Node) -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.55
	nm.agent_height = 1.3
	nm.agent_max_climb = 0.45
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.3
	nm.cell_height = 0.2
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = (1 << 0) | (1 << 1)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, scene)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	if not _nav_map.is_valid():
		_nav_map = NavigationServer3D.map_create()
		NavigationServer3D.map_set_cell_size(_nav_map, 0.3)
		NavigationServer3D.map_set_cell_height(_nav_map, 0.2)
		NavigationServer3D.map_set_active(_nav_map, true)
		_nav_region = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(_nav_region, _nav_map)
	NavigationServer3D.region_set_navigation_mesh(_nav_region, nm)
	_nav_scene = scene
	for i in 4:
		await physics_frame
	_nav_dirty = false


func _path_to(to: Vector3) -> PackedVector3Array:
	if not _nav_map.is_valid():
		return PackedVector3Array([to])
	var p := NavigationServer3D.map_get_path(_nav_map, player.global_position, to, true)
	if p.is_empty():
		return PackedVector3Array([to])
	return p


func _reachable(at: Vector3) -> bool:
	if not _nav_map.is_valid():
		return true
	var near := NavigationServer3D.map_get_closest_point(_nav_map, at)
	return Vector2(near.x - at.x, near.z - at.z).length() < 2.5


## Take hold of a scene that just came up (the ranch, or the Factory): its player and
## camera, and a navmesh of its ground.
func _attach(scene: Node) -> void:
	_stop()
	player = scene.get("player")
	rig = player.call("get_camera_pivot").get_node("CameraRig")
	for i in 30:
		await physics_frame
	await _bake_nav(scene)


# --- the virtual controller -------------------------------------------------------------

func _control() -> void:
	_clock += 1.0 / float(Engine.physics_ticks_per_second)
	if _done or player == null or not is_instance_valid(player) or rig == null or not is_instance_valid(rig):
		return
	if not player.is_inside_tree():
		return
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var cam: Camera3D = rig.call("get_camera")
	var look := _look_at
	var walking := not _arrived and _path_i < _path.size()
	if walking and not _aim:
		look = _lookahead()
		if Vector2(look.x - player.global_position.x, look.z - player.global_position.z).length() < 1.2:
			look = Vector3.INF
	var dyaw := 0.0
	var dpitch := 0.0
	if look != Vector3.INF and cam != null:
		var from := cam.global_position if _aim else player.global_position
		var d := look - from
		var yaw_t := atan2(-d.x, -d.z)
		var err := wrapf(yaw_t - rig.global_rotation.y, -PI, PI)
		var rate := deg_to_rad(TURN_DEG_S) * dt
		var step := clampf(err * (1.0 - exp(-7.0 * dt)) * 1.6, -rate, rate)
		dyaw = -step
		var flat := Vector2(d.x, d.z).length()
		var pitch_t := rad_to_deg(atan2(d.y, maxf(flat, 0.01))) if _aim else -10.0
		var pe := pitch_t - float(rig.call("get_look_pitch_degrees"))
		dpitch = -deg_to_rad(clampf(pe * 0.12, -2.5, 2.5))
	_turn(dyaw, dpitch)
	if walking:
		var target := _path[_path_i]
		var to := target - player.global_position
		to.y = 0.0
		var last := _path_i == _path.size() - 1
		if to.length() < (minf(RUN_ARRIVE, _arrive_r) if last else 0.9):
			_path_i += 1
			if _path_i >= _path.size():
				_stop()
				return
		var fwd := -rig.global_basis.z
		fwd.y = 0.0
		var facing := fwd.normalized().dot(to.normalized()) if to.length() > 0.01 else 1.0
		if _unstick_t > 0.0:
			_unstick_t -= dt
			_hold(&"move_right", _unstick_dir > 0.0)
			_hold(&"move_left", _unstick_dir <= 0.0)
			_hold(&"move_forward", true)
		else:
			_hold(&"move_left", false)
			_hold(&"move_right", false)
			# A key is all or nothing: facing away, she turns first and then goes.
			_hold(&"move_forward", facing > 0.25)
		# The last metre to a fine mark is taken at a creep, so she stops on it.
		var fine := last and _arrive_r < 0.8 and to.length() < 2.0
		_hold(&"sneak", _sneak or fine)
		_stuck_t += dt
		if _stuck_t > 1.2:
			if player.global_position.distance_to(_last_pos) < 0.35:
				_unstick_t = 0.7
				_unstick_dir = -_unstick_dir
			_stuck_t = 0.0
			_last_pos = player.global_position
		if _nav_map.is_valid() and Engine.get_physics_frames() % 30 == 0:
			var ground := NavigationServer3D.map_get_closest_point(_nav_map, player.global_position)
			_hold(&"jump", player.global_position.y - ground.y > 0.9 and (player as CharacterBody3D).is_on_floor())
	else:
		_hold(&"move_forward", false)
		_hold(&"sneak", _sneak)


func _lookahead() -> Vector3:
	var left := 3.0
	var i := _path_i
	var p := player.global_position
	while i < _path.size():
		var seg := _path[i] - p
		seg.y = 0.0
		if seg.length() >= left:
			return p + seg.normalized() * left + Vector3(0, 0.8, 0)
		left -= seg.length()
		p = _path[i]
		i += 1
	return _path[_path.size() - 1] + Vector3(0, 0.8, 0)


func _stop() -> void:
	_arrived = true
	_path = PackedVector3Array()
	_path_i = 0
	_hold(&"move_forward", false)
	_hold(&"move_left", false)
	_hold(&"move_right", false)
	_hold(&"jump", false)


## Walk to `to` (re-pathing as it goes). Returns whether she got within `arrive`.
func _walk(to: Vector3, arrive: float = RUN_ARRIVE, timeout: float = 90.0) -> bool:
	if _nav_dirty:
		await _bake_nav(_nav_scene)
	_aim = false
	_arrive_r = arrive
	var t0 := _t()
	var repath := 0.0
	_path = _path_to(to)
	_path_i = 0
	_arrived = false
	var check_t := _t()
	var check_at := player.global_position
	var stuck := 0
	while _t() - t0 < timeout:
		await physics_frame
		if not is_instance_valid(player) or not player.is_inside_tree():
			return false
		var gap := Vector2(player.global_position.x - to.x, player.global_position.z - to.z).length()
		if gap <= arrive:
			_stop()
			return true
		if _menu() != "" and _menu() != "talk":
			# Something opened over the world (a letter, the epilogue): stop and let the
			# brain deal with it.
			_stop()
			return false
		if _t() - check_t > 2.0:
			var moved := Vector2(player.global_position.x - check_at.x, player.global_position.z - check_at.z).length()
			check_t = _t()
			check_at = player.global_position
			if moved < 0.4:
				stuck += 1
				if stuck >= 3:
					_stop()
					_say("gives up on a blocked walk at %s" % player.global_position.snapped(Vector3.ONE * 0.1))
					return false
				var away := player.global_position - to
				away.y = 0.0
				var side := away.normalized().cross(Vector3.UP) * (1.0 if stuck % 2 == 1 else -1.0)
				_path = _path_to(player.global_position + (away.normalized() * 1.5 + side * 2.5))
				_path_i = 0
				_arrived = false
				var s0 := _t()
				while _t() - s0 < 1.6 and not _arrived:
					await physics_frame
				repath = 99.0
				check_t = _t()
				check_at = player.global_position
		repath += 1.0 / 60.0
		if _arrived or repath > 3.0:
			repath = 0.0
			_path = _path_to(to)
			_path_i = 0
			_arrived = false
	_stop()
	return false


## Face `at` (yaw and pitch) for a moment, standing still.
func _face(at: Vector3, seconds := 0.6) -> void:
	_look_at = at
	_aim = true
	await _wait(seconds)
	_aim = false
	_look_at = Vector3.INF


## Get to where E does `kind` (and, for TALK, to `subject`): walk to `at`, and if the prompt
## is somebody else's, try standing on other sides of it.
func _approach(kind: int, at: Vector3, arrive: float, subject: String = "") -> bool:
	await _walk(at, arrive)
	for i in 8:
		await _wait(0.25)
		var act := _interaction()
		if int(act.get("kind", 0)) == kind and (subject == "" or str(act.get("subject", "")) == subject):
			return true
		var ang := TAU * float(i) / 6.0 + rng.randf() * 0.5
		var spot := at + Vector3(cos(ang), 0, sin(ang)) * maxf(arrive * 0.8, 1.0)
		await _walk(spot, 0.45, 5.0)
	return false


# --- reading the screen: letters, talk, the epilogue, stray menus ----------------------

func _tend_screens() -> void:
	if not _ranch_ok():
		return
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		_stop()
		await _wait(3.0 + rng.randf() * 2.0)
		await _press(&"ui_accept")
		await _wait(0.4)
		return
	var ep: Variant = ranch.get("epilogue")
	if ep != null and is_instance_valid(ep):
		await _read_epilogue(ep)
		return
	var held := _menu()
	if held == "" or held == "talk":
		_held_since = -1.0
		return
	if held != _held_name:
		_held_name = held
		_held_since = _t()
		return
	if _t() - _held_since < 12.0:
		return
	_bug("a %s stayed open with nothing of the bot's using it; Escape" % held)
	await _press(&"ui_cancel")
	await _wait(1.0)
	_held_since = _t()


func _read_epilogue(ep: Node) -> void:
	_stop()
	_say("the epilogue")
	var guard := 0
	while is_instance_valid(ep) and guard < 12:
		guard += 1
		await _wait(5.0)
		if is_instance_valid(ep):
			await _press(&"ui_accept")
	_epilogue_done = true
	_milestone("epilogue read")


func _talk_to_news() -> bool:
	var p := _people()
	if p == null:
		return false
	var best: StringName = &""
	var best_d := INF
	for id: StringName in p.get("npcs"):
		if not _wants_to_hear(id) or not bool(p.call("has_news", id)):
			continue
		var n: Node3D = p.call("npc", id)
		if n == null or not _reachable(n.global_position):
			continue
		var d := n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = id
	if best == &"":
		return false
	return await _talk_to(best)


## Walk up to `id`, get her prompt, press E, read it through.
func _talk_to(id: StringName) -> bool:
	var p := _people()
	var who: Node3D = p.call("npc", id)
	if who == null:
		return false
	_say("walks over to talk to %s" % id)
	if id == &"tumble":
		# She is at your heels already: step clear of the plots and buildings and let her
		# come up beside you.
		await _walk(_open_ground(), 2.0, 30.0)
		await _wait(1.5)
	else:
		await _walk(who.global_position, 2.0)
	var want_name := str(who.get("def").display_name) if who.get("def") != null else ""
	var tries := 0
	var act := _interaction()
	while tries < 6 and (int(act.get("kind", 0)) != InteractionScript.Kind.TALK or str(act.get("subject", "")) != want_name):
		tries += 1
		var away := who.global_position - player.global_position
		away.y = 0.0
		var side := who.global_position + away.normalized().rotated(Vector3.UP, rng.randf_range(-1.4, 1.4)) * 1.1
		await _walk(side if tries % 3 != 0 else who.global_position, 0.6, 5.0)
		_look_at = who.global_position + Vector3(0, 1.0, 0)
		await _wait(0.3)
		_look_at = Vector3.INF
		act = _interaction()
	if int(act.get("kind", 0)) != InteractionScript.Kind.TALK or str(act.get("subject", "")) != want_name:
		_say("could not get %s's prompt (%s)" % [id, act])
		return false
	_stop()
	await _press(&"interact")
	await _wait(0.3)
	if not bool(p.call("is_talking")):
		_say("E did not start a talk with %s" % id)
		return false
	await _read_conversation(p)
	return true


## A patch of grass with nothing on it that E could mean (no plot, no building).
func _open_ground() -> Vector3:
	var things: Array[Vector3] = []
	var b := ranch.get_node_or_null(^"Buildings")
	if b != null:
		for c in b.get_children():
			if c is Node3D:
				things.append((c as Node3D).global_position)
	for sl: Node3D in _slots():
		things.append(sl.global_position)
	var p := _people()
	for id: StringName in p.get("npcs"):
		if id != &"tumble":
			things.append((p.call("npc", id) as Node3D).global_position)
	var best := player.global_position
	var best_score := -INF
	for gx in range(-4, 5):
		for gz in range(-4, 5):
			var c := player.global_position + Vector3(gx * 4.0, 0.0, gz * 4.0)
			if not _reachable(c):
				continue
			var clear := INF
			for t in things:
				clear = minf(clear, Vector2(c.x - t.x, c.z - t.z).length())
			var score := minf(clear, 12.0) - 0.15 * c.distance_to(player.global_position)
			if score > best_score:
				best_score = score
				best = c
	return best


## Who the bot wants to hear from (an ending decides some conversations are not had).
func _wants_to_hear(id: StringName) -> bool:
	if want == "half_light" and id in [&"pip", &"bramble", &"fennel"] and _path_name() == "rescue":
		# Half Light: she never asks anypony to join her; only Static.
		return false
	if id == &"marigold" and _path_name() == "factory" and _story().has_flag("jubilee_ready") \
			and want == "gray_gold" and int(_story().get_var("rescued", 0)) < EndingsScript.GRAY_GOLD_RESCUES:
		return false
	if id == &"static" and _path_name() == "rescue" and not _rescue_ready_for_climax():
		# Static's "ready" asks for the lift; the first meeting and status are fine any time.
		var s := _story()
		if s.has_flag("static_met") and PathRulesScript.pylons_cut(s) >= 4:
			return false
	return true


## Read the open conversation through: E for each line (finishing the reveal first, the
## way the talk box wants it), a number key for a choice.
func _read_conversation(p: Node) -> void:
	var guard := 0
	while bool(p.call("is_talking")) and guard < 80:
		guard += 1
		var runner: Object = p.get("runner")
		var box: Node = p.get("talk_box")
		var line: Dictionary = runner.call("current") if runner != null else {}
		var text := str(line.get("text", ""))
		await _wait(maxf(1.0, text.length() / read_cps) if text != "" else 1.5)
		if not bool(p.call("is_talking")):
			break
		if box != null and bool(box.call("is_revealing")):
			await _press(&"interact")
			await _wait(0.3)
		if runner != null and bool(runner.call("has_choices")):
			var choices: Array = line.get("choices", [])
			var pick := _choose(StringName(str((runner.get("dialogue") as Resource).get("id"))), choices)
			await _think()
			_say("chooses \"%s\"" % (choices[pick] if pick < choices.size() else "?"))
			await _press_key(KEY_1 + pick)
		else:
			await _press(&"interact")
	await _wait(0.4)


## Which choice a player going for this ending takes. Read off the words on the buttons.
func _choose(dialogue_id: StringName, choices: Array) -> int:
	var prefer: Array[String] = []
	match String(dialogue_id):
		"factory_window":
			prefer = ["Sign the contract"] if want in ["brightest_rainbow", "gray_gold"] else ["Get Tumble out"]
		"marigold_color_day", "marigold_jubilee", "static_ready":
			prefer = ["Let's go", "Take me up", "Take us up"]
	for i in choices.size():
		for w in prefer:
			if str(choices[i]).contains(w):
				return i
	return 0


# --- the ranch's verbs ------------------------------------------------------------------

func _creator() -> void:
	var cs: Node = ranch.get("creation_screen")
	for i in 120:
		await process_frame
		if cs != null and bool(cs.call("is_open")):
			break
	if cs == null or not bool(cs.call("is_open")):
		return
	_say("the creator")
	await _wait(4.0)
	# A look at the default pony, a swatch picked with the arrows and Enter, then yes.
	for i in 2:
		await _wait(rng.randf_range(1.0, 2.0))
		await _press(&"ui_right")
	await _press(&"ui_accept")
	await _wait(2.0)
	if not await click_text("This is me", 20.0):
		return
	await _wait(1.0)
	_milestone("the creator: this is me")


func _build_pen(slot: Node3D, want_id: StringName) -> bool:
	_say("builds a pen on %s (%s)" % [slot.name, want_id])
	if not await _approach(InteractionScript.Kind.PLOT_BUILD, _slot_side(slot, 4.55), 0.35, String(slot.name)):
		_build_fails[slot.name] = int(_build_fails.get(slot.name, 0)) + 1
		_say("no build prompt at %s (%s)" % [slot.name, _interaction()])
		return false
	# The legal band is a hand's width (outside the stakes, inside the trigger): read the
	# prompt and step out or in until it says "build here".
	var act := _interaction()
	var out := 4.55
	for i in 8:
		act = _interaction()
		var mine := int(act.get("kind", 0)) == InteractionScript.Kind.PLOT_BUILD and str(act.get("subject", "")) == String(slot.name)
		if mine and str(act.get("reason", "")) == "":
			break
		out += 0.12 if mine else -0.12
		out = clampf(out, 4.35, 4.75)
		await _walk(_slot_side(slot, out), 0.1, 3.0)
		await _wait(0.3)
	act = _interaction()
	if str(act.get("reason", "")) != "" or int(act.get("kind", 0)) != InteractionScript.Kind.PLOT_BUILD:
		_say("the build prompt refuses: '%s' (%s)" % [act.get("reason", ""), act])
		_build_fails[slot.name] = int(_build_fails.get(slot.name, 0)) + 1
		return false
	var before := _pens().size()
	await _press(&"interact")
	await _wait(0.6)
	var bm: Node = ranch.get("build_menu")
	if bm == null or not bool(bm.call("is_open")):
		_build_fails[slot.name] = int(_build_fails.get(slot.name, 0)) + 1
		return false
	await _think()
	var entries: Array = bm.call("entries")
	var target := 0
	for i in entries.size():
		if (entries[i] as PlotData).id == want_id:
			target = i
	await _menu_to(bm, target)
	await _press(&"ui_accept")
	await _wait(1.0)
	if bool(bm.call("is_open")):
		await _press(&"ui_cancel")
		await _wait(0.4)
	if _pens().size() == before:
		_build_fails[slot.name] = int(_build_fails.get(slot.name, 0)) + 1
		return false
	_nav_dirty = true
	return true


## Where to stand beside a plot: on its open side, away from the neighbouring column of
## plots (the four sit 9 m apart, so the side facing a neighbour is the neighbour's ground).
func _slot_side(slot: Node3D, out: float) -> Vector3:
	var centre_x := 0.0
	for s: Node3D in _slots():
		centre_x += s.global_position.x
	centre_x /= maxf(1.0, float(_slots().size()))
	var side := 1.0 if slot.global_position.x >= centre_x else -1.0
	return slot.global_position + Vector3(side * out, 0.0, 0.0)


## Arrow keys until the menu's cursor is on row `target` (reading where it is).
func _menu_to(menu: Node, target: int) -> void:
	for i in 40:
		var at := int(menu.call("selected_index"))
		if at == target:
			return
		await _press(&"ui_down" if target > at else &"ui_up", 2)
		await _wait(0.12)


func _pen_with_room() -> Node:
	for pen in _pens():
		if not bool(pen.call("is_full")) and not bool(pen.call("is_padlocked")) \
				and int(pen.call("count")) < _pen_target(pen):
			return pen
	return null


## How full she keeps a pen: never crowded enough to stop a Bloom.
func _pen_room() -> int:
	var n := 0
	for pen in _pens():
		if not bool(pen.call("is_padlocked")):
			n += maxi(0, _pen_target(pen) - int(pen.call("count")))
	return n


func _pen_target(pen: Node) -> int:
	return mini(int(pen.get("capacity")) if pen.get("capacity") != null else 6, 6)


func _pen_the_bag(force := false) -> bool:
	var bag := _bag()
	if bag == null or bag.count() == 0:
		return false
	if not force and bag.count() < 3 and not bag.is_full() and _wild_near(30.0) != null:
		return false
	var pen := _pen_with_room()
	if pen == null:
		return false
	var slot: Node3D = (pen as Node).get_parent() as Node3D
	_say("pens %d from the bag" % bag.count())
	await _walk(_slot_side(slot, 4.45), 0.5)
	var guard := 0
	while bag.count() > 0 and not bool(pen.call("is_full")) and guard < 12:
		guard += 1
		var act := _interaction()
		if int(act.get("kind", 0)) != InteractionScript.Kind.PEN_MOVE_IN:
			await _walk(_slot_side(slot, 4.3 if guard % 2 == 0 else 4.6), 0.3, 6.0)
			act = _interaction()
		if int(act.get("kind", 0)) != InteractionScript.Kind.PEN_MOVE_IN:
			continue
		await _press(&"interact")
		await _wait(0.6 + rng.randf() * 0.4)
		if int(pen.call("count")) >= _pen_target(pen):
			break
	return true


func _wild_near(radius: float, filter := Callable()) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	var spawner: Node = ranch.get("spawner")
	for p: Node3D in spawner.call("get_spawned"):
		if not is_instance_valid(p) or int(p.get("state")) >= 5 or p.is_in_group(&"penned"):
			continue
		if filter.is_valid() and not bool(filter.call(p)):
			continue
		var d := p.global_position.distance_to(player.global_position)
		if d < best_d and _reachable(p.global_position):
			best_d = d
			best = p
	return best


func _sighted() -> Node3D:
	var h: Node = ranch.get("happenings")
	if h == null:
		return null
	var v: Variant = h.get("sighting")
	if v == null or not is_instance_valid(v):
		return null
	var p := v as Node3D
	if p == null or int(p.get("state")) >= 5 or not _reachable(p.global_position):
		return null
	return p


## Find a pony (or go after `target`), creep up, hold the Scoop on her until she is secured.
func _hunt(target: Node3D = null, filter := Callable()) -> bool:
	var bag := _bag()
	if bag == null or bag.is_full() or not _story().has_flag("has_scoop"):
		return false
	# A person carries what the pens can take, and a few over.
	if bag.count() >= _pen_room() + 3 and not _pens().is_empty():
		return false
	var pony := target if target != null else _wild_near(80.0, filter)
	if pony == null:
		return false
	_say("goes after a pony %.0f m away" % pony.global_position.distance_to(player.global_position))
	var t0 := _t()
	while _t() - t0 < 40.0 and is_instance_valid(pony):
		var d := pony.global_position.distance_to(player.global_position)
		if d <= CATCH_RANGE:
			break
		_sneak = d < SNEAK_RANGE
		_hold(&"gallop", d > 25.0 and not _sneak)
		await _walk(pony.global_position, CATCH_RANGE - 0.5, 3.0)
		if _menu() != "" and _menu() != "talk":
			break
	_hold(&"gallop", false)
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
		_look_at = Vector3.INF
		return true
	var before := bag.count()
	_hold(&"beam", true)
	var hold := 0.0
	while hold < 5.0:
		await physics_frame
		hold += 1.0 / 60.0
		if is_instance_valid(pony):
			_look_at = pony.global_position + Vector3(0, 0.6, 0)
		if bool(beam.call("is_holding")) and bool(beam.call("is_secured")):
			await _wait(rng.randf_range(0.08, 0.2))
			break
		if not bool(beam.call("is_holding")) and hold > 1.2:
			break
	_hold(&"beam", false)
	_aim = false
	_look_at = Vector3.INF
	await _wait(0.5)
	if bag.count() > before:
		_say("caught one (bag %d)" % bag.count())
	else:
		_say("she got away")
	return true


## The Market: sell the gems, buy what is on the list.
func _shop() -> bool:
	var list := _shopping_list()
	var gems: Object = gs.get("gems")
	var gem_total := int(gems.call("total")) if gems != null and gems.has_method("total") else 0
	var pens_gems := 0
	for pen in _pens():
		pens_gems += int(pen.call("gems"))
	var worth := false
	for item: ShopItem in list:
		if _bits() + (gem_total + pens_gems) * 4 >= item.cost:
			worth = true
	if not worth and gem_total + pens_gems < 40:
		return false
	if _t() - _last_market < (120.0 if _market_fails == 0 else 300.0):
		return false
	_last_market = _t()
	_say("goes to the market (%d bits, %d gems)" % [_bits(), gem_total + pens_gems])
	if not await _approach(InteractionScript.Kind.MARKET, _node_pos(^"Buildings/Market"), 3.4):
		_market_fails += 1
		return true
	_stop()
	await _press(&"interact")
	await _wait(0.8)
	var mm: Node = ranch.call("get_market_menu")
	if mm == null or not bool(mm.call("is_open")):
		_market_fails += 1
		return true
	_market_fails = 0
	await _think()
	# Sell tab, row 0: Sell everything.
	if int(mm.call("tab")) != 0:
		await _press(&"ui_right")
	await _menu_to(mm, 0)
	await _press(&"ui_accept")
	await _wait(0.6)
	var bought := 0
	for pass_i in 24:
		list = _shopping_list()
		var item: ShopItem = null
		for it: ShopItem in list:
			if _bits() >= it.cost:
				item = it
				break
		if item == null:
			break
		if int(mm.call("tab")) != 1:
			await _press(&"ui_right")
			await _wait(0.3)
		var rows: Array = mm.call("buy_rows")
		var at := -1
		for i in rows.size():
			if (rows[i] as ShopItem).id == item.id:
				at = i
		if at < 0:
			break
		await _menu_to(mm, at)
		await _think()
		var bits_before := _bits()
		await _press(&"ui_accept")
		await _wait(0.4)
		if _bits() >= bits_before:
			_say("the Market would not sell %s: %s" % [item.display_name, mm.call("footer_text")])
			break
		bought += 1
		_say("buys %s (%d bits left)" % [item.display_name, _bits()])
		if item.kind != ShopItemScript.Kind.CARE:
			_nav_dirty = true
	await _think()
	await _press(&"ui_cancel")
	await _wait(0.5)
	if bool(mm.call("is_open")):
		_bug("Escape did not close the Market")
	return true


## What she wants from the Market right now, most wanted first (only what is listed and not
## already owned).
func _shopping_list() -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	var shop: Object = ranch.call("get_shop")
	var mm: Node = ranch.call("get_market_menu")
	if shop == null or mm == null:
		return out
	var by_id := {}
	for it: ShopItem in (mm.call("buy_rows") as Array):
		if bool(shop.call("listed", it)):
			by_id[it.id] = it
	# Food first, for the ponies in the pens: every food low on the shelf, the loved ones first.
	var loved := _loved_foods()
	for f: StringName in loved:
		var id := StringName(String(f))
		if by_id.has(id) and _pantry_count(f) < 6:
			out.append(by_id[id])
	for id: StringName in _gear_wishlist():
		if not by_id.has(id):
			continue
		var item: ShopItem = by_id[id]
		if item.kind == ShopItemScript.Kind.CARE:
			continue
		if item.kind == ShopItemScript.Kind.PERMIT:
			if bool(shop.call("owns_permit", item.permit_zone)):
				continue
		elif bool(shop.call("owns_gear", item.id)):
			continue
		out.append(item)
	return out


func _gear_wishlist() -> Array[StringName]:
	var base: Array[StringName] = [&"bigger_saddlebag", &"gallop_shoes", &"pony_whistle", &"long_beam"]
	match _path_name():
		"rescue":
			if want == "placement":
				base.append_array([&"permit_orchard", &"permit_lake", &"permit_nightmeadow"])
			else:
				base.append_array([&"permit_orchard", &"permit_lake", &"permit_nightmeadow", &"permit_everfree"])
		"factory":
			if want == "brightest_rainbow":
				base.append(&"calm_lamp")
	return base


## The foods the ponies in the pens (and the bag) love, most votes first, then the rest.
func _loved_foods() -> Array[StringName]:
	var votes := {}
	for pen in _pens():
		for inst: PonyInstance in pen.call("ponies"):
			if inst.is_marked():
				continue
			var f: StringName = PonyTraitsScript.favorite_of(inst)
			votes[f] = int(votes.get(f, 0)) + 1
	var out: Array[StringName] = []
	for f in votes:
		out.append(f)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return int(votes[a]) > int(votes[b]))
	if not (&"hay" in out):
		out.append(&"hay")
	return out


## Deliver ponies at the Depot: `pick` says which rows (Dictionaries) she hands over.
func _deliver(pick: Callable, limit: int) -> int:
	var depot := _node_pos(^"Buildings/Depot")
	_say("takes ponies to the Depot")
	if not await _approach(InteractionScript.Kind.DEPOT, depot, 3.2):
		return 0
	_stop()
	await _press(&"interact")
	await _wait(0.8)
	var dm: Node = ranch.call("get_depot_menu")
	if dm == null or not bool(dm.call("is_open")):
		return 0
	if int(dm.call("tab")) != 0:
		_bug("the Depot opened on tab %d, not Deliver" % int(dm.call("tab")))
	var sent := 0
	var guard := 0
	while guard < limit + 4 and sent < limit:
		guard += 1
		var rows: Array = dm.call("deliver_rows")
		var at := -1
		for i in rows.size():
			if bool(pick.call(rows[i] as Dictionary)):
				at = i
				break
		if at < 0:
			break
		await _think()
		await _menu_to(dm, at)
		var before := rows.size()
		await _press(&"ui_accept")
		await _wait(0.3)
		if bool(dm.call("is_confirming")):
			# A named pony: the menu asks, and the cursor starts on No. Up to Yes.
			await _menu_to(dm, 0)
			await _press(&"ui_accept")
			await _wait(0.3)
		await _wait(0.6)
		if (dm.call("deliver_rows") as Array).size() >= before:
			_say("the Depot did not take her")
			break
		sent += 1
	await _think()
	await _press(&"ui_cancel")
	await _wait(0.5)
	if bool(dm.call("is_open")):
		await _press(&"ui_cancel")
		await _wait(0.4)
	_say("delivered %d" % sent)
	return sent


## Which penned ponies are no use to her except at the Depot (before the reveal): the newest
## stock, unmarked, not coming along.
func _row_is_extra(r: Dictionary) -> bool:
	if not bool(r.get("stock", false)) or bool(r.get("marked", false)):
		return false
	var uid := StringName(str(r.get("uid", "")))
	var inst := _pen_pony(uid)
	return inst != null and _is_extra(inst)


## Before the reveal the first pen built is where the Blooms happen and the others are the
## shipping pens: a pony in a shipping pen who is not on her way to a Bloom goes to the Depot.
func _is_extra(inst: PonyInstance) -> bool:
	if not inst.is_stock() or inst.is_marked() or inst.bloom >= 0.3:
		return false
	var pens := _pens()
	for i in pens.size():
		for other: PonyInstance in pens[i].call("ponies"):
			if other.uid == inst.uid:
				return i > 0
	return false


func _pen_pony(uid: StringName) -> PonyInstance:
	for pen in _pens():
		for inst: PonyInstance in pen.call("ponies"):
			if inst.uid == uid:
				return inst
	return null


func _all_penned() -> Array[PonyInstance]:
	var out: Array[PonyInstance] = []
	for pen in _pens():
		for inst: PonyInstance in pen.call("ponies"):
			out.append(inst)
	return out


## Nothing pressing: walk somewhere with ponies, the way a person roams.
func _wander() -> void:
	var spawner: Node = ranch.get("spawner")
	var spots: Array = []
	for p: Node3D in spawner.call("get_spawned"):
		if is_instance_valid(p) and not p.is_in_group(&"penned") and _reachable(p.global_position):
			spots.append(p.global_position)
	if spots.is_empty():
		await _wait(2.0)
		return
	var to: Vector3 = spots[rng.randi() % spots.size()]
	await _walk(to, 8.0, 25.0)
	await _wait(rng.randf_range(0.5, 1.5))


func _status() -> void:
	var s := _story()
	var line := "STATUS ch %d path '%s' bits %d deliveries %d blooms %d rescued %d heat %d rank %d pylons %d allies %d bag %d" % [
		s.chapter, _path_name(), _bits(), s.deliveries, int(s.get_var("blooms", 0)),
		int(s.get_var("rescued", 0)), PathRulesScript.heat(s), PathRulesScript.rank(s),
		PathRulesScript.pylons_cut(s), StoryV1Script.allies(s), _bag().count() if _bag() != null else -1]
	for pen in _pens():
		var ps: Array = pen.call("ponies")
		var b := 0.0
		var h := 0.0
		for inst: PonyInstance in ps:
			b += inst.bloom
			h += inst.happiness
		var n := maxf(1.0, float(ps.size()))
		line += " | pen %d bloom %.2f happy %.2f" % [ps.size(), b / n, h / n]
	var w := _world()
	if w != null:
		line += " | %s cycle %d" % [WorldStateScript.phase_name(w.phase()), w.cycle_index()]
	var c := PathRulesScript.contract(s)
	if not c.is_empty():
		line += " | contract %s" % [c]
	line += " | real fps %d, process %.1f ms, physics %.1f ms, draws %d, game/wall %.2f" % [
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		_t() / maxf(1.0, (Time.get_ticks_msec() - _t_start_ms) / 1000.0)]
	_say(line)


# --- the brain --------------------------------------------------------------------------

func _brain() -> void:
	while not _done:
		if _t() - _last_status > 120.0:
			_last_status = _t()
			if _ranch_ok() and current_scene == ranch:
				_status()
		if await _follow_scene():
			continue
		_watch_story()
		if _check_finished():
			return
		await _tend_screens()
		if _menu() != "" and _menu() != "talk":
			await _wait(0.2)
			continue
		var p := _people()
		if p != null and bool(p.call("is_talking")):
			# Somebody started talking on her own (a scripted beat): read it.
			await _read_conversation(p)
			continue
		if await _talk_to_news():
			continue
		if await _path_work():
			continue
		await _wander()


var _seen_flags := {}
var _seen_counts := {}


## Milestones as the story reaches them (reading the flags, never setting one).
func _watch_story() -> void:
	var s := _story()
	if s == null:
		return
	for f in ["has_scoop", "met_fennel", "depot_explained", "invited", "color_day", "reveal_done",
			"static_met", "intake_ledger", "ally_pip", "ally_bramble", "ally_fennel", "jubilee_ready",
			"climax_done", "clover_rescued", "placed"]:
		if s.has_flag(f) and not _seen_flags.has(f):
			_seen_flags[f] = true
			_milestone("flag %s" % f)
	var counts := {"chapter": s.chapter, "deliveries": s.deliveries, "blooms": int(s.get_var("blooms", 0)),
		"rank": PathRulesScript.rank(s), "pylons": PathRulesScript.pylons_cut(s), "rescued": int(s.get_var("rescued", 0))}
	for k: String in counts:
		if int(counts[k]) != int(_seen_counts.get(k, 0)):
			_seen_counts[k] = int(counts[k])
			if k in ["chapter", "rank", "pylons"] or (k == "deliveries" and int(counts[k]) in [1, 3, 6, 10, 15, 20, 25]) \
					or (k in ["blooms", "rescued"] and int(counts[k]) % 5 in [0, 1, 2] and int(counts[k]) <= 30):
				_milestone("%s %d" % [k, int(counts[k])])


## The scene changed under her (the lift, a reload): follow it.
func _follow_scene() -> bool:
	var s := current_scene
	if s == null:
		await process_frame
		return true
	if s == ranch and _ranch_ok():
		return false
	if s.get("interior") != null:
		_say("rides the lift up (%s)" % str(FactoryRun.mode))
		_milestone("up the lift: %s" % str(FactoryRun.mode))
		factory = s
		await _play_factory(s)
		factory = null
		return true
	if s.get("people") != null and s.get("player") != null:
		for i in 60:
			await process_frame
		ranch = s
		await _attach(ranch)
		_milestone("the ranch (path '%s', ending '%s')" % [_path_name(), str(_story().get_var("ending", ""))])
		if _ending_seen == "placement":
			_aftermath_ok = str(_story().get_var("ending", "")) == "" and not _story().has_flag("placed") \
				and "placement" in (_story().get_var("endings_seen", []) as Array)
		return true
	await process_frame
	return true


func _check_finished() -> bool:
	var s := _story()
	var e := str(s.get_var("ending", "")) if s != null else ""
	if minutes > 0.0:
		if _t() >= minutes * 60.0:
			_finish_pacing()
			return true
		return false
	if e != "" and _ending_seen == "":
		_ending_seen = e
		_milestone("ENDING %s" % e)
	if _ending_seen == "":
		return false
	if _ending_seen != want:
		_finish_fail("wanted %s, the game played %s" % [want, _ending_seen])
		return true
	if not _epilogue_done:
		return false
	if want == "placement" and not _aftermath_ok:
		# The morning before comes back after the epilogue (a scene reload).
		if _t() - _ending_t() > 60.0:
			_finish_fail("Placement played but the morning before never came back clean")
			return true
		return false
	_finish_ok()
	return true


func _ending_t() -> float:
	for m in _milestones:
		if m.contains("ENDING"):
			var parts := m.strip_edges().split(" ")[0].split(":")
			return float(parts[0]) * 3600.0 + float(parts[1]) * 60.0 + float(parts[2])
	return _t()


## What to do next on the ranch, by priority. True if it did something.
func _path_work() -> bool:
	var s := _story()
	var path := _path_name()
	if path == "":
		return await _act_one_two()
	if path == "factory":
		return await _factory_work()
	return await _rescue_work()


# --- Acts One and Two -------------------------------------------------------------------

func _act_one_two() -> bool:
	var s := _story()
	if not s.has_flag("met_fennel"):
		# Before Fennel shows her the pens there is nothing to build: catch, and listen.
		if await _hunt():
			return true
		return false
	if await _build_pens(2 if s.deliveries < 6 else 4):
		return true
	if await _pen_the_bag():
		return true
	# Deliveries: the invitation wants six (and two Blooms). The ponies not yet coming
	# along go; the ones on their way to a Bloom stay.
	if s.has_flag("depot_explained") and _t() >= _depot_rest_until:
		var extras := 0
		for inst in _all_penned():
			if _is_extra(inst):
				extras += 1
		var need_room := _pen_with_room() == null and _bag() != null and _bag().count() > 0
		if extras >= 1 and (s.deliveries < 6 or need_room or extras >= 3):
			var n := await _deliver(_row_is_extra, mini(extras, 3))
			if n == 0:
				_depot_rest_until = _t() + 120.0
			return true
	if await _shop():
		return true
	if await _hunt(_sighted()):
		return true
	var bag := _bag()
	if bag != null and bag.count() > 0 and (bag.is_full() or _wild_near(30.0) == null):
		if await _pen_the_bag(true):
			return true
	if await _hunt():
		return true
	return false


## Ponies on their way to a Bloom (some progress), across the pens.
func _bloomers() -> int:
	var n := 0
	for inst in _all_penned():
		if inst.is_stock() and not inst.is_marked() and inst.bloom >= 0.03:
			n += 1
	return n


func _build_pens(up_to: int) -> bool:
	var pens := _pens()
	if pens.size() >= up_to:
		return false
	if not pens.is_empty() and _pen_with_room() != null:
		return false
	for slot: Node3D in _slots():
		if slot.call("get_built") != null or int(_build_fails.get(slot.name, 0)) >= 3:
			continue
		var want_id := &"pen_small"
		if _bits() >= 480 + 60:
			want_id = &"pen_grand"
		elif _bits() >= 150 + 30:
			want_id = &"pen_large"
		await _build_pen(slot, want_id)
		return true
	return false


# --- the Factory path -------------------------------------------------------------------

func _factory_work() -> bool:
	var s := _story()
	var c := PathRulesScript.contract(s)
	var gray := want == "gray_gold"
	var rescued := int(s.get_var("rescued", 0))
	if s.has_flag("jubilee_ready") and (not gray or rescued >= EndingsScript.GRAY_GOLD_RESCUES):
		# Marigold has the Jubilee for her: _talk_to_news() takes her there.
		if await _talk_to_news():
			return true
	if await _build_pens(4 if gray else 2):
		return true
	if await _pen_the_bag():
		return true
	# Deliver what the contract counts.
	var counts := func(r: Dictionary) -> bool:
		if not bool(r.get("stock", false)) or bool(r.get("marked", false)):
			return false
		var inst := _pen_pony(StringName(str(r.get("uid", ""))))
		if inst == null:
			return false
		if gray and _keep_for_bloom(inst):
			return false
		return _contract_counts(PathRulesScript.contract(_story()), _coat_of_stock(inst.stock))
	var ready := 0
	for inst in _all_penned():
		if inst.is_stock() and not inst.is_marked() and not (gray and _keep_for_bloom(inst)) \
				and _contract_counts(c, _coat_of_stock(inst.stock)):
			ready += 1
	if ready > 0 and not c.is_empty() and _t() >= _depot_rest_until:
		var left := int(c.get("want", 0)) - int(c.get("got", 0))
		if ready >= mini(left, 3) or _bag().is_full() or _pen_with_room() == null:
			var n := await _deliver(counts, ready)
			if n == 0:
				_depot_rest_until = _t() + 90.0
			return true
	# Brightest Rainbow: a pony about to Bloom goes to the Depot first (any delivery counts
	# toward something), so nopony Blooms after the reveal.
	if not gray and _t() >= _depot_rest_until:
		var close := false
		for inst in _all_penned():
			if inst.is_stock() and not inst.is_marked() and inst.bloom > 0.7:
				close = true
		if close:
			var n2 := await _deliver(func(r: Dictionary) -> bool:
				var inst2 := _pen_pony(StringName(str(r.get("uid", ""))))
				return inst2 != null and bool(r.get("stock", false)) and not inst2.is_marked() and inst2.bloom > 0.6, 6)
			if n2 == 0:
				_depot_rest_until = _t() + 90.0
			return true
	# Full pens of ponies the contract does not want: they go too (a pen is for working).
	if _pen_with_room() == null and _bag() != null and _bag().count() > 0 and _t() >= _depot_rest_until:
		var n3 := await _deliver(func(r: Dictionary) -> bool:
			var inst3 := _pen_pony(StringName(str(r.get("uid", ""))))
			return inst3 != null and bool(r.get("stock", false)) and not inst3.is_marked() \
				and not (gray and _keep_for_bloom(inst3)), 3)
		if n3 == 0:
			_depot_rest_until = _t() + 90.0
		return true
	if await _shop():
		return true
	var kind := str(c.get("kind", "any"))
	var filter := Callable()
	if kind == "vivid" or (kind == "jubilee" and int(c.get("vivid", 0)) < PathRulesScript.JUBILEE_VIVID):
		filter = func(p: Node) -> bool: return PathRulesScript.is_vivid(_coat_of_body(p))
	elif kind == "pastel":
		filter = func(p: Node) -> bool: return PathRulesScript.is_pastel(_coat_of_body(p))
	if gray and _bloom_keepers() < EndingsScript.GRAY_GOLD_RESCUES + 1 - rescued:
		filter = Callable()
	if await _hunt(null, filter):
		return true
	if filter.is_valid() and await _hunt(null, Callable()):
		return true
	return false


func _contract_counts(c: Dictionary, coat: Color) -> bool:
	match str(c.get("kind", "")):
		"any":
			return true
		"jubilee":
			if int(c.get("vivid", 0)) >= PathRulesScript.JUBILEE_VIVID:
				return true
			var left := int(c.get("want", 0)) - int(c.get("got", 0))
			var vivid_left := PathRulesScript.JUBILEE_VIVID - int(c.get("vivid", 0))
			return PathRulesScript.is_vivid(coat) or left > vivid_left
		"pastel":
			return PathRulesScript.is_pastel(coat)
		"vivid":
			return PathRulesScript.is_vivid(coat)
	return false


## Gray Gold: the ponies she is quietly letting Bloom (the ones furthest along).
func _keep_for_bloom(inst: PonyInstance) -> bool:
	var rescued := int(_story().get_var("rescued", 0))
	var need := EndingsScript.GRAY_GOLD_RESCUES + 1 - rescued
	if need <= 0:
		return false
	var ranked: Array[PonyInstance] = []
	for i in _all_penned():
		if i.is_stock() and not i.is_marked():
			ranked.append(i)
	ranked.sort_custom(func(a: PonyInstance, b: PonyInstance) -> bool: return a.bloom > b.bloom)
	var idx := ranked.find(inst)
	return idx >= 0 and idx < need


func _bloom_keepers() -> int:
	var n := 0
	for i in _all_penned():
		if i.is_stock() and not i.is_marked():
			n += 1
	return n


# --- the Rescue path --------------------------------------------------------------------

func _rescue_ready_for_climax() -> bool:
	var s := _story()
	if PathRulesScript.pylons_cut(s) < 4:
		return false
	if want == "lights_out":
		var net := int(s.get_var("rescued", 0)) - StoryV1Script.delivered_after_reveal(gs.get("book"))
		# The climax frees the line too (five or six); come up with enough to pass twenty.
		return StoryV1Script.allies(s) >= 3 and net >= EndingsScript.LIGHTS_OUT_RESCUES - 4
	return true


func _act3() -> Node:
	return ranch.get("act3")


func _site(id: String) -> Dictionary:
	var a := _act3()
	if a == null:
		return {}
	for s: Dictionary in a.get("sites"):
		if str(s.id) == id:
			return s
	return {}


func _rescue_work() -> bool:
	var s := _story()
	var a := _act3()
	if a == null:
		return false
	if want == "placement":
		return await _placement_work()
	# Static, first (she tells you about the pylons), and when it is time, for the lift.
	if _rescue_ready_for_climax() and await _talk_to_news():
		return true
	var night := _is_night()
	if want == "lights_out":
		if await _build_pens(4):
			return true
		if await _pen_the_bag():
			return true
		# One raid (Pip and Fennel want to hear of it), at night, with room in the bag.
		var raids := int(s.get_var("raids", 0))
		if raids < 1 and night and _night_left() > 90.0 and _region_open_for("corral_orchard"):
			if await _raid("corral_orchard"):
				return true
		# The Dye Vat, with a pony in the bag (Bramble wants to see it).
		if int(s.get_var("dyed", 0)) < 1 and _bag() != null and _bag().count() > 0:
			if await _use_site("dye_vat"):
				return true
	if night and _night_left() > 60.0:
		for pid: String in PathRulesScript.PYLONS:
			if pid in (s.get_var("pylons", []) as Array):
				continue
			if not _region_open_for(pid):
				continue
			if await _cut_pylon(pid):
				return true
	if want == "lights_out":
		# Marked ponies down the Lantern Line, freeing the pens for the next ones.
		var marked := 0
		for inst in _all_penned():
			if inst.is_marked():
				marked += 1
		if marked >= 4 and _region_open_for("lantern_gate") and await _use_site("lantern_gate"):
			return true
		if await _shop():
			return true
		if _bloomers_total() < 22 and await _hunt():
			return true
	else:
		if await _shop():
			return true
	return false


func _bloomers_total() -> int:
	var n := 0
	for inst in _all_penned():
		if inst.is_stock() and not inst.is_marked():
			n += 1
	return n + (_bag().count() if _bag() != null else 0)


## The region a site stands in is open (its permit is bought).
func _region_open_for(site_id: String) -> bool:
	var region := ""
	if site_id.begins_with("corral_"):
		region = site_id.substr(7)
	elif site_id.begins_with("pylon_"):
		region = {"pylon_meadow": "nightmeadow", "pylon_orchard": "orchard", "pylon_lake": "lake",
			"pylon_everfree": "everfree"}.get(site_id, "")
	elif site_id == "lantern_gate":
		region = "everfree"
	if region == "":
		return true
	var shop: Object = ranch.call("get_shop")
	return shop != null and bool(shop.call("owns_permit", StringName(region)))


## Walk to an Act Three site and get its prompt.
func _go_to_site(id: String) -> bool:
	var site := _site(id)
	if site.is_empty():
		return false
	var n: Node3D = site.node
	_say("heads for %s" % id)
	var reach := 3.0 if str(site.kind) != "corral" else 4.5
	await _walk(n.global_position, reach, 120.0)
	for i in 6:
		await _wait(0.3)
		var pr := _prompt()
		if _site_prompt_ok(site, pr):
			return true
		var ang := TAU * float(i) / 6.0
		await _walk(n.global_position + Vector3(cos(ang), 0, sin(ang)) * (reach * 0.7), 0.5, 6.0)
	_say("no prompt for %s (prompt '%s', interaction %s)" % [id, _prompt(), _interaction()])
	return false


func _site_prompt_ok(site: Dictionary, pr: String) -> bool:
	match str(site.kind):
		"pylon":
			return pr.contains("cut the pylon")
		"corral":
			return pr.contains("slip the gate")
		"gate":
			return pr.contains("Lantern Line")
		"vat":
			return pr.contains("Dye Vat")
	return false


func _cut_pylon(id: String) -> bool:
	if not await _go_to_site(id):
		_site_fail(id)
		return true
	var before := PathRulesScript.pylons_cut(_story())
	_stop()
	_hold(&"interact", true)
	var t0 := _t()
	while _t() - t0 < 7.0 and PathRulesScript.pylons_cut(_story()) == before:
		await physics_frame
	_hold(&"interact", false)
	await _wait(0.5)
	if PathRulesScript.pylons_cut(_story()) > before:
		_milestone("cut %s (%d of 4, heat %d)" % [id, PathRulesScript.pylons_cut(_story()), PathRulesScript.heat(_story())])
	else:
		_say("held E at %s but the pylon is still up (prompt '%s')" % [id, _prompt()])
		_site_fail(id)
	return true


func _raid(id: String) -> bool:
	var bag := _bag()
	if bag == null or bag.capacity - bag.count() < 1:
		return false
	if not await _go_to_site(id):
		_site_fail(id)
		return true
	var before := bag.count()
	_stop()
	_hold(&"interact", true)
	var t0 := _t()
	while _t() - t0 < 6.0 and bag.count() == before:
		await physics_frame
	_hold(&"interact", false)
	await _wait(0.5)
	if bag.count() > before:
		_milestone("raided %s (+%d in the bag, heat %d)" % [id, bag.count() - before, PathRulesScript.heat(_story())])
	else:
		_say("held E at %s but the gate did not slip (prompt '%s')" % [id, _prompt()])
		_site_fail(id)
	return true


var _site_fails := {}


func _site_fail(id: String) -> void:
	_site_fails[id] = int(_site_fails.get(id, 0)) + 1
	if int(_site_fails[id]) >= 3:
		_bug("could not work %s through input after 3 tries (last prompt '%s')" % [id, _prompt()])


func _use_site(id: String) -> bool:
	if int(_site_fails.get(id, 0)) >= 3:
		return false
	if not await _go_to_site(id):
		_site_fail(id)
		return true
	_stop()
	var s := _story()
	var dyed := int(s.get_var("dyed", 0))
	var sent := int(s.get_var("sent", 0))
	await _press(&"interact")
	await _wait(0.8)
	if int(s.get_var("dyed", 0)) > dyed:
		_milestone("dyed a pony at the vat")
	elif int(s.get_var("sent", 0)) > sent:
		_milestone("sent %d down the Lantern Line" % (int(s.get_var("sent", 0)) - sent))
	else:
		_say("E at %s did nothing (prompt '%s')" % [id, _prompt()])
		_site_fail(id)
	return true


## PLACEMENT: raid until the Heat is at the top, deliver nopony, and let a collection day come.
func _placement_work() -> bool:
	var s := _story()
	if await _build_pens(4):
		return true
	if await _pen_the_bag(true):
		return true
	if await _shop():
		return true
	if PathRulesScript.heat(s) < PathRulesScript.HEAT_MAX and _is_night() and _night_left() > 60.0:
		for region: String in ["orchard", "lake", "nightmeadow", "everfree"]:
			var cid: String = "corral_" + region
			if cid in (s.get_var("raided", []) as Array) or not _region_open_for(cid):
				continue
			if int(_site_fails.get(cid, 0)) >= 3:
				continue
			var bag := _bag()
			if bag.capacity - bag.count() < 1:
				await _pen_the_bag(true)
				return true
			if await _raid(cid):
				return true
	return false


# --- the Rainbow Factory ----------------------------------------------------------------

## Up the lift and through the Works the way a player goes: walk to whatever the scene is
## waiting for, creep past the lanterns, hold E where it asks, read what is said. The Factory
## takes her back down itself.
func _play_factory(f: Node) -> void:
	_stop()
	for i in 30:
		await process_frame
	await _attach(f)
	var t0 := _t()
	while current_scene == f and _t() - t0 < 1800.0:
		var people: Node = f.get("people")
		if people != null and bool(people.call("is_talking")):
			await _read_conversation(people)
			continue
		var g: Dictionary = f.get("goal")
		if g.is_empty():
			await _wait(0.25)
			continue
		var at: Vector3 = g.at
		if str(g.kind) == "area":
			await _sneak_to(f, at)
		elif str(g.kind) == "hold":
			_say("holds E to %s" % str(g.get("verb", "")))
			await _walk(at, 1.8, 40.0)
			_stop()
			_hold(&"interact", true)
			var h := 0.0
			while current_scene == f and not (f.get("goal") as Dictionary).is_empty() \
					and (f.get("goal") as Dictionary).get("verb") == g.get("verb") and h < 15.0:
				await physics_frame
				h += 1.0 / 60.0
				if player.global_position.distance_to(at) > 2.8:
					break
			_hold(&"interact", false)
			await _wait(0.3)
	_say("back down from the Factory")
	player = null
	rig = null


## Walk toward `at`, standing still whenever a patrol's lantern would catch the next step.
func _sneak_to(f: Node, at: Vector3) -> void:
	var patrols: Array = f.call("patrols") if f.has_method("patrols") else []
	var t0 := _t()
	var g0: Dictionary = f.get("goal")
	while _t() - t0 < 90.0 and current_scene == f:
		var g: Dictionary = f.get("goal")
		if g.is_empty() or g.get("area") != g0.get("area"):
			break
		var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
		if d < 0.8:
			# At the fallback point and the area has not fired: step about inside it.
			await _walk(at + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-2.5, 0.5)), 0.5, 3.0)
			continue
		var ahead := player.global_position + (at - player.global_position).normalized() * 1.6
		var seen := false
		for p in patrols:
			if is_instance_valid(p) and bool(p.get("enabled")) and (bool(p.call("sees", ahead)) or bool(p.call("sees", player.global_position))):
				seen = true
		if seen:
			_stop()
			_sneak = true
			await _wait(0.4)
			continue
		_sneak = not patrols.is_empty()
		await _walk(at, 0.7, 1.0)
	_sneak = false
	_stop()


# --- the end ----------------------------------------------------------------------------

func _summary() -> String:
	var lines: Array[String] = []
	lines.append("PLAYTHROUGH_SUMMARY ending=%s game=%s wall=%ds" % [want, _clock_text(_t()),
		(Time.get_ticks_msec() - _t_start_ms) / 1000])
	for m in _milestones:
		lines.append("PLAYTHROUGH_SUMMARY   " + m)
	for b in _bugs:
		lines.append("PLAYTHROUGH_SUMMARY   bug: " + b)
	return "\n".join(lines)


func _finish_ok() -> void:
	_out(_summary())
	_release_moves()
	_hold(&"interact", false)
	_hold(&"beam", false)
	_out("PLAYTHROUGH_%s %s game %s wall %ds" % ["DEV_OK" if _continued else "OK", want,
		_clock_text(_t()), (Time.get_ticks_msec() - _t_start_ms) / 1000])
	ok("ending %s" % want)


func _finish_fail(why: String) -> void:
	fail(why)


## Every failure (the watchdog's too) says where the run got to.
func fail(msg: String) -> void:
	if _done:
		return
	_out(_summary())
	_out("PLAYTHROUGH_FAILED %s %s" % [want, msg])
	_release_moves()
	super(msg)


func _finish_pacing() -> void:
	var nov: Novelty = gs.get("novelty")
	var horizon := float(gs.get("play_seconds"))
	print(_summary())
	print("BOT_OK %s" % NoveltyScript.clock(horizon))
	if pacing_path != "":
		var s := _story()
		var md := NoveltyScript.markdown(nov.entries, horizon, {"bot seed": seed_value,
			"catches": int(s.get_var("catches", 0)), "deliveries": s.deliveries,
			"blooms": int(s.get_var("blooms", 0)), "bits": _bits()})
		var f := FileAccess.open(pacing_path, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
			f.close()
		var a := NoveltyScript.analyse(nov.entries, horizon)
		print("PACING_%s %s" % ["OK" if a.ok else "FAILED", "; ".join(a.failures)])
	ok("pacing run")
