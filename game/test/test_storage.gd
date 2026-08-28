extends GutTest
## Tests for the beam's capture storage (game/systems/storage.gd).
##
## Storage is deliberately a RefCounted with no scene dependency, so every one of these
## runs without a tree, a physics frame or a pony body -- the container's rules ("full
## means full", "the last one in is the first one out", "every change announces itself")
## are exactly the kind of thing that should be pinned in milliseconds rather than
## inferred from what the magic beam did in a 300-frame scene.
##
## WHY `changed` IS TESTED AS HARD AS THE RETURN VALUES. The HUD and the beam's own
## effects will both hang off that signal; a store() that quietly forgot to emit would
## leave a correct inventory behind a stale display, which is the kind of bug that looks
## like a rendering problem for a day. It is also asserted NOT to fire on the two
## no-ops (a store into a full bag, a release from an empty one), because a signal that
## fires when nothing happened is just as useless to a listener as one that does not
## fire when something did.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const StorageScript := preload("res://systems/storage.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


## One caught pony. Every call makes a NEW individual, even for the same character id --
## which is the point of the container holding PonyInstances rather than PonyData, and is
## what test_two_catches_of_one_character... below leans on.
func _instance(id: String) -> PonyInstance:
	return PonyInstanceScript.create(StringName(id))


func test_a_new_storage_is_empty_and_not_full() -> void:
	var storage = StorageScript.new(3)
	assert_eq(storage.capacity, 3, "capacity is what the constructor was handed")
	assert_eq(storage.count(), 0, "a new storage holds nothing")
	assert_false(storage.is_full(), "...and is not full")


func test_it_stores_up_to_capacity() -> void:
	var storage = StorageScript.new(3)
	for i in range(3):
		assert_true(storage.store(_instance("pony%d" % i)), "store %d must succeed" % i)
		assert_eq(storage.count(), i + 1, "count follows the stores")
	assert_true(storage.is_full(), "three of three is full")


func test_storing_past_capacity_returns_false_and_does_not_grow_the_count() -> void:
	# The beam reads this return value to decide whether the pony goes into the bag or
	# drops back into the world unharmed, so "false" has to mean the bag really did not
	# take her -- a false that still appended would lose a pony AND drop her.
	var storage = StorageScript.new(2)
	storage.store(_instance("a"))
	storage.store(_instance("b"))
	var refused: PonyInstance = _instance("c")
	assert_false(storage.store(refused), "a full storage refuses")
	assert_eq(storage.count(), 2, "...and does not grow")
	assert_eq(storage.peek().data_id, &"b", "...and does not displace what was already in it")


func test_storing_null_is_refused_without_growing_the_count() -> void:
	# A null slipping in would be a hole in the bag that only surfaced at release(),
	# where null already means "empty" -- two different meanings for one value.
	var storage = StorageScript.new(2)
	assert_false(storage.store(null), "null is not a pony")
	assert_eq(storage.count(), 0, "and must not occupy a slot")


func test_release_returns_entries_lifo_and_empties() -> void:
	var storage = StorageScript.new(3)
	storage.store(_instance("first"))
	storage.store(_instance("second"))
	storage.store(_instance("third"))

	assert_eq(storage.release().data_id, &"third", "the last one in comes out first")
	assert_eq(storage.release().data_id, &"second")
	assert_eq(storage.release().data_id, &"first")
	assert_eq(storage.count(), 0, "releasing everything empties it")
	assert_false(storage.is_full())


func test_release_on_empty_returns_null() -> void:
	var storage = StorageScript.new(2)
	assert_null(storage.release(), "there is nothing to let out of an empty storage")
	assert_eq(storage.count(), 0)


func test_releasing_frees_a_slot_the_next_store_can_use() -> void:
	var storage = StorageScript.new(1)
	storage.store(_instance("a"))
	assert_false(storage.store(_instance("b")), "one slot, one pony")
	storage.release()
	assert_true(storage.store(_instance("b")), "letting one out makes room for the next")
	assert_eq(storage.count(), 1)


func test_changed_fires_on_a_store_and_on_a_release() -> void:
	var storage = StorageScript.new(2)
	watch_signals(storage)

	storage.store(_instance("a"))
	assert_signal_emit_count(storage, "changed", 1, "a store announces itself")

	storage.release()
	assert_signal_emit_count(storage, "changed", 2, "so does a release")


func test_changed_does_not_fire_when_nothing_actually_changed() -> void:
	var storage = StorageScript.new(1)
	storage.store(_instance("a"))
	watch_signals(storage)

	storage.store(_instance("b"))
	storage.release()
	storage.release()
	assert_signal_emit_count(storage, "changed", 1,
		"only the release that actually let a pony out may report a change")


func test_contents_is_a_copy_so_a_caller_cannot_edit_the_bag_behind_its_back() -> void:
	var storage = StorageScript.new(2)
	storage.store(_instance("a"))
	var listing := storage.contents()
	listing.clear()
	assert_eq(storage.count(), 1, "clearing the listing must not empty the storage")


func test_two_catches_of_one_character_are_two_separate_ponies_in_the_bag() -> void:
	# THE Phase 1B keystone, asserted from the container's side. Before PonyInstance the
	# bag held PonyData -- the shared, one-per-CHARACTER resource -- so catching two
	# Twilights put two pointers to the SAME record in it. A reviewer looked in the bag and
	# saw `contents=[twilight, twilight]`, which is exactly as bad as it reads: there was
	# nowhere for one of them to be hungrier than the other.
	var storage = StorageScript.new(4)
	var first = _instance("twilight")
	var second = _instance("twilight")
	assert_true(storage.store(first), "the first Twilight goes in")
	assert_true(storage.store(second), "and so does the second")

	assert_eq(storage.count(), 2, "two catches of one character count as two ponies")
	var listing: Array = storage.contents()
	assert_eq(listing.size(), 2)
	assert_ne(String(listing[0].uid), String(listing[1].uid),
		"...and they are distinguishable -- different uids, compared as String")
	assert_eq(listing[0].data_id, listing[1].data_id, "...while still being the same character")

	# Independent state is the whole reason the uids have to differ.
	listing[0].happiness = 0.9
	assert_ne(storage.contents()[1].happiness, 0.9,
		"cheering one Twilight up must not cheer the other one up")


func test_a_zero_capacity_storage_is_full_from_the_start() -> void:
	# Degenerate but reachable (a save file, a debug tweak); it must refuse cleanly
	# rather than divide the beam's release path by zero.
	var storage = StorageScript.new(0)
	assert_true(storage.is_full(), "no slots means permanently full")
	assert_false(storage.store(_instance("a")), "and nothing can go in")
	assert_null(storage.release())


func test_a_negative_capacity_is_clamped_rather_than_trusted() -> void:
	var storage = StorageScript.new(-5)
	assert_eq(storage.capacity, 0, "a negative capacity is nonsense; clamp it to empty")
	assert_true(storage.is_full())
	assert_false(storage.store(_instance("a")))


## The saddlebag gear (game/data/shop/bigger_saddlebag.tres) grows a bag that is already in
## use and already has ponies in it, so capacity has to be settable after construction,
## and settable in only one safe direction. A bag holding more than its capacity would make
## is_full() true with room on the shelf and refuse the next store() forever, a state no
## constructor could ever produce, so shrinking stops at the contents.
func test_capacity_can_grow_but_never_below_what_is_held() -> void:
	var bag = StorageScript.new(2)
	bag.store(_instance("twilight"))
	bag.store(_instance("twilight"))
	bag.set_capacity(5)
	assert_eq(bag.capacity, 5)
	assert_false(bag.is_full())
	bag.set_capacity(1)
	assert_eq(bag.capacity, 2, "shrinking below the contents is clamped to the contents")
	assert_true(bag.is_full())
