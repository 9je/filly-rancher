class_name Compendium
extends RefCounted
## THE PLAYER'S KNOWLEDGE OF THE ROSTER: for every character, whether she has never been
## seen (UNSEEN), has been spotted in the world but not yet caught (SEEN), or has been
## caught at least once (CAUGHT). GameState carries this as `compendium`
## (game/systems/game_state.gd); a later task's page draws it against PonyRegistry to show
## something like "12 / 43 seen".
##
## STATE ONLY EVER MOVES FORWARD. mark_seen()/mark_caught() never downgrade a character who
## is already further along; catching a pony you never noticed first still counts as
## having seen her, and re-marking a caught pony as merely seen would erase real progress
## over a UI ordering bug or a duplicated call. Both return whether anything actually
## changed, so a caller can tell "this raised her state" from "she was already there"
## without a second lookup.
##
## UNSEEN IS THE ABSENCE OF AN ENTRY, not a stored value: a fresh Compendium has nothing in
## `_states` at all, and state_of() answers UNSEEN for any id it has never heard of.
## to_dict() keeps that compact on disk; only SEEN and CAUGHT entries are written; which
## is what makes an old save missing the `compendium` key entirely (SaveIO.migrate() adds
## `compendium: {}`) indistinguishable from a save that has the key and nobody has been
## marked in it yet.
##
## COUNTS ARE MEASURED AGAINST A PonyRegistry, not against `_states`. `_states` only ever
## holds entries for ids somebody actually raised; count()/count_in_zone()/total() walk the
## REGISTRY's roster and ask this compendium's state of each entry, so an unmarked character
## is counted as UNSEEN rather than simply absent from the tally.
##
## RefCounted, no scene, GUT-tested in isolation (game/test/test_compendium.gd), the same
## discipline as GemPouch and Inventory (game/systems/gem_pouch.gd, game/systems/inventory.gd).
##
## PROCESSED IS WHAT THE COMPANY CALLS IT. A character the player has delivered to the
## Depot is PROCESSED: above CAUGHT, and reached by the same one way _raise(), so a pony
## delivered and then somehow caught again is still delivered. Before the story's fork the
## page renders it as "Delivered" with a smiley; after the fork the same state renders as a
## desaturated portrait and a yield percentage. One state, and only the words change.

enum State { UNSEEN, SEEN, CAUGHT, PROCESSED }

## Emitted once per real change, with the id that moved and the state it moved TO. Not for
## a re-mark that changes nothing, matching GemPouch.changed's rule.
signal changed(data_id: StringName, state: int)

## StringName -> State. Only ever holds SEEN or CAUGHT entries; see the class comment.
var _states: Dictionary = {}


func state_of(id: StringName) -> int:
	return int(_states.get(id, State.UNSEEN))


## Raise `id` to SEEN if she is currently UNSEEN. Returns whether that happened; false if
## she was already SEEN or CAUGHT, because this never downgrades.
func mark_seen(id: StringName) -> bool:
	return _raise(id, State.SEEN)


## Raise `id` to CAUGHT if she is not already there. Returns whether that happened.
func mark_caught(id: StringName) -> bool:
	return _raise(id, State.CAUGHT)


## Raise `id` to PROCESSED: she has been delivered to the Depot. Returns whether that
## happened. Never called for a stock pony, who has no entry at all.
func mark_processed(id: StringName) -> bool:
	return _raise(id, State.PROCESSED)


func _raise(id: StringName, state: int) -> bool:
	if state_of(id) >= state:
		return false
	_states[id] = state
	changed.emit(id, state)
	return true


## How many characters in `registry`'s roster are currently at exactly `state`.
func count(state: int, registry: PonyRegistry) -> int:
	var n := 0
	for data: PonyData in _all_data(registry):
		if state_of(data.id) == state:
			n += 1
	return n


## How many characters who spawn in `zone` are currently at exactly `state`.
func count_in_zone(zone: StringName, state: int, registry: PonyRegistry) -> int:
	var n := 0
	for data: PonyData in registry.by_zone(zone):
		if state_of(data.id) == state:
			n += 1
	return n


## The size of the roster this compendium is measured against, e.g. for a "12 / 43" label.
func total(registry: PonyRegistry) -> int:
	return _all_data(registry).size()


## Every PonyData in `registry`, which is PonyRegistry.all()'s own job. This used to union
## by_rarity() over the four tiers, which returns everybody exactly once only because
## `rarity` is a single enum field and the tiers therefore partition the roster; the
## registry now answers the question directly, in one stated order, for every caller at
## once.
static func _all_data(registry: PonyRegistry) -> Array[PonyData]:
	return registry.all()


## String keys, int values, UNSEEN entries omitted; see the class comment.
func to_dict() -> Dictionary:
	var out := {}
	for id in _states.keys():
		var state := int(_states[id])
		if state != State.UNSEEN:
			out[String(id)] = state
	return out


## Junk is dropped rather than kept: a non-numeric value, a FRACTIONAL number, or a whole
## number that is not SEEN or CAUGHT (including an explicit 0, and anything out of range),
## is skipped entirely rather than stored; so a hand-edited or corrupted entry cannot
## fabricate a state this class never produces on its own.
##
## THE FRACTIONAL CHECK IS FOR THE ROUND TRIP THROUGH JSON, not for hand-typed floats. JSON
## has no integer type (see SaveIO's class comment), so a state this class itself wrote as
## the int 2 comes back through SaveIO.load() as the float 2.0; that is accepted, `int()`
## recovers it exactly. What must NOT be accepted is 1.5 or 2.7: silently truncating one of
## those to a real state would be fabricating a state that was never actually written,
## which is exactly the failure this whole function exists to refuse.
static func from_dict(d: Dictionary) -> Compendium:
	var c := Compendium.new()
	for key in d.keys():
		var raw: Variant = d[key]
		if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
			continue
		var raw_number: float = float(raw)
		if raw_number != floor(raw_number):
			continue
		var state := int(raw_number)
		if state != State.SEEN and state != State.CAUGHT and state != State.PROCESSED:
			continue
		c._states[StringName(str(key))] = state
	return c
