class_name PlotSlot
extends Area3D
## A BUILDABLE SQUARE OF GROUND. Walk into it, press interact, choose what goes here.
##
## Four of these sit in the ranch's reserved clearing (game/world/props.gd's PEN_PLOTS_*,
## a patch of map that has been kept deliberately empty since Phase 1A for exactly this).
## An empty slot is a marked-out plot with corner stakes; a built one holds whatever its
## PlotData named.
##
## --- IT BUILDS ONCE ------------------------------------------------------------------
##
## The single rule this file exists to enforce. "Build" is triggered by standing somewhere
## and pressing a button, which players do twice by accident constantly -- a double tap, a
## held button, a menu that did not close on the first frame. A slot that built twice would
## leave two pens interpenetrating in the same square metre, each with its own roster and
## one of them unreachable, and would charge for both. build() therefore refuses on an
## occupied slot BEFORE it instantiates anything, and game/test/test_plot_slot.gd asserts
## the refusal against the child count as well as against the return value -- because a
## version that returned false after instantiating would look correct from the outside and
## be precisely the bug described.
##
## --- IT DOES NOT KNOW WHAT A PEN IS ------------------------------------------------------
##
## build() loads `plot.scene_path`, instantiates it, and -- if the result has a configure()
## method -- hands it the PlotData and this slot's id. That is duck typing on purpose: when
## Task 4's garden and Task 6's market stall arrive they are new .tres files pointing at new
## scenes, and this file does not change. Adding a buildable is authoring data, which is the
## same rule game/systems/pony_data.gd holds for characters.
##
## --- WHAT IS SAVED -----------------------------------------------------------------------
##
## Nothing, by this file. `GameState.plots` is a {slot id -> plot id} Dictionary of Strings
## (JSON has no integer keys, which is why both halves are Strings -- see game_state.gd),
## written by game/world/ranch.gd from the live slots before every save and replayed back
## through build() on load. The slot is the thing that knows its own state; the state is
## copied out of it, not kept in two places.

const LayersScript := preload("res://world/collision_layers.gd")
const PlotDataScript := preload("res://systems/plot_data.gd")

## How far past a built pen's fence line the trigger volume reaches, in metres. See
## TRIGGER_HALF below for the two constraints that fix this number.
const TRIGGER_MARGIN := 0.45

## Half-extent of the trigger box on XZ: the pen's 3.9 m plus the margin, 4.35 m.
##
## THE TWO CONSTRAINTS THIS NUMBER IS SQUEEZED BETWEEN, both asserted by game/world/ranch.gd.
## Upper bound: a slot centre sits 4.5 m from the edge of the reserved clearing
## (PropsScript.PEN_PLOTS_*), so anything past 4.5 puts a corner of the trigger outside the
## ground that was set aside for it. Also 4.5, from the other side: the slots are on a 9 m
## grid, and 2 x 4.5 is where neighbouring triggers would start to overlap. 4.35 clears both
## with 0.15 m to spare.
##
## Lower bound: a player pressed against a built pen's gate has her centre 4.40 m out (3.90
## fence + 0.08 half the rail + 0.42 her capsule radius) -- FURTHER than the trigger's own
## half-extent. That is fine and is why this is a box-versus-capsule overlap and not a
## distance comparison: her 0.42 m radius reaches in, and she stays inside the trigger until
## her centre is 4.77 m out, nearly a metre clear of the fence.
const TRIGGER_HALF := 3.9 + TRIGGER_MARGIN

## Height of the trigger box. Tall enough that a player mid-jump is still inside it.
const TRIGGER_HEIGHT := 4.0

## What an EMPTY slot looks like: four corner stakes and a marked-out boundary between
## them, matching the footprint the pen will occupy.
##
## THE BOUNDARY BOARDS EXIST BECAUSE OF A RENDER. The first version of this was corner
## stakes alone, and an offscreen capture of the clearing showed the result plainly: sixteen
## 0.95 m sticks scattered across an open field, reading as debris rather than as four
## marked-out plots -- from the establishing camera they were barely visible at all, and at
## ground level they looked like something had been knocked over. A closed pale line on the
## ground is what makes a square of grass legible as "something goes here", and it doubles
## as a preview: it is drawn on exactly the footprint the fence will land on.
const STAKE_SIZE := 0.18
const STAKE_HEIGHT := 1.05
const STAKE_COLOR := Color(0.541, 0.435, 0.298)
## Half-extent of the marked footprint -- the same 3.9 m game/world/pen.gd builds its fence
## on, so what you see marked out is what you get.
const STAKE_INSET := 3.9
const MARK_WIDTH := 0.24
const MARK_HEIGHT := 0.12
const MARK_COLOR := Color(0.745, 0.694, 0.541)

## THE GHOST: WHAT THE GROUND LOOKS LIKE WHILE SHE IS DECIDING.
##
## The owner: "finding the right spot to build the paddock can be harder than it should".
## The rule that was refusing him is older than the complaint (a fence may not materialise
## through the body of the person who ordered it, PlotSlot.is_on_footprint) but it was only
## ever spoken after he had walked in, pressed E, read a catalogue and picked a pen. So the
## answer is shown on the ground, live, before anything is spent: the footprint the fence
## will stand on, filled green while she is standing somewhere it can go up and red while
## she is not, with the reason on the HUD prompt she is already reading.
##
## Colours are literals rather than imports: game/ui/menu_style.gd is a UI file and a
## world node must not depend on one. Green-for-take and red-for-refuse in the same
## register the menus speak, chosen for this ground plane, not copied from any const.
enum Ghost { OFF, VALID, REFUSED }
const GHOST_VALID_COLOR := Color(0.443, 0.741, 0.463, 0.34)
const GHOST_REFUSED_COLOR := Color(0.796, 0.373, 0.361, 0.34)
## The filled footprint sits a hair above the marker boards so the two never z fight.
const GHOST_HEIGHT := 0.05
## A low upstand around the edge, so the footprint reads as a volume the fence will occupy
## rather than as a stain on the grass, without pretending to be the fence itself.
const GHOST_WALL_HEIGHT := 0.55
const GHOST_WALL_WIDTH := 0.14

## Emitted when something is successfully built here. Carries both halves: the data for a
## HUD toast, the node for anything that wants to talk to it.
signal built(plot: PlotData, node: Node)

## Identity in the save file. Set in ranch.tscn, one per slot, and never reused -- it is
## the key GameState.plots is written under and the address stamped into every resident
## pony's PonyInstance.home_slot.
@export var slot_id: StringName = &""

## The PlotData built here, or null while the slot is empty. Read-only in practice; build()
## is the only thing that sets it.
var contents: PlotData = null

var _built_node: Node = null
var _stakes: Node3D = null
var _ghost: Node3D = null
var _ghost_state: int = Ghost.OFF


## Layers assigned in _init() rather than only in _ready(), so a slot is on the right ones
## the moment it exists -- including a `PlotSlot.new()` in a test that never enters a tree.
## The world's layer policy is not something a slot should only acquire by being mounted.
func _init() -> void:
	collision_layer = LayersScript.INTERACTION
	collision_mask = LayersScript.PLAYER
	monitoring = true
	# A slot has nothing to say to another Area3D, and being monitorable would put it in
	# every pony's DetectionArea results.
	monitorable = false


func _ready() -> void:
	_ensure_shape()
	_refresh_stakes()


## Nothing has been built here yet.
func is_empty() -> bool:
	return contents == null


## The node that was built here, or null. Re-validated every call so a node freed by
## something else cannot be handed back as a dangling reference.
func get_built() -> Node:
	if _built_node != null and not is_instance_valid(_built_node):
		_built_node = null
		contents = null
	return _built_node


## Build `plot` here. Returns false and changes NOTHING if the slot is already occupied, if
## `plot` is null, or if its scene cannot be loaded.
##
## COST IS NOT CHECKED HERE. That is deliberate: the slot's job is "can this ground take a
## building", the wallet's job is "can you pay for it", and the build menu
## (game/ui/build_menu.gd) is where the two meet. Folding the wallet in here would make
## every test of the slot's own rule need an Economy, and would make a free rebuild after a
## load -- which is exactly what happens on every load -- have to fake a purchase.
##
## A PLOT WHOSE SCENE IS MISSING LEAVES THE SLOT EMPTY AND BUILDABLE. A hand-edited .tres,
## or a scene renamed without its data following it, must not permanently brick a square of
## the ranch.
func build(plot: PlotData) -> bool:
	if plot == null or not is_empty():
		return false
	if plot.scene_path.is_empty() or not ResourceLoader.exists(plot.scene_path):
		push_error("PlotSlot '%s': plot '%s' points at scene '%s', which does not exist."
			% [String(slot_id), String(plot.id), plot.scene_path])
		return false

	var packed: Resource = load(plot.scene_path)
	if packed == null or not (packed is PackedScene):
		push_error("PlotSlot '%s': plot '%s' scene '%s' did not load as a PackedScene."
			% [String(slot_id), String(plot.id), plot.scene_path])
		return false

	var node: Node = (packed as PackedScene).instantiate()
	if node == null:
		push_error("PlotSlot '%s': plot '%s' scene '%s' failed to instantiate."
			% [String(slot_id), String(plot.id), plot.scene_path])
		return false

	# CONFIGURED BEFORE add_child(), so the built scene's _ready() sees its real capacity
	# and slot id rather than the scene's authored defaults. A Pen builds its fence and
	# spawns its residents in _ready(); handing it its capacity afterwards would mean a
	# grand pen briefly being a three-pony pen, which is a race the moment anything restores
	# a roster during the same frame.
	node.name = "%s_%s" % [String(plot.id), String(slot_id)]
	if node.has_method("configure"):
		node.call("configure", plot, slot_id)

	add_child(node)
	contents = plot
	_built_node = node
	_refresh_stakes()
	set_ghost(Ghost.OFF)
	built.emit(plot, node)
	return true


## Take down whatever is here and return the slot to empty and buildable. Returns false if
## there was nothing on it.
##
## NO REFUND, AND NO CARE FOR WHAT WAS INSIDE. This is deliberately the mechanism only:
## game/world/ranch.gd's boot-time containment probe uses it to put its own scratch pen back
## down, and it empties that pen's roster first. A player-facing "demolish this pen" -- what
## it costs, what happens to the ponies living in it, whether they go back in the saddlebag
## or into the wild -- is a design decision nobody has made yet, and the day somebody makes
## it, it belongs in the caller. NO PONY EVER DIES, so a caller that demolishes an occupied
## pen without emptying it first is a bug in that caller; this refuses to hide it by
## silently rehoming her somewhere she was never sent.
func demolish() -> bool:
	var node := get_built()
	if node == null:
		return false
	if node.has_method("count") and int(node.call("count")) > 0:
		push_error(("PlotSlot '%s': demolishing a plot that still holds %d pony/ponies. " +
			"They have to be moved out first -- see this method's comment.")
			% [String(slot_id), int(node.call("count"))])
	remove_child(node)
	node.queue_free()
	_built_node = null
	contents = null
	_refresh_stakes()
	return true


## WOULD A BODY OF `radius` STANDING AT WORLD `point` BE INSIDE THE FENCE THIS PLOT IS ABOUT
## TO GROW? True if any part of it overlaps the marked footprint.
##
## THE RULE THIS EXISTS FOR: YOU MUST NOT BE ABLE TO SEAL YOURSELF IN BY BUILDING. From the
## owner's playtest -- "i also trapped myself inside the pen and couldnt leave" -- he built a
## paddock while standing on the plot and the finished pen closed around him. A pen's gateway
## is a gate now (game/world/pen.gd) so that is survivable, but a fence that materialises
## through the body of the person who ordered it is still a bug: she is left overlapping a
## slab, to be shoved out of it on whichever side the depenetration picks.
##
## MEASURED AGAINST THE MARKED SQUARE, not against some separate safety radius, and that is
## the point of putting it here rather than in the caller: STAKE_INSET is the boundary this
## slot has been DRAWING ON THE GROUND since before anything was built on it, and it is the
## same 3.9 m game/world/pen.gd stands its fence on. So the line a player is asked to step
## outside of is a line she can already see -- which is what makes a refusal actionable
## instead of mysterious. game/test/test_pen_gate.gd pins those two numbers together.
##
## IN THIS SLOT'S OWN FRAME. Two of ranch.tscn's four slots are turned 180 degrees so their
## gates face open ground, and a world-space comparison would silently be measuring the wrong
## axis for them -- the same trap game/world/ranch.gd's containment probe documents.
func is_on_footprint(point: Vector3, radius: float) -> bool:
	var local: Vector3 = to_local(point)
	return absf(local.x) <= STAKE_INSET + radius and absf(local.z) <= STAKE_INSET + radius


## MAY A PEN GO UP HERE, WITH A BODY OF `radius` STANDING AT `point`, AND IF NOT, WHY NOT.
##
## The one place the build refusals are stated, so the prompt, the ghost and the actual
## refusal in game/world/ranch.gd cannot disagree about what the rule is -- which is exactly
## what a preview is for. Returns {"ok": bool, "reason": String}; `reason` is player-facing
## copy and is empty on a yes.
##
## The reason names the LINE, because the line is drawn on the ground in front of her
## (_refresh_stakes draws it on STAKE_INSET, the same 3.9 m Pen.HALF_EXTENT stands its fence
## on) -- which is what makes a refusal actionable instead of mysterious.
func placement_check(point: Vector3, radius: float) -> Dictionary:
	if not is_empty():
		return {"ok": false, "reason": "something already stands here"}
	if is_on_footprint(point, radius):
		return {"ok": false, "reason": "too close to the fence line, step outside the markers"}
	return {"ok": true, "reason": ""}


## Show, hide or recolour the preview footprint. A BUILT SLOT REFUSES A GHOST OUTRIGHT: a
## coloured footprint inside a standing fence is the overlapping-frames picture the owner
## already reported once, and the way to not draw it is to not be able to.
func set_ghost(state: int) -> void:
	var wanted: int = Ghost.OFF if not is_empty() else state
	if wanted == _ghost_state:
		return
	_ghost_state = wanted
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _ghost_state == Ghost.OFF:
		return
	_ghost = Node3D.new()
	_ghost.name = "PlotGhost"
	var colour: Color = GHOST_VALID_COLOR if _ghost_state == Ghost.VALID else GHOST_REFUSED_COLOR
	var mat := _ghost_material(colour)
	var span := STAKE_INSET * 2.0
	_ghost_box("Floor", Vector3(span, GHOST_HEIGHT, span),
		Vector3(0.0, GHOST_HEIGHT * 0.5, 0.0), mat)
	for s in [-1.0, 1.0]:
		_ghost_box("WallX%s" % ("N" if s < 0.0 else "P"),
			Vector3(GHOST_WALL_WIDTH, GHOST_WALL_HEIGHT, span),
			Vector3(s * STAKE_INSET, GHOST_WALL_HEIGHT * 0.5, 0.0), mat)
		_ghost_box("WallZ%s" % ("N" if s < 0.0 else "P"),
			Vector3(span, GHOST_WALL_HEIGHT, GHOST_WALL_WIDTH),
			Vector3(0.0, GHOST_WALL_HEIGHT * 0.5, s * STAKE_INSET), mat)
	add_child(_ghost)


func ghost_state() -> int:
	return _ghost_state


## The plot id stored for this slot in a save, or "" when the slot is empty. The exact
## String GameState.plots wants -- see the class comment on why both halves are Strings.
func saved_plot_id() -> String:
	return String(contents.id) if contents != null else ""


## An Area3D with no shape never fires body_entered, and that failure is completely
## invisible -- the build prompt simply never appears and nothing anywhere reports why.
## Built in code rather than authored per-slot in ranch.tscn so four slots cannot drift
## into four different sizes.
func _ensure_shape() -> void:
	if find_children("*", "CollisionShape3D", false, false).size() > 0:
		return
	var box := BoxShape3D.new()
	box.size = Vector3(TRIGGER_HALF * 2.0, TRIGGER_HEIGHT, TRIGGER_HALF * 2.0)
	var col := CollisionShape3D.new()
	col.name = "Trigger"
	col.shape = box
	col.position = Vector3(0.0, TRIGGER_HEIGHT * 0.5, 0.0)
	add_child(col)


## The marked-out plot, shown only while the slot is empty: a boundary on the ground and a
## stake at each corner.
##
## AN EMPTY SLOT HAS TO BE VISIBLE. Without this it is a patch of grass indistinguishable
## from the rest of the field that happens to pop a prompt when you walk over it, and a
## player would never know the clearing was for anything. See STAKE_SIZE above for the
## render that decided the shape of it.
##
## Meshes only, no collision: you walk over a plot you are about to build on, and a marker
## you can trip on is worse than no marker.
func _refresh_stakes() -> void:
	var want_marks := is_empty()
	if want_marks and _stakes == null:
		_stakes = Node3D.new()
		_stakes.name = "PlotMarks"

		var stake_mat := _mark_material(STAKE_COLOR)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_mark("Stake%s%s" % ["N" if sx < 0.0 else "P", "N" if sz < 0.0 else "P"],
					Vector3(STAKE_SIZE, STAKE_HEIGHT, STAKE_SIZE),
					Vector3(sx * STAKE_INSET, STAKE_HEIGHT * 0.5 - 0.15, sz * STAKE_INSET),
					stake_mat)

		# The boundary itself: four boards laid flat on the plot's own edge, so the marked
		# square is exactly the square the fence will stand on.
		var board_mat := _mark_material(MARK_COLOR)
		var span := STAKE_INSET * 2.0
		for s in [-1.0, 1.0]:
			_mark("EdgeX%s" % ("N" if s < 0.0 else "P"),
				Vector3(MARK_WIDTH, MARK_HEIGHT, span),
				Vector3(s * STAKE_INSET, MARK_HEIGHT * 0.5 - 0.02, 0.0), board_mat)
			_mark("EdgeZ%s" % ("N" if s < 0.0 else "P"),
				Vector3(span, MARK_HEIGHT, MARK_WIDTH),
				Vector3(0.0, MARK_HEIGHT * 0.5 - 0.02, s * STAKE_INSET), board_mat)

		add_child(_stakes)
	elif not want_marks and _stakes != null:
		_stakes.queue_free()
		_stakes = null


func _mark_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _mark(mark_name: String, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = mark_name
	mesh_node.mesh = box
	mesh_node.position = at
	_stakes.add_child(mesh_node)


## Unshaded and transparent: this is a diagram drawn on the world, not a thing in it, and a
## lit preview would change colour with the hour and stop meaning yes or no.
func _ghost_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _ghost_box(box_name: String, size: Vector3, at: Vector3,
		mat: StandardMaterial3D) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = box_name
	mesh_node.mesh = box
	mesh_node.position = at
	_ghost.add_child(mesh_node)
