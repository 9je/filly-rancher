class_name Storage
extends RefCounted
## The pony you just caught has to go somewhere. This is that somewhere: a fixed-capacity
## LIFO container of PonyData records, owned by the magic beam
## (game/actors/player/magic_beam.gd) and read by whatever HUD, corral or barn wants to
## know what the player is carrying.
##
## RECORDS, NOT NODES. What goes in is the PonyData the captured pony was built from, not
## the Pony node itself. A captured pony is freed at the moment of capture and rebuilt
## from her record when she is let out again, through the same
## PonyRegistry -> PonyVisuals path everything else spawns through
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

## Emitted whenever the contents actually change -- once per successful store(), once per
## release() that returned a pony. Deliberately NOT emitted for a refused store or a
## release from an empty bag: a listener redrawing a HUD on every call would otherwise
## repaint on events where nothing moved, and "changed" would stop meaning changed.
signal changed()

## How many ponies fit. Read-only in practice; clamped at construction so a nonsense
## value cannot make is_full() lie. Not `const` only because it is per-instance.
var capacity: int = 0

## Newest last. Never handed out directly -- see contents().
var _items: Array[PonyData] = []


func _init(p_capacity: int) -> void:
	capacity = maxi(0, p_capacity)


## Put `data` in the bag. Returns false -- and changes nothing at all -- if the bag is
## full or `data` is null; the caller is then still responsible for the pony it was
## holding (the beam drops her back into the world unharmed).
##
## `null` is refused rather than stored because release() already uses null to mean
## "there was nothing in here"; a stored null would make those two states
## indistinguishable to every reader.
func store(data: PonyData) -> bool:
	if data == null or is_full():
		return false
	_items.append(data)
	changed.emit()
	return true


## Take the most recently stored pony back out, or null if there is nothing in here.
func release() -> PonyData:
	if _items.is_empty():
		return null
	var data: PonyData = _items.pop_back()
	changed.emit()
	return data


## How many ponies are in the bag right now.
func count() -> int:
	return _items.size()


## Whether another store() would be refused.
func is_full() -> bool:
	return _items.size() >= capacity


## The most recently stored pony without removing her, or null if empty. For a HUD that
## wants to show "next out" without disturbing the contents.
func peek() -> PonyData:
	return _items.back() if not _items.is_empty() else null


## A COPY of the contents, oldest first, for display. A copy rather than the array
## itself: handing out the live array would let a HUD append to, clear or reorder the
## player's inventory by accident, and `changed` would never fire for it.
func contents() -> Array[PonyData]:
	return _items.duplicate()
