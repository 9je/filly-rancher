# Playtest fix: scale

## The note

> "Some house models are the same size as ponies. Scaling is inconsistent everywhere."

The order: write `SCALE.md` (a reference table of target sizes relative to pony height for
every category), make doors clearly fit ponies and houses several ponies tall, fix every asset
to match, and add a test that checks every placed asset's bounding box against `SCALE.md`.

## Root cause

Nothing on the map was ever sized against the pony. Four unrelated conventions met in one
valley, each derived from something else:

1. **The PonySFM / Sweet Apple Acres family, `Props.MLP_SCALE` 0.5193.** Divided out of ONE
   model: `saa_barn.glb` (13.479 m as converted) to a 7.0 m ridge chosen as "two metres over
   the old primitive barn's 4.9 m". Every converted building then stood at that one factor
   (`Building.model_scale` was 1.0 by rule, and `test_building_model.gd` pinned it), on the
   argument that one family scale is consistency. But the Ponyville Environments houses are
   not drawn to the barn's scale, so they landed at 3.6 to 5.8 m. The ponies themselves come
   from the same Source models through a different door (`tools/convert_roster.sh`,
   `--scale 2.0` / `0.5`) and stand **2.19 m** to the ear tip. So: town row houses 1.6 to
   2.2 PH (pony heights), the Board 1.64 PH, the Farmhouse 2.63 PH, the Market 2.44 PH.
2. **The Kenney kits, `Props.BASE_SCALE` 1.5.** Derived in Phase 1A from a 2-unit door module
   against the old 4.28-unit pony. Nobody re-measured after the pony changed; the market stall
   stood 1.86 m, an awning lower than the pony under it.
3. **The regions' dressing (`region_dressing.gd`).** Kenney Nature Kit trees and stones drawn
   at hand-typed random multiples of their OWN model's size -- and the kit's models are not
   one size, so one wood held trees from 1.94 to 5.42 PH. The orchard's converted apple trees,
   baskets and crates were placed at **1.0**, the raw converted size, skipping MLP_SCALE and
   SCALE_FIX entirely: orchard apple trees at 1.5 PH beside 2.6 PH apple trees on the walk up
   to it, and 7 cm baskets.
4. **Doors.** `Building.MIN_DOOR_CLEARANCE` (2.25 m) was compared with `door_height`, which is
   measured from local y = 0. Local y = 0 has been 0.85 m inside a solid plinth since the plinth
   rose to `FLOOR_TOP` (2026-08-31), so every door passed the check while standing 1.75 to
   2.15 m clear of the floor: 0.80 to 0.98 PH, shorter than the pony walking through it.

Plus a handful of per-asset `SCALE_FIX` numbers targeted by eye at a 2.138 m pony and never
checked again (the old farm fence rail, 0.34 PH; the Night Meadow's fifth standing stone,
0.65 PH where its ring stood 0.9 to 1.3).

## The fix

**`SCALE.md`** (repo root) is the reference: 1 PH = the player's rendered height measured in
the world (2.19 m with the shipped roster), a category table with min/max in PH (and a minimum
width for doors), and an asset-to-category table. Both tables are machine read by the test.

Data changes, by asset (every number is in data -- scale factors and layout -- not in the
test):

| asset / thing | before | after | how |
|---|---|---|---|
| Farmhouse (`pv_wide_b`) | 5.77 m, 2.63 PH | 7.21 m, 3.29 PH | `model_scale` 1.25, shell scaled with it (`ranch.tscn`) |
| Market (`pv_general`) | 5.34 m, 2.44 PH | 7.21 m, 3.29 PH | `model_scale` 1.35, shell scaled |
| Board (`pv_bridged_b`) | 3.60 m, 1.64 PH | 6.66 m, 3.04 PH | `model_scale` 1.85, shell scaled; moved (3, -1) to (5, 0), yaw 45 (see below) |
| Depot (`pv_tower_b`) | 7.43 m, 3.39 PH | 9.66 m, 4.41 PH | `model_scale` 1.3 so its painted door clearly fits a pony |
| town row, six `pv_*` | 3.6 to 4.9 m, 1.66 to 2.23 PH | about 7.0 m, 3.2 PH each | `Props.SCALE_FIX` per file; west row re-spaced to z 31 / 39.5 / 48 |
| every doorway (5) | 0.80 to 0.98 PH clear | 1.37 PH (3.0 m) clear | `door_height` 3.85; `MIN_DOOR_CLEARANCE` 2.85 m (1.3 PH) now checked against `door_height - FLOOR_TOP` (`Building.door_clearance()`); Palace walls 3.6 to 4.6 m so its lintel clears |
| `kenney_market_stall` | 1.86 m, 0.85 PH | 3.06 m, 1.40 PH | `SCALE_FIX` 1.65; moved (2, 3) to (3.8, 6.5), off the Market's grown ramp |
| `saa_fence_old` | 0.75 m, 0.34 PH | 1.00 m, 0.46 PH | `SCALE_FIX` 1.93 to 2.57 |
| orchard apple trees (dressing) | 3.36 m, 1.53 PH | 5.6 m, 2.6 PH | `region_dressing.gd` stands converted props at `Props.scale_for()`, the factor props.gd uses |
| orchard baskets and crates | 0.17 / 0.40 m | 0.50 / 0.70 m | same |
| Kenney Nature Kit trees (dressing) | 1.94 to 5.42 PH | 2.3 to 3.9 PH | asked for by HEIGHT in PH per planting, scaled off each model's own measured height |
| Night Meadow standing stones | 0.65 to 1.33 PH | 1.05 to 1.35 PH | same, by height |
| pens (the four Plots slots, `PEN_PLOTS_CENTRE`) | z 8.5 / 17.5 | z 11 / 20 | moved 2.5 m south so the grown Market's wall does not stand over slot 1 |
| yard props | -- | -- | crate (4, 7) to (4.5, 8.8), basket (2.5, 6) to (1.8, 7.2), bush (13.5, -6) to (15.5, -4): clear of the grown Market ramp, Depot and Farmhouse |
| `MARKET_RADIUS` | 4.5 | 6.0 | the Market's door and Vendor stand 1.35x further from its origin |

Reclassified rather than rescaled (the table was wrong, not the asset): the dead corn stalk is
a stalk fallen in its row (0.83 m high, 1.8 m across; stood up to a live stalk's 2.4 m it
sprawled 5 m wide), so it is a `plant`; the big fallen log and tall stump are `prop_medium`;
flat stepping stones are `ground`; the canoe on the bank is `prop_small`.

Unchanged and already in range: the barns (`saa_barn`, 7.0 m, 3.2 PH, the number MLP_SCALE is
derived from and ranch.gd asserts), the Palace (9.0 m, 4.1 PH), the sheds, every other prop.

### Calls made (logged here; DECISIONS.md is not this task's to edit)

- **The Board's origin moved** 2.2 m, (3, -1) to (5, 0), turned 45 degrees to face the same
  way as the Market's door. `test_building_model.gd` pins every origin "for the owner's save";
  at house size the Board does not fit the notch between the Market's and the Farmhouse's
  ramps at its old origin (searched every position within 5 m and every 15 degree yaw), and
  a 2 m nudge of where E opens the request board is a smaller cost than a house a pony can
  look over. Nothing in a save stores building positions.
- **The pens moved 2.5 m south.** Pens are restored by slot id, not position, so a save's pens
  follow their slots; the clearing stays inside the flat apron's tolerance (ranch self-check).
- **The barn stays 7.0 m.** It is in range (3.2 PH) and it is the measured anchor of
  MLP_SCALE; raising it would mean re-deriving MLP_SCALE for every prop on the map.
- **A model's painted door is judged by eye, not by the test.** Each converted building is one
  mesh, so its painted door has no bounding box of its own. The test measures the doorway a
  pony walks through (the shell's collision opening); the after shots show the painted doors.

## The test

`game/test_input/test_scale.gd`, run with `tools/run_input_tests.sh scale`. It boots the real
game in the invisible display, clicks New game on the title screen, takes the creator's pony
and closes the welcome letter with `RealInput`, then only READS the world: 1 PH off the
player's rendered body, then the world-space bounding box of every placed asset -- every
`Props` placement, every Building's model and its doorway (clear height from the Floor slab's
top to the Lintel's underside, clear width between the front walls), the mailbox, the region
fence gates, every instance of every region dressing MultiMesh (union of its parts), the
Strip's lamps, marquee and race track rails and posts, the plot stakes, Spike, the valley rim
and the Prism Works, and Act Three's sites when they exist -- and holds each against
`SCALE.md`. Any visible geometry no collector claims fails as "unmapped". It writes the full
per-placement report to `build/playtest_evidence/scale/test_scale_report.txt`; the before and
after reports are kept beside it as `test_scale_report_before.txt` and
`test_scale_report_after.txt` (one line per placement, 867 of them).

The Factory interior is a separate scene reached only at the reveal, so it is not reachable
from a new game by real input in a test's time budget, and Act Three's sites do not exist on
a new save; both are listed in the collector but measured only when present.

### Before (the fixes reverted, the same test and table)

```
$ tools/run_input_tests.sh scale
[scale] INPUT_TEST_FAILED test_scale 19 of 102 assets off SCALE.md (1 PH = 2.19 m): 
  kenney_market_stall stall 0.85-0.85 PH not in 1.20-2.50;
  mlp_apple_tree tree 1.53-3.07 PH not in 2.00-5.00;
  saa_fence_old fence 0.34-0.34 PH not in 0.40-1.30;
  pv_pink_b house 1.66-1.66 PH not in 3.00-6.00;
  pv_ogb_1 house 2.23-2.23 PH not in 3.00-6.00;
  pv_courtyard_b house 2.04-2.04 PH not in 3.00-6.00;
  pv_courtyard_b_balcony house 2.04-2.04 PH not in 3.00-6.00;
  pv_ogb_2 house 1.90-1.90 PH not in 3.00-6.00;
  pv_balcony_b house 1.67-1.67 PH not in 3.00-6.00;
  mlp_basket prop_small 0.08-0.23 PH not in 0.08-0.60;
  door door 0.80-0.98 PH not in 1.30-2.20 w 0.82;
  pv_wide_b house 2.63-2.63 PH not in 3.00-6.00;
  pv_general house 2.44-2.44 PH not in 3.00-6.00;
  pv_bridged_b house 1.64-1.64 PH not in 3.00-6.00;
  tree_default_dark tree 2.89-5.26 PH not in 2.00-5.00;
  stone_tallE standing_stone 0.65-0.65 PH not in 0.80-2.50;
  tree_pineTallB_detailed tree 3.53-5.42 PH not in 2.00-5.00;
  tree_fat_darkh tree 1.94-3.49 PH not in 2.00-5.00;
  tree_pineTallC_detailed tree 2.77-5.12 PH not in 2.00-5.00
INPUT_TESTS passed=0 failed=1
```

(`mlp_basket 0.08-0.23` is rounding in the one-line summary: the orchard's baskets measured
0.077 PH, 7 cm, under the 0.08 floor; the full report has every placement.)

### After

```
$ tools/run_input_tests.sh scale first_pony
[scale] INPUT_TEST_OK test_scale 867 placements of 102 assets all within SCALE.md (1 PH = 2.19 m)
[first_pony] INPUT_TEST_OK test_first_pony caught on the first try
INPUT_TESTS passed=2 failed=0
```

Ranch self-check on the same boot: `RANCH_OK ponies=49 props=115 assets=present`.

GUT, headless: `tools/run_tests.sh`, all 1752 tests pass. The ones this fix had to touch:
`test_building_model.gd` (shells now pinned at their SCALE.md factor and size, the Board's new
origin), `test_props.gd` (the Kenney base-scale case uses a piece with no SCALE_FIX row),
`test_ranch_world.gd` (the door check is against the clear opening over the floor),
`test_attendant.gd` (the Vendor's radius is the grown MARKET_RADIUS).

## Evidence

`build/playtest_evidence/scale/pairs/*.jpg`: the same view before and after, side by side, with
only the player pony in frame (the residents are hidden for the shots so nopony stands in front
of the lens). Rendered by `game/scenes/test/scale_shots.gd` in the invisible display;
`yard_from_above.jpg` shows the homestead footprints after the rescale.
