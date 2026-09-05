# Presentation Redesign -- Design

Date: 2026-09-04. Owner directive after the first full phase-3 playtest: "we need
to take a step back and consider a full resdesign" ... "mlp show style through and
through. consistent thoughtfully placed assets."

## 1. What this is and is not

This is a redesign of the PRESENTATION layer: art coherence, UI framework, input,
character creation, camera, animation, and the sound mix. It is NOT a rewrite.
`game/systems/` (economy, casino math, story, ledger, save) survives untouched --
the casino was the playtest's one bright spot and its math is published and tested.
Content work (the voice slice, story slice 4) is ON HOLD until this phase lands.

The playtest verdict this answers, item by item, is recorded in the session memory
`playtest-2026-09-04` and repeated in section 8 as the acceptance list.

### The register

MLP show style through and through. The PonySFM packs (hand-painted, flat-shaded,
show-accurate) are the visual anchor; everything else on screen rises to them or
leaves the map. Kenney low-poly geometry may survive only where it reads as
neutral (fences, crates, small clutter) after a palette pass; anything
flat-primitive or signature-Kenney (the turquoise blob trees, the placeholder
box buildings) goes.

## 2. Standing constraints (unchanged, binding on every slice)

- NO PONY EVER DIES. No rigging the casino. THE MATH DOES NOT CHANGE --
  `game/systems/` is read-only for this whole phase except the save-safety fix
  in section 3.
- No realistic pony vocalizations; the one sanctioned neigh gag stays exactly
  as shipped (`Sound.GAG_ID`, corpus sweep exempts it by constant).
- No em dashes in any player-facing copy; the house dash is " -- ".
- Sources: no accounts ever, never the owner's email; record every source URL.
  Usage-rights vetting is waived by the owner. PonySFM downloads are no-login.
- Suite stays green at every merge; MIN_TESTS never decreases; every gate that
  exists keeps passing; new visuals update the gallery/census gates rather than
  deleting them.
- Keyboard must remain FULLY functional everywhere -- mouse support is added,
  keyboard is never removed.

## 3. Slice R0 -- save safety (small, first, blocking)

The play copy was consolidated away (2026-09-04); the owner now plays from the
main checkout, so the parked defect is urgent: headless gate/test boots write the
LIVE `user://saves` slots. Fix: a single test-mode switch (env var
`FILLY_TEST_SAVE_DIR` or a `--headless`-detected redirect in the save system)
that every gate and test boot uses, plus a gate assertion that a sweep leaves
`user://saves` byte-identical. This is the only `game/systems/` change in the
phase. It ships alone, before anything else, so the owner's real save can
coexist with dev sweeps.

## 4. Slice R1 -- the UI overhaul

The complaint cluster: "all ui being keyboard only is tough", "the gui seems very
cheap", "not industry standard ... for character creation", letter UI "week",
controls card bleeding through the letter, "Save the ranch" misread, toast lag.

### 4.1 One Theme, mouse-first input

- Build a real Godot `Theme` resource (`game/ui/theme/filly_theme.tres`) with
  show-style styling: warm paper panels, wooden frames, the established palette
  from `menu_style.gd` promoted into StyleBoxes, hover/focus/pressed states for
  buttons, sliders, tabs, and list rows. `menu_style.gd` consts become the
  single source the Theme is generated from (a `tools/` generator script keeps
  them in lockstep) so existing drawn chrome and new themed controls match.
- Every menu becomes mouse + keyboard dual-input: real focusable `Button`/
  `Slider`/`TabBar` controls (themed) replace hand-rolled keyboard row cursors
  where possible; where a screen keeps custom drawing (casino felt, stationery),
  it gains click/hover hit-testing on its rows. `mouse_filter = IGNORE` is
  removed game-wide; the pause menu releases the mouse; every screen shows a
  pointer-usable close button. Keyboard navigation and the existing footer key
  hints remain.
- Toast queue: drain concurrently or cap display time so rapid actions never
  back up (the "text on top lags behind" complaint).
- Copy fixes: "Save the ranch" becomes "Save game" (and "Load game"); a pass
  over button/footer copy for oddly-worded lines.

### 4.2 Character creation rebuilt

- The creation screen becomes a true full-screen experience: the paused live
  world is fully hidden behind an opaque show-style backdrop (sky + clouds from
  the owned MLP cloud sprites, or a drawn stage) -- no world camera, no
  map-flash, no clipping into the farmhouse. The existing SubViewport turntable
  is kept but promoted: the pony preview fills the left half at a flattering
  camera angle, with drag-to-rotate mouse control on top of the auto-spin.
- Layout to industry standard: name field, big swatch grids with hover states
  and selected outlines (not tiny `<` `>` steppers), mane style cards with
  preview thumbnails, the cutie-mark canvas kept (it already supports the
  mouse) but framed as its own step/panel with the ink/shape/brush rows as
  proper themed buttons.
- Boot order fix: on a fresh save the creation screen opens BEFORE the world is
  revealed at all (world build may proceed behind the opaque backdrop; no
  frame of raw map is ever visible).

### 4.3 Letters and cards

- Letter panel restyled on the stationery kit with the new theme: proper
  margins, drop shadow, wax seal, readable line length; the controls card (H)
  hides while any letter or menu overlay is open (the bleed-through bug).
- Letter copy pass: the owner called the language "a bit weird" -- rewrite the
  15 authored letters for natural, in-register phrasing (dark-humor corporate
  cheer stays, clunky phrasing goes). STORY_OK's byte-identity checks update to
  the new copy in the same commit.
- The mail fiction gets consistent: reading letters happens AT the mailbox in
  the world (walk up, E opens the letter panel); the pause-menu Mail page
  remains as an archive labeled "Saddlebag copies" so the "it says it's by my
  house but it's in the pause menu" confusion dies.

## 5. Slice R2 -- world coherence

The complaint cluster: "the clashing asset style looks terrible", the Palace
"looks terrible", thoughtless placement.

### 5.1 Buildings

- `game/world/building.gd` primitives retire from view. Owned, converted,
  show-accurate replacements: the ranch Barn becomes `saa_barn.glb`, a second
  ranch structure uses `saa_shed.glb`, the Market becomes `pv_general.glb`
  (+ its sign), and the Farmhouse/Board/Depot are cast from the six Ponyville
  Environments town buildings (`pv_wide_b`, `pv_pink_b`, `pv_tower_b`,
  `pv_courtyard_b`, `pv_balcony_b`, `pv_bridged_b`) -- chosen per footprint.
  The `Building` class survives only as the invisible collision/door-marker
  shell sized to each model (interaction points, door apron ramps, census).
- The Spectra Palace: first try to SOURCE a show-style Las Pegasus/casino
  structure from PonySFM (no-login; we own only the two arcade floor games).
  If nothing suitable exists, kit-bash: a wide facade assembled from the
  Ponyville Environments pieces + a purpose-drawn marquee (real geometry
  arch, bulb rings, gold trim -- casino_paint's language in 3D) replacing the
  floating `Label3D` sign with its visible control dots. Either way the purple
  primitive box goes.
- Fix the sign z-fighting/floating-dots on every remaining board.

### 5.2 Environment and placement

- The turquoise Kenney blob trees are replaced by the owned PonySFM trees
  (Sweet Apple Acres live/dead trees, orchard apple trees, environment bushes).
  Kenney nature survives only as neutral rocks/paths if it reads clean next to
  the MLP kit; otherwise it goes too.
- A deliberate placement pass on the whole map: the ranch yard composed like a
  farmstead (barn, shed, well, wagon, hay), the town row on real dirt roads
  (`dirt_road` tiles are owned), the Strip as a coherent boardwalk approach to
  the Palace, breathing room between structures, nothing intersecting.
  "Thoughtfully placed" is the acceptance bar; screenshots from the gallery
  gate document before/after.
- Terrain/palette tune so ground, grass, and the hand-painted assets share
  light: the existing terrain shader gets a saturation/tone pass against the
  PonySFM palette.

## 6. Slice R3 -- feel and mix

The complaint cluster: tail glitching, walk animation "worse than before",
multi-press penning + terrible denied sound, pen placement guesswork, loud
ambience, terrible footsteps.

- Tail physics: damp or re-pin the tail bones (the "glitching out a lot" jiggle).
- Walk animation: re-tune the gait cycle speed/foot timing against actual move
  speed (the perceived regression came with the new hoofstep audio making any
  foot/ground mismatch audible -- sync steps to footfalls, not a timer).
- Penning: one E press pens when legal; when the pen is genuinely full the
  denied feedback is ONE soft themed sound + toast, debounced so mashing E
  never machine-guns it.
- Paddock placement: live ghost preview on the plot -- green when valid, red
  with the reason when not ("too close to the fence"), so finding a legal spot
  is visual instead of trial-and-error. Fix the overlapping old-fence/new-frame
  visual from the playtest ("wtf is happening here").
- Sound mix ear pass, owner's verdicts applied: ambient beds down (start
  -6 dB on the Ambient bus default), footsteps replaced with softer grass/dirt
  samples via the manifest (one-line swaps + `--only` refetch), the parked
  knobs (mail_open level, wheel/reel noise floors, race_cheer length,
  capture-charge pulse) resolved in the same pass.

## 7. Order and gating

R0 first and alone (save safety). Then R1, R2, R3 as separate SDD-looped
slices, each: spec section -> plan -> build in a worktree -> per-task review ->
final opus review -> merge only on MERGE READY + green gates -> push. R1 before
R2 because every screenshot of R2's world work is taken through R1's UI, and
because CC/input is the owner's sharpest pain. R3 last except that pure sound
knob turns (section 6's mix bullet) may ride R1 as one small task -- they're
manifest edits, not code.

Gates: SOUND_OK, GALLERY (props), RANCH census, WALK, and STORY_OK all update
with the work they cover; MIN_TESTS ratchets up as tests are added, never down.

## 8. Acceptance list (the playtest, answered)

1. New save: no frame of raw world, CC full-screen, pony clearly visible. (R1)
2. CC layout reads industry standard, mouse-driven. (R1)
3. Letter UI feels crafted; language natural; no card bleed-through. (R1)
4. Tail does not glitch in normal movement. (R3)
5. Every menu usable by mouse alone and keyboard alone. (R1)
6. Ambience sits under the mix, footsteps pleasant. (R1 knobs / R3)
7. No clashing styles in any screenshot; GUI reads crafted. (R1+R2)
8. Penning is one press; denied feedback is soft and single. (R3)
9. Pen area shows no overlapping fence chaos; placement is guided. (R3)
10. Mail read at the mailbox; pause page is the archive; "Save game". (R1)
11. Toasts keep up with rapid play. (R1)
12. Palace exterior looks like a destination. (R2)
13. Casino UI keeps its crown and gains mouse play. (R1)

## 9. Non-goals

Voice slice (on hold, designed, next after this phase), story slice 4, music,
factory interior, gamepad polish beyond what already works, interiors for the
new buildings (doors/aprons remain functional thresholds), any change to odds,
payouts, prices, or story logic.

## 10. Open questions parked for the owner

- Palace sourcing: if PonySFM yields no casino structure, is the kit-bash
  facade acceptable, or would the owner rather source a pack themselves?
- Letter copy rewrite: any lines the owner specifically wants kept?
- Main menu: the game currently boots straight into the world (no title
  screen). A proper title/main menu is industry standard and cheap once the
  Theme exists -- assumed IN scope for R1 unless vetoed.
