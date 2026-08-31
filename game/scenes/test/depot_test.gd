extends Node
## THE DEPOT GATE. Proves a delivery end to end on the real ranch: a pony caught with the
## real beam, penned, and handed across the counter for real credit, walking to the crate
## on her own legs and freeing herself only when she gets there, with nothing else in the
## world losing a body along the way.
##
## WHY A GATE AND NOT ONLY game/test/test_depot_menu.gd and game/test/test_pen.gd. Those
## prove the menu's own arithmetic and the pen's own bookkeeping against lambdas and a bare
## Pen.new(); neither can see the WIRE: whether ranch.gd's deliver_pony() really reaches
## into the SAME pen the beam just filled, whether the body that walks to the crate is the
## SAME body that was standing in the paddock a moment before, whether a delivery that
## should touch exactly one pony quietly frees a second one somewhere else in the world.
##
## THE RANCH IS HOSTED HERE, not launched, the same way scenes/test/collection_test.gd's
## is; see that file's class comment for what _hosted changes and why this gate waits on
## gate_report_finished rather than polling for a symptom of it. The catch sequence below
## (freeze, stand, aim, grab, secure, release) is collection_test.gd's own, read rather than
## re-invented.
##
## THE NAMED DELIVERY (Compendium.State.PROCESSED) USES A PONY BUILT DIRECTLY INTO THE PEN
## with Pen.add_pony(), the way scenes/test/ledger_test.gd's resident is, rather than a
## second beam catch off the roaming herd: what that check is about is the Compendium and
## the pause menu, not a second capture, and the world population count at the bottom of
## this file ("boot count minus the ONE delivered pony") is a claim about the roaming herd
## alone -- a pony who was never drawn from it costs that claim nothing to keep clean.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const LedgerScript := preload("res://systems/ledger.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const SpawnerScript := preload("res://world/spawner.gd")

const SLOT := 7  # a scratch slot; distinct from collection_test.gd's 5 and ledger_test.gd's 6

## Seed for the beam's capture generator. Fixed for capture_test.gd's and collection_test.gd's
## reason: the beam is entropy-seeded in play, which is useless for a gate.
const CAPTURE_SEED := 20260831

const SETTLE_FRAMES := 10
const AIM_ITERATIONS := 12
const AIM_TOLERANCE_DEG := 1.0
const GRAB_DISTANCE := 4.0
const GRAB_WAIT_FRAMES := 45
const SECURE_WAIT_FRAMES := int(MagicBeamScript.SECURE_SECONDS * 60.0) + 90

## Longest a delivery walk is given, in frames, before it counts as a pony who never
## arrived. LEAVE_SECONDS is the ceiling Pony.leave_toward() guarantees; the margin is for
## the frame the timer is read on. Taken from collection_test.gd's LEAVE_WAIT_FRAMES.
const LEAVE_WAIT_FRAMES := int(PonyScript.LEAVE_SECONDS * 60.0) + 60

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## Same duplicate-label guard as every other hosted gate's; see collection_test.gd's.
func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = ok
		return
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "DEPOT", 180.0)
	var ranch := $Ranch as Ranch

	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	var state = get_node("/root/GameState")
	# THE BOOT COUNT, TAKEN BEFORE ANYTHING BELOW TOUCHES THE HERD. The population check at
	# the bottom of this file is this number against itself.
	var boot_population: int = ranch.spawner.get_spawned().size()

	# --- the Depot stands, and its counter guards the same way the Market's does ----------
	var depot := ranch.get_node_or_null(^"Buildings/Depot") as Node3D
	_set_check("the Depot stands", depot != null)
	var crate := ranch.get_node_or_null(^"Buildings/Depot/Crate") as Node3D
	_set_check("its crate marker exists", crate != null)
	var depot_menu = ranch.get_depot_menu()
	var market_menu = ranch.get_market_menu()
	_set_check("the Depot menu opens", depot_menu.open())
	depot_menu.close()
	_set_check("the market opens", market_menu.open())
	_set_check("the Depot refuses to open over the Market", not depot_menu.open())
	market_menu.close()
	_set_check("closing the market unpauses the tree", not get_tree().paused)

	# --- a stock pony, picked off the live herd and frozen the way capture_test.gd freezes
	# everything it measures the beam against ---------------------------------------------
	var to_catch: Pony = null
	for pony: Pony in ranch.spawner.get_spawned():
		if pony.is_stock() and not pony.is_leaving():
			to_catch = pony
			break
	_set_check("there is a stock pony out there to catch", to_catch != null)
	if to_catch == null:
		_finish()
		return
	_freeze(to_catch)
	await _frames(SETTLE_FRAMES)

	var beam: Node3D = ranch.player.get_magic_beam()
	_set_check("the player carries a beam", beam != null)
	if beam == null:
		_finish()
		return
	beam.set_capture_rng(_seeded_rng(CAPTURE_SEED))
	var storage: Storage = beam.get_storage()
	_set_check("the saddlebag starts empty", storage.count() == 0)

	await _stand_player_near(ranch, to_catch, GRAB_DISTANCE)
	await _aim_at(ranch, _chest(to_catch), "the stock pony")
	beam.grab()
	var acquired := false
	for i in range(GRAB_WAIT_FRAMES):
		await get_tree().physics_frame
		if beam.is_holding():
			acquired = true
			break
	_set_check("the beam takes the pony the crosshair is on", acquired)
	var secured := false
	for i in range(SECURE_WAIT_FRAMES):
		if beam.is_secured():
			secured = true
			break
		await get_tree().physics_frame
	_set_check("holding her long enough secures her", secured)
	beam.release()
	_set_check("letting go of a secured pony puts her in the saddlebag", storage.count() == 1)

	# --- moved into a pen through ranch.gd's own path, the E prompt's target -------------
	var slots: Array[PlotSlot] = ranch.plot_slots()
	var free_plot: PlotData = null
	for plot: PlotData in ranch.plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	_set_check("there is an empty plot and a pen that costs nothing to put on it",
		slots.size() > 0 and slots[0].is_empty() and free_plot != null)
	if slots.is_empty() or free_plot == null:
		_finish()
		return
	_set_check("the pen goes up", slots[0].build(free_plot))
	var pen := slots[0].get_built() as Pen
	_set_check("the built slot is a real pen", pen != null)
	if pen == null:
		_finish()
		return
	_set_check("the pony in the saddlebag moves into it", ranch._move_pony_into_pen(slots[0]))
	var residents: Array[PonyInstance] = pen.ponies()
	_set_check("she is living in the pen and no longer in the bag",
		residents.size() == 1 and storage.count() == 0)
	if residents.is_empty():
		_finish()
		return
	var stock_uid: StringName = residents[0].uid

	# --- deliver_rows() lists her, stock first, at the stock rate --------------------------
	var rows: Array[Dictionary] = depot_menu.deliver_rows()
	_set_check("she is on the deliver tab", rows.size() == 1
		and StringName(rows[0].get("uid", &"")) == stock_uid)
	_set_check("stock first", bool(rows[0].get("stock", false)))
	_set_check("priced at the stock delivery credit",
		int(rows[0].get("credit", -1)) == LedgerScript.DELIVERY_CREDIT_STOCK)

	# --- the census, watched from here through the whole delivery -------------------------
	# EVERY BODY IN THE WORLD, roaming and penned, taken AFTER the catch above: the roaming
	# body the beam just took is already gone (magic_beam.gd's _settle_pony() queue_free()s
	# it on a successful hold, which is a capture and not a loss the delivery could be
	# blamed for), so this dictionary is exactly what a delivery that touches nothing else
	# is supposed to leave alone.
	#
	# A FRAME IS LET PASS FIRST, because queue_free() only QUEUES: the freed body is still
	# is_instance_valid() (and so still counted by Spawner.get_spawned()) until the engine
	# actually clears it at the end of the frame it was called on. Taking the census before
	# that frame turns had counted her old, already-departing roaming body as a THIRD thing
	# in the world, on top of her new pen body -- and then charged this check for the very
	# deferred free that capture, not delivery, caused.
	await _frames(SETTLE_FRAMES)
	var refs := _whole_world_refs(ranch, pen)
	_set_check("there is something in the census for the delivery to be measured against",
		refs.size() > 1)

	# CAPTURED BEFORE THE DELIVERY, because release_body() (which deliver_pony() calls) hands
	# back the SAME live node it already had rather than building a fresh one -- see
	# game/world/pen.gd's release_body() and game/test/test_pen.gd's
	# test_a_released_body_leaves_the_pen_alive_and_reparented(), which proves it -- and
	# Pen.body_for() cannot find her again once release_body() has cleared her from the pen's
	# own bookkeeping.
	var body_before: Node3D = pen.body_for(stock_uid)
	_set_check("the pen knows which body is hers before any of this starts", body_before != null)

	var balance_before: int = state.ledger.balance
	var result: Dictionary = ranch.deliver_pony(stock_uid)
	print("DEPOT deliver ok=%s credit=%s named=%s balance=%d->%d"
		% [result.get("ok"), result.get("credit"), result.get("named"), balance_before,
			state.ledger.balance])
	_set_check("delivering her answers ok, her credit, and that she is not named",
		bool(result.get("ok", false)) == true
			and int(result.get("credit", -1)) == LedgerScript.DELIVERY_CREDIT_STOCK
			and bool(result.get("named", true)) == false)
	_set_check("the balance fell by exactly the stock credit",
		state.ledger.balance == balance_before - LedgerScript.DELIVERY_CREDIT_STOCK)
	_set_check("delivered_this_period counts her", state.ledger.delivered_this_period == 1)
	_set_check("GameState no longer finds her", state.find_pony(stock_uid) == null)
	var still_penned := false
	for slot: PlotSlot in ranch.plot_slots():
		var p := slot.get_built() as Pen
		if p != null and p.find_pony(stock_uid) != null:
			still_penned = true
	_set_check("no pen finds her either", not still_penned)

	# --- she is walking, not gone -----------------------------------------------------------
	await get_tree().physics_frame
	var delivered_body: Pony = body_before as Pony
	# CAPTURED NOW, WHILE SHE IS STILL VALID: the census check below reads this after the
	# wait loop, by which point she is expected to have been freed, and get_instance_id() on
	# an already freed object is not something to lean on.
	var delivered_id: int = delivered_body.get_instance_id() if delivered_body != null else -1
	_set_check("her body is still in the tree the frame after the delivery",
		delivered_body != null and is_instance_valid(delivered_body)
			and delivered_body.is_inside_tree())
	_set_check("she is leaving, not idling", delivered_body != null and delivered_body.is_leaving())

	var first_gap := INF
	var last_gap := INF
	var gone := false
	var frames_taken := 0
	for i in range(LEAVE_WAIT_FRAMES):
		await get_tree().physics_frame
		frames_taken = i + 1
		if delivered_body == null or not is_instance_valid(delivered_body):
			gone = true
			break
		last_gap = delivered_body.global_position.distance_to(ranch.crate_position())
		if first_gap == INF:
			first_gap = last_gap
	print("DEPOT deliver walk first=%.2f last=%.2f gone=%s frames=%d of %d"
		% [first_gap, last_gap, gone, frames_taken, LEAVE_WAIT_FRAMES])
	_set_check("her distance to the crate fell", first_gap != INF and last_gap < first_gap)
	_set_check("she is freed within Pony.LEAVE_SECONDS", gone)
	_set_check("her final measured distance to the crate was inside the arrival radius",
		last_gap <= PonyScript.LEAVE_ARRIVAL_RADIUS)

	# --- NOTHING ELSE LOST A PONY --------------------------------------------------------
	var went_null: Array[int] = []
	for id in refs:
		if (refs[id] as WeakRef).get_ref() == null:
			went_null.append(id)
	print("DEPOT deliver census went_null=%d of %d" % [went_null.size(), refs.size()])
	_set_check("the only body that went null is the delivered one",
		went_null.size() == 1 and went_null[0] == delivered_id)

	# --- a named delivery marks PROCESSED, and the compendium page says so ----------------
	var registry: PonyRegistry = state.get_registry()
	var named_data: PonyData = registry.all()[0]
	var named_inst := PonyInstanceScript.create(named_data.id)
	_set_check("a second resident, this one named, moves into the pen",
		pen.add_pony(named_inst))
	state.compendium.mark_caught(named_data.id)
	var result_named: Dictionary = ranch.deliver_pony(named_inst.uid)
	_set_check("delivering a named pony answers ok and names her", bool(result_named.get("ok", false))
		and bool(result_named.get("named", false)))
	_set_check("she is marked PROCESSED",
		state.compendium.state_of(named_data.id) == CompendiumScript.State.PROCESSED)

	var pause = ranch.get_pause_menu()
	_set_check("the compendium page opens", pause.open_page(PauseMenu.Page.COMPENDIUM))
	var roster: Array[PonyData] = pause.roster()
	var rows_text: Array[String] = pause.compendium_rows()
	var row_index := -1
	for i in range(roster.size()):
		if roster[i].id == named_data.id:
			row_index = i
			break
	_set_check("her row reads Delivered, with the Company's smiley",
		row_index >= 0 and rows_text[row_index].contains("Delivered :)"))
	_set_check("the header still counts her as caught",
		pause.compendium_header().contains("%d of" % (state.compendium.count(
			CompendiumScript.State.CAUGHT, registry)
			+ state.compendium.count(CompendiumScript.State.PROCESSED, registry))))
	pause.close()

	# --- paying the company ---------------------------------------------------------------
	var economy: Economy = ranch.get_economy()
	economy.bits += 1000
	var balance_before_pay: int = state.ledger.balance
	var bits_before_pay: int = economy.bits
	var paid: int = ranch.pay_the_company(200)
	_set_check("paying 200 moves the balance by exactly 200",
		paid == 200 and state.ledger.balance == balance_before_pay - 200)
	_set_check("...and debits the wallet by exactly 200", economy.bits == bits_before_pay - 200)

	var payable: int = state.ledger.payable()
	var over_offer: int = payable + 5000
	economy.bits += over_offer
	var bits_before_overpay: int = economy.bits
	var paid_over: int = ranch.pay_the_company(over_offer)
	_set_check("a pay of more than payable() takes only what is allowed",
		paid_over == payable)
	_set_check("...and debits the wallet by that same number, never more",
		economy.bits == bits_before_overpay - payable)

	# --- the statement names the player and carries no dash -------------------------------
	var lines: Array[String] = depot_menu.statement_provider.call()
	var joined: String = "\n".join(lines)
	_set_check("the statement names the player", joined.contains(ranch._player_name()))
	_set_check("...and carries no double hyphen", not joined.contains("--"))
	_set_check("...and no em dash", not joined.contains(char(0x2014)))

	# --- the world's population, boot count minus the one delivered pony, plus whatever
	# tick_stock() legitimately stands back up, measured by the gate's own call rather than
	# by a frame count of its own ------------------------------------------------------------
	var arrived: int = ranch.spawner.tick_stock(SpawnerScript.STOCK_RESPAWN_SECONDS)
	var final_count: int = ranch.spawner.get_spawned().size()
	print("DEPOT population boot=%d final=%d arrived=%d" % [boot_population, final_count, arrived])
	_set_check("the world holds the boot count minus the delivered pony, plus what tick_stock stood up",
		final_count == boot_population - 1 + arrived)

	# --- cleanup: nothing here writes a save, but SLOT is reserved the same way the other
	# hosted gates reserve theirs, so this leaves no file behind if a future edit adds one ---
	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_finish()


# --- the census -----------------------------------------------------------------------------

## A WeakRef to every pony body standing in the world right now: the roaming herd
## (ranch.spawner.get_spawned()) and every resident of every built pen. Keyed by instance id
## purely to give _set_check() something stable to print; the values are what the delivery
## check below actually reads.
func _whole_world_refs(ranch: Ranch, pen: Pen) -> Dictionary:
	var out := {}
	for pony: Pony in ranch.spawner.get_spawned():
		out[pony.get_instance_id()] = weakref(pony)
	for slot: PlotSlot in ranch.plot_slots():
		var built := slot.get_built() as Pen
		if built == null:
			continue
		for inst: PonyInstance in built.ponies():
			var body: Node3D = built.body_for(inst.uid)
			if body != null:
				out[body.get_instance_id()] = weakref(body)
	return out


# --- driving the player, copied from scenes/test/collection_test.gd's own -------------------

## Stop a pony reacting and stop her wandering, and take the fight out of her. Same three
## lines, and the same reason, as collection_test.gd's _freeze(): a pony who can see the
## player is a pony who is running by the time he is close enough to grab her, and this gate
## is about the delivery, not about a chase.
func _freeze(pony: Pony) -> void:
	var detection := pony.get_node_or_null("DetectionArea") as Area3D
	if detection != null:
		detection.monitoring = false
	pony.roam_radius = 0.0
	pony.beam_holds = MagicBeamScript.WRENCH_GRACE_HOLDS


## Put the player on the ground `distance` metres from `pony`, on the bearing he is already
## on, and let the physics server and the spring arm catch up.
func _stand_player_near(ranch: Ranch, pony: Node3D, distance: float) -> void:
	var away: Vector3 = ranch.player.global_position - pony.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	var stand: Vector3 = pony.global_position + away.normalized() * distance
	stand.y = float(ranch.terrain.call("height_at", stand.x, stand.z)) + 0.15
	ranch.player.global_position = stand
	ranch.player.velocity = Vector3.ZERO
	await _frames(SETTLE_FRAMES)


## Drive the camera rig until get_aim_ray() points at `target`, then assert that it does.
## Same loop as collection_test.gd's _aim_at().
func _aim_at(ranch: Ranch, target: Vector3, label: String) -> void:
	var rig: Node = ranch.player.get_camera_pivot().get_node("CameraRig")
	for i in range(AIM_ITERATIONS):
		var ray = rig.get_aim_ray()
		var want: Vector3 = (target - ray.origin).normalized()
		var have: Vector3 = ray.direction
		var yaw_error := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		var pitch_error := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
		rig.add_look_delta(-yaw_error, -pitch_error)
		await get_tree().physics_frame
	var ray = rig.get_aim_ray()
	var want: Vector3 = (target - ray.origin).normalized()
	var error_deg := rad_to_deg(acos(clampf(want.dot(ray.direction), -1.0, 1.0)))
	_set_check("the crosshair really is on %s" % label, error_deg <= AIM_TOLERANCE_DEG)


func _chest(pony: Node3D) -> Vector3:
	return pony.global_position + Vector3(0.0, MagicBeamScript.PONY_HOLD_LIFT, 0.0)


# --- helpers -----------------------------------------------------------------------------------

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("depot_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("depot_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("DEPOT_OK " if all_ok else "DEPOT_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
