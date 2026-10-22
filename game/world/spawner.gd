class_name Spawner
extends Node3D
## Fills the ranch's ZoneMarkers with wild ponies: for each marker, build a
## rarity-weighted SpawnTable from the registry entries zoned for that marker, draw
## `spawn_count` of them, and stand each one on the actual ground inside the
## marker's disc.
##
## THE GROUND IS FOUND BY RAYCAST, not assumed. game/world/terrain.gd is a rolling
## heightfield and the zone markers sit out past its flat apron on purpose, so
## `y = marker.y` would bury half a herd and float the other half. Each candidate
## point is probed with a downward ray and the pony is placed on what it hits. The
## ray also does a second job: a point that lands on a PROP is rejected and re-rolled,
## which is what stops a pony from spawning inside a tree trunk.
##
## RAYCASTS NEED A PHYSICS FRAME FIRST. The terrain's trimesh collider and the
## props' colliders are created in their own _ready(), and the physics server has
## not stepped since -- a space-state query made in the same frame sees an empty
## world and every ray misses. populate() must therefore be called AFTER at least
## one physics frame has elapsed; ranch.gd awaits two before calling it. Calling it
## too early does not fail silently: every ray misses, every placement falls back,
## and the fallback count is reported and asserted on.
##
## DETERMINISM. The draw is seeded, and the registry's entries are sorted BY THEIR
## id AS A STRING before the table is built. Both halves matter. PonyRegistry walks
## a directory, so its dictionary order is the filesystem's, not a guarantee; and
## StringName's `<` compares interned POINTERS rather than text, so sorting on the
## raw ids gives an order that is stable within one process and different between
## processes. That exact bug already shipped once in this project (game/scenes/test/
## wild_ponies.gd documents it) -- the String() casts below are the fix and must not
## be "simplified" away.
##
## COLLISION LAYERS ARE ASSIGNED HERE, per instance, rather than in pony.tscn. Not a
## style choice: the ranch is where the world's layer policy lives (see
## game/world/collision_layers.gd), and pony.tscn is shared with wild_ponies.tscn,
## which is a Phase 0-style test scene built entirely on the default layer 1. Setting
## the layers on the instance keeps that gate working untouched while the real world
## gets real layers.

## Emitted once for every wild pony this spawner puts on the map, from populate() AND from
## refresh(), after setup() has run so `pony.get_data()` already answers. THE ONE PLACE a
## caller can subscribe to "a new pony exists" without having to remember that ponies now
## arrive twice: at boot, and every time the sky turns over. ranch.gd wires each arrival's
## `noticed_player` off this, and a wiring done at the populate() call site only would have
## left every pony who walked in at dusk unable to enter the compendium.
signal pony_spawned(pony: CharacterBody3D)

const LayersScript := preload("res://world/collision_layers.gd")
const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const SpawnTableScript := preload("res://systems/spawn_table.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const PonyGeneratorScript := preload("res://systems/pony_generator.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")

## Real seconds a marker waits before standing a replacement for a stock pony who was
## caught, delivered or otherwise left. Long enough that emptying a field feels like an
## achievement for the length of a walk back to the pens, short enough that the field is
## full again by the next visit. THE WILD MUST NEVER RUN DRY: this timer is the whole of
## the spec's repeatability promise.
const STOCK_RESPAWN_SECONDS := 45.0

## The most pony bodies this spawner will ever have standing at once, named and stock
## together. A ceiling rather than a target: it is what stops a future retune of
## stock_count from quietly tripling the frame cost, and ranch.gd's report fails on a world
## that exceeds it.
const WORLD_PONY_BUDGET := 60

## How far above and below a candidate point the ground ray is cast. Generous
## against terrain.gd's ~+/-2.4 m of relief, and cheap.
const RAY_UP := 40.0
const RAY_DOWN := 60.0

## Re-rolls allowed per pony before giving up on finding clear ground. Each reroll
## is rejected for one of two reasons: the ray hit a prop (she would be inside a
## tree) or she landed on top of a pony already placed.
const PLACEMENT_ATTEMPTS := 12

## Minimum ground distance between two freshly-spawned ponies, in metres. Two 0.42 m
## capsules need 0.84 m not to interpenetrate; 1.4 m leaves them visibly separate on
## frame one rather than shoving each other apart.
const MIN_SEPARATION := 1.4

@export_group("Spawning")
## Directory of PonyData .tres records.
##
## READ EXACTLY ONCE, at the first _spawnable_entries() (which is populate()'s first act),
## and cached in `_entries` for every later refresh(). Re-pointing it after that would be a
## lie: the cache is not rebuilt, so the spawner would go on drawing out of the old
## directory while its inspector said otherwise. The setter therefore REFUSES the new value
## and says so, rather than accepting an assignment that does nothing.
@export_dir var pony_dir := "res://data/ponies":
	set(value):
		if _entries_loaded and value != pony_dir:
			push_error(("Spawner: pony_dir cannot be changed to '%s' after the roster has " +
				"been read (it is cached at the first populate()); the spawner is still " +
				"drawing from '%s'.") % [value, pony_dir])
			return
		pony_dir = value

## Fixed so the ranch is the same ranch every launch: same ponies, same spots, same
## wander targets. A collection game whose roster reshuffles every time you open it
## has no map to learn.
##
## AND SINCE THE SEED IS FIXED, WHICH HERD IT DRAWS IS A CONTENT DECISION, NOT A
## COIN TOSS, so it is searched for rather than left to whatever the first plausible
## number happened to produce. Three seeds have been retired that way. 20260827 drew 3
## Rainbow Dashes and 5 Fluttershies and NO Twilight, every launch, forever, back when
## the whole roster was three ponies. 20260839 replaced it; then slice 2 took the roster
## to 43 characters, and that number drew only 8 distinct ponies with Nurse Redheart
## standing in the field three times over. 20260874 replaced THAT, and drew ten distinct
## characters out of a 43-strong ranch pool. Slice 3 then re-zoned 30 of those 43 into
## four regions, which left 20260874 drawing from a 13-pony ranch pool it was never
## searched against. None of those draws was wrong. SpawnTable splits each tier's weight
## among that tier's members, so a repeat is an ordinary outcome. It is just an outcome
## nobody should be stuck with permanently.
##
## 20721716 DRAWS TWENTY-TWO DISTINCT CHARACTERS INTO TWENTY-TWO SLOTS at the hour the
## world boots into, which is the ceiling: nobody is standing in the field twice. That was
## true of the nine ZoneMarkers ranch.tscn held before Phase 3 slice 1 Task 2 (five on the
## homestead at spawn_count 2, one in each region at 3, no stock crowd yet).
##
##   ranch (10)       Lotus, Rarity, Sweetie Belle, Twilight Sparkle, Fluttershy,
##                    Derpy Hooves, Starlight Glimmer, Pinkie Pie, Nurse Redheart,
##                    Scootaloo
##   orchard (3)      Carrot Top, Berry Punch, Caramel
##   everfree (3)     Doctor Whooves, Pokey Pierce, Kerfuffle
##   lake (3)         Milky Way, Flitter, Minuette
##   nightmeadow (3)  Mane Allgood, Limestone Pie, Marble Pie
##
## TASK 2 CUT EVERY MARKER'S spawn_count TO 1 AND GAVE EACH ONE A STOCK BUDGET ON TOP: the
## pacing rule is a named pony is at most one in five of a wild draw in the homestead and
## rarer beyond it, and twenty two named slots on a nine marker map could not hold that
## ratio next to a crowd. The same nine markers now draw nine named slots, and 20721716
## was RE-MEASURED against that smaller draw rather than re-picked: it still rolls a clear
## dawn for cycle 0 (that condition is about the sky, not the marker count, so retuning
## spawn_count could not have moved it) and it still draws nine DISTINCT characters into
## the nine slots, which was the whole property being asked of it.
##
##   ranch        Lotus, Rarity, Sweetie Belle, Twilight Sparkle, Fluttershy
##   orchard      Berry Punch
##   everfree     Pokey Pierce
##   lake         Milky Way
##   nightmeadow  Mane Allgood
##
## "AT THE HOUR THE WORLD BOOTS INTO" IS NEW, AND IT IS WHY THIS SEED REPLACED 20295486.
## Slice 5 gave PonyData `phases` and `weathers`, so populate() no longer draws from a
## zone's whole roster: it draws from the characters available at the phase and weather it
## is handed. That is a smaller pool at every hour (the everfree edge and the night meadow
## are down to three each at DAWN under a clear sky), and 20295486 was searched against
## pools that no longer exist. The search below therefore had a second condition on it:
## the seed must also ROLL A CLEAR DAWN for cycle 0 (WorldState.weather_for(seed, 0,
## DAWN) == CLEAR), so the sky the player actually boots into is the sky the herd was
## drawn for. 20295486 rolls rain at that hour and always did; nothing noticed while the
## draw ignored weather.
##
## NO LEGENDARY IS DRAWN AT DAWN, and no seed can change that: all three legendaries keep
## other hours now (Sunset Shimmer at dusk, Trixie and Shining Armor at night), so at DAWN
## the tier is empty everywhere on the map. The old seed's "all four tiers in one draw"
## property has become impossible rather than unlucky, and losing it is the point of the
## feature: the rarest characters are things you go out at the right hour to find, not
## things standing in the first field you walk into. The nine slot draw is 5 COMMON,
## 2 UNCOMMON and 2 RARE, and the legendaries arrive through refresh() when the sky comes
## round. The stock crowd never touches this tier count either way: her personality and
## her colours are drawn off their own RNG, in _fill_stock(), not off this one.
##
## FOUND BY SEARCH, not by taste. A throwaway script replayed SpawnTable's own draw
## against every seed from 20260600 upward with the real roster, the real zones, the real
## conditions at DAWN and CLEAR, and the markers read out of ranch.tscn in scene order,
## scoring each seed by how many distinct characters its 22 draws contain. 461,117 seeds
## were tried. Exactly one before 20721716 reaches 22 at all (20357460), and that one
## rolls rain at dawn, so it fails the second condition. Re-pick the same way if the
## roster, the zoning or the conditions change, because the draw depends on all three.
##
## NINE SLOTS CANNOT SHOW 43 CHARACTERS, and no seed will change that either. What changed
## in slice 5 is that they no longer have to: refresh() below sends the ponies whose hour
## has passed off the map and draws whoever the new hour belongs to, so the rest of the
## roster arrives over a session rather than waiting for the save to be deleted. And nine
## slots was never meant to be the whole of what is standing in the field: Task 2's stock
## crowd is the other forty, so a named pony now takes minutes to find rather than being
## the first thing the boot draw puts in front of the player.
##
## KEEP THIS IN STEP WITH GameState.DEFAULT_WORLD_SEED. A save carries the seed its world
## was generated from, and a run with no save takes this one into the state; the two are
## asserted equal in game/test/test_spawner_seed.gd.
@export var spawn_seed := 20721716

## Node whose ZoneMarker children this spawner fills. Defaults to a sibling `Zones`.
@export var zones_path := NodePath("../Zones")

## Every PonyData the registry loaded, spawnable or not -- the roster as authored.
## Used to tell a mis-typed zone_id apart from an assetless checkout.
var _roster: Array = []

var _spawned: Array[CharacterBody3D] = []
var _fallback_placements := 0
var _empty_zones: Array[StringName] = []
var _unspawnable: Array[StringName] = []

## Which ZoneMarker each live pony was drawn for, keyed by her instance id. refresh()
## needs it to answer "how many of this marker's ponies are still staying", and there is
## nowhere else to keep it: a Pony knows her PonyData and her home POINT, not the marker
## the point came out of. Pruned in step with _spawned, in get_spawned().
var _marker_by_pony: Dictionary = {}

## Slot numbers are handed out once and never reused, across populate() AND every later
## refresh(). They feed the per pony wander RNG and the ground placement RNG (see
## _spawn_one and _ground_point), so reusing them would stand every replacement on the
## exact spot the pony she replaced was drawn onto, refresh after refresh.
var _next_slot := 0

## The registry, read once. _spawnable_entries() walks a directory and loads forty three
## resources; populate() does that at boot and refresh() would do it again on every phase
## and every weather change for the rest of the session. Cached here rather than inside
## PonyRegistry because the sort and the assetless filter are this node's own, and
## because _roster and _unspawnable are reported and must not re-accumulate.
var _entries: Array[PonyData] = []
var _entries_loaded := false

## THE SKY THE HERD WAS LAST DRAWN FOR: the (phase, weather) pair the last populate() or
## refresh() was handed, as WorldState enum ints. refresh() compares each candidate against
## it to tell a character whose hours have JUST OPENED apart from one who was already
## available at the previous hour and simply lost the draw. That distinction is the whole of
## the priority fill below: without it a freed slot went back into the rarity weighted draw,
## and a night only character could stand three cycles' worth of nights behind an
## unconditional common who was already eligible.
##
## NOT PERSISTED, on purpose. populate() sets the pair at boot, so a fresh run is honest
## from its first refresh. After a mid session load the remembered pair is the PRE LOAD
## hour, which is acceptable while there is no in game Load page (the only load a session
## does happens before the ranch builds its herd). The worst that mismatch can do is spend
## ONE refresh treating a newcomer as an old face, and the next hour puts it right.
var _last_phase: int = WorldStateScript.Phase.DAWN
var _last_weather: int = WorldStateScript.Weather.CLEAR

## Seconds a marker has been short of its stock budget, keyed by marker instance id. Reset
## the moment a replacement is stood.
var _stock_wait: Dictionary = {}

var _regions: RegionRegistry = null

## The registry hidden records resolve through, kept like _entries.
var _stock_registry: PonyRegistry = null


## Draw and place every zone's ponies. Returns how many actually reached the tree.
##
## Call after at least one physics frame -- see the class comment.
##
## `phase` and `weather` are WorldState enum ints and are the sky the world boots into: a
## character whose PonyData.available() says no for that pair is not in the pool at all,
## so the herd the player walks out into already keeps the hours it is meant to keep.
## They default to DAWN and CLEAR, which is what a fresh clock reads at elapsed zero, so
## every existing caller keeps exactly the draw it had.
func populate(phase: int = WorldStateScript.Phase.DAWN,
		weather: int = WorldStateScript.Weather.CLEAR) -> int:
	# Before the early return below, so a spawner with no markers still remembers the hour
	# it was booted into rather than claiming DAWN forever.
	_last_phase = phase
	_last_weather = weather

	var markers := get_markers()
	if markers.is_empty():
		push_error("Spawner: no ZoneMarker found under '%s' -- nothing to populate" % zones_path)
		return 0

	var entries := _spawnable_entries()

	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed

	var slot := 0
	for marker: ZoneMarker in markers:
		var pool := _pool_for(marker, entries, phase, weather)

		# TWO DIFFERENT FAILURES, KEPT APART ON PURPOSE. "This zone_id matches no
		# pony in the roster at all" is a content bug -- a typo'd zone name -- and
		# ranch.gd fails the gate on it. "The roster has ponies for this zone but
		# none of their models exist on this machine" is the ordinary assetless
		# checkout (CI, a fresh clone), and must NOT fail. Collapsing them made the
		# assetless run go red for the wrong reason.
		if _zoned_in_roster(marker.zone_id) == 0 and not marker.zone_id in _empty_zones:
			_empty_zones.append(marker.zone_id)

		if pool.is_empty():
			continue

		var table := SpawnTableScript.new(pool, rng)
		for i in range(marker.spawn_count):
			var data: PonyData = table.draw()
			if data == null:
				push_error("Spawner: SpawnTable.draw() returned null for zone '%s' slot %d"
					% [marker.zone_id, i])
				continue
			var pony := _spawn_one(data, marker, slot)
			if pony != null:
				_spawned.append(pony)
				_marker_by_pony[pony.get_instance_id()] = marker
			slot += 1

	slot = _fill_stock(slot)
	_next_slot = slot
	return _spawned.size()


## THE SKY CHANGED, so the herd changes with it. Every wild pony whose conditions no
## longer hold is told to leave() (she walks off and frees herself out of sight, see
## Pony.leave(); nothing owned is reachable from here, and nothing dies), and every marker
## left short is topped back up out of the pool that matches the new hour. Returns
## `{"left": n, "arrived": n, "unfilled": n, "made_room": n}`, the first two of which are
## what the caller puts on screen.
##
## WHOEVER THE HOUR HAS JUST OPENED FOR GOES FIRST, ahead of the weighted draw. A freed slot
## used to go straight back into SpawnTable, where a night only legendary competed on rarity
## weight against every unconditional common in the zone who was standing there a minute ago
## and is eligible again now; a measurement on this branch had a night only character take
## three extra cycles to appear that way. So each marker's free slots are offered first to
## its NEWCOMERS: the characters whose conditions hold now, did NOT hold at the pair this
## spawner last drew for (`_last_phase`, `_last_weather`), and who are standing nowhere on
## the map. Which newcomer takes which slot is still the seeded per refresh RNG's to say, so
## the draw is as deterministic as it ever was; what has changed is who is in the running.
## Only once the newcomers run out do the remaining slots go to the ordinary weighted draw.
##
## AND IF A MARKER IS FULL, ONE RESIDENT MAKES ROOM. A newcomer with nowhere to stand would
## otherwise wait for a departure that a full marker of unconditional residents will never
## produce, because the night only pool is exactly the pool with nobody to displace. So a
## marker with no free slot and nobody already on their way out sends ONE staying resident
## home (Pony.leave(), the same walk off any other departure makes; nothing dies, nothing
## owned is reachable from here) and gives the freed slot to the newcomer in the same
## refresh. The resident chosen is always an UNCONDITIONAL one (empty `phases` AND empty
## `weathers`), because she is the one character who can come back at any hour, so nothing
## is lost by sending her home. At most one eviction per marker per refresh, counted in
## "made_room"; she is counted in "left" as well, because from the player's side she
## wandered off like anybody else.
##
## DETERMINISTIC PER HOUR, NOT PER CALL. The draw RNG is seeded from the world seed, the
## cycle index and the phase, so the same save at the same hour of the same day draws the
## same replacements however often it is reloaded. `cycle * 4 + phase` is the phase
## counted from the start of play, which is the exact granularity weather is rolled at
## (game/systems/world_state.gd), so a phase and its weather always arrive together and
## the pair of them is one number.
##
## A LEAVING PONY DOES NOT COUNT toward her marker's tally, so her replacement is drawn in
## the same breath and the two of them are briefly both on the map. That overlap is what
## "one wanders off as another arrives" is supposed to look like.
##
## NOBODY STANDS IN THE FIELD TWICE, AND THE RULE IS MAP-WIDE RATHER THAN PER MARKER. The
## characters already standing anywhere on the map and staying are struck out of every
## marker's pool before it is drawn from, and each arrival is struck out for the rest of
## the call. Without it a refresh could put a second Caramel in the orchard next to the
## first one, which is the exact outcome the world seed was searched to avoid at boot; it
## would be odd to buy that property for the boot draw and then throw it away four minutes
## later. THE DRAW IS NOT ALLOWED TO CHEAT ITS WAY OUT: a marker whose pool empties leaves
## the slot EMPTY for that hour and counts it in the returned `unfilled`, rather than
## drawing a duplicate or raising an error. An unfilled slot is a legitimate reading of a
## quiet hour; on the shipped map it never happens, and
## game/test/test_roster_data.gd's "every zone can fill its markers" test is what keeps
## that true as the roster changes.
##
## IDEMPOTENT for a given (phase, weather, cycle): the second call finds every marker full
## of ponies who are all still available, and draws nothing. The priority fill does not
## break that and cannot: the remembered pair is set to (phase, weather) at the end of every
## refresh, so on the second call every candidate that is available now was available then
## too, the newcomer list is empty everywhere, and with it the eviction.
##
## AT (cycle 0, DAWN) THE REFRESH SEED IS THE PLAIN WORLD SEED, because `0 * 4 + 0` is
## zero, so the first refresh of a brand new save replays populate()'s own RNG stream. It
## does not replay populate()'s draw: the pools differ (the map is already full, so most
## markers ask for nothing) and the exclusion above is in force. Worth knowing when reading
## a trace of a first session, and not worth perturbing the seed to avoid.
##
## STOCK KEEPS NO HOURS. The hidden stock records carry empty `phases` and `weathers`, so
## `available()` answers true at every hour for every one of them; this function iterates
## get_spawned() and checks that same condition without caring whether a pony is stock or
## named, so a stock pony is never told to leave by a change of sky and is never touched
## here at all. Her field refills on its own timer instead; see tick_stock().
func refresh(phase: int, weather: int, cycle: int, player_position: Vector3) -> Dictionary:
	var left := 0
	for pony in get_spawned():
		if pony.is_leaving():
			continue
		var data: PonyData = pony.get_data()
		if data != null and data.available(phase, weather):
			continue
		if pony.leave():
			left += 1

	var markers := get_markers()
	if markers.is_empty():
		_last_phase = phase
		_last_weather = weather
		return {"left": left, "arrived": 0, "unfilled": 0, "made_room": 0}

	var entries := _spawnable_entries()
	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed + cycle * 4 + phase

	var staying := _staying_by_marker()
	var leaving := _leaving_by_marker()
	var taken := _standing_ids()
	var arrived := 0
	var unfilled := 0
	var made_room := 0
	var slot := _next_slot
	for marker: ZoneMarker in markers:
		var pool := _pool_for(marker, entries, phase, weather)
		# Built once per marker and drained as it is drawn from, so a newcomer handed one
		# slot cannot be handed the next one as well.
		var newcomers := _newcomers(pool, taken)
		var wanted: int = marker.spawn_count - int(staying.get(marker.get_instance_id(), 0))

		if wanted <= 0:
			# THE ONE EVICTION. Only for a marker that is genuinely stuck: full, with nobody
			# already walking off it (a departure this same refresh is about to free a slot
			# on its own, and taking a second pony off the map for the same arrival would
			# empty the field), and with a newcomer who has nowhere else to go.
			if newcomers.is_empty() or int(leaving.get(marker.get_instance_id(), 0)) > 0:
				continue
			var resident := _evictable(marker, rng)
			if resident == null or not resident.leave():
				continue
			left += 1
			made_room += 1
			wanted = 1

		for i in range(wanted):
			var data: PonyData = null
			if not newcomers.is_empty():
				# One number off `rng` per pick, the same as a SpawnTable draw spends, so
				# which characters a slot is offered does not shift the rest of the stream.
				var pick := rng.randi_range(0, newcomers.size() - 1)
				data = newcomers[pick]
				newcomers.remove_at(pick)
			else:
				# Rebuilt per slot rather than once per marker, because the previous slot's
				# arrival is struck out of it. SpawnTable spends exactly one number from
				# `rng` per draw whatever it is handed, so the stream stays deterministic.
				var choices := _without(pool, taken)
				if choices.is_empty():
					unfilled += 1
					continue
				data = SpawnTableScript.new(choices, rng).draw()
				if data == null:
					push_error("Spawner: SpawnTable.draw() returned null for zone '%s' slot %d"
						% [marker.zone_id, i])
					continue
			taken[data.id] = true
			var pony := _spawn_one(data, marker, slot)
			if pony != null:
				_spawned.append(pony)
				_marker_by_pony[pony.get_instance_id()] = marker
				arrived += 1
			slot += 1

	_next_slot = slot
	_last_phase = phase
	_last_weather = weather
	# `player_position` is deliberately not read. Where a departing pony is discarded is her
	# own business: Pony.leave() measures the distance to the player she can actually see,
	# which is the same test her notice radius is stated against, and second-guessing it
	# from here would give two answers to one question. It is in the signature because the
	# caller has the position to hand and because a future "do not stand a replacement in
	# his face" rule belongs in this function and nowhere else.
	return {"left": left, "arrived": arrived, "unfilled": unfilled, "made_room": made_room}


## {id: true} for every pony standing on the map who is STAYING there. The set refresh()
## refuses to draw a second copy of.
func _standing_ids() -> Dictionary:
	var ids := {}
	for pony in get_spawned():
		if pony.is_leaving():
			continue
		var data: PonyData = pony.get_data()
		if data != null:
			ids[data.id] = true
	return ids


## The characters in `pool`, already cut down to this marker's zone and to the hour being
## drawn for, whose hours have JUST OPENED: not available at the pair this spawner last
## drew for, and standing nowhere on the map. The list the priority fill offers slots to
## before anybody else. Empty whenever the sky has not actually changed, which is what makes
## a repeated refresh do nothing.
func _newcomers(pool: Array[PonyData], taken: Dictionary) -> Array[PonyData]:
	var out: Array[PonyData] = []
	for data: PonyData in pool:
		if taken.has(data.id):
			continue
		if data.available(_last_phase, _last_weather):
			continue
		out.append(data)
	return out


## The staying resident of `marker` to send home so a newcomer can have her slot, or null if
## this marker has nobody it would be honest to move.
##
## UNCONDITIONAL RESIDENTS ONLY: empty `phases` and empty `weathers`, so she is drawable at
## every hour in every weather and can walk back in on the next refresh that has room. A
## pony who keeps hours of her own might not get another chance this session, and the point
## of the whole feature is to show MORE of the roster, not to trade one rare sighting for
## another.
##
## Picked off `rng` rather than taking the first, so which of an interchangeable few goes
## home is the hour's own decision and is stable for a given save, cycle and phase.
func _evictable(marker: ZoneMarker, rng: RandomNumberGenerator) -> CharacterBody3D:
	var candidates: Array[CharacterBody3D] = []
	for pony in get_spawned():
		if pony.is_leaving():
			continue
		var home: ZoneMarker = _marker_by_pony.get(pony.get_instance_id())
		if home != marker:
			continue
		var data: PonyData = pony.get_data()
		if data == null or not data.phases.is_empty() or not data.weathers.is_empty():
			continue
		candidates.append(pony)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## `pool` without the entries whose id is a key of `taken`.
func _without(pool: Array[PonyData], taken: Dictionary) -> Array[PonyData]:
	var result: Array[PonyData] = []
	for data: PonyData in pool:
		if not taken.has(data.id):
			result.append(data)
	return result


## The entries zoned for `marker` who can be drawn at this hour and in this weather.
func _pool_for(marker: ZoneMarker, entries: Array[PonyData], phase: int,
		weather: int) -> Array[PonyData]:
	var pool: Array[PonyData] = []
	for data: PonyData in entries:
		if not marker.zone_id in data.spawn_zones:
			continue
		if not data.available(phase, weather):
			continue
		pool.append(data)
	return pool


## {marker instance id: how many of its ponies are ALREADY on their way out}. The eviction
## fallback reads it: a marker with a departure in flight is about to have a free slot of its
## own, so it is not stuck and nobody there needs to be moved along.
func _leaving_by_marker() -> Dictionary:
	var counts := {}
	for pony in get_spawned():
		if not pony.is_leaving():
			continue
		var marker: ZoneMarker = _marker_by_pony.get(pony.get_instance_id())
		if marker == null or not is_instance_valid(marker):
			continue
		var key := marker.get_instance_id()
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


## {marker instance id: how many of its ponies are alive and NOT on their way out}.
func _staying_by_marker() -> Dictionary:
	var counts := {}
	for pony in get_spawned():
		if pony.is_leaving():
			continue
		var marker: ZoneMarker = _marker_by_pony.get(pony.get_instance_id())
		if marker == null or not is_instance_valid(marker):
			continue
		var key := marker.get_instance_id()
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


## How many stock ponies belong at `marker`: its own `stock_count`, clamped into its
## region's authored band. A marker whose zone has no RegionData (the open homestead) uses
## its own number as it stands.
##
## THE UPPER BOUND IS RAISED TO THE LOWER ONE IF A DATA FILE HAS THEM THE WRONG WAY ROUND.
## clampi() with max below min returns the MAX, so an authoring slip of stock_min 4,
## stock_max 2 would quietly empty a region down to 2 while its own file asked for at least
## 4; taking maxi() of the pair means a bad band reads as "at least stock_min" rather than
## as a silently under-populated field. A region .tres is hand authored and this is the one
## place its two numbers are ever compared.
func stock_budget(marker: ZoneMarker) -> int:
	if marker == null:
		return 0
	if _regions == null:
		_regions = RegionRegistryScript.new()
		_regions.load_all()
	var region: RegionData = _regions.by_id(marker.zone_id)
	if region == null:
		return maxi(0, marker.stock_count)
	return clampi(marker.stock_count, region.stock_min,
		maxi(region.stock_min, region.stock_max))


func stock_standing() -> int:
	var n := 0
	for pony in get_spawned():
		if pony.is_stock() and not pony.is_leaving():
			n += 1
	return n


func named_standing() -> int:
	var n := 0
	for pony in get_spawned():
		if not pony.is_stock() and not pony.is_leaving():
			n += 1
	return n


## Stand one stock pony at `marker`. Her personality is one of the three hidden base
## records and her colours are a palette triple, both drawn off `rng`. The stream mixes in
## engine instance ids upstream (_fill_stock, tick_stock), so the crowd is stable within a
## boot but MAY reshuffle across boots; that is fine for anonymous stock, and the named
## draw is the one the world seed actually pins.
func _spawn_stock(marker: ZoneMarker, slot: int, rng: RandomNumberGenerator) -> CharacterBody3D:
	var id: StringName = StockPaletteScript.IDS[rng.randi_range(0,
		StockPaletteScript.IDS.size() - 1)]
	var data: PonyData = _registry_for_stock().by_id(id)
	if data == null:
		return null
	# EVERY DRIFTER IS GENERATED: a fresh look off the stream, built on whichever donor
	# body the generator picked. The body that loads is the donor's, so that is the path
	# the assetless guard checks (docs/ci.md section 4: one calm skip, no push_error).
	var look := PonyGeneratorScript.generate(rng.randi(), _drifter_opts(marker, rng))
	var path := DonorTableScript.model_path(look.donor)
	if not ResourceLoader.exists(path):
		return null
	return _spawn_one(data, marker, slot, look.to_dict())


## Wild Drifters: mostly adults, a few foals, rare variants by region.
func _drifter_opts(marker: ZoneMarker, rng: RandomNumberGenerator) -> Dictionary:
	var opts := {}
	if rng.randf() < 0.12:
		opts["foal"] = true
	var rare: StringName = _rare_variant_for(marker)
	if rare != &"" and rng.randf() < 0.06:
		opts["variant"] = rare
	return opts


## The rare variant a marker's region can turn up, if any (GDD 4.2).
func _rare_variant_for(marker: ZoneMarker) -> StringName:
	var zone := String(marker.zone_id) if marker != null else ""
	match zone:
		"lake":
			return &"pearl"
		"nightmeadow":
			return &"starry"
		"everfree":
			return &"ember"
	return &""


## The registry hidden records resolve through. Loaded once and kept, like _entries.
func _registry_for_stock() -> PonyRegistry:
	if _stock_registry == null:
		_stock_registry = PonyRegistryScript.new()
		_stock_registry.load_all(pony_dir)
	return _stock_registry


## Top every marker up to its stock budget. Returns the next free slot number.
##
## THE CROWD IS ALLOWED TO REPEAT ITSELF. The map wide no duplicates rule exists so that
## seeing a named character is an event (game/world/spawner.gd's refresh() comment); two
## stock ponies of the same personality standing in one field is not a duplicate, it is a
## field with two ponies in it, which is the entire point of the crowd.
func _fill_stock(from_slot: int) -> int:
	var slot := from_slot
	for marker: ZoneMarker in get_markers():
		var want: int = stock_budget(marker) - _stock_at(marker)
		if want <= 0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = spawn_seed * 131 + marker.get_instance_id() % 100003
		for i in range(want):
			if _spawned.size() >= WORLD_PONY_BUDGET:
				break
			var pony := _spawn_stock(marker, slot, rng)
			if pony != null:
				_spawned.append(pony)
				_marker_by_pony[pony.get_instance_id()] = marker
			slot += 1
	return slot


## How many stock ponies are standing at `marker` and staying.
func _stock_at(marker: ZoneMarker) -> int:
	var n := 0
	for pony in get_spawned():
		if not pony.is_stock() or pony.is_leaving():
			continue
		if _marker_by_pony.get(pony.get_instance_id()) == marker:
			n += 1
	return n


## THE FIELD FILLS ITSELF BACK UP. Called every physics frame by ranch.gd while somebody is
## playing, and directly by the tests and the gates. A marker that is short of its budget
## banks `delta`; once it has banked STOCK_RESPAWN_SECONDS it stands ONE replacement and
## starts again, so emptying a field of four takes four waits rather than one. A marker at
## its budget banks nothing, so the timer never runs ahead of the need for it.
##
## Returns how many arrived, which is what a caller puts in a report line.
func tick_stock(delta: float) -> int:
	if delta <= 0.0:
		return 0
	var arrived := 0
	var slot := _next_slot
	for marker: ZoneMarker in get_markers():
		var key := marker.get_instance_id()
		if stock_budget(marker) - _stock_at(marker) <= 0:
			_stock_wait[key] = 0.0
			continue
		var waited: float = float(_stock_wait.get(key, 0.0)) + delta
		if waited < STOCK_RESPAWN_SECONDS:
			_stock_wait[key] = waited
			continue
		_stock_wait[key] = 0.0
		if _spawned.size() >= WORLD_PONY_BUDGET:
			continue
		var rng := RandomNumberGenerator.new()
		# The slot number is in the seed, so consecutive replacements at one marker are not
		# the same pony over and over.
		rng.seed = spawn_seed * 131 + key % 100003 + slot * 7919
		var pony := _spawn_stock(marker, slot, rng)
		slot += 1
		if pony != null:
			_spawned.append(pony)
			_marker_by_pony[pony.get_instance_id()] = marker
			arrived += 1
	_next_slot = slot
	return arrived


func get_markers() -> Array[ZoneMarker]:
	var result: Array[ZoneMarker] = []
	var root := get_node_or_null(zones_path)
	if root == null:
		return result
	for child in root.get_children():
		if child is ZoneMarkerScript:
			result.append(child)
	return result


## The wild ponies that are STILL IN THE WORLD, oldest first.
##
## PRUNED, NOT RAW, and that is a bug fix rather than tidiness. A captured pony is freed
## by the magic beam (magic_beam.gd's _settle_pony: her record goes in the bag and her
## node is queue_free'd), and this array went on holding the dangling reference. Anything
## that iterated it afterwards -- `for pony: CharacterBody3D in spawner.get_spawned()`,
## which is how ranch.gd and the Phase 1A integration driver both read it -- hit
## "Trying to assign invalid previously freed instance" the moment the player caught
## anything, because GDScript performs the typed assignment BEFORE the loop body's own
## is_instance_valid() guard can run. Found by playing the game, not by a gate: nothing
## in the project captured a pony and then re-read this list until Task 9 did.
##
## Pruning here rather than making every caller defensive: "who is still out there" is
## this node's own question to answer, and there is exactly one right answer to it.
##
## Returns a COPY, not `_spawned` itself: a caller that appended to or cleared the
## array it got back would be silently corrupting this node's own bookkeeping of who
## is out there, rather than just reading it. `.duplicate()` is a shallow copy -- the
## CharacterBody3D elements themselves are shared (as they must be; callers need the
## real pony nodes), only the array container is independent.
func get_spawned() -> Array[CharacterBody3D]:
	var live: Array[CharacterBody3D] = []
	var live_markers := {}
	for pony in _spawned:
		if not is_instance_valid(pony):
			continue
		live.append(pony)
		var key := pony.get_instance_id()
		if _marker_by_pony.has(key):
			live_markers[key] = _marker_by_pony[key]
	_spawned = live
	# Rebuilt rather than erased from, and in step with _spawned, so no stale entry can
	# outlive the pony it describes and hand refresh() a marker tally counting somebody who
	# is not out there any more.
	_marker_by_pony = live_markers
	return _spawned.duplicate()


## How many ponies had to be placed WITHOUT a ground hit. Must be zero: a non-zero
## count means the raycast is not finding the terrain (physics not stepped yet, wrong
## mask, or no collider at all), and the herd is standing at the marker's own height
## instead of on the ground.
func get_fallback_placements() -> int:
	return _fallback_placements


## Zone ids whose registry query returned nothing.
func get_empty_zones() -> Array[StringName]:
	return _empty_zones


## Ponies in the registry whose model_path does not resolve on this machine.
func get_unspawnable() -> Array[StringName]:
	return _unspawnable


## How many PonyData records the registry loaded, spawnable or not. Zero here means
## the roster itself could not be read -- a different and much worse problem than a
## roster whose models are missing.
func get_roster_size() -> int:
	return _roster.size()


## How many ponies the AUTHORED roster places in `zone`, regardless of whether their
## models exist on this machine.
func _zoned_in_roster(zone: StringName) -> int:
	var n := 0
	for data: PonyData in _roster:
		if zone in data.spawn_zones:
			n += 1
	return n


## Registry entries that can actually be built right now, sorted by id text.
##
## PonyRegistry deliberately KEEPS an entry whose model_path is broken (its own doc
## comment explains why: one bad path must not take a pony's stats and zones down
## with it), and PonyVisuals.build() is the choke point that refuses it -- loudly.
## Filtering here instead means an assetless checkout produces one calm report line
## rather than a push_error per pony per zone, which is what keeps the ranch's
## degraded mode legible in a CI log.
func _spawnable_entries() -> Array[PonyData]:
	if _entries_loaded:
		return _entries

	var registry := PonyRegistryScript.new()
	var by_id: Dictionary = registry.load_all(pony_dir)
	_roster = by_id.values()

	var result: Array[PonyData] = []
	for data: PonyData in by_id.values():
		if data.model_path.is_empty() or not ResourceLoader.exists(data.model_path):
			if not data.id in _unspawnable:
				_unspawnable.append(data.id)
			continue
		result.append(data)

	# See the class comment: String(), not the raw StringName. This is the fix for a
	# real nondeterminism bug, not a redundant cast.
	result.sort_custom(func(a: PonyData, b: PonyData) -> bool:
		return String(a.id) < String(b.id))
	_entries = result
	_entries_loaded = true
	return _entries


## One pony: drawn record, ground-found position, seeded RNG, layered collision. `look` is
## her palette triple plus her base model, or {} for a named pony whose look is her model.
func _spawn_one(data: PonyData, marker: ZoneMarker, slot: int,
		look: Dictionary = {}) -> CharacterBody3D:
	var pony: CharacterBody3D = PonyScene.instantiate()
	pony.name = "Pony%02d_%s" % [slot, data.id]
	pony.roam_radius = marker.roam_radius

	# Each pony gets her own generator, seeded from the world seed plus her slot, so
	# the map is reproducible AND no two ponies pick their wander targets in lockstep.
	var pony_rng := RandomNumberGenerator.new()
	pony_rng.seed = spawn_seed + slot * 7919
	pony.set_rng(pony_rng)

	pony.collision_layer = LayersScript.PONY
	# PONY_WALKABLE, not WALKABLE: WALKABLE plus the PEN_GATE bit a pen's gate leaf sits on.
	# Every pony carries it whether or not she has ever seen a pen -- a pony who acquired it
	# only on moving into one would walk out of the first pen she was ever put in.
	pony.collision_mask = LayersScript.PONY_WALKABLE
	var detection := pony.get_node_or_null("DetectionArea") as Area3D
	if detection != null:
		detection.collision_layer = LayersScript.INTERACTION
		# She notices the player. Nothing else. Masking for PROPS here would make
		# every tree she walks past read as "the player is here".
		detection.collision_mask = LayersScript.PLAYER

	# Position BEFORE add_child: Pony._ready() records wherever she is standing at
	# that moment as her roaming anchor, and a pony added at the origin and moved
	# afterwards spends the rest of her life being leashed back to the origin
	# (pony.gd's setup() doc says so explicitly).
	pony.position = to_local(_ground_point(marker, slot))
	add_child(pony)
	# BEFORE setup(), and that ordering is now load bearing. setup() is what builds the
	# body, and which base model it builds is a property of her look; set_stock() after the
	# fact could only re-tint a body that had already been built from the wrong mesh. It is
	# a no op for a named pony, who passes an empty look.
	if not look.is_empty():
		pony.set_stock(look)
	pony.setup(data)
	# AFTER setup(), so a listener may read get_data() straight off the signal's argument.
	pony_spawned.emit(pony)
	return pony


## A random point inside `marker`'s disc, on the ground, clear of props and of the
## ponies already placed. Uniform over the disc's AREA -- sqrt() on the radius --
## because without it every draw crowds the centre and the herd spawns in a knot.
func _ground_point(marker: ZoneMarker, slot: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	# Derived from the world seed and the slot rather than shared with the draw RNG,
	# so a re-roll here cannot shift which pony the NEXT slot draws.
	rng.seed = spawn_seed * 31 + slot

	var space := get_world_3d().direct_space_state
	var centre := marker.global_position
	var last := centre

	for attempt in range(PLACEMENT_ATTEMPTS):
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * marker.spawn_radius
		var candidate := centre + Vector3(cos(angle), 0.0, sin(angle)) * radius
		last = candidate

		var query := PhysicsRayQueryParameters3D.create(
			candidate + Vector3.UP * RAY_UP,
			candidate + Vector3.DOWN * RAY_DOWN,
			LayersScript.WORLD)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue

		var collider: Object = hit.get("collider")
		if collider is CollisionObject3D \
				and (collider as CollisionObject3D).collision_layer & LayersScript.PROPS != 0:
			# Inside a building or a tree canopy. Try somewhere else.
			continue

		var point: Vector3 = hit["position"]
		if _too_close(point):
			continue
		return point

	# Every attempt was rejected or missed. Fall back to the last candidate at the
	# marker's own height and COUNT IT -- ranch.gd fails the gate on a non-zero
	# count, so this can never quietly become the normal path.
	_fallback_placements += 1
	return Vector3(last.x, centre.y, last.z)


func _too_close(point: Vector3) -> bool:
	for other in _spawned:
		var d := Vector2(other.global_position.x - point.x, other.global_position.z - point.z)
		if d.length() < MIN_SEPARATION:
			return true
	return false
