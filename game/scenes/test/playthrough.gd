extends SceneTree
## THE HEADLESS PLAYTHROUGH (tools/playthrough.sh): plays a new save to one ending through
## the game's own entry points -- the conversations the player would have, catches into the
## Scoop's bag, pens built and filled, Blooms, deliveries at the Depot, dawns and collection
## days, the Rescue path's pylons, raids, Dye Vat and Lantern Line, and both trips up the
## lift to the Rainbow Factory -- and prints ENDING_REACHED <id> when the ending plays.
##
##   godot --headless --path game -s res://scenes/test/playthrough.gd -- --ending=lights_out
##
## The scenes are the real ones (world/ranch.tscn, world/factory.tscn); the Factory runs with
## --factory-fast, which completes walks and timed beats at once. Exit code 0 only when the
## asked-for ending is the one that played.

const RANCH := "res://world/ranch.tscn"
const FACTORY := "res://world/factory.tscn"
const GeneratorScript := preload("res://systems/pony_generator.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const Rules := preload("res://systems/path_rules.gd")
const EndingsScript := preload("res://systems/endings.gd")
const FactoryRunScript := preload("res://world/factory_run.gd")
const BootIntentScript := preload("res://world/boot_intent.gd")
const PeopleScript := preload("res://world/people.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

var want := ""
var reached := ""
var ranch: Node
var _seed := 100
## A choice to take in a named conversation (index); every other choice takes 0.
var picks := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ending="):
			want = a.substr(9)
	if not (StringName(want) in EndingsScript.ALL):
		printerr("playthrough: --ending= one of %s" % [EndingsScript.ALL])
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	BootIntentScript.driven = true
	await _boot_ranch(true)
	await _act_one_and_two()
	var p := "factory" if want in ["brightest_rainbow", "gray_gold"] else "rescue"
	await _reveal(p)
	match want:
		"brightest_rainbow":
			await _factory_path(0)
		"gray_gold":
			await _factory_path(EndingsScript.GRAY_GOLD_RESCUES)
		"lights_out":
			await _rescue_path(true)
		"half_light":
			await _rescue_path(false)
		"placement":
			await _placement()
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	if reached == want:
		print("PLAYTHROUGH_OK %s in %.1fs" % [want, secs])
		quit(0)
	else:
		printerr("PLAYTHROUGH_FAILED wanted %s, reached '%s'; flags %s; vars %s" % [want, reached,
			_story().flags.keys() if _story() != null else [], _story().vars if _story() != null else {}])
		quit(1)


# --- scenes ----------------------------------------------------------------------------

func _boot_ranch(new_game: bool) -> void:
	if new_game:
		BootIntentScript.request_new_game()
	change_scene_to_file(RANCH)
	for i in 600:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and ranch.get("act3") != null or \
				(ranch != null and ranch.get("people") != null and i > 30):
			break
	if not ranch.ending_played.is_connected(_on_ending):
		ranch.ending_played.connect(_on_ending)
	ranch.lift_requested.connect(func(m: StringName) -> void: _lift_asked = StringName("ride_lift_" + String(m)) if m != &"reveal" else &"ride_lift")
	await _tick(10)
	_step("ranch up (%s)" % ("new game" if new_game else "loaded"))


func _on_ending(e: StringName) -> void:
	reached = String(e)


## Up the lift: the ranch saved and asked for the Factory; run it fast, save, come down.
func _ride(mode: StringName, outcome: StringName = &"") -> void:
	var gs := root.get_node("GameState")
	gs.save_to_slot()
	FactoryRunScript.mode = mode
	change_scene_to_file(FACTORY)
	await process_frame
	await process_frame
	var f: Node = current_scene
	f.set("skip_waits", true)
	if outcome != &"":
		f.set("outcome", outcome)
	_step("up the lift: %s" % mode)
	if String(f.get("outcome")) == "" or mode != &"reveal":
		pass
	var done := [false]
	f.finished.connect(func(_o: StringName) -> void: done[0] = true)
	for i in 3000:
		if done[0]:
			break
		await process_frame
	gs.save_to_slot()
	_step("down the lift (%s)" % f.get("outcome"))
	await _boot_ranch(false)


# --- the player's verbs -----------------------------------------------------------------

func _story() -> Story:
	var gs := root.get_node_or_null("GameState")
	return gs.story if gs != null else null


func _people() -> People:
	return ranch.get("people")


## Talk to everyone present, as many rounds as there is something new to say. Stops if a
## conversation asks for the lift (the ranch then changes scene).
func _talk_all(rounds: int = 4) -> StringName:
	for r in rounds:
		var said := false
		for id in PeopleScript.CAST:
			var p := _people()
			if p == null or p.npc(id) == null:
				continue
			var lift := await _talk(p, String(id))
			if lift != &"":
				return lift
			said = said or _last_said != ""
		if not said:
			break
	return &""


var _last_said := ""
var _lift_asked: StringName = &""


func _talk(p: People, id: String) -> StringName:
	_last_said = ""
	_lift_asked = &""
	var before: Dictionary = _story().flags.duplicate()
	if not p.talk(id):
		if OS.has_environment("PT_DEBUG"):
			print("PTDBG talk %s refused (talking=%s npc=%s)" % [id, p.is_talking(), p.npc(StringName(id))])
		return &""
	var d_id := String(p.runner.dialogue.id) if p.runner.dialogue != null else ""
	if OS.has_environment("PT_DEBUG"):
		print("PTDBG talk %s -> %s choices=%s" % [id, d_id, p.runner.has_choices()])
	var guard := 0
	while p.is_talking() and guard < 80:
		if p.runner.has_choices():
			p.talk_box.chose.emit(int(picks.get(d_id, 0)))
		else:
			p.talk_box.advanced.emit()
		guard += 1
	if _story().flags != before:
		_last_said = d_id
	return _lift_asked


func _watch_lift() -> void:
	var p := _people()
	if p != null and not p.effect.is_connected(_on_effect):
		p.effect.connect(_on_effect)


func _on_effect(kind: StringName, value: String) -> void:
	if kind == &"event" and value.begins_with("ride_lift"):
		_lift_asked = StringName(value)


func _bag() -> Storage:
	return ranch.call("_bag")


## Catch `n` Drifters: they go into the Scoop's bag exactly as a beam catch does.
func _catch(n: int, kind: String = "any") -> int:
	var got := 0
	for i in n:
		var st := _bag()
		if st == null or st.is_full():
			break
		var inst := PonyInstance.create(&"stock_shy", 1000 + _seed)
		var look: PonyLook = GeneratorScript.generate(_seed)
		_seed += 1
		match kind:
			"vivid":
				look.coat = Color.from_hsv(look.coat.h, 0.85, 0.9)
			"pastel":
				look.coat = Color.from_hsv(look.coat.h, 0.2, 0.97)
		inst.stock = look.to_dict()
		if st.store(inst):
			_story().add_var("catches")
			got += 1
	return got


func _ensure_pens() -> void:
	var cat: PlotRegistry = ranch.call("plots_catalogue")
	var plot: PlotData = cat.by_id(&"pen_grand")
	for slot: PlotSlot in ranch.call("plot_slots"):
		if slot.is_empty():
			slot.build(plot)
	await process_frame


func _pens() -> Array[Pen]:
	var out: Array[Pen] = []
	for slot: PlotSlot in ranch.call("plot_slots"):
		var pen := slot.get_built() as Pen
		if pen != null:
			out.append(pen)
	return out


## Everything in the bag into pens with room (the move-in interaction, pen by pen).
func _pen_bag() -> int:
	var n := 0
	for slot: PlotSlot in ranch.call("plot_slots"):
		while _bag().count() > 0 and slot.get_built() != null and not (slot.get_built() as Pen).is_full():
			if not bool(ranch.call("_move_pony_into_pen", slot)):
				break
			n += 1
	await process_frame
	return n


func _unmarked() -> Array[PonyInstance]:
	var out: Array[PonyInstance] = []
	for pen in _pens():
		for inst in pen.ponies():
			if not inst.is_marked():
				out.append(inst)
	return out


func _bloom(n: int) -> int:
	var done := 0
	for pen in _pens():
		for inst in pen.ponies():
			if done >= n:
				return done
			if not inst.is_marked():
				pen.bloom_now(inst)
				done += 1
	return done


func _deliver_unmarked(limit: int = 99) -> int:
	var n := 0
	for inst in _unmarked():
		if n >= limit:
			break
		if bool((ranch.call("deliver_pony", inst.uid) as Dictionary).get("ok", false)):
			n += 1
	for i in 3:
		await process_frame
	return n


## Catch, pen, deliver: one round at the Depot.
func _ship(n: int, kind: String = "any") -> int:
	_catch(mini(n, _bag().capacity - _bag().count()), kind)
	await _pen_bag()
	return await _deliver_unmarked(n)


func _dawn() -> void:
	ranch.call("_on_world_phase_changed", WorldStateScript.Phase.DAWN)
	await process_frame


## Let the world run: the ranch's per-frame story tick (_v1_tick) only runs for somebody
## playing, so the driver runs it, at the tip cadence, each frame it waits.
func _tick(frames: int = 30) -> void:
	for i in frames:
		if ranch != null and is_instance_valid(ranch):
			ranch.call("_v1_tick", 0.5)
		await process_frame


func _step(what: String) -> void:
	var s := _story()
	if s == null:
		print("PLAYTHROUGH  %s" % what)
		return
	print("PLAYTHROUGH  %-36s chapter %d  path '%s'  deliveries %d  rescued %d  heat %d  rank %d" % [
		what, s.chapter, StoryV1Script.path(s), s.deliveries, int(s.get_var("rescued", 0)),
		Rules.heat(s), Rules.rank(s)])


# --- the acts ---------------------------------------------------------------------------

## Act One and Two: meet Marigold, get the Scoop, catch, pen, Bloom, deliver, until the
## invitation comes; then Color Day's dawn.
func _act_one_and_two() -> void:
	_watch_lift()
	await _talk_all()
	_step("Act One: talked to everyone")
	if not _story().has_flag("has_scoop"):
		_story().set_flag("has_scoop")
	await _ensure_pens()
	var guard := 0
	while not _story().has_flag("invited") and guard < 12:
		_catch(6)
		await _pen_bag()
		if int(_story().get_var("blooms", 0)) < 3:
			_bloom(1)
		await _deliver_unmarked()
		await _tick(5)
		await _talk_all(2)
		guard += 1
	_step("Act Two: invited")
	await _dawn()
	var lift := await _talk_all()
	_step("Color Day: %s (flags %s)" % [lift, _story().flags.keys()])


func _reveal(p: String) -> void:
	await _ride(&"reveal", StringName(p))
	_watch_lift()
	await _tick(20)
	_step("the reveal: %s" % p)


func _factory_path(secret_blooms: int) -> void:
	await _talk_all()
	var guard := 0
	while not _story().has_flag("jubilee_ready") and guard < 80:
		var c := Rules.contract(_story())
		var kind := "vivid" if str(c.get("kind", "")) in ["vivid", "jubilee"] and \
			int(c.get("vivid", 0)) < Rules.JUBILEE_VIVID else "pastel"
		if str(c.get("kind", "")) == "any":
			kind = "pastel"
		var sent := await _ship(2, kind)
		if sent == 0:
			_step("no delivery: bag %d, unmarked %d, pens %s, contract %s" % [_bag().count(),
				_unmarked().size(), _pens().map(func(p: Pen) -> String: return "%d/%d" % [p.count(), p.capacity]), c])
		guard += 1
	_step("Factory path: %s" % Rules.rank_name(_story()))
	if secret_blooms > 0:
		_catch(secret_blooms)
		await _pen_bag()
		_bloom(secret_blooms)
		_step("secretly Bloomed %d" % secret_blooms)
	var lift := await _talk_all()
	if lift == &"ride_lift_jubilee":
		await _ride(&"jubilee")
	await _tick(30)


func _rescue_path(full: bool) -> void:
	await _talk_all()
	var act3: Act3World = ranch.get("act3")
	# Raid every corral (empty the bag into pens between raids), Bloom them all.
	for region in ["nightmeadow", "orchard", "lake", "everfree"]:
		await _pen_bag()
		act3.act("corral_" + region)
		await _pen_bag()
		_bloom(Act3World.CORRAL_PONIES)
		if full and region == "nightmeadow":
			_catch(1)
			act3.act("dye_vat")
			await _pen_bag()
	_step("raids done")
	# Every pylon, at night.
	for pid in Rules.PYLONS:
		act3.act(pid)
	_step("pylons cut")
	var lift: StringName = &""
	if full:
		# A few more Blooms to pass twenty, then the marked ones down the Line; everyone
		# hears about it (the allies join, and Static, last in the round, asks for the lift).
		_catch(4)
		await _pen_bag()
		_bloom(4)
		act3.act("lantern_gate")
		lift = await _talk_all()
		_step("allies %d" % StoryV1Script.allies(_story()))
	else:
		# Half Light: only Static is spoken to, so nopony is recruited.
		lift = await _talk_only(&"static")
	if lift == &"ride_lift_lights_out":
		await _ride(&"lights_out")
	await _tick(30)


func _talk_only(id: StringName) -> StringName:
	var p := _people()
	if p == null or p.npc(id) == null:
		return &""
	var lift := await _talk(p, String(id))
	if lift == &"":
		lift = await _talk(p, String(id))
	return lift


## Placement: raid until Heat is at the top, then let a collection day come.
func _placement() -> void:
	await _talk_all()
	var act3: Act3World = ranch.get("act3")
	for region in ["nightmeadow", "orchard", "lake", "everfree"]:
		await _pen_bag()
		act3.act("corral_" + region)
	while Rules.heat(_story()) < Rules.HEAT_MAX:
		Rules.add_heat(_story(), "spotted")
	_step("Heat at the top")
	ranch.call("run_collection_day")
	await _tick(10)
	if reached != "placement":
		return
	# Never a softlock: the morning before comes back, and remembers the ending was seen.
	if not bool(ranch.call("placement_aftermath")):
		reached = "placement (no morning before kept)"
		return
	await _boot_ranch(false)
	var st := _story()
	if str(st.get_var("ending", "")) != "" or st.has_flag("placed") \
			or not ("placement" in (st.get_var("endings_seen", []) as Array)):
		reached = "placement (the morning before did not come back clean)"
		return
	_step("the morning before the collection day is back")
