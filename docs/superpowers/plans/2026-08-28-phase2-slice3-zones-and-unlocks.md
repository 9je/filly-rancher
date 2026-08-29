# Phase 2 Slice 3: Zones and Unlocks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the map past its single field into four regions that read as places, each fenced off until a permit is bought at the Market, and move part of the roster out into them so rarity has somewhere to live.

**Architecture:** Regions are data (`RegionData` resources under `game/data/regions/`, loaded by a `RegionRegistry`): a centre, a radius, a permit price, a grass palette, and where the gate stands. The terrain reads the registry to tint the ground per region and to hollow a lake basin. A `RegionFence` scene (built from primitives the way `Pen` is) rings a locked region with rails and posts and one gate leaf whose collider drops the moment the permit is in `GameState.unlocks`. `Shop` learns to sell `PERMIT` items (the kind already exists and is refused today). `ZoneMarker`s for the new `zone_id`s go into `ranch.tscn`, and the roster's `.tres` files are re-zoned so each region has residents. A hosted gate (`region_test.tscn`) proves: locked means the player is stopped, buying the permit opens the gate, the region's ponies spawn inside it, and the permit survives a save.

**Tech Stack:** Godot 4.5.2, GDScript, GUT, the project's gate conventions.

**Spec:** `docs/superpowers/specs/2026-08-28-phase2-bigger-world-design.md`, sections "Zones and unlocks", "The Market" (PERMIT), "Data model changes" (`RegionGate`, `unlocks`), build order item 3.

## Global Constraints

- No em dash (U+2014) and no double hyphen (` -- `) in anything a player can read (region names, toasts, shop rows) or in new code, comments, docs, or data.
- Menus draw and emit; `ranch.gd` transacts. The Market's PERMIT rows go through `Shop.buy()` like everything else.
- `NO PONY EVER DIES`. Re-zoning a character changes where new wild ponies spawn; it never touches an owned `PonyInstance`.
- A gate prints its marker only after deciding; exit code is the verdict. Hosted ranch mode is used for the new gate (no own watchdog, `gate_report_finished`, `GameState.reset()` at boot).
- Saves: permits live in the existing `unlocks` array as `"permit_<zone>"` strings. No format version bump (no new key).
- The ranch's existing checks must keep passing: "every pony was spawned inside her zone", "no zone came back with an empty roster", "the spawn zones sit on sloped ground" (`MIN_ZONE_RELIEF` 0.25), the pen-plot clearing checks, and `RANCH_OK ponies=<n> props=<n> assets=present` (the numbers change and are recorded in the plan's Task 6).
- Ponies keep their leashes; a region's residents wander inside their `ZoneMarker`'s `roam_radius` as today.
- The terrain is generated in code (see `game/world/terrain.gd`'s header for why); the lake basin and region tints are arithmetic, not imported assets.
- Branch: `phase2-slice3-zones`. Commit after every task.

---

## The regions

Map: `Terrain.HALF` goes from 70 to 110 m (a 220 m square; `CELL` stays 2 m, 12,100 quads). The homestead apron (`FLAT_RADIUS` 30, `BLEND_RADIUS` 44 around `HOMESTEAD_CENTRE` (0, -4)) is unchanged, so every existing prop, plot, building and zone keeps its ground.

| id | display_name | centre (x, z) | radius | permit cost | gate faces | grass low / high | zone_id | residents (moved from `ranch`) |
|---|---|---|---|---|---|---|---|---|
| orchard | The Orchard | (62, 30) | 22 | 150 | west (toward the homestead) | (0.30, 0.46, 0.17) / (0.56, 0.62, 0.24) | `orchard` | applejack, applebloom, braeburn, caramel, carrottop, cheerilee, berrypunch |
| everfree | The Everfree Edge | (-64, -40) | 24 | 1200 | east | (0.16, 0.30, 0.20) / (0.28, 0.42, 0.28) | `everfree` | trixie, pinkamena, sunsetshimmer, lightningdust, drwhooves, kerfuffle |
| lake | The Lake | (60, -62) | 24 | 300 | south-west | (0.26, 0.44, 0.24) / (0.50, 0.60, 0.32) | `lake` | soarin, spitfire, cloudchaser, flitter, lyra, bonbon, minuette, milkyway |
| nightmeadow | The Night Meadow | (-61, 69) | 24 | 700 | north-east | (0.36, 0.40, 0.48) / (0.58, 0.60, 0.70) | `nightmeadow` | songbirdserenade, octavia, vinylscratch, nightlight, mane_allgood, marblepie, maudpie, limestonepie, cocopommel |

Everyone else stays `ranch` (twilight, rainbowdash, fluttershy, pinkiepie, derpyhooves, starlightglimmer, rarity, shiningarmor, sweetiebelle, scootaloo, pokeypierce, redheart, aloeblossom, lotusblossom). That is 14 on the ranch and 30 out in the regions; the two LEGENDARY characters are in the two most expensive regions.

Every region centre is at least 60 m from the homestead centre, outside the apron (relief present, so "sloped ground" holds), and every region disc plus its fence ring (radius + 3 m) stays inside `HALF` minus the 2 m boundary wall: the furthest point is nightmeadow at (-58, 66), radius 27 with the fence, reaching z = 93 < 108.

Each region gets one `ZoneMarker` at its centre with `spawn_radius = radius - 6`, `spawn_count = 3`, `roam_radius = 6`. The five existing ranch markers keep their positions and counts; the ranch roster of 14 fills them as before.

The lake: a basin of depth 2.2 m over the lake region (a smooth bowl, `smoothstep` from the rim), with a flat blue water `MeshInstance3D` disc at basin depth minus 0.4 m over the inner 70 percent of the radius. Water is decorative; the ground under it is the terrain, walkable, no collision on the water mesh. The night meadow's palette is the pale silver in the table; the everfree edge is dark and gets a copse of pines around its rim in `props.gd`'s `LAYOUT`.

Fences: a `RegionFence` is a regular polygon of 28 segments at `radius + 3` m, three rails per segment at `Pen.RAIL_HEIGHTS`, posts at each vertex sat on `height_at()`, and one gate segment (facing the homestead as in the table) whose leaf carries the only `PEN_GATE`-layer collider on the ring; the rails and posts are on `PROPS`. The player's mask includes `PROPS`, so the ring stops the player; ponies' masks include `PEN_GATE` and `PROPS`, so residents stay in and outsiders stay out. Buying the permit disables the leaf's collider and swings the leaf open (visually, like the pen's), and the fence stays as scenery.

---

### Task 1: RegionData and RegionRegistry, with the four data files

**Files:**
- Create: `game/systems/region_data.gd`, `game/systems/region_registry.gd`
- Create: `game/data/regions/orchard.tres`, `everfree.tres`, `lake.tres`, `nightmeadow.tres`
- Test: `game/test/test_region_registry.gd`

**Interfaces:**
- `class_name RegionData extends Resource`: `id: StringName`, `display_name: String`, `centre: Vector2`, `radius: float`, `permit_cost: int`, `gate_yaw_degrees: float` (0 = gate on the +X side of the ring, counter-clockwise positive, same convention as `Pen.gate_yaw_degrees`), `grass_low: Color`, `grass_high: Color`, `has_lake: bool`, `lake_depth: float`. `permit_id() -> StringName` returns `"permit_" + id`. `contains(point: Vector2) -> bool`.
- `class_name RegionRegistry extends RefCounted`: `const REGION_DIR := "res://data/regions"`, `load_all(dir := REGION_DIR) -> Dictionary`, `all() -> Array[RegionData]` (by `permit_cost` then id), `by_id(id) -> RegionData`, `region_at(point: Vector2) -> RegionData` (the region whose disc contains the point, or null for the open ranch).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## The regions as data: game/systems/region_data.gd, game/systems/region_registry.gd,
## and game/data/regions/*.tres. Same shape as test_shop_registry.gd.

const RegionRegistryScript := preload("res://systems/region_registry.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const TerrainScript := preload("res://world/terrain.gd")


func _registry() -> RegionRegistry:
	var reg: RegionRegistry = RegionRegistryScript.new()
	reg.load_all(RegionRegistryScript.REGION_DIR)
	return reg


func test_the_four_regions_load() -> void:
	var ids: Array = []
	for r in _registry().all():
		ids.append(String(r.id))
	ids.sort()
	assert_eq(ids, ["everfree", "lake", "nightmeadow", "orchard"])


func test_all_is_sorted_by_permit_cost_then_id_and_costs_are_positive() -> void:
	var items := _registry().all()
	for i in range(items.size()):
		assert_gt(items[i].permit_cost, 0, "%s must cost something" % items[i].id)
		if i > 0:
			var a := items[i - 1]
			var b := items[i]
			assert_true(a.permit_cost < b.permit_cost or (a.permit_cost == b.permit_cost and String(a.id) < String(b.id)))


func test_every_region_sits_outside_the_homestead_apron_and_inside_the_map() -> void:
	for r in _registry().all():
		var d: float = r.centre.distance_to(TerrainScript.HOMESTEAD_CENTRE)
		assert_gt(d - r.radius, TerrainScript.BLEND_RADIUS, "%s must be clear of the apron" % r.id)
		var reach: float = maxf(absf(r.centre.x), absf(r.centre.y)) + r.radius + 3.0
		assert_lt(reach, TerrainScript.HALF - TerrainScript.BOUNDARY_THICKNESS, "%s must fit inside the boundary wall" % r.id)


func test_regions_do_not_overlap_each_other() -> void:
	var items := _registry().all()
	for i in range(items.size()):
		for j in range(i + 1, items.size()):
			var gap: float = items[i].centre.distance_to(items[j].centre) - items[i].radius - items[j].radius
			assert_gt(gap, 6.0, "%s and %s need a walkable gap between their fences" % [items[i].id, items[j].id])


func test_display_names_carry_no_dashes() -> void:
	for r in _registry().all():
		assert_false(r.display_name.is_empty())
		assert_false(r.display_name.contains("--") or r.display_name.contains("—"))


func test_permit_id_and_contains() -> void:
	var r: RegionData = RegionDataScript.new()
	r.id = &"orchard"
	r.centre = Vector2(10.0, 10.0)
	r.radius = 5.0
	assert_eq(r.permit_id(), &"permit_orchard")
	assert_true(r.contains(Vector2(12.0, 12.0)))
	assert_false(r.contains(Vector2(20.0, 10.0)))


func test_region_at_finds_the_disc_or_null() -> void:
	var reg := _registry()
	var orchard: RegionData = reg.by_id(&"orchard")
	assert_not_null(orchard)
	assert_eq(reg.region_at(orchard.centre), orchard)
	assert_null(reg.region_at(Vector2.ZERO), "the homestead is open ranch")


func test_exactly_one_region_has_a_lake() -> void:
	var lakes := 0
	for r in _registry().all():
		if r.has_lake:
			lakes += 1
			assert_gt(r.lake_depth, 0.0)
	assert_eq(lakes, 1)
```

`TerrainScript.HALF` is 70 today; this test passes only once Task 3 raises it to 110. Run the test file after Task 3 as well; in this task, expect the "inside the map" assertion to fail for the outer regions and record that in the report as expected.

- [ ] **Step 2: Run the test to verify it fails** (preload error).

- [ ] **Step 3: Write region_data.gd**

```gdscript
class_name RegionData
extends Resource
## ONE REGION OF THE MAP, as data. Where it is, how big, what its permit costs, what its
## grass looks like, and whether there is a lake in it. One .tres per region under
## game/data/regions/, so adding a region is authoring a data file: Terrain tints the
## ground from it, RegionFence rings it, the Market sells its permit, and the spawner's
## ZoneMarker for it carries the matching zone_id.
##
## `centre` is XZ in metres (Vector2.y is world Z), the same convention props.gd's LAYOUT
## uses. `gate_yaw_degrees` follows Pen.gate_yaw_degrees: 0 puts the gate on the +X side
## of the ring, positive turns counter-clockwise seen from above.

@export var id: StringName = &""
@export var display_name: String = ""
@export var centre := Vector2.ZERO
@export var radius := 20.0
@export var permit_cost := 0
@export var gate_yaw_degrees := 0.0
@export var grass_low := Color(0.239, 0.408, 0.196)
@export var grass_high := Color(0.443, 0.541, 0.271)
@export var has_lake := false
@export var lake_depth := 0.0


## The unlock string the Market writes and the fence reads.
func permit_id() -> StringName:
	return StringName("permit_" + String(id))


func contains(point: Vector2) -> bool:
	return point.distance_to(centre) <= radius


## 0 at the rim and beyond, 1 well inside. Terrain uses it to blend grass and, for the
## lake, to shape the basin. `feather` metres of smooth edge.
func weight_at(point: Vector2, feather: float = 8.0) -> float:
	var d := point.distance_to(centre)
	return 1.0 - smoothstep(radius - feather, radius, d)


func _to_string() -> String:
	return "RegionData(%s, r=%.0f, permit=%d)" % [String(id), radius, permit_cost]
```

- [ ] **Step 4: Write region_registry.gd** (copy `game/systems/shop_registry.gd`'s shape exactly, including `_resource_path`; sort by `permit_cost` then id; add `region_at`):

```gdscript
func region_at(point: Vector2) -> RegionData:
	for region in _ordered:
		if region.contains(point):
			return region
	return null
```

- [ ] **Step 5: Write the four .tres files** from the regions table. `centre = Vector2(62, 30)`, `radius = 22.0`, `permit_cost = 150`, `gate_yaw_degrees`: orchard 180 (gate on the west, toward the homestead), everfree 0 (east), lake 226 (south-west), nightmeadow 48 (north-east); colours as `Color(r, g, b, 1)`; `has_lake = true` and `lake_depth = 2.2` for lake only.

- [ ] **Step 6: Reimport, run the test** (expect 7 of 8 passing with only the map-bounds assertion failing until Task 3).

- [ ] **Step 7: Commit**

```bash
git add game/systems/region_data.gd game/systems/region_data.gd.uid game/systems/region_registry.gd game/systems/region_registry.gd.uid game/data/regions/ game/test/test_region_registry.gd game/test/test_region_registry.gd.uid
git commit -m "feat: RegionData and RegionRegistry, four regions as data"
```

---

### Task 2: Permits for sale

**Files:**
- Modify: `game/systems/shop.gd` (`refusal()` and `buy()` PERMIT branches)
- Create: `game/data/shop/permit_orchard.tres`, `permit_everfree.tres`, `permit_lake.tres`, `permit_nightmeadow.tres`
- Test: `game/test/test_shop.gd`, `game/test/test_shop_registry.gd`

**Interfaces:**
- `Shop.owns_permit(zone: StringName) -> bool` (checks `"permit_<zone>"` in unlocks). PERMIT purchase appends `"permit_" + permit_zone` to unlocks once; refused if owned ("You already hold that permit.") or if `permit_zone` is empty.
- `ShopItem` PERMIT rows: `id = permit_<zone>`, `kind = 1`, `permit_zone = <zone>`, `cost` from the regions table, `display_name` "Permit: The Orchard" etc., a one-line description.

- [ ] **Step 1: Write the failing tests**

In `test_shop.gd`, replace `test_permit_and_build_kinds_are_refused_in_this_slice` with:

```gdscript
func test_buying_a_permit_records_it_once_and_never_twice() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)  # 500 bits
	var permit: ShopItem = ShopItemScript.new()
	permit.id = &"permit_lake"
	permit.display_name = "Permit: The Lake"
	permit.cost = 150
	permit.kind = ShopItemScript.Kind.PERMIT
	permit.permit_zone = &"lake"
	assert_false(_shop.owns_permit(&"lake"))
	assert_true(_shop.can_buy(permit))
	assert_true(_shop.buy(permit))
	assert_true(_shop.owns_permit(&"lake"))
	assert_eq(_unlocks, ["permit_lake"])
	assert_eq(_econ.bits, 350)
	assert_false(_shop.can_buy(permit), "a held permit is not sold again")
	assert_false(_shop.refusal(permit).is_empty())
	assert_false(_shop.buy(permit))
	assert_eq(_econ.bits, 350)


func test_a_permit_with_no_zone_is_refused() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var broken: ShopItem = ShopItemScript.new()
	broken.id = &"permit_nowhere"
	broken.cost = 1
	broken.kind = ShopItemScript.Kind.PERMIT
	assert_false(_shop.buy(broken))
	assert_eq(_econ.bits, 500)


func test_the_build_kind_is_still_refused() -> void:
	_econ.sell(PonyDataScript.Rarity.LEGENDARY, 5)
	var build: ShopItem = ShopItemScript.new()
	build.id = &"pen"
	build.cost = 1
	build.kind = ShopItemScript.Kind.BUILD
	build.plot_id = &"pen_small"
	assert_false(_shop.buy(build))
	assert_eq(_econ.bits, 500)
```

In `test_shop_registry.gd` add:

```gdscript
func test_every_permit_names_a_region_that_exists_and_matches_its_price() -> void:
	var regions: RegionRegistry = RegionRegistryScript.new()
	regions.load_all(RegionRegistryScript.REGION_DIR)
	var permits := _registry().of_kind(ShopItemScript.Kind.PERMIT)
	assert_eq(permits.size(), regions.all().size(), "one permit per region")
	for item in permits:
		var region: RegionData = regions.by_id(item.permit_zone)
		assert_not_null(region, "%s names zone '%s', which is not a region" % [item.id, item.permit_zone])
		assert_eq(item.cost, region.permit_cost, "%s must cost what the region says" % item.id)
		assert_eq(String(item.id), "permit_" + String(item.permit_zone))
```
with `const RegionRegistryScript := preload("res://systems/region_registry.gd")`.

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement in shop.gd**

Replace the PERMIT handling in `refusal()`:
```gdscript
		ShopItemScript.Kind.PERMIT:
			if String(item.permit_zone).is_empty():
				return "That is not for sale."
			if owns_permit(item.permit_zone):
				return "You already hold that permit."
```
(the `_:` branch keeps refusing BUILD with "Not for sale yet."), add to `buy()`'s match:
```gdscript
		ShopItemScript.Kind.PERMIT:
			_unlocks.append(String(permit_id_for(item.permit_zone)))
```
and add:
```gdscript
## The unlock string a region's permit is recorded under. One place, so the fence and
## the shop cannot disagree about it.
static func permit_id_for(zone: StringName) -> StringName:
	return StringName("permit_" + String(zone))


func owns_permit(zone: StringName) -> bool:
	return _unlocks.has(String(permit_id_for(zone)))
```
Update the class comment's PERMIT line. `RegionData.permit_id()` must produce the same string; add `assert_eq(RegionDataScript.new_with_id(...)...)` is not needed, the registry test above already ties price and id together.

- [ ] **Step 4: Write the four permit .tres files** (same shape as `hay.tres`; `kind = 1`):
- `permit_orchard`: "Permit: The Orchard", 150, "Opens the gate east of the homestead. Apple country, and the ponies who farm it."
- `permit_everfree`: "Permit: The Everfree Edge", 1200, "Opens the gate to the dark woods in the west. Strange ponies keep to the trees."
- `permit_lake`: "Permit: The Lake", 300, "Opens the gate down to the water. Pegasi drink here, and nobody hurries."
- `permit_nightmeadow`: "Permit: The Night Meadow", 700, "Opens the far gate in the south. Quiet ponies, pale grass, and a rare song."

- [ ] **Step 5: Reimport; run both test files; run `test_market_menu.gd` too** (the Buy tab lists `registry.all()`, so the four permits appear; its catalogue-order test must still hold: permits sort by cost among the other rows).

- [ ] **Step 6: Commit**

```bash
git add game/systems/shop.gd game/data/shop/permit_*.tres game/test/test_shop.gd game/test/test_shop_registry.gd
git commit -m "feat: the Market sells permits; a held permit is never sold twice"
```

---

### Task 3: The map grows, and the ground reads as regions

**Files:**
- Modify: `game/world/terrain.gd` (`HALF`, `_raw_height`, `height_at`, colour in `_build_mesh`, a `regions` provider)
- Modify: `game/world/ranch.tscn` (a `Water` MeshInstance3D under a new `Regions` Node3D; the `Regions` node is where Task 4's fences also go)
- Test: `game/test/test_terrain.gd` (extend; read it first)

**Interfaces:**
- `Terrain.regions: RegionRegistry` (set by `ranch.gd` before the terrain builds; if null, the terrain builds as today with no tints and no lake).
- `Terrain.height_at(x, z)` now subtracts the lake basin: `lake_depth * region.weight_at(point, radius * 0.5)` for a `has_lake` region.
- `Terrain.grass_at(x, z) -> Color` (the per-vertex colour, blended by relief as today, then lerped toward the region's palette by `weight_at`).
- `Terrain.build_water(region: RegionData) -> MeshInstance3D` returns a disc mesh for the lake, placed by `ranch.gd`.

- [ ] **Step 1: Read `terrain.gd`'s `_build_mesh()` and `game/test/test_terrain.gd`, then write the failing tests**

Append to `test_terrain.gd` (match its fixture for constructing a Terrain; if it instantiates the script as a node under a test world, keep that):

```gdscript
const RegionRegistryScript := preload("res://systems/region_registry.gd")


func test_the_map_is_two_hundred_and_twenty_metres_across() -> void:
	assert_eq(TerrainScript.HALF, 110.0)


func test_the_lake_region_is_a_basin_and_the_others_are_not() -> void:
	var terrain := _terrain_with_regions()
	var regions: RegionRegistry = terrain.regions
	var lake: RegionData = regions.by_id(&"lake")
	var centre_h: float = terrain.height_at(lake.centre.x, lake.centre.y)
	var rim_h: float = terrain.height_at(lake.centre.x + lake.radius + 5.0, lake.centre.y)
	assert_lt(centre_h, rim_h - lake.lake_depth * 0.8, "the lake centre sits well below its rim")
	var orchard: RegionData = regions.by_id(&"orchard")
	var raw: float = terrain._raw_height(orchard.centre.x, orchard.centre.y) * terrain._relief_weight(orchard.centre.x, orchard.centre.y)
	assert_almost_eq(terrain.height_at(orchard.centre.x, orchard.centre.y), raw, 0.001, "a dry region is untouched")


func test_grass_tints_toward_the_region_palette_inside_and_not_outside() -> void:
	var terrain := _terrain_with_regions()
	var night: RegionData = terrain.regions.by_id(&"nightmeadow")
	var inside: Color = terrain.grass_at(night.centre.x, night.centre.y)
	var outside: Color = terrain.grass_at(0.0, 30.0)
	assert_gt(inside.b, outside.b + 0.1, "the night meadow reads bluer than the ranch")


func test_without_a_registry_the_terrain_builds_as_before() -> void:
	var terrain := _bare_terrain()
	assert_null(terrain.regions)
	assert_almost_eq(terrain.height_at(60.0, -62.0),
		terrain._raw_height(60.0, -62.0) * terrain._relief_weight(60.0, -62.0), 0.001)
```

Write `_terrain_with_regions()` and `_bare_terrain()` helpers following the file's existing fixture, loading the registry from `RegionRegistryScript.REGION_DIR`. `_raw_height`/`_relief_weight` are underscore-private but reachable in GDScript; the test reads them to define "untouched".

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

In `terrain.gd`:
- `const HALF := 110.0` and update the comment (a 110x110 quad grid, 24,200 triangles).
- `const RegionRegistryScript := preload("res://systems/region_registry.gd")`, `var regions: RegionRegistry = null` with a doc comment (set by the ranch before `_ready()` builds the mesh; null means the plain map).
- `height_at`:
```gdscript
func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z) * _relief_weight(x, z)
	if regions != null:
		for region in regions.all():
			if region.has_lake:
				h -= region.lake_depth * region.weight_at(Vector2(x, z), region.radius * 0.5)
	return h
```
- `grass_at(x, z) -> Color`: the existing relief-based lerp between `GRASS_LOW` and `GRASS_HIGH` extracted into this function; then, for the region at the point (if any), `lerp` the result toward `region.grass_low.lerp(region.grass_high, t)` by `region.weight_at(point)` where `t` is the same relief factor. `_build_mesh()` calls `grass_at` for each vertex colour instead of its inline code.
- `build_water(region) -> MeshInstance3D`: a `CylinderMesh` (top and bottom radius `region.radius * 0.7`, height 0.05) with a `StandardMaterial3D` (albedo `Color(0.20, 0.42, 0.62, 0.85)`, transparency alpha, roughness 0.15, metallic 0.1), positioned at `(centre.x, height_at(centre) + region.lake_depth * 0.55 - 0.4, centre.y)`. No collision.
- The `_build_boundary()` walls read `HALF`, so they move with it; confirm by reading that function.

In `ranch.gd` `_ready()`: before the buildings loop (the terrain builds in its own `_ready()`, which runs BEFORE the ranch's because children ready first, so the registry must be handed over earlier). Read `terrain.gd`'s `_ready()`: if it builds the mesh there, change it to build lazily on first `height_at()`/`get_mesh` or add `func rebuild()`; the cleanest is: `Terrain._ready()` does nothing if `regions == null` AND a flag `defer_build` is set... Simpler and explicit: `ranch.tscn` sets `defer_build = true` on the Terrain node (a new `@export var defer_build := false`), and `ranch.gd` calls `terrain.regions = _regions_registry()` then `terrain.build()` as its first act after the watchdog. Tests and other scenes that use `terrain.tscn`/the script directly keep `defer_build = false` and build in `_ready()` as today. Record which of these you did in the commit message.

Also in `ranch.gd`: `var _region_registry: RegionRegistry` loaded once (`_regions_registry()` like `_plots_catalogue()`), and after the terrain builds, for each region with `has_lake`, `regions_root.add_child(terrain.build_water(region))` where `regions_root` is the new `$Regions` node.

- [ ] **Step 4: Run test_terrain.gd, test_region_registry.gd (now 8 of 8), the direct ranch scene, and terrain_probe/camera_test/wild_ponies gates**

Expected: `RANCH_OK`, exit 0, and the ranch's own "spawn zones sit on sloped ground" still true. `terrain_probe` may assert map extents; read `game/scenes/test/terrain_probe.gd` and update any literal 70.

- [ ] **Step 5: Commit**

```bash
git add game/world/terrain.gd game/world/ranch.gd game/world/ranch.tscn game/test/test_terrain.gd game/scenes/test/terrain_probe.gd
git commit -m "feat: the map is 220 m across, the ground reads as regions, and the lake is a basin"
```

---

### Task 4: RegionFence, the ring with a gate that a permit opens

**Files:**
- Create: `game/world/region_fence.gd`, `game/world/region_fence.tscn`
- Test: `game/test/test_region_fence.gd`

**Interfaces:**
- `class_name RegionFence extends Node3D`: `configure(region: RegionData, ground_sampler: Callable)`, `build()`, `set_open(open: bool)` (drops or restores the gate leaf's collider and swings the leaf), `is_open() -> bool`, `gate_position() -> Vector3` (world, for the toast prompt and the gate probe), `gate_body() -> StaticBody3D`, `const SEGMENTS := 28`, `const RING_MARGIN := 3.0`, `const GATE_WIDTH := 4.0`.
- Layers: rails and posts on a `StaticBody3D` with `collision_layer = PROPS`; the leaf on its own `StaticBody3D` with `collision_layer = PEN_GATE | PROPS` while closed and `0` while open (so the player and ponies are both stopped by a closed gate, and neither by an open one).

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
## The ring around a locked region. Two capsules identical except for their masks are
## driven at the gateway with move_and_slide, the way test_pen_gate.gd does it: a closed
## gate stops both; an open gate lets the player through; the rails stop the player at a
## plain segment either way.

const RegionFenceScene := preload("res://world/region_fence.tscn")
const RegionDataScript := preload("res://systems/region_data.gd")
const LayersScript := preload("res://world/collision_layers.gd")

var _world: Node3D
var _fence: RegionFence
var _region: RegionData


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = LayersScript.TERRAIN
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	_region = RegionDataScript.new()
	_region.id = &"test"
	_region.centre = Vector2(0.0, 0.0)
	_region.radius = 12.0
	_region.gate_yaw_degrees = 0.0
	_fence = RegionFenceScene.instantiate()
	_world.add_child(_fence)
	_fence.configure(_region, func(_x: float, _z: float) -> float: return 0.0)
	_fence.build()


func _walker(mask: int, from: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = LayersScript.PLAYER
	body.collision_mask = mask
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.3
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.65, 0.0)
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = from
	return body


## Drive `body` toward `target` for `frames` physics frames; returns how far it got.
func _drive(body: CharacterBody3D, target: Vector3, frames: int) -> float:
	var start := body.global_position
	for i in range(frames):
		var dir := (target - body.global_position)
		dir.y = 0.0
		body.velocity = dir.normalized() * 4.0
		body.move_and_slide()
		await wait_physics_frames(1)
	return (body.global_position - start).length()


func test_a_closed_gate_stops_the_player() -> void:
	var gate := _fence.gate_position()
	var outside := gate + Vector3(4.0, 0.0, 0.0)
	var inside := gate - Vector3(4.0, 0.0, 0.0)
	var player := _walker(LayersScript.WALKABLE, outside)
	var moved: float = await _drive(player, inside, 90)
	assert_lt(moved, 3.0, "the closed gate must stop her short of the ring")


func test_an_open_gate_lets_the_player_through_and_still_stops_a_pony() -> void:
	_fence.set_open(true)
	assert_true(_fence.is_open())
	var gate := _fence.gate_position()
	var outside := gate + Vector3(4.0, 0.0, 0.0)
	var inside := gate - Vector3(4.0, 0.0, 0.0)
	var player := _walker(LayersScript.WALKABLE, outside)
	var moved: float = await _drive(player, inside, 90)
	assert_gt(moved, 7.0, "the open gate must let her walk in")
	var pony := _walker(LayersScript.PONY_WALKABLE, outside)
	var pony_moved: float = await _drive(pony, inside, 90)
	assert_gt(pony_moved, 7.0, "an open gate is open to ponies too; the leash is what keeps residents in")


func test_the_rails_stop_the_player_away_from_the_gate() -> void:
	_fence.set_open(true)
	var ring: float = _region.radius + RegionFence.RING_MARGIN
	var outside := Vector3(0.0, 0.0, ring + 4.0)
	var inside := Vector3(0.0, 0.0, ring - 4.0)
	var player := _walker(LayersScript.WALKABLE, outside)
	var moved: float = await _drive(player, inside, 90)
	assert_lt(moved, 3.0, "a plain segment is a fence")


func test_reopening_and_closing_toggles_the_collider() -> void:
	_fence.set_open(true)
	assert_eq(_fence.gate_body().collision_layer, 0)
	_fence.set_open(false)
	assert_eq(_fence.gate_body().collision_layer, LayersScript.PEN_GATE | LayersScript.PROPS)
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Write region_fence.tscn** (a `Node3D` root named `RegionFence` with the script) and `region_fence.gd`:

```gdscript
class_name RegionFence
extends Node3D
## THE RING AROUND A LOCKED REGION. A regular polygon of rails and posts at the region's
## radius plus RING_MARGIN, with one segment replaced by a gate whose leaf carries the
## only collider a permit removes. Built from primitives the way game/world/pen.gd builds
## a paddock, and for the same reason: nothing under game/assets/converted/ is in git.
##
## LAYERS. Rails and posts are PROPS: the player is stopped by them (her mask includes
## PROPS) and so is every pony. The leaf is PROPS plus PEN_GATE while closed and nothing
## while open, so an open gate is open to everyone. Residents stay in their region by
## their leash, not by this fence; the fence's job is to keep the PLAYER out until she
## has paid, and to read as a border afterwards.

const LayersScript := preload("res://world/collision_layers.gd")
const PenScript := preload("res://world/pen.gd")

const SEGMENTS := 28
const RING_MARGIN := 3.0
const GATE_WIDTH := 4.0
const GATE_OPEN_DEGREES := 95.0
const GATE_SWING_DEGREES_PER_SECOND := 140.0

var _region: RegionData
var _ground := Callable()
var _rails: StaticBody3D
var _gate: StaticBody3D
var _hinge: Node3D
var _open := false
var _angle := 0.0
var _gate_world := Vector3.ZERO


func configure(region: RegionData, ground_sampler: Callable) -> void:
	_region = region
	_ground = ground_sampler


func _y(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else 0.0


## Build the ring. The gate is the segment whose midpoint bearing is closest to
## gate_yaw_degrees.
func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rails = StaticBody3D.new()
	_rails.name = "Rails"
	_rails.collision_layer = LayersScript.PROPS
	_rails.collision_mask = 0
	add_child(_rails)
	_gate = StaticBody3D.new()
	_gate.name = "Gate"
	_gate.collision_mask = 0
	add_child(_gate)
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	add_child(_hinge)

	var ring: float = _region.radius + RING_MARGIN
	var centre := Vector3(_region.centre.x, 0.0, _region.centre.y)
	var gate_bearing := deg_to_rad(_region.gate_yaw_degrees)
	var gate_index := 0
	var best := TAU
	for i in range(SEGMENTS):
		var mid := (float(i) + 0.5) * TAU / float(SEGMENTS)
		var diff: float = absf(angle_difference(mid, gate_bearing))
		if diff < best:
			best = diff
			gate_index = i

	var post_mat := PenScript._material_static(PenScript.POST_COLOR)
	var rail_mat := PenScript._material_static(PenScript.RAIL_COLOR)
	for i in range(SEGMENTS):
		var a0 := float(i) * TAU / float(SEGMENTS)
		var a1 := float(i + 1) * TAU / float(SEGMENTS)
		var p0 := centre + Vector3(cos(a0), 0.0, -sin(a0)) * ring
		var p1 := centre + Vector3(cos(a1), 0.0, -sin(a1)) * ring
		p0.y = _y(p0.x, p0.z)
		p1.y = _y(p1.x, p1.z)
		_post(p0, post_mat)
		if i == gate_index:
			_gate_segment(p0, p1, rail_mat)
		else:
			_rail_segment(_rails, p0, p1, rail_mat)


func _post(at: Vector3, mat: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(PenScript.POST_SIZE, PenScript.FENCE_HEIGHT + PenScript.POST_BURY, PenScript.POST_SIZE)
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at + Vector3(0.0, (PenScript.FENCE_HEIGHT - PenScript.POST_BURY) * 0.5, 0.0)
	_rails.add_child(mesh)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = box.size
	shape.shape = col
	shape.position = mesh.position
	_rails.add_child(shape)


## Three rails between two posts, on `body`. Rails follow the ground between the posts.
func _rail_segment(body: StaticBody3D, p0: Vector3, p1: Vector3, mat: StandardMaterial3D) -> void:
	var span := p1 - p0
	var length := span.length()
	var mid := (p0 + p1) * 0.5
	var yaw := atan2(-span.z, span.x)
	for h in PenScript.RAIL_HEIGHTS:
		var box := BoxMesh.new()
		box.size = Vector3(length, PenScript.RAIL_THICKNESS, PenScript.RAIL_DEPTH)
		box.material = mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position = mid + Vector3(0.0, h, 0.0)
		mesh.rotation.y = yaw
		mesh.rotation.z = -atan2(span.y, Vector2(span.x, span.z).length())
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var col := BoxShape3D.new()
		col.size = box.size
		shape.shape = col
		shape.position = mesh.position
		shape.rotation = mesh.rotation
		body.add_child(shape)


## The gate: a leaf hinged at p0, drawn under the hinge so it can swing, with its collider
## on `_gate` (which never moves; set_open() drops the layer instead).
func _gate_segment(p0: Vector3, p1: Vector3, mat: StandardMaterial3D) -> void:
	var span := p1 - p0
	var length := span.length()
	var yaw := atan2(-span.z, span.x)
	_hinge.position = p0
	_hinge.rotation.y = yaw
	var leaf_mat := PenScript._material_static(PenScript.GATE_COLOR)
	for h in PenScript.RAIL_HEIGHTS:
		var box := BoxMesh.new()
		box.size = Vector3(length, PenScript.RAIL_THICKNESS, PenScript.RAIL_DEPTH)
		box.material = leaf_mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position = Vector3(length * 0.5, h, 0.0)
		_hinge.add_child(mesh)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = Vector3(length, PenScript.FENCE_HEIGHT, PenScript.RAIL_DEPTH)
	shape.shape = col
	shape.position = (p0 + p1) * 0.5 + Vector3(0.0, PenScript.FENCE_HEIGHT * 0.5, 0.0)
	shape.rotation.y = yaw
	_gate.add_child(shape)
	_gate_world = (p0 + p1) * 0.5
	set_open(false)


func set_open(open: bool) -> void:
	_open = open
	_gate.collision_layer = 0 if open else (LayersScript.PEN_GATE | LayersScript.PROPS)


func is_open() -> bool:
	return _open


func gate_position() -> Vector3:
	return _gate_world


func gate_body() -> StaticBody3D:
	return _gate


func _process(delta: float) -> void:
	if _hinge == null:
		return
	var target: float = GATE_OPEN_DEGREES if _open else 0.0
	if is_equal_approx(_angle, target):
		return
	_angle = move_toward(_angle, target, GATE_SWING_DEGREES_PER_SECOND * delta)
	_hinge.rotation.y = atan2(-(_gate_world - _hinge.position).z, (_gate_world - _hinge.position).x) + deg_to_rad(-_angle)
```

`PenScript._material_static` and `PenScript.GATE_COLOR`: read `pen.gd`'s `_material(colour)` (instance method, line ~910) and `GATE_COLOR`. Add a `static func _material_static(colour: Color) -> StandardMaterial3D` to `pen.gd` that the instance method delegates to, so both fences share one material recipe; if `GATE_COLOR` does not exist under that name, use the constant `pen.gd` actually uses for its leaf. The hinge yaw in `_process` recomputes the segment's bearing from the stored points; keep the stored `yaw` in a member instead if that reads cleaner.

- [ ] **Step 4: Run test_region_fence.gd** (expect 4 passing), then test_pen.gd and test_pen_gate.gd (the `_material_static` extraction must not change the pen).

- [ ] **Step 5: Commit**

```bash
git add game/world/region_fence.gd game/world/region_fence.gd.uid game/world/region_fence.tscn game/world/pen.gd game/test/test_region_fence.gd game/test/test_region_fence.gd.uid
git commit -m "feat: RegionFence, a ring of rails with one gate a permit opens"
```

---

### Task 5: Zones and residents, the fences on the map, the permits wired

**Files:**
- Modify: `game/world/ranch.tscn` (four `ZoneMarker`s under `Zones`; four `RegionFence` instances under `Regions`)
- Modify: `game/world/ranch.gd` (build fences after the terrain, open them from `unlocks`, react to a permit purchase, prompt at a locked gate, `_report()` checks)
- Modify: `game/data/ponies/*.tres` (30 characters re-zoned per the regions table)
- Modify: `game/world/props.gd` (`LAYOUT` gains trees per region: 6 oaks and fats around the orchard, 8 pines around the everfree edge, 4 default trees by the lake, 5 pines by the night meadow, all OUTSIDE each ring by at least 4 m and outside every zone disc)
- Test: `game/test/test_roster_data.gd` (the "zoned ranch for now" test becomes "every zone a character names exists as a marker in ranch.tscn"), `game/test/test_props.gd` if it pins the prop count (read it)

**Interfaces:**
- `Ranch.get_region_fences() -> Array` (of `RegionFence`), `Ranch.is_region_open(zone: StringName) -> bool`, `Ranch.nearest_locked_gate() -> RegionFence` (within `GATE_PROMPT_RADIUS := 6.0`, else null).
- Toast at a locked gate, once per approach: `"This is %s. The permit costs %d bits at the market."` and at a just-opened gate: `"%s is open."`

- [ ] **Step 1: Scene edits**

Add four `ZoneMarker` nodes under `Zones` with `zone_id`, position `(centre.x, 0, centre.y)`, `spawn_radius = radius - 6`, `spawn_count = 3`, `roam_radius = 6`. Add a `Regions` Node3D (Task 3 may have added it for the water) and four `RegionFence` instances named `Fence_orchard` etc. The fences are configured and built by `ranch.gd`, not in the scene, because they need `height_at`.

- [ ] **Step 2: ranch.gd**

After the terrain builds and before the spawner runs:
```gdscript
	for region in _regions_registry().all():
		var fence := regions_root.get_node_or_null("Fence_" + String(region.id)) as RegionFence
		if fence == null:
			push_error("ranch: no RegionFence for region '%s' in ranch.tscn" % region.id)
			continue
		fence.configure(region, Callable(terrain, "height_at"))
		fence.build()
	_apply_permits()
```
with
```gdscript
## Open every fence whose permit is in the unlocks. On boot and after every purchase,
## the same way _apply_unlocks() reads the gear.
func _apply_permits() -> void:
	if _game_state == null:
		return
	for fence in get_region_fences():
		fence.set_open(_game_state.unlocks.has(String(fence.region().permit_id())))
```
(`RegionFence.region() -> RegionData` returns `_region`; add it in this task.) Call `_apply_permits()` from `_on_buy_requested()` after a successful buy (next to `_apply_unlocks()`), toasting `"%s is open." % region.display_name` when the bought item is a PERMIT. Add `_update_gate_prompt()` to `_physics_process()`: nearest locked fence whose `gate_position()` is within `GATE_PROMPT_RADIUS` of the player, prompt once per approach like the market prompt.

`_report()` gains: `"every region has a fence"`, `"a locked region's gate is solid to the player"` (a ray on `WALKABLE` across the closed orchard gate hits `fence.gate_body()`), `"a permit in the unlocks opens its gate"` (set `_game_state.unlocks` to include `permit_orchard`, call `_apply_permits()`, assert `is_open()`, then restore), `"every region zone has residents in the roster"` (`PonyRegistry.by_zone(zone)` non-empty for each region), and prints `RANCH regions=%d fences=%d open=%d`.

Update `_seat_plot_slots`-style seating: props.gd already seats by `height_at`; the fences seat their own posts.

- [ ] **Step 3: Re-zone the 30 `.tres` files** per the regions table: `spawn_zones = Array[StringName]([&"orchard"])` and so on. The 14 ranch characters keep `[&"ranch"]`.

- [ ] **Step 4: Update test_roster_data.gd**

Replace `test_every_character_is_zoned_ranch_for_now` with:
```gdscript
func test_every_zone_a_character_names_has_a_marker_and_every_marker_has_residents() -> void:
	var scene: PackedScene = load("res://world/ranch.tscn")
	var ranch := scene.instantiate()
	var marker_zones := {}
	for marker in ranch.get_node("Zones").get_children():
		marker_zones[marker.zone_id] = true
	ranch.free()
	var used := {}
	for id in _roster():
		for zone in _roster()[id].spawn_zones:
			assert_true(marker_zones.has(zone), "%s spawns in '%s', which has no ZoneMarker" % [id, zone])
			used[zone] = true
	for zone in marker_zones:
		assert_true(used.has(zone), "zone '%s' has a marker but nobody lives there" % zone)
```
Instantiating `ranch.tscn` without adding it to the tree does not run `_ready()`, so this is cheap; if it turns out to trigger `@onready` errors, read the `Zones` children from the `.tscn` text instead with `FileAccess` and a regex on `zone_id = &"..."`.

- [ ] **Step 5: props.gd LAYOUT** additions per the table; run `test_props.gd` and adjust any pinned count.

- [ ] **Step 6: Run the direct ranch scene and the full gate loop and the suite**

`RANCH_OK ponies=<n> props=<m>`: `n` is 10 plus 12 (four new markers, three each) = 22; `m` is 34 plus the new trees. Record both in the report and in the commit message; check `.github/workflows/smoke_run.sh` matches only the marker (it does today).

- [ ] **Step 7: Commit**

```bash
git add game/world/ranch.tscn game/world/ranch.gd game/data/ponies/ game/world/props.gd game/world/region_fence.gd game/test/test_roster_data.gd game/test/test_props.gd
git commit -m "feat: four regions with residents, fenced until their permits are bought"
```

---

### Task 6: The region gate, end to end

**Files:**
- Create: `game/scenes/test/region_test.gd`, `game/scenes/test/region_test.tscn` (hosted ranch, like `market_test.tscn`)
- Modify: `tools/run_tests.sh` (`MIN_TESTS`), `docs/testing.md` (a "The region gate" subsection beside the market one)

- [ ] **Step 1: Write the gate** (copy `market_test.gd`'s scaffold: `_set_check` with duplicate detection, `await ranch.gate_report_finished`, `state.reset()` then `ranch.rebind_economy()`, `_finish()` printing `REGION_OK checks=N` after the verdict, `quit(0 if all_ok else 1)`, watchdog 120 s). Checks, in order:

1. the ranch is hosted; the ranch's own report passed
2. four fences exist; all four are closed on a fresh state
3. the orchard's ponies spawned inside the orchard: for every spawned pony (`ranch.spawner.get_spawned()`) whose `data().spawn_zones` has `orchard`, `region.contains(Vector2(pos.x, pos.z))`
4. no orchard pony spawned on the ranch, and no ranch pony spawned in a region
5. the player is stopped by the closed orchard gate: place the player 4 m outside `gate_position()` along the gate's outward bearing, drive toward the inside for 90 physics frames using `Input.action_press("move_forward")` after aiming the camera rig at the gate (read how `market_test`/`capture_test` move the player; if driving through input is awkward in a hosted scene, use `PhysicsServer3D`-free direct `move_and_slide` on `ranch.player` with a set velocity), assert she moved less than 3 m
6. the permit is in the catalogue and unaffordable at 0 bits (`shop.can_buy(permit)` false)
7. fund via `get_economy().sell(LEGENDARY, 2)` (200 bits); buy `permit_orchard` through the market menu (`set_tab(BUY)`, find its row, `confirm()`); unlocks has `permit_orchard`; the fence is open; the other three are still closed
8. the player now walks through the same gate (moved more than 7 m)
9. buying the permit again is refused
10. save to a scratch slot; reset; rebind; load; `_apply_permits()` ran through `state_loaded`: the orchard fence is open again and the others closed
11. `is_region_open(&"orchard")` true, `is_region_open(&"lake")` false

- [ ] **Step 2: Run it until every label passes honestly.** Then the full gate loop (now eleven scenes plus the ranch) and the suite; set `MIN_TESTS`; add the docs subsection (no dashes).

- [ ] **Step 3: Commit**

```bash
git add game/scenes/test/region_test.gd game/scenes/test/region_test.gd.uid game/scenes/test/region_test.tscn tools/run_tests.sh docs/testing.md
git commit -m "test: the region gate, from a locked fence to a bought permit to a reloaded save"
```

---

## Self-review

**Spec coverage.** "The map grows... distinct places": Task 3 (size, tints, lake) and Task 5 (trees per region). "Each region is a ZoneMarker... with a zone_id": Task 5. "A locked region is a RegionGate: a visible barrier... with a bit price. Paying at the market clears it": Tasks 2, 4, 5 (the spec's `RegionGate` is realised as `RegionFence`, a ring with a gate, because an open map needs a barrier, not a doorway). "The save's existing unlocks array records which gates are open": Tasks 2 and 5, no version bump. "Ponies keep their leashes": unchanged. Testing: unit tests per system, a hosted gate, save round trip in the gate.

**Placeholder scan.** None. The one judgment left to the executor (how the terrain defers its build so the registry can be handed over) is stated with a recommended shape and a fallback.

**Type consistency.** `RegionData.permit_id()` and `Shop.permit_id_for()` both produce `"permit_<zone>"`; the registry test in Task 2 pins the shop rows against the region data. `RegionFence.set_open/is_open/gate_position/gate_body/region` are used by Task 5 and Task 6 as defined in Task 4. `Terrain.regions`, `build_water`, `grass_at` as defined in Task 3.
