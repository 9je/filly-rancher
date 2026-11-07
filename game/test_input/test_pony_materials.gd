extends "res://test_input/input_test.gd"
## PLAYTEST NOTE "bad textures on some pony models and weird eyes on others"
## (docs/playtest_fixes/ponies.md). A fresh save from the title screen, played with the mouse
## and the keyboard only. Every roster character and 50 generated Drifters are stood in a
## meadow by the spawner's own guest path (spawn_guest, the way a rare sighting arrives);
## the player is seen at the start of the walk with them far off (FAR tier: outline-free
## twins, tongue and teeth hidden), then walks over and looks round among them (FULL tier),
## walks to any she has not seen up close, and turns away again (FAR). At every look, every
## surface of every pony, story character, Spike and the player herself goes through
## PonyMaterialAudit: a toon pass with use_texture and no texture, an eye with no texture or
## no material, a texture that failed to load or is the converter's missing-texture
## placeholder, a far twin that lost its texture. One problem anywhere fails the test.

const Audit := preload("res://test_input/pony_material_audit.gd")
const Generator := preload("res://systems/pony_generator.gd")
const StockPalette := preload("res://systems/stock_palette.gd")

const GENERATED := 50
const FULL := 0
const FAR := 2

var _guests: Array = []          # [label, pony]
var _seen := {}                  # label -> {tier: true}
var _problems := {}              # line -> true
var _looks := 0
## Set only where this test reaches its own verdict. InputTest._main() calls ok("finished") when
## _play() returns, and a script error inside _play() returns it early, so without this a crash
## halfway through the walk would read as a pass.
var _verdict := false


func ok(msg: String = "") -> void:
	if not _verdict:
		fail("ended without a verdict (a script error stopped _play?): " + msg)
		return
	super.ok(msg)


func _play() -> void:
	_deadline_s = 900.0
	if not await boot_new_game():
		return
	if not await finish_creator():
		return
	await wait(1.0)
	await close_letter()
	await _settle_talk(6.0)
	var spawner: Node = ranch.get("spawner")
	var marker: Node3D = _meadow(spawner)
	if not check(marker != null, "no spawn marker to stand the ponies at"):
		return
	_stand_everypony(spawner, marker)
	note("%d ponies stood at %s, %.0f m off" % [_guests.size(), marker.name,
		marker.global_position.distance_to(player.global_position)])
	if not check(_guests.size() >= 43 + GENERATED, "only %d of %d ponies stood up" % [_guests.size(), 43 + GENERATED]):
		return
	await wait(1.5)

	# FAR: from where she starts, looking away from them (out of view and past 12 m is FAR).
	var start := player.global_position
	await look_at_point(start + (start - marker.global_position))
	await wait(1.0)
	_look_all("from the start, facing away")

	# FULL: walk over and look round among them.
	await _walk(marker.global_position, 3.0, 60.0)
	for k in 8:
		RI.look(Vector2(140, 0))
		await wait(0.6)
		_look_all("among them, turn %d" % k)
	# Anyone not yet seen up close: go to her (ten walks at most).
	var budget := 60.0
	for g: Array in _guests:
		if not is_instance_valid(g[1]) or _seen[g[0]].has(FULL) or budget <= 0.0 \
				or (g[1] as Node3D).global_position.y < start.y - 20.0:
			continue
		var p: Node3D = g[1]
		budget -= 6.0
		# Through the crowd if need be; the camera has to come within ~10 m of her for FULL.
		for attempt in 3:
			if not is_instance_valid(g[1]) or _seen[g[0]].has(FULL):
				break
			var at := p.global_position
			await _walk(at, 2.5, 20.0)
			if not is_instance_valid(g[1]):
				break
			await look_at_point(p.global_position)
			await wait(0.6)
			var cam: Camera3D = rig.call("get_camera")
			note("beside %s: camera %.1f m from her, tier %d" % [g[0],
				cam.global_position.distance_to(p.global_position), int(p.get("detail"))])
			_look_all("beside %s" % g[0])

	# FAR again: walk back to the start and turn away, so every pony past 12 m and out of view
	# drops tier.
	await _walk(start, 2.0, 40.0)
	await look_at_point(start + (start - marker.global_position))
	await wait(1.0)
	_look_all("walked off, looking away")
	budget = 60.0
	for g: Array in _guests:
		if is_instance_valid(g[1]) and not _seen[g[0]].has(FAR) and budget > 0.0:
			var p: Node3D = g[1]
			budget -= 6.0
			var from := p.global_position
			await _walk(player.global_position + (player.global_position - from).normalized() * 20.0, 2.0, 12.0)
			await wait(0.6)
			_look_all("away from %s" % g[0])

	var missing := PackedStringArray()
	var gone := 0
	var fell := PackedStringArray()
	for g: Array in _guests:
		if not is_instance_valid(g[1]):
			# The world took her (a wild pony wanders off the map): judged on the looks she had.
			gone += 1
			continue
		if (g[1] as Node3D).global_position.y < start.y - 20.0:
			# Stood where the spawner found no ground (its counted fallback placement) and fell
			# out of the world: no camera can get near her, so she is judged on the looks she
			# had, and named, because that is a spawner bug of its own.
			fell.append(g[0])
			continue
		for tier: int in [FULL, FAR]:
			if not _seen[g[0]].has(tier):
				missing.append("%s never seen at %s" % [g[0], "FULL" if tier == FULL else "FAR"])
	note("%d looks, %d actors (%d left the world mid-test, %d fell through it: %s), %d distinct problems" % [
		_looks, _guests.size(), gone, fell.size(), ", ".join(fell), _problems.size()])
	if not _problems.is_empty():
		var lines: Array = _problems.keys()
		lines.sort()
		var by := {}
		for l: String in lines:
			var who := l.get_slice("@", 0).get_slice(" ", 0)
			by[who] = int(by.get(who, 0)) + 1
		print("INPUT_TEST_NOTE broken, by actor: ", by)
		for l: String in lines.slice(0, 60):
			print("INPUT_TEST_NOTE problem: ", l)
		_verdict = true
		fail("%d broken pony materials (first: %s)" % [lines.size(), lines[0]])
		return
	_verdict = true
	if not check(missing.is_empty(), "tier coverage: %s" % ", ".join(missing.slice(0, 10))):
		return
	ok("%d ponies, cast, Spike and the player: no missing texture or eye, near and far" % _guests.size())


## The meadow nearest where she starts (the ranch's own herd ground), 15 m off or more, so
## the walk there is short and open and the herd starts out of reach of the FULL tier.
func _meadow(spawner: Node) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for m: Node3D in spawner.call("get_markers"):
		var d := m.global_position.distance_to(player.global_position)
		if d < bd and d > 15.0:
			bd = d
			best = m
	return best


## Every roster character and GENERATED Drifters, through the spawner's guest path. Reading
## the roster and the generator decides WHAT stands up; nothing here moves the player.
func _stand_everypony(spawner: Node, marker: Node3D) -> void:
	var slot := 900
	var reg: Object = spawner.call("_registry_for_stock")
	for f in DirAccess.get_files_at("res://data/ponies"):
		if not f.ends_with(".tres"):
			continue
		var at: Vector3 = spawner.call("_ground_point", marker, slot)
		slot += 1
		var data: Resource = load("res://data/ponies/" + f)
		var p: Node3D = spawner.call("spawn_guest", data, {}, at, 4.0)
		# A named pony already out in the wild is not stood up twice (PS3 item 39: the spawner
		# refuses a second of anypony): audit the one already standing instead.
		if p == null:
			p = _standing(spawner, StringName(data.get("id")))
			if p != null:
				p.global_position = at
		_add_guest("roster:" + f.get_basename(), p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	for i in GENERATED:
		var opts := {"foal": true} if rng.randf() < 0.12 else {}
		var look := Generator.generate(rng.randi(), opts)
		var data: Resource = reg.call("by_id", StockPalette.IDS[i % StockPalette.IDS.size()])
		var at: Vector3 = spawner.call("_ground_point", marker, slot)
		slot += 1
		var p: Node3D = spawner.call("spawn_guest", data, look.to_dict(), at, 4.0)
		_add_guest("drifter%02d:%s" % [i, look.donor], p)


## The wild pony with PonyData `id` already on the map, or null.
func _standing(spawner: Object, id: StringName) -> Node3D:
	for q in spawner.call("get_spawned"):
		var d: Resource = (q as Node).call("get_data") if (q as Node).has_method("get_data") else null
		if d != null and StringName(d.get("id")) == id:
			return q
	return null


func _add_guest(label: String, p: Node3D) -> void:
	if p == null:
		print("INPUT_TEST_NOTE could not stand up ", label)
		return
	p.set("calm", 9999.0)
	_guests.append([label, p])
	_seen[label] = {}


## One look round the scene: audit everypony as she is drawn right now.
func _look_all(why: String) -> void:
	_looks += 1
	var full := 0
	var far := 0
	for g: Array in _guests:
		if not is_instance_valid(g[1]):
			continue
		var p: Node3D = g[1]
		var tier: int = int(p.get("detail"))
		_seen[g[0]][tier] = true
		full += 1 if tier == FULL else 0
		far += 1 if tier == FAR else 0
		_record(Audit.audit(p, "%s@%s" % [g[0], ["FULL", "MID", "FAR"][tier]]))
	var people: Node = ranch.get("people")
	if people != null:
		for n in people.get_children():
			if n is Npc:
				_record(Audit.audit(n, "cast:%s" % (n as Npc).character_id))
	var spike: Node = ranch.get("spike")
	if spike != null:
		_record(Audit.audit(spike, "spike"))
	_record(Audit.audit(player, "player"))
	note("look %d (%s): %d FULL, %d FAR, %d problems so far" % [_looks, why, full, far, _problems.size()])
	# Evidence, when asked for: what the player was looking at (FILLY_PONY_SHOTS=/abs/dir).
	var shots := OS.get_environment("FILLY_PONY_SHOTS")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		root.get_viewport().get_texture().get_image().save_png("%s/look_%02d.png" % [shots, _looks])


func _record(lines: PackedStringArray) -> void:
	for l in lines:
		# One line per material and tier, however many looks saw it.
		_problems[l] = true


func _walk(to: Vector3, arrive: float, secs: float) -> void:
	await _settle_talk(0.4)
	await walk_to(to, arrive, secs)
	await _settle_talk(0.4)


## A conversation that opened on its own (Marigold's welcome) is read through, as a person would.
func _settle_talk(secs: float) -> void:
	var people: Node = ranch.get("people")
	var t := 0.0
	while t < secs:
		if bool(people.call("is_talking")):
			await talk_through()
		var lp: Node = ranch.get("letter_panel")
		if lp != null and bool(lp.call("is_open")):
			await click(lp.call("close_button_node"))
		await wait(0.2)
		t += 0.2
