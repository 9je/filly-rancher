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
##   13  sighting_1     a rare canon pony appears somewhere open; every 7 min after, another
##   17  palace_flyer   the Palace on the Strip opens (the casino was shut till now)
##   26  newsletter     Pip photographs the ranch for the Corporation newsletter (a clue)
##   30  race_day       the track's first race day (after the Palace is open)
##   35  lost_foal      Pip's lost foal: bring her back for a reward
##   40  collector_visit  a Collector walks up to your fence, writes something down, leaves
##   45  starry         two starry Drifters (a rare coat) wander down from the hills

const GeneratorScript := preload("res://systems/pony_generator.gd")
const SIGHTING_FIRST := 13.0 * 60.0
const SIGHTING_EVERY := 7.0 * 60.0
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


func _physics_process(delta: float) -> void:
	if ranch == null or _gs() == null or not bool(ranch.get("_interactive")):
		return
	_check_t += delta
	if _check_t < 1.0:
		return
	_check_t = 0.0
	if not bool(ranch.call("_no_other_menu_open")):
		return
	var story := _story()
	var t := _t()
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
	elif t >= SIGHTING_FIRST:
		var n := int(story.get_var("sightings", 0))
		if t >= SIGHTING_FIRST + SIGHTING_EVERY * n and (sighting == null or not is_instance_valid(sighting)
				or t >= SIGHTING_FIRST + SIGHTING_EVERY * n + 120.0):
			if _sighting():
				story.set_var("sightings", n + 1)
	_check_lost_foal()


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
	for d: PonyData in reg.call("all"):
		if String(d.id).begins_with("stock_") or d.rarity < 1:
			continue
		# Caught (2) or delivered (3) already: Tumble points out somepony new.
		if book != null and int(book.call("state_of", d.id)) >= 2:
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
	var dir := _compass(at - _player().global_position)
	ranch.call("_toast", "Tumble: \"Look, look! %s, over to the %s!\"" % [pick.display_name, dir])
	ranch.call("_novelty", "event", "sighting_" + String(pick.id), "Tumble spots %s out in the grass" % pick.display_name)
	return true


func _compass(v: Vector3) -> String:
	var a := fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return names[int(round(a / 45.0)) % 8]


func _palace_flyer() -> void:
	_mark("palace_flyer")
	_story().set_flag("palace_open")
	ranch.call("_toast", "A flyer on the board: the Palace on the Strip has its GRAND OPENING tonight! Slots, the wheel, cards, and racing.")
	ranch.call("_novelty", "event", "palace_flyer", "The Palace on the Strip opens")


func _race_day() -> void:
	_mark("race_day")
	_story().set_flag("race_day")
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
	ranch.call("_toast", "Pip: \"A little filly's wandered off from town, out to the %s. Bring her home safe and there's %d bits in it.\"" % [
		_compass(at - _player().global_position), LOST_FOAL_REWARD])
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
	var start := _ground(14.0, 40.0)
	n.global_position = start
	n.setup(def)
	var stop := _ground(-4.0, 16.0)
	n.set_mode_walk_to(stop)
	ranch.call("_toast", "A Collector in a grey coat comes up the lane and stops at your fence.")
	ranch.call("_novelty", "clue", "collector_visit", "A Collector stops at the fence and takes notes")
	var t := create_tween()
	t.tween_interval(26.0)
	t.tween_callback(func() -> void:
		if is_instance_valid(n):
			ranch.call("_toast", "The Collector writes something on a clipboard, and leaves.")
			n.set_mode_walk_to(start))
	t.tween_interval(24.0)
	t.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


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
	ranch.call("_toast", "Pip: \"Smile! Cloudsdale wants you for the newsletter!\" Steward of the Week: %d ponies placed, \"a yield of %d%% above the valley average.\"" % [n, 40 + n * 7])
	ranch.call("_novelty", "clue", "newsletter", "Pip photographs you for the Corporation newsletter")
