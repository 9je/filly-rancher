class_name Ranch
extends Node3D
## THE MAP. The first actual place in this game -- everything before it was a test
## scene on a grey plane -- and, as of Phase 1A Task 7, the project's main scene.
##
## WHAT IT IS. Terrain (game/world/terrain.gd) with a sun and a sky, a homestead of
## Kenney props at the validated 1.5x scale (game/world/props.gd), the player
## standing in the yard, five ZoneMarkers spread over the map, and a Spawner
## (game/world/spawner.gd) that fills them with wild ponies drawn from the registry.
##
## WHERE THE ZONES ARE, AND WHY THERE ARE FIVE OF THEM NOW. The first playtest's report
## was "ponies were only around the perimeter", and it was right: the three original
## markers sat at (2, -42), (40, 8) and (-30, 38), all of them 40 m or more from the
## player's spawn and none of them anywhere a player crossing the middle of the map would
## meet one. Eight ponies on a 140 x 140 m map is not many to begin with, and putting all
## eight around the rim meant the entire middle of the ranch -- the part you actually walk
## through -- was empty.
##
## The three original markers are kept (they are on real relief, which the raycast
## placement check below depends on) at two ponies each, and two more are added where the
## map was bare: HomePasture, a small herd in the open ground north-east of the pen plots,
## about 10 m from where the player spawns, so the FIRST thing a new session contains is
## a pony; and WestHollow, out west between the tree line and the map edge, which was the
## largest continuously empty quarter of the map. Ten ponies over five places rather than
## eight over three.
##
## AND FOUR MORE, OUT IN THE REGIONS, as of Phase 2 slice 3. The map is 220 m across now
## and carries four regions as data (game/data/regions/*.tres): the orchard, the everfree
## edge, the lake and the night meadow. Each one gets a ZoneMarker at its centre carrying
## its own zone_id, so 30 of the 43 characters are zoned somewhere other than `ranch` and
## the ten slots on the homestead stop being the whole roster's only address. Each one is
## also ringed by a RegionFence built below, shut until its permit is in GameState.unlocks:
## the ponies who live out there are visible across a fence you have not paid to cross,
## which is the entire point of a permit and the reason the fence is a ring rather than a
## wall you cannot see past.
##
## Their spawn radii are NOT the plan's "region radius minus 6" for the orchard and the
## everfree edge, and the reason is the check named "no spawn disc reaches more than
## halfway to another marker" in _report(): see the comment there.
##
## Sizing all five is bounded by things this file's own checks care about: no disc may
## overlap the pen-plot clearing (game/world/props.gd's PEN_PLOTS_*), no disc may sit on
## a prop's footprint, and no two markers may be close enough that a pony spawned in one
## ends up nearer another -- "every pony was spawned inside her zone" is checked against
## her NEAREST marker, so overlapping discs would fail it. HomePasture's 6.5 m radius is
## the one that is tight rather than chosen: it is the largest circle at (7, 19) that
## clears the pen plots to the west and the oak at (14, 27) to the north-east.
##
## THIS FILE IS ALSO THE GATE. `RANCH_OK ponies=<n> props=<n> assets=<state>`, exit
## 0, printed only when every check below actually held. The checks are chosen the
## way the rest of this project chooses them -- each one has a specific way it can
## go red:
##
##   * "the player is standing on the ground" fails if the terrain collider is not
##     built, if the raycast/trimesh is wrong, or if the player's mask stops
##     matching the terrain's layer. It is the check that catches a main scene that
##     boots into a void, which is the worst possible regression for a MAIN SCENE.
##   * "every prop has collision" fails for a prop whose .glb carries no mesh, or if
##     the trimesh generation is dropped -- the difference between a barn and a
##     hologram, and nothing else here would notice.
##   * "the camera pulls in against a building" is the one that would have caught
##     the latent bug this task was told to fix. Before this map, EVERY collision
##     object in the project sat on the untouched default layer 1, and the camera's
##     spring arm probed with the untouched default mask 1, so it worked by
##     coincidence. Give the world real layers and leave that mask alone and the
##     camera sails through the barn -- with no error, no warning, and no numeric
##     assertion anywhere in this project able to see it. So the mask is asserted
##     structurally AND the pull-in is measured against an actual building.
##   * "no pony was placed by fallback" fails if the spawner's ground raycast is
##     finding nothing -- which is what happens if populate() is called before the
##     physics server has stepped, and would otherwise show up only as a herd
##     hovering at marker height in a screenshot nobody took.
##   * "the zones sit on sloped ground" fails if someone flattens the terrain. That
##     is not an aesthetic assertion: on flat ground the spawner's raycast placement
##     is indistinguishable from `y = 0`, so this check is what keeps the check
##     above from going hollow.
##   * "the pen-plot clearing is clear" fails if a prop or a pony ends up in the
##     ground reserved for Phase 1B's plots.
##   * "a save round-trips through the user:// filesystem" fails if a save cannot be
##     written or cannot be read back with every field intact. It is here rather than only
##     in the unit suite because this gate is the thing CI runs on real Windows and
##     tools/run_windows_build.sh runs under Proton, and `user://` resolves to a completely
##     different place on Windows (docs/windows-testing.md) through a differently
##     implemented rename. The gate also PRINTS where the file landed, which is how that
##     question gets an empirical answer on a machine nobody here can log into.
##   * "no pony is standing inside a prop" fails if a pony's own collision capsule
##     overlaps any prop's collider RIGHT NOW, checked by shape query rather than by
##     distance to a marker or a reroll history. The spawner's own prop-rejection
##     reroll (spawner.gd) only fires when the ground raycast that placed her hits a
##     PROPS-layer collider -- and on this exact layout no prop's footprint overlaps
##     any zone disc, so that reroll never fires here. This check exists so a pony
##     ending up inside the barn is caught independently of whether the reroll that
##     was supposed to prevent it was ever reachable.
##
## ASSETLESS CHECKOUTS ARE A DECLARED STATE, NOT A SILENT PASS. game/assets/converted/
## is gitignored, so CI and a fresh clone have no ponies and no props (docs/ci.md
## section 4). The ranch degrades to bare terrain -- that is option (a) of the three
## that doc lists, chosen because it is also what a new machine needs before the
## pipeline has been run on it -- and prints `assets=absent` so the zero counts read
## as "there was nothing to load here", not as "loading worked and found nothing".
## When assets ARE present, the counts are checked against what the layout and the
## markers say they should be, so the strict version of the gate is the one that
## runs on the machine that can actually run it.
##
## OFFSCREEN RENDERING. `xvfb-run tools/bin/godot --path game --audio-driver Dummy
## world/ranch.tscn -- --screenshot-dir=<path>` (NOT --headless) runs the same checks
## and then saves a dozen PNGs: the establishing shot, the view from the player's own
## eyes at spawn, a spawn zone with ponies in it, the camera pressed against a
## building, an eye-level look at the barn for scale, and -- added by the playtest pass,
## see _capture_the_mechanic() -- THE CORE LOOP ITSELF through the player's own camera
## with the real HUD over it: a shy pony bolting from beyond beam range, the beam and its
## landing ring at range, and a capture mid-struggle. Every check in this file is a
## number; whether the place READS as a place, and whether the mechanic READS at all, are
## not things a number can answer -- and the second of those had never been photographed
## in the real scene at all before the first playtest went and found five problems with
## it by hand.
## `--audio-driver Dummy` is required explicitly here (not implied, since this run is
## NOT --headless) -- this is the main scene, a captured pony here can fire the same
## first-capture voice line scenes/test/capture_test.gd's header describes, and
## game/systems/audio_safety.gd's Master-bus mute is a backstop, not a reason to skip
## the flag.

## Emitted instead of quitting when this ranch is HOSTED: instanced under another
## scene (scenes/test/market_test.tscn does exactly that) rather than run as the main
## scene. See _hosted below for why the quit cannot simply stay unconditional.
signal gate_report_finished(all_ok: bool)

## Emitted when a race at the Palace has been paid out, with what the player's bet returned
## (0 for a loser) and which lane won. A gate hangs off this rather than polling the track.
signal race_settled(payout: int, winner: int)

const LayersScript := preload("res://world/collision_layers.gd")
const PropsScript := preload("res://world/props.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const PlotRegistryScript := preload("res://systems/plot_registry.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")
const RegionFenceScript := preload("res://world/region_fence.gd")
const ShopItemScript := preload("res://systems/shop_item.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PenScript := preload("res://world/pen.gd")
const EconomyScript := preload("res://systems/economy.gd")
const ShopScript := preload("res://systems/shop.gd")
const SettingsScript := preload("res://systems/settings.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PlayerScript := preload("res://actors/player/player.gd")
const InputDeviceScript := preload("res://systems/input_device.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const SkyRigScript := preload("res://world/sky_rig.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const LedgerScript := preload("res://systems/ledger.gd")
const LettersScript := preload("res://systems/letters.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const PlayerLookScript := preload("res://systems/player_look.gd")
const StripScript := preload("res://world/strip.gd")
const CasinoSignScript := preload("res://systems/casino_sign.gd")
const InteractionScript := preload("res://world/interaction.gd")
const BuildingScript := preload("res://world/building.gd")
const CasinoScript := preload("res://systems/casino.gd")
const SlotsScript := preload("res://systems/slots.gd")
const WheelScript := preload("res://systems/wheel.gd")
const BlackjackScript := preload("res://systems/blackjack.gd")
const CasinoMenuScript := preload("res://ui/casino_menu.gd")
const WheelMenuScript := preload("res://ui/wheel_menu.gd")
const RaceCardScript := preload("res://systems/race_card.gd")
const RaceTrackScript := preload("res://world/race_track.gd")
const CompanyRunnersScript := preload("res://systems/company_runners.gd")
const AttendantScript := preload("res://world/attendant.gd")

## Headless watchdog ceiling. A normal run (assets present) finishes in under 2s on
## this machine; 30s leaves a wide margin for a slower box while still failing in
## seconds rather than in whatever an external timeout happens to be set to -- see
## GateWatchdog's own doc comment for why this exists at all.
const WATCHDOG_TIMEOUT_SEC := 30.0

## Physics frames awaited before the spawner's raycasts run. The terrain and prop
## colliders are created during _ready(); the physics server has not stepped since,
## so a space-state query made now sees an empty world. Two rather than one is
## belt-and-braces and costs 33 ms.
const PHYSICS_WARMUP_FRAMES := 2

## Frames the world is stepped before anything is measured, so the player and the
## herd have settled onto the ground under gravity instead of being sampled in
## mid-drop.
const SETTLE_FRAMES := 40

## Frames allowed for SpringArm3D's collision probe to settle after the player and
## the rig are moved for the camera-vs-building check (the arm casts once per
## physics frame).
const CAMERA_SETTLE_FRAMES := 8

## How far off the terrain surface a body may sit and still count as "on the
## ground", in metres. The player's and a pony's origin are both at the bottom of
## their capsule, so this is slack for the floor snap, not for a body's height.
const GROUND_TOLERANCE := 0.20

## Minimum pull-in the spring arm must show when the player has a building at her
## back: half a metre less than its commanded rest length. A wall the arm ignores
## returns exactly spring_length, so any real margin proves contact -- 0.5 m makes
## it impossible to satisfy by floating-point noise.
const MIN_CAMERA_PULL_IN := 0.5

## How far a prop's visible base may sit from where props.gd seated it, in metres.
## Tight on purpose: the seating is arithmetic, so anything but rounding here means
## a prop moved after it was placed or the AABB it was seated by is not the AABB it
## renders with.
const SEATING_TOLERANCE := 0.02

## Metres of relief allowed across the Palace's own footprint. Bigger than SEATING_TOLERANCE
## because this is the ground under a fourteen metre building rather than the seating error
## of a prop.
##
## 0.65, NOT 0.35, AND THAT NUMBER WAS MEASURED, NOT GUESSED. Terrain._raw_height() has no
## flat pocket anywhere inside the Strip's own 26 m disc that a 14 x 9 m footprint fits into
## at 0.35 m or under: a Nelder-Mead search of height_at() over the whole region (and a grid
## sweep of the original box this constant's comment used to name, x in [-10, 10], z in
## [58, 70]) bottoms out at 0.633 m, at the box's own x = -10 edge. Buildings/Palace sits at
## exactly that spot (world (-10, 0, 61.6); see strip.gd's mount_marquee(), whose board is
## read off this same building rather than typed to match it separately). Nowhere closer to
## the strip's own centre does better than about 0.95 m, which is what the original (0, 66)
## placement measured. Shrinking the building instead would fix it (relief scales with
## footprint size), but a Palace narrow enough to clear 0.35 m
## stops reading as the map's biggest building, which is the one thing ranch.tscn's comment
## on ridge_height says this building is for. 0.65 leaves a hair of margin over the measured
## 0.633 rather than trimming it to the metre.
const PALACE_MAX_RELIEF := 0.65

## Metres of relief the zone markers' ground must actually have, so that placing a
## pony by raycast is measurably different from placing her at y=0.
const MIN_ZONE_RELIEF := 0.25

## The save slot the GATE writes its round-trip probe into -- never the slot the game
## plays in (GameState.DEFAULT_SLOT, 0), so running the gate can never touch a real ranch.
##
## The probe file is deliberately LEFT ON DISK afterwards rather than cleaned up. It is the
## artefact that answers "where did `user://` actually resolve on this machine?", which is
## the single highest-value cross-platform question in this phase: on Windows `user://`
## lands in `%APPDATA%\Godot\app_userdata\Filly Rancher\`, a completely different place
## from Linux's `~/.local/share/godot/app_userdata/Filly Rancher/`
## (docs/windows-testing.md). The gate prints the globalized path of this file, so a
## Proton or CI log says exactly where the engine put it, and the file itself can then be
## found and read on the host filesystem.
const GATE_SAVE_SLOT := 9

## How close to the farmhouse door the player has to walk for the ranch to save, in
## metres, and how far she has to walk back off before it will save again. The gap between
## them is hysteresis: without it, standing in the doorway would save on every physics
## frame -- 60 file writes a second, each one copying the previous save to a backup.
##
## 6 m is a little wider than the farmhouse's own footprint (6.6 x 5.6 m), so "go home" is
## satisfied by walking up to the building rather than by finding an exact spot.
const HOUSE_SAVE_RADIUS := 6.0
const HOUSE_SAVE_REARM := 9.0

## How close to the Market's origin counts as "at the market", in metres. A little wider
## than the building's own half-diagonal (5.5 x 4.5 m, so 3.55 m corner to centre), so
## "go to the market" is satisfied by walking up to the door rather than into the wall.
const MARKET_RADIUS := 4.5

## How close to the request board's post counts as "at the board", in metres. Narrower than
## MARKET_RADIUS because the board is a small thing (3.0 x 1.2 m) five metres from the
## Market's door, and two prompts that both fire in the gap between them would be two
## toasts fighting over one patch of grass.
const BOARD_RADIUS := 3.0

## How near the loading dock she has to be for E to open the Depot. Tighter than the
## Market's radius because the Depot is a smaller building on a busier corner of the yard.
const DEPOT_RADIUS := 4.0

## How close to the Spectra Palace the counter opens from. Wider than the Depot's, because
## the Palace is fourteen metres across and the door is in the middle of one long side.
const PALACE_RADIUS := 5.0

## THE TWO PONIES BEHIND COUNTERS, and where they stand.
##
## AT THE DOOR AND FACING OUT. "Facing the counter" is resolved as standing at the counter
## and looking out across it, toward whoever walks up, which is what a vendor does and what
## makes her legible from thirty metres away.
##
## OUTSIDE THE BUILDING, not inside it, and that is a consequence of Building's plinth (see
## Building.FLOOR_TOP and Building.GROUND_DROP): the interior floor stands FLOOR_TOP +
## GROUND_DROP, 1.80 m, above the lowest corner of ground the building was seated against, so
## a body seated on the terrain inside a building would be buried in its own boards. Both
## counters are things the player opens from the door anyway.
##
## MEASURED FROM THE FOOT OF THE DOOR APRON, NOT FROM THE WALL. The ramp down from the
## doorway runs Building.DOOR_APRON_RUN out past the plinth (see Building.apron_foot_z()),
## and an attendant standing closer than that stands on ground the ramp is above: she would
## be knee deep in a plank instead of a plinth. So this is clearance PAST the ramp's foot,
## which also keeps her off the one bit of ground the player has to walk up.
const ATTENDANT_STANDOFF := 1.0

## Their looks, pinned rather than drawn. A shopkeeper who is a different colour every boot
## is a shopkeeper nobody recognises, and a gate that screenshots the Market wants the same
## picture twice.
const VENDOR_LOOK := {"coat": 2, "mane": 5, "eyes": 1, "mane_style": 1}
const TELLER_LOOK := {"coat": 6, "mane": 0, "eyes": 3, "mane_style": 3}

## Plot slots the map must carry -- the plan asks for four to six, and the reserved
## clearing (PropsScript.PEN_PLOTS_*) is an 18 m square, which fits four 7.8 m pens on a
## 9 m grid with room to walk between them. A range rather than an exact number so a later
## task can add a fifth without this becoming a two-file change, and a FLOOR because
## "somebody deleted the Plots node" must fail rather than pass with zero slots.
const MIN_PLOT_SLOTS := 4
const MAX_PLOT_SLOTS := 6

## Metres of height variation allowed across the reserved clearing.
##
## THIS IS THE ASSUMPTION game/world/pen.gd's CARPENTRY RESTS ON. A pen's fence is built
## flat in pen-local space and the pen is seated at its slot's ground height; that is only
## honest while the clearing is flat, which it is today (measured spread: 0.071 m end to
## end, because the whole clearing sits inside game/world/terrain.gd's homestead apron).
## The day a terrain retune pushes the apron in or moves the clearing out, this check goes
## red -- rather than a fence quietly floating at one corner in a screenshot nobody takes.
const PEN_GROUND_FLATNESS := 0.25

## Physics frames the pen-containment probe runs for: SETTLE_FRAMES to land and adopt their
## bodies, then PEN_PROBE_FLEE_FRAMES of the worst case.
##
## THE SECOND HALF IS THE WHOLE TEST, AND IT IS SET UP RATHER THAN WAITED FOR. Three ponies
## pottering about a paddock never go anywhere near the fence, so a probe that only watched
## them wander would pass with the leash set to anything at all -- measured: with BOTH the
## leash and the fence colliders deliberately removed, 90 frames of ordinary wandering still
## reported every pony safely inside. Waiting longer is not the fix either; it took 300
## frames (5 seconds of every boot) before a wander happened to carry one out.
##
## So the probe PUTS them in the worst case instead: each body is teleported hard against
## the fence, facing out, at PEN_PROBE_EDGE_GAP from the rails -- outside her leash, which
## is where a pony who has just overshot a flee actually is -- and the player is set down in
## the middle so the shy one bolts. From there, a leash that does not pull her back or a
## fence that does not stop her shows up within a few frames rather than eventually. 60
## frames is one second, which is what this costs a real boot.
const PEN_PROBE_FRAMES := 40
const PEN_PROBE_FLEE_FRAMES := 60

## How far inside the fence line the probe's ponies are placed, in metres. Their capsules
## are PONY_BODY_RADIUS wide, so this leaves them just touching the rails.
const PEN_PROBE_EDGE_GAP := 0.45

## Metres a probe pony must move during the flee phase for the run to count as a stress
## test. THE ANTI-VACUITY GUARD: "everybody is still inside the fence" is trivially true of
## ponies who never moved, so a physics step that stopped stepping, a state machine that
## stopped ticking, or bodies that failed to adopt would all sail through the containment
## check while measuring nothing.
const PEN_PROBE_MIN_TRAVEL := 0.30

## Ponies the containment probe puts in its pen. Three, so they crowd each other and shove
## -- one pony alone in a paddock never goes anywhere near the fence, and a containment
## check she cannot fail is not a check.
const PEN_PROBE_PONIES := 3

## The player's own capsule radius, from game/actors/player/player.tscn. Used by
## _player_stands_on_footprint(): a fence may not go up on a plot she is standing on, and
## "standing on" has to include the 0.42 m of her that reaches past her own centre.
const PLAYER_BODY_RADIUS := 0.42

## How far the gateway probe sweeps a capsule out from the middle of the pen, in metres from
## the pen's centre. 4.40 puts the trailing edge of a 0.42 m capsule at 3.98 -- clear of the
## 3.90 fence line, so reaching it means the body is genuinely OUTSIDE -- while staying
## inside the reserved clearing, whose edge is 4.50 m from a slot centre (props.gd's
## PEN_PLOTS_*). Sweeping further would run the probe out over ground where a tree is allowed
## to be, and a check that fails because of a tree is a check nobody trusts.
const GATE_PROBE_REACH := 4.40

## Height of the gateway probe's capsule centre above the pen's ground plane. Its 1.30 m body
## then spans 0.20 m to 1.50 m: high enough to clear the 0.07 m the clearing is out of level
## by, low enough to cut through the gate leaf's collider, which tops out at 1.45 m.
const GATE_PROBE_CENTRE_Y := 0.85

## How near a locked region's gateway the player has to be for the permit prompt, in
## metres. Wider than the plot slots' own triggers because a region gate is approached
## across open country rather than stepped onto: she should be told what the fence is
## while the fence is still what she is walking at, not once she is nosing the rails.
const GATE_PROMPT_RADIUS := 6.0

## How much room a region's fence ring must leave beyond the furthest a homestead pony can
## legitimately roam. See the check named "no homestead roam disc reaches a region's fence
## ring" in _report() for what goes wrong at zero.
const REGION_CLEARANCE := 1.0

## How far out from the gateway the "a locked gate is solid" ray starts and ends, in
## metres. Short enough that a horizontal ray cannot reach up into rising ground before
## it reaches the leaf, long enough to start clear of the leaf's own depth.
const GATE_RAY_REACH := 2.0

@onready var terrain: StaticBody3D = $Terrain
@onready var props: Node3D = $Props
@onready var buildings: Node3D = $Buildings
@onready var attendants: Node3D = $Attendants
@onready var spawner: Node3D = $Spawner
@onready var player: CharacterBody3D = $Player
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var capture_camera: Camera3D = $CaptureCamera
@onready var plots_root: Node3D = $Plots
## Everything that belongs to a region rather than to the homestead: the lake's water
## disc now, and Task 4's fence rings alongside it.
@onready var regions_root: Node3D = $Regions
@onready var strip: Node3D = $Strip
@onready var build_menu: CanvasLayer = $BuildMenu
@onready var market_menu: CanvasLayer = $MarketMenu
@onready var depot_menu: CanvasLayer = $DepotMenu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var casino_menu: CanvasLayer = $CasinoMenu
@onready var slots_menu: CanvasLayer = $SlotsMenu
@onready var wheel_menu: CanvasLayer = $WheelMenu
@onready var blackjack_menu: CanvasLayer = $BlackjackMenu
@onready var race_track: Node3D = $Strip/Track
@onready var race_menu: CanvasLayer = $RaceMenu
## The screen a new game opens on (Task 8): the player's own pony on a turntable, and the
## name the Company will know her by. Typed as the plain CanvasLayer ranch.tscn declares,
## reached through has_method() like every other menu here, for the same reason
## _bind_build_menu() gives: a script that failed to parse must be a FAILED check in
## _report(), not a boot that dies reaching straight into a property it does not have.
@onready var creation_screen: CanvasLayer = $CreationScreen
## THE READER FOR THE COMPANY'S POST (Ruling 25). Read only, closes on confirm, and shown
## exactly once: right after the creation screen is confirmed, carrying the WELCOME letter,
## which is where the four steps of the money loop and both of the ledger's numbers are
## written. Typed as the plain CanvasLayer ranch.tscn declares and reached through
## has_method(), like every other menu here, for the reason _bind_build_menu() gives.
@onready var letter_panel: CanvasLayer = $LetterPanel
## The sky. Typed as the plain Node3D ranch.tscn declares rather than as SkyRig, and
## always reached through has_method(), for the reason _bind_build_menu() gives about the
## menus: a sky_rig.gd that failed to PARSE leaves exactly this node in the tree with no
## script on it, and reaching straight into a method it then does not have would abort boot
## instead of showing up as a FAILED check in _report().
@onready var sky_rig: Node3D = $SkyRig

var _screenshot_dir := ""
var _rig: Node3D
var _spring_arm: SpringArm3D

## The GameState autoload (game/systems/game_state.gd), or null if it is not registered --
## which is a failed check below, not something to crash on.
var _game_state: Node

## Whether a person is playing, as opposed to a gate/CI/screenshot run. Autosave and the
## save-at-the-house trigger are enabled ONLY for this case: every automated run boots this
## same main scene with the same autoloads, and a save on quit that did not ask this
## question would end `bash tools/run_tests.sh` by overwriting the developer's ranch.
var _interactive := false

## Whether a save was found and loaded at boot. Printed, so a log says which world this is.
var _save_loaded := false

## THE CLOCK. Elapsed play time, and the phase and weather it implies
## (game/systems/world_state.gd). Owned here rather than in an autoload because it is a
## property of the SAVE, not of the process: it is built from GameState.world_seed and
## GameState.world_time in _bind_game_state(), REBUILT on state_loaded for the same reason
## rebind_economy() is (a load replaces what the state holds, and anything still pointing at
## the old objects is pointing at a world nobody is playing), ticked in _physics_process()
## and written back in _sync_game_state().
var _world: WorldState = null

## The command-line overrides, parsed in _ready() from OS.get_cmdline_user_args().
##
## `--phase=` and `--weather=` PIN the world: a screenshot run or a gate that wants a
## stormy night must be able to have one without waiting seven minutes for it and without
## the answer depending on which seed the save happens to carry. Giving only one of the two
## takes the other from the unpinned world at that moment and pins both, so `--weather=fog`
## still means "the fog that this seed and this hour would have had, held still".
##
## `--world-time=` only SETS the clock; it does not pin it. It is how you ask for "the ranch
## eleven minutes in" and then let it run.
##
## -1 and -1.0 mean "not given". Names are matched case-insensitively; anything else is a
## push_error and is ignored, because a typo in a screenshot script must be loud and must
## not silently photograph a different hour than the one that was asked for.
var _arg_phase := -1
var _arg_weather := -1
var _arg_world_time := -1.0

## How many owned ponies were put back into the saddlebag at boot. Printed rather than
## only counted: "the save loaded" and "the ponies in it reached the bag" are two different
## claims, and a restore that silently dropped them would satisfy the first one.
var _restored_ponies := 0

## False while the player is standing at the house, so the autosave fires once per visit
## instead of once per physics frame. Re-armed when she walks HOUSE_SAVE_REARM away.
var _house_armed := true

## Labels that were assigned to `checks` more than once. A Dictionary silently
## overwrites on a repeated key -- that is exactly the bug a reviewer proved live in
## `game/scenes/test/capture_test.gd` (two checks shared a label, one silently
## overwrote the other, and a whole requirement went ungated while the gate still
## printed green). `_set_check()` below is the only place `checks` may be written, and
## it records a collision here instead of only push_error'ing it, so a duplicate label
## fails the gate itself rather than merely logging a warning nobody reads.
var _duplicate_check_labels: Array[String] = []

## The buildable catalogue (game/systems/plot_registry.gd), loaded once at boot.
var _plot_registry: PlotRegistry = null

## The regions of the map (game/systems/region_registry.gd), loaded once at boot and handed
## to the terrain before it shapes itself. See the top of _ready().
var _region_registry: RegionRegistry = null

## get_region_fences() read once, right after the fences are built in _ready(), for
## nearest_locked_gate() to walk every physics frame without a get_children() scan and a
## fresh Array each time. get_region_fences() itself stays a live query: tests call it
## directly and a live query is the honest answer there.
var _region_fence_cache: Array[RegionFence] = []

## The wallet, seeded from the loaded save and written straight back into GameState.bits
## on every change. Task 6 gives this prices and a shop; here it is what the build menu
## charges against, so that "you cannot build what you cannot afford" is enforced by the
## same object that will enforce it later rather than by an int compared in the UI.
var _economy: Economy = null

## True while a collector is owed a visit. A runtime cache, not the source of truth --
## Ledger.pending_punishment is that, because it is what is actually saved.
## _seed_collector_state() below is what keeps this in step with it across a load, and
## Ledger.pending_punishment_cycle is what says WHICH dawn he may call on.
var _collector_due := false

## The crowd's palette, loaded once and kept, for _coat_word() below. The spawner keeps its
## own for the same reason; a .tres load per menu row is a load per row.
var _stock_palette: StockPalette = null

## How many plots a loaded save put back, and how many ponies went into pens rather than
## into the saddlebag. Printed by the gate.
var _restored_plots := 0
var _penned_ponies := 0

## Results of the boot-time pen-containment probe -- see _probe_pen_containment().
var _pen_probe: Dictionary = {}

## The counter the Market menu transacts against. Rebuilt by rebind_economy() rather than
## built once, because GameState REPLACES its `gems` and `inventory` objects on every load
## and reset (game_state.gd's from_dict/reset), and a Shop still holding the pouch from
## boot would be selling gems nobody owns any more.
var _shop: Shop = null

## Player preferences, owned here because this is where the things they control live: the
## camera rig and the audio bus.
var _settings: Settings = null

## Every roll at every table comes off this one generator, so a gate can seed it and get the
## same night's play back. Seeded from the clock for a person actually playing; see
## set_casino_seed().
var _casino_rng := RandomNumberGenerator.new()

## The bet currently on the track: whose race it is, which lane is backed, for how much, and
## the exact field the odds were quoted from. Kept here rather than on the track, because the
## track knows about lanes and this file knows about money.
var _race_entrant: StringName = &""
var _race_lane := -1
var _race_stake := 0
var _race_field: Array[Dictionary] = []

## The card each penned pony was last quoted at, keyed by uid. Filled by race_entrants(),
## read by start_race(), emptied by _clear_race_bet().
var _quoted_fields: Dictionary = {}

## The three standing favours (game/systems/request_board.gd). REBUILT rather than mutated
## on every load, for exactly the reason rebind_economy() rebuilds the wallet: a load
## replaces GameState.requests wholesale, and a board still holding the previous session's
## Dictionaries would be paying out requests nobody on this save was ever given.
var _board: RequestBoard = null

## The whole character roster, loaded once and kept, because the board is rebuilt on every
## load and re-reading 45 .tres files each time would be a disk scan per load. _report()
## still loads its own copy; that one is a gate deliberately re-measuring rather than
## trusting a cache.
var _roster: PonyRegistry = null

## Whether the spawner has actually populated yet. The sky's phase and weather signals can
## in principle land before that (a run that pins the clock from the command line, or a
## load fired while boot is still walking down _ready()), and refreshing a herd that does
## not exist yet would spawn the boot herd twice.
var _herd_ready := false

## Which locked region's gateway the player is currently standing at, or &"" for none.
## The region id rather than a bool because there are four gates: walking from one to
## another must produce a second prompt, and a bool would swallow it.
var _gate_prompted: StringName = &""

## Whether the cursor is currently meant to be captured to the game, mirroring the
## CAPTURED/VISIBLE split _set_cursor_captured() drives Input.mouse_mode with. Tracked as a
## plain bool ON RANCH, separately from Input.mouse_mode itself, because Godot's headless
## display driver always reports Input.mouse_mode as MOUSE_MODE_VISIBLE no matter what was
## last assigned to it (confirmed empirically -- `godot --headless` never returns anything
## else from the getter) -- which would make the creation screen's cursor wiring the one
## piece of it no headless test could ever observe. game/test/test_ranch_creation.gd reads
## this instead. Starts true: camera_rig.gd captures the mouse in its own _ready(), before
## any menu (including this one) has had a chance to run.
var _cursor_captured := true

## Is this ranch the scene the process was launched with, or is it INSTANCED UNDER another
## scene that owns the process?
##
## _report() below ends a headless run with get_tree().quit(), and _ready() arms a
## GateWatchdog on the same assumption, both correct when world/ranch.tscn IS the run.
## A test scene that instances the ranch to drive it (scenes/test/market_test.tscn) would
## have the process shut down underneath it before its own driver got a frame, and would
## be racing a second watchdog it did not arm. Hosted, the verdict is EMITTED
## (gate_report_finished) and the host decides what to do with it.
var _hosted := false


func _ready() -> void:
	# Asked before anything else, because the very next line depends on the answer: a
	# hosted ranch neither arms the watchdog nor quits the process. See _hosted.
	_hosted = get_tree().current_scene != self

	# Armed FIRST, before anything below has a chance to raise mid-function -- see
	# GateWatchdogScript's doc comment for the exact hang this guards against. Not armed
	# when hosted: the host owns the process, and its own watchdog is the one that should
	# be allowed to kill it.
	if not _hosted:
		GateWatchdogScript.arm(self, "RANCH", WATCHDOG_TIMEOUT_SEC)

	# THE GROUND, BEFORE ANYTHING ASKS WHERE IT IS. The Terrain node readies before this
	# function runs (children ready first) and, because ranch.tscn sets defer_build on it,
	# deliberately built nothing: the lake is a hole in the heightfield, so the terrain has
	# to know which regions are on it before the first vertex is placed. Every later line
	# here reads terrain.height_at() to seat a building, a plot, a prop or a pony, so the
	# handover and the build happen here, at the very top, or all of them are seated against
	# a map that does not exist yet.
	terrain.regions = _regions_registry()
	terrain.build()
	for region: RegionData in _regions_registry().all():
		if region.has_lake:
			regions_root.add_child(terrain.build_water(region))

	# THE FENCES, HERE AND NOT IN THE SCENE FILE. A ring of rails has to be seated on the
	# ground post by post, and the ground does not exist until the two lines above have
	# run; a fence built in ranch.tscn would be a ring of timber hanging at y = 0 over a
	# map with two and a half metres of relief in it. The scene holds four empty nodes
	# with the script on them and nothing else, which is also what keeps them findable by
	# name here rather than conjured out of the registry.
	#
	# They all come up SHUT. _apply_permits() opens the ones the save paid for, and it
	# cannot be called from here: the save has not been read yet. It is read by
	# _bind_game_state() a few dozen lines down, and the call follows it.
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
		# KEEP THE LIGHT RING OFF THE PALACE. The ring is centred on the region, the Palace
		# is not (see PALACE_MAX_RELIEF's comment), so one ring position falls inside its
		# footprint; read straight off the live node rather than a second copy of its
		# position and size, so a later re-siting of the Palace cannot leave this stale.
		var palace_building: Building = get_node_or_null(^"Buildings/Palace") as BuildingScript
		if palace_building != null:
			strip.avoid_footprint(
				Vector2(palace_building.global_position.x, palace_building.global_position.z),
				Vector2(palace_building.width * 0.5, palace_building.depth * 0.5))
			# THE SIGN IS SIZED AND PLACED FROM THE BUILDING, off the live node, for the
			# reason avoid_footprint() is: a hand typed world position for the marquee is
			# what put a 66 character line at y = 5.4 on a building whose ridge is at 4.6.
			#
			# AND THE WAY IT FACES COMES OFF THE SAME NODE. A Building's door is in its local
			# plus Z gable end, so the front face and the direction the sign has to look are
			# that axis put through the building's own basis, the same derivation
			# _stand_one() uses to work out which side of a building an attendant stands on.
			# This used to be "minus half the depth along world Z" plus a half turn baked
			# into strip.gd, which is the Palace's CURRENT angle written down twice and wrong
			# for any other.
			var palace_out: Vector3 = palace_building.global_transform.basis \
				* Vector3(0.0, 0.0, 1.0)
			palace_out.y = 0.0
			palace_out = palace_out.normalized() if palace_out.length_squared() > 0.0 \
				else Vector3(0.0, 0.0, 1.0)
			strip.mount_marquee(
				palace_building.global_position
					+ palace_out * (palace_building.depth * 0.5),
				palace_out,
				Vector2(palace_building.width * 0.5, palace_building.depth * 0.5),
				palace_building.global_position.y + palace_building.ridge_height)
		strip.build()

	if race_track != null and race_track.has_method("configure"):
		race_track.call("configure", Callable(terrain, "height_at"))
		race_track.call("build")
		if not race_track.is_connected("race_finished", _on_race_finished):
			race_track.connect("race_finished", _on_race_finished)

	# EVERY PONY WHO EVER REACHES THE MAP, at boot and at every later change of sky (see
	# Spawner.pony_spawned). Connected at the top of boot rather than beside the populate()
	# call below because populate() emits it from inside itself: a connect made after that
	# call would miss the entire boot herd and only ever see the arrivals.
	#
	# connect()-by-name, matching _bind_build_menu(): `spawner` is typed as the Node3D
	# ranch.tscn declares, and the string form is how the rest of this file reaches a
	# script member through a node typed by its scene rather than by its script.
	if not spawner.is_connected("pony_spawned", _on_pony_spawned):
		spawner.connect("pony_spawned", _on_pony_spawned)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]
		elif arg.begins_with("--phase="):
			_arg_phase = _parse_named_value(arg, WorldStateScript.PHASE_NAMES, "phase")
		elif arg.begins_with("--weather="):
			_arg_weather = _parse_named_value(arg, WorldStateScript.WEATHER_NAMES, "weather")
		elif arg.begins_with("--world-time="):
			var seconds := arg.split("=", true, 1)[1]
			if seconds.is_valid_float():
				_arg_world_time = maxf(0.0, float(seconds))
			else:
				push_error("ranch: --world-time=%s is not a number of seconds; ignored."
					% seconds)

	_interactive = DisplayServer.get_name() != "headless" and _screenshot_dir == ""

	_rig = player.get_camera_pivot().get_node("CameraRig")
	_spring_arm = _rig.get_node("SpringArm3D")

	player.global_position = player_spawn.global_position

	# EVERY MENU IS SHUT UNTIL IT IS WIRED, and this is the first line of _ready() that can
	# be reached with the tree already accepting input. Boot takes about two and a half
	# seconds from here (the physics warmup, the pen-containment probe, the settle frames)
	# and _bind_pause_menu() does not run until the end of it. Escape pressed during the
	# wait used to raise a PAUSED panel over a world that was still running, with a
	# Save and a Quit connected to nothing and no ranch listening for `opened` to pause the
	# tree. The refusal is the shutter the menus already have for "another menu is up"; the
	# bind functions below overwrite it with the real predicate once there is something
	# behind it. set() by name for the reason _bind_build_menu() gives: a menu whose script
	# failed to parse is a FAILED check in _report(), not a boot that dies here.
	for menu: CanvasLayer in [build_menu, market_menu, pause_menu, depot_menu, casino_menu,
			slots_menu, wheel_menu, blackjack_menu, race_menu]:
		if menu != null:
			menu.set("can_open", func() -> bool: return false)

	# BEFORE the spawner runs: a loaded save carries the seed the wild world was generated
	# from, and applying it afterwards would mean the herd you come back to is not the herd
	# you left.
	_bind_game_state()

	# THE RAIN NEEDS SOMEBODY TO FALL ON. _bind_game_state() above built the WorldState and
	# has already handed it to the rig (apply_immediately, so boot has no eight second ramp
	# from a sky nobody saw), which leaves only this: the rain is a small column overhead
	# rather than a lid over 220 metres of map, so it travels with the player.
	if sky_rig != null and sky_rig.has_method("follow"):
		sky_rig.follow(player)

	# IMMEDIATELY AFTER the save is read, and long before the ponies in it are put back.
	# The gear a save records changes how much the world can hold: the saddlebag the player
	# bought is what says whether her herd fits in it. So it is applied here, at the top of
	# boot, rather than in _bind_build_menu()'s rebind_economy() at the bottom.
	# It used to run at the bottom, which meant _restore_owned_ponies() below poured a
	# 15-pony save into a bag still at its base 12 and left three ponies in neither the bag
	# nor a pen. The beam exists by now (it is a child of the player scene), and
	# MagicBeam.apply_unlocks() is absolute rather than incremental, so rebind_economy()'s
	# own call later is a harmless no-op.
	_apply_unlocks()

	# And the permits the same save carries, on the fences built at the top of this
	# function. A region she has already paid for must be open before she can reach it,
	# and "before" here means before the first frame, not after the first walk out there.
	_apply_permits()

	# The hand-built barn and farmhouse first: they are the map's only real buildings
	# (game/world/building.gd says why), they exist on every checkout including CI,
	# and they are seated by exactly the rule props.gd seats the Kenney props with -- except
	# for WHICH ground height that rule is handed. A Building is 14 by 9 m, not a point, and
	# Building.seat_ground() reads the LOWEST corner of its own footprint rather than the
	# single sample under its origin, which is what building.gd's SEAT_CLEARANCE exists for
	# (see its own comment): a plinth deep enough to clear a dipping corner does nothing if
	# it is still seated against the middle of the footprint instead.
	for node: Node3D in buildings.get_children():
		node.build()
		var seat_height: float = terrain.height_at(node.global_position.x, node.global_position.z)
		var seated_building: Building = node as BuildingScript
		if seated_building != null:
			seat_height = seated_building.seat_ground(Callable(terrain, "height_at"))
		PropsScript.seat(node, seat_height)

	# THE VENDOR AND THE TELLER, right after the buildings that give them their doors are
	# seated: _stand_attendants() reads the live building nodes' global_position/depth, so
	# it has to run after this loop, not before it.
	_stand_attendants()

	# THE LOADING DOCK STAYS ON THE GROUND. Buildings/Depot/Crate is a Marker3D authored at
	# local y = 0, which used to put it right at the old thin floor's own height; now that a
	# Building's local y = 0 is buried SKIRT_DEPTH inside a plinth deep enough to clear the
	# map's worst relief, a child left at that reference rides up with the whole building
	# instead of staying where a pony delivering a crate can actually walk up to it. She
	# arrives on the ground, not on the Depot's own doorstep, so the mark she is walking
	# toward has to stay down there with her rather than floating at plinth height.
	#
	# Its z in ranch.tscn stands clear of the door apron's foot for the reason
	# ATTENDANT_STANDOFF gives: a dock mark under the ramp is a pony walking into one.
	var crate_marker := get_node_or_null(^"Buildings/Depot/Crate") as Node3D
	if crate_marker != null:
		crate_marker.global_position.y = terrain.height_at(
			crate_marker.global_position.x, crate_marker.global_position.z)

	# THE SIGN READS ITSELF OUT OF THE GAMES. Written here rather than authored into
	# ranch.tscn so that the lobby cannot advertise a house edge the tables are not actually
	# charging; game/systems/casino_sign.gd asks each game for its own number.
	var lobby_sign := get_node_or_null(^"Buildings/Palace/Sign") as Label3D
	if lobby_sign != null:
		lobby_sign.text = "\n".join(CasinoSignScript.lines())

	var prop_count: int = props.build() + buildings.get_child_count()

	# THE BEAM'S CATCHES, BEFORE THERE IS ANYTHING ON THE MAP TO CATCH. The beam is a child
	# of the player scene and so has existed since the first line of this function; the
	# connection is made here, immediately above populate(), because everything a capture
	# records (the compendium, the board) is about the ponies populate() is about to place.
	_bind_capture()

	for i in range(PHYSICS_WARMUP_FRAMES):
		await get_tree().physics_frame

	# THE HERD KEEPS THE HOUR THE SAVE WAS QUIT AT. populate() takes the sky it is drawing
	# for (slice 5 task 1), and _world is already built by _bind_game_state() above, so a
	# save quit at midnight boots into the ponies who are actually out at midnight rather
	# than into the DAWN default and then a correction on the next phase flip.
	var pony_count: int = spawner.populate(_world.phase(), _world.weather()) if _world != null \
		else spawner.populate()
	_herd_ready = true

	# The plot slots are seated on the terrain before anything is built on them, so a pen
	# inherits a slot that is already standing on the ground rather than having to find it
	# for itself.
	_seat_plot_slots()

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	# BEFORE the save's own plots are restored, while every slot is guaranteed empty: put a
	# pen up, drop ponies in it, watch whether they stay, and take it down again. See
	# _probe_pen_containment() for why this happens at boot in every mode rather than only
	# in a gate run.
	_pen_probe = await _probe_pen_containment()

	# Now the player's actual ranch: what she built, then who lives in it.
	_restored_plots = _restore_plots()

	# After the beam exists and the world has settled: put the ponies the player owned when
	# she quit back where they live -- pens first, saddlebag for everyone else.
	_restored_ponies = restore_owned_ponies()

	_bind_build_menu()

	await _report(pony_count, prop_count)

	_apply_player_look()
	_maybe_open_creation()


# --- saving and loading ----------------------------------------------------------------

## Find the GameState autoload, load the play slot if there is one, and decide whether this
## run is allowed to write anything.
##
## THE SEED IS PUSHED BOTH WAYS, ONCE, AND ONLY HERE. A loaded save hands its `world_seed`
## to the spawner, so coming back gives you the ranch you left. A run with NO save takes the
## spawner's own exported default INTO the state, so the very first save records the seed the
## world was actually generated with rather than a default that a later edit to spawner.tscn
## could silently change out from under it.
##
## AFTER THIS THE STATE OWNS THE NUMBER AND THE SPAWNER READS IT. Every later load re-reads
## it into the spawner from _rebuild_world_state(), and _sync_game_state() never writes it
## back; the two directions used to fight, and the loser was the loaded save.
func _bind_game_state() -> void:
	_game_state = get_node_or_null(^"/root/GameState")
	if _game_state == null:
		# Not fatal here -- it is a FAILED check in _report(), which is a better place for
		# it than a crash during boot. The clock is still built, off the spawner's own seed:
		# a session that cannot SAVE is still a session that has an hour in it, and
		# get_world_state() returning null would take the sky down with the save system.
		push_error("ranch: the GameState autoload is not registered; this session cannot save.")
		_rebuild_world_state()
		return

	# A HOSTED RANCH NEVER READS THE PLAYER'S SAVE. A gate has to reach the same verdict on
	# every machine, and whatever slot 0 happens to hold on this one is not that; nor is a
	# gate entitled to a real save file. Nothing is written back either: autosave is off for
	# every non-interactive run (see _interactive below).
	if _hosted:
		_game_state.reset()
		_save_loaded = false
	else:
		_save_loaded = _game_state.load_from_slot()
	if _save_loaded:
		spawner.spawn_seed = _game_state.world_seed
	else:
		_game_state.world_seed = spawner.spawn_seed

	# Every write -- the one at the house AND the one on quit -- pulls the live world in
	# through this first. Without it, quitting would save whatever the state last happened
	# to hold, which for a session that never walked home is an empty saddlebag.
	_game_state.world_sync = Callable(self, "_sync_game_state")

	# Only a person playing may write. See _interactive's comment.
	_game_state.autosave_enabled = _interactive

	# CONNECTED AFTER load_from_slot() above, on purpose: that call emits state_loaded
	# itself, and rebuilding the economy from inside boot would only be undone by
	# _bind_build_menu() a moment later. This is for the loads that come AFTER boot, each
	# of which hands GameState a brand new GemPouch and a brand new Inventory.
	if not _game_state.state_loaded.is_connected(rebind_economy):
		_game_state.state_loaded.connect(rebind_economy)

	# THE CLOCK, FROM THE SAVE THAT WAS JUST READ, and rebuilt on every load after this one
	# for exactly the reason the line above rebuilds the economy: a load REPLACES what
	# GameState holds, and a WorldState still counting from the world_time of the session
	# being replaced is the clock of a ranch nobody is playing any more. Connected after
	# load_from_slot() above for the same reason too; that call emits state_loaded itself,
	# and the build immediately below is the one boot wants.
	_rebuild_world_state()
	if not _game_state.state_loaded.is_connected(_rebuild_world_state):
		_game_state.state_loaded.connect(_rebuild_world_state)

	# AND THE HERD THAT CLOCK IMPLIES, LAST OF THE THREE. Connected after the rebuild above
	# so it runs after it: a save loaded at midnight has to have its WorldState in place
	# before anything asks what hour to draw ponies for. Deliberately NOT folded into
	# _rebuild_world_state() itself, because that function is also called by _report()'s
	# reload probe, which is measuring the sky and has no business shuffling the herd while
	# it does. Nothing happens on the boot load: this connect comes after load_from_slot().
	if not _game_state.state_loaded.is_connected(_refresh_herd):
		_game_state.state_loaded.connect(_refresh_herd)


## Put the owned ponies back where they live after a load.
##
## PENS FIRST, SADDLEBAG SECOND. Every pony carries the slot she lives on in her own record
## (PonyInstance.home_slot -- see game/world/pen.gd on why her address is in there rather
## than in a second list), so a load is: for each pony, find her pen, put her in it;
## everyone else goes in the bag. This is the arrangement Task 2's version of this function
## said was a stopgap -- "Task 3's pens are where the ones that do not fit will actually
## live" -- and it is retired here.
##
## A PONY WHOSE PEN IS GONE goes in the bag AND HAS HER ADDRESS CLEARED. Her pen may have
## been demolished, or her save may name a plot type this build no longer carries, or the
## pen may be full because its capacity was retuned downward. Leaving her address pointing
## at a pen that has no record of her would mean she is filed in two places at once: in the
## bag, and (as far as the save is concerned) in a pen. One of those has to win, and it has
## to be the one that is actually holding her.
##
## Storage is still fixed-capacity, so a save holding more ponies than pens-plus-bag can
## carry cannot be fully restored -- which is why _sync_game_state() below still MERGES
## rather than overwrites. A pony who did not fit anywhere stays in the file.
##
## THE GEAR IS APPLIED FIRST, HERE, and not only by _ready()'s call above. How many ponies
## fit in the bag is the whole subject of this function's second half, and the answer is
## bought in the Market: a save carrying `bigger_saddlebag` restores into a bag of 18, and
## the same save restored into a bag of 12 silently strands the difference. Putting the
## call inside the function that depends on it means no caller can reintroduce the ordering
## bug by calling this one line too early. apply_unlocks() is absolute, so the repeat costs
## nothing.
##
## CALLING THIS TWICE IN ONE SESSION IS SAFE. Every pony already living in a pen or already
## in the bag is skipped by uid, so a second call after a mid-session load places only what
## is actually missing. Without that skip a second call was destructive rather than merely
## wasteful: a resident whose pen already holds her fails add_pony() (it refuses a duplicate
## uid), which used to fall through to the `else` below, clear her address and file her in
## the bag as well: one pony, two homes.
##
## Returns how many ponies THIS call placed. On boot, when nothing is placed yet, that is
## the whole restored herd.
func restore_owned_ponies() -> int:
	if _game_state == null:
		return 0
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return 0
	_apply_unlocks()
	var storage: Storage = beam.get_storage()

	var pens := {}
	var already_home := {}
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen != null:
			pens[String(slot.slot_id)] = pen
			for resident: PonyInstance in pen.ponies():
				already_home[resident.uid] = true
	for carried: PonyInstance in storage.contents():
		already_home[carried.uid] = true

	var restored := 0
	var to_the_bag: Array[PonyInstance] = []
	for instance: PonyInstance in _game_state.get_ponies():
		if already_home.has(instance.uid):
			continue
		var pen: Pen = pens.get(String(instance.home_slot), null)
		if pen != null and pen.add_pony(instance):
			restored += 1
			_penned_ponies += 1
		else:
			instance.home_slot = &""
			to_the_bag.append(instance)

	for instance in to_the_bag:
		if not storage.store(instance):
			break
		restored += 1
	return restored


# --- plots ---------------------------------------------------------------------------

## Every PlotSlot on the map, in scene order. Filtered by type rather than by node name so
## a slot renamed in ranch.tscn does not silently disappear from the ranch's own idea of
## how many slots it has (which is what MIN_PLOT_SLOTS then measures).
func _plot_slots() -> Array[PlotSlot]:
	var found: Array[PlotSlot] = []
	if plots_root == null:
		return found
	for child in plots_root.get_children():
		if child is PlotSlotScript:
			found.append(child)
	return found


## Stand every slot on the ground and wire its `built` signal. The same seating rule
## props.gd uses -- one rule for the whole map.
func _seat_plot_slots() -> void:
	for slot in _plot_slots():
		slot.global_position.y = terrain.height_at(slot.global_position.x,
			slot.global_position.z)
		if not slot.built.is_connected(_on_plot_built):
			slot.built.connect(_on_plot_built)


## The catalogue, loaded once.
func _plots_catalogue() -> PlotRegistry:
	if _plot_registry == null:
		_plot_registry = PlotRegistryScript.new()
		_plot_registry.load_all(PlotRegistryScript.PLOT_DIR)
	return _plot_registry


## The regions, loaded once. Same shape as _plots_catalogue() above.
func _regions_registry() -> RegionRegistry:
	if _region_registry == null:
		_region_registry = RegionRegistryScript.new()
		_region_registry.load_all(RegionRegistryScript.REGION_DIR)
	return _region_registry


## Replay `GameState.plots` onto the slots. Returns how many went back up.
##
## A SAVED PLOT TYPE THIS BUILD DOES NOT CARRY leaves the slot EMPTY AND BUILDABLE, loudly.
## The alternative -- substituting some other plot -- would silently change what the player
## built, and refusing to load would cost her the whole ranch over one renamed .tres.
func _restore_plots() -> int:
	if _game_state == null:
		return 0
	var built := 0
	for slot in _plot_slots():
		var plot_id := str(_game_state.plots.get(String(slot.slot_id), ""))
		if plot_id.is_empty():
			continue
		var plot: PlotData = _plots_catalogue().by_id(StringName(plot_id))
		if plot == null:
			push_error(("ranch: the save says slot '%s' holds a '%s', which is not a plot " +
				"type this build carries. The slot has been left empty and buildable.")
				% [String(slot.slot_id), plot_id])
			continue
		if slot.build(plot):
			built += 1
	return built


## What is standing on the slots right now, as the {slot id -> plot id} dictionary of
## Strings GameState.plots wants (JSON has no integer keys -- see game_state.gd). Slots
## with nothing on them are OMITTED rather than stored as "": an empty entry and a missing
## one mean the same thing, and only one of them costs bytes in a file a human reads.
func _live_plots() -> Dictionary:
	var live := {}
	for slot in _plot_slots():
		if not slot.is_empty():
			live[String(slot.slot_id)] = slot.saved_plot_id()
	return live


## Hand a freshly built pen the terrain sampler, so the residents it sets down stand on the
## ground rather than at the slot's exact height. (The fence itself is built flat in
## pen-local space; PEN_GROUND_FLATNESS above is the check that keeps that honest.)
func _on_plot_built(_plot: PlotData, node: Node) -> void:
	var pen := node as Pen
	if pen != null:
		pen.ground_sampler = Callable(terrain, "height_at")
		# The pantry a pen feeds from is GameState's, read fresh on every call rather than
		# captured here. See _current_inventory().
		pen.inventory_provider = Callable(self, "_current_inventory")


## Wire the build menu to the wallet and to the thing that actually builds.
##
## THE TRANSACTION LIVES HERE, NOT IN THE MENU. The menu emits "she picked this"; this is
## what checks the wallet, calls PlotSlot.build(), and only then spends. Charging BEFORE
## the build would need a refund path for a build that failed, and a refund path is a place
## for bits to be created out of nothing.
func _bind_build_menu() -> void:
	# The wallet, the shop and the other two menus FIRST, and outside the guard below: a
	# build menu whose script failed to parse is a FAILED check, not a reason for the
	# Market and the pause menu to go unwired with it.
	rebind_economy()
	_bind_market_menu()
	_bind_depot_menu()
	_bind_casino_menus()
	_bind_pause_menu()
	_bind_letter_panel()

	if build_menu == null or not build_menu.has_method("open"):
		return
	# set()/connect()-by-name rather than direct property access and `.plot_chosen.connect`,
	# because `build_menu` is typed as the CanvasLayer that ranch.tscn declares. A build menu
	# whose SCRIPT failed to parse is still exactly that -- a CanvasLayer with no script --
	# and reaching straight into a property it then does not have raises a runtime error that
	# aborts this function. The whole point of the has_method() guard above is that a broken
	# menu is a FAILED check in _report(), not a boot that dies before it gets there.
	build_menu.set("bits_provider", Callable(self, "_current_bits"))
	build_menu.set("can_open", func() -> bool: return _no_menu_but(build_menu))
	if not build_menu.is_connected("plot_chosen", _on_plot_chosen):
		build_menu.connect("plot_chosen", _on_plot_chosen)
	if not build_menu.is_connected("opened", _on_menu_opened):
		build_menu.connect("opened", _on_menu_opened)
	if not build_menu.is_connected("closed", _on_menu_closed):
		build_menu.connect("closed", _on_menu_closed)


## THE WORLD STOPS WHILE THE MENU IS UP. See game/ui/build_menu.gd's class comment for why
## this lives here rather than in the menu: the player reads WASD with
## Input.is_action_pressed() in _physics_process, which no amount of consuming events in a
## UI script will stop, and `ui_down` shares the down arrow with `move_back`.
##
## The cursor is released with it, because game/actors/player/camera_rig.gd only turns the
## camera while the mouse is CAPTURED -- so letting it go also stops mouse-look, and a menu
## you cannot get the pointer back from is a menu players close with Alt-F4.
func _on_menu_opened(_slot: PlotSlot) -> void:
	get_tree().paused = true
	_set_cursor_captured(false)


func _on_menu_closed() -> void:
	get_tree().paused = false
	_set_cursor_captured(true)


## THE ONE PLACE THE CURSOR IS SHOWN OR HIDDEN. Split out of _on_menu_opened()/
## _on_menu_closed() so _maybe_open_creation()/_on_creation_confirmed() below can free and
## re-capture the mouse through the SAME path every other menu uses, without also touching
## get_tree().paused a second time -- the creation screen already owns that toggle itself
## (CreationScreen.open()/confirm()). Only a person actually playing has a cursor worth
## moving: a headless or screenshot run has no window to capture it into, and grabbing it
## during an automated capture is exactly the kind of thing that makes people stop running
## captures. Touches nothing but Input.mouse_mode, so it needs no tree and is exactly what
## game/test/test_ranch_creation.gd drives on a Ranch that was never added to one.
func _set_cursor_captured(captured: bool) -> void:
	_cursor_captured = captured
	if _interactive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _current_bits() -> int:
	return _economy.bits if _economy != null else 0


func _on_bits_changed(new_total: int) -> void:
	if _game_state != null:
		_game_state.bits = new_total
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_bits"):
		hud.set_bits(new_total)


## REBUILD THE WALLET AND THE SHOP FROM WHATEVER GameState HOLDS RIGHT NOW.
##
## Public, and connected to GameState.state_loaded, because a load does not mutate the
## pouch and the pantry: it REPLACES them (game_state.gd's from_dict(), and reset() the
## same way). A Shop built once at boot would go on selling out of the GemPouch object the
## title screen made, while the game credited gems to a different one, and nothing would
## look wrong until the numbers stopped matching.
##
## Pens need no equivalent: _current_inventory() below is a Callable that reads
## _game_state.inventory on every call, so a pen always feeds from the live pantry.
func rebind_economy() -> void:
	if _economy != null and _economy.bits_changed.is_connected(_on_bits_changed):
		_economy.bits_changed.disconnect(_on_bits_changed)
	_economy = EconomyScript.new(_game_state.bits if _game_state != null else 0)
	_economy.bits_changed.connect(_on_bits_changed)

	_shop = ShopScript.new(_economy, _game_state.gems, _game_state.inventory,
		_game_state.unlocks) if _game_state != null else null
	if market_menu != null:
		market_menu.set("shop", _shop)

	_apply_unlocks()
	# The permits ride in the same replaced `unlocks` array as the gear, so the fences
	# have to be re-read from it here too. This is what makes a mid-session load put the
	# regions back the way the loaded save left them rather than the way the session that
	# is being replaced left them.
	_apply_permits()

	# EVERY PONY THE PLAYER OWNS IS A PONY SHE HAS CAUGHT, and the compendium has to be
	# told so on every load, not only on a fresh one. A save written before slice 5
	# carries a full paddock and an empty compendium (SaveIO.migrate() adds the key, not
	# its contents), and a player who has to re-catch her own herd to fill the book in
	# would rightly call that a bug. Before the board is rebuilt, because the board's fill()
	# reads the compendium to decide who it may ask her to go and find.
	_mark_owned_caught()

	# The board, from whatever GameState holds right now, for rebind_economy()'s own reason:
	# a load REPLACES `requests` rather than mutating it.
	_rebuild_request_board()

	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_bits"):
		hud.set_bits(_economy.bits)

	if _game_state != null and not _game_state.ledger.changed.is_connected(_on_balance_changed):
		_game_state.ledger.changed.connect(_on_balance_changed)
	_apply_padlocks()
	_apply_beam_recall()
	_seed_collector_state()
	_push_balance()
	# A mid-session load REPLACES GameState.player (from_dict()), so the pony on screen has
	# to be re-dressed here too, or a loaded save would show the look of the session it
	# replaced until the player next changed a swatch.
	_apply_player_look()


func _on_balance_changed(_balance: int) -> void:
	_push_balance()


## WHATEVER THE COLLECTOR OWES RIGHT NOW, READ OFF THE PERSISTED LEDGER rather than left at
## _collector_due's own runtime default of false. Called from rebind_economy(), so both a
## boot that finds a save already on disk and a mid session load reach the same state a
## live session would: the punishment itself was always saved correctly
## (Ledger.to_dict()/from_dict(), Ledger.pending_punishment), but nothing used to tell this
## var about it, so a load silently swallowed an armed collector until the next collection
## day happened to arm a fresh one.
func _seed_collector_state() -> void:
	if _game_state == null:
		return
	_collector_due = _game_state.ledger.pending_punishment != LedgerScript.Punishment.NONE


# --- the clock and the sky --------------------------------------------------------------

## The world clock this ranch is running on, or null only if boot has not reached
## _bind_game_state() yet. Exposed for gates and tests, which otherwise cannot tell a ranch
## whose clock stopped from one that is simply in a long DAY.
func get_world_state() -> WorldState:
	return _world


## MOVE THE CLOCK BY HAND. The public way for a gate or a test to reach an hour without
## sitting through it; _physics_process() below ticks only for somebody actually playing,
## precisely so that a gate, a screenshot run or a headless test never moves the world's
## time as a side effect of existing.
##
## A pinned world ignores this, by design: pinning means "hold still", and a gate that
## pinned an hour and then advanced past it would be asking for two different things.
func advance_world(seconds: float) -> void:
	if _world != null:
		_world.advance(seconds)


## BUILD (OR REBUILD) THE CLOCK FROM WHATEVER GameState HOLDS RIGHT NOW, apply the
## command-line overrides to it, and point the sky and the HUD at the result.
##
## Connected to GameState.state_loaded, and the reason is rebind_economy()'s: a load does
## not mutate the numbers, it replaces the object holding them. The old WorldState is
## disconnected here rather than left to be freed quietly, so a mid-session load cannot
## leave two clocks driving one sky; which would look like a sky that ramps twice as fast
## and only on saves that were loaded rather than booted into.
##
## THE OVERRIDES ARE RE-APPLIED ON EVERY REBUILD, not only at boot. A screenshot run pinned
## to a stormy night that loaded a save halfway through would otherwise photograph whatever
## hour the save happened to hold.
func _rebuild_world_state() -> void:
	# THE SPAWNER'S SEED, RE-READ FROM THE STATE FIRST. _bind_game_state() pushes the loaded
	# save's world_seed into the spawner at boot and never again, so before this line a
	# mid-session load left the herd being drawn from the seed of the session that had just
	# been replaced, while the board beside it was rebuilt from the loaded one. The state
	# OWNS the number and the spawner reads it; here, at the one place a load's numbers are
	# taken up, and before the post-load refresh draws anything with it.
	#
	# A no-op at boot in both directions: _bind_game_state() has already made the two agree
	# by then, whichever of them was the source. A no-op in _report()'s reload probe too,
	# which does not touch world_seed.
	if _game_state != null:
		spawner.spawn_seed = _game_state.world_seed

	if _world != null:
		if _world.phase_changed.is_connected(_on_world_phase_changed):
			_world.phase_changed.disconnect(_on_world_phase_changed)
		if _world.weather_changed.is_connected(_on_world_weather_changed):
			_world.weather_changed.disconnect(_on_world_weather_changed)

	_world = _build_world_state()
	_world.phase_changed.connect(_on_world_phase_changed)
	_world.weather_changed.connect(_on_world_weather_changed)

	if sky_rig != null and sky_rig.has_method("apply_immediately"):
		sky_rig.apply_immediately(_world)
	_show_world_line()


## A CLOCK BUILT FROM GameState'S OWN NUMBERS, WIRED TO NOTHING. What a save loaded at this
## instant would restore: the same seed, the same elapsed seconds and the same
## --phase=/--weather=/--world-time= overrides.
##
## SEPARATE FROM _rebuild_world_state() BECAUSE CONSTRUCTING A CLOCK AND INSTALLING ONE ARE
## TWO JOBS. Installing is the delicate half (disconnect the old state's signals, connect
## the new one's, re-aim the sky, repush the HUD label) and reads as itself only once the
## eight lines of "which seed, which second, pinned to what" are somewhere else. Nothing
## here is connected to anything or held by anybody; the caller decides what the clock
## becomes.
##
## PINNED BEFORE ANYTHING IS LISTENING, on purpose: pin() emits phase_changed and
## weather_changed for whichever half it moved, and a rig connected first would start an
## eight second ramp away from a sky that was never on screen. _rebuild_world_state()
## connects the signals AFTER this returns, and its apply_immediately() is what puts the
## pinned sky up, in one frame.
func _build_world_state() -> WorldState:
	var world_seed: int = _game_state.world_seed if _game_state != null else spawner.spawn_seed
	var elapsed: float = _game_state.world_time if _game_state != null else 0.0
	if _arg_world_time >= 0.0:
		elapsed = _arg_world_time
	var built := WorldStateScript.new(world_seed, elapsed)
	if _arg_phase >= 0 or _arg_weather >= 0:
		# Only one of the two given means the other is taken from the UNPINNED world at
		# this moment; the weather this seed and this hour would really have had; and
		# then both are held.
		var phase: int = _arg_phase if _arg_phase >= 0 else built.phase()
		var weather: int = _arg_weather if _arg_weather >= 0 else built.weather()
		built.pin(phase, weather)
	return built


## A phase flip and a weather roll are two signals that can land on the same frame, and
## both mean the same thing to the sky and to the HUD, so both go through one place. A
## second apply() mid ramp is continuous by construction (see SkyRig.apply), so the pair
## bends the light rather than fighting over it.
func _on_world_phase_changed(_phase: int) -> void:
	_on_world_changed()


func _on_world_weather_changed(_weather: int) -> void:
	_on_world_changed()


func _on_world_changed() -> void:
	if sky_rig != null and sky_rig.has_method("apply"):
		sky_rig.apply(_world)
	_show_world_line()
	# CALLED FROM IN HERE RATHER THAN FROM A SECOND LISTENER ON THE SAME TWO SIGNALS. The
	# reload probe in _report() asserts phase_changed and weather_changed carry EXACTLY one
	# connection each (a second clock driving one sky is the bug that check exists for), so
	# "the herd changes with the hour" has to ride the connection that is already there.
	_refresh_herd()
	_maybe_run_collection_day()
	_maybe_serve_collector()


## THE SKY TURNED OVER, SO THE HERD DOES TOO. Everybody whose hours have ended walks off,
## everybody whose hours have begun walks on; see Spawner.refresh() for the draw and for
## why nothing here can delete a pony.
##
## SAID OUT LOUD ONLY WHEN SOMETHING MOVED, AND ONLY THE HALF THAT MOVED. A phase that
## changes nothing about who is out (DAWN to DAY, for most of the roster) would otherwise
## print "0 ponies wandered off, 0 arrived." over the middle of the screen every few
## minutes, which is a notification that nothing happened; and a phase where two walked off
## and nobody came would say "and 0 arrived", which is a notification of an absence. So each
## clause is emitted only when its own count is non zero, and the counts are pluralised:
## "2 ponies wandered off.", "1 pony arrived.", "2 ponies wandered off, 1 pony arrived."
##
## A FUTURE LOAD PAGE MUST CLEAR THE HERD BEFORE THIS RUNS AGAIN. Everything here assumes
## the ponies standing on the map belong to the world the clock is running; a load that
## swapped the save out from under a live ranch without emptying the spawner first would
## leave the previous world's herd standing in the new one, and the first phase change would
## report their departures as if they had been drawn for this save. There is no in game Load
## today (a save is loaded before the ranch builds its herd), which is why this is a note
## rather than a guard.
##
## THE CYCLE INDEX IS READ LIVE off the clock rather than counted here, because
## Spawner.refresh() seeds its draw from `cycle * 4 + phase` and a cycle number kept in a
## second place would eventually disagree with the one the player's save is actually on.
func _refresh_herd() -> void:
	if _world == null or not _herd_ready:
		return
	var moved: Dictionary = spawner.refresh(_world.phase(), _world.weather(),
		_world.cycle_index(), player.global_position)
	var left := int(moved.get("left", 0))
	var arrived := int(moved.get("arrived", 0))
	var clauses: Array[String] = []
	if left != 0:
		clauses.append("%s wandered off" % _pony_count_phrase(left))
	if arrived != 0:
		clauses.append("%s arrived" % _pony_count_phrase(arrived))
	if not clauses.is_empty():
		_toast("%s." % ", ".join(clauses))


## "1 pony" or "2 ponies". The herd toast is the only line in the game that counts ponies
## out loud, and "1 ponies wandered off" is the kind of thing a player reads as a bug in
## everything else too.
func _pony_count_phrase(count: int) -> String:
	return "1 pony" if count == 1 else "%d ponies" % count


## Said in words as well as in light. Repainted on a change and at boot, never per frame;
## the same contract HUD.set_bits() has.
func _show_world_line() -> void:
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_world_line"):
		hud.set_world_line(_world.describe() if _world != null else "")


## Match `--name=value` against a list of display names, case-insensitively, and return the
## index; which IS the enum value, since WorldState's PHASE_NAMES and WEATHER_NAMES are
## indexed by their enums. -1 for anything unrecognised, with a push_error: a typo in a
## screenshot script has to be loud, because the alternative is a run that quietly
## photographs a different hour than the one that was asked for and looks perfectly fine.
func _parse_named_value(arg: String, names: Array[String], what: String) -> int:
	var value := arg.split("=", true, 1)[1].strip_edges().to_lower()
	for i in range(names.size()):
		if names[i].to_lower() == value:
			return i
	var allowed: Array[String] = []
	for name in names:
		allowed.append(name.to_upper())
	push_error("ranch: unknown %s '%s'; expected one of %s. Ignored."
		% [what, value, ", ".join(allowed)])
	return -1


## The Market and the pause menu follow the build menu's contract: they emit, this
## transacts and pauses. See _bind_build_menu() for why the wiring is by name.
func _bind_market_menu() -> void:
	if market_menu == null or not market_menu.has_method("open") or _shop == null:
		return
	market_menu.set("shop", _shop)
	market_menu.set("can_open", func() -> bool: return _no_menu_but(market_menu))
	for pair in [["opened", _on_market_opened], ["closed", _on_menu_closed],
			["sell_requested", _on_sell_requested], ["sell_all_requested", _on_sell_all_requested],
			["buy_requested", _on_buy_requested]]:
		if not market_menu.is_connected(pair[0], pair[1]):
			market_menu.connect(pair[0], pair[1])


func _bind_depot_menu() -> void:
	if depot_menu == null or not depot_menu.has_method("open"):
		return
	depot_menu.set("can_open", func() -> bool: return _no_menu_but(depot_menu))
	depot_menu.set("rows_provider", func() -> Array[Dictionary]: return _penned_rows())
	depot_menu.set("bits_provider", func() -> int: return _current_bits())
	# WHAT THE LEDGER WILL ACTUALLY ACCEPT, so the Pay tab never offers a row that would be
	# trimmed on the way through (Ledger.pay() caps at payable(); bits settle the service
	# charges, not the principal). The menu asks; this file answers.
	depot_menu.set("payable_provider", func() -> int:
		return _game_state.ledger.payable() if _game_state != null else 0)
	depot_menu.set("statement_provider", func() -> Array[String]: return _statement())
	for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed],
			["deliver_requested", _on_deliver_requested],
			["pay_requested", _on_pay_requested]]:
		if not depot_menu.is_connected(pair[0], pair[1]):
			depot_menu.connect(pair[0], pair[1])


## `_on_menu_opened` takes a PlotSlot; the Depot's `opened` carries nothing, so it needs a
## nullary sibling rather than a bound lambda that would not compare equal on reconnect.
func _on_menu_opened_any() -> void:
	_on_menu_opened(null)


## THE LETTER READER, ON THE SAME PAUSE WIRING AS EVERY OTHER PANEL (Ruling 25). It has no
## providers and no request signals: it is handed a rendered letter by whoever is showing
## one and hands nothing back but "I am up" and "I am gone". That is the entire binding, and
## it is why _show_welcome_letter() can simply call open() and be finished.
func _bind_letter_panel() -> void:
	if letter_panel == null or not letter_panel.has_method("open"):
		return
	for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed]]:
		if not letter_panel.is_connected(pair[0], pair[1]):
			letter_panel.connect(pair[0], pair[1])


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
			["room_requested", _on_room_requested]]:
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

	if race_menu != null and race_menu.has_method("open"):
		race_menu.set("can_open",
			func() -> bool: return _no_menu_but(race_menu) and casino_can_enter())
		race_menu.set("chips_provider", func() -> int: return _current_chips())
		race_menu.set("entrants_provider",
			func() -> Array[Dictionary]: return race_entrants())
		for pair in [["opened", _on_menu_opened_any], ["closed", _on_menu_closed],
				["race_requested", _on_race_requested]]:
			if not race_menu.is_connected(pair[0], pair[1]):
				race_menu.connect(pair[0], pair[1])


## WHETHER THE PALACE WILL LET HER IN. Always true in this slice.
##
## THE BAN SEAM. The spec's Resistance route bans the player from the Strip at high heat and
## lifts it like every other punishment. That slice changes this one function and nothing
## else: every casino menu's can_open already asks it, enforce_casino_ban() shuts whatever
## was already open when the answer changed, and start_race() refuses on it too.
func casino_can_enter() -> bool:
	return true


## THE BAN CLOSES WHAT IS ALREADY OPEN. can_open only guards the DOOR: a ban that landed
## while the player was sitting at the blackjack table left her sitting at the blackjack
## table, still betting, until she chose to leave. A ban that only stops you coming back is
## not a ban.
##
## Returns whether it shut anything, so a caller (a test, a future Resistance slice wanting
## to say something) can tell a real ban landing from a quiet frame. Asked once a frame
## rather than wired to a signal because casino_can_enter() is a FUNCTION in this slice, with
## nothing to emit; the polling site is one line and moves to the signal the day there is one.
func enforce_casino_ban() -> bool:
	if casino_can_enter():
		return false
	var shut := false
	for menu: CanvasLayer in [casino_menu, slots_menu, wheel_menu, blackjack_menu, race_menu]:
		if menu == null or not menu.has_method("is_open") or not menu.is_open():
			continue
		menu.call("close")
		shut = true
	return shut


## Seed every roll at every table. For gates: a casino that rolls off the clock is a casino a
## gate cannot make a claim about.
func set_casino_seed(seed_value: int) -> void:
	_casino_rng.seed = seed_value


func _current_chips() -> int:
	return _game_state.casino.chips if _game_state != null else 0


## What is standing in the pens, as the Depot lists it. Stock ponies and named ponies alike;
## the menu sorts and prices the rows, this only says who is here.
func _penned_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for inst: PonyInstance in pen.ponies():
			# NOT THE ONE WHO IS OUT RUNNING. deliver_pony() refuses her anyway, but a row
			# that always refuses is a row that lies, and the Depot has already learned that
			# lesson once on the Pay tab (see DepotMenu.pay_amounts()). She comes back to
			# the list the moment the wire settles.
			if is_racing(inst.uid):
				continue
			var data: PonyData = inst.data()
			var rarity: int = data.rarity if data != null else PonyDataScript.Rarity.COMMON
			rows.append({
				"uid": inst.uid,
				"name": inst.display_name(),
				"stock": inst.is_stock(),
				"coat": _coat_word(inst),
				"credit": LedgerScript.delivery_credit(rarity, inst.is_stock()),
			})
	return rows


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


## THE FORM GUIDE: everybody standing in a pen, with her live price.
##
## PRICED HERE AND NOWHERE ELSE. Each row's odds are read off the field that pony WOULD run
## in, through RaceCard.decimal_odds(field, PLAYER_LANE), so the number on the screen is by
## construction the number the settle uses; the panel has no way to price a lane itself and
## deliberately never gets one.
##
## THE QUOTED CARDS ARE KEPT, keyed by uid. The shipped code cached one field because the
## panel had a two step flow (pick a pony, then pick a lane); the guide prices everybody at
## once, so the cache is a dictionary and the guarantee is wider: the field a race settles
## against is exactly the field whose odds were on the screen when she pressed the button.
## _clear_race_bet() empties it with the rest of the bet.
##
## NOT THE ONE WHO IS ALREADY OUT ON THE TRACK (Ruling 27). start_race() refuses her, so a
## row offering her was a row that could only ever refuse, and the Depot's Deliver tab and
## its Pay tab both learned that lesson already: a row that always refuses is a row that
## lies (see _penned_rows() and DepotMenu.pay_amounts()). She comes back to the guide the
## moment the wire settles, exactly as she comes back to the Deliver tab.
func race_entrants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var runners: CompanyRunners = CompanyRunnersScript.load_shipped()
	_quoted_fields.clear()
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for inst: PonyInstance in pen.ponies():
			if is_racing(inst.uid):
				continue
			var field: Array[Dictionary] = RaceCardScript.build_field(
				RaceCardScript.entrant_from(inst), runners)
			_quoted_fields[inst.uid] = field
			var chances: Array[float] = RaceCardScript.win_chances(field)
			out.append({
				"uid": inst.uid,
				"name": inst.display_name(),
				"happiness": inst.happiness,
				"odds": RaceCardScript.decimal_odds(field, RaceCardScript.PLAYER_LANE),
				"chance": chances[RaceCardScript.PLAYER_LANE] if not chances.is_empty() else 0.0,
			})
	return out


## ONE WORD THAT TELLS TWO STOCK PONIES APART, for the Deliver tab. Every member of the
## crowd shares one hidden record and therefore one display_name ("Pony"), so a pen holding
## six of them listed six identical rows and the player picked one by counting. Her COAT is
## the thing she is actually distinguishable by on screen, so the coat swatch her save
## record carries is named (StockPalette.colour_name) and the menu draws it in front of her
## name: "Butter Pony", "Sky Pony".
##
## EMPTY FOR A NAMED PONY, who has a name of her own and needs no help being told apart.
func _coat_word(inst: PonyInstance) -> String:
	if inst == null or not inst.is_stock():
		return ""
	if _stock_palette == null:
		_stock_palette = StockPaletteScript.load_stock()
	return StockPaletteScript.colour_name(
		_stock_palette.coat_at(int(inst.stock.get("coat", 0))))


func _statement() -> Array[String]:
	if _game_state == null:
		return []
	var cycle: int = _world.cycle_index() if _world != null else 0
	return _game_state.ledger.statement_lines(_player_name(), _built_plot_count(),
		_open_permit_count(), cycle)


## What the player called herself at the creation screen. The whole of the Company's
## paperwork reads it from here so there is one answer.
func _player_name() -> String:
	return _game_state.player.player_name if _game_state != null else PlayerLookScript.DEFAULT_NAME


func _built_plot_count() -> int:
	var n := 0
	for slot in _plot_slots():
		if not slot.is_empty():
			n += 1
	return n


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


## The loading dock the delivered pony walks into, in world space, or the Depot's own origin
## if the marker is missing.
func crate_position() -> Vector3:
	var crate := get_node_or_null(^"Buildings/Depot/Crate") as Node3D
	if crate != null:
		return crate.global_position
	var depot := get_node_or_null(^"Buildings/Depot") as Node3D
	return depot.global_position if depot != null else Vector3.ZERO


func is_near_depot() -> bool:
	var depot := get_node_or_null(^"Buildings/Depot") as Node3D
	if depot == null:
		return false
	var gap := Vector2(player.global_position.x - depot.global_position.x,
		player.global_position.z - depot.global_position.z).length()
	return gap <= DEPOT_RADIUS


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


func _bind_pause_menu() -> void:
	if pause_menu == null or not pause_menu.has_method("open"):
		return
	_settings = SettingsScript.new()
	_settings.load_from()
	_apply_settings()
	pause_menu.set("settings", _settings)
	pause_menu.set("can_open", func() -> bool: return _no_menu_but(pause_menu))
	# WHAT THE COMPENDIUM AND REQUESTS PAGES DRAW (game/ui/pause_menu.gd). Pushed in rather
	# than pulled by the menu, exactly like `settings` above: the menu is instantiated bare
	# by its own tests and by the boot shutter, and a page that loaded the roster off disk
	# for itself would make both of those pay for a ranch they do not have.
	#
	# RE PUSHED ON EVERY LOAD, because three of the five are REPLACED by one: rebind_economy()
	# builds a new RequestBoard and a load hands GameState a new Compendium, while
	# _rebuild_world_state() builds a new clock. Injecting once at boot would leave the pause
	# menu reading the board, the book and the hour of the session that was just replaced.
	# The registry and the region catalogue are cached for the life of the process and are
	# re-pushed only because they ride along in the same call.
	var inject_pages := func() -> void:
		pause_menu.set("compendium", get_compendium())
		pause_menu.set("registry", _pony_roster())
		pause_menu.set("regions", _regions_registry())
		pause_menu.set("board", get_request_board())
		pause_menu.set("world_state", get_world_state())
		pause_menu.set("statement_provider", func() -> Array[String]: return _statement())
	inject_pages.call()
	if _game_state != null and not _game_state.state_loaded.is_connected(inject_pages):
		_game_state.state_loaded.connect(inject_pages)
	for pair in [["opened", _on_pause_opened], ["closed", _on_menu_closed],
			["save_requested", _on_pause_save], ["quit_requested", _on_pause_quit],
			["settings_changed", _on_settings_changed]]:
		if not pause_menu.is_connected(pair[0], pair[1]):
			pause_menu.connect(pair[0], pair[1])


## Is every menu EXCEPT `menu` closed? Pass null to ask about all three.
##
## THE ONE PREDICATE, ASKED FROM BOTH SIDES. Every menu here pauses the tree on open and
## unpauses it on close, so two of them stacked means closing the top one unpauses the
## world under the one still on screen. Escape must not stack a pause menu on the build
## menu or the Market; E must not stack the Market on a pause menu. That used to be two
## different rules in two different places, one of them (the Market's) enforced only at the
## call site that happened to remember it, so MarketMenu.open() would cheerfully open over
## an open pause menu. Asking one question, excluding only the menu doing the asking, is
## what keeps the two directions from drifting apart again.
func _no_menu_but(menu: CanvasLayer) -> bool:
	for other in [build_menu, market_menu, pause_menu, depot_menu, creation_screen,
			casino_menu, slots_menu, wheel_menu, blackjack_menu, race_menu, letter_panel]:
		if other == menu or other == null:
			continue
		if other.has_method("is_open") and other.is_open():
			return false
	return true


## A NEW GAME OPENS ON THE CREATION SCREEN. Only for somebody actually playing: a hosted
## ranch, a headless gate and a screenshot run all skip it, so no automated run ever waits
## on a button nobody is going to press. A session that LOADED a save skips it too; there is
## no re-edit screen this phase.
##
## THE CURSOR IS FREED HERE, THE SAME WAY EVERY OTHER MENU FREES IT. Without this,
## game/actors/player/camera_rig.gd has already captured the mouse in its own _ready()
## (which runs before this function ever does), and nothing on the screen would be
## clickable: the pointer stays locked to the paused, invisible ranch behind it. Not routed
## through _on_menu_opened() itself, because that also toggles get_tree().paused a second
## time (CreationScreen.open() already owns that) -- see _set_cursor_captured()'s comment.
func _maybe_open_creation() -> void:
	if not _interactive or _save_loaded or _game_state == null:
		return
	if creation_screen == null or not creation_screen.has_method("open"):
		return
	if not creation_screen.is_connected("confirmed", _on_creation_confirmed):
		creation_screen.connect("confirmed", _on_creation_confirmed)
	creation_screen.call("open", _game_state.player)
	_set_cursor_captured(false)


## She has made her pony. Keep it, dress the model, and write it down straight away: the
## first thing that happens after this is a ranch, and a crash before the first autosave
## should not cost her the pony she just spent five minutes on.
func _on_creation_confirmed(look: PlayerLook) -> void:
	_set_cursor_captured(true)
	if _game_state == null:
		return
	_game_state.player = look
	_apply_player_look()
	save_game()
	_show_welcome_letter(look)


## THE ONE LETTER A NEW RANCH OPENS ON, drawn rather than thrown away.
##
## THE QUOTA COMES OFF THE LEDGER. This call used to hand render() a name and a balance and
## nothing else, so the template's `quota` fell through to its own default of 0 and the
## welcome letter told every new player "We expect 0 ponies delivered to the Depot each
## period", which is both wrong and the exact opposite of the thing that letter exists to
## say. Ledger.quota is the number the Depot actually judges her against; there is only one
## of it, and this is where it comes from.
##
## AND THE BODY IS SHOWN, NOT TOASTED. The whole of the game's onboarding is in the body of
## this letter (catch, pen, collect, sell, then the balance and the quota in a sentence
## each); toasting the TITLE said "Cloudsdale Weather Corporation: Welcome to the family!"
## and dropped every word of it. game/ui/letter_panel.gd is the reader, ranch.gd does the
## showing, and the pause comes through the same shared handlers every other panel uses.
## Ruling 25.
func _show_welcome_letter(look: PlayerLook) -> void:
	if _game_state == null:
		return
	var letter: Dictionary = LettersScript.render(LettersScript.Id.WELCOME, {
		"name": look.player_name,
		"balance": _game_state.ledger.balance,
		"quota": _game_state.ledger.quota,
	})
	if letter_panel != null and letter_panel.has_method("open") \
			and bool(letter_panel.call("open", letter)):
		return
	# A panel that failed to parse, or a detached Ranch in a test that never wired one: say
	# what arrived rather than saying nothing at all.
	_toast("%s: %s" % [letter["sender"], letter["title"]])


func _apply_player_look() -> void:
	if _game_state == null or player == null or not player.has_method("apply_look"):
		return
	player.call("apply_look", _game_state.player)


## Nothing at all is up: no build menu, no Market, no pause menu.
##
## THE BUILD PROMPT AND THE MARKET PROMPT BOTH ASK THIS before they react to a keypress.
## The build prompt used to ask a narrower question, whether its OWN menu was open, so E
## pressed while the Market or the pause menu was up still ran the build path underneath
## them. Both prompts ask the whole question now, which is what makes the sentence above
## true of the code rather than only of the intention.
func _no_other_menu_open() -> bool:
	return _no_menu_but(null)


func _on_market_opened() -> void:
	# Swept BEFORE the shelves are drawn, so the Market sells what the pens made a second
	# ago rather than what they had made by the last save.
	collect_gems()
	if market_menu.has_method("refresh"):
		market_menu.refresh()
	_on_menu_opened(null)


func _on_pause_opened() -> void:
	_on_menu_opened(null)


func _on_sell_requested(rarity: int, count: int) -> void:
	if _shop == null:
		return
	# MEASURED ACROSS THE SALE, not taken from the request. Shop.sell() takes as many as the
	# pouch actually holds and answers in BITS, so `count` is what the menu asked for and
	# says nothing about what was found: a request that outran the pouch used to toast
	# "Sold 3 gems" over a sale of one. And one gem is a gem, not a gems.
	var held_before: int = _shop.gem_count(rarity)
	var earned: int = _shop.sell(rarity, count)
	var sold_count: int = held_before - _shop.gem_count(rarity)
	if earned > 0:
		_toast("Sold %d %s for %d bits." % [
			sold_count, "gem" if sold_count == 1 else "gems", earned])
	# The board is told what LEFT THE POUCH, the same number the toast reports, for the
	# same reason: `count` is what the menu asked for and a request that outran the pouch
	# would otherwise credit her for gems she never had.
	if _board != null and sold_count > 0:
		_pay_out(_board.on_sold(rarity, sold_count))
	if market_menu.has_method("refresh"):
		market_menu.refresh()


func _on_sell_all_requested() -> void:
	if _shop == null:
		return
	# COUNTED PER RARITY ACROSS THE SALE. sell_all() answers in bits and says nothing about
	# what it emptied, and the board's SELL_GEMS_OF_RARITY request is about a tier, so
	# "sell everything" has to be reported to it as one on_sold() per tier rather than as
	# one lump. Measured before and after rather than taken from sell_all()'s return for
	# _on_sell_requested()'s reason: the pouch is the authority on what was in it.
	var held_before := {}
	for rarity in PonyDataScript.Rarity.values():
		held_before[rarity] = _shop.gem_count(rarity)
	var earned: int = _shop.sell_all()
	if earned > 0:
		_toast("Sold everything for %d bits." % earned)
	if _board != null:
		for rarity in held_before.keys():
			var sold_count: int = int(held_before[rarity]) - _shop.gem_count(rarity)
			if sold_count > 0:
				_pay_out(_board.on_sold(rarity, sold_count))
	if market_menu.has_method("refresh"):
		market_menu.refresh()


func _on_buy_requested(item: ShopItem) -> void:
	if _shop == null or item == null:
		return
	if _shop.buy(item):
		# Gear takes effect the moment it is bought, not on the next load. So does a
		# permit: the gate she is standing at swings open while she is still standing at
		# it, which is the only moment the purchase can be SEEN to have done anything.
		_apply_unlocks()
		_apply_permits()
		# ONE TOAST, NOT TWO. "Bought Permit: The Orchard." followed by "The Orchard is
		# open." is the same sentence twice, and the second one is the one that says what
		# changed out in the world.
		var region: RegionData = null
		if item.kind == ShopItemScript.Kind.PERMIT:
			region = _regions_registry().by_id(item.permit_zone)
		if region != null:
			_toast("%s is open." % region.display_name)
		else:
			_toast("Bought %s." % item.display_name)
	if market_menu.has_method("refresh"):
		market_menu.refresh()


## The Save row. REFUSED OUT LOUD while a race is running, rather than failing silently or
## writing a file that cannot describe the bet; see save_game() for the whole of the reason.
## The refusal is worded as the Palace would word it, because that is who is refusing.
func _on_pause_save() -> void:
	if race_track != null and bool(race_track.call("is_running")):
		_toast("Not while they are running! Watch it home, then save.")
		return
	var ok := save_game()
	_toast("Ranch saved" if ok else "SAVE FAILED. See the log.")


func _on_pause_quit() -> void:
	# GameState's quit-time autosave is what writes on the way out (see game_state.gd);
	# this only asks the tree to close. Unpaused first, because a paused tree is not a
	# state anything downstream of here should have to reason about.
	get_tree().paused = false
	get_tree().quit()


func _on_settings_changed() -> void:
	_apply_settings()
	if _settings != null:
		_settings.save_to()


## Push the settings into the things they control. The camera rig owns sensitivity and
## invert; the audio bus owns volume.
func _apply_settings() -> void:
	if _settings == null:
		return
	if _rig != null:
		_rig.mouse_sensitivity = _settings.mouse_sensitivity
		_rig.invert_look = _settings.invert_look
	if _interactive:
		_settings.apply_audio()


## COLLECTION DAY, ONCE PER PERIOD. Every third cycle, on the first phase change inside it,
## the upkeep and the service charge land on the balance and the period's quota is judged.
## The collector the judgement arms does NOT call now: he calls at the first dawn of a LATER
## cycle (_maybe_serve_collector), which is what makes the letter arrive before the knock
## and gives her a cycle to do something about it.
##
## GUARDED BY THE LEDGER'S OWN Ledger.is_collection_day_due(), NOT BY A RUNTIME COUNTER OF
## THE LAST CYCLE BILLED. A runtime counter resets to nothing on every fresh process, so it
## cannot tell "this period was never billed" from "this period was billed by whichever
## session wrote the save this process just loaded" -- and a phase change landing inside a
## cycle already billed by an earlier session used to re-run the collection day: upkeep and
## the service charge added twice, the tier escalated twice, delivered_this_period reset a
## second time. periods_run is part of the save, so asking the ledger is what makes a
## reloaded process agree with the one that saved.
func _maybe_run_collection_day() -> void:
	if _game_state == null or _world == null:
		return
	var cycle: int = _world.cycle_index()
	if not _game_state.ledger.is_collection_day_due(cycle):
		return
	var summary: Dictionary = run_collection_day()
	if int(summary["punishment"]) != LedgerScript.Punishment.NONE:
		_collector_due = true


func run_collection_day() -> Dictionary:
	var ledger: Ledger = _game_state.ledger
	var cycle: int = _world.cycle_index() if _world != null else 0
	var summary: Dictionary = ledger.run_collection_day(cycle, _built_plot_count(),
		_open_permit_count())
	var letter: Dictionary = LettersScript.render(LettersScript.Id.COLLECTION_NOTICE, {
		"name": _player_name(), "balance": int(summary["balance"]),
		"upkeep": int(summary["upkeep"])})
	_toast("%s. Balance: %d bits." % [letter["title"], int(summary["balance"])])
	if not bool(summary["quota_met"]):
		_toast("Quota: %d of %d delivered. An associate will call at the next dawn."
			% [int(summary["delivered"]), int(summary["quota"])])
	_push_balance()
	return summary


## THE COLLECTOR CALLS. One rung of the ladder, served once, on the first DAWN OF A CYCLE
## LATER THAN THE ONE THAT ARMED IT (see _maybe_serve_collector, and Ledger.
## pending_punishment_cycle for why "later" rather than "next"). Every rung is reversible
## and none of them takes a pony: a fee is bits, a revoked permit is a fence that closes
## over ponies who stay exactly where they are, a padlock is a pen that makes no gems, and a
## recall is a horn she gets back next cycle. Returns which rung was served, for the gates.
##
## A RUNG WITH NOTHING TO BITE ON FALLS BACK TO THE FEE rather than passing quietly. A
## player with no permits bought has nothing to revoke and a player with no pen built has
## nothing to padlock, and those are exactly the players early enough in the game to be
## missing quota: serving them a rung with no consequence spent the escalation (tier had
## already climbed) and gave them a free period. The fee is the rung below, it always lands,
## and the toast and the letter both say what actually happened rather than what the ladder
## intended.
func serve_collector() -> int:
	if _game_state == null:
		return LedgerScript.Punishment.NONE
	var ledger: Ledger = _game_state.ledger
	var punishment: int = ledger.take_pending_punishment()
	var served: int = punishment
	match punishment:
		LedgerScript.Punishment.FEE:
			_serve_collector_fee()
		LedgerScript.Punishment.PERMIT_REVOKED:
			var permit: StringName = _dearest_open_permit()
			if permit == &"":
				served = LedgerScript.Punishment.FEE
				_serve_collector_fee()
			else:
				ledger.revoked_permits.append(String(permit))
				_game_state.unlocks.erase(String(permit))
				_apply_permits()
				_toast("An associate called: one permit is under review. Pay to resume access.")
		LedgerScript.Punishment.PEN_PADLOCKED:
			var slot_id: StringName = _fullest_pen_slot()
			if slot_id == &"":
				served = LedgerScript.Punishment.FEE
				_serve_collector_fee()
			else:
				ledger.padlocked_slots.append(String(slot_id))
				_apply_padlocks()
				_toast("An associate called: one pen is sealed pending payment. Everyone inside is fine!")
		LedgerScript.Punishment.BEAM_RECALLED:
			var cycle: int = _world.cycle_index() if _world != null else 0
			ledger.beam_recalled_until = cycle + LedgerScript.BEAM_RECALL_CYCLES
			_apply_beam_recall()
			_toast("An associate called: your horn licence is suspended for one cycle.")
	if served != LedgerScript.Punishment.NONE:
		var letter: Dictionary = LettersScript.render(LettersScript.Id.COLLECTOR_VISIT, {
			"name": _player_name(), "punishment": _punishment_phrase(served)})
		_toast(String(letter["title"]))
	_push_balance()
	return served


## THE FIRST RUNG, AND THE ONE EVERY OTHER RUNG FALLS BACK ON. Paid out of the wallet if she
## can cover it, added to the balance if she cannot; nothing is ever confiscated.
func _serve_collector_fee() -> void:
	var fee: int = LedgerScript.COLLECTOR_FEE
	if _economy != null and _economy.can_afford(fee):
		_economy.spend(fee)
		_toast("An associate called: a service fee of %d bits. Have a lovely day!" % fee)
	else:
		_game_state.ledger.balance += fee
		_toast("An associate called: %d bits added to your balance. No trouble at all!" % fee)


## THE KNOCK, ONE FULL CYCLE AFTER THE LETTER. A collection day always lands on a DAWN
## (Ledger.is_collection_cycle() only answers true at a cycle boundary, and a cycle's first
## phase is DAWN by construction), so "serve at the next dawn" served the collector in the
## very same _on_world_changed() that billed her: notice and visit in one frame, with no
## period in between to ship or to pay in. The rung is therefore held until the first DAWN
## of a cycle STRICTLY LATER than the one that armed it, which is the beat the spec
## describes and the reason the letter is worth reading.
##
## THE ARMING CYCLE LIVES ON THE LEDGER (Ledger.pending_punishment_cycle), not here, so it
## travels with the save: quitting between the notice and the visit comes back owing the
## same visit on the same dawn, exactly as _seed_collector_state() does for the rung itself.
func _maybe_serve_collector() -> void:
	if _world == null:
		return
	# The beam's recall expires on its own clock, so this is asked at every phase change and
	# not only at dawn.
	_apply_beam_recall()
	if not _collector_due or _world.phase() != WorldStateScript.Phase.DAWN:
		return
	if _game_state != null \
			and _world.cycle_index() <= _game_state.ledger.pending_punishment_cycle:
		# Armed this very cycle. The letter has just landed; he calls at the next dawn.
		return
	_collector_due = false
	serve_collector()


static func _punishment_phrase(punishment: int) -> String:
	match punishment:
		LedgerScript.Punishment.FEE:
			return "a service fee"
		LedgerScript.Punishment.PERMIT_REVOKED:
			return "a permit under review"
		LedgerScript.Punishment.PEN_PADLOCKED:
			return "a sealed pen"
		LedgerScript.Punishment.BEAM_RECALLED:
			return "a suspended horn licence"
	return "a courtesy visit"


## The most expensive permit she currently holds. The dearest one, so the punishment is felt
## rather than shrugged off, and so it is obvious which fence closed. PRICED REGIONS ONLY:
## the Strip is always open (is_region_open() says so directly, having no fence to ask), but
## it is not a permit anybody bought and there is nothing on it to revoke.
func _dearest_open_permit() -> StringName:
	var best: StringName = &""
	var best_cost := -1
	for region: RegionData in _regions_registry().all():
		if region.permit_cost <= 0:
			continue
		if not is_region_open(region.id):
			continue
		if region.permit_cost > best_cost:
			best_cost = region.permit_cost
			best = ShopScript.permit_id_for(region.id)
	return best


## The slot id of the pen with the most ponies in it that is not already padlocked.
func _fullest_pen_slot() -> StringName:
	var best: StringName = &""
	var most := -1
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null or pen.is_padlocked():
			continue
		if pen.count() > most:
			most = pen.count()
			best = slot.slot_id
	return best


## Push the ledger's padlock list onto the pens. Absolute rather than incremental, the way
## _apply_permits() and _apply_unlocks() are: a pen not on the list is not padlocked, so a
## load, a relief and a collector all reach the same state from the same one function.
func _apply_padlocks() -> void:
	if _game_state == null:
		return
	var locked: Array = _game_state.ledger.padlocked_slots
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen != null:
			pen.set_padlocked(String(slot.slot_id) in locked)


## Same shape for the horn.
func _apply_beam_recall() -> void:
	if _game_state == null:
		return
	var beam: Node3D = player.get_magic_beam()
	if beam == null or not beam.has_method("set_recalled"):
		return
	var cycle: int = _world.cycle_index() if _world != null else 0
	beam.call("set_recalled", _game_state.ledger.beam_is_recalled(cycle))


func _push_balance() -> void:
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_balance") and _game_state != null:
		hud.call("set_balance", _game_state.ledger.balance)


## Read GameState.unlocks into the things that honour them. On boot and after every
## purchase. MagicBeam.apply_unlocks() is absolute rather than incremental, so calling this
## twice cannot stack a bonus.
func _apply_unlocks() -> void:
	if _game_state == null:
		return
	var beam: Node3D = player.get_magic_beam()
	if beam != null and beam.has_method("apply_unlocks"):
		beam.apply_unlocks(_game_state.unlocks)


## Open every fence whose permit is in the unlocks, and shut every fence whose permit is
## not. On boot and after every purchase, the same way _apply_unlocks() reads the gear.
##
## ABSOLUTE, NOT INCREMENTAL, and for the reason MagicBeam.apply_unlocks() is: this runs
## again after every load, and a load REPLACES GameState's arrays. A version that only ever
## opened gates would leave the previous save's regions standing open behind a state that
## never paid for them.
func _apply_permits() -> void:
	if _game_state == null:
		return
	for fence in get_region_fences():
		if fence.region() == null:
			continue
		fence.set_open(_game_state.unlocks.has(String(fence.region().permit_id())))


## Every RegionFence under $Regions, in scene order. Empty before _ready() has built them.
func get_region_fences() -> Array[RegionFence]:
	var found: Array[RegionFence] = []
	if regions_root == null:
		return found
	for child in regions_root.get_children():
		if child is RegionFenceScript:
			found.append(child)
	return found


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


## The nearest LOCKED gateway within GATE_PROMPT_RADIUS of the player, or null. What the
## permit prompt hangs off, and measured to the gateway rather than to the region's centre:
## the fence is 25 m or more from that centre, so a prompt keyed to the middle of the
## region would either never fire or fire across the whole meadow.
func nearest_locked_gate() -> RegionFence:
	var best: RegionFence = null
	var best_d := GATE_PROMPT_RADIUS
	for fence in _region_fence_cache:
		if fence.is_open() or fence.region() == null:
			continue
		var gate: Vector3 = fence.gate_position()
		var d := Vector2(player.global_position.x - gate.x,
			player.global_position.z - gate.z).length()
		if d <= best_d:
			best_d = d
			best = fence
	return best


## The pantry a pen feeds from, read live rather than captured.
##
## GameState REPLACES its Inventory on every load and reset, so a Callable that returns the
## CURRENT one is the only binding that survives a load. This is why pens are absent from
## rebind_economy() above.
func _current_inventory() -> Inventory:
	return _game_state.inventory if _game_state != null else null


## Fold every pen's tray into the pouch. Before a save (so the gems survive quitting) and
## when the Market opens (so it sells what the pens made a second ago). Returns how many
## gems moved.
func collect_gems() -> int:
	if _game_state == null:
		return 0
	var moved := 0
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		var tray: Dictionary = pen.take_gems_by_rarity()
		for rarity in tray.keys():
			_game_state.gems.add(int(rarity), int(tray[rarity]))
			moved += int(tray[rarity])
	return moved


## The Depot menu, or null before boot has bound it. Exposed for gates and tests, matching
## get_request_board() and get_compendium() below.
func get_depot_menu() -> CanvasLayer:
	return depot_menu


## DELIVER ONE PONY. Returns `{"ok": bool, "credit": int, "named": bool, "name": String}`,
## so a gate can assert on what happened rather than on a toast.
##
## THE WALK HAPPENS FIRST, AND EVERYTHING IRREVERSIBLE HANGS OFF ITS ANSWER. Pony.
## leave_toward() returns false for a pony the beam has hold of, and this function used to
## throw that answer away: it credited the account, deleted her record, marked her
## PROCESSED and counted her toward quota BEFORE pointing her at the crate, so a resident
## floating in the beam was paid for and then handed straight back on release. Now the
## order is: find her, refuse if she is HELD, take her body out of the pen, point her at
## the crate, and only once she is actually walking does anything change that cannot be
## changed back.
##
## THE TWO REFUSALS ARE BEFORE ANY MUTATION, which is what makes "refuse and unwind
## nothing" true rather than merely hopeful: nothing is unwound because nothing was done.
## Even her body stays in the pen until the walk is accepted.
##
## HER BODY COMES OUT OF THE PEN ALIVE (Pen.release_body), and only after the walk has
## been accepted, so a refusal leaves her standing in the pen she was already standing in.
## She walks to the crate herself and frees herself on arrival, in Pony._state_leaving,
## which stays the one line in this project that frees a pony. There is no branch here that
## removes her any other way, deliberately: NO PONY EVER DIES ON SCREEN, and nothing
## gruesome happens at the Depot.
##
## AND THE BEAM WILL NOT TAKE HER BACK once she is walking: Pony.is_being_delivered() is
## true for the whole of the walk and MagicBeam._is_grabbable() declines her. That is a
## grab that never starts, not a pony taken away.
func deliver_pony(uid: StringName) -> Dictionary:
	var refused := {"ok": false, "credit": 0, "named": false, "name": ""}
	if _game_state == null:
		return refused
	var pen: Pen = null
	var inst: PonyInstance = null
	for slot in _plot_slots():
		var candidate := slot.get_built() as Pen
		if candidate == null:
			continue
		var found: PonyInstance = candidate.find_pony(uid)
		if found != null:
			pen = candidate
			inst = found
			break
	if pen == null or inst == null:
		return refused

	# REFUSED WHILE SHE IS ON THE TRACK. Her pen body is hidden for the length of a race and
	# a bet of the player's own money is riding on her; delivering her mid race would credit
	# the account for a pony the wire is about to pay out on, free her out from under
	# _on_race_finished()'s own unhide, and leave the Palace settling a bet on somebody who
	# no longer exists. The Depot's rows skip her too (_penned_rows()), so this is the second
	# of the two checks a refusal like this is worth.
	if is_racing(uid):
		_toast("She is under orders at the Palace! The counter will take her after the race.")
		return refused

	# HER BODY, STILL IN THE PEN. Read rather than released, so the two refusals below cost
	# nothing to make: at this point the pen still holds her, the save still has her record,
	# and the account has not moved.
	var body: Node3D = pen.body_for(uid)
	if body == null or not (body is PonyScript):
		return refused

	# REFUSED WHILE THE BEAM HAS HER. The hold is the beam's, and a hold that turns into a
	# capture must be allowed to finish as one; a delivery that talked over it would credit
	# the account for a pony who is about to land back in the saddlebag.
	if (body as PonyScript).state == PonyScript.State.HELD:
		_toast("Put her down first, and the counter will take her from there!")
		return refused

	# THE WALK IS THE COMMIT POINT, and it is asked BEFORE anything is spent, deleted or
	# credited. leave_toward() answers false for exactly one reason (she is HELD), which the
	# line above has already refused; this is that same rule read off the seam's own answer
	# rather than guessed at a second time, and it costs one branch to keep honest.
	if not body.leave_toward(crate_position()):
		_toast("Put her down first, and the counter will take her from there!")
		return refused

	# From here down the delivery HAS happened. release_body() cannot fail on a pony this
	# function has already found a live body and a live record for (see pen.gd), and it is
	# the call that takes the pen's collision bits off her so the walk can actually reach
	# the crate.
	if pen.release_body(uid, self) == null:
		return refused
	_game_state.remove_pony(uid)

	var data: PonyData = inst.data()
	var rarity: int = data.rarity if data != null else PonyDataScript.Rarity.COMMON
	var credit: int = _game_state.ledger.credit_delivery(rarity, inst.is_stock())
	var named: bool = not inst.is_stock()
	if named:
		_game_state.compendium.mark_processed(inst.data_id)

	# credit_delivery() has already counted her, so the ledger's own running total IS the
	# number this receipt should carry.
	var shipments: int = _game_state.ledger.shipments
	var letter: Dictionary = LettersScript.render(
		LettersScript.Id.RECEIPT_NAMED if named else LettersScript.Id.RECEIPT_STOCK,
		{"name": _player_name(), "count": shipments, "credit": credit,
			"pony": inst.display_name()})
	_toast("%s: %s shipment received, %d bits credited."
		% [letter["sender"], LettersScript.ordinal(shipments), credit])

	if depot_menu != null and depot_menu.has_method("refresh"):
		depot_menu.refresh()
	_relieve_if_paid_down()
	return {"ok": true, "credit": credit, "named": named, "name": inst.display_name()}


## PAY THE COMPANY. The ledger says how much it will accept (bits settle the service
## charges, not the principal), the wallet is debited by exactly that, and the difference is
## explained rather than silently swallowed. Returns what was actually paid.
func _on_pay_requested(bits: int) -> void:
	pay_the_company(bits)


func pay_the_company(bits: int) -> int:
	if _game_state == null or _economy == null:
		return 0
	var ledger: Ledger = _game_state.ledger
	var wanted: int = mini(bits, _economy.bits)
	var taken: int = ledger.pay(wanted)
	if taken <= 0:
		_toast("Bits settle the service charges. The principal is settled in stock.")
		return 0
	_economy.spend(taken)
	if taken < bits:
		_toast("Paid %d bits. That is as low as bits will take it; the rest is stock."
			% taken)
	else:
		_toast("Paid %d bits. Balance: %d." % [taken, ledger.balance])
	_relieve_if_paid_down()
	if depot_menu != null and depot_menu.has_method("refresh"):
		depot_menu.refresh()
	return taken


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
		# TYPED BEFORE THE CALL, NOT AT IT. show_result()'s parameter is Array[String];
		# a bare `[...]` literal is a loosely typed Array, and a dynamic call() does not
		# get the compile time coercion a direct call would, so the untyped literal fails
		# call()'s own runtime type check. Same fix at wheel_menu's and blackjack_menu's
		# call() below.
		var lines: Array[String] = [SlotsScript.line_text(reels),
			"You win %d chips." % won if won > 0 else "Nothing this time."]
		slots_menu.call("show_result", lines)
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
		var lines: Array[String] = [WheelScript.pocket_text(pocket),
			"You win %d chips." % won if won > 0 else "The house takes that one."]
		wheel_menu.call("show_result", lines)
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
		var lines: Array[String] = [
			"You: " + _cards_text(hand["player"]),
			"Dealer: " + _cards_text(hand["dealer"]),
			BlackjackScript.outcome_text(hand),
		]
		blackjack_menu.call("show_result", lines)
	_refresh_casino_menus()
	return {"ok": true, "hand": hand, "won": won, "stake": stake}


## RUN A RACE. Returns {"ok": bool, "field": Array, "result": Dictionary, "odds": float}.
##
## YOUR PONY IS YOUR BET, so there is no lane argument: the entrant always runs on
## RaceCard.PLAYER_LANE and that is the only lane the stake can be on. The lane parameter
## this used to take let a caller back a Company runner, which is what the 2026-08-31
## playtest asked to have removed.
##
## WHAT DOES NOT HAPPEN HERE, and it is still the point of the whole thing: the entrant is
## not taken out of her pen, not handed to the track, not adopted by anything and not freed.
## Her pen body is hidden for the length of the race so the world does not show her twice,
## and _on_race_finished() shows it again. The six bodies on the track are RaceRunners, which
## are not ponies at all; see game/world/race_runner.gd.
##
## THE STAKE COMES OUT BEFORE THE FIELD IS DRAWN, the same order every table here uses. The
## seed comes off the casino's own generator, so a gate that called set_casino_seed() gets the
## same race every run and a player gets a different one every time.
func start_race(uid: StringName, stake: int) -> Dictionary:
	var refused := {"ok": false, "field": [], "result": {}, "odds": 0.0}
	if _game_state == null or race_track == null or race_track.call("is_running"):
		return refused
	# THE BAN CLOSES THE TRACK TOO. casino_can_enter() gates every menu's can_open, but a
	# menu that was already open when the ban landed could still emit, and a gate or a save
	# hook could still call this directly. The Palace either lets her in or it does not.
	if not casino_can_enter():
		return refused
	var found: Dictionary = _penned(uid)
	if found.is_empty():
		return refused
	if not _game_state.casino.can_stake(stake):
		return refused
	var inst: PonyInstance = found["inst"]
	# THE FIELD THE ODDS WERE QUOTED FROM, when there is one. A uid with no quote (a gate or
	# a save hook calling straight in without opening the panel) rebuilds, which is the same
	# field the guide would have shown had it been asked.
	var field: Array[Dictionary] = []
	if _quoted_fields.has(uid):
		field = _quoted_fields[uid]
	if field.is_empty():
		field = RaceCardScript.build_field(
			RaceCardScript.entrant_from(inst), CompanyRunnersScript.load_shipped())
	if not _game_state.casino.remove_chips(stake):
		return refused

	var result: Dictionary = RaceCardScript.run(field, _casino_rng.randi())

	var pen: Pen = found["pen"]
	var body: Node3D = pen.body_for(uid)
	if body != null:
		# HIDDEN, NEVER REMOVED. She is still in the pen's roster, still in the save, and
		# still standing where she was; the player just does not see her in two places.
		body.visible = false

	# BOTH RETURNS ARE READ, NEITHER IS DISCARDED. dress() is informational only: fewer
	# than LANES dressed is the documented degraded state on a checkout with no converted
	# assets, and the race still runs on the RaceRunner nodes regardless of whether they
	# carry a model (see race_runner.gd), but start()'s bool is the one true signal for
	# whether a race actually began, and it can answer false (a field this call built wrong,
	# the track already mid race some other way). A false here must not be allowed to leave
	# the stake spent and her body hidden with nothing ever going to put either back:
	# race_finished is the only other unhide site, and the bet's own bookkeeping below is
	# only set once start() has actually said yes.
	var dressed: int = int(race_track.call("dress", field))
	var started: bool = bool(race_track.call("start", field, result))
	if not started:
		# UNWIND. Nothing about this race actually happened, so nothing about it may stick:
		# the stake comes back, her body is shown again, and this is a refusal exactly like
		# any of the ones above it.
		_game_state.casino.add_chips(stake)
		if body != null:
			body.visible = true
		push_error(
			"ranch.start_race: race_track.start() refused a %d-lane field (%d dressed); stake refunded."
			% [field.size(), dressed])
		return refused

	_race_entrant = uid
	_race_lane = RaceCardScript.PLAYER_LANE
	_race_stake = stake
	_race_field = field

	if race_menu != null and race_menu.has_method("close"):
		race_menu.close()
	_toast("They are under orders at the Spectra Palace!")
	return {"ok": true, "field": field, "result": result,
		"odds": RaceCardScript.decimal_odds(field, RaceCardScript.PLAYER_LANE)}


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
		_toast("%s takes it. Your pony was not in front today." % winner_name)
	_refresh_casino_menus()
	race_settled.emit(won, winner)
	_clear_race_bet()


## EVERY VARIABLE THE BET LIVES IN, PUT BACK AT ONCE. Four of them, and _race_field was
## being left behind by the wire while the other three were cleared: a settled race left the
## last field standing, so anything that read it between races read a card nobody was on.
## The quoted cards go with them, because they are the cards THIS bet's odds came from.
func _clear_race_bet() -> void:
	_race_entrant = &""
	_race_lane = -1
	_race_stake = 0
	_race_field = []
	_quoted_fields.clear()


## IS THERE A PONY ON THE TRACK RIGHT NOW, and is she this one? `_race_entrant` is set by
## start_race() only once the track has actually said yes and is put back at the wire (or by
## refund_open_race()), so it is the authority on "she is out running" for everything that
## must not touch her while she is: the Depot counter, and the rows it draws.
func is_racing(uid: StringName) -> bool:
	return not _race_entrant.is_empty() and uid == _race_entrant


## THE STAKE COMES BACK IF THE RACE NEVER SETTLES. Returns how many chips were put back, 0
## when there was no bet on the track.
##
## THE HOLE THIS CLOSES. start_race() takes the stake immediately and _on_race_finished()
## is the only thing that ever pays it back; a session that ended between the two (the
## window's close button, the tree tearing down, a save written mid race) recorded a purse
## with the stake gone and no bet anywhere in it. Nothing crashed and nothing said anything:
## the chips were simply not there any more. A casino may take a bet it settles; it may not
## quietly keep one it never ran.
##
## IDEMPOTENT, because it is called from more than one place and both of them can fire in
## the same shutdown: the second call finds no stake and does nothing.
func refund_open_race() -> int:
	if _game_state == null or _race_stake <= 0:
		return 0
	var refunded: int = _race_stake
	_game_state.casino.add_chips(refunded)
	# Her body was hidden for the length of a race that is not going to finish; the same
	# unhide _on_race_finished() and start_race()'s own unwind do.
	var found: Dictionary = _penned(_race_entrant)
	if not found.is_empty():
		var body: Node3D = (found["pen"] as Pen).body_for(_race_entrant)
		if body != null:
			body.visible = true
	_clear_race_bet()
	return refunded


## THE WINDOW'S CLOSE BUTTON, AND THE TEARDOWN. Both deliver one of these, and either can be
## the end of a session with a race still running, so both refund. GameState answers the same
## two notifications with its quit-time save (game/systems/game_state.gd); an autoload is
## notified before the main scene is, so this is NOT what keeps the refund out of that save.
## _sync_game_state() is: it is the one funnel every write goes through, it runs before the
## file is written, and it refunds there. This is the belt to that pair of braces, for a
## teardown that never writes anything at all.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		refund_open_race()


func get_race_track() -> Node3D:
	return race_track


func get_race_menu() -> CanvasLayer:
	return race_menu


func _on_race_requested(uid: StringName, stake: int) -> void:
	start_race(uid, stake)


func _cards_text(cards: Array) -> String:
	var names: Array[String] = []
	for card in cards:
		names.append(BlackjackScript.card_text(int(card)))
	return ", ".join(names)


func _refresh_casino_menus() -> void:
	for menu: CanvasLayer in [casino_menu, slots_menu, wheel_menu, blackjack_menu, race_menu]:
		if menu != null and menu.has_method("refresh"):
			menu.call("refresh")


func _on_buy_chips_requested(bits: int) -> void:
	buy_chips(bits)


func _on_cash_out_requested(chips: int) -> void:
	cash_out(chips)


func _on_spin_requested(stake: int) -> void:
	play_slots(stake)


## TRANSLATES A FELT TAB INTO A Wheel.Bet VALUE before the bet ever reaches play_wheel().
## WheelMenu.Tab is COLOUR-first because that is the felt's own reading order
## (game/ui/wheel_menu.gd); Wheel.Bet is NUMBER-first because that is the order
## game/systems/wheel.gd's own comment writes it out in. The menu never touches Wheel, so
## this is the one seam where the two numberings meet, and it is here rather than folded
## into play_wheel() so a gate calling play_wheel() directly (as test-8's does) can pass a
## genuine Wheel.Bet value and mean it.
func _on_wheel_bet_requested(kind: int, guess: int, stake: int) -> void:
	var bet_kind: int = WheelScript.Bet.COLOUR if kind == WheelMenuScript.Tab.COLOUR \
		else WheelScript.Bet.NUMBER
	play_wheel(bet_kind, guess, stake)


func _on_deal_requested(stake: int) -> void:
	play_blackjack(stake)


## SHE PICKED A ROW IN THE LOBBY. The cage and the house rules are pages of the lobby menu
## itself, so those two turn a tab rather than opening anything; the four games each open
## their own panel, exactly as before.
func _on_room_requested(row: int) -> void:
	if casino_menu == null:
		return
	match row:
		CasinoMenuScript.Row.CAGE:
			casino_menu.call("set_tab", CasinoMenuScript.Tab.CAGE)
		CasinoMenuScript.Row.RULES:
			casino_menu.call("set_tab", CasinoMenuScript.Tab.RULES)
		CasinoMenuScript.Row.SLOTS:
			_open_table(slots_menu)
		CasinoMenuScript.Row.WHEEL:
			_open_table(wheel_menu)
		CasinoMenuScript.Row.BLACKJACK:
			_open_table(blackjack_menu)
		CasinoMenuScript.Row.RACING:
			_open_table(race_menu)


## Close the lobby and open one table over the top of it. Closing first, and not after, so
## _no_menu_but() is true by the time the table asks it: two open menus is the state that
## leaves the world unpaused under the one still on screen (see _no_menu_but()).
func _open_table(menu: CanvasLayer) -> void:
	if menu == null or not menu.has_method("open"):
		return
	if casino_menu != null and casino_menu.has_method("close"):
		casino_menu.close()
	menu.call("open")


## The menu behind one of CasinoMenu's four game rows, or null.
func get_table_menu(row: int) -> CanvasLayer:
	match row:
		CasinoMenuScript.Row.SLOTS:
			return slots_menu
		CasinoMenuScript.Row.WHEEL:
			return wheel_menu
		CasinoMenuScript.Row.BLACKJACK:
			return blackjack_menu
		CasinoMenuScript.Row.RACING:
			return race_menu
	return null


func get_casino_menu() -> CanvasLayer:
	return casino_menu


func _on_deliver_requested(uid: StringName) -> void:
	deliver_pony(uid)


## GIVE EVERYTHING BACK once the balance is under the ceiling. Called after every payment
## and after every delivery, because either can be what brings her back into good standing.
func _relieve_if_paid_down() -> void:
	if _game_state == null:
		return
	var given: Dictionary = _game_state.ledger.relieve(
		_world.cycle_index() if _world != null else -1)
	if given.is_empty():
		return
	for permit in given.get("permits", []):
		if not String(permit) in _game_state.unlocks:
			_game_state.unlocks.append(String(permit))
	_apply_permits()
	_apply_padlocks()
	_apply_beam_recall()
	_toast("Your account is in good standing again. Cloudsdale thanks you!")


func is_near_market() -> bool:
	var market := get_node_or_null(^"Buildings/Market") as Node3D
	if market == null:
		return false
	var gap := Vector2(player.global_position.x - market.global_position.x,
		player.global_position.z - market.global_position.z).length()
	return gap <= MARKET_RADIUS


## WALK UP TO A LOCKED FENCE AND BE TOLD WHAT IT IS AND WHAT IT COSTS. Once per approach,
## because a toast reprinted at 60 Hz never fades and never stops covering the screen. This
## is the last prompt in the game still working that way: everything the interact key can
## reach went through game/world/interaction.gd and became a persistent HUD line instead (see
## _update_interaction()), and the five _update_*_interaction() handlers this sentence used
## to point at are gone with their latches.
##
## THERE IS NO BUTTON HERE, deliberately. A gate is not a thing you interact with; it is a
## thing you are refused by, and the refusal has to name the shop that lifts it. Pressing E
## at the rails and being told "you cannot afford this" would be a purchase screen at the
## far end of the map, 120 m from the wallet and the gems it spends.
func _update_gate_prompt() -> void:
	if not _no_other_menu_open():
		return
	var fence := nearest_locked_gate()
	var here: StringName = fence.region().id if fence != null else &""
	if here == _gate_prompted:
		return
	_gate_prompted = here
	if fence != null:
		_toast("This is %s. The permit costs %d bits at the market."
			% [fence.region().display_name, fence.region().permit_cost])


# --- the compendium, the board and the payouts -------------------------------------------

## Subscribe to the beam's catches. ONE CONNECTION, made once at boot, rather than a hook
## per pony: the beam is what turns a hold into a capture (see magic_beam.gd), and it
## already carries the PonyInstance the compendium and the board both need.
##
## connect()-by-name for _bind_build_menu()'s reason: `beam` is reached through the player
## scene and is typed as a Node3D here.
func _bind_capture() -> void:
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		# A FAILED check in _report() ("the HUD found the magic beam"), not a crash in boot.
		return
	if not beam.is_connected("captured", _on_pony_captured):
		beam.connect("captured", _on_pony_captured)


## A wild pony has just reached the map, from populate() at boot or from refresh() at a
## change of sky. Her PonyData is bound into the handler rather than looked up again later,
## because by the time she is noticed she may well be the only thing that still knows who
## she was.
func _on_pony_spawned(pony: Node3D) -> void:
	if pony == null:
		return
	var data: PonyData = pony.get_data()
	if data == null:
		return
	# Unconditionally, with no is_connected() guard: every pony arriving here is a node
	# that was instantiated a moment ago, so there is nothing for a second connection to
	# be made on top of. (A bound Callable does not compare equal to the same handler bound
	# to a different argument anyway, so the guard would not have worked.)
	pony.connect("noticed_player", _on_pony_noticed.bind(data))


## The player has laid eyes on her for the first time. SEEN in the compendium, and progress
## on the board's "find her and get a good look" request if one is asking for this face.
func _on_pony_noticed(data: PonyData) -> void:
	if data == null or _game_state == null:
		return
	_game_state.compendium.mark_seen(data.id)
	if _board != null:
		_pay_out(_board.on_seen(data))


## The beam turned a hold into a capture. CAUGHT in the compendium (which never downgrades,
## so catching a pony nobody ever noticed still records having seen her), and progress on
## the board.
##
## THE ZONE IS WHERE THE PLAYER IS STANDING, not where the pony was standing. A pony beamed
## across a fence line from outside it was not brought FROM the region she happened to be
## grazing in, and the board's BRING_PERSONALITY_FROM_ZONE request is about the trip.
## &"ranch" is the answer for the open homestead, which is what RegionRegistry.region_at()
## returning null means.
func _on_pony_captured(instance: PonyInstance) -> void:
	if instance == null or _game_state == null:
		return
	# THE CROWD IS NOT COLLECTED. A stock pony has no Compendium entry and no request ever
	# names one: she is supply, not a character. Marking her would put an id in the book
	# that no page can ever show and no count can ever include.
	if instance.is_stock():
		return
	_game_state.compendium.mark_caught(instance.data_id)
	if _board == null:
		return
	var here: RegionData = _regions_registry().region_at(
		Vector2(player.global_position.x, player.global_position.z))
	var zone: StringName = here.id if here != null else &"ranch"
	_pay_out(_board.on_caught(instance.data(), zone))


## Mark every pony the player owns CAUGHT. The three places one can be: the save's own
## roster, a pen's residents, and the saddlebag. All three, because they do not agree at
## every moment: a pony penned since the last write is in a pen and not in
## GameState.ponies, and _sync_game_state() is what reconciles them, at save time, not now.
##
## Returns how many entries this call actually raised, which is zero on the second call and
## on any load of a save whose compendium was already complete. NOTHING IS EVER REMOVED
## here or anywhere else; the compendium only moves forward.
func _mark_owned_caught() -> int:
	if _game_state == null:
		return 0
	var raised := 0
	for instance: PonyInstance in _game_state.get_ponies():
		if _game_state.compendium.mark_caught(instance.data_id):
			raised += 1
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for resident: PonyInstance in pen.ponies():
			if _game_state.compendium.mark_caught(resident.data_id):
				raised += 1
	var beam: Node3D = player.get_magic_beam()
	if beam != null:
		for carried: PonyInstance in beam.get_storage().contents():
			if _game_state.compendium.mark_caught(carried.data_id):
				raised += 1
	return raised


## The character roster, loaded once per session. See _roster.
func _pony_roster() -> PonyRegistry:
	if _roster == null:
		_roster = PonyRegistryScript.new()
		_roster.load_all(spawner.pony_dir)
	return _roster


## Every character id the compendium has heard of, SEEN or CAUGHT, as the board's fill()
## wants them. Read off to_dict(), which is exactly "the entries that are not UNSEEN"
## (game/systems/compendium.gd) rather than a second walk of the roster that would have to
## be kept in step with that rule by hand.
func _seen_ids() -> Array:
	if _game_state == null:
		return []
	return _game_state.compendium.to_dict().keys()


## BUILD (OR REBUILD) THE BOARD FROM WHATEVER GameState HOLDS RIGHT NOW.
##
## An EMPTY `requests` array is a ranch that has never had a board: the tutorial three go
## up (catch one, pen one, sell a gem), and fill() tops the board back to three as they are
## claimed. A non-empty one is restored as it stands, seed and draw counter included, so a
## save resumed at request four does not start the sequence over.
##
## THE SEED IS THE WORLD SEED, the same number the herd was drawn from. It has to come out
## of the save rather than out of a fresh roll, or reloading would hand the player a
## different set of favours than the ones she quit looking at.
func _rebuild_request_board() -> void:
	if _game_state == null:
		_board = null
		_refresh_tasks()
		return
	# PRICED REGIONS ONLY, the seventh site: the Strip has no ZoneMarker (Zones/ in
	# ranch.tscn only names the four priced regions, the ones a pony can actually be spawned
	# into), so "Bring a <personality> pony from The Strip" would be a request on_caught()
	# can never match; on_caught() checks the caught pony's own zone against the request's
	# zone exactly, and no pony is ever tagged &"strip". Handing the board a permanently
	# uncompletable favour is worse than never offering it.
	var region_ids: Array[StringName] = []
	var region_names := {}
	for region: RegionData in _regions_registry().all():
		if region.permit_cost <= 0:
			continue
		region_ids.append(region.id)
		region_names[region.id] = region.display_name

	var seed_value: int = _game_state.world_seed
	var saved: Array = _game_state.requests
	if saved.is_empty():
		_board = RequestBoardScript.new(seed_value, _pony_roster(), region_ids, region_names)
		_board.seed_tutorial()
	else:
		_board = RequestBoardScript.from_array(saved, _pony_roster(), region_ids, region_names)
	_board.fill(_seen_ids())
	_refresh_tasks()


## Repaint the HUD's starter checklist. Called wherever the board can have moved: after a
## payout, after a rebuild, and once at boot. Cheap (three rows, and nothing at all once
## they are claimed) and idempotent.
func _refresh_tasks() -> void:
	var hud := get_node_or_null(^"HUD")
	if hud == null or not hud.has_method("set_tasks"):
		return
	# HOISTED INTO A TYPED LOCAL, AND ASSEMBLED WITH A PLAIN if/else RATHER THAN A
	# TERNARY. Passing an inline `_board.tutorial_rows() if _board != null else []`
	# straight into this dynamic call throws exactly the SCRIPT ERROR
	# game/ui/hud.gd's set_tasks() comment describes, on the null-board branch
	# _bind_game_state() promises is not fatal (review round 1). The seemingly obvious
	# fix -- hoisting that same ternary into a typed local first -- is NOT enough on its
	# own: a `var rows: Array[Dictionary] = x if cond else []` still throws "Trying to
	# assign an array of type Array to a variable of type Array[Dictionary]" the moment
	# the bare `[]` branch is the one actually taken (confirmed directly: the true branch,
	# where `_board.tutorial_rows()` runs, assigns fine, and the false branch, an untyped
	# empty literal squeezed through the ternary, does not). A plain if/else statement
	# has no such quirk -- each assignment to `rows` is independently typed, not merged
	# through a ternary's own type inference -- so it is what actually survives both
	# branches, not just the one every real playthrough happens to exercise.
	var rows: Array[Dictionary] = []
	if _board != null:
		rows = _board.tutorial_rows()
	hud.set_tasks(rows)


## PAY FOR EVERY REQUEST THIS EVENT JUST COMPLETED. `completed` is what an on_*() call
## handed back: copies of the requests that flipped to done on THIS call and no others, so
## nothing here can pay twice for one favour.
##
## CLAIM FIRST, AND PAY OUT OF WHAT THE CLAIM HANDED BACK. claim() is the board's own
## authority on whether this request is done and not yet paid, and it answers with an empty
## Dictionary when it is neither (game/systems/request_board.gd); paying first and claiming
## afterwards threw that answer away, which made `paid` a field nothing consulted and left
## the door open for one favour to be paid twice by two events that both thought they had
## finished it. A refused claim is reported and skipped rather than paid on the strength of
## the copy that was handed in.
##
## THEN BITS, THEN FOOD, THEN THE TOAST, THEN THE REFILL, PER REQUEST. The refill sits inside
## the loop rather than after it so that a rare event finishing two requests at once still
## leaves three offers standing between the two toasts; fill() draws nothing when the board
## is already full, so the repeat costs nothing.
func _pay_out(completed: Array) -> void:
	if _board == null:
		return
	for entry in completed:
		var request_id := String((entry as Dictionary).get("id", ""))
		var claimed: Dictionary = _board.claim(request_id)
		if claimed.is_empty():
			push_warning(("ranch: request '%s' was reported complete but the board refused " +
				"to claim it (unknown, not done, or already paid); nothing was paid.")
				% request_id)
			continue
		var reward_bits := int(claimed.get("reward_bits", 0))
		var reward_food := String(claimed.get("reward_food", ""))
		# OFF THE REQUEST, NOT OFF THE BOARD'S CONSTANT. The request carries its own
		# reward_food_count now (game/systems/request_board.gd), which is what lets the
		# toast below name what was actually handed over.
		var reward_food_count := int(claimed.get("reward_food_count", 0))
		if _economy != null and reward_bits > 0:
			_economy.grant(reward_bits)
		if _game_state != null and not reward_food.is_empty() and reward_food_count > 0:
			_game_state.inventory.add(StringName(reward_food), reward_food_count)
		# THE TOAST NAMES THE FOOD. "+40 bits" for a favour that also handed over two hay is
		# a receipt that does not match what went into the saddlebag, and the player has no
		# other way to find out that it did.
		var reward_text := "+%d bits" % reward_bits
		if not reward_food.is_empty() and reward_food_count > 0:
			reward_text += " and %d %s" % [reward_food_count, reward_food]
		_toast("Request done: %s (%s)" % [String(claimed.get("text", "")), reward_text])
		_board.fill(_seen_ids())
	_refresh_tasks()


## The board this ranch is running, or null only if there is no GameState to hold it.
## Exposed for the gates, which otherwise cannot tell a board with nothing on it from a
## board that was never built.
func get_request_board() -> RequestBoard:
	return _board


## The player's compendium, or null when there is no GameState. Read straight off the state
## rather than cached here, for rebind_economy()'s reason: a load replaces it.
func get_compendium() -> Compendium:
	return _game_state.compendium if _game_state != null else null


## Is the player standing at the request board?
##
## THE OVERLAP WITH THE MARKET IS NOT SETTLED HERE ANY MORE. This used to end with
## "and not is_near_market()", because the board stands five metres from the Market's
## origin and the two radii meet in the middle. That rule now lives in one place, as one
## line of game/world/interaction.gd's PRIORITY list, with every other precedence in the
## game beside it; a predicate that answers "am I at the board" should answer that and not
## also arbitrate.
func is_near_board() -> bool:
	var board := get_node_or_null(^"Buildings/Board") as Node3D
	if board == null:
		return false
	var gap := Vector2(player.global_position.x - board.global_position.x,
		player.global_position.z - board.global_position.z).length()
	return gap <= BOARD_RADIUS


## Show her what the board is asking for.
##
## TASK 5 IS THE PAGE. Until the pause menu grows one, the board opens the pause menu the
## way the PAUSE action does and says the three active requests in a toast; readable, and
## enough to play the loop with, but not the thing this is meant to be.
##
## The page number is fetched out of PauseMenu's own constant map rather than written here
## as `PauseMenu.Page.REQUESTS`, because that enum entry does not exist yet and a source
## file that names it would not compile. The lookup answers -1 today and the real page
## number the moment Task 5 adds it, with no edit here.
func _open_request_page() -> void:
	if pause_menu == null or not pause_menu.has_method("open"):
		return
	var page_id := _pause_menu_page("REQUESTS")
	if page_id >= 0 and pause_menu.has_method("open_page"):
		pause_menu.call("open_page", page_id)
		return
	pause_menu.open()
	var lines: Array[String] = []
	for entry in (_board.active() if _board != null else []):
		lines.append(String((entry as Dictionary).get("text", "")))
	if not lines.is_empty():
		_toast(" / ".join(lines))


## The value of PauseMenu.Page.`page_name`, or -1 if this build's pause menu has no such
## page (or no script at all). See _open_request_page().
func _pause_menu_page(page_name: String) -> int:
	if pause_menu == null or pause_menu.get_script() == null:
		return -1
	var constants: Dictionary = pause_menu.get_script().get_script_constant_map()
	var pages: Variant = constants.get("Page", null)
	if typeof(pages) != TYPE_DICTIONARY:
		return -1
	var page_map: Dictionary = pages
	return int(page_map[page_name]) if page_map.has(page_name) else -1


func get_shop() -> Shop:
	return _shop


func get_market_menu() -> CanvasLayer:
	return market_menu


func get_pause_menu() -> CanvasLayer:
	return pause_menu


func get_economy() -> Economy:
	return _economy


func plot_slots() -> Array[PlotSlot]:
	return _plot_slots()


func plots_catalogue() -> PlotRegistry:
	return _plots_catalogue()


## Is this ranch instanced under another scene rather than run as the main scene? See
## _hosted for what changes when it is.
func is_hosted() -> bool:
	return _hosted


func _on_plot_chosen(plot: PlotData, slot: PlotSlot) -> void:
	if plot == null or slot == null:
		return
	if _economy != null and not _economy.can_afford(plot.cost):
		_toast("You cannot afford a %s yet." % plot.display_name)
		return
	# THE SECOND HALF OF THE PLAYTEST REPORT THE GATE FIXES THE FIRST HALF OF. Checked HERE
	# as well as at the prompt, because this is the last point before a fence exists and the
	# prompt is only the last point before a MENU does -- and nothing stops a future caller
	# reaching _on_plot_chosen by another route.
	if _player_stands_on_footprint(slot):
		_toast("Step outside the plot markers first, or you would be fenced in.")
		return
	if not slot.build(plot):
		_toast("Nothing can go up on that plot.")
		return
	if _economy != null:
		_economy.spend(plot.cost)
	_toast("%s built." % plot.display_name)


## Move the pony at the top of the saddlebag into the pen the player is standing at.
##
## THIS IS `Storage.release()`'s PRODUCTION CALLER on the pen side -- the finding Phase 1A's
## review raised ("release() exists with zero callers") and that Phase 1B's plan named as a
## carried fact. MagicBeam.release_stored() is the other one; this is the one that makes a
## pen a place ponies live rather than a decoration.
##
## THE ORDER IS CHECK, THEN RELEASE, THEN ADD, THEN PUT HER BACK IF THE ADD SOMEHOW FAILED.
## A pony taken out of the bag and refused by the pen with nowhere to go is a pony deleted
## by a bookkeeping mistake, and NO PONY EVER DIES covers that as much as it covers
## anything else.
func _move_pony_into_pen(slot: PlotSlot) -> bool:
	var pen := slot.get_built() as Pen if slot != null else null
	if pen == null:
		return false
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return false
	var storage: Storage = beam.get_storage()
	var next: PonyInstance = storage.peek()
	if next == null:
		_toast("Your saddlebag is empty.")
		return false
	if pen.is_full():
		_toast("That pen is full.")
		return false

	var instance: PonyInstance = storage.release()
	if not pen.add_pony(instance):
		# Belt and braces -- and this branch was NOT unreachable, whatever this comment used
		# to claim. Beaming a pony OUT of a pen left her on that pen's roster: the slot
		# stayed spent, has_pony() stayed true, and every attempt to move her back in landed
		# here, which is the "She would not go in." the second playtest reported. That leak
		# is fixed at its source (game/world/pen.gd evicts a resident off her own captured()
		# signal), so this is once again the guard it was meant to be rather than a symptom.
		# It stays, because a pony taken out of the bag and refused with nowhere to go is a
		# pony deleted by bookkeeping, and NO PONY EVER DIES covers that too.
		storage.store(instance)
		_toast("She would not go in.")
		return false
	_toast("%s moved into the pen." % instance.display_name())
	# AFTER the add succeeded and not before: the two branches above both end with her back
	# in the saddlebag, and a board credited on the attempt would pay for a penning that
	# never happened.
	if _board != null:
		_pay_out(_board.on_penned(instance.data()))
	return true


## EVERYTHING E COULD MEAN WHERE THE PLAYER IS STANDING, unranked. The world half of the
## resolver: this file knows what a plot slot and a Pen and a saddlebag are, and
## game/world/interaction.gd knows which of them wins. Public so a gate or a test can ask
## "what is offered here" without an Input event and without a frame.
##
## A PEN IS ALWAYS A CANDIDATE, even with an empty bag or a full pen, so that standing in
## your own paddock and pressing E can never open the Market instead. What the prompt says
## in that state is Interaction.prompt_for()'s business.
func interaction_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null:
		return out
	var at: Vector3 = player.global_position
	for slot in _plot_slots():
		if not (player in slot.get_overlapping_bodies()):
			continue
		var gap: float = Vector2(at.x - slot.global_position.x,
			at.z - slot.global_position.z).length()
		if slot.is_empty():
			out.append(InteractionScript.candidate(
				InteractionScript.Kind.PLOT_BUILD, gap, String(slot.name)))
		else:
			out.append(InteractionScript.candidate(
				InteractionScript.Kind.PEN_MOVE_IN, gap, _next_in_the_bag()))
	if is_near_market():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.MARKET, _flat_gap_to(^"Buildings/Market")))
	if is_near_board():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.BOARD, _flat_gap_to(^"Buildings/Board")))
	if is_near_depot():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.DEPOT, _flat_gap_to(^"Buildings/Depot")))
	# THE BAN CLOSES THE DOOR RATHER THAN GREYING IT OUT. The shipped code showed no prompt
	# under a ban but still let the press through to casino_menu.open(), which then refused
	# on its own can_open; a player got a silent nothing. A banned Palace is simply not
	# offered, so the prompt and the button agree.
	if is_near_palace() and casino_can_enter():
		out.append(InteractionScript.candidate(
			InteractionScript.Kind.PALACE, _flat_gap_to(^"Buildings/Palace")))
	return out


## Whoever is at the top of the saddlebag, by name, or "" for an empty bag. Only the prompt
## reads this; _move_pony_into_pen() asks the Storage itself when the key is actually
## pressed, so a pony beamed in between the prompt and the press is still the one who goes
## into the pen.
func _next_in_the_bag() -> String:
	if player == null:
		return ""
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return ""
	var storage: Storage = beam.get_storage()
	if storage == null:
		return ""
	var next: PonyInstance = storage.peek()
	return next.display_name() if next != null else ""


func _flat_gap_to(path: NodePath) -> float:
	var node := get_node_or_null(path) as Node3D
	if node == null or player == null:
		return 0.0
	return Vector2(player.global_position.x - node.global_position.x,
		player.global_position.z - node.global_position.z).length()


## THE ONE THING E WILL DO, or an empty dictionary. Public for the same reason
## interaction_candidates() is.
func current_interaction() -> Dictionary:
	if not _no_other_menu_open():
		return {}
	return InteractionScript.resolve(interaction_candidates())


## DO IT. Returns whether anything actually happened. Public and Input free, so a gate can
## drive the verb the player presses instead of reaching past it (scenes/test/
## collection_test.gd's own note explains why it had to reach past the old one).
func perform_interaction(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	match int(action.get("kind", InteractionScript.Kind.NONE)):
		InteractionScript.Kind.PLOT_BUILD:
			var slot: PlotSlot = _slot_named(String(action.get("subject", "")))
			if slot == null:
				return false
			# Told BEFORE the menu rather than after she has picked something: being made
			# to choose a pen and only then being sent to stand somewhere else is a worse
			# version of the same refusal.
			if _player_stands_on_footprint(slot):
				_toast("Step outside the plot markers to build here.")
				return false
			if build_menu == null or not build_menu.has_method("open"):
				return false
			return bool(build_menu.open(slot))
		InteractionScript.Kind.PEN_MOVE_IN:
			var pen_slot: PlotSlot = _nearest_occupied_slot()
			return _move_pony_into_pen(pen_slot) if pen_slot != null else false
		InteractionScript.Kind.MARKET:
			if market_menu == null or not market_menu.has_method("open"):
				return false
			return bool(market_menu.open())
		InteractionScript.Kind.BOARD:
			_open_request_page()
			return true
		InteractionScript.Kind.DEPOT:
			if depot_menu == null or not depot_menu.has_method("open"):
				return false
			return bool(depot_menu.open())
		InteractionScript.Kind.PALACE:
			if casino_menu == null or not casino_menu.has_method("open"):
				return false
			return bool(casino_menu.open())
	return false


## The plot slot called `slot_name`, or null. The PLOT_BUILD candidate carries the slot's
## own node name as its subject precisely so this lookup is a name and not an index into a
## list that may have been rebuilt since the candidate was made.
func _slot_named(slot_name: String) -> PlotSlot:
	for slot in _plot_slots():
		if String(slot.name) == slot_name:
			return slot
	return null


## The nearest built slot the player is actually standing in. The PEN_MOVE_IN candidate
## carries the pony's name as its subject (that is what the prompt needs), so the slot is
## found again here rather than carried; the resolver already guaranteed she is standing in
## exactly one, and "nearest" settles a map edit that ever overlapped two.
func _nearest_occupied_slot() -> PlotSlot:
	var best: PlotSlot = null
	var best_gap := INF
	for slot in _plot_slots():
		if slot.is_empty() or not (player in slot.get_overlapping_bodies()):
			continue
		var gap: float = Vector2(player.global_position.x - slot.global_position.x,
			player.global_position.z - slot.global_position.z).length()
		if gap < best_gap:
			best_gap = gap
			best = slot
	return best


## THE WHOLE INTERACT VERB, ONCE A FRAME. Ask the world what is on offer, ask the resolver
## which one wins, say so on the HUD, and act on exactly that one if the key went down.
##
## NO LATCHES. The five handlers this replaces kept six of them between them, each
## implementing "fire once per approach" a slightly different way, and one of them
## (_prompt_slot) doubled as the mutex the other four consulted. The prompt is a persistent
## label now, so there is nothing to fire once and nothing to go stale.
func _update_interaction() -> void:
	var action: Dictionary = current_interaction()
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("set_prompt"):
		hud.set_prompt(InteractionScript.prompt_for(action,
			InputDeviceScript.hint(&"interact")))
	if action.is_empty() or not Input.is_action_just_pressed(&"interact"):
		return
	perform_interaction(action)


## IS THE PLAYER STANDING WHERE THE FENCE IS ABOUT TO GO UP?
##
## THE OTHER HALF OF "i also trapped myself inside the pen and couldnt leave": he built the
## paddock while standing on the plot, and it closed around him. The gate now means being
## inside a pen is survivable, but a fence materialising through the body of the person who
## ordered it is a bug of its own -- she is left overlapping a slab, to be shoved out of it on
## whichever side the depenetration picks, on the frame after she pressed a button in a menu.
##
## REFUSED WITH A REASON, rather than moving her outside as the pen completes. Being
## teleported is the one outcome that can surprise her: she is looking at a menu, and the
## world she looks back at is not the one she left. "Step outside the plot markers" is a
## sentence she can act on -- and those markers are drawn on EXACTLY this footprint by
## game/world/plot_slot.gd's _refresh_stakes(), so the line she is being asked to step over is
## already on the ground in front of her. There is room to stand: a slot's trigger reaches
## 4.35 m and holds her while her capsule is inside it, so the legal band runs from 4.32 m out
## (this function's own limit) to about 4.77 m.
##
## THE GEOMETRY ITSELF LIVES ON THE SLOT (PlotSlot.is_on_footprint), because the slot is what
## draws the marked square and knows its own frame -- two of ranch.tscn's four are turned 180
## degrees. This function is only "which body, and how wide is she".
func _player_stands_on_footprint(slot: PlotSlot) -> bool:
	if slot == null or player == null:
		return false
	return slot.is_on_footprint(player.global_position, PLAYER_BODY_RADIUS)


func _toast(text: String) -> void:
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("toast"):
		hud.toast(text)


## Copy the live world back into the savable state, immediately before a write.
##
## MERGES rather than replaces the owned list: what is in the saddlebag right now, plus any
## pony the state already knew about who is not in it (see restore_owned_ponies). Replacing
## outright would mean a save silently deleting every pony the bag could not hold.
func _sync_game_state() -> void:
	if _game_state == null:
		return
	# The trays first: gems left sitting in a pen at quit time are gems the save never
	# hears about, and this is the one funnel every write goes through.
	collect_gems()
	# AND THE SAME FUNNEL IS WHERE AN UNFINISHED BET COMES BACK. A save written while a race
	# is running would record a purse with the stake already taken and no bet anywhere in the
	# file to settle it: a silent forfeit, paid by a player who did nothing but quit. Doing it
	# HERE rather than only from _notification() is what makes the ordering irrelevant, since
	# GameState calls this before it writes, and it is notified before this node is. See
	# refund_open_race(); save_game() refuses outright while the track runs, so in practice
	# the only write that ever reaches a live race is the one on the way out.
	refund_open_race()
	var owned: Array[PonyInstance] = []
	var seen := {}
	var beam: Node3D = player.get_magic_beam()
	if beam != null:
		for instance: PonyInstance in beam.get_storage().contents():
			owned.append(instance)
			seen[instance.uid] = true
	# Everyone living in a pen. Their addresses ride in their own records, so writing them
	# into the roster is the whole of "the pens survive quitting" -- there is no second
	# structure to keep in step.
	for slot in _plot_slots():
		var pen := slot.get_built() as Pen
		if pen == null:
			continue
		for instance: PonyInstance in pen.ponies():
			if not seen.has(instance.uid):
				owned.append(instance)
				seen[instance.uid] = true
	for instance: PonyInstance in _game_state.get_ponies():
		if not seen.has(instance.uid):
			owned.append(instance)
	_game_state.set_ponies(owned)
	_game_state.plots = _live_plots()
	# THE WORLD SEED IS NOT WRITTEN HERE. The state owns it and the spawner reads it (see
	# _rebuild_world_state); a write in this direction meant that a save loaded mid-session
	# had the seed of the session it replaced stamped back over it on the next save, because
	# the spawner's copy was the stale one. _bind_game_state() is what gives a brand new
	# ranch its seed, once, so the first save still records the map it was generated from.
	# THE CLOCK, UNLESS IT WAS PINNED. --phase=/--weather= freeze the world at an hour
	# nobody played to, and writing that back would hand the player a ranch stopped at
	# whatever a screenshot run happened to ask for. WorldState.advance() already refuses
	# to move a pinned clock, so the value here could only ever be the one the save was
	# opened with; but the whole point of the flag is that a pinned run touches nothing,
	# and "it would have written the same number" is not the same promise.
	if _world != null and not _world.is_pinned():
		_game_state.world_time = _world.elapsed()
	# THE BOARD, WHOLE: its seed, its draw counter and every request on it (see
	# RequestBoard.to_array()). The compendium needs no line here, because GameState owns
	# that object outright and this ranch only ever marks entries on it in place.
	if _board != null:
		_game_state.requests = _board.to_array()


## Save the ranch. Returns whether it landed. The live world is copied in by
## GameState.save_to_slot() itself, through the `world_sync` Callable registered above;
## deliberately not called here, so that this path and the save-on-quit path cannot drift
## apart into "one of them syncs and the other does not".
##
## NOT WHILE THERE IS A RACE ON. A save taken mid race is a save of a world with a bet in it
## that the file has no way to describe, so reloading it would either lose the stake or, if
## the refund fired first, void a race the player is standing there watching. Both are the
## Palace quietly deciding a bet for her. The one save that IS allowed to land mid race is
## the one on the way out, which goes through GameState.save_on_quit() rather than here and
## refunds in _sync_game_state() before it writes.
##
## THIS IS THE ONE PLACE THAT REFUSES, and it covers both callers: the pause menu's Save row
## (_on_pause_save(), which says so out loud) and the autosave that fires when the player
## walks home past the farmhouse.
func save_game() -> bool:
	if _game_state == null:
		return false
	if race_track != null and bool(race_track.call("is_running")):
		return false
	return _game_state.save_to_slot()


## Save when the player comes home, and on nothing else.
##
## THE HOUSE IS THE SAVE POINT because it is the one place on this map that already means
## "you". Hysteresis (HOUSE_SAVE_RADIUS vs HOUSE_SAVE_REARM) is what makes it one save per
## visit instead of one per frame -- standing in the doorway at 60 fps would otherwise
## rewrite the file, and its backup, sixty times a second.
##
## Gated on `_interactive` twice over (here and in GameState.autosave_enabled): a gate run
## teleports the player around the map to probe the camera, and one of those poses is a
## metre from a building. An autosave that fired on that would be a gate overwriting a real
## save.
func _physics_process(delta: float) -> void:
	# THE CLOCK ONLY RUNS FOR SOMEBODY PLAYING, and it is the first thing this function
	# does so that the guard below cannot ever be edited into swallowing it. A gate boots
	# this same scene, teleports the player about and spins hundreds of frames; a
	# screenshot run holds a pose. Neither is time the player lived through, and a world
	# whose hour moved because CI ran is a world CI is allowed to change. advance_world()
	# above is the deliberate way to move it instead. (advance() is itself a no-op on a
	# pinned world, so --phase=/--weather= stop the clock here as well.)
	if _interactive and _world != null:
		_world.advance(delta)

	if not _interactive:
		return
	# The wild refills itself while somebody is playing. Not while a gate is driving the
	# scene: a gate that teleports the player about for two hundred frames would otherwise
	# stand a fresh crowd behind it, and the pony count it is asserting on would move under
	# it. The gates call spawner.tick_stock() themselves, deliberately, where they mean to.
	spawner.tick_stock(delta)
	_update_interaction()
	# AFTER the interaction pass, so a ban that landed this frame shuts a door the resolver
	# would otherwise have just opened. See enforce_casino_ban().
	enforce_casino_ban()
	_update_gate_prompt()
	if _game_state == null:
		return
	var house := get_node_or_null(^"Buildings/Farmhouse") as Node3D
	if house == null:
		return
	var gap := Vector2(player.global_position.x - house.global_position.x,
		player.global_position.z - house.global_position.z).length()
	if gap > HOUSE_SAVE_REARM:
		_house_armed = true
		return
	if gap > HOUSE_SAVE_RADIUS or not _house_armed:
		return
	# NOT WHILE THEY ARE RUNNING. save_game() refuses on its own (see its comment); this
	# asks first so the arming is NOT spent, and the save simply happens on the next
	# approach, rather than being reported as a failure that never actually occurred.
	if race_track != null and bool(race_track.call("is_running")):
		return
	_house_armed = false
	var ok := save_game()
	var hud := get_node_or_null(^"HUD")
	if hud != null and hud.has_method("toast"):
		hud.toast("Ranch saved" if ok else "SAVE FAILED. See the log.")


# --- the two ponies behind counters --------------------------------------------------

## STAND THE VENDOR AND THE TELLER. Their positions come off the live building nodes rather
## than being typed as world coordinates, the same rule Strip.mount_marquee() follows: a
## Building's door is in its local plus Z gable end, so the spot in front of it is its own
## origin plus half its depth along that axis plus the standoff, whichever way the building
## has been turned in the scene.
##
## THEY ARE UNDER `Attendants`, WHICH IS NEITHER Props NOR Buildings, so neither number the
## ranch gate prints moves. See _report()'s own attendant checks.
##
## PAST THE DOOR APRON'S FOOT, not past the wall: see ATTENDANT_STANDOFF.
func _stand_attendants() -> void:
	if attendants == null:
		return
	var registry := PonyRegistryScript.new()
	registry.load_all(spawner.pony_dir if spawner != null else "res://data/ponies")
	_stand_one(registry, "Vendor", ^"Buildings/Market", StockPaletteScript.IDS[1],
		VENDOR_LOOK)
	_stand_one(registry, "Teller", ^"Buildings/Palace", StockPaletteScript.IDS[2],
		TELLER_LOOK)


func _stand_one(registry: PonyRegistry, who: String, building_path: NodePath,
		record_id: StringName, look: Dictionary) -> void:
	var building := get_node_or_null(building_path) as Building
	if building == null:
		return
	var data: PonyData = registry.by_id(record_id)
	if data == null:
		return
	var out_dir: Vector3 = (building.global_transform.basis * Vector3(0.0, 0.0, 1.0))
	out_dir.y = 0.0
	if out_dir.length_squared() <= 0.0:
		return
	out_dir = out_dir.normalized()
	var at: Vector3 = building.global_position \
		+ out_dir * (building.apron_foot_z() + ATTENDANT_STANDOFF)
	var node: Attendant = AttendantScript.new()
	node.name = who
	attendants.add_child(node)
	node.global_position = Vector3(at.x, terrain.height_at(at.x, at.z), at.z)
	node.dress(data, look, out_dir)
	PropsScript.seat(node, terrain.height_at(at.x, at.z))


## How many attendants are standing. Printed by the report and asserted there; a public
## reader so a gate does not have to walk the tree.
func attendant_count() -> int:
	return attendants.get_child_count() if attendants != null else 0


# --- the gate -----------------------------------------------------------------------

## The only place `checks` may be written. Guards against the exact bug a reviewer
## found live in `game/scenes/test/capture_test.gd`: a label reused for a second check
## silently discards the first one, and the gate keeps printing green with a whole
## requirement no longer gated. A Dictionary itself will not tell you that happened --
## `checks[label] = x` just overwrites -- so the guard has to live here, not in the
## Dictionary.
func _set_check(checks: Dictionary, label: String, ok: bool) -> void:
	if checks.has(label):
		push_error(("ranch: DUPLICATE CHECK LABEL -- '%s' was assigned twice; the first " +
			"assignment was silently discarded and its requirement went ungated.") % label)
		if not label in _duplicate_check_labels:
			_duplicate_check_labels.append(label)
	checks[label] = ok


func _report(pony_count: int, prop_count: int) -> void:
	var checks := {}

	var props_present: bool = PropsScript.has_assets()
	var expected_props: int = PropsScript.expected_count() + buildings.get_child_count()
	var expected_ponies := 0
	for marker in spawner.get_markers():
		expected_ponies += marker.spawn_count + spawner.stock_budget(marker)
	# "Some pony in the roster has a model on this machine". Asked of the spawner's
	# own roster rather than by re-scanning the directory here: one scan, one answer,
	# and it cannot disagree with what the spawner actually drew from.
	var roster_size: int = spawner.get_roster_size()
	var ponies_present: bool = roster_size > 0 \
		and spawner.get_unspawnable().size() < roster_size
	if not ponies_present:
		expected_ponies = 0
	# A roster that failed to LOAD is not an assetless checkout, it is a broken game:
	# game/data/ponies/*.tres is committed, so it is present on every machine and in
	# every export. (It read as empty in the first exported build of this scene --
	# see PonyRegistry._resource_path for why.)
	_set_check(checks, "the pony roster loaded at all", roster_size > 0)

	var assets_state := "present"
	if not props_present and not ponies_present:
		assets_state = "absent"
	elif not props_present or not ponies_present:
		assets_state = "partial"
	if assets_state != "present":
		# Said once, plainly, at the top of the report -- a log that is going to
		# contain "0 ponies" should say why before it says the number.
		print(("RANCH NOTE assets=%s: game/assets/converted/ is gitignored, so this " +
			"checkout has no pony models and/or no props (docs/ci.md section 4). " +
			"The ranch is running on terrain and its hand-built buildings only; " +
			"the pony and prop counts below are expected to be zero.") % assets_state)

	# --- terrain ---------------------------------------------------------------
	var terrain_shape := terrain.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_set_check(checks, "the terrain has a collider",
		terrain_shape != null and terrain_shape.shape != null)
	_set_check(checks, "the terrain is on the TERRAIN layer",
		terrain.collision_layer == LayersScript.TERRAIN)

	# --- the player is somewhere real ------------------------------------------
	var p := player.global_position
	var ground_y: float = terrain.height_at(p.x, p.z)
	var player_offset: float = absf(p.y - ground_y)
	print("RANCH player pos=(%.2f, %.3f, %.2f) ground=%.3f offset=%.3f on_floor=%s"
		% [p.x, p.y, p.z, ground_y, player_offset, player.is_on_floor()])
	_set_check(checks, "the player is standing on the ground", player_offset <= GROUND_TOLERANCE)
	_set_check(checks, "the player reports a floor under her", player.is_on_floor())
	_set_check(checks, "the player's mask includes the terrain",
		player.collision_mask & LayersScript.TERRAIN != 0)
	_set_check(checks, "the player's mask includes the props",
		player.collision_mask & LayersScript.PROPS != 0)
	_set_check(checks, "the player is on the PLAYER layer",
		player.collision_layer == LayersScript.PLAYER)

	# --- props ------------------------------------------------------------------
	var all_props := _all_props()
	var total_shapes := 0
	var uncollided: Array[String] = []
	var prop_layers_ok := true
	var props_seated := true
	var pen_intrusions: Array[String] = []
	for prop: Node3D in all_props:
		var box: AABB = PropsScript.world_aabb(prop)
		# Measured off the live scene tree rather than from a counter kept during
		# construction: a counter can only tell you what the builder THOUGHT it made.
		var shapes: int = prop.find_children("*", "CollisionShape3D", true, false).size()
		total_shapes += shapes
		if shapes == 0:
			uncollided.append(prop.name)
		for body: StaticBody3D in _bodies_of(prop):
			if body.collision_layer != LayersScript.PROPS:
				prop_layers_ok = false
		if PropsScript.is_in_pen_plots(prop.global_position.x, prop.global_position.z):
			pen_intrusions.append(prop.name)
		# How far the bottom of the visible model sits from where props.gd seated it.
		# Zero means the prop is standing ON the ground, not floating over it and not
		# buried in it -- the assertion the eye would otherwise have to make. A Building
		# was not seated against the single point under its own origin (see the seating
		# loop above and Building.SEAT_CLEARANCE's comment); its expected ground is the
		# same seat_ground() reading ranch.gd actually handed Props.seat() for it.
		var expected_ground: float = terrain.height_at(
			prop.global_position.x, prop.global_position.z)
		var checked_building: Building = prop as BuildingScript
		if checked_building != null:
			expected_ground = checked_building.seat_ground(Callable(terrain, "height_at"))
		var sunk: float = box.position.y - (expected_ground - PropsScript.SINK_BIAS)
		if absf(sunk) > SEATING_TOLERANCE:
			props_seated = false
		print("RANCH prop %-34s pos=(%6.1f, %5.2f, %6.1f) height=%.2f seat_error=%+.3f"
			% [prop.name, prop.global_position.x, prop.global_position.y,
				prop.global_position.z, box.size.y, sunk])
	print("RANCH props placed=%d expected=%d shapes=%d missing=%s"
		% [prop_count, expected_props, total_shapes,
			", ".join(props.get_missing()) if not props.get_missing().is_empty() else "-"])
	_set_check(checks, "every layout entry with an asset was placed", prop_count == expected_props)
	_set_check(checks, "every prop got at least one collision shape", uncollided.is_empty())
	if not uncollided.is_empty():
		push_error("ranch: props with NO collision shape: %s" % ", ".join(uncollided))
	_set_check(checks, "every prop collider is on the PROPS layer", prop_layers_ok)
	_set_check(checks, "every prop is seated on the ground (none floats or sinks)", props_seated)

	# --- ponies -----------------------------------------------------------------
	var ponies: Array[CharacterBody3D] = spawner.get_spawned()
	var on_ground := true
	var in_zone := true
	var max_relief := 0.0
	var prop_overlaps: Array[String] = []
	var space := get_world_3d().direct_space_state
	for pony in ponies:
		var pos: Vector3 = pony.global_position
		var home: Vector3 = pony.get_home()
		var g: float = terrain.height_at(pos.x, pos.z)
		var offset: float = absf(pos.y - g)
		var marker := _nearest_marker(home)
		var from_marker := INF
		if marker != null:
			from_marker = Vector2(home.x - marker.global_position.x,
				home.z - marker.global_position.z).length()
			if from_marker > marker.spawn_radius + 0.01:
				in_zone = false
		if offset > GROUND_TOLERANCE:
			on_ground = false
		max_relief = maxf(max_relief, absf(terrain.height_at(home.x, home.z)))
		if PropsScript.is_in_pen_plots(home.x, home.z):
			pen_intrusions.append(pony.name)
		# The spawner's own reroll (game/world/spawner.gd, "inside a building or a tree
		# canopy, try somewhere else") only fires when the RAYCAST that first found her
		# ground point hits a PROPS-layer collider. Measured against this exact map, no
		# prop's footprint overlaps any zone disc (nearest is ~13.5 m outside
		# EastField), so that branch never fires here and a pony standing inside the
		# barn at ground level -- the raycast finding the barn's own floor, not
		# rejecting it -- would pass every check above. This is an independent,
		# after-the-fact geometric check: does the pony's ACTUAL capsule overlap ANY
		# prop's collider, right now, regardless of how she got there.
		if _pony_overlaps_prop(pony, space):
			prop_overlaps.append(pony.name)
		print("RANCH pony %-22s home=(%6.1f, %5.2f, %6.1f) now=(%6.1f, %5.2f, %6.1f) ground_offset=%.3f zone=%s r=%.1f state=%s"
			% [pony.name, home.x, home.y, home.z, pos.x, pos.y, pos.z, offset,
				marker.zone_id if marker != null else "<none>", from_marker,
				pony.state_name(pony.state)])
	_set_check(checks, "every pony spawned", ponies.size() == expected_ponies)
	print("RANCH crowd named=%d stock=%d budget=%d" % [
		spawner.named_standing(), spawner.stock_standing(), spawner.WORLD_PONY_BUDGET])
	_set_check(checks, "the world stays inside its pony budget",
		ponies.size() <= spawner.WORLD_PONY_BUDGET)
	# The spec's pacing rule, asserted rather than hoped for: a named pony is at most one in
	# five of what is standing in the homestead, so finding one takes minutes.
	var ranch_named := 0
	var ranch_stock := 0
	for marker in spawner.get_markers():
		if marker.zone_id != &"ranch":
			continue
		ranch_named += marker.spawn_count
		ranch_stock += spawner.stock_budget(marker)
	_set_check(checks, "named ponies are at most one in five of the homestead crowd",
		ranch_stock >= ranch_named * 4)
	_set_check(checks, "every pony is standing on the ground", on_ground)
	_set_check(checks, "every pony was spawned inside her zone", in_zone)
	_set_check(checks, "no pony needed a fallback placement",
		spawner.get_fallback_placements() == 0)
	_set_check(checks, "no zone came back with an empty roster",
		spawner.get_empty_zones().is_empty())
	# See the class comment: this is what stops the raycast check above going hollow.
	_set_check(checks, "the spawn zones sit on sloped ground",
		max_relief >= MIN_ZONE_RELIEF if ponies.size() > 0 else true)
	# THE GEOMETRY THAT MAKES THE CHECK ABOVE MEAN WHAT IT SAYS. "Inside her zone" is
	# asked of her NEAREST marker, not of the marker she was drawn for, because a pony
	# does not carry her marker around with her. That is only the same question while no
	# marker's spawn disc reaches more than halfway to another marker: put two discs any
	# closer and a pony spawned legitimately on the far rim of hers is nearer the other
	# one, and a correct spawn fails the gate. Slice 3's regions walked straight into it:
	# the orchard's marker was 31 m from EastField when these discs were first sized, so
	# its spawn disc could not be the radius minus 6 the plan asked for without the two
	# overlapping in this sense. The regions have since been pushed outward (see the check
	# below) and the orchard now sits 45 m out, but 14 m is what the map was tuned and
	# photographed with and widening it now would re-roll every spawn for no gain.
	var discs_own_their_ponies := true
	var markers: Array[ZoneMarker] = spawner.get_markers()
	for i in range(markers.size()):
		for j in range(markers.size()):
			if i == j:
				continue
			var apart := Vector2(markers[i].global_position.x - markers[j].global_position.x,
				markers[i].global_position.z - markers[j].global_position.z).length()
			if markers[i].spawn_radius >= apart * 0.5:
				discs_own_their_ponies = false
				push_error(("ranch: zone '%s' spawns up to %.1f m out, which is nearer " +
					"marker '%s' (%.1f m away) than its own.")
					% [markers[i].zone_id, markers[i].spawn_radius, markers[j].name, apart])
	_set_check(checks, "no spawn disc reaches more than halfway to another marker",
		discs_own_their_ponies)

	_set_check(checks, "no pony is standing inside a prop", prop_overlaps.is_empty())
	if not prop_overlaps.is_empty():
		push_error("ranch: pony overlapping a prop's collider: %s" % ", ".join(prop_overlaps))

	_set_check(checks, "the pen-plot clearing is clear", pen_intrusions.is_empty())
	# The PenPlots marker in ranch.tscn is what a human sees when they open the
	# scene; PropsScript.PEN_PLOTS_CENTRE is what the layout and these checks
	# actually use. Assert they agree, or the visible marker becomes a lie the first
	# time one of them is nudged.
	var pen_marker := $PenPlots as Marker3D
	_set_check(checks, "the PenPlots marker agrees with the reserved area",
		Vector2(pen_marker.global_position.x, pen_marker.global_position.z)
			.distance_to(PropsScript.PEN_PLOTS_CENTRE) < 0.01)
	if not pen_intrusions.is_empty():
		push_error("ranch: pen-plot clearing intruded on by: %s" % ", ".join(pen_intrusions))

	# --- the two ponies behind counters, and the census they must not touch ------------
	#
	# THEY ARE NOT PONIES AND THEY ARE NOT PROPS. `ponies=` counts spawner.get_spawned(),
	# which only ever holds Pony nodes; `props=` is Props.expected_count() plus the
	# Buildings children. The attendants are under `Attendants`, which is neither, so
	# neither number moves and this line is their own.
	var staff: int = attendant_count()
	_set_check(checks, "the vendor and the teller are both standing", staff == 2)
	var staff_are_bodies := true
	var staff_dressed := 0
	if attendants != null:
		for child in attendants.get_children():
			if child is PonyScript:
				staff_are_bodies = false
			elif child is AttendantScript and bool(child.call("has_model")):
				staff_dressed += 1
	_set_check(checks, "no attendant is a Pony, so the beam has nothing to take and the herd "
		+ "has nobody extra in it", staff_are_bodies)
	_set_check(checks, "every attendant is dressed, or the assets are absent",
		staff_dressed == staff or not ponies_present)
	var staff_in_herd := false
	for pony in ponies:
		if pony.get_parent() == attendants:
			staff_in_herd = true
	_set_check(checks, "no attendant is in the spawned herd", not staff_in_herd)
	print("RANCH attendants=%d dressed=%d" % [staff, staff_dressed])

	# --- plots and pens ------------------------------------------------------------------
	var slots := _plot_slots()
	var slots_seated := true
	var slots_in_clearing := true
	var slots_triggered := true
	var slot_ids := {}
	var slot_ids_unique := true
	for slot in slots:
		var at: Vector3 = slot.global_position
		var slot_ground: float = terrain.height_at(at.x, at.z)
		if absf(at.y - slot_ground) > SEATING_TOLERANCE:
			slots_seated = false
		# The whole TRIGGER, not just the centre: a slot whose middle is inside the reserved
		# clearing but whose corners hang over a tree is still a slot with a tree in it.
		for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0),
				Vector2(1.0, 1.0)]:
			var probe := Vector2(at.x + corner.x * PlotSlotScript.TRIGGER_HALF,
				at.z + corner.y * PlotSlotScript.TRIGGER_HALF)
			if not PropsScript.is_in_pen_plots(probe.x, probe.y):
				slots_in_clearing = false
		# See PlotSlot._ensure_shape(): an Area3D with no shape never fires body_entered,
		# and the only symptom is a build prompt that silently never appears.
		var trigger_shapes: Array = slot.find_children("*", "CollisionShape3D", false, false)
		if trigger_shapes.size() != 1 or (trigger_shapes[0] as CollisionShape3D).shape == null:
			slots_triggered = false
		if slot_ids.has(String(slot.slot_id)) or String(slot.slot_id).is_empty():
			slot_ids_unique = false
		slot_ids[String(slot.slot_id)] = true
		print("RANCH plot %-8s pos=(%6.1f, %5.2f, %6.1f) seat_error=%+.3f built=%s"
			% [String(slot.slot_id), at.x, at.y, at.z, at.y - slot_ground,
				slot.saved_plot_id() if not slot.is_empty() else "-"])

	# Every pair, both ways round the grid. Two slots whose triggers overlap make "which
	# plot am I standing on" a question with two answers, and the interact button would
	# then act on whichever one happened to be first in the scene.
	var slots_disjoint := true
	for i in range(slots.size()):
		for j in range(i + 1, slots.size()):
			var gap := Vector2(slots[i].global_position.x - slots[j].global_position.x,
				slots[i].global_position.z - slots[j].global_position.z).abs()
			if gap.x < PlotSlotScript.TRIGGER_HALF * 2.0 \
					and gap.y < PlotSlotScript.TRIGGER_HALF * 2.0:
				slots_disjoint = false

	_set_check(checks, "the ranch has between four and six plot slots",
		slots.size() >= MIN_PLOT_SLOTS and slots.size() <= MAX_PLOT_SLOTS)
	_set_check(checks, "every plot slot has a unique, non-empty id", slot_ids_unique)
	_set_check(checks, "every plot slot is seated on the ground", slots_seated)
	_set_check(checks, "every plot slot lies inside the reserved clearing", slots_in_clearing)
	_set_check(checks, "no two plot slots overlap", slots_disjoint)
	_set_check(checks, "every plot slot has a trigger shape", slots_triggered)

	# THE ASSUMPTION pen.gd's FLAT CARPENTRY RESTS ON -- see PEN_GROUND_FLATNESS.
	var clearing_low := INF
	var clearing_high := -INF
	for i in range(13):
		for j in range(13):
			var cx: float = PropsScript.PEN_PLOTS_CENTRE.x - PropsScript.PEN_PLOTS_HALF_EXTENT \
				+ 2.0 * PropsScript.PEN_PLOTS_HALF_EXTENT * float(i) / 12.0
			var cz: float = PropsScript.PEN_PLOTS_CENTRE.y - PropsScript.PEN_PLOTS_HALF_EXTENT \
				+ 2.0 * PropsScript.PEN_PLOTS_HALF_EXTENT * float(j) / 12.0
			var h: float = terrain.height_at(cx, cz)
			clearing_low = minf(clearing_low, h)
			clearing_high = maxf(clearing_high, h)
	var clearing_spread: float = clearing_high - clearing_low
	_set_check(checks, "the reserved clearing is flat enough to stand a fence on",
		clearing_spread <= PEN_GROUND_FLATNESS)

	# THE MEASUREMENT THAT MATTERS, asserted on the map rather than only in a unit test: a
	# pony is 2.138 m to her horn tip, not 1.163 m at the withers (docs/pipeline.md
	# section 3). Same argument game/world/building.gd's MIN_DOOR_CLEARANCE makes for a
	# doorway.
	_set_check(checks, "a pen's fence clears a pony's horn tip",
		PenScript.FENCE_HEIGHT >= 2.138 and PenScript.GATE_CLEARANCE >= 2.138)
	# roam_radius IS SOFT: fleeing momentum overshoots it by ~1.15 m, so a leash set at the
	# fence line is a pony clipped through her own paddock.
	_set_check(checks, "a penned pony's leash stops short of the fence by more than her flee overshoot",
		PenScript.roam_radius_for(PenScript.HALF_EXTENT) + ZoneMarkerScript.ROAM_OVERSHOOT
			+ PenScript.PONY_BODY_RADIUS <= PenScript.HALF_EXTENT)

	var catalogue: Array[PlotData] = _plots_catalogue().all()
	_set_check(checks, "the plot catalogue loaded at all", catalogue.size() > 0)
	var free_plots := 0
	for plot in catalogue:
		if plot.cost == 0:
			free_plots += 1
	# Bits come from selling gems, gems come from penned ponies, ponies need a pen. If every
	# plot cost something, a brand new save could never build anything.
	_set_check(checks, "at least one plot is buildable with zero bits", free_plots > 0)

	print("RANCH plots slots=%d catalogue=%d restored=%d penned=%d clearing_spread=%.3f bits=%d"
		% [slots.size(), catalogue.size(), _restored_plots, _penned_ponies, clearing_spread,
			_current_bits()])

	# THE PEN PROBE. See _probe_pen_containment() for why this runs at boot in every mode
	# and why an empty result is a failure rather than a skip -- the four slots are in
	# ranch.tscn on every checkout, assetless or not, so a probe that did not run means a
	# slot that could not be built on.
	print(("RANCH pen probe ran=%s ponies=%d inside=%s no_clip=%s solid=%s travelled=%.2f " +
		"worst=(%.2f, %.2f) half=%.2f leash=%.2f")
		% [_pen_probe.get("ran", false), _pen_probe.get("ponies", 0),
			_pen_probe.get("inside", false), _pen_probe.get("no_clip", false),
			_pen_probe.get("solid", false), _pen_probe.get("travelled", 0.0),
			_pen_probe.get("worst_x", 0.0), _pen_probe.get("worst_z", 0.0),
			_pen_probe.get("half", 0.0), _pen_probe.get("roam", 0.0)])
	_set_check(checks, "a pen could be built on a slot and stocked with ponies",
		bool(_pen_probe.get("ran", false)) and int(_pen_probe.get("ponies", 0)) == PEN_PROBE_PONIES)
	# THE ANTI-VACUITY GUARD, checked BEFORE the containment result it guards: "everybody is
	# inside the fence" is trivially true of ponies who never moved at all.
	_set_check(checks, "the pen probe actually moved its ponies",
		bool(_pen_probe.get("stressed", false)))
	_set_check(checks, "every penned pony is still inside her fence after being driven at it",
		bool(_pen_probe.get("inside", false)))
	_set_check(checks, "no penned pony is standing inside the fence itself",
		bool(_pen_probe.get("no_clip", false)))
	# See _fence_is_solid(): without this one, deleting the pen's colliders outright still
	# printed RANCH_OK, because the leash alone kept the ponies in.
	_set_check(checks, "a pen's fence is solid all the way round at pony height",
		bool(_pen_probe.get("solid", false)))
	_set_check(checks, "the probe pen was taken back down",
		bool(_pen_probe.get("torn_down", false)))

	# --- the market ----------------------------------------------------------------------
	# The building is hand-built like the barn and the farmhouse, so it stands on an
	# assetless checkout too and these checks are not gated on assets_state.
	_set_check(checks, "the market building stands", get_node_or_null(^"Buildings/Market") != null)
	_set_check(checks, "the shop is wired", _shop != null)
	# `== _shop` rather than `!= null`: the menu holding SOME shop is not the requirement,
	# the menu holding the shop that spends this ranch's wallet is.
	_set_check(checks, "the market menu is wired",
		market_menu != null and market_menu.has_method("open") and market_menu.get("shop") == _shop)
	_set_check(checks, "the pause menu is wired",
		pause_menu != null and pause_menu.has_method("open") and pause_menu.get("settings") == _settings)
	var catalogue_count: int = market_menu.buy_rows().size() if market_menu != null \
		and market_menu.has_method("buy_rows") else 0
	_set_check(checks, "the shop catalogue loaded", catalogue_count > 0)
	print("RANCH market shop=%s catalogue=%d gems=%d inventory=%d unlocks=%d"
		% [_shop != null, catalogue_count,
			_game_state.gems.total() if _game_state != null else 0,
			_game_state.inventory.ids().size() if _game_state != null else 0,
			_game_state.unlocks.size() if _game_state != null else 0])

	# --- the collection --------------------------------------------------------------------
	# THE BOOK AND THE BOARD, WHICH ARE BOTH INVISIBLE UNTIL SOMEBODY ASKS. A compendium
	# that was never wired and a compendium nobody has filled in yet read identically from
	# the outside (both say "0 seen"), and a board with no requests on it looks exactly like
	# a board whose page has not been written. So each of the three is asked as a number
	# here rather than inferred from the fact that the classes exist.
	var book: Compendium = get_compendium()
	_set_check(checks, "the compendium exists", book != null)

	# EVERY OWNED PONY IS A CAUGHT PONY, re-derived here rather than trusted: this is the
	# check that would catch rebind_economy()'s _mark_owned_caught() being dropped, or being
	# called before the pens are restored. It counts the ones that are NOT recorded, so the
	# failure names a real number instead of a bare false.
	var uncaught: Array[String] = []
	if book != null and _game_state != null:
		for instance: PonyInstance in _game_state.get_ponies():
			if book.state_of(instance.data_id) != CompendiumScript.State.CAUGHT:
				uncaught.append(String(instance.data_id))
		for slot in _plot_slots():
			var pen := slot.get_built() as Pen
			if pen == null:
				continue
			for resident: PonyInstance in pen.ponies():
				if book.state_of(resident.data_id) != CompendiumScript.State.CAUGHT:
					uncaught.append(String(resident.data_id))
		var owner_beam: Node3D = player.get_magic_beam()
		if owner_beam != null:
			for carried: PonyInstance in owner_beam.get_storage().contents():
				if book.state_of(carried.data_id) != CompendiumScript.State.CAUGHT:
					uncaught.append(String(carried.data_id))
	if not uncaught.is_empty():
		push_error("ranch: %d owned pony/ponies are not CAUGHT in the compendium: %s"
			% [uncaught.size(), ", ".join(uncaught)])
	_set_check(checks, "every owned pony is caught in the compendium",
		book != null and uncaught.is_empty())

	# THREE OFFERS, ALWAYS. fill() tops the board back up to RequestBoard.ACTIVE after every
	# claim, and SELL_GEMS_OF_RARITY has no precondition at all, so a board showing fewer
	# than three means the refill is not running rather than that the well ran dry.
	var active_requests: int = _board.active().size() if _board != null else 0
	_set_check(checks, "three requests are active on a fresh state",
		_board != null and active_requests == RequestBoardScript.ACTIVE)

	# Hand-built like the Market, so it stands on an assetless checkout too and this is not
	# gated on assets_state.
	_set_check(checks, "the board stands", get_node_or_null(^"Buildings/Board") != null)

	_set_check(checks, "the Depot stands", get_node_or_null(^"Buildings/Depot") != null)
	_set_check(checks, "the Depot has a crate to walk into",
		get_node_or_null(^"Buildings/Depot/Crate") != null)
	var ledger: Ledger = _game_state.ledger if _game_state != null else null
	_set_check(checks, "the ranch built a ledger", ledger != null)
	print("RANCH ledger balance=%d quota=%d delivered=%d tier=%d" % [
		ledger.balance if ledger != null else 0, ledger.quota if ledger != null else 0,
		ledger.delivered_this_period if ledger != null else 0,
		ledger.tier if ledger != null else 0])

	var book_registry: PonyRegistry = _pony_roster()
	# `requests` is the ACTIVE count, the same number the check above reads. requests() also
	# returns every claimed request the board has ever carried, so printing that would have
	# made a healthy board's number climb forever while the three on offer never changed.
	#
	# `seen` IS SEEN PLUS CAUGHT, the same definition the COMPENDIUM page's header uses
	# (game/ui/pause_menu.gd, compendium_header): every pony the player has caught is a pony
	# she has laid eyes on, and two lines about one book that count it differently are two
	# lines nobody can compare.
	var book_seen: int = 0
	var book_caught: int = 0
	if book != null:
		book_caught = book.count(CompendiumScript.State.CAUGHT, book_registry)
		book_seen = book.count(CompendiumScript.State.SEEN, book_registry) + book_caught
	print("RANCH collection seen=%d caught=%d of %d requests=%d" % [
		book_seen,
		book_caught,
		book.total(book_registry) if book != null else 0,
		active_requests])

	# --- the regions ------------------------------------------------------------------
	# Four data files, four rings of timber, four zones with residents in them. The three
	# facts that can each be true while the other two are broken: a region with no fence
	# is an unlocked region nobody paid for, a fence that stops nobody is the same thing
	# more expensively, and a zone with a marker but no ponies zoned to it is a meadow
	# behind a 1200-bit gate with nothing in it.
	var regions: Array[RegionData] = _regions_registry().all()
	var fences := get_region_fences()
	var fenced := {}
	var open_gates := 0
	for fence in fences:
		if fence.region() != null:
			fenced[fence.region().id] = true
		if fence.is_open():
			open_gates += 1
	var roster: PonyRegistry = PonyRegistryScript.new()
	roster.load_all(spawner.pony_dir)
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

	# NO HOMESTEAD ROAM DISC MAY REACH A REGION'S FENCE RING. The bug this exists for, found
	# by scenes/test/region_test.tscn: a `ranch` pony drawn for WestHollow spawned 22.1 m
	# from the everfree centre, which is 4.9 m INSIDE a ring standing at radius +
	# RegionFence.RING_MARGIN, with the gate shut and a pony's mask containing PEN_GATE. She
	# was walled into a region she does not belong to, behind the most expensive permit on
	# the map, for the rest of the save. Nothing above catches it: "every pony was spawned
	# inside her zone" asks her NEAREST marker, which was still WestHollow, and the halfway
	# rule below compares markers to markers rather than markers to rings.
	#
	# ZoneMarker.outer_bound() is the honest reach, the spawn disc plus a pony's whole roam
	# circle plus the flee overshoot, and its own doc already names it as the bound "any
	# future fence or boundary prop for this zone must clear". REGION_CLEARANCE on top of
	# that, so a fence line is never merely tangent to where a pony can get to.
	#
	# ASKED OF THE LIVE MARKERS AND THE LIVE REGIONS, not of a table of numbers: this has to
	# fail when somebody nudges a marker in ranch.tscn or a centre in a .tres, which is
	# exactly how it got in.
	# A REGION'S OWN MARKER MUST ALSO STAY INSIDE ITS OWN RING, with a metre to spare
	# (REGION_CLEARANCE). A resident's roam disc is drawn from her ZoneMarker; if that disc
	# reaches past the timber, she is a pony the fence cannot hold, on the shipped map, no
	# playtest required.
	var regions_stand_clear := true
	for marker: ZoneMarker in spawner.get_markers():
		var at := Vector2(marker.global_position.x, marker.global_position.z)
		if marker.zone_id == &"ranch":
			# PRICED REGIONS ONLY: the clearance being measured is the distance to a fence
			# RING, and a free region has no ring for a roam disc to reach.
			for region: RegionData in priced_regions:
				var apart := at.distance_to(region.centre)
				var needed: float = (region.radius + RegionFenceScript.RING_MARGIN
					+ marker.outer_bound() + REGION_CLEARANCE)
				if apart < needed:
					regions_stand_clear = false
					push_error(("ranch: homestead zone '%s' reaches to within %.1f m of region " +
						"'%s', whose fence ring needs %.1f m of room.")
						% [marker.name, apart, region.id, needed])
		else:
			var own_region: RegionData = _regions_registry().by_id(marker.zone_id)
			if own_region == null:
				regions_stand_clear = false
				push_error("ranch: zone marker '%s' names a region this map does not have: '%s'."
					% [marker.name, marker.zone_id])
			else:
				var own_limit: float = own_region.radius + RegionFenceScript.RING_MARGIN
				var offset: float = at.distance_to(own_region.centre)
				var own_reach: float = offset + marker.outer_bound() + REGION_CLEARANCE
				if own_reach > own_limit:
					regions_stand_clear = false
					push_error(("ranch: region '%s' marker '%s' reaches %.1f m from the centre " +
						"with clearance, past its own fence ring at %.1f m.")
						% [own_region.id, marker.name, own_reach, own_limit])
	_set_check(checks, "no homestead roam disc reaches a region's fence ring, and every " +
		"region's own residents stay inside their own ring", regions_stand_clear)

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

	# THE LIGHT RING CLEARS THE PALACE. game/world/strip.gd's avoid_footprint() is what
	# skips a lamp that would otherwise stand inside or against the building (the ring is
	# centred on the region, not on the Palace, which sits off centre; see
	# PALACE_MAX_RELIEF's comment above, so one ring position falls inside its footprint
	# without it). This re-checks that work independently, against the Palace's own live
	# position, so a later re-siting of either the Palace or the ring cannot silently let a
	# lamp back into the wall.
	var lamps_clear := true
	var lamp_count := 0
	if strip != null and palace != null:
		var p_at: Vector3 = palace.global_position
		var margin: float = StripScript.PALACE_CLEARANCE
		var p_min := Vector2(p_at.x - 7.0 - margin, p_at.z - 4.5 - margin)
		var p_max := Vector2(p_at.x + 7.0 + margin, p_at.z + 4.5 + margin)
		var positions: Array[Vector3] = (strip as StripScript).light_positions()
		lamp_count = positions.size()
		for pos: Vector3 in positions:
			if pos.x >= p_min.x and pos.x <= p_max.x and pos.z >= p_min.y and pos.z <= p_max.y:
				lamps_clear = false
				push_error(("ranch: a Strip lamp at (%.1f, %.1f) stands within its own " +
					"%.1f m margin of the Palace") % [pos.x, pos.z, margin])
	print("RANCH strip lamps=%d clear=%s" % [lamp_count, lamps_clear])
	_set_check(checks, "every Strip lamp clears the Palace footprint by its own margin",
		lamps_clear)

	var gate_probe: Dictionary = await _probe_region_gate()
	print("RANCH region gate ran=%s solid=%s opened=%s hit=%s"
		% [gate_probe.get("ran", false), gate_probe.get("solid", false),
			gate_probe.get("opened", false), gate_probe.get("hit", "<none>")])
	# An empty probe is a FAILED check and not a skip, for the reason the camera block
	# below spells out at length: the regions and their fences exist on every checkout,
	# assetless or not, so "there was nothing to probe" can only mean the thing that was
	# supposed to be probed is not there.
	_set_check(checks, "a locked region's gate is solid to the player",
		bool(gate_probe.get("solid", false)))
	_set_check(checks, "a permit in the unlocks opens its gate",
		bool(gate_probe.get("opened", false)))

	# --- THE GATE IS A GATE -----------------------------------------------------------------
	# "i also trapped myself inside the pen and couldnt leave" (owner playtest). The gateway
	# has to be a doorway to the player and a wall to a pony, and since the two are the same
	# capsule at the same height that can only be true by layer. Four checks, because any one
	# of them alone can pass while the feature is broken: a gateway open to BOTH is a leaky
	# pen, a gateway shut to both is the cage that was reported, and either of the two mask
	# facts on its own is a policy nobody applied.
	print("RANCH pen gate player_reached=%.3f pony_reached=%.3f player_mask=%d pony_mask=%d"
		% [_pen_probe.get("gate_player", 0.0), _pen_probe.get("gate_pony", 1.0),
			player.collision_mask, _pen_probe.get("pony_mask", 0)])
	_set_check(checks, "a player-sized body can walk out through a pen's gateway",
		float(_pen_probe.get("gate_player", 0.0)) >= 0.999)
	_set_check(checks, "a pony-sized body is stopped in the same gateway",
		float(_pen_probe.get("gate_pony", 1.0)) < 0.999)
	_set_check(checks, "the player's mask does not include a pen's gate leaf",
		player.collision_mask & LayersScript.PEN_GATE == 0)
	_set_check(checks, "a penned pony's mask does include a pen's gate leaf",
		int(_pen_probe.get("pony_mask", 0)) & LayersScript.PEN_GATE != 0)

	# --- the build menu ------------------------------------------------------------------
	# Same argument as the HUD block below: a build menu that failed to load its script is
	# still a CanvasLayer in the tree, drawn perfectly, doing nothing. `has_method` rather
	# than a bare call, for the same reason -- a call straight into an unscripted node
	# raises mid-report and the gate DISAPPEARS instead of failing.
	var menu = build_menu
	var menu_scripted: bool = menu != null and menu.has_method("entries")
	_set_check(checks, "the build menu is mounted and its script loaded", menu_scripted)
	if menu_scripted:
		_set_check(checks, "the build menu lists the whole plot catalogue",
			menu.entries().size() == catalogue.size() and catalogue.size() > 0)
		var provider: Variant = menu.get("bits_provider")
		_set_check(checks, "the build menu is wired to a wallet",
			provider is Callable and (provider as Callable).is_valid())

		# IT MUST REFUSE TO OPEN ON AN OCCUPIED SLOT, or the player builds a second pen on
		# top of her first one and the slot's whole build-once rule is bypassed by the only
		# thing that ever calls it.
		#
		# Measured against a THROWAWAY slot built here, not against whatever happens to be
		# on the map: the map's slots are empty in a fresh gate run, so asking the question
		# of them would be asking it of a case that cannot answer -- a check that passes
		# because there was nothing to refuse. This project has shipped that shape of gate
		# more than once; see the camera block below.
		var scratch: PlotSlot = PlotSlotScript.new()
		scratch.slot_id = &"slot_gate_probe"
		var refused_on_occupied := false
		var opened_on_empty: bool = menu.open(scratch)
		if opened_on_empty:
			menu.close()
		if catalogue.size() > 0 and scratch.build(catalogue[0]):
			refused_on_occupied = not menu.open(scratch)
			if not refused_on_occupied:
				menu.close()
		scratch.free()
		# Both halves, so "refuses everything" cannot pass as "refuses the right thing".
		_set_check(checks, "the build menu opens on an empty slot", opened_on_empty)
		_set_check(checks, "the build menu refuses to open on an occupied slot",
			refused_on_occupied)

	# --- the HUD ---------------------------------------------------------------------
	# A HUD that failed to find the beam looks EXACTLY like a HUD with an empty bag:
	# "0 / 12" and a row of empty pips, drawn perfectly, meaning nothing. game/ui/hud.gd
	# binds itself lazily (its own comment says why sibling ready order must not be
	# depended on), so "did the binding actually take" is a real thing to assert rather
	# than a formality -- and it is exactly the kind of failure a screenshot cannot show.
	# `has_method` rather than a bare call: a hud.gd that failed to PARSE still leaves a
	# CanvasLayer node in the tree with no script attached, and calling straight into it
	# raises a runtime error that aborts this whole report mid-way -- so the gate hangs
	# instead of printing RANCH_FAILED. (Which is exactly what a missing type hint in
	# hud.gd did the first time this check ran.) A gate must fail, not disappear.
	var hud := $HUD
	var hud_scripted: bool = hud != null and hud.has_method("get_beam")
	_set_check(checks, "the HUD is mounted and its script loaded", hud_scripted)
	if hud_scripted:
		# `player.get_magic_beam()` fetched ONCE and null-checked before anything chains
		# off it. The unguarded version of this (calling `.get_magic_beam()` twice more
		# and dereferencing straight into `.get_storage().capacity`) is the exact line a
		# reviewer proved turns "the beam failed to wire up" into a silent 240s hang
		# instead of a failed check: a null beam raises a GDScript runtime error mid-
		# function, which aborts this whole report -- including its own `quit()` -- with
		# nothing printed. GateWatchdogScript.arm() above is the backstop for THAT
		# failure mode generally; this null check is the actual fix for THIS call.
		var beam: Node3D = player.get_magic_beam()
		_set_check(checks, "the HUD found the magic beam", hud.get_beam() == beam)
		_set_check(checks, "the HUD is showing the beam's real capacity",
			beam != null and hud.get_capacity() == beam.get_storage().capacity
				and hud.get_capacity() > 0)

	# --- the clock and the sky ------------------------------------------------------
	# THE SKY IS THE ONE PART OF THE WORLD A SCREENSHOT CANNOT PROVE. A rendered frame of a
	# stormy night and a rendered frame of a rig that never got wired to the clock at all
	# both look like "the sky ranch.tscn was hand lit with, or something near it", and the
	# second one is a whole feature quietly not running. So the gate asks the rig what it is
	# WALKING TOWARD and compares it against what the clock says the hour and the weather
	# are, which is a number on both sides.
	_set_check(checks, "the world state exists", _world != null)
	# THE CLOCK THIS RUN WAS ACTUALLY ON, held before the reload probe below replaces it, so
	# that the `RANCH world` line at the end of this section reports the run rather than the
	# probe. It is the same object as _world until that probe runs.
	var run_clock: WorldState = _world
	var world_wired := _sky_rig_matches_state(_world)
	if not _interactive and _world != null:
		# THE RELOAD IS PERFORMED, NOT IMITATED. A load REPLACES what GameState holds and
		# ranch.gd builds a whole new WorldState out of it (see _rebuild_world_state, and
		# rebind_economy for the same problem in the economy). A rig still holding boot's
		# state passes the line above and is wrong the moment the player loads a save, and
		# nothing else in this project would catch it.
		#
		# ASKING A SCRATCH COPY WOULD BE ASKING NOTHING. A WorldState rebuilt from the same
		# seed and the same elapsed seconds is equal to the live one by construction, so
		# comparing the rig against it is the first check written twice: `x and x`, which
		# cannot fail and so measures nothing. What has to be exercised is the rebuild
		# ITSELF, and every part of it that a mid-session load depends on.
		#
		# SAFE HERE AND ONLY HERE. This branch is closed to interactive sessions, where the
		# clock is RUNNING and a rebuild would set it back to whatever GameState last
		# synced. Outside one, nothing has advanced the clock since boot, which is why the
		# probe can assert the rebuilt hour and weather are the ones it replaced: if they
		# ever differ, the rebuild is not reproducing the session and that is a failure.
		var before_state: WorldState = _world
		var before_phase: int = _world.phase()
		var before_weather: int = _world.weather()

		_rebuild_world_state()

		# Every clause is a way the reload path has actually been broken or could be. A
		# rebuild that returned the same object would mean the load never replaced anything;
		# a different hour would mean it is not reproducing this session; a second listener
		# on either signal is the two-clocks-one-sky bug _rebuild_world_state's disconnect
		# exists to stop, and a listener left on the OLD state is the same bug from the
		# other end; an unmatched rig would mean the rebuild forgot to re-aim the sky; and a
		# stale HUD line would mean it forgot the label.
		var reload_ok: bool = _world != before_state \
			and _world.phase() == before_phase \
			and _world.weather() == before_weather \
			and _world.phase_changed.get_connections().size() == 1 \
			and _world.weather_changed.get_connections().size() == 1 \
			and before_state.phase_changed.get_connections().size() == 0 \
			and before_state.weather_changed.get_connections().size() == 0 \
			and _sky_rig_matches_state(_world)
		if hud_scripted and hud.has_method("get_world_line"):
			reload_ok = reload_ok and hud.get_world_line() == _world.describe()
		world_wired = world_wired and reload_ok
	_set_check(checks, "the sky rig is wired to the state", world_wired)

	if _world != null and _world.is_pinned():
		# A PINNED RUN IS ONLY WORTH PINNING IF IT STAYS PUT. --phase=/--weather= exist so a
		# screenshot or a gate can have a stormy night on demand, and the promise attached
		# to them is that such a run never writes a moved clock into anybody's save. The
		# clock is asked to move a full minute here and must refuse.
		#
		# YES, THIS REPORT MOVES THE LIVE CLOCK, and so does the reload probe above; both on
		# purpose, and neither is incidental. Asking a pinned clock to advance IS the
		# assertion: a probe that only read is a probe that cannot tell "held" from "never
		# asked". What is guarded is the reverse, that a gate never leaves a MOVED clock
		# behind: this branch is entered only when the clock is pinned and refusing, the
		# `RANCH world` line prints run_clock rather than either result, and no
		# non-interactive run autosaves anything (see _interactive).
		var before: float = _world.elapsed()
		_world.advance(60.0)
		_set_check(checks, "a pinned run does not move the clock",
			absf(_world.elapsed() - before) < 0.0001)

	# THE HUD HALF OF THE SAME CLAIM, and nothing else in the project gates it. An unwired
	# world line is a blank line at the bottom of the Bag box, which looks exactly like a
	# HUD that simply has nothing to say; so "the ranch actually pushed the hour to it"
	# has to be asked rather than assumed, and asked of the LABEL, which is what
	# HUD.get_world_line() reads. NOT one of the three labels task 4's brief lists: it is
	# added because the task's other half is "the HUD says what hour it is" and a
	# requirement this gate only printed would be a requirement nothing checked.
	var hud_line := ""
	if hud_scripted and hud.has_method("get_world_line"):
		hud_line = hud.get_world_line()
	_set_check(checks, "the HUD is saying what hour it is",
		_world != null and hud_line == _world.describe())

	# PRINTED OFF run_clock, WHICH IS THE HOUR THE SESSION WAS ON. The reload probe above
	# replaced _world with an equal but different object, and the pinned check just asked
	# the live clock to move; this line is a report on the run, so it reads the clock the
	# run had. (The probe asserts the two agree on phase and weather, so a disagreement here
	# would already have failed a check rather than quietly printed the wrong hour.)
	if run_clock != null:
		print("RANCH world elapsed=%.1f phase=%s weather=%s pinned=%s"
			% [run_clock.elapsed(), WorldStateScript.phase_name(run_clock.phase()).to_upper(),
				WorldStateScript.weather_name(run_clock.weather()).to_upper(),
				run_clock.is_pinned()])
	else:
		print("RANCH world MISSING; no clock was built")

	# --- saving --------------------------------------------------------------------
	# THE CHECK THAT EARNS ITS PLACE IN THIS GATE. `user://` resolves somewhere completely
	# different on Windows than on Linux (docs/windows-testing.md), the directory does not
	# pre-exist, and the rename that publishes a save is implemented differently on the two
	# platforms. None of that is visible in a unit test on the developer's machine -- but
	# this gate is ALSO run by CI on real Windows and by tools/run_windows_build.sh under
	# Proton, and this check is what makes those runs answer "can this build actually write
	# and re-read a save on that platform, in that filesystem" rather than only "does the
	# scene graph build".
	_set_check(checks, "the GameState autoload is mounted", _game_state != null)
	var save_probe := _probe_save_round_trip()
	print("RANCH save user_dir=%s file=%s wrote=%s reloaded=%s loaded_at_boot=%s owned=%d restored=%d"
		% [OS.get_user_data_dir(), save_probe["path"], save_probe["wrote"],
			save_probe["reloaded"], _save_loaded,
			_game_state.pony_count() if _game_state != null else -1, _restored_ponies])
	_set_check(checks, "a save round-trips through the user:// filesystem", save_probe["ok"])

	# --- the camera ---------------------------------------------------------------
	_set_check(checks, "the camera probes the world, not just layer 1",
		_spring_arm.collision_mask == LayersScript.WORLD)
	var pull_in: Dictionary = await _probe_camera_against_building()
	if pull_in.get("ran", false):
		# `hit` is the spring arm's own bookkeeping; `actual` is where the lens really
		# ended up, measured off its transform, and `fade` is what CameraRig does about
		# it. All three, because the first two have already disagreed once on this rig
		# (see CameraRig's note on SpringArm3D.margin) and because a fade of 0.00 at
		# 0.55 m is the whole of the fix for the camera-inside-the-pony close-up --
		# worth a printed number rather than only a screenshot.
		#
		# `actual` is now the LENS -- shoulder offset and all -- while the fade is driven
		# by where the ARM left the mount (CameraRig.get_arm_distance()), so at a normal
		# distance the two are allowed to differ by the offset. At this pose they agree,
		# because the ramp has eased the offset to nothing by the time the arm is this
		# short.
		print("RANCH camera building=%s rest=%.2f hit=%.2f actual=%.2f pull_in=%.2f subject_opacity=%.2f"
			% [pull_in["building"], pull_in["rest"], pull_in["hit"], pull_in["actual"],
				pull_in["pull_in"], pull_in["opacity"]])
		_set_check(checks, "the player's body is faded out when the camera is inside her",
			pull_in["opacity"] <= 0.01)
		_set_check(checks, "the camera pulls in against a building",
			pull_in["pull_in"] >= MIN_CAMERA_PULL_IN)
	else:
		# The barn and farmhouse are hand-built in building.gd and exist on EVERY
		# checkout, assetless or not -- they are not gated on assets_state. So a probe
		# that comes back empty means _find_wall_stand_point()'s raycast found no wall
		# on a map that unquestionably has one: a real regression (wrong layer, wrong
		# mask, a building that failed to build, or -- the case a reviewer actually
		# caught -- a building's collider disabled outright), not an assetless
		# checkout with nothing to probe.
		#
		# This USED to branch on assets_state: a FAILED check when assets=present, but
		# only a `print` -- no _set_check() call at all, so the label never entered
		# `checks` -- when assets was absent or partial. That branch was reasoned to be
		# unreachable; it is not. It is exactly the path CI runs (assets are always
		# absent in CI -- see docs/ci.md section 4), so a reviewer disabling both
		# buildings' colliders sailed straight through: this whole check silently did
		# not exist for that run, `RANCH_OK ponies=0 props=2 assets=absent` printed,
		# exit 0. A missing dictionary entry is not visible in the "every check held"
		# loop below the way `false` is -- so a silent SKIP here is worse than a wrong
		# answer, it's a gate CI runs that cannot fail this way at all.
		#
		# An empty probe is now an unconditional FAILED check, in every assets_state,
		# with no SKIP path left to fall into.
		print("RANCH camera check FAILED -- no building found to probe (assets=%s)"
			% assets_state)
		_set_check(checks, "the camera pulls in against a building", false)

	# --- the player's own look (Task 8) -----------------------------------------
	var has_look: bool = _game_state != null and _game_state.player != null
	_set_check(checks, "the player has a look", has_look)
	_set_check(checks, "the creation screen is closed in an automated run",
		creation_screen == null or not creation_screen.call("is_open"))
	if has_look:
		print("RANCH player name=%s coat=%d mane=%d eyes=%d mark=%s" % [
			_player_name(), _game_state.player.coat, _game_state.player.mane,
			_game_state.player.eyes, _game_state.player.has_mark()])

	# --- verdict -------------------------------------------------------------------
	# A duplicate label is not a check that failed -- it is a check that never ran. It
	# fails the gate here, unconditionally, rather than only being logged by
	# _set_check() above, so it cannot start being broken without anyone noticing.
	if not _duplicate_check_labels.is_empty():
		push_error("ranch: %d check label(s) were assigned more than once: %s"
			% [_duplicate_check_labels.size(), ", ".join(_duplicate_check_labels)])

	var all_ok := _duplicate_check_labels.is_empty()
	for label in checks:
		if not checks[label]:
			push_error("ranch: FAILED check -- %s" % label)
			all_ok = false

	var summary := "ponies=%d props=%d assets=%s" % [ponies.size(), prop_count, assets_state]
	print("RANCH hosted=%s" % _hosted)
	print(("RANCH_OK " if all_ok else "RANCH_FAILED ") + summary)

	if _hosted:
		# Somebody else owns this process. Hand them the verdict and let them decide. See
		# _hosted for the shutdown race this avoids.
		gate_report_finished.emit(all_ok)
		return

	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if all_ok else 1)
		return

	if _screenshot_dir != "":
		await _capture_all()
		get_tree().quit(0 if all_ok else 1)
		return

	# Windowed, no screenshot directory: this is somebody playing the game. Leave it
	# running. (An exported build launched by CI passes --headless and quits above;
	# --quit-after bounds it either way.)


## PUT A PEN UP, PUT PONIES IN IT, AND WATCH WHETHER THEY STAY.
##
## THE CHECK THIS WHOLE TASK EXISTS TO PASS, and the one thing here no unit test can
## answer. game/test/test_pen.gd can prove the arithmetic -- that the leash stops short of
## the fence by more than a fleeing pony's measured 1.15 m of overshoot, that the fence
## clears her 2.138 m horn tip. It cannot prove that a real CharacterBody3D, on a real
## collision layer, running the real wander/flee state machine on real terrain, is still
## inside the paddock a second later. Every part of that sentence has been wrong in this
## project at least once: a layer mask that stopped matching, a leash measured from the
## wrong origin, a collider that was never generated.
##
## SO IT IS MEASURED TWICE, TWO DIFFERENT WAYS. Where she is (her capsule's footprint
## against the fence line) AND whether her body actually intersects the pen's colliders
## from the outside. The first catches a pony who walked out; the second catches a pony who
## is standing exactly in the fence, which reads as "inside" to a coordinate comparison and
## is a pony clipped through a rail.
##
## WHY IT RUNS AT BOOT IN EVERY MODE, INCLUDING A REAL PLAY SESSION. The alternative is
## running it only in gate runs, which means the check does not exist for the run the
## player actually makes -- and this codebase has already shipped a gate whose most
## important check silently did not run on the path CI takes (see the camera block below).
## It runs on slot 0 BEFORE _restore_plots(), so the slot is guaranteed empty whatever the
## save says, and it takes its pen down again afterwards. `_report()` is awaited inside
## `_ready()`, so this all happens before the player has had a frame in which to act.
##
## Returns {ran, inside, no_clip, worst_x, worst_z, half, roam, ponies}.
func _probe_pen_containment() -> Dictionary:
	var result := {"ran": false, "inside": false, "no_clip": false, "torn_down": false,
		"solid": false, "stressed": false, "travelled": 0.0,
		"worst_x": 0.0, "worst_z": 0.0, "half": PenScript.HALF_EXTENT,
		"roam": PenScript.roam_radius_for(PenScript.HALF_EXTENT), "ponies": 0}

	var slots := _plot_slots()
	if slots.is_empty():
		return result
	var slot: PlotSlot = slots[0]
	if not slot.is_empty():
		return result

	# The cheapest pen in the catalogue, so this probe is not silently gated on a plot type
	# somebody later prices out of reach.
	var plot: PlotData = null
	for candidate in _plots_catalogue().all():
		if candidate.capacity >= PEN_PROBE_PONIES:
			plot = candidate
			break
	if plot == null or not slot.build(plot):
		return result

	var pen := slot.get_built() as Pen
	if pen == null:
		return result

	# Real characters off the real roster, so the bodies that spawn are the bodies the game
	# spawns -- a probe pony built from a made-up data_id resolves to no PonyData, gets no
	# model, and would be contained by nothing.
	var registry: PonyRegistry = _game_state.get_registry() if _game_state != null else null
	var roster: Array[PonyData] = registry.by_zone(&"ranch") if registry != null \
		else [] as Array[PonyData]

	var probes: Array[PonyInstance] = []
	for i in range(PEN_PROBE_PONIES):
		var character: StringName = roster[i % roster.size()].id if not roster.is_empty() \
			else &"twilight"
		var inst: PonyInstance = PonyInstanceScript.create(character)
		if pen.add_pony(inst):
			probes.append(inst)

	result["ponies"] = probes.size()

	for i in range(PEN_PROBE_FRAMES):
		await get_tree().physics_frame

	# THE WORST CASE, SET UP RATHER THAN WAITED FOR -- see PEN_PROBE_FLEE_FRAMES. Each body
	# goes hard against the fence, spread around it, outside her own leash; then the player
	# is put down in the middle so the shy one bolts. Her position is restored below;
	# _report() has not yet run the camera probe, which moves her the same way for the same
	# kind of reason.
	var edge: float = PenScript.HALF_EXTENT - PenScript.PONY_BODY_RADIUS - PEN_PROBE_EDGE_GAP
	var started: Dictionary = {}
	for i in range(probes.size()):
		var body := pen.body_for(probes[i].uid) as CharacterBody3D
		if body == null:
			continue
		var angle: float = TAU * float(i) / float(maxi(1, probes.size()))
		var spot := Vector3(cos(angle) * edge, 0.35, sin(angle) * edge)
		body.global_position = pen.to_global(spot)
		started[probes[i].uid] = body.global_position

	# A STAND-IN, NOT THE PLAYER HIMSELF. This used to teleport the real player into the
	# middle of the pen and put him back sixty frames later. In a gate run nobody saw it; in
	# a real play session the owner did -- "it does a thing where it temporarily teleports me
	# to the paddock at the start, but it's only a second, a bit confusing" -- because
	# _report() is awaited inside _ready() and those frames still RENDER. The probe has to
	# keep running in every mode (see the block comment above: a check that skips the run the
	# player actually makes is the failure this codebase has already shipped once), so the
	# fix is to spook the ponies with something that is a player to a pony without being THE
	# player. Pony._is_player() accepts anything in PLAYER_GROUP, and Pony._player_is_sneaking()
	# asks through has_method() precisely so a stand-in with no gait can answer -- the file
	# says so: "PLAYER_GROUP exists precisely so a test stand-in (or a Phase 2 decoy) can be a
	# player to a pony without being a Player". Not answering counts as NOT sneaking, i.e. the
	# full notice radius, which is the harsher case and the one worth probing.
	#
	# It carries a real capsule on the real PLAYER layer, matching player.tscn's 0.42/1.3, so
	# the residents are shoved by a body exactly as they were before rather than merely
	# noticing a ghost.
	var decoy := CharacterBody3D.new()
	decoy.name = "PenProbeDecoy"
	decoy.collision_layer = LayersScript.PLAYER
	decoy.collision_mask = 0
	var decoy_shape := CollisionShape3D.new()
	var decoy_capsule := CapsuleShape3D.new()
	decoy_capsule.radius = 0.42
	decoy_capsule.height = 1.3
	decoy_shape.shape = decoy_capsule
	decoy.add_child(decoy_shape)
	decoy.add_to_group(PonyScript.PLAYER_GROUP)
	add_child(decoy)
	decoy.global_position = pen.to_global(Vector3(0.0, 0.4, 0.0))
	for i in range(PEN_PROBE_FLEE_FRAMES):
		await get_tree().physics_frame

	var inside := probes.size() > 0
	var travelled := 0.0
	var no_clip := true
	var worst_x := 0.0
	var worst_z := 0.0
	var space := get_world_3d().direct_space_state
	for inst in probes:
		var body := pen.body_for(inst.uid) as CharacterBody3D
		if body == null:
			inside = false
			continue
		# In the PEN's own frame, because the two back-row slots are rotated 180 degrees in
		# ranch.tscn (so their gates face open ground rather than the gap behind their
		# neighbour) and a world-space comparison would silently be measuring the wrong
		# axis for them.
		var local: Vector3 = pen.to_local(body.global_position)
		var edge_x: float = absf(local.x) + PenScript.PONY_BODY_RADIUS
		var edge_z: float = absf(local.z) + PenScript.PONY_BODY_RADIUS
		worst_x = maxf(worst_x, edge_x)
		worst_z = maxf(worst_z, edge_z)
		if edge_x > PenScript.HALF_EXTENT or edge_z > PenScript.HALF_EXTENT:
			inside = false
		if _body_overlaps(body, pen, space):
			no_clip = false
		if started.has(inst.uid):
			travelled = maxf(travelled,
				(body.global_position - (started[inst.uid] as Vector3)).length())
		print("RANCH pen probe %-22s local=(%6.2f, %6.2f) edge=(%.2f, %.2f) state=%s"
			% [body.name, local.x, local.z, edge_x, edge_z, body.state_name(body.state)])

	# The decoy goes before the pen does, so nothing outlives the probe. Freed rather than
	# hidden: a body left on the PLAYER layer would go on being noticed by every pony in the
	# world for the rest of the session.
	decoy.queue_free()
	result["solid"] = _fence_is_solid(pen, space)
	# Measured with the player back home, so her own body is nowhere near the gateway.
	var gateway: Dictionary = _probe_gateway(pen, space)
	result["gate_player"] = float(gateway.get("player", 0.0))
	result["gate_pony"] = float(gateway.get("pony", 1.0))
	# A REAL resident's mask, read off a body the pen actually spawned, rather than the
	# constant it was assigned from: this is the half of the claim that says the policy in
	# collision_layers.gd reached the ponies standing in the paddock.
	for inst in probes:
		var body := pen.body_for(inst.uid) as CharacterBody3D
		if body != null:
			result["pony_mask"] = body.collision_mask
			break
	result["travelled"] = travelled
	result["stressed"] = travelled >= PEN_PROBE_MIN_TRAVEL

	result["ran"] = true
	result["inside"] = inside
	result["no_clip"] = no_clip
	result["worst_x"] = worst_x
	result["worst_z"] = worst_z

	# Take it back down. remove_pony() frees each body and clears her production ledger
	# entry; freeing the pen returns the slot to the empty, buildable state the real save is
	# about to be restored onto.
	for inst in probes:
		pen.remove_pony(inst.uid)
	slot.demolish()
	# Reported rather than assumed. If the teardown ever stopped working, the very next
	# thing that happens is _restore_plots() trying to build the player's real pen onto a
	# slot that is still holding the probe's -- which the slot would correctly refuse, and
	# the player would come back to a ranch with a pen missing and nothing said about it.
	result["torn_down"] = slot.is_empty()
	return result


## IS THERE ACTUALLY A FENCE THERE, or only a leash?
##
## THIS CHECK EXISTS BECAUSE THE OTHER TWO PASSED WITHOUT IT. Deleting the pen's collider
## generation outright -- leaving four sides of decorative rails with nothing solid behind
## them -- left `inside` and `no_clip` both true and printed RANCH_OK: the leash alone kept
## the ponies in, and "no pony is standing inside the fence" is trivially satisfied by a
## fence that is not there. That is the vacuous-check shape this codebase has shipped
## before, caught here by trying it.
##
## So this asks the fence directly. From just inside each of the four sides, at three
## positions along it and at three heights spanning a pony capsule, fire a short ray
## outward: every one of them has to hit THIS PEN. A missing barrier, a barrier that does
## not reach the ground, a gap at a corner or a gateway with nothing across it all come back
## as a ray that went straight out into the field.
##
## The heights stop below GATE_LEAF_HEIGHT deliberately. The gateway is open ABOVE the gate
## leaf and is meant to be -- that is the 2.25 m of framed clear air a pony will walk
## through when gates open. What must be solid is the band a pony capsule occupies, and that
## is what is measured.
##
## FIRED WITH A PONY'S MASK, NOT WITH PROPS. Since the gate leaf became a gate it sits on its
## own layer (CollisionLayers.PEN_GATE) so that the player can walk out of a pen she built
## around herself; PONY_BARRIER is PROPS plus that bit, which is what the fence looks like to
## the animal it is there to hold. Asking this question with PROPS alone would report the
## gateway as a GAP in a fence that is, to a pony, completely solid -- a false red, and one
## that would tempt somebody into "fixing" it by putting the leaf back on PROPS and shutting
## the player in again.
func _fence_is_solid(pen: Pen, space: PhysicsDirectSpaceState3D) -> bool:
	var half: float = PenScript.HALF_EXTENT
	var solid := true
	for side in range(4):
		var outward := Vector3(cos(float(side) * PI * 0.5), 0.0, sin(float(side) * PI * 0.5))
		var along := Vector3(-outward.z, 0.0, outward.x)
		for offset in [-0.55, 0.0, 0.55]:
			for height in [0.25, 0.75, 1.25]:
				var from_local: Vector3 = along * (offset * half) \
					+ outward * (half - 1.0) + Vector3.UP * height
				var to_local: Vector3 = from_local + outward * 2.0
				var query := PhysicsRayQueryParameters3D.create(
					pen.to_global(from_local), pen.to_global(to_local),
					LayersScript.PONY_BARRIER)
				var hit := space.intersect_ray(query)
				if hit.is_empty() or not _is_pen_part(hit.get("collider"), pen):
					solid = false
					print(("RANCH pen fence GAP side=%d along=%+.2f height=%.2f -- a ray " +
						"fired outward from inside the pen did not hit its own fence")
						% [side, offset * half, height])
	return solid


## Is `collider` part of `pen` -- either the pen's own body or the separate one its gate leaf
## hangs its collider on?
##
## A PEN IS TWO BODIES NOW. The fence proper is the Pen StaticBody3D on PROPS; the gate leaf
## is its own StaticBody3D on PEN_GATE, which is what lets a pony be held by a gateway the
## player walks through (see game/world/pen.gd). Every check below that used to compare a hit
## against `pen` by identity would call the gateway a hole in the fence without this.
func _is_pen_part(collider: Variant, pen: Node) -> bool:
	if pen == null or collider == null:
		return false
	if collider == pen:
		return true
	var as_pen := pen as Pen
	return as_pen != null and as_pen.gate_body() != null and collider == as_pen.gate_body()


## CAN THE FARMER GET OUT, AND CAN THE LIVESTOCK NOT? Returns {player, pony}, each the
## fraction of the way out through the gateway that a capsule of that kind gets.
##
## THE OWNER'S PLAYTEST NOTE THIS ANSWERS: "i also trapped myself inside the pen and couldnt
## leave". Both halves are measured in the same place, through the same hole, with the same
## capsule -- the player's and a pony's are IDENTICAL (r = 0.42, h = 1.30; player.tscn and
## pony.tscn agree to the centimetre), which is precisely why the answer cannot come from
## geometry and has to come from layers. What differs between the two sweeps is only the
## mask, so a difference in the result IS the layer policy working.
##
## SWEPT, NOT TELEPORTED-AND-CHECKED. Putting a body down outside the fence and finding it
## outside proves nothing about whether it could have got there.
##
## The masks are the STATIC halves of each character's real mask -- PROPS for the player
## (everything solid she collides with that a pen is built from) and PONY_BARRIER for a pony
## (that plus the gate leaf's PEN_GATE). Characters are left out on purpose: the probe's own
## three ponies are standing against the fence at the time, one of them very possibly right
## in the gateway, and this question is about the fence and not about the traffic. That the
## PLAYER's real mask contains PROPS and does not contain PEN_GATE, and that a real penned
## pony's contains both, are asserted separately in _report() -- together those two facts and
## this measurement are the whole claim.
func _probe_gateway(pen: Pen, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_BODY_RADIUS
	capsule.height = 1.30
	var from: Vector3 = pen.to_global(Vector3(0.0, GATE_PROBE_CENTRE_Y, 0.0))
	var motion: Vector3 = pen.to_global(
		Vector3(GATE_PROBE_REACH, GATE_PROBE_CENTRE_Y, 0.0)) - from
	var result := {}
	for who: Array in [["player", LayersScript.PROPS], ["pony", LayersScript.PONY_BARRIER]]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, from)
		query.collision_mask = int(who[1])
		query.motion = motion
		# cast_motion returns [safe fraction, unsafe fraction]. The safe one is how far the
		# capsule gets before it touches anything: 1.0 is "walked all the way out".
		var travel: Array = space.cast_motion(query)
		var reached: float = float(travel[0]) if travel.size() > 0 else 0.0
		result[who[0]] = reached
		print("RANCH pen gateway %-6s mask=%2d reached=%.3f of %.2f m -> %.2f m from centre"
			% [who[0], int(who[1]), reached, GATE_PROBE_REACH, reached * GATE_PROBE_REACH])
	return result


## Whether `body`'s capsule is intersecting any of `owner_node`'s collision shapes right
## now. The independent, after-the-fact half of the containment probe -- see its comment.
## Built the same way _pony_overlaps_prop() below is, and deliberately not merged with it:
## that one asks about the PROPS layer generally, this one asks about ONE specific body's
## shapes, and a shared version would have to take so many parameters that neither call
## site would read.
func _body_overlaps(body: CharacterBody3D, owner_node: CollisionObject3D,
		space: PhysicsDirectSpaceState3D) -> bool:
	var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null or shape.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	# PONY_BARRIER rather than PROPS, and _is_pen_part rather than an identity test, for the
	# same reason _fence_is_solid() uses them: a pen's gate leaf is a second body on a second
	# layer, and a pony standing inside it is exactly as clipped as one standing inside a rail.
	query.collision_mask = LayersScript.PONY_BARRIER
	query.exclude = [body.get_rid()]
	query.margin = 0.0
	for hit in space.intersect_shape(query, 8):
		if _is_pen_part(hit.get("collider"), owner_node):
			return true
	return false


## SHUT THE ORCHARD GATE, WALK A RAY INTO IT, AND THEN BUY THE PERMIT ON PAPER.
##
## Two facts, measured on the real ring in the real world rather than in a unit test,
## because both of them have already been true of a fence that did not work: that a locked
## leaf is solid to a body carrying the PLAYER's own mask (WALKABLE, which deliberately
## excludes PEN_GATE), and that putting the permit in `unlocks` and re-applying is all it
## takes to open it. game/test/test_region_fence.gd can prove set_open() flips a layer; it
## cannot prove that the layer it flips is one the player's mask is looking at.
##
## IT PUTS EVERYTHING BACK. The gate is shut for the ray whether or not the loaded save had
## already bought it, and the "opened" check never edits `_game_state.unlocks` itself: it
## swaps in a duplicated array with the permit added, calls _apply_permits(), reads the
## fence, then swaps the ORIGINAL array back in and calls _apply_permits() again. The whole
## exchange is synchronous, no await between the swap and the restore, so nothing else
## (the Shop holds the original array by reference) ever observes the duplicate. A
## developer whose save owns the orchard does not lose it by running a gate.
##
## Returns {ran, solid, opened, hit}.
func _probe_region_gate() -> Dictionary:
	var result := {"ran": false, "solid": false, "opened": false, "hit": "<none>"}
	if _game_state == null:
		return result
	var fence: RegionFence = null
	for f in get_region_fences():
		if f.region() != null and f.region().id == &"orchard":
			fence = f
	if fence == null or fence.gate_body() == null:
		push_error("ranch: no orchard fence to probe")
		return result
	result["ran"] = true

	fence.set_open(false)
	# The layer written above is a physics server property, and the query below reads the
	# server. One step, so the write has landed before the ray is cast.
	await get_tree().physics_frame

	var region: RegionData = fence.region()
	var gate: Vector3 = fence.gate_position()
	var outward := Vector3(gate.x - region.centre.x, 0.0, gate.z - region.centre.y).normalized()
	var eye := gate + Vector3(0.0, GATE_PROBE_CENTRE_Y, 0.0)
	var query := PhysicsRayQueryParameters3D.create(eye + outward * GATE_RAY_REACH,
		eye - outward * GATE_RAY_REACH, LayersScript.WALKABLE)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if collider is Node:
		result["hit"] = (collider as Node).name
	result["solid"] = collider == fence.gate_body()

	var permit := String(region.permit_id())
	var had: bool = _game_state.unlocks.has(permit)
	var live: Array = _game_state.unlocks
	var scratch: Array = live.duplicate()
	if not had:
		scratch.append(permit)
	_game_state.unlocks = scratch
	_apply_permits()
	result["opened"] = fence.is_open()
	_game_state.unlocks = live
	_apply_permits()
	return result


## Is the sky rig actually walking toward the hour and the weather `state` says it is?
##
## TAKES THE CLOCK AS AN ARGUMENT rather than reading _world, because _report() asks it
## twice: once of the live clock, and once of a scratch clock built the way a reload would
## build one (see _build_world_state). Both are the same question and neither is entitled to
## replace the other.
##
## COMPARED ON THE PHASE-AND-WEATHER QUANTITIES ONLY, never on the sun's position. The
## sun's elevation and bearing are continuous functions of phase_progress(), so in a session
## where the clock is running they drift away from the target the last apply() set, every
## frame, by design; comparing them would make this check fail simply because time
## passed. Light energy, light colour, sky top and fog density are step functions of
## (phase, weather): they change only when the phase or the weather changes, which is
## exactly when apply() is called. So they agree if and only if the rig is wired.
func _sky_rig_matches_state(state: WorldState) -> bool:
	if state == null or sky_rig == null or not sky_rig.has_method("current_targets"):
		return false
	var targets: Dictionary = sky_rig.current_targets()
	if targets.is_empty():
		return false
	var phase: int = state.phase()
	var weather: int = state.weather()
	var energy: float = targets.get(SkyRigScript.KEY_LIGHT_ENERGY, -1.0)
	var fog: float = targets.get(SkyRigScript.KEY_FOG_DENSITY, -1.0)
	var light: Color = targets.get(SkyRigScript.KEY_LIGHT_COLOR, Color.BLACK)
	var top: Color = targets.get(SkyRigScript.KEY_SKY_TOP, Color.BLACK)
	return absf(energy - SkyRigScript.light_energy(phase, weather)) < 0.0001 \
		and absf(fog - SkyRigScript.fog_density(weather)) < 0.000001 \
		and light.is_equal_approx(SkyRigScript.light_color(phase, weather)) \
		and top.is_equal_approx(SkyRigScript.sky_top(phase, weather))


## Write a save into the gate's own scratch slot, read it back with a SECOND, independent
## GameState, and report whether every field came back.
##
## {ok, wrote, reloaded, path}. Never touches the slot the game plays in.
##
## A SEPARATE GameState ON EACH SIDE, not the autoload: reading back into the live state
## would overwrite whatever the player just loaded, and reading back into the SAME object
## that wrote it would pass even if the file on disk were empty -- the values would still
## be sitting in memory. Two objects and one file is what makes this measure the
## filesystem instead of measuring a dictionary.
##
## The probe pony is a real PonyInstance round-tripped through PonyInstance.to_dict(), so
## this exercises the actual serialisation path the player's ponies use, not a toy payload.
##
## THE POUCH AND THE PANTRY ARE IN HERE for the same reason the pony is. They are the two
## fields slice 1 added to the save, they are the two the format version was bumped for,
## and a probe that wrote every OTHER field would have gone on printing a green
## save_round_trip on a build that had quietly stopped writing either of them.
func _probe_save_round_trip() -> Dictionary:
	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(GATE_SAVE_SLOT))
	var result := {"ok": false, "wrote": false, "reloaded": false, "path": path}

	var writer: Node = GameStateScript.new()
	writer.bits = 1234
	writer.world_seed = spawner.spawn_seed
	writer.plots = {"0": "gate_probe"}
	# The clock rides in the save now too, and a probe that wrote every OTHER field would
	# go on printing a green save_round_trip on a build that had quietly stopped writing it.
	writer.world_time = 754.5
	writer.unlocks = ["gate_probe"]
	writer.gems.add(PonyDataScript.Rarity.RARE, 3)
	writer.inventory.add(&"hay", 5)
	writer.add_pony(PonyInstanceScript.from_dict({
		"uid": "gate_probe#000001", "data_id": "twilight",
		"nickname": "Probe", "happiness": 0.625, "hunger": 0.375, "caught_at_ms": 1772150400000,
	}))
	result["wrote"] = writer.save_to_slot(GATE_SAVE_SLOT)
	writer.free()

	var reader: Node = GameStateScript.new()
	result["reloaded"] = reader.load_from_slot(GATE_SAVE_SLOT)
	if result["reloaded"]:
		var ponies: Array = reader.get_ponies()
		result["ok"] = bool(result["wrote"]) \
			and reader.bits == 1234 \
			and reader.world_seed == spawner.spawn_seed \
			and absf(reader.world_time - 754.5) < 0.0001 \
			and String(reader.plots.get("0", "")) == "gate_probe" \
			and ponies.size() == 1 \
			and String(ponies[0].uid) == "gate_probe#000001" \
			and ponies[0].nickname == "Probe" \
			and absf(ponies[0].happiness - 0.625) < 0.0001 \
			and ponies[0].caught_at_ms == 1772150400000 \
			and reader.gems.count(PonyDataScript.Rarity.RARE) == 3 \
			and reader.inventory.count(&"hay") == 5
	reader.free()
	return result


## Everything solid the layout put on the map: the Kenney props and the two
## hand-built buildings. One list, so no check can quietly cover only half of them.
func _all_props() -> Array[Node3D]:
	var result: Array[Node3D] = []
	result.append_array(props.get_placed())
	for node: Node3D in buildings.get_children():
		result.append(node)
	return result


## Every StaticBody3D belonging to `prop`, INCLUDING the node itself when it is one.
## The Kenney props carry their colliders on generated StaticBody3D children; a
## Building IS the static body. Missing that distinction would make the layer check
## pass vacuously on exactly the objects the camera has to stop against.
func _bodies_of(prop: Node3D) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	if prop is StaticBody3D:
		result.append(prop)
	for body: StaticBody3D in prop.find_children("*", "StaticBody3D", true, false):
		result.append(body)
	return result


## True if `pony`'s own collision capsule, at its CURRENT global transform, overlaps
## ANY prop's collider (buildings included -- see _all_props()/_bodies_of()).
##
## This is checked BY SHAPE QUERY, not by distance to a marker or a prop's centre,
## for the same reason the ground placement itself is a raycast (see spawner.gd's
## class comment): the pony's actual capsule is what a player would see standing
## inside a wall, and nothing about her `home`/`zone` bookkeeping can tell you that.
## See the class comment above and the call site in _report() for why this check
## exists independently of the spawner's own prop-rejection reroll.
func _pony_overlaps_prop(pony: CharacterBody3D, space: PhysicsDirectSpaceState3D) -> bool:
	var shape_node := pony.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		# No shape to query with is itself a different, already-covered problem (a
		# pony whose body is malformed would fail other checks); do not fabricate an
		# overlap that was never measured.
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = LayersScript.PROPS
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_shape(query, 1).is_empty()


func _nearest_marker(point: Vector3) -> ZoneMarker:
	var best: ZoneMarker = null
	var best_d := INF
	for marker: ZoneMarker in spawner.get_markers():
		var d := Vector2(point.x - marker.global_position.x,
			point.z - marker.global_position.z).length()
		if d < best_d:
			best_d = d
			best = marker
	return best


# --- camera-vs-building -------------------------------------------------------------

## Stand the player right up against the biggest building with the building at her
## back, and measure how far the spring arm has to pull the camera in.
##
## THE STAND POINT IS FOUND BY RAYCAST, not taken from the building's AABB. The
## first version of this check used `aabb.max.x + 0.75` and measured a pull-in of
## exactly zero -- correctly, because a Kenney windmill's bounding box is defined by
## its sails, which stick out several metres past the tower and past nothing at all
## at camera height. A "camera hits the building" check that quietly stands the
## player next to thin air is worse than no check. So: cast a horizontal ray INTO the
## building at the exact height the camera will sit, and stand 0.75 m off whatever
## surface it actually finds (0.75 m clears the player's 0.42 m capsule radius).
## Buildings are tried tallest-first until one presents a wall.
##
## The rig is then yawed to -90 degrees, which points the arm's +Z -- the direction
## it casts, and the direction the camera sits from the pivot -- along world -X,
## straight into that surface. Pitch is levelled to zero first, so the arm probes
## horizontally into the wall rather than diagonally over the roof.
func _probe_camera_against_building() -> Dictionary:
	var found := _find_wall_stand_point()
	if found.is_empty():
		return {"ran": false}
	var building: Node3D = found["building"]
	var stand: Vector3 = found["stand"]

	var saved_pos: Vector3 = player.global_position
	var saved_yaw: float = _rig.rotation.y
	var saved_pitch: float = _rig.get_look_pitch_degrees()

	player.global_position = stand
	player.velocity = Vector3.ZERO
	_rig.rotation.y = -PI * 0.5
	_rig.add_look_delta(0.0, deg_to_rad(saved_pitch))

	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame

	var rest: float = _spring_arm.spring_length
	var hit: float = _spring_arm.get_hit_length()

	var result := {
		"ran": true,
		"building": building.name,
		"rest": rest,
		"hit": hit,
		"actual": _rig.get_camera_distance(),
		"opacity": _rig.get_subject_opacity(),
		"pull_in": rest - hit,
		"stand": stand,
	}

	player.global_position = saved_pos
	player.velocity = Vector3.ZERO
	_rig.rotation.y = saved_yaw
	_rig.add_look_delta(0.0, deg_to_rad(_rig.get_look_pitch_degrees() - saved_pitch))
	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame
	return result


## Buildings (never trees -- a canopy is a bad camera obstacle to prove anything
## with; the arm could be stopping on a leaf a player would happily walk under),
## tallest first.
func _buildings_by_height() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for prop: Node3D in _all_props():
		if not prop.name.begins_with("kenney_tree"):
			result.append(prop)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return PropsScript.world_aabb(a).size.y > PropsScript.world_aabb(b).size.y)
	return result


## The tallest building, for framing shots. Not used for the collision probe -- see
## _find_wall_stand_point() for why an AABB is the wrong thing to stand against.
func _tallest_building() -> Node3D:
	var buildings := _buildings_by_height()
	return buildings[0] if not buildings.is_empty() else null


## {building, stand} for the first building that presents an actual wall to a
## horizontal ray at camera height, or {} if none does. See
## _probe_camera_against_building() for why this is a raycast and not arithmetic.
func _find_wall_stand_point() -> Dictionary:
	var space := get_world_3d().direct_space_state
	for building: Node3D in _buildings_by_height():
		var box: AABB = PropsScript.world_aabb(building)
		var centre := box.get_center()
		var y: float = terrain.height_at(centre.x, centre.z) + 1.45
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(box.position.x + box.size.x + 8.0, y, centre.z),
			Vector3(centre.x, y, centre.z),
			LayersScript.PROPS)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var wall: Vector3 = hit["position"]
		var stand := Vector3(wall.x + 0.75, 0.0, wall.z)
		stand.y = terrain.height_at(stand.x, stand.z) + 0.15
		return {"building": building, "stand": stand}
	return {}


# --- offscreen capture ---------------------------------------------------------------

func _capture_all() -> void:
	# 01 -- does this read as a place at all?
	capture_camera.global_position = Vector3(33.0, 18.0, 36.0)
	capture_camera.look_at(Vector3(-1.0, 2.0, -7.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("01_establishing")

	# 02 -- what the owner actually sees the instant the game boots.
	_rig.get_camera().make_current()
	await _capture("02_player_eye_at_spawn")

	# 03 -- a spawn zone with ponies in it, framed from the herd's own centre of mass
	# so the shot is about the ponies and not about wherever a fixed camera pointed.
	var ponies: Array[CharacterBody3D] = spawner.get_spawned()
	if not ponies.is_empty():
		var centre := Vector3.ZERO
		var markers: Array = spawner.get_markers()
		var zone: ZoneMarker = markers[0] if not markers.is_empty() else null
		var n := 0
		for pony in ponies:
			if zone == null or _nearest_marker(pony.get_home()) == zone:
				centre += pony.global_position
				n += 1
		if n > 0:
			centre /= float(n)
			capture_camera.global_position = centre + Vector3(7.0, 3.2, 9.0)
			capture_camera.look_at(centre + Vector3(0.0, 0.9, 0.0), Vector3.UP)
			capture_camera.make_current()
			await _capture("03_spawn_zone_ponies")

	# 04 -- the spring arm pressed against a real building.
	var pull_in: Dictionary = await _probe_camera_against_building()
	if pull_in.get("ran", false):
		# Re-enter the pose (the probe restores it), hold it for the shot.
		player.global_position = pull_in["stand"]
		_rig.rotation.y = -PI * 0.5
		_rig.add_look_delta(0.0, deg_to_rad(_rig.get_look_pitch_degrees()))
		for i in range(CAMERA_SETTLE_FRAMES):
			await get_tree().physics_frame
		_rig.get_camera().make_current()
		await _capture("04a_camera_pressed_to_wall")

		# ...and again from 1.2 m further out. Both shots are worth keeping: 04a is
		# the strict pose the check measures -- the arm at 0.55 m, well inside the pony
		# -- and it is now the picture of CameraRig's subject fade doing its job (she
		# is gone and the world is visible). Until Phase 1A Task 9 the same shot was an
		# unreadable macro close-up of her flank, which is what the fade was written to
		# fix; SpringArm3D's pull-in is NOT bounded by CameraRig.SPRING_MIN and will
		# happily put the camera inside her. 04b is the same wall from a playable
		# distance, where she is fully drawn and the arm is visibly shortened.
		var back_off: Vector3 = pull_in["stand"] + Vector3(1.2, 0.0, 0.0)
		back_off.y = terrain.height_at(back_off.x, back_off.z) + 0.15
		player.global_position = back_off
		for i in range(CAMERA_SETTLE_FRAMES):
			await get_tree().physics_frame
		print("RANCH camera(backed off 1.2 m) rest=%.2f hit=%.2f"
			% [_spring_arm.spring_length, _spring_arm.get_hit_length()])
		await _capture("04b_camera_near_wall")

		player.global_position = player_spawn.global_position
		_rig.rotation.y = 0.0

	await _capture_the_mechanic()

	# 05 -- eye level in the yard, for judging prop scale against a 1.16 m pony.
	var barn := _tallest_building()
	if barn != null:
		var box: AABB = PropsScript.world_aabb(barn)
		var target := box.get_center()
		var eye := target + Vector3(9.0, 0.0, 11.0)
		eye.y = terrain.height_at(eye.x, eye.z) + 1.45
		capture_camera.global_position = eye
		capture_camera.look_at(Vector3(target.x, box.position.y + box.size.y * 0.45, target.z),
			Vector3.UP)
		capture_camera.make_current()
		await _capture("05_scale_at_the_barn")

	await _capture_plots()


## 06 to 09: the plot loop, photographed by DRIVING IT rather than by staging it.
##
## Every step below goes through the same call the player's button press goes through --
## BuildMenu.open(), BuildMenu.confirm(), and the saddlebag-to-pen move that
## _move_pony_into_pen() performs -- so what these four pictures show is the real path and
## not a pen assembled for the camera. If the build menu stops opening, or a pen stops
## being buildable, or Storage.release() stops handing a pony over, these shots come out
## wrong (or do not come out) rather than coming out fine because a fixture built the pen
## directly.
##
## Screenshot runs only, which is why it is safe for it to leave a pen standing: those runs
## have autosave off (see _interactive) and quit immediately afterwards.
func _capture_plots() -> void:
	var slots := _plot_slots()
	if slots.is_empty():
		print("RANCH capture: no plot slots to photograph")
		return
	var slot: PlotSlot = slots[0]
	var at: Vector3 = slot.global_position

	# 06 -- an empty plot: four corner stakes and nothing else. This is what the player is
	# looking at when the build prompt appears, and the thing this shot is asked to answer
	# is whether an empty plot reads as "something goes here" at all.
	capture_camera.global_position = at + Vector3(7.5, 4.6, 7.5)
	capture_camera.look_at(at + Vector3(0.0, 0.4, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("06_empty_plot_slot")

	var menu = build_menu
	if menu == null or not menu.has_method("open"):
		return

	# 07 -- the build menu over that same view.
	if menu.open(slot):
		await _capture("07_build_menu")
		# ...and the same button the player presses. pen_small costs nothing and sorts
		# first, so the default selection is affordable from a cold start.
		if not menu.confirm():
			print("RANCH capture: the build menu refused to build the default plot")
			menu.close()
	else:
		print("RANCH capture: the build menu would not open on an empty slot")

	# 08 -- the finished pen, empty. Rails, gate and posts against a 1.16 m-at-the-withers
	# world: this is the shot that answers "does the fence read at the right scale".
	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame
	capture_camera.global_position = at + Vector3(9.0, 5.4, 9.0)
	capture_camera.look_at(at + Vector3(0.0, 1.1, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("08_pen_built")

	# 09 -- the same pen with ponies in it, at a pony's own eye height. Ponies are put in
	# THROUGH THE SADDLEBAG, using _move_pony_into_pen(), which is Storage.release()'s
	# production caller on the pen side.
	var pen := slot.get_built() as Pen
	var beam: Node3D = player.get_magic_beam()
	if pen != null and beam != null:
		var registry: PonyRegistry = _game_state.get_registry() if _game_state != null \
			else null
		var roster: Array[PonyData] = registry.by_zone(&"ranch") if registry != null \
			else [] as Array[PonyData]
		var storage: Storage = beam.get_storage()
		var wanted: int = mini(pen.capacity, maxi(1, roster.size()))
		for i in range(wanted):
			var character: StringName = roster[i % roster.size()].id if not roster.is_empty() \
				else &"twilight"
			if storage.store(PonyInstanceScript.create(character)):
				_move_pony_into_pen(slot)
		for i in range(SETTLE_FRAMES):
			await get_tree().physics_frame
		print("RANCH capture: pen '%s' holds %d/%d"
			% [String(slot.slot_id), pen.count(), pen.capacity])

	capture_camera.global_position = at + Vector3(6.6, 1.75, 6.6)
	capture_camera.look_at(at + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("09_pen_with_ponies")

	# 09b -- straight down the fence line from outside, level with a pony. The scale shot:
	# a 1.163 m withers and a 2.138 m horn tip against a 2.25 m fence, in one frame.
	var side := at + Vector3(PenScript.HALF_EXTENT + 2.6, 0.0, 0.0)
	side.y = terrain.height_at(side.x, side.z) + 1.15
	capture_camera.global_position = side
	capture_camera.look_at(at + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	capture_camera.make_current()
	await _capture("09b_pen_scale_at_the_fence")


## THE SHOTS THE PLAYTEST ASKED FOR: the core loop, through the player's own camera, with
## the real HUD over it. Everything above this point photographs the PLACE; nothing in the
## project photographed the MECHANIC in the place, and every one of the owner's five
## complaints was about how the mechanic feels rather than about how the ranch looks.
##
## Screenshot-pass only (this whole function is downstream of the headless quit), and
## deliberately so: it moves the player about and takes a pony out of the world, which is
## exactly what a gate must not do to the state its own checks were computed from. Every
## check in _report() has already run and printed by the time this is reached.
##
## Numbers are printed beside each shot for the same reason wild_ponies.gd prints them:
## a picture of a beam and a printed hold time that disagree is the paper-correct-but-
## visually-wrong bug the whole capture pass exists to catch.
func _capture_the_mechanic() -> void:
	var beam: Node3D = player.get_magic_beam()
	if beam == null:
		return

	# 06 -- a SHY pony noticing the player from beyond the beam's reach, and bolting. The
	# whole of the headline fix, in one frame: he is not close enough to take her, and she
	# is already leaving.
	var shy := _find_pony_by_personality(PonyDataScript.Personality.SHY)
	if shy != null:
		# ...and 06a first: the SAME pony, the SAME distance, with the player creeping.
		# The second playtest's sneak in one comparison -- two frames that differ only in
		# whether Shift is held, one of which has a pony running out of it and one of which
		# has a pony still grazing. Nothing else in the project photographs a NON-event, and
		# "she did not notice me" is exactly the sort of claim a number can assert and only a
		# picture can make believable.
		var sneak_reach: float = beam.reach()
		var sneak_notice: float = PonyScript.notice_radius_for(
			PonyDataScript.Personality.SHY, false)
		Input.action_press(PlayerScript.SNEAK_ACTION)
		await _stand_player_near(shy, (sneak_reach + sneak_notice) * 0.5)
		await _aim_rig_at(shy.global_position + Vector3(0.0, 0.65, 0.0))
		for i in range(18):
			await get_tree().physics_frame
		await _aim_rig_at(shy.global_position + Vector3(0.0, 0.65, 0.0))
		print("RANCH mechanic sneak pony=%s state=%s gap=%.2f sneaking=%s notice_running=%.2f notice_sneaking=%.2f speed=%.2f"
			% [shy.name, PonyScript.state_name(shy.state),
				_ground_gap(player.global_position, shy.global_position),
				player.is_sneaking(), sneak_notice,
				PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, true),
				shy.get_ground_speed()])
		_rig.get_camera().make_current()
		await _capture("06a_she_has_not_noticed_you_creeping")
		Input.action_release(PlayerScript.SNEAK_ACTION)
		for i in range(4):
			await get_tree().physics_frame

		var reach: float = beam.reach()
		# Stood at the midpoint of the warning band -- outside REACH, inside HER notice
		# radius, which since the second playtest is a SHY pony's own wider one (14 m) and
		# not the shared base. The player is not sneaking here, which is the whole point of
		# the shot: this is what a pony does when you come at her at a run.
		var notice: float = PonyScript.notice_radius_for(
			PonyDataScript.Personality.SHY, false)
		var stand_off: float = (reach + notice) * 0.5
		await _stand_player_near(shy, stand_off)
		await _aim_rig_at(shy.global_position + Vector3(0.0, 0.65, 0.0))
		for i in range(18):
			await get_tree().physics_frame
		# Re-aimed after the wait: she has been running the whole time, and a shot of the
		# grass she left is not a shot of a pony fleeing.
		await _aim_rig_at(shy.global_position + Vector3(0.0, 0.65, 0.0))
		var gap: float = _ground_gap(player.global_position, shy.global_position)
		print("RANCH mechanic flee pony=%s state=%s gap=%.2f reach=%.2f detection=%.2f speed=%.2f"
			% [shy.name, PonyScript.state_name(shy.state), gap, reach,
				notice, shy.get_ground_speed()])
		_rig.get_camera().make_current()
		await _capture("06_she_bolts_before_you_are_in_range")

	# The beam shots want a pony who holds still while she is photographed, which on this
	# roster means a BOLD one -- she has no reaction to the player at all, so the framing
	# is not racing her state machine. Falls back to whoever is left.
	var target := _find_pony_by_personality(PonyDataScript.Personality.BOLD)
	if target == null:
		var live: Array[CharacterBody3D] = spawner.get_spawned()
		target = live[0] if not live.is_empty() else null
	if target == null:
		return

	# A BOLD pony is graded HARD, and a HARD hold can be TORN OUT OF before it secures her
	# (magic_beam.gd's WRENCH_CHANCE_HARD) -- which would leave the shots below photographing
	# an empty beam roughly half the time. So she is handed to the beam already past
	# WRENCH_GRACE_HOLDS grabs, which by the published rule means her wrench chance is
	# exactly zero.
	#
	# SAID OUT LOUD RATHER THAN SWITCHED OFF, exactly as this file's mechanic pass already
	# does for a pony's own detection: this is the real rule being used, not a test-only
	# bypass, so a build where the falloff stopped reaching zero would make these shots
	# flaky here instead of quietly passing. The wrench has its own home -- it is driven,
	# and its convergence proved, in scenes/test/capture_test.gd's WRENCH phase.
	target.beam_holds = beam.WRENCH_GRACE_HOLDS

	# 07 -- the beam sweeping empty ground at full stretch: the arc, and the ring lying on
	# the grass under where it runs out. This is the shot for "hard to gauge distance of
	# beam" -- the ring is on a surface the eye is already reading perspective off, and it
	# is drawn even when the beam has hit nothing, so sweeping for range is something the
	# player can DO rather than guess at. Aimed 15 degrees off the pony so nothing gets
	# grabbed and the beam stays empty.
	await _stand_player_near(target, beam.reach() - 0.6)
	var aside := (target.global_position - player.global_position).rotated(Vector3.UP, deg_to_rad(28.0))
	await _aim_rig_at(player.global_position + aside + Vector3(0.0, 0.4, 0.0))
	beam.grab()
	for i in range(8):
		await get_tree().physics_frame
	print("RANCH mechanic sweep holding=%s has_target=%s has_mark=%s mark=(%.1f, %.2f, %.1f) gap=%.2f"
		% [beam.is_holding(), beam.has_target(), beam.has_mark(),
			beam.get_mark_point().x, beam.get_mark_point().y, beam.get_mark_point().z,
			_ground_gap(player.global_position, beam.get_mark_point())])
	_rig.get_camera().make_current()
	await _capture("07a_beam_landing_ring_at_range")
	beam.release()
	for i in range(int(beam.ESCAPE_COOLDOWN * 60.0) + 4):
		await get_tree().physics_frame

	# 07b -- the same distance, aimed AT her, beam off: the reticle alone says she is in
	# range, before the button is pressed.
	await _aim_rig_at(target.global_position + Vector3(0.0, 0.65, 0.0))
	print("RANCH mechanic in_range pony=%s gap=%.2f has_target=%s (beam still OFF)"
		% [target.name, _ground_gap(player.global_position, target.global_position),
			beam.has_target()])
	_rig.get_camera().make_current()
	await _capture("07b_in_range_before_pressing")

	# 07c -- the fumbled catch, and the one state in which the LOCKED landing ring is
	# visible at all. Aiming the beam at a pony in range takes her on the same frame, so
	# "beam on, target in range, nothing held" only exists during the post-slip cooldown --
	# which is exactly the moment the player is re-lining up a catch they just dropped, and
	# so exactly the moment the ring is worth having. Also gets the toast that teaches the
	# mistake ("she slipped out") into a frame.
	beam.grab()
	for i in range(3):
		await get_tree().physics_frame
	beam.release()
	for i in range(10):
		await get_tree().physics_frame
	await _aim_rig_at(target.global_position + Vector3(0.0, 0.65, 0.0))
	beam.grab()
	for i in range(4):
		await get_tree().physics_frame
	print("RANCH mechanic cooling loss=%s holding=%s has_target=%s has_mark=%s"
		% [beam.get_last_loss(), beam.is_holding(), beam.has_target(), beam.has_mark()])
	await _capture("07c_locked_on_during_the_cooldown")
	beam.release()
	for i in range(int(beam.ESCAPE_COOLDOWN * 60.0) + 6):
		await get_tree().physics_frame
	await _aim_rig_at(target.global_position + Vector3(0.0, 0.65, 0.0))

	beam.grab()
	for i in range(6):
		await get_tree().physics_frame
	print("RANCH mechanic beam holding=%s secure_progress=%.2f mark=%s"
		% [beam.is_holding(), beam.get_secure_progress(), beam.has_mark()])
	await _capture("08_beam_reaching")

	# 09 -- mid-hold: the OUTER GREEN catch ring part-filled and the INNER RED wriggle ring
	# part-drained. (Which ring means what was swapped at the owner's direction after the
	# third playtest -- see the ring note at the top of game/ui/hud.gd.) Waited to a
	# FRACTION of the secure time rather than a fixed frame count, so this stays the
	# mid-hold shot whatever the subdue time is retuned to, and whatever this attempt's
	# jitter rolled it at.
	while beam.is_holding() and beam.get_secure_progress() < 0.55:
		await get_tree().physics_frame
	print("RANCH mechanic struggle hold=%.2fs secure=%.2fs struggle=%.2fs progress=%.2f secured=%s"
		% [beam.get_hold_seconds(), beam.get_secure_seconds(), beam.get_struggle_seconds(),
			beam.get_secure_progress(), beam.is_secured()])
	await _capture("09_catch_ring_half_filled")

	# 10 -- secured: let go NOW.
	while beam.is_holding() and not beam.is_secured():
		await get_tree().physics_frame
	print("RANCH mechanic secured hold=%.2fs secured=%s" % [
		beam.get_hold_seconds(), beam.is_secured()])
	await _capture("10_secured_let_go_now")

	beam.release()
	for i in range(4):
		await get_tree().physics_frame
	await _capture("11_caught_her")

	player.global_position = player_spawn.global_position
	player.velocity = Vector3.ZERO

	# 12 -- the whole map from above, for the complaint a close-up cannot answer: "ponies
	# were only around the perimeter". A herd is a handful of pixels from up here, so the
	# picture is read alongside the per-pony `RANCH pony ... home=(x, y, z)` table printed
	# by _report() -- the shot is for judging whether the SPREAD looks like a place with
	# animals living all over it, and the table is for knowing exactly where they are.
	var wide := $CaptureCamera as Camera3D
	wide.global_position = Vector3(6.0, 64.0, 80.0)
	wide.look_at(Vector3(-2.0, 0.0, -8.0), Vector3.UP)
	wide.make_current()
	# The HUD is hidden for this one shot and put back afterwards. It is drawn for the
	# player, at the player's eye, and over a map shot the hints card covers a whole
	# quadrant of the thing the picture is of.
	var hud := $HUD as CanvasLayer
	var hud_was_visible: bool = hud.visible
	hud.visible = false
	await _capture("12_spawn_spread")
	hud.visible = hud_was_visible


## Stand the player `distance` metres from `pony` on the ground, on the side she is
## currently facing away from, and level the rig at her. Used only by the screenshot pass.
func _stand_player_near(pony: Node3D, distance: float) -> void:
	var away := player.global_position - pony.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	var stand: Vector3 = pony.global_position + away.normalized() * distance
	stand.y = terrain.height_at(stand.x, stand.z) + 0.15
	player.global_position = stand
	player.velocity = Vector3.ZERO
	for i in range(CAMERA_SETTLE_FRAMES):
		await get_tree().physics_frame


## Drive the camera rig until get_aim_ray() points at `target`. The same iterative
## correction scenes/test/capture_test.gd uses, and iterative for the same reason: the
## camera hangs off a spring arm, so changing the pitch moves the eye the ray starts from.
func _aim_rig_at(target: Vector3) -> void:
	for i in range(12):
		var ray = _rig.get_aim_ray()
		var want: Vector3 = (target - ray.origin).normalized()
		var have: Vector3 = ray.direction
		var yaw_error := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		var pitch_error := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
		_rig.add_look_delta(-yaw_error, -pitch_error)
		await get_tree().physics_frame


func _find_pony_by_personality(personality: int) -> CharacterBody3D:
	for pony: CharacterBody3D in spawner.get_spawned():
		var data: PonyData = pony.get_data()
		if data != null and data.personality == personality:
			return pony
	return null


func _ground_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _capture(shot_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir.path_join("%s.png" % shot_name)
	image.save_png(path)
	print("SCREENSHOT_SAVED %s" % path)
