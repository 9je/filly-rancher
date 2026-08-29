class_name Storage
extends RefCounted
## The pony you just caught has to go somewhere. This is that somewhere: a fixed-capacity
## LIFO container of PonyInstance records, owned by the magic beam
## (game/actors/player/magic_beam.gd) and read by whatever HUD, corral or barn wants to
## know what the player is carrying.
##
## INSTANCES, NOT CHARACTER DEFINITIONS -- and that is a bug fix, not a refactor. This
## container used to hold PonyData, the shared one-per-CHARACTER resource, so catching two
## Twilights put two pointers to the SAME record in the bag: a reviewer inspected it and
## saw `contents=[twilight, twilight]`. There was nowhere for one of them to be hungrier
## than the other, which blocked every other thing Phase 1B wants to do. What goes in now
## is a PonyInstance (game/systems/pony_instance.gd): one individual, with her own uid and
## her own happiness/hunger. Her CHARACTER is still a shared PonyData, resolved on demand
## through inst.data().
##
## RECORDS, NOT NODES. What goes in is a record, not the Pony node itself. A captured pony
## is freed at the moment of capture and rebuilt from her record when she is let out again,
## through the same PonyRegistry -> PonyVisuals path everything else spawns through
## (docs/notes-hair-sim.md: loading a .glb directly is what silently drops the mane/tail
## spring simulation). Keeping nodes alive-but-hidden in a backpack instead would mean
## carrying a physics body, a detection area and a skeleton per captured pony, and would
## give the container a scene dependency it has no use for.
##
## RefCounted, NOT a Node, and deliberately so: nothing in here needs a tree, a frame or
## a transform, so all of it is testable in milliseconds (game/test/test_storage.gd)
## instead of only through a beam in a running scene.
##
## LIFO rather than FIFO. Releasing gives back the pony you caught most recently, which
## is what "let that one back out, I did not mean to grab her" wants; a queue would hand
## back a stranger from ten minutes ago. Nothing outside depends on the order beyond
## that, so if a later phase wants an addressable inventory (pick slot 4) it should grow
## a keyed accessor rather than reinterpret this one.
##
## NO PONY EVER DIES -- the project-wide rule. That rule shows up here as the contract on
## store(): a refusal returns false and changes NOTHING, so the caller still holds a live
## pony it is responsible for putting back in the world. A store() that "failed" after
## already dropping the record on the floor would be exactly the leak the rule forbids.

## Emitted whenever what a display of this bag would show actually changes: once per
## successful store(), once per release() that returned a pony, and once per set_capacity()
## that actually moved the capacity. Deliberately NOT emitted for a refused store, a
## release from an empty bag, or a set_capacity() that resolved to the value already held:
## a listener redrawing a HUD on every call would otherwise repaint on events where nothing
## moved, and "changed" would stop meaning changed.
##
## CAPACITY IS PART OF THE ANNOUNCEMENT, not just the contents, and that is a fix rather
## than a nicety. game/ui/hud.gd caches the capacity it binds to and rebuilds only on this
## signal, so a saddlebag that grew silently would leave the HUD printing "n / 12" and
## drawing twelve pips over a bag that holds eighteen, and game/world/ranch.gd's self check
## that the HUD shows the beam's real capacity would fail.
signal changed()

## How many ponies fit. Clamped at construction so a nonsense value cannot make is_full()
## lie. Not `const` only because it is per-instance, and no longer read-only either: the
## shop's saddlebag gear grows a bag that is already in use, through set_capacity(), which
## clamps in ONE direction only (never below the contents) and announces a real move on
## `changed`. Write it through that function rather than assigning it, or every listener
## keeps showing the old number.
var capacity: int = 0

## Newest last. Never handed out directly -- see contents().
var _items: Array[PonyInstance] = []


func _init(p_capacity: int) -> void:
	capacity = maxi(0, p_capacity)


## Grow (or shrink) the bag. Never below what it already holds: a capacity that dropped
## under the contents would make the next store() refuse while count() > capacity, a
## state no store ever produced. The saddlebag gear calls this.
##
## Emits `changed` when the capacity actually moves, and only then. A HUD that caches the
## capacity has no other way to hear about a bag that grew mid-game; a no-op call (the
## same number again, or a shrink the clamp swallowed) stays silent, for the same reason a
## refused store() does.
func set_capacity(new_capacity: int) -> void:
	var clamped := maxi(_items.size(), maxi(0, new_capacity))
	if clamped == capacity:
		return
	capacity = clamped
	changed.emit()


## Put `instance` in the bag. Returns false -- and changes nothing at all -- if the bag is
## full or `instance` is null; the caller is then still responsible for the pony it was
## holding (the beam drops her back into the world unharmed).
##
## `null` is refused rather than stored because release() already uses null to mean
## "there was nothing in here"; a stored null would make those two states
## indistinguishable to every reader.
##
## Deliberately does NOT reject an instance whose uid is already in the bag. A duplicate
## uid would be a minting bug upstream, and silently swallowing the second copy here would
## hide it while ALSO losing a pony the caller is holding -- exactly the leak the
## no-pony-ever-dies rule forbids. PonyInstance.create() is the one place uids come from,
## and it is what guarantees they differ.
func store(instance: PonyInstance) -> bool:
	if instance == null or is_full():
		return false
	_items.append(instance)
	changed.emit()
	return true


## Take the most recently stored pony back out, or null if there is nothing in here.
##
## THIS IS THE HANDOVER POINT, not the end of the story. What comes back is a record; the
## caller is what puts a live Pony in the world again from it -- MagicBeam.release_stored()
## (game/actors/player/magic_beam.gd) does that for the player, and Task 3's pens will do
## the same when a pony is let out into one. Her state rides along in the instance, so a
## pony let out and caught again is the SAME pony, at the same happiness, with the same
## uid, rather than a fresh copy of her character.
func release() -> PonyInstance:
	if _items.is_empty():
		return null
	var instance: PonyInstance = _items.pop_back()
	changed.emit()
	return instance


## How many ponies are in the bag right now.
func count() -> int:
	return _items.size()


## Whether another store() would be refused.
func is_full() -> bool:
	return _items.size() >= capacity


## The most recently stored pony without removing her, or null if empty. For a HUD that
## wants to show "next out" without disturbing the contents.
func peek() -> PonyInstance:
	return _items.back() if not _items.is_empty() else null


## A COPY of the contents, oldest first, for display. A copy rather than the array
## itself: handing out the live array would let a HUD append to, clear or reorder the
## player's inventory by accident, and `changed` would never fire for it.
func contents() -> Array[PonyInstance]:
	return _items.duplicate()

