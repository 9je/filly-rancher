class_name Pen
extends StaticBody3D
## A PADDOCK: the place a captured pony stops being inventory and becomes livestock.
##
## WHAT CHANGES WHEN A PONY MOVES IN. Until this file existed, the saddlebag was the whole
## roster -- every pony you owned was a pip in the HUD and nothing else, and Task 2's
## ranch.gd says so in as many words ("Task 3's pens are where the ones that do not fit
## will actually live"). A pony in a pen has a BODY standing on the map, gets hungry on the
## clock, decays or gains happiness, produces gems into a tray you come and collect, and is
## still there when you quit and come back. The saddlebag goes back to being what its name
## says: the thing you carry her home in.
##
## --- THE ROSTER IS THE PEN -------------------------------------------------------------
##
## `_residents` (an ordered Array[PonyInstance]) is the pen. The CharacterBody3Ds standing
## in the paddock are a CONSEQUENCE of it, rebuilt from it whenever the pen is on the map,
## and they are never consulted for anything that gets saved. That ordering matters: the
## roster is what round-trips through the save file, so a pen that kept the right bodies
## and the wrong roster would look perfect on screen and reload wrong -- which is a class
## of bug that takes a session to notice and a session to trust the fix for.
##
## Every roster operation works on a `Pen.new()` that has never entered a scene tree. That
## is what makes game/test/test_pen.gd run in milliseconds with no models, no physics frame
## and no terrain, and it is what makes those tests pass on a CI checkout that has no
## converted .glb assets at all (docs/ci.md section 4).
##
## --- WHERE A PENNED PONY LIVES IN THE SAVE FILE -----------------------------------------
##
## In her own record. `PonyInstance.home_slot` is the id of the slot she lives on, or ""
## for a pony in the bag. There is deliberately NO second list of "who is in pen 2" in the
## save: one fact, one place, so a pony and her address cannot desync, and so a traded pony
## blob (the spec wants two players swapping ponies by sending each other JSON) carries
## where she lived with her. game/world/ranch.gd reads it back on load and posts each pony
## either to her pen or to the saddlebag.
##
## --- BEING CAUGHT IS HOW A PONY MOVES OUT ------------------------------------------------
##
## The magic beam can pick a resident up, and doing so EVICTS her. That is a decision, and
## the playtest that forced it is worth writing down: catching a penned pony USED to appear
## to work -- she went in the saddlebag, her body vanished -- while this pen quietly kept
## her on its roster. The slot stayed consumed, has_pony() stayed true, and moving her back
## in was refused with "She would not go in." for the rest of the session. She was filed in
## two places at once, which is the exact desync the save-file section above exists to make
## impossible; nothing was enforcing it on the way OUT.
##
## The alternative -- make a resident an invalid beam target, "she already lives here" --
## was rejected. The beam is the only verb this game has for moving a pony, and there is no
## pen UI to move her with instead: a pony you can put in a pen and never take out again
## reads far worse than one you catch the same way you caught her in the first place, and it
## would have made the thing the owner had already successfully done impossible rather than
## reliable.
##
## So residency is single-sourced HERE, and it changes at exactly one instant: the one where
## her record enters the saddlebag. _on_resident_captured() is subscribed to each resident
## body's own `captured` signal, so the eviction cannot be forgotten by a caller -- the beam
## does not know pens exist and does not have to. A hold that ends any OTHER way changes
## nothing at all: _reseat_released_residents() puts her back on her standing spot, so a
## pony who wriggles out of the beam is visibly still yours and still living here, rather
## than dumped on the far side of her own fence with a leash pointing through it.
##
## --- THE SAME `Pony` ACTOR, ON A SHORTER LEASH -------------------------------------------
##
## A penned pony is game/actors/pony/pony.tscn -- the identical actor the spawner drops in
## the wild, adopting the identical PonyInstance -- with her `roam_radius` set to the pen
## instead of to an 8 m wild territory. There is no second pony type and there must not be:
## every behaviour, animation, gait and hair-sim fix already made applies to her for free,
## and PonyRegistry -> PonyVisuals stays the only sanctioned spawn path
## (docs/notes-hair-sim.md).
##
## --- THE TWO MEASUREMENTS THIS FILE IS BUILT AROUND ---------------------------------------
##
## 1. A PONY IS 2.138 m TO HER HORN TIP, not 1.163 m at the withers (docs/pipeline.md
##    section 3). FENCE_HEIGHT and GATE_CLEARANCE below are both sized off the SECOND
##    number, exactly as game/world/building.gd's MIN_DOOR_CLEARANCE is -- a fence sized
##    off "how tall is a pony" and reaching for the withers figure is a fence she can put
##    her whole head over, and it looks wrong the moment you stand next to it.
##
## 2. `roam_radius` IS SOFT. It is where a pony TURNS AROUND, not a wall: Phase 1A measured
##    a fleeing pony's momentum carrying her ~1.15 m past it (ZoneMarker.ROAM_OVERSHOOT). A
##    leash set at the fence line therefore means a spooked pony clips straight through her
##    own paddock. roam_radius_for() below stops the leash short by that overshoot PLUS her
##    own body radius, so the fence is never what has to catch her -- and the fence is
##    still solid underneath, because "never has to" and "cannot" are different promises
##    and this file makes both.
##
## --- A FARM GATE IS A GATE: SHUT TO A PONY, OPEN TO WHOEVER WORKS THE LATCH ----------------
##
## THIS SECTION IS THE FIX FOR A PLAYTEST REPORT: "i also trapped myself inside the pen and
## couldnt leave". The gate leaf used to be one more slab on THIS StaticBody3D, on
## CollisionLayers.PROPS, and the player's mask contains PROPS -- so a paddock built while
## standing on the plot sealed its own builder in with no way out at all. A pen with a
## pony-sized hole in one side is not a pen; a pen with no way out for the farmer is not a
## pen either, it is a cage.
##
## BOTH PROMISES ARE KEPT BY WHO IS ASKING, NOT BY GEOMETRY, and they have to be: the player
## and a pony are the SAME 0.42 m radius, 1.30 m capsule (player.tscn and pony.tscn are
## identical in collision terms), so no gap, height or clearance can admit one and refuse the
## other. The leaf therefore gets its own body on its own layer, CollisionLayers.PEN_GATE. A
## pony's mask is PONY_WALKABLE and contains that bit; the player's is WALKABLE and does not.
## The rest of the fence is untouched PROPS and still stops everybody, which is why only the
## GATEWAY became passable and not one centimetre of the fence.
##
## THE LEAF SWINGS, AND THE SWING IS COSMETIC ONLY. _gate_body's collider does not move --
## it stands across the gateway whether the mesh is drawn open or shut -- so containment is
## the same at every instant regardless of what the animation is doing, and ranch.gd's
## containment probe cannot be fooled by one. What the swing buys is honesty the other way:
## without it the player walks through a visibly closed gate, which is the next line of the
## same playtest report.
##
## None of this forecloses Task 5's escape-on-neglect: a pony escaping is a state change --
## remove_pony() and a respawn out in the wild with her state intact -- not a pathfinding
## exercise through a gap in the fence. NO PONY EVER DIES; a neglected one leaves, and
## leaving is something the pen does TO its roster, not something she squeezes through.

const LayersScript := preload("res://world/collision_layers.gd")
const NeedsScript := preload("res://systems/needs.gd")
const ProductionScript := preload("res://systems/production.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
## Needed for `State.HELD` alone -- see _reseat_released_residents(). pony.tscn already
## pulls this script in, so this preload adds a name, not a dependency.
const PonyScript := preload("res://actors/pony/pony.gd")

# --- geometry ------------------------------------------------------------------------------

## Half the pen's footprint on each axis, in metres: the pen is a 7.8 m square. Sized to the
## ranch's reserved clearing, not picked freely -- game/world/props.gd reserves an 18 m
## square at PEN_PLOTS_CENTRE, ranch.tscn puts four slots in it on a 9 m grid, and 7.8 m
## leaves a 1.2 m gap between neighbouring fences. See ranch.tscn's Plots node.
const HALF_EXTENT := 3.9

## Post-top height above the pen's ground plane. ABOVE A PONY'S 2.138 m HORN TIP -- see the
## class comment's measurement 1. Deliberately the same clearance figure
## game/world/building.gd uses for a doorway, so there is one number in this project for
## "tall enough for a pony" rather than two that can drift.
const FENCE_HEIGHT := 2.25

## Clear headroom under the gate's header beam. Same number, same reason.
const GATE_CLEARANCE := 2.25

## The pony capsule's radius, from game/actors/pony/pony.tscn. Used for the leash setback
## and for the standing-spot spacing. Restated here rather than read off the scene because
## it is needed by roam_radius_for(), which is a static called from tests that never
## instantiate a pony.
const PONY_BODY_RADIUS := 0.42

## Extra slack between "where she turns around, plus her overshoot, plus her body" and the
## fence line. Small and deliberate: it is the margin that makes the fence never the thing
## that catches her, and every centimetre of it is a centimetre of paddock she cannot use.
const LEASH_MARGIN := 0.35

## Fence carpentry, all in metres.
const POST_SIZE := 0.16
const RAIL_THICKNESS := 0.12
const RAIL_DEPTH := 0.10
## Rail centre heights above the ground plane. Three rails: a low one she cannot step over,
## a middle one at withers height, and a top one just under the post caps. The gaps between
## them are ~0.6 m, far narrower than the 0.84 m across a pony capsule, so the fence reads
## as open rails and is still solid -- see _add_barrier() on why the COLLIDER is one slab.
const RAIL_HEIGHTS: Array[float] = [0.55, 1.30, 2.05]
## How far the posts are buried. The reserved clearing is flat to within 0.07 m end to end
## (measured), so this is cosmetic insurance against a future terrain retune rather than
## load-bearing -- and ranch.gd's gate now asserts that flatness so the day it stops being
## true is the day a check goes red, not the day a fence floats in a screenshot.
const POST_BURY := 0.30
## Clear width of the gateway.
const GATE_WIDTH := 3.0
## Height of the gate leaf itself. Shorter than the fence on purpose: a farm gate is a gate,
## not a wall, and the space above it is above a pony capsule (which tops out at 1.30 m plus
## its cap) so nothing can use it. See the class comment's gate section.
const GATE_LEAF_HEIGHT := 1.45

## How far the leaf swings when somebody walks up to it, and how fast it gets there.
##
## INWARD, into the paddock. A 2.9 m leaf swung the other way would reach 6.8 m from the
## pen's centre -- past the 4.35 m plot it was built on and into whatever is standing next
## to it -- while the paddock is 7.8 m across and always has room for it.
const GATE_OPEN_DEGREES := 80.0
const GATE_SWING_DEGREES_PER_SECOND := 220.0

## How close the player has to get to the middle of the GATEWAY before the leaf swings.
## Measured from the gateway rather than from the pen, so standing in the middle of your own
## paddock (3.9 m away) leaves the gate shut behind you -- which is what a shut gate is for.
const GATE_SENSOR_RADIUS := 3.0

## Standing spots, as a golden-angle spiral out from the middle of the pen. A spiral rather
## than a row: ponies arranged on a grid read as a car park, which is the same note
## game/world/props.gd's LAYOUT makes about scattering trees. Bounded, hence
## MAX_RESIDENT_SPOTS.
const SPOT_INNER := 0.55
const SPOT_STEP := 0.50
const GOLDEN_ANGLE := 2.39996322972865332

## How many residents the spot spiral can seat before its radius runs past the leash.
## game/test/test_pen.gd asserts that no plot in the shipped catalogue asks for more,
## so a .tres authored with capacity 20 fails a test rather than stacking two ponies on
## one square metre.
const MAX_RESIDENT_SPOTS := 8

# --- colour ------------------------------------------------------------------------------

const POST_COLOR := Color(0.412, 0.290, 0.196)
const RAIL_COLOR := Color(0.561, 0.427, 0.290)
const GATE_COLOR := Color(0.478, 0.353, 0.243)

# --- configuration ----------------------------------------------------------------------

## How many ponies live here. Pushed in from PlotData.capacity by game/world/plot_slot.gd --
## a small pen and a grand pen are this scene with a different number in a .tres.
@export var capacity := 3

## The slot this pen stands on. Stamped onto every resident's PonyInstance.home_slot, which
## is how a save knows where to put her back. See the class comment.
@export var slot_id: StringName = &""

## Which way the gateway faces, in degrees about Y (0 = +X). Per-pen rather than fixed so
## the four slots in ranch.tscn can all open onto walkable ground instead of two of them
## opening onto the 1.2 m gap behind their neighbour.
@export var gate_yaw_degrees := 0.0

## Optional ground-height sampler, `func(x: float, z: float) -> float` in WORLD space. Set
## by game/world/ranch.gd from the terrain so the fence sits on the ground it is standing
## on. Unset (the default, and what every unit test uses) means a flat pen at y = 0.
var ground_sampler := Callable()

# --- signals ------------------------------------------------------------------------------

## A pony moved in or out. Carries the whole roster's size rather than the pony, because
## every listener so far (the HUD, a future pen sign) wants the count.
signal roster_changed(count: int)

## Gems appeared in the tray. Task 5 turns these into beamable pickups; until then they
## accumulate and take_gems() hands them over.
signal gems_produced(total: int)

## A resident ate. Carries who and what, for a toast or a test.
signal fed(uid: StringName, food_id: StringName)

# --- state ---------------------------------------------------------------------------------

## The pen. Move-in order, so a future pen UI is not reshuffled by a feeding.
var _residents: Array[PonyInstance] = []

## uid -> the live Pony body, for the residents who have one. Only populated while the pen
## is in the tree; a pen built in a unit test has a roster and no bodies.
var _bodies: Dictionary = {}

## uids whose body was in a beam when this pen last looked. Read and cleared by
## _reseat_released_residents(), which is the whole of what it is for.
var _held_bodies: Dictionary = {}

## The tray: gems by the rarity of the pony who made them (int rarity to int count). A
## transient staging area; game/world/ranch.gd folds it into GameState.gems before a save
## and when the Market opens, because Economy prices a gem by rarity and a plain total
## would throw that information away at the moment it was made.
var _gems_by_rarity: Dictionary = {}

## `func() -> Inventory`, the shared pantry the residents eat from. Injected by ranch.gd.
## Left invalid, nobody eats, which is what a test pen with no ranch wants.
var inventory_provider := Callable()

var _shell_built := false

## The gate leaf's own StaticBody3D, on CollisionLayers.PEN_GATE: the one part of this fence
## a pony cannot pass and the player can. Null until build_shell() has run. See gate_body().
var _gate_body: StaticBody3D = null

## The leaf's visual hinge and the Area3D that notices the player at the gateway. BOTH ARE
## COSMETIC. See the class comment on why _gate_body above is deliberately NOT parented to
## the hinge: a swing that could move a collider is a fence you cannot test.
var _gate_hinge: Node3D = null
var _gate_sensor: Area3D = null
var _gate_angle := 0.0


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0
	build_shell()
	# A pen restored from a save has its roster before it enters the tree; this is where
	# those residents get bodies.
	for inst in _residents:
		_spawn_body(inst)


## Take this pen's size and address from the PlotData that built it. Called by
## game/world/plot_slot.gd BEFORE the pen enters the tree, which is what lets `capacity`
## be a number in a .tres rather than a number in this file -- a Paddock, a Big Pen and a
## Grand Pen are all this one scene. Duck-typed from the slot's side (it calls `configure`
## if the built node has it), so Task 4's garden and Task 6's market stall get the same
## hook for free without plot_slot.gd learning what any of them are.
func configure(plot: PlotData, a_slot_id: StringName) -> void:
	if plot != null:
		capacity = maxi(1, plot.capacity)
	slot_id = a_slot_id


# --- the roster ---------------------------------------------------------------------------

## Move `inst` in. Returns false -- and changes NOTHING, including her home_slot -- if the
## pen is full, if she is null, or if she already lives here.
##
## THE FALSE MATTERS AS MUCH AS THE TRUE. The caller is holding a pony when it asks; a
## refusal that had already stamped her address, or already consumed a slot, would leave her
## recorded as living somewhere that has no record of her, and the next load would find her
## in neither the pen nor the bag. That is a pony lost to bookkeeping, which the
## no-pony-ever-dies rule does not distinguish from any other way of losing one.
func add_pony(inst: PonyInstance) -> bool:
	if inst == null or is_full() or has_pony(inst.uid):
		return false
	_residents.append(inst)
	inst.home_slot = slot_id
	_spawn_body(inst)
	roster_changed.emit(count())
	return true


## Take the pony with `uid` out and hand her back, or null if she does not live here.
##
## THE ONE WAY A PONY STOPS LIVING HERE. Called by a pen UI, by Task 5's escape-on-neglect,
## and -- via _on_resident_captured() -- by a beam catching her, so that every route out of
## the pen does the same four things and none of them can do three of them.
##
## Her body goes, her address is cleared, and her banked fractional gem progress is
## FORGOTTEN -- Production keeps that in a process-wide static Dictionary keyed by uid, so
## without this it grows once per pony ever penned for the life of the process, and a pony
## re-penned later would silently resume a part-finished gem from a previous tenancy.
func remove_pony(uid: StringName) -> PonyInstance:
	for i in range(_residents.size()):
		if _residents[i].uid == uid:
			var inst: PonyInstance = _residents[i]
			_residents.remove_at(i)
			inst.home_slot = &""
			_despawn_body(uid)
			ProductionScript.forget(uid)
			roster_changed.emit(count())
			return inst
	return null


## The resident with `uid`, or null. Does not remove her.
func find_pony(uid: StringName) -> PonyInstance:
	for inst in _residents:
		if inst.uid == uid:
			return inst
	return null


func has_pony(uid: StringName) -> bool:
	return find_pony(uid) != null


## A COPY of the roster, in move-in order. A copy for the same reason Storage.contents()
## hands one out: a pen UI that cleared the array it was given would empty the pen silently,
## with no signal fired and nothing at save time to hint that anything had gone.
func ponies() -> Array[PonyInstance]:
	return _residents.duplicate()


func count() -> int:
	return _residents.size()


func is_full() -> bool:
	return _residents.size() >= capacity


## The live body standing in for `uid`, or null (she may have no body, or the pen may not
## be on the map). Re-validated every call so a body freed by something else cannot be
## handed back as a dangling reference.
func body_for(uid: StringName) -> Node3D:
	var body: Node3D = _bodies.get(uid, null)
	if body != null and not is_instance_valid(body):
		_bodies.erase(uid)
		return null
	return body


# --- the clock ------------------------------------------------------------------------------

## Advance every resident by `delta` seconds and bank whatever gems they produced. Returns
## the gems produced THIS call.
##
## A PUBLIC METHOD RATHER THAN ONLY A _physics_process BODY, so a test can compress ten
## minutes into one call and so a future time-skip ("you slept until morning") has one thing
## to call. _physics_process below is a one-line caller of it.
##
## Needs first, then feeding, then Production. The ordering is right, and it earns its keep
## at exactly one line: STARVING. The two thresholds are far apart. Production pays nothing
## only to a pony at or above Production.STARVING_HUNGER_THRESHOLD (0.95 of full hunger);
## _feed_if_hungry() reaches for the pantry much earlier, at Needs.HUNGRY_THRESHOLD (0.5),
## and a successful feed puts her hunger back to zero.
##
## So: advance her hunger, feed her if the pantry can, and only then ask Production what she
## made. A resident who crosses 0.5 during THIS tick eats on this tick rather than the next
## one, and a resident who crosses 0.95 during this tick is fed back below it before
## Production ever looks, so a stocked ranch never loses a gem it could have paid for with
## one bale. Anywhere between the two thresholds the order is invisible: she is hungry, she
## eats, and she was producing either way.
func tick(delta: float) -> int:
	if delta <= 0.0 or _residents.is_empty():
		return 0
	var produced := 0
	for inst in _residents:
		NeedsScript.tick(inst, delta)
		_feed_if_hungry(inst)
		var made := ProductionScript.tick(inst, delta)
		if made > 0:
			var data: PonyData = inst.data()
			var rarity: int = data.rarity if data != null else PonyDataScript.Rarity.COMMON
			_gems_by_rarity[rarity] = int(_gems_by_rarity.get(rarity, 0)) + made
			produced += made
	if produced > 0:
		gems_produced.emit(gems())
	return produced


## Feed `inst` one item from the pantry if she is hungry and something EDIBLE is stocked.
## Her favourite first, then whatever else is in there. Hunger is checked AFTER Needs.tick()
## above so a pony who crossed the threshold this tick eats this tick.
##
## WHAT IS IN THE PANTRY IS NOT ALL FOOD. Inventory (game/systems/inventory.gd) counts item
## ids and does not know what one means, so the Market's non-food goods share it with the
## hay. This used to take Inventory.ids()[0] whenever no favourite was stocked, and ids() is
## sorted, so one brush in the pantry sorted ahead of the hay and starved the whole ranch
## for as long as it was owned: the removal succeeded, Needs.feed() refused an id it could
## not resolve, the brush went back, and the same brush was picked again on the next tick,
## forever. Now the ids are walked and anything Needs.resolve_food() cannot resolve is
## skipped, so a pantry holding a brush and a bale feeds the bale.
##
## ONE ids() CALL, walked once. It allocates and sorts a fresh array per call, and the
## favourite and the fallback have to be chosen from the same reading of the shelves.
func _feed_if_hungry(inst: PonyInstance) -> void:
	if inst.hunger < NeedsScript.HUNGRY_THRESHOLD:
		return
	if not inventory_provider.is_valid():
		return
	var pantry: Inventory = inventory_provider.call()
	if pantry == null:
		return
	var choice: StringName = &""
	for food_id: StringName in pantry.ids():
		if NeedsScript.resolve_food(food_id) == null:
			continue
		if NeedsScript.is_favorite(inst, food_id):
			choice = food_id
			break
		if String(choice).is_empty():
			choice = food_id
	if String(choice).is_empty():
		return
	# Take first, feed second: a feed that fails puts the item back rather than leaving it
	# consumed for nothing. The walk above has already ruled out the one failure Needs.feed()
	# reports, so this is the belt to that braces.
	if not pantry.remove(choice, 1):
		return
	if not NeedsScript.feed(inst, choice):
		pantry.add(choice, 1)
		return
	fed.emit(inst.uid, choice)


func _physics_process(delta: float) -> void:
	tick(delta)
	# Both, and the order does not matter: one is roster bookkeeping (a resident who broke
	# out of a beam goes back on her spot), the other is cosmetic (the leaf eases open for a
	# player standing at the gateway). Neither reads the other's state.
	_reseat_released_residents()
	_swing_gate(delta)


## Ease the leaf toward open or shut, depending on whether the player is at the gateway.
##
## PURELY VISUAL. The collider this is drawn over never moves, so nothing about containment
## depends on this function having run, or on it having run at the right time, or on it
## having run at all -- which is exactly the property that lets the ranch's containment probe
## measure a fence rather than an animation. See the class comment.
func _swing_gate(delta: float) -> void:
	if _gate_hinge == null or not is_instance_valid(_gate_hinge):
		return
	var wants_open: bool = _gate_sensor != null and is_instance_valid(_gate_sensor) \
		and not _gate_sensor.get_overlapping_bodies().is_empty()
	var target: float = GATE_OPEN_DEGREES if wants_open else 0.0
	if is_equal_approx(_gate_angle, target):
		return
	_gate_angle = move_toward(_gate_angle, target, GATE_SWING_DEGREES_PER_SECOND * delta)
	# NEGATIVE so the leaf swings INTO the paddock -- see GATE_OPEN_DEGREES. A +90 degree turn
	# about Y maps `along` onto `outward` for all four sides (check it: side 0's along is +Z
	# and its outward is +X), so a negative angle is always the inward one.
	_gate_hinge.rotation.y = deg_to_rad(-_gate_angle)


## Gems sitting in the tray, uncollected, all rarities together.
func gems() -> int:
	var sum := 0
	for value in _gems_by_rarity.values():
		sum += int(value)
	return sum


## The tray by rarity. A copy.
func gems_by_rarity() -> Dictionary:
	return _gems_by_rarity.duplicate()


## Empty the tray and hand its contents over, by rarity.
func take_gems_by_rarity() -> Dictionary:
	var got := _gems_by_rarity
	_gems_by_rarity = {}
	return got


## Empty the tray and hand over the total. Kept for callers that only count.
func take_gems() -> int:
	var total := gems()
	_gems_by_rarity = {}
	return total


# --- geometry helpers ------------------------------------------------------------------------

## Where a pony's leash is set for a pen of this half-extent.
##
## SHE TURNS AROUND HERE, she does not stop here -- see the class comment's measurement 2.
## The setback is the flee overshoot plus her own body radius plus a little slack, so that
## even the worst case (straight at the fence, at a gallop) leaves her inside it. Static so
## tests can pin the arithmetic without building a pen.
static func roam_radius_for(half_extent: float) -> float:
	return maxf(0.0, half_extent - ZoneMarkerScript.ROAM_OVERSHOOT - PONY_BODY_RADIUS
		- LEASH_MARGIN)


## Where resident number `index` is set down, in pen-local space (y = 0). A golden-angle
## spiral -- see SPOT_INNER. Static for the same reason roam_radius_for() is.
static func resident_spot(index: int) -> Vector3:
	var angle := float(index) * GOLDEN_ANGLE
	var radius := SPOT_INNER + SPOT_STEP * sqrt(float(index))
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


## Ground height at a WORLD xz, via the injected sampler, or 0.0 if there is none.
func _ground(x: float, z: float) -> float:
	if ground_sampler.is_valid():
		return float(ground_sampler.call(x, z))
	return 0.0


## The gate leaf's collider body, or null if this pen has not built its shell yet.
##
## PUBLIC BECAUSE A PEN'S FENCE IS NOW TWO BODIES, and every check that asks "did my ray hit
## MY pen?" has to know it. game/world/ranch.gd's fence-solidity ray and its pony-clipping
## shape query both compare what they hit against the pen; without this a ray fired across
## the gateway comes back holding a body that is not `pen` and the check reads as a GAP in a
## fence that is, to a pony, entirely solid. See ranch.gd's _is_pen_part().
##
## Re-validated on every call, exactly as body_for() is, so a freed node cannot be handed
## back as a dangling reference.
func gate_body() -> StaticBody3D:
	if _gate_body != null and not is_instance_valid(_gate_body):
		_gate_body = null
	return _gate_body


# --- bodies -----------------------------------------------------------------------------------

## Put a live Pony in the paddock for `inst`, leashed to the pen.
##
## Does nothing outside the tree: a pen in a unit test is a roster, and a body would need a
## scene, a model and a physics frame to mean anything. Also does nothing for a pony who
## already has one, so a restore that runs twice cannot double her.
func _spawn_body(inst: PonyInstance) -> void:
	if not is_inside_tree() or inst == null or body_for(inst.uid) != null:
		return

	var pony: Node3D = PonyScene.instantiate()
	pony.name = "Pony_%s" % String(inst.uid).replace("#", "_")
	# Layers assigned per instance, exactly as game/world/spawner.gd and
	# MagicBeam.release_stored() do it and for the reason they document: pony.tscn is shared
	# with Phase 0-era test scenes built entirely on the default layer 1, so the world's
	# layer policy is applied here rather than baked into the scene. A penned pony on the
	# wrong layer would walk through her own fence.
	pony.collision_layer = LayersScript.PONY
	# PONY_WALKABLE, not WALKABLE: it is WALKABLE plus the gate leaf's own PEN_GATE bit, and
	# that bit is the entire reason a pony stays in a paddock the player can walk out of. A
	# resident spawned with plain WALKABLE walks straight through her own gate.
	pony.collision_mask = LayersScript.PONY_WALKABLE
	var detection := pony.get_node_or_null("DetectionArea") as Area3D
	if detection != null:
		detection.collision_layer = LayersScript.INTERACTION
		detection.collision_mask = LayersScript.PLAYER

	pony.roam_radius = roam_radius_for(HALF_EXTENT)

	# --- HER LEASH IS ANCHORED TO THE MIDDLE OF THE PEN, AND THAT IS THE WHOLE TRICK -------
	#
	# Pony._ready() records wherever she is standing AT THAT MOMENT as her roaming anchor,
	# and pony.gd's setup() flags it as a hazard: "a pony added at the origin and moved
	# afterwards will spend the rest of her life being leashed back to the origin". Here it
	# is not a hazard, it is the mechanism -- she is added at the pen's centre so that the
	# centre becomes her home, and only then set down on her own standing spot.
	#
	# THE BUG THIS IS THE FIX FOR, found by the ranch gate's containment probe rather than
	# by reading the code. Anchoring each pony to her own SPOT meant her reachable radius
	# was measured from the spot, not from the middle: spot (up to 1.87 m out on the
	# spiral) + leash (1.98) + flee overshoot (1.15) + her body (0.42) = 5.42 m, against a
	# fence at 3.90. Every resident but the first was leashed to a circle that stuck out
	# through the rails, and the only reason nothing had walked out yet was that the fence
	# was catching them -- which is exactly the "never has to" promise this file makes,
	# being quietly cashed in every time a pony wandered. Anchored to the centre, the
	# arithmetic is the one roam_radius_for() actually documents: 1.98 + 1.15 + 0.42 = 3.55,
	# inside 3.90 with 0.35 m to spare, for every resident regardless of where she stands.
	#
	# Written as LOCAL positions because a node that is not in the tree yet has no global
	# transform to assign to -- spawner.gd and magic_beam.gd make the same conversion.
	pony.position = Vector3.ZERO
	add_child(pony)

	_seat_body(pony, _residents.find(inst))
	pony.adopt(inst)

	# SHE REPORTS HER OWN CAPTURE, and this pen acts on it. One line, and it is the whole
	# of why the ghost-resident leak in the class comment cannot come back: nothing that
	# catches a pony has to remember that pens exist. See _on_resident_captured().
	pony.captured.connect(_on_resident_captured.bind(inst.uid))

	_bodies[inst.uid] = pony


func _despawn_body(uid: StringName) -> void:
	var body: Node3D = body_for(uid)
	_bodies.erase(uid)
	_held_bodies.erase(uid)
	if body != null:
		body.queue_free()


## Set `body` down on standing spot `index`, in pen-local space, on the ground beneath it.
##
## Shared by the first spawn and by _reseat_released_residents(), so a resident put back
## after a beam hold stands exactly where she stood before it rather than approximately
## where she stood before it. Her velocity is cleared with her position: a body carrying the
## fall it had picked up while the beam let go would slide off the spot it was just put on.
func _seat_body(body: Node3D, index: int) -> void:
	var spot: Vector3 = resident_spot(index)
	var world := global_transform * spot
	spot.y = _ground(world.x, world.z) - global_position.y + 0.05
	body.position = spot
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


## A resident reported that a beam hold on her became a capture. She stops living here.
##
## `Pony.captured` is emitted from notify_captured(), which the beam calls at exactly one
## moment: after her record has gone into the saddlebag and immediately before it frees her
## body (see game/actors/player/magic_beam.gd's _settle_pony). So by the time this runs she
## is already inventory, and remove_pony() makes the pen agree -- roster, slot, home_slot,
## body and production ledger, all four in the one place they have always been done.
##
## CONNECTED FROM THIS SIDE ON PURPOSE. The beam is in game/actors/player/ and knows nothing
## about pens; teaching it would put a second authority on residency in the file least
## likely to be kept in step with this one. Anything that ever takes a resident out of the
## world through a capture -- a market stall, a trade, a future pen UI -- gets the eviction
## for free by going through the same signal.
func _on_resident_captured(uid: StringName) -> void:
	remove_pony(uid)


## Put a resident back on her spot when a beam let go of her WITHOUT taking her.
##
## The other half of the class comment's decision. A hold that ends in a capture is
## _on_resident_captured()'s business; a hold that ends any other way -- she outlasted the
## struggle timer (Pony.break_free()), or the saddlebag was full and the beam set her back
## down (MagicBeam's capture_refused path) -- leaves her a resident whose BODY is wherever
## she was floating, which is in front of the player and therefore usually OUTSIDE her own
## fence. She would be a pony who lives in this pen, is leashed to its centre, and is
## standing on the wrong side of a solid barrier: stuck against it for good. That is the
## "wiggle out in there making it unclear" half of the playtest note.
##
## WATCHED RATHER THAN SIGNALLED, because the two ways a hold can end without a capture do
## not share one: pony.gd is deliberately silent on set_held(false), and only break_free()
## reports. What they do share is the transition OUT of State.HELD, which is what this
## reads.
##
## THIS IS NOT A CONTAINMENT NET, and it must never become one. Only a body this pen
## actually watched go INTO a beam is moved; a resident who merely wandered is left exactly
## where she wandered to, because game/world/ranch.gd's boot-time containment probe measures
## precisely that and a pen that quietly teleported strays home would make the probe green
## by lying to it.
func _reseat_released_residents() -> void:
	if _held_bodies.is_empty() and _bodies.is_empty():
		return
	for i in range(_residents.size()):
		var uid: StringName = _residents[i].uid
		var body: Node3D = body_for(uid)
		if body == null:
			_held_bodies.erase(uid)
			continue
		if body.state == PonyScript.State.HELD:
			_held_bodies[uid] = true
			continue
		if _held_bodies.erase(uid):
			_seat_body(body, i)


# --- carpentry -------------------------------------------------------------------------------

## Build the fence. Idempotent -- called from _ready(), and safe to call again.
func build_shell() -> void:
	if _shell_built:
		return
	_shell_built = true

	if FENCE_HEIGHT < 2.138:
		push_error(("Pen '%s': FENCE_HEIGHT %.2f m does not clear a pony's 2.138 m horn " +
			"tip") % [name, FENCE_HEIGHT])

	var post_mat := _material(POST_COLOR)
	var rail_mat := _material(RAIL_COLOR)
	var gate_mat := _material(GATE_COLOR)

	# Which side the gateway is in, as a quarter turn. Snapped rather than free so the
	# gateway is always aligned with a fence side; a 37-degree gate would be a hole.
	var gate_side: int = posmod(int(round(gate_yaw_degrees / 90.0)), 4)

	# Sides, in the same order the quarter turns count: +X, +Z, -X, -Z.
	for side in range(4):
		var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
		var along := Vector3(-outward.z, 0.0, outward.x)
		_build_side("Side%d" % side, outward, along, side == gate_side,
			post_mat, rail_mat, gate_mat)


## One fence side: posts, rails, and a solid barrier, with the gateway left out of the rails
## and filled by a gate leaf when this is the gate side.
func _build_side(side_name: String, outward: Vector3, along: Vector3, is_gate: bool,
		post_mat: StandardMaterial3D, rail_mat: StandardMaterial3D,
		gate_mat: StandardMaterial3D) -> void:
	var line := outward * HALF_EXTENT
	var half_gate := GATE_WIDTH * 0.5 if is_gate else 0.0

	# --- posts ---------------------------------------------------------------------------
	# Five per side: the two corners, the two gate jambs (or two intermediates when this is
	# not the gate side), and the midpoint. Positions are derived from the gateway so a
	# retuned GATE_WIDTH moves the jambs with it.
	var offsets: Array[float] = [-HALF_EXTENT, HALF_EXTENT]
	if is_gate:
		offsets.append(-half_gate)
		offsets.append(half_gate)
		offsets.append((HALF_EXTENT + half_gate) * 0.5)
		offsets.append(-(HALF_EXTENT + half_gate) * 0.5)
	else:
		offsets.append(-HALF_EXTENT / 3.0)
		offsets.append(HALF_EXTENT / 3.0)
		offsets.append(0.0)

	for offset in offsets:
		var at := line + along * offset
		var top := FENCE_HEIGHT
		if is_gate and absf(absf(offset) - half_gate) < 0.001:
			# The jambs carry the header beam, so they run past the fence line.
			top = GATE_CLEARANCE + 0.30
		_slab("%sPost%d" % [side_name, roundi(offset * 100.0)],
			Vector3(POST_SIZE, top + POST_BURY, POST_SIZE),
			Vector3(at.x, (top - POST_BURY) * 0.5, at.z), post_mat, false)

	# --- rails ---------------------------------------------------------------------------
	# Two runs flanking the gateway when there is one, a single run when there is not.
	var runs: Array = []
	if is_gate:
		runs.append([-HALF_EXTENT, -half_gate])
		runs.append([half_gate, HALF_EXTENT])
	else:
		runs.append([-HALF_EXTENT, HALF_EXTENT])

	for run in runs:
		var a: float = run[0]
		var b: float = run[1]
		var mid: float = (a + b) * 0.5
		var span: float = b - a
		if span <= 0.001:
			continue
		for height in RAIL_HEIGHTS:
			var at := line + along * mid
			_slab("%sRail%dat%d" % [side_name, roundi(height * 100.0), roundi(mid * 100.0)],
				_side_size(along, span, RAIL_THICKNESS, RAIL_DEPTH),
				Vector3(at.x, height, at.z), rail_mat, false)

	# --- the gate itself ------------------------------------------------------------------
	if is_gate:
		var header_at := line
		# The header's UNDERSIDE sits at GATE_CLEARANCE: a pony walks under 2.25 m of clear
		# air, which is her 2.138 m horn tip plus a hand's width. This is the number
		# game/world/building.gd's MIN_DOOR_CLEARANCE makes the same argument for.
		_slab("%sHeader" % side_name,
			_side_size(along, GATE_WIDTH, 0.22, 0.16),
			Vector3(header_at.x, GATE_CLEARANCE + 0.11, header_at.z), post_mat, false)
		# The leaf. Two bars and a diagonal would be prettier; two bars is what reads at
		# this scale and it is one shape instead of five.
		#
		# HUNG ON A HINGE at the low jamb so it can swing open for the player. The bars are
		# children of the hinge rather than of the pen -- that is the only reason a rotation
		# moves them -- and the leaf's COLLIDER is deliberately not (see _add_barrier).
		_gate_hinge = Node3D.new()
		_gate_hinge.name = "%sGateHinge" % side_name
		var hinge_at := line + along * -half_gate
		_gate_hinge.position = Vector3(hinge_at.x, 0.0, hinge_at.z)
		add_child(_gate_hinge)
		for bar_h in [0.45, 1.25]:
			var bar_mesh := BoxMesh.new()
			bar_mesh.size = _side_size(along, GATE_WIDTH - 0.10, 0.16, 0.08)
			bar_mesh.material = gate_mat
			var bar := MeshInstance3D.new()
			bar.name = "%sGateBar%d" % [side_name, roundi(bar_h * 100.0)]
			bar.mesh = bar_mesh
			bar.position = along * half_gate + Vector3.UP * bar_h
			_gate_hinge.add_child(bar)
		_gate_sensor = _build_gate_sensor(side_name, line)

	# --- the barrier ------------------------------------------------------------------------
	_add_barrier(side_name, outward, along, is_gate)


## THE COLLIDER, and the one place this file's geometry is deliberately not what you see.
##
## What you see is posts and rails. What you bump into is one slab per side, from the ground
## to the fence top, plus one across the gateway. That is the SAME barrier: a pony capsule
## is 0.84 m across and the widest gap between two rails is ~0.6 m, so no rail arrangement
## here was ever passable -- the slab just says it in one shape instead of fifteen, on a
## map that will end up with several pens on it.
##
## Sunk POST_BURY below the ground plane for the same reason the posts are: the reserved
## clearing is flat to 0.07 m today, and a barrier that started exactly at y = 0 would leave
## a hairline gap at the pen's low corner the day that stops being true.
func _add_barrier(side_name: String, outward: Vector3, along: Vector3, is_gate: bool) -> void:
	var line := outward * HALF_EXTENT
	var height := FENCE_HEIGHT + POST_BURY
	var centre_y := FENCE_HEIGHT * 0.5 - POST_BURY * 0.5
	if not is_gate:
		_collider("%sBarrier" % side_name,
			_side_size(along, HALF_EXTENT * 2.0, height, POST_SIZE),
			Vector3(line.x, centre_y, line.z))
		return

	# Gate side: a panel each side of the gateway, plus the shut gate across it. See the
	# class comment on why the gateway is closed and why that does not foreclose Task 5.
	var panel: float = HALF_EXTENT - GATE_WIDTH * 0.5
	if panel > 0.001:
		for sign_ in [-1.0, 1.0]:
			var mid: float = sign_ * (HALF_EXTENT + GATE_WIDTH * 0.5) * 0.5
			var at := line + along * mid
			_collider("%sBarrier%s" % [side_name, "Lo" if sign_ < 0.0 else "Hi"],
				_side_size(along, panel, height, POST_SIZE),
				Vector3(at.x, centre_y, at.z))
	# THE GATE LEAF'S COLLIDER -- the one piece of this fence that is NOT on PROPS.
	#
	# Its own StaticBody3D so it can be on its own layer: PEN_GATE is in a pony's mask and is
	# not in the player's, and that is the whole of what makes this a gate instead of a wall.
	# See the class comment. A CHILD OF THE PEN, NOT OF THE VISUAL HINGE, so no amount of
	# swinging can move it: the gateway is shut to a pony at every instant, including the
	# frames where the leaf is drawn wide open for the farmer walking through it.
	_gate_body = StaticBody3D.new()
	_gate_body.name = "%sGateLeafBody" % side_name
	_gate_body.collision_layer = LayersScript.PEN_GATE
	_gate_body.collision_mask = 0
	add_child(_gate_body)
	var leaf_shape := BoxShape3D.new()
	leaf_shape.size = _side_size(along, GATE_WIDTH, GATE_LEAF_HEIGHT + POST_BURY, POST_SIZE)
	var leaf_col := CollisionShape3D.new()
	leaf_col.name = "%sGateBarrier" % side_name
	leaf_col.shape = leaf_shape
	leaf_col.position = Vector3(line.x, GATE_LEAF_HEIGHT * 0.5 - POST_BURY * 0.5, line.z)
	_gate_body.add_child(leaf_col)


## The Area3D that notices the player standing at the gateway. It drives the swing and
## NOTHING else -- see _swing_gate().
##
## Layered exactly as game/world/plot_slot.gd layers its trigger: on INTERACTION so nothing
## mistakes it for something solid, masking PLAYER so a pony leaning on her own gate does not
## open it, and monitorable = false so it never turns up in a pony's DetectionArea results.
func _build_gate_sensor(side_name: String, line: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = "%sGateSensor" % side_name
	area.collision_layer = LayersScript.INTERACTION
	area.collision_mask = LayersScript.PLAYER
	area.monitoring = true
	area.monitorable = false
	area.position = Vector3(line.x, GATE_LEAF_HEIGHT * 0.5, line.z)
	var sphere := SphereShape3D.new()
	sphere.radius = GATE_SENSOR_RADIUS
	var col := CollisionShape3D.new()
	col.name = "Trigger"
	col.shape = sphere
	area.add_child(col)
	add_child(area)
	return area


## A box size for something running ALONG a fence side: `span` along the side, `height` up,
## `depth` through the fence. `along` is one of the four axis directions, so this is a swap
## rather than a rotation -- which keeps every shape axis-aligned and every BoxShape3D exact.
func _side_size(along: Vector3, span: float, height: float, depth: float) -> Vector3:
	if absf(along.x) > 0.5:
		return Vector3(span, height, depth)
	return Vector3(depth, height, span)


func _material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## One visible box. `with_collision` is false for every call in this file -- the fence's
## solidity is _add_barrier()'s job -- but the parameter is here rather than absent because
## a caller that wants both should not have to reach for a second function.
func _slab(slab_name: String, size: Vector3, at: Vector3, mat: StandardMaterial3D,
		with_collision := true) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat

	var mesh_node := MeshInstance3D.new()
	mesh_node.name = slab_name
	mesh_node.mesh = box
	mesh_node.position = at
	add_child(mesh_node)

	if with_collision:
		_collider(slab_name + "Col", size, at)


func _collider(shape_name: String, size: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = shape_name
	col.shape = shape
	col.position = at
	add_child(col)
