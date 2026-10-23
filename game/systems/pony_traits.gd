class_name PonyTraits
extends RefCounted
## WHAT A PONY IS LIKE, NOT ONLY HOW SHE LOOKS (MISSION.md, "pony traits must matter
## mechanically"). Every generated Drifter has a favorite food and one quirk, and her race
## does something: so two ponies in the grass are two different decisions about who to
## catch, which pen she goes in, who she goes in with, and what to feed her.
##
## DERIVED, NOT STORED. Both come from her look's seed (the same seed that names her), so a
## pony caught before this file existed has them too, the same ones every time, and nothing
## in the save format changed. Named ponies get a quirk from a short canon list (Pinkie is
## a Social Butterfly) or, failing that, from their id.
##
## Every effect is a pure function here, so the rules have one home and one test file
## (game/test/test_pony_traits.gd); the pen, the beam, the pony and the race only ask.

const FOODS: Array[StringName] = [&"hay", &"carrot", &"apple", &"daisy", &"daffodil"]
const FOOD_WEIGHTS: Array[int] = [30, 22, 22, 14, 12]
const FOOD_PLURAL := {&"hay": "hay", &"carrot": "carrots", &"apple": "apples",
	&"daisy": "daisies", &"daffodil": "daffodils"}

const QUIRK_ORDER: Array[StringName] = [&"glutton", &"night_owl", &"social", &"loner",
	&"sparkler", &"skittish", &"escapee", &"sleepy", &"showoff"]
const QUIRKS := {
	&"glutton": {"name": "Glutton", "text": "eats twice as fast and makes half again as many gems"},
	&"night_owl": {"name": "Night Owl", "text": "makes twice the gems at night and half by day"},
	&"social": {"name": "Social Butterfly", "text": "is a friend to every pony in her pen"},
	&"loner": {"name": "Loner", "text": "frets in a crowd of three, and Blooms fastest on her own"},
	&"sparkler": {"name": "Sparkler", "text": "turns a quarter of her gems a grade finer"},
	&"skittish": {"name": "Skittish", "text": "spots you from twice as far, but gives up quickly in the Scoop"},
	&"escapee": {"name": "Escape Artist", "text": "hops a Paddock fence at night (a Big or Grand Pen holds her)"},
	&"sleepy": {"name": "Sleepyhead", "text": "never frets at night, and Blooms slowly"},
	&"showoff": {"name": "Show-off", "text": "runs a faster race"},
}
## Canon ponies whose quirk is who they are.
const CANON := {
	&"pinkiepie": &"social", &"fluttershy": &"skittish", &"rainbowdash": &"showoff",
	&"twilight": &"night_owl", &"rarity": &"sparkler", &"applebloom": &"escapee",
	&"scootaloo": &"escapee", &"sweetiebelle": &"escapee", &"derpyhooves": &"glutton",
	&"lyra": &"social", &"octavia": &"loner", &"vinylscratch": &"night_owl",
	&"maudpie": &"loner", &"pinkamena": &"loner", &"trixie": &"showoff", &"spitfire": &"showoff", &"applejack": &"glutton",
}

## Set by the ranch at each phase change (the night-dependent quirks read it).
static var night := false
## Off: nopony has a quirk. For tests of the pen, production and Bloom rules on their own
## (the traits have test_pony_traits.gd); the game never turns it off.
static var quirks_enabled := true
static var _cache: Dictionary = {}


static func _rng_for(key: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key * 2654435761 + 977)
	return rng


## Her favorite food. A Drifter's is drawn from her seed; a named pony keeps her record's.
static func favorite_of(inst: PonyInstance) -> StringName:
	if inst == null:
		return &"hay"
	if inst.is_stock():
		var seed_value := int(inst.stock.get("seed", 0))
		if seed_value == 0:
			return &"hay"
		var rng := _rng_for(seed_value)
		var roll := rng.randi_range(1, 100)
		for i in FOODS.size():
			roll -= FOOD_WEIGHTS[i]
			if roll <= 0:
				return FOODS[i]
		return &"hay"
	var data := inst.data()
	if data != null and not data.favorite_foods.is_empty():
		return data.favorite_foods[0]
	return &"hay"


## Her quirk (a key of QUIRKS), or &"" for a pony with none (only an unseeded stock pony).
static func quirk_of(inst: PonyInstance) -> StringName:
	if inst == null or not quirks_enabled:
		return &""
	var key := String(inst.uid)
	if _cache.has(key):
		return _cache[key]
	var q := quirk_for(inst.stock, inst.data_id)
	if key != "":
		_cache[key] = q
	return q


## The same answer from what a wild body carries (her stock look, or her record's id).
static func quirk_for(stock: Dictionary, data_id: StringName) -> StringName:
	if not quirks_enabled:
		return &""
	if not stock.is_empty():
		var seed_value := int(stock.get("seed", 0))
		if seed_value == 0:
			return &""
		var rng := _rng_for(seed_value + 31)
		return QUIRK_ORDER[rng.randi() % QUIRK_ORDER.size()]
	if CANON.has(data_id):
		return CANON[data_id]
	if data_id == &"":
		return &""
	return QUIRK_ORDER[absi(hash(String(data_id))) % QUIRK_ORDER.size()]


## A wild body's favorite (her stock seed, or her record's first favorite).
static func favorite_for(stock: Dictionary, data: PonyData) -> StringName:
	if not stock.is_empty():
		var inst := PonyInstance.new()
		inst.stock = stock
		return favorite_of(inst)
	if data != null and not data.favorite_foods.is_empty():
		return data.favorite_foods[0]
	return &"hay"


static func race_of(inst: PonyInstance) -> StringName:
	if inst == null:
		return &"earth"
	if inst.is_stock():
		return StringName(str(inst.stock.get("race", "earth")))
	var data := inst.data()
	return StringName(str(data.get("race"))) if data != null and data.get("race") != null else &"earth"


static func quirk_name(q: StringName) -> String:
	return str((QUIRKS.get(q, {}) as Dictionary).get("name", ""))


static func quirk_text(q: StringName) -> String:
	return str((QUIRKS.get(q, {}) as Dictionary).get("text", ""))


## "Night Owl, loves carrots" (what the catch toast and the Monocle say).
static func describe(inst: PonyInstance) -> String:
	var q := quirk_of(inst)
	var food: String = FOOD_PLURAL.get(favorite_of(inst), "hay")
	if q == &"":
		return "loves %s" % food
	return "%s, loves %s" % [quirk_name(q), food]


# --- the rules --------------------------------------------------------------------------

static func hunger_mult(q: StringName) -> float:
	return 2.0 if q == &"glutton" else 1.0


static func gem_mult(q: StringName, is_night: bool) -> float:
	match q:
		&"glutton":
			return 1.5
		&"night_owl":
			return 2.0 if is_night else 0.5
	return 1.0


## The chance that one of her gems comes out a grade finer.
static func sparkle_chance(q: StringName) -> float:
	return 0.25 if q == &"sparkler" else 0.0


static func is_friend_to_all(q: StringName) -> bool:
	return q == &"social"


## Extra happiness she loses a second from her own temperament (a loner in a crowd).
static func fret_per_second(q: StringName, pen_count: int, is_night: bool) -> float:
	if q == &"loner" and pen_count >= 3:
		return 1.0 / 300.0
	return 0.0


## Whether her happiness is spared the hungry decay tonight.
static func calm_at_night(q: StringName, is_night: bool) -> bool:
	return q == &"sleepy" and is_night


static func bloom_mult(q: StringName, race: StringName, pen_count: int) -> float:
	var m := 1.0
	if race == &"earth":
		m *= 1.2
	match q:
		&"loner":
			if pen_count <= 1:
				m *= 1.5
		&"sleepy":
			m *= 0.75
	return m


static func notice_mult(q: StringName) -> float:
	return 2.0 if q == &"skittish" else 1.0


## A skittish pony's struggle is short: she gives up in the Scoop almost at once.
static func easy_hold(q: StringName) -> bool:
	return q == &"skittish"


static func escapes_from(q: StringName, plot_id: StringName, is_night: bool) -> bool:
	return q == &"escapee" and is_night and plot_id == &"pen_small"


static func race_mult(q: StringName) -> float:
	return 1.3 if q == &"showoff" else 1.0


## Running away: a pegasus flutters off faster than you can follow on hoof.
static func flee_mult(race: StringName) -> float:
	return 1.35 if race == &"pegasus" else 1.0


## A unicorn startled at close range blinks a few metres away, once per encounter.
static func blinks(race: StringName) -> bool:
	return race == &"unicorn"
