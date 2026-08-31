extends Node
## THE COLLECTION GATE. Proves the whole of slice 5's collection loop in one run, on the
## real ranch: a herd whose membership answers to the hour, a compendium that fills itself
## from what the player actually does, a request board that pays for it, a pause menu page
## repeating the counts, and a save that brings all of it back.
##
## WHY A GATE AND NOT ONLY UNIT TESTS. game/test/test_pony_data.gd proves available(),
## game/test/test_compendium.gd proves the three states and their counts, and
## game/test/test_request_board.gd proves the templates and the payouts, all without a
## scene. None of them can see the WIRE between them, and the wire is what breaks: a
## spawner that never re-reads the sky, a beam whose captured() nobody connected, a
## compendium the pause menu was handed once at boot and never again, a board rebuilt from
## a fresh seed on every load. Every one of those passes the whole unit suite and leaves the
## player with a book that never fills and favours she is never paid for.
##
## THE RANCH IS HOSTED HERE, not launched. world/ranch.tscn is instanced under this scene,
## so ranch.gd runs with _hosted true: it arms no watchdog of its own, it does not quit the
## process out from under this driver, it never reads the player's save, and it hands its
## own verdict over as gate_report_finished(all_ok). This gate waits for that signal rather
## than polling for a symptom of it, and folds the ranch's answer into its own. Same
## scaffold as scenes/test/market_test.gd, scenes/test/region_test.gd and
## scenes/test/world_test.gd.
##
## NOTHING HERE NAMES A CHARACTER. Which characters keep night hours is a property of the
## .tres files on disk, and a gate with `nightlight` typed into it would go green on a
## roster that had stopped being conditional at all. The classes below (NIGHT-only,
## DAY-only, "her hours have ended") are computed at run time by asking every character's
## own PonyData.available() about all sixteen (phase, weather) pairs, so a retuned roster
## moves this gate with it. The characters it actually walks up to are picked out of the
## live herd the same way.
##
## THE CLOCK IS MOVED IN PHASE-LENGTH STEPS, never in one jump to night. Each step is a
## phase change, each phase change is a Spawner.refresh() through ranch.gd's own signal
## path, and it is the sequence of refreshes, not the final hour, that this is about.
##
## NO PONY EVER DIES IN HERE. The one pony this gate frees is freed by the departure path
## the spec allows (Pony._state_leaving), by her own timer, at her own distance; the one it
## catches is bagged and then penned, which is where she lives from then on.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const MarketMenuScript := preload("res://ui/market_menu.gd")
const InteractionScript := preload("res://world/interaction.gd")

const SLOT := 5  # a scratch slot; a hosted ranch reads no slot at all, so nothing collides

## Seed for the beam's capture generator: the jitter on the subdue clock and every wrench
## roll. Fixed for the same reason scenes/test/capture_test.gd fixes its own: the beam is
## entropy-seeded in play, which is right for a player and useless for a gate, where an
## unlucky roll would be an intermittent red with nothing in the output to tell it from a
## regression.
const CAPTURE_SEED := 20260829

## Frames to let the physics server catch up after a body has been moved by hand. The
## camera hangs off a spring arm and the pony detection areas are broadphase volumes;
## neither has an opinion about a teleport until a step has run.
const SETTLE_FRAMES := 10

## Frames the aim loop is given to converge, and how close it has to land. Both taken from
## scenes/test/capture_test.gd, which measures the same rig the same way.
const AIM_ITERATIONS := 12
const AIM_TOLERANCE_DEG := 1.0

## How far from a pony the player is stood to catch her: comfortably inside the beam's
## reach, and far enough out that the hold point is in front of him rather than inside him.
const GRAB_DISTANCE := 4.0

## How far from a pony the player is stood to be NOTICED by her: well inside the tightest
## notice radius on the roster, so the check is about whether the notice is WIRED to the
## compendium rather than about where the boundary is (scenes/test/capture_test.gd measures
## the boundary itself, in metres, and does it better than a ranch full of moving ponies
## could).
const NOTICE_DISTANCE := 3.0

## Longest the SEEN check waits for her to react, in frames. Generous: she has to be picked
## up by her own DetectionArea's broadphase first, and that is a physics step of its own.
const NOTICE_WAIT_FRAMES := 120

## Longest a grab is given to acquire, and a hold to be reported secured. The second is
## derived from the beam's own constant rather than typed, so a retune of SECURE_SECONDS
## cannot leave this waiting less time than a capture now takes.
const GRAB_WAIT_FRAMES := 45
const SECURE_WAIT_FRAMES := int(MagicBeamScript.SECURE_SECONDS * 60.0) + 90

## Longest a departure is given, in frames, before it counts as a pony who never left.
## LEAVE_SECONDS is the ceiling Pony guarantees; the margin is for the frame the timer is
## read on. A pony well clear of the player normally goes in about four seconds, so this
## bound is not what the run spends its time on.
const LEAVE_WAIT_FRAMES := int(PonyScript.LEAVE_SECONDS * 60.0) + 60

## Metres a leaving pony has to put between herself and the player she set off in front of
## before "she walked away" is a measurement rather than a rounding error. Her flee speed
## covers this in a little over a second, and she has the whole of LEAVE_SECONDS.
const LEAVE_MIN_TRAVEL := 4.0

## Nights this gate is willing to spin through looking for a NIGHT-only arrival. See the
## block that uses it: each one is four advance_world() calls and costs no wall time.
const EXTRA_NIGHTS := 12

## How many of those extra nights the shipped draw actually needs, MEASURED, not required.
## It was 3 while a freed slot went back into the rarity weighted draw and a night only
## character had to out roll every unconditional common in her zone; Spawner.refresh() now
## offers a freed slot to the characters whose hours have just opened before anybody else,
## and the first night answers. Printed beside the real count rather than asserted on: the
## claim with teeth is that the night pool is reachable AT ALL (see the block that spins the
## loop), and a re-zoning that puts the number back up to 1 or 2 is a fact about the roster
## worth seeing in a diff, not a build worth failing.
const EXPECTED_EXTRA_NIGHTS := 0

## Metres two ponies have to be apart for this gate to use one for the SEEN check and the
## other for the capture. Comfortably more than the widest notice radius on the roster, so
## walking up to the first cannot be what makes the second react.
const PONY_SEPARATION := 30.0

var _checks: Dictionary = {}
var _duplicates: Array[String] = []

## The one departure this gate watches from up close. See _advance_one_phase().
var _watched := false
var _watch_id: StringName = &""
var _watch_gap_before := 0.0
var _watch_gap_last := 0.0
var _watch_gone := false
## Physics frames between the hour turning and her body being freed. Printed rather than
## asserted on: the ceiling she has to be gone inside is LEAVE_WAIT_FRAMES, which _watch_gone
## already answers, and what this adds is a number that MOVES when the walk changes, so a
## departure that started taking twice as long shows up in a diff of two runs.
var _watch_frames := 0


## Record one check's verdict under `label`. A repeated label is a check that never ran:
## the second verdict would silently overwrite the first and the total would come out one
## short, so a collision is recorded and fails the gate in _finish(). Same rule as
## market_test.gd's, world_test.gd's and ranch.gd's own.
##
## The loser is kept under a suffixed key rather than dropped: a run with a duplicate still
## reports BOTH verdicts, so the collision costs you the label rather than the measurement.
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
	GateWatchdogScript.arm(self, "COLLECTION", 180.0)
	var ranch := $Ranch as Ranch

	# The ranch's boot awaits inside its own _ready(), so it has already yielded by the
	# time this line runs and the connection lands before the verdict is emitted.
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	# Untyped on purpose, the way world_test.gd and market_test.gd read it: the autoload's
	# script carries no class_name, so a `Node` annotation here would refuse every property
	# below at parse time.
	var state = get_node("/root/GameState")
	var compendium: Compendium = ranch.get_compendium()
	var board: RequestBoard = ranch.get_request_board()
	var world: WorldState = ranch.get_world_state()
	var registry: PonyRegistry = state.get_registry()
	_set_check("the ranch built a compendium", compendium != null)
	_set_check("the ranch built a request board", board != null)
	_set_check("the ranch built a world clock", world != null)
	_set_check("there is a character roster to count against", registry != null
		and not _roster(registry).is_empty())
	if compendium == null or board == null or world == null or registry == null:
		_finish()
		return

	# --- who the roster says keeps which hours ------------------------------------------
	var night_only: Dictionary = _only_at(registry, WorldStateScript.Phase.NIGHT)
	var day_only: Dictionary = _only_at(registry, WorldStateScript.Phase.DAY)
	print("COLLECTION roster total=%d night_only=%s day_only=%s"
		% [_roster(registry).size(), _id_list(night_only), _id_list(day_only)])
	_set_check("the roster holds characters who only come out at night",
		not night_only.is_empty())
	_set_check("the roster holds characters who only come out in the day",
		not day_only.is_empty())

	# --- the herd a fresh ranch opens with -----------------------------------------------
	var boot_phase: int = world.phase()
	var boot_weather: int = world.weather()
	var standing_at_boot: Array = ranch.spawner.get_spawned()
	print("COLLECTION boot phase=%s weather=%s standing=%d"
		% [WorldStateScript.phase_name(boot_phase).to_upper(),
			WorldStateScript.weather_name(boot_weather).to_upper(), standing_at_boot.size()])
	_set_check("a fresh ranch opens at dawn", boot_phase == WorldStateScript.Phase.DAWN)
	_set_check("there is a herd standing on it", standing_at_boot.size() > 0)
	var wrong_hour: Array[String] = []
	var night_out_at_dawn: Array[String] = []
	for pony: Pony in standing_at_boot:
		var data: PonyData = pony.get_data()
		if data == null:
			continue
		if not data.available(boot_phase, boot_weather):
			wrong_hour.append(String(data.id))
		if night_only.has(data.id):
			night_out_at_dawn.append(String(data.id))
	print("COLLECTION boot out_of_hours=%s night_only_standing=%s"
		% [_string_list(wrong_hour), _string_list(night_out_at_dawn)])
	_set_check("every pony standing at boot keeps the hour and weather she is standing in",
		wrong_hour.is_empty())
	_set_check("no character who only comes out at night is standing at dawn",
		night_out_at_dawn.is_empty())

	# --- pick the two ponies this gate walks up to ----------------------------------------
	# THE CATCH TARGET IS CHOSEN AND FROZEN FIRST, before the player is moved anywhere near
	# anybody. Her DetectionArea goes off and her roam radius goes to zero, which is exactly
	# what scenes/test/capture_test.gd does to every pony it measures the beam against and
	# for the same reason: a pony who bolts between the aim loop and the grab turns "the
	# beam took her" into a coin toss on a chase. She is never noticed, so her compendium
	# entry goes straight from UNSEEN to CAUGHT, which is the narrower claim that catching
	# somebody nobody ever looked at still records having seen her.
	var to_catch: Pony = _pick_pony(standing_at_boot, compendium, null)
	_set_check("there is a pony out there to catch", to_catch != null)
	if to_catch != null:
		_freeze(to_catch)
	var to_notice: Pony = _pick_pony(standing_at_boot, compendium, to_catch)
	_set_check("...and a second one, far enough off, to walk up to", to_notice != null)
	if to_catch == null or to_notice == null:
		_finish()
		return
	var catch_id: StringName = to_catch.get_data().id
	var notice_id: StringName = to_notice.get_data().id
	print("COLLECTION targets notice=%s catch=%s" % [String(notice_id), String(catch_id)])
	await _frames(SETTLE_FRAMES)

	# --- she is seen ----------------------------------------------------------------------
	_set_check("the pony to be noticed starts UNSEEN",
		compendium.state_of(notice_id) == CompendiumScript.State.UNSEEN)
	await _stand_player_near(ranch, to_notice, NOTICE_DISTANCE)
	var noticed := false
	for i in range(NOTICE_WAIT_FRAMES):
		if compendium.state_of(notice_id) != CompendiumScript.State.UNSEEN:
			noticed = true
			break
		await get_tree().physics_frame
	print("COLLECTION seen id=%s state=%s" % [String(notice_id),
		_state_name(compendium.state_of(notice_id))])
	# ONE CHECK, NOT TWO. "she noticed him" and "the book says SEEN" were separate labels
	# reading the same field a line apart: `noticed` is set by watching for exactly the
	# state change the second one then asserts, so neither could fail without the other.
	_set_check("standing inside her notice radius gets her written down as SEEN",
		noticed and compendium.state_of(notice_id) == CompendiumScript.State.SEEN)

	# --- she is caught ----------------------------------------------------------------------
	var beam: Node3D = ranch.player.get_magic_beam()
	_set_check("the player carries a beam", beam != null)
	if beam == null:
		_finish()
		return
	beam.set_capture_rng(_seeded_rng(CAPTURE_SEED))
	var storage: Storage = beam.get_storage()
	_set_check("the saddlebag is empty before the catch", storage.count() == 0)
	_set_check("the pony to be caught is not already in the book",
		compendium.state_of(catch_id) != CompendiumScript.State.CAUGHT)

	var catch_request: Dictionary = _request_of_kind(board, RequestBoardScript.Kind.CATCH_ANY)
	var pen_request: Dictionary = _request_of_kind(board, RequestBoardScript.Kind.PEN_ANY)
	var sell_request: Dictionary = _request_of_kind(board, RequestBoardScript.Kind.SELL_ANY)
	print("COLLECTION tutorial catch=%s/%d pen=%s/%d sell=%s/%d" % [
		String(catch_request.get("id", "-")), int(catch_request.get("reward_bits", 0)),
		String(pen_request.get("id", "-")), int(pen_request.get("reward_bits", 0)),
		String(sell_request.get("id", "-")), int(sell_request.get("reward_bits", 0))])
	_set_check("the board opens on the tutorial three", not catch_request.is_empty()
		and not pen_request.is_empty() and not sell_request.is_empty())
	# The numbers the brief names, asserted once and read out of the board everywhere else,
	# so a retune of the tutorial moves one check rather than three.
	_set_check("the tutorial three pay 20, 30 and 50 bits",
		int(catch_request.get("reward_bits", 0)) == 20
		and int(pen_request.get("reward_bits", 0)) == 30
		and int(sell_request.get("reward_bits", 0)) == 50)

	await _stand_player_near(ranch, to_catch, GRAB_DISTANCE)
	await _aim_at(ranch, _chest(to_catch), "the pony to catch")
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

	var bits_before_catch: int = state.bits
	beam.release()
	print("COLLECTION catch id=%s bagged=%d state=%s bits=%d->%d" % [String(catch_id),
		storage.count(), _state_name(compendium.state_of(catch_id)),
		bits_before_catch, state.bits])
	_set_check("letting go of a secured pony puts her in the saddlebag", storage.count() == 1)
	_set_check("catching her marks her CAUGHT in the compendium",
		compendium.state_of(catch_id) == CompendiumScript.State.CAUGHT)
	_set_check("...which is a record of having seen her too, though nobody ever did",
		compendium.to_dict().has(String(catch_id)))
	_set_check("catching her finished the board's first favour",
		_is_done(board, String(catch_request.get("id", ""))))
	_set_check("...and paid the bits that favour was offering",
		state.bits == bits_before_catch + int(catch_request.get("reward_bits", 0)))

	# --- she is penned -------------------------------------------------------------------
	# THE PEN IS BUILT AND SHE IS MOVED IN THROUGH THE INTERACT VERB ITSELF: the player is
	# stood on the plot, ranch.current_interaction() is asked what the key would do there,
	# and ranch.perform_interaction() does exactly that. Both are public and Input free for
	# this reason (see their own comments), so the gate no longer has to reach past the
	# resolver into _move_pony_into_pen() and take on faith that the two agree.
	#
	# WHAT STILL CANNOT BE DRIVEN FROM HERE is the KEY PRESS: the whole of ranch.gd's
	# _physics_process input handling is gated on `_interactive`, which is false in a
	# headless run precisely so a gate teleporting the player about cannot trip a build menu
	# or an autosave. Everything downstream of Input.is_action_just_pressed() is what runs
	# below, which is the half that carries the board.
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
	var bits_before_pen: int = state.bits
	# Standing IN the plot is what makes the slot a candidate at all (see
	# ranch.interaction_candidates(), which asks the slot's own overlapping bodies), and an
	# Area3D does not know about a body that was teleported into it until the physics server
	# has run.
	ranch.player.global_position = Vector3(slots[0].global_position.x,
		ranch.player.global_position.y, slots[0].global_position.z)
	ranch.player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pen_action: Dictionary = ranch.current_interaction()
	print("COLLECTION interact kind=%d subject='%s'" % [
		int(pen_action.get("kind", -1)), String(pen_action.get("subject", ""))])
	_set_check("standing in a built pen, the interact key means move her in",
		int(pen_action.get("kind", InteractionScript.Kind.NONE))
			== InteractionScript.Kind.PEN_MOVE_IN)
	_set_check("the pony in the saddlebag moves into it",
		ranch.perform_interaction(pen_action))
	var pen := slots[0].get_built() as Pen
	print("COLLECTION pen residents=%d bagged=%d bits=%d->%d"
		% [pen.count() if pen != null else -1, storage.count(), bits_before_pen, state.bits])
	_set_check("she is living in the pen and no longer in the bag",
		pen != null and pen.count() == 1 and storage.count() == 0)
	_set_check("penning her finished the board's second favour",
		_is_done(board, String(pen_request.get("id", ""))))
	_set_check("...and paid the bits the second favour was offering",
		state.bits == bits_before_pen + int(pen_request.get("reward_bits", 0)))

	# --- a gem is sold ---------------------------------------------------------------------
	var shop: Shop = ranch.get_shop()
	_set_check("the ranch bound a shop", shop != null)
	if shop == null:
		_finish()
		return
	var rarity: int = PonyDataScript.Rarity.COMMON
	state.gems.add(rarity, 1)
	var menu = ranch.get_market_menu()
	_set_check("the market opens", menu.open())
	menu.set_tab(MarketMenuScript.Tab.SELL)
	menu.move_selection(1 + rarity)
	var bits_before_sell: int = state.bits
	var gem_price: int = shop.gem_price(rarity)
	_set_check("the gem sells", menu.confirm())
	print("COLLECTION sell price=%d bits=%d->%d" % [gem_price, bits_before_sell, state.bits])
	_set_check("selling it finished the board's third favour",
		_is_done(board, String(sell_request.get("id", ""))))
	_set_check("...and paid the third favour's bits on top of the gem's own price",
		state.bits == bits_before_sell + gem_price + int(sell_request.get("reward_bits", 0)))
	menu.close()
	_set_check("closing the market unpauses the tree", not get_tree().paused)

	# --- and three more go up in their place ------------------------------------------------
	var active: Array = board.active()
	var tutorial_ids := {
		String(catch_request.get("id", "")): true,
		String(pen_request.get("id", "")): true,
		String(sell_request.get("id", "")): true,
	}
	var still_tutorial := 0
	for entry in active:
		if tutorial_ids.has(String((entry as Dictionary).get("id", ""))):
			still_tutorial += 1
	print("COLLECTION board active=%d kinds=%s" % [active.size(), _kind_list(active)])
	_set_check("three favours are standing on the board again",
		active.size() == RequestBoardScript.ACTIVE)
	_set_check("...and not one of them is a tutorial favour over again",
		still_tutorial == 0)

	# --- the page repeats the counts ---------------------------------------------------------
	var pause = ranch.get_pause_menu()
	_set_check("the compendium page opens", pause.open_page(PauseMenu.Page.COMPENDIUM))
	_set_check("...and it is the page that is up", pause.page() == PauseMenu.Page.COMPENDIUM)
	var header: String = pause.compendium_header()
	var caught_now: int = compendium.count(CompendiumScript.State.CAUGHT, registry)
	# SEEN PLUS CAUGHT, which is the page's own definition of the word (game/ui/pause_menu.gd,
	# compendium_header) and the ranch report's too: a caught pony has been laid eyes on.
	# Recomputed here rather than read off the page, so this compares two answers to one
	# question instead of printing one answer twice.
	var seen_now: int = compendium.count(CompendiumScript.State.SEEN, registry) + caught_now
	var want_header := "%d of %d caught, %d seen"\
		% [caught_now, compendium.total(registry), seen_now]
	print("COLLECTION page header='%s' expected='%s'" % [header, want_header])
	_set_check("the page header reads the compendium's own counts", header == want_header)
	# ANTI-VACUITY: "0 of 43 caught, 0 seen" would match a header built from an empty book
	# handed to an empty book, which is exactly the wiring failure this is here to catch.
	_set_check("...and there is something in the book for it to be counting",
		caught_now >= 1 and seen_now >= 1)
	pause.close()
	_set_check("closing the pause menu unpauses the tree", not get_tree().paused)

	# --- the sky turns over, and the herd turns over with it ------------------------------
	# THE PLAYER GOES HOME FIRST, so nothing below is measured with him standing in the
	# middle of it. _advance_one_phase() walks him back out to one chosen pony, once, for
	# the single check that is about being watched; see its comment.
	ranch.player.global_position = ranch.player_spawn.global_position
	ranch.player.velocity = Vector3.ZERO
	await _frames(SETTLE_FRAMES)

	var phases_seen: Array[int] = [world.phase()]
	await _advance_one_phase(ranch, world, state)
	phases_seen.append(world.phase())
	var standing_by_day := _standing_ids(ranch)
	print("COLLECTION day phase=%s weather=%s standing=%d"
		% [WorldStateScript.phase_name(world.phase()).to_upper(),
			WorldStateScript.weather_name(world.weather()).to_upper(), standing_by_day.size()])

	await _advance_one_phase(ranch, world, state)
	phases_seen.append(world.phase())
	await _advance_one_phase(ranch, world, state)
	phases_seen.append(world.phase())

	_set_check("the clock really walked through dawn, day, dusk and night",
		phases_seen == [WorldStateScript.Phase.DAWN, WorldStateScript.Phase.DAY,
			WorldStateScript.Phase.DUSK, WorldStateScript.Phase.NIGHT])
	var night_phase: int = world.phase()
	var night_weather: int = world.weather()

	var standing_at_night := _standing_ids(ranch)
	var arrived_night_only: Array[String] = []
	var out_of_hours_at_night: Array[String] = []
	for id in standing_at_night:
		var data: PonyData = registry.by_id(id)
		if data == null:
			continue
		if night_only.has(id):
			arrived_night_only.append(String(id))
		if not data.available(night_phase, night_weather):
			out_of_hours_at_night.append(String(id))

	# Two classes, because the strict one can be empty through nobody's fault: a roster with
	# two DAY-only characters in forty-three need not have had either of them drawn. The
	# broad one (everybody who WAS out in the day and whose hours have since ended) is the
	# same claim over a set big enough to assert is non-empty, so neither check can pass
	# by having had nothing to look at.
	var day_only_stayed: Array[String] = []
	var ended_left := 0
	var ended_stayed: Array[String] = []
	for id in standing_by_day:
		var data: PonyData = registry.by_id(id)
		if data == null or data.available(night_phase, night_weather):
			continue
		if standing_at_night.has(id):
			ended_stayed.append(String(id))
			if day_only.has(id):
				day_only_stayed.append(String(id))
		else:
			ended_left += 1
	print("COLLECTION night phase=%s weather=%s standing=%d night_only_arrived=%s"
		% [WorldStateScript.phase_name(night_phase).to_upper(),
			WorldStateScript.weather_name(night_weather).to_upper(),
			standing_at_night.size(), _string_list(arrived_night_only)])
	print("COLLECTION night hours_ended=%d gone=%d stayed=%s day_only_stayed=%s"
		% [ended_left + ended_stayed.size(), ended_left, _string_list(ended_stayed),
			_string_list(day_only_stayed)])

	_set_check("every character who only comes out in the day is leaving or gone by night",
		day_only_stayed.is_empty())
	_set_check("every character out in the day whose hours have ended is leaving or gone",
		ended_stayed.is_empty())
	_set_check("...and there were characters whose hours ended, to test that on",
		ended_left + ended_stayed.size() > 0)
	_set_check("nobody is standing at night who does not keep night hours",
		out_of_hours_at_night.is_empty())

	# --- the night pool is reachable ----------------------------------------------------------
	# ASKED OVER SEVERAL NIGHTS RATHER THAN ONE, and this is a statement about the draw, not
	# a hedge. Spawner.refresh() fills a marker out of its own zone's pool and only into the
	# slots it has; four NIGHT-only characters in a roster of forty-three need not all be
	# reachable from the three slots one night happens to open. What must be true is that
	# they are reachable AT ALL. A build where the conditional half of the roster could
	# never be drawn would be a build where a third of the compendium is uncompletable, and
	# that is the failure this is here for. Each extra night is four advance_world() calls
	# and a handful of frames; the loop stops at the first one that answers, and its count is
	# printed against EXPECTED_EXTRA_NIGHTS so a change in the draw shows up as a number
	# rather than as a red.
	#
	# THE LOOP STAYS THOUGH IT NO LONGER SPINS. The first night answers now that a freed slot
	# goes to the characters whose hours have just opened before it goes to the weighted
	# draw, and the measured count is zero. Deleting the loop would buy nothing (an unspun
	# loop costs no frames) and would trade a number that moves for a gate that goes red the
	# next time somebody re-zones a night pony.
	var nights_spun := 0
	while arrived_night_only.is_empty() and nights_spun < EXTRA_NIGHTS:
		nights_spun += 1
		for i in range(WorldStateScript.PHASE_SECONDS.size()):
			await _advance_one_phase(ranch, world, state)
		for id in _standing_ids(ranch):
			if night_only.has(id):
				arrived_night_only.append(String(id))
	print("COLLECTION nights extra=%d expected=%d night_only_arrived=%s cycle=%d"
		% [nights_spun, EXPECTED_EXTRA_NIGHTS, _string_list(arrived_night_only),
			world.cycle_index()])
	_set_check("a character who only comes out at night does arrive at night",
		not arrived_night_only.is_empty())
	_set_check("...and the clock was at night when she was counted",
		world.phase() == WorldStateScript.Phase.NIGHT)

	# --- and the pony whose hours ended really walked off -------------------------------------
	print("COLLECTION leave id=%s watched_from=%.1f walked=%.1f gone=%s frames=%d of %d"
		% [String(_watch_id), _watch_gap_before, _watch_gap_last - _watch_gap_before,
			_watch_gone, _watch_frames, LEAVE_WAIT_FRAMES])
	_set_check("one departure was watched from inside the player's own notice radius",
		_watched and _watch_gap_before <= PonyScript.LEAVE_DISTANCE)
	_set_check("...and she walked clear of him rather than vanishing where she stood",
		_watch_gap_last - _watch_gap_before > LEAVE_MIN_TRAVEL)
	_set_check("...and was gone inside the ceiling her own departure promises", _watch_gone)

	# --- the book and the board survive quitting ---------------------------------------------
	_set_check("the save lands", state.save_to_slot(SLOT))
	var raw: Dictionary = SaveIOScript.load(SLOT)
	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	var saved_book: Dictionary = compendium.to_dict()
	var saved_board: String = _board_signature(board)
	print("COLLECTION save version=%d book=%d board='%s' path=%s"
		% [int(raw.get("version", 0)), saved_book.size(), saved_board, path])
	_set_check("the file is the current save version",
		int(raw.get("version", 0)) == SaveIOScript.FORMAT_VERSION)
	_set_check("the file carries the compendium", raw.has("compendium")
		and (raw["compendium"] as Dictionary).size() == saved_book.size())
	_set_check("the file carries the requests", raw.has("requests")
		and (raw["requests"] as Array).size() == board.to_array().size())

	state.reset()
	_set_check("a reset empties the book", state.compendium.to_dict().is_empty())
	_set_check("...and takes the requests with it", state.requests.is_empty())
	ranch.rebind_economy()
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	var reloaded_book: Compendium = ranch.get_compendium()
	var reloaded_board: RequestBoard = ranch.get_request_board()
	print("COLLECTION reload book=%d board='%s' caught=%s"
		% [reloaded_book.to_dict().size() if reloaded_book != null else -1,
			_board_signature(reloaded_board),
			_state_name(reloaded_book.state_of(catch_id)) if reloaded_book != null else "-"])
	_set_check("loading a save brings the whole book back",
		reloaded_book != null and reloaded_book.to_dict() == saved_book)
	_set_check("...the pony she caught among them",
		reloaded_book != null
			and reloaded_book.state_of(catch_id) == CompendiumScript.State.CAUGHT)
	_set_check("...the pony she only saw among them too",
		reloaded_book != null
			and reloaded_book.state_of(notice_id) == CompendiumScript.State.SEEN)
	_set_check("loading a save brings the board back exactly as it was written",
		reloaded_board != null and _board_signature(reloaded_board) == saved_board)

	# EVERY PONY THE PLAYER OWNS IS CAUGHT, PROVEN ON A BOOK THAT DOES NOT ALREADY SAY SO.
	# The file above carries her as CAUGHT, so a load alone cannot tell rebind_economy()'s
	# _mark_owned_caught() apart from the save having remembered. The book is blanked by
	# hand first, while the pony herself stays exactly where she lives, in her pen, so that
	# the only thing that can put her back in it is the rule that owning her is catching
	# her. (The ranch's own report checks this label too, and cannot help being vacuous
	# about it: at that point in a hosted boot the player owns nobody.)
	_set_check("the player owns a pony for that rule to be about", state.pony_count() >= 1)
	state.compendium = CompendiumScript.new()
	_set_check("a book blanked by hand really is blank",
		state.compendium.to_dict().is_empty())
	ranch.rebind_economy()
	print("COLLECTION owned owned=%d state=%s"
		% [state.pony_count(), _state_name(ranch.get_compendium().state_of(catch_id))])
	_set_check("every owned pony is caught again after the book is blanked and rebound",
		ranch.get_compendium().state_of(catch_id) == CompendiumScript.State.CAUGHT)

	# --- cleanup ---------------------------------------------------------------------------
	# The backup as well as the save: commit() copies the old file aside before renaming
	# over it, so a gate that swept up only slot_<n>.json would leave a slot_<n>.json.bak
	# behind in the player's own user:// directory from the second run onward.
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIOScript.backup_path(SLOT)))
	_finish()


# --- the roster, classified by its own available() -----------------------------------------

## Every character on the roster: PonyRegistry.all(), which is the same walk
## game/ui/pause_menu.gd's roster() and Compendium's counting both make.
func _roster(registry: PonyRegistry) -> Array[PonyData]:
	return registry.all()


## {id: true} for every character who can be out at `phase` and at NO OTHER phase, in any
## weather at all.
##
## ASKED THROUGH available() RATHER THAN READ OFF PonyData.phases, and over all sixteen
## (phase, weather) pairs rather than over the phase list alone, because available() is the
## function the spawner actually draws with: a character whose weather list rules her out of
## every hour would be "NIGHT-only" by her phase array and never appear at all. Nothing here
## names a character, so a retuned roster moves this gate rather than breaking it.
func _only_at(registry: PonyRegistry, phase: int) -> Dictionary:
	var out := {}
	for data: PonyData in _roster(registry):
		var here := false
		var elsewhere := false
		for p in range(WorldStateScript.PHASE_SECONDS.size()):
			for w in range(WorldStateScript.WEATHER_NAMES.size()):
				if not data.available(p, w):
					continue
				if p == phase:
					here = true
				else:
					elsewhere = true
		if here and not elsewhere:
			out[data.id] = true
	return out


# --- picking a pony out of the live herd ----------------------------------------------------

## The first pony in the herd who is not yet in the book at all and is at least
## PONY_SEPARATION from `away_from` (pass null for no such constraint). Herd order is the
## spawner's own placement order, which is seeded, so this picks the same pony on every run.
func _pick_pony(herd: Array, compendium: Compendium, away_from: Pony) -> Pony:
	for pony: Pony in herd:
		if not is_instance_valid(pony) or pony.is_leaving():
			continue
		var data: PonyData = pony.get_data()
		if data == null or compendium.state_of(data.id) != CompendiumScript.State.UNSEEN:
			continue
		if away_from != null:
			if pony == away_from:
				continue
			if pony.global_position.distance_to(away_from.global_position) < PONY_SEPARATION:
				continue
		return pony
	return null


## Stop a pony reacting and stop her wandering, and take the fight out of her.
##
## THE PUBLISHED RULE, USED RATHER THAN BYPASSED, on all three counts.
## `DetectionArea.monitoring` off and `roam_radius` zero are what
## scenes/test/capture_test.gd does to every pony it measures the beam against: the beam's
## reach is shorter than every notice radius on the roster by construction, so a pony who
## can see the player is a pony who is running by the time he is close enough to grab her,
## and a gate about the COMPENDIUM would be silently measuring a chase. `beam_holds` past
## MagicBeam.WRENCH_GRACE_HOLDS puts her wrench chance at exactly zero by the beam's own
## published falloff. She is a pony who has been grabbed several times before and has no
## fight left, not a pony the rules were suspended for.
func _freeze(pony: Pony) -> void:
	var detection := pony.get_node_or_null("DetectionArea") as Area3D
	if detection != null:
		detection.monitoring = false
	pony.roam_radius = 0.0
	pony.beam_holds = MagicBeamScript.WRENCH_GRACE_HOLDS


## MOVE THE CLOCK ON BY EXACTLY ONE PHASE, and, once in the run, watch a departure happen
## from close enough that it has to be a walk rather than a disappearance.
##
## WHY THE WATCHING IS FOLDED INTO THE ADVANCE. A pony whose hours end while nobody is
## anywhere near her is discarded on the first frame of her departure, and correctly so: her
## own DetectionArea has no player in it, Pony._leave_distance() answers INF, and the
## guarantee "never in front of the player" is already satisfied. Timing that would be
## timing nothing. So the player is stood three metres from somebody the coming phase is
## about to close on, inside her own notice radius, and then the hour turns; now the
## departure has to actually carry her out of his sight before she may be freed, which is
## the property worth a gate.
##
## WHICH pony that is cannot be decided in advance, because it depends on the draw: a phase
## change need not end anybody's hours at all (this ranch had a dusk that ended nobody's).
## So every advance offers, the first one that has a candidate takes it, and the rest are
## ordinary advances. The weather of the phase being moved into is read out of
## WorldState.weather_for(), the same pure function the clock is about to roll, rather than
## by advancing first and looking afterwards.
func _advance_one_phase(ranch: Ranch, world: WorldState, state) -> void:
	var phase_count: int = WorldStateScript.PHASE_SECONDS.size()
	var next_phase: int = (world.phase() + 1) % phase_count
	var next_cycle: int = world.cycle_index() \
		+ (1 if next_phase == WorldStateScript.Phase.DAWN else 0)
	var next_weather: int = WorldStateScript.weather_for(
		state.world_seed, next_cycle, next_phase)

	var doomed: Pony = null
	if not _watched:
		doomed = _pick_doomed(ranch, next_phase, next_weather)
		if doomed != null:
			await _stand_player_near(ranch, doomed, NOTICE_DISTANCE)

	if doomed != null and is_instance_valid(doomed):
		_watch_gap_before = doomed.global_position.distance_to(ranch.player.global_position)
	ranch.advance_world(WorldStateScript.PHASE_SECONDS[world.phase()])
	await _frames(4)

	if doomed == null or not is_instance_valid(doomed):
		return
	_watched = true
	_watch_id = doomed.get_data().id
	_watch_gap_last = _watch_gap_before
	var ghost: WeakRef = weakref(doomed)
	for i in range(LEAVE_WAIT_FRAMES):
		await get_tree().physics_frame
		_watch_frames = i + 1
		if ghost.get_ref() == null:
			_watch_gone = true
			break
		_watch_gap_last = doomed.global_position.distance_to(ranch.player.global_position)
	ranch.player.global_position = ranch.player_spawn.global_position
	ranch.player.velocity = Vector3.ZERO
	await _frames(SETTLE_FRAMES)


## The first pony standing on the map whose hours are about to end: out now, and not
## available at (`phase`, `weather`). Herd order is the spawner's own placement order, which
## is seeded, so this picks the same pony on every run.
func _pick_doomed(ranch: Ranch, phase: int, weather: int) -> Pony:
	for pony: Pony in ranch.spawner.get_spawned():
		if pony.is_leaving():
			continue
		var data: PonyData = pony.get_data()
		if data != null and not data.available(phase, weather):
			return pony
	return null


## {id: true} for everyone standing on the map right now who is not on her way off it.
func _standing_ids(ranch: Ranch) -> Dictionary:
	var out := {}
	for pony: Pony in ranch.spawner.get_spawned():
		if pony.is_leaving():
			continue
		var data: PonyData = pony.get_data()
		if data != null:
			out[data.id] = true
	return out


# --- driving the player ---------------------------------------------------------------------

## Put the player on the ground `distance` metres from `pony`, on the bearing he is already
## on, and let the physics server and the spring arm catch up. The same move ranch.gd's own
## _stand_player_near() makes for its screenshot poses.
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
##
## Iterative rather than analytic because the camera hangs off a spring arm: changing the
## pitch moves the eye point the ray starts from, so the correction has to be re-derived
## from the new eye point. The same loop, and the same assertion, as
## scenes/test/capture_test.gd's. The assertion is the point, because nothing here hands
## the beam a target: the beam runs its own cast along the same ray this loop steers.
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


## The centre of a pony's collision capsule: what the crosshair should rest on, and what the
## beam's hold point lines up with (MagicBeam.PONY_HOLD_LIFT).
func _chest(pony: Node3D) -> Vector3:
	return pony.global_position + Vector3(0.0, MagicBeamScript.PONY_HOLD_LIFT, 0.0)


# --- reading the board ------------------------------------------------------------------------

## A copy of the first not-done request of `kind`, or an empty Dictionary.
func _request_of_kind(board: RequestBoard, kind: int) -> Dictionary:
	for entry in board.active():
		if int((entry as Dictionary).get("kind", -1)) == kind:
			return entry as Dictionary
	return {}


## Whether the request `id` is on the board and marked done.
func _is_done(board: RequestBoard, id: String) -> bool:
	for entry in board.requests():
		var req: Dictionary = entry
		if String(req.get("id", "")) == id:
			return bool(req.get("done", false))
	return false


# --- printing ---------------------------------------------------------------------------------

## One line naming everything about a board that a save is supposed to carry: its seed, its
## draw counter, and every request\'s id, kind, progress, target, reward and claim state,
## and the SENTENCE the player reads. The text is a saved field like any other and the only
## one the player actually sees; a reload that brought back three correct rewards attached
## to three blank lines would have been a green save with an unreadable board on it.
##
## COMPARED AS A STRING RATHER THAN AS to_array() AGAINST to_array(). A save is JSON, and
## JSON has no integer type, so every count and every enum comes back off disk as a float
## and a Dictionary written with ints does not compare equal to the same Dictionary read
## back (RequestBoard.from_array keeps what it was handed). Rendering both sides through
## int() says what "the board came back" actually means, the same favours and the same way
## through them, instead of failing on the storage type of a number nobody changed.
func _board_signature(board: RequestBoard) -> String:
	if board == null:
		return "<no board>"
	var parts: Array[String] = []
	for entry in board.to_array():
		var rec: Dictionary = entry
		if rec.has("seed"):
			parts.append("seed=%d/draw=%d"
				% [int(rec.get("seed", 0)), int(rec.get("draw_counter", 0))])
			continue
		parts.append("%s:%d:%d/%d:%s:%s:%d:%s x%d:%d:%d:%s:'%s'" % [
			String(rec.get("id", "")), int(rec.get("kind", -1)),
			int(rec.get("progress", 0)), int(rec.get("count", 0)),
			bool(rec.get("done", false)), bool(rec.get("paid", false)),
			int(rec.get("reward_bits", 0)), String(rec.get("reward_food", "")),
			int(rec.get("reward_food_count", 0)),
			int(rec.get("personality", -1)), int(rec.get("rarity", -1)),
			String(rec.get("character", "")) + "@" + String(rec.get("zone", "")),
			String(rec.get("text", ""))])
	return " | ".join(parts)


func _state_name(value: int) -> String:
	return String(CompendiumScript.State.keys()[value]) if value >= 0 \
		and value < CompendiumScript.State.size() else "INVALID(%d)" % value


## Sorted as Strings, never as StringNames: Godot orders StringName by interned POINTER,
## which is stable within one process and different between two. This gate is diffed
## against its own previous run, so every list it prints has to be in an order that does
## not depend on which names the engine happened to intern first.
func _id_list(ids: Dictionary) -> String:
	var names: Array[String] = []
	for id in ids:
		names.append(String(id))
	return _string_list(names)


func _string_list(values: Array[String]) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	return "[%s]" % ", ".join(sorted)


func _kind_list(entries: Array) -> String:
	var names: Array[String] = []
	for entry in entries:
		names.append(String(RequestBoardScript.Kind.keys()[
			int((entry as Dictionary).get("kind", 0))]))
	return _string_list(names)


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
			push_error("collection_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("collection_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("COLLECTION_OK " if all_ok else "COLLECTION_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
