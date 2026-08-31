extends Node
## THE REGION GATE. Proves the whole of slice 3's unlock loop on the real map, in one run:
## a ring of timber stands shut around every region that has a price on it, the ponies who live in each one
## spawned inside it and nobody else did, the orchard's gateway is a wall the player cannot
## walk through, the permit for it is in the Market and unaffordable while the wallet is
## empty, selling two legendary gems pays for it, buying it swings that one gate open and
## leaves the other three shut, she now walks straight through it, it cannot be bought
## twice, and a save-reset-load round trip puts the regions back exactly the way the file
## says rather than the way the session did.
##
## THE RANCH IS HOSTED HERE, not launched. world/ranch.tscn is instanced under this scene,
## so ranch.gd runs with _hosted true: it arms no watchdog of its own, it does not quit the
## process out from under this driver, it never reads the player's save, and it hands its
## own verdict over as gate_report_finished(all_ok). This gate waits for that signal rather
## than polling for a symptom of it, and folds the ranch's answer into its own. Same
## scaffold as scenes/test/market_test.gd.
##
## WHY THE PLAYER IS DRIVEN AND NOT RAY-CAST. A ray tells you a collider is there; it does
## not tell you a body cannot get past it. The claim a permit makes is a claim about where
## she can GET to, so both gate checks below drive ranch.player at the gateway with
## move_and_slide() over physics frames, the way test/test_region_fence.gd's _drive does,
## and measure how far from the region's centre she ended up. The unit test does this to a
## fence standing on a flat plane in a bare scene; this does it to the fence the shipped
## map actually builds, on the shipped terrain, at the shipped radius, with the shipped
## permit paying for it.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const MarketMenuScript := preload("res://ui/market_menu.gd")
const RegionFenceScript := preload("res://world/region_fence.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

const SLOT := 7  # a scratch slot; a hosted ranch reads no slot at all, so nothing collides

## The region the whole permit loop is driven through. The cheapest of the four (150 bits),
## which is what makes "two legendary gems pay for it" an honest amount of money rather
## than a number chosen to fit.
const ZONE := &"orchard"
## A region that is never bought here, so "the permit opened a gate" can be told apart from
## "the permit opened every gate".
const OTHER_ZONE := &"lake"
const PERMIT_ITEM := &"permit_orchard"
const PERMIT_UNLOCK := "permit_orchard"

## How hard the player is driven at the gateway and for how long. 6 m/s for 90 frames is
## 9 m at the project's 60 Hz tick, comfortably more than the 8 m she is asked to cover, so
## "she did not get in" can never quietly mean "she ran out of frames". Both numbers are
## test/test_region_fence.gd's, deliberately: the two files are asking the same question of
## the same geometry and a reader comparing them should not have to reconcile two speeds.
const WALK_SPEED := 6.0
const WALK_FRAMES := 90
## Where she starts and where she is aimed, in metres either side of the gateway.
const APPROACH := 4.0
## How far she has to have travelled for a drive to have happened at all. She is asked to
## cover 8 m; a run that moved her less than this measured nothing, whatever it concluded.
const MIN_TRAVEL := 2.0
## How far past the fence line "she got in" has to put her. The gateway is 4 m deep from
## where she is aimed, so this leaves 2 m of slack for the leaf's own thickness and for a
## resident she may have to squeeze past on the way.
const INSIDE_MARGIN := 2.0
## How far above the ground her feet are held during a drive. See _drive_at_gate().
const GROUND_CLEARANCE := 0.05

var _checks: Dictionary = {}
var _duplicates: Array[String] = []
var _ranch: Ranch = null


## Record one check's verdict under `label`. A repeated label is a check that never ran:
## the second verdict would silently overwrite the first and the total would come out one
## short, so a collision is recorded and fails the gate in _finish(). Same rule as
## market_test.gd's _set_check(), capture_test.gd's _record() and ranch.gd's _set_check().
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
	GateWatchdogScript.arm(self, "REGION", 120.0)
	var ranch := $Ranch as Ranch
	_ranch = ranch

	# The ranch's boot awaits inside its own _ready(), so it has already yielded by the
	# time this line runs and the connection lands before the verdict is emitted.
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)
	# A ranch that failed its own report still gets driven through everything below, for
	# market_test.gd's reason: a log showing WHICH parts of the loop survived is worth more
	# than an early exit, and the gate fails either way.
	var fences: Array[RegionFence] = ranch.get_region_fences()
	_set_check("the ranch booted and bound a shop", ranch.get_shop() != null)
	if ranch.get_shop() == null or fences.is_empty():
		_set_check("there are fences to test", not fences.is_empty())
		_finish()
		return

	# --- four rings, all shut ------------------------------------------------------------
	var priced := 0
	for region: RegionData in ranch._regions_registry().all():
		if region.permit_cost > 0:
			priced += 1
	_set_check("there is one fence for every priced region", fences.size() == priced)
	_set_check("the free region has no fence and needs none",
		ranch.is_region_open(&"strip") and priced == fences.size())
	var zones: Array[StringName] = []
	var all_shut := true
	for fence in fences:
		if fence.region() == null:
			all_shut = false
			continue
		zones.append(fence.region().id)
		if fence.is_open():
			all_shut = false
	print("REGION fences=%d zones=%s" % [fences.size(), str(zones)])
	_set_check("every fence knows which region it rings",
		zones.size() == fences.size() and zones.has(ZONE) and zones.has(OTHER_ZONE))
	_set_check("every gate is shut before a permit is bought", all_shut)

	var orchard: RegionFence = _fence_for(ZONE)
	_set_check("the orchard has a fence", orchard != null)
	if orchard == null:
		_finish()
		return
	var region: RegionData = orchard.region()

	# --- who lives where ------------------------------------------------------------------
	# A region is a place with somebody in it, not a fenced-off patch of grass. Three
	# counts rather than one verdict, so a run that spawned nobody at all reads as the
	# vacuous thing it is instead of passing every containment test by having nothing to
	# test. `spawn_zones` is one zone per pony in the shipped roster, so "her zone" is
	# unambiguous and a pony is either a region's resident or the homestead's.
	var region_ids: Array[StringName] = zones
	var zoned_here := 0
	var strays_out := 0
	var strays_in: Array[String] = []
	for body: CharacterBody3D in ranch.spawner.get_spawned():
		var pony := body as Pony
		if pony == null or pony.get_data() == null:
			continue
		# STOCK PONIES CARRY NO spawn_zones AT ALL (game/data/hidden/*.tres): the whole
		# point of the crowd is that she belongs to whichever marker filled her, ranch or
		# region alike, not to one authored zone the way a named character is. The check
		# below is about a NAMED character's authored home disagreeing with where she is
		# standing, which is not a question a stock pony's record can even answer.
		if pony.is_stock():
			continue
		var data: PonyData = pony.get_data()
		var at := Vector2(pony.global_position.x, pony.global_position.z)
		var her_zone: StringName = &""
		for zone: StringName in region_ids:
			if data.spawn_zones.has(zone):
				her_zone = zone
		if her_zone == ZONE:
			zoned_here += 1
		if her_zone.is_empty():
			# A homestead pony. She must not be standing inside ANY region: the whole map
			# is behind gates she has not paid for, and a ranch pony over the fence is a
			# region the player can reach without a permit by catching her there.
			for fence in fences:
				if fence.region() == null or not fence.region().contains(at):
					continue
				# The ring stands RING_MARGIN outside the disc, so a stray inside the disc
				# is inside the TIMBER as well, with the gate shut and a pony's mask
				# containing PEN_GATE. Reported with both numbers because "she is in the
				# wrong meadow" and "she is locked in a paddock nobody can open" are
				# different sizes of wrong and the distance is what tells them apart.
				var ring: float = fence.region().radius + RegionFenceScript.RING_MARGIN
				var away: float = at.distance_to(fence.region().centre)
				strays_in.append("%s at %.1f m from '%s' (disc %.0f m, ring %.0f m)"
					% [pony.name, away, fence.region().id, fence.region().radius, ring])
		else:
			var hers: RegionData = _region_for(her_zone, fences)
			if hers == null or at.distance_to(hers.centre) > hers.radius + RegionFenceScript.RING_MARGIN:
				strays_out += 1
	print("REGION residents orchard=%d out_of_region=%d ranch_ponies_in_a_region=%d"
		% [zoned_here, strays_out, strays_in.size()])
	for stray in strays_in:
		push_error("region_test: a homestead pony is inside a fenced region: %s" % stray)
	_set_check("the orchard's residents actually spawned", zoned_here > 0)
	_set_check("every region's residents spawned inside their region", strays_out == 0)
	_set_check("no homestead pony spawned inside a region", strays_in.is_empty())

	# --- a known-empty wallet --------------------------------------------------------------
	# reset() REPLACES the pouch, the pantry and the unlocks and announces nothing, so the
	# Shop built around the old ones has to be rebuilt by hand. rebind_economy() is the
	# public path that does it, and _apply_permits() rides along inside it: the assertion
	# two lines down is what proves that, because a rebind that forgot the fences would
	# leave whatever the boot report's own gate probe last set.
	var state = get_node("/root/GameState")
	state.reset()
	ranch.rebind_economy()
	var shop: Shop = ranch.get_shop()
	_set_check("a reset and a rebind leave every gate shut", _open_count(fences) == 0)
	_set_check("the wallet is empty after a reset", shop.bits() == 0)

	# --- the shut gate is a wall ------------------------------------------------------------
	var shut: Dictionary = await _drive_at_gate(orchard)
	print("REGION shut gate: line=%.2f start=%.2f end=%.2f moved=%.2f"
		% [shut["line"], shut["start"], shut["end"], shut["moved"]])
	# ANTI-VACUITY FIRST. "She did not get in" is trivially true of a body that never moved,
	# which is what a missing collider under her feet or an unparented player would both
	# look like.
	_set_check("she really walked at the shut gate", float(shut["moved"]) > MIN_TRAVEL)
	_set_check("a shut gate holds the player outside the fence line",
		float(shut["end"]) > float(shut["line"]))
	# And the prompt that is the only reason she would ever know a permit exists. She is
	# standing at the gateway right now, so the ranch has to be able to name the region she
	# is standing at.
	var prompted: RegionFence = ranch.nearest_locked_gate()
	_set_check("standing at the shut gate names that region as locked",
		prompted != null and prompted.region() != null and prompted.region().id == ZONE)

	# --- the permit is for sale, and out of reach ---------------------------------------------
	var menu = ranch.get_market_menu()
	_set_check("the market opens", menu.open())
	menu.set_tab(MarketMenuScript.Tab.BUY)
	var rows: Array[ShopItem] = menu.buy_rows()
	var permit_index := -1
	for i in range(rows.size()):
		if rows[i].id == PERMIT_ITEM:
			permit_index = i
	_set_check("the orchard permit is in the catalogue", permit_index >= 0)
	if permit_index < 0:
		menu.close()
		_finish()
		return
	var permit: ShopItem = rows[permit_index]
	_set_check("the permit is priced at what the region asks",
		permit.cost == region.permit_cost and permit.permit_zone == ZONE)
	_set_check("an empty wallet cannot buy the permit", not shop.can_buy(permit))
	menu.move_selection(permit_index)
	_set_check("confirming an unaffordable permit is refused", not menu.confirm())
	_set_check("the refusal left the gate shut", not orchard.is_open())

	# --- pay for it -----------------------------------------------------------------------
	# Funded through the Economy's own sale rather than by writing `bits` directly, so
	# bits_changed fires and GameState and the HUD follow the way they do in play. Two
	# legendary gems is 200 bits against a 150-bit permit: enough, and not by much.
	var earned: int = ranch.get_economy().sell(PonyDataScript.Rarity.LEGENDARY, 2)
	_set_check("two legendary gems pay more than the permit costs", earned > permit.cost)
	_set_check("the sale reached GameState", state.bits == shop.bits())
	_set_check("the permit is affordable once she has been paid", shop.can_buy(permit))
	menu.set_tab(MarketMenuScript.Tab.BUY)
	menu.move_selection(permit_index)
	var before: int = shop.bits()
	_set_check("the permit is buyable", menu.confirm())
	_set_check("the permit cost bits", shop.bits() == before - permit.cost)
	_set_check("the permit is recorded in the unlocks", state.unlocks.has(PERMIT_UNLOCK))
	_set_check("buying the permit opened its gate", orchard.is_open())
	_set_check("and opened NOTHING else", _open_count(fences) == 1)
	var hud = ranch.get_node("HUD")
	_set_check("the toast says the region is open",
		_hud_says(hud, "%s is open." % region.display_name))
	_set_check("the permit cannot be bought twice", not menu.confirm())
	_set_check("the second attempt did not charge her", shop.bits() == before - permit.cost)
	menu.close()
	_set_check("closing the market unpauses", not get_tree().paused)

	# --- the same gateway, now a doorway -------------------------------------------------
	# Same fence, same bearing, same drive, same distances. The ONLY thing that changed
	# between this run and the one above is that 150 bits were spent.
	var through: Dictionary = await _drive_at_gate(orchard)
	print("REGION open gate: line=%.2f start=%.2f end=%.2f moved=%.2f"
		% [through["line"], through["start"], through["end"], through["moved"]])
	_set_check("she really walked at the open gate", float(through["moved"]) > MIN_TRAVEL)
	_set_check("a bought gate lets the player walk into the region",
		float(through["end"]) < float(through["line"]) - INSIDE_MARGIN)
	_set_check("a bought gate no longer prompts for a permit",
		ranch.nearest_locked_gate() == null)

	# --- the save is what says which regions are open ----------------------------------------
	_set_check("the save lands", state.save_to_slot(SLOT))
	var raw := SaveIOScript.load(SLOT)
	_set_check("the permit is in the file", raw.get("unlocks", []).has(PERMIT_UNLOCK))
	state.reset()
	ranch.rebind_economy()
	_set_check("a reset takes the permit away", not state.unlocks.has(PERMIT_UNLOCK))
	_set_check("and shuts the gate it paid for", not orchard.is_open())
	# NOTHING BELOW CALLS _apply_permits(). load_from_slot() emits state_loaded, ranch.gd
	# connected rebind_economy() to it at boot, and rebind_economy() re-reads the fences
	# from the replaced unlocks array. That chain is the thing under test: a load that
	# restored the wallet but not the gates would leave the player locked out of a region
	# her save file says she owns.
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	_set_check("the permit came back", state.unlocks.has(PERMIT_UNLOCK))
	_set_check("loading a save re-opened the region it paid for", orchard.is_open())
	_set_check("and re-opened nothing else", _open_count(fences) == 1)
	_set_check("the orchard reads as open", ranch.is_region_open(ZONE))
	_set_check("the lake reads as shut", not ranch.is_region_open(OTHER_ZONE))
	_set_check("a region this map does not have reads as shut",
		not ranch.is_region_open(&"no_such_region"))

	# --- cleanup ------------------------------------------------------------------------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT)))
	_finish()


## The fence ringing `zone`, or null.
func _fence_for(zone: StringName) -> RegionFence:
	for fence in _ranch.get_region_fences():
		if fence.region() != null and fence.region().id == zone:
			return fence
	return null


## The RegionData for `zone`, read off the fences rather than off a second load of the
## registry: the fences are what the map actually stood, and a check that compared a pony's
## position against a freshly loaded .tres could agree with the data while disagreeing with
## the world.
func _region_for(zone: StringName, fences: Array[RegionFence]) -> RegionData:
	for fence in fences:
		if fence.region() != null and fence.region().id == zone:
			return fence.region()
	return null


func _open_count(fences: Array[RegionFence]) -> int:
	var open := 0
	for fence in fences:
		if fence.is_open():
			open += 1
	return open


## Walk ranch.player from APPROACH metres outside `fence`'s gateway to APPROACH metres
## inside it, and report {line, start, end, moved} in metres: `line` is how far the gateway
## itself is from the region's centre, `start` and `end` how far she was from that centre
## before and after, `moved` how far she actually travelled. Every one of those is a flat
## XZ distance, because the question a ring answers is a question about the ground plane.
##
## HER OWN CONTROLLER IS OFF FOR THE DRIVE. player.gd's _physics_process() reads Input,
## applies gravity and calls move_and_slide() itself; leaving it running would have two
## pieces of code moving the same body every frame and the distance measured would be
## neither one's. This is the same body, the same capsule and the same layers she plays
## with (PLAYER, masking WALKABLE) driven by hand, which is exactly what
## test/test_region_fence.gd's walkers are.
##
## HER FEET ARE HELD ON THE TERRAIN each frame rather than left to gravity, for the same
## reason: the shipped ground rolls, and a body that fell, bounced or caught on a rise
## would report a distance about the hillside instead of about the gate.
func _drive_at_gate(fence: RegionFence) -> Dictionary:
	var region: RegionData = fence.region()
	var centre := Vector2(region.centre.x, region.centre.y)
	var gate: Vector3 = fence.gate_position()
	var outward := Vector3(gate.x - centre.x, 0.0, gate.z - centre.y).normalized()
	var start := gate + outward * APPROACH
	var target := gate - outward * APPROACH

	var player: CharacterBody3D = _ranch.player
	var was_processing := player.is_physics_processing()
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.global_position = _on_ground(start)
	await get_tree().physics_frame

	var from := player.global_position
	for i in range(WALK_FRAMES):
		var dir := target - player.global_position
		dir.y = 0.0
		player.velocity = dir.normalized() * WALK_SPEED
		player.global_position = _on_ground(player.global_position)
		player.move_and_slide()
		await get_tree().physics_frame
	player.velocity = Vector3.ZERO
	player.set_physics_process(was_processing)

	return {
		"line": Vector2(gate.x, gate.z).distance_to(centre),
		"start": Vector2(from.x, from.z).distance_to(centre),
		"end": Vector2(player.global_position.x, player.global_position.z).distance_to(centre),
		"moved": Vector2(player.global_position.x - from.x,
			player.global_position.z - from.z).length(),
	}


## `at` with its height replaced by the terrain's, plus a hand's clearance so her capsule
## rests on the ground instead of starting inside it.
func _on_ground(at: Vector3) -> Vector3:
	var y: float = float(_ranch.terrain.call("height_at", at.x, at.z))
	return Vector3(at.x, y + GROUND_CLEARANCE, at.z)


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("region_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("region_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("REGION_OK " if all_ok else "REGION_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)


## Whether the HUD has said `text` to the player: the line on screen, or anything queued
## behind it.
##
## THE WHOLE QUEUE, NOT THE LABEL ALONE. A toast raised while another one is still up waits
## its turn now instead of overwriting it (game/ui/hud.gd, toast()). Reading the label alone
## was green here only because this gate's permit toast happens to be the one on screen at
## the moment it is asked; anything raised before it, now or later, would fail this check
## for the queue rather than for a defect. The same helper as scenes/test/market_test.gd's,
## and the same reason.
func _hud_says(hud, text: String) -> bool:
	if hud.toast_text() == text:
		return true
	return hud.pending_toasts().has(text)
