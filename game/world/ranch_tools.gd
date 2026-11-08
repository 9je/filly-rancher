class_name RanchTools
extends Node
## THE GEAR THAT CHANGES HOW YOU PLAY (MISSION.md, "Fun and anti-repetition rules"): each
## of these is a new verb, a new movement, a new option or a chore taken off your hooves,
## not a bigger number. Built by ranch.gd, which owns the world; this node only reads the
## player's buttons and asks the ranch to do things.
##
##   Treat Pouch      F    throw a treat where you look (without it, F drops one at your hooves);
##                         a pony who loves it trots over and eats, calm
##                         (she holds easy in the Scoop), and a pen pony gets her favorite meal
##   Gallop Shoes     Ctrl a burst of speed
##   Pony Whistle     Q    every wild pony near you stops still for a few seconds
##   Scoop Launcher   E    aimed at one of your pens: the pony at the top of the bag sails in
##   Steward's Monocle     the pony under the crosshair: her name, quirk and favorite food
##   Gem Chute             the pens' gems are sold as they are made: no trips to the Market
##   Depot Cart            (ranch.gd, at dawn) full pens' unmarked ponies go to the Depot
##   Lure Post             (Factory path) wild ponies drift in toward the ranch
##   Yield Lens            (Factory path) the Monocle shows how vivid she is, and what she pays

const PonyTraitsScript := preload("res://systems/pony_traits.gd")
const NeedsScript := preload("res://systems/needs.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const ToonStylerScript := preload("res://systems/toon_styler.gd")
const PathRulesScript := preload("res://systems/path_rules.gd")

const TREAT_RANGE := 16.0
const TREAT_LURE_RADIUS := 6.5
const TREAT_COOLDOWN := 1.0
const WHISTLE_RADIUS := 15.0
const WHISTLE_SECONDS := 4.0
const WHISTLE_COOLDOWN := 7.0
const GALLOP_SECONDS := 2.6
const GALLOP_COOLDOWN := 4.0
const GALLOP_MULT := 1.75
const LAUNCH_RANGE := 24.0
const CHUTE_PERIOD := 15.0
const LURE_PERIOD := 20.0
const FOOD_COLORS := {&"hay": Color(0.93, 0.8, 0.38), &"carrot": Color(0.98, 0.52, 0.16),
	&"apple": Color(0.88, 0.16, 0.2), &"daisy": Color(0.97, 0.97, 0.92), &"daffodil": Color(1.0, 0.86, 0.2)}

signal used(tool: StringName)

var ranch: Node
var _treat_cd := 0.0
var _whistle_cd := 0.0
var _gallop_t := 0.0
var _gallop_cd := 0.0
var _chute_t := 0.0
var _chute_bits := 0
var _chute_toast_t := 0.0
var _lure_t := 0.0
var _launch_slot: Node = null


func owns(gear: StringName) -> bool:
	return bool(ranch.call("_owns", gear))


func _gs() -> Node:
	return ranch.get("_game_state")


func _player() -> CharacterBody3D:
	return ranch.get("player")


func _free_to_act() -> bool:
	return bool(ranch.get("_interactive")) and bool(ranch.call("_no_other_menu_open"))


func _physics_process(delta: float) -> void:
	if ranch == null or _gs() == null or not bool(ranch.get("_interactive")):
		return
	_treat_cd = maxf(0.0, _treat_cd - delta)
	_whistle_cd = maxf(0.0, _whistle_cd - delta)
	_gallop_cd = maxf(0.0, _gallop_cd - delta)
	if _gallop_t > 0.0:
		_gallop_t -= delta
		if _gallop_t <= 0.0:
			_player().set("speed_mult", 1.0)
	if _free_to_act():
		if Input.is_action_just_pressed(&"gallop"):
			gallop()
		if Input.is_action_just_pressed(&"whistle"):
			whistle()
		if Input.is_action_just_pressed(&"treat"):
			toss_treat()
	_tick_chute(delta)
	_tick_lure(delta)
	_update_monocle()


# --- Gallop Shoes ---------------------------------------------------------------------------

func gallop() -> bool:
	if not owns(&"gallop_shoes") or _gallop_cd > 0.0 or _gallop_t > 0.0:
		return false
	_gallop_t = GALLOP_SECONDS
	_gallop_cd = GALLOP_SECONDS + GALLOP_COOLDOWN
	_player().set("speed_mult", GALLOP_MULT)
	_sound(&"scoop_pop")
	ranch.call("_novelty", "mechanic", "first_gallop", "Galloped in the Gallop Shoes")
	used.emit(&"gallop_shoes")
	return true


func is_galloping() -> bool:
	return _gallop_t > 0.0


# --- Pony Whistle ---------------------------------------------------------------------------

func whistle() -> int:
	if not owns(&"pony_whistle") or _whistle_cd > 0.0:
		return 0
	_whistle_cd = WHISTLE_COOLDOWN
	var stilled := 0
	for p in _wild():
		if p.global_position.distance_to(_player().global_position) <= WHISTLE_RADIUS:
			p.set("calm", maxf(float(p.get("calm")), WHISTLE_SECONDS))
			if int(p.get("state")) < 5:
				p.call("_transition_to", 0)
			stilled += 1
	_pulse(_player().global_position, Color(1.0, 0.85, 0.4), WHISTLE_RADIUS)
	_sound(&"ui_confirm")
	ranch.call("_toast", "Fweeet! %s" % ("%d stop still." % stilled if stilled > 0 else "Nopony near enough to hear."))
	ranch.call("_novelty", "mechanic", "first_whistle", "Blew the Pony Whistle")
	used.emit(&"pony_whistle")
	return stilled


# --- Treat Pouch ----------------------------------------------------------------------------

## BAIT FOR EVERYONE (P8 S3; idea A3: "drop her favourite food, she comes to eat, and while
## she eats she is easy"). Without the Treat Pouch the food is DROPPED at her hooves and a pony
## within DROP_LURE_RADIUS who fancies it comes to eat; the Pouch THROWS it where she looks.
const DROP_AHEAD := 1.6
const DROP_LURE_RADIUS := 11.0


## Toss (with the Pouch) or drop (without) a treat. Returns how many ponies came for it.
func toss_treat() -> int:
	if _treat_cd > 0.0:
		return 0
	var pouch := owns(&"treat_pouch")
	var pantry: Inventory = _gs().get("inventory")
	var target := _aimed_pony()
	var food := _pick_food(pantry, target)
	if food == &"":
		ranch.call("_toast", "The treat pouch is empty. Buy some feed at the Market.")
		return 0
	_treat_cd = TREAT_COOLDOWN
	pantry.remove(food, 1)
	var at := _landing() if pouch else _drop_point()
	_fly(food, at)
	var came := 0
	var who := ""
	var lure := TREAT_LURE_RADIUS if pouch else DROP_LURE_RADIUS
	for p in _wild():
		if p.global_position.distance_to(at) <= lure and bool(p.call("offer_treat", at, food)):
			came += 1
			who = _name_of(p)
	var fed := _feed_pen_at(at, food)
	var label := String(food)
	if came > 0:
		ranch.call("_toast", "%s trots over for the %s." % [who, label] if came == 1 else "%d ponies trot over for the %s." % [came, label])
	elif fed != "":
		ranch.call("_toast", "%s gets a %s from your hoof." % [fed, label])
	else:
		ranch.call("_toast", "Nopony nearby fancied the %s." % label)
	ranch.call("_novelty", "mechanic", "first_treat", "Tossed a treat from the Treat Pouch" if pouch else "Dropped a treat for a pony")
	used.emit(&"treat_pouch")
	return came


func _pick_food(pantry: Inventory, target: Node3D) -> StringName:
	if pantry == null:
		return &""
	if target != null:
		var fav := PonyTraitsScript.favorite_for(target.call("get_stock"), target.call("get_data"))
		if pantry.count(fav) > 0:
			return fav
	for f in PonyTraitsScript.FOODS:
		if pantry.count(f) > 0:
			return f
	return &""


## A treat thrown into one of your pens: the nearest resident gets it as a meal.
func _feed_pen_at(at: Vector3, food: StringName) -> String:
	for slot in ranch.call("_plot_slots"):
		var pen: Node = (slot as Node).call("get_built")
		if pen == null or not pen.has_method("ponies"):
			continue
		if Vector2(at.x - slot.global_position.x, at.z - slot.global_position.z).length() > 4.6:
			continue
		var best: PonyInstance = null
		var best_d := INF
		for inst: PonyInstance in pen.call("ponies"):
			var b: Node3D = pen.call("body_of", inst.uid)
			var d := b.global_position.distance_to(at) if b != null else 3.0
			if d < best_d:
				best_d = d
				best = inst
		if best != null and NeedsScript.feed(best, food):
			if NeedsScript.is_favorite(best, food):
				best.favorite_glow = 180.0
			return best.display_name()
	return ""


# --- Scoop Launcher -------------------------------------------------------------------------

## What the launcher would do right now (the ranch shows it when it has nothing of its own).
func offer(key: String) -> String:
	_launch_slot = null
	if not owns(&"scoop_launcher"):
		return ""
	var bag: Storage = _bag()
	if bag == null or bag.count() == 0:
		return ""
	var hit := _aim_hit(LAUNCH_RANGE + 8.0)
	if hit == Vector3.INF or hit.distance_to(_player().global_position) > LAUNCH_RANGE:
		return ""
	for slot in ranch.call("_plot_slots"):
		var pen: Node = (slot as Node).call("get_built")
		if pen == null or not pen.has_method("is_full") or bool(pen.call("is_full")):
			continue
		if Vector2(hit.x - slot.global_position.x, hit.z - slot.global_position.z).length() <= 5.0:
			_launch_slot = slot
			var top: PonyInstance = bag.peek()
			return "%s: launch %s into the pen" % [key, top.display_name() if top != null else "her"]
	return ""


func work(just_pressed: bool) -> void:
	if not just_pressed or _launch_slot == null:
		return
	launch(_launch_slot)


func launch(slot: Node) -> bool:
	var bag: Storage = _bag()
	if slot == null or bag == null or bag.count() == 0:
		return false
	var from := _player().global_position + Vector3(0, 1.4, 0)
	var to: Vector3 = (slot as Node3D).global_position + Vector3(0, 0.6, 0)
	if not bool(ranch.call("_move_pony_into_pen", slot)):
		return false
	_arc_orb(from, to, Color(1.0, 0.8, 0.95))
	_sound(&"scoop_pop")
	ranch.call("_novelty", "mechanic", "first_launch", "Launched a pony into a pen with the Scoop Launcher")
	used.emit(&"scoop_launcher")
	return true


# --- Gem Chute ------------------------------------------------------------------------------

func _tick_chute(delta: float) -> void:
	if not owns(&"gem_chute"):
		return
	_chute_t += delta
	_chute_toast_t += delta
	if _chute_t < CHUTE_PERIOD:
		return
	_chute_t = 0.0
	ranch.call("collect_gems")
	var shop: Object = ranch.call("get_shop")
	if shop == null:
		return
	var pouch: Object = _gs().get("gems")
	for rarity in 4:
		var n := int(pouch.call("count", rarity))
		if n > 0:
			_chute_bits += int(shop.call("sell", rarity, n))
	if _chute_bits > 0 and _chute_toast_t >= 60.0:
		ranch.call("_toast", "Gem Chute: Bramble sent up %d bits." % _chute_bits)
		ranch.call("_novelty", "mechanic", "first_chute", "The Gem Chute sold the pens' gems on its own")
		ranch.call("_push_balance") if ranch.has_method("_push_balance") else null
		_chute_bits = 0
		_chute_toast_t = 0.0


# --- Lure Post (Factory path) ---------------------------------------------------------------

func _tick_lure(delta: float) -> void:
	if not owns(&"lure_post"):
		return
	_lure_t += delta
	if _lure_t < LURE_PERIOD:
		return
	_lure_t = 0.0
	var home := Vector3(-6.0, 0.0, 12.0)
	for p in _wild():
		if p.global_position.distance_to(home) < 70.0 and p.global_position.distance_to(home) > 12.0:
			p.call("offer_treat", home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), &"lure")
			return


# --- the Monocle and the Yield Lens ---------------------------------------------------------

## WHO IS UNDER THE CROSSHAIR, FOR EVERYONE NOW (P8; playtest 2026-11-08 items 9, 10). A
## Drifter, a Bloomed Drifter and a named pony looked alike out in the grass, and her
## favourite food (the bait, S3) was the Monocle's secret. The plain line is free: what she
## is and what she loves. The Monocle adds her quirk, the Yield Lens her vividness.
func _update_monocle() -> void:
	var hud := ranch.get_node_or_null(^"HUD")
	if hud == null or not hud.has_method("set_target_info"):
		return
	if not _free_to_act():
		hud.call("set_target_info", "")
		return
	var p := _aimed_pony()
	if p == null:
		hud.call("set_target_info", "")
		return
	var inst := PonyInstance.new()
	inst.stock = p.call("get_stock")
	var data: PonyData = p.call("get_data")
	if data != null:
		inst.data_id = data.id
	var fav := PonyTraitsScript.favorite_for(inst.stock, data)
	var loves := "loves %s" % PonyTraitsScript.FOOD_PLURAL.get(fav, "hay")
	if not (owns(&"steward_monocle") or owns(&"yield_lens")):
		hud.call("set_target_info", "%s, %s" % [kind_word(inst, data), loves])
		return
	var q := PonyTraitsScript.quirk_for(inst.stock, inst.data_id)
	var line := "%s  --  %s%s" % [_name_of(p), (PonyTraitsScript.quirk_name(q) + ", ") if q != &"" else "",
		loves]
	if owns(&"yield_lens") and not inst.stock.is_empty():
		var coat := Color.html(str(inst.stock.get("coat", "ffffff")))
		line += "  |  %s" % ("VIVID: pays triple" if PathRulesScript.is_vivid(coat) else
			("pastel" if PathRulesScript.is_pastel(coat) else "ordinary"))
	hud.call("set_target_info", line)


# --- helpers --------------------------------------------------------------------------------

func _bag() -> Storage:
	return ranch.call("_bag")


func _wild() -> Array:
	var out: Array = []
	var spawner: Node = ranch.get("spawner")
	if spawner != null:
		for p in spawner.call("get_spawned"):
			if is_instance_valid(p):
				out.append(p)
	for n in ranch.get_children():
		if n is CharacterBody3D and n.has_method("offer_treat") and n.has_meta(&"escaped") and not (n in out):
			out.append(n)
	return out


## "Drifter" (blank), "Bloomed Drifter", or a named pony's name: what she is to the ranch.
static func kind_word(inst: PonyInstance, data: PonyData) -> String:
	if inst != null and inst.is_stock():
		return "Bloomed Drifter" if inst.is_marked() else "Drifter"
	return data.display_name if data != null else "A pony"


func _name_of(p: Node) -> String:
	var data: PonyData = p.call("get_data")
	var stock: Dictionary = p.call("get_stock")
	if not stock.is_empty() and int(stock.get("seed", 0)) != 0:
		return GeneratorScript.make_name(int(stock.get("seed", 0)))
	return data.display_name if data != null else "A pony"


func _aim_ray() -> Array:
	var rig: Node = _player().get_camera_pivot().get_node_or_null("CameraRig")
	if rig == null:
		return []
	var ray = rig.call("get_aim_ray")
	return [ray.origin, ray.direction]


func _aim_hit(range_m: float) -> Vector3:
	var r := _aim_ray()
	if r.is_empty():
		return Vector3.INF
	var space := _player().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * range_m)
	q.exclude = [_player().get_rid()]
	var hit := space.intersect_ray(q)
	return hit.get("position", Vector3.INF)


func _aimed_pony() -> Node3D:
	var r := _aim_ray()
	if r.is_empty():
		return null
	var space := _player().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * 26.0)
	q.exclude = [_player().get_rid()]
	q.collision_mask = 0xFFFFFFFF
	var hit := space.intersect_ray(q)
	var c: Object = hit.get("collider")
	if c is CharacterBody3D and (c as Node).has_method("offer_treat") and not (c as Node).has_meta(&"penned"):
		return c as Node3D
	return null


## Just in front of her hooves, on the ground.
func _drop_point() -> Vector3:
	var pl := _player()
	var fwd := -pl.global_transform.basis.z
	var r := _aim_ray()
	if not r.is_empty():
		fwd = r[1]
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var at := pl.global_position + fwd * DROP_AHEAD
	var terrain: Node = ranch.get("terrain")
	if terrain != null and terrain.has_method("height_at"):
		at.y = float(terrain.call("height_at", at.x, at.z))
	return at


func _landing() -> Vector3:
	var hit := _aim_hit(TREAT_RANGE)
	if hit != Vector3.INF:
		return hit
	var r := _aim_ray()
	var at: Vector3 = r[0] + r[1] * TREAT_RANGE
	var terrain: Node = ranch.get("terrain")
	if terrain != null and terrain.has_method("height_at"):
		at.y = float(terrain.call("height_at", at.x, at.z))
	return at


## The treat in the air: a little arc of food, toon-shaded, gone on landing.
func _fly(food: StringName, to: Vector3) -> void:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FOOD_COLORS.get(food, Color(0.93, 0.8, 0.38))
	mesh.material = mat
	m.mesh = mesh
	ranch.add_child(m)
	ToonStylerScript.style(m, &"prop")
	_arc(m, _player().global_position + Vector3(0, 1.3, 0), to + Vector3(0, 0.1, 0), 0.55, true)


func _arc_orb(from: Vector3, to: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	mesh.material = mat
	m.mesh = mesh
	ranch.add_child(m)
	_arc(m, from, to, 0.7, true)


func _arc(node: Node3D, from: Vector3, to: Vector3, seconds: float, free_after: bool) -> void:
	node.global_position = from
	var peak := maxf(from.y, to.y) + 2.2
	var t := node.create_tween()
	t.tween_method(func(f: float) -> void:
		if not is_instance_valid(node):
			return
		var p := from.lerp(to, f)
		p.y = lerpf(lerpf(from.y, peak, f), lerpf(peak, to.y, f), f)
		node.global_position = p, 0.0, 1.0, seconds)
	if free_after:
		t.tween_callback(node.queue_free)


func _pulse(at: Vector3, color: Color, radius: float) -> void:
	var m := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	m.mesh = mesh
	ranch.add_child(m)
	m.global_position = at + Vector3(0, 0.3, 0)
	m.scale = Vector3.ONE * 0.5
	var t := m.create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3(radius, 1.0, radius), 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	t.chain().tween_callback(m.queue_free)


func _sound(id: StringName) -> void:
	ranch.call("_sound_call", &"play", [id]) if ranch.has_method("_sound_call") else null
