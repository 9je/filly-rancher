class_name Props
extends Node3D
## The homestead: every static prop on the ranch, placed to scale, sat on the
## ground, and given collision.
##
## LOADED AT RUNTIME, NOT REFERENCED FROM THE SCENE FILE -- and that is a
## deliberate CI decision, not laziness. game/assets/converted/ is gitignored, so a
## CI checkout and a fresh clone have no props at all. The export-error gate in
## .github/workflows/build-and-smoke.yml fails the build if a scene statically
## references a resource that cannot be resolved, and ranch.tscn is now the MAIN
## SCENE, so a `[ext_resource path="res://assets/converted/props/..."]` line in it
## would break every CI run. Scanning PROP_DIR at runtime and skipping what is not
## there is docs/ci.md section 4's option (a): the ranch degrades gracefully to bare
## terrain instead of failing to export. ranch.gd then reports `assets=absent`
## explicitly, so a contentless ranch announces itself rather than passing silently.
##
## SCALE IS 1.5x AND THAT NUMBER IS NOT NEGOTIABLE HERE. docs/pipeline.md section 4
## derives it: Task 8 validated 3.0x against the old 4.28-unit ponies, and the
## Phase 1A metric rescale halved the pony side, so 3.0 * 2.138 / 4.276 = 1.5
## reproduces exactly the prop/pony relationship that was already judged to read
## correctly on screen. At 1.5x a Kenney 2-unit door module is 3 m, which clears the
## 2.14 m a pony actually needs (measured to the horn tip, NOT to the 1.16 m
## withers -- sizing anything pass-through off the withers figure produces doorways
## she cannot walk through).
##
## TREE_SCALE AND FAMILY_TREE ARE KEPT WITH NO LAYOUT ENTRY USING THEM. Slice R2's own
## placement pass (this file's LAYOUT) replanted every "kenney_tree_*" entry as an MLP
## species -- the owner's verdict on the Kenney Nature Kit was that its flat cyan canopy
## clashed with everything else on the map -- so nothing below reads FAMILY_TREE any more.
## Both stay for the family machinery `game/test/test_props.gd` pins (:32, :63, :127 all
## name them) and for anyone who ever replants a Kenney tree here again.
##
## ...WITH ONE PER-PROP EXCEPTION, and it is a documented defect, not a fudge.
## kenney_survival_structure.glb came through the FBX branch of the pipeline, and
## Blender's automatic FBX unit conversion is not reliable for this pack: the same
## model measures 2.0 units as Kenney's own GLB and 0.50 units after the FBX
## round-trip -- 4x undersized (docs/pipeline.md section 4, quirk 4). It ships at
## its native broken scale on purpose (that doc records quirks rather than papering
## over them), so the correction has to happen at map-build time, here, exactly
## once, next to the reason.
##
## PROPS ARE SEATED BY THEIR OWN BOUNDING BOX, NOT BY THEIR ORIGIN, because the
## Kenney kits do not agree with each other about where a model's origin is. Measured
## on this exact prop set: kenney_survival_structure and kenney_market_stall have
## their origin at the base, while kenney_windmill and kenney_watermill have theirs at
## the CENTRE of the model -- so dropping each prop at `y = ground` buried the
## windmill 2.34 m and the watermill 1.35 m, exactly half their height each, and left
## the other two correct. It looked like a layout mistake and was actually an asset
## convention mismatch, which is why the fix is a measurement (shift each prop until
## its AABB floor meets the terrain) rather than a per-prop y offset typed in by hand.
## ranch.gd then asserts the seating held, so "nothing floats and nothing sinks" is a
## checked claim rather than a hopeful one.
##
## EVERY PROP GETS COLLISION. Generated per-MeshInstance3D as a trimesh, because
## these are static, concave, and the player must not walk through a barn. Convex
## hulls would have sealed the windmill's arches and a box would have made every
## tree a crate.

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const LayersScript := preload("res://world/collision_layers.gd")

const PROP_DIR := "res://assets/converted/props/"

## docs/pipeline.md section 4. See the class comment.
const BASE_SCALE := 1.5

## ONE PONY HEIGHT (1 PH), in metres: the player's rendered body, hoof to ear tip, as
## game/test_input/test_scale.gd measures it in the world. SCALE.md sizes every asset on the
## map in multiples of it; code that has to ask for a size (region_dressing.gd's trees and
## standing stones) asks in PH through this. The test measures the pony afresh each run and
## would catch the roster drifting away from this number.
const PONY_HEIGHT := 2.19

## Metres a seated prop's bottom is pushed below the terrain surface. Small and
## deliberate: the ground is a 2 m-cell heightfield, so a prop with any footprint
## sits across a slightly curved surface, and a base seated at exactly y=ground
## shows a hairline of daylight under its uphill edge.
const SINK_BIAS := 0.05

## How high over its ground a foliage prop keeps collision. See _add_collision().
const FOLIAGE_COLLIDE_HEIGHT := 3.0

## A PROP WIDER THAN THIS, STANDING OFF THE FLAT APRON, GETS A PLINTH OF ITS OWN.
##
## seat() puts the bottom of a model's AABB SINK_BIAS below the ground height at ONE point.
## That is right for a tree and wrong for a barn: the flattest 13 by 10 m rectangle anywhere
## on this map outside the homestead apron still has 0.366 m of relief across it, and the
## barn's own site has 0.643 m. Seated at one point, a wide model shows daylight under one
## corner and buries the other, and the terrain passes through its floor plane, which is a
## horizontal face and therefore z fights.
##
## game/world/building.gd solved exactly this for the procedural buildings on 2026-08-31
## (FLOOR_TOP, SKIRT_DEPTH, PLINTH_INSET). A mesh prop cannot use that answer, because a
## Building BUILDS its own plinth and a .glb's floor is whatever the modeller drew. So the
## prop gets a solid box under it instead: seated against the LOWEST of nine samples across
## its own footprint, deep enough to bridge the measured relief, inset on every side so its
## own outer face is never coplanar with the model's. The terrain then always passes through
## the SIDE of an opaque box, which is the property the Building plinth buys.
##
## SKIRT_INSET is PLINTH_INSET's number for PLINTH_INSET's reason. SKIRT_MIN_DEPTH is what
## the box has UNDER the relief it is bridging, so a 0.64 m dip gets a 1.54 m box.
## WIDE_FOOTPRINT is the longer side at which one point seating stops being good enough.
const SKIRT_INSET := 0.06
const SKIRT_MIN_DEPTH := 0.90
const WIDE_FOOTPRINT := 4.0

## Turned earth, and deliberately not a colour any of the models use: a skirt that reads as
## part of the building is a building with a strangely tall base, while a skirt that reads
## as ground the building is standing in is what it actually is.
const SKIRT_COLOUR := Color(0.21, 0.17, 0.13)

## Per-file multiplier ON TOP of BASE_SCALE. Only ever for a prop whose shipped
## asset is at a known-wrong scale.
##
## kenney_survival_structure.glb IS NO LONGER IN LAYOUT and its entry below stays anyway.
## docs/pipeline.md section 4 quirk 5 calls it an open timber frame that "reads as farm
## equipment abandoned in a field"; the Ponyville General store stands where it used to,
## across the Market yard. The correction is a MEASUREMENT of a defect in that pack's FBX
## branch (2.0 units as Kenney's own GLB, 0.50 after the round trip), not a decoration on
## a layout line, so it is kept for anyone who re places the prop and so the doc that
## records the defect still has something to point at.
##
## THE MLP ROWS BELOW ARE THE SAME KIND OF MEASUREMENT, and they exist because MLP_SCALE
## was divided out of ONE model. saa_barn.glb is an SFM hero set piece drawn at 13.479 m;
## the rest of the six packs is authored at real world metres, which the gallery says
## plainly: an eight foot picnic table measures 2.438 m, a four foot bell housing 1.219 m,
## a skeeball cabinet 2.450 m. Multiplying those by 0.5193 gave a 9 cm basket, a knee high
## bell tower and an orchard whose trees stood shorter than the ponies under them.
##
## So the DEFAULT correction is 1.93, which is 1 / MLP_SCALE: it restores the metres the
## model was drawn at. Every model whose native size already reads correctly for the thing
## it depicts carries exactly that number. Any OTHER number means the shipped model is not
## the size of the thing its filename names, and the comment beside it says what it was
## targeted at instead. The yardstick throughout is the one the renders are judged by: a
## pony is 2.138 m to the horn tip, the homestead barn ridge is 4.9 m, saa_barn is 7.0 m.
##
## saa_barn.glb, pv_general.glb, pv_general_sign.glb and the six pv_*_b town buildings
## carry NO row on purpose, and that is a measurement too. The barn is the model the scale
## was derived from and ranch.gd fails if it stops standing at 7.00 m; the sign is authored
## to hang on the General and has to keep its own building's scale; the town row already
## measures 3.6 m to 7.4 m. school_cone.glb is left alone for the same reason: 0.95 m is
## already a traffic cone standing beside a 2.138 m pony.
##
## Every number below is target_height / (native_height * MLP_SCALE), with native_height
## read off scenes/test/model_gallery.tscn in its props mode.
const SCALE_FIX := {
	"kenney_survival_structure.glb": 4.0,  # FBX unit-conversion defect, quirk 4.
	# --- Sweet Apple Acres: the farm on the walk to the Orchard ----------------------
	"saa_shed.glb": 1.93,  # 3.51 m: native metres, half the height of the barn beside it.
	"saa_hay_pile.glb": 1.93,  # 2.11 m: native metres, a pile a pony cannot see over.
	"saa_hay_block.glb": 1.93,  # 0.70 m: native metres, one bale.
	"saa_wagon.glb": 1.93,  # 0.98 m at 3.25 m long: native metres, a farm cart.
	"saa_seed_bag.glb": 1.93,  # 0.65 m: native metres, a sack a pony could drag.
	"saa_water_chute.glb": 1.93,  # 0.83 m: native metres.
	"saa_wire_arch.glb": 1.93,  # 2.74 m: native metres, and a pony walks under it.
	"saa_fence_old.glb": 2.57,  # 1.00 m rail (0.46 PH), 5.4 m long. Native 0.75 m was a knee-high rail.
	"saa_corn_plant.glb": 3.83,  # 2.40 m: a stalk over a pony; native 1.21 m is a seedling.
	"saa_corn_plant_dead.glb": 3.83,  # the live stalk's number: the dead model is a stalk
	# FALLEN in its row (0.83 m high, 1.8 m across), so SCALE.md files it as a plant on the
	# ground, not as a standing crop. Stood up to a live stalk's 2.4 m it sprawled 5 m wide.
	"mlp_apple_tree.glb": 3.21,  # 5.60 m before jitter; the Kenney trees stood 6.2 m.
	"mlp_apple_tree_bare.glb": 3.36,  # 5.60 m: the same target, the same species.
	"mlp_bush.glb": 1.93,  # 0.80 m: native metres.
	"mlp_chicken_coop.glb": 1.93,  # 1.57 m: native metres.
	"mlp_farm_well.glb": 1.93,  # 1.42 m: native metres, a well a pony leans over.
	"mlp_crate.glb": 3.40,  # 0.70 m: native 0.40 m is a doll's crate.
	"mlp_basket.glb": 5.70,  # 0.50 m: native 0.17 m seats at 9 cm, effectively invisible.
	# --- the schoolyard --------------------------------------------------------------
	"school_belltower.glb": 4.33,  # 2.40 m: the pack ships the bell HOUSING, a 1.07 m cube.
	"school_sign.glb": 3.56,  # 2.20 m: a yard sign at pony eye height, not a 1.19 m plaque.
	"school_swingframe.glb": 1.93,  # 3.14 m: native metres, and a pony swings under it.
	"school_horseshoe.glb": 1.93,  # 1.22 m: native metres.
	"school_tetherball_pole.glb": 1.28,  # 3.60 m: native 5.43 m is a mast, not a pole.
	"school_picnic_table.glb": 3.03,  # 0.90 m: a 0.76 m table taken to pony scale. Skirted.
	# --- Las Pegasus, on the Strip ---------------------------------------------------
	"lp_skeeball.glb": 1.93,  # 2.46 m: native metres, a cabinet a pony can reach.
	"lp_dance_game.glb": 1.93,  # 2.53 m: native metres.
	"saa_small_dirt_pile.glb": 9.91,  # 0.35 m: native 0.068 m is a smear on the grass.
	# --- the treeline, which is MLP now ------------------------------------------------
	# THE KENNEY NATURE KIT'S FOLIAGE IS A FLAT CYAN SWATCH. docs/pipeline.md section 4
	# quirk 6 checked it: "leafsGreen" is the colour Kenney authored, not a colour space
	# bug, and the owner's word for the result was that the clashing asset style looks
	# terrible. Thirty nine of them stood on this map. These five replace them, at targets
	# taken from the orchard's own apple trees so the whole map's canopy agrees with itself.
	"saa_tree_wide.glb": 2.96,  # 6.20 m: the tallest canopy on the map.
	"saa_tree_narrow.glb": 3.15,  # 5.60 m: the orchard's own number.
	"saa_tree_dead_wide.glb": 2.77,  # 5.60 m: the same species, dead.
	"saa_tree_dead_narrow.glb": 2.98,  # 5.20 m: a thinner trunk reads shorter.
	"saa_dead_tree_large.glb": 4.05,  # 7.20 m: the Everfree's one landmark.
	# --- the town row and the Market stall: SCALE.md's house and stall rows --------------
	# ONE PONY HEIGHT (PH) IS 2.19 m, measured off the player in the world (SCALE.md). At the
	# MLP family's own MLP_SCALE these Ponyville houses stood 3.6 to 4.9 m, 1.6 to 2.2 PH: a
	# house barely taller than the pony at its door, which is the owner's playtest note word
	# for word. Each now stands about 7.0 m to the ridge, 3.2 PH.
	"pv_pink_b.glb": 1.92,  # 3.64 m -> 7.0 m.
	"pv_ogb_1.glb": 1.43,  # 4.88 m -> 7.0 m.
	"pv_courtyard_b.glb": 1.56,  # 4.48 m -> 7.0 m.
	"pv_courtyard_b_balcony.glb": 1.56,  # 4.48 m -> 7.0 m.
	"pv_ogb_2.glb": 1.68,  # 4.16 m -> 7.0 m.
	"pv_balcony_b.glb": 1.91,  # 3.66 m -> 7.0 m.
	# A Kenney piece, so ON TOP of BASE_SCALE: 1.86 m was an awning lower than the pony
	# standing under it. 3.06 m is 1.4 PH.
	"kenney_market_stall.glb": 1.65,
}

## Category-wide multiplier ON TOP of BASE_SCALE, for a "kenney_tree_*" entry, IF one is
## ever planted again. No LAYOUT entry uses it now -- see the class comment -- but the
## number stays: the Nature Kit trees are shipped at their intended scale, they are just
## stylised too small to read as trees once ponies and a real barn are standing next to
## them, and that measurement does not stop being true because the map stopped using it.
const TREE_SCALE := 3.0

## THE MLP FAMILY'S OWN BASE SCALE, and it REPLACES BASE_SCALE rather than multiplying it.
## BASE_SCALE is a Kenney kit number (docs/pipeline.md section 4 derives it from a 2 unit
## Kenney door module); a Source engine model converted by tools/convert_props.sh arrives
## with the inch to metre conversion already baked into its vertex data by SourceIO, at
## whatever size a 2015 SFM modeller drew it. Those are two unrelated conventions and
## multiplying one by the other has no meaning.
##
## MEASURED, NOT CHOSEN. scenes/test/model_gallery.tscn -- --props loads every converted
## prop and prints the world AABB of each; MLP_SCALE is MLP_TARGET_BARN_RIDGE divided by
## the native height that gate reported for saa_barn.glb. ranch.gd then measures the
## seated barn and fails if it does not stand at the target, so the number below and the
## barn on the map cannot drift apart silently.
const MLP_TARGET_BARN_RIDGE := 7.0

## From the run above: scenes/test/model_gallery.tscn -- --props reported saa_barn.glb at
## 13.479 m tall as converted, so MLP_TARGET_BARN_RIDGE / 13.479 = 0.5193. Re-run
## that gate and redo this division if tools/convert_props.sh's export ever changes shape.
const MLP_SCALE := 0.5193

## THE FAMILY A LAYOUT ENTRY BELONGS TO, and the base scale each family is built at.
##
## Three, and they are three different measuring conventions rather than three tastes:
## a Kenney kit piece (BASE_SCALE, derived from a 2 unit door module), a Kenney Nature Kit
## tree (BASE_SCALE again, then TREE_SCALE on top, because the kit's trees are stylised
## shorter than a pony), and an MLP prop converted out of a Source model (MLP_SCALE, which
## replaces BASE_SCALE outright: see its own comment).
##
## An entry may name its family explicitly. An entry that does not is a Kenney piece,
## unless its file begins with "kenney_tree", which is the rule the shipped treeline
## already follows and which is why 50 layout entries did not have to be edited to say so.
const FAMILY_KENNEY := &"kenney"
const FAMILY_TREE := &"tree"
const FAMILY_MLP := &"mlp"

const FAMILY_SCALE := {
	&"kenney": BASE_SCALE,
	&"tree": BASE_SCALE * TREE_SCALE,
	&"mlp": MLP_SCALE,
}

## Node name prefixes that are foliage rather than structure. ranch.gd frames its shots and
## runs its camera-against-a-wall probe against "every prop that is not one of these": a
## canopy is a bad obstacle to prove a camera with, because the arm may be stopping on a
## leaf a player would walk straight under.
const FOLIAGE_PREFIXES := ["kenney_tree", "mlp_apple_tree", "saa_tree", "saa_dead_tree"]

## THE OPEN GROUND, reserved for Phase 1B's pen plots. Centre and half-extent in
## metres, on XZ. Nothing is placed here, no pony spawns here, and ranch.gd asserts
## both -- an "open area" that quietly grew a tree in it is exactly the kind of
## layout regression nobody notices until the feature that needed the space lands.
## (-14, 15.5), was (-14, 13): moved 2.5 m south with the four Plots slots in ranch.tscn when
## the Market grew to SCALE.md's house size -- its south-west wall would otherwise have stood
## over the corner of slot 1 (docs/playtest_fixes/scale.md).
const PEN_PLOTS_CENTRE := Vector2(-14.0, 15.5)
const PEN_PLOTS_HALF_EXTENT := 9.0

## The homestead layout, hand-composed rather than scattered randomly.
##
## Read as a picture: the stall is the clutter that makes a yard look lived in; trees ring
## the open country and thin out toward the buildings, in MLP species since slice R2 (the
## Kenney Nature Kit's flat cyan canopy was the owner's own example of a clashing style),
## so the homestead reads as a clearing somebody made rather than a field with objects
## dropped on it. `y` is never specified -- every prop is sat on height_at() so nothing
## floats and nothing sinks.
##
## `s` is an optional per-entry size jitter, applied on top of BASE_SCALE (and of
## SCALE_FIX). Fixed values rather than an RNG draw: a hand-varied treeline is
## reproducible, and reproducibility is what makes a screenshot regression legible.
## The ranch's OWN buildings are still not in here and still not meshes: game/world/
## building.gd assembles them from primitives, because they are in git, they exist in CI
## and in a fresh clone, and their doorways are asserted against MIN_DOOR_CLEARANCE. What
## the MLP props below are is scenery: a farm on the walk to the Orchard, a shop across the
## yard, a town on the road north. Nothing here is ever walked into.
const LAYOUT := [
	# --- yard fixtures, all inside Terrain's flat apron ---------------------------
	# The windmill and the watermill came off the map in slice R2: game/world/building.gd's
	# own header calls them a bare X of sails and a bare waterwheel, and the owner's verdict
	# on the clashing Kenney silhouette applied to these two as much as to the treeline.
	# (3.8, 6.5), not (2.0, 3.0): at its SCALE.md size the stall would stand on the foot of the
	# Market's own door ramp, and the Depot's west wall, both of which grew to SCALE.md's house
	# size (docs/playtest_fixes/scale.md).
	{"file": "kenney_market_stall.glb", "at": Vector2(10.5, -9.0), "yaw": 270.0},
	# --- treeline, replanted MLP in slice R2 --------------------------------------
	# SAME COORDINATES, SAME YAW, ONLY THE SPECIES AND THE FAMILY CHANGED. Every `at` below
	# was already verified clear of every region fence ring, every ZoneMarker disc and the
	# pen-plot clearing (test_props.gd:148 and :155 both assert it); reusing them cannot
	# break a clearance that was already checked. Oaks and fats, the map's broad canopies,
	# become saa_tree_wide; the homestead's own default and pine trunks become
	# saa_tree_narrow, the same species the orchard already plants.
	{"file": "saa_tree_wide.glb", "at": Vector2(-25.0, -21.0), "yaw": 0.0, "s": 1.15, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(-26.0, -8.0), "yaw": 40.0, "s": 1.25, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(-5.0, -27.0), "yaw": 200.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(8.0, -28.0), "yaw": 75.0, "s": 0.95, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(24.0, -20.0), "yaw": 150.0, "s": 1.30, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(31.0, -2.0), "yaw": 20.0, "s": 1.10, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(26.0, 14.0), "yaw": 260.0, "s": 1.00, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(14.0, 27.0), "yaw": 300.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(-33.0, 10.0), "yaw": 210.0, "s": 1.25, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(-31.0, -25.0), "yaw": 15.0, "s": 1.10, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(37.0, -31.0), "yaw": 130.0, "s": 1.05, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(-17.0, -32.0), "yaw": 245.0, "s": 0.95, "family": &"mlp"},
	# Copses rather than an even scatter: two or three trunks together read as
	# woodland, evenly-spaced singles read as a car park.
	{"file": "saa_tree_narrow.glb", "at": Vector2(-27.0, -14.0), "yaw": 60.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(-24.0, -17.0), "yaw": 190.0, "s": 0.95, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(30.0, 18.0), "yaw": 100.0, "s": 1.10, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(33.0, 22.0), "yaw": 25.0, "s": 1.25, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(-12.0, -36.0), "yaw": 140.0, "s": 1.15, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(45.0, -12.0), "yaw": 310.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(-42.0, -6.0), "yaw": 80.0, "s": 1.30, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(-40.0, 24.0), "yaw": 45.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_tree_wide.glb", "at": Vector2(-43.0, 20.0), "yaw": 260.0, "s": 1.00, "family": &"mlp"},
	# One inside the clearing, for shade and to break up the yard. Its neighbour at
	# (17, 7.5) came out when the yard grew crates, a basket, a well and a coop; a shade
	# tree in the middle of that is a tree in the middle of a yard.
	{"file": "saa_tree_wide.glb", "at": Vector2(-24.5, 4.5), "yaw": 165.0, "s": 1.10, "family": &"mlp"},
	# --- the regions -------------------------------------------------------------
	# Slice 3's four regions (game/data/regions/*.tres) are 60 m and more from the
	# homestead, and the treeline above stops at about 45 m: without these, a region
	# read as a coloured patch of grass with a fence round it and nothing else on the
	# horizon. Each region gets the planting its name promises, and each species is the
	# one whose silhouette says the name: orchard oaks and fats, everfree pines, willowy
	# defaults by the lake, a thin line of pines along the night meadow.
	#
	# EVERY ONE OF THEM STANDS OUTSIDE ITS REGION'S FENCE, by at least 4 m past the ring
	# (RegionFence.RING_MARGIN puts that at radius + 3), and outside every ZoneMarker
	# disc on the map. Both matter: a trunk inside the ring is a trunk a resident can
	# spawn inside of (the spawner's prop reroll only fires when her ground ray HITS the
	# prop, which a canopy edge does not), and a trunk ON the ring is a tree growing
	# through a fence rail. Planted outside, they read as the country the fence is the
	# edge of, which is the whole job a boundary fence has on a map this size.
	# The Orchard, (72, 40) r 22: apples on the high ground, none across the west gate.
	# APPLE TREES, ON THE SAME SIX POINTS. The Kenney Nature Kit's foliage is a flat
	# cyan/mint swatch (docs/pipeline.md section 4 quirk 6: it is Kenney's authored
	# "leafsGreen" colour, checked and not a colour space bug), which read as a lawn
	# ornament in an orchard the player pays a permit to reach. These six coordinates are
	# unchanged on purpose: each sits at exactly radius 31 from the region centre, which is
	# the fence ring plus the 4 m every planted tree clears it by, and reusing them cannot
	# break a clearance that was already verified.
	{"file": "mlp_apple_tree.glb", "at": Vector2(101.1, 50.6), "yaw": 25.0, "s": 1.20, "family": &"mlp"},
	{"file": "mlp_apple_tree.glb", "at": Vector2(87.5, 66.8), "yaw": 140.0, "s": 1.10, "family": &"mlp"},
	{"file": "mlp_apple_tree_bare.glb", "at": Vector2(66.6, 70.5), "yaw": 265.0, "s": 1.25, "family": &"mlp"},
	{"file": "mlp_apple_tree.glb", "at": Vector2(48.3, 59.9), "yaw": 60.0, "s": 1.05, "family": &"mlp"},
	{"file": "mlp_apple_tree.glb", "at": Vector2(87.5, 13.2), "yaw": 195.0, "s": 1.15, "family": &"mlp"},
	{"file": "mlp_apple_tree_bare.glb", "at": Vector2(98.8, 24.5), "yaw": 310.0, "s": 1.20, "family": &"mlp"},
	# The Everfree Edge, (-74, -49) r 24: the densest planting on the map, and the
	# darkest, so the corner of the world the palette already made gloomy also LOOKS
	# like woodland rather than like a lawn at dusk. Dead trunks now, not live pines:
	# saa_tree_dead_narrow for six of the eight, and saa_dead_tree_large -- the Everfree's
	# one landmark -- at the two coordinates that stood furthest into the gloom.
	{"file": "saa_tree_dead_narrow.glb", "at": Vector2(-62.7, -18.0), "yaw": 15.0, "s": 1.30, "family": &"mlp"},
	{"file": "saa_tree_dead_narrow.glb", "at": Vector2(-79.7, -16.5), "yaw": 105.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_dead_tree_large.glb", "at": Vector2(-95.2, -23.7), "yaw": 200.0, "s": 1.35, "family": &"mlp"},
	{"file": "saa_tree_dead_narrow.glb", "at": Vector2(-105.0, -37.7), "yaw": 285.0, "s": 1.15, "family": &"mlp"},
	{"file": "saa_tree_dead_narrow.glb", "at": Vector2(-105.9, -57.5), "yaw": 40.0, "s": 1.30, "family": &"mlp"},
	{"file": "saa_tree_dead_narrow.glb", "at": Vector2(-95.2, -74.3), "yaw": 150.0, "s": 1.25, "family": &"mlp"},
	{"file": "saa_dead_tree_large.glb", "at": Vector2(-76.9, -81.9), "yaw": 230.0, "s": 1.35, "family": &"mlp"},
	{"file": "saa_tree_dead_narrow.glb", "at": Vector2(-57.5, -77.6), "yaw": 320.0, "s": 1.20, "family": &"mlp"},
	# The Lake, (60, -62) r 24: four only, and spread wide. The water is the thing to
	# look at there, and a ring of trunks around it would be a hedge round a pond.
	{"file": "saa_tree_narrow.glb", "at": Vector2(90.1, -51.1), "yaw": 70.0, "s": 1.15, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(29.9, -72.9), "yaw": 185.0, "s": 1.25, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(49.1, -92.1), "yaw": 250.0, "s": 1.10, "family": &"mlp"},
	{"file": "saa_tree_narrow.glb", "at": Vector2(76.0, -89.7), "yaw": 330.0, "s": 1.20, "family": &"mlp"},
	# The Night Meadow, (-61, 69) r 24: a windbreak along the far side, leaving the
	# south-east open toward the homestead so the walk out to it has a view. Dead wide
	# trunks: the same species as the Everfree, a wider silhouette to break up the skyline.
	{"file": "saa_tree_dead_wide.glb", "at": Vector2(-33.3, 85.0), "yaw": 50.0, "s": 1.15, "family": &"mlp"},
	{"file": "saa_tree_dead_wide.glb", "at": Vector2(-55.4, 100.5), "yaw": 125.0, "s": 1.30, "family": &"mlp"},
	{"file": "saa_tree_dead_wide.glb", "at": Vector2(-81.6, 93.5), "yaw": 210.0, "s": 1.20, "family": &"mlp"},
	{"file": "saa_tree_dead_wide.glb", "at": Vector2(-93.0, 69.0), "yaw": 285.0, "s": 1.25, "family": &"mlp"},
	{"file": "saa_tree_dead_wide.glb", "at": Vector2(-81.6, 44.5), "yaw": 355.0, "s": 1.15, "family": &"mlp"},
	# --- Sweet Apple Acres, on the walk out to the Orchard --------------------------
	# APPLEJACK'S FARM, NOT THE PLAYER'S. The homestead's own barn is still the same
	# procedural shell (game/world/building.gd, `Buildings/Barn` in ranch.tscn) -- it just
	# wears saa_barn.glb now, the same hero model the Depot, the Market and the Farmhouse
	# wear their own PonySFM pieces. This is that SAME model standing a second time, 60 m
	# away at the farm the orchard belongs to, on the walk out to it: a deliberate reuse
	# (the pack ships one barn), not an accident. This entry is scenery either way: an MLP
	# mesh prop here is never walked into. No attendant stands at one, no dock marker sits
	# on one, and ranch.gd checks that no prop's collider reaches inside a building's
	# interaction radius, so the only doors the game opens stay procedural.
	#
	# The barn, the shed and the town row carry "skirt": true. So do the four old fence
	# rails: at their corrected scale each is 4.06 m long, which is past WIDE_FOOTPRINT,
	# and a rail seated at one point across four metres of sloping pasture is exactly the
	# case the skirt exists for. Everything within 29 m of the Orchard centre (72, 40) is
	# inside its fence ring plus the 4 m margin every prop clears it by, so nothing below
	# is: test_props.gd checks that on every entry.
	{"file": "saa_barn.glb", "at": Vector2(41.0, 51.3), "yaw": 205.0, "family": &"mlp", "skirt": true},
	{"file": "saa_shed.glb", "at": Vector2(34.0, 45.0), "yaw": 160.0, "family": &"mlp", "skirt": true},
	{"file": "saa_wagon.glb", "at": Vector2(46.0, 58.0), "yaw": 75.0, "family": &"mlp"},
	{"file": "saa_hay_pile.glb", "at": Vector2(35.0, 42.0), "yaw": 20.0, "family": &"mlp"},
	{"file": "saa_hay_pile.glb", "at": Vector2(37.5, 40.5), "yaw": 200.0, "family": &"mlp", "s": 0.90},
	{"file": "saa_wire_arch.glb", "at": Vector2(32.0, 52.0), "yaw": 115.0, "family": &"mlp"},
	{"file": "saa_water_chute.glb", "at": Vector2(34.0, 66.0), "yaw": 250.0, "family": &"mlp"},
	{"file": "saa_seed_bag.glb", "at": Vector2(33.0, 47.0), "yaw": 40.0, "family": &"mlp"},
	{"file": "saa_fence_old.glb", "at": Vector2(30.0, 48.0), "yaw": 0.0, "family": &"mlp", "skirt": true},
	{"file": "saa_fence_old.glb", "at": Vector2(30.0, 54.0), "yaw": 0.0, "family": &"mlp", "skirt": true},
	{"file": "saa_fence_old.glb", "at": Vector2(49.0, 63.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "saa_fence_old.glb", "at": Vector2(48.0, 67.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	# The corn patch: two rows of six. The two dead stalks are placed, not drawn from an
	# RNG, for the same reason the treeline's size jitter is: a hand varied row is
	# reproducible, and reproducibility is what makes a screenshot regression legible.
	{"file": "saa_corn_plant.glb", "at": Vector2(30.0, 58.0), "yaw": 10.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(33.0, 58.0), "yaw": 200.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(36.0, 58.0), "yaw": 95.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(39.0, 58.0), "yaw": 280.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(42.0, 58.0), "yaw": 150.0, "family": &"mlp"},
	{"file": "saa_corn_plant_dead.glb", "at": Vector2(45.0, 58.0), "yaw": 25.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(30.0, 61.0), "yaw": 320.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(33.0, 61.0), "yaw": 60.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(36.0, 61.0), "yaw": 240.0, "family": &"mlp"},
	{"file": "saa_corn_plant_dead.glb", "at": Vector2(39.0, 61.0), "yaw": 130.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(42.0, 61.0), "yaw": 300.0, "family": &"mlp"},
	{"file": "saa_corn_plant.glb", "at": Vector2(45.0, 61.0), "yaw": 175.0, "family": &"mlp"},
	# Hedging, so the yard has an edge that is not a fence.
	{"file": "mlp_bush.glb", "at": Vector2(38.0, 43.5), "yaw": 0.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(42.0, 42.0), "yaw": 140.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(33.0, 56.0), "yaw": 260.0, "family": &"mlp"},
	# Apple trees along the walk itself, so the orchard starts before the fence does.
	{"file": "mlp_apple_tree.glb", "at": Vector2(30.0, 40.0), "yaw": 75.0, "family": &"mlp", "s": 1.05},
	{"file": "mlp_apple_tree.glb", "at": Vector2(30.0, 44.0), "yaw": 30.0, "family": &"mlp", "s": 1.10},
	{"file": "mlp_apple_tree.glb", "at": Vector2(33.0, 50.0), "yaw": 150.0, "family": &"mlp", "s": 1.00},
	{"file": "mlp_apple_tree.glb", "at": Vector2(47.0, 60.0), "yaw": 245.0, "family": &"mlp", "s": 1.15},
	{"file": "mlp_apple_tree.glb", "at": Vector2(38.0, 64.0), "yaw": 300.0, "family": &"mlp", "s": 1.05},
	{"file": "mlp_apple_tree_bare.glb", "at": Vector2(27.0, 64.0), "yaw": 100.0, "family": &"mlp", "s": 1.10},
	# --- Ponyville General is gone from here in slice R2 -----------------------------
	# IT NEVER STOOD ALONE AGAIN AFTER TASK 3. It used to stand BESIDE the Market as its
	# own free-standing pv_general.glb, a stand-in for a shop the Market itself did not
	# yet wear; task 3 put that same model, resized, on the Market building proper
	# (game/world/building.gd, ranch.tscn), so the two entries that used to stand here --
	# pv_general.glb at (19.0, -2.0) and its sign at (-1.0, 5.0) -- were a duplicate store
	# from that point on. Removed rather than left as clutter: the Market wears the model
	# now, and the census counts it once, under Buildings, the way it always counted the
	# barn.
	# --- the town row, on the road north -------------------------------------------------
	# A ROAD, AND SIX BUILDINGS THAT ARE NOT THE RANCH'S OWN. The Farmhouse, the Board and
	# the Depot wear pv_wide_b, pv_bridged_b and pv_tower_b now (slice R2, ranch.tscn), so
	# the row uses the three that are left plus the three new pieces
	# tools/prop_manifest.txt gained. SOME OF THESE ARE TWINS, and that is a stated choice
	# rather than an oversight: pv_tower_b stands here AND on the Depot, pv_courtyard_b and
	# pv_pink_b each stand here once AND again on the palace facade (game/world/
	# palace_facade.gd). The packs this map is built from ship one of each hero piece; a
	# second sighting 30 m and more away reads as the same town's architecture repeating
	# itself, not as a copy-paste seam, and every placement rule this file already checks
	# (region clearance, breathing room, pen-plot exclusion) runs on each entry
	# independently regardless of how many other entries share its file.
	#
	# THE ROAD ITSELF IS NOT A PROP ANY MORE. Sixteen `saa_dirt_road.glb` tiles used to stand
	# here, re-spaced to 2.0 m to overlap their own neighbours after the first version (2.28 m,
	# their native seated length) gapped on the 0.70 m of relief this run climbs. Tightening
	# the spacing did not fix it: the re-review's own render of `15_town_row_north_road.png`
	# still showed sixteen half-buried plates with grass between every pair, because a rigid,
	# flat, 0.155 m-thick tile cannot bend to follow ground that climbs under it -- the far
	# half of each tile sinks below grade no matter how tightly the tiles are packed. Removed
	# outright rather than spaced a third way (whole-branch review 2026-09-05 F3, re-review
	# 2026-09-06): the controller's ruling is that a road on sloped ground is PAINTED into the
	# terrain instead of laid on top of it. See `game/world/terrain.gd`'s `PATH_POINTS` and
	# `game/world/terrain.gdshader`'s path mask -- same centreline (x = 1.5), same run,
	# conforming to the real height field by construction because it IS the height field,
	# with no plate, no seam and no step to gap.
	{"file": "pv_pink_b.glb", "at": Vector2(15.0, 36.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_ogb_1.glb", "at": Vector2(15.0, 43.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	{"file": "pv_courtyard_b.glb", "at": Vector2(15.0, 50.0), "yaw": 270.0, "family": &"mlp", "skirt": true},
	# The tall courtyard-balcony block stands at z 36, BEHIND shot 19's camera (aim
	# (-10, 61.6), eye offset -22 puts the lens near z 39.6): at z 50 it cropped the
	# marquee out of the one screenshot that exists to showcase it. The shorter
	# balcony_b takes z 50; the street keeps all three buildings either way.
	# THE WEST ROW STEPPED SOUTH WHEN IT GREW (z 31 / 39.5 / 48, was 36 / 43 / 50): at SCALE.md's
	# house size pv_ogb_2 is 8.9 m along the street and the three no longer fit between z 33
	# and the Palace's own front at z 53.9 (docs/playtest_fixes/scale.md).
	{"file": "pv_courtyard_b_balcony.glb", "at": Vector2(-12.0, 31.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "pv_ogb_2.glb", "at": Vector2(-12.0, 39.5), "yaw": 90.0, "family": &"mlp", "skirt": true},
	{"file": "pv_balcony_b.glb", "at": Vector2(-12.0, 48.0), "yaw": 90.0, "family": &"mlp", "skirt": true},
	# --- the schoolyard, west of the road --------------------------------------------
	# A SCHOOLYARD AND NO SCHOOL, and that is the pack rather than an omission.
	# ponysfm-schoolhouse ships school_roof, school_door, school_window, school_sign,
	# porchroof, porchtop, support_beam_school and belltower: a modular kit for a Source
	# map with no assembled building in it, the same trap docs/pipeline.md section 4 quirk
	# 5 records for the Kenney Fantasy Town Kit. So the bell tower stands over a yard with
	# swings, a horseshoe pit, a tetherball pole, a picnic table and a cone, and the
	# schoolhouse is a building this project does not have an asset for.
	#
	# The pack's swingseat.mdl is not converted: Props.seat() puts the bottom of a model on
	# the ground, so a seat meant to hang from the frame would be placed standing on it.
	#
	# The picnic table carries a skirt and nothing else here does. At 0.90 m tall it is
	# 3.84 m by 2.70 m on the ground, and turned 45 degrees that is a 4.62 m world AABB,
	# past WIDE_FOOTPRINT on a yard that is nowhere near the flat apron.
	{"file": "school_belltower.glb", "at": Vector2(-26.0, 58.0), "yaw": 100.0, "family": &"mlp", "skirt": true},
	{"file": "school_sign.glb", "at": Vector2(-22.0, 54.0), "yaw": 120.0, "family": &"mlp"},
	{"file": "school_swingframe.glb", "at": Vector2(-30.0, 55.0), "yaw": 20.0, "family": &"mlp"},
	{"file": "school_horseshoe.glb", "at": Vector2(-30.0, 61.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "school_tetherball_pole.glb", "at": Vector2(-23.0, 61.0), "yaw": 0.0, "family": &"mlp"},
	{"file": "school_picnic_table.glb", "at": Vector2(-27.0, 63.0), "yaw": 45.0, "family": &"mlp", "skirt": true},
	{"file": "school_cone.glb", "at": Vector2(-21.0, 58.0), "yaw": 0.0, "family": &"mlp"},
	# --- Las Pegasus, on the Strip -----------------------------------------------------
	# THE CLEAR BAND BETWEEN THE PALACE AND THE RACE TRACK: x in [-2, 18], z in [67, 72].
	# The Palace's own rectangle is x in [-17, -3], z in [57.1, 66.1]; race_track.gd's south
	# rail is at z = 87.8 with the near one at z = 72.2; strip.gd's lamp ring is radius 21
	# about (0, 74), so both of these stand inside the ring rather than in it, and
	# Strip.avoid_footprint() is not asked to drop a lamp for them.
	#
	# They are cabinets, not tables: the games the player actually plays are casino_menu's,
	# and nothing here is an interaction candidate. They are what makes the Strip look like
	# somewhere people go.
	{"file": "lp_skeeball.glb", "at": Vector2(4.0, 69.0), "yaw": 180.0, "family": &"mlp", "skirt": true},
	{"file": "lp_dance_game.glb", "at": Vector2(11.0, 69.0), "yaw": 180.0, "family": &"mlp", "skirt": true},
	# --- the boardwalk up to the Palace -------------------------------------------------
	# THE APPROACH IS THE HALF OF A DESTINATION NOBODY BUILDS. The Palace's door faces world
	# minus Z at (-10, 57.1), which sits INSIDE its own PALACE_RADIUS (6.0 from (-10, 61.6)):
	# a solid road tile cannot pave the last stretch to the door without ranch.gd calling it
	# an intrusion, so the boardwalk runs a narrow lane south of the building instead --
	# each tile at yaw 0 is only 2.28 m wide here rather than the town row's 10.52 m, because
	# it is spaced ALONG its own long axis instead of across it -- and stops at a small
	# clearing a few strides short of the door, which the bushes dress as the entrance. Every
	# tile clears the Palace's own rectangle (x in [-17, -3], z in [57.1, 66.1]), the arcade
	# band (x in [-2, 18], z in [67, 72]) and PALACE_RADIUS itself, the last with room to
	# spare (gap 7.65 m and 10.46 m respectively, both past the 6.0 m the door opens at).
	# The boardwalk's own two saa_dirt_road tiles came off with the road's sixteen (round 2
	# re-review): the terrain-painted path serves the walk up, and a rigid plate on 0.36 to
	# 0.80 m of relief was the same half-buried plank the road fix exists to end.
	{"file": "mlp_bush.glb", "at": Vector2(-3.0, 54.0), "yaw": 200.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(-9.0, 53.5), "yaw": 40.0, "family": &"mlp"},
	# --- the homestead yard: a farmstead, not a field with objects dropped in it ---------
	# RE-LAID 2026-10-25 with the buildings round the plaza (owner playtest: "all the
	# buildings feel very randomly placed"): the barn's working corner north-west, the well
	# and the coop either side of the Farmhouse, the stall and its crates on the Market's
	# north end.
	# READ AS A PICTURE. The shed stands beside the barn with the wagon between them and hay
	# stacked against the shed's wall, which is what a working yard looks like; the well and
	# the coop sit on the house side; the crates and the basket cluster by the market stall
	# so the shop has a delivery corner rather than a scatter of clutter. Every coordinate
	# clears the Market's own new footprint (10.62 m wide at 45 degrees about (-2, -1),
	# reaching 5.9 m on the diagonal) by at least 0.6 m, and clears every interaction radius
	# on the map by more.
	{"file": "saa_shed.glb", "at": Vector2(-22.0, -12.0), "yaw": 90.0, "family": &"mlp"},
	{"file": "saa_wagon.glb", "at": Vector2(-20.5, -8.5), "yaw": 200.0, "family": &"mlp"},
	{"file": "saa_hay_block.glb", "at": Vector2(-21.5, -16.0), "yaw": 15.0, "family": &"mlp"},
	{"file": "saa_hay_pile.glb", "at": Vector2(-17.0, -20.5), "yaw": 40.0, "family": &"mlp"},
	{"file": "saa_seed_bag.glb", "at": Vector2(-13.8, -11.0), "yaw": 300.0, "family": &"mlp"},
	{"file": "mlp_farm_well.glb", "at": Vector2(-4.5, -16.5), "yaw": 60.0, "family": &"mlp"},
	{"file": "mlp_chicken_coop.glb", "at": Vector2(9.5, -17.0), "yaw": 180.0, "family": &"mlp"},
	{"file": "mlp_crate.glb", "at": Vector2(12.0, -11.2), "yaw": 30.0, "family": &"mlp"},
	{"file": "mlp_basket.glb", "at": Vector2(9.0, -11.5), "yaw": 0.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(-3.5, -10.5), "yaw": 120.0, "family": &"mlp"},
	{"file": "mlp_bush.glb", "at": Vector2(23.5, -12.0), "yaw": 20.0, "family": &"mlp"},
	# (The small dirt pile that stood at (-18.5, 3.5) is gone: in the toon light it read as a
	# flat yellow blob with marks on it, and nobody could tell what it was. PT7, playtest
	# 2026-11-05 item 27.)
]

var _placed: Array[Node3D] = []
var _shape_count := 0
var _missing: Array[String] = []
var _entries: Array[Dictionary] = []
var _skirts: Array[MeshInstance3D] = []
var _seat_grounds: Dictionary = {}


## True if ANY prop in the layout has a converted asset on this machine.
##
## Asked before building rather than inferred from a zero count afterwards: "no
## props were placed" and "this checkout has no props to place" are different facts,
## and collapsing them is how a broken layout would come to look like an expected
## CI result.
static func has_assets() -> bool:
	for entry: Dictionary in LAYOUT:
		if ResourceLoader.exists(PROP_DIR + String(entry["file"])):
			return true
	return false


## The number of layout entries whose asset IS present on this machine -- what
## build() is expected to place. Anything less than this is a real failure.
static func expected_count() -> int:
	var n := 0
	for entry: Dictionary in LAYOUT:
		if ResourceLoader.exists(PROP_DIR + String(entry["file"])):
			n += 1
	return n


## Build the homestead. Returns the number of props actually placed -- 0 on an
## assetless checkout, which is a reported state and not an error.
func build() -> int:
	# The same body as build_paced(), with no pace: it never awaits, so it runs to the end
	# inside this call. call() by name because the parser insists a function that CAN await
	# is always awaited, and every existing caller of build() is synchronous.
	return int(call(&"build_paced", Callable()))


## build(), handing a frame back after each prop: `await pace.call(done, total)` (the
## ranch's boot behind the loading screen, docs/playtest_fixes/loading.md). An invalid pace
## is build() exactly.
func build_paced(pace: Callable) -> int:
	if not has_assets():
		# No converted props on this machine at all (CI, or a clone that has not run
		# the pipeline yet). Bare terrain, reported by ranch.gd -- and reported as a
		# distinct `assets=absent` state rather than as a zero that looks like a pass.
		return 0

	var done := 0
	for entry: Dictionary in LAYOUT:
		done += 1
		if pace.is_valid():
			await pace.call(done, LAYOUT.size())
		var file: String = entry["file"]
		var path := PROP_DIR + file
		if not ResourceLoader.exists(path):
			if not file in _missing:
				_missing.append(file)
			continue

		var scene: Resource = load(path)
		if scene == null or not (scene is PackedScene):
			push_error("Props: '%s' did not load as a PackedScene" % path)
			continue

		var inst: Node3D = (scene as PackedScene).instantiate()
		if inst == null:
			push_error("Props: '%s' failed to instantiate" % path)
			continue
		# One light model for the whole valley (game/systems/toon_styler.gd).
		ToonStylerScript.style(inst, ToonStylerScript.category_for(file))

		var at: Vector2 = entry["at"]
		inst.name = "%s_%d" % [file.get_basename(), _placed.size()]
		inst.scale = Vector3.ONE * scale_for(entry)
		inst.rotation.y = deg_to_rad(float(entry["yaw"]))
		var ground := _ground_height(at.x, at.y)
		inst.position = Vector3(at.x, ground, at.y)
		add_child(inst)

		# Measured AFTER the scale and the yaw are applied and the node is in the tree:
		# world_aabb() is a world space measurement, and a footprint is the footprint of
		# the model as it will actually stand.
		var box := world_aabb(inst)
		var centre := Vector2(box.get_center().x, box.get_center().z)
		var half := Vector2(box.size.x * 0.5, box.size.z * 0.5)
		var relief := Vector2(ground, ground)
		var skirted: bool = bool(entry.get("skirt", false))
		if skirted:
			relief = footprint_relief(centre, half, Callable(self, "_ground_height"))
			ground = relief.x

		seat(inst, ground)
		_seat_grounds[inst] = ground
		apply_fade(inst)

		if skirted:
			_add_skirt(inst, centre, half, relief.y - relief.x, ground)

		var foliage := ToonStylerScript.category_for(file) == &"foliage"
		_shape_count += _add_collision(inst, ground if foliage else NAN)
		_placed.append(inst)
		_entries.append(entry)

	if not _missing.is_empty():
		push_warning("Props: %d layout entries have no converted asset: %s"
			% [_missing.size(), ", ".join(_missing)])

	return _placed.size()


## THE FAR ONES FADE (after home-equestria's distance tiers): every prop drew at any range,
## and the yard ran 2300 to 3700 draw calls. A prop fades out past a distance that grows with
## its size (a pebble well before a tree), never inside the yard, and anything as big as a
## barn stays on the skyline.
const FADE_NEAREST := 70.0
const FADE_FARTHEST := 220.0
## Metres of fade distance per metre of the prop's longest side.
const FADE_PER_METRE := 25.0
## At or over this longest side, a prop never fades.
const FADE_NEVER_FROM := 10.0
const FADE_MARGIN := 8.0
## Under this longest side a prop casts no shadow: a pebble's or a flower's shadow is a few
## pixels, but each one is drawn again in every shadow cascade (the sun's passes were about
## 2000 of the yard's 3500 draw calls).
const SHADOW_FROM := 2.5


## Where a prop whose longest side is `size` metres has faded out; 0 for never.
static func fade_end_for(size: float) -> float:
	if size >= FADE_NEVER_FROM:
		return 0.0
	return clampf(size * FADE_PER_METRE, FADE_NEAREST, FADE_FARTHEST)


## Give every mesh of `inst` (standing in the tree) its fade, by the size it stands at.
static func apply_fade(inst: Node3D) -> void:
	var box := world_aabb(inst)
	var size := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var end := fade_end_for(size)
	var geo: Array[Node] = inst.find_children("*", "GeometryInstance3D", true, false)
	if inst is GeometryInstance3D:
		geo.append(inst)
	if size < SHADOW_FROM:
		for g: GeometryInstance3D in geo:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if end <= 0.0:
		return
	for g: GeometryInstance3D in geo:
		g.visibility_range_end = end
		g.visibility_range_end_margin = FADE_MARGIN
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Number of props standing on the ranch right now.
func get_prop_count() -> int:
	return _placed.size()


## Number of collision shapes generated across all props. ranch.gd asserts this is
## at least one per prop: "every prop needs collision" is a claim that has to be
## measured, not assumed, because a prop whose .glb happens to contain no
## MeshInstance3D would silently get none.
func get_shape_count() -> int:
	return _shape_count


func get_placed() -> Array[Node3D]:
	return _placed


## The LAYOUT entry a placed prop came from, or {} for anything Props did not place.
func entry_of(node: Node3D) -> Dictionary:
	var index := _placed.find(node)
	return _entries[index] if index >= 0 else {}


## True if Props seated `node` and recorded the height it used.
func has_seat_ground(node: Node3D) -> bool:
	return _seat_grounds.has(node)


## The ground height `node` was actually seated against: the height under its origin for
## an ordinary prop, the lowest of nine footprint samples for a skirted one. ranch.gd's
## seating check reads this rather than re-deriving it, for the same reason it reads
## Building.seat_ground() for a building: the number a prop was seated by and the number
## the gate checks it against must not be able to drift apart.
func seat_ground_of(node: Node3D) -> float:
	return float(_seat_grounds.get(node, 0.0))


## Every skirt box standing under a wide prop. Not props, not in the census; ranch.gd
## checks their collision layer alongside the props' own.
func get_skirts() -> Array[MeshInstance3D]:
	return _skirts


## Layout entries whose asset file is missing on this machine.
func get_missing() -> Array[String]:
	return _missing


## True world-space AABB over every MeshInstance3D under `root`. Same computation as
## game/scenes/test/terrain_probe.gd's -- kept local rather than shared because that
## file is a Phase 0 probe scene and this is shipping world code; the duplication is
## nine lines and the coupling would be worse.
static func world_aabb(root: Node3D) -> AABB:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	var result := AABB()
	var first := true
	for m: MeshInstance3D in meshes:
		var local_aabb: AABB = m.get_aabb()
		var xform: Transform3D = m.global_transform
		for i in range(8):
			var corner: Vector3 = xform * local_aabb.get_endpoint(i)
			if first:
				result = AABB(corner, Vector3.ZERO)
				first = false
			else:
				result = result.expand(corner)
	return result


## Ground height at the four corners, the four edge midpoints and the centre of the
## rectangle `centre` plus or minus `half`, sampled through `ground_sampler`. Returns
## (lowest, highest).
##
## Nine points and not one, for the reason game/world/building.gd's footprint_relief() takes
## nine: the height under a wide model's ORIGIN says nothing about the corner that is going
## to hang in the air. Deliberately the same shape as that function, so a reviewer reading
## one has read both; it is a free function here because a prop has no footprint of its own
## to ask, only the AABB of whatever the modeller drew.
static func footprint_relief(centre: Vector2, half: Vector2, ground_sampler: Callable) -> Vector2:
	var lowest := INF
	var highest := -INF
	for dx: float in [-half.x, 0.0, half.x]:
		for dz: float in [-half.y, 0.0, half.y]:
			var h: float = float(ground_sampler.call(centre.x + dx, centre.y + dz))
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	return Vector2(lowest, highest)


## True if a prop with this world AABB, standing on ground that is `flat` or not, has to be
## seated by its footprint and given a skirt. ranch.gd asks this of every LIVE placed prop
## and fails the gate if an entry that needs one does not carry `"skirt": true`, so the rule
## is checked against measurements rather than remembered.
static func needs_skirt(box: AABB, flat: bool) -> bool:
	return not flat and maxf(box.size.x, box.size.z) > WIDE_FOOTPRINT


## Shift `node` vertically until the bottom of what you can actually SEE sits
## SINK_BIAS below `ground`, whatever the asset thinks its own origin is. The one
## seating rule on the ranch -- ranch.gd applies it to the hand-built buildings too,
## and then asserts the result on everything.
##
## `node` must already be in the tree: the AABB is measured in world space.
static func seat(node: Node3D, ground: float) -> void:
	var box := world_aabb(node)
	if box.size == Vector3.ZERO:
		return
	node.global_position.y += (ground - SINK_BIAS) - box.position.y


## True if XZ falls inside the reserved pen-plot clearing.
static func is_in_pen_plots(x: float, z: float) -> bool:
	return absf(x - PEN_PLOTS_CENTRE.x) <= PEN_PLOTS_HALF_EXTENT \
		and absf(z - PEN_PLOTS_CENTRE.y) <= PEN_PLOTS_HALF_EXTENT


## The family `entry` belongs to. See FAMILY_SCALE.
static func family_of(entry: Dictionary) -> StringName:
	if entry.has("family"):
		return StringName(entry["family"])
	var file: String = entry["file"]
	if file.begins_with("kenney_tree"):
		return FAMILY_TREE
	return FAMILY_KENNEY


## The uniform scale `entry` is built at: its family's base, times any per-file correction
## in SCALE_FIX, times the entry's own `s` jitter. The one place these three multiply, so
## nothing can apply two of them and forget the third.
static func scale_for(entry: Dictionary) -> float:
	var file: String = entry["file"]
	var base: float = float(FAMILY_SCALE.get(family_of(entry), BASE_SCALE))
	return base * float(SCALE_FIX.get(file, 1.0)) * float(entry.get("s", 1.0))


## True if `node_name` is one of the foliage families. See FOLIAGE_PREFIXES.
static func is_foliage(node_name: String) -> bool:
	for prefix: String in FOLIAGE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _ground_height(x: float, z: float) -> float:
	var terrain := get_parent().get_node_or_null("Terrain")
	if terrain == null or not terrain.has_method("height_at"):
		push_error("Props: no sibling Terrain with height_at() -- props would float")
		return 0.0
	return terrain.height_at(x, z)


## Give `inst` collision. Godot's MeshInstance3D.create_trimesh_collision() adds a
## StaticBody3D child carrying a ConcavePolygonShape3D built from that mesh, which
## inherits the prop's scale through the transform chain -- so the collider is the
## shape you can see, at the size you can see it, with no second scale factor to
## keep in sync. Returns how many shapes were created.
##
## FOLIAGE (a `ground` is passed) COLLIDES ONLY WHERE SOMETHING CAN TOUCH IT: the faces
## reaching below FOLIAGE_COLLIDE_HEIGHT over its ground. A tree model is 60,000 to 80,000
## faces, nearly all canopy, and every pony sliding past one queried them all: the 60-pony
## check spent half its physics tick inside the orchard's leaves (scenes/test/perf.gd,
## exp=shapes). The trunk, the low boughs and the bush itself are kept, so nothing walks
## through a tree. The canopy above is kept too, on its own layer (CollisionLayers.CANOPY)
## that only the camera probes, so the lens never sinks into the leaves.
func _add_collision(inst: Node3D, ground := NAN) -> int:
	var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)

	var created := 0
	for m: MeshInstance3D in meshes:
		if m.mesh == null:
			continue
		if is_nan(ground):
			m.create_trimesh_collision()
			created += 1
		elif _add_low_collision(m, ground + FOLIAGE_COLLIDE_HEIGHT):
			created += 1

	for body: StaticBody3D in inst.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = LayersScript.CANOPY if body.has_meta(&"canopy") \
				else LayersScript.PROPS
		body.collision_mask = 0

	return created


## The trimesh of `m`'s faces that dip below world height `top`, as a StaticBody3D child
## (the same shape create_trimesh_collision() builds, minus what lies wholly above). The
## faces wholly above go to a second body marked `canopy`, which _add_collision() puts on
## CollisionLayers.CANOPY. False when no face reaches that low.
func _add_low_collision(m: MeshInstance3D, top: float) -> bool:
	var faces := m.mesh.get_faces()
	var xf := m.global_transform
	# Only world y is needed, so one row of the basis, not a whole transform per vertex.
	var row := Vector3(xf.basis.x.y, xf.basis.y.y, xf.basis.z.y)
	var lift := xf.origin.y - top
	var keep := PackedVector3Array()
	var high := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var low := row.dot(faces[i]) + lift < 0.0 or row.dot(faces[i + 1]) + lift < 0.0 \
				or row.dot(faces[i + 2]) + lift < 0.0
		# Packed arrays copy on assignment, so each one is appended to by name.
		if low:
			keep.append(faces[i])
			keep.append(faces[i + 1])
			keep.append(faces[i + 2])
		else:
			high.append(faces[i])
			high.append(faces[i + 1])
			high.append(faces[i + 2])
	if not high.is_empty():
		_add_face_body(m, high, "_canopy").set_meta(&"canopy", true)
	if keep.is_empty():
		return false
	_add_face_body(m, keep, "_col")
	return true


func _add_face_body(m: MeshInstance3D, faces: PackedVector3Array, suffix: String) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = String(m.name) + suffix
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	m.add_child(body)
	return body


## A solid box under a wide prop, so the terrain always passes through the SIDE of
## something opaque instead of through a horizontal face. See SKIRT_INSET above for the
## whole argument, and game/world/building.gd's PLINTH_INSET for the same fix on the
## procedural buildings.
##
## PARENTED TO Props, NOT TO THE PROP, and that is load bearing. world_aabb() is what
## seat() and ranch.gd's seating check both measure, and a box hanging below the model
## would move the bottom they read: every skirted prop would report itself sunk by the
## skirt's whole depth and the gate would go red on a correctly placed barn. As a sibling
## it is collided and layered like any prop and is deliberately absent from _placed, so it
## never enters the census either.
func _add_skirt(inst: Node3D, centre: Vector2, half: Vector2, relief: float,
		top: float) -> MeshInstance3D:
	var depth: float = relief + SKIRT_MIN_DEPTH
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(0.2, (half.x - SKIRT_INSET) * 2.0), depth,
		maxf(0.2, (half.y - SKIRT_INSET) * 2.0))
	var material := StandardMaterial3D.new()
	material.albedo_color = SKIRT_COLOUR
	material.roughness = 0.95
	mesh.material = material

	var skirt := MeshInstance3D.new()
	skirt.name = "%s_skirt" % inst.name
	skirt.mesh = mesh
	add_child(skirt)
	# Its top face meets the model's own floor, which seat() has just put SINK_BIAS below
	# the lowest footprint sample.
	skirt.global_position = Vector3(centre.x, top - SINK_BIAS - depth * 0.5, centre.y)
	_shape_count += _add_collision(skirt)
	_skirts.append(skirt)
	return skirt
