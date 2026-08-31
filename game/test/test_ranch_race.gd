extends GutTest
## Regression test for game/world/ranch.gd's start_race(): what happens when
## RaceTrack.start() itself refuses the field it was handed.
##
## THE BUG THIS PINS. start_race() used to call race_track.dress(field) and
## race_track.start(field, result) as bare statements, reading neither return. By the point
## those two calls happen the stake has already left the purse and the entrant's pen body
## has already been hidden; and if start() ever answered false, nothing put either of
## those back: race_finished is the only place that unhides her, and a race that never
## started never fires it. The caller still got back {"ok": true, ...}.
##
## WHY A STUBBED TRACK, NOT A DOCTORED FIELD. RaceTrack.start() only refuses a field whose
## size does not match LANES, which in real play only happens if CompanyRunners fails to
## load: a condition this checkout cannot reliably force to order. A fake race_track
## whose start() always says no exercises the exact same code path (an authentic, LANES
## sized field; only the track's own answer is false) without depending on that.
##
## WHY A DETACHED RANCH, RATHER THAN world/ranch.tscn. See test_ranch_collection.gd's class
## comment for the reasoning this file borrows: a full ranch scene boots terrain, a
## spawner and a physics warmup this bug has nothing to do with. Ranch.new() never enters a
## tree, so _ready() never runs and every @onready var stays null except the ones this file
## sets by hand.
##
## WHY THE PEN BODY IS A BARE Node3D, NOT A REAL PONY. Pen._spawn_body() only ever builds a
## body when the pen is inside a tree (guarded by is_inside_tree()), which a detached Pen
## never is, confirmed by game/test/test_pen.gd's own "most of this runs out of tree"
## reasoning. What this test needs is only whether start_race() shows an existing body
## again, not whether one gets built, so a stand-in is registered directly into the pen's
## own `_bodies` dictionary the way this project already reaches into a collaborator's
## underscored internals from its own tests.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const PenScript := preload("res://world/pen.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")

const STARTING_CHIPS := 500
const STAKE := 50


## A track that refuses every race it is handed, whatever field it is given. Node3D, the
## same type race_track is declared as on Ranch; every call ranch.gd makes on it is
## duck-typed through Object.call(), never through the real RaceTrack script.
class FakeTrackThatRefuses:
	extends Node3D

	func is_running() -> bool:
		return false

	func dress(_field: Array) -> int:
		return 0

	func start(_field: Array, _result: Dictionary) -> bool:
		return false


## The control case's track: agrees to start every race. Never actually runs a clock or
## fires race_finished; this file is not testing the wire back, only that start_race()'s
## unwind is conditioned on start()'s answer rather than unconditional.
class FakeTrackThatAccepts:
	extends Node3D

	func is_running() -> bool:
		return false

	func dress(_field: Array) -> int:
		return 6

	func start(_field: Array, _result: Dictionary) -> bool:
		return true


## A detached Ranch with one pony standing in one pen, and `track` standing in for
## race_track. Everything start_race() touches before it ever reaches race_track is real: a
## real GameState, a real Casino purse, a real Pen holding a real PonyInstance found through
## the same _plot_slots()/_penned() walk a hosted ranch uses.
func _ranch_with_pony(track: Node3D) -> Dictionary:
	var ranch: RanchScript = autofree(RanchScript.new())
	ranch._game_state = autofree(GameStateScript.new())
	ranch._game_state.casino.add_chips(STARTING_CHIPS)
	ranch.race_track = autofree(track)

	var pen: Pen = autofree(PenScript.new())
	pen.slot_id = &"slot_1"
	var inst: PonyInstance = PonyInstanceScript.create(&"stock_bold")
	assert_true(pen.add_pony(inst), "precondition: she must actually be in the pen")

	var body: Node3D = autofree(Node3D.new())
	pen._bodies[inst.uid] = body

	var slot: PlotSlot = autofree(PlotSlotScript.new())
	slot._built_node = pen

	var plots_root: Node3D = autofree(Node3D.new())
	plots_root.add_child(slot)
	ranch.plots_root = plots_root

	return {"ranch": ranch, "pen": pen, "inst": inst, "body": body}


func test_a_track_that_refuses_to_start_refunds_the_stake_and_shows_her_again() -> void:
	var built := _ranch_with_pony(FakeTrackThatRefuses.new())
	var ranch: RanchScript = built["ranch"]
	var pen: Pen = built["pen"]
	var inst: PonyInstance = built["inst"]
	var body: Node3D = built["body"]

	assert_true(body.visible, "sanity: she is standing in plain sight before any of this")

	var result: Dictionary = ranch.start_race(inst.uid, 0, STAKE)
	assert_push_error(1,
		"a race that race_track itself refused to start must still be reported")

	assert_false(result["ok"], "a race that race_track refused must not be reported as ok")
	assert_eq(ranch._game_state.casino.chips, STARTING_CHIPS,
		"the stake must come back when the race never actually started")
	assert_true(body.visible,
		"her body must be shown again; race_finished is the only other unhide site, and " +
		"a race that never started never fires it")
	assert_true(pen.find_pony(inst.uid) != null,
		"she must still be exactly where she always was: living in her own pen")
	assert_eq(ranch._race_entrant, &"",
		"no bet bookkeeping may be left behind by a race that the track refused")


func test_a_track_that_does_start_leaves_the_stake_spent_and_the_body_hidden() -> void:
	# THE CONTROL CASE: with a track that actually agrees to run, the same call must still
	# spend the stake and hide the body, proving the guard above is conditioned on
	# start()'s own answer, not an unconditional refund that would silently break every
	# ordinary race too.
	var built := _ranch_with_pony(FakeTrackThatAccepts.new())
	var ranch: RanchScript = built["ranch"]
	var inst: PonyInstance = built["inst"]
	var body: Node3D = built["body"]

	var result: Dictionary = ranch.start_race(inst.uid, 0, STAKE)
	assert_push_error(0, "a race the track actually agreed to run must not be reported")

	assert_true(result["ok"], "a track that agrees to start must report the race as ok")
	assert_eq(ranch._game_state.casino.chips, STARTING_CHIPS - STAKE,
		"an ordinary, accepted race must still spend the stake")
	assert_false(body.visible,
		"an ordinary, accepted race must still hide her body for the length of the race")
	assert_eq(ranch._race_entrant, inst.uid,
		"an ordinary, accepted race must still record whose bet is on the track")
