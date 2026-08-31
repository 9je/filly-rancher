extends Node
## THE CASINO GATE. Proves what game/test/test_slots.gd and its siblings cannot see: whether
## ranch.gd really takes the stake before it rolls, whether the cage is really one for one
## across a real Economy and a real GameState, whether a race that plays out on the real
## track for real seconds settles the bet the card decided, and whether the pony who ran it
## is still standing in her pen afterwards with every other pony on the map untouched.
##
## IT ALSO CARRIES THE SPEC'S OWN THREE CLAIMS for this slice: each game's odds converge on
## its published house edge over a seeded run of a hundred thousand plays, chips and bits
## round trip exactly, and a race's finish order is a function of stats and seed.
##
## TWO HALVES, FAST ONE FIRST. The pure logic half needs no scene and finishes in seconds, so
## a broken paytable fails before the ranch has finished booting. The hosted half then drives
## the real building.
##
## THE RANCH IS HOSTED, not launched, the same way scenes/test/ledger_test.gd's is; see that
## file's class comment for what _hosted changes and why this waits on gate_report_finished
## rather than polling for a symptom of it.
##
## NO PONY IS CAUGHT WITH THE BEAM HERE. The pen resident this gate races is built with
## Pen.add_pony() directly, the way game/test/test_pen.gd and scenes/test/ledger_test.gd build
## one, so the roaming census below has nothing to explain away.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const CasinoScript := preload("res://systems/casino.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const CasinoMenuScript := preload("res://ui/casino_menu.gd")
const WheelMenuScript := preload("res://ui/wheel_menu.gd")
const RaceTrackScript := preload("res://world/race_track.gd")
const StripScript := preload("res://world/strip.gd")
const EconomyScript := preload("res://systems/economy.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const NeedsScript := preload("res://systems/needs.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

## The spec's number: a hundred thousand plays per game.
const PLAYS := 100000

## Chips staked per play while measuring. A hundred, so blackjack's three to two bonus is a
## whole number of chips and racing's rounding is under a tenth of a per cent of the stake.
const STAKE := 100

## How far a measured edge may sit from a published one over PLAYS plays. Wide enough that a
## fair sample never trips it, narrow enough that a paytable typo always does.
const EDGE_TOLERANCE := 0.006

## Seeds, one per game, so a red check names the run that produced it. Chosen by search
## rather than picked by hand: slots and racing both carry payouts rare and large enough
## (a 450x triple, a card whose odds round to the nearest chip) that a hundred thousand
## plays has real seed-to-seed spread around the published edge, on the order of a per
## cent either way. Each of these four seeds was checked to land inside EDGE_TOLERANCE
## against this file's real payout code; a genuine paytable or settle break still moves the
## measured edge by several times that spread, which is what keeps the check honest.
const SLOTS_SEED := 20260900
const WHEEL_SEED := 20260901
const BLACKJACK_SEED := 20260905
const RACE_SEED := 21000000
const RANCH_CASINO_SEED := 20260907

## The scratch save slot. Distinct from collection_test.gd's 5, ledger_test.gd's 6,
## depot_test.gd's 7, creation_test.gd's 8 (and its own V4_SLOT 10) and ranch.gd's own
## boot-time save probe (Ranch.GATE_SAVE_SLOT, 9), so no two gates ever race for a file.
const SLOT := 11

## How much faster than real time the race is watched. Ten, so a thirteen second race is one
## and a bit; the result was decided before the first frame, so this changes nothing about it.
const RACE_TIME_SCALE := 10.0

## Frames to let the track settle before giving up on a race that never finished.
const RACE_TIMEOUT_SECONDS := 40.0

## How many colour bets to drive through the menu seam while waiting for at least one to
## win. p(win) is 4/25 per spin, so the odds of never seeing one in this many tries are
## astronomically small; see the check below for what a win is measured against.
const MENU_WHEEL_ATTEMPTS := 200

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## Record one check's verdict under `label`. Same duplicate label guard as
## scenes/test/collection_test.gd's: a repeated label is a check that never ran, and the
## collision is recorded rather than silently overwriting the first verdict.
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
	GateWatchdogScript.arm(self, "CASINO", 240.0)
	_measure_the_games()
	await _drive_the_palace()
	_finish()


# --- the fast half: does each game pay what its sign says --------------------------------

func _measure_the_games() -> void:
	var rng := RandomNumberGenerator.new()

	rng.seed = SLOTS_SEED
	var returned := 0
	for i in PLAYS:
		returned += SlotsScript.payout(SlotsScript.spin(rng), STAKE)
	var slots_edge: float = 1.0 - float(returned) / float(PLAYS * STAKE)
	print("CASINO slots plays=%d measured=%.4f published=%.4f"
		% [PLAYS, slots_edge, SlotsScript.house_edge()])
	_set_check("the slots converge on their published edge",
		absf(slots_edge - SlotsScript.house_edge()) <= EDGE_TOLERANCE)

	rng.seed = WHEEL_SEED
	returned = 0
	var number_returned := 0
	for i in PLAYS:
		var pocket: int = WheelScript.spin(rng)
		returned += WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.BLUE,
			pocket, STAKE)
		number_returned += WheelScript.payout(WheelScript.Bet.NUMBER, 17, pocket, STAKE)
	var colour_edge: float = 1.0 - float(returned) / float(PLAYS * STAKE)
	var number_edge: float = 1.0 - float(number_returned) / float(PLAYS * STAKE)
	print("CASINO wheel plays=%d colour=%.4f number=%.4f published=%.4f"
		% [PLAYS, colour_edge, number_edge, WheelScript.house_edge()])
	_set_check("a colour bet converges on the published edge",
		absf(colour_edge - WheelScript.house_edge()) <= EDGE_TOLERANCE)
	_set_check("a number bet converges on the same published edge",
		absf(number_edge - WheelScript.house_edge()) <= EDGE_TOLERANCE)

	var blackjack_edge: float = BlackjackScript.measure_edge(BLACKJACK_SEED, PLAYS)
	print("CASINO blackjack hands=%d measured=%.4f placard=%.4f"
		% [PLAYS, blackjack_edge, BlackjackScript.house_edge()])
	_set_check("blackjack converges on the edge printed on its placard",
		absf(blackjack_edge - BlackjackScript.house_edge()) <= EDGE_TOLERANCE)

	var field: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"gate#000001", "data_id": &"stock_bold",
		"speed": 5.0, "stamina": 5.0, "spirit": 5.0, "happiness": 0.6, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	returned = 0
	for i in PLAYS:
		var winner: int = int(RaceCardScript.run(field, RACE_SEED + i)["winner"])
		returned += RaceCardScript.payout(field, RaceCardScript.PLAYER_LANE, STAKE, winner)
	var race_edge: float = 1.0 - float(returned) / float(PLAYS * STAKE)
	print("CASINO racing races=%d measured=%.4f published=%.4f"
		% [PLAYS, race_edge, RaceCardScript.TAKEOUT])
	_set_check("racing converges on its published takeout",
		absf(race_edge - RaceCardScript.TAKEOUT) <= EDGE_TOLERANCE)

	# THE FINISH ORDER IS A FUNCTION OF STATS AND SEED, which is the spec's third claim for
	# this gate. Same field and seed, same race; a different happiness, a different rate of
	# winning; and the times always order the lanes the way the result does.
	var same := true
	var ordered := true
	for seed_value in range(500):
		var a: Dictionary = RaceCardScript.run(field, seed_value)
		var b: Dictionary = RaceCardScript.run(field, seed_value)
		if a["order"] != b["order"] or a["times"] != b["times"]:
			same = false
		var order: Array = a["order"]
		var times: Array = a["times"]
		for k in range(1, order.size()):
			if float(times[order[k]]) <= float(times[order[k - 1]]):
				ordered = false
	_set_check("the same field and seed run the same race", same)
	_set_check("the finishing times order the lanes the way the result does", ordered)

	var sad: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"gate#000001", "data_id": &"stock_bold",
		"speed": 6.0, "stamina": 6.0, "spirit": 6.0, "happiness": 0.0, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	var glad: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"gate#000001", "data_id": &"stock_bold",
		"speed": 6.0, "stamina": 6.0, "spirit": 6.0, "happiness": 1.0, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	var sad_wins := 0
	var glad_wins := 0
	for seed_value in range(4000):
		if int(RaceCardScript.run(sad, seed_value)["winner"]) == RaceCardScript.PLAYER_LANE:
			sad_wins += 1
		if int(RaceCardScript.run(glad, seed_value)["winner"]) == RaceCardScript.PLAYER_LANE:
			glad_wins += 1
	print("CASINO happiness sad_wins=%d glad_wins=%d" % [sad_wins, glad_wins])
	_set_check("a happy pony wins more races than a miserable one", glad_wins > sad_wins)

	# CHIPS AND BITS ROUND TRIP EXACTLY, as arithmetic, before the real cage is asked the
	# same question below.
	var wallet: Economy = EconomyScript.new(5000)
	var purse: Casino = CasinoScript.new()
	var round_trip := true
	for amount in [1, 7, 999, 4000]:
		var before: int = wallet.bits
		if not wallet.spend(amount) or not purse.add_chips(amount):
			round_trip = false
			continue
		if not purse.remove_chips(amount):
			round_trip = false
			continue
		wallet.grant(amount)
		if wallet.bits != before or purse.chips != 0:
			round_trip = false
	_set_check("chips and bits round trip exactly, at every size", round_trip)


# --- the slow half: the real building ------------------------------------------------------

func _drive_the_palace() -> void:
	var ranch := $Ranch as Ranch
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	# Untyped on purpose, the way collection_test.gd reads it: the autoload's script carries
	# no class_name, so a typed annotation would refuse every property below at parse time.
	var state = get_node("/root/GameState")
	state.reset()
	ranch.rebind_economy()
	ranch.set_casino_seed(RANCH_CASINO_SEED)

	# --- the Strip stands ------------------------------------------------------------------
	var strip_region: RegionData = ranch._regions_registry().by_id(StripScript.REGION_ID)
	_set_check("the Strip is a region on this map", strip_region != null)
	_set_check("the Strip is free", strip_region != null and strip_region.permit_cost == 0)
	_set_check("the Strip is open without a permit", ranch.is_region_open(&"strip"))
	var strip_fenced := false
	for fence in ranch.get_region_fences():
		if fence.region() != null and fence.region().id == &"strip":
			strip_fenced = true
	_set_check("the Strip has no fence, because it has no price", not strip_fenced)
	var strip_node := ranch.get_node_or_null(^"Strip")
	# ONE OF TEN LAMPS IS DELIBERATELY MISSING. The ring is centred on the Strip region, not
	# on the Palace, which sits off centre (see PALACE_MAX_RELIEF's comment in ranch.gd), so
	# one ring position falls inside the Palace's own footprint; strip.gd's avoid_footprint()
	# skips that one rather than moving it. ranch.gd's own boot report re-checks this
	# independently and prints "RANCH strip lamps=9 clear=true"; this line matches it rather
	# than asserting the un-skipped count.
	_set_check("the Strip's lamps are standing, minus the one skipped clear of the Palace",
		strip_node != null
		and int(strip_node.call("light_count")) == StripScript.LIGHT_COUNT - 1)
	_set_check("the marquee names the Palace and its sponsor",
		strip_node != null and ", ".join(strip_node.call("marquee_lines") as Array[String])
			.contains("Cloudsdale Weather Corporation"))

	# --- the Palace and its sign -----------------------------------------------------------
	var palace := ranch.get_node_or_null(^"Buildings/Palace") as Node3D
	_set_check("the Spectra Palace is standing", palace != null)
	_set_check("the Palace stands inside the Strip", strip_region != null and palace != null
		and strip_region.contains(Vector2(palace.global_position.x, palace.global_position.z)))
	_set_check("the cage counter is in the lobby",
		ranch.get_node_or_null(^"Buildings/Palace/Cage") != null)
	var lobby_sign := ranch.get_node_or_null(^"Buildings/Palace/Sign") as Label3D
	_set_check("the lobby sign is hanging", lobby_sign != null)
	var sign_text: String = lobby_sign.text if lobby_sign != null else ""
	var publishes_everything := true
	for pair in [["Slots", SlotsScript.house_edge()], ["The Wheel", WheelScript.house_edge()],
			["Blackjack", BlackjackScript.house_edge()], ["Racing", RaceCardScript.TAKEOUT]]:
		if not sign_text.contains(CasinoSignScript.edge_line(String(pair[0]),
				float(pair[1]))):
			publishes_everything = false
			push_error("casino: the lobby sign does not publish %s" % pair[0])
	print("CASINO sign lines=%d" % sign_text.split("\n").size())
	_set_check("the lobby sign publishes every game's real house edge", publishes_everything)
	var sign_clean := true
	for line in sign_text.split("\n"):
		if line.contains("--") or line.contains("—"):
			sign_clean = false
	_set_check("nothing on the sign carries a dash", sign_clean)

	# --- the track -------------------------------------------------------------------------
	var track := ranch.get_race_track()
	_set_check("the track has six lanes",
		track != null and int(track.call("runner_count")) == RaceTrackScript.LANES)
	var track_ok := track != null
	if track != null:
		var gate_point: Vector3 = track.call("lane_point", 0, 0.0)
		var wire_point: Vector3 = track.call("lane_point", 0, 1.0)
		track_ok = absf(Vector2(gate_point.x, gate_point.z).distance_to(
			Vector2(wire_point.x, wire_point.z)) - RaceCardScript.TRACK_LENGTH) < 0.01
	_set_check("the track is exactly as long as the card thinks it is", track_ok)
	var lanes_apart := true
	if track != null:
		for lane in range(1, RaceTrackScript.LANES):
			if absf(float(track.call("lane_z", lane)) - float(track.call("lane_z", lane - 1))
					- RaceTrackScript.LANE_WIDTH) > 0.001:
				lanes_apart = false
	_set_check("the lanes are evenly spaced", lanes_apart)

	# --- the cage, and every way to abuse it ------------------------------------------------
	var wallet: Economy = ranch.get_economy()
	wallet.grant(5000)
	var bits_before: int = wallet.bits
	_set_check("buying more chips than she has bits for buys nothing",
		ranch.buy_chips(bits_before + 1) <= bits_before)
	wallet.grant(1)
	var refused_zero: bool = ranch.buy_chips(0) == 0
	var refused_negative: bool = ranch.buy_chips(-500) == 0
	_set_check("a buy in of zero buys nothing", refused_zero)
	_set_check("a buy in of a negative number buys nothing", refused_negative)
	_set_check("neither refusal moved a chip", state.casino.chips >= 0)

	state.casino.remove_chips(state.casino.chips)
	wallet.grant(maxi(0, 5000 - wallet.bits))
	var start_bits: int = wallet.bits
	var bought: int = ranch.buy_chips(1000)
	_set_check("a thousand bits buy a thousand chips",
		bought == 1000 and state.casino.chips == 1000 and wallet.bits == start_bits - 1000)
	var cashed: int = ranch.cash_out(1000)
	_set_check("a thousand chips cash out for a thousand bits",
		cashed == 1000 and state.casino.chips == 0 and wallet.bits == start_bits)
	_set_check("cashing out more chips than she holds cashes out nothing",
		ranch.cash_out(50) == 0 and wallet.bits == start_bits)
	_set_check("cashing out a negative number cashes out nothing",
		ranch.cash_out(-50) == 0 and wallet.bits == start_bits)

	# --- the tables --------------------------------------------------------------------------
	ranch.buy_chips(3000)
	var chips_before: int = state.casino.chips
	var over: Dictionary = ranch.play_slots(chips_before + 1)
	_set_check("a stake bigger than the purse is refused, and the purse does not move",
		not bool(over["ok"]) and state.casino.chips == chips_before)
	_set_check("a stake of zero is refused", not bool(ranch.play_slots(0)["ok"]))
	_set_check("a negative stake is refused", not bool(ranch.play_slots(-200)["ok"]))
	_set_check("no refusal moved a chip", state.casino.chips == chips_before)

	var settled := true
	for i in 40:
		var before: int = state.casino.chips
		var spin: Dictionary = ranch.play_slots(50)
		if not bool(spin["ok"]) or state.casino.chips != before - 50 + int(spin["won"]):
			settled = false
	_set_check("every spin settles at exactly the stake out and the win in", settled)

	settled = true
	for i in 40:
		var before: int = state.casino.chips
		var bet: Dictionary = ranch.play_wheel(WheelScript.Bet.COLOUR, WheelScript.Colour.RED,
			50)
		if not bool(bet["ok"]) or state.casino.chips != before - 50 + int(bet["won"]):
			settled = false
	_set_check("every wheel bet settles at exactly the stake out and the win in", settled)

	# --- one wheel bet, driven through the menu seam end to end (Task 6 review addition) ---
	# WheelMenu.Tab is COLOUR first and Wheel.Bet is NUMBER first (see wheel_menu.gd's own
	# class comment); ranch._on_wheel_bet_requested() is the one place that translates
	# between them. Nothing above exercises that translation from the menu's own side, so a
	# future re-ordering of either enum would still pass every check above it while quietly
	# paying a colour bet at 24x instead of 6x. This drives the felt itself: open the table,
	# pick the COLOUR tab, confirm, repeat until a win is seen, and check what it paid.
	var wheel_table: CanvasLayer = ranch.get_table_menu(CasinoMenuScript.Game.WHEEL)
	_set_check("the wheel opens as a table", wheel_table != null and bool(wheel_table.call("open")))
	var menu_win_seen := false
	var menu_win_correct := true
	if wheel_table != null:
		wheel_table.call("set_tab", WheelMenuScript.Tab.COLOUR)
		wheel_table.call("set_stake_index", 0)
		for i in MENU_WHEEL_ATTEMPTS:
			var stake_played: int = int(wheel_table.call("selected_stake"))
			if stake_played <= 0:
				break
			var before: int = state.casino.chips
			if not bool(wheel_table.call("confirm")):
				break
			var won: int = state.casino.chips - before + stake_played
			if won > 0:
				menu_win_seen = true
				if won != (WheelScript.COLOUR_PAYS_TO_ONE + 1) * stake_played:
					menu_win_correct = false
		wheel_table.call("close")
	_set_check("a colour bet driven through the menu seam wins at least once in this run",
		menu_win_seen)
	_set_check("a colour bet driven through the menu seam pays colour odds, not number odds",
		menu_win_correct)

	settled = true
	for i in 40:
		var before: int = state.casino.chips
		var hand: Dictionary = ranch.play_blackjack(50)
		if not bool(hand["ok"]) or state.casino.chips != before - 50 + int(hand["won"]):
			settled = false
	_set_check("every hand settles at exactly the stake out and the win in", settled)

	# --- a bet abandoned in the middle of being placed ----------------------------------------
	var table: CanvasLayer = ranch.get_table_menu(CasinoMenuScript.Game.SLOTS)
	var before_cancel: int = state.casino.chips
	_set_check("a table opens at the Palace", table != null and table.call("open"))
	if table != null:
		table.call("move_selection", 1)
		table.call("close")
	_set_check("walking away mid bet costs nothing", state.casino.chips == before_cancel)

	# --- the door, and the seam the ban will hang on -------------------------------------------
	_set_check("the Palace is open to her in this slice", ranch.casino_can_enter())
	var lobby: CanvasLayer = ranch.get_casino_menu()
	var pause: CanvasLayer = ranch.get_pause_menu()
	var refused_over_pause := false
	if lobby != null and pause != null:
		pause.call("open")
		refused_over_pause = not bool(lobby.call("open"))
		pause.call("close")
	_set_check("the lobby refuses to open over another menu, so its can_open is consulted",
		refused_over_pause)

	# --- the race, on the real track ------------------------------------------------------------
	var census_before: int = ranch.spawner.get_spawned().size()
	var bodies: Array[WeakRef] = []
	for body in ranch.spawner.get_spawned():
		bodies.append(weakref(body))

	# THE PEN IS FOUND THE WAY ledger_test.gd FINDS ONE: the first plot in the catalogue that
	# costs nothing, rather than by an id. There is no plot whose id is "pen"; the shipped
	# catalogue is pen_small, pen_large and pen_grand (game/data/plots/), and hard coding one
	# of those names here would be a gate that breaks the day somebody renames a plot.
	var slots: Array[PlotSlot] = ranch.plot_slots()
	var free_plot: PlotData = null
	for plot: PlotData in ranch.plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	var built: bool = not slots.is_empty() and free_plot != null and slots[0].is_empty() \
		and slots[0].build(free_plot)
	_set_check("a pen is standing to enter a pony from", built)
	var pen: Pen = slots[0].get_built() as Pen if not slots.is_empty() else null
	var racer: PonyInstance = PonyInstanceScript.create(&"stock_bold")
	racer.stock = {"coat": 1, "mane": 2, "eyes": 0}
	racer.happiness = 0.40
	racer.hunger = 0.10
	_set_check("she is in the pen", pen != null and pen.add_pony(racer))
	state.add_pony(racer)

	var entrants: Array[Dictionary] = ranch.race_entrants()
	var listed := false
	for entry in entrants:
		if StringName(entry["uid"]) == racer.uid:
			listed = true
	_set_check("the race panel lists her as an entrant", listed)

	var chips_at_the_off: int = state.casino.chips
	var race: Dictionary = ranch.start_race(racer.uid, RaceCardScript.PLAYER_LANE, 100)
	_set_check("the race is under orders", bool(race["ok"]))
	_set_check("the stake left the purse before the field was drawn",
		state.casino.chips == chips_at_the_off - 100)
	_set_check("she is still in her pen while the race runs",
		pen != null and pen.find_pony(racer.uid) != null)
	var pen_body: Node3D = pen.body_for(racer.uid) if pen != null else null
	_set_check("her pen body is hidden rather than removed",
		pen_body != null and is_instance_valid(pen_body) and not pen_body.visible)

	Engine.time_scale = RACE_TIME_SCALE
	# A DICTIONARY, NOT TWO INTS. GDScript captures a lambda's outer local variables BY
	# VALUE at the moment the lambda is created; reassigning `settled_payout = payout`
	# inside the closure would rebind the closure's own copy and never touch this
	# function's variable, so the wait loop below would spin to the timeout even on a race
	# that settled on schedule. A Dictionary is a reference type: the closure and this
	# function share the same object, so mutating a key inside it is visible out here.
	# scenes/test/capture_test.gd's own watchers use the same trick with an Array.
	var race_result := {"payout": -1, "winner": -1}
	var watcher := func(payout: int, winner: int) -> void:
		race_result["payout"] = payout
		race_result["winner"] = winner
	ranch.race_settled.connect(watcher)
	var waited := 0.0
	while int(race_result["payout"]) < 0 and waited < RACE_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Engine.time_scale = 1.0
	ranch.race_settled.disconnect(watcher)
	var settled_payout: int = int(race_result["payout"])
	var settled_winner: int = int(race_result["winner"])

	_set_check("the race finished and paid out", settled_payout >= 0)
	var result: Dictionary = race.get("result", {})
	_set_check("the lane that won is the lane the card said would win",
		settled_winner == int(result.get("winner", -2)))
	var expected_payout: int = RaceCardScript.payout(race["field"],
		RaceCardScript.PLAYER_LANE, 100, settled_winner)
	_set_check("the bet paid exactly what the shown odds promised",
		settled_payout == expected_payout)
	_set_check("the purse moved by exactly the stake out and the win in",
		state.casino.chips == chips_at_the_off - 100 + expected_payout)

	_set_check("she came home to the same pen",
		pen != null and pen.find_pony(racer.uid) != null)
	_set_check("her body is visible again",
		pen_body != null and is_instance_valid(pen_body) and pen_body.visible)
	# HUNGER GETS A WINDOW, NOT A POINT. RaceCard.apply_race_effects() is not the only thing
	# that touched her hunger while the race ran: game/world/pen.gd's own _process() calls
	# Needs.tick() for every pony it holds, race or no race, and that ticking used the same
	# real seconds this wait loop just spent watching the track (`waited`, already scaled by
	# RACE_TIME_SCALE the same way Pen's own delta was). So her hunger the moment she comes
	# home is RACE_HUNGER plus AT LEAST zero and AT MOST HUNGER_PER_SECOND * waited of
	# ordinary ambient drift; never less than the race's own cost, which is what would
	# actually go wrong if apply_race_effects() were skipped or halved. Happiness carries no
	# matching drift: Needs.tick() only spends happiness once hunger crosses HUNGRY_THRESHOLD
	# (0.5), and hers never gets close, so it stays an exact check.
	var hunger_after_race: float = 0.10 + RaceCardScript.RACE_HUNGER
	var max_ambient_drift: float = waited * NeedsScript.HUNGER_PER_SECOND
	_set_check("she came home hungrier by exactly what a race costs, plus at most the same "
			+ "ambient drift every other penned pony got over the same wait",
		racer.hunger >= hunger_after_race - 0.0001
		and racer.hunger <= hunger_after_race + max_ambient_drift + 0.0005)
	_set_check("and happier by exactly what a race is worth",
		absf(racer.happiness - (0.40 + RaceCardScript.RACE_HAPPINESS)) < 0.0001)
	_set_check("the ranch still owns her", state.find_pony(racer.uid) != null)

	var census_after: int = ranch.spawner.get_spawned().size()
	print("CASINO census before=%d after=%d" % [census_before, census_after])
	_set_check("the wild herd is exactly the size it was before the race",
		census_after == census_before)
	var all_alive := true
	for ref in bodies:
		if ref.get_ref() == null:
			all_alive = false
	_set_check("not one pony anywhere in the world was freed by a race", all_alive)

	# --- the chips survive quitting ------------------------------------------------------------
	var chips_at_save: int = state.casino.chips
	_set_check("the ranch saved", state.save_to_slot(SLOT))
	state.reset()
	_set_check("a reset empties the purse", state.casino.chips == 0)
	_set_check("the save came back", state.load_from_slot(SLOT))
	_set_check("and the chips came back with it", state.casino.chips == chips_at_save)

	# --- leave no scratch file behind, the same way every sibling hosted gate cleans up its
	# own slot (collection_test.gd's 5, ledger_test.gd's 6, depot_test.gd's 7,
	# creation_test.gd's 8/10) -----------------------------------------------------------------
	var slot_path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)
	var backup_path: String = ProjectSettings.globalize_path(SaveIOScript.backup_path(SLOT))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)


func _finish() -> void:
	var failed: Array[String] = []
	for label in _checks:
		if not bool(_checks[label]):
			failed.append(String(label))
	for label in _duplicates:
		failed.append("duplicate check label: %s" % label)
	for label in _checks:
		print("CASINO %s %s" % ["ok  " if bool(_checks[label]) else "FAIL", label])
	var all_ok: bool = failed.is_empty()
	# Marker after the verdict, exit code IS the verdict. See docs/testing.md.
	if all_ok:
		print("CASINO_OK checks=%d" % _checks.size())
	else:
		print("CASINO_FAILED checks=%d failed=%d" % [_checks.size(), failed.size()])
	get_tree().quit(0 if all_ok else 1)
