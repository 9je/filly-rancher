class_name PlotData
extends Resource
## Static description of one thing you can BUILD on the ranch: what it is called, what it
## costs, and which scene to instantiate for it. One .tres per plot type under
## game/data/plots/ -- adding a buildable is authoring a new data file, never writing new
## code, mirroring the PonyData / game/data/ponies/ and FoodData / game/data/foods/ pattern
## (game/systems/pony_data.gd, game/systems/food_data.gd).
##
## THE POINT OF `scene_path` BEING DATA. A small pen and a grand pen are the same
## game/world/pen.tscn with a different `capacity` in a .tres. When Task 4's garden and
## Task 6's market stall arrive they are new .tres files pointing at new scenes, and
## game/world/plot_slot.gd -- the thing that actually builds them -- does not change at
## all. That is the project's "adding content is authoring data" rule applied to buildings
## rather than to characters, and it is why the slot loads the scene by path and configures
## it through a duck-typed configure() rather than knowing what a Pen is.
##
## Deliberately thin, like FoodData: this carries what identifies a plot and what the build
## menu (game/ui/build_menu.gd) has to draw. It carries no behaviour -- how a pen holds
## ponies is pen.gd's business, and how a purchase is paid for is economy.gd's.

## Unique lookup key, e.g. &"pen_small". Matches the PlotRegistry dictionary key and the
## value stored in GameState.plots (slot id -> plot id) that a save reloads from.
@export var id: StringName = &""

## What the build menu calls it. Never the id -- "pen_small" is a database key, "Paddock"
## is a thing a player recognises.
@export var display_name: String = ""

## Bits to build one. Zero is legal and at least one plot MUST be zero -- see
## test_at_least_one_plot_is_free_so_a_cold_start_is_not_deadlocked: bits come from selling
## gems, gems come from penned ponies, ponies need a pen, so a catalogue where everything
## costs something is an economy a new save can never enter.
@export var cost: int = 0

## The scene instantiated into the slot when this is built. See the class comment.
@export var scene_path: String = ""

## One line for the build menu, under the name. Written for a player deciding between two
## rows, not as documentation.
@export_multiline var description: String = ""

## How many ponies the built thing holds, for the plot types that hold ponies; 0 for the
## ones that do not (a garden, a market stall). Read by game/world/plot_slot.gd and pushed
## into the built scene's configure().
##
## NOT IN THE PLAN'S FIELD LIST, and added deliberately. Without it the three pen tiers
## below would be three .tres files pointing at three near-identical .gd files, or one
## pen.gd with a hard-coded size and no tiers at all -- either way "a bigger pen" would be
## a code change, which is the exact thing the data-driven rule above exists to prevent.
@export var capacity: int = 0


func _to_string() -> String:
	return "PlotData(%s, cost=%d, capacity=%d)" % [String(id), cost, capacity]
