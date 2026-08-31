class_name PonyInstance
extends RefCounted
## ONE PONY YOU ACTUALLY OWN -- the keystone of Phase 1B, and the thing that was missing.
##
## THE BUG THIS CLASS EXISTS TO FIX. Until now, capturing a pony put her PonyData
## (game/systems/pony_data.gd) into the saddlebag. PonyData is the CHARACTER definition:
## static, shared, exactly one per .tres on the roster. So catching two Twilights put two
## pointers to the same record in the bag -- a reviewer inspected it and saw literally
## `contents=[twilight, twilight]`. There was no per-individual anything, which meant
## happiness, hunger and a production timer had nowhere to live and "feed the hungry one"
## was not even expressible. Everything else in Phase 1B (pens, needs, production, saving)
## hangs off this distinction:
##
##   PonyData      the species entry. Authored, shared, read-only at runtime.
##   PonyInstance  one individual. Minted at capture, mutable, saved, traded.
##
## An instance never holds a PonyData reference; it holds her `data_id` and resolves it on
## demand (see data() / resolve_data()). That is deliberate and it is what makes a save
## file portable: the record on the receiving machine is whatever that build's roster says
## it is, and a data_id the receiver has never heard of resolves to NULL rather than to a
## dangling pointer or a crash.
##
## RefCounted, no scene tree, no Node -- so the whole of it is GUT-testable in
## milliseconds (game/test/test_pony_instance.gd), the pattern every system under
## game/systems/ follows.
##
## --- THE UID SCHEME, AND THE TWO FOOTGUNS IT IS BUILT TO AVOID ------------------------
##
## A uid is `<data_id>#<serial>`, zero-padded to six digits: `twilight#000001`. The serial
## is a plain monotonic integer counter, global across the whole roster, minted by
## create(). So the second pony ever caught is `fluttershy#000002` whether or not she is
## the same character as the first.
##
##   1. NOT DERIVED FROM `Time`. The obvious alternative -- a timestamp, or a hash of one
##      -- is different on every run, so a seeded, reproducible world stops being
##      reproducible the moment a pony is caught in it, and no gate can ever pin an
##      expected uid. uid_for() is a PURE function of (data_id, serial), pinned to literal
##      expected strings by the tests, so a clock creeping back in fails immediately.
##      `caught_at_ms` is where the wall clock legitimately lives, and it is passed IN by
##      the caller rather than read here, so this file has no clock dependency at all.
##
##   2. NOT ORDERED BY SORTING StringNames. Godot compares StringName with `<` by INTERNED
##      POINTER, not by text: stable within one process, different between processes. That
##      exact bug already shipped in this project once and made a "seeded" spawn differ
##      run to run (game/world/spawner.gd's DETERMINISM comment and
##      game/scenes/test/wild_ponies.gd both carry the scar). So ordering here is carried
##      by an INTEGER serial, and any code that must order uids does it on String(uid) or
##      on serial_of(uid) -- never on the raw StringName.
##
## THE COUNTER AND SAVE FILES. A restored uid is kept verbatim, and from_dict() pushes the
## counter PAST the restored serial (see _observe_serial). Without that, loading a save and
## then catching one more pony would mint a uid that already belongs to somebody, and two
## different ponies would answer to one name -- the one failure mode a uid is supposed to
## make impossible. Task 2's save/load depends on this.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd: the class cache lives in the gitignored game/.godot/ and a
## fresh clone has not built it yet.

const PonyRegistryScript := preload("res://systems/pony_registry.gd")

## Directory the shared registry lazily loads the roster from, when nobody has injected
## one. Same path everything else in the project reads the roster from.
const ROSTER_DIR := "res://data/ponies"

## Separates the character id from the serial in a uid. `#` because it cannot appear in a
## PonyData id (they are file-stem identifiers) and it reads as "number" at a glance.
const UID_SEPARATOR := "#"

## Digits the serial is padded to. Six is 999,999 individuals in one save, which is far
## past anything the ranch can hold; the padding exists so String(uid) sorts in mint order
## for a human reading a save file, not because anything depends on it.
const UID_SERIAL_DIGITS := 6

## Range both state values live in. Task 4 (game/systems/needs.gd) owns the RULES that
## move them; this file only owns storing them and refusing to store nonsense.
const STATE_MIN := 0.0
const STATE_MAX := 1.0

## A freshly caught pony: middling happiness (she has just been abducted by a horn beam,
## but she is not starving) and not hungry yet. Task 4 may retune these; they live here
## because from_dict() needs them as fallbacks for an older save with no such field.
const HAPPINESS_DEFAULT := 0.5
const HUNGER_DEFAULT := 0.0

## Monotonic mint counter. Process-wide and static ON PURPOSE: uniqueness has to hold
## across every Storage, every pen and every corner of the world at once, so a counter per
## container would hand out colliding uids the first time a pony moved between two of them.
static var _serial := 0

## The roster used to resolve data_id -> PonyData. Lazily loaded from ROSTER_DIR on first
## use; injectable via set_registry() so a test or a gate can point it somewhere else (and
## so tests can reset it, since it outlives any one of them).
static var _registry: PonyRegistry = null

## Unique per INDIVIDUAL, e.g. &"twilight#000003". Never compared or sorted as a
## StringName -- see the class comment's footgun 2. Assigned at construction; treat as
## read-only afterwards, because the whole point of it is that it does not change.
var uid: StringName = &""

## Which PonyData she was built from, e.g. &"twilight". Shared by every individual of that
## character; resolve it with data().
var data_id: StringName = &""

## What the player has chosen to call her, or "" for "use the character's own name". See
## display_name().
var nickname: String = ""

## STATE_MIN..STATE_MAX. Drives gem production in Task 5; moved by Task 4's needs rules.
var happiness := HAPPINESS_DEFAULT

## STATE_MIN..STATE_MAX, where MAX is starving. Never fatal -- no pony ever dies; a
## neglected pony escapes (Task 5), she does not starve to death.
var hunger := HUNGER_DEFAULT

## Unix time in milliseconds at the moment she was caught, or 0 if unknown. PASSED IN by
## the caller rather than read here: this class must stay a pure function of its inputs so
## uids and gates stay reproducible (class comment, footgun 1).
var caught_at_ms := 0

## WHERE SHE LIVES: the `slot_id` of the PlotSlot whose pen she is in, or &"" for a pony in
## the saddlebag (or one who has never been penned). Added by Phase 1B Task 3.
##
## HER ADDRESS RIDES IN HER OWN RECORD, deliberately, rather than in a second "who is in
## pen 2" list in the save file. One fact in one place, so a pony and her address cannot
## desync -- the failure that arrangement invites is a save where pen 2 lists a uid that no
## pony record has, or a pony recorded in two pens at once, and both of those end with a
## pony who exists in the file and is standing nowhere. It also means a traded pony blob
## (the spec wants two players swapping ponies by sending each other JSON) carries where she
## lived with her, which is strictly more information than a bare pony.
##
## Set and cleared ONLY by game/world/pen.gd's add_pony()/remove_pony(). A pony refused by a
## full pen keeps her old address, because a refusal must change nothing. Being CAUGHT by
## the magic beam clears it too, but still through remove_pony() -- the pen hears about the
## capture from the pony's own `captured` signal and evicts her; nothing else anywhere is
## allowed to write this field, or there would be two authorities on where she lives.
var home_slot: StringName = &""

## HER LOOK, if she is one of the crowd: `{"coat": int, "mane": int, "eyes": int}`, indices
## into game/data/stock_palette.tres. EMPTY for a named character, whose look is her model.
##
## ON THE INDIVIDUAL AND NOT ON THE CHARACTER, because that is the whole difference between
## a stock pony and a named one: two ponies of the same character are the same colours, and
## two stock ponies of the same hidden base record are not. Her three indices are the only
## thing that makes her her, so they ride in her own record beside her uid and her hunger,
## and a traded blob carries her colours with her.
##
## INDICES RATHER THAN COLOURS, for the reason StockPalette's class comment gives: a colour
## written into a save freezes today's palette into every old file.
var stock: Dictionary = {}


## Mint a brand new individual of `character_id`. Every call produces a DIFFERENT pony,
## even for the same character -- that is the entire point of this class.
static func create(character_id: StringName, at_ms := 0) -> PonyInstance:
	var inst := PonyInstance.new()
	inst.data_id = character_id
	inst.uid = mint_uid(character_id)
	inst.caught_at_ms = at_ms
	return inst


## The next unused uid for `character_id`, advancing the shared counter.
static func mint_uid(character_id: StringName) -> StringName:
	_serial += 1
	return uid_for(character_id, _serial)


## The uid a given character and serial produce. PURE -- no clock, no RNG, no global state
## read -- so it is pinned to literal expected values by the tests and a build whose uids
## started depending on the time of day fails there rather than in a save file six weeks
## later.
static func uid_for(character_id: StringName, serial: int) -> StringName:
	return StringName("%s%s%0*d" % [
		String(character_id), UID_SEPARATOR, UID_SERIAL_DIGITS, serial])


## The serial encoded in `a_uid`, or -1 if it does not carry one. The inverse of uid_for(),
## and the ONLY sanctioned way to order two uids -- doing it by comparing the StringNames
## themselves is the interned-pointer footgun in the class comment.
static func serial_of(a_uid: StringName) -> int:
	var text := String(a_uid)
	var cut := text.rfind(UID_SEPARATOR)
	if cut < 0:
		return -1
	var digits := text.substr(cut + 1)
	return int(digits) if digits.is_valid_int() else -1


## Point the resolver at a registry of your own, or at `null` to make the next lookup
## lazily reload ROSTER_DIR. Exists so a test does not have to hit the disk, and so a
## future GameState can hand over the roster it already loaded rather than loading a
## second copy.
static func set_registry(registry: PonyRegistry) -> void:
	_registry = registry


## The registry lookups go through, loading ROSTER_DIR on first use. Never null.
static func get_registry() -> PonyRegistry:
	if _registry == null:
		_registry = PonyRegistryScript.new()
		_registry.load_all(ROSTER_DIR)
	return _registry


## The PonyData for `character_id`, or NULL if this build's roster has never heard of her.
##
## NULL IS A SUPPORTED ANSWER, not an error case to be papered over. A save file from a
## build with a pony this one does not have, or a traded blob naming a character the
## receiver has not got, both land here -- and the caller (a HUD pip, a pen) has to cope by
## showing a default rather than by crashing. Substituting some other pony's record would
## be worse than a blank: the player would be looking at a stranger wearing the name.
static func resolve_data(character_id: StringName) -> PonyData:
	return get_registry().by_id(character_id)


## This individual's character record, or null -- see resolve_data().
func data() -> PonyData:
	return resolve_data(data_id)


## Is she one of the crowd? Asked of her LOOK rather than of her data_id, because the look
## is what the save carries and the id is what a build's roster happens to hold: a record
## whose data_id this build has never heard of still resolves to null and still has to know
## whether to be tinted.
func is_stock() -> bool:
	return not stock.is_empty()


## What to call her on screen: her nickname, else her character's display name, else the
## raw data_id. The last fallback is deliberately the id rather than "" or "a pony": a
## label that says `not_a_pony_at_all` tells whoever is looking at it what went wrong,
## and an empty one tells them nothing.
func display_name() -> String:
	if not nickname.is_empty():
		return nickname
	var record := data()
	if record != null and not record.display_name.is_empty():
		return record.display_name
	return String(data_id)


## A plain, JSON-safe dictionary of every field. StringNames come out as Strings because
## JSON has no StringName -- Task 2 writes these to a human-readable save file, and the
## spec wants two players able to trade a pony by sending each other one of these blobs.
func to_dict() -> Dictionary:
	return {
		"uid": String(uid),
		"data_id": String(data_id),
		"nickname": nickname,
		"happiness": happiness,
		"hunger": hunger,
		"caught_at_ms": caught_at_ms,
		"home_slot": String(home_slot),
		"stock": stock.duplicate(),
	}


## Rebuild an instance from a to_dict() dictionary (or from one JSON.parse_string handed
## back, which is the same thing with every number as a float).
##
## Returns NULL for something that is not a pony record at all -- no data_id, or an empty
## one -- because that is the caller's cue to skip the entry rather than to add a nameless
## ghost to the roster. Anything else missing is FILLED IN from the defaults instead: an
## older save, or a hand-edited traded blob, must load as a usable pony rather than take
## the game down.
##
## Out-of-range happiness/hunger are CLAMPED, not trusted. A corrupt or hand-edited file
## should not be able to produce a pony who is 4000% happy and outproduces the whole ranch.
static func from_dict(d: Dictionary) -> PonyInstance:
	var id := StringName(str(d.get("data_id", "")))
	if String(id).is_empty():
		return null

	var inst := PonyInstance.new()
	inst.data_id = id

	var restored := str(d.get("uid", ""))
	if restored.is_empty():
		inst.uid = mint_uid(id)
	else:
		inst.uid = StringName(restored)
		# See the class comment: the counter has to clear a restored serial, or the next
		# capture after a load mints a uid somebody already owns.
		_observe_serial(inst.uid)

	inst.nickname = str(d.get("nickname", ""))
	inst.happiness = clampf(float(d.get("happiness", HAPPINESS_DEFAULT)), STATE_MIN, STATE_MAX)
	inst.hunger = clampf(float(d.get("hunger", HUNGER_DEFAULT)), STATE_MIN, STATE_MAX)
	inst.caught_at_ms = int(d.get("caught_at_ms", 0))
	# Absent in every save written before Phase 1B Task 3, and in every hand-traded blob
	# from such a build. str() of the default gives "" -- a pony in the bag -- rather than a
	# pony penned in a slot called "<null>".
	inst.home_slot = StringName(str(d.get("home_slot", "")))
	# JSON has no integer type, so every index comes back as a float and is int()ed; and a
	# value that is not a dictionary of three numbers is DROPPED rather than kept, so a hand
	# edited blob cannot fabricate a look this class would not have written.
	inst.stock = {}
	var saved_stock: Variant = d.get("stock", {})
	if typeof(saved_stock) == TYPE_DICTIONARY:
		var triple: Dictionary = saved_stock
		var ok := true
		for key in ["coat", "mane", "eyes"]:
			var raw: Variant = triple.get(key, null)
			if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
				ok = false
				break
		if ok:
			inst.stock = {
				"coat": int(triple["coat"]),
				"mane": int(triple["mane"]),
				"eyes": int(triple["eyes"]),
			}
	return inst


## Raise the mint counter above `a_uid`'s serial, if it carries one. Idempotent and
## monotonic: a uid with a lower serial (or none at all) leaves the counter alone.
static func _observe_serial(a_uid: StringName) -> void:
	_serial = maxi(_serial, serial_of(a_uid))


func _to_string() -> String:
	return "PonyInstance(%s, happiness=%.2f, hunger=%.2f)" % [String(uid), happiness, hunger]
