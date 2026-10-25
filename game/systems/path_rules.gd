class_name PathRules
extends RefCounted
## THE RULES OF ACT THREE (STORY.md sections 4 and 5), as static functions over Story, so
## every number is here and under test (game/test/test_path_rules.gd) and the world only
## reports what happened: a delivery, a Bloom, a raid, a pylon cut, a dawn.
##
## Factory path: contracts, ranks, the Jubilee order.
## Rescue path: Heat and what it costs, pylons, the Lantern Line, allies, Placement.
## Everything is kept in Story.vars and Story flags, so it saves with the story.

const StoryV1Script := preload("res://systems/story_v1.gd")

# --- the Factory path ----------------------------------------------------------------

const RANKS: Array[String] = ["Steward", "Senior Steward", "Supervisor", "Regional Director"]
## Contracts completed to hold each rank (index = rank). Signing makes you Senior Steward.
const RANK_AT: Array[int] = [0, 0, 2, 4]
const DIRECTOR := 3
const JUBILEE_ORDER := 6
const JUBILEE_VIVID := 2
## A coat this saturated is "vivid" (Yield Lens: three times the pay); under PASTEL, pastel.
## 0.37, NOT THE 0.55 IT WAS: the generator's coat swatches (data/pony_gen.tres) top out at
## 0.45, so at 0.55 no everyday Drifter was ever vivid and the vivid contract and the
## Jubilee order waited on the rare starry Nightmeadow variant alone (found by the real-input
## playthrough, docs/playtest_fixes/playthrough.md). At 0.37 the brightest five of the 24
## swatches count, about one Drifter in five.
const VIVID := 0.37
const PASTEL := 0.4

## A contract: {want, kind ("any", "pastel", "vivid"), bonus, got}.
static func contract(story: Story) -> Dictionary:
	var c: Variant = story.get_var("contract", {})
	if c is Dictionary and not (c as Dictionary).is_empty():
		return c
	return {}


static func rank(story: Story) -> int:
	return int(story.get_var("rank", 0))


static func rank_name(story: Story) -> String:
	return RANKS[clampi(rank(story), 0, RANKS.size() - 1)]


## The next contract on the board, from how many are done (deterministic: a save and a
## headless run see the same board).
static func next_contract(done: int) -> Dictionary:
	var kinds := ["any", "pastel", "vivid", "any", "pastel"]
	var kind: String = kinds[done % kinds.size()]
	var want := 3 + done
	if kind == "vivid":
		want = 2 + done / 2
	return {"want": want, "kind": kind, "bonus": 400 + 300 * done, "got": 0}


static func post_contract(story: Story) -> void:
	if not contract(story).is_empty():
		return
	if story.has_flag("climax_done"):
		# Post-game (STORY.md section 6): gray, rich, and the contracts keep coming.
		story.set_var("contract", next_contract(int(story.get_var("contracts_done", 0))))
		return
	if story.has_flag("jubilee_ready"):
		return
	if rank(story) >= DIRECTOR:
		story.set_var("contract", {"want": JUBILEE_ORDER, "kind": "jubilee", "bonus": 5000,
			"got": 0, "vivid": 0})
	else:
		story.set_var("contract", next_contract(int(story.get_var("contracts_done", 0))))


static func is_vivid(coat: Color) -> bool:
	return coat.s >= VIVID


static func is_pastel(coat: Color) -> bool:
	return coat.s < PASTEL


static func contract_line(story: Story) -> String:
	var c := contract(story)
	if c.is_empty():
		return ""
	if c.kind == "jubilee":
		return "THE JUBILEE ORDER: %d ponies, %d of them vivid (%d/%d, vivid %d/%d)" % [
			c.want, JUBILEE_VIVID, c.got, c.want, int(c.get("vivid", 0)), JUBILEE_VIVID]
	var what := "ponies" if c.kind == "any" else "%s ponies" % c.kind
	return "Contract: %d %s by collection day, bonus %d (%d/%d)" % [c.want, what, c.bonus, c.got, c.want]


## A pony delivered on the Factory path. Returns {bonus, rank_up, jubilee_ready} for the
## world to show; the bonus is the caller's to credit.
static func factory_delivery(story: Story, coat: Color) -> Dictionary:
	var out := {"bonus": 0, "rank_up": false, "jubilee_ready": false}
	if StoryV1Script.path(story) != StoryV1Script.PATH_FACTORY:
		return out
	post_contract(story)
	var c := contract(story)
	if c.is_empty():
		# The Jubilee order is filled: nothing left on the board.
		return out
	var counts := false
	match str(c.kind):
		"any", "jubilee":
			counts = true
		"pastel":
			counts = is_pastel(coat)
		"vivid":
			counts = is_vivid(coat)
	if not counts:
		return out
	c.got = int(c.got) + 1
	if c.kind == "jubilee" and is_vivid(coat):
		c.vivid = int(c.get("vivid", 0)) + 1
	story.set_var("contract", c)
	var met := int(c.got) >= int(c.want)
	if c.kind == "jubilee":
		met = met and int(c.get("vivid", 0)) >= JUBILEE_VIVID
		if met:
			story.set_flag("jubilee_ready")
			story.set_var("contract", {})
			out.jubilee_ready = true
			out.bonus = int(c.bonus)
		return out
	if met:
		out.bonus = int(c.bonus)
		var done := story.add_var("contracts_done")
		story.set_var("contract", {})
		var r := rank(story)
		while r + 1 < RANKS.size() and done >= RANK_AT[r + 1]:
			r += 1
		if r != rank(story):
			story.set_var("rank", r)
			out.rank_up = true
		post_contract(story)
	return out


## Pay for one delivery on the Factory path: doubled stipend, and the Yield Lens' vivid
## premium.
static func factory_pay(story: Story, base: int, coat: Color, has_lens: bool) -> int:
	var mult := int(story.get_var("stipend_mult", 1))
	var pay := base * maxi(mult, 1)
	if has_lens and is_vivid(coat):
		pay *= 3
	return pay


# --- the Rescue path -----------------------------------------------------------------

const HEAT_MAX := 100
const HEAT := {
	"raid": 12,        # each pony freed from an Intake Corral
	"spotted": 8,      # a Collector lantern caught you
	"lantern": 2,      # a pony walked out along the Lantern Line
	"missed_quota": 10,
	"pylon": -15,      # a pylon cut
	"dye": -6,         # a rescued pony repainted in the Dye Vat
	"dawn": -3,        # every dawn, Heat cools a little
}
## What Heat costs at a collection day, worst first.
const FINE_AT := 40
const PADLOCK_AT := 65
const TAKE_AT := 85
const FINE := 200
const PYLONS: Array[String] = ["pylon_meadow", "pylon_orchard", "pylon_lake", "pylon_everfree"]


static func heat(story: Story) -> int:
	return int(story.get_var("heat", 0))


static func add_heat(story: Story, what: String, times: int = 1) -> int:
	if StoryV1Script.path(story) != StoryV1Script.PATH_RESCUE:
		return heat(story)
	var h := clampi(heat(story) + int(HEAT.get(what, 0)) * times, 0, HEAT_MAX)
	story.set_var("heat", h)
	return h


## A Bloom after the reveal is a rescue on either path: a marked pony cannot be drained.
## On the Rescue path that is the defence; on the Factory path it is the "secretly Bloomed"
## count that makes Gray Gold (STORY.md section 6).
static func rescue_bloom(story: Story, uid: String = "") -> void:
	if StoryV1Script.revealed(story):
		count_rescue(story, uid)


## One pony rescued, counted once however many ways she was saved (a Bloom, then the
## Lantern Line). `uid` "" always counts (ponies the world never named, like the freed
## line in Lights Out).
static func count_rescue(story: Story, uid: String = "", n: int = 1) -> bool:
	if uid != "":
		var seen: Array = story.get_var("rescued_uids", [])
		if uid in seen:
			return false
		seen.append(uid)
		story.set_var("rescued_uids", seen)
	story.add_var("rescued", n)
	return true


## A marked pony sent down the Lantern Line: a permanent rescue. Unmarked ones cannot go
## (they would be found).
static func send_down_line(story: Story, marked: bool, uid: String = "") -> bool:
	if StoryV1Script.path(story) != StoryV1Script.PATH_RESCUE or not marked:
		return false
	count_rescue(story, uid)
	story.add_var("sent")
	add_heat(story, "lantern")
	return true


static func pylons_cut(story: Story) -> int:
	return (story.get_var("pylons", []) as Array).size()


static func cut_pylon(story: Story, id: String) -> bool:
	if StoryV1Script.path(story) != StoryV1Script.PATH_RESCUE or not (id in PYLONS):
		return false
	var cut: Array = story.get_var("pylons", [])
	if id in cut:
		return false
	cut.append(id)
	story.set_var("pylons", cut)
	story.set_var("pylons_cut", cut.size())
	add_heat(story, "pylon")
	return true


static func lights_out_ready(story: Story) -> bool:
	return StoryV1Script.path(story) == StoryV1Script.PATH_RESCUE and pylons_cut(story) >= PYLONS.size()


## A collection day on the Rescue path: what Heat costs. Returns {fine, padlock, take,
## placed}; the world applies them. Heat at the maximum through a collection day is the
## Placement ending (STORY.md section 6).
static func rescue_collection_day(story: Story, delivered_this_period: int) -> Dictionary:
	var out := {"fine": 0, "padlock": false, "take": false, "placed": false}
	if StoryV1Script.path(story) != StoryV1Script.PATH_RESCUE:
		return out
	if delivered_this_period <= 0:
		add_heat(story, "missed_quota")
	var h := heat(story)
	if h >= HEAT_MAX:
		story.set_flag("placed")
		out.placed = true
		return out
	if h >= FINE_AT:
		out.fine = FINE
	if h >= PADLOCK_AT:
		out.padlock = true
	if h >= TAKE_AT:
		out.take = true
	return out


## Ally recruitment conditions (each is a conversation once its condition holds).
static func ally_ready(story: Story, ally: String) -> bool:
	if StoryV1Script.path(story) != StoryV1Script.PATH_RESCUE or story.has_flag(ally):
		return false
	match ally:
		"ally_pip":
			return int(story.get_var("raids", 0)) >= 1
		"ally_bramble":
			return int(story.get_var("dyed", 0)) >= 1
		"ally_fennel":
			return story.has_flag("intake_ledger")
	return false
