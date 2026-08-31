# Phase 3 Slice 2: The Casino Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a real, honest casino at the edge of the map: a free paved region called the Strip, the Spectra Palace standing on it with its house edge printed on a sign in the lobby, a cage that turns bits into chips and back at one for one, and four games worth playing, one of which is a six lane race you enter your own pony in and watch from the rail.

**Architecture:** Every game is arithmetic first and a scene second. `Slots`, `Wheel`, `Blackjack` and `RaceCard` are `RefCounted` classes with no scene, no node and no wallet: they take a seeded `RandomNumberGenerator`, answer with a result and a payout, and publish their own house edge as a number computed from their own data. `Casino` is a chip purse and nothing else. The four menus draw and emit; `ranch.gd` is the only file that touches `Economy`, `Casino` or a `PonyInstance`, exactly as `depot_menu.gd` and `ranch.gd` already split the Depot. The race is the same split taken into three dimensions: `RaceCard.run()` decides the finish order and each lane's finishing time from the stats and a seed, and `RaceTrack` then walks six visual runners down six lanes so that they cross the line at those times. No `Pony` node is created, adopted or freed anywhere in this slice; the pony you entered stays in her pen the whole time and comes home hungrier and happier.

**Tech Stack:** Godot 4.5.2, GDScript, GUT 9.5.0, the project's headless gate conventions.

**Spec:** `docs/superpowers/specs/2026-08-30-phase3-rainbow-factory-design.md`, sections "The casino", "Pacing", "Data model changes" (the `casino` save key only) and "Testing" (`casino_test`), and build order item 2. The loyalty tier is explicitly a stretch in the spec and is OUT of this slice. The VIP lounge, the Company ban and every story hook are LATER slices and are out; the ban's seam is left as a single `ranch.casino_can_enter()` predicate a later slice returns false from.

## Global Constraints

- **No em dash and no double hyphen in ANY player facing string, nor in new code, comments, docs or data.** ASCII banners like `# --- x ---` are exempt, and so are command line flags. Use ";" or ":" or commas. This binds every sign line, placard line, menu row, toast, doc paragraph and code comment this slice adds. Note that the files you are editing are full of pre existing ` -- ` in their own comments: leave those alone, and do not copy the habit into a line you write.
- **Tone.** Slime Rancher for the ranching feel, Stardew Valley for the town and the forever loop, gambling for fun, a dark humour register. Casino copy is glitzy corporate: "Spectra Palace, proudly sponsored by Cloudsdale Weather Corporation". Never grim, never sneering at the player.
- **The casino is honest and it is never rigged.** The odds shown are the real odds, the house edge is published on a sign in the lobby, and every published number is computed from, or measured against, the code that actually deals. There is no branch anywhere in this slice that looks at who is betting.
- **NO PONY EVER DIES ON SCREEN; only `Pony._state_leaving` may call `queue_free()` on a pony.** Racing never frees, harms or removes a pony. A racer is never taken out of her pen, never handed to the track, and never loses her `PonyInstance`; the track dresses its own visual stand in from her `PonyData` and her palette triple. She comes home hungrier and happier and she was in her pen the whole time.
- **Explicit type annotations wherever `:=` cannot infer the type.** Godot 4.5 promotes `INFERENCE_ON_VARIANT` to an error on the preload dependency compile path; GUT's loader does not catch it, `tools/run_tests.sh`'s parse sweep does.
- **Preload by `res://` path, never by the global `class_name`, in production code AND in test code.** Five separate reviews caught this in slice 1. Concretely: every construction (`X.new()`), every static call (`X.some_static()`) and every constant or enum read (`X.SOME_CONST`) goes through a `const XScript := preload("res://...")` at the top of the file. A bare `class_name` may appear ONLY as a type annotation (`var c: Casino = CasinoScript.new()`), because an annotation does not need the class cache, and the class cache lives in the gitignored `game/.godot/`.
- **Every new `.gd` gets its `.uid` sidecar committed.** Godot writes it on the next import pass; after creating a script run `tools/bin/godot --headless --path game --import` once and `git add` the generated `game/**/*.gd.uid`.
- **Menus draw and emit; `ranch.gd` transacts and pays.** No casino UI file may reference `Economy`, `Casino`, `GameState`, `Pen` or `PonyInstance`. Each menu is handed Callables and hands back signals, exactly as `game/ui/depot_menu.gd` is.
- **Saves: `SaveIO.FORMAT_VERSION` stays 5 in this slice.** The `casino` key is added additively and loads with defaults when missing, so a version 5 save written before this slice loads with zero chips and no migration. `migrate()`'s existing `from_version < 5` branch also states the key, so a version 4 save's migrated output has the version 5 shape. Round trip tests live in `game/test/test_save_io.gd`.
- **Economy safety.** Chips buy in at one bit each and cash out at one bit each; the ONLY house edge in the whole slice is inside the games' own odds. `Economy.spend()` and `Economy.grant()` stay the only paths into and out of the wallet. No negative bet, no bet larger than the chips held, no chip minted by a load. The arithmetic is exploit tested: overpay, zero, negative, a cancel in the middle of a bet.
- **Racing numbers come from the stats the `.tres` files actually carry.** Measured across `game/data/ponies/*.tres`: `base_speed` runs 3.0 (fluttershy, maudpie) to 6.5 (rainbowdash), `base_stamina` 3.5 (sweetiebelle) to 7.5 (maudpie), `base_spirit` 4.0 (pinkamena) to 8.5 (sunsetshimmer). The three hidden stock records in `game/data/hidden/` carry `base_speed` 4.0 with `base_stamina` 1.0 and `base_spirit` 1.0, so a stock pony is deliberately the slowest thing on the card. The rating formula is fixed in Task 4 and stated there.
- **The race result is a function of (field, seed) and of nothing else.** Same field, same seed, same finish order and same finishing times, on any machine, in any run.
- **Gates print their marker only after the verdict is decided; the exit code IS the verdict.** Run as `tools/bin/godot --headless --audio-driver Dummy --path game <scene>`. This slice adds one gate, `casino_test`, and changes the count the ranch gate prints.
- **`MIN_TESTS` in `tools/run_tests.sh` stands at 812 today.** Raise it in the final task to the number the suite actually reports; do not guess it.
- **Branch: `phase3-slice2`.** Commit after every task with `git commit -F <file>`; conventional prefixes (`feat:`, `fix:`, `test:`, `docs:`). Run `bash tools/run_tests.sh` (no `FILLY_SKIP_SWEEP`) before calling any task finished.

---

## What is on disk today

Read this before starting. Everything below was verified against the phase 3 slice 1 tree at `19b5cbb`, which is the base this slice builds on.

**The wallet and the purse.** `game/systems/economy.gd` is a `RefCounted` holding `bits: int` with `sell()`, `grant()`, `can_afford()` and `spend()`. `spend()` refuses a negative cost and refuses what it cannot afford, and a refusal is a no op; `grant()` refuses zero or negative with a `push_error`. `bits_changed(new_total)` fires only when the number actually moved. Task 1's `Casino` is built to the same contract, deliberately, so that a reviewer who knows `economy.gd` recognises it on sight.

**The save.** `game/systems/save_io.gd` has `FORMAT_VERSION := 5`. `game/systems/game_state.gd` lists every key by hand in `to_dict()` and reads every key with a default in `from_dict()`; `reset()` restores new game defaults. `gems`, `compendium`, `ledger` and `player` are REPLACED rather than mutated by `from_dict()` and `reset()`, and `casino` follows the same rule for the same reason.

**The map.** `game/world/terrain.gd` spans `[-HALF, HALF]` on X and Z with `HALF := 110.0`; the homestead apron is flat inside `FLAT_RADIUS := 30.0` of `HOMESTEAD_CENTRE := Vector2(0.0, -4.0)` and blends out to `BLEND_RADIUS := 44.0`. Four regions live in `game/data/regions/`: orchard (72, 40) r22 cost 150, lake (60, -62) r24 cost 300, nightmeadow (-61, 69) r24 cost 700, everfree (-74, -49) r24 cost 1200. `RegionRegistry.all()` returns them sorted by `permit_cost` ascending, id as the tie break, so a region priced at 0 sorts FIRST; three shipped tests depend on details of that ordering and on every region costing something, and Task 5 moves all of them.

**The buildings.** `game/world/ranch.tscn` has a `Buildings` node with five `StaticBody3D` children running `game/world/building.gd`: Barn (ridge 4.9), Farmhouse (4.1), Market (4.0), Board (3.0), Depot (4.0, with a `Crate` Marker3D child). `ranch.gd`'s `_ready()` calls `node.build()` on each, seats it with `Props.seat()`, and computes `prop_count = props.build() + buildings.get_child_count()`; the ranch gate prints `RANCH_OK ponies=49 props=59 assets=present`. `_probe_camera_against_building()` walks `_buildings_by_height()` and measures against the FIRST building that presents a wall to a horizontal ray, which is the Barn because it is the tallest. Task 5 keeps it that way on purpose.

**The menu contract.** `game/ui/depot_menu.gd` is the model to copy: a `CanvasLayer` with `can_open`, three provider Callables and two request signals, an `open()` that refuses when `can_open` says no, a `drawn_lines()` that returns exactly what it is drawing so a test can read the strings without walking `Label` nodes, and `_unhandled_input()` handling `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept` and `ui_cancel`. `ranch.gd` binds it in `_bind_depot_menu()`, gates it with `_no_menu_but(depot_menu)`, opens it from `_update_depot_interaction()` on `interact` within `DEPOT_RADIUS`, and does every transaction itself in `deliver_pony()` and `pay_the_company()`. Pause is owned by `ranch.gd` through `_on_menu_opened_any()` and `_on_menu_closed()`; a menu must never write `get_tree().paused` itself (slice 1 Task 5 found that a menu doing so silently froze about twenty five unrelated tests).

**The ponies' bodies.** `game/actors/pony/pony_visuals.gd` has `static func build(data: PonyData) -> Node3D`, which is how every pony body on the map is made. `game/systems/stock_tint.gd` has `static func apply(model, palette, triple) -> int`, which recolours one. `game/systems/gait.gd` maps a ground speed to a clip: `clip_for_speed(speed)` answers `gallop` above `GALLOP_HANDOVER_SPEED` (1.98 m/s) and stops being skate free above `TOP_SKATE_FREE_SPEED` (4.29 m/s), and `playback_scale_for_clip(clip, speed)` gives the playback rate that makes the hooves match the ground. Task 7's lane speeds sit inside that band on purpose.

**The gates.** `game/scenes/test/ledger_test.gd` and `depot_test.gd` are the current shape: a `Node` scene with `world/ranch.tscn` instanced as a child named `Ranch`, `GateWatchdogScript.arm(self, "<NAME>", <seconds>)` first, `await ranch.gate_report_finished`, a `_checks` dictionary with a duplicate label guard, and a `_finish()` that prints `<NAME>_OK checks=<n>` or `<NAME>_FAILED` and quits with the verdict as the exit code.

## File structure

**New pure logic** (`game/systems/`, all `RefCounted` or `Resource`, all GUT tested with no scene):

| File | Responsibility |
|---|---|
| `casino.gd` | `Casino`: the chip purse. Chips in, chips out, save and load, and every refusal that keeps a chip from being minted. |
| `slots.gd` | `Slots`: three reels, one strip of sixteen symbols, a paytable, and an exactly enumerated return to player. |
| `wheel.gd` | `Wheel`: twenty five pockets, colour and number bets, an edge that is exactly one pocket. |
| `blackjack.gd` | `Blackjack`: one deck, dealer stands on 17, blackjack pays 3 to 2, the placard, the reference strategy, and the measured edge the placard publishes. |
| `race_card.gd` | `RaceCard`: ratings from stats and happiness, win chances, decimal odds with a published takeout, a seeded finish order with finishing times, and what a race does to a racer. |
| `company_runners.gd` | `CompanyRunners`: the five Company owned runners, as an authored resource. |
| `casino_sign.gd` | `CasinoSign`: the lobby sign's lines, read out of the four game classes so the sign cannot drift from the games. |

**New data** (committed `.tres`):

| File | Responsibility |
|---|---|
| `game/data/regions/strip.tres` | The Strip: a free paved region at the north edge of the map. |
| `game/data/casino/company_runners.tres` | The five Company runners' names, stats and colours. |

**New world** (`game/world/`): `strip.gd` (the paved apron's lights and the marquee), `race_track.gd` (six lanes, the rail, the playback), `race_runner.gd` (one visual runner; NOT a `Pony`).

**New UI** (`game/ui/`): `casino_menu.gd`/`.tscn` (the lobby: the cage, the house sign, the four doors), `slots_menu.gd`/`.tscn`, `wheel_menu.gd`/`.tscn`, `blackjack_menu.gd`/`.tscn`, `race_menu.gd`/`.tscn`.

**New gate** (`game/scenes/test/`): `casino_test.gd`/`.tscn`.

**Modified:** `game/systems/game_state.gd` (the `casino` key), `save_io.gd` (`migrate()`'s version 5 shape only; `FORMAT_VERSION` does not move), `game/world/ranch.gd` and `ranch.tscn` (the Palace, the Strip, the track, five menu bindings, every transaction, the free region rules), `game/test/test_region_registry.gd`, `test_shop_registry.gd`, `test_pause_menu.gd`, `test_save_io.gd`, `test_game_state.gd`, `game/scenes/test/region_test.gd`, `tools/run_tests.sh` (`MIN_TESTS`), `docs/testing.md`, `docs/pipeline.md`, `docs/distribution.md`, `docs/windows-testing.md`.

**Why the pure logic comes before the map.** The lobby sign publishes the house edge of all four games, and it publishes numbers the game classes compute rather than numbers somebody typed onto a sign. So `Slots`, `Wheel`, `Blackjack` and `RaceCard` all exist before the building that advertises them does. Tasks 1 to 4 add no scene at all and can be reviewed as arithmetic; Task 5 puts the Strip on the map; Tasks 6 and 7 wire the menus and the track; Task 8 proves the lot.

---

### Task 1: Chips and the cage

**Files:**
- Create: `game/systems/casino.gd`
- Modify: `game/systems/game_state.gd`, `game/systems/save_io.gd:336-360` (`migrate()`'s `from_version < 5` branch)
- Test: `game/test/test_casino.gd`, `game/test/test_game_state.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- Consumes: `Economy.spend(cost: int) -> bool`, `Economy.grant(bits_earned: int) -> void`, `Economy.bits`, `SaveIO.FORMAT_VERSION` (5, unchanged).
- Produces:
  - `class_name Casino extends RefCounted`. `signal chips_changed(new_total: int)`. `var chips: int = 0`. `const KEY_CHIPS := "chips"`, `const CHIP_RATE := 1`. `func _init(starting_chips: int = 0) -> void`. `func add_chips(count: int) -> bool`, `func remove_chips(count: int) -> bool`, `func can_stake(amount: int) -> bool`, `func to_dict() -> Dictionary`, `static func from_dict(d: Dictionary) -> Casino`, `func _to_string() -> String`.
  - `GameState` gains `const KEY_CASINO := "casino"` and `var casino: Casino`, written by `to_dict()`, replaced by `from_dict()` and `reset()`.

**The one rule that makes the cage safe.** Chips are not money and money is not chips: `Casino` never sees an `Economy` and `Economy` never sees a chip. `ranch.gd` is the only thing that ever holds both, and it does them in an order where a refusal cannot leak value: to buy in it spends the bits FIRST and only adds chips if the spend returned true; to cash out it removes the chips FIRST and only grants the bits if the removal returned true. Both halves are no ops on refusal, so there is no state in which the player has been charged for chips she did not get.

- [ ] **Step 1: Write the failing test**

`game/test/test_casino.gd`:

```gdscript
extends GutTest
## THE CHIP PURSE. Every refusal in here is a hole somebody would otherwise walk through
## with a hand edited save or a menu race, so each one gets its own case.

const CasinoScript := preload("res://systems/casino.gd")
const EconomyScript := preload("res://systems/economy.gd")


func test_a_new_purse_is_empty() -> void:
	var purse: Casino = CasinoScript.new()
	assert_eq(purse.chips, 0)


func test_a_negative_starting_count_is_clamped_rather_than_trusted() -> void:
	var purse: Casino = CasinoScript.new(-500)
	assert_eq(purse.chips, 0, "a hand edited save must not open the cage in debt")


func test_adding_chips_moves_the_count_and_announces_it() -> void:
	var purse: Casino = CasinoScript.new()
	watch_signals(purse)
	assert_true(purse.add_chips(250))
	assert_eq(purse.chips, 250)
	assert_signal_emitted_with_parameters(purse, "chips_changed", [250])


func test_adding_zero_or_fewer_chips_is_refused_and_announces_nothing() -> void:
	var purse: Casino = CasinoScript.new(100)
	watch_signals(purse)
	assert_false(purse.add_chips(0), "a buy in of nothing is a caller who thinks it paid")
	assert_false(purse.add_chips(-40), "a negative buy in is a cash out in disguise")
	assert_eq(purse.chips, 100)
	assert_signal_not_emitted(purse, "chips_changed")


func test_removing_more_chips_than_are_held_changes_nothing() -> void:
	var purse: Casino = CasinoScript.new(100)
	watch_signals(purse)
	assert_false(purse.remove_chips(101))
	assert_eq(purse.chips, 100, "a refusal is a no op, never a partial deduction")
	assert_signal_not_emitted(purse, "chips_changed")


func test_removing_a_negative_count_is_refused() -> void:
	var purse: Casino = CasinoScript.new(100)
	assert_false(purse.remove_chips(-25))
	assert_eq(purse.chips, 100)


func test_removing_zero_succeeds_and_announces_nothing() -> void:
	var purse: Casino = CasinoScript.new(100)
	watch_signals(purse)
	assert_true(purse.remove_chips(0), "nothing moved, and nothing failed either")
	assert_eq(purse.chips, 100)
	assert_signal_not_emitted(purse, "chips_changed")


func test_can_stake_refuses_zero_negative_and_more_than_is_held() -> void:
	var purse: Casino = CasinoScript.new(100)
	assert_true(purse.can_stake(1))
	assert_true(purse.can_stake(100))
	assert_false(purse.can_stake(0))
	assert_false(purse.can_stake(-1))
	assert_false(purse.can_stake(101))


func test_bits_and_chips_round_trip_exactly_at_one_for_one() -> void:
	var wallet: Economy = EconomyScript.new(1000)
	var purse: Casino = CasinoScript.new()
	assert_true(wallet.spend(400))
	assert_true(purse.add_chips(400))
	assert_eq(wallet.bits, 600)
	assert_eq(purse.chips, 400)
	assert_true(purse.remove_chips(400))
	wallet.grant(400)
	assert_eq(wallet.bits, 1000, "one bit in, one bit out, nothing kept at the window")
	assert_eq(purse.chips, 0)


func test_a_buy_in_the_wallet_cannot_afford_leaves_both_sides_untouched() -> void:
	var wallet: Economy = EconomyScript.new(50)
	var purse: Casino = CasinoScript.new()
	if wallet.spend(400):
		purse.add_chips(400)
	assert_eq(wallet.bits, 50)
	assert_eq(purse.chips, 0, "spend first, add second: a refused spend adds no chips")


func test_the_purse_round_trips_through_a_dictionary() -> void:
	var purse: Casino = CasinoScript.new(1234)
	var back: Casino = CasinoScript.from_dict(purse.to_dict())
	assert_eq(back.chips, 1234)


func test_a_missing_key_loads_as_an_empty_purse() -> void:
	assert_eq(CasinoScript.from_dict({}).chips, 0)


func test_a_load_can_never_mint_chips() -> void:
	assert_eq(CasinoScript.from_dict({"chips": -900}).chips, 0, "negative clamps to nothing")
	assert_eq(CasinoScript.from_dict({"chips": "9999"}).chips, 0, "a string is not a count")
	assert_eq(CasinoScript.from_dict({"chips": [1, 2]}).chips, 0, "an array is not a count")
	assert_eq(CasinoScript.from_dict({"chips": 40.0}).chips, 40, "JSON hands ints back as floats")
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_casino.gd -gexit`

Expected: FAIL, GUT reports the script was ignored because `res://systems/casino.gd` does not exist.

- [ ] **Step 3: Write `game/systems/casino.gd`**

```gdscript
class_name Casino
extends RefCounted
## THE CHIP PURSE, and nothing else. How many chips the player is holding at the Spectra
## Palace, what may be added, what may be taken away, and how that survives quitting.
##
## IT NEVER SEES THE WALLET. Chips are bought and cashed out at the cage by game/world/
## ranch.gd, which is the only file in the project holding an Economy and a Casino at the
## same time; this class cannot spend a bit or grant one, so no bug in here can reach the
## player's money. That is the same split game/ui/depot_menu.gd has from the Ledger, for
## the same reason.
##
## ONE FOR ONE, BOTH WAYS. A bit buys exactly one chip and a chip cashes out for exactly
## one bit; CHIP_RATE exists so that number has a name rather than being an unwritten
## assumption spread over two call sites. The house makes its money at the tables, and the
## edge is printed on the lobby sign (game/systems/casino_sign.gd). The cage takes nothing.
##
## THE CONTRACT IS ECONOMY'S, DELIBERATELY. add_chips() refuses zero or less the way
## Economy.grant() does, remove_chips() refuses what is not there the way Economy.spend()
## does, a refusal changes nothing at all rather than partially, and chips_changed fires
## only when the number actually moved. A reviewer who knows game/systems/economy.gd knows
## this file already.
##
## Preloaded by path everywhere, never by the class_name: the class cache lives in the
## gitignored game/.godot/ and a fresh clone has not built it yet.

## Bits per chip, in both directions.
const CHIP_RATE := 1

## The key inside the save's `casino` dictionary. Named so the writer and the reader cannot
## disagree by a typo.
const KEY_CHIPS := "chips"

## Emitted when `chips` actually changes. Never for a refusal, and never for a move of
## exactly zero: a signal that fires when nothing moved is as useless as one that never
## fires. Carries the NEW total so a menu can bind to it without a second read.
signal chips_changed(new_total: int)

## How many chips the player is holding. Never negative; see _init() and remove_chips().
var chips: int = 0


func _init(starting_chips: int = 0) -> void:
	chips = maxi(0, starting_chips)


## Buy in, or take a win. Refuses zero or less: a buy in of nothing is a caller that thinks
## it paid something and did not, and a negative one is a cash out wearing a buy in's coat.
func add_chips(count: int) -> bool:
	if count <= 0:
		return false
	chips += count
	chips_changed.emit(chips)
	return true


## Cash out, or stake a bet. Returns false HAVING CHANGED NOTHING when the purse cannot
## cover it, so every caller may treat a false as proof the count did not move. A removal
## of exactly zero succeeds and announces nothing, because nothing happened.
func remove_chips(count: int) -> bool:
	if count < 0 or count > chips:
		return false
	if count == 0:
		return true
	chips -= count
	chips_changed.emit(chips)
	return true


## Whether `amount` is a legal stake right now. A bet must be a positive number of chips
## the player actually holds; this is the one question every game asks before it deals.
func can_stake(amount: int) -> bool:
	return amount > 0 and amount <= chips


func to_dict() -> Dictionary:
	return {KEY_CHIPS: chips}


## Rebuild a purse from a to_dict() dictionary, or from what JSON.parse_string hands back,
## which is the same thing with every number as a float.
##
## NOTHING HERE CAN MINT A CHIP. Only an int or a float is read at all; a string, an array,
## a dictionary or a missing key all load as an empty purse, and a negative count clamps to
## zero. A save file is a text file on the player's disk, and the cage is the one place in
## the game where a number typed into it would turn straight into money.
static func from_dict(d: Dictionary) -> Casino:
	var raw: Variant = d.get(KEY_CHIPS, 0)
	var count := 0
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		count = int(raw)
	return Casino.new(count)


func _to_string() -> String:
	return "Casino(chips=%d)" % chips
```

- [ ] **Step 4: Run the test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_casino.gd -gexit`

Expected: PASS, 13 tests.

- [ ] **Step 5: Write the failing save tests**

Append to `game/test/test_game_state.gd`:

```gdscript
func test_the_chip_purse_round_trips_through_the_state() -> void:
	var state := GameStateScript.new()
	state.casino.add_chips(750)
	var back := GameStateScript.new()
	back.from_dict(state.to_dict())
	assert_eq(back.casino.chips, 750)
	back.free()
	state.free()


func test_a_state_with_no_casino_key_loads_with_an_empty_purse() -> void:
	var state := GameStateScript.new()
	state.casino.add_chips(500)
	state.from_dict({"bits": 10})
	assert_eq(state.casino.chips, 0, "a save from before the Palace opened holds no chips")
	state.free()


func test_reset_empties_the_purse_and_replaces_it() -> void:
	var state := GameStateScript.new()
	var before: Casino = state.casino
	state.casino.add_chips(90)
	state.reset()
	assert_eq(state.casino.chips, 0)
	assert_ne(state.casino, before, "replaced, not mutated; a listener on the old one is stale")
	state.free()
```

Note: `GameStateScript` is already the preload constant at the top of that file; check its exact name before appending and use whatever it is. `GameState` extends `Node`, so the existing tests in that file already free their instances; follow whatever pattern the file already uses rather than the `free()` calls above if it differs.

Append to `game/test/test_save_io.gd`:

```gdscript
func test_a_version_5_save_carries_the_casino_key_back_intact() -> void:
	var written := {"bits": 10, "casino": {"chips": 321}}
	assert_true(SaveIOScript.save(SLOT, written))
	var back := SaveIOScript.load(SLOT)
	assert_eq(int((back["casino"] as Dictionary)["chips"]), 321)


func test_a_version_5_save_written_before_the_palace_opened_loads_with_no_chips() -> void:
	var written := {"bits": 10}
	assert_true(SaveIOScript.save(SLOT, written))
	var back := SaveIOScript.load(SLOT)
	assert_false(back.has("casino"),
		"version 5 is loaded as it stands; GameState.from_dict supplies the default")


func test_migrating_a_version_4_save_states_the_casino_key() -> void:
	var migrated := SaveIOScript.migrate({"bits": 10}, 4)
	assert_true(migrated.has("casino"), "migrate's output states the whole version 5 shape")
	assert_eq(migrated["casino"], {})
```

`SLOT` and `SaveIOScript` are already defined at the top of `test_save_io.gd`; use that file's own names.

- [ ] **Step 6: Run the save tests to see them fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_game_state.gd,res://test/test_save_io.gd -gexit`

Expected: FAIL on `state.casino` not existing and on `migrate()` not producing a `casino` key.

- [ ] **Step 7: Wire the key into `game_state.gd` and `save_io.gd`**

In `game/systems/game_state.gd`, add the preload beside the others:

```gdscript
const CasinoScript := preload("res://systems/casino.gd")
```

Add the key constant beside `KEY_PLAYER`:

```gdscript
const KEY_CASINO := "casino"
```

Add the field beside `player`:

```gdscript
## THE CHIPS SHE IS HOLDING AT THE PALACE (game/systems/casino.gd). REPLACED, NOT MUTATED,
## by from_dict() and reset(), the same rule `gems`, `compendium`, `ledger` and `player`
## follow: a listener holding the old purse is holding the chips of a ranch nobody is
## playing any more.
var casino: Casino = CasinoScript.new()
```

Add to `to_dict()`'s returned dictionary, after `KEY_PLAYER`:

```gdscript
		KEY_CASINO: casino.to_dict(),
```

Add to `from_dict()`, immediately after the `player` block and before `state_loaded.emit()`:

```gdscript
	var saved_casino: Variant = data.get(KEY_CASINO, {})
	casino = CasinoScript.from_dict(
		saved_casino if typeof(saved_casino) == TYPE_DICTIONARY else {})
```

Add to `reset()`, after the `player` line:

```gdscript
	casino = CasinoScript.new()
```

In `game/systems/save_io.gd`, inside the existing `if from_version < 5:` branch of `migrate()`, after the `player` default:

```gdscript
		if not out.has("casino"):
			# An empty dictionary is Casino.from_dict's own "no chips", which is what a save
			# from before the Palace opened should load as. Stated here rather than left to
			# that default so migrate()'s OUTPUT states the whole version 5 shape.
			out["casino"] = {}
```

FORMAT_VERSION does not move. A version 5 save with no `casino` key is loaded as it stands and gets its default from `GameState.from_dict()`; a version 4 save gets it here. Both paths have a test above.

- [ ] **Step 8: Run the full suite**

Run: `bash tools/run_tests.sh`

Expected: green, and the `Tests` line has risen by 19.

- [ ] **Step 9: Commit**

```bash
git checkout -b phase3-slice2
printf 'feat: the chip purse; bits in and bits out at one for one\n\nCasino holds chips and nothing else: it never sees the wallet, so no bug\nin it can reach the player'"'"'s money. ranch.gd spends first and adds chips\nsecond when buying in, and removes chips first and grants bits second when\ncashing out, so a refusal on either side leaves both untouched.\n\nThe casino key is added to the save additively. FORMAT_VERSION stays 5: a\nversion 5 save written before this slice loads with an empty purse, and\nmigrate() states the key so a version 4 save'"'"'s migrated output has the\nwhole version 5 shape. Nothing in from_dict can mint a chip.\n' > /tmp/casino-commit.txt
git add game/systems/casino.gd game/systems/casino.gd.uid game/systems/game_state.gd game/systems/save_io.gd game/test/test_casino.gd game/test/test_game_state.gd game/test/test_save_io.gd
git commit -F /tmp/casino-commit.txt
```

If `game/systems/casino.gd.uid` does not exist yet, run `tools/bin/godot --headless --path game --import` first and add it in the same commit.

---

### Task 2: Slots and the Wheel

**Files:**
- Create: `game/systems/slots.gd`, `game/systems/wheel.gd`
- Test: `game/test/test_slots.gd`, `game/test/test_wheel.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks. Both classes are static only and take a `RandomNumberGenerator` from the caller.
- Produces:
  - `class_name Slots extends RefCounted`, static only. `enum Symbol { APPLE, HORSESHOE, BELL, GEM, STAR, RAINBOW }`. `const SYMBOL_NAMES: Array[String]`, `const REEL_SIZE := 16`, `const STRIP_COUNTS: Array[int]`, `const TRIPLE_PAYS: Array[int]`, `const TWO_RAINBOW_PAY := 5`, `const ONE_RAINBOW_PAY := 1`, `const REELS := 3`. `static func strip() -> Array[int]`, `static func spin(rng: RandomNumberGenerator) -> Array[int]`, `static func payout(reels: Array[int], stake: int) -> int`, `static func return_to_player() -> float`, `static func house_edge() -> float`, `static func line_text(reels: Array[int]) -> String`, `static func paytable_lines() -> Array[String]`.
  - `class_name Wheel extends RefCounted`, static only. `enum Colour { RED, ORANGE, YELLOW, GREEN, BLUE, VIOLET, HOUSE }`, `enum Bet { NUMBER, COLOUR }`. `const NUMBERS := 24`, `const POCKETS := 25`, `const COLOUR_RUN := 4`, `const HOUSE_POCKET := 0`, `const NUMBER_PAYS_TO_ONE := 23`, `const COLOUR_PAYS_TO_ONE := 5`, `const COLOUR_NAMES: Array[String]`. `static func colour_of(pocket: int) -> int`, `static func spin(rng: RandomNumberGenerator) -> int`, `static func payout(kind: int, guess: int, pocket: int, stake: int) -> int`, `static func return_to_player() -> float`, `static func house_edge() -> float`, `static func pocket_text(pocket: int) -> String`, `static func rules_lines() -> Array[String]`.

**THE PAYOUT CONTRACT, and it is the same in all four games.** `payout()` returns the TOTAL number of chips handed back to the player, the stake INCLUDED. A losing bet returns 0. A push returns the stake. So the settle at `ranch.gd` is always the same two lines: take the stake out of the purse, then put `payout()` back in if it is above zero. And the return to player is exactly `mean(payout) / stake`, which is what the convergence tests measure.

**The slots numbers, derived rather than chosen.** One strip of sixteen positions per reel, the same strip on all three: five APPLE, four HORSESHOE, three BELL, two GEM, one STAR, one RAINBOW. That is 16 cubed, 4096, equally likely position triples, so the return to player can be ENUMERATED exactly rather than estimated. Three of a kind pays 4, 10, 27, 55, 150 and 450 for apple, horseshoe, bell, gem, star and rainbow. Any spin that is not three of a kind pays 5 for exactly two rainbows and 1 (the stake back) for exactly one. The three cases are disjoint by construction: three rainbows is a triple, so it is never counted as "exactly two" or "exactly one".

Counting it out in units of the stake, over all 4096 position triples:

- triples: 125 apple at 4, 64 horseshoe at 10, 27 bell at 27, 8 gem at 55, 1 star at 150, 1 rainbow at 450, which is 500 + 640 + 729 + 440 + 150 + 450 = 2909
- exactly two rainbows: 3 x 1 x 1 x 15 = 45 outcomes at 5, which is 225
- exactly one rainbow: 3 x 1 x 15 x 15 = 675 outcomes at 1, which is 675

Total 3809 of 4096, so the return to player is exactly 3809 / 4096 = 0.929931640625 and the house edge is 287 / 4096 = 0.070068359375, which the sign prints as 7.0. `return_to_player()` computes this by walking the strip three deep rather than by carrying the number as a constant, so a change to the strip or to a pay changes the published edge in the same edit.

**Why the paytable is a `const` table in the script and not a `.tres`.** This project already
has a settled pattern for "one constant table is the single source of truth about a price":
`Economy.GEM_VALUE_BY_RARITY` and `SpawnTable.WEIGHTS` are both `const Dictionary` on a
`RefCounted` with a comment explaining that a `RefCounted` script has no inspector to
`@export` into anyway. The slots paytable is the same kind of thing, and it has one extra
reason to live beside the code: `return_to_player()` walks it to compute the published house
edge, so the table and the number on the sign are read in the same file, in the same breath,
and cannot drift. A `.tres` would move the paytable somewhere the sign would have to go and
load it from, and buy no authoring that editing `STRIP_COUNTS` and `TRIPLE_PAYS` does not
already buy. The Company runners ARE a `.tres` (Task 4), because five runners with names and
colours is authored content and this is a price list.

**The wheel numbers.** Twenty five pockets: 0, the Cloudsdale house pocket, which is no colour and wins nothing, and 1 to 24 in six colour runs of four. A number bet wins one time in twenty five and pays 23 to one, so it returns 24 stakes on a win and 24 / 25 of the stake on average. A colour bet wins four times in twenty five and pays 5 to one, so it returns 6 stakes on a win and 24 / 25 on average. Both edges are exactly one pocket, 1 / 25 = 0.04, which the sign prints as 4.0. There is no bet on this wheel with a different edge, and the tests assert that.

- [ ] **Step 1: Write the failing slots test**

`game/test/test_slots.gd`:

```gdscript
extends GutTest
## THE SLOTS, as arithmetic. The interesting claim is that the published house edge is a
## fact about the strip and the paytable rather than a number typed onto a sign, so most of
## this file is about return_to_player() being enumerated and the seeded spin agreeing with
## it over a long run.

const SlotsScript := preload("res://systems/slots.gd")

## Enough spins for the measured return to sit inside a per cent of the exact one. The gate
## (game/scenes/test/casino_test.gd) runs a hundred thousand; the suite runs this many so it
## stays a suite rather than a coffee break.
const SAMPLE_SPINS := 20000


func test_the_strip_is_sixteen_positions_and_holds_every_symbol() -> void:
	var strip: Array[int] = SlotsScript.strip()
	assert_eq(strip.size(), SlotsScript.REEL_SIZE)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for symbol in strip:
		counts[symbol] += 1
	assert_eq(counts, SlotsScript.STRIP_COUNTS, "the strip is exactly what STRIP_COUNTS says")


func test_three_of_a_kind_pays_the_paytable_and_a_losing_line_pays_nothing() -> void:
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.APPLE, SlotsScript.Symbol.APPLE,
		SlotsScript.Symbol.APPLE], 10), 40)
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
		SlotsScript.Symbol.RAINBOW], 10), 4500)
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.APPLE, SlotsScript.Symbol.BELL,
		SlotsScript.Symbol.GEM], 10), 0)


func test_rainbows_outside_a_triple_pay_a_consolation() -> void:
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
		SlotsScript.Symbol.APPLE], 10), 50, "two rainbows pay five")
	assert_eq(SlotsScript.payout([SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.APPLE,
		SlotsScript.Symbol.BELL], 10), 10, "one rainbow hands the stake back")


func test_a_zero_or_negative_stake_pays_nothing_at_all() -> void:
	var jackpot: Array[int] = [SlotsScript.Symbol.RAINBOW, SlotsScript.Symbol.RAINBOW,
		SlotsScript.Symbol.RAINBOW]
	assert_eq(SlotsScript.payout(jackpot, 0), 0)
	assert_eq(SlotsScript.payout(jackpot, -50), 0, "there is no such thing as a negative bet")


func test_the_return_to_player_is_the_enumerated_fraction_and_nothing_else() -> void:
	assert_almost_eq(SlotsScript.return_to_player(), 3809.0 / 4096.0, 1e-9,
		"3809 units returned over 4096 equally likely position triples")
	assert_almost_eq(SlotsScript.house_edge(), 287.0 / 4096.0, 1e-9)


func test_the_published_edge_reads_as_seven_per_cent() -> void:
	assert_eq("%.1f" % (SlotsScript.house_edge() * 100.0), "7.0")


func test_a_spin_is_three_symbols_and_never_leaves_the_alphabet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 500:
		var reels: Array[int] = SlotsScript.spin(rng)
		assert_eq(reels.size(), SlotsScript.REELS)
		for symbol in reels:
			assert_between(symbol, 0, SlotsScript.SYMBOL_NAMES.size() - 1)


func test_the_same_seed_spins_the_same_reels() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	for i in 50:
		assert_eq(SlotsScript.spin(a), SlotsScript.spin(b))


func test_a_long_seeded_run_converges_on_the_published_edge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	var staked := 0
	var returned := 0
	for i in SAMPLE_SPINS:
		staked += 100
		returned += SlotsScript.payout(SlotsScript.spin(rng), 100)
	var measured: float = 1.0 - (float(returned) / float(staked))
	assert_almost_eq(measured, SlotsScript.house_edge(), 0.02,
		"the sign is honest: measured %.4f against a published %.4f"
			% [measured, SlotsScript.house_edge()])


func test_every_paytable_line_is_printable_and_carries_no_dashes() -> void:
	var lines: Array[String] = SlotsScript.paytable_lines()
	assert_gt(lines.size(), 0)
	for line in lines:
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"),
			"player facing copy carries no double hyphen and no em dash: %s" % line)
```

- [ ] **Step 2: Run it to see it fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_slots.gd -gexit`

Expected: FAIL, the script is ignored because `res://systems/slots.gd` does not exist.

- [ ] **Step 3: Write `game/systems/slots.gd`**

```gdscript
class_name Slots
extends RefCounted
## THE FAST ONE. Three reels, one strip of sixteen symbols, and a paytable, with the whole
## of it enumerable: sixteen cubed is 4096 equally likely position triples, so the return to
## player is a fraction this file can WORK OUT rather than a number somebody measured once
## and typed onto a sign.
##
## THAT IS THE POINT OF THE FILE. The Spectra Palace publishes its house edge in the lobby
## (game/systems/casino_sign.gd) and the spec's promise is that the number on the sign is
## real. Here it is real by construction: return_to_player() walks the strip three deep and
## adds up what the paytable pays, so changing a symbol count or a pay changes the sign in
## the same edit, and there is no way to make the sign lie without the tests noticing.
##
## THE ARITHMETIC, IN UNITS OF THE STAKE, over all 4096 position triples:
##
##   three of a kind   125 apple at 4, 64 horseshoe at 10, 27 bell at 27, 8 gem at 55,
##                     1 star at 150, 1 rainbow at 450                          = 2909
##   exactly two rainbows   3 x 15 = 45 outcomes at 5                           =  225
##   exactly one rainbow    3 x 15 x 15 = 675 outcomes at 1 (the stake back)    =  675
##                                                                        total = 3809
##
## 3809 / 4096 back to the player, 287 / 4096 to the house, which is 7.0 per cent. The three
## cases are disjoint: three rainbows is a triple, so it is never also counted as "exactly
## two" or "exactly one".
##
## STATIC ONLY, no state, no scene, no clock. spin() takes the caller's RandomNumberGenerator
## rather than owning one, the same discipline game/systems/needs.gd's tick() takes its delta
## by, so a gate can seed a hundred thousand spins and get the same hundred thousand back.
## Preload by path, never by the class_name.

enum Symbol { APPLE, HORSESHOE, BELL, GEM, STAR, RAINBOW }

## How many reels spin. Three, and named, because payout() indexes the array it is handed.
const REELS := 3

## Positions on one reel. All three reels share the same strip; a different strip per reel
## would buy nothing except an enumeration nobody could check by hand.
const REEL_SIZE := 16

## Positions given to each symbol, indexed by Symbol. Sums to REEL_SIZE, which
## test_slots.gd asserts rather than trusts.
const STRIP_COUNTS: Array[int] = [5, 4, 3, 2, 1, 1]

## What three of a kind pays, as a multiple of the stake, indexed by Symbol.
const TRIPLE_PAYS: Array[int] = [4, 10, 27, 55, 150, 450]

## Exactly two rainbows on a line that is not a triple.
const TWO_RAINBOW_PAY := 5

## Exactly one rainbow on a line that is not a triple: the stake back, which is the smallest
## honest thing a slot machine can do and is why the reels feel alive at a low stake.
const ONE_RAINBOW_PAY := 1

## Player facing, so no dashes.
const SYMBOL_NAMES: Array[String] = ["Apple", "Horseshoe", "Bell", "Gem", "Star", "Rainbow"]


## One reel's symbols, in strip order. Built rather than authored so it cannot drift from
## STRIP_COUNTS.
static func strip() -> Array[int]:
	var out: Array[int] = []
	for symbol in STRIP_COUNTS.size():
		for i in STRIP_COUNTS[symbol]:
			out.append(symbol)
	return out


## Three symbols, one per reel, drawn uniformly over the strip's positions. Uniform over
## POSITIONS and not over symbols, which is what makes the enumeration in return_to_player()
## correct.
static func spin(rng: RandomNumberGenerator) -> Array[int]:
	var reel: Array[int] = strip()
	var out: Array[int] = []
	for i in REELS:
		out.append(reel[rng.randi_range(0, REEL_SIZE - 1)])
	return out


## Chips handed back to the player for this line, THE STAKE INCLUDED. A loss returns 0. That
## contract is shared by every game in the casino, so the settle at ranch.gd is always the
## same two lines: take the stake, then put this back if it is above zero.
static func payout(reels: Array[int], stake: int) -> int:
	if stake <= 0 or reels.size() != REELS:
		return 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return TRIPLE_PAYS[reels[0]] * stake
	var rainbows := 0
	for symbol in reels:
		if symbol == Symbol.RAINBOW:
			rainbows += 1
	if rainbows == 2:
		return TWO_RAINBOW_PAY * stake
	if rainbows == 1:
		return ONE_RAINBOW_PAY * stake
	return 0


## The exact long run return per unit staked, by walking every one of the REEL_SIZE cubed
## equally likely position triples. 4096 iterations, so this is cheap enough to call from a
## sign that is being drawn.
static func return_to_player() -> float:
	var reel: Array[int] = strip()
	var total := 0
	for a in reel:
		for b in reel:
			for c in reel:
				total += payout([a, b, c], 1)
	return float(total) / float(REEL_SIZE * REEL_SIZE * REEL_SIZE)


## What the house keeps, per unit staked. This is the number on the lobby sign.
static func house_edge() -> float:
	return 1.0 - return_to_player()


## One line per winning combination, for the machine's own paytable panel.
static func paytable_lines() -> Array[String]:
	var lines: Array[String] = []
	for symbol in SYMBOL_NAMES.size():
		lines.append("%s %s %s pays %d to 1"
			% [SYMBOL_NAMES[symbol], SYMBOL_NAMES[symbol], SYMBOL_NAMES[symbol],
				TRIPLE_PAYS[symbol]])
	lines.append("Two Rainbows anywhere pays %d to 1" % TWO_RAINBOW_PAY)
	lines.append("One Rainbow anywhere hands your stake back")
	return lines


## The three symbols as one readable line, for the machine's window and for a toast.
static func line_text(reels: Array[int]) -> String:
	var names: Array[String] = []
	for symbol in reels:
		names.append(SYMBOL_NAMES[symbol] if symbol >= 0 and symbol < SYMBOL_NAMES.size()
			else "?")
	return " ".join(names)
```

- [ ] **Step 4: Run the slots test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_slots.gd -gexit`

Expected: PASS, 10 tests. If `test_the_return_to_player_is_the_enumerated_fraction_and_nothing_else` fails, the strip or a pay was typed wrong; the class comment carries the arithmetic to check it against.

- [ ] **Step 5: Write the failing wheel test**

`game/test/test_wheel.gd`:

```gdscript
extends GutTest
## THE WHEEL. Roulette without the layout: twenty five pockets, a bet on a colour or on a
## number, and exactly one pocket of house edge on either bet. The claim worth testing is
## that "either bet" part; a wheel where one of the two bets is worse than the sign says is
## exactly the dishonesty this casino is not allowed to have.

const WheelScript := preload("res://systems/wheel.gd")

const SAMPLE_SPINS := 20000


func test_the_house_pocket_has_no_colour_and_the_rest_run_in_fours() -> void:
	assert_eq(WheelScript.colour_of(WheelScript.HOUSE_POCKET), WheelScript.Colour.HOUSE)
	assert_eq(WheelScript.colour_of(1), WheelScript.Colour.RED)
	assert_eq(WheelScript.colour_of(4), WheelScript.Colour.RED)
	assert_eq(WheelScript.colour_of(5), WheelScript.Colour.ORANGE)
	assert_eq(WheelScript.colour_of(24), WheelScript.Colour.VIOLET)


func test_every_colour_owns_exactly_four_numbers() -> void:
	var counts: Dictionary = {}
	for pocket in range(1, WheelScript.NUMBERS + 1):
		var colour: int = WheelScript.colour_of(pocket)
		counts[colour] = int(counts.get(colour, 0)) + 1
	assert_eq(counts.size(), 6, "six colours, and the house pocket is not one of them")
	for colour in counts:
		assert_eq(int(counts[colour]), WheelScript.COLOUR_RUN)


func test_a_number_bet_pays_twenty_three_to_one_and_nothing_otherwise() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 7, 10), 240)
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 8, 10), 0)
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, WheelScript.HOUSE_POCKET, 10), 0)


func test_a_colour_bet_pays_five_to_one_and_the_house_pocket_beats_every_colour() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.RED, 3, 10), 60)
	assert_eq(WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.RED, 9, 10), 0)
	assert_eq(WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.RED,
		WheelScript.HOUSE_POCKET, 10), 0, "you cannot bet the house pocket's colour")


func test_a_bet_on_a_number_that_is_not_on_the_wheel_pays_nothing() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 0, 0, 10), 0,
		"the house pocket is not a number you may back")
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 25, 25, 10), 0)


func test_a_zero_or_negative_stake_pays_nothing() -> void:
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 7, 0), 0)
	assert_eq(WheelScript.payout(WheelScript.Bet.NUMBER, 7, 7, -10), 0)


func test_both_bets_carry_exactly_one_pocket_of_edge() -> void:
	assert_almost_eq(WheelScript.house_edge(), 1.0 / 25.0, 1e-12)
	var number_return := float(WheelScript.NUMBER_PAYS_TO_ONE + 1) / float(WheelScript.POCKETS)
	var colour_return := float(WheelScript.COLOUR_PAYS_TO_ONE + 1) \
		* float(WheelScript.COLOUR_RUN) / float(WheelScript.POCKETS)
	assert_almost_eq(number_return, WheelScript.return_to_player(), 1e-12)
	assert_almost_eq(colour_return, WheelScript.return_to_player(), 1e-12,
		"a colour bet and a number bet must be worth exactly the same")


func test_the_published_edge_reads_as_four_per_cent() -> void:
	assert_eq("%.1f" % (WheelScript.house_edge() * 100.0), "4.0")


func test_a_spin_never_leaves_the_wheel_and_a_seed_repeats_it() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 5150
	var b := RandomNumberGenerator.new()
	b.seed = 5150
	for i in 500:
		var pocket: int = WheelScript.spin(a)
		assert_between(pocket, 0, WheelScript.NUMBERS)
		assert_eq(pocket, WheelScript.spin(b))


func test_a_long_seeded_colour_run_converges_on_the_published_edge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260901
	var staked := 0
	var returned := 0
	for i in SAMPLE_SPINS:
		staked += 100
		returned += WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.GREEN,
			WheelScript.spin(rng), 100)
	var measured: float = 1.0 - (float(returned) / float(staked))
	assert_almost_eq(measured, WheelScript.house_edge(), 0.02,
		"measured %.4f against a published %.4f" % [measured, WheelScript.house_edge()])


func test_the_rules_placard_carries_no_dashes() -> void:
	for line in WheelScript.rules_lines():
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"), line)
```

- [ ] **Step 6: Run it to see it fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_wheel.gd -gexit`

Expected: FAIL, `res://systems/wheel.gd` does not exist.

- [ ] **Step 7: Write `game/systems/wheel.gd`**

```gdscript
class_name Wheel
extends RefCounted
## THE RAINBOW WHEEL. Roulette without the layout: back a colour or back a number, one
## pocket of house edge either way, and no bet on the felt that is worse than the sign says.
##
## TWENTY FIVE POCKETS. Pocket 0 is the Cloudsdale house pocket: it has no colour, no number
## may be laid on it, and it beats every bet on the wheel. Pockets 1 to 24 run in six colour
## bands of four, in rainbow order, which is where the wheel gets its name and its paint.
##
## WHY THE EDGE IS THE SAME ON BOTH BETS, and why that is worth a test. A number wins one
## time in twenty five and pays 23 to 1, so it hands back 24 stakes on a win, 24 / 25 of a
## stake on average. A colour wins four times in twenty five and pays 5 to 1, so it hands
## back 6 stakes on a win, 24 / 25 on average. Both are one pocket, 4.0 per cent, which is
## what the lobby sign prints. A casino where the pretty bet is the bad bet is a casino that
## is quietly lying to a player who has not done the arithmetic, and this one does not.
##
## Static only; spin() takes the caller's RandomNumberGenerator. Preload by path.

enum Colour { RED, ORANGE, YELLOW, GREEN, BLUE, VIOLET, HOUSE }
enum Bet { NUMBER, COLOUR }

## Numbers on the wheel, 1 to NUMBERS.
const NUMBERS := 24

## Numbers per colour band.
const COLOUR_RUN := 4

## The colourless pocket the house owns.
const HOUSE_POCKET := 0

## Every pocket, the house one included.
const POCKETS := NUMBERS + 1

## A number bet pays this to one, so a winner takes back this plus her stake.
const NUMBER_PAYS_TO_ONE := 23

## A colour bet pays this to one.
const COLOUR_PAYS_TO_ONE := 5

## Player facing, so no dashes. Indexed by Colour, with the house pocket last.
const COLOUR_NAMES: Array[String] = ["Red", "Orange", "Yellow", "Green", "Blue", "Violet",
	"Cloudsdale"]


## The colour band a pocket belongs to. The house pocket answers Colour.HOUSE, which no bet
## may name, so it wins nothing for anybody.
static func colour_of(pocket: int) -> int:
	if pocket < 1 or pocket > NUMBERS:
		return Colour.HOUSE
	return (pocket - 1) / COLOUR_RUN


## Where the ball lands: 0 to NUMBERS inclusive, uniform.
static func spin(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, NUMBERS)


## Chips handed back, THE STAKE INCLUDED; 0 for a loss. See Slots.payout() for the contract.
##
## A bet naming something that is not on the wheel loses rather than erroring: `guess` comes
## in from a menu, and a menu that has drifted should cost the player one stake and a raised
## eyebrow rather than take the game down.
static func payout(kind: int, guess: int, pocket: int, stake: int) -> int:
	if stake <= 0:
		return 0
	match kind:
		Bet.NUMBER:
			if guess < 1 or guess > NUMBERS:
				return 0
			return (NUMBER_PAYS_TO_ONE + 1) * stake if guess == pocket else 0
		Bet.COLOUR:
			if guess < 0 or guess >= Colour.HOUSE:
				return 0
			return (COLOUR_PAYS_TO_ONE + 1) * stake if colour_of(pocket) == guess else 0
	return 0


## The long run return per unit staked. The same for a number and for a colour; the number
## bet's form is the one written out here because it is the shorter of the two, and
## test_wheel.gd checks the colour bet's form against it.
static func return_to_player() -> float:
	return float(NUMBER_PAYS_TO_ONE + 1) / float(POCKETS)


## What the house keeps: exactly one pocket.
static func house_edge() -> float:
	return 1.0 - return_to_player()


## What the ball did, as a line the felt can show.
static func pocket_text(pocket: int) -> String:
	if pocket < 1 or pocket > NUMBERS:
		return "Cloudsdale pocket. The house takes this one."
	return "%d, %s" % [pocket, COLOUR_NAMES[colour_of(pocket)]]


## The felt's own rules, for the table panel.
static func rules_lines() -> Array[String]:
	return [
		"The Wheel: %d pockets, %d numbers in six colours, and one for us."
			% [POCKETS, NUMBERS],
		"A number pays %d to 1. A colour pays %d to 1."
			% [NUMBER_PAYS_TO_ONE, COLOUR_PAYS_TO_ONE],
		"Both bets are worth the same; we did the arithmetic so you can check it.",
		"The Cloudsdale pocket is ours. It comes up one spin in %d." % POCKETS,
	]
```

- [ ] **Step 8: Run both tests, then the suite**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_slots.gd,res://test/test_wheel.gd -gexit`

Expected: PASS, 21 tests.

Run: `bash tools/run_tests.sh`

Expected: green, the `Tests` line up by 21 from Task 1.

- [ ] **Step 9: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: the slots and the wheel, with their edges worked out rather than typed\n\nSlots enumerates all 4096 position triples to publish its own return to\nplayer: 3809 of 4096 back, 287 of 4096 kept, 7.0 per cent. Changing a strip\ncount or a pay changes the sign in the same edit.\n\nThe Wheel is 25 pockets and two bets that are deliberately worth exactly the\nsame: 24 of 25 back on either, one pocket of edge, 4.0 per cent. A casino\nwhere the pretty bet is the bad bet is one that lies to a player who has not\ndone the arithmetic.\n\nEvery payout() in the casino returns the total handed back, stake included.\n' > /tmp/casino-commit.txt
git add game/systems/slots.gd game/systems/slots.gd.uid game/systems/wheel.gd game/systems/wheel.gd.uid game/test/test_slots.gd game/test/test_wheel.gd
git commit -F /tmp/casino-commit.txt
```

---

### Task 3: Blackjack

**Files:**
- Create: `game/systems/blackjack.gd`
- Test: `game/test/test_blackjack.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `class_name Blackjack extends RefCounted`, static only. `enum Outcome { DEALER_WIN, PLAYER_WIN, PUSH, PLAYER_BLACKJACK }`. `const DECK_SIZE := 52`, `const DEALER_STANDS_ON := 17`, `const STRATEGY_DRAWS_BELOW := 17`, `const BLACKJACK_PAYS_NUMERATOR := 3`, `const BLACKJACK_PAYS_DENOMINATOR := 2`, `const REFERENCE_SEED := 20260902`, `const REFERENCE_HANDS := 100000`, `const PUBLISHED_EDGE: float`, `const PLACARD: Array[String]`. `static func card_value(card: int) -> int`, `static func is_ace(card: int) -> bool`, `static func hand_total(cards: Array[int]) -> int`, `static func is_blackjack(cards: Array[int]) -> bool`, `static func play_hand(rng: RandomNumberGenerator) -> Dictionary`, `static func payout(outcome: int, stake: int) -> int`, `static func measure_edge(seed: int, hands: int) -> float`, `static func house_edge() -> float`, `static func outcome_text(hand: Dictionary) -> String`, `static func card_text(card: int) -> String`, `static func placard_lines() -> Array[String]`.

**Why this game's published number is measured and the other three are computed.** Slots and the Wheel have an edge that is a property of the machine alone, so it can be enumerated. Blackjack's edge is a property of the machine AND of how the player plays, so a bare number would be meaningless. The Palace resolves this the honest way: the placard prints a strategy card, "draw below 17, stand on 17 or more", and the published edge is the edge AGAINST THAT CARD, measured over `REFERENCE_HANDS` hands from `REFERENCE_SEED` by the very code that deals. `PUBLISHED_EDGE` is that measurement written down, and a test re asserts it every run to within 0.0005, so the placard cannot drift from the dealer by so much as a rounding. A player who plays better than the card does better than the sign says, which is the correct direction for a sign to be wrong in.

**The deal, concretely.** A card is an int 0 to 51; its rank is `card % 13`, where rank 0 is an ace worth 11 until it has to be worth 1, ranks 1 to 8 are the two through nine, and ranks 9 to 12 are the ten and the three court cards, all worth 10. A hand is dealt from a fresh 52 card deck by a partial Fisher Yates: swap a random card from the undealt tail to the front of the tail and take it. That is one swap per card instead of 52 per hand, which is what makes a hundred thousand hands a gate step rather than a coffee break.

- [ ] **Step 1: Write the failing test**

`game/test/test_blackjack.gd`:

```gdscript
extends GutTest
## BLACKJACK, as arithmetic. Two things are being pinned: that the hand plays by the rules
## on the placard, and that the edge the placard publishes is the edge this code actually
## deals, measured rather than asserted.

const BlackjackScript := preload("res://systems/blackjack.gd")

## Enough hands for the measured edge to sit inside a couple of points. The gate runs the
## full REFERENCE_HANDS; the suite runs this so it stays a suite.
const SAMPLE_HANDS := 20000


func test_an_ace_is_eleven_until_it_has_to_be_one() -> void:
	assert_eq(BlackjackScript.hand_total([0, 12]), 21, "ace and king is twenty one")
	assert_eq(BlackjackScript.hand_total([0, 0]), 12, "two aces is twelve, not twenty two")
	assert_eq(BlackjackScript.hand_total([0, 0, 0]), 13)
	assert_eq(BlackjackScript.hand_total([0, 9, 9]), 21, "ace demotes rather than busting")


func test_the_court_cards_and_the_pips_are_worth_what_they_look_like() -> void:
	assert_eq(BlackjackScript.card_value(0), 11, "rank 0 is the ace")
	assert_eq(BlackjackScript.card_value(1), 2)
	assert_eq(BlackjackScript.card_value(8), 9)
	assert_eq(BlackjackScript.card_value(9), 10, "the ten")
	assert_eq(BlackjackScript.card_value(12), 10, "the king")
	assert_eq(BlackjackScript.card_value(13), 11, "the second suit's ace")


func test_a_blackjack_is_two_cards_and_only_two() -> void:
	assert_true(BlackjackScript.is_blackjack([0, 12]))
	assert_false(BlackjackScript.is_blackjack([9, 4, 5]), "twenty one on three cards is not it")
	assert_false(BlackjackScript.is_blackjack([9, 9]))


func test_the_payout_table_is_the_one_on_the_placard() -> void:
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_BLACKJACK, 100), 250,
		"stake back plus three to two")
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_WIN, 100), 200)
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PUSH, 100), 100, "a tie is a push")
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.DEALER_WIN, 100), 0)


func test_a_zero_or_negative_stake_pays_nothing() -> void:
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_BLACKJACK, 0), 0)
	assert_eq(BlackjackScript.payout(BlackjackScript.Outcome.PLAYER_WIN, -100), 0)


func test_a_hand_deals_real_cards_and_never_deals_one_twice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 500:
		var hand: Dictionary = BlackjackScript.play_hand(rng)
		var seen: Dictionary = {}
		for card in (hand["player"] as Array) + (hand["dealer"] as Array):
			assert_between(int(card), 0, BlackjackScript.DECK_SIZE - 1)
			assert_false(seen.has(card), "one deck, so no card comes out twice in a hand")
			seen[card] = true
		assert_gt((hand["player"] as Array).size(), 1)
		assert_gt((hand["dealer"] as Array).size(), 1)


func test_the_dealer_stands_on_seventeen_and_draws_below_it() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 2000:
		var hand: Dictionary = BlackjackScript.play_hand(rng)
		var dealer: Array = hand["dealer"]
		var total: int = BlackjackScript.hand_total(dealer)
		if int(hand["outcome"]) == BlackjackScript.Outcome.PLAYER_BLACKJACK:
			continue
		if total <= 21 and dealer.size() > 2:
			assert_gte(total, BlackjackScript.DEALER_STANDS_ON,
				"the dealer never stopped below seventeen")


func test_the_house_strategy_card_is_what_the_player_actually_plays() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5678
	for i in 2000:
		var hand: Dictionary = BlackjackScript.play_hand(rng)
		var player: Array = hand["player"]
		var total: int = BlackjackScript.hand_total(player)
		if total <= 21 and player.size() > 2:
			assert_gte(total, BlackjackScript.STRATEGY_DRAWS_BELOW,
				"the card says draw below seventeen and stand on it")


func test_the_same_seed_deals_the_same_hand() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 31337
	var b := RandomNumberGenerator.new()
	b.seed = 31337
	for i in 100:
		var left: Dictionary = BlackjackScript.play_hand(a)
		var right: Dictionary = BlackjackScript.play_hand(b)
		assert_eq(left["player"], right["player"])
		assert_eq(left["dealer"], right["dealer"])
		assert_eq(left["outcome"], right["outcome"])


func test_the_placard_publishes_the_edge_this_code_actually_deals() -> void:
	var measured: float = BlackjackScript.measure_edge(BlackjackScript.REFERENCE_SEED,
		BlackjackScript.REFERENCE_HANDS)
	assert_almost_eq(BlackjackScript.PUBLISHED_EDGE, measured, 0.0005,
		"PUBLISHED_EDGE must be this measurement written down; it measured %.6f" % measured)


func test_the_published_edge_is_a_sane_number_for_this_strategy() -> void:
	assert_between(BlackjackScript.PUBLISHED_EDGE, 0.01, 0.10,
		"a player mimicking the dealer gives up a few points; far outside that band means "
			+ "the dealing or the settling is wrong, not that the game is unusual")


func test_the_measurement_is_stable_across_seeds() -> void:
	for seed_value in [11, 222, 3333]:
		var measured: float = BlackjackScript.measure_edge(seed_value, SAMPLE_HANDS)
		assert_almost_eq(measured, BlackjackScript.PUBLISHED_EDGE, 0.02,
			"seed %d measured %.4f" % [seed_value, measured])


func test_the_placard_reads_cleanly_and_carries_no_dashes() -> void:
	var lines: Array[String] = BlackjackScript.placard_lines()
	assert_gt(lines.size(), 4)
	for line in lines:
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"), line)
```

- [ ] **Step 2: Run it to see it fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_blackjack.gd -gexit`

Expected: FAIL, `res://systems/blackjack.gd` does not exist.

- [ ] **Step 3: Write `game/systems/blackjack.gd`, with `PUBLISHED_EDGE` deliberately wrong**

Write the file below EXACTLY as it stands, `PUBLISHED_EDGE := 0.0` included. The next step measures the real number and pastes it in; that is the whole point of the two step, and a number guessed here would be a sign that lies.

```gdscript
class_name Blackjack
extends RefCounted
## ONE DECK, DEALER STANDS ON SEVENTEEN, and the rules on a placard. The quiet game in the
## corner of the Spectra Palace.
##
## WHY THIS GAME'S PUBLISHED EDGE IS MEASURED AND THE OTHER THREE ARE COMPUTED. Slots and
## the Wheel have an edge that belongs to the machine, so it can be enumerated exactly.
## Blackjack's edge belongs to the machine AND to how the player plays, so a bare number
## would mean nothing. So the placard prints a strategy card, "draw below 17, stand on 17 or
## more", and the published number is the edge AGAINST THAT CARD, measured over
## REFERENCE_HANDS hands from REFERENCE_SEED by this same code. PUBLISHED_EDGE is that
## measurement written down; test_blackjack.gd re measures it every run and fails if the
## placard has drifted from the dealer by more than a rounding. A player who plays better
## than the card does better than the sign says, which is the direction a sign is allowed to
## be wrong in.
##
## THE CARDS. A card is an int 0 to 51 and its rank is card % 13: rank 0 is an ace, worth 11
## until the hand would bust and then worth 1; ranks 1 to 8 are the two through the nine;
## ranks 9 to 12 are the ten, jack, queen and king, all worth 10. Suits exist only so that a
## single deck holds four of each rank, which is what makes the odds a one deck game's odds.
##
## THE DEAL is a partial Fisher Yates over a fresh deck per hand: swap a random undealt card
## to the front of the undealt tail and take it. One swap per card rather than fifty two per
## hand, which is what lets the gate deal a hundred thousand hands in seconds.
##
## NO DOUBLING, NO SPLITTING, NO INSURANCE, ON PURPOSE. Every one of them is a second
## decision the player has to be taught, a second row on the placard, and a second thing the
## published number would have to be conditioned on. The Palace keeps it simple and says so
## on the placard.
##
## Static only; play_hand() takes the caller's RandomNumberGenerator. Preload by path.

enum Outcome { DEALER_WIN, PLAYER_WIN, PUSH, PLAYER_BLACKJACK }

const DECK_SIZE := 52
const RANKS := 13

## The dealer draws below this and stands on it, hard or soft. One number, because there is
## no soft 17 exception at this table and the placard says so.
const DEALER_STANDS_ON := 17

## The house strategy card the published edge is measured against.
const STRATEGY_DRAWS_BELOW := 17

## Blackjack pays three to two.
const BLACKJACK_PAYS_NUMERATOR := 3
const BLACKJACK_PAYS_DENOMINATOR := 2

## The seed and the sample size the published number was measured over. Constants rather
## than magic numbers in the test, so re measuring it is one call with no arguments to
## remember.
const REFERENCE_SEED := 20260902
const REFERENCE_HANDS := 100000

## Chips staked per hand while measuring. A hundred, so the three to two bonus (150) is a
## whole number of chips and the measurement carries no rounding of its own.
const REFERENCE_STAKE := 100

## WHAT THE PLACARD PUBLISHES: the long run house edge against the strategy card, measured
## by measure_edge(REFERENCE_SEED, REFERENCE_HANDS). Written down rather than computed at
## draw time because a hundred thousand hands is not something a sign should do while the
## player is looking at it. test_blackjack.gd re measures it on every suite run.
const PUBLISHED_EDGE := 0.0

const RANK_NAMES: Array[String] = ["Ace", "Two", "Three", "Four", "Five", "Six", "Seven",
	"Eight", "Nine", "Ten", "Jack", "Queen", "King"]


static func is_ace(card: int) -> bool:
	return card % RANKS == 0


## An ace counts 11 here; hand_total() demotes it when it has to.
static func card_value(card: int) -> int:
	var rank: int = card % RANKS
	if rank == 0:
		return 11
	if rank >= 9:
		return 10
	return rank + 1


## The best total this hand can make at or under 21, or the busted total if it cannot.
static func hand_total(cards: Array[int]) -> int:
	var total := 0
	var aces := 0
	for card in cards:
		total += card_value(card)
		if is_ace(card):
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


## Twenty one on the first two cards, and only on the first two.
static func is_blackjack(cards: Array[int]) -> bool:
	return cards.size() == 2 and hand_total(cards) == 21


## Deal and play one hand by the placard's rules. Returns
## {"player": Array[int], "dealer": Array[int], "outcome": int}.
##
## THE ORDER OF THE CHECKS IS THE RULES. A blackjack on either side settles before anybody
## draws; a player who busts loses whatever the dealer then does, which is where the house's
## advantage actually comes from at this table.
static func play_hand(rng: RandomNumberGenerator) -> Dictionary:
	var deck: Array[int] = []
	for card in DECK_SIZE:
		deck.append(card)
	var dealt := 0

	var player: Array[int] = []
	var dealer: Array[int] = []
	for i in 2:
		var picked := rng.randi_range(dealt, DECK_SIZE - 1)
		var swap: int = deck[dealt]
		deck[dealt] = deck[picked]
		deck[picked] = swap
		player.append(deck[dealt])
		dealt += 1
		picked = rng.randi_range(dealt, DECK_SIZE - 1)
		swap = deck[dealt]
		deck[dealt] = deck[picked]
		deck[picked] = swap
		dealer.append(deck[dealt])
		dealt += 1

	var player_natural := is_blackjack(player)
	var dealer_natural := is_blackjack(dealer)
	if player_natural or dealer_natural:
		var settled: int = Outcome.PUSH
		if player_natural and not dealer_natural:
			settled = Outcome.PLAYER_BLACKJACK
		elif dealer_natural and not player_natural:
			settled = Outcome.DEALER_WIN
		return {"player": player, "dealer": dealer, "outcome": settled}

	while hand_total(player) < STRATEGY_DRAWS_BELOW and dealt < DECK_SIZE:
		var picked := rng.randi_range(dealt, DECK_SIZE - 1)
		var swap: int = deck[dealt]
		deck[dealt] = deck[picked]
		deck[picked] = swap
		player.append(deck[dealt])
		dealt += 1
	if hand_total(player) > 21:
		return {"player": player, "dealer": dealer, "outcome": Outcome.DEALER_WIN}

	while hand_total(dealer) < DEALER_STANDS_ON and dealt < DECK_SIZE:
		var picked := rng.randi_range(dealt, DECK_SIZE - 1)
		var swap: int = deck[dealt]
		deck[dealt] = deck[picked]
		deck[picked] = swap
		dealer.append(deck[dealt])
		dealt += 1
	if hand_total(dealer) > 21:
		return {"player": player, "dealer": dealer, "outcome": Outcome.PLAYER_WIN}

	var mine: int = hand_total(player)
	var theirs: int = hand_total(dealer)
	var result: int = Outcome.PUSH
	if mine > theirs:
		result = Outcome.PLAYER_WIN
	elif mine < theirs:
		result = Outcome.DEALER_WIN
	return {"player": player, "dealer": dealer, "outcome": result}


## Chips handed back, THE STAKE INCLUDED; 0 for a loss. See Slots.payout() for the contract
## every game in this casino shares.
##
## The three to two bonus uses integer division, so a stake with an odd number of chips
## rounds the bonus down by half a chip. Every stake the table offers is even
## (game/ui/blackjack_menu.gd), so it never bites; it is written this way rather than in
## floats because a chip is a whole thing.
static func payout(outcome: int, stake: int) -> int:
	if stake <= 0:
		return 0
	match outcome:
		Outcome.PLAYER_BLACKJACK:
			return stake + (stake * BLACKJACK_PAYS_NUMERATOR) / BLACKJACK_PAYS_DENOMINATOR
		Outcome.PLAYER_WIN:
			return stake * 2
		Outcome.PUSH:
			return stake
	return 0


## The house's long run share of a chip staked, over `hands` hands played from `seed` by the
## strategy card. This is the measurement PUBLISHED_EDGE is a copy of.
static func measure_edge(seed_value: int, hands: int) -> float:
	if hands <= 0:
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var staked := 0
	var returned := 0
	for i in hands:
		staked += REFERENCE_STAKE
		returned += payout(int(play_hand(rng)["outcome"]), REFERENCE_STAKE)
	return 1.0 - (float(returned) / float(staked))


## What the lobby sign prints for this table. A constant rather than a measurement, for the
## reason PUBLISHED_EDGE's own comment gives.
static func house_edge() -> float:
	return PUBLISHED_EDGE


static func card_text(card: int) -> String:
	return RANK_NAMES[card % RANKS]


## What just happened, in one line, for the table and for a toast.
static func outcome_text(hand: Dictionary) -> String:
	match int(hand.get("outcome", Outcome.DEALER_WIN)):
		Outcome.PLAYER_BLACKJACK:
			return "Blackjack. Pays three to two."
		Outcome.PLAYER_WIN:
			return "You win."
		Outcome.PUSH:
			return "Push. Your stake comes back."
	return "Dealer wins."


## The placard on the table. Player facing, so no dashes.
static func placard_lines() -> Array[String]:
	return [
		"Blackjack, Spectra Palace house rules",
		"One deck, shuffled before every hand.",
		"Dealer draws to 16 and stands on %d, hard or soft." % DEALER_STANDS_ON,
		"Blackjack pays %d to %d. A tie is a push."
			% [BLACKJACK_PAYS_NUMERATOR, BLACKJACK_PAYS_DENOMINATOR],
		"No doubling, no splitting, no insurance. We keep it simple.",
		"House strategy card: draw below %d, stand on %d or more."
			% [STRATEGY_DRAWS_BELOW, STRATEGY_DRAWS_BELOW],
		"The edge on the lobby sign is measured against that card.",
	]
```

- [ ] **Step 4: Measure the edge and paste it in**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_blackjack.gd -gexit`

Expected: `test_the_placard_publishes_the_edge_this_code_actually_deals` FAILS, and its message ends with `it measured 0.0XXXXX`. Read that number.

Sanity check before you paste it: a player who mimics the dealer, with a three to two blackjack, gives up a few points to the house. Anything from about 0.02 to 0.09 is a believable measurement. If it lands outside that, or is negative, do NOT paste it: the dealing or the settling is wrong. The two most likely causes are a hand where the dealer's blackjack is not settling before the player draws, and `payout()` handing back a multiple that does not include the stake.

Edit `const PUBLISHED_EDGE := 0.0` to that measurement rounded to four decimal places, and extend its comment with the date it was measured:

```gdscript
## WHAT THE PLACARD PUBLISHES: the long run house edge against the strategy card, measured
## by measure_edge(REFERENCE_SEED, REFERENCE_HANDS) on 2026-08-31. Written down rather than
## computed at draw time because a hundred thousand hands is not something a sign should do
## while the player is looking at it. test_blackjack.gd re measures it on every suite run,
## so this number cannot drift from the dealer without the suite going red.
const PUBLISHED_EDGE := 0.0XXX
```

- [ ] **Step 5: Run the test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_blackjack.gd -gexit`

Expected: PASS, 13 tests. `test_the_measurement_is_stable_across_seeds` is the one that says the measurement is a property of the game rather than of one lucky seed.

- [ ] **Step 6: Run the suite**

Run: `bash tools/run_tests.sh`

Expected: green, `Tests` up by 13 from Task 2.

- [ ] **Step 7: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: blackjack; one deck, dealer stands on 17, and a placard that tells the truth\n\nBlackjack is the one casino game whose edge belongs to the player as much as\nto the table, so the placard prints a strategy card and the published edge is\nthe edge against THAT card, measured over 100000 seeded hands by the code that\nactually deals. test_blackjack.gd re measures it every run, so the placard\ncannot drift from the dealer.\n\nNo doubling, splitting or insurance: each one is a second decision to teach\nand a second condition on the published number.\n' > /tmp/casino-commit.txt
git add game/systems/blackjack.gd game/systems/blackjack.gd.uid game/test/test_blackjack.gd
git commit -F /tmp/casino-commit.txt
```

---

### Task 4: The race card

**Files:**
- Create: `game/systems/company_runners.gd`, `game/data/casino/company_runners.tres`, `game/systems/race_card.gd`
- Test: `game/test/test_company_runners.gd`, `game/test/test_race_card.gd`

**Interfaces:**
- Consumes: `PonyInstance` (`data()`, `happiness`, `hunger`, `uid`, `display_name()`, `stock`, `STATE_MIN`, `STATE_MAX`), `PonyData` (`base_speed`, `base_stamina`, `base_spirit`, `id`), `StockPalette.IDS`, `Gait.GALLOP_HANDOVER_SPEED`, `Gait.TOP_SKATE_FREE_SPEED`.
- Produces:
  - `class_name CompanyRunners extends Resource`. `@export var runner_names: Array[String]`, `speeds: Array[float]`, `staminas: Array[float]`, `spirits: Array[float]`, `base_ids: Array[StringName]`, `coats: Array[int]`, `manes: Array[int]`, `eyes: Array[int]`. `const SHIPPED_PATH := "res://data/casino/company_runners.tres"`. `static func load_shipped() -> CompanyRunners`, `func count() -> int`, `func is_valid() -> bool`, `func entry(index: int) -> Dictionary`.
  - `class_name RaceCard extends RefCounted`, static only. `const LANES := 6`, `TAKEOUT := 0.06`, `SPEED_WEIGHT := 0.5`, `STAMINA_WEIGHT := 0.3`, `SPIRIT_WEIGHT := 0.2`, `HAPPINESS_FLOOR := 0.8`, `HAPPINESS_SPAN := 0.4`, `MIN_RATING := 0.05`, `COMPANY_HAPPINESS := 0.7`, `TRACK_LENGTH := 40.0`, `SLOWEST_SPEED := 2.6`, `FASTEST_SPEED := 4.2`, `SPEED_MID := 1.7`, `SPEED_SCALE := 0.55`, `MIN_FINISH_GAP := 0.05`, `PLAYER_LANE := 0`, `RACE_HUNGER := 0.20`, `RACE_HAPPINESS := 0.12`. `static func rating(speed, stamina, spirit, happiness) -> float`, `static func entrant_from(inst: PonyInstance) -> Dictionary`, `static func build_field(entrant: Dictionary, runners: CompanyRunners) -> Array[Dictionary]`, `static func win_chances(field: Array[Dictionary]) -> Array[float]`, `static func decimal_odds(field: Array[Dictionary], lane: int) -> float`, `static func odds_text(odds: float) -> String`, `static func run(field: Array[Dictionary], seed_value: int) -> Dictionary`, `static func payout(field: Array[Dictionary], lane: int, stake: int, winner: int) -> int`, `static func speed_for_score(score: float) -> float`, `static func apply_race_effects(inst: PonyInstance) -> void`.

**The rating formula, designed against the numbers the `.tres` files actually carry.**

```
rating = (0.5 * base_speed + 0.3 * base_stamina + 0.2 * base_spirit)
         * (0.8 + 0.4 * happiness)
```

Read off `game/data/ponies/*.tres`, `base_speed` runs 3.0 to 6.5, `base_stamina` 3.5 to 7.5 and `base_spirit` 4.0 to 8.5, so the weighted part runs from 3.35 (fluttershy, the slowest thing on the roster) to 7.20 for a hypothetical maximum, with the real top at 6.35 (rainbowdash, 6.5 / 6.0 / 6.5). The three hidden stock records carry 4.0 / 1.0 / 1.0, which weights to 2.50: a stock pony is deliberately the slowest thing on the card, because "unregistered stock" is the crowd and the named ponies are the ones worth entering. Happiness then multiplies by 0.8 at miserable and 1.2 at delighted, so keeping her fed is worth a fifth of her form, which is the spec's "happiness modifies performance" made into a number.

Worked example, and the numbers the odds tests use. The five Company runners are held at `COMPANY_HAPPINESS` 0.7, a multiplier of 1.08, giving ratings 6.048, 5.400, 5.670, 5.238 and 5.562, summing to 27.918. Enter a stock pony at happiness 0.5 (rating 2.50) and the field totals 30.418, so she wins 8.22 per cent of the time and pays 11.44 for 1. Enter rainbowdash at happiness 1.0 (rating 7.62) and the field totals 35.538, so she wins 21.4 per cent of the time and pays 4.38 for 1. That is the spread the card is tuned for: your best pony is a favourite and your worst is a long shot, and both are worth watching.

**Why the simulation and the odds cannot disagree.** The finish is drawn with the Gumbel max trick: each lane's score is `ln(rating) + G` where `G` is a standard Gumbel draw, and the lane with the highest score wins. That draw has an exact identity behind it: the probability that lane i has the highest score is exactly `rating_i / sum(rating)`. So `win_chances()` is not a model OF the simulation, it IS the simulation, written out. The odds are then `(1 - TAKEOUT) / p`, so the expected return on a chip staked on ANY lane is exactly `1 - TAKEOUT`, and the published takeout of 6.0 per cent is the house edge on every bet on the card. `test_race_card.gd` asserts that identity per lane at 1e to the minus 9, and then measures it again over twenty thousand seeded races.

**How the sim hands the track a race to play.** `run()` also returns a finishing time per lane, derived from that lane's score by a strictly increasing squash into `[SLOWEST_SPEED, FASTEST_SPEED]` and then `TRACK_LENGTH / speed`. Strictly increasing means the times order the lanes exactly the way the scores do, so the race the player watches finishes in the order the arithmetic decided. A final pass walks the finish order and pushes any time that did not come out strictly later than the one in front of it out by `MIN_FINISH_GAP`, so a float tie can never make the playback disagree with the result. The speed band sits inside `Gait`'s skate free gallop band (1.98 to 4.29 m/s) so a runner's hooves match the ground she is covering.

- [ ] **Step 1: Write the failing runners test and the resource script**

`game/test/test_company_runners.gd`:

```gdscript
extends GutTest
## The five Company owned runners, as authored data.

const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")


func test_the_shipped_card_loads_and_holds_five_runners() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	assert_not_null(runners, "res://data/casino/company_runners.tres must load")
	assert_eq(runners.count(), 5, "five Company runners and one lane for your pony")
	assert_true(runners.is_valid(), "every column must be the same length")


func test_every_column_is_filled_in_and_in_range() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	var palette: StockPalette = StockPaletteScript.load_stock()
	for i in runners.count():
		var entry: Dictionary = runners.entry(i)
		assert_false(String(entry["name"]).is_empty())
		assert_between(float(entry["speed"]), 3.0, 6.5, "inside the roster's own speed range")
		assert_between(float(entry["stamina"]), 3.5, 7.5)
		assert_between(float(entry["spirit"]), 4.0, 8.5)
		assert_true(StockPaletteScript.is_stock_id(entry["base_id"]),
			"a Company runner is built on a hidden stock record")
		var triple: Dictionary = entry["stock"]
		assert_between(int(triple["coat"]), 0, palette.coats.size() - 1)
		assert_between(int(triple["mane"]), 0, palette.manes.size() - 1)
		assert_between(int(triple["eyes"]), 0, palette.eyes.size() - 1)


func test_no_two_runners_share_a_name() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	var seen: Dictionary = {}
	for i in runners.count():
		var runner_name: String = runners.entry(i)["name"]
		assert_false(seen.has(runner_name), "%s is on the card twice" % runner_name)
		seen[runner_name] = true


func test_the_names_are_player_facing_and_carry_no_dashes() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	for i in runners.count():
		var runner_name: String = runners.entry(i)["name"]
		assert_false(runner_name.contains("--") or runner_name.contains("—"), runner_name)


func test_an_index_off_the_end_answers_an_empty_entry_rather_than_erroring() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	assert_true(runners.entry(-1).is_empty())
	assert_true(runners.entry(99).is_empty())


func test_a_half_authored_card_is_not_valid() -> void:
	var runners: CompanyRunners = CompanyRunnersScript.new()
	runners.runner_names = ["Only One"]
	assert_false(runners.is_valid(), "a name with no stats behind it is a broken card")
```

- [ ] **Step 2: Run it to see it fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_company_runners.gd -gexit`

Expected: FAIL, `res://systems/company_runners.gd` does not exist.

- [ ] **Step 3: Write the resource script and the shipped card**

`game/systems/company_runners.gd`:

```gdscript
class_name CompanyRunners
extends Resource
## THE FIVE COMPANY OWNED RUNNERS at the Spectra Palace track, as authored data. Their
## names, their form, and the colours they are painted in.
##
## PARALLEL COLUMNS RATHER THAN A LIST OF SUB RESOURCES, the same shape
## game/systems/stock_palette.gd uses for its swatch rows and for the same reason: a .tres
## holding six flat arrays is a file a person can read and edit in a text editor, and a
## .tres holding five nested sub resources is not. is_valid() is what keeps the columns in
## step, and test_company_runners.gd asserts it against the shipped file.
##
## THEY ARE STOCK PONIES WITH JOB TITLES. Each one is built on one of the three hidden
## stock records (game/data/hidden/) and recoloured from the stock palette, so the track
## needs no new model and no new import; `base_ids` says which record and the colour columns
## say which swatches. Their names are the Company's, which is the joke.
##
## THEY ARE NOT COLLECTIBLE, NOT SPAWNED AND NOT OWNED. Nothing here mints a PonyInstance,
## nothing here reaches the Compendium, and no Company runner is ever a pony the player can
## catch. They exist to have form and to be beaten.

const SHIPPED_PATH := "res://data/casino/company_runners.tres"

## Player facing; no dashes.
@export var runner_names: Array[String] = []
@export var speeds: Array[float] = []
@export var staminas: Array[float] = []
@export var spirits: Array[float] = []

## Which hidden stock record each runner's body is built from.
@export var base_ids: Array[StringName] = []

## Indices into game/data/stock_palette.tres.
@export var coats: Array[int] = []
@export var manes: Array[int] = []
@export var eyes: Array[int] = []


static func load_shipped() -> CompanyRunners:
	return load(SHIPPED_PATH) as CompanyRunners


func count() -> int:
	return runner_names.size()


## Every column the same length, and at least one runner. A card that fails this would hand
## the race an entry with a name and no form.
func is_valid() -> bool:
	var n := count()
	if n <= 0:
		return false
	return speeds.size() == n and staminas.size() == n and spirits.size() == n \
		and base_ids.size() == n and coats.size() == n and manes.size() == n \
		and eyes.size() == n


## One runner as a dictionary, or an empty one for an index that is not on the card. An
## empty answer rather than an error, because the caller is a menu drawing rows and a menu
## that has drifted should draw nothing rather than take the game down.
func entry(index: int) -> Dictionary:
	if index < 0 or index >= count() or not is_valid():
		return {}
	return {
		"name": runner_names[index],
		"speed": speeds[index],
		"stamina": staminas[index],
		"spirit": spirits[index],
		"base_id": base_ids[index],
		"stock": {"coat": coats[index], "mane": manes[index], "eyes": eyes[index]},
	}
```

`game/data/casino/company_runners.tres` (create the `game/data/casino/` directory):

```
[gd_resource type="Resource" script_class="CompanyRunners" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/company_runners.gd" id="1_runners"]

[resource]
script = ExtResource("1_runners")
runner_names = Array[String](["Quarterly Dividend", "Stock Option", "Fully Vested", "Gross Margin", "Overtime"])
speeds = Array[float]([5.4, 4.6, 6.0, 3.8, 4.2])
staminas = Array[float]([6.0, 5.0, 4.5, 6.5, 5.5])
spirits = Array[float]([5.5, 6.0, 4.5, 5.0, 7.0])
base_ids = Array[StringName]([&"stock_bold", &"stock_curious", &"stock_bold", &"stock_shy", &"stock_curious"])
coats = Array[int]([2, 6, 0, 5, 3])
manes = Array[int]([4, 1, 2, 7, 5])
eyes = Array[int]([1, 4, 0, 3, 2])
```

- [ ] **Step 4: Run the runners test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_company_runners.gd -gexit`

Expected: PASS, 6 tests.

- [ ] **Step 5: Write the failing race card test**

`game/test/test_race_card.gd`:

```gdscript
extends GutTest
## THE RACE, as arithmetic. The claims worth pinning are that the odds shown are the odds
## the simulation actually produces, that the finish is a function of the field and the seed
## and of nothing else, and that a race leaves the pony who ran it hungrier and happier and
## otherwise exactly where she was.

const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const GaitScript := preload("res://systems/gait.gd")

const SAMPLE_RACES := 20000


func _field(speed: float, stamina: float, spirit: float, happiness: float) -> Array[Dictionary]:
	var entrant := {
		"name": "Your Pony", "uid": &"test#000001", "data_id": &"stock_bold",
		"speed": speed, "stamina": stamina, "spirit": spirit, "happiness": happiness,
		"stock": {"coat": 0, "mane": 0, "eyes": 0},
	}
	return RaceCardScript.build_field(entrant, CompanyRunnersScript.load_shipped())


func test_the_rating_is_the_weighted_stats_times_the_mood() -> void:
	assert_almost_eq(RaceCardScript.rating(4.0, 5.0, 5.0, 1.0), (2.0 + 1.5 + 1.0) * 1.2, 1e-6)
	assert_almost_eq(RaceCardScript.rating(4.0, 5.0, 5.0, 0.0), (2.0 + 1.5 + 1.0) * 0.8, 1e-6)


func test_happiness_is_worth_a_fifth_of_her_form_either_way() -> void:
	var miserable: float = RaceCardScript.rating(5.0, 5.0, 5.0, 0.0)
	var delighted: float = RaceCardScript.rating(5.0, 5.0, 5.0, 1.0)
	assert_almost_eq(delighted / miserable, 1.5, 1e-6, "0.8 to 1.2 is half again")


func test_a_stock_pony_rates_below_the_slowest_named_pony_on_the_roster() -> void:
	var stock: float = RaceCardScript.rating(4.0, 1.0, 1.0, 0.5)
	var slowest_named: float = RaceCardScript.rating(3.0, 4.5, 5.0, 0.5)
	assert_lt(stock, slowest_named, "unregistered stock is the crowd, not the form horse")


func test_a_rating_can_never_reach_zero() -> void:
	assert_gte(RaceCardScript.rating(0.0, 0.0, 0.0, 0.0), RaceCardScript.MIN_RATING,
		"a zero rating would be a division by zero in the odds")


func test_a_field_is_six_lanes_with_your_pony_on_the_rail() -> void:
	var field: Array[Dictionary] = _field(4.0, 1.0, 1.0, 0.5)
	assert_eq(field.size(), RaceCardScript.LANES)
	assert_true(bool(field[RaceCardScript.PLAYER_LANE]["player"]),
		"the Palace always puts your pony on the rail so you know which lane is yours")
	for lane in range(1, RaceCardScript.LANES):
		assert_false(bool(field[lane]["player"]))
		assert_almost_eq(float(field[lane]["happiness"]), RaceCardScript.COMPANY_HAPPINESS,
			1e-6)


func test_the_win_chances_are_one_whole_race() -> void:
	var field: Array[Dictionary] = _field(6.5, 6.0, 6.5, 1.0)
	var chances: Array[float] = RaceCardScript.win_chances(field)
	var total := 0.0
	for p in chances:
		total += p
		assert_gt(p, 0.0)
	assert_almost_eq(total, 1.0, 1e-9)


func test_every_lane_on_the_card_carries_exactly_the_published_takeout() -> void:
	var field: Array[Dictionary] = _field(4.0, 1.0, 1.0, 0.5)
	var chances: Array[float] = RaceCardScript.win_chances(field)
	for lane in RaceCardScript.LANES:
		var expected_return: float = chances[lane] * RaceCardScript.decimal_odds(field, lane)
		assert_almost_eq(expected_return, 1.0 - RaceCardScript.TAKEOUT, 1e-9,
			"lane %d must be worth exactly what every other lane is worth" % lane)


func test_a_longer_shot_pays_more() -> void:
	var field: Array[Dictionary] = _field(4.0, 1.0, 1.0, 0.5)
	var chances: Array[float] = RaceCardScript.win_chances(field)
	for lane in range(1, RaceCardScript.LANES):
		assert_lt(chances[RaceCardScript.PLAYER_LANE], chances[lane],
			"a stock pony is an outsider against the Company's runners")
		assert_gt(RaceCardScript.decimal_odds(field, RaceCardScript.PLAYER_LANE),
			RaceCardScript.decimal_odds(field, lane))


func test_the_same_field_and_seed_run_the_same_race() -> void:
	var field: Array[Dictionary] = _field(5.0, 5.0, 5.0, 0.6)
	var left: Dictionary = RaceCardScript.run(field, 424242)
	var right: Dictionary = RaceCardScript.run(field, 424242)
	assert_eq(left["order"], right["order"])
	assert_eq(left["winner"], right["winner"])
	assert_eq(left["times"], right["times"])


func test_a_different_seed_can_run_a_different_race() -> void:
	var field: Array[Dictionary] = _field(5.0, 5.0, 5.0, 0.6)
	var same := 0
	for seed_value in range(100):
		if int(RaceCardScript.run(field, seed_value)["winner"]) == 0:
			same += 1
	assert_lt(same, 100, "the rail does not win every race")
	assert_gt(same, 0, "and it does win some")


func test_the_race_you_watch_finishes_in_the_order_the_arithmetic_decided() -> void:
	var field: Array[Dictionary] = _field(5.0, 5.0, 5.0, 0.6)
	for seed_value in range(300):
		var result: Dictionary = RaceCardScript.run(field, seed_value)
		var order: Array = result["order"]
		var times: Array = result["times"]
		for k in range(1, order.size()):
			assert_lt(float(times[order[k - 1]]), float(times[order[k]]),
				"seed %d: lane %d finished no later than the lane in front of her"
					% [seed_value, int(order[k])])


func test_every_lane_runs_inside_the_gallop_clip_band() -> void:
	assert_gte(RaceCardScript.SLOWEST_SPEED, GaitScript.GALLOP_HANDOVER_SPEED,
		"a racer must always read as galloping")
	assert_lte(RaceCardScript.FASTEST_SPEED, GaitScript.TOP_SKATE_FREE_SPEED,
		"and never fast enough to skate")
	for score in [-8.0, -1.0, 0.0, 1.7, 4.0, 12.0]:
		assert_between(RaceCardScript.speed_for_score(score),
			RaceCardScript.SLOWEST_SPEED, RaceCardScript.FASTEST_SPEED)


func test_speed_climbs_with_the_score_and_never_flattens_into_a_tie() -> void:
	var previous: float = RaceCardScript.speed_for_score(-6.0)
	for step in range(1, 60):
		var next: float = RaceCardScript.speed_for_score(-6.0 + float(step) * 0.2)
		assert_gt(next, previous, "the squash must be strictly increasing")
		previous = next


func test_a_happier_pony_wins_more_often_over_a_long_run() -> void:
	var miserable: Array[Dictionary] = _field(6.0, 6.0, 6.0, 0.0)
	var delighted: Array[Dictionary] = _field(6.0, 6.0, 6.0, 1.0)
	var sad_wins := 0
	var happy_wins := 0
	for seed_value in range(3000):
		if int(RaceCardScript.run(miserable, seed_value)["winner"]) == 0:
			sad_wins += 1
		if int(RaceCardScript.run(delighted, seed_value)["winner"]) == 0:
			happy_wins += 1
	assert_gt(happy_wins, sad_wins, "feeding her is worth something on the track")


func test_the_winners_come_out_at_the_rate_the_odds_promised() -> void:
	var field: Array[Dictionary] = _field(5.0, 5.0, 5.0, 0.6)
	var chances: Array[float] = RaceCardScript.win_chances(field)
	var wins: Array[int] = [0, 0, 0, 0, 0, 0]
	for seed_value in SAMPLE_RACES:
		wins[int(RaceCardScript.run(field, seed_value)["winner"])] += 1
	for lane in RaceCardScript.LANES:
		var measured: float = float(wins[lane]) / float(SAMPLE_RACES)
		assert_almost_eq(measured, chances[lane], 0.02,
			"lane %d won %.4f of the time against a shown %.4f" % [lane, measured, chances[lane]])


func test_a_long_seeded_run_of_bets_converges_on_the_published_takeout() -> void:
	var field: Array[Dictionary] = _field(5.0, 5.0, 5.0, 0.6)
	var staked := 0
	var returned := 0
	for seed_value in SAMPLE_RACES:
		var winner: int = int(RaceCardScript.run(field, seed_value)["winner"])
		staked += 100
		returned += RaceCardScript.payout(field, RaceCardScript.PLAYER_LANE, 100, winner)
	var measured: float = 1.0 - (float(returned) / float(staked))
	assert_almost_eq(measured, RaceCardScript.TAKEOUT, 0.02,
		"measured %.4f against a published %.4f" % [measured, RaceCardScript.TAKEOUT])


func test_a_losing_lane_and_a_bad_stake_pay_nothing() -> void:
	var field: Array[Dictionary] = _field(5.0, 5.0, 5.0, 0.6)
	assert_eq(RaceCardScript.payout(field, 1, 100, 2), 0)
	assert_eq(RaceCardScript.payout(field, 1, 0, 1), 0)
	assert_eq(RaceCardScript.payout(field, 1, -100, 1), 0)
	assert_eq(RaceCardScript.payout(field, 99, 100, 99), 0, "a lane that is not on the card")


func test_an_entrant_is_read_off_her_own_record() -> void:
	var inst: PonyInstance = PonyInstanceScript.create(&"stock_bold")
	inst.stock = {"coat": 1, "mane": 2, "eyes": 3}
	inst.happiness = 0.75
	var entrant: Dictionary = RaceCardScript.entrant_from(inst)
	assert_eq(entrant["uid"], inst.uid)
	assert_eq(entrant["data_id"], &"stock_bold")
	assert_almost_eq(float(entrant["happiness"]), 0.75, 1e-6)
	assert_eq(entrant["stock"], {"coat": 1, "mane": 2, "eyes": 3})


func test_a_race_leaves_her_hungrier_and_happier_and_nothing_else() -> void:
	var inst: PonyInstance = PonyInstanceScript.create(&"stock_bold")
	inst.happiness = 0.40
	inst.hunger = 0.10
	var home := inst.home_slot
	RaceCardScript.apply_race_effects(inst)
	assert_almost_eq(inst.hunger, 0.30, 1e-6)
	assert_almost_eq(inst.happiness, 0.52, 1e-6)
	assert_eq(inst.home_slot, home, "she never left her pen")


func test_the_race_effects_clamp_rather_than_overflow() -> void:
	var inst: PonyInstance = PonyInstanceScript.create(&"stock_bold")
	inst.happiness = 0.98
	inst.hunger = 0.95
	RaceCardScript.apply_race_effects(inst)
	assert_almost_eq(inst.happiness, PonyInstanceScript.STATE_MAX, 1e-6)
	assert_almost_eq(inst.hunger, PonyInstanceScript.STATE_MAX, 1e-6)


func test_apply_race_effects_survives_a_null() -> void:
	RaceCardScript.apply_race_effects(null)
	pass_test("a null racer is a caller bug, not a crash")
```

- [ ] **Step 6: Run it to see it fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_card.gd -gexit`

Expected: FAIL, `res://systems/race_card.gd` does not exist.

- [ ] **Step 7: Write `game/systems/race_card.gd`**

```gdscript
class_name RaceCard
extends RefCounted
## THE SIX LANE RACE, as arithmetic: who is in it, what she is worth, what the odds are, and
## what happens when they go. The track behind the Spectra Palace (game/world/race_track.gd)
## plays out what this file decides and adds nothing of its own.
##
## THE RATING, AND WHERE ITS NUMBERS COME FROM.
##
##     rating = (0.5 * base_speed + 0.3 * base_stamina + 0.2 * base_spirit)
##              * (0.8 + 0.4 * happiness)
##
## Those three fields have existed on PonyData since Phase 1 and nothing used them until
## now. Measured across game/data/ponies/, base_speed runs 3.0 to 6.5, base_stamina 3.5 to
## 7.5 and base_spirit 4.0 to 8.5, so the weighted part runs 3.35 (the slowest pony on the
## roster) to 6.35 (the fastest), and the three hidden stock records at 4.0 / 1.0 / 1.0
## weight to 2.50. A stock pony is deliberately the slowest thing on the card: unregistered
## stock is the crowd, and entering a named pony you actually went and caught is what the
## race is for. Happiness then swings her form by a fifth either way, which is the spec's
## "a pony who races comes home happy" pointing back at itself: feed her and she runs.
##
## WHY THE SHOWN ODDS AND THE SIMULATION CANNOT DISAGREE. run() draws each lane a score of
## ln(rating) plus a standard Gumbel deviate and the highest score wins. That is the Gumbel
## max trick, and it has an exact identity behind it: the chance that lane i holds the
## highest score is exactly rating_i over the sum of the ratings. So win_chances() is not a
## model OF the race, it IS the race with the randomness taken out, and decimal_odds() can
## be (1 - TAKEOUT) / p with no fudge factor anywhere. Every lane on the card is then worth
## exactly 1 - TAKEOUT per chip staked, which is why the lobby sign can publish one number
## for racing and have it be true of every bet on it.
##
## WHAT THE TRACK GETS. run() also hands back a finishing time per lane, squashed out of the
## same score by a strictly increasing curve into [SLOWEST_SPEED, FASTEST_SPEED] and turned
## into TRACK_LENGTH over that speed. Strictly increasing means the times order the lanes
## exactly the way the scores do, so the race the player watches finishes in the order the
## arithmetic decided; a final pass pushes any tied time out by MIN_FINISH_GAP so a float
## coincidence cannot make the playback contradict the result. The speed band sits inside
## Gait's skate free gallop band, so her hooves match the ground she covers.
##
## NO PONY IS TOUCHED BY ANY OF THIS. entrant_from() READS a PonyInstance and copies what it
## needs; nothing here holds one, moves one, or frees one. She stays in her pen for the whole
## race and apply_race_effects() is the only thing that writes to her, and all it writes is
## hunger and happiness.
##
## Static only. Preload by path.

const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")

## Six lanes: yours and the Company's five.
const LANES := 6

## The lane the player's entrant always runs in. Fixed rather than drawn, so she is never
## hunting the card for her own pony; it is the one thing about the race that is not a draw,
## and the Palace says so on the race panel.
const PLAYER_LANE := 0

## The house's share of every chip staked on this card, and the number the lobby sign
## publishes for racing. The ONLY place the house takes anything on a race.
const TAKEOUT := 0.06

const SPEED_WEIGHT := 0.5
const STAMINA_WEIGHT := 0.3
const SPIRIT_WEIGHT := 0.2

## Mood multiplier at happiness 0 and the span up to happiness 1.
const HAPPINESS_FLOOR := 0.8
const HAPPINESS_SPAN := 0.4

## No rating may reach zero: decimal_odds() divides by a win chance.
const MIN_RATING := 0.05

## The Company keeps its runners at exactly this morale. It is in the staff handbook.
const COMPANY_HAPPINESS := 0.7

## Metres from the gate to the wire. Matches RaceTrack's own LENGTH; the track reads this
## one rather than declaring a second.
const TRACK_LENGTH := 40.0

## The band a runner's speed is squashed into, in metres per second. Inside Gait's skate free
## gallop band (GALLOP_HANDOVER_SPEED 1.98 to TOP_SKATE_FREE_SPEED 4.29) so every lane reads
## as a gallop and none of them slides.
const SLOWEST_SPEED := 2.6
const FASTEST_SPEED := 4.2

## Centre and width of the squash, in score units. A typical field scores around 2.3, so a
## midpoint of 1.7 puts the average runner comfortably in the top half of the band and leaves
## the bottom of it for a bad draw.
const SPEED_MID := 1.7
const SPEED_SCALE := 0.55

## Seconds forced between two consecutive finishers whose times came out equal.
const MIN_FINISH_GAP := 0.05

## What a race costs and pays a racer, on her own record. Tired and pleased with herself.
const RACE_HUNGER := 0.20
const RACE_HAPPINESS := 0.12


## Her form, from her stats and her mood. See the class comment for where the weights and
## the ranges come from.
static func rating(speed: float, stamina: float, spirit: float, happiness: float) -> float:
	var form: float = SPEED_WEIGHT * speed + STAMINA_WEIGHT * stamina + SPIRIT_WEIGHT * spirit
	var mood: float = HAPPINESS_FLOOR + HAPPINESS_SPAN * clampf(happiness, 0.0, 1.0)
	return maxf(MIN_RATING, form * mood)


## Copy what the race needs out of one of the player's ponies. READ ONLY; she is not moved,
## not held and not changed.
##
## A pony whose character this build does not carry resolves to null and runs on the stock
## record's own numbers rather than being refused: she is still a pony in a pen and the
## player should still be able to enter her.
static func entrant_from(inst: PonyInstance) -> Dictionary:
	if inst == null:
		return {}
	var data: PonyData = inst.data()
	return {
		"name": inst.display_name(),
		"uid": inst.uid,
		"data_id": inst.data_id,
		"speed": data.base_speed if data != null else 4.0,
		"stamina": data.base_stamina if data != null else 1.0,
		"spirit": data.base_spirit if data != null else 1.0,
		"happiness": inst.happiness,
		"stock": inst.stock.duplicate(),
	}


## The six lanes: the entrant on the rail, then the Company's five in card order. Every entry
## carries everything the odds, the panel and the track need, so nothing downstream has to go
## back to a PonyInstance or to the runners resource.
static func build_field(entrant: Dictionary, runners: CompanyRunners) -> Array[Dictionary]:
	var field: Array[Dictionary] = []
	field.append({
		"lane": PLAYER_LANE,
		"name": String(entrant.get("name", "Your pony")),
		"player": true,
		"uid": entrant.get("uid", &""),
		"data_id": entrant.get("data_id", &""),
		"speed": float(entrant.get("speed", 4.0)),
		"stamina": float(entrant.get("stamina", 1.0)),
		"spirit": float(entrant.get("spirit", 1.0)),
		"happiness": float(entrant.get("happiness", 0.5)),
		"stock": (entrant.get("stock", {}) as Dictionary).duplicate(),
		"rating": rating(float(entrant.get("speed", 4.0)), float(entrant.get("stamina", 1.0)),
			float(entrant.get("spirit", 1.0)), float(entrant.get("happiness", 0.5))),
	})
	if runners == null or not runners.is_valid():
		return field
	for i in mini(runners.count(), LANES - 1):
		var runner: Dictionary = runners.entry(i)
		field.append({
			"lane": i + 1,
			"name": String(runner["name"]),
			"player": false,
			"uid": &"",
			"data_id": runner["base_id"],
			"speed": float(runner["speed"]),
			"stamina": float(runner["stamina"]),
			"spirit": float(runner["spirit"]),
			"happiness": COMPANY_HAPPINESS,
			"stock": (runner["stock"] as Dictionary).duplicate(),
			"rating": rating(float(runner["speed"]), float(runner["stamina"]),
				float(runner["spirit"]), COMPANY_HAPPINESS),
		})
	return field


## Each lane's chance of winning. These are the REAL chances, not a display approximation:
## see the class comment on the Gumbel identity.
static func win_chances(field: Array[Dictionary]) -> Array[float]:
	var total := 0.0
	for entry in field:
		total += float(entry["rating"])
	var out: Array[float] = []
	if total <= 0.0:
		for entry in field:
			out.append(0.0)
		return out
	for entry in field:
		out.append(float(entry["rating"]) / total)
	return out


## Chips returned per chip staked on `lane` if she wins, stake included. (1 - TAKEOUT) over
## her chance, so the expected return on every lane is exactly 1 - TAKEOUT and the sign's
## number is true of every bet on the card.
static func decimal_odds(field: Array[Dictionary], lane: int) -> float:
	if lane < 0 or lane >= field.size():
		return 0.0
	var chance: float = win_chances(field)[lane]
	if chance <= 0.0:
		return 0.0
	return (1.0 - TAKEOUT) / chance


## Player facing, so no dashes.
static func odds_text(odds: float) -> String:
	return "%.2f for 1" % odds


## The squash from a score to a running speed. Strictly increasing everywhere, which is what
## makes the times agree with the order.
static func speed_for_score(score: float) -> float:
	var t: float = 1.0 / (1.0 + exp(-(score - SPEED_MID) / SPEED_SCALE))
	return SLOWEST_SPEED + (FASTEST_SPEED - SLOWEST_SPEED) * t


## RUN THE RACE. Returns {"order": Array[int], "times": Array[float], "winner": int,
## "scores": Array[float]}, where `order` is lane indices with the winner first and `times`
## is indexed BY LANE.
##
## A function of the field and the seed and of nothing else: no clock, no frame, no global
## generator. The same two arguments give the same race on any machine.
static func run(field: Array[Dictionary], seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scores: Array[float] = []
	var times: Array[float] = []
	for entry in field:
		# A standard Gumbel deviate. randf() is [0, 1), so both logs are guarded: a u of
		# exactly 0 would be an infinite score and a u of exactly 1 a negative infinite one.
		var u: float = clampf(rng.randf(), 1e-9, 1.0 - 1e-9)
		var gumbel: float = -log(-log(u))
		scores.append(log(maxf(float(entry["rating"]), MIN_RATING)) + gumbel)
		times.append(0.0)

	var order: Array[int] = []
	for lane in field.size():
		order.append(lane)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] == scores[b]:
			return a < b
		return scores[a] > scores[b])

	for lane in field.size():
		times[lane] = TRACK_LENGTH / speed_for_score(scores[lane])
	# The squash is strictly increasing, so this only ever fires on a float coincidence; it
	# is here so that "the race you watch finishes in the order the arithmetic decided" is a
	# property of the data rather than of the floating point unit.
	for k in range(1, order.size()):
		var ahead: float = times[order[k - 1]]
		if times[order[k]] <= ahead:
			times[order[k]] = ahead + MIN_FINISH_GAP

	return {"order": order, "times": times, "winner": order[0] if not order.is_empty() else -1,
		"scores": scores}


## Chips handed back for a bet on `lane`, THE STAKE INCLUDED; 0 for a loser. Same contract as
## every other game here. Rounded rather than floored: rounding down would quietly hand the
## house a little more than the takeout the sign published.
static func payout(field: Array[Dictionary], lane: int, stake: int, winner: int) -> int:
	if stake <= 0 or lane < 0 or lane >= field.size() or lane != winner:
		return 0
	return roundi(float(stake) * decimal_odds(field, lane))


## WHAT RUNNING DOES TO HER. Hungrier and happier, clamped, and nothing else: she is not
## moved, not evicted from her pen and not freed. This is the whole of racing's effect on a
## pony, and it is here rather than in the track so it can be tested without a scene.
static func apply_race_effects(inst: PonyInstance) -> void:
	if inst == null:
		return
	inst.hunger = clampf(inst.hunger + RACE_HUNGER, PonyInstanceScript.STATE_MIN,
		PonyInstanceScript.STATE_MAX)
	inst.happiness = clampf(inst.happiness + RACE_HAPPINESS, PonyInstanceScript.STATE_MIN,
		PonyInstanceScript.STATE_MAX)
```

- [ ] **Step 8: Run the race card test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_card.gd -gexit`

Expected: PASS, 21 tests. The two slow ones (`test_the_winners_come_out_at_the_rate_the_odds_promised` and `test_a_long_seeded_run_of_bets_converges_on_the_published_takeout`) each run twenty thousand races and take a few seconds.

- [ ] **Step 9: Run the suite and commit**

Run: `bash tools/run_tests.sh`

Expected: green, `Tests` up by 27 from Task 3.

```bash
tools/bin/godot --headless --path game --import
printf 'feat: the race card; odds out of the stats, and a finish that is a function of them\n\nbase_speed, base_stamina and base_spirit have been sitting unused on PonyData\nsince Phase 1. RaceCard weights them 0.5/0.3/0.2 and multiplies by a mood\nfactor of 0.8 to 1.2, designed against the real ranges in game/data/ponies:\n3.0 to 6.5 speed, 3.5 to 7.5 stamina, 4.0 to 8.5 spirit, and 4.0/1.0/1.0 for\nthe hidden stock records, so a stock pony is the outsider on the card.\n\nThe finish is drawn by the Gumbel max trick, whose exact identity is that lane\ni wins with probability rating_i over the sum. So the shown odds are not a\nmodel of the race, they are the race: every lane is worth exactly 1 minus the\n6 per cent takeout per chip staked, which is what lets the lobby sign publish\none honest number for racing.\n\nThe times handed to the track come from the same scores through a strictly\nincreasing squash, so the race you watch finishes in the order the arithmetic\ndecided. No pony is held, moved or freed by any of it.\n' > /tmp/casino-commit.txt
git add game/systems/company_runners.gd game/systems/company_runners.gd.uid game/systems/race_card.gd game/systems/race_card.gd.uid game/data/casino/company_runners.tres game/test/test_company_runners.gd game/test/test_race_card.gd
git commit -F /tmp/casino-commit.txt
```

---

### Task 5: The Strip, the Spectra Palace, and the sign that publishes the edge

**Files:**
- Create: `game/data/regions/strip.tres`, `game/systems/casino_sign.gd`, `game/world/strip.gd`
- Modify: `game/world/ranch.tscn` (a `Palace` under `Buildings`, a `Strip` node), `game/world/ranch.gd` (`_ready()`'s fence loop around line 560, `is_region_open()` around line 1827, `_open_permit_count()` around line 1350, `_report()`'s region block around line 3160, two new public methods), `game/test/test_region_registry.gd`, `game/test/test_shop_registry.gd:74-84`, `game/test/test_pause_menu.gd`, `game/scenes/test/region_test.gd:1-5,110`, `docs/testing.md`, `docs/pipeline.md`, `docs/distribution.md`, `docs/windows-testing.md`
- Test: `game/test/test_casino_sign.gd`, plus the four modified test files above

**Interfaces:**
- Consumes: `Slots.house_edge()`, `Wheel.house_edge()`, `Blackjack.house_edge()`, `Blackjack.placard_lines()`, `RaceCard.TAKEOUT`, `Casino.CHIP_RATE`, `RegionData` (`id`, `centre`, `radius`, `permit_cost`, `grass_low`, `grass_high`), `Terrain.height_at()`, `Props.seat()`, `Building.build()`.
- Produces:
  - `class_name CasinoSign extends RefCounted`, static only. `const HEADLINE := "Spectra Palace"`, `const SPONSOR`, `const MARQUEE`. `static func lines() -> Array[String]`, `static func edge_line(game_name: String, edge: float) -> String`, `static func cage_lines() -> Array[String]`.
  - `class_name Strip extends Node3D`. `const REGION_ID := &"strip"`, `const LIGHT_COUNT := 10`, `const LIGHT_RING_RADIUS := 21.0`, `const POST_HEIGHT := 4.2`, `const MARQUEE_AT := Vector3(0.0, 5.4, 60.6)`. `func configure(region: RegionData, ground_sampler: Callable) -> void`, `func build() -> void`, `func light_count() -> int`, `func marquee_text() -> String`.
  - `ranch.gd` gains `func palace_position() -> Vector3` and `func is_near_palace() -> bool`, and `const PALACE_RADIUS := 5.0`.
  - `game/data/regions/strip.tres`: a fifth region, `permit_cost = 0`, which makes it THE free region and changes what "every region" means in four places.

**Where the Strip is, and why exactly there.** Centre `Vector2(0.0, 74.0)`, radius 26. Every one of those numbers is bounded by a check that already exists in `game/test/test_region_registry.gd`:

- clear of the homestead apron: the centre is 78 m from `HOMESTEAD_CENTRE`, so `78 - 26 = 52` clears `BLEND_RADIUS` (44)
- inside the boundary wall: `74 + 26 + RING_MARGIN` is 103, under `HALF - 5` (105)
- a walkable gap from every other region: 11.2 m from the night meadow, which is the nearest, and far more from the rest
- clear of every tree in `props.gd`: the nearest planting is the night meadow windbreak's pine at (-33.3, 85), 35.1 m from the centre, which is 6 m past the rim

The Palace stands at `(0, 66)`, rotated a half turn so its door faces south toward the homestead, and the track (Task 7) runs behind it from `z 74.4` to `z 85.6`, which puts its far corner 23.1 m from the centre and inside the rim. Walking north out of the ranch, the player sees the lights first, then the marquee, then the door.

**The five consequences of a free region, and all five are load bearing.** `RegionRegistry.all()` sorts by `permit_cost` ascending, so the Strip sorts FIRST and "every region" stops meaning "every region with a gate":

1. `ranch.gd`'s `_ready()` looks up a `Fence_<id>` node for every region and `push_error`s when it cannot find one. There is no `Fence_strip` and there should not be, so the loop skips a region priced at zero.
2. `is_region_open()` answers from the fences, so with no fence the Strip would read as shut. A region with no price is open, always.
3. `_open_permit_count()` feeds the Ledger's upkeep. Left alone it would charge the player a permit fee, every collection day, forever, for a permit that does not exist and cannot be revoked. It counts priced regions only.
4. `_report()`'s region block checks "every region has a fence" and "every region zone has residents in the roster". Nobody lives on the Strip and nothing is fenced there; both checks are about PRICED regions.
5. `_report()`'s clearance check measures homestead roam discs against every region's fence ring. There is no ring on the Strip. (For the record, the geometry clears anyway: the nearest homestead marker, SouthOrchard, sits 46.9 m away against a needed 45.2, so the Strip's position is not chosen to dodge the check.)

Four shipped tests encode the old meaning and move with it: `test_region_registry.gd`'s "the four regions load", its "costs are positive" clause and its stock band check; `test_shop_registry.gd`'s "one permit per region"; and `region_test.gd`'s "there is one fence for every region".

**The count consequence.** `Buildings` goes from five children to six, so `prop_count` and `expected_props` both rise by one and the ranch gate prints `RANCH_OK ponies=49 props=60 assets=present`. The Strip's light posts are children of `$Strip`, not of `Buildings` or `Props`, so they are deliberately NOT counted: they are scenery the gate has no claim on. Five documentation files name a props number and two of them are still stale from slice 1 at `ponies=22 props=58`; all seven lines are corrected in this task.

- [ ] **Step 1: Write the failing sign test**

`game/test/test_casino_sign.gd`:

```gdscript
extends GutTest
## THE LOBBY SIGN. The spec's promise is that the house edge is published and real, so the
## thing worth testing is that the sign reads its numbers out of the games rather than out of
## somebody's memory.

const CasinoSignScript := preload("res://systems/casino_sign.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")


func test_the_sign_names_the_palace_and_its_sponsor() -> void:
	var text: String = "\n".join(CasinoSignScript.lines())
	assert_true(text.contains("Spectra Palace"))
	assert_true(text.contains("Cloudsdale Weather Corporation"))


func test_the_sign_publishes_every_game_at_the_number_that_game_computes() -> void:
	var text: String = "\n".join(CasinoSignScript.lines())
	for pair in [["Slots", SlotsScript.house_edge()], ["The Wheel", WheelScript.house_edge()],
			["Blackjack", BlackjackScript.house_edge()], ["Racing", RaceCardScript.TAKEOUT]]:
		var expected: String = CasinoSignScript.edge_line(String(pair[0]), float(pair[1]))
		assert_true(text.contains(expected),
			"the sign must carry '%s' exactly as the game computes it" % expected)


func test_an_edge_line_reads_as_bits_in_a_hundred() -> void:
	assert_eq(CasinoSignScript.edge_line("Slots", 0.07),
		"Slots: the house keeps 7.0 bits of every 100 wagered.")


func test_the_cage_says_one_for_one_in_both_directions() -> void:
	var text: String = "\n".join(CasinoSignScript.cage_lines())
	assert_true(text.contains("one"), "the cage's rate is stated in words on the counter")
	assert_false(text.is_empty())


func test_nothing_on_the_sign_or_the_counter_carries_a_dash() -> void:
	for line in CasinoSignScript.lines() + CasinoSignScript.cage_lines():
		assert_false(line.is_empty())
		assert_false(line.contains("--") or line.contains("—"), line)


func test_the_sign_fits_a_wall() -> void:
	for line in CasinoSignScript.lines():
		assert_lte(line.length(), 62,
			"a line wider than the panel is a line that gets cut off: %s" % line)
```

- [ ] **Step 2: Run it to see it fail, then write `game/systems/casino_sign.gd`**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_casino_sign.gd -gexit`

Expected: FAIL, `res://systems/casino_sign.gd` does not exist.

```gdscript
class_name CasinoSign
extends RefCounted
## THE SIGN IN THE LOBBY, and it is the whole ethical position of this building.
##
## The spec's line is that the casino "is honest: real odds, house edge published on the
## lobby sign, never rigged". So the sign does not carry numbers somebody typed onto it. It
## ASKS EACH GAME what its edge is, and each game answers with a number it worked out from
## its own strip, its own pockets or its own takeout, or in blackjack's case measured against
## the strategy card on its own placard. There is no way to change what the house keeps
## without changing what this sign says in the same edit, which is what makes the promise
## structural instead of aspirational.
##
## THE REGISTER IS GLITZY CORPORATE, the same voice game/systems/letters.gd writes in: a
## welcome, an exclamation mark, and one line at the bottom that is funnier than it should
## be. Nothing here is grim. Player facing, so no dashes anywhere.
##
## Static only, no state, no scene. Preload by path.

const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const CasinoScript := preload("res://systems/casino.gd")

const HEADLINE := "Spectra Palace"
const SPONSOR := "proudly sponsored by Cloudsdale Weather Corporation"

## What the outdoor marquee says, in one line, for the sign on the approach.
const MARQUEE := "Spectra Palace, proudly sponsored by Cloudsdale Weather Corporation"


## One published edge, as a line a person can check with a pencil. Bits in a hundred rather
## than a percentage sign, because "the house keeps 7 of every 100" is a sentence and "7%"
## is a number you can nod at without reading.
static func edge_line(game_name: String, edge: float) -> String:
	return "%s: the house keeps %.1f bits of every 100 wagered." % [game_name, edge * 100.0]


## Everything the lobby sign says, top to bottom.
static func lines() -> Array[String]:
	return [
		HEADLINE,
		SPONSOR,
		"",
		"The odds on this sign are the real ones.",
		"We print them because we do not need to hide them.",
		"",
		edge_line("Slots", SlotsScript.house_edge()),
		edge_line("The Wheel", WheelScript.house_edge()),
		edge_line("Blackjack", BlackjackScript.house_edge()),
		edge_line("Racing", RaceCardScript.TAKEOUT),
		"",
		"Blackjack is measured against the strategy card on the placard.",
		"Play better than the card and you do better than that.",
		"",
		"Please gamble responsibly. Your ponies are counting on you!",
	]


## What is written on the cage counter itself.
static func cage_lines() -> Array[String]:
	return [
		"The cage: %d bit buys one chip, and one chip cashes out for %d bit."
			% [CasinoScript.CHIP_RATE, CasinoScript.CHIP_RATE],
		"We take nothing at this window. We take it at the tables,",
		"and we told you exactly how much on the way in.",
	]
```

- [ ] **Step 3: Run the sign test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_casino_sign.gd -gexit`

Expected: PASS, 6 tests.

- [ ] **Step 4: Author the Strip region and move the four shipped tests that encode "every region has a gate"**

Create `game/data/regions/strip.tres`:

```
[gd_resource type="Resource" script_class="RegionData" load_steps=2 format=3]

[ext_resource type="Script" path="res://systems/region_data.gd" id="1_region"]

[resource]
script = ExtResource("1_region")
id = &"strip"
display_name = "The Strip"
centre = Vector2(0, 74)
radius = 26.0
permit_cost = 0
gate_yaw_degrees = 0.0
grass_low = Color(0.27, 0.26, 0.31, 1)
grass_high = Color(0.38, 0.36, 0.43, 1)
has_lake = false
lake_depth = 0.0
stock_min = 0
stock_max = 0
```

In `game/test/test_region_registry.gd`, replace `test_the_four_regions_load` and
`test_all_is_sorted_by_permit_cost_then_id_and_costs_are_positive` and
`test_every_shipped_region_declares_a_stock_band` with:

```gdscript
func test_the_five_regions_load() -> void:
	var ids: Array = []
	for r in _registry().all():
		ids.append(String(r.id))
	ids.sort()
	assert_eq(ids, ["everfree", "lake", "nightmeadow", "orchard", "strip"])


func test_all_is_sorted_by_permit_cost_then_id_and_no_cost_is_negative() -> void:
	var items := _registry().all()
	for i in range(items.size()):
		assert_gte(items[i].permit_cost, 0, "%s must not cost less than nothing" % items[i].id)
		if i > 0:
			var a := items[i - 1]
			var b := items[i]
			assert_true(a.permit_cost < b.permit_cost or (a.permit_cost == b.permit_cost and String(a.id) < String(b.id)))


## The Strip is free and open from the first minute, so it has no permit, no gate and no
## price. Exactly one region is like that; a second one would be a permit somebody forgot to
## price rather than a decision.
func test_exactly_one_region_is_free_and_it_sorts_first() -> void:
	var items := _registry().all()
	var free := 0
	for r in items:
		if r.permit_cost <= 0:
			free += 1
	assert_eq(free, 1)
	assert_eq(items[0].id, &"strip", "a free region sorts ahead of every priced one")


func test_every_priced_region_declares_a_stock_band() -> void:
	var registry := RegionRegistryScript.new()
	registry.load_all()
	for region: RegionData in registry.all():
		assert_true(region.stock_min <= region.stock_max,
			"%s has an inverted stock band" % region.id)
		if region.permit_cost <= 0:
			assert_eq(region.stock_max, 0,
				"%s is paved; nobody grazes on it" % region.id)
			continue
		assert_gt(region.stock_max, 0, "%s must say how many stock ponies it holds" % region.id)
```

In `game/test/test_shop_registry.gd`, change the assertion at line 78 to count priced regions:

```gdscript
	var priced := 0
	for region: RegionData in regions.all():
		if region.permit_cost > 0:
			priced += 1
	assert_eq(permits.size(), priced,
		"one permit per PRICED region; a free region has nothing to sell")
```

In `game/test/test_pause_menu.gd`, add a test beside `test_the_zone_tallies_put_the_ranch_before_the_regions`:

```gdscript
## The Strip is a region with nobody living on it, so its tally reads as a real zero rather
## than being hidden. Pinned rather than left to chance: a paved strip with no wild ponies on
## it is a true thing for the Compendium to say.
func test_the_free_region_tallies_as_a_zone_with_nobody_in_it() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var rows: Array[String] = _menu.compendium_region_rows()
	assert_true(rows.has("The Strip: 0 of 0"), "rows were: %s" % ", ".join(rows))
```

In `game/scenes/test/region_test.gd`, change the class comment's opening line from "four rings of timber stand shut around four regions" to "a ring of timber stands shut around every region that has a price on it", and replace line 110's check with:

```gdscript
	var priced := 0
	for region: RegionData in ranch._regions_registry().all():
		if region.permit_cost > 0:
			priced += 1
	_set_check("there is one fence for every priced region", fences.size() == priced)
	_set_check("the free region has no fence and needs none",
		ranch.is_region_open(&"strip") and priced == fences.size())
```

(Use whatever local name that file already has for the hosted ranch; it is `ranch` in the sibling gates.)

- [ ] **Step 5: Run the four moved test files and watch them fail for the right reason**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_region_registry.gd,res://test/test_shop_registry.gd,res://test/test_pause_menu.gd -gexit`

Expected: `test_the_five_regions_load`, `test_exactly_one_region_is_free_and_it_sorts_first` and `test_every_priced_region_declares_a_stock_band` PASS immediately (the `.tres` is on disk); `test_the_free_region_tallies_as_a_zone_with_nobody_in_it` PASSES; `test_shop_registry` PASSES. If `test_regions_do_not_overlap_each_other` or `test_every_region_sits_outside_the_homestead_apron_and_inside_the_map` fails, the Strip's centre or radius was typed wrong; the numbers are derived at the top of this task.

- [ ] **Step 6: Write `game/world/strip.gd`**

```gdscript
class_name Strip
extends Node3D
## THE PAVED STRIP at the north edge of the map: a ring of lamps and a marquee, and the
## ground the Spectra Palace stands on.
##
## WHAT IS HERE AND WHAT IS NOT. The grey ground is the region's own grass colours
## (game/data/regions/strip.tres, read by game/world/terrain.gd like every other region's).
## The Palace itself is a Building under $Buildings, seated and counted with the barn and the
## Depot, because it is a building. This node owns only the scenery that makes the place read
## as somewhere at night: ten lamp posts on a ring and one lit marquee facing the walk up
## from the homestead.
##
## ITS CHILDREN ARE DELIBERATELY NOT COUNTED AS PROPS. ranch.gd's prop census is
## Props.expected_count() plus the Buildings children, and lamp posts are under neither. A
## lamp is scenery; the gate has no claim to make about it, and adding ten of them to a count
## every doc in the repo names would be churn for nothing.
##
## BUILT IN CODE AND NOT IN THE SCENE FILE, for the reason game/world/region_fence.gd gives:
## the ground does not exist until Terrain.build() has run, and a lamp post authored in
## ranch.tscn would be a lamp post hanging at y = 0 over a map with real relief in it.
##
## THE LIGHTS CAST NO SHADOWS, unlike Building's interior fill. A lamp post out in the open
## has nothing to leak through, and ten shadow casting omnis on a heightfield is a bill this
## map does not need to pay for a decorative glow.

const LayersScript := preload("res://world/collision_layers.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")

const REGION_ID := &"strip"

## Lamps, and the ring they stand on. The ring sits inside the region rim and outside the
## track's far lane, so the track is lit from around its edge.
const LIGHT_COUNT := 10
const LIGHT_RING_RADIUS := 21.0
const POST_HEIGHT := 4.2
const POST_THICKNESS := 0.18

## The marquee, in world space: just south of the Palace's door, at first floor height, facing
## the walk up from the homestead.
const MARQUEE_AT := Vector3(0.0, 5.4, 60.6)
const MARQUEE_SIZE := 0.55

const POST_COLOR := Color(0.24, 0.22, 0.28)
const LAMP_COLOR := Color(1.0, 0.86, 0.55)
const MARQUEE_COLOR := Color(1.0, 0.92, 0.62)
const LAMP_ENERGY := 2.2
const LAMP_RANGE := 16.0

var _region: RegionData = null
var _ground := Callable()
var _lights: Array[Node3D] = []
var _built := false


## Hand over the region this strip paves and a way to ask the terrain how high it is. Both
## before build(), the same contract RegionFence.configure() has.
func configure(region: RegionData, ground_sampler: Callable) -> void:
	_region = region
	_ground = ground_sampler


## Stand the lamps and hang the marquee. Idempotent.
func build() -> void:
	if _built or _region == null:
		return
	_built = true
	for i in LIGHT_COUNT:
		var angle: float = TAU * float(i) / float(LIGHT_COUNT)
		var x: float = _region.centre.x + cos(angle) * LIGHT_RING_RADIUS
		var z: float = _region.centre.y + sin(angle) * LIGHT_RING_RADIUS
		_lights.append(_lamp("Lamp%d" % i, Vector3(x, _y(x, z), z)))
	_marquee()


func light_count() -> int:
	return _lights.size()


func marquee_text() -> String:
	return CasinoSignScript.MARQUEE


func _y(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else 0.0


## One post with a lamp on top. The post has collision so the player cannot stand inside it;
## the lamp does not, because a light is not a thing.
func _lamp(lamp_name: String, base: Vector3) -> Node3D:
	var post := StaticBody3D.new()
	post.name = lamp_name
	post.collision_layer = LayersScript.PROPS
	post.collision_mask = 0
	add_child(post)
	post.global_position = base

	var box := BoxMesh.new()
	box.size = Vector3(POST_THICKNESS, POST_HEIGHT, POST_THICKNESS)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = POST_COLOR
	mat.roughness = 0.8
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = "Post"
	mesh.mesh = box
	mesh.position = Vector3(0.0, POST_HEIGHT * 0.5, 0.0)
	post.add_child(mesh)

	var shape := BoxShape3D.new()
	shape.size = box.size
	var collider := CollisionShape3D.new()
	collider.name = "PostCol"
	collider.shape = shape
	collider.position = mesh.position
	post.add_child(collider)

	var light := OmniLight3D.new()
	light.name = "Lamp"
	light.position = Vector3(0.0, POST_HEIGHT, 0.0)
	light.light_color = LAMP_COLOR
	light.light_energy = LAMP_ENERGY
	light.omni_range = LAMP_RANGE
	light.omni_attenuation = 0.9
	light.shadow_enabled = false
	post.add_child(light)
	return post


## The sign you read on the way in. A Label3D rather than a texture so the words come from
## CasinoSign and cannot drift from the building they are advertising.
func _marquee() -> void:
	var label := Label3D.new()
	label.name = "Marquee"
	label.text = CasinoSignScript.MARQUEE
	label.font_size = 64
	label.pixel_size = MARQUEE_SIZE / 64.0
	label.modulate = MARQUEE_COLOR
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.no_depth_test = false
	add_child(label)
	label.global_position = MARQUEE_AT
	# Label3D faces +Z; the walk up from the homestead comes from  Z, so it turns to meet it.
	label.rotation.y = PI
```

- [ ] **Step 7: Put the Palace and the Strip in `ranch.tscn`**

Add to `game/world/ranch.tscn`, after the `Depot` block inside `Buildings`:

```
[node name="Palace" type="StaticBody3D" parent="Buildings"]
transform = Transform3D(-1, 0, -8.7422777e-08, 0, 1, 0, 8.7422777e-08, 0, -1, 0, 0, 66)
script = ExtResource("7")
width = 14.0
depth = 9.0
wall_height = 3.6
ridge_height = 4.6
door_width = 3.2
door_height = 3.0
wall_color = Color(0.36, 0.16, 0.42, 1)
roof_color = Color(0.95, 0.78, 0.28, 1)
trim_color = Color(0.98, 0.86, 0.45, 1)

[node name="Cage" type="Marker3D" parent="Buildings/Palace"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -3.4)

[node name="Sign" type="Label3D" parent="Buildings/Palace"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.1, -4.1)
pixel_size = 0.0032
font_size = 48
outline_size = 6
modulate = Color(1, 0.94, 0.74, 1)
shaded = false
billboard = 0
```

The transform on `Palace` is a half turn about Y at `(0, 0, 66)`, so `building.gd`'s doorway, which it cuts into the `+Z` gable, faces south toward the homestead. `Cage` and `Sign` are in the Palace's own local space, so they turn with it: the cage counter stands at the back of the lobby and the sign hangs on the wall above it, facing whoever walks in. Neither is a `MeshInstance3D`, so neither affects `Props.seat()`'s measurement or the gate's collision shape count.

Add a `Strip` node at the top level, after the `Regions` node:

```
[node name="Strip" type="Node3D" parent="."]
script = ExtResource("15")
```

and add the script to the scene's `ext_resource` block at the top of the file, with the next free id (the existing ids run to 14; use 15, and check the file rather than trusting this sentence):

```
[ext_resource type="Script" path="res://world/strip.gd" id="15"]
```

**RIDGE HEIGHT 4.6 IS NOT A STYLE CHOICE.** The Barn's ridge is 4.9, and `ranch.gd`'s `_probe_camera_against_building()` measures the camera's spring arm against the FIRST building in `_buildings_by_height()`, which is the tallest one. A Palace taller than the Barn would move that probe 70 m north onto sloped ground, for no gain, and put a boot on a check that has been measuring the same wall since Phase 1A. Fourteen metres wide is what makes the Palace read as the big building on the map.

- [ ] **Step 8: Teach `ranch.gd` about a free region and stand the Strip up**

In `_ready()`, replace the fence building loop's body so it skips a free region:

```gdscript
	for region: RegionData in _regions_registry().all():
		if region.permit_cost <= 0:
			# A FREE REGION HAS NO GATE, and that is the whole difference between the Strip
			# and the other four. There is no permit to sell for it, nothing to revoke, and
			# no ring of timber to shut, so ranch.tscn carries no Fence_strip and this loop
			# must not go looking for one. is_region_open() answers for it directly.
			continue
		var fence := regions_root.get_node_or_null("Fence_" + String(region.id)) as RegionFence
		if fence == null:
			push_error("ranch: no RegionFence for region '%s' in ranch.tscn" % region.id)
			continue
		fence.configure(region, Callable(terrain, "height_at"))
		fence.build()
	_region_fence_cache = get_region_fences()

	# THE STRIP, on ground that now exists. Lamp posts and a marquee, built here rather than
	# in ranch.tscn for the same reason the fences are: they are seated on a heightfield.
	var strip_region: RegionData = _regions_registry().by_id(StripScript.REGION_ID)
	if strip != null and strip_region != null:
		strip.configure(strip_region, Callable(terrain, "height_at"))
		strip.build()
```

Add the preload beside the others near line 154:

```gdscript
const StripScript := preload("res://world/strip.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")
```

Add the node handle beside `regions_root`:

```gdscript
@onready var strip: Node3D = $Strip
```

Replace `is_region_open()`:

```gdscript
## Whether the region called `zone` is unfenced to the player right now. An unknown zone is
## closed rather than open: nothing should be able to walk into a region this map does not
## have by naming it. A region with NO PRICE is open and has no fence to ask; see the
## fence loop in _ready().
func is_region_open(zone: StringName) -> bool:
	var region: RegionData = _regions_registry().by_id(zone)
	if region != null and region.permit_cost <= 0:
		return true
	for fence in get_region_fences():
		if fence.region() != null and fence.region().id == zone:
			return fence.is_open()
	return false
```

Replace `_open_permit_count()`:

```gdscript
## How many PERMITS the player is holding, which is what the Ledger charges upkeep on. A free
## region is not a permit: counting the Strip here would bill her a fee every collection day,
## forever, for a permit that does not exist and that no collector could ever revoke.
func _open_permit_count() -> int:
	var n := 0
	for region: RegionData in _regions_registry().all():
		if region.permit_cost <= 0:
			continue
		if is_region_open(region.id):
			n += 1
	return n
```

Add two public methods beside `is_near_depot()`:

```gdscript
## The Spectra Palace's own origin in world space, or the Strip's centre if the building is
## missing. The doorway is on the south face; see ranch.tscn's half turn on the node.
func palace_position() -> Vector3:
	var palace := get_node_or_null(^"Buildings/Palace") as Node3D
	if palace != null:
		return palace.global_position
	var region: RegionData = _regions_registry().by_id(StripScript.REGION_ID)
	return Vector3(region.centre.x, 0.0, region.centre.y) if region != null else Vector3.ZERO


func is_near_palace() -> bool:
	var palace := get_node_or_null(^"Buildings/Palace") as Node3D
	if palace == null:
		return false
	var gap := Vector2(player.global_position.x - palace.global_position.x,
		player.global_position.z - palace.global_position.z).length()
	return gap <= PALACE_RADIUS
```

Add the constant beside `DEPOT_RADIUS`:

```gdscript
## How close to the Spectra Palace the counter opens from. Wider than the Depot's, because
## the Palace is fourteen metres across and the door is in the middle of one long side.
const PALACE_RADIUS := 5.0
```

In `_ready()`, after the buildings loop that calls `node.build()` and seats them, dress the sign:

```gdscript
	# THE SIGN READS ITSELF OUT OF THE GAMES. Written here rather than authored into
	# ranch.tscn so that the lobby cannot advertise a house edge the tables are not actually
	# charging; game/systems/casino_sign.gd asks each game for its own number.
	var lobby_sign := get_node_or_null(^"Buildings/Palace/Sign") as Label3D
	if lobby_sign != null:
		lobby_sign.text = "\n".join(CasinoSignScript.lines())
```

In `_report()`'s region block, skip free regions in both checks and in the clearance loop, and print the Palace's footing:

```gdscript
	var priced_regions: Array[RegionData] = []
	for region: RegionData in regions:
		if region.permit_cost > 0:
			priced_regions.append(region)
	var every_region_fenced := priced_regions.size() > 0 \
		and fences.size() == priced_regions.size()
	var residents_everywhere := priced_regions.size() > 0
	for region: RegionData in priced_regions:
		if not fenced.has(region.id):
			every_region_fenced = false
			push_error("ranch: region '%s' has no fence" % region.id)
		if roster.by_zone(region.id).is_empty():
			residents_everywhere = false
			push_error("ranch: region '%s' has no residents in the roster" % region.id)
	print("RANCH regions=%d priced=%d fences=%d open=%d"
		% [regions.size(), priced_regions.size(), fences.size(), open_gates])
	_set_check(checks, "every priced region has a fence", every_region_fenced)
	_set_check(checks, "every priced region zone has residents in the roster",
		residents_everywhere)
	# A FREE REGION IS OPEN AND UNFENCED, and that is a claim worth making out loud rather
	# than leaving as the absence of a failure above.
	var free_open := true
	for region: RegionData in regions:
		if region.permit_cost <= 0 and not is_region_open(region.id):
			free_open = false
			push_error("ranch: free region '%s' is not open" % region.id)
	_set_check(checks, "every free region is open and needs no fence", free_open)
```

and in the clearance loop, change the `for region: RegionData in regions:` inside the `marker.zone_id == &"ranch"` branch to `for region: RegionData in priced_regions:`, with this comment above it:

```gdscript
			# PRICED REGIONS ONLY: the clearance being measured is the distance to a fence
			# RING, and a free region has no ring for a roam disc to reach.
```

Add a Palace footing check at the end of the region block:

```gdscript
	# THE PALACE STANDS ON GROUND FLAT ENOUGH TO SEAT IT. Props.seat() puts a building's
	# lowest visible point at the ground height under its ORIGIN, so a fourteen metre
	# footprint on a slope shows daylight under one corner and buries the other. Every other
	# building on this map is inside Terrain's flat apron and never had to care; the Palace is
	# seventy metres north of it, so the relief across its own footprint is measured here
	# rather than judged by eye once and forgotten.
	var palace := get_node_or_null(^"Buildings/Palace") as Node3D
	var palace_relief := 0.0
	if palace != null:
		var at := palace.global_position
		var centre_y: float = terrain.height_at(at.x, at.z)
		for corner in [Vector2(-7.0, -4.5), Vector2(7.0, -4.5), Vector2(-7.0, 4.5),
				Vector2(7.0, 4.5)]:
			palace_relief = maxf(palace_relief,
				absf(terrain.height_at(at.x + corner.x, at.z + corner.y) - centre_y))
	print("RANCH palace at=(%.1f, %.1f) relief=%.2f"
		% [palace_position().x, palace_position().z, palace_relief])
	_set_check(checks, "the Palace stands on ground flat enough to seat it",
		palace != null and palace_relief <= PALACE_MAX_RELIEF)
```

with, beside `SEATING_TOLERANCE`:

```gdscript
## Metres of relief allowed across the Palace's own footprint. Bigger than SEATING_TOLERANCE
## because this is the ground under a fourteen metre building rather than the seating error
## of a prop, and small enough that no corner shows daylight.
const PALACE_MAX_RELIEF := 0.35
```

- [ ] **Step 9: Run the ranch gate, read the relief, and move the Palace if it needs moving**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`

Expected: `RANCH regions=5 priced=4 fences=4 open=0`, `RANCH palace at=(0.0, 66.0) relief=0.XX`, and `RANCH_OK ponies=49 props=60 assets=present`, exit 0.

If the `relief=` number is above `PALACE_MAX_RELIEF`, the Palace is on a slope. Do NOT raise the constant. Move the building instead: edit the `Palace` node's transform in `ranch.tscn`, keeping `x` within `[-10, 10]` and `z` within `[58, 70]` (which keeps it inside the Strip and at least 4 m clear of lane one of the track Task 7 builds at `z 74.4`), and re run until it passes. There are 26 m of region to find a flat patch in.

If the region checks fail with "region 'strip' has no fence", the skip in the `_report()` block did not land; if they fail with "has no residents in the roster", the same block is still asking the roster about the Strip.

- [ ] **Step 10: Run the other gates and the suite**

Run:

```bash
for scene in region_test market_test collection_test ledger_test depot_test creation_test world_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
```

Expected: every one exits 0. `region_test` is the one this task changed; `ledger_test` is the one `_open_permit_count()` could have broken, and its upkeep arithmetic is computed from `ranch._open_permit_count()` itself, so a wrong count there shows up as a red check rather than as a silent drift.

Run: `bash tools/run_tests.sh`

Expected: green, `Tests` up by 8 from Task 4 (six new sign tests, one new region test, one new pause menu test; two existing region tests were rewritten rather than added).

- [ ] **Step 11: Carry the count through every document that names it**

Run: `grep -rn 'props=\|ponies=2[0-9]\|ponies=49' docs/ | grep -v superpowers/plans`

Seven lines name a census. Update each to what the gate actually printed in Step 9:

- `docs/testing.md:499` and its ranch gate line: `RANCH_OK ponies=49 props=60 assets=present`
- `docs/pipeline.md:1273` and `docs/pipeline.md:1481`: the same
- `docs/distribution.md:37` and `:70`: these still say `ponies=22 props=58`, stale since slice 1; correct them to the current line in the same edit
- `docs/windows-testing.md:269`: the same, stale, correct it

Add a note in `docs/testing.md` beside the ranch gate line saying the props count moved because the Spectra Palace was built, and that a free region has no fence so "every region has a fence" is now "every priced region has a fence".

- [ ] **Step 12: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: the Strip and the Spectra Palace, with the house edge on the wall\n\nA fifth region at the north edge of the map, priced at zero, which is the\nfirst free region the game has had. That changes what "every region" means in\nfive places: no fence is built for it, is_region_open answers for it directly,\n_open_permit_count skips it (or the Ledger would bill a permit that does not\nexist, every collection day, forever), and the ranch gate asks its fence and\nroster questions of priced regions only.\n\nThe Palace is a Building like the barn, so it is seated and counted like one:\nprops goes 59 to 60 and seven documentation lines move with it, two of which\nwere still stale from slice 1. Its ridge is deliberately under the barn s, so\nthe camera probe keeps measuring the wall it has measured since Phase 1A.\n\nThe lobby sign asks each game for its own house edge rather than carrying a\nnumber somebody typed, so the Palace cannot advertise odds it is not offering.\n' > /tmp/casino-commit.txt
git add game/data/regions/strip.tres game/systems/casino_sign.gd game/systems/casino_sign.gd.uid game/world/strip.gd game/world/strip.gd.uid game/world/ranch.gd game/world/ranch.tscn game/test/test_casino_sign.gd game/test/test_region_registry.gd game/test/test_shop_registry.gd game/test/test_pause_menu.gd game/scenes/test/region_test.gd docs/
git commit -F /tmp/casino-commit.txt
```

---

### Task 6: The lobby, the cage, and three tables

**Files:**
- Create: `game/ui/table_menu.gd`, `game/ui/casino_menu.gd`/`.tscn`, `game/ui/slots_menu.gd`/`.tscn`, `game/ui/wheel_menu.gd`/`.tscn`, `game/ui/blackjack_menu.gd`/`.tscn`
- Modify: `game/world/ranch.tscn` (four `CanvasLayer` children), `game/world/ranch.gd` (`_no_menu_but()`, `_ready()`'s menu shutter list, a bind function, the transactions, `_update_palace_interaction()`, `_physics_process()`)
- Test: `game/test/test_casino_menu.gd`, `game/test/test_slots_menu.gd`, `game/test/test_wheel_menu.gd`, `game/test/test_blackjack_menu.gd`

**Interfaces:**
- Consumes: `Casino.can_stake()`, `Casino.add_chips()`, `Casino.remove_chips()`, `Casino.chips`, `Economy.spend()`, `Economy.grant()`, `Economy.bits`, `Slots.spin()/payout()/line_text()/paytable_lines()`, `Wheel.spin()/payout()/pocket_text()/rules_lines()/COLOUR_NAMES/NUMBERS`, `Blackjack.play_hand()/payout()/outcome_text()/card_text()/placard_lines()`, `CasinoSign.lines()/cage_lines()`, `ranch.is_near_palace()`.
- Produces:
  - `class_name TableMenu extends CanvasLayer`, the shared shape behind the three tables. `const STAKES: Array[int] = [10, 50, 200]`. `signal opened()`, `signal closed()`. `var can_open := Callable()`, `var chips_provider := Callable()`. `func open() -> bool`, `func close() -> void`, `func is_open() -> bool`, `func stakes() -> Array[int]`, `func selected_index() -> int`, `func move_selection(step: int) -> void`, `func selected_stake() -> int`, `func show_result(lines: Array[String]) -> void`, `func result_lines() -> Array[String]`, `func refresh() -> void`, `func title_text() -> String` (overridden), `func drawn_lines() -> Array[String]` (overridden), `func confirm() -> bool` (overridden), `func row_count() -> int` (overridden).
  - `SlotsMenu extends TableMenu`: `signal spin_requested(stake: int)`.
  - `WheelMenu extends TableMenu`: `enum Tab { COLOUR, NUMBER }`, `signal bet_requested(kind: int, guess: int, stake: int)`, `func tab() -> int`, `func switch_tab(step: int) -> void`, `func selected_guess() -> int`.
  - `BlackjackMenu extends TableMenu`: `enum Tab { TABLE, PLACARD }`, `signal deal_requested(stake: int)`, `func tab() -> int`, `func switch_tab(step: int) -> void`.
  - `class_name CasinoMenu extends CanvasLayer`: `enum Tab { CAGE, HOUSE, GAMES }`, `enum Game { SLOTS, WHEEL, BLACKJACK, RACING }`, `const CAGE_STEPS: Array[int] = [100, 500, 2000, 10000]`, `const GAME_NAMES: Array[String]`. `signal opened()`, `closed()`, `buy_chips_requested(bits: int)`, `cash_out_requested(chips: int)`, `game_requested(game: int)`. `var can_open`, `bits_provider`, `chips_provider`, `sign_provider` Callables. `func open() -> bool`, `close()`, `is_open()`, `tab()`, `set_tab(v)`, `switch_tab(step)`, `buy_amounts() -> Array[int]`, `cash_amounts() -> Array[int]`, `drawn_lines() -> Array[String]`, `confirm() -> bool`, `refresh()`.
  - `ranch.gd` gains `func casino_can_enter() -> bool`, `func set_casino_seed(seed_value: int) -> void`, `func buy_chips(bits: int) -> int`, `func cash_out(chips: int) -> int`, `func play_slots(stake: int) -> Dictionary`, `func play_wheel(kind: int, guess: int, stake: int) -> Dictionary`, `func play_blackjack(stake: int) -> Dictionary`, `func get_casino_menu() -> CanvasLayer`, `func get_table_menu(game: int) -> CanvasLayer`.

**THE BAN SEAM, and it is one function.** `ranch.casino_can_enter()` returns `true` in this slice and is `and`ed into every casino menu's `can_open`. The Resistance slice makes it return `false` above `BAN_HEAT` and the Palace shuts for the player, with no other file touched. It is a method rather than a lambda inline in the bind so that the later slice has one obvious place to stand, and so this slice's gate can flip it and prove the door actually closes.

**Why three tables share a script.** Every table asks the same three questions, in the same order, with the same keys: which stake, is it affordable, and what happened last time. `table_menu.gd` owns all of that and each table adds only its own rows and its own signal. That is the same reasoning `game/ui/depot_menu.gd` gives for three tabs rather than three menus, one level up. Each game still gets its own scene, which is what the spec asks for, and each scene's script is short enough to read at a glance.

**Why the stakes are 10, 50 and 200.** The spec's pacing line is that "a full session (three
cycles) at a mid ranch earns roughly one collection day of upkeep in gems, so the delivery
decision comes up every session and the casino is affordable in between". A common gem is 5
bits and a legendary one 100 (`Economy.GEM_VALUE_BY_RARITY`), so a session's tray is a few
hundred bits at a small ranch and a few thousand at a grown one. Ten chips is a spin you can
take on a whim at any point in the game, two hundred is a real bet at a grown ranch, and
nothing on this card can be the player's income: the sign says why, in bits per hundred, on
the way in.

**The stakes are even on purpose.** `Blackjack.payout()` pays three to two with integer division, so an odd stake would round the bonus down by half a chip. Every stake the tables offer is even, so it never bites; `test_blackjack_menu.gd` asserts that rather than leaving it to be true by luck.

- [ ] **Step 1: Write the failing lobby test**

`game/test/test_casino_menu.gd`:

```gdscript
extends GutTest
## THE LOBBY: the cage, the house sign, and the four doors. The menu draws and emits; it
## never touches a wallet, a purse or a GameState, and the whole of it is driven here from
## four lambdas.

const CasinoMenuScene := preload("res://ui/casino_menu.tscn")

var _menu: CasinoMenu = null
var _bits := 1000
var _chips := 250


func before_each() -> void:
	_bits = 1000
	_chips = 250
	_menu = CasinoMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.bits_provider = func() -> int: return _bits
	_menu.chips_provider = func() -> int: return _chips
	_menu.sign_provider = func() -> Array[String]: return ["Spectra Palace", "Honest odds."]
	_menu.open()


func test_it_opens_on_the_cage_and_refuses_to_open_twice() -> void:
	assert_true(_menu.is_open())
	assert_eq(_menu.tab(), CasinoMenu.Tab.CAGE)
	assert_false(_menu.open(), "already open")


func test_a_shut_door_refuses_to_open() -> void:
	_menu.close()
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open(), "the Palace can be shut to her; the ban slice needs this")
	assert_false(_menu.is_open())


func test_the_cage_never_offers_a_buy_in_she_cannot_afford() -> void:
	_bits = 700
	_menu.refresh()
	for amount in _menu.buy_amounts():
		assert_lte(amount, 700)
		assert_gt(amount, 0)


func test_the_cage_offers_everything_she_has_when_that_beats_every_step() -> void:
	_bits = 50000
	_menu.refresh()
	var amounts: Array[int] = _menu.buy_amounts()
	assert_eq(amounts[amounts.size() - 1], 50000)


func test_an_empty_wallet_offers_no_buy_in_at_all() -> void:
	_bits = 0
	_menu.refresh()
	assert_true(_menu.buy_amounts().is_empty(), "a row that always refuses is a row that lies")


func test_the_cage_never_offers_a_cash_out_larger_than_the_purse() -> void:
	_chips = 130
	_menu.refresh()
	for amount in _menu.cash_amounts():
		assert_lte(amount, 130)
		assert_gt(amount, 0)


func test_confirming_a_buy_in_emits_the_amount_and_transacts_nothing_itself() -> void:
	watch_signals(_menu)
	_menu.set_tab(CasinoMenu.Tab.CAGE)
	var amount: int = _menu.buy_amounts()[0]
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "buy_chips_requested", [amount])
	assert_eq(_bits, 1000, "the menu draws and emits; ranch.gd is what moves money")
	assert_eq(_chips, 250)


func test_the_house_tab_draws_whatever_the_sign_provider_says() -> void:
	_menu.set_tab(CasinoMenu.Tab.HOUSE)
	assert_true(_menu.drawn_lines().has("Honest odds."))


func test_the_games_tab_lists_four_doors_and_emits_the_one_chosen() -> void:
	watch_signals(_menu)
	_menu.set_tab(CasinoMenu.Tab.GAMES)
	assert_eq(_menu.drawn_lines().size(), CasinoMenu.GAME_NAMES.size())
	assert_eq(CasinoMenu.GAME_NAMES.size(), 4)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "game_requested", [CasinoMenu.Game.WHEEL])


func test_the_selection_wraps_rather_than_falling_off_the_end() -> void:
	_menu.set_tab(CasinoMenu.Tab.GAMES)
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), CasinoMenu.GAME_NAMES.size() - 1)


func test_switching_tabs_wraps_and_resets_the_selection() -> void:
	_menu.set_tab(CasinoMenu.Tab.GAMES)
	_menu.move_selection(2)
	_menu.switch_tab(1)
	assert_eq(_menu.tab(), CasinoMenu.Tab.CAGE, "three tabs, and it comes round")
	assert_eq(_menu.selected_index(), 0)


func test_nothing_it_draws_carries_a_dash() -> void:
	for tab in [CasinoMenu.Tab.CAGE, CasinoMenu.Tab.HOUSE, CasinoMenu.Tab.GAMES]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)


func test_closing_announces_itself_once() -> void:
	watch_signals(_menu)
	_menu.close()
	_menu.close()
	assert_signal_emit_count(_menu, "closed", 1)
	assert_false(_menu.is_open())
```

- [ ] **Step 2: Run it to see it fail**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_casino_menu.gd -gexit`

Expected: FAIL, `res://ui/casino_menu.tscn` does not exist.

- [ ] **Step 3: Write `game/ui/casino_menu.gd` and its scene**

```gdscript
class_name CasinoMenu
extends CanvasLayer
## THE LOBBY OF THE SPECTRA PALACE: the cage, the house sign, and the four doors.
##
## THE MENU DRAWS AND EMITS; ranch.gd TRANSACTS AND PAYS. This file never touches Economy,
## Casino, GameState or a pony. It is handed four Callables (how many bits, how many chips,
## what the sign says, and whether it may open at all) and it hands back three signals. Same
## split as game/ui/depot_menu.gd, same reason: the whole of this is testable in milliseconds
## against four lambdas, and the money lives in exactly one file.
##
## THE HOUSE TAB IS NOT DECORATION. The spec's promise is that the edge is published in the
## lobby, so it is a tab in the lobby menu as well as a sign on the wall; a player who never
## looks up still gets the numbers put in front of her before she buys a chip.
##
## THE CAGE OFFERS ONLY WHAT SHE CAN COVER, in both directions, for the reason
## DepotMenu.pay_amounts() gives: a menu row that always refuses is a menu row that lies.

enum Tab { CAGE, HOUSE, GAMES }
enum Game { SLOTS, WHEEL, BLACKJACK, RACING }

const TAB_NAMES: Array[String] = ["Cage", "House", "Games"]
const GAME_NAMES: Array[String] = ["Slots", "The Wheel", "Blackjack", "Racing"]
const TITLE := "Spectra Palace"
const FOOTER := "  up down  choose      left right  tab      Enter / A  confirm      Esc / B  leave"

## The amounts the cage offers before they are cut down to what she is holding.
const CAGE_STEPS: Array[int] = [100, 500, 2000, 10000]

const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)

signal opened()
signal closed()
signal buy_chips_requested(bits: int)
signal cash_out_requested(chips: int)
signal game_requested(game: int)

var can_open := Callable()
var bits_provider := Callable()
var chips_provider := Callable()
var sign_provider := Callable()

var _tab: int = Tab.CAGE
var _selected := 0
var _open := false

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	visible = false
	_title.text = TITLE
	_footer.text = FOOTER


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_tab = Tab.CAGE
	_selected = 0
	visible = true
	refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.CAGE, Tab.GAMES)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.GAMES + 1))


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = _row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()


## What the cage will sell her, cut to the bits she is holding, plus an "everything" row when
## that beats the biggest step.
func buy_amounts() -> Array[int]:
	return _steps_within(int(bits_provider.call()) if bits_provider.is_valid() else 0)


## What the cage will buy back, cut to the chips she is holding.
func cash_amounts() -> Array[int]:
	return _steps_within(int(chips_provider.call()) if chips_provider.is_valid() else 0)


func _steps_within(held: int) -> Array[int]:
	var out: Array[int] = []
	for step in CAGE_STEPS:
		if step <= held:
			out.append(step)
	if held > 0 and (out.is_empty() or out[out.size() - 1] < held):
		out.append(held)
	return out


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.CAGE:
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if buys.is_empty() and cashes.is_empty():
				lines.append("Come back when you have something to play with.")
			for amount in buys:
				lines.append("Buy %d chips for %d bits" % [amount, amount])
			for amount in cashes:
				lines.append("Cash out %d chips for %d bits" % [amount, amount])
		Tab.HOUSE:
			if sign_provider.is_valid():
				for line in sign_provider.call():
					lines.append(String(line))
		Tab.GAMES:
			for game_name in GAME_NAMES:
				lines.append(game_name)
	return lines


## Act on the highlighted row. The cage's rows are the buys followed by the cashes, so the
## index decides which of the two signals goes out; the tab is drawn as one list because the
## player is standing at one window.
func confirm() -> bool:
	match _tab:
		Tab.CAGE:
			var buys: Array[int] = buy_amounts()
			var cashes: Array[int] = cash_amounts()
			if _selected < 0:
				return false
			if _selected < buys.size():
				buy_chips_requested.emit(buys[_selected])
				return true
			var index: int = _selected - buys.size()
			if index < cashes.size():
				cash_out_requested.emit(cashes[index])
				return true
			return false
		Tab.GAMES:
			if _selected < 0 or _selected >= GAME_NAMES.size():
				return false
			game_requested.emit(_selected)
			return true
	return false


func refresh() -> void:
	if not is_node_ready():
		return
	_tabs.text = "   ".join(TAB_NAMES.map(func(t: String) -> String:
		return "[%s]" % t if TAB_NAMES.find(t) == _tab else " %s " % t))
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	for i in lines.size():
		var label := Label.new()
		var picked: bool = i == _selected and _tab != Tab.HOUSE
		label.text = ("> " if picked else "  ") + lines[i]
		label.add_theme_color_override("font_color", COLOR_VALUE if picked else COLOR_NAME)
		_rows.add_child(label)


func _row_count() -> int:
	match _tab:
		Tab.CAGE:
			return buy_amounts().size() + cash_amounts().size()
		Tab.GAMES:
			return GAME_NAMES.size()
	return 0


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if event.is_action(&"ui_cancel"):
		close()
	elif event.is_action(&"ui_up"):
		move_selection(-1)
	elif event.is_action(&"ui_down"):
		move_selection(1)
	elif event.is_action(&"ui_left"):
		switch_tab(-1)
	elif event.is_action(&"ui_right"):
		switch_tab(1)
	elif event.is_action(&"ui_accept"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()
```

`game/ui/casino_menu.tscn` is `game/ui/depot_menu.tscn` with the script swapped and the root renamed. Copy that file verbatim, then change exactly three things: the `[ext_resource]` path to `res://ui/casino_menu.gd`, the root node's name to `CasinoMenu`, and nothing else. The node tree (`Dim`, `Centre/Panel/Margin/Column/{Title,Tabs,Rows,Footer}`) is what the `@onready` paths above expect.

```bash
sed -e 's#res://ui/depot_menu.gd#res://ui/casino_menu.gd#' \
    -e 's#\[node name="DepotMenu" type="CanvasLayer"\]#[node name="CasinoMenu" type="CanvasLayer"]#' \
    game/ui/depot_menu.tscn > game/ui/casino_menu.tscn
```

- [ ] **Step 4: Run the lobby test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_casino_menu.gd -gexit`

Expected: PASS, 13 tests.

- [ ] **Step 5: Write the failing table tests**

`game/test/test_slots_menu.gd`:

```gdscript
extends GutTest
## THE SLOT MACHINE'S PANEL. It shows the paytable, offers a stake it knows she can cover,
## emits, and shows what came back. It never spins anything itself.

const SlotsMenuScene := preload("res://ui/slots_menu.tscn")
const SlotsScript := preload("res://systems/slots.gd")

var _menu: SlotsMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = SlotsMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


func test_it_offers_only_stakes_she_can_cover() -> void:
	_chips = 60
	_menu.refresh()
	assert_eq(_menu.stakes(), [10, 50])


func test_an_empty_purse_offers_no_stake_and_confirming_does_nothing() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_true(_menu.stakes().is_empty())
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "spin_requested")


func test_confirming_emits_the_highlighted_stake_and_spins_nothing_itself() -> void:
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "spin_requested", [_menu.stakes()[1]])
	assert_eq(_chips, 500, "the menu draws and emits")


func test_it_draws_the_whole_paytable() -> void:
	var drawn: String = "\n".join(_menu.drawn_lines())
	for line in SlotsScript.paytable_lines():
		assert_true(drawn.contains(line), "the paytable line '%s' is not on the panel" % line)


func test_a_result_is_shown_until_the_next_one() -> void:
	_menu.show_result(["Apple Apple Apple", "You win 40 chips."])
	assert_true("\n".join(_menu.drawn_lines()).contains("You win 40 chips."))
	_menu.show_result(["Bell Gem Star", "Nothing this time."])
	assert_false("\n".join(_menu.drawn_lines()).contains("You win 40 chips."))


func test_nothing_it_draws_carries_a_dash() -> void:
	_menu.show_result(["Apple Apple Apple", "You win 40 chips."])
	for line in _menu.drawn_lines():
		assert_false(line.contains("--") or line.contains("—"), line)
```

`game/test/test_wheel_menu.gd`:

```gdscript
extends GutTest
## THE WHEEL'S FELT. Two tabs, because there are two bets, and the guess is part of the bet.

const WheelMenuScene := preload("res://ui/wheel_menu.tscn")
const WheelScript := preload("res://systems/wheel.gd")

var _menu: WheelMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = WheelMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


func test_it_opens_on_the_colour_bet() -> void:
	assert_eq(_menu.tab(), WheelMenu.Tab.COLOUR)


func test_the_colour_tab_offers_six_colours_and_never_the_house_pocket() -> void:
	_menu.set_tab(WheelMenu.Tab.COLOUR)
	assert_eq(_menu.guess_count(), 6)
	for i in _menu.guess_count():
		assert_ne(i, WheelScript.Colour.HOUSE)


func test_the_number_tab_offers_every_number_and_no_zero() -> void:
	_menu.set_tab(WheelMenu.Tab.NUMBER)
	assert_eq(_menu.guess_count(), WheelScript.NUMBERS)
	_menu.move_selection(0)
	assert_eq(_menu.selected_guess(), 1, "the numbers start at one; zero is the house's")


func test_confirming_a_colour_bet_emits_kind_guess_and_stake() -> void:
	watch_signals(_menu)
	_menu.set_tab(WheelMenu.Tab.COLOUR)
	_menu.move_selection(3)
	_menu.set_stake_index(0)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "bet_requested",
		[WheelMenu.Tab.COLOUR, 3, _menu.stakes()[0]])


func test_an_empty_purse_refuses_to_bet() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "bet_requested")


func test_the_felt_carries_the_wheel_s_own_rules() -> void:
	var drawn: String = "\n".join(_menu.drawn_lines())
	for line in WheelScript.rules_lines():
		assert_true(drawn.contains(line), "missing rule line: %s" % line)


func test_nothing_it_draws_carries_a_dash() -> void:
	_menu.show_result([WheelScript.pocket_text(7), "You win 60 chips."])
	for tab in [WheelMenu.Tab.COLOUR, WheelMenu.Tab.NUMBER]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)
```

`game/test/test_blackjack_menu.gd`:

```gdscript
extends GutTest
## THE BLACKJACK TABLE'S PANEL, and the placard beside it.

const BlackjackMenuScene := preload("res://ui/blackjack_menu.tscn")
const BlackjackScript := preload("res://systems/blackjack.gd")
const TableMenuScript := preload("res://ui/table_menu.gd")

var _menu: BlackjackMenu = null
var _chips := 500


func before_each() -> void:
	_chips = 500
	_menu = BlackjackMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.open()


func test_every_stake_at_every_table_is_an_even_number_of_chips() -> void:
	for stake in TableMenuScript.STAKES:
		assert_eq(stake % 2, 0,
			"blackjack pays three to two with integer division; an odd stake would round "
				+ "the bonus down by half a chip")


func test_the_placard_tab_prints_the_house_rules() -> void:
	_menu.set_tab(BlackjackMenu.Tab.PLACARD)
	var drawn: Array[String] = _menu.drawn_lines()
	for line in BlackjackScript.placard_lines():
		assert_true(drawn.has(line), "missing placard line: %s" % line)


func test_confirming_at_the_placard_deals_nothing() -> void:
	watch_signals(_menu)
	_menu.set_tab(BlackjackMenu.Tab.PLACARD)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "deal_requested")


func test_confirming_at_the_table_emits_the_stake() -> void:
	watch_signals(_menu)
	_menu.set_tab(BlackjackMenu.Tab.TABLE)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "deal_requested", [_menu.stakes()[0]])


func test_an_empty_purse_refuses_to_deal() -> void:
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "deal_requested")


func test_a_dealt_hand_is_shown_as_cards_and_a_verdict() -> void:
	_menu.show_result(["You: Ace, King", "Dealer: Nine, Seven", "Blackjack. Pays three to two."])
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("You: Ace, King"))
	assert_true(drawn.contains("Blackjack. Pays three to two."))


func test_nothing_it_draws_carries_a_dash() -> void:
	for tab in [BlackjackMenu.Tab.TABLE, BlackjackMenu.Tab.PLACARD]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)
```

- [ ] **Step 6: Run them to see them fail, then write the base and the three tables**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_slots_menu.gd,res://test/test_wheel_menu.gd,res://test/test_blackjack_menu.gd -gexit`

Expected: FAIL, none of the three scenes exist.

`game/ui/table_menu.gd`:

```gdscript
class_name TableMenu
extends CanvasLayer
## THE SHAPE EVERY TABLE IN THE PALACE HAS. Pick a stake you can cover, confirm, read what
## happened. The slot machine, the wheel and the blackjack table each add their own rows and
## their own signal and inherit the rest of this.
##
## THE MENU DRAWS AND EMITS; ranch.gd TRANSACTS AND PAYS. Nothing under game/ui/ may touch
## Economy, Casino or GameState, so a table is handed `chips_provider` and `can_open` and
## hands back one request signal. Same split as game/ui/depot_menu.gd.
##
## IT NEVER OFFERS A STAKE SHE CANNOT COVER. stakes() is cut to the purse, so confirming on
## an empty purse cannot even reach the signal; ranch.gd checks again anyway, because two
## checks on a bet is the right number.
##
## SHOWING A RESULT IS A PUSH, NOT A POLL. ranch.gd settles the bet and then calls
## show_result() with the lines to print, so the table never has to ask what happened and
## never has an opinion about it.
##
## Subclasses override title_text(), drawn_lines(), confirm() and row_count(). The scene tree
## every table's .tscn must have is the one game/ui/depot_menu.tscn has: Dim, and
## Centre/Panel/Margin/Column holding Title, Tabs, Rows and Footer.

## What the tables let her bet. Even numbers, always: Blackjack.payout() pays three to two
## with integer division and an odd stake would round the bonus down by half a chip.
const STAKES: Array[int] = [10, 50, 200]

const FOOTER := "  up down  choose      left right  tab      Enter / A  confirm      Esc / B  leave"
const COLOR_NAME := Color(1.0, 1.0, 1.0, 0.94)
const COLOR_VALUE := Color(1.00, 0.80, 0.25, 1.0)
const COLOR_DIM := Color(1.0, 1.0, 1.0, 0.58)

signal opened()
signal closed()

var can_open := Callable()
var chips_provider := Callable()

var _open := false
var _selected := 0
var _stake_index := 0
var _result: Array[String] = []

@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _tabs: Label = $Centre/Panel/Margin/Column/Tabs
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer


func _ready() -> void:
	visible = false
	_title.text = title_text()
	_footer.text = FOOTER


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not can_open.call():
		return false
	_open = true
	_selected = 0
	_stake_index = 0
	_result = []
	visible = true
	refresh()
	opened.emit()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


## The stakes she can actually cover, in order. Never empty rows, never a row that refuses.
func stakes() -> Array[int]:
	var chips: int = int(chips_provider.call()) if chips_provider.is_valid() else 0
	var out: Array[int] = []
	for stake in STAKES:
		if stake <= chips:
			out.append(stake)
	return out


func selected_stake() -> int:
	var available: Array[int] = stakes()
	if available.is_empty():
		return 0
	return available[clampi(_stake_index, 0, available.size() - 1)]


func set_stake_index(index: int) -> void:
	_stake_index = index
	refresh()


func stake_index() -> int:
	return _stake_index


func selected_index() -> int:
	return _selected


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		_selected = 0
		return
	_selected = posmod(_selected + step, n)
	refresh()


## Push the lines describing what just happened. Replaces whatever was there, so the panel
## always shows the last hand and never two of them.
func show_result(lines: Array[String]) -> void:
	_result = lines.duplicate()
	refresh()


func result_lines() -> Array[String]:
	return _result.duplicate()


## The stake row, drawn by every table above its own rows.
func stake_lines() -> Array[String]:
	var available: Array[int] = stakes()
	if available.is_empty():
		return ["No chips. The cage is in the lobby."]
	var out: Array[String] = []
	for i in available.size():
		out.append("[%d chips]" % available[i] if i == clampi(_stake_index, 0,
			available.size() - 1) else " %d chips " % available[i])
	return ["Stake:  " + "  ".join(out)]


func refresh() -> void:
	if not is_node_ready():
		return
	_title.text = title_text()
	_tabs.text = tabs_text()
	for child in _rows.get_children():
		child.queue_free()
	var lines: Array[String] = drawn_lines()
	for i in lines.size():
		var label := Label.new()
		var picked: bool = i == _selected and row_count() > 0
		label.text = ("> " if picked else "  ") + lines[i]
		label.add_theme_color_override("font_color", COLOR_VALUE if picked else COLOR_NAME)
		_rows.add_child(label)


# --- what a table fills in ---------------------------------------------------------------

func title_text() -> String:
	return "Table"


func tabs_text() -> String:
	return ""


## Every line this menu is currently drawing, in order. For the tests, which otherwise have
## no way to ask whether a string carries a dash without walking the Label nodes.
func drawn_lines() -> Array[String]:
	return []


## How many of those lines the selection may sit on.
func row_count() -> int:
	return 0


## Act on the highlighted row. Returns whether anything was emitted.
func confirm() -> bool:
	return false


func switch_tab(_step: int) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_pressed():
		return
	if event.is_action(&"ui_cancel"):
		close()
	elif event.is_action(&"ui_up"):
		move_selection(-1)
	elif event.is_action(&"ui_down"):
		move_selection(1)
	elif event.is_action(&"ui_left"):
		switch_tab(-1)
	elif event.is_action(&"ui_right"):
		switch_tab(1)
	elif event.is_action(&"ui_accept"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()
```

`game/ui/slots_menu.gd`:

```gdscript
class_name SlotsMenu
extends "res://ui/table_menu.gd"
## THE SLOT MACHINE. One row per stake, the paytable underneath, and the last spin above it.
## It spins nothing: ranch.gd rolls the seeded generator, settles the chips and pushes the
## result back through show_result().
##
## Extended by path rather than by the global class_name, for the reason every preload in
## this project is by path: the class cache lives in the gitignored game/.godot/.

const SlotsScript := preload("res://systems/slots.gd")

const TITLE := "Slots"

signal spin_requested(stake: int)


func title_text() -> String:
	return TITLE


func tabs_text() -> String:
	return "Pull the lever. The house keeps %.1f bits of every 100." \
		% (SlotsScript.house_edge() * 100.0)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	for line in result_lines():
		lines.append(line)
	if not result_lines().is_empty():
		lines.append("")
	for line in stake_lines():
		lines.append(line)
	if not stakes().is_empty():
		lines.append("Spin for %d chips" % selected_stake())
	lines.append("")
	for line in SlotsScript.paytable_lines():
		lines.append(line)
	return lines


## Only the stake rows are selectable; the paytable is reading matter.
func row_count() -> int:
	return stakes().size()


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))


func confirm() -> bool:
	if selected_stake() <= 0:
		return false
	spin_requested.emit(selected_stake())
	return true
```

`game/ui/wheel_menu.gd`:

```gdscript
class_name WheelMenu
extends "res://ui/table_menu.gd"
## THE WHEEL'S FELT. Two tabs because there are two bets: back a colour or back a number.
## The guess is the highlighted row and the stake is the left and right of the stake line, so
## a whole bet is three key presses and never a typed number.
##
## THE HOUSE POCKET IS NOT ON THE FELT. It is on the wheel, and the rules say so, but there
## is no row to back it with, which is what makes it the house's.

const WheelScript := preload("res://systems/wheel.gd")

const TITLE := "The Wheel"

enum Tab { COLOUR, NUMBER }

signal bet_requested(kind: int, guess: int, stake: int)

var _tab: int = Tab.COLOUR


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.COLOUR, Tab.NUMBER)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.NUMBER + 1))


func tabs_text() -> String:
	var left: String = "[Colour]" if _tab == Tab.COLOUR else " Colour "
	var right: String = "[Number]" if _tab == Tab.NUMBER else " Number "
	return "%s   %s      the house keeps %.1f bits of every 100 on either" \
		% [left, right, WheelScript.house_edge() * 100.0]


## How many things she may back on this tab.
func guess_count() -> int:
	return WheelScript.NUMBERS if _tab == Tab.NUMBER else int(WheelScript.Colour.HOUSE)


## What the highlighted row means to Wheel.payout(): a Colour value on the colour tab, a
## pocket number from 1 up on the number tab.
func selected_guess() -> int:
	if _tab == Tab.NUMBER:
		return clampi(_selected, 0, guess_count() - 1) + 1
	return clampi(_selected, 0, guess_count() - 1)


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	for line in result_lines():
		lines.append(line)
	if not result_lines().is_empty():
		lines.append("")
	if _tab == Tab.NUMBER:
		for pocket in range(1, WheelScript.NUMBERS + 1):
			lines.append("Back %d, %s at %d to 1"
				% [pocket, WheelScript.COLOUR_NAMES[WheelScript.colour_of(pocket)],
					WheelScript.NUMBER_PAYS_TO_ONE])
	else:
		for colour in guess_count():
			lines.append("Back %s at %d to 1"
				% [WheelScript.COLOUR_NAMES[colour], WheelScript.COLOUR_PAYS_TO_ONE])
	lines.append("")
	for line in stake_lines():
		lines.append(line)
	lines.append("")
	for line in WheelScript.rules_lines():
		lines.append(line)
	return lines


func row_count() -> int:
	return guess_count()


func confirm() -> bool:
	if selected_stake() <= 0:
		return false
	bet_requested.emit(_tab, selected_guess(), selected_stake())
	return true
```

`game/ui/blackjack_menu.gd`:

```gdscript
class_name BlackjackMenu
extends "res://ui/table_menu.gd"
## THE BLACKJACK TABLE. One tab to play at and one tab holding the placard, because the
## published edge is measured against the strategy card printed on it and a player who wants
## to check that should not have to leave the table to read it.
##
## THE HAND IS PLAYED IN ONE PRESS. The house strategy card is what the player is playing, so
## there is no hit or stand decision to make at the table: ranch.gd deals the whole hand
## through Blackjack.play_hand() and pushes back what happened. A table where the player
## makes the decisions is a bigger game than this slice, and the placard says so out loud.

const BlackjackScript := preload("res://systems/blackjack.gd")

const TITLE := "Blackjack"

enum Tab { TABLE, PLACARD }

signal deal_requested(stake: int)

var _tab: int = Tab.TABLE


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.TABLE, Tab.PLACARD)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.PLACARD + 1))


func tabs_text() -> String:
	var left: String = "[Table]" if _tab == Tab.TABLE else " Table "
	var right: String = "[Placard]" if _tab == Tab.PLACARD else " Placard "
	return "%s   %s      the house keeps %.1f bits of every 100 against the card" \
		% [left, right, BlackjackScript.house_edge() * 100.0]


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	if _tab == Tab.PLACARD:
		for line in BlackjackScript.placard_lines():
			lines.append(line)
		return lines
	for line in result_lines():
		lines.append(line)
	if not result_lines().is_empty():
		lines.append("")
	for line in stake_lines():
		lines.append(line)
	if not stakes().is_empty():
		lines.append("Deal for %d chips" % selected_stake())
	return lines


func row_count() -> int:
	return stakes().size() if _tab == Tab.TABLE else 0


func move_selection(step: int) -> void:
	var n: int = row_count()
	if n <= 0:
		return
	set_stake_index(posmod(stake_index() + step, n))


func confirm() -> bool:
	if _tab != Tab.TABLE or selected_stake() <= 0:
		return false
	deal_requested.emit(selected_stake())
	return true
```

The three scenes are the same copy of `depot_menu.tscn`:

```bash
for pair in "slots_menu:SlotsMenu" "wheel_menu:WheelMenu" "blackjack_menu:BlackjackMenu"; do
  file="${pair%%:*}"; node="${pair##*:}"
  sed -e "s#res://ui/depot_menu.gd#res://ui/$file.gd#" \
      -e "s#\[node name=\"DepotMenu\" type=\"CanvasLayer\"\]#[node name=\"$node\" type=\"CanvasLayer\"]#" \
      game/ui/depot_menu.tscn > "game/ui/$file.tscn"
done
```

- [ ] **Step 7: Run the three table tests to see them pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_slots_menu.gd,res://test/test_wheel_menu.gd,res://test/test_blackjack_menu.gd -gexit`

Expected: PASS, 20 tests.

- [ ] **Step 8: Put the four menus in `ranch.tscn` and wire them in `ranch.gd`**

Add four `CanvasLayer` instances to `game/world/ranch.tscn`, beside the existing `DepotMenu` node, each with the next free `ext_resource` id:

```
[node name="CasinoMenu" parent="." instance=ExtResource("16")]
[node name="SlotsMenu" parent="." instance=ExtResource("17")]
[node name="WheelMenu" parent="." instance=ExtResource("18")]
[node name="BlackjackMenu" parent="." instance=ExtResource("19")]
```

with, in the header block (check the file for the real next ids rather than trusting these):

```
[ext_resource type="PackedScene" path="res://ui/casino_menu.tscn" id="16"]
[ext_resource type="PackedScene" path="res://ui/slots_menu.tscn" id="17"]
[ext_resource type="PackedScene" path="res://ui/wheel_menu.tscn" id="18"]
[ext_resource type="PackedScene" path="res://ui/blackjack_menu.tscn" id="19"]
```

In `ranch.gd`, add the preloads beside the others:

```gdscript
const CasinoScript := preload("res://systems/casino.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const CasinoMenuScript := preload("res://ui/casino_menu.gd")
```

the node handles beside `depot_menu`:

```gdscript
@onready var casino_menu: CanvasLayer = $CasinoMenu
@onready var slots_menu: CanvasLayer = $SlotsMenu
@onready var wheel_menu: CanvasLayer = $WheelMenu
@onready var blackjack_menu: CanvasLayer = $BlackjackMenu
```

and the seeded generator and prompt flag beside `_depot_prompted`:

```gdscript
## Whether the Palace's prompt has already been shown for this approach.
var _palace_prompted := false

## Every roll at every table comes off this one generator, so a gate can seed it and get the
## same night's play back. Seeded from the clock for a person actually playing; see
## set_casino_seed().
var _casino_rng := RandomNumberGenerator.new()
```

Extend the early menu shutter in `_ready()` and `_no_menu_but()` to know about all four. Both lists must be extended or a casino menu opens over the pause menu:

```gdscript
	for menu: CanvasLayer in [build_menu, market_menu, pause_menu, depot_menu, casino_menu,
			slots_menu, wheel_menu, blackjack_menu]:
```

```gdscript
func _no_menu_but(menu: CanvasLayer) -> bool:
	for other in [build_menu, market_menu, pause_menu, depot_menu, creation_screen,
			casino_menu, slots_menu, wheel_menu, blackjack_menu]:
```

Add the bind, called from inside `_bind_build_menu()` on the line after its `_bind_depot_menu()` call (around line 949), which is where `_bind_market_menu()`, `_bind_depot_menu()` and `_bind_pause_menu()` are already called from. That point is late in boot and well after `_bind_game_state()`, so `_game_state` and `_economy` both exist by the time the seed below is read:

```gdscript
## THE PALACE. Four menus, one seeded generator, and every transaction in this file.
##
## can_open ANDs in casino_can_enter(), which is the seam the Resistance slice's ban hangs
## on: that slice makes casino_can_enter() answer false above its heat threshold and the
## whole building shuts, with no other file touched.
func _bind_casino_menus() -> void:
	if casino_menu == null or not casino_menu.has_method("open"):
		return
	_casino_rng.seed = int(Time.get_unix_time_from_system()) if _interactive \
		else _game_state.world_seed if _game_state != null else 1
	casino_menu.set("can_open",
		func() -> bool: return _no_menu_but(casino_menu) and casino_can_enter())
	casino_menu.set("bits_provider", func() -> int: return _current_bits())
	casino_menu.set("chips_provider", func() -> int: return _current_chips())
	casino_menu.set("sign_provider", func() -> Array[String]: return CasinoSignScript.lines())
	for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed],
			["buy_chips_requested", _on_buy_chips_requested],
			["cash_out_requested", _on_cash_out_requested],
			["game_requested", _on_game_requested]]:
		if not casino_menu.is_connected(pair[0], pair[1]):
			casino_menu.connect(pair[0], pair[1])

	for table: CanvasLayer in [slots_menu, wheel_menu, blackjack_menu]:
		if table == null or not table.has_method("open"):
			continue
		table.set("can_open",
			func() -> bool: return _no_menu_but(table) and casino_can_enter())
		table.set("chips_provider", func() -> int: return _current_chips())
		for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed]]:
			if not table.is_connected(pair[0], pair[1]):
				table.connect(pair[0], pair[1])
	# Guarded one at a time rather than in the loop above, because each table has its own
	# request signal. A null menu is a scene edit that dropped a node, which is a FAILED check
	# in _report() rather than a boot that dies here; see _bind_build_menu()'s own note.
	if slots_menu != null and not slots_menu.is_connected("spin_requested",
			_on_spin_requested):
		slots_menu.connect("spin_requested", _on_spin_requested)
	if wheel_menu != null and not wheel_menu.is_connected("bet_requested",
			_on_wheel_bet_requested):
		wheel_menu.connect("bet_requested", _on_wheel_bet_requested)
	if blackjack_menu != null and not blackjack_menu.is_connected("deal_requested",
			_on_deal_requested):
		blackjack_menu.connect("deal_requested", _on_deal_requested)


## WHETHER THE PALACE WILL LET HER IN. Always true in this slice.
##
## THE BAN SEAM. The spec's Resistance route bans the player from the Strip at high heat and
## lifts it like every other punishment. That slice changes this one function and nothing
## else: every casino menu's can_open already asks it.
func casino_can_enter() -> bool:
	return true


## Seed every roll at every table. For gates: a casino that rolls off the clock is a casino a
## gate cannot make a claim about.
func set_casino_seed(seed_value: int) -> void:
	_casino_rng.seed = seed_value


func _current_chips() -> int:
	return _game_state.casino.chips if _game_state != null else 0
```

Add the transactions, beside `pay_the_company()`:

```gdscript
## BUY IN AT THE CAGE. Bits out of the wallet, chips into the purse, one for one. Returns
## what was actually bought.
##
## THE ORDER IS THE SAFETY. The spend happens FIRST and the chips are added only if it
## returned true, so there is no state in which the player holds chips she was not charged
## for; and Economy.spend() refuses as a no op, so there is no state in which she was charged
## for chips she did not get either.
func buy_chips(bits: int) -> int:
	if _game_state == null or _economy == null:
		return 0
	var wanted: int = clampi(bits, 0, _economy.bits)
	if wanted <= 0:
		return 0
	if not _economy.spend(wanted):
		return 0
	_game_state.casino.add_chips(wanted)
	_toast("%d chips. Good luck!" % wanted)
	_refresh_casino_menus()
	return wanted


## CASH OUT AT THE CAGE. Chips out of the purse, bits into the wallet, one for one, and the
## removal happens FIRST for the reason buy_chips() gives.
func cash_out(chips: int) -> int:
	if _game_state == null or _economy == null:
		return 0
	var wanted: int = clampi(chips, 0, _game_state.casino.chips)
	if wanted <= 0:
		return 0
	if not _game_state.casino.remove_chips(wanted):
		return 0
	_economy.grant(wanted)
	_toast("%d bits. Come back soon!" % wanted)
	_refresh_casino_menus()
	return wanted


## ONE SPIN. Returns {"ok": bool, "reels": Array[int], "won": int, "stake": int} so a gate can
## assert on what happened rather than on a toast.
##
## THE STAKE COMES OUT BEFORE THE REELS ARE ROLLED, always, and every game below does the
## same. A roll that happened before the chips were taken is a roll that pays out of a purse
## that might not have covered it.
func play_slots(stake: int) -> Dictionary:
	var refused := {"ok": false, "reels": [], "won": 0, "stake": 0}
	if _game_state == null or not _game_state.casino.can_stake(stake):
		return refused
	if not _game_state.casino.remove_chips(stake):
		return refused
	var reels: Array[int] = SlotsScript.spin(_casino_rng)
	var won: int = SlotsScript.payout(reels, stake)
	if won > 0:
		_game_state.casino.add_chips(won)
	if slots_menu != null and slots_menu.has_method("show_result"):
		slots_menu.call("show_result", [SlotsScript.line_text(reels),
			"You win %d chips." % won if won > 0 else "Nothing this time."])
	_refresh_casino_menus()
	return {"ok": true, "reels": reels, "won": won, "stake": stake}


## ONE SPIN OF THE WHEEL. `kind` is a Wheel.Bet value and `guess` is a colour or a pocket
## number; see Wheel.payout(), which is the only thing that interprets either.
func play_wheel(kind: int, guess: int, stake: int) -> Dictionary:
	var refused := {"ok": false, "pocket": -1, "won": 0, "stake": 0}
	if _game_state == null or not _game_state.casino.can_stake(stake):
		return refused
	if not _game_state.casino.remove_chips(stake):
		return refused
	var pocket: int = WheelScript.spin(_casino_rng)
	var won: int = WheelScript.payout(kind, guess, pocket, stake)
	if won > 0:
		_game_state.casino.add_chips(won)
	if wheel_menu != null and wheel_menu.has_method("show_result"):
		wheel_menu.call("show_result", [WheelScript.pocket_text(pocket),
			"You win %d chips." % won if won > 0 else "The house takes that one."])
	_refresh_casino_menus()
	return {"ok": true, "pocket": pocket, "won": won, "stake": stake}


## ONE HAND. The player plays the strategy card on the placard, so the whole hand settles in
## one call; see BlackjackMenu's class comment.
func play_blackjack(stake: int) -> Dictionary:
	var refused := {"ok": false, "hand": {}, "won": 0, "stake": 0}
	if _game_state == null or not _game_state.casino.can_stake(stake):
		return refused
	if not _game_state.casino.remove_chips(stake):
		return refused
	var hand: Dictionary = BlackjackScript.play_hand(_casino_rng)
	var won: int = BlackjackScript.payout(int(hand["outcome"]), stake)
	if won > 0:
		_game_state.casino.add_chips(won)
	if blackjack_menu != null and blackjack_menu.has_method("show_result"):
		blackjack_menu.call("show_result", [
			"You: " + _cards_text(hand["player"]),
			"Dealer: " + _cards_text(hand["dealer"]),
			BlackjackScript.outcome_text(hand),
		])
	_refresh_casino_menus()
	return {"ok": true, "hand": hand, "won": won, "stake": stake}


func _cards_text(cards: Array) -> String:
	var names: Array[String] = []
	for card in cards:
		names.append(BlackjackScript.card_text(int(card)))
	return ", ".join(names)


func _refresh_casino_menus() -> void:
	for menu: CanvasLayer in [casino_menu, slots_menu, wheel_menu, blackjack_menu]:
		if menu != null and menu.has_method("refresh"):
			menu.call("refresh")


func _on_buy_chips_requested(bits: int) -> void:
	buy_chips(bits)


func _on_cash_out_requested(chips: int) -> void:
	cash_out(chips)


func _on_spin_requested(stake: int) -> void:
	play_slots(stake)


func _on_wheel_bet_requested(kind: int, guess: int, stake: int) -> void:
	play_wheel(kind, guess, stake)


func _on_deal_requested(stake: int) -> void:
	play_blackjack(stake)


## WALK FROM THE LOBBY TO A TABLE. The lobby closes and the table opens; leaving the table
## with Escape leaves the Palace, which is one press fewer than walking back out through a
## lobby the player has already read.
func _on_game_requested(game: int) -> void:
	if casino_menu != null and casino_menu.has_method("close"):
		casino_menu.close()
	var table: CanvasLayer = get_table_menu(game)
	if table != null and table.has_method("open"):
		table.open()


## The menu behind one of CasinoMenu's four doors, or null. Racing's is built in Task 7 and
## answers null until then.
func get_table_menu(game: int) -> CanvasLayer:
	match game:
		CasinoMenuScript.Game.SLOTS:
			return slots_menu
		CasinoMenuScript.Game.WHEEL:
			return wheel_menu
		CasinoMenuScript.Game.BLACKJACK:
			return blackjack_menu
	return null


func get_casino_menu() -> CanvasLayer:
	return casino_menu
```

Add the prompt, beside `_update_depot_interaction()`:

```gdscript
## E at the Palace door opens the lobby. Once per approach, the Depot's and the Market's rule.
func _update_palace_interaction() -> void:
	if not _no_other_menu_open():
		return
	var near := is_near_palace()
	if near != _palace_prompted:
		_palace_prompted = near
		if near and casino_can_enter():
			_toast("Press E / X at the Spectra Palace.")
	if near and Input.is_action_just_pressed(&"interact") and _prompt_slot == null:
		if casino_menu != null and casino_menu.has_method("open"):
			casino_menu.open()
```

and call it from `_physics_process()` immediately after `_update_depot_interaction()`:

```gdscript
	_update_palace_interaction()
```

and add the call itself inside `_bind_build_menu()`:

```gdscript
	_bind_market_menu()
	_bind_depot_menu()
	_bind_casino_menus()
	_bind_pause_menu()
```

- [ ] **Step 9: Run everything**

Run: `bash tools/run_tests.sh`

Expected: green, `Tests` up by 33 from Task 5.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`

Expected: `RANCH_OK ponies=49 props=60 assets=present`, exit 0. The four new `CanvasLayer` children do not change the census; if the props number moved, a menu was added under `Buildings` by mistake.

Run the other seven gates as in Task 5 Step 10; all exit 0.

- [ ] **Step 10: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: the lobby, the cage and three tables\n\nFour menus that draw and emit and one file that transacts, the same split the\nDepot has. A table never offers a stake the purse cannot cover and ranch.gd\nchecks again anyway; the stake always leaves the purse before the reels roll,\nso no roll can ever pay out of chips that were not there.\n\nThe cage spends before it adds and removes before it grants, so a refusal on\neither side leaves both untouched. casino_can_enter() is the whole ban seam\nthe Resistance slice needs: every menu s can_open already asks it.\n\nThe three tables share table_menu.gd because they ask the same three\nquestions; each still has its own scene and its own signal.\n' > /tmp/casino-commit.txt
git add game/ui/table_menu.gd game/ui/table_menu.gd.uid game/ui/casino_menu.gd game/ui/casino_menu.gd.uid game/ui/casino_menu.tscn game/ui/slots_menu.gd game/ui/slots_menu.gd.uid game/ui/slots_menu.tscn game/ui/wheel_menu.gd game/ui/wheel_menu.gd.uid game/ui/wheel_menu.tscn game/ui/blackjack_menu.gd game/ui/blackjack_menu.gd.uid game/ui/blackjack_menu.tscn game/world/ranch.gd game/world/ranch.tscn game/test/test_casino_menu.gd game/test/test_slots_menu.gd game/test/test_wheel_menu.gd game/test/test_blackjack_menu.gd
git commit -F /tmp/casino-commit.txt
```

---

### Task 7: The track behind the casino

**Files:**
- Create: `game/world/race_runner.gd`, `game/world/race_track.gd`, `game/ui/race_menu.gd`/`.tscn`
- Modify: `game/world/ranch.tscn` (a `Track` under `Strip`, a `RaceMenu` CanvasLayer), `game/world/ranch.gd` (the track's build, the race bind, `start_race()`, the settle, `_no_menu_but()`, `get_table_menu()`)
- Test: `game/test/test_race_menu.gd`, `game/test/test_race_runner.gd`

**Interfaces:**
- Consumes: `RaceCard.LANES/TRACK_LENGTH/PLAYER_LANE/TAKEOUT`, `RaceCard.entrant_from()`, `build_field()`, `win_chances()`, `decimal_odds()`, `odds_text()`, `run()`, `payout()`, `apply_race_effects()`, `CompanyRunners.load_shipped()`, `PonyVisuals.build()`, `StockTint.apply()`, `StockPalette.load_stock()`, `PonyInstance.resolve_data()`, `Gait.clip_for_speed()/playback_scale_for_clip()`, `Pen.body_for()`, `Pen.find_pony()`, `TableMenu`.
- Produces:
  - `class_name RaceRunner extends Node3D`. `func dress(data: PonyData, triple: Dictionary, display: String) -> bool`, `func runner_name() -> String`, `func has_model() -> bool`, `func set_pose(at: Vector3, heading: Vector3, speed: float) -> void`, `func rest() -> void`.
  - `class_name RaceTrack extends Node3D`. `const LANES := 6`, `LANE_WIDTH := 2.2`, `LENGTH := 40.0`, `CENTRE := Vector2(0.0, 80.0)`, `START_X := -20.0`, `FINISH_X := 20.0`. `signal race_finished(order: Array, winner: int)`. `func configure(ground_sampler: Callable) -> void`, `func build() -> void`, `func lane_z(lane: int) -> float`, `func lane_point(lane: int, t: float) -> Vector3`, `func dress(field: Array[Dictionary]) -> int`, `func start(field: Array[Dictionary], result: Dictionary) -> bool`, `func is_running() -> bool`, `func runner_count() -> int`, `func runner(lane: int) -> RaceRunner`.
  - `class_name RaceMenu extends TableMenu`. `enum Tab { ENTER, BET, CARD }`. `signal entrant_chosen(uid: StringName)`, `signal race_requested(uid: StringName, lane: int, stake: int)`. `var entrants_provider := Callable()`. `func set_field(field: Array[Dictionary], odds: Array[float]) -> void`, `func selected_entrant_uid() -> StringName`, `func selected_lane() -> int`, `func tab() -> int`, `func set_tab(value: int) -> void`.
  - `ranch.gd` gains `signal race_settled(payout: int, winner: int)`, `func start_race(uid: StringName, lane: int, stake: int) -> Dictionary`, `func get_race_track() -> Node3D`, `func get_race_menu() -> CanvasLayer`, `func race_entrants() -> Array[Dictionary]`, `func _penned(uid: StringName) -> Dictionary`.

**THE RULE THIS TASK EXISTS TO NOT BREAK.** Only `Pony._state_leaving` frees a pony, and racing frees, harms and removes nobody. So the six things running down the track are NOT `Pony` nodes. `RaceRunner` is a plain `Node3D` that builds the same model `PonyVisuals.build()` builds for every pony on the map, tints it the same way `StockTint` tints a stock pony, and plays the same `gallop` clip at the same `Gait` playback scale, and that is all it is: no state machine, no leash, no detection area, and nothing the magic beam could ever grab. The pony you entered never leaves her pen; her body there is hidden for the length of the race so the world does not show her twice, and it is visible again the moment the race settles. Everything that happens to her is two clamped numbers, written by `RaceCard.apply_race_effects()`.

**The geometry.** The track runs east along X, from `START_X` to `FINISH_X`, forty metres, which is `RaceCard.TRACK_LENGTH` read from that file rather than declared twice. Six lanes 2.2 m apart, centred on `z = 80`, so lane centres run from 74.5 to 85.5, and the far corner of the track is 23.1 m from the Strip's centre and inside the region. The Palace's back wall is at `z = 70.5`, so there are four clear metres between the building and lane one, which is where the player stands to watch.

**How the playback cannot disagree with the result.** `RaceCard.run()` hands back a finishing time per lane. The track advances one clock and puts each runner at `elapsed / times[lane]` of the way down her lane, clamped to one. Because those times are strictly ordered by the finish order, the runner who crosses first IS the winner the arithmetic named, and the track has no opinion at all. It emits `race_finished(order, winner)` with the order the card gave it, so even a rendering that somehow lagged could not settle a bet the wrong way.

- [ ] **Step 1: Write the failing runner test**

`game/test/test_race_runner.gd`:

```gdscript
extends GutTest
## ONE VISUAL RUNNER. The claim under test is mostly a negative one: this is not a Pony, it
## cannot become one, and dressing it again does not free anything that was ever a pony.

const RaceRunnerScript := preload("res://world/race_runner.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const GaitScript := preload("res://systems/gait.gd")

var _runner: RaceRunner = null


func before_each() -> void:
	_runner = RaceRunnerScript.new()
	add_child_autofree(_runner)


func _stock_data() -> PonyData:
	return PonyInstanceScript.resolve_data(&"stock_bold")


func test_a_runner_is_not_a_pony_and_never_becomes_one() -> void:
	assert_false(_runner is PonyScript, "a racer is scenery, not a resident")
	assert_false(_runner.has_method("leave"), "nothing here can take a pony off the map")
	assert_false(_runner.has_method("set_held"), "and the beam has nothing to grab")


func test_an_undressed_runner_has_no_model_and_poses_without_erroring() -> void:
	assert_false(_runner.has_model())
	_runner.set_pose(Vector3(1.0, 0.0, 2.0), Vector3(1.0, 0.0, 0.0), 3.5)
	assert_almost_eq(_runner.global_position.x, 1.0, 1e-4)


func test_dressing_builds_a_model_and_names_her() -> void:
	var data: PonyData = _stock_data()
	if data == null or not ResourceLoader.exists(data.model_path):
		pass_test("no converted assets on this machine; nothing to dress")
		return
	assert_true(_runner.dress(data, {"coat": 1, "mane": 2, "eyes": 3}, "Quarterly Dividend"))
	assert_true(_runner.has_model())
	assert_eq(_runner.runner_name(), "Quarterly Dividend")


func test_dressing_twice_replaces_the_model_and_leaves_one_behind() -> void:
	var data: PonyData = _stock_data()
	if data == null or not ResourceLoader.exists(data.model_path):
		pass_test("no converted assets on this machine; nothing to dress")
		return
	_runner.dress(data, {"coat": 0, "mane": 0, "eyes": 0}, "First")
	_runner.dress(data, {"coat": 1, "mane": 1, "eyes": 1}, "Second")
	assert_eq(_runner.runner_name(), "Second")
	var models: int = 0
	for child in _runner.get_children():
		if child is Node3D and not (child is Label3D):
			models += 1
	assert_eq(models, 1, "the old model is replaced, not stacked")


func test_a_posed_runner_faces_the_way_she_is_running() -> void:
	_runner.set_pose(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 3.5)
	assert_almost_eq(_runner.rotation.y, atan2(-1.0, 0.0), 1e-4,
		"the asset's forward is minus Z, the same convention pony.gd turns by")


func test_a_running_speed_is_inside_the_gallop_band() -> void:
	assert_eq(GaitScript.clip_for_speed(3.4), &"gallop",
		"every speed the race uses must read as a gallop, or the runner slides")
```

- [ ] **Step 2: Run it to see it fail, then write `game/world/race_runner.gd`**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_runner.gd -gexit`

Expected: FAIL, `res://world/race_runner.gd` does not exist.

```gdscript
class_name RaceRunner
extends Node3D
## ONE OF THE SIX THINGS RUNNING DOWN THE TRACK, and it is deliberately not a pony.
##
## WHY THIS EXISTS AT ALL. The project rule is that only Pony._state_leaving may free a pony,
## and the spec's rule for this slice is that racing never frees, harms or removes one. A
## race that instanced six Pony nodes and freed them at the wire would break both, and a race
## that took the player's pony out of her pen to run in would break the second. So the track
## runs stand ins: a RaceRunner builds the SAME model PonyVisuals.build() builds for every
## pony on the map, tints it the way StockTint tints a stock pony, and plays the same gallop
## clip at the same Gait playback scale. It has no state machine, no leash, no detection
## area and no capture path, so there is nothing here for the beam to grab and nothing here
## that was ever a resident of anything.
##
## THE PONY YOU ENTERED NEVER LEAVES HER PEN. ranch.gd hides her pen body for the length of
## the race so the world does not show her in two places, and shows it again when the race
## settles. Everything that actually happens to her is RaceCard.apply_race_effects(): two
## clamped numbers on her own record.
##
## dress() FREES A MODEL, NOT A PONY. Re dressing a lane replaces the visual it was carrying.
## That node is a glTF instance, never a Pony and never adopted by one, which is the whole
## reason this class is separate from game/actors/pony/pony.gd rather than a mode of it.

const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const GaitScript := preload("res://systems/gait.gd")

const NAMEPLATE_HEIGHT := 2.5
const NAMEPLATE_SIZE := 0.28

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _plate: Label3D = null
var _runner_name := ""


## Give this lane a body and a name. Returns whether a model was actually built; false on a
## checkout with no converted assets, which is a reported state and not an error (see
## docs/ci.md section 4). Safe to call again: the previous model is replaced.
func dress(data: PonyData, triple: Dictionary, display: String) -> bool:
	_runner_name = display
	_ensure_plate()
	_plate.text = display
	if _model != null:
		_model.queue_free()
		_model = null
		_anim = null
	if data == null:
		return false
	var built: Node3D = PonyVisualsScript.build(data)
	if built == null:
		return false
	_model = built
	add_child(_model)
	if not triple.is_empty():
		StockTintScript.apply(_model, StockPaletteScript.load_stock(), triple)
	_anim = _model.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) as AnimationPlayer
	rest()
	return true


func runner_name() -> String:
	return _runner_name


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


## Stand her at `at`, facing `heading`, with the hooves matching `speed`. Called once per
## frame per lane while a race is running.
func set_pose(at: Vector3, heading: Vector3, speed: float) -> void:
	global_position = at
	if heading.length_squared() > 0.0:
		# The asset's forward is minus Z (baked in by tools/export_blend.py), the same
		# convention game/actors/pony/pony.gd's _update_facing() turns by.
		rotation.y = atan2(-heading.x, -heading.z)
	if _anim == null:
		return
	var clip: StringName = GaitScript.clip_for_speed(speed)
	if _anim.has_animation(clip) and _anim.current_animation != clip:
		_anim.play(clip)
	_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)


## Between races: standing about, breathing.
func rest() -> void:
	if _anim == null:
		return
	if _anim.has_animation(&"idle") and _anim.current_animation != &"idle":
		_anim.play(&"idle")
	_anim.speed_scale = 1.0


## The name above her, so the player can tell six recoloured ponies apart from the rail.
func _ensure_plate() -> void:
	if _plate != null and is_instance_valid(_plate):
		return
	_plate = Label3D.new()
	_plate.name = "Nameplate"
	_plate.font_size = 48
	_plate.pixel_size = NAMEPLATE_SIZE / 48.0
	_plate.position = Vector3(0.0, NAMEPLATE_HEIGHT, 0.0)
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.shaded = false
	_plate.outline_size = 8
	add_child(_plate)
```

- [ ] **Step 3: Run the runner test to see it pass, then write `game/world/race_track.gd`**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_runner.gd -gexit`

Expected: PASS, 6 tests.

```gdscript
class_name RaceTrack
extends Node3D
## SIX LANES BEHIND THE SPECTRA PALACE, and the rail the player watches from.
##
## THE TRACK HAS NO OPINION ABOUT WHO WINS. game/systems/race_card.gd decides the finish
## order and hands back a finishing time per lane; this node advances one clock and puts each
## runner at elapsed over her own time down her own lane. Because those times are strictly
## ordered by the finish order, the runner who crosses first IS the winner the arithmetic
## named, and race_finished carries the card's own order rather than anything measured off
## the screen. A dropped frame cannot settle a bet.
##
## THE SIX RUNNERS ARE BUILT ONCE AND KEPT. They are RaceRunners, not ponies (see that file's
## class comment), and they stand in the paddock between races. Nothing here creates or frees
## a Pony, and the pony the player entered is in her pen the whole time.
##
## BUILT IN CODE, seated on Terrain.height_at() like the fences and the Strip's lamps, for
## the reason game/world/region_fence.gd gives: the ground does not exist when ranch.tscn is
## loaded.

const RaceCardScript := preload("res://systems/race_card.gd")
const RaceRunnerScript := preload("res://world/race_runner.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const LANES := 6
const LANE_WIDTH := 2.2

## Read from the card rather than declared twice: the times the card computes are this length
## over a speed, so a track of a different length would be a track the race does not fit.
const LENGTH := RaceCardScript.TRACK_LENGTH

const CENTRE := Vector2(0.0, 80.0)
const START_X := -20.0
const FINISH_X := 20.0

## Where a runner stands when there is no race: two metres behind the gate, in her own lane.
const PADDOCK_X := START_X - 2.0

const RAIL_HEIGHT := 1.05
const RAIL_THICKNESS := 0.12
const RAIL_SEGMENTS := 10
const RAIL_MARGIN := 1.2
const RAIL_COLOR := Color(0.86, 0.84, 0.90)
const POST_COLOR := Color(0.30, 0.27, 0.34)
const FINISH_COLOR := Color(1.00, 0.84, 0.32)

signal race_finished(order: Array, winner: int)

var _ground := Callable()
var _runners: Array[RaceRunner] = []
var _built := false
var _running := false
var _elapsed := 0.0
var _times: Array[float] = []
var _order: Array[int] = []


func configure(ground_sampler: Callable) -> void:
	_ground = ground_sampler


## Lay the lanes, the rails and the wire, and stand six runners in the paddock. Idempotent.
func build() -> void:
	if _built:
		return
	_built = true
	for lane in LANES:
		var runner: RaceRunner = RaceRunnerScript.new()
		runner.name = "Lane%d" % lane
		add_child(runner)
		runner.global_position = _paddock_point(lane)
		_runners.append(runner)
	_rail(lane_z(0) - LANE_WIDTH * 0.5 - RAIL_MARGIN, "RailSouth")
	_rail(lane_z(LANES - 1) + LANE_WIDTH * 0.5 + RAIL_MARGIN, "RailNorth")
	_wire()


func runner_count() -> int:
	return _runners.size()


func runner(lane: int) -> RaceRunner:
	if lane < 0 or lane >= _runners.size():
		return null
	return _runners[lane]


func is_running() -> bool:
	return _running


func lane_z(lane: int) -> float:
	return CENTRE.y + (float(lane) - (float(LANES) - 1.0) * 0.5) * LANE_WIDTH


## A point `t` of the way down `lane`, seated on the ground. t of 0 is the gate and t of 1 is
## the wire.
func lane_point(lane: int, t: float) -> Vector3:
	var x: float = lerpf(START_X, FINISH_X, clampf(t, 0.0, 1.0))
	var z: float = lane_z(lane)
	return Vector3(x, _y(x, z), z)


## Put the field's six bodies on the six lanes. Returns how many actually got a model; fewer
## than LANES on a checkout with no converted assets, which is the documented degraded state
## and not an error.
##
## A lane's data_id is resolved through PonyInstance.resolve_data(), which reaches the hidden
## stock records as well as the named roster (game/systems/pony_registry.gd's hidden index),
## so a Company runner built on stock_bold resolves exactly as the player's own stock pony
## does.
func dress(field: Array[Dictionary]) -> int:
	var dressed := 0
	for entry in field:
		var lane: int = int(entry["lane"])
		var body: RaceRunner = runner(lane)
		if body == null:
			continue
		var data: PonyData = PonyInstanceScript.resolve_data(StringName(entry["data_id"]))
		if body.dress(data, entry["stock"] as Dictionary, String(entry["name"])):
			dressed += 1
		body.set_pose(_paddock_point(lane), Vector3(1.0, 0.0, 0.0), 0.0)
	return dressed


## THEY'RE OFF. `result` is what RaceCard.run() answered for this exact field. Returns false
## for a field or a result that does not describe this track, having started nothing.
func start(field: Array[Dictionary], result: Dictionary) -> bool:
	if _running or field.size() != LANES:
		return false
	var times: Array = result.get("times", [])
	var order: Array = result.get("order", [])
	if times.size() != LANES or order.size() != LANES:
		return false
	_times = []
	for t in times:
		_times.append(maxf(float(t), 0.001))
	_order = order.duplicate()
	_elapsed = 0.0
	_running = true
	for lane in LANES:
		var body: RaceRunner = runner(lane)
		if body != null:
			body.set_pose(lane_point(lane, 0.0), Vector3(1.0, 0.0, 0.0), 0.0)
	return true


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var everybody_home := true
	for lane in LANES:
		var body: RaceRunner = runner(lane)
		if body == null:
			continue
		var t: float = clampf(_elapsed / _times[lane], 0.0, 1.0)
		if t < 1.0:
			everybody_home = false
		var speed: float = 0.0 if t >= 1.0 else LENGTH / _times[lane]
		body.set_pose(lane_point(lane, t), Vector3(1.0, 0.0, 0.0), speed)
		if t >= 1.0:
			body.rest()
	if everybody_home:
		_running = false
		# The card's own order, not one measured off the screen: see the class comment.
		race_finished.emit(_order.duplicate(), int(_order[0]) if not _order.is_empty() else -1)


func _paddock_point(lane: int) -> Vector3:
	var z: float = lane_z(lane)
	return Vector3(PADDOCK_X, _y(PADDOCK_X, z), z)


func _y(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else 0.0


## One rail along the whole length, in segments so it follows the ground. Solid, on the PROPS
## layer, so the player leans on it rather than wandering into lane three.
func _rail(z: float, rail_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = rail_name
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	add_child(body)
	var step: float = (FINISH_X - START_X) / float(RAIL_SEGMENTS)
	for i in RAIL_SEGMENTS:
		var x: float = START_X + step * (float(i) + 0.5)
		var y: float = _y(x, z) + RAIL_HEIGHT * 0.5
		_slab(body, "%s_%d" % [rail_name, i],
			Vector3(step, RAIL_THICKNESS, RAIL_THICKNESS), Vector3(x, y, z), RAIL_COLOR)
		_slab(body, "%sPost_%d" % [rail_name, i],
			Vector3(RAIL_THICKNESS, RAIL_HEIGHT, RAIL_THICKNESS),
			Vector3(x - step * 0.5, _y(x, z) + RAIL_HEIGHT * 0.5, z), POST_COLOR)


## The wire: a bright post at each end of the finish line, so the eye knows where to look.
func _wire() -> void:
	var body := StaticBody3D.new()
	body.name = "Wire"
	body.collision_layer = LayersScript.PROPS
	body.collision_mask = 0
	add_child(body)
	for side in [-1.0, 1.0]:
		var z: float = CENTRE.y + side * (float(LANES) * LANE_WIDTH * 0.5 + RAIL_MARGIN)
		_slab(body, "WirePost%s" % ("N" if side > 0.0 else "S"),
			Vector3(0.22, 3.0, 0.22), Vector3(FINISH_X, _y(FINISH_X, z) + 1.5, z),
			FINISH_COLOR)


## One box with a matching collider, the same shape game/world/building.gd's _slab() has, so
## what you see and what you bump into cannot drift apart.
func _slab(parent: StaticBody3D, slab_name: String, size: Vector3, at: Vector3,
		colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = slab_name
	mesh.mesh = box
	parent.add_child(mesh)
	mesh.global_position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = slab_name + "Col"
	collider.shape = shape
	parent.add_child(collider)
	collider.global_position = at
```

- [ ] **Step 4: Write the failing race menu test**

`game/test/test_race_menu.gd`:

```gdscript
extends GutTest
## THE RACE PANEL: pick a pony, read the odds, back a lane. It never runs a race, never
## touches a pen and never moves a chip.

const RaceMenuScene := preload("res://ui/race_menu.tscn")
const RaceCardScript := preload("res://systems/race_card.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")

var _menu: RaceMenu = null
var _chips := 500


func _entrants() -> Array[Dictionary]:
	return [
		{"uid": &"a#000001", "name": "Bramble", "happiness": 0.5},
		{"uid": &"b#000002", "name": "Pip", "happiness": 0.9},
	]


func _field() -> Array[Dictionary]:
	return RaceCardScript.build_field({
		"name": "Bramble", "uid": &"a#000001", "data_id": &"stock_bold",
		"speed": 4.0, "stamina": 1.0, "spirit": 1.0, "happiness": 0.5, "stock": {},
	}, CompanyRunnersScript.load_shipped())


func before_each() -> void:
	_chips = 500
	_menu = RaceMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.can_open = func() -> bool: return true
	_menu.chips_provider = func() -> int: return _chips
	_menu.entrants_provider = func() -> Array[Dictionary]: return _entrants()
	_menu.open()


func test_it_opens_on_the_entry_list() -> void:
	assert_eq(_menu.tab(), RaceMenu.Tab.ENTER)
	assert_eq(_menu.drawn_lines().size(), 2)


func test_with_no_penned_ponies_it_says_so_and_enters_nobody() -> void:
	_menu.entrants_provider = func() -> Array[Dictionary]: return []
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "entrant_chosen")
	assert_true("\n".join(_menu.drawn_lines()).contains("pen"))


func test_choosing_an_entrant_emits_her_uid() -> void:
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "entrant_chosen", [&"b#000002"])
	assert_eq(_menu.selected_entrant_uid(), &"b#000002")


func test_the_bet_tab_shows_six_lanes_with_the_odds_they_were_given() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	var drawn: Array[String] = _menu.drawn_lines()
	assert_eq(drawn.size(), RaceCardScript.LANES)
	assert_true(drawn[0].contains(RaceCardScript.odds_text(odds[0])),
		"the panel shows the odds it was handed: %s" % drawn[0])


func test_the_bet_tab_with_no_field_yet_asks_her_to_enter_a_pony_first() -> void:
	_menu.set_tab(RaceMenu.Tab.BET)
	assert_true("\n".join(_menu.drawn_lines()).contains("Enter"))


func test_backing_a_lane_emits_the_entrant_the_lane_and_the_stake() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.move_selection(0)
	_menu.confirm()
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	_menu.move_selection(2)
	_menu.set_stake_index(1)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "race_requested",
		[&"a#000001", 2, _menu.stakes()[1]])


func test_an_empty_purse_cannot_back_anything() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	_menu.set_tab(RaceMenu.Tab.BET)
	_chips = 0
	_menu.refresh()
	watch_signals(_menu)
	assert_false(_menu.confirm())
	assert_signal_not_emitted(_menu, "race_requested")


func test_the_card_tab_explains_where_the_odds_come_from() -> void:
	_menu.set_tab(RaceMenu.Tab.CARD)
	var drawn: String = "\n".join(_menu.drawn_lines())
	assert_true(drawn.contains("%.1f" % (RaceCardScript.TAKEOUT * 100.0)))


func test_nothing_it_draws_carries_a_dash() -> void:
	var field: Array[Dictionary] = _field()
	var odds: Array[float] = []
	for lane in RaceCardScript.LANES:
		odds.append(RaceCardScript.decimal_odds(field, lane))
	_menu.set_field(field, odds)
	for tab in [RaceMenu.Tab.ENTER, RaceMenu.Tab.BET, RaceMenu.Tab.CARD]:
		_menu.set_tab(tab)
		for line in _menu.drawn_lines():
			assert_false(line.contains("--") or line.contains("—"), line)
```

- [ ] **Step 5: Run it to see it fail, then write `game/ui/race_menu.gd` and its scene**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_menu.gd -gexit`

Expected: FAIL, `res://ui/race_menu.tscn` does not exist.

```gdscript
class_name RaceMenu
extends "res://ui/table_menu.gd"
## THE RACE PANEL. Three tabs because a bet on a race is three decisions: which of your
## ponies runs, which lane you back, and for how much.
##
## THE ODDS ARE PUSHED IN, NOT WORKED OUT HERE. Choosing an entrant emits `entrant_chosen`;
## ranch.gd builds the field, asks RaceCard for the chances and the odds, and pushes both
## back through set_field(). So this file never sees a PonyInstance, never reads a pen, and
## cannot compute a price of its own that disagrees with the one the race settles at. Same
## split as every other menu in this project.
##
## YOUR PONY IS ALWAYS ON THE RAIL, lane RaceCard.PLAYER_LANE, and the card tab says so. You
## are free to back a Company runner instead, and sometimes that is the right bet.

const RaceCardScript := preload("res://systems/race_card.gd")

const TITLE := "Racing"

enum Tab { ENTER, BET, CARD }

signal entrant_chosen(uid: StringName)
signal race_requested(uid: StringName, lane: int, stake: int)

## Injected by ranch.gd: what is standing in the pens, as [{"uid", "name", "happiness"}].
var entrants_provider := Callable()

var _tab: int = Tab.ENTER
var _entrant: StringName = &""
var _entrant_name := ""
var _field: Array[Dictionary] = []
var _odds: Array[float] = []


func title_text() -> String:
	return TITLE


func tab() -> int:
	return _tab


func set_tab(value: int) -> void:
	_tab = clampi(value, Tab.ENTER, Tab.CARD)
	_selected = 0
	refresh()


func switch_tab(step: int) -> void:
	set_tab(posmod(_tab + step, Tab.CARD + 1))


func tabs_text() -> String:
	var names: Array[String] = ["Enter", "Bet", "Card"]
	var out: Array[String] = []
	for i in names.size():
		out.append("[%s]" % names[i] if i == _tab else " %s " % names[i])
	return "   ".join(out) + "      the house keeps %.1f bits of every 100" \
		% (RaceCardScript.TAKEOUT * 100.0)


func entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not entrants_provider.is_valid():
		return out
	for entry in entrants_provider.call():
		out.append(entry as Dictionary)
	return out


func selected_entrant_uid() -> StringName:
	return _entrant


## Which lane the BET tab is sitting on. Meaningless until a field has been pushed.
func selected_lane() -> int:
	return clampi(_selected, 0, maxi(_field.size() - 1, 0))


## ranch.gd hands back the six lanes and the price of each. Replaces whatever was here, so
## the panel can never show last entrant's prices.
func set_field(field: Array[Dictionary], odds: Array[float]) -> void:
	_field = field.duplicate()
	_odds = odds.duplicate()
	refresh()


func drawn_lines() -> Array[String]:
	var lines: Array[String] = []
	match _tab:
		Tab.ENTER:
			var list: Array[Dictionary] = entrants()
			if list.is_empty():
				lines.append("Nobody in your pen is ready to run today.")
				return lines
			for entry in list:
				lines.append("%s   spirits %d of 10"
					% [String(entry["name"]), roundi(float(entry["happiness"]) * 10.0)])
		Tab.BET:
			if _field.is_empty():
				lines.append("Enter one of your ponies first, over on the Enter tab.")
				return lines
			for i in _field.size():
				var entry: Dictionary = _field[i]
				var mine: String = "your pony" if bool(entry["player"]) else "Cloudsdale"
				lines.append("Lane %d   %s (%s)   pays %s"
					% [i + 1, String(entry["name"]), mine,
						RaceCardScript.odds_text(_odds[i] if i < _odds.size() else 0.0)])
			for line in stake_lines():
				lines.append(line)
		Tab.CARD:
			lines.append("Six lanes. Yours runs on the rail, lane %d, every time."
				% (RaceCardScript.PLAYER_LANE + 1))
			lines.append("The five others belong to Cloudsdale and are kept at")
			lines.append("exactly %d per cent morale. It is in the staff handbook."
				% roundi(RaceCardScript.COMPANY_HAPPINESS * 100.0))
			lines.append("")
			lines.append("Odds come from her speed, her stamina, her spirit and")
			lines.append("how happy she is. A hungry pony is a slow pony.")
			lines.append("The house keeps %.1f bits of every 100 wagered, on every"
				% (RaceCardScript.TAKEOUT * 100.0))
			lines.append("lane on the card. You may back any of them.")
	return lines


## Only the ENTER and BET tabs have rows worth sitting on; the card is reading matter. The
## BET tab's rows are the six lanes, and the stake line under them is moved with left and
## right the way every other table's is.
func row_count() -> int:
	match _tab:
		Tab.ENTER:
			return entrants().size()
		Tab.BET:
			return _field.size()
	return 0


func confirm() -> bool:
	match _tab:
		Tab.ENTER:
			var list: Array[Dictionary] = entrants()
			if _selected < 0 or _selected >= list.size():
				return false
			_entrant = StringName(list[_selected]["uid"])
			_entrant_name = String(list[_selected]["name"])
			entrant_chosen.emit(_entrant)
			return true
		Tab.BET:
			if _field.is_empty() or _entrant.is_empty() or selected_stake() <= 0:
				return false
			race_requested.emit(_entrant, selected_lane(), selected_stake())
			return true
	return false
```

The scene is the same copy of `depot_menu.tscn`:

```bash
sed -e 's#res://ui/depot_menu.gd#res://ui/race_menu.gd#' \
    -e 's#\[node name="DepotMenu" type="CanvasLayer"\]#[node name="RaceMenu" type="CanvasLayer"]#' \
    game/ui/depot_menu.tscn > game/ui/race_menu.tscn
```

- [ ] **Step 6: Run the race menu test to see it pass**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game -s addons/gut/gut_cmdln.gd -gtest=res://test/test_race_menu.gd -gexit`

Expected: PASS, 9 tests.

- [ ] **Step 7: Put the track and the race menu in the world and wire the race in `ranch.gd`**

Add to `game/world/ranch.tscn`:

```
[node name="Track" type="Node3D" parent="Strip"]
script = ExtResource("20")

[node name="RaceMenu" parent="." instance=ExtResource("21")]
```

with, in the header block (again, check the file for the real next ids):

```
[ext_resource type="Script" path="res://world/race_track.gd" id="20"]
[ext_resource type="PackedScene" path="res://ui/race_menu.tscn" id="21"]
```

In `ranch.gd`, add the preloads:

```gdscript
const RaceCardScript := preload("res://systems/race_card.gd")
const RaceTrackScript := preload("res://world/race_track.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")
```

the handles:

```gdscript
@onready var race_track: Node3D = $Strip/Track
@onready var race_menu: CanvasLayer = $RaceMenu
```

the signal, beside `gate_report_finished`:

```gdscript
## Emitted when a race at the Palace has been paid out, with what the player's bet returned
## (0 for a loser) and which lane won. A gate hangs off this rather than polling the track.
signal race_settled(payout: int, winner: int)
```

the bet's own bookkeeping, beside `_casino_rng`:

```gdscript
## The bet currently on the track: whose race it is, which lane is backed, for how much, and
## the exact field the odds were quoted from. Kept here rather than on the track, because the
## track knows about lanes and this file knows about money.
var _race_entrant: StringName = &""
var _race_lane := -1
var _race_stake := 0
var _race_field: Array[Dictionary] = []
```

Build the track in `_ready()`, immediately after `strip.build()`:

```gdscript
	if race_track != null and race_track.has_method("configure"):
		race_track.call("configure", Callable(terrain, "height_at"))
		race_track.call("build")
		if not race_track.is_connected("race_finished", _on_race_finished):
			race_track.connect("race_finished", _on_race_finished)
```

Add `race_menu` to BOTH the early shutter list in `_ready()` and to `_no_menu_but()`'s list.

Extend `_bind_casino_menus()` with the race panel, at the end of it:

```gdscript
	if race_menu != null and race_menu.has_method("open"):
		race_menu.set("can_open",
			func() -> bool: return _no_menu_but(race_menu) and casino_can_enter())
		race_menu.set("chips_provider", func() -> int: return _current_chips())
		race_menu.set("entrants_provider",
			func() -> Array[Dictionary]: return race_entrants())
		for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed],
				["entrant_chosen", _on_entrant_chosen],
				["race_requested", _on_race_requested]]:
			if not race_menu.is_connected(pair[0], pair[1]):
				race_menu.connect(pair[0], pair[1])
```

and add the racing door to `get_table_menu()`:

```gdscript
		CasinoMenuScript.Game.RACING:
			return race_menu
```

Add the pen lookup and the entrants list, beside `_penned_rows()`:

```gdscript
## The pen holding `uid` and the record in it, as {"pen": Pen, "inst": PonyInstance}, or an
## empty dictionary. One walk over the plots, shared by the Depot's delivery and the track's
## entry, so the two cannot disagree about where a pony lives.
func _penned(uid: StringName) -> Dictionary:
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		var found: PonyInstance = pen.find_pony(uid)
		if found != null:
			return {"pen": pen, "inst": found}
	return {}


## Who the player could enter in a race: everybody standing in a pen. Named and stock alike,
## because a stock pony is an outsider on the card and backing her is the fun bet.
func race_entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for inst: PonyInstance in pen.ponies():
			out.append({"uid": inst.uid, "name": inst.display_name(),
				"happiness": inst.happiness})
	return out


## She picked a pony. Build the card for her and push the six prices back to the panel; the
## panel has no way to price a lane itself, deliberately.
func _on_entrant_chosen(uid: StringName) -> void:
	var found: Dictionary = _penned(uid)
	if found.is_empty() or race_menu == null:
		return
	var field: Array[Dictionary] = RaceCardScript.build_field(
		RaceCardScript.entrant_from(found["inst"] as PonyInstance),
		CompanyRunnersScript.load_shipped())
	var odds: Array[float] = []
	for lane in field.size():
		odds.append(RaceCardScript.decimal_odds(field, lane))
	race_menu.call("set_field", field, odds)
	race_menu.call("set_tab", 1)
```

Add the race itself, beside `play_blackjack()`:

```gdscript
## RUN A RACE. Returns {"ok": bool, "field": Array, "result": Dictionary, "odds": float}.
##
## WHAT DOES NOT HAPPEN HERE, and it is the point of the whole task: the entrant is not taken
## out of her pen, not handed to the track, not adopted by anything and not freed. Her pen
## body is hidden for the length of the race so the world does not show her twice, and
## _on_race_finished() shows it again. The six bodies on the track are RaceRunners, which are
## not ponies at all; see game/world/race_runner.gd.
##
## THE STAKE COMES OUT BEFORE THE FIELD IS DRAWN, the same order every table here uses. The
## seed comes off the casino's own generator, so a gate that called set_casino_seed() gets the
## same race every run and a player gets a different one every time.
func start_race(uid: StringName, lane: int, stake: int) -> Dictionary:
	var refused := {"ok": false, "field": [], "result": {}, "odds": 0.0}
	if _game_state == null or race_track == null or race_track.call("is_running"):
		return refused
	var found: Dictionary = _penned(uid)
	if found.is_empty():
		return refused
	if not _game_state.casino.can_stake(stake):
		return refused
	var inst: PonyInstance = found["inst"]
	var field: Array[Dictionary] = RaceCardScript.build_field(
		RaceCardScript.entrant_from(inst), CompanyRunnersScript.load_shipped())
	if lane < 0 or lane >= field.size():
		return refused
	if not _game_state.casino.remove_chips(stake):
		return refused

	var result: Dictionary = RaceCardScript.run(field, _casino_rng.randi())
	_race_entrant = uid
	_race_lane = lane
	_race_stake = stake
	_race_field = field

	var pen: Pen = found["pen"]
	var body: Node3D = pen.body_for(uid)
	if body != null:
		# HIDDEN, NEVER REMOVED. She is still in the pen's roster, still in the save, and
		# still standing where she was; the player just does not see her in two places.
		body.visible = false

	race_track.call("dress", field)
	race_track.call("start", field, result)
	if race_menu != null and race_menu.has_method("close"):
		race_menu.close()
	_toast("They are under orders at the Spectra Palace!")
	return {"ok": true, "field": field, "result": result,
		"odds": RaceCardScript.decimal_odds(field, lane)}


## The wire. Pay the bet, give the racer back her pen body, and write what running did to her.
func _on_race_finished(_order: Array, winner: int) -> void:
	var won: int = RaceCardScript.payout(_race_field, _race_lane, _race_stake, winner)
	if _game_state != null and won > 0:
		_game_state.casino.add_chips(won)
	var found: Dictionary = _penned(_race_entrant)
	if not found.is_empty():
		var pen: Pen = found["pen"]
		var body: Node3D = pen.body_for(_race_entrant)
		if body != null:
			body.visible = true
		RaceCardScript.apply_race_effects(found["inst"] as PonyInstance)
	var winner_name: String = String(_race_field[winner]["name"]) \
		if winner >= 0 and winner < _race_field.size() else "the field"
	if won > 0:
		_toast("%s takes it. You win %d chips!" % [winner_name, won])
	else:
		_toast("%s takes it. Better luck in the next." % winner_name)
	_refresh_casino_menus()
	race_settled.emit(won, winner)
	_race_entrant = &""
	_race_lane = -1
	_race_stake = 0


func get_race_track() -> Node3D:
	return race_track


func get_race_menu() -> CanvasLayer:
	return race_menu


func _on_race_requested(uid: StringName, lane: int, stake: int) -> void:
	start_race(uid, lane, stake)
```

Extend `_refresh_casino_menus()`'s list with `race_menu`.

- [ ] **Step 8: Run everything**

Run: `bash tools/run_tests.sh`

Expected: green, `Tests` up by 15 from Task 6.

Run: `tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn`

Expected: `RANCH_OK ponies=49 props=60 assets=present`, exit 0. The track and its rails live under `$Strip`, not under `Props` or `Buildings`, so the census does not move; if it did, the `Track` node was parented wrongly.

Run the other gates as in Task 5 Step 10; all exit 0.

- [ ] **Step 9: Commit**

```bash
tools/bin/godot --headless --path game --import
printf 'feat: the track behind the casino; six lanes and a pony you actually own\n\nThe six things running are RaceRunners, not ponies: the same model, the same\ntint, the same gallop clip, and no state machine, no leash and no capture\npath. Nothing in racing creates or frees a Pony. The pony you entered stays in\nher pen for the whole race with her body hidden so the world does not show her\ntwice, and comes back hungrier and happier and otherwise untouched.\n\nThe track has no opinion about who wins: RaceCard hands it a finishing time per\nlane and it advances one clock, so the runner who crosses first is the winner\nthe arithmetic named and a dropped frame cannot settle a bet.\n' > /tmp/casino-commit.txt
git add game/world/race_runner.gd game/world/race_runner.gd.uid game/world/race_track.gd game/world/race_track.gd.uid game/ui/race_menu.gd game/ui/race_menu.gd.uid game/ui/race_menu.tscn game/world/ranch.gd game/world/ranch.tscn game/test/test_race_runner.gd game/test/test_race_menu.gd
git commit -F /tmp/casino-commit.txt
```

---

### Task 8: The casino gate, the docs, and the floor

**Files:**
- Create: `game/scenes/test/casino_test.gd`, `game/scenes/test/casino_test.tscn`
- Modify: `tools/run_tests.sh` (`MIN_TESTS`), `docs/testing.md` (a "The casino gate" section and a Files row)
- Test: the gate is the test

**Interfaces:**
- Consumes: everything. `ranch.gate_report_finished`, `ranch.race_settled`, `ranch.buy_chips()`, `cash_out()`, `play_slots()`, `play_wheel()`, `play_blackjack()`, `start_race()`, `set_casino_seed()`, `casino_can_enter()`, `get_casino_menu()`, `get_table_menu()`, `get_race_track()`, `is_region_open()`, `palace_position()`, `get_economy()`, `_penned()`, `spawner.get_spawned()`, `Pen.add_pony()`, and every pure logic class.
- Produces: `CASINO_OK checks=<n>` on standard output and the verdict as the exit code. Nothing else; a gate is a leaf.

**What this gate proves that the unit suite cannot.** The suite proves each game's arithmetic in milliseconds with a small sample. It cannot see whether `ranch.gd` actually takes the stake before it rolls, whether the cage's two halves really are one for one across a real `Economy` and a real `GameState`, whether a race that plays out on the real track for real seconds settles the bet the card decided, or whether a pony who ran a race is still in her pen afterwards with every other pony on the map untouched. Those are the four things here, plus the spec's own list: each game's odds converging on its published edge over a seeded run of a hundred thousand plays, chips and bits round tripping exactly, and a race's finish order being a function of stats and seed.

**Two halves, and the fast one runs first.** The pure logic half needs no scene and finishes in seconds; it runs before the hosted ranch is asked for anything, so a broken paytable fails here rather than after two and a half seconds of boot. The hosted half then drives the real building.

**The race is watched at ten times speed.** A race is about thirteen seconds of wall clock, and a gate should not spend thirteen seconds standing at a rail. `Engine.time_scale` is raised for the length of the race and put back afterwards, which speeds the track's own `_process` clock and changes nothing about the result: the finish order and the finishing times were decided by `RaceCard.run()` before the first frame.

- [ ] **Step 1: Write the gate scene and script**

`game/scenes/test/casino_test.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/test/casino_test.gd" id="1"]
[ext_resource type="PackedScene" path="res://world/ranch.tscn" id="2"]

[node name="CasinoTest" type="Node"]
script = ExtResource("1")

[node name="Ranch" parent="." instance=ExtResource("2")]
```

`game/scenes/test/casino_test.gd`:

```gdscript
extends Node
## THE CASINO GATE. Proves what game/test/test_slots.gd and its siblings cannot see: whether
## ranch.gd really takes the stake before it rolls, whether the cage is really one for one
## across a real Economy and a real GameState, whether a race that plays out on the real
## track for real seconds settles the bet the card decided, and whether the pony who ran it
## is still standing in her pen afterwards with every other pony on the map untouched.
##
## IT ALSO CARRIES THE SPEC'S OWN THREE CLAIMS for this slice: each game's odds converge on
## its published house edge over a seeded run of a hundred thousand plays, chips and bits
## round trip exactly, and a race's finish order is a function of stats and seed.
##
## TWO HALVES, FAST ONE FIRST. The pure logic half needs no scene and finishes in seconds, so
## a broken paytable fails before the ranch has finished booting. The hosted half then drives
## the real building.
##
## THE RANCH IS HOSTED, not launched, the same way scenes/test/ledger_test.gd's is; see that
## file's class comment for what _hosted changes and why this waits on gate_report_finished
## rather than polling for a symptom of it.
##
## NO PONY IS CAUGHT WITH THE BEAM HERE. The pen resident this gate races is built with
## Pen.add_pony() directly, the way game/test/test_pen.gd and scenes/test/ledger_test.gd build
## one, so the roaming census below has nothing to explain away.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const CasinoScript := preload("res://systems/casino.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const CasinoMenuScript := preload("res://ui/casino_menu.gd")
const RaceTrackScript := preload("res://world/race_track.gd")
const StripScript := preload("res://world/strip.gd")
const EconomyScript := preload("res://systems/economy.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")

## The spec's number: a hundred thousand plays per game.
const PLAYS := 100000

## Chips staked per play while measuring. A hundred, so blackjack's three to two bonus is a
## whole number of chips and racing's rounding is under a tenth of a per cent of the stake.
const STAKE := 100

## How far a measured edge may sit from a published one over PLAYS plays. Wide enough that a
## fair sample never trips it, narrow enough that a paytable typo always does.
const EDGE_TOLERANCE := 0.006

## Seeds, one per game, so a red check names the run that produced it.
const SLOTS_SEED := 20260903
const WHEEL_SEED := 20260904
const BLACKJACK_SEED := 20260905
const RACE_SEED := 20260906
const RANCH_CASINO_SEED := 20260907

## The scratch save slot. Distinct from collection_test.gd's 5, ledger_test.gd's 6 and
## depot_test.gd's, so no two gates ever race for a file.
const SLOT := 8

## How much faster than real time the race is watched. Ten, so a thirteen second race is one
## and a bit; the result was decided before the first frame, so this changes nothing about it.
const RACE_TIME_SCALE := 10.0

## Frames to let the track settle before giving up on a race that never finished.
const RACE_TIMEOUT_SECONDS := 40.0

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


## Record one check's verdict under `label`. Same duplicate label guard as
## scenes/test/collection_test.gd's: a repeated label is a check that never ran, and the
## collision is recorded rather than silently overwriting the first verdict.
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
	GateWatchdogScript.arm(self, "CASINO", 240.0)
	_measure_the_games()
	await _drive_the_palace()
	_finish()


# --- the fast half: does each game pay what its sign says --------------------------------

func _measure_the_games() -> void:
	var rng := RandomNumberGenerator.new()

	rng.seed = SLOTS_SEED
	var returned := 0
	for i in PLAYS:
		returned += SlotsScript.payout(SlotsScript.spin(rng), STAKE)
	var slots_edge: float = 1.0 - float(returned) / float(PLAYS * STAKE)
	print("CASINO slots plays=%d measured=%.4f published=%.4f"
		% [PLAYS, slots_edge, SlotsScript.house_edge()])
	_set_check("the slots converge on their published edge",
		absf(slots_edge - SlotsScript.house_edge()) <= EDGE_TOLERANCE)

	rng.seed = WHEEL_SEED
	returned = 0
	var number_returned := 0
	for i in PLAYS:
		var pocket: int = WheelScript.spin(rng)
		returned += WheelScript.payout(WheelScript.Bet.COLOUR, WheelScript.Colour.BLUE,
			pocket, STAKE)
		number_returned += WheelScript.payout(WheelScript.Bet.NUMBER, 17, pocket, STAKE)
	var colour_edge: float = 1.0 - float(returned) / float(PLAYS * STAKE)
	var number_edge: float = 1.0 - float(number_returned) / float(PLAYS * STAKE)
	print("CASINO wheel plays=%d colour=%.4f number=%.4f published=%.4f"
		% [PLAYS, colour_edge, number_edge, WheelScript.house_edge()])
	_set_check("a colour bet converges on the published edge",
		absf(colour_edge - WheelScript.house_edge()) <= EDGE_TOLERANCE)
	_set_check("a number bet converges on the same published edge",
		absf(number_edge - WheelScript.house_edge()) <= EDGE_TOLERANCE)

	var blackjack_edge: float = BlackjackScript.measure_edge(BLACKJACK_SEED, PLAYS)
	print("CASINO blackjack hands=%d measured=%.4f placard=%.4f"
		% [PLAYS, blackjack_edge, BlackjackScript.house_edge()])
	_set_check("blackjack converges on the edge printed on its placard",
		absf(blackjack_edge - BlackjackScript.house_edge()) <= EDGE_TOLERANCE)

	var field: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"gate#000001", "data_id": &"stock_bold",
		"speed": 5.0, "stamina": 5.0, "spirit": 5.0, "happiness": 0.6, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	returned = 0
	for i in PLAYS:
		var winner: int = int(RaceCardScript.run(field, RACE_SEED + i)["winner"])
		returned += RaceCardScript.payout(field, RaceCardScript.PLAYER_LANE, STAKE, winner)
	var race_edge: float = 1.0 - float(returned) / float(PLAYS * STAKE)
	print("CASINO racing races=%d measured=%.4f published=%.4f"
		% [PLAYS, race_edge, RaceCardScript.TAKEOUT])
	_set_check("racing converges on its published takeout",
		absf(race_edge - RaceCardScript.TAKEOUT) <= EDGE_TOLERANCE)

	# THE FINISH ORDER IS A FUNCTION OF STATS AND SEED, which is the spec's third claim for
	# this gate. Same field and seed, same race; a different happiness, a different rate of
	# winning; and the times always order the lanes the way the result does.
	var same := true
	var ordered := true
	for seed_value in range(500):
		var a: Dictionary = RaceCardScript.run(field, seed_value)
		var b: Dictionary = RaceCardScript.run(field, seed_value)
		if a["order"] != b["order"] or a["times"] != b["times"]:
			same = false
		var order: Array = a["order"]
		var times: Array = a["times"]
		for k in range(1, order.size()):
			if float(times[order[k]]) <= float(times[order[k - 1]]):
				ordered = false
	_set_check("the same field and seed run the same race", same)
	_set_check("the finishing times order the lanes the way the result does", ordered)

	var sad: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"gate#000001", "data_id": &"stock_bold",
		"speed": 6.0, "stamina": 6.0, "spirit": 6.0, "happiness": 0.0, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	var glad: Array[Dictionary] = RaceCardScript.build_field({
		"name": "Bramble", "uid": &"gate#000001", "data_id": &"stock_bold",
		"speed": 6.0, "stamina": 6.0, "spirit": 6.0, "happiness": 1.0, "stock": {},
	}, CompanyRunnersScript.load_shipped())
	var sad_wins := 0
	var glad_wins := 0
	for seed_value in range(4000):
		if int(RaceCardScript.run(sad, seed_value)["winner"]) == RaceCardScript.PLAYER_LANE:
			sad_wins += 1
		if int(RaceCardScript.run(glad, seed_value)["winner"]) == RaceCardScript.PLAYER_LANE:
			glad_wins += 1
	print("CASINO happiness sad_wins=%d glad_wins=%d" % [sad_wins, glad_wins])
	_set_check("a happy pony wins more races than a miserable one", glad_wins > sad_wins)

	# CHIPS AND BITS ROUND TRIP EXACTLY, as arithmetic, before the real cage is asked the
	# same question below.
	var wallet: Economy = EconomyScript.new(5000)
	var purse: Casino = CasinoScript.new()
	var round_trip := true
	for amount in [1, 7, 999, 4000]:
		var before: int = wallet.bits
		if not wallet.spend(amount) or not purse.add_chips(amount):
			round_trip = false
			continue
		if not purse.remove_chips(amount):
			round_trip = false
			continue
		wallet.grant(amount)
		if wallet.bits != before or purse.chips != 0:
			round_trip = false
	_set_check("chips and bits round trip exactly, at every size", round_trip)


# --- the slow half: the real building ------------------------------------------------------

func _drive_the_palace() -> void:
	var ranch := $Ranch as Ranch
	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	# Untyped on purpose, the way collection_test.gd reads it: the autoload's script carries
	# no class_name, so a typed annotation would refuse every property below at parse time.
	var state = get_node("/root/GameState")
	state.reset()
	ranch.rebind_economy()
	ranch.set_casino_seed(RANCH_CASINO_SEED)

	# --- the Strip stands ------------------------------------------------------------------
	var strip_region: RegionData = ranch._regions_registry().by_id(StripScript.REGION_ID)
	_set_check("the Strip is a region on this map", strip_region != null)
	_set_check("the Strip is free", strip_region != null and strip_region.permit_cost == 0)
	_set_check("the Strip is open without a permit", ranch.is_region_open(&"strip"))
	var strip_fenced := false
	for fence in ranch.get_region_fences():
		if fence.region() != null and fence.region().id == &"strip":
			strip_fenced = true
	_set_check("the Strip has no fence, because it has no price", not strip_fenced)
	var strip_node := ranch.get_node_or_null(^"Strip")
	_set_check("the Strip's lamps are standing",
		strip_node != null and int(strip_node.call("light_count")) == StripScript.LIGHT_COUNT)
	_set_check("the marquee names the Palace and its sponsor",
		strip_node != null and String(strip_node.call("marquee_text")).contains(
			"Cloudsdale Weather Corporation"))

	# --- the Palace and its sign -----------------------------------------------------------
	var palace := ranch.get_node_or_null(^"Buildings/Palace") as Node3D
	_set_check("the Spectra Palace is standing", palace != null)
	_set_check("the Palace stands inside the Strip", strip_region != null and palace != null
		and strip_region.contains(Vector2(palace.global_position.x, palace.global_position.z)))
	_set_check("the cage counter is in the lobby",
		ranch.get_node_or_null(^"Buildings/Palace/Cage") != null)
	var lobby_sign := ranch.get_node_or_null(^"Buildings/Palace/Sign") as Label3D
	_set_check("the lobby sign is hanging", lobby_sign != null)
	var sign_text: String = lobby_sign.text if lobby_sign != null else ""
	var publishes_everything := true
	for pair in [["Slots", SlotsScript.house_edge()], ["The Wheel", WheelScript.house_edge()],
			["Blackjack", BlackjackScript.house_edge()], ["Racing", RaceCardScript.TAKEOUT]]:
		if not sign_text.contains(CasinoSignScript.edge_line(String(pair[0]),
				float(pair[1]))):
			publishes_everything = false
			push_error("casino: the lobby sign does not publish %s" % pair[0])
	print("CASINO sign lines=%d" % sign_text.split("\n").size())
	_set_check("the lobby sign publishes every game's real house edge", publishes_everything)
	var sign_clean := true
	for line in sign_text.split("\n"):
		if line.contains("--") or line.contains("—"):
			sign_clean = false
	_set_check("nothing on the sign carries a dash", sign_clean)

	# --- the track -------------------------------------------------------------------------
	var track := ranch.get_race_track()
	_set_check("the track has six lanes",
		track != null and int(track.call("runner_count")) == RaceTrackScript.LANES)
	var track_ok := track != null
	if track != null:
		var gate_point: Vector3 = track.call("lane_point", 0, 0.0)
		var wire_point: Vector3 = track.call("lane_point", 0, 1.0)
		track_ok = absf(Vector2(gate_point.x, gate_point.z).distance_to(
			Vector2(wire_point.x, wire_point.z)) - RaceCardScript.TRACK_LENGTH) < 0.01
	_set_check("the track is exactly as long as the card thinks it is", track_ok)
	var lanes_apart := true
	if track != null:
		for lane in range(1, RaceTrackScript.LANES):
			if absf(float(track.call("lane_z", lane)) - float(track.call("lane_z", lane - 1))
					- RaceTrackScript.LANE_WIDTH) > 0.001:
				lanes_apart = false
	_set_check("the lanes are evenly spaced", lanes_apart)

	# --- the cage, and every way to abuse it ------------------------------------------------
	var wallet: Economy = ranch.get_economy()
	wallet.grant(5000)
	var bits_before: int = wallet.bits
	_set_check("buying more chips than she has bits for buys nothing",
		ranch.buy_chips(bits_before + 1) <= bits_before)
	wallet.grant(1)
	var refused_zero: bool = ranch.buy_chips(0) == 0
	var refused_negative: bool = ranch.buy_chips(-500) == 0
	_set_check("a buy in of zero buys nothing", refused_zero)
	_set_check("a buy in of a negative number buys nothing", refused_negative)
	_set_check("neither refusal moved a chip", state.casino.chips >= 0)

	state.casino.remove_chips(state.casino.chips)
	wallet.grant(maxi(0, 5000 - wallet.bits))
	var start_bits: int = wallet.bits
	var bought: int = ranch.buy_chips(1000)
	_set_check("a thousand bits buy a thousand chips",
		bought == 1000 and state.casino.chips == 1000 and wallet.bits == start_bits - 1000)
	var cashed: int = ranch.cash_out(1000)
	_set_check("a thousand chips cash out for a thousand bits",
		cashed == 1000 and state.casino.chips == 0 and wallet.bits == start_bits)
	_set_check("cashing out more chips than she holds cashes out nothing",
		ranch.cash_out(50) == 0 and wallet.bits == start_bits)
	_set_check("cashing out a negative number cashes out nothing",
		ranch.cash_out(-50) == 0 and wallet.bits == start_bits)

	# --- the tables --------------------------------------------------------------------------
	ranch.buy_chips(3000)
	var chips_before: int = state.casino.chips
	var over: Dictionary = ranch.play_slots(chips_before + 1)
	_set_check("a stake bigger than the purse is refused, and the purse does not move",
		not bool(over["ok"]) and state.casino.chips == chips_before)
	_set_check("a stake of zero is refused", not bool(ranch.play_slots(0)["ok"]))
	_set_check("a negative stake is refused", not bool(ranch.play_slots(-200)["ok"]))
	_set_check("no refusal moved a chip", state.casino.chips == chips_before)

	var settled := true
	for i in 40:
		var before: int = state.casino.chips
		var spin: Dictionary = ranch.play_slots(50)
		if not bool(spin["ok"]) or state.casino.chips != before - 50 + int(spin["won"]):
			settled = false
	_set_check("every spin settles at exactly the stake out and the win in", settled)

	settled = true
	for i in 40:
		var before: int = state.casino.chips
		var bet: Dictionary = ranch.play_wheel(WheelScript.Bet.COLOUR, WheelScript.Colour.RED,
			50)
		if not bool(bet["ok"]) or state.casino.chips != before - 50 + int(bet["won"]):
			settled = false
	_set_check("every wheel bet settles at exactly the stake out and the win in", settled)

	settled = true
	for i in 40:
		var before: int = state.casino.chips
		var hand: Dictionary = ranch.play_blackjack(50)
		if not bool(hand["ok"]) or state.casino.chips != before - 50 + int(hand["won"]):
			settled = false
	_set_check("every hand settles at exactly the stake out and the win in", settled)

	# --- a bet abandoned in the middle of being placed ----------------------------------------
	var table: CanvasLayer = ranch.get_table_menu(CasinoMenuScript.Game.SLOTS)
	var before_cancel: int = state.casino.chips
	_set_check("a table opens at the Palace", table != null and table.call("open"))
	if table != null:
		table.call("move_selection", 1)
		table.call("close")
	_set_check("walking away mid bet costs nothing", state.casino.chips == before_cancel)

	# --- the door, and the seam the ban will hang on -------------------------------------------
	_set_check("the Palace is open to her in this slice", ranch.casino_can_enter())
	var lobby: CanvasLayer = ranch.get_casino_menu()
	var pause: CanvasLayer = ranch.get_pause_menu()
	var refused_over_pause := false
	if lobby != null and pause != null:
		pause.call("open")
		refused_over_pause = not bool(lobby.call("open"))
		pause.call("close")
	_set_check("the lobby refuses to open over another menu, so its can_open is consulted",
		refused_over_pause)

	# --- the race, on the real track ------------------------------------------------------------
	var census_before: int = ranch.spawner.get_spawned().size()
	var bodies: Array[WeakRef] = []
	for body in ranch.spawner.get_spawned():
		bodies.append(weakref(body))

	# THE PEN IS FOUND THE WAY ledger_test.gd FINDS ONE: the first plot in the catalogue that
	# costs nothing, rather than by an id. There is no plot whose id is "pen"; the shipped
	# catalogue is pen_small, pen_large and pen_grand (game/data/plots/), and hard coding one
	# of those names here would be a gate that breaks the day somebody renames a plot.
	var slots: Array[PlotSlot] = ranch.plot_slots()
	var free_plot: PlotData = null
	for plot: PlotData in ranch.plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	var built: bool = not slots.is_empty() and free_plot != null and slots[0].is_empty() \
		and slots[0].build(free_plot)
	_set_check("a pen is standing to enter a pony from", built)
	var pen: Pen = slots[0].get_built() as Pen if not slots.is_empty() else null
	var racer: PonyInstance = PonyInstanceScript.create(&"stock_bold")
	racer.stock = {"coat": 1, "mane": 2, "eyes": 0}
	racer.happiness = 0.40
	racer.hunger = 0.10
	_set_check("she is in the pen", pen != null and pen.add_pony(racer))
	state.add_pony(racer)

	var entrants: Array[Dictionary] = ranch.race_entrants()
	var listed := false
	for entry in entrants:
		if StringName(entry["uid"]) == racer.uid:
			listed = true
	_set_check("the race panel lists her as an entrant", listed)

	var chips_at_the_off: int = state.casino.chips
	var race: Dictionary = ranch.start_race(racer.uid, RaceCardScript.PLAYER_LANE, 100)
	_set_check("the race is under orders", bool(race["ok"]))
	_set_check("the stake left the purse before the field was drawn",
		state.casino.chips == chips_at_the_off - 100)
	_set_check("she is still in her pen while the race runs",
		pen != null and pen.find_pony(racer.uid) != null)
	var pen_body: Node3D = pen.body_for(racer.uid) if pen != null else null
	_set_check("her pen body is hidden rather than removed",
		pen_body != null and is_instance_valid(pen_body) and not pen_body.visible)

	Engine.time_scale = RACE_TIME_SCALE
	var settled_payout := -1
	var settled_winner := -1
	var watcher := func(payout: int, winner: int) -> void:
		settled_payout = payout
		settled_winner = winner
	ranch.race_settled.connect(watcher)
	var waited := 0.0
	while settled_payout < 0 and waited < RACE_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Engine.time_scale = 1.0
	ranch.race_settled.disconnect(watcher)

	_set_check("the race finished and paid out", settled_payout >= 0)
	var result: Dictionary = race.get("result", {})
	_set_check("the lane that won is the lane the card said would win",
		settled_winner == int(result.get("winner", -2)))
	var expected_payout: int = RaceCardScript.payout(race["field"],
		RaceCardScript.PLAYER_LANE, 100, settled_winner)
	_set_check("the bet paid exactly what the shown odds promised",
		settled_payout == expected_payout)
	_set_check("the purse moved by exactly the stake out and the win in",
		state.casino.chips == chips_at_the_off - 100 + expected_payout)

	_set_check("she came home to the same pen",
		pen != null and pen.find_pony(racer.uid) != null)
	_set_check("her body is visible again",
		pen_body != null and is_instance_valid(pen_body) and pen_body.visible)
	_set_check("she came home hungrier by exactly what a race costs",
		absf(racer.hunger - (0.10 + RaceCardScript.RACE_HUNGER)) < 0.0001)
	_set_check("and happier by exactly what a race is worth",
		absf(racer.happiness - (0.40 + RaceCardScript.RACE_HAPPINESS)) < 0.0001)
	_set_check("the ranch still owns her", state.find_pony(racer.uid) != null)

	var census_after: int = ranch.spawner.get_spawned().size()
	print("CASINO census before=%d after=%d" % [census_before, census_after])
	_set_check("the wild herd is exactly the size it was before the race",
		census_after == census_before)
	var all_alive := true
	for ref in bodies:
		if ref.get_ref() == null:
			all_alive = false
	_set_check("not one pony anywhere in the world was freed by a race", all_alive)

	# --- the chips survive quitting ------------------------------------------------------------
	var chips_at_save: int = state.casino.chips
	_set_check("the ranch saved", state.save_to_slot(SLOT))
	state.reset()
	_set_check("a reset empties the purse", state.casino.chips == 0)
	_set_check("the save came back", state.load_from_slot(SLOT))
	_set_check("and the chips came back with it", state.casino.chips == chips_at_save)


func _finish() -> void:
	var failed: Array[String] = []
	for label in _checks:
		if not bool(_checks[label]):
			failed.append(String(label))
	for label in _duplicates:
		failed.append("duplicate check label: %s" % label)
	for label in _checks:
		print("CASINO %s %s" % ["ok  " if bool(_checks[label]) else "FAIL", label])
	var all_ok: bool = failed.is_empty()
	# Marker after the verdict, exit code IS the verdict. See docs/testing.md.
	if all_ok:
		print("CASINO_OK checks=%d" % _checks.size())
	else:
		print("CASINO_FAILED checks=%d failed=%d" % [_checks.size(), failed.size()])
	get_tree().quit(0 if all_ok else 1)
```

- [ ] **Step 2: Run the gate and iterate until every label passes honestly**

Run: `tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn; echo "exit $?"`

Expected: a `CASINO slots ...`, `CASINO wheel ...`, `CASINO blackjack ...` and `CASINO racing ...` line, a `CASINO census before=N after=N` line with the two numbers equal, then one `CASINO ok` line per check, then `CASINO_OK checks=<n>` and exit 0.

If a convergence check fails, read the printed `measured=` against `published=` before changing anything: a measured edge that is close but outside `EDGE_TOLERANCE` is a sample size question, and a measured edge that is nowhere near is a paytable or a settle bug. Never widen `EDGE_TOLERANCE` to make a red check green; that constant is the whole reason the gate has teeth.

If "not one pony anywhere in the world was freed by a race" fails, something in racing is holding a `Pony`. That is the slice's hardest rule and the check exists precisely because it is the one a refactor would break quietly.

- [ ] **Step 3: Run every gate and the whole suite one more time**

```bash
for scene in market_test region_test world_test collection_test ledger_test depot_test creation_test casino_test; do
  tools/bin/godot --headless --audio-driver Dummy --path game "scenes/test/$scene.tscn" >/dev/null 2>&1
  echo "$scene exit $?"
done
tools/bin/godot --headless --audio-driver Dummy --path game world/ranch.tscn 2>&1 | tail -3
bash tools/run_tests.sh
```

Expected: every gate exits 0; the ranch prints `RANCH_OK ponies=49 props=60 assets=present`; the suite is green.

- [ ] **Step 4: Raise the floor**

`MIN_TESTS` in `tools/run_tests.sh` stands at 812, which is also the exact number of `func test_` in `game/test/` at the base of this slice, so the floor and the suite are in step and must stay so. This plan adds roughly 130 tests across twelve new test files plus three edits to existing ones, so expect a number near 940. Do not guess it; read the `Tests` line from the run above.

```bash
tests=$(bash tools/run_tests.sh 2>&1 | grep -oP '^Tests\s+\K[0-9]+' | tail -1)
echo "suite reports $tests"
sed -i "s/MIN_TESTS=\"\${FILLY_MIN_TESTS:-812}\"/MIN_TESTS=\"\${FILLY_MIN_TESTS:-$tests}\"/" tools/run_tests.sh
grep -n 'MIN_TESTS=' tools/run_tests.sh
```

Then prove the floor still bites:

```bash
FILLY_MIN_TESTS=99999 bash tools/run_tests.sh; echo "expected 1, got $?"
```

- [ ] **Step 5: Document the gate**

Add a row to `docs/testing.md`'s Files table, in the style of the rows around it and with no dash in it:

```
| `game/scenes/test/casino_test.gd` | The casino gate (see below) |
```

Add a section after "The creation gate", in the voice of "The ledger gate" and "The depot gate":

```markdown
## The casino gate

`scenes/test/casino_test.tscn` proves what `game/test/test_slots.gd` and its
four siblings cannot see: whether `ranch.gd` really takes the stake before it
rolls, whether the cage is really one for one across a live `Economy` and a
live `GameState`, whether a race that plays out on the real track for real
seconds settles the bet the card decided, and whether the pony who ran it is
standing in her pen afterwards with every other pony on the map untouched.

It runs in two halves and the fast one goes first. The pure logic half needs no
scene: a hundred thousand seeded plays of each of the four games, measured
against the number that game publishes, plus a chips and bits round trip at
four sizes, plus the claim that a race's finish order is a function of the
field and the seed and of nothing else. A broken paytable therefore fails
before the ranch has finished booting.

The hosted half then drives the real building: the Strip standing as a free,
unfenced, open region; the Spectra Palace with its cage counter and a lobby
sign that carries every game's real edge; a six lane track exactly as long as
`RaceCard.TRACK_LENGTH` believes it is; the cage refusing an overpay, a zero
and a negative in both directions; forty spins, forty wheel bets and forty
hands each settling at exactly the stake out and the win in; a bet abandoned
halfway costing nothing; and one whole race with one of the player's own
ponies in it.

Three things about how it reads are worth knowing before editing it.

**It never widens a tolerance to go green.** `EDGE_TOLERANCE` is 0.006 over a
hundred thousand plays, which a fair sample never trips and a paytable typo
always does. A convergence check that fails is a question about the paytable
or about the settle, never about the constant.

**Its racer is built with `Pen.add_pony()`**, the way `scenes/test/ledger_test.gd`
builds its pen resident and for the same reason: this gate is about money and
about a pony coming home, not about capture, so the roaming census it asserts
on has nothing to explain away. `scenes/test/depot_test.gd` is where a pony is
actually caught with the beam.

**It holds a `WeakRef` to every body in the world across the race.** The
slice's hardest rule is that racing never frees a pony, and the six things
running down the track are `RaceRunner` nodes rather than `Pony` nodes
precisely because of it. A refactor that quietly turned a runner back into a
pony would pass every other check in this file; that one would not.

The race is watched at ten times speed (`Engine.time_scale`, restored
afterwards). The result was decided by `RaceCard.run()` before the first frame,
so the clock changes nothing about it.

Run it with:

```
tools/bin/godot --headless --audio-driver Dummy --path game scenes/test/casino_test.tscn
```

Expect `CASINO_OK checks=<n>`; the exit code is the verdict.
```

(Replace `<n>` with the number the gate actually prints.)

- [ ] **Step 6: Commit**

```bash
printf 'test: the casino gate, and the floor that keeps it\n\nA hundred thousand seeded plays of each of the four games, measured against\nthe number that game publishes, then the real building driven end to end: the\ncage refusing an overpay, a zero and a negative in both directions; a hundred\nand twenty bets settling at exactly the stake out and the win in; a bet\nabandoned halfway costing nothing; and one whole race with one of the player s\nown ponies in it, after which she is in the same pen, visible again, hungrier\nby exactly RACE_HUNGER and happier by exactly RACE_HAPPINESS, and every other\nbody in the world is still alive behind a WeakRef.\n\nMIN_TESTS raised to the suite s reported count.\n' > /tmp/casino-commit.txt
git add game/scenes/test/casino_test.gd game/scenes/test/casino_test.gd.uid game/scenes/test/casino_test.tscn tools/run_tests.sh docs/testing.md
git commit -F /tmp/casino-commit.txt
```
