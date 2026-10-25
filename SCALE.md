# SCALE -- how big everything is, in pony heights

THE ONE YARDSTICK IS THE PONY. Every asset that stands in the world is sized relative to
**1 PH (one pony height)**: the player's own rendered body measured from hoof to the top of
her ears or horn, in the world, at runtime. With the shipped roster that is about
**2.19 m** (the bounding box of the converted model; the 1.30 m collision capsule is NOT the
yardstick -- it stops at the withers and the head).

Why it matters: three conventions used to meet on this map without ever being compared to
the pony. Kenney kit pieces were built at `Props.BASE_SCALE` 1.5 (derived from an old pony
size), PonySFM / Sweet Apple Acres models at `Props.MLP_SCALE` 0.5193 (divided out of one
barn, to a ridge height chosen against the old primitive barn), and the regions' Kenney
Nature Kit dressing at hand-typed random factors -- with the orchard's apple trees at no
factor at all. Houses landed between 1.6 and 2.6 PH, a market stall was shorter than the
pony at it, and doors were shorter than the pony walking through them. See
`docs/playtest_fixes/scale.md` for the whole account.

## How it is checked

`game/test_input/test_scale.gd` (run: `tools/run_input_tests.sh scale`) boots a new game
through the real title screen with mouse input, measures 1 PH off the player, then
measures every placed asset's world-space bounding-box height (and each doorway's clear
opening) on the ranch, in the town, at the Palace and the Strip, in all four regions and on
the valley rim, and fails listing every asset outside its row below. Anything visible that
no asset row claims fails as "unmapped". The Factory interior is not reachable from a new
game, so it is not measured by this test (see the fix doc).

The two tables below are MACHINE READ by that test: keep the header rows exactly as they
are. Heights are in PH; `-` means no bound.

## Target sizes by category

| category | min_ph | max_ph | min_width_ph | what it is and how it is measured |
|---|---|---|---|---|
| house | 3.0 | 6.0 | - | homes, shops, the town row, the Depot: the model from its own floor to the ridge. Several ponies tall. |
| landmark | 3.0 | 8.0 | - | the barns and the Spectra Palace: at least as tall as the houses round them |
| door | 1.3 | 2.2 | 0.6 | a doorway's CLEAR opening, from the floor the pony stands on to the lintel; width between the jambs. A pony walks in with room over her ears. |
| outbuilding | 1.4 | 3.0 | - | a shed: taller than a pony, smaller than a house |
| stall | 1.2 | 2.5 | - | a market stall: its awning is over the head of a pony standing at it |
| structure | 1.0 | 3.0 | - | things a pony stands under or beside: swing frame, wire arch, bell tower, tetherball pole, lamp posts, a yard sign |
| fence | 0.4 | 1.3 | - | every fence and rail: pen, region ring and gate, race rail, old farm rail |
| tree | 2.0 | 5.0 | - | every tree, live or dead, Kenney or Sweet Apple Acres |
| crop | 0.8 | 1.6 | - | a corn stalk: about a pony |
| bush | 0.25 | 1.0 | - | bushes and hedging |
| plant | 0.02 | 0.7 | - | flowers, grass tufts, reeds, mushrooms, a dead corn stalk fallen in its row |
| prop_small | 0.08 | 0.6 | - | things a pony could push or step over: crate, basket, bale, sack, cone, dirt pile, small log, low stump, a canoe on the bank |
| prop_medium | 0.3 | 1.5 | - | things about pony size: well, coop, wagon, hay pile, picnic table, horseshoe pit, water chute, mailbox, game cabinets, a big fallen log, a tall stump |
| sign | 0.3 | 2.0 | - | boards hung on buildings: the Palace marquee and lobby sign |
| rock | 0.05 | 1.5 | - | rocks and flat stones |
| standing_stone | 0.8 | 2.5 | - | the Night Meadow's ring |
| marker | 0.2 | 1.0 | - | build-plot stakes |
| ground | 0.0 | 0.3 | - | things lying flat: lily pads, jetty planks, flat stepping stones |
| character | 0.25 | 0.8 | - | Spike (a baby dragon, about half a pony) |
| terrain | 15 | - | - | terrain features: the valley rim and the Prism Works on the skyline |

## Which asset is which category

First matching row wins (`*` is a wildcard). The asset name is the model's file name
without `.glb`, or the name the test gives a code-built thing.

| asset | category | where it stands |
|---|---|---|
| door | door | every Building with a doorway (`game/world/building.gd`, `ranch.tscn`) |
| saa_barn | landmark | the homestead barn and Sweet Apple Acres |
| spectra_palace | landmark | the Palace on the Strip |
| pv_* | house | Farmhouse, Market, Board, Depot, the town row, the Palace facade |
| saa_shed | outbuilding | homestead yard, Sweet Apple Acres |
| kenney_market_stall | stall | the Market yard |
| school_belltower | structure | schoolyard |
| school_swingframe | structure | schoolyard |
| school_tetherball_pole | structure | schoolyard |
| school_sign | structure | schoolyard |
| saa_wire_arch | structure | Sweet Apple Acres |
| strip_lamp | structure | the Strip's lamp ring |
| strip_marquee | sign | the Palace front |
| lobby_sign | sign | the Palace front |
| region_fence | fence | the four region rings (measured on the gate leaf) |
| race_rail | fence | the race track |
| race_wire_post | structure | the race track's finish posts |
| race_gate_post | marker | the race track's lane starting posts |
| saa_fence_old | fence | Sweet Apple Acres |
| pen | fence | built pens |
| saa_tree_* | tree | treeline, regions |
| saa_dead_tree_large | tree | the Everfree landmark |
| mlp_apple_tree* | tree | orchard, Sweet Apple Acres walk |
| tree_* | tree | region dressing (Kenney Nature Kit) |
| saa_corn_plant_dead | plant | Sweet Apple Acres (a stalk fallen in its row) |
| saa_corn_plant* | crop | Sweet Apple Acres |
| mlp_bush | bush | hedging |
| plant_bush* | bush | Everfree dressing |
| flower_* | plant | Night Meadow |
| grass* | plant | regions |
| plant_flat* | plant | Lake reeds |
| mushroom_* | plant | Everfree |
| mlp_crate | prop_small | yard, orchard |
| mlp_basket | prop_small | yard, orchard |
| saa_hay_block | prop_small | yard |
| saa_seed_bag | prop_small | yard, Sweet Apple Acres |
| saa_small_dirt_pile | prop_small | yard |
| school_cone | prop_small | schoolyard |
| log_large | prop_medium | Everfree |
| stump_oldTall | prop_medium | Everfree |
| log* | prop_small | Everfree |
| stump_* | prop_small | Everfree |
| saa_hay_pile | prop_medium | yard, Sweet Apple Acres, orchard |
| saa_wagon | prop_medium | yard, Sweet Apple Acres |
| saa_water_chute | prop_medium | Sweet Apple Acres |
| mlp_farm_well | prop_medium | yard |
| mlp_chicken_coop | prop_medium | yard |
| school_picnic_table | prop_medium | schoolyard |
| school_horseshoe | prop_medium | schoolyard |
| lp_skeeball | prop_medium | the Strip |
| lp_dance_game | prop_medium | the Strip |
| mailbox | prop_medium | by the Depot |
| place_sign | structure | the plaza fingerpost and the shop and yard signs (2026-10-25) |
| canoe | prop_small | the Lake |
| rock_smallFlat* | ground | the Lake shore |
| rock_* | rock | Everfree, Lake |
| stone_tall* | standing_stone | Night Meadow |
| plot_stake | marker | the four build plots |
| lily_* | ground | the Lake |
| path_wood | ground | the Lake jetty |
| spike | character | the Depot |
| valley_rim | terrain | the skyline |
| prism_works | terrain | the skyline |
