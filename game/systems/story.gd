class_name Story
extends RefCounted
## WHERE THE PLAYER IS IN THE ARC, AS SAVED STATE. A chapter, a flag set, four counters and
## the mail log; no scene, no clock, no RNG, so the whole of it is GUT testable in
## milliseconds (game/test/test_story.gd), the same discipline game/systems/ledger.gd and
## game/systems/compendium.gd are built under.
##
## --- THE COUNTERS ARE THINGS THE GAME ALREADY EMITS -----------------------------------
##
## The design doc: "Chapter advances on triggers the game already emits: deliveries made,
## collection days passed, named ponies delivered". So this object counts exactly those,
## told by game/world/ranch.gd at the moment each happens, rather than reaching into the
## Ledger for numbers that mean something slightly different. Ledger.shipments is the
## Company's count of stock received; `deliveries` here is the story's count of the same
## event, and keeping them separate is what lets a later slice change one without silently
## re-timing every letter in the game.
##
## SURVEY_DAYS IS THE ONE COUNTER THAT CAN BE UNDER ZERO. It is "collection days since she
## answered the Survey", and an unanswered Survey answers -1, which is below every
## threshold a beat can carry. That is the whole of "the letter can sit unanswered forever
## and the beat never fires", expressed as arithmetic rather than as a special case.
##
## --- THE LADDER STOPS AT WEATHER IN THIS SLICE ----------------------------------------
##
## CONTACT, COMPANY and RESISTANCE are in the enum because the save has to be able to hold
## them and because the authored COMPANY letters name them. Nothing here can reach them:
## LADDER has one row. Slice 4 appends CONTACT's row (the spec's CONTACT_DELIVERIES, 6,
## and a named delivery or three collection days) and the fork; no letter and no save
## written by this slice needs a migration when it does.
##
## NOTHING HERE EVER FREES, HARMS OR MOVES A PONY. It records that one left by the
## departure path and what the Company chose to call the colour on the receipt.
##
## A LETTER NEVER CHANGES MEANING AFTER IT IS POSTED. post() may carry an optional `params`
## dictionary, frozen into the mail log entry at that moment; mail_params() hands it back
## unchanged. Ranch.mail_rows() renders a posted letter against its own frozen params rather
## than against whatever the world says right now, which is what keeps a receipt naming the
## pony it was actually about instead of whichever pony the Survey happens to name today.
## Absent (the field a save written before this existed has none of) defaults to an empty
## dictionary, which from_dict() tolerates the same way it tolerates every other optional
## field.
##
## Preloaded by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd: the class cache lives in the gitignored game/.godot/ and a
## fresh clone has not built it yet.

## Chapters, in order. The save holds the INDEX; the authored letters name the STRING, so a
## .tres that names a chapter this build does not have is a loud failure in story_test
## rather than a silent zero.
enum Chapter { SUNNY, WEATHER, CONTACT, COMPANY, RESISTANCE }

## The kinds of trigger a StoryBeat may carry. CHAPTER is "as soon as the chapter is
## reached", and its counter is always 0 so any threshold of 0 is met on arrival.
enum Trigger { CHAPTER, DELIVERIES, COLLECTION_DAYS, NAMED_DELIVERIES, SURVEY_DAYS }

const CHAPTER_NAMES: Array[String] = ["SUNNY", "WEATHER", "CONTACT", "COMPANY", "RESISTANCE"]
const TRIGGER_NAMES: Array[String] = ["CHAPTER", "DELIVERIES", "COLLECTION_DAYS",
	"NAMED_DELIVERIES", "SURVEY_DAYS"]

## Deliveries that turn SUNNY into WEATHER. Three, for a pacing reason with a test on it:
## the spec puts the first collection day one real hour in and the fork about three
## sessions in, so the letters have to start going strange while the player is still
## pleased with herself, not five sessions later.
const WEATHER_DELIVERIES := 3

## THE LADDER, one row per chapter change this build can make. See the class comment for
## why it is one row long.
const LADDER: Array[Dictionary] = [
	{"chapter": Chapter.WEATHER, "kind": Trigger.DELIVERIES, "threshold": WEATHER_DELIVERIES},
]

## What the Survey pays for answering, and what the coupon is worth. Paid by ranch.gd
## through Economy.grant() and Inventory.add(), which are the seams every other reward in
## the game already flows through; no money arithmetic lives here.
const SURVEY_BONUS_BITS := 50
const SURVEY_COUPON_ITEM := &"hay"
const SURVEY_COUPON_COUNT := 3

## The words the Company's receipts use for a colour. A fixed list indexed by a hash of the
## character's id: the same pony is always the same colour, on every machine and in every
## save, and nothing here ever rolls anything.
const SPECTRA_COLOURS: Array[String] = ["rose", "amber", "citrine", "viridian", "cobalt",
	"indigo", "violet"]

## Emitted when the chapter actually moves, with the chapter it moved TO. Not for an
## advance() that changed nothing, matching Compendium.changed's rule.
signal chapter_changed(chapter: int)

## Emitted once per beat actually posted, with its id, so a mailbox flag and a HUD line can
## hang off one event.
signal mail_posted(id: StringName)

var chapter: int = Chapter.SUNNY

## String keys, bool values. Plain and untyped for GameState.unlocks' reason: these are
## assigned dynamically from the ranch and from tests.
var flags: Dictionary = {}

var deliveries := 0
var named_deliveries := 0
var collection_days := 0

## `collection_days` at the moment she answered the Survey, or -1 while she has not.
var survey_period := -1

## The cycle the Priority Requisition was posted on, or -1. The collector calls at the first
## DAWN of a LATER cycle, exactly as Ledger.pending_punishment_cycle makes the collector's
## knock land a cycle after his letter; a requisition served in the same breath as its own
## letter is not the beat the spec describes.
var requisition_cycle := -1

## Who she named on the Survey: {"uid": String, "data_id": String, "name": String,
## "coat": String}. SAVED, because slices 4 and 6 read it: the fork's first raid can bring
## her home if the Requisition never fired, and the Factory's window is her.
var survey_choice: Dictionary = {}

## The last named pony delivered: {"name": String, "colour": String}. The receipt that
## lists her beside a colour is written months of play before anybody understands it, so
## the two strings it needs travel with the save rather than being recomputed from a world
## that no longer has her in it.
var last_named: Dictionary = {}

## The mail log, oldest first: [{"id": String, "read": bool, "reply": String}]. Letters are
## kept forever; re-reading old mail is the whole point of the paper channel.
var mail: Array = []


static func chapter_index(name: StringName) -> int:
	return CHAPTER_NAMES.find(String(name))


static func trigger_index(name: StringName) -> int:
	return TRIGGER_NAMES.find(String(name))


## The Company's word for her colour. Deterministic, and deliberately not a property of the
## pony: it is what the paperwork says, which is the joke.
static func spectra_colour(data_id: StringName) -> String:
	var key: String = String(data_id)
	if key.is_empty():
		return SPECTRA_COLOURS[0]
	return SPECTRA_COLOURS[absi(hash(key)) % SPECTRA_COLOURS.size()]


# --- the counters ------------------------------------------------------------------------

## One pony left by the departure path. `named` is false for the crowd, in which case the
## other two arguments are ignored.
func note_delivery(named: bool, display_name: String = "", data_id: StringName = &"") -> void:
	deliveries += 1
	if not named:
		return
	named_deliveries += 1
	last_named = {"name": display_name, "colour": spectra_colour(data_id)}


func note_collection_day() -> void:
	collection_days += 1


## The value a beat's threshold is measured against. See the class comment for why
## SURVEY_DAYS can answer -1.
func counter(kind: int) -> int:
	match kind:
		Trigger.CHAPTER:
			return 0
		Trigger.DELIVERIES:
			return deliveries
		Trigger.COLLECTION_DAYS:
			return collection_days
		Trigger.NAMED_DELIVERIES:
			return named_deliveries
		Trigger.SURVEY_DAYS:
			return -1 if survey_period < 0 else collection_days - survey_period
	return -1


## Climb the ladder if this build's next rung is met. Returns whether the chapter moved.
func advance() -> bool:
	var moved := false
	for rung: Dictionary in LADDER:
		var next: int = int(rung["chapter"])
		if chapter >= next:
			continue
		if counter(int(rung["kind"])) < int(rung["threshold"]):
			break
		chapter = next
		moved = true
		chapter_changed.emit(chapter)
	return moved


# --- flags -------------------------------------------------------------------------------

func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value


# --- the mail log ------------------------------------------------------------------------

func has_mail(id: StringName) -> bool:
	return _entry(id) != null


## Post `id`, unread. Returns false, changing nothing, for a beat already in the log: a
## letter arrives exactly once. `params` is frozen into the entry AS OF THIS MOMENT and
## handed back unchanged by mail_params(): the caller's snapshot of the world at post time,
## not a live reference to it.
func post(id: StringName, params: Dictionary = {}) -> bool:
	if String(id).is_empty() or has_mail(id):
		return false
	mail.append({"id": String(id), "read": false, "reply": "", "params": params.duplicate(true)})
	mail_posted.emit(id)
	return true


func mail_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in mail:
		out.append(StringName(String((entry as Dictionary).get("id", ""))))
	return out


func unread_count() -> int:
	var n := 0
	for entry in mail:
		if not bool((entry as Dictionary).get("read", false)):
			n += 1
	return n


func is_read(id: StringName) -> bool:
	var entry: Variant = _entry(id)
	return entry != null and bool((entry as Dictionary).get("read", false))


## What `id` was rendered against at post time, or an empty dictionary for a letter posted
## before this field existed (a pre-fix save) or posted with none. Empty is a real answer,
## not an error: the caller falls back to a live render for it, the same as this letter has
## always rendered.
func mail_params(id: StringName) -> Dictionary:
	var entry: Variant = _entry(id)
	if entry == null:
		return {}
	var raw: Variant = (entry as Dictionary).get("params", {})
	return (raw as Dictionary).duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}


## Returns whether THIS call is the one that marked it, so a caller can tell "she just
## opened it" from "she opened it last week" without a second lookup.
func mark_read(id: StringName) -> bool:
	var entry: Variant = _entry(id)
	if entry == null or bool((entry as Dictionary).get("read", false)):
		return false
	(entry as Dictionary)["read"] = true
	return true


## What she answered on `id`, or "" for a letter with no reply control or no answer yet.
func replied_to(id: StringName) -> String:
	var entry: Variant = _entry(id)
	return "" if entry == null else String((entry as Dictionary).get("reply", ""))


## Record an answer. Refuses an empty answer and refuses to overwrite one, because a reply
## control that could be answered twice is a bonus that could be paid twice.
func record_reply(id: StringName, reply: String) -> bool:
	if reply.is_empty():
		return false
	var entry: Variant = _entry(id)
	if entry == null or not String((entry as Dictionary).get("reply", "")).is_empty():
		return false
	(entry as Dictionary)["reply"] = reply
	return true


func _entry(id: StringName) -> Variant:
	var key: String = String(id)
	for entry in mail:
		if String((entry as Dictionary).get("id", "")) == key:
			return entry
	return null


# --- the Survey --------------------------------------------------------------------------

func survey_answered() -> bool:
	return survey_period >= 0


## She named a pony. `choice` carries "uid", "data_id", "name" and "coat", all Strings.
## Once only; the second call changes nothing and answers false.
func answer_survey(choice: Dictionary) -> bool:
	if survey_answered():
		return false
	survey_choice = {
		"uid": String(choice.get("uid", "")),
		"data_id": String(choice.get("data_id", "")),
		"name": String(choice.get("name", "")),
		"coat": String(choice.get("coat", "")),
	}
	survey_period = collection_days
	set_flag("survey_answered")
	return true


# --- serialisation -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	# NOT NAMED `log`: that is a GDScript built in (the logarithm) and shadowing it is a
	# warning this project treats as noise it does not want.
	var entries: Array = []
	for entry in mail:
		var row: Dictionary = entry
		var params: Variant = row.get("params", {})
		entries.append({
			"id": String(row.get("id", "")),
			"read": bool(row.get("read", false)),
			"reply": String(row.get("reply", "")),
			"params": (params as Dictionary).duplicate(true) if typeof(params) == TYPE_DICTIONARY
				else {},
		})
	var saved_flags: Dictionary = {}
	for key in flags:
		saved_flags[String(key)] = bool(flags[key])
	return {
		"chapter": chapter,
		"flags": saved_flags,
		"deliveries": deliveries,
		"named_deliveries": named_deliveries,
		"collection_days": collection_days,
		"survey_period": survey_period,
		"requisition_cycle": requisition_cycle,
		"survey_choice": survey_choice.duplicate(true),
		"last_named": last_named.duplicate(true),
		"mail": entries,
	}


## Rebuild from to_dict()'s output, or from what JSON.parse_string hands back, which is the
## same thing with every number as a float. Every field is optional and falls back to a
## brand new story's value, which is what makes a save written before this key existed load
## without a migration step; and every field is CLAMPED rather than trusted, so a hand
## edited file cannot produce a chapter this build does not have or a negative counter.
static func from_dict(d: Dictionary) -> Story:
	var out := Story.new()
	out.chapter = clampi(int(d.get("chapter", Chapter.SUNNY)), Chapter.SUNNY,
		Chapter.RESISTANCE)
	out.deliveries = maxi(0, int(d.get("deliveries", 0)))
	out.named_deliveries = maxi(0, int(d.get("named_deliveries", 0)))
	out.collection_days = maxi(0, int(d.get("collection_days", 0)))
	out.survey_period = maxi(-1, int(d.get("survey_period", -1)))
	out.requisition_cycle = maxi(-1, int(d.get("requisition_cycle", -1)))

	var saved_flags: Variant = d.get("flags", {})
	if typeof(saved_flags) == TYPE_DICTIONARY:
		for key in (saved_flags as Dictionary):
			out.flags[String(key)] = bool((saved_flags as Dictionary)[key])

	out.survey_choice = _string_map(d.get("survey_choice", {}))
	out.last_named = _string_map(d.get("last_named", {}))

	var saved_mail: Variant = d.get("mail", [])
	if typeof(saved_mail) == TYPE_ARRAY:
		for entry in (saved_mail as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = entry
			var id: String = String(row.get("id", ""))
			if id.is_empty() or out.has_mail(StringName(id)):
				continue
			out.mail.append({
				"id": id,
				"read": bool(row.get("read", false)),
				"reply": String(row.get("reply", "")),
				"params": _params_map(row.get("params", {})),
			})
	return out


static func _string_map(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key in (value as Dictionary):
		out[String(key)] = String((value as Dictionary)[key])
	return out


## A frozen letter's params, off JSON.parse_string's answer or off to_dict()'s own. Every
## number a StoryBeat renders (count/quota/balance) travels as a whole float once it has
## been through JSON, so it is cast back to int here; a String stays a String. Not TYPED to
## a fixed key set, because Story does not know StoryBeat's placeholder names and should
## not have to: an unrecognised key is simply carried through, the same tolerance
## _string_map() and the rest of from_dict() give every other optional field.
static func _params_map(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key in (value as Dictionary):
		var v: Variant = (value as Dictionary)[key]
		if typeof(v) == TYPE_FLOAT and v == floorf(v):
			out[String(key)] = int(v)
		else:
			out[String(key)] = v
	return out
