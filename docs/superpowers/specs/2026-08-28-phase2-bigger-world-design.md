# Filly Rancher, Phase 2: A Bigger World

**Date:** 2026-08-28
**Status:** Design for review, pre-implementation
**Scope:** The five slices that turn a one-field ranch into a game with a horizon. Each slice gets its own implementation plan; this document is the shape they all fit.
**Supersedes:** the World row of the 2026-08-26 spec's "Decisions already made" table. That spec chose zone-gated scenes with loading transitions and listed a seamless world as out of scope. The owner has since chosen one continuous map that opens up in stages. This document records the new decision; the old one is retired, not contradicted.

## Why this phase exists

The owner played the Phase 1B build to completion in one sitting: 21 ponies caught, four pens built, and a wallet reading zero bits. Every pony he penned produced gems on schedule and there was nowhere to sell them. `Economy.sell()` shipped without a shop. That single missing verb is why the ranch felt inert, and it is the first thing this phase fixes.

The second finding is that the world's breadth is already half built and entirely unused. `PonyData.spawn_zones`, `PonyRegistry.by_zone()`, `SpawnTable.draw()` and `ZoneMarker` all exist. Every pony in the game is zoned `ranch`, so the 140 m map reads as one field. `Rarity` already has four tiers and gem value is already keyed to the producing pony's rarity. The systems for "rare ponies are worth chasing" and "ponies earn you bits" were designed as one loop. They only need the map and the market to connect them.

The owner's words, which this design is held to: "bigger map, more characters, rarer ponies, weather, time of day, ponies that only appear under certain conditions, a collection, a way to make bits from your ponies." And later: "a pause menu instead of losing mouse control with escape."

## The loop

Everything below serves one cycle:

**Discover** a pony in the compendium as a silhouette, or see her in the wild.
**Chase** her to where and when she appears.
**Earn** bits from the gems your penned ponies produce, more from rarer ponies.
**Unlock** the next region, the gear that makes the next chase possible, the care that keeps ponies producing.
**Discover** what lives there.

A slice that does not feed this cycle does not belong in this phase.

## Approach

Build the shared spine first, then pour content in as data. This is how the codebase already works: `PonyData`, `PlotData`, `FoodData` and their registries are `.tres` resources read by generic systems. It is also the lesson of Phase 1B, where a system shipped without its last step and the whole loop went dead. A spine means no half loops.

Rejected alternatives, recorded so they stay rejected:

- **Region at a time.** Ship the forest complete, then the lake. Content lands sooner, at the cost of five subtly different implementations of the same idea.
- **Content first.** Import the 43 remaining characters and a bigger map now, retrofit systems later. Fastest visible change, and the one most likely to be torn up.

## Systems

### WorldState

Owns time of day and weather. Both are derived deterministically from the save's existing `world_seed` plus elapsed play time, so the whole system persists as one integer and one float. Nothing polls it; it emits `phase_changed(phase)` and `weather_changed(weather)` and listeners react.

- **Phases:** `DAWN`, `DAY`, `DUSK`, `NIGHT`. A full cycle is 20 real minutes, tuned so a single session sees every phase. `DAY` is the longest.
- **Weather:** `CLEAR`, `RAIN`, `FOG`, `STORM`. Weather is rolled per phase from the seed, with `CLEAR` most common and `STORM` rare. Weather is a table, not a simulation.
- **Rendering:** the phase drives the sun's angle and colour and the `WorldEnvironment` sky; weather drives fog density, a rain particle layer, and ambient light. This is the one genuinely new subsystem in the phase.
- **Saves:** `world_time` (seconds elapsed) is added to the save. The seed already exists. Loading a save resumes at the phase and weather it was saved in.

### Spawn conditions

`PonyData` gains a condition block: `phases: Array[WorldState.Phase]` and `weathers: Array[WorldState.Weather]`, both empty meaning "any". Together with the existing `spawn_zones` these are the complete description of where and when a character appears.

`Spawner` already filters the roster by zone before `SpawnTable.draw()`. It gains the phase and weather filters and, critically, **re-evaluates on `WorldState` change**. A pony whose conditions no longer hold wanders off-screen and despawns; a pony whose conditions now hold spawns at her zone. The spawner already regenerates the wild herd from the seed on every boot, so this is a generalisation of what it does, not a new responsibility.

"Only appears in fog, at night, by the lake" becomes three fields in one `.tres`. That is the entire authoring cost of a conditional pony, and it is the point of the design.

### Zones and unlocks

The map grows. `Terrain.HALF` moves from 70 m to a size the regions justify, and the flat field becomes distinct places. Candidate regions, in the order they unlock: the **Ranch** (home, free), the **Orchard** (Applejack's family, common ponies, first unlock), the **Everfree edge** (forest, fog-dependent ponies), the **Lake** (dawn and dusk ponies, storms), and the **Night Meadow** (night-only ponies, the rarest). Region names and their residents are authoring decisions for the plan, not this spec.

Each region is a `ZoneMarker` or a cluster of them, with a `zone_id`. A locked region is a `RegionGate`: a visible barrier (a fence with a closed gate, a fallen tree, a washed-out bridge) with a bit price. Paying at the market clears it. The save's existing `unlocks` array records which gates are open, and `RegionGate` reads it on boot.

Terrain colour and props are what make a region read as itself. Ponies keep their leashes, so a region's residents stay in it.

### The Market

A building on the ranch with an interaction prompt, opening a two-tab UI.

**Sell.** Lists gems by the rarity of the pony that produced them, with the count and the price per gem from `Economy.GEM_VALUE_BY_RARITY`. Sell one, sell all. This calls `Economy.sell()`, which exists and is tested, and which nothing in the game currently calls.

**Buy.** A catalogue that is pure data: a new `ShopItem` resource with `id`, `display_name`, `description`, `cost`, `kind` and a `kind`-specific payload. Four kinds, matching what the owner asked bits to buy:

- `GEAR`: permanent upgrades applied to the player. Beam reach, catch window width, sneak notice radius, a tracker that marks a spawned rare pony on the HUD. Stored in `unlocks`.
- `PERMIT`: opens a `RegionGate`. Stored in `unlocks`.
- `BUILD`: the existing `PlotData` catalogue, moved here from the build menu so there is one shop. The build menu keeps its plot-side flow.
- `CARE`: consumables. Food (the existing `FoodData`), grooming, treats. Stored as counts in a new `inventory` dictionary on the save. Feeding a penned pony consumes one.

Selling is the income. Care is the running cost. Gear and permits are the progression. Every one of the owner's four requested sinks is the same shop with different rows.

### The Compendium

The collection spine, and the reason the roster exists as a roster rather than a list.

One entry per `PonyData`, in three states: **unseen** (silhouette and rarity colour only), **seen** (name and portrait revealed, conditions shown as question marks), **caught** (conditions revealed). Seeing means she was within the player's notice radius while spawned; catching means `MagicBeam.captured` fired for her `data_id`.

Progress is stored in a new `compendium` dictionary on the save, `data_id` to state. It is per save, not global, because the two players trade ponies by pasting files and a traded pony should count as caught for its new owner.

The compendium is a page of the pause menu. It shows completion as a count and, per region, as a count. That per-region count is what pulls the player toward the next unlock.

### Requests

A board on the ranch, three requests active at a time, drawn from templates and filled with concrete targets:

- "Bring me a **{personality}** pony from the **{region}**."
- "I need **{n}** gems from a **{rarity}** pony."
- "Show me **{character}**." (a compendium-driven request: seen, not caught)

Completing one pays bits and, sometimes, a `CARE` item. Requests are stored in the save as their filled-in form, so a request survives quitting. They exist to point the player at parts of the compendium they would otherwise skip, and they double as the tutorial: the first three requests on a new save are fixed and walk the player through catch, pen, sell.

### Pause menu

`Esc` opens a pause menu instead of silently freeing the cursor. The tree pauses (the build menu already establishes the pattern: `PROCESS_MODE_ALWAYS` on the menu, everything else paused). Pages: **Resume**, **Compendium**, **Requests**, **Settings** (volume, mouse sensitivity, invert look), **Save**, **Quit to desktop**.

The cursor is freed while the menu is open and captured again on resume. `camera_rig.gd`'s current toggle on `ui_cancel` is replaced; `hud.gd`'s `FREE CURSOR` hint row becomes `PAUSE`.

This lands in slice one because the compendium and requests need a home before they exist, and because the owner asked for it.

## Data model changes

| Where | Change |
|---|---|
| `PonyData` | `phases`, `weathers` arrays (empty = any). |
| `ShopItem` (new) | `id`, `display_name`, `description`, `cost`, `kind`, payload. |
| `RegionGate` (new scene) | `zone_id`, `permit_id`, barrier geometry. |
| Save | `world_time: float`, `inventory: Dictionary`, `compendium: Dictionary`, `requests: Array`. `unlocks` gains gear and permit ids. `version` increments; the loader accepts the previous version and fills defaults. |

No existing save key changes meaning. A Phase 1B save loads into Phase 2 with a fresh world clock, an empty inventory, a compendium marking already-owned ponies as caught, and the tutorial requests.

## Testing

The project's rule, from `docs/testing.md`: a gate prints its success marker only after deciding it succeeded, and exit code is the verdict. Every system above gets:

- **Pure-logic tests** in `game/test/` for anything with no scene: `WorldState` phase and weather derivation from a seed, spawn condition filtering, `ShopItem` purchase and refund paths, compendium state transitions, request filling and completion.
- **A headless gate** per slice: `market_test` (sell, buy, permit, gate opens), `world_state_test` (a full cycle at accelerated time, spawn set changes with it), `compendium_test` (unseen to seen to caught, per-region counts).
- **Save round trips** for every new key, in `test_save_io.gd`, including loading a version-1 save.
- **The visual harness** for time of day and weather, because a sky is a thing you look at. Renders at each phase and each weather, reviewed by eye, as `visual_review.gd` does for ponies.

## Build order

Each slice is its own plan and its own branch, merged green.

1. **Market and pause menu.** Closes the dead loop. Gives the compendium and requests a home before they exist. Smallest slice, largest change to how the game feels.
2. **Roster and rarity.** The 43 characters already on disk, converted through the proven SFM path, with rarity spread across them so the four tiers all have members. Rarity gates what is worth chasing; with slice one in, it also gates what pays.
3. **Zones and unlocks.** The map grows and splits into regions. `RegionGate` and `PERMIT` items. Mostly authoring against systems that exist.
4. **Time and weather.** `WorldState` and its rendering. The one new subsystem.
5. **Conditions, compendium, requests.** The payoff. Needs 2, 3 and 4 underneath it.

## Not in this phase

Recorded so they stay visible and stay out:

- **Fusion** (the 2026-08-26 spec's Phase 2). It is a gacha on top of a collection; the collection comes first.
- **Racing and betting** (that spec's Phase 3).
- **Voices and music** (that spec's Phase 4). `docs/notes-voice.md` stands.
- **Player customisation and non-unicorn capture styles.**
- **Multiplayer, pony death, combat, distribution.** Still out, as before.
