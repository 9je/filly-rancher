extends Node
## THE SAVABLE WORLD. Autoload (`GameState`, registered in game/project.godot) holding
## everything about a ranch that has to survive quitting: the ponies you own, the wallet,
## what is built on which plot, what you have unlocked, and the seed the world was
## generated from. game/systems/save_io.gd puts it on disk; this file decides what "it"
## is.
##
## WHY AN AUTOLOAD AND NOT A NODE IN ranch.tscn. The state has to outlive the scene. The
## moment there is a second scene -- a barn interior, a shop, a title screen -- a state
## owned by the ranch is a state that is destroyed by walking through a door. An autoload
## is also what lets a future save/quit menu reach it from anywhere without threading a
## reference through every UI node.
##
## THE FIELDS ARE PLAIN AND THE SERIALISATION IS EXPLICIT. to_dict() lists every field by
## hand rather than reflecting over the object. Reflection would silently start saving any
## private bookkeeping var a later task adds (and silently stop saving a renamed one); a
## hand-written list is a place where "is this saved?" has an answer you can read, and the
## round-trip test in game/test/test_game_state.gd fails the moment a field is added to
## one side and not the other.
##
## PONIES ARE THE PLAYER'S, NOT THE WORLD'S. `ponies` is the list of individuals the
## player OWNS -- what the plan calls the roster. It is not the character roster (that is
## PonyRegistry, loaded from res://data/ponies and identical on every machine) and it is
## not the wild herd (that is the spawner's, regenerated from `world_seed` on every boot).
## Only the owned individuals are saved, because only they carry state nothing else can
## reproduce.
##
## ONE REGISTRY, LOADED ONCE. ensure_registry() loads res://data/ponies and hands the
## result to PonyInstance.set_registry(). Without that, PonyInstance's lazy static would
## load a SECOND copy of the same roster behind this one the first time anything resolved
## a data_id -- two copies of the same authored data, free to drift apart at the exact
## moment one of them is reloaded. Flagged during Task 1's review; this is the fix.
##
## AUTOSAVE IS OFF UNTIL A SCENE TURNS IT ON, and that is a safety property, not a
## preference. Every gate, every export smoke run and the whole GUT suite boots the real
## main scene with the real autoloads. If quitting saved unconditionally,
## `bash tools/run_tests.sh` would end by overwriting the developer's ranch with whatever
## empty state the test process happened to hold. game/world/ranch.gd enables it only for
## an interactive, non-headless, non-screenshot run -- i.e. only when a person is actually
## playing.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd: the class cache lives in the gitignored game/.godot/ and a
## fresh clone has not built it yet.

const SaveIOScript := preload("res://systems/save_io.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")

## Where the authored character roster is read from. The same directory the spawner and
## PonyInstance use; named here because this is now the one place it is loaded.
const ROSTER_DIR := "res://data/ponies"

## The slot a normal play session uses. Multiple slots exist in the file format from day
## one (the spec's pony trading wants a place to put a received blob), but the game itself
## only ever touches this one until there is UI to choose another.
const DEFAULT_SLOT := 0

## A new ranch. Zero bits is deliberate: Task 6's economy is supposed to be entered
## through selling the first gem, not through a starting float.
const STARTING_BITS := 0

## The seed a new world is generated from. Matches game/world/spawner.gd's exported
## default so that a brand-new game and an un-saved gate run produce the SAME world -- if
## these two numbers drift apart, the gates stop measuring the map the player gets.
const DEFAULT_WORLD_SEED := 20260839

## Keys in the save file. Named constants rather than inline strings because the loader
## and the writer must agree, and a typo in one of them is a field that silently stops
## being saved.
const KEY_PONIES := "ponies"
const KEY_BITS := "bits"
const KEY_PLOTS := "plots"
const KEY_UNLOCKS := "unlocks"
const KEY_WORLD_SEED := "world_seed"
const KEY_GEMS := "gems"
const KEY_INVENTORY := "inventory"

## Emitted after from_dict() or load_from_slot() has replaced the world. A HUD or a pen
## that cached anything out of here has to rebuild on this.
signal state_loaded()

## Emitted after a successful write, with the slot written. A "Ranch saved" toast hangs
## off this.
signal state_saved(slot: int)

## The individuals the player owns. Order is preserved across a save so a future inventory
## screen is not reshuffled by reloading.
var ponies: Array[PonyInstance] = []

## The wallet. Task 6 gives it an Economy with prices and transactions; until then it is
## the number that has to survive a reload, which is this file's business either way.
var bits := STARTING_BITS

## What is built where: plot slot id -> plot type id, both Strings. STRING KEYS, not ints:
## JSON has no integer keys, so `{0: "pen"}` would save and reload as `{"0": "pen"}` and
## every lookup by the int key would miss. SaveIO refuses non-string keys outright rather
## than let that happen quietly. Task 3 fills this in.
var plots: Dictionary = {}

## Unlock ids the player has earned or bought (beam upgrades, capacity, recipes). Plain
## Strings for the same JSON reason as `plots`.
##
## Deliberately an UNTYPED Array despite holding only Strings. GameState is reached as an
## autoload -- `GameState.unlocks = [...]` from a shop or a test -- and a dynamic
## assignment of an untyped array literal to an `Array[String]` property fails at RUNTIME
## with "Invalid assignment of property", not at parse time. A typed array here would buy
## nothing (from_dict coerces every entry with str() anyway) and would hand every future
## caller a runtime error that only fires on the line that sets it.
var unlocks: Array = []

## The seed the wild world is generated from. Saved so that reloading gives you back the
## same ranch you left rather than a differently-shaped one.
var world_seed := DEFAULT_WORLD_SEED

## The gems the player holds, by producing rarity (game/systems/gem_pouch.gd). Pens fold
## their trays into this before every save and when the Market opens (ranch.gd), so this
## is the count that survives quitting and the count the Market sells from.
##
## REPLACED, NOT MUTATED, by from_dict() and reset(): a listener holding the old object is
## holding a pouch nothing will fill again. Re-read after state_loaded.
var gems: GemPouch = GemPouchScript.new()

## Consumables the player holds (game/systems/inventory.gd). Same replacement rule.
var inventory: Inventory = InventoryScript.new()

## Whether quitting writes a save. See the class comment -- off by default on purpose.
var autosave_enabled := false

## Called immediately before EVERY write, to copy the live world into this state.
##
## THIS EXISTS BECAUSE A SAVE ON QUIT HAS NO OTHER WAY TO BE CURRENT. The ponies the player
## is carrying live in the beam's Storage, not here; this state is only refreshed when
## something copies them across. The save-at-the-house path could do that itself, but the
## save-on-QUIT path runs from a notification during teardown, with no scene code involved
## -- so without this hook, quitting would write whatever this object last happened to
## hold: an empty roster for a session that had never saved at the house, i.e. a session's
## worth of ponies silently not saved. Hanging the sync off the write instead of off the
## caller means every write is current by construction, including ones added later.
##
## Registered by game/world/ranch.gd. An unset or stale Callable (its object freed during
## teardown) is simply skipped -- is_valid() covers both.
var world_sync := Callable()

## The authored character roster, loaded once. Never null after ensure_registry().
var _registry: PonyRegistry = null

## Set once save_on_quit() has run, so a shutdown that delivers more than one of the
## notifications below cannot write the same state twice (harmless, but it would also mean
## a second write during teardown, when the state may already be half torn down).
var _quit_saved := false


func _ready() -> void:
	ensure_registry()


## Save on the way out, when a scene has asked for it.
##
## Both notifications are handled because they cover different exits and neither covers
## the other: NOTIFICATION_WM_CLOSE_REQUEST is the window's close button (and is NOT sent
## by get_tree().quit(), which is how every gate and the exported smoke run end), while
## NOTIFICATION_EXIT_TREE fires during teardown for all of them. autosave_enabled is what
## keeps the second one from firing in automated runs.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_on_quit()


# --- the roster of owned ponies --------------------------------------------------------

## Take ownership of `instance`. Refuses null -- see Storage.store() for the same contract
## and the same reason: null already means "nothing here" to every reader.
func add_pony(instance: PonyInstance) -> bool:
	if instance == null:
		return false
	ponies.append(instance)
	return true


## The individual with this uid, or null. Addressed by uid, never by data_id: two Twilights
## are two ponies and only the uid tells them apart.
func find_pony(uid: StringName) -> PonyInstance:
	for instance in ponies:
		if instance.uid == uid:
			return instance
	return null


## Remove and return the individual with this uid, or null if she is not here.
func remove_pony(uid: StringName) -> PonyInstance:
	for i in ponies.size():
		if ponies[i].uid == uid:
			var instance: PonyInstance = ponies[i]
			ponies.remove_at(i)
			return instance
	return null


## A COPY of the owned list, for display and for iteration while something else may be
## adding or removing -- same reasoning as Storage.contents().
func get_ponies() -> Array[PonyInstance]:
	return ponies.duplicate()


func pony_count() -> int:
	return ponies.size()


## Replace the owned list wholesale, e.g. when syncing back from the player's saddlebag
## before a save. Nulls are dropped rather than stored.
func set_ponies(list: Array) -> void:
	ponies.clear()
	for instance in list:
		add_pony(instance as PonyInstance)


# --- the roster of CHARACTERS ----------------------------------------------------------

## The authored character roster, loading it on first call and handing it to PonyInstance
## so nothing loads a second copy. Idempotent; safe to call from anywhere.
func ensure_registry() -> PonyRegistry:
	if _registry == null:
		_registry = PonyRegistryScript.new()
		_registry.load_all(ROSTER_DIR)
		PonyInstanceScript.set_registry(_registry)
	return _registry


func get_registry() -> PonyRegistry:
	return ensure_registry()


# --- serialisation ----------------------------------------------------------------------

## Everything that has to survive quitting, as a plain JSON-safe dictionary. Listed by
## hand -- see the class comment for why this is not reflection.
func to_dict() -> Dictionary:
	var pony_dicts: Array = []
	for instance in ponies:
		pony_dicts.append(instance.to_dict())
	return {
		KEY_PONIES: pony_dicts,
		KEY_BITS: bits,
		KEY_PLOTS: plots.duplicate(true),
		KEY_UNLOCKS: unlocks.duplicate(),
		KEY_WORLD_SEED: world_seed,
		KEY_GEMS: gems.to_dict(),
		KEY_INVENTORY: inventory.to_dict(),
	}


## Replace the world with what `data` describes. Every field is optional and every missing
## one falls back to a new-game default: that is what makes a save written by an older
## build load in a newer one without a migration step (see SaveIO.migrate()).
##
## A pony record that is not a pony record (no data_id -- a hand-edited blob, a truncated
## paste) is SKIPPED, not fatal, and not substituted with a placeholder. One bad record
## must not cost the player the rest of her ranch. A pony whose character this build does
## not carry, on the other hand, is KEPT: she resolves to null and shows as a default in
## the HUD, and deleting her would be the save system killing a pony, which this project
## does not do.
func from_dict(data: Dictionary) -> void:
	ponies.clear()
	for entry in data.get(KEY_PONIES, []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var instance := PonyInstanceScript.from_dict(entry)
		if instance != null:
			ponies.append(instance)

	bits = int(data.get(KEY_BITS, STARTING_BITS))
	world_seed = int(data.get(KEY_WORLD_SEED, DEFAULT_WORLD_SEED))

	plots = {}
	var saved_plots: Variant = data.get(KEY_PLOTS, {})
	if typeof(saved_plots) == TYPE_DICTIONARY:
		for key in saved_plots:
			plots[str(key)] = str(saved_plots[key])

	unlocks = []
	var saved_unlocks: Variant = data.get(KEY_UNLOCKS, [])
	if typeof(saved_unlocks) == TYPE_ARRAY:
		for unlock in saved_unlocks:
			unlocks.append(str(unlock))

	var saved_gems: Variant = data.get(KEY_GEMS, {})
	gems = GemPouchScript.from_dict(saved_gems if typeof(saved_gems) == TYPE_DICTIONARY else {})
	var saved_inventory: Variant = data.get(KEY_INVENTORY, {})
	inventory = InventoryScript.from_dict(
		saved_inventory if typeof(saved_inventory) == TYPE_DICTIONARY else {})

	state_loaded.emit()


## Back to a brand new ranch. Does not touch anything on disk.
func reset() -> void:
	ponies.clear()
	bits = STARTING_BITS
	plots = {}
	unlocks = []
	world_seed = DEFAULT_WORLD_SEED
	gems = GemPouchScript.new()
	inventory = InventoryScript.new()


# --- disk ---------------------------------------------------------------------------------

func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return SaveIOScript.has_slot(slot)


## Write the world to `slot`. Pulls the live world in through `world_sync` first, so a
## save is never a snapshot of a stale copy. Returns whether it landed; emits state_saved
## on success.
func save_to_slot(slot: int = DEFAULT_SLOT) -> bool:
	if world_sync.is_valid():
		world_sync.call()
	if not SaveIOScript.save(slot, to_dict()):
		return false
	state_saved.emit(slot)
	return true


## Load `slot` over the live world. Returns false -- HAVING CHANGED NOTHING -- when there
## is no save there or the file cannot be trusted.
##
## That "changed nothing" is the important half. The obvious implementation (clear, then
## fill from whatever loaded) turns a corrupt file into an erased ranch: the player boots,
## the read fails, and the failure itself is what destroys the state. SaveIO returns {}
## for both "missing" and "corrupt", so this checks for empty BEFORE touching a field.
func load_from_slot(slot: int = DEFAULT_SLOT) -> bool:
	var data := SaveIOScript.load(slot)
	if data.is_empty():
		return false
	from_dict(data)
	return true


## Write on the way out, if a scene enabled it. Returns whether anything was written, so
## the no-op case is observable in a test rather than only in a log.
func save_on_quit() -> bool:
	if not autosave_enabled or _quit_saved:
		return false
	_quit_saved = true
	return save_to_slot(DEFAULT_SLOT)
