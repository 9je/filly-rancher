class_name RequestBoard
extends RefCounted
## THREE STANDING FAVOURS the ranch can ask of the player, refreshed as they are finished.
## GameState carries whatever this class hands back as `requests` (game/systems/game_state.gd,
## Task 2); an opaque Array of Dictionaries as far as that file is concerned; this file is
## the only place that shape is defined and read. A later task wires this board to the ranch
## (catching, penning, selling, spotting a pony) and pays the rewards it reports; this file
## only tracks progress and produces the text; it never touches Economy, GemPouch or
## Inventory directly.
##
## RefCounted, no scene tree; same discipline as Compendium (game/systems/compendium.gd)
## and Economy (game/systems/economy.gd), so the whole thing is GUT-testable headlessly
## (game/test/test_request_board.gd).
##
## --- THE FIRST THREE ARE A TUTORIAL, NOT A DRAW -------------------------------------------
##
## seed_tutorial() hands out exactly CATCH_ANY, PEN_ANY, SELL_ANY, in that order, with fixed
## text and fixed rewards; these three teach the three verbs the ranch is built on before
## the board starts asking for anything specific. fill() never produces these kinds; once
## they are claimed they are gone for good ("the tutorial three are not refilled" is simply
## fill() only ever drawing from the three TEMPLATE kinds below).
##
## --- DETERMINISM: ONE RNG PER DRAW, SEEDED FROM (seed, draw_counter) ----------------------
##
## Every drawn (non-tutorial) request gets its own RandomNumberGenerator, seeded from
## `hash(Vector2i(_seed, _draw_counter))`, and `_draw_counter` advances by exactly one per
## draw attempt (successful or not) before that RNG is used. Two boards constructed with the
## same seed that receive the same sequence of fill()/on_*() calls therefore produce
## bit-identical requests(); nothing here ever reads the global RNG. `_draw_counter` is
## part of the board's persisted state (see to_array() below) specifically so a reloaded
## board picks up the SAME sequence a save/quit/reload must not restart from scratch.
##
## --- to_array() / from_array(): THE SEED AND COUNTER RIDE IN ELEMENT 0 --------------------
##
## `to_array()` returns a plain Array (so `GameState.requests = board.to_array()` type-checks
## against GameState's own `Array` field) whose FIRST element is a metadata Dictionary
## `{"seed": int, "draw_counter": int}` and every element after that is one request
## Dictionary. from_array() cannot re-seed the board any other way: its signature is fixed
## by the brief to `(a, registry, regions)` with no separate seed parameter, and without the
## seed a reloaded board could not continue drawing the same sequence at all; only the
## draw_counter would be recoverable (from surviving "req_N" ids), and even that breaks once
## a draw fails without producing a request (a real, if rare, possibility once every
## character has been seen and the region list is short). Storing both explicitly, once,
## alongside the requests is simpler than trying to reconstruct either from the request list.
##
## --- ADDED FIELD NOT IN THE BRIEF'S DICTIONARY SHAPE: "paid" ------------------------------
##
## `paid: bool` is added to every request dict alongside the brief's listed keys. `done`
## means "progress reached its target"; `paid` means "claim() has already handed this one
## out". Keeping them separate is what makes claiming twice return {} (see claim()) while
## still letting requests() show a completed-but-unclaimed request as done.
##
## --- SEE_CHARACTER's FOOD REWARD IS A FIXED AMOUNT, NOT A DICTIONARY FIELD ----------------
##
## The brief's request shape has `reward_food: String` (an item id, e.g. "hay") but no count
## field, and the brief's own template text says "reward 40 bits plus 2 hay"; a fixed
## amount, not one that varies per request. SEE_CHARACTER_FOOD_COUNT below is that fixed
## amount; the later task that pays rewards multiplies reward_food (if non-empty) by that
## constant instead of an unnamed field. Every other kind leaves reward_food as "".

const PonyDataScript := preload("res://systems/pony_data.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")
const EconomyScript := preload("res://systems/economy.gd")
const SpawnTableScript := preload("res://systems/spawn_table.gd")

enum Kind { CATCH_ANY, PEN_ANY, SELL_ANY, BRING_PERSONALITY_FROM_ZONE, SELL_GEMS_OF_RARITY, SEE_CHARACTER }

## How many not-done requests the board tries to keep on offer at once.
const ACTIVE := 3

## The item id and fixed amount SEE_CHARACTER's reward hands out alongside its bits. See the
## class comment on why this is a constant rather than a dictionary field.
const SEE_CHARACTER_FOOD_ID := "hay"
const SEE_CHARACTER_FOOD_COUNT := 2

## SELL_GEMS_OF_RARITY's target count is drawn uniformly from this inclusive range.
const SELL_GEMS_COUNT_MIN := 3
const SELL_GEMS_COUNT_MAX := 6

## Bits per gem sold above the gem's own sale value (EconomyScript.GEM_VALUE_BY_RARITY,
## game/systems/economy.gd); a completed SELL_GEMS_OF_RARITY request pays out MORE than
## just selling the gems at the market would, which is the whole point of asking for them.
const SELL_GEMS_BONUS_PER_GEM := 15

var _seed: int
var _registry: PonyRegistry
var _regions: Array[StringName] = []
var _region_names: Dictionary = {}
var _region_registry: RegionRegistry = null

var _requests: Array = []
var _draw_counter: int = 0


## `region_names` is an optional {id -> display name} lookup used to build
## BRING_PERSONALITY_FROM_ZONE's text without touching disk; see the class comment. When a
## region's id is missing from it, RegionRegistry (game/systems/region_registry.gd) is
## loaded lazily, once, and consulted instead; a region unknown to BOTH falls back to its
## bare id so a request never carries broken text.
func _init(seed: int, registry: PonyRegistry, regions: Array[StringName], region_names: Dictionary = {}) -> void:
	_seed = seed
	_registry = registry
	_regions = regions.duplicate()
	_region_names = region_names.duplicate()


# --- reading -------------------------------------------------------------------------------

## Every request on the board, done or not, as copies; mutating the result never touches
## the board's own state.
func requests() -> Array:
	var out: Array = []
	for r in _requests:
		out.append((r as Dictionary).duplicate(true))
	return out


## Requests that have not yet reached their target count, as copies.
func active() -> Array:
	var out: Array = []
	for r in _requests:
		if not bool(r.get("done", false)):
			out.append((r as Dictionary).duplicate(true))
	return out


# --- the tutorial three ---------------------------------------------------------------------

## Appends CATCH_ANY, PEN_ANY, SELL_ANY, in that exact order, with fixed text and fixed
## rewards. Does not consume the draw sequence and is not idempotent; call it once, at the
## start of a fresh ranch.
func seed_tutorial() -> void:
	_requests.append(_tutorial_request("tutorial_catch", Kind.CATCH_ANY, 20,
		"Catch a pony with your magic beam."))
	_requests.append(_tutorial_request("tutorial_pen", Kind.PEN_ANY, 30,
		"Move a pony into a pen."))
	_requests.append(_tutorial_request("tutorial_sell", Kind.SELL_ANY, 50,
		"Sell a gem at the market."))


func _tutorial_request(id: String, kind: int, reward_bits: int, text: String) -> Dictionary:
	return _blank_request(id, kind, reward_bits, "", text)


func _blank_request(id: String, kind: int, reward_bits: int, reward_food: String, text: String) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"personality": -1,
		"zone": "",
		"rarity": -1,
		"count": 1,
		"progress": 0,
		"character": "",
		"reward_bits": reward_bits,
		"reward_food": reward_food,
		"done": false,
		"paid": false,
		"text": text,
	}


# --- filling the board from templates -------------------------------------------------------

## Draws new requests (BRING_PERSONALITY_FROM_ZONE, SELL_GEMS_OF_RARITY, SEE_CHARACTER only
## (never a tutorial kind) until `active()` has ACTIVE entries, deterministic from the seed
## and the draw counter. `seen` is the ids (StringName or String, either works) already SEEN
## or CAUGHT in the player's Compendium (game/systems/compendium.gd); the board has no
## compendium of its own, so the caller supplies this each time. A character already
## targeted by another active SEE_CHARACTER request is excluded too, so the board never asks
## twice for the same face at once. When every character is excluded, SEE_CHARACTER simply
## drops out of the draw and the other two templates fill the remaining slots.
func fill(seen: Array = []) -> void:
	var guard := 0
	while active().size() < ACTIVE and guard < 1000:
		guard += 1
		var excluded := _excluded_characters(seen)
		# Annotated rather than inferred: _draw_one() returns Variant (a Dictionary or
		# null), and Godot 4.5 treats INFERENCE_ON_VARIANT as an ERROR rather than as a
		# warning, so `var drawn := ...` here refuses to compile the whole file.
		var drawn: Variant = _draw_one(excluded)
		if drawn == null:
			break
		_requests.append(drawn)


func _excluded_characters(seen: Array) -> Dictionary:
	var excluded := {}
	for s in seen:
		excluded[String(s)] = true
	for r in _requests:
		if not bool(r.get("done", false)) and int(r.get("kind", -1)) == Kind.SEE_CHARACTER:
			excluded[String(r.get("character", ""))] = true
	return excluded


## One seeded draw. Returns null only if no template could be built at all (defensive; in
## practice SELL_GEMS_OF_RARITY has no precondition and is always available).
func _draw_one(excluded_characters: Dictionary) -> Variant:
	var this_draw := _draw_counter
	_draw_counter += 1

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(_seed, this_draw))

	var kinds := _available_kinds(excluded_characters)
	var kind: int = kinds[rng.randi() % kinds.size()]

	match kind:
		Kind.BRING_PERSONALITY_FROM_ZONE:
			return _draw_bring(rng, this_draw)
		Kind.SELL_GEMS_OF_RARITY:
			return _draw_sell_gems(rng, this_draw)
		Kind.SEE_CHARACTER:
			return _draw_see_character(rng, this_draw, excluded_characters)
	return null


## Which of the three drawable kinds currently have at least one possible outcome.
## SELL_GEMS_OF_RARITY has no precondition, so this is never empty.
func _available_kinds(excluded_characters: Dictionary) -> Array:
	var kinds: Array = [Kind.SELL_GEMS_OF_RARITY]
	if not _regions.is_empty():
		kinds.append(Kind.BRING_PERSONALITY_FROM_ZONE)
	if not _unseen_ponies(excluded_characters).is_empty():
		kinds.append(Kind.SEE_CHARACTER)
	return kinds


func _draw_bring(rng: RandomNumberGenerator, this_draw: int) -> Dictionary:
	var zone_id: StringName = _regions[rng.randi() % _regions.size()]
	var personalities := PonyDataScript.Personality.values()
	var personality: int = personalities[rng.randi() % personalities.size()]
	var personality_name := String(PonyDataScript.Personality.keys()[personality]).to_lower()
	var region_name := _region_display_name(zone_id)

	var r := _blank_request("req_%d" % this_draw, Kind.BRING_PERSONALITY_FROM_ZONE, 80, "",
		"Bring a %s pony from %s." % [personality_name, region_name])
	r["personality"] = personality
	r["zone"] = String(zone_id)
	return r


func _draw_sell_gems(rng: RandomNumberGenerator, this_draw: int) -> Dictionary:
	var count := rng.randi_range(SELL_GEMS_COUNT_MIN, SELL_GEMS_COUNT_MAX)
	var rarity := _weighted_rarity(rng)
	var rarity_name := String(PonyDataScript.Rarity.keys()[rarity]).to_lower()
	var unit_value: int = EconomyScript.GEM_VALUE_BY_RARITY.get(rarity, 0)
	var reward := count * (unit_value + SELL_GEMS_BONUS_PER_GEM)

	var r := _blank_request("req_%d" % this_draw, Kind.SELL_GEMS_OF_RARITY, reward, "",
		"Sell %d %s gems." % [count, rarity_name])
	r["rarity"] = rarity
	r["count"] = count
	return r


## Weighted toward COMMON/UNCOMMON: reuses SpawnTable.WEIGHTS (game/systems/spawn_table.gd),
## the project's one existing rarity-tier weighting, rather than inventing a second curve
## that has to be kept in sync with it by hand.
func _weighted_rarity(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in SpawnTableScript.WEIGHTS.values():
		total += w
	var roll := rng.randf() * total
	var running := 0.0
	var last := PonyDataScript.Rarity.LEGENDARY
	for rarity in SpawnTableScript.WEIGHTS.keys():
		last = rarity
		running += SpawnTableScript.WEIGHTS[rarity]
		if roll < running:
			return rarity
	return last


func _draw_see_character(rng: RandomNumberGenerator, this_draw: int, excluded_characters: Dictionary) -> Variant:
	var eligible := _unseen_ponies(excluded_characters)
	if eligible.is_empty():
		return null
	var data: PonyData = eligible[rng.randi() % eligible.size()]

	var r := _blank_request("req_%d" % this_draw, Kind.SEE_CHARACTER, 40, SEE_CHARACTER_FOOD_ID,
		"Find %s and get a good look at her." % data.display_name)
	r["character"] = String(data.id)
	return r


## Every PonyData in the registry not in `excluded` (ids as String keys). Walks the roster by
## rarity tier, the same technique Compendium._all_data() uses; PonyRegistry has no plain
## all() accessor, and by_rarity() partitions the whole roster exactly once per character.
func _unseen_ponies(excluded: Dictionary) -> Array[PonyData]:
	var out: Array[PonyData] = []
	for rarity in PonyDataScript.Rarity.values():
		for data: PonyData in _registry.by_rarity(rarity):
			if not excluded.has(String(data.id)):
				out.append(data)
	return out


func _region_display_name(zone_id: StringName) -> String:
	if _region_names.has(zone_id):
		return String(_region_names[zone_id])
	var key := String(zone_id)
	if _region_names.has(key):
		return String(_region_names[key])
	if _region_registry == null:
		_region_registry = RegionRegistryScript.new()
		_region_registry.load_all()
	var region: RegionData = _region_registry.by_id(zone_id)
	if region != null:
		return region.display_name
	return key


# --- events ----------------------------------------------------------------------------------

## `data` was caught anywhere; `zone` is the zone the catch happened in. Bumps every not-done
## CATCH_ANY by one, and every not-done BRING_PERSONALITY_FROM_ZONE whose personality and
## zone both match. Returns copies of the requests this call completed.
func on_caught(data: PonyData, zone: StringName) -> Array:
	if data == null:
		return []
	var flipped: Array = []
	for r in _requests:
		var req: Dictionary = r
		if bool(req.get("done", false)):
			continue
		var kind := int(req.get("kind", -1))
		var matched := false
		if kind == Kind.CATCH_ANY:
			matched = true
		elif kind == Kind.BRING_PERSONALITY_FROM_ZONE \
				and int(req.get("personality", -1)) == data.personality \
				and String(req.get("zone", "")) == String(zone):
			matched = true
		if matched and _bump(req, 1):
			flipped.append(req.duplicate(true))
	return flipped


## `data` was moved into a pen. Bumps every not-done PEN_ANY by one.
func on_penned(data: PonyData) -> Array:
	if data == null:
		return []
	var flipped: Array = []
	for r in _requests:
		var req: Dictionary = r
		if bool(req.get("done", false)):
			continue
		if int(req.get("kind", -1)) == Kind.PEN_ANY and _bump(req, 1):
			flipped.append(req.duplicate(true))
	return flipped


## `count` gems of `rarity` (a PonyData.Rarity value) were just sold. Bumps every not-done
## SELL_ANY by one (any sale at all completes it), and every not-done SELL_GEMS_OF_RARITY of
## the matching rarity by `count`; this is the one kind whose progress accumulates across
## several calls rather than completing on the first.
func on_sold(rarity: int, count: int) -> Array:
	if count <= 0:
		return []
	var flipped: Array = []
	for r in _requests:
		var req: Dictionary = r
		if bool(req.get("done", false)):
			continue
		var kind := int(req.get("kind", -1))
		var bumped := false
		if kind == Kind.SELL_ANY:
			bumped = _bump(req, 1)
		elif kind == Kind.SELL_GEMS_OF_RARITY and int(req.get("rarity", -1)) == rarity:
			bumped = _bump(req, count)
		if bumped:
			flipped.append(req.duplicate(true))
	return flipped


## `data` was spotted (Compendium.mark_seen fired for her). Bumps the not-done SEE_CHARACTER
## request naming her, if any.
func on_seen(data: PonyData) -> Array:
	if data == null:
		return []
	var flipped: Array = []
	for r in _requests:
		var req: Dictionary = r
		if bool(req.get("done", false)):
			continue
		if int(req.get("kind", -1)) == Kind.SEE_CHARACTER \
				and String(req.get("character", "")) == String(data.id) \
				and _bump(req, 1):
			flipped.append(req.duplicate(true))
	return flipped


## Adds `amount` to `req`'s progress in place and flips it to done the moment progress
## reaches count. Returns whether THIS call is the one that flipped it (so a caller summing
## several on_*() results never double-counts a completion).
func _bump(req: Dictionary, amount: int) -> bool:
	req["progress"] = int(req.get("progress", 0)) + amount
	if not bool(req.get("done", false)) and int(req["progress"]) >= int(req.get("count", 1)):
		req["done"] = true
		return true
	return false


# --- claiming ----------------------------------------------------------------------------------

## Marks the done, unpaid request `id` as paid and returns a copy of it (reward fields and
## all) for the caller to actually pay out. Returns an empty Dictionary if `id` is unknown,
## not yet done, or already paid; claiming twice never pays twice.
func claim(id: String) -> Dictionary:
	for r in _requests:
		var req: Dictionary = r
		if String(req.get("id", "")) != id:
			continue
		if not bool(req.get("done", false)) or bool(req.get("paid", false)):
			return {}
		req["paid"] = true
		return req.duplicate(true)
	return {}


# --- save / load -------------------------------------------------------------------------------

## A plain Array: element 0 is `{"seed": int, "draw_counter": int}`, every element after that
## is one request Dictionary. See the class comment for why the seed and counter are embedded
## here rather than carried separately.
func to_array() -> Array:
	var out: Array = [{"seed": _seed, "draw_counter": _draw_counter}]
	for r in _requests:
		out.append((r as Dictionary).duplicate(true))
	return out


## Rebuilds a board from to_array()'s output. A request whose SEE_CHARACTER character (or
## BRING_PERSONALITY_FROM_ZONE zone) is not known to `registry` (or not in `regions`) is
## dropped; reported with push_warning(), not a crash; and every other request is kept.
static func from_array(a: Array, registry: PonyRegistry, regions: Array[StringName],
		region_names: Dictionary = {}) -> RequestBoard:
	var seed_val := 0
	var counter := 0
	var start_index := 0
	if a.size() > 0 and typeof(a[0]) == TYPE_DICTIONARY:
		var meta: Dictionary = a[0]
		if meta.has("seed") and meta.has("draw_counter") and not meta.has("id"):
			seed_val = int(meta["seed"])
			counter = int(meta["draw_counter"])
			start_index = 1

	var board := RequestBoard.new(seed_val, registry, regions, region_names)
	board._draw_counter = counter

	for i in range(start_index, a.size()):
		if typeof(a[i]) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = (a[i] as Dictionary).duplicate(true)
		var kind := int(rec.get("kind", -1))

		if kind == Kind.SEE_CHARACTER:
			var char_id := StringName(String(rec.get("character", "")))
			if String(char_id).is_empty() or registry.by_id(char_id) == null:
				push_warning("RequestBoard.from_array: dropping request '%s'; unknown character '%s'" % [
					rec.get("id", ""), char_id
				])
				continue

		if kind == Kind.BRING_PERSONALITY_FROM_ZONE:
			var zone_id := StringName(String(rec.get("zone", "")))
			if String(zone_id).is_empty() or not (zone_id in regions):
				push_warning("RequestBoard.from_array: dropping request '%s'; unknown zone '%s'" % [
					rec.get("id", ""), zone_id
				])
				continue

		board._requests.append(rec)

	return board
