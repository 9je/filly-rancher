extends Node
## THE MARKET GATE. Proves the loop the Phase 1B playtest found broken: 21 ponies penned,
## gems produced, zero bits, because nothing sold them. Runs the real ranch, builds a
## pen, pens a happy pony, ticks her until she makes gems, opens the Market, sells,
## buys hay, watches a hungry pony eat it, buys gear, sees the beam honour it, saves and
## reloads gems and inventory, and opens and closes the pause menu without leaving the
## tree paused.
##
## THE RANCH IS HOSTED HERE, not launched. world/ranch.tscn is instanced under this scene,
## so ranch.gd runs with _hosted true: it arms no watchdog of its own, it does not quit the
## process out from under this driver, it never reads the player's save, and it hands its
## own verdict over as gate_report_finished(all_ok). This gate waits for that signal rather
## than polling for a symptom of it, and folds the ranch's answer into its own.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const ProductionScript := preload("res://systems/production.gd")
const NeedsScript := preload("res://systems/needs.gd")
const MarketMenuScript := preload("res://ui/market_menu.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")

const SLOT := 8  # a scratch slot; a hosted ranch reads no slot at all, so nothing collides

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## Record one check's verdict under `label`. A repeated label is a check that never ran:
## the second verdict would silently overwrite the first and the total would come out one
## short, so a collision is recorded and fails the gate in _finish(). Same rule as
## capture_test.gd's _record() and ranch.gd's _set_check().
##
## The loser is kept under a suffixed key rather than dropped, capture_test.gd's way: a run
## with a duplicate still reports BOTH verdicts, so the collision costs you the label rather
## than the measurement.
func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = ok
		return
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "MARKET", 120.0)
	var ranch := $Ranch as Ranch

	# The ranch's boot awaits inside its own _ready(), so it has already yielded by the
	# time this line runs and the connection lands before the verdict is emitted.
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)
	# A ranch that failed its own report still gets driven through everything below: a log
	# showing WHICH parts of the market loop survived is worth more than an early exit, and
	# the gate fails either way.
	_set_check("the ranch booted and bound a shop", ranch.get_shop() != null)
	if ranch.get_shop() == null:
		_finish()
		return

	var state = get_node("/root/GameState")
	# A known-empty ranch to trade from. reset() REPLACES the pouch and the inventory and
	# announces nothing, so the shop built around the old ones has to be rebuilt by hand.
	state.reset()
	ranch.rebind_economy()
	var shop: Shop = ranch.get_shop()

	# --- produce ------------------------------------------------------------------------
	var slots: Array[PlotSlot] = ranch.plot_slots()
	_set_check("there is an empty plot to build on", slots.size() > 0 and slots[0].is_empty())
	var free_plot: PlotData = null
	for plot in ranch.plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	_set_check("a free plot type exists", free_plot != null)
	_set_check("the pen goes up", slots[0].build(free_plot))
	var pen = slots[0].get_built()
	var her := PonyInstanceScript.create(&"twilight")
	her.happiness = 1.0
	her.hunger = 0.0
	_set_check("she moves in", pen.add_pony(her))
	pen.tick(ProductionScript.PRODUCTION_PERIOD_SECONDS * 3.0)
	_set_check("three periods make three gems", pen.gems() == 3)
	var rarity: int = her.data().rarity

	# --- sell ---------------------------------------------------------------------------
	var menu = ranch.get_market_menu()
	_set_check("the market opens", menu.open())
	_set_check("opening collected the tray into the pouch",
		shop.gem_count(rarity) == 3 and pen.gems() == 0)
	_set_check("the tree is paused while the market is up", get_tree().paused)
	# THE BOARD IS PART OF THE PRICE NOW. A sale also pays out whatever request it just
	# finished (ranch.gd's _pay_out), and on a state that was reset a moment ago that is
	# the tutorial "Sell a gem at the market." So the expectation is read off the board
	# rather than written here as a number: a gate that hard-coded 50 would go red the day
	# somebody retunes the tutorial's reward, which is not a bug in the market loop.
	var board: RequestBoard = ranch.get_request_board()
	_set_check("the board is standing before the sale", board != null)
	var request_bits := 0
	for entry in (board.active() if board != null else []):
		var kind := int((entry as Dictionary).get("kind", -1))
		if kind == RequestBoardScript.Kind.SELL_ANY:
			request_bits += int((entry as Dictionary).get("reward_bits", 0))
		elif kind == RequestBoardScript.Kind.SELL_GEMS_OF_RARITY \
				and int((entry as Dictionary).get("rarity", -1)) == rarity \
				and int((entry as Dictionary).get("count", 0)) <= 3:
			request_bits += int((entry as Dictionary).get("reward_bits", 0))
	var expected_bits: int = 3 * shop.gem_price(rarity) + request_bits
	_set_check("sell everything is confirmable", menu.confirm())
	_set_check("selling paid the rarity price", shop.bits() == expected_bits)
	_set_check("the pouch is empty after selling", shop.gem_count(rarity) == 0)
	_set_check("the wallet reached GameState", state.bits == expected_bits)
	var hud = ranch.get_node("HUD")
	_set_check("the HUD shows the wallet", hud.get_bits_text() == "%d bits" % expected_bits)

	# --- buy care -----------------------------------------------------------------------
	menu.set_tab(MarketMenuScript.Tab.BUY)
	var hay_index := -1
	var rows = menu.buy_rows()
	for i in range(rows.size()):
		if rows[i].id == &"hay":
			hay_index = i
	_set_check("hay is in the catalogue", hay_index >= 0)
	menu.move_selection(hay_index)
	var before: int = shop.bits()
	_set_check("hay is affordable from one rare pony's sale", menu.confirm())
	_set_check("hay landed in the inventory", state.inventory.count(&"hay") >= 1)
	_set_check("hay cost bits", shop.bits() < before)

	# --- eat ----------------------------------------------------------------------------
	her.hunger = NeedsScript.HUNGRY_THRESHOLD + 0.1
	var hay_before: int = state.inventory.count(&"hay")
	pen.tick(0.1)
	_set_check("a hungry resident ate from the inventory",
		state.inventory.count(&"hay") == hay_before - 1)
	_set_check("and is no longer hungry", her.hunger < NeedsScript.HUNGRY_THRESHOLD)

	# --- buy gear -----------------------------------------------------------------------
	# Funded through the Economy's own sale rather than by writing `bits` directly, so
	# bits_changed fires and GameState and the HUD follow the way they do in play.
	ranch.get_economy().sell(PonyDataScript.Rarity.LEGENDARY, 10)
	_set_check("funding the wallet reached GameState", state.bits == shop.bits())
	var player_node = ranch.player
	var beam = player_node.get_magic_beam()
	var capacity_before: int = beam.get_storage().capacity
	var reach_before: float = beam.reach()
	var bag_index := -1
	for i in range(rows.size()):
		if rows[i].id == &"bigger_saddlebag":
			bag_index = i
	_set_check("the saddlebag is in the catalogue", bag_index >= 0)
	menu.set_tab(MarketMenuScript.Tab.BUY)
	menu.move_selection(bag_index)
	_set_check("the saddlebag is buyable when funded", menu.confirm())
	_set_check("the unlock is recorded", state.unlocks.has("bigger_saddlebag"))
	_set_check("the beam grew the bag", beam.get_storage().capacity > capacity_before)
	_set_check("the saddlebag cannot be bought twice", not menu.confirm())
	_set_check("reach is unchanged by the saddlebag", is_equal_approx(beam.reach(), reach_before))
	menu.close()
	_set_check("closing the market unpauses", not get_tree().paused)

	# --- save and reload ----------------------------------------------------------------
	state.gems.add(PonyDataScript.Rarity.LEGENDARY, 2)
	_set_check("the save lands", state.save_to_slot(SLOT))
	var raw := SaveIOScript.load(SLOT)
	_set_check("the file is the current version",
		int(raw.get("version", 0)) == SaveIOScript.FORMAT_VERSION)
	_set_check("gems are in the file", raw.has("gems") and raw["gems"].get("3", 0) == 2)
	_set_check("inventory is in the file", raw.has("inventory"))
	_set_check("unlocks are in the file", raw.get("unlocks", []).has("bigger_saddlebag"))
	state.reset()
	_set_check("a reset emptied the pouch", state.gems.is_empty())
	_set_check("the slot loads back", state.load_from_slot(SLOT))
	_set_check("gems came back", state.gems.count(PonyDataScript.Rarity.LEGENDARY) == 2)
	_set_check("unlocks came back", state.unlocks.has("bigger_saddlebag"))

	# --- a bought saddlebag full of ponies survives a load --------------------------------
	# THE ORDERING THIS PINS: the gear a save records has to be honoured BEFORE the ponies
	# in it are poured back, or the herd is restored into a bag that is still the size it
	# was before the player bought a bigger one. Fifteen ponies is deliberately more than
	# the base bag holds and fewer than the bought one does, so a bag that was not grown in
	# time loses exactly the ones in between, to neither the bag nor a pen.
	var storage: Storage = beam.get_storage()
	_set_check("the saddlebag is empty before the herd goes in", storage.count() == 0)
	var herd := 15
	var stowed := 0
	for i in range(herd):
		if storage.store(PonyInstanceScript.create(&"twilight")):
			stowed += 1
	_set_check("fifteen ponies fit in the bought saddlebag", stowed == herd)
	_set_check("the herd saves", state.save_to_slot(SLOT))
	_set_check("the whole herd reached the save", state.pony_count() >= herd)

	state.reset()
	ranch.rebind_economy()
	# The bag a fresh boot starts with: empty, and back at the capacity it has before any
	# gear is applied. set_capacity() refuses to shrink under the contents, so the emptying
	# comes first.
	while storage.release() != null:
		pass
	storage.set_capacity(capacity_before)
	_set_check("the bag is back to its base capacity", storage.capacity == capacity_before)
	# Boot reads the save BEFORE anything is connected to state_loaded, because ranch.gd's
	# _bind_game_state() connects rebind_economy only after its own load, on purpose. So at
	# boot the load itself applies no gear. The connection comes off for this one call to
	# reproduce that; leaving it on would grow the bag on the way through and the ordering
	# under test would never run.
	state.state_loaded.disconnect(ranch.rebind_economy)
	var herd_loaded: bool = state.load_from_slot(SLOT)
	state.state_loaded.connect(ranch.rebind_economy)
	_set_check("the herd's save loads back", herd_loaded)
	var restored: int = ranch.restore_owned_ponies()
	_set_check("the bag was grown before the herd went back into it",
		storage.capacity == MagicBeamScript.BIGGER_SADDLEBAG_CAPACITY)
	_set_check("every bagged pony came back", storage.count() == herd)
	_set_check("the restore reports what it put back", restored == herd)
	_set_check("the resident already in her pen stayed in it", pen.count() == 1)
	# A load mid-session can reach this twice. It must place what is missing and nothing
	# else, with no pony filed in a pen and in the bag at once.
	_set_check("a second restore places nobody twice", ranch.restore_owned_ponies() == 0)
	_set_check("and the bag still holds the herd exactly once", storage.count() == herd)

	# The load above ran with rebind_economy disconnected, exactly as boot's does, so the
	# Shop is still holding the pouch from before it. Put that back the way an ordinary
	# mid-session load leaves it.
	ranch.rebind_economy()
	var shop_now: Shop = ranch.get_shop()

	# --- what the player is told ----------------------------------------------------------
	# The sale toast is measured across the sale rather than read off the request, and one
	# gem is a gem. Both halves are only visible from here: nothing else drives ranch.gd's
	# _on_sell_requested() with a real Shop behind it.
	state.gems.add(PonyDataScript.Rarity.COMMON, 1)
	menu.set_tab(MarketMenuScript.Tab.SELL)
	menu.move_selection(1 + PonyDataScript.Rarity.COMMON)
	var one_gem_bits: int = shop_now.gem_price(PonyDataScript.Rarity.COMMON)
	_set_check("a single common gem sells", menu.confirm())
	_set_check("the toast counts one gem as a gem",
		_hud_says(hud, "Sold 1 gem for %d bits." % one_gem_bits))
	_set_check("the pouch is empty after the single sale",
		shop_now.gem_count(PonyDataScript.Rarity.COMMON) == 0)

	# --- the world seed follows the save --------------------------------------------------
	# THE HERD AND THE BOARD HAVE TO BE DRAWN FROM ONE NUMBER, AND THE SAVE OWNS IT.
	# ranch.gd pushed the loaded save's world_seed into the spawner at boot and never again,
	# so a load made mid-session left the spawner still drawing from the seed of the session
	# it had just replaced, while the request board beside it was rebuilt from the loaded
	# one; and then the next save stamped the stale spawner seed back over the loaded save.
	# The symptom is not an error, it is a herd that quietly rearranges itself and a seed
	# that drifts a little further every time she loads.
	#
	# ONLY ASKABLE FROM HERE. It takes a real load through the live GameState autoload with
	# a real spawner attached to it; the ranch's own save round trip probes throwaway
	# GameState instances on purpose, and no GUT test has a ranch.
	var boot_seed: int = ranch.spawner.spawn_seed
	var other_seed: int = boot_seed + 4242
	state.world_seed = other_seed
	_set_check("the save under test lands, with a seed the boot did not have",
		other_seed != boot_seed and state.save_to_slot(SLOT))
	state.reset()
	_set_check("the slot with the other seed loads back", state.load_from_slot(SLOT))
	_set_check("a load hands the spawner the seed it just loaded",
		ranch.spawner.spawn_seed == state.world_seed and state.world_seed == other_seed)
	_set_check("the save lands again after that load", state.save_to_slot(SLOT))
	var reseeded := SaveIOScript.load(SLOT)
	_set_check("and the file still holds the loaded seed, not the boot seed",
		int(reseeded.get("world_seed", 0)) == other_seed)

	# --- pause menu ---------------------------------------------------------------------
	var pause = ranch.get_pause_menu()
	_set_check("the pause menu opens", pause.open())
	_set_check("the tree is paused while paused", get_tree().paused)
	_set_check("the pause menu refuses to open twice", not pause.open())
	pause.close()
	_set_check("resuming unpauses", not get_tree().paused)
	pause.open()
	_set_check("the market refuses while paused", not menu.open())
	pause.close()
	# And the interlock read the other way round, through the ranch's own wiring rather
	# than through a lambda a test wrote: with the Market up, Escape must not stack a pause
	# menu on it. Both directions ask ranch.gd's one predicate (_no_menu_but), and the way
	# that used to go wrong was one direction being enforced only at the call site that
	# happened to remember it.
	_set_check("the market opens again", menu.open())
	_set_check("the pause menu refuses while the market is up", not pause.open())
	_set_check("...and the refusal did not open it", not pause.is_open())
	menu.close()
	_set_check("closing the market unpauses again", not get_tree().paused)

	# --- cleanup ------------------------------------------------------------------------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT)))
	_finish()


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("market_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("market_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("MARKET_OK " if all_ok else "MARKET_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)


## Whether the HUD has said `text` to the player: the line on screen, or anything queued
## behind it.
##
## THE WHOLE QUEUE, NOT THE LABEL ALONE. A toast raised while another one is still up waits
## its turn now instead of overwriting it (game/ui/hud.gd, toast()), which is the fix for a
## sale line the "Request done" line used to wipe out before it could be read. This gate
## drives several toast raising actions in a handful of frames, so the sentence it is
## checking for is routinely two or three behind the label; asking the label alone would be
## asking which of the player's messages happened to be first, not whether she was told.
func _hud_says(hud, text: String) -> bool:
	if hud.toast_text() == text:
		return true
	return hud.pending_toasts().has(text)
