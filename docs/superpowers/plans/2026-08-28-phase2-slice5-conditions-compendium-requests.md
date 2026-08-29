# Phase 2 Slice 5: Conditions, Compendium and Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The payoff of the arc: ponies that only appear at certain hours and in certain weather, a compendium that turns 43 characters into a collection with a shape, and a request board that points the player at the parts of it she would otherwise skip.

**Architecture:** Three pure-logic systems and their data, then the wiring. `PonyData` gains `phases` and `weathers` (empty means any); the `Spawner` gains `refresh(state)` that despawns wild ponies whose conditions no longer hold (they walk away and vanish out of sight; they were never owned) and draws replacements from the pool that matches now, deterministically per phase. `Compendium` (RefCounted) holds one of UNSEEN, SEEN, CAUGHT per character and answers counts per region; a pony marks herself seen the first time she notices the player, and the beam's `captured` marks caught. `RequestBoard` (RefCounted) holds three active requests filled from templates, with the first three on a new save fixed as the tutorial; it consumes game events (caught, penned, sold, seen) and pays out. Both are saved (format version 4). The pause menu gains COMPENDIUM and REQUESTS pages; a board building on the ranch opens the requests page directly. A hosted gate walks the whole thing.

**Tech Stack:** Godot 4.5.2, GDScript, GUT, the project's gate conventions.

**Spec:** `docs/superpowers/specs/2026-08-28-phase2-bigger-world-design.md`, sections "Spawn conditions", "The Compendium", "Requests", "Pause menu", "Data model changes", build order item 5.

## Global Constraints

- No em dash (U+2014) and no double hyphen (` -- `) in anything a player can read (compendium rows, request text, toasts, page titles) or in new code, comments, docs, or data.
- `NO PONY EVER DIES`: a wild pony leaving on a condition change is despawned only while she is out of the player's sight (further than `Pony.DETECTION_RADIUS + SHY_NOTICE_BONUS` from the player) or after she has walked away for `LEAVE_SECONDS`; a held, penned or bagged pony is never touched. Owned `PonyInstance`s are never removed by anything in this slice.
- Determinism: `Spawner.refresh()` draws with an RNG seeded from `world_seed`, the cycle index and the phase, so the same save at the same hour spawns the same ponies.
- Menus draw and emit; `ranch.gd` transacts and pays.
- Save: `compendium: Dictionary` (data_id to state int) and `requests: Array` (each request as a dict) under keys `"compendium"` and `"requests"`; `SaveIO.FORMAT_VERSION` becomes 4; `migrate()` adds an empty compendium (then `ranch.gd` marks every owned pony as CAUGHT on load, so a Phase 1 save's ponies count) and the tutorial requests.
- The compendium is per save (a traded pony counts as caught for her new owner).
- Gates: hosted ranch mode; markers after verdicts; exit code is the verdict. The world can be pinned with `--phase=`/`--weather=` (slice 4) for renders.
- Branch: `phase2-slice5-collection`. Commit after every task.

---

## The conditions

Roughly a third of the roster becomes conditional; the rest stays "any". Phases use `WorldState.Phase` ints (DAWN 0, DAY 1, DUSK 2, NIGHT 3); weathers use `WorldState.Weather` ints (CLEAR 0, RAIN 1, FOG 2, STORM 3). Empty arrays mean any.

| id | phases | weathers | why |
|---|---|---|---|
| sunsetshimmer (LEGENDARY, everfree) | [DUSK] | [CLEAR] | the sunset pony, at sunset |
| trixie (LEGENDARY, everfree) | [NIGHT] | [] | shows are at night |
| shiningarmor (LEGENDARY, nightmeadow) | [NIGHT] | [CLEAR] | a guard on a clear night |
| pinkamena (RARE, everfree) | [NIGHT, DUSK] | [RAIN, STORM] | she only comes out in bad weather |
| maudpie (RARE, nightmeadow) | [] | [FOG, RAIN] | rocks are best in the wet |
| spitfire (RARE, lake) | [DAY] | [CLEAR] | the Wonderbolts fly in good weather |
| soarin (UNCOMMON, lake) | [DAY, DAWN] | [CLEAR] | as above |
| lightningdust (UNCOMMON, everfree) | [] | [STORM] | she chases lightning |
| octavia (UNCOMMON, nightmeadow) | [DUSK, NIGHT] | [] | the concert is at dusk |
| vinylscratch (UNCOMMON, nightmeadow) | [NIGHT] | [] | the party is at night |
| nightlight (COMMON, nightmeadow) | [NIGHT] | [] | it is in the name |
| marblepie (UNCOMMON, nightmeadow) | [DAWN, DUSK] | [] | too shy for daylight |
| cocopommel (UNCOMMON, nightmeadow) | [DAY] | [] | a working day |
| flitter (COMMON, lake) | [] | [CLEAR, RAIN] | |
| cloudchaser (COMMON, lake) | [] | [CLEAR, FOG] | |
| milkyway (COMMON, lake) | [NIGHT, DAWN] | [] | the milking hours |
| carrottop (COMMON, orchard) | [DAWN, DAY] | [] | the harvest |
| kerfuffle (COMMON, everfree) | [] | [FOG] | |

Everyone else: `[]`, `[]`. Every region keeps at least three unconditional residents, so a marker never has an empty pool. The night meadow at DAY draws from cocopommel, mane_allgood, limestonepie and shiningarmor (no: he is NIGHT), so cocopommel, mane_allgood, limestonepie: three. The everfree edge at DAY CLEAR draws from drwhooves, trixie (no: NIGHT), pinkamena (no), sunsetshimmer (no), lightningdust (no: STORM), kerfuffle (no: FOG): only drwhooves, which is one, so move `kerfuffle` to `[]`/`[]` and keep `lightningdust` STORM only: drwhooves and kerfuffle are two; add `applebloom`'s cousin? No: re-zone `pokeypierce` (COMMON, ranch) to `everfree` unconditional. The everfree edge then has drwhooves, kerfuffle, pokeypierce always, plus four conditional. The ranch keeps 12.

`test_roster_data.gd` gains a test that, for every region zone and every (phase, weather) pair, at least two characters match; that is the invariant behind the table above, and it fails loudly if a future author conditions a region into emptiness.

---

### Task 1: Conditions on the data, and the spawner that honours them

**Files:**
- Modify: `game/systems/pony_data.gd` (two exports), `game/data/ponies/*.tres` (the 18 conditional characters; `pokeypierce` re-zoned), `game/world/spawner.gd` (`refresh`, `matches`, despawn), `game/actors/pony/pony.gd` (`leave()`), `game/systems/spawn_table.gd` only if `draw()` needs a filtered pool (it takes the pool as an argument already, so no)
- Test: `game/test/test_roster_data.gd`, `game/test/test_spawner.gd` (create), `game/test/test_pony.gd`

**Interfaces:**
- `PonyData.phases: Array[int]`, `PonyData.weathers: Array[int]`; `PonyData.available(phase: int, weather: int) -> bool` (empty means any).
- `Spawner.refresh(phase: int, weather: int, player_position: Vector3) -> Dictionary` returning `{"left": n, "arrived": n}`; internally: for each spawned pony whose `get_data().available(phase, weather)` is false, call `pony.leave()`; then for each marker with fewer than `spawn_count` live-and-staying ponies, draw from `entries.filter(available)` with an RNG seeded `spawn_seed + cycle * 4 + phase` (pass `cycle` too: signature `refresh(phase, weather, cycle, player_position)`), spawn as `populate()` does. A pony who is leaving does not count toward the marker's live count. `Spawner.get_spawned()` already prunes freed ponies.
- `Pony.leave()`: enters a new `State.LEAVING`: walks directly away from the player (or from her home if no player) at wander speed, ignores the leash, and `queue_free()`s when she is further than `LEAVE_DISTANCE := 16.0` from the player or after `LEAVE_SECONDS := 20.0`; refuses while `HELD` (the beam owns her) and, if captured while leaving, the capture wins (`captured` fires as usual; the leave is cancelled by the capture path freeing her). `is_leaving() -> bool`. `NO PONY EVER DIES` note in the doc: only wild, unowned bodies ever leave; owned records live in `GameState.ponies`, pens and the bag, none of which this touches.

- [ ] **Step 1: Tests.** `test_roster_data.gd`: `test_every_region_has_at_least_two_residents_for_every_hour_and_weather` (loop zones x phases x weathers; count `available`); `test_conditional_characters_use_valid_phase_and_weather_values` (every int within the enums). `test_pony.gd`: `available()` truth table (empty means any; a listed phase with an unlisted weather is false). `test_spawner.gd` (new; build a `Spawner` with two `ZoneMarker`s over a floor in a test world, a registry from a fixture dir under `game/test/fixtures/ponies_conditional/` with four characters: two unconditional, one NIGHT-only, one STORM-only, all pointing at a real glb such as `twilight.glb`): `populate()` at DAY/CLEAR never spawns the NIGHT-only one; `refresh(NIGHT, CLEAR, 0, far_away)` marks the DAY-only ones leaving and spawns the NIGHT-only one; a leaving pony far from the player is freed within `LEAVE_SECONDS` (advance physics frames); `refresh` with the same arguments twice is idempotent; the draw is deterministic for the same `(seed, cycle, phase)`. `test_pony.gd`: `leave()` is refused while HELD (call `leave()` after the beam's hold path sets HELD; read how test_magic_beam or test_pony sets HELD) and `is_leaving()` reads back.
- [ ] **Step 2:** run, expect failures. **Step 3:** implement; author the 18 `.tres` and the `pokeypierce` re-zone. **Step 4:** the direct ranch scene (`RANCH_OK`, and the seed comment in `spawner.gd` must still be true: the boot draw at DAWN/CLEAR may change because conditional ponies drop out of the pool; if it does, re-run the seed search from slice 3's report with the DAWN/CLEAR pools and update the comment and `DEFAULT_WORLD_SEED`), `wild_ponies` (it draws its own herd; its fixture is the `ranch` pool, all unconditional), the suite. **Step 5: Commit** `feat: ponies that keep hours; the spawner refreshes with the sky`.

---

### Task 2: Compendium, and save format version 4

**Files:**
- Create: `game/systems/compendium.gd`
- Modify: `game/systems/game_state.gd`, `game/systems/save_io.gd`
- Test: `game/test/test_compendium.gd`, `game/test/test_game_state.gd`, `game/test/test_save_io.gd`

**Interfaces:**
- `class_name Compendium extends RefCounted`; `enum State { UNSEEN, SEEN, CAUGHT }`; `signal changed(data_id: StringName, state: int)`; `state_of(id) -> int`; `mark_seen(id) -> bool` (true if it changed; never downgrades); `mark_caught(id) -> bool`; `count(state: int, registry: PonyRegistry) -> int`; `count_in_zone(zone: StringName, state: int, registry: PonyRegistry) -> int`; `total(registry) -> int`; `to_dict() -> Dictionary` (String keys, int values, UNSEEN entries omitted); `static from_dict(d) -> Compendium` (drops junk).
- `GameState.compendium: Compendium` (replaced on load like `gems`), `GameState.requests: Array` (plain dicts; Task 3 defines their shape), keys `"compendium"` and `"requests"`; `FORMAT_VERSION := 4`; `migrate()` adds `compendium: {}` and `requests: []` when absent.

- [ ] **Step 1: Tests** (the compendium's transitions and monotonicity; counts against the real registry for a hand-marked set; round trip; junk dropped; game_state round trip and defaults; save_io pin 4, migrate adds both, a composed v3-file test mirroring the v1/v2 ones). **Step 2:** run. **Step 3:** implement. **Step 4:** run the files plus the market and region gates. **Step 5: Commit** `feat: the Compendium; save format version 4`.

---

### Task 3: RequestBoard

**Files:**
- Create: `game/systems/request_board.gd`
- Test: `game/test/test_request_board.gd`

**Interfaces:**
- `class_name RequestBoard extends RefCounted`; `enum Kind { CATCH_ANY, PEN_ANY, SELL_ANY, BRING_PERSONALITY_FROM_ZONE, SELL_GEMS_OF_RARITY, SEE_CHARACTER }`; `const ACTIVE := 3`; a request is a Dictionary `{ "id": String, "kind": int, "personality": int, "zone": String, "rarity": int, "count": int, "progress": int, "character": String, "reward_bits": int, "reward_food": String, "done": bool, "text": String }`.
- `_init(seed: int, registry: PonyRegistry, regions: Array[StringName])`; `requests() -> Array` (copies); `active() -> Array` (not done); `seed_tutorial() -> void` (CATCH_ANY 1, PEN_ANY 1, SELL_ANY 1 with rewards 20, 30, 50 bits, in that order, texts "Catch a pony with your magic beam.", "Move a pony into a pen.", "Sell a gem at the market."); `fill() -> void` (draws new requests from templates until `ACTIVE` are active, deterministic from the seed and a draw counter); `on_caught(data: PonyData, zone: StringName)`, `on_penned(data: PonyData)`, `on_sold(rarity: int, count: int)`, `on_seen(data: PonyData)`; each returns an Array of requests completed by that event (the caller pays); `claim(id) -> Dictionary` marks paid; `to_array() / static from_array(a, registry, regions)`.
- Templates: `BRING_PERSONALITY_FROM_ZONE` ("Bring a %s pony from %s." with `PonyData.Personality` names in lower case and the region's display name; reward 80 bits), `SELL_GEMS_OF_RARITY` ("Sell %d %s gems." count 3 to 6, rarity weighted toward COMMON/UNCOMMON; reward 15 bits per gem above their sale value), `SEE_CHARACTER` ("Find %s and get a good look at her." a character not yet seen; reward 40 bits plus 2 `hay`). Text carries no dashes.

- [ ] **Step 1: Tests** (tutorial order and texts; `fill` reaches three and is deterministic; each `on_*` completes the matching request and not others; `SELL_GEMS_OF_RARITY` accumulates progress across sales; `claim` pays once; round trip through `to_array`/`from_array`; a request naming a character the registry lacks is dropped on load, not crashed). **Step 2:** run. **Step 3:** implement. **Step 4:** run. **Step 5: Commit** `feat: RequestBoard, three requests at a time, the first three a tutorial`.

---

### Task 4: Ranch wiring: seen and caught, refresh with the sky, the board, the payouts

**Files:**
- Modify: `game/world/ranch.gd`, `game/world/ranch.tscn` (a `Board` building near the market, small: width 3.0, depth 1.2, wall_height 2.4, ridge 3.0, door_width 0.0 if `Building` allows, else a plain `MeshInstance3D` sign built in code), `game/actors/pony/pony.gd` (`signal noticed_player()` emitted once per body the first time `_sees_player()` is true), `game/ui/hud.gd` (nothing new; toasts)
- Test: `game/test/test_pony.gd` (the signal fires once)

**Interfaces:**
- On `world_state.phase_changed` / `weather_changed`: `spawner.refresh(phase, weather, cycle, player.global_position)`; toast `"%d ponies wandered off, %d arrived." % [left, arrived]` only when either is non-zero.
- Every spawned pony (at populate and at refresh) has `noticed_player` connected to `_on_pony_noticed(data)` which calls `compendium.mark_seen(data.id)` and `board.on_seen(data)`; the beam's `captured(instance)` calls `compendium.mark_caught(instance.data_id)` and `board.on_caught(data, zone)` (zone = the region the player stands in, via `RegionRegistry.region_at`, else `ranch`); `_move_pony_into_pen` success calls `board.on_penned`; `_on_sell_requested/_on_sell_all_requested` call `board.on_sold(rarity, count)` per rarity sold.
- Completed requests: toast `"Request done: %s (+%d bits)"`, `economy` gains the bits (through `Economy.sell`? No: add `Economy.grant(bits: int)` with a test: positive only, emits `bits_changed`), inventory gains the food, `board.claim(id)`, then `board.fill()`.
- On load (`rebind_economy()`'s hook): rebuild `_board` from `GameState.requests`; if the array is empty, `seed_tutorial()` then `fill()`; mark every owned pony CAUGHT in the compendium (`GameState.ponies` plus pens plus bag).
- The board building: `"Press E / X to read the board."` prompt once per approach; interact opens the pause menu on the REQUESTS page (`pause_menu.open_page(PauseMenu.Page.REQUESTS)`, Task 5).
- `_report()` gains: `"the compendium exists"`, `"every owned pony is caught in the compendium"`, `"three requests are active on a fresh state"`, `"the board stands"`; prints `RANCH collection seen=%d caught=%d of %d requests=%d`.

- [ ] Steps as usual; the direct ranch scene, the eleven gates and the suite green. **Commit** `feat: seen and caught are recorded, the sky refreshes the herd, and the board pays out`.

---

### Task 5: The Compendium and Requests pages

**Files:**
- Modify: `game/ui/pause_menu.gd`, `game/ui/pause_menu.tscn`
- Test: `game/test/test_pause_menu.gd`

**Interfaces:**
- `Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS }`; `Row { RESUME, COMPENDIUM, REQUESTS, SAVE, SETTINGS, QUIT }` (rows reordered so the two new pages sit under Resume); `MAIN_ROWS` follows; `open_page(page: int) -> bool` (opens if allowed and jumps to the page); `var compendium: Compendium`, `var registry: PonyRegistry`, `var regions: RegionRegistry`, `var board: RequestBoard`, `var world_state: WorldState` (for showing which conditions hold now), all injected by `ranch.gd`.
- COMPENDIUM page: header `"%d of %d caught, %d seen"`; then one row per region (ranch first) with `"%s: %d of %d"`; then the character list in registry order, a window of `PAGE_ROWS := 10` rows scrolled by `ui_up`/`ui_down` with wrap, each row `"???"` for UNSEEN (rarity colour only), the display name for SEEN, and the display name plus `"  when: %s, %s"` for CAUGHT (phase names joined by "/", or "any"; weather names joined by "/", or "any"). `ui_left`/`ui_right` do nothing here; `ui_cancel` back to MAIN.
- REQUESTS page: one row per active request with its text and `"%d / %d"` progress where `count > 1`, and the reward; a footer `"Finish one to get a new one."`. `ui_cancel` back.
- Tests: `open_page(COMPENDIUM)` lands on it; the header counts match a hand-marked compendium against the real registry; scrolling wraps over 43 rows; an UNSEEN row reads `???` and a CAUGHT row shows its conditions; the REQUESTS page lists exactly `board.active()`; `back()` returns to MAIN with the right row selected.

- [ ] Steps as usual. **Commit** `feat: the Compendium and Requests pages`.

---

### Task 6: The collection gate, docs, the floor

**Files:**
- Create: `game/scenes/test/collection_test.gd`, `.tscn` (hosted ranch)
- Modify: `tools/run_tests.sh`, `docs/testing.md`, `docs/pipeline.md` (the roster subsection gains the conditions table)

Gate checks: the ranch is hosted and its report passed; at boot (DAWN, CLEAR) no NIGHT-only character is spawned; `ranch.advance_world(...)` to NIGHT then `refresh` (through the ranch's signal path): at least one NIGHT-only character arrived and every DAY-only one is leaving or gone; a leaving pony far from the player is gone within `LEAVE_SECONDS`; the compendium marks a spawned pony SEEN when the player stands within her notice radius (teleport the player next to her and wait frames); catching her (drive the beam as `market_test` does not; instead call the same path `capture_test` uses to hold and secure a pony, or, if that is too entangled, `compendium.mark_caught` through the beam's `captured` signal emitted by a real capture in the gate; read `capture_test.gd` for the minimal capture sequence) marks CAUGHT and completes the tutorial's first request with 20 bits paid; penning her completes the second; selling a gem completes the third; three new requests are then active; the compendium page header reads the counts; save, reset, rebind, load: compendium and requests come back; `WORLD`/`REGION`/`MARKET` gates still green. Marker `COLLECTION_OK checks=N`.

- [ ] Steps as usual; set `MIN_TESTS`; docs. **Commit** `test: the collection gate`.

---

## Self-review

**Spec coverage.** Spawn conditions and re-evaluation on `WorldState` change: Task 1 and 4. Compendium states, triggers, per-region counts, page: Tasks 2, 4, 5. Requests: templates, three active, tutorial, payouts, board, page: Tasks 3, 4, 5. Save keys and version 4 with migration and "owned counts as caught": Task 2 and 4. Testing: pure-logic tests per system, a hosted gate, round trips: all tasks and Task 6.

**Placeholder scan.** The one deliberate openness is the capture sequence inside the gate (Task 6 names two routes and where to read for each). Everything else is named.

**Type consistency.** `PonyData.available(phase, weather)` used by the spawner and the roster test; `Spawner.refresh(phase, weather, cycle, player_position)` used by Task 4; `Compendium` and `RequestBoard` APIs used by Tasks 4, 5, 6 as defined in Tasks 2 and 3; `PauseMenu.open_page` used by Task 4 as defined in Task 5 (Task 4 may stub the call behind `has_method`).
