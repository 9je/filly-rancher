# Phase 1B: The Ranch Economy — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the loop. Captured ponies live in pens, eat food you grow, get happy, produce gems on a timer; you sell gems for bits, buy upgrades and more plots, and the whole thing survives quitting the game.

**Architecture:** Phase 1A proved the *verbs* (roam, find, capture). Phase 1B adds the *nouns that persist*. The keystone is a `PonyInstance` — an individual pony with her own identity and state — replacing the current arrangement where capturing stores a shared reference to a character definition. Everything else (happiness, hunger, production, pens, saving) hangs off that. Ranch structures are data-driven plot buildings placed into fixed slots. All economy logic lives in scene-free `RefCounted` classes under `game/systems/` so it is GUT-testable headlessly, with node scripts staying thin — the pattern Phase 1A's final review confirmed is holding.

**Tech Stack:** Godot 4.5.2 (GDScript, Forward+), GUT for headless unit tests.

**Spec:** `docs/superpowers/specs/2026-08-26-filly-rancher-design.md` (Phase 1 section)

**Builds on:** Phase 1A (merged at `818c6fa`). Read `docs/pipeline.md`, `docs/testing.md`, `docs/ci.md`, `docs/distribution.md`, `docs/windows-testing.md`, and `docs/phase1a-playtest.md` before starting.

## Global Constraints

- Godot 4.5.2, GDScript only, Forward+. Both platform exports must build every phase; `game/world/ranch.tscn` is the main scene and the export smoke marker is `RANCH_OK`.
- **1 unit = 1 metre.** A pony is 1.163 m at the withers but **2.138 m to horn tip** — size pens, gates and doorways for 2.14 m.
- **No pony ever dies.** Neglect leads to escape, never death.
- Every collectible character stays a `PonyData` resource; adding a character must require **zero gameplay-code changes**.
- Logic testable without a scene tree lives in `game/systems/` as `RefCounted` with GUT tests. Node scripts stay thin.
- Every gate must be **proven capable of failing** — demonstrate red, then green. This project has shipped five gates that passed while measuring nothing; three more were found in Phase 1A's final review and are fixed in Task 1 here.
- Automated runs pass `--audio-driver Dummy`; the `audio_safety.gd` autoload mutes the master bus on headless/screenshot runs. Never make the developer's machine play sound.
- **Use offscreen rendering** (`xvfb-run` + llvmpipe, real GPU available via Mesa radv) for anything visual. It has caught over a dozen bugs that numeric assertions waved through.
- Commit messages end with: `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## Carried facts Phase 1B will trip on if ignored

- `roam_radius` is **soft**: fleeing momentum overshoots it by ~1.15 m. A fence placed exactly on it gets clipped through.
- `Storage.release()` exists with **zero callers** — Phase 1B is what wires it.
- `populate()` is called once (`ranch.gd`); there is **no respawn**, so the world permanently empties.
- Rainbow Dash's flee speed is clamped by `GALLOP_MAX_PLAYBACK` to only 7% above the player's gallop; the fix is a third clip, not a bigger constant. Out of scope here, but it caps chase tension.
- Hair simulation is tuned and gated for **Twilight only**; Rainbow Dash and Fluttershy have known-failing chains (disclosed, out of scope).

## File Structure

```
game/
├── systems/                         # scene-free, GUT-tested
│   ├── pony_instance.gd             # individual pony: uid + state (Task 1)
│   ├── game_state.gd                # autoload: the whole savable world (Task 2)
│   ├── save_io.gd                   # JSON read/write + versioning (Task 2)
│   ├── needs.gd                     # hunger/happiness rules (Task 4)
│   ├── production.gd                # gem timers driven by happiness (Task 5)
│   ├── economy.gd                   # wallet, prices, transactions (Task 6)
│   └── plot_data.gd                 # plot/building definitions (Task 3)
├── data/
│   ├── foods/*.tres                 # food definitions (Task 4)
│   └── plots/*.tres                 # buildable plot types (Task 3)
├── world/
│   ├── plot_slot.gd                 # a buildable slot on the ranch (Task 3)
│   ├── pen.gd                       # holds ponies, feeds them (Task 3/4)
│   ├── garden.gd                    # grows food over time (Task 4)
│   └── market_stall.gd              # sell gems, buy things (Task 6)
├── ui/
│   ├── build_menu.gd/.tscn          # choose what to build in a slot (Task 3)
│   ├── shop.gd/.tscn                # market UI (Task 6)
│   └── hud.gd                       # extended: bits, held gems (Task 6)
└── test/                            # GUT tests mirror systems/
```

---

### Task 1: PonyInstance — individual identity

The keystone. Today capturing stores a shared `PonyData`; the bag literally holds two pointers to the same record, so there is nowhere to put happiness or a production timer.

**Files:**
- Create: `game/systems/pony_instance.gd`, `game/test/test_pony_instance.gd`
- Modify: `game/systems/storage.gd`, `game/actors/player/magic_beam.gd`, `game/actors/pony/pony.gd`, `game/ui/hud.gd`, and their tests

**Interfaces:**
- Produces: `PonyInstance` (RefCounted) with `uid: StringName` (unique per individual), `data_id: StringName` (which `PonyData`), `nickname: String`, `happiness: float`, `hunger: float`, `caught_at_ms: int`, plus `to_dict() -> Dictionary` / `static from_dict(d) -> PonyInstance`. `Storage` holds `PonyInstance`s, not `PonyData`. A helper resolves `data_id` → `PonyData` via `PonyRegistry`.

- [ ] **Step 1: Write failing tests** — two instances of the same character have different `uid`s and independent state; `to_dict`/`from_dict` round-trips every field exactly; an unknown `data_id` resolves to null without crashing; `Storage` reports `count()` correctly with duplicates of one character.
- [ ] **Step 2: Run tests, confirm they fail for the right reason.**
- [ ] **Step 3: Implement `pony_instance.gd`.** Generate `uid` from a monotonic counter plus character id — NOT from `Time` (determinism) and NOT by sorting `StringName`s (Godot compares those by interned pointer, which broke a "seeded" spawn in Phase 1A and is a live footgun).
- [ ] **Step 4: Migrate `Storage`** to hold `PonyInstance`. Update `magic_beam.gd`'s capture path to construct one from the captured `Pony`. Update the HUD to read the instance (rarity pip colour comes from the resolved `PonyData`).
- [ ] **Step 5: Wire `Storage.release()`** — releasing spawns a live `Pony` back into the world from the instance, preserving her state. This retires the "zero callers" finding and is what pens will use.
- [ ] **Step 6: Fix the three tautological gates** the Phase 1A review identified, since you are touching their files: `playground.gd:110,127` and `test_player.gd:170`, `test_pony.gd:152` compare `Gait.playback_scale_for_speed` against itself (stubbing it to `1.0` still passes) — pin literal expected values instead. Prove each now fails when stubbed.
- [ ] **Step 7: Verify** — `CAPTURE_OK`, `RANCH_OK`, full suite green, and a headless check that capturing two of the same character yields two distinct instances. Commit.

---

### Task 2: Save and load

**Files:**
- Create: `game/systems/game_state.gd` (autoload), `game/systems/save_io.gd`, `game/test/test_save_io.gd`
- Modify: `game/project.godot` (autoload registration), `game/world/ranch.gd`

**Interfaces:**
- Produces: `GameState` autoload holding the savable world (roster, wallet, plots, unlocks, world seed) with `to_dict()`/`from_dict()`; `SaveIO.save(slot, dict) -> bool` / `SaveIO.load(slot) -> Dictionary` writing human-readable JSON to `user://saves/slot_<n>.json`, with a `version` field and a documented policy for loading older versions.

- [ ] **Step 1: Write failing tests** — a full round-trip preserves every field; loading a missing slot returns an empty dict rather than crashing; a corrupt/truncated JSON file fails loudly and does NOT destroy the existing save; an unknown future `version` refuses to load rather than silently misreading.
- [ ] **Step 2: Run, confirm failure. Implement `save_io.gd`**, then `game_state.gd`.
- [ ] **Step 3: Write atomically** — save to a temp file and rename, so an interrupted write cannot corrupt the previous save. Prove it (write a deliberately failing save mid-way; confirm the old file survives intact).
- [ ] **Step 4: Wire it in** — save at the player house / on quit, autoload on start. Human-readable JSON is deliberate: the spec wants the two players able to trade ponies by sending each other a blob.
- [ ] **Step 5: Verify the Windows path.** `user://` on Windows resolves to `%APPDATA%\Godot\app_userdata\Filly Rancher\` (confirmed empirically under Proton). Run `bash tools/run_windows_build.sh` and confirm a save written under Proton lands there and reloads. This is the single highest-value cross-platform check in the phase — do not skip it.
- [ ] **Step 6: Verify** full suite, all gates, both exports. Commit.

---

### Task 3: Plots, pens, and the build menu

**Files:**
- Create: `game/systems/plot_data.gd`, `game/data/plots/*.tres`, `game/world/plot_slot.gd`, `game/world/pen.gd`, `game/ui/build_menu.{gd,tscn}`, tests
- Modify: `game/world/ranch.tscn` (place slots), `game/world/ranch.gd`

**Interfaces:**
- Produces: `PlotData` (Resource: id, display name, cost, scene path, description); `PlotSlot` (Area3D) with `build(plot: PlotData) -> bool`, `is_empty()`, `contents`; `Pen` with `add_pony(inst: PonyInstance) -> bool` (false when full), `remove_pony(uid) -> PonyInstance`, `capacity`, `ponies()`.

- [ ] **Step 1: Failing tests** for `PlotSlot`/`Pen` logic — a slot builds once and refuses a second build; a pen accepts up to capacity then refuses; removing by uid returns the right individual; a pen with mixed characters keeps them distinct.
- [ ] **Step 2: Implement**, tests green.
- [ ] **Step 3: Place 4–6 slots** in the ranch's reserved open area. **Fences and gates must clear 2.14 m** (horn tip, not withers) and must not sit exactly on a `roam_radius` boundary (fleeing momentum overshoots ~1.15 m and would clip through).
- [ ] **Step 4: Build menu UI** — approach a slot, press interact, choose a plot type you can afford. Keep it keyboard/gamepad navigable, matching the existing HUD's input conventions.
- [ ] **Step 5: Release ponies into pens** from storage (this is `Storage.release()`'s real consumer). A penned pony uses the same `Pony` actor with a leash to the pen bounds rather than a new actor type.
- [ ] **Step 6: Verify** — render the ranch with a built pen containing ponies and LOOK: do they stay inside? Do fences read at the right scale beside a 1.16 m pony? Print `RANCH_OK` with new plot checks; prove the new checks can fail. Commit.

---

### Task 4: Food, gardens, hunger and happiness

**Files:**
- Create: `game/systems/needs.gd`, `game/data/foods/*.tres`, `game/world/garden.gd`, tests
- Modify: `game/actors/pony/pony.gd`, `game/systems/pony_instance.gd`, `game/ui/hud.gd`

**Interfaces:**
- Produces: `FoodData` (Resource: id, display name, grow seconds, seed cost); `Needs.tick(inst, delta) -> void` advancing hunger and decaying happiness; `Needs.feed(inst, food_id) -> bool` (favourite foods give a bigger happiness bump — `PonyData.favorite_foods` already exists and is populated).

- [ ] **Step 1: Failing tests** — hunger rises over time; feeding lowers it; a favourite food raises happiness more than a non-favourite; happiness decays while hungry; values clamp to their ranges and never go negative or exceed max.
- [ ] **Step 2: Implement `needs.gd`**, tests green. Keep it pure: no scene access, injected delta, so it is deterministic and testable.
- [ ] **Step 3: Gardens** — a plot type that grows a food over time and can be harvested (the magic beam already picks up loose `RigidBody3D`s, so harvested food should be beamable, which reuses the mechanic rather than adding a new one).
- [ ] **Step 4: Feeding** — drop food in a pen; penned ponies eat it and their state updates.
- [ ] **Step 5: HUD** — show a penned pony's happiness and hunger when you look at her.
- [ ] **Step 6: Verify** — a headless simulation over compressed time showing hunger rising, feeding helping, and favourites helping more; render a garden through its growth stages and LOOK at it. Commit.

---

### Task 5: Gem production and escape

**Files:**
- Create: `game/systems/production.gd`, tests
- Modify: `game/world/pen.gd`, `game/actors/pony/pony.gd`

**Interfaces:**
- Produces: `Production.tick(inst, delta) -> int` returning gems produced this tick, scaled by happiness; a gem pickup spawned in the pen (beamable, like food).

- [ ] **Step 1: Failing tests** — a happy pony produces faster than an unhappy one; a starving pony produces nothing; production is deterministic given the same inputs; gems accumulate correctly over compressed time.
- [ ] **Step 2: Implement**, tests green.
- [ ] **Step 3: Escape, not death.** A pony neglected past a threshold starts an escape timer and then leaves the pen, returning to the wild pool where she can be recaptured — with her state intact, so a long-neglected pony is a real loss of progress but never a dead pony. **This is a project-wide rule; make the gate prove she survives.**
- [ ] **Step 4: Spawn gems** in the pen as beamable pickups; selling comes in Task 6.
- [ ] **Step 5: Verify** — compressed-time headless run showing production scaling with happiness and an escape occurring on neglect with the pony alive afterwards; render a pen with gems and LOOK. Commit.

---

### Task 6: Bits, the market stall, and upgrades

**Files:**
- Create: `game/systems/economy.gd`, `game/world/market_stall.gd`, `game/ui/shop.{gd,tscn}`, tests
- Modify: `game/ui/hud.gd`, `game/systems/game_state.gd`

**Interfaces:**
- Produces: `Economy` (RefCounted) with `bits`, `sell(gem_type, count) -> int`, `can_afford(cost) -> bool`, `spend(cost) -> bool`, signal `bits_changed`; a market stall you walk up to; a shop UI selling plots, seeds, pen upgrades, and beam upgrades (range, pony-slot capacity).

- [ ] **Step 1: Failing tests** — selling adds the right bits; spending refuses when short and does not partially deduct; buying an upgrade applies it; the wallet round-trips through save/load.
- [ ] **Step 2: Implement**, tests green.
- [ ] **Step 3: Market stall + shop UI**, keyboard/gamepad navigable.
- [ ] **Step 4: Wire upgrades** — beam range and storage capacity are the two that change how the game plays; make sure both take effect immediately and persist.
- [ ] **Step 5: Tune** so the first few purchases arrive at a satisfying pace; state the intended pacing in the report so it can be argued with.
- [ ] **Step 6: Verify** — full economic round trip headless (capture → pen → feed → gems → sell → buy → upgrade applies → save → reload → still applied). Commit.

---

### Task 7: Respawn, integration pass, and the playable build

**Files:**
- Modify: `game/world/spawner.gd`, `game/world/ranch.gd`, `docs/`
- Create: `docs/phase1b-playtest.md`

- [ ] **Step 1: Respawn.** `populate()` runs once today, so the world permanently empties. Add gradual respawn in zones the player is not currently standing in, so the ranch refills without ponies popping in front of you. Keep it seeded and deterministic for the gates.
- [ ] **Step 2: Integration pass** — actually play it via offscreen rendering: capture, pen, feed, wait for gems, sell, buy an upgrade, save, quit, reload, confirm everything survived. Fix what breaks. Record every fix; finding nothing would be a surprising result worth stating explicitly.
- [ ] **Step 3: Add an `EXPECTED_CHECKS` floor to every gate** (a Phase 1A review finding: deleting a whole check phase still printed `CAPTURE_OK checks=39`, and `RANCH` printed no count at all). Prove a missing phase now fails.
- [ ] **Step 4: All gates and the full suite green**; both platform exports; run the Linux binary; run `bash tools/run_windows_build.sh` (Proton) and confirm a save round-trips on the Windows path.
- [ ] **Step 5: `docs/phase1b-playtest.md`** — the loop, the controls, what is deliberately missing (the Ponypedia, fusion, racing, voices — all Phase 2+), and known issues carried forward.
- [ ] **Step 6: Commit** and report Phase 1B complete.
