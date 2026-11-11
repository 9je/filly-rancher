class_name Act3World
extends Node3D
## THE RESCUE PATH'S PLACES IN THE VALLEY (STORY.md section 5): a weather pylon in each
## region, an Intake Corral beside it, the Lantern Line's gate past the Everfree, and the
## Dye Vat behind Bramble's stall. Built by ranch.gd once the path is Rescue.
##
## Each place is a Site: a model, a reach, and a verb. The ranch asks offer() when it has
## nothing of its own to offer, and calls work() every frame it is showing ours; a site
## that needs a long hold (a pylon, a corral gate) counts the hold here. What a verb DOES to
## the story is PathRules' call; this node only moves bodies and says what happened.

signal acted(site_id: String, result: Dictionary)

const PathRulesScript := preload("res://systems/path_rules.gd")
const PatrolScript := preload("res://world/collector_patrol.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const NpcScript := preload("res://actors/npc/npc.gd")

const REACH := 3.6
const PYLON_HOLD := 4.0
const CORRAL_HOLD := 2.5
const CORRAL_PONIES := 3
## Pylon and corral offsets from each region's centre (x, z).
const PYLON_AT := {
	"pylon_meadow": [&"nightmeadow", Vector2(9, -6)],
	"pylon_orchard": [&"orchard", Vector2(-8, 7)],
	"pylon_lake": [&"lake", Vector2(-10, 8)],
	"pylon_everfree": [&"everfree", Vector2(8, 9)],
}
const CORRAL_OFFSET := Vector2(-7, -5)
const GATE_AT := Vector3(-92.0, 0.0, -68.0)
const VAT_AT := Vector3(11.0, 0.0, 8.5)

## Set by the ranch before add_child.
var story: Story
var player: Node3D
var height_at: Callable = func(_x: float, _z: float) -> float: return 0.0
var region_centre: Callable = func(_id: StringName) -> Vector2: return Vector2.ZERO
## True at night (pylons and raids are night work).
var is_night: Callable = func() -> bool: return true
## The ranch's answers to "send the marked ponies" and "dye a pony in the bag".
var send_marked: Callable = func() -> int: return 0
var dye_one: Callable = func() -> String: return ""
var bag_room: Callable = func() -> int: return 0
var bag_store: Callable = func(_inst: PonyInstance) -> bool: return false

var sites: Array[Dictionary] = []
var _hold := 0.0
var _held_site := ""


func _ready() -> void:
	build()


func build() -> void:
	for id: String in PYLON_AT:
		var spec: Array = PYLON_AT[id]
		var c: Vector2 = region_centre.call(spec[0]) + spec[1]
		var cut := id in (story.get_var("pylons", []) as Array)
		var node := _model("res://assets/models/weather_pylon.glb", c, 1.0)
		if cut:
			_topple(node, false)
		_add_site({"id": id, "kind": "pylon", "node": node, "hold": PYLON_HOLD})
		var cc: Vector2 = region_centre.call(spec[0]) + spec[1] + CORRAL_OFFSET
		var corral := _model("res://assets/models/intake_corral.glb", cc, 1.0)
		var cid := "corral_" + String(spec[0])
		var raided := cid in (story.get_var("raided", []) as Array)
		var guard := _guard(cc, cid) if not raided else null
		if not raided:
			_fill_corral(corral)
		_add_site({"id": cid, "kind": "corral", "node": corral, "hold": CORRAL_HOLD, "guard": guard})
	var gate := _model("res://assets/models/lantern_gate.glb", Vector2(GATE_AT.x, GATE_AT.z), 1.0)
	_add_site({"id": "lantern_gate", "kind": "gate", "node": gate, "hold": 0.0})
	var vat := _model("res://assets/models/dye_vat.glb", Vector2(VAT_AT.x, VAT_AT.z), 1.0)
	_add_site({"id": "dye_vat", "kind": "vat", "node": vat, "hold": 0.0})


func _add_site(d: Dictionary) -> void:
	sites.append(d)


func _model(path: String, at: Vector2, s: float) -> Node3D:
	var n: Node3D
	if ResourceLoader.exists(path):
		n = (load(path) as PackedScene).instantiate()
	else:
		n = Node3D.new()
	add_child(n)
	n.position = Vector3(at.x, float(height_at.call(at.x, at.y)), at.y)
	n.scale = Vector3.ONE * s
	ToonStyler.style(n, &"prop", {})
	return n


## Drifters penned for the lift: silhouettes at the rail, freed by the raid.
func _fill_corral(corral: Node3D) -> void:
	for i in range(CORRAL_PONIES):
		var p: Node3D = (load("res://actors/pony/pony.tscn") as PackedScene).instantiate()
		corral.add_child(p)
		p.set_stock(GeneratorScript.generate(7300 + i + int(corral.position.x * 7.0)).to_dict())
		p.setup(load("res://data/hidden/stock_shy.tres"))
		p.set_physics_process(false)
		p.position = Vector3(-1.2 + i * 1.2, 0, 0.3 * float(i % 2))
		p.rotation.y = randf() * TAU
		p.set_meta(&"penned", true)


## A Collector with a lantern walks the corral at night.
func _guard(at: Vector2, cid: String) -> Npc:
	var def := CharacterDef.new()
	def.id = StringName(cid + "_guard")
	def.display_name = "Collector"
	def.char_seed = int(absf(at.x * 31.0 + at.y))
	def.look = {"coat": "8a8f99", "mane": "4d525c", "mane2": "5f6470", "tail": "4d525c"}
	var n: Npc = NpcScript.new()
	add_child(n)
	var y := float(height_at.call(at.x, at.y))
	n.position = Vector3(at.x + 4.5, y, at.y)
	n.setup(def)
	var patrol: CollectorPatrol = PatrolScript.new()
	patrol.points.assign([Vector3(at.x + 4.5, y, at.y + 4.0), Vector3(at.x + 4.5, y, at.y - 4.0),
		Vector3(at.x - 4.5, y, at.y - 4.0), Vector3(at.x - 4.5, y, at.y + 4.0)])
	patrol.target = player
	n.add_child(patrol)
	patrol.spotted.connect(func(_t: Node3D) -> void: _on_spotted())
	n.set_meta(&"patrol", patrol)
	return n


func _on_spotted() -> void:
	# The corral guards walk all day, but their lanterns only count in the dark.
	if not bool(is_night.call()):
		return
	var h := PathRulesScript.add_heat(story, "spotted")
	_hold = 0.0
	acted.emit("spotted", {"heat": h, "text": "A Collector's lantern found you."})


## The site in reach, or {}.
func nearest() -> Dictionary:
	if player == null:
		return {}
	var best := {}
	var best_ratio := 1.0
	for s in sites:
		var n: Node3D = s.node
		var d := Vector2(n.global_position.x - player.global_position.x,
			n.global_position.z - player.global_position.z).length()
		# A corral is wide: its reach is its rail, not its centre.
		var ratio := d / (REACH * (1.8 if s.kind == "corral" else 1.0))
		if ratio < best_ratio:
			best = s
			best_ratio = ratio
	return best


## The prompt for the site in reach, or "" (the ranch shows its own then).
func offer(key: String) -> String:
	var s := nearest()
	if s.is_empty():
		return ""
	match str(s.kind):
		"pylon":
			if s.id in (story.get_var("pylons", []) as Array):
				return "This pylon is down. The sky over here is a band thinner."
			if not bool(is_night.call()):
				return "A Cloudsdale weather pylon. Come back at night to cut it."
			return "%s: hold to cut the pylon  %d%%" % [key, _pct(s)]
		"corral":
			if s.id in (story.get_var("raided", []) as Array):
				return "An empty Intake Corral. They will not use this one again."
			if not bool(is_night.call()):
				return "An Intake Corral, full of Drifters waiting for the lift. Come back at night."
			return "%s: hold to open the gate  %d%%" % [key, _pct(s)]
		"gate":
			return "%s: send your marked ponies down the Lantern Line" % key
		"vat":
			return "%s: the Dye Vat. Repaint a pony from your saddlebag so the registry loses her" % key
	return ""


func _pct(s: Dictionary) -> int:
	if _held_site != s.id or float(s.hold) <= 0.0:
		return 0
	return int(clampf(_hold / float(s.hold), 0.0, 1.0) * 100.0)


## Called each frame the ranch shows our prompt. `pressed` is the interact key held,
## `just` its press this frame.
func work(delta: float, pressed: bool, just: bool) -> void:
	var s := nearest()
	if s.is_empty():
		_hold = 0.0
		return
	if float(s.hold) > 0.0:
		if _held_site != s.id:
			_held_site = s.id
			_hold = 0.0
		if pressed and _can_hold(s):
			_hold += delta
			if _hold >= float(s.hold):
				_hold = 0.0
				act(s.id)
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
	elif just:
		act(s.id)


func _can_hold(s: Dictionary) -> bool:
	if not bool(is_night.call()):
		return false
	match str(s.kind):
		"pylon":
			return not (s.id in (story.get_var("pylons", []) as Array))
		"corral":
			return not (s.id in (story.get_var("raided", []) as Array))
	return false


## Do site `id`'s verb now (the driver calls this directly). Returns what happened.
func act(id: String) -> Dictionary:
	var s := {}
	for x in sites:
		if x.id == id:
			s = x
	if s.is_empty():
		return {}
	var r := {"text": ""}
	match str(s.kind):
		"pylon":
			if PathRulesScript.cut_pylon(story, id):
				_topple(s.node, true)
				var n := PathRulesScript.pylons_cut(story)
				r.text = "The pylon is down. %d of 4. The Collectors' trail goes cold." % n
				if PathRulesScript.lights_out_ready(story):
					r.text += " Every pylon is cut: Static can get you back into the Works."
				r.cut = n
		"corral":
			r = _raid(s)
		"gate":
			var sent: int = send_marked.call()
			r.sent = sent
			r.text = ("%d walked out along the Lantern Line. Their postcards will come in their own words." % sent) \
				if sent > 0 else "Only marked ponies can go down the Line. Help one Bloom first."
		"vat":
			var who: String = dye_one.call()
			if who != "":
				story.add_var("dyed")
				PathRulesScript.add_heat(story, "dye")
				r.text = "%s comes out of the vat a different pony. The registry has lost her." % who
			else:
				r.text = "Bring a pony in your saddlebag to the vat. One the vat has not had yet."
	acted.emit(id, r)
	return r


func _raid(s: Dictionary) -> Dictionary:
	var raided: Array = story.get_var("raided", [])
	if s.id in raided:
		return {"text": ""}
	var corral: Node3D = s.node
	var freed := 0
	var left := 0
	for p in corral.get_children():
		if not p.has_meta(&"penned") or p.is_queued_for_deletion():
			continue
		if int(bag_room.call()) <= 0:
			left += 1
			continue
		var inst := PonyInstance.create(&"stock_shy", int(Time.get_unix_time_from_system() * 1000.0))
		inst.stock = p.get_stock() if p.has_method("get_stock") else {}
		if bool(bag_store.call(inst)):
			freed += 1
			p.queue_free()
	if freed == 0:
		return {"text": "Your saddlebag is full. Empty it before the raid."}
	story.add_var("raids")
	PathRulesScript.add_heat(story, "raid", freed)
	if left > 0:
		# A bag too small for the whole corral: the rest wait for the next trip.
		return {"text": "%d Drifters into your saddlebag, %d still inside." % [freed, left], "freed": freed}
	raided.append(s.id)
	story.set_var("raided", raided)
	var guard: Node = s.get("guard")
	if guard != null and is_instance_valid(guard):
		guard.queue_free()
	var text := "%d Drifters out of the corral and into your saddlebag." % freed
	if not story.has_flag("intake_ledger"):
		story.set_flag("intake_ledger")
		text += " On the gatepost: a page torn from the Works' intake ledger. Fennel should see this."
	return {"text": text, "freed": freed}


func _topple(n: Node3D, animate: bool) -> void:
	var to := Vector3(deg_to_rad(78.0), n.rotation.y, 0)
	if not animate:
		n.rotation = to
		return
	var t := create_tween()
	t.tween_property(n, "rotation", to, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
