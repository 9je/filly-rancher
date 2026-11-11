class_name Happenings
extends Node
## THINGS THAT HAPPEN TO YOU (MISSION.md, "Fun and anti-repetition rules": novelty every few
## minutes, and activities that rotate). The valley does not wait for the player to make
## the next thing happen: a sun shower brings pegasus Drifters down, Tumble spots a canon
## pony out in the grass, the Palace has its grand opening, the track has a race day, a foal
## goes missing. Each fires once a save, on the play clock and the story, with a toast and a
## novelty entry, and leaves the player something to go and do.
##
## The schedule (ALL in play minutes, each also waiting on its own condition):
##   9   sun_shower     three pegasus Drifters come down near you (after a couple of catches)
##   13  sighting_1     a rare canon pony appears somewhere open; then at most two a day, six
##                      minutes apart (RareGate.sighting_due; playtest 2026-11-08 item 12)
##   17  palace_flyer   the Palace on the Strip opens (the casino was shut till now)
##   26  newsletter     Pip photographs the ranch for the Corporation newsletter (a clue)
##   30  race_day       the track's first race day (after the Palace is open)
##   35  lost_foal      Pip's lost foal: bring her back for a reward
##   40  collector_visit  a Collector in a grey coat walks past your fence, pauses, walks on
##   45  starry         two starry Drifters (a rare coat) wander down from the hills

const GeneratorScript := preload("res://systems/pony_generator.gd")
const AccessoriesScript := preload("res://systems/accessories.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const RareGateScript := preload("res://systems/rare_gate.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const LOST_FOAL_REWARD := 150

var ranch: Node
## The canon pony Tumble last pointed out (the bot and the HUD both look for her).
var sighting: Node3D
var lost_foal: Node3D
var _check_t := 0.0


func _gs() -> Node:
	return ranch.get("_game_state")


func _story() -> Story:
	return _gs().get("story")


func _t() -> float:
	return float(_gs().get("play_seconds"))


func _done(id: String) -> bool:
	return id in (_story().get_var("happened", []) as Array)


func _mark(id: String) -> void:
	var list: Array = _story().get_var("happened", [])
	list.append(id)
	_story().set_var("happened", list)
	_story().set_var("happening_at", _t())


func _physics_process(delta: float) -> void:
	if ranch == null or _gs() == null or not bool(ranch.get("_interactive")):
		return
	_check_t += delta
	if _check_t < 1.0:
		return
	_check_t = 0.0
	if not out_and_free():
		return
	var story := _story()
	var t := _t()
	# ONE AT A TIME, AND ONLY WITH HER THERE (playtest 2026-11-10 items 3 and 5: Trixie, Derpy
	# and Rainbow Dash all at once; a shower's worth of events fired and gone while the game
	# sat idle). The ladder below is keyed off play time, so a long menu, the Palace or an idle
	# spell built up a backlog that then went off one a second. Now: EVENT_GAP between any two
	# world events, and nothing while she has stood still for IDLE_HOLD.
	_track_idle(delta_since_check())
	if _idle_for >= IDLE_HOLD:
		return
	if t - float(story.get_var("happening_at", -INF)) < EVENT_GAP:
		return
	var catches := int(story.get_var("catches", 0))
	if not _done("sun_shower") and t >= 9.0 * 60.0 and catches >= 2:
		_sun_shower()
	elif not _done("palace_flyer") and t >= 17.0 * 60.0:
		_palace_flyer()
	elif not _done("newsletter") and t >= 26.0 * 60.0:
		_newsletter()
	elif not _done("race_day") and t >= 30.0 * 60.0 and story.has_flag("palace_open"):
		_race_day()
	elif not _done("lost_foal") and t >= 35.0 * 60.0:
		_lost_foal()
	elif not _done("collector_visit") and t >= 40.0 * 60.0:
		_collector_visit()
	elif not _done("starry") and t >= 45.0 * 60.0:
		_starry()
	elif not _done("rainboom") and t >= 52.0 * 60.0:
		_rainboom()
	elif not _done("derpy_mail") and t >= 57.0 * 60.0:
		_derpy_mail()
	elif not _done("trixie_show") and t >= 63.0 * 60.0 and story.has_flag("palace_open"):
		_trixie_show()
	elif _sighting_due(story, t):
		if _sighting():
			var day := _cycle()
			if int(story.get_var("sighting_day", -1)) != day:
				story.set_var("sighting_day", day)
				story.set_var("sightings_today", 0)
			story.set_var("sightings_today", int(story.get_var("sightings_today", 0)) + 1)
			story.set_var("sighting_at", t)
			story.set_var("happening_at", t)
			story.set_var("sightings", int(story.get_var("sightings", 0)) + 1)
	_check_lost_foal()


## WORLD EVENTS WAIT UNTIL SHE IS OUT AND FREE (playtest 2026-11-08 item 13: sightings and
## spotting fired while she was in the casino or a menu, and she missed them): outdoors (not
## in the Palace), no menu up, nobody talking to her.
func out_and_free() -> bool:
	if not bool(ranch.call("_no_other_menu_open")) or bool(ranch.get("_in_palace")):
		return false
	var people: Node = ranch.get("people")
	return people == null or not bool(people.call("is_talking"))


## Seconds of play between two world events (the ladder's own spacing is minutes; this only
## bites when a backlog would fire them back to back).
const EVENT_GAP := 75.0
## Standing still this long, she is away from the keyboard: the world waits for her.
const IDLE_HOLD := 60.0
const IDLE_MOVE_M := 0.6
var _idle_for := 0.0
var _idle_at := Vector3.INF
var _last_check_ms := 0


func delta_since_check() -> float:
	var now := Time.get_ticks_msec()
	var d := 1.0 if _last_check_ms == 0 else float(now - _last_check_ms) / 1000.0
	_last_check_ms = now
	return clampf(d, 0.0, 5.0)


func _track_idle(d: float) -> void:
	var p := _player()
	if p == null:
		return
	if _idle_at == Vector3.INF or p.global_position.distance_to(_idle_at) > IDLE_MOVE_M:
		_idle_at = p.global_position
		_idle_for = 0.0
	else:
		_idle_for += d


func _cycle() -> int:
	var world: WorldState = ranch.call("get_world_state")
	return world.cycle_index() if world != null else 0


## A sighting may fire: at most RareGate.SIGHTINGS_PER_DAY a day, spaced, and not while the
## last one is still out there to be found.
func _sighting_due(story: Story, t: float) -> bool:
	if sighting != null and is_instance_valid(sighting) and not sighting.is_queued_for_deletion():
		return false
	var today := int(story.get_var("sightings_today", 0)) \
		if int(story.get_var("sighting_day", -1)) == _cycle() else 0
	return RareGateScript.sighting_due(today, float(story.get_var("sighting_at", -INF)), t)


func _player() -> Node3D:
	return ranch.get("player")


func _ground(x: float, z: float) -> Vector3:
	var terrain: Node = ranch.get("terrain")
	var y := float(terrain.call("height_at", x, z)) if terrain != null and terrain.has_method("height_at") else 0.0
	return Vector3(x, y + 0.3, z)


## A point `near..far` metres from the player that the herd could stand on (inside the
## map, clear of the homestead's buildings), or INF.
func _spot(near: float, far: float) -> Vector3:
	var p := _player().global_position
	for i in 16:
		var a := randf() * TAU
		var r := randf_range(near, far)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		if absf(x) > 95.0 or absf(z) > 95.0:
			continue
		if Vector2(x, z - (-4.0)).length() < 16.0:
			continue
		if not _open_at(x, z):
			continue
		return _ground(x, z)
	# Nowhere open that far out (she is deep in a corner of the map): nearer, anywhere open.
	for i in 24:
		var a := randf() * TAU
		var r := randf_range(10.0, near)
		var x := clampf(p.x + cos(a) * r, -95.0, 95.0)
		var z := clampf(p.z + sin(a) * r, -95.0, 95.0)
		if _open_at(x, z):
			return _ground(x, z)
	return Vector3.INF


## Whether the ground at (x, z) is somewhere the player may go (no shut permit fence).
func _open_at(x: float, z: float) -> bool:
	var reg: RegionRegistry = ranch.call("_regions_registry")
	var region: RegionData = reg.region_at(Vector2(x, z)) if reg != null else null
	if region == null or region.permit_cost <= 0:
		return true
	var shop: Object = ranch.call("get_shop")
	return shop != null and bool(shop.call("owns_permit", region.id))


func _stock_data() -> PonyData:
	var reg: Object = _gs().call("get_registry")
	return reg.call("by_id", &"stock_curious") if reg != null else null


# --- the happenings ---------------------------------------------------------------------

func _sun_shower() -> void:
	_mark("sun_shower")
	var spawner: Node = ranch.get("spawner")
	var data: PonyData = load("res://data/hidden/stock_curious.tres")
	var made := 0
	for i in 3:
		var at := _spot(9.0, 16.0)
		if at == Vector3.INF:
			continue
		var look := GeneratorScript.generate(int(_t() * 1000.0) + i * 7, {"race": &"pegasus"})
		if spawner.call("spawn_guest", data, look.to_dict(), at) != null:
			made += 1
	ranch.call("_toast", "A sun shower! %d pegasus Drifters swoop down out of the clouds to drink." % made)
	ranch.call("_novelty", "event", "sun_shower", "A sun shower brings pegasus Drifters down")


## Tumble points one out: a canon pony nopony has caught yet, somewhere open.
func _sighting() -> bool:
	var reg: Object = _gs().call("get_registry")
	var book: Object = _gs().get("compendium")
	if reg == null:
		return false
	var pool: Array = []
	var world: WorldState = ranch.call("get_world_state")
	for d: PonyData in reg.call("all"):
		if String(d.id).begins_with("stock_") or d.rarity < 1:
			continue
		# Caught (2) or delivered (3) already: Tumble points out somepony new.
		if book != null and int(book.call("state_of", d.id)) >= 2:
			continue
		# HER HOURS, HER WEATHER, HER DECORATION, ONE NEW LEGENDARY A DAY (RareGate, item 12):
		# Tumble only points out somepony who could really be out there now.
		if world != null and not d.available(world.phase(), world.weather()):
			continue
		if not bool(ranch.call("rare_allowed", d)):
			continue
		pool.append(d)
	if pool.is_empty():
		return false
	pool.sort_custom(func(a: PonyData, b: PonyData) -> bool: return a.rarity < b.rarity)
	var pick: PonyData = pool[randi() % mini(4, pool.size())]
	var at := _spot(22.0, 40.0)
	if at == Vector3.INF:
		return false
	var spawner: Node = ranch.get("spawner")
	sighting = spawner.call("spawn_guest", pick, {}, at, 6.0)
	if sighting == null:
		return false
	# THE TRAIL TAKES YOU TO HER, not a compass word (PT8; the owner could not tell which way
	# was north-east and never found Octavia). Ranch.guide picks her up as &"sighting".
	ranch.call("_toast", "Tumble: \"Look, look! It's %s! Follow the sparkles, quick!\"" % pick.display_name)
	# A RARE ONE IS SHOWN, NOT ONLY NAMED (P8 idea F11): three seconds of where she is, from
	# over the player's shoulder, then the trail.
	if pick.rarity >= PonyData.Rarity.RARE and bool(ranch.get("_interactive")):
		var player: Node3D = ranch.get("player")
		if player != null:
			var eye := player.global_position + Vector3.UP * 3.0 + (player.global_position - at).normalized() * 3.0
			Cinematic.shared(ranch.get_tree()).play([
				{"from": "here", "to": eye, "look_node": sighting, "look_height": 1.0, "time": 1.2},
				{"from": eye, "to": eye.lerp(at, 0.35) + Vector3.UP, "look_node": sighting,
					"look_height": 1.0, "time": 2.2, "caption": "Tumble: \"Look! It's %s!\"" % pick.display_name},
			], {"freeze": [player], "host": ranch})
	ranch.call("_novelty", "event", "sighting_" + String(pick.id), "Tumble spots %s out in the grass" % pick.display_name)
	return true


func _palace_flyer() -> void:
	_mark("palace_flyer")
	_story().set_flag("palace_open")
	ranch.call("_toast", "A flyer on the board: the Palace on the Strip has its GRAND OPENING tonight! Slots, the wheel, cards, and racing.")
	ranch.call("_novelty", "event", "palace_flyer", "The Palace on the Strip opens")


func _race_day() -> void:
	_mark("race_day")
	_story().set_flag("race_day")
	# She has raced already (playtest 2026-11-10 item 6): the invitation would be old news.
	var gs := _gs()
	var nov = gs.get("novelty") if gs != null else null
	if nov != null and nov.has_method("has") and bool(nov.call("has", "first_race")):
		return
	ranch.call("_toast", "Race day at the Palace track! Bring a pony from your pens and enter her. Show-offs run faster.")
	ranch.call("_novelty", "event", "race_day", "Race day at the track")


func _lost_foal() -> void:
	var at := _spot(30.0, 55.0)
	if at == Vector3.INF:
		return
	_mark("lost_foal")
	var spawner: Node = ranch.get("spawner")
	var data: PonyData = load("res://data/hidden/stock_shy.tres")
	var look := GeneratorScript.generate(424242, {"foal": true})
	lost_foal = spawner.call("spawn_guest", data, look.to_dict(), at, 5.0)
	if lost_foal != null:
		lost_foal.set_meta(&"lost_foal", true)
		_story().set_var("lost_foal_seed", int(look.rng_seed))
	# The trail leads to her (PT8: a compass word told the owner nothing).
	if lost_foal != null:
		sighting = lost_foal
	ranch.call("_toast", "Pip: \"A little filly's wandered off from town! Follow the sparkles and bring her home safe: there's %d bits in it.\"" % LOST_FOAL_REWARD)
	ranch.call("_novelty", "npc", "lost_foal", "Pip asks you to find a lost foal")


## The lost foal, once she is in your saddlebag: home, and the reward.
func _check_lost_foal() -> void:
	if not _done("lost_foal") or _done("lost_foal_home"):
		return
	var seed_value := int(_story().get_var("lost_foal_seed", 0))
	var bag: Storage = ranch.call("_bag")
	if bag == null:
		return
	for inst: PonyInstance in bag.contents():
		if int(inst.stock.get("seed", -1)) == seed_value:
			_mark("lost_foal_home")
			var econ: Object = ranch.call("get_economy")
			if econ != null:
				econ.call("grant", LOST_FOAL_REWARD)
			ranch.call("_toast", "You found the lost foal! Pip sends %d bits, and the filly's mother sends a pie." % LOST_FOAL_REWARD)
			ranch.call("_novelty", "story", "lost_foal_home", "Brought the lost foal home")
			return


## A Collector in a grey coat comes up the lane, stops at the fence, looks at your pens for a
## while, writes something down, and goes. Nopony says anything about it. (A clue.)
func _collector_visit() -> void:
	_mark("collector_visit")
	var def := CharacterDef.new()
	def.id = &"collector_visit"
	def.display_name = "Collector"
	def.char_seed = 4401
	def.look = {"coat": "8a8f99", "mane": "4d525c", "mane2": "5f6470", "tail": "4d525c"}
	var n: Npc = (load("res://actors/npc/npc.gd") as Script).new()
	ranch.add_child(n)
	# A WALK BY, NOT A VISIT (PT10; owner, 2026-11-05: "it should have been just more of a
	# mysterious walk by than a slow shuffle to me then walk away", and the line named a coat
	# he was not wearing). He comes along the lane at a walk, stops by the fence for a few
	# seconds with his clipboard, and walks on out of sight the other way.
	var start := _ground(34.0, 30.0)
	var by_fence := _ground(-2.0, 18.0)
	var gone := _ground(-38.0, 26.0)
	n.global_position = start
	n.setup(def)
	_dress_collector(n)
	n.walk_speed = COLLECTOR_SPEED
	n.set_mode_walk_to(by_fence)
	# NO NARRATION (PS8 item 56a): the walk-by is shown, never told. The toasts named a coat
	# and a clipboard he did not have; now he has both and nothing says so.
	ranch.call("_novelty", "clue", "collector_visit", "A Collector walks past and takes notes")
	var t := create_tween()
	t.tween_interval(start.distance_to(by_fence) / COLLECTOR_SPEED + 0.5)
	t.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.act(&"neutral", &"nod"))
	t.tween_interval(3.5)
	t.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.set_mode_walk_to(gone))
	t.tween_interval(by_fence.distance_to(gone) / COLLECTOR_SPEED + 1.0)
	t.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


## His grey coat and his clipboard, on his rig, in his own toon.
static func _dress_collector(n: Node) -> void:
	var visuals := n.get_node_or_null(^"Visuals")
	if visuals == null or visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	for id: StringName in [&"collector_coat", &"clipboard"]:
		var piece: Node3D = AccessoriesScript.wear_kit(body, id)
		if piece != null and ToonStyler.shading_enabled:
			PonyPaintScript.paint_piece(piece)


## A brisk walk, not a shuffle.
const COLLECTOR_SPEED := 1.7


## Two Drifters with stars in their coats, the rarest look the valley has, wander in.
func _starry() -> void:
	_mark("starry")
	var spawner: Node = ranch.get("spawner")
	var data: PonyData = load("res://data/hidden/stock_shy.tres")
	var made := 0
	for i in 2:
		var at := _spot(14.0, 26.0)
		if at == Vector3.INF:
			continue
		var look := GeneratorScript.generate(55500 + i * 3, {"variant": &"starry"})
		if spawner.call("spawn_guest", data, look.to_dict(), at, 6.0) != null:
			made += 1
	ranch.call("_toast", "Tumble: \"Look at their coats! They've got STARS in them!\" %d starry Drifters wander down from the hills." % made)
	ranch.call("_novelty", "pony", "starry_drifters", "Starry Drifters, the rarest coat, wander in")


## STEWARD OF THE WEEK. Pip takes a picture of you and your pens for the Corporation's
## newsletter; the caption under it is all yield. (A clue, and a smile for the camera.)
func _newsletter() -> void:
	_mark("newsletter")
	var n := int(_story().deliveries)
	# THE CAPTION IS JUST A CAPTION NOW (PT10; owner: the clues were "a little too on the
	# nose a little too early"): the yield figure waits for later in the story.
	ranch.call("_toast", "Pip: \"Smile! You're in the Cloudsdale newsletter!\" Steward of the Week: %d ponies placed." % n)
	ranch.call("_novelty", "clue", "newsletter", "Pip photographs you for the Corporation newsletter")


## A canon pony by id, standing at `at`, unless the player has already caught or delivered
## her (then the moment plays without her). Returns the pony or null.
func _canon_guest(id: StringName, at: Vector3, roam: float = 6.0) -> Node3D:
	var reg: Object = _gs().call("get_registry")
	var book: Object = _gs().get("compendium")
	if reg == null or at == Vector3.INF:
		return null
	var data: PonyData = reg.call("by_id", id)
	if data == null or (book != null and int(book.call("state_of", id)) >= 2):
		return null
	return ranch.get("spawner").call("spawn_guest", data, {}, at, roam)


## RAINBOW DASH'S SONIC RAINBOOM (Ben's favourite): a ring of every colour bursts across
## the sky, and the pony who made it lands somewhere near, looking pleased with herself.
func _rainboom() -> void:
	_mark("rainboom")
	var p := _player().global_position
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var sky := p + dir * 40.0 + Vector3(0, 28.0, 0)
	_rainbow_ring(sky)
	var sound := get_node_or_null("/root/Sound")
	if sound != null:
		sound.call("play_at", &"sparkle", p)
	var dash := _canon_guest(&"rainbowdash", _spot(16.0, 26.0))
	if dash != null:
		sighting = dash
	var where := " Rainbow Dash lands nearby, hooves on hips. Follow the sparkles!" if dash != null else ""
	ranch.call("_toast", "KA-BOOM! A Sonic Rainboom rolls across the sky!%s" % where)
	ranch.call("_novelty", "event", "rainboom", "Rainbow Dash's Sonic Rainboom over the valley")


func _rainbow_ring(at: Vector3) -> void:
	var cols := [Color(0.94, 0.25, 0.3), Color(0.98, 0.6, 0.2), Color(0.98, 0.9, 0.3),
		Color(0.4, 0.85, 0.4), Color(0.3, 0.65, 0.98), Color(0.6, 0.4, 0.9)]
	for i in cols.size():
		var ring := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3(0, 0, 1)
		pm.emission_ring_radius = 2.0 + i * 0.6
		pm.emission_ring_inner_radius = 1.6 + i * 0.6
		pm.emission_ring_height = 0.2
		pm.direction = Vector3(1, 0, 0)
		pm.spread = 180.0
		pm.flatness = 1.0
		pm.radial_velocity_min = 14.0
		pm.radial_velocity_max = 16.0
		pm.gravity = Vector3.ZERO
		pm.color = cols[i]
		ring.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(1.4, 1.4)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_texture = BloomCeremony.star_texture()
		quad.material = mat
		ring.draw_pass_1 = quad
		ring.amount = 160
		ring.lifetime = 2.2
		ring.one_shot = true
		ring.explosiveness = 1.0
		ranch.add_child(ring)
		ring.global_position = at
		ring.look_at(_player().global_position, Vector3.UP)
		ring.emitting = true
		get_tree().create_timer(3.0).timeout.connect(ring.queue_free)


## DERPY'S MAIL MIX-UP: she drops in at the mailbox with a letter that is not yours (it is
## for Twilight), says sorry, and leaves a muffin's worth of apples to make up for it.
func _derpy_mail() -> void:
	_mark("derpy_mail")
	var box: Node3D = ranch.call("get_mailbox")
	var at := _ground(box.global_position.x + 2.5, box.global_position.z + 2.0) if box != null else _spot(8.0, 14.0)
	var derpy := _canon_guest(&"derpyhooves", at, 4.0)
	var inv: Inventory = _gs().get("inventory")
	if inv != null:
		inv.add(&"apple", 3)
	var who := "Derpy" if derpy != null else "A grey pegasus with a mail bag"
	ranch.call("_toast", "%s crash-lands by your mailbox with a letter for... Twilight Sparkle? \"I just don't know what went wrong!\" She leaves you 3 apples to say sorry." % who)
	ranch.call("_novelty", "npc", "derpy_mail", "Derpy's mail mix-up at the mailbox")


## THE GREAT AND POWERFUL TRIXIE plays the Strip: a show outside the Palace, and Trixie
## herself on the boardwalk for anypony brave enough to try the Scoop on her.
func _trixie_show() -> void:
	_mark("trixie_show")
	var at := _ground(randf_range(-8.0, 8.0), 66.0)
	var trixie := _canon_guest(&"trixie", at, 5.0)
	var tail := " She's on the Strip right now." if trixie != null else ""
	ranch.call("_toast", "A poster on the board: THE GREAT AND POWERFUL TRIXIE, LIVE outside the Palace! Tonight only!%s" % tail)
	ranch.call("_novelty", "event", "trixie_show", "The Great and Powerful Trixie plays the Strip")
