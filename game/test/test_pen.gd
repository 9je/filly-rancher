extends GutTest
## Tests for the pen (game/world/pen.gd) -- Phase 1B Task 3. A pen is the first place in
## this game where a captured pony STOPS BEING INVENTORY and starts being livestock: she
## lives there, she is fed there, she produces gems there, and she is still there when you
## quit and come back.
##
## THE ROSTER IS THE PEN, THE BODIES ARE A CONSEQUENCE. Every rule below is asserted
## against the PonyInstance roster, not against how many CharacterBody3Ds are standing in
## the paddock, because the roster is what is saved and the bodies are rebuilt from it. A
## pen that kept the right number of bodies and the wrong roster would look perfect and
## save wrong, which is the failure this ordering is chosen to catch.
##
## WHY MOST OF THIS RUNS OUT OF TREE. Pen.add_pony()/remove_pony() are pure roster
## operations and are deliberately usable on a `Pen.new()` that has never entered a scene:
## it makes the container's rules testable in milliseconds, with no models, no physics
## frame and no terrain -- which also means they still run on a CI checkout that has no
## converted .glb assets at all (docs/ci.md section 4). The two tests that DO need a tree
## say so and are about body spawning specifically.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const PenScript := preload("res://world/pen.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PlotDataScript := preload("res://systems/plot_data.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const ProductionScript := preload("res://systems/production.gd")
const NeedsScript := preload("res://systems/needs.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const StorageScript := preload("res://systems/storage.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const LayersScript := preload("res://world/collision_layers.gd")

## A scratch save slot for the round-trip test. NOT slot 0 (the one the game plays in) and
## NOT slot 9 (game/world/ranch.gd's gate probe) -- a test that stamped on either would
## delete a real ranch or make the gate flaky.
const SCRATCH_SLOT := 8

## The pony's full height, horn tip included, from docs/pipeline.md section 3. NOT her
## 1.163 m withers height -- see test_the_fence_clears_a_ponys_horn_tip_not_her_withers.
const PONY_FULL_HEIGHT := 2.138



## The pen's own rules, without the traits' (game/test/test_pony_traits.gd has those).
func before_all() -> void:
	PonyTraits.quirks_enabled = false


func after_all() -> void:
	PonyTraits.quirks_enabled = true

func after_each() -> void:
	# Production keeps a process-wide fractional-gem ledger keyed by uid. Left alone, one
	# test's leftover progress would decide another test's first gem.
	ProductionScript.clear_all_progress()


func _pen(capacity: int = 3, id: String = "slot_pen") -> Pen:
	var pen: Pen = PenScript.new()
	pen.capacity = capacity
	pen.slot_id = StringName(id)
	return autofree(pen)


func _instance(character: String) -> PonyInstance:
	return PonyInstanceScript.create(StringName(character))


# --- capacity ---------------------------------------------------------------------------

func test_a_new_pen_is_empty() -> void:
	var pen := _pen(3)
	assert_eq(pen.count(), 0, "a freshly built pen holds nobody")
	assert_false(pen.is_full(), "...and is not full")
	assert_eq(pen.ponies().size(), 0, "...and its roster is empty")


func test_a_pen_accepts_up_to_capacity_then_refuses() -> void:
	var pen := _pen(3)
	for i in range(3):
		assert_true(pen.add_pony(_instance("twilight")), "pony %d must fit" % i)
		assert_eq(pen.count(), i + 1, "the count follows the additions")
	assert_true(pen.is_full(), "three of three is full")

	var refused := _instance("twilight")
	assert_false(pen.add_pony(refused), "a full pen refuses")
	assert_eq(pen.count(), 3, "...and does not grow")
	assert_false(pen.has_pony(refused.uid), "...and the refused pony is not secretly in it")


func test_a_refused_pony_is_not_marked_as_living_here() -> void:
	# THE NO-PONY-EVER-DIES RULE'S BOOKKEEPING HALF. `home_slot` is what a save uses to
	# put her back where she lives. Stamping it on a pony the pen then refused would give
	# her an address she is not at: on the next load the ranch would look for her in a pen
	# that has no record of her, and she would be in neither the pen nor the saddlebag.
	var pen := _pen(1)
	pen.add_pony(_instance("twilight"))
	var refused := _instance("fluttershy")
	assert_false(pen.add_pony(refused), "precondition: the pen is full")
	assert_eq(String(refused.home_slot), "", "a refused pony keeps no address here")


func test_a_pen_refuses_null() -> void:
	var pen := _pen(3)
	assert_false(pen.add_pony(null), "null is not a pony")
	assert_eq(pen.count(), 0, "...and nothing was added")


func test_a_pen_refuses_a_pony_it_already_holds() -> void:
	# Double-click on "move her in", or a save restored twice. Adding her again would
	# consume a second slot and put two bodies of the same individual in the paddock.
	var pen := _pen(3)
	var her := _instance("twilight")
	assert_true(pen.add_pony(her), "precondition")
	assert_false(pen.add_pony(her), "the same individual cannot move in twice")
	assert_eq(pen.count(), 1, "...and she does not occupy two places")


# --- identity ---------------------------------------------------------------------------

func test_remove_by_uid_returns_that_individual_and_only_her() -> void:
	var pen := _pen(3)
	var a := _instance("twilight")
	var b := _instance("twilight")
	var c := _instance("twilight")
	pen.add_pony(a)
	pen.add_pony(b)
	pen.add_pony(c)

	var out: PonyInstance = pen.remove_pony(b.uid)
	assert_eq(out, b, "remove_pony returns the individual whose uid was asked for")
	assert_eq(pen.count(), 2, "...and exactly one pony left")
	assert_false(pen.has_pony(b.uid), "...she is gone")
	assert_true(pen.has_pony(a.uid), "...and the others stayed")
	assert_true(pen.has_pony(c.uid), "...both of them")


func test_removing_a_uid_that_is_not_here_returns_null_and_changes_nothing() -> void:
	var pen := _pen(3)
	pen.add_pony(_instance("twilight"))
	assert_null(pen.remove_pony(&"nobody#000999"), "an unknown uid is not somebody else")
	assert_eq(pen.count(), 1, "...and nobody was evicted for it")


func test_a_removed_pony_no_longer_lives_here() -> void:
	var pen := _pen(3)
	var her := _instance("twilight")
	pen.add_pony(her)
	assert_eq(her.home_slot, &"slot_pen", "precondition: she lives in this pen")
	pen.remove_pony(her.uid)
	assert_eq(String(her.home_slot), "",
		"a pony taken out of a pen has no address until something gives her one")


func test_a_pen_of_three_twilights_keeps_them_distinct() -> void:
	# The exact arrangement PonyInstance exists to make expressible: three of ONE
	# character, each with her own state. Before Task 1 the bag held three pointers to the
	# same PonyData and "feed the hungry one" was not a sentence you could write.
	var pen := _pen(3)
	var a := _instance("twilight")
	var b := _instance("twilight")
	var c := _instance("twilight")
	pen.add_pony(a)
	pen.add_pony(b)
	pen.add_pony(c)

	b.happiness = 0.9
	c.hunger = 0.8

	var uids := {}
	for inst in pen.ponies():
		uids[inst.uid] = true
	assert_eq(uids.size(), 3, "three individuals, three uids")

	assert_eq(pen.find_pony(a.uid).happiness, PonyInstanceScript.HAPPINESS_DEFAULT,
		"the first one's happiness was not touched")
	assert_eq(pen.find_pony(b.uid).happiness, 0.9, "the second one's own happiness stuck")
	assert_eq(pen.find_pony(c.uid).hunger, 0.8, "the third one's own hunger stuck")


func test_a_pen_of_mixed_characters_keeps_them_distinct() -> void:
	var pen := _pen(3)
	var t := _instance("twilight")
	var f := _instance("fluttershy")
	var r := _instance("rainbowdash")
	pen.add_pony(t)
	pen.add_pony(f)
	pen.add_pony(r)

	assert_eq(pen.find_pony(t.uid).data_id, &"twilight", "Twilight is still Twilight")
	assert_eq(pen.find_pony(f.uid).data_id, &"fluttershy", "Fluttershy is still Fluttershy")
	assert_eq(pen.find_pony(r.uid).data_id, &"rainbowdash", "Rainbow Dash is still herself")

	# ...and the roster comes back in the order they moved in, so a future pen UI does not
	# reshuffle itself every time somebody is fed.
	var order: Array[StringName] = []
	for inst in pen.ponies():
		order.append(inst.data_id)
	assert_eq(order, [&"twilight", &"fluttershy", &"rainbowdash"] as Array[StringName],
		"the roster is in move-in order")


func test_ponies_hands_out_a_copy_not_the_live_roster() -> void:
	# A pen UI that cleared the array it was handed would empty the pen, silently, with no
	# signal fired and no save-time hint that anything had gone.
	var pen := _pen(3)
	pen.add_pony(_instance("twilight"))
	var listing := pen.ponies()
	listing.clear()
	assert_eq(pen.count(), 1, "clearing the returned array does not empty the pen")


# --- needs and production ----------------------------------------------------------------

func test_a_pen_advances_its_residents_hunger() -> void:
	# The pen is what drives Needs.tick() for the ponies it holds -- nothing else does, so
	# a pony in a pen that did not tick would never get hungry and never need feeding.
	var pen := _pen(2)
	var her := _instance("twilight")
	pen.add_pony(her)
	var before := her.hunger
	pen.tick(60.0)
	assert_gt(her.hunger, before, "an hour of pen time makes a pony hungrier")
	assert_almost_eq(her.hunger, before + 60.0 * NeedsScript.HUNGER_PER_SECOND, 0.0001,
		"...by exactly the rate needs.gd documents")


func test_a_pen_does_not_tick_a_pony_who_has_moved_out() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")
	pen.add_pony(her)
	pen.remove_pony(her.uid)
	var before := her.hunger
	pen.tick(120.0)
	assert_eq(her.hunger, before, "a pony who left is no longer the pen's business")


func test_a_pen_banks_the_gems_its_residents_produce() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")
	her.happiness = 1.0
	her.hunger = 0.0
	pen.add_pony(her)

	var produced: int = pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS)
	assert_eq(produced, 1, "a perfectly happy pony yields one gem per production period")
	assert_eq(pen.gems(), 1, "...and the pen is holding it")

	assert_eq(pen.take_gems(), 1, "taking the gems hands them over")
	assert_eq(pen.gems(), 0, "...and empties the pen's tray")


func test_an_empty_pen_produces_nothing() -> void:
	var pen := _pen(2)
	assert_eq(pen.tick(3600.0), 0, "an hour in an empty pen yields no gems")


func test_a_pen_forgets_a_departed_ponys_production_progress() -> void:
	# Production's fractional-gem ledger is a process-wide static Dictionary keyed by uid.
	# Without a forget() on the way out it grows once per pony ever penned, for the life of
	# the process -- and a pony re-penned later would silently resume a part-finished gem
	# from a previous tenancy.
	var pen := _pen(2)
	var her := _instance("twilight")
	her.happiness = 1.0
	pen.add_pony(her)
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 0.5)
	assert_gt(ProductionScript.progress_of(her.uid), 0.0, "precondition: half a gem banked")

	pen.remove_pony(her.uid)
	assert_eq(ProductionScript.progress_of(her.uid), 0.0,
		"leaving the pen clears her entry from the production ledger")


# --- geometry ---------------------------------------------------------------------------

func test_the_fence_clears_a_ponys_horn_tip_not_her_withers() -> void:
	# THE MEASUREMENT THAT MATTERS. A pony is 1.163 m at the withers and 2.138 m to the top
	# of her horn (docs/pipeline.md section 3). Sizing a fence off "how tall is a pony" and
	# reaching for the withers figure produces a paddock she can put her whole head over.
	# game/world/building.gd's MIN_DOOR_CLEARANCE makes the same argument for doorways.
	assert_gte(PenScript.FENCE_HEIGHT, PONY_FULL_HEIGHT,
		"the fence must top out above a pony's horn tip, not her withers")
	assert_gte(PenScript.GATE_CLEARANCE, PONY_FULL_HEIGHT,
		"the gateway must let a 2.138 m pony walk through it")


func test_the_leash_stops_short_of_the_fence_by_more_than_the_flee_overshoot() -> void:
	# roam_radius IS SOFT. A fleeing pony's momentum carries her ~1.15 m past it
	# (ZoneMarker.ROAM_OVERSHOOT, measured in Phase 1A), so a leash set exactly at the
	# fence line means a spooked pony clips straight through her own paddock. The leash
	# has to stop short by the overshoot PLUS her own body radius, or the fence is
	# decorative.
	#
	# MEASURED FROM THE PEN'S CENTRE, which is where every resident's leash is anchored --
	# see _spawn_body(). If it were anchored to her standing spot instead, her spot's own
	# offset would have to be in this sum too, and it does not fit.
	var half: float = PenScript.HALF_EXTENT
	var roam: float = PenScript.roam_radius_for(half)
	assert_gt(roam, 0.5, "the leash must leave a pony somewhere to actually walk")
	assert_lte(roam + ZoneMarkerScript.ROAM_OVERSHOOT + PenScript.PONY_BODY_RADIUS, half,
		"leash + flee overshoot + body radius must still land inside the fence line")


func test_every_resident_stands_inside_her_own_leash_and_clear_of_her_neighbours() -> void:
	# Two separate failures, one loop. A standing spot outside the leash radius means she
	# starts the game being dragged home; two spots closer together than two bodies means
	# the pen spawns its residents interpenetrating and they shove each other apart on the
	# first physics frame, which is exactly the "spawn interpenetrating" note
	# game/actors/player/magic_beam.gd already carries.
	var largest: int = PenScript.MAX_RESIDENT_SPOTS
	var roam: float = PenScript.roam_radius_for(PenScript.HALF_EXTENT)
	var spots: Array[Vector3] = []
	for i in range(largest):
		var spot: Vector3 = PenScript.resident_spot(i)
		assert_lte(Vector2(spot.x, spot.z).length(), roam,
			"resident %d starts inside her own leash radius" % i)
		spots.append(spot)

	for i in range(spots.size()):
		for j in range(i + 1, spots.size()):
			assert_gte(spots[i].distance_to(spots[j]), PenScript.PONY_BODY_RADIUS * 2.0,
				"residents %d and %d must not start inside each other" % [i, j])


func test_the_biggest_pen_in_the_catalogue_has_a_standing_spot_for_everyone() -> void:
	# The spot spiral is a fixed pattern with a bounded radius, so it can run out. A pen
	# authored with a capacity past the end of it would put two residents on the same
	# square metre -- a .tres edit breaking geometry, with no code change to notice it.
	var registry := PlotRegistryScript.new()
	registry.load_all("res://data/plots")
	for plot in registry.all():
		assert_lte(plot.capacity, PenScript.MAX_RESIDENT_SPOTS,
			"plot '%s' holds %d ponies but the pen only has %d standing spots"
				% [String(plot.id), plot.capacity, PenScript.MAX_RESIDENT_SPOTS])


# --- the body a resident gets --------------------------------------------------------------

func test_a_resident_gets_a_body_leashed_to_the_pen() -> void:
	# IN TREE. A pen outside the tree keeps a roster and nothing else; the body is what
	# appears when the pen is actually standing on the map.
	var pen: Pen = PenScript.new()
	pen.capacity = 2
	pen.slot_id = &"slot_body"
	add_child_autofree(pen)
	var her := _instance("twilight")
	assert_true(pen.add_pony(her), "precondition")

	var body: Node3D = pen.body_for(her.uid)
	assert_not_null(body, "a resident of a pen that is on the map has a body")
	assert_eq(body.get_instance().uid, her.uid, "...and it is HER body, carrying her state")
	assert_almost_eq(body.roam_radius, PenScript.roam_radius_for(PenScript.HALF_EXTENT),
		0.0001, "...leashed to the pen, not to a wild pony's 8 m territory")
	# ANCHORED TO THE MIDDLE OF THE PEN, not to the spot she was set down on. A pony leashed
	# to her own standing spot can reach spot + leash + flee overshoot + her own body from
	# the centre -- 5.42 m out of a pen whose fence is at 3.90 -- and the only thing stopping
	# her walking out is the fence catching her, which pen.gd promises never has to happen.
	# The ranch gate's containment probe found this live; this is the unit-sized version.
	assert_almost_eq(body.get_home().distance_to(pen.global_position), 0.0, 0.01,
		"her roaming anchor is the pen's centre, wherever she happens to be standing")
	assert_eq(body.collision_layer, LayersScript.PONY,
		"...on the same layer the spawner puts a wild pony on")


func test_a_penned_stock_pony_keeps_her_colours() -> void:
	# IN TREE, like test_a_resident_gets_a_body_leashed_to_the_pen just above: _spawn_body()
	# does nothing outside the tree (pen.gd), so _pen()'s out-of-tree pen never grows a body
	# to check the colours on.
	var pen: Pen = PenScript.new()
	pen.capacity = 3
	pen.slot_id = &"slot_stock"
	add_child_autofree(pen)
	var inst := PonyInstanceScript.create(&"stock_curious")
	inst.stock = {"coat": 4, "mane": 1, "eyes": 0}
	assert_true(pen.add_pony(inst))
	var body: Node3D = pen.body_for(inst.uid)
	assert_not_null(body, "a resident has a body standing in the pen")
	assert_eq(body.get_stock(), {"coat": 4, "mane": 1, "eyes": 0},
		"the body wears what her record says")


func test_a_removed_resident_loses_her_body() -> void:
	var pen: Pen = PenScript.new()
	pen.capacity = 2
	pen.slot_id = &"slot_body2"
	add_child_autofree(pen)
	var her := _instance("twilight")
	pen.add_pony(her)
	assert_not_null(pen.body_for(her.uid), "precondition: she has a body")
	pen.remove_pony(her.uid)
	assert_null(pen.body_for(her.uid), "a pony who moved out is not still standing there")


# --- being caught is how a pony moves out ---------------------------------------------------
#
# THE SECOND PLAYTEST'S BUG, AND EVERY ASSERTION IT WOULD HAVE NEEDED. The owner beamed
# ponies out of a pen and then could not put them back: "after i removed them they wouldnt
# go back in", with a screenshot of ranch.gd's "She would not go in." toast. The cause was
# that nothing evicted her. MagicBeam stored her record and freed her body; the pen kept her
# on its roster with her home_slot still stamped, so the slot was spent forever, has_pony()
# stayed true, and add_pony() refused her for the rest of the session.
#
# WHY THESE TESTS DRIVE `Pony.notify_captured()` RATHER THAN A REAL BEAM. That method IS the
# beam's side of the contract -- magic_beam.gd's _settle_pony() stores her record, calls it,
# and frees the body, in that order -- and it is the only part of a capture the pen is
# entitled to know about. Driving a real beam would need a camera, a physics space and a
# couple of hundred frames of aiming (that is what scenes/test/capture_test.tscn is for) and
# would pin the beam's aiming rather than the pen's bookkeeping.


func _penned(id: String, capacity := 2) -> Pen:
	# IN TREE, unlike _pen(): the eviction rides on a resident BODY's own captured() signal,
	# so it only exists where a body does.
	var pen: Pen = PenScript.new()
	pen.capacity = capacity
	pen.slot_id = StringName(id)
	add_child_autofree(pen)
	return pen


func _resident_body(pen: Pen, inst: PonyInstance) -> Node3D:
	var body: Node3D = pen.body_for(inst.uid)
	assert_not_null(body, "precondition: a resident of a pen on the map has a body")
	return body


## Do to the pen exactly what MagicBeam._settle_pony() does when a hold becomes a capture:
## her record goes into the bag FIRST, then she reports the capture, then her body is freed.
func _beam_her_out(pen: Pen, inst: PonyInstance, bag: Storage) -> void:
	var body: Node3D = _resident_body(pen, inst)
	assert_true(bag.store(inst), "precondition: the saddlebag has room for her")
	body.notify_captured()
	body.queue_free()


func test_a_resident_caught_by_the_beam_stops_living_here() -> void:
	var pen := _penned("slot_caught", 3)
	var her := _instance("twilight")
	assert_true(pen.add_pony(her), "precondition: she moved in")

	_beam_her_out(pen, her, StorageScript.new(4))

	assert_eq(pen.count(), 0, "catching her takes her off the roster")
	assert_false(pen.has_pony(her.uid), "...there is no ghost of her left in the pen")
	assert_null(pen.find_pony(her.uid), "...by any of the roster's own questions")
	assert_eq(pen.ponies().size(), 0, "...including the copy a pen UI would be handed")
	assert_null(pen.body_for(her.uid), "...and she is not still standing in the paddock")
	assert_eq(String(her.home_slot), "",
		"...and her address is cleared, so a save files her in the saddlebag")


func test_a_caught_resident_can_be_penned_again_and_again() -> void:
	# THE OWNER'S BUG, END TO END. Twice round the loop rather than once: a fix that cleared
	# the roster but left something else behind -- a spent slot, a stale body, a production
	# ledger entry -- can still pass a single lap.
	var pen := _penned("slot_loop")
	var her := _instance("twilight")
	var bag := StorageScript.new(4)

	for lap in range(2):
		assert_true(pen.add_pony(her), "lap %d: she moves in" % lap)
		assert_eq(pen.count(), 1, "lap %d: ...and the pen holds exactly her" % lap)
		assert_eq(her.home_slot, &"slot_loop", "lap %d: ...at this address" % lap)
		assert_not_null(pen.body_for(her.uid), "lap %d: ...with a body in the paddock" % lap)

		_beam_her_out(pen, her, bag)
		assert_eq(pen.count(), 0, "lap %d: catching her empties the pen" % lap)
		assert_eq(bag.count(), 1, "lap %d: ...and she is in the saddlebag" % lap)
		assert_eq(bag.release(), her, "lap %d: ...and out of it she comes again" % lap)


func test_catching_a_resident_gives_her_slot_back_to_the_pen() -> void:
	# THE OCCUPANCY HALF. The leak's most visible symptom was a pen that stayed full after
	# you had emptied it -- a one-pony pen you could never use again.
	var pen := _penned("slot_full", 1)
	var her := _instance("twilight")
	assert_true(pen.add_pony(her), "precondition")
	assert_true(pen.is_full(), "precondition: one of one is full")

	_beam_her_out(pen, her, StorageScript.new(4))

	assert_false(pen.is_full(), "the slot she was using is free again")
	assert_eq(pen.count(), 0, "...and the occupancy count is back where it started")
	var somebody_else := _instance("fluttershy")
	assert_true(pen.add_pony(somebody_else), "...so somebody else can have it")
	assert_eq(pen.count(), 1, "...and exactly one pony lives here")


func test_catching_a_resident_forgets_her_banked_gem_progress() -> void:
	# Production's fractional-gem ledger is a process-wide static keyed by uid -- see
	# test_a_pen_forgets_a_departed_ponys_production_progress. EVERY route out of the pen has
	# to clear it, not only the one that calls remove_pony() by name, or the ledger leaks one
	# entry per pony ever caught and a re-penned pony resumes a stranger's part-finished gem.
	var pen := _penned("slot_ledger")
	var her := _instance("twilight")
	her.happiness = 1.0
	pen.add_pony(her)
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 0.5)
	assert_gt(ProductionScript.progress_of(her.uid), 0.0, "precondition: half a gem banked")

	_beam_her_out(pen, her, StorageScript.new(4))

	assert_eq(ProductionScript.progress_of(her.uid), 0.0,
		"being caught clears her ledger entry, exactly as walking out does")


func test_a_pen_stops_ticking_a_resident_the_beam_took() -> void:
	# The roster is what tick() walks, so a ghost would go on getting hungry and go on
	# producing gems into this pen's tray while sitting in the player's saddlebag.
	var pen := _penned("slot_tick")
	var her := _instance("twilight")
	her.happiness = 1.0
	pen.add_pony(her)

	_beam_her_out(pen, her, StorageScript.new(4))

	var hunger_before: float = her.hunger
	assert_eq(pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 4.0), 0,
		"a pony who has been caught produces nothing for the pen she left")
	assert_almost_eq(her.hunger, hunger_before, 0.0001,
		"...and does not get hungry on its clock either")


func test_a_caught_resident_survives_a_save_and_load_as_a_pony_in_the_saddlebag() -> void:
	# HER ADDRESS HAS TO BE COHERENT ACROSS THE WRITE, not merely in memory. Her record is
	# the only place that address lives, and it is the SAME object that is now in the bag --
	# so an eviction that had not cleared home_slot would have the next load post a pony who
	# is in the saddlebag into a pen with no record of her.
	var pen := _penned("slot_rt")
	var her := _instance("twilight")
	her.happiness = 0.8
	pen.add_pony(her)
	var bag := StorageScript.new(4)
	_beam_her_out(pen, her, bag)

	var writer: Node = autofree(GameStateScript.new())
	writer.plots = {"slot_rt": "pen_small"}
	for inst in bag.contents():
		writer.add_pony(inst)
	assert_true(writer.save_to_slot(SCRATCH_SLOT), "the save must land")

	var reader: Node = autofree(GameStateScript.new())
	assert_true(reader.load_from_slot(SCRATCH_SLOT), "...and load back")
	var loaded: Array[PonyInstance] = reader.get_ponies()
	assert_eq(loaded.size(), 1, "one pony came back")
	assert_eq(loaded[0].uid, her.uid, "...and she is the same individual")
	assert_eq(String(loaded[0].home_slot), "",
		"...with no address, which is how ranch.gd knows to put her in the saddlebag")
	assert_almost_eq(loaded[0].happiness, 0.8, 0.0001, "...in the state she was caught in")

	# And the pen she was caught out of takes her back. That is the loop closing.
	var rebuilt := _pen(2, "slot_rt")
	assert_true(rebuilt.add_pony(loaded[0]), "she can move back into her old pen")
	assert_eq(rebuilt.find_pony(her.uid).home_slot, &"slot_rt", "...at its address")

	SaveIOScript.delete_slot(SCRATCH_SLOT)


func test_a_resident_who_wriggles_out_of_the_beam_is_put_back_on_her_spot() -> void:
	# THE OTHER HALF OF THE PLAYTEST NOTE -- "you can also catch things in there and have
	# them wiggle out in there maiknng it unclear". A hold that does not end in a capture
	# must change NOTHING: she is still a resident, and her body is back on her standing spot
	# rather than left wherever the beam had floated her to -- which is in front of the
	# player, and so usually outside her own fence, on the wrong side of a solid barrier and
	# leashed to the middle of a pen she can no longer walk back into.
	var pen := _penned("slot_wriggle")
	var her := _instance("twilight")
	pen.add_pony(her)
	var body: Node3D = _resident_body(pen, her)
	var spot: Vector3 = PenScript.resident_spot(0)

	body.set_held(true)
	await wait_physics_frames(2)
	# Where a beam leaves her: floating well outside the fence, in front of the player.
	body.position = Vector3(PenScript.HALF_EXTENT + 3.0, 1.6, 0.0)
	body.break_free()
	await wait_physics_frames(2)

	assert_true(pen.has_pony(her.uid), "wriggling free does not move her out")
	assert_eq(her.home_slot, &"slot_wriggle", "...and does not change her address")
	assert_eq(pen.count(), 1, "...nor the pen's occupancy")
	assert_almost_eq(Vector2(body.position.x, body.position.z).distance_to(
		Vector2(spot.x, spot.z)), 0.0, 0.35,
		"...and she is standing back on her own spot, inside her own fence")


func test_a_resident_who_merely_wandered_is_left_where_she_wandered_to() -> void:
	# THE GUARD ON THE TEST ABOVE. Putting a released pony back is deliberately NOT a
	# containment net: a pen that teleported any stray resident home would make
	# game/world/ranch.gd's boot-time containment probe green by lying to it, and that probe
	# is what caught the leash-anchor bug this file's body tests now pin. Only a body this
	# pen actually watched go INTO a beam is ever moved.
	var pen := _penned("slot_wander")
	var her := _instance("twilight")
	pen.add_pony(her)
	var body: Node3D = _resident_body(pen, her)

	body.position = Vector3(PenScript.HALF_EXTENT + 3.0, 0.05, 0.0)
	await wait_physics_frames(2)

	assert_gt(Vector2(body.position.x, body.position.z).length(), PenScript.HALF_EXTENT,
		"a resident who was never in a beam is left exactly where she got to")


# --- persistence ------------------------------------------------------------------------

func test_pen_contents_survive_a_save_and_load_round_trip() -> void:
	# THE WHOLE POINT OF A PEN. A pony you put in one has to still be in it after you quit
	# -- otherwise a pen is a display case and the ranch resets every session.
	#
	# TWO SEPARATE GameStates AND ONE FILE, exactly as ranch.gd's own gate probe does it:
	# reading back into the object that wrote it would pass even if the file on disk were
	# empty, because the values would still be sitting in memory.
	var writer: Node = autofree(GameStateScript.new())
	var pen := _pen(3, "slot_2")
	var a := _instance("twilight")
	var b := _instance("fluttershy")
	a.happiness = 0.75
	b.hunger = 0.4
	pen.add_pony(a)
	pen.add_pony(b)

	writer.plots = {"slot_2": "pen_small"}
	for inst in pen.ponies():
		writer.add_pony(inst)
	assert_true(writer.save_to_slot(SCRATCH_SLOT), "the save must land")

	var reader: Node = autofree(GameStateScript.new())
	assert_true(reader.load_from_slot(SCRATCH_SLOT), "...and load back")
	assert_eq(str(reader.plots.get("slot_2", "")), "pen_small",
		"the pen is still built on slot_2")

	var rebuilt := _pen(3, "slot_2")
	var restored := 0
	for inst in reader.get_ponies():
		if inst.home_slot == &"slot_2":
			assert_true(rebuilt.add_pony(inst), "she moves back into her own pen")
			restored += 1
	assert_eq(restored, 2, "both residents came back with their address intact")
	assert_eq(rebuilt.count(), 2, "...and the rebuilt pen holds them")

	assert_almost_eq(rebuilt.find_pony(a.uid).happiness, 0.75, 0.0001,
		"...at the happiness she went to bed at")
	assert_almost_eq(rebuilt.find_pony(b.uid).hunger, 0.4, 0.0001,
		"...and the hunger she went to bed at")
	assert_eq(rebuilt.find_pony(b.uid).data_id, &"fluttershy",
		"...and she is still the character she was")

	SaveIOScript.delete_slot(SCRATCH_SLOT)


func test_a_ponys_address_round_trips_through_her_own_record() -> void:
	# home_slot rides in PonyInstance.to_dict() rather than in a second parallel list in
	# the save file. One place, so a pony and her address cannot desync -- and so a traded
	# pony blob carries where she lived, which is the format the spec asks for.
	var pen := _pen(2, "slot_4")
	var her := _instance("twilight")
	pen.add_pony(her)
	var copy: PonyInstance = PonyInstanceScript.from_dict(her.to_dict())
	assert_eq(copy.home_slot, &"slot_4", "her address survived the round trip")


func test_a_pony_with_no_address_loads_as_one_in_the_saddlebag() -> void:
	# Every pony saved before this task existed has no home_slot key at all. She must load
	# as a pony in the bag, not as a pony penned in slot "" -- which is what an unguarded
	# str(null) would produce.
	var legacy := {"uid": "twilight#000042", "data_id": "twilight", "happiness": 0.5}
	var inst: PonyInstance = PonyInstanceScript.from_dict(legacy)
	assert_not_null(inst, "an old record still loads")
	assert_eq(String(inst.home_slot), "", "...as a pony nobody has penned")


# --- the tray, and the pantry it feeds from ----------------------------------------------

func test_the_tray_counts_gems_by_the_producing_pony_s_rarity() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")  # RARE in game/data/ponies/twilight.tres
	her.happiness = 1.0
	her.hunger = 0.0
	pen.add_pony(her)
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS)
	var by_rarity: Dictionary = pen.gems_by_rarity()
	assert_eq(by_rarity.get(her.data().rarity, 0), 1)
	assert_eq(pen.gems(), 1, "the total still adds up")


func test_take_gems_by_rarity_hands_over_the_tray_and_empties_it() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")
	her.happiness = 1.0
	her.hunger = 0.0
	pen.add_pony(her)
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 2.0)
	var taken: Dictionary = pen.take_gems_by_rarity()
	assert_eq(taken.get(her.data().rarity, 0), 2)
	assert_eq(pen.gems(), 0)
	assert_eq(pen.gems_by_rarity().size(), 0)


func test_a_hungry_resident_eats_from_the_inventory() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"hay", 1)
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	watch_signals(pen)
	pen.tick(0.1)
	assert_eq(inv.count(&"hay"), 0, "the hay was eaten")
	assert_lt(her.hunger, NeedsScript.HUNGRY_THRESHOLD, "and she is no longer hungry")
	assert_signal_emitted_with_parameters(pen, "fed", [her.uid, &"hay"])


func test_a_resident_prefers_her_favourite_when_both_are_stocked() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"hay", 1)
	inv.add(&"daffodil", 1)  # a Twilight favourite, see twilight.tres
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	pen.tick(0.1)
	assert_eq(inv.count(&"daffodil"), 0, "she took the daffodil")
	assert_eq(inv.count(&"hay"), 1, "and left the hay")


## The test above stocks two of Twilight's OWN favourites, so it pins the sorted order the
## pantry is walked in and nothing else. This one is the favourite-versus-neutral case:
## carrot sorts first and is not on her list, hay sorts second and is. She must reach past
## the carrot.
func test_a_resident_reaches_past_a_neutral_food_for_her_favourite() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"carrot", 1)  # not a Twilight favourite, and first in sorted order
	inv.add(&"hay", 1)     # a Twilight favourite, see twilight.tres
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	pen.tick(0.1)
	assert_eq(inv.count(&"hay"), 0, "she took the hay she likes")
	assert_eq(inv.count(&"carrot"), 1, "and left the carrot she does not")


## THE PANTRY IS NOT A LARDER. Inventory counts item ids and does not know what one means,
## so anything the player owns can share it with the hay: a grooming brush from a later
## slice, or an id from a save written by a build that carried a food this one does not.
## `brush` sorts ahead of `carrot`, and the pen used to take Inventory.ids()[0] whenever no
## FAVOURITE was stocked, so one brush in the pantry starved every pen on the ranch for as
## long as it was owned: the brush was taken off the shelf, Needs.feed() refused an id it
## could not resolve, the brush went back, and the next tick picked the same brush again.
## Carrot rather than hay on purpose, because hay is a Twilight favourite and the favourite
## pass would have reached past the brush on its own.
func test_a_non_food_in_the_pantry_does_not_block_feeding() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"brush", 1)    # not a food, and first in sorted order
	inv.add(&"carrot", 1)   # a food, and not a Twilight favourite
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	watch_signals(pen)
	pen.tick(0.1)
	assert_eq(inv.count(&"carrot"), 0, "she ate past the brush to the carrot")
	assert_eq(inv.count(&"brush"), 1, "and the brush is still a brush")
	assert_lt(her.hunger, NeedsScript.HUNGRY_THRESHOLD, "so she is no longer hungry")
	assert_signal_emitted_with_parameters(pen, "fed", [her.uid, &"carrot"])


func test_a_pantry_holding_nothing_edible_feeds_nobody_and_consumes_nothing() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"brush", 2)
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	watch_signals(pen)
	pen.tick(0.1)
	assert_eq(inv.count(&"brush"), 2, "nothing inedible is taken off the shelf")
	assert_gte(her.hunger, NeedsScript.HUNGRY_THRESHOLD, "and she is still hungry")
	assert_signal_not_emitted(pen, "fed", "a pen that fed nobody says nothing")


func test_a_pen_with_no_inventory_does_not_feed_and_does_not_crash() -> void:
	var pen := _pen(2)
	var her := _instance("twilight")
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	pen.add_pony(her)
	pen.tick(0.1)
	assert_gte(her.hunger, NeedsScript.HUNGRY_THRESHOLD, "nothing to eat, still hungry")


func test_a_full_resident_does_not_eat() -> void:
	var pen := _pen(2)
	var inv = InventoryScript.new()
	inv.add(&"hay", 1)
	pen.inventory_provider = func() -> Inventory: return inv
	var her := _instance("twilight")
	her.hunger = 0.0
	pen.add_pony(her)
	pen.tick(0.1)
	assert_eq(inv.count(&"hay"), 1, "food is not wasted on a pony who is not hungry")


# --- the Depot: a live body released, and the collector's padlock ------------------------

func test_a_released_body_leaves_the_pen_alive_and_reparented() -> void:
	var pen: Pen = _pen(3)
	add_child_autofree(pen)
	var host := Node3D.new()
	add_child_autofree(host)
	var inst := PonyInstanceScript.create(&"stock_bold")
	inst.stock = {"coat": 1, "mane": 1, "eyes": 1}
	pen.add_pony(inst)
	var body: Node3D = pen.body_for(inst.uid)
	var where: Vector3 = body.global_position
	var released: Node3D = pen.release_body(inst.uid, host)
	assert_eq(released, body, "the same body, still alive")
	assert_true(is_instance_valid(released))
	assert_eq(released.get_parent(), host)
	assert_almost_eq(released.global_position, where, Vector3(0.01, 0.01, 0.01),
		"she is standing where she was standing")
	assert_null(pen.find_pony(inst.uid), "and the pen no longer has a record of her")
	# SHE MUST BE ABLE TO WALK BACK OUT THROUGH HER OWN GATE. A resident's collision_mask
	# carries PEN_GATE (Pen._spawn_body(), CollisionLayers.PONY_WALKABLE) so a resident
	# cannot leave on her own; a body handed to the Depot's crate walk that still carried
	# that mask would be trapped at her own gate leaf for the whole of Pony.LEAVE_SECONDS
	# and never actually reach the crate. Found by scenes/test/depot_test.gd, which is the
	# first place in the suite that runs a released body through real physics frames.
	assert_eq((released as CollisionObject3D).collision_mask, LayersScript.WALKABLE,
		"released, she carries a walking character's mask, not a resident's")
	assert_eq(pen.count(), 0)
	assert_eq(inst.home_slot, &"", "her address is cleared by the pen, as always")


func test_releasing_a_pony_who_is_not_here_answers_null_and_changes_nothing() -> void:
	var pen: Pen = _pen(3)
	var host := Node3D.new()
	add_child_autofree(host)
	assert_null(pen.release_body(&"nobody#000001", host))
	assert_eq(pen.count(), 0)


func test_a_padlocked_pen_makes_no_gems_and_keeps_its_ponies() -> void:
	var pen := _pen(3)
	var inst := PonyInstanceScript.create(&"stock_shy")
	inst.happiness = 1.0
	pen.add_pony(inst)
	pen.set_padlocked(true)
	assert_eq(pen.tick(120.0), 0, "no gems until the balance is back under the ceiling")
	assert_eq(pen.count(), 1, "and nobody is taken")
	pen.set_padlocked(false)
	assert_gt(pen.tick(120.0), 0, "paying gives the pen back")


## A POST AGAINST THE LENS STEPS ASIDE (render review 2026-10-26: at the gate a fence post a
## hand from the camera filled a third of the screen). Timber within LENS_CLEAR_M of the lens
## is not drawn; the rest of the fence is, and the colliders never move.
func test_timber_against_the_lens_is_not_drawn() -> void:
	var pen: Pen = PenScript.new()
	pen.slot_id = &"slot_lens"
	add_child_autofree(pen)
	pen.build_shell()
	var post := pen.find_child("Side0Post*", true, false) as MeshInstance3D
	assert_not_null(post, "sanity: a post to stand by")
	pen.clear_lens(post.global_position + Vector3(0, 0, 0.2))
	assert_false(post.visible, "the post at the lens goes")
	var far := 0
	for m: Node in pen.find_children("*Rail*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).visible:
			far += 1
	assert_gt(far, 4, "the rest of the fence stays")
	pen.clear_lens(pen.global_position + Vector3(30, 2, 30))
	assert_true(post.visible, "and it comes back when the lens moves off")
