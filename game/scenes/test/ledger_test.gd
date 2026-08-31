extends Node
## THE LEDGER GATE. Proves the whole of slice 1's debt arithmetic on the real ranch, on
## the real clock: a collection day that bills once even though the clock crosses it
## through four phase changes a cycle, a collector ladder that climbs in the order the
## spec names, and a world that is still whole after every rung of it.
##
## WHY A GATE AND NOT ONLY game/test/test_ledger.gd. That file proves the arithmetic in
## milliseconds, with a cycle number handed in by hand. It cannot see the WIRE: whether
## ranch.gd's own advance_world() actually reaches Ledger.is_collection_day_due() once per
## period rather than once per phase change, whether a revoked permit really closes the
## fence a pony is standing behind rather than only a variable, whether a padlocked pen
## really stops paying rather than only reporting that it will. Every one of those passes
## the unit suite and leaves a live ranch billing four times a cycle or a "revoked" permit
## that still lets her through the gate.
##
## THE RANCH IS HOSTED HERE, not launched, the same way scenes/test/collection_test.gd's
## is; see that file's class comment for what _hosted changes and why this gate waits on
## gate_report_finished rather than polling for a symptom of it.
##
## NO PONY IS EVER CAUGHT THROUGH THE BEAM HERE. The pen resident this gate needs to prove
## a padlock still holds every resident is built with Pen.add_pony() directly, the same
## way game/test/test_pen.gd builds one -- off the roaming herd entirely, so the census
## check below (which is about billing, not about capture) has nothing to explain away.
## scenes/test/depot_test.gd is where a pony is actually caught with the beam.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const LedgerScript := preload("res://systems/ledger.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")

const SLOT := 6  # a scratch slot; distinct from collection_test.gd's 5 so the two never race

## Seed for the beam's capture generator. Never actually rolled against here (the beam
## refuses to start while recalled, before any roll would happen), but set anyway per the
## shared scaffold's rule: a beam left on its own entropy is a beam this gate has no
## business touching, even for a call that turns out to be a no-op.
const CAPTURE_SEED := 20260830

## Simulated seconds a padlocked pen is ticked for, matching the number
## game/test/test_pen.gd already proves a padlocked pen makes nothing over.
const PADLOCK_TICK_SECONDS := 120.0

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## Record one check's verdict under `label`. Same duplicate-label guard as
## scenes/test/collection_test.gd's _set_check(): a repeated label is a check that never
## ran, and the collision is recorded rather than silently overwriting the first verdict.
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
	GateWatchdogScript.arm(self, "LEDGER", 180.0)
	var ranch := $Ranch as Ranch

	# The ranch's boot awaits inside its own _ready(), so it has already yielded by the
	# time this line runs and the connection lands before the verdict is emitted.
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	# Untyped on purpose, the way collection_test.gd reads it: the autoload's script
	# carries no class_name, so a typed annotation here would refuse every property below
	# at parse time.
	var state = get_node("/root/GameState")
	var ledger: Ledger = state.ledger
	var world: WorldState = ranch.get_world_state()
	_set_check("the ranch built a ledger", ledger != null)
	_set_check("the ranch built a world clock", world != null)
	if ledger == null or world == null:
		_finish()
		return

	_set_check("it opens at the sponsorship balance with the starting quota",
		ledger.balance == LedgerScript.STARTING_BALANCE
			and ledger.quota == LedgerScript.STARTING_QUOTA)

	# --- the pony census, watched from here to the end -----------------------------------
	# THE ROAMING HERD IS NEVER TOUCHED BY ANYTHING BELOW. No catch, no departure this gate
	# drives on purpose; every check from here on compares ranch.spawner.get_spawned()
	# against its own last reading and treats ANY drop as a failure unless every pony
	# missing from it was already is_leaving() the last time this gate looked -- which nothing
	# here should ever produce, since advance_world() below never runs long enough in real
	# physics time for a departure it starts to finish.
	var census_ids := _census_ids(ranch)

	# --- set up two permits and a stocked pen BEFORE any billing, so the ladder has a real
	# fence and a real resident to prove untouched rather than an empty claim, and so upkeep
	# is high enough that four bad periods genuinely cross the ceiling rather than merely
	# missing quota (see the paydown section below) ----------------------------------------
	var fences: Array[RegionFence] = ranch.get_region_fences()
	_set_check("there are at least two region fences to buy permits for",
		fences.size() >= 2)
	if fences.size() < 2:
		_finish()
		return
	# SORTED BY PERMIT COST, DEAREST FIRST, because ranch._dearest_open_permit() -- what the
	# PERMIT_REVOKED rung actually closes -- always picks the most expensive OPEN permit. The
	# fence this gate checks against has to be the one the ladder really revokes, not merely
	# one of the two that happen to be open.
	var priced := fences.duplicate()
	priced.sort_custom(func(a: RegionFence, b: RegionFence) -> bool:
		return a.region().permit_cost > b.region().permit_cost)
	var fence: RegionFence = priced[0]
	var region: RegionData = fence.region()
	_set_check("the dearest fence carries its region", region != null)
	if region == null:
		_finish()
		return
	for f: RegionFence in [priced[0], priced[1]]:
		state.unlocks.append(String(f.region().permit_id()))
	ranch._apply_permits()
	_set_check("buying both permits opens both fences",
		ranch.is_region_open(priced[0].region().id) and ranch.is_region_open(priced[1].region().id))
	census_ids = _check_census(ranch, census_ids, "the permit purchases")

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
	var resident := PonyInstanceScript.create(&"stock_shy")
	resident.stock = {"coat": 0, "mane": 0, "eyes": 0}
	resident.happiness = 1.0
	_set_check("a resident moves in, off the roaming herd", pen.add_pony(resident))
	census_ids = _check_census(ranch, census_ids, "stocking the pen")

	var beam: Node3D = ranch.player.get_magic_beam()
	_set_check("the player carries a beam", beam != null)
	if beam == null:
		_finish()
		return
	beam.set_capture_rng(_seeded_rng(CAPTURE_SEED))
	var storage: Storage = beam.get_storage()
	_set_check("the saddlebag starts empty", storage.count() == 0)
	var bagged := PonyInstanceScript.create(&"stock_bold")
	bagged.stock = {"coat": 1, "mane": 1, "eyes": 1}
	storage.store(bagged)
	_set_check("something rides in the saddlebag before the beam is ever recalled",
		storage.count() == 1)

	# --- the first collection day, on the real clock ---------------------------------------
	#
	# ADVANCED IN PHASE-LENGTH STEPS, never in one jump to the boundary. WorldState.advance()
	# only compares the START phase and weather against the END ones (game/systems/world_state.gd,
	# set_elapsed()): a jump of exactly WorldState.CYCLE_SECONDS * Ledger.PERIOD_CYCLES always
	# lands back on the SAME phase it started from (that jump is a whole number of cycles), so
	# phase_changed never fires for it, and whether _on_world_changed() runs at all then depends
	# on weather_changed alone, which is not guaranteed to differ two periods running -- proven
	# by measurement against this project's own fixed default world seed. Stepping one phase at a
	# time (Spawner.refresh()'s own unit, and scenes/test/collection_test.gd's) makes every step a
	# real, guaranteed phase_changed, and is the stronger version of "bills once, not four times a
	# cycle" besides: the loop below runs the DAY, DUSK and NIGHT phase changes inside a period as
	# well as its one DAWN, and periods_run must not move on any of the three that are not it.
	var period_seconds: float = WorldStateScript.CYCLE_SECONDS * LedgerScript.PERIOD_CYCLES
	var balance_at_start: int = ledger.balance
	var expected_upkeep: int = ledger.upkeep_for(ranch._built_plot_count(), ranch._open_permit_count())
	var expected_charge: int = ledger.service_charge()
	_advance_to_next_period(ranch, world, ledger, "the first collection day")
	census_ids = _check_census(ranch, census_ids, "the first collection day")
	print("LEDGER period1 periods_run=%d elapsed=%.0f balance=%d->%d cycle=%d"
		% [ledger.periods_run, world.elapsed(), balance_at_start, ledger.balance, world.cycle_index()])
	_set_check("advancing one period runs exactly one collection day",
		ledger.periods_run == 1)
	_set_check("...and it lands at one real hour of play",
		is_equal_approx(world.elapsed(), period_seconds))
	_set_check("the first collection day left the balance above where it started",
		ledger.balance > balance_at_start)
	_set_check("the quota went unmet, so the ladder climbed one rung", ledger.tier == 1)
	# THE COLLECTOR ALREADY CALLED, IN THE SAME BREATH AS THE BILL. A collection day always
	# lands exactly on the DAWN that opens its cycle (is_collection_cycle() only answers true
	# at a cycle boundary, and a new cycle's first phase is DAWN by construction), so
	# ranch._maybe_serve_collector() -- called right after ranch._maybe_run_collection_day()
	# out of the very same _on_world_changed() -- finds _collector_due already true and the
	# phase already DAWN, and serves the fee before advance_world() ever returns here. There
	# is no separate "wait for dawn" step to drive; the arithmetic below is the proof the fee
	# really was served (she cannot afford it, so it rides on the balance) rather than merely
	# judged, and the explicit call after it is the SECOND call at that same dawn the spec asks
	# for.
	_set_check("the fee really was served, not merely judged",
		ledger.balance == balance_at_start + expected_upkeep + expected_charge
			+ LedgerScript.COLLECTOR_FEE)
	var second_call: int = ranch.serve_collector()
	_set_check("a second call at the same dawn serves nobody",
		second_call == LedgerScript.Punishment.NONE)
	census_ids = _check_census(ranch, census_ids, "the fee")

	# --- three more bad periods, one rung each ----------------------------------------------
	var ladder := [LedgerScript.Punishment.PERMIT_REVOKED, LedgerScript.Punishment.PEN_PADLOCKED,
		LedgerScript.Punishment.BEAM_RECALLED]
	var ladder_names := ["permit revoked", "pen padlocked", "beam recalled"]
	for i in ladder.size():
		var before: int = ledger.balance
		_advance_to_next_period(ranch, world, ledger, "collection day %d" % (i + 2))
		census_ids = _check_census(ranch, census_ids, "collection day %d" % (i + 2))
		_set_check("collection day %d ran exactly once" % (i + 2),
			ledger.periods_run == i + 2)
		_set_check("rung %d climbs the ladder to %s, in order" % [i + 2, ladder_names[i]],
			ledger.tier == i + 2)
		var served: int = ranch.serve_collector()
		print("LEDGER collector rung=%d already_served=%s balance=%d->%d"
			% [i + 2, served == LedgerScript.Punishment.NONE, before, ledger.balance])
		_set_check("rung %d was already served at the same dawn it was judged" % (i + 2),
			served == LedgerScript.Punishment.NONE)
		census_ids = _check_census(ranch, census_ids, "rung %d" % (i + 2))

		match ladder[i]:
			LedgerScript.Punishment.PERMIT_REVOKED:
				_set_check("the permit's unlock is gone", not ranch.is_region_open(region.id))
				_set_check("the region's fence node still stands",
					is_instance_valid(fence) and fence.is_inside_tree())
				var still_here := true
				for pony: Pony in ranch.spawner.get_spawned():
					var data: PonyData = pony.get_data()
					if data != null and region.id in data.spawn_zones and not is_instance_valid(pony):
						still_here = false
				_set_check("every pony inside the region is still standing", still_here)
			LedgerScript.Punishment.PEN_PADLOCKED:
				_set_check("the pen is padlocked", pen.is_padlocked())
				_set_check("...and still holds her", pen.count() == 1
					and pen.find_pony(resident.uid) != null)
				_set_check("...and makes no gems while padlocked",
					pen.tick(PADLOCK_TICK_SECONDS) == 0)
			LedgerScript.Punishment.BEAM_RECALLED:
				_set_check("the beam is recalled", beam.is_recalled())
				beam.grab()
				_set_check("the beam refuses to start", not beam.is_active())
				_set_check("the saddlebag still holds whatever it held",
					storage.count() == 1 and storage.peek().uid == bagged.uid)

	# --- paying down to the ceiling gives everything back, in one call --------------------
	var economy: Economy = ranch.get_economy()
	economy.bits += 20000
	var overage: int = maxi(1, ledger.balance - LedgerScript.CEILING + 1)
	_set_check("the balance really is over the ceiling before this is a test of anything",
		ledger.balance > LedgerScript.CEILING)
	ranch.pay_the_company(overage)
	print("LEDGER paydown overage=%d balance=%d ceiling=%d"
		% [overage, ledger.balance, LedgerScript.CEILING])
	_set_check("paying down under the ceiling restores the permit",
		ranch.is_region_open(region.id))
	_set_check("...unpadlocks the pen, which makes gems again",
		not pen.is_padlocked() and pen.tick(PADLOCK_TICK_SECONDS) > 0)
	_set_check("...and gives the horn back",
		not beam.is_recalled())
	_set_check("the ledger's own books agree nothing is still owed back",
		ledger.revoked_permits.is_empty() and ledger.padlocked_slots.is_empty()
			and ledger.beam_recalled_until < 0)
	census_ids = _check_census(ranch, census_ids, "paying down")

	# --- the save round trips the balance, the quota, the tier and the padlock list -------
	var balance_before_save: int = ledger.balance
	var quota_before_save: int = ledger.quota
	var tier_before_save: int = ledger.tier
	_set_check("the save lands", state.save_to_slot(SLOT))
	var raw: Dictionary = SaveIOScript.load(SLOT)
	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	_set_check("the file is the current save version",
		int(raw.get("version", 0)) == SaveIOScript.FORMAT_VERSION)
	_set_check("the file carries a ledger", raw.has("ledger"))

	state.reset()
	_set_check("a reset opens a fresh ledger",
		state.ledger.balance == LedgerScript.STARTING_BALANCE)
	ranch.rebind_economy()
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	ranch.rebind_economy()
	print("LEDGER reload balance=%d->%d quota=%d->%d tier=%d->%d"
		% [balance_before_save, state.ledger.balance, quota_before_save, state.ledger.quota,
			tier_before_save, state.ledger.tier])
	_set_check("loading a save brings the balance back", state.ledger.balance == balance_before_save)
	_set_check("...the quota with it", state.ledger.quota == quota_before_save)
	_set_check("...the tier with it", state.ledger.tier == tier_before_save)
	_set_check("...and the padlock list, empty because it was paid down",
		state.ledger.padlocked_slots.is_empty())

	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIOScript.backup_path(SLOT)))
	_finish()


# --- the clock ---------------------------------------------------------------------------

## Advance the world one phase at a time (WorldStateScript.PHASE_SECONDS[world.phase()] each
## step, the same unit scenes/test/collection_test.gd's _advance_one_phase() uses) until
## `ledger.periods_run` has gone up by one. See the comment above this function's first call
## for why a single big jump of WorldState.CYCLE_SECONDS * Ledger.PERIOD_CYCLES is not used:
## it always lands back on the same phase it started from and is not guaranteed to change the
## weather either, so whether it fires _on_world_changed() AT ALL depends on a coin toss this
## gate has no business resting on. Capped generously (twenty phases, five cycles) so a bug
## that stopped billing entirely fails this gate instead of hanging it; GateWatchdog is the
## backstop either way.
func _advance_to_next_period(ranch: Ranch, world: WorldState, ledger: Ledger,
		context: String) -> void:
	var target: int = ledger.periods_run + 1
	var guard := 0
	while ledger.periods_run < target and guard < 20:
		ranch.advance_world(WorldStateScript.PHASE_SECONDS[world.phase()])
		guard += 1
	_set_check("%s landed inside the step budget this gate gave it" % context, guard < 20)


# --- the pony census ---------------------------------------------------------------------

## Every roaming pony's instance id, as a Dictionary used like a set.
func _census_ids(ranch: Ranch) -> Dictionary:
	var out := {}
	for pony: Pony in ranch.spawner.get_spawned():
		out[pony.get_instance_id()] = pony
	return out


## Compare the roaming herd against `before` (this function's own last answer). Anybody
## missing has to have been is_leaving() the last time this gate looked at her, or this
## step just lost a pony to something billing is not allowed to touch. Returns the new
## reading, so the caller threads it into the next call.
func _check_census(ranch: Ranch, before: Dictionary, label: String) -> Dictionary:
	var now := _census_ids(ranch)
	var unexplained := 0
	for id in before:
		if now.has(id):
			continue
		var pony: Pony = before[id]
		if not (is_instance_valid(pony) and pony.is_leaving()):
			unexplained += 1
	_set_check("the roaming census through %s lost nobody it cannot explain" % label,
		unexplained == 0)
	return now


# --- helpers -------------------------------------------------------------------------------

func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("ledger_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("ledger_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("LEDGER_OK " if all_ok else "LEDGER_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
