class_name Building
extends StaticBody3D
## A gabled farm building -- walls, a doorway you can actually walk through, a
## pitched roof -- assembled from primitives at load time.
##
## WHY THIS EXISTS: THE PROP KIT HAS NO BUILDINGS IN IT. That was not obvious from
## the pipeline's own measurements and it is worth writing down. docs/pipeline.md
## section 4 lists `kenney_windmill.glb` (3.11 units) and `kenney_watermill.glb`
## (1.80) under "buildings/structures", and every structural gate agreed: they
## import, they validate, they measure, they collide. The first rendered frame of the
## ranch showed what they actually are -- the Fantasy Town Kit's modular ATTACHMENT
## pieces. `windmill.glb` is a bare X of sails with no tower behind it.
## `watermill.glb` is a bare waterwheel with no mill. `kenney_survival_structure.glb`
## is an open timber frame. There is no house, no barn, no wall with a door in it
## anywhere in game/assets/converted/props/. A "homestead" composed from them reads
## as farm equipment abandoned in a field, which is exactly what the render showed.
##
## Converting the pack's complete building modules WAS the real fix, and slice R2 did it:
## five of the six ranch buildings below now wear a converted PonySFM/Sweet Apple Acres
## model (see the Model export group), turned to face the doorway and stood on this
## shell's own plinth. The Palace is the sixth; game/world/palace_facade.gd kit-bashes it
## out of several pieces instead, so it names no model_file here.
##
## THE PRIMITIVE SHELL IS THE FALLBACK NOW, NOT THE PLAN, and it still builds in full on
## every machine, model or no model: game/assets/converted/ is gitignored (docs/ci.md
## section 4), so a CI checkout and a fresh clone have no props at all, and a shell that
## only stood when its model was present would leave those machines with invisible
## collision and no skyline. On such a machine a barn made of boxes is still a better
## visual anchor than a windmill with no windmill, and the fallback path buys two things a
## converted prop alone could not:
##
##   1. IT IS IN GIT. Everything under game/assets/converted/ is gitignored, so a CI
##      checkout and a fresh clone have no props at all (docs/ci.md section 4). These
##      buildings are code, so the ranch has a skyline on every machine -- including
##      the CI runner, which means the camera-versus-a-real-wall check that this
##      task exists to fix runs in CI too instead of only on the owner's box.
##   2. IT HAS A DOORWAY SIZED FROM THE MEASUREMENT THAT MATTERS. A pony is 1.163 m
##      at the withers and 2.138 m to the top of her horn (docs/pipeline.md section
##      3). Anything you can walk through has to clear the SECOND number; sizing a
##      door off "how tall is a pony" and reaching for the withers figure produces a
##      door she heads straight into. `door_height` is asserted against
##      MIN_DOOR_CLEARANCE below so that mistake cannot be made silently here.
##
## SCALE. Deliberately kept in the Kenney kits' family rather than at real-world barn
## proportions: those kits are stylised small (their trees top out around 3 m at the
## project's 1.5x prop factor), and a photoreal 8 m barn dropped next to them would
## make the rest of the map look like a model railway. Consistency reads as a place;
## one correctly-scaled object among stylised ones does not.

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const PropsScript := preload("res://world/props.gd")
const TerrainScript := preload("res://world/terrain.gd")

## Metres of headroom a doorway must offer. The pony's full 2.138 m plus a hand's
## width, so the number in this file is recognisably the horn-tip measurement and not
## the withers one.
const MIN_DOOR_CLEARANCE := 2.25

## HOW FAR THE FLOOR SLAB REACHES ABOVE AND BELOW THE BUILDING'S OWN ORIGIN.
##
## THE BUG THESE CLOSE. The slab used to be 0.14 m thick with its bottom face at exactly
## local y = 0, and Props.seat() drops a building until the bottom of its world AABB is
## SINK_BIAS (0.05 m) under the ground height at ONE point. The ground under
## Buildings/Palace SPANS 1.264 m from its lowest sample to its highest across that 14 by 9 m
## footprint, measured, and that is the FLATTEST such rectangle anywhere on the Strip.
## Ground that tall crossing a floor that thin is two nearly coplanar surfaces fighting for
## the same pixels: the owner's "z fighting at the palace base, a flickering skirt where the
## building meets terrain", 2026-08-31.
##
## 1.264 IS THE SPAN; 0.633 IS THE HALF SPAN. ranch.gd's PALACE_MAX_RELIEF is written against
## the largest DEVIATION of a corner from the height under the building's own centre, which
## is half the distance a plinth actually has to bridge. Reading that half span as if it were
## the span is what an earlier version of this comment and of test_building_base.gd both did.
##
## SO THE FLOOR BECOMES A PLINTH. What has to clear the span is not FLOOR_TOP on its own but
## FLOOR_TOP + GROUND_DROP (1.80 m), because ranch.gd seats a building against the LOWEST
## corner of its footprint rather than a point under the middle; that is what leaves no
## corner of terrain poking through the boards. SKIRT_DEPTH is below it, so the plinth's
## bottom face has
## somewhere to be once ranch.gd seats it against the LOWEST corner of the footprint
## instead of one point under the middle (see SEAT_CLEARANCE and Building.footprint_relief()
## below -- the ground therefore always passes through the SIDE of a solid box, never a
## horizontal face, no matter how the terrain tips under the four corners).
##
## THE STEP UP IS INTENTIONAL AND READS AS ONE. The better part of a metre is a stride, not
## a wall, and a building that sits on a plinth reads as built rather than as dropped on
## the grass.
const FLOOR_TOP := 0.85
const SKIRT_DEPTH := 1.20

## HOW FAR THE PLINTH'S OWN OUTER FACE SITS BACK FROM THE WALL PLANE ABOVE IT, ON EVERY
## SIDE.
##
## THE BUG THIS CLOSES. Without an inset the Floor slab spans exactly `width` by `depth`,
## the same footprint WallLeft/WallRight/WallBack are built flush against, so over
## y in [0, FLOOR_TOP] the plinth's outer face and the wall's outer face are the SAME
## PLANE: two opaque surfaces of different materials fighting for the same pixels the whole
## height of the step, which is the striping the 2026-08-31 review's own screenshots showed
## at the Palace's base and at the Barn's scale reference
## (02_player_eye_at_spawn.png, 05_scale_at_the_barn.png) -- Ruling 22, round 1.
##
## A FEW CENTIMETRES OF REVEAL is what a real foundation looks like anyway: the wall stands
## PROUD of the skirt beneath it rather than continuing its face straight down. Small enough
## that no one mistakes it for a design change, big enough that the two faces are never
## anywhere near coplanar.
const PLINTH_INSET := 0.06

## THE DOOR APRON: how far it runs, and how thick.
##
## THE BUG THIS CLOSES. Floor is one solid slab across the WHOLE footprint, door gap or
## not -- the door only cuts a hole in the WALL layer, not in the plinth underneath it. Once
## the plinth's own top rose to FLOOR_TOP, every doorway on the map came with a sheer,
## unclimbable step in front of it and nothing to mark it as one: Ruling 22, round 1.
##
## AND THE FIRST APRON DID NOT CLOSE IT. It ran from local y = 0 INWARD and UPWARD to
## FLOOR_TOP, which puts the whole box inside the solid plinth: local y = 0 is not the
## ground (see GROUND_DROP), and everything from there up to FLOOR_TOP over the entire
## footprint is plinth. Six buildings kept their 1.80 m sheer thresholds, and the player's
## only evidence that an apron existed at all was a 5 cm lip of it standing proud of the
## interior floorboards. Whole branch review, 2026-08-31.
##
## SO IT RUNS THE OTHER WAY: from FLOOR_TOP at the plinth's own front face, OUTWARD past
## that face and DOWNWARD to the ground the building was seated against, which is
## GROUND_DROP below local y = 0. That is a rise of FLOOR_TOP + GROUND_DROP (1.80 m), and
## DOOR_APRON_RUN is what turns that rise into a slope somebody reads as a ramp rather than
## as a wall: 2.8 m of run for 1.80 m of rise is 32.7 degrees, well under the 60 the test
## refuses and well over the 10 below which it stops reading as a climb at all. A shorter
## run would be a steeper, meaner threshold; a longer one starts colliding with whatever is
## standing in front of the building (see ranch.gd's ATTENDANT_CLEARANCE, which steps its two
## attendants sideways out of this ramp's way for exactly that reason).
##
## DOOR_APRON_THICKNESS is how thick that box is, cosmetic rather than structural: this is
## readability of the threshold, not a physics walkway, and interactions elsewhere in the
## game are XZ radius and untouched by it.
const DOOR_APRON_RUN := 2.8
const DOOR_APRON_THICKNESS := 0.12

## HOW FAR PAST THE WORST CORNER ranch.gd SEATS A BUILDING, on top of Props.SINK_BIAS.
##
## THE REASON THIS EXISTS. Props.seat() only ever sees one ground height and shifts the
## whole node so the bottom of its own visible AABB sits SINK_BIAS below THAT height --
## it has no idea a building's footprint is 14 by 9 m rather than a point. Handing it the
## height under the building's own origin (what ranch.gd did before this file existed) put
## the plinth's bottom SINK_BIAS below the CENTRE of the footprint, which is no help at all
## against a corner that dips lower than the centre does -- and a plinth deep enough to
## clear that corner does not change where seat() puts the bottom face by one millimetre,
## because seat() re-anchors to whatever the deepest point of the mesh is, whatever depth
## that mesh happens to be built to. The only way to actually clear every corner is to seat
## the building against the LOWEST one, which is what footprint_relief() below measures and
## what ranch.gd's seating loop now hands to Props.seat() for every Building.
##
## SINK_BIAS alone (0.05 m) is not enough of a margin to call a passing check a real gap
## rather than a rounding accident (see test_building_base.gd's own MARGIN, 0.15 m, which
## SINK_BIAS on its own cannot clear); SEAT_CLEARANCE is the rest of it.
const SEAT_CLEARANCE := 0.20

## WHERE THE GROUND ACTUALLY IS, IN THIS BUILDING'S OWN COORDINATES.
##
## Follow the seating arithmetic through once. ranch.gd hands Props.seat() the number
## seat_ground() answers, which is SEAT_CLEARANCE under the LOWEST corner of the footprint,
## and seat() then shifts the whole node until the bottom of its visible AABB, which is the
## plinth's underside SKIRT_DEPTH below local y = 0, sits Props.SINK_BIAS under that. Local
## y = 0 therefore comes to rest exactly this far ABOVE that lowest corner, on every
## building on the map: 0.95 m as the constants stand.
##
## THE BUG THIS CLOSES, AND IT IS THE WHOLE REASON THIS CONSTANT EXISTS. The first door
## apron climbed "from the doorway at y = 0" to FLOOR_TOP, on the assumption that local
## y = 0 was the ground. It is not: it is nearly a metre in the air and buried inside a
## solid plinth, so the apron was entombed and every doorway on the map stayed a
## FLOOR_TOP + GROUND_DROP (1.80 m) sheer step, with a 5 cm lip of apron poking up through
## the interior floor as the only visible sign of it. Whole branch review, 2026-08-31.
const GROUND_DROP := SKIRT_DEPTH - SEAT_CLEARANCE - PropsScript.SINK_BIAS

@export_group("Shell")
## Footprint along X, in metres.
@export var width := 9.0
## Footprint along Z. The roof ridge runs along Z, so the gable ends -- and the door
## -- face +/-Z.
@export var depth := 6.5
## Height of the eaves.
@export var wall_height := 3.4
## Height of the ridge. Must exceed wall_height or the roof is inside out.
@export var ridge_height := 4.8
@export var wall_thickness := 0.28
## How far the roof oversails the walls.
@export var eave_overhang := 0.45

@export_group("Doorway")
## Clear opening in the +Z gable end. Checked against MIN_DOOR_CLEARANCE.
@export var door_width := 2.8
@export var door_height := 2.8

@export_group("Colour")
@export var wall_color := Color(0.556863, 0.231373, 0.192157)
@export var roof_color := Color(0.278431, 0.243137, 0.223529)
## The door lintel and the interior floor. Dark timber by default: a pale lintel
## reads as a gap in the wall rather than as a beam over a door -- which is exactly
## how the first render of the barn looked.
@export var trim_color := Color(0.309804, 0.219608, 0.176471)

## How metallic this building's TRIM is. Zero for every building on the map except the Palace,
## which ranch.tscn sets to 0.45. A lot of "this building is special" for one exported float.
@export_range(0.0, 1.0) var trim_metallic := 0.0

@export_group("Model")
## THE CONVERTED .glb THIS SHELL WEARS, or "" for the primitive shell.
##
## WHY THE PRIMITIVE SHELL DID NOT SIMPLY GO. game/assets/converted/ is gitignored
## (docs/ci.md section 4), so a CI checkout and a fresh clone have no props at all. A shell
## that only renders when its model is present would leave the CI runner, the export smoke
## and the Windows build with a map of invisible collision. So the shell stays, in full, and
## a model hides it only when the file is actually on the machine. `assets=absent` therefore
## still means what ranch.gd has always printed it to mean.
##
## The walls, the roof, the gables and the lintel hide. THE PLINTH AND THE DOOR APRON DO
## NOT: game/test/test_building_base.gd asserts both by name on every building on the
## shipped map, they are what stops the terrain z fighting a base seated across a metre of
## relief (see FLOOR_TOP), and the apron is the threshold a player walks up. What changes is
## the plinth's COLOUR, to the terrain's own tuned DIRT (game/world/terrain.gd), so it reads
## as the turned earth a building is set into rather than as dark timber that matches
## nothing on a hand painted MLP model -- and its FOOTPRINT, to the model's own
## ground-contact rectangle rather than this shell's eave-width one, so the earth reads as a
## few centimetres of set-in ground rather than a pedestal reaching past the model on every
## side (see GROUND_CONTACT_SLICE and _model_ground_contact_footprint()).
@export var model_file := ""
## Multiplier ON TOP of Props.MLP_SCALE. One, for every building on the shipped map: the
## whole point of MLP_SCALE is that every converted Source model on this map is at one
## scale, and a building at a different one is the clash this slice exists to end. It is an
## export rather than a constant so a model whose shipped size is a defect (the case
## Props.SCALE_FIX exists for) can be corrected in the scene beside the model that needs it.
@export var model_scale := 1.0
## Degrees the model is turned about Y inside the shell, so its own entrance faces the
## shell's local plus Z -- which is where the doorway, the apron and the attendants are.
## The packs do not agree on which way a model faces, so this is a measurement, taken off a
## rendered shot, not a convention.
@export var model_yaw := 0.0

const WALL_ROUGHNESS := 0.88
const ROOF_ROUGHNESS := 0.70
const TRIM_ROUGHNESS := 0.45

## The mesh parts a worn model hides. Collision is untouched: what the player bumps into is
## the same box shell it has always been, sized in ranch.tscn to the model standing in front
## of it.
const HIDEABLE := ["WallBack", "WallLeft", "WallRight", "WallFrontL", "WallFrontR",
	"Lintel", "RoofLeft", "RoofRight"]

## HOW FAR ABOVE A WORN MODEL'S OWN FLOOR the plinth's footprint is measured across, when
## deciding how wide the ground it stands in should be.
##
## THE BUG THIS CLOSES. Before this existed the plinth was sized to `width` by `depth`,
## which Task 3 measured off the model's FULL seated AABB -- for a PonySFM cottage that is
## the roof's own eave line, a metre or more past the walls it actually stands on. A plinth
## that size reads as a pedestal the model was set ON rather than ground it was set INTO
## (whole-branch review, 2026-09-05, F1). A thin slice just above the model's own floor
## catches the walls -- which run the model's full height and so have a corner inside any
## slice -- and misses the roof, which overhangs but does not reach down to the ground.
const GROUND_CONTACT_SLICE := 0.5

var _built := false
var _wearing := false


func _ready() -> void:
	collision_layer = LayersScript.PROPS
	collision_mask = 0
	# Hooves on a building are on its planked ramp or its boarded floor (player.gd
	# SURFACE_META); a worn model's stone foundation is a wall, not somewhere to stand.
	set_meta(&"step_surface", &"hoof_wood")


## Assemble the building. Idempotent; called by ranch.gd so that seating against the
## terrain can happen immediately afterwards, in one place, by the same rule props
## are seated by.
func build() -> void:
	if _built:
		return
	_built = true

	if door_height < MIN_DOOR_CLEARANCE:
		push_error(("Building '%s': door_height %.2f m does not clear a pony's %.2f m " +
			"horn tip -- see MIN_DOOR_CLEARANCE") % [name, door_height, MIN_DOOR_CLEARANCE])
	if ridge_height <= wall_height:
		push_error("Building '%s': ridge_height must exceed wall_height" % name)

	var wall_mat := _material(wall_color, WALL_ROUGHNESS)
	var roof_mat := _material(roof_color, ROOF_ROUGHNESS)
	var trim_mat := _material(trim_color, TRIM_ROUGHNESS, trim_metallic)

	# THE MODEL GOES UP FIRST WHEN NAMED, so its own ground-contact footprint is known
	# before the plinth beneath it is sized -- see GROUND_CONTACT_SLICE. An earlier version
	# stood the model last, after the shell; nothing else in this file depends on that order,
	# and this is the one thing that now has to happen before the plinth is built.
	#
	# THE PLINTH-PAINT DECISION AND `_wearing` GATE ON THE SAME CALL, DELIBERATELY. A file
	# that exists but fails to load, is not a PackedScene, or measures an empty AABB used to
	# leave `wearing` (checked only by ResourceLoader.exists()) true while _stand_model()'s
	# own, more careful result went into _wearing -- painting the plinth as ground for a
	# model that never actually stood, with the primitive shell still visible on top of it: a
	# grey box on a black plinth (whole-branch review, 2026-09-05, F11; parked at Task 2's
	# own review before that). One boolean now feeds both.
	var wearing: bool = false
	if model_file != "" and ResourceLoader.exists(_model_path()):
		wearing = _stand_model()
	_wearing = wearing

	# A MODEL CHANGES WHAT THE PLINTH IS FOR. Under the primitive shell it is the building's
	# own boarded floor and matches its lintel; under a hand painted MLP model it is the
	# ground the model is set into, and the terrain's own tuned DIRT is the colour that
	# already says so on every sloped hillside on the map (game/world/terrain.gd). It used to
	# be props.gd's SKIRT_COLOUR -- near black -- which read as a box rather than earth
	# (whole-branch review, 2026-09-05, F1).
	var plinth_mat := _material(
		TerrainScript.DIRT if wearing else trim_color,
		0.95 if wearing else TRIM_ROUGHNESS)

	var half_w := width * 0.5
	var half_d := depth * 0.5
	var t := wall_thickness

	# --- plinth ------------------------------------------------------------------
	# A boarded floor on a deep skirt rather than grass showing through the doorway,
	# and deep enough that the terrain crosses its SIDE rather than its faces. See
	# FLOOR_TOP and SKIRT_DEPTH for the measurement this is sized from. Inset by
	# PLINTH_INSET on every side so its own outer face is never flush with the wall
	# plane standing on top of it -- see PLINTH_INSET's own comment for the coplanar
	# pair that made.
	#
	# SIZED TO THE SHELL FOR A PRIMITIVE, TO THE MODEL'S OWN GROUND CONTACT FOR A WORN ONE.
	# `width` by `depth` is the eave-width rectangle Task 3 measured a model's full seated
	# AABB to -- right for the collision shell (still that size, see HIDEABLE's own comment)
	# and wrong for a plinth standing under a model whose roof overhangs its own walls.
	# See GROUND_CONTACT_SLICE and _model_ground_contact_footprint().
	var plinth_rect: Rect2 = (_model_ground_contact_footprint()
		if wearing else Rect2(-half_w, -half_d, width, depth))
	var plinth_centre: Vector2 = plinth_rect.position + plinth_rect.size * 0.5
	var plinth_size: Vector2 = plinth_rect.size
	var plinth: float = FLOOR_TOP + SKIRT_DEPTH
	_slab("Floor",
		Vector3(plinth_size.x - PLINTH_INSET * 2.0, plinth, plinth_size.y - PLINTH_INSET * 2.0),
		Vector3(plinth_centre.x, FLOOR_TOP - plinth * 0.5, plinth_centre.y), plinth_mat)

	# --- walls -------------------------------------------------------------------
	_slab("WallBack", Vector3(width, wall_height, t),
		Vector3(0.0, wall_height * 0.5, -half_d + t * 0.5), wall_mat, 0.0, 0.0, true)
	_slab("WallLeft", Vector3(t, wall_height, depth - t * 2.0),
		Vector3(-half_w + t * 0.5, wall_height * 0.5, 0.0), wall_mat, 0.0, 0.0, true)
	_slab("WallRight", Vector3(t, wall_height, depth - t * 2.0),
		Vector3(half_w - t * 0.5, wall_height * 0.5, 0.0), wall_mat, 0.0, 0.0, true)

	# --- front gable end, with the doorway left out of it -------------------------
	var panel := maxf((width - door_width) * 0.5, 0.0)
	var front_z := half_d - t * 0.5
	if panel > 0.001:
		_slab("WallFrontL", Vector3(panel, wall_height, t),
			Vector3(-(width - panel) * 0.5, wall_height * 0.5, front_z), wall_mat, 0.0, 0.0, true)
		_slab("WallFrontR", Vector3(panel, wall_height, t),
			Vector3((width - panel) * 0.5, wall_height * 0.5, front_z), wall_mat, 0.0, 0.0, true)
	var lintel := wall_height - door_height
	if lintel > 0.001:
		_slab("Lintel", Vector3(door_width, lintel, t),
			Vector3(0.0, door_height + lintel * 0.5, front_z), trim_mat, 0.0, 0.0, true)

	# --- door apron ------------------------------------------------------------------
	# THE PLINTH'S OWN SOLID FACE, RIGHT WHERE THE DOOR GAP IS, WOULD OTHERWISE BE A SHEER
	# 1.80 m STEP with nothing marking it as a way up. See DOOR_APRON_RUN's own comment for
	# the two versions of this and why the first one was invisible.
	#
	# ANCHORED AT THE TOP, NOT THE BOTTOM. The high end of the slope sits at exactly
	# FLOOR_TOP, at the PLINTH's front face rather than the wall's (the plinth is inset by
	# PLINTH_INSET, so its face is the one the ramp actually has to meet), and it runs out
	# and down from there. That anchoring is what keeps every part of the box above the
	# boards OUTSIDE the footprint the boards cover: the only corner of the apron that
	# reaches back inside the plinth's own XZ rectangle is the underside one, and it is below
	# FLOOR_TOP, buried in solid plinth where nobody sees it. The interior lip is not
	# tolerated here, it is geometrically unreachable.
	#
	# A single leaning box, built the same way the roof below is (a rotated BoxMesh rather
	# than hand-wound triangles), so what is drawn and what is collided with are one shape.
	if door_width > 0.001:
		var apron_run: float = DOOR_APRON_RUN
		var apron_rise: float = FLOOR_TOP + GROUND_DROP
		var apron_slope := sqrt(apron_run * apron_run + apron_rise * apron_rise)
		var apron_angle := atan2(apron_rise, apron_run)
		# The plinth's own front face, not front_z (the WALL's mid-thickness plane) and not
		# half_d (the WALL's own half-depth): for a worn model the plinth's front face has
		# moved to plinth_centre.y + plinth_size.y * 0.5, the same ground-contact rectangle
		# Floor was just sized to, so the ramp still starts exactly where the boards end
		# rather than short of them or floating past their new, smaller edge.
		var apron_top_z: float = plinth_centre.y + plinth_size.y * 0.5 - PLINTH_INSET
		_slab("DoorApron", Vector3(door_width, DOOR_APRON_THICKNESS, apron_slope),
			Vector3(plinth_centre.x, FLOOR_TOP - apron_rise * 0.5, apron_top_z + apron_run * 0.5),
			plinth_mat, 0.0, apron_angle)

	# A WORN MODEL STANDS ON A STONE FOUNDATION, UP A PLANKED RAMP (shaders/stonework.gdshader):
	# the visual review found plain tinted boxes under every house, which read as the
	# primitive shell they are. The geometry and its collision are unchanged; only the skin.
	if wearing:
		_skin(get_node_or_null(^"Floor") as MeshInstance3D, 0, Vector2.ZERO)
		_skin(get_node_or_null(^"DoorApron") as MeshInstance3D, 1, Vector2(1.0, 0.0).rotated(-rotation.y))

	# --- roof ---------------------------------------------------------------------
	# Two slabs leaning against each other. Built as rotated BoxMeshes rather than as
	# hand-wound triangles so Godot's own (clockwise-front-face) winding is used
	# instead of re-derived -- terrain.gd's class comment explains what getting that
	# wrong costs.
	var run := half_w + eave_overhang
	var rise := ridge_height - wall_height
	var slope := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	var slab := Vector3(slope, 0.22, depth + eave_overhang * 2.0)
	var mid_y := (wall_height + ridge_height) * 0.5
	_slab("RoofLeft", slab, Vector3(-run * 0.5, mid_y, 0.0), roof_mat, angle, 0.0, true)
	_slab("RoofRight", slab, Vector3(run * 0.5, mid_y, 0.0), roof_mat, -angle, 0.0, true)

	# --- gable infill --------------------------------------------------------------
	# The triangle of wall between the eaves and the ridge, at each end. Two
	# triangles, no collision (the roof slabs above already stop everything), and
	# CULL_DISABLED because a hand-wound triangle that comes out backwards would be an
	# invisible hole rather than a visible mistake -- and unlike the terrain, nothing
	# here depends on the facing.
	var gable := ArrayMesh.new()
	var verts := PackedVector3Array([
		Vector3(-half_w, wall_height, half_d), Vector3(half_w, wall_height, half_d),
		Vector3(0.0, ridge_height, half_d),
		Vector3(-half_w, wall_height, -half_d), Vector3(half_w, wall_height, -half_d),
		Vector3(0.0, ridge_height, -half_d),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	gable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var gable_mat := _material(wall_color, WALL_ROUGHNESS)
	gable_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gable.surface_set_material(0, gable_mat)
	var gable_node := MeshInstance3D.new()
	gable_node.name = "Gables"
	gable_node.mesh = gable
	add_child(gable_node)

	# THE MODEL WENT UP FIRST, before the plinth was even sized, but nothing here hides the
	# shell it stands in front of until the shell actually exists -- which is now, the walls
	# and the roof above having just been built. `wearing` answers false on any machine with
	# no converted props, which is what leaves the primitives visible on CI.
	if wearing:
		gable_node.visible = false
		for part: String in HIDEABLE:
			var node := get_node_or_null(NodePath(part)) as MeshInstance3D
			if node != null:
				node.visible = false
	else:
		# NO INTERIOR LIGHT UNDER A MODEL. An invisible MeshInstance3D casts no shadow, so an
		# OmniLight3D inside hidden walls would light the grass outside them: a glowing barn
		# in daylight. The spec puts interiors out of scope for this slice (section 9), so the
		# doorway is a threshold and the room behind it is the model's own business.
		_add_interior_light()


## The top of the plinth and the bottom of the skirt, in this building's own parent space.
## For the test that walks every building on the map and asks whether the ground under its
## own footprint can reach either one.
func floor_top_y() -> float:
	return position.y + FLOOR_TOP


func skirt_bottom_y() -> float:
	return position.y - SKIRT_DEPTH


## HOW FAR OUT ALONG THIS BUILDING'S OWN +Z THE DOOR APRON'S FOOT REACHES, from the origin.
## Half the depth for a building with no doorway (Buildings/Board), which stands no apron.
##
## Public because things get placed in front of doors: it is the reach a placement beside a
## doorway has to stay clear of, and game/test/test_attendant.gd asserts the Vendor and the
## Teller stand beside this ramp rather than on it or past its foot.
func apron_foot_z() -> float:
	if door_width <= 0.001:
		return depth * 0.5
	return depth * 0.5 - PLINTH_INSET + DOOR_APRON_RUN


## True if this shell actually stands a converted model rather than its own primitives.
## False before build(), false for a shell with no model_file, and false on any machine
## where that file has not been converted.
func wears_a_model() -> bool:
	return _wearing


## Instance model_file, scale it into the MLP family, turn it to face the doorway and stand
## it on the plinth. Returns true if a model actually went up.
##
## SEATED BY ITS OWN BOUNDING BOX, NOT BY ITS ORIGIN, for the reason props.gd's own class
## comment gives at length: these packs do not agree on where a model's origin is, so the
## only reliable way to put a floor on a floor is to measure the floor. Measured AFTER the
## scale and the yaw are applied and the node is in the tree, because a footprint is the
## footprint of the model as it will actually stand.
##
## AND IT LANDS ON FLOOR_TOP RATHER THAN ON LOCAL ZERO. Local y = 0 is nearly a metre inside
## a solid plinth (see GROUND_DROP); a model dropped there would be half buried, and its
## bottom would drag the whole building's world AABB down, which is the number ranch.gd
## seats every building by and then re-checks. Standing it on the plinth's own top face
## leaves the plinth's underside the lowest thing under this node, exactly as before.
## A converted PonySFM building by its file name (under Props.PROP_DIR), or one of the game's
## own Blender-built models by its full res:// path (the Spectra Palace).
func _model_path() -> String:
	return model_file if model_file.begins_with("res://") else PropsScript.PROP_DIR + model_file


func _stand_model() -> bool:
	if model_file.is_empty():
		return false
	var path: String = _model_path()
	if not ResourceLoader.exists(path):
		return false
	var scene: Resource = load(path)
	if scene == null or not (scene is PackedScene):
		push_error("Building '%s': '%s' did not load as a PackedScene" % [name, path])
		return false
	var inst: Node3D = (scene as PackedScene).instantiate()
	if inst == null:
		push_error("Building '%s': '%s' failed to instantiate" % [name, path])
		return false
	ToonStylerScript.style(inst, &"building")
	var holder := Node3D.new()
	holder.name = "Model"
	add_child(holder)
	holder.add_child(inst)
	inst.scale = Vector3.ONE * (PropsScript.MLP_SCALE * model_scale)
	inst.rotation.y = deg_to_rad(model_yaw)

	var box: AABB = PropsScript.world_aabb(holder)
	if box.size == Vector3.ZERO:
		push_error("Building '%s': '%s' measured an empty AABB" % [name, path])
		holder.queue_free()
		return false
	# Centre it on the shell in XZ and put its floor on the plinth's top face. global_position
	# is used because world_aabb() is a world space measurement and the parent may be turned.
	var centre: Vector3 = box.get_center()
	holder.global_position += Vector3(0.0, FLOOR_TOP - box.position.y, 0.0)
	holder.global_position -= Vector3(centre.x - global_position.x, 0.0,
		centre.z - global_position.z)
	return true


## THE MODEL'S OWN WALLS, NOT ITS ROOF: a rectangle in THIS BUILDING'S OWN LOCAL FRAME
## (the frame Floor and DoorApron are both built in), covering only the geometry standing
## within GROUND_CONTACT_SLICE of the model's own floor. Call only after _stand_model() has
## returned true, so `Model` exists and already stands on the plinth's top face.
##
## WHY A SLICE RATHER THAN THE WHOLE MODEL. A PonySFM cottage's roof oversails its walls the
## same way this shell's own eave_overhang does; measuring every mesh over its full height
## reproduces `width` by `depth`, the eave line, which is the black-pedestal defect this
## function exists to close (F1). A thin band just above the floor catches every VERTEX that
## actually touches the ground -- a wall runs the model's full height, so it has vertices in
## any slice -- while the roof, whose lowest point is the eave itself, has none.
##
## REAL VERTICES, NOT A MESH'S OWN AABB CORNERS -- unlike every other footprint measurement
## in this file and in props.gd, which is corner-of-AABB and says so. Measured here (a
## converted `tools/convert_props.sh` model), every building on the shipped map turned out
## to be ONE MeshInstance3D per model (walls, roof and all, baked into a single surface by
## the SFM/glTF export), so a bounding box has exactly one width regardless of which height
## it is sliced at: a corner-of-AABB version of this function returned the full eave
## rectangle for every building tried, because the box's own bottom corners span the same
## width its top corners do. Walking the mesh's actual `ARRAY_VERTEX` data is the only way
## to tell "the wall passes through this slice" from "the roof's bounding box does" when
## both live in the same MeshInstance3D. Paid once per building at map-build time, not per
## frame -- tens of thousands of Vector3 transforms is not free, but it is not a frame
## budget either.
##
## MEASURED IN THIS BUILDING'S OWN LOCAL FRAME (via to_local()), not world space, because
## Floor and DoorApron are both positioned in that frame and a turned building's world AABB
## of its own footprint is a LOOSER box than the footprint itself -- test_building_base.gd's
## own class comment makes the identical argument for the door apron.
func _model_ground_contact_footprint() -> Rect2:
	var holder := get_node_or_null(^"Model") as Node3D
	var fallback := Rect2(-width * 0.5, -depth * 0.5, width, depth)
	if holder == null:
		return fallback
	var meshes: Array = holder.find_children("*", "MeshInstance3D", true, false)
	var ceiling := FLOOR_TOP + GROUND_CONTACT_SLICE
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for m: MeshInstance3D in meshes:
		var mesh: Mesh = m.mesh
		if mesh == null:
			continue
		var xform: Transform3D = m.global_transform
		for surf in range(mesh.get_surface_count()):
			if mesh.surface_get_primitive_type(surf) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var corner: Vector3 = to_local(xform * v)
				if corner.y > ceiling + 0.001:
					continue
				min_x = minf(min_x, corner.x)
				max_x = maxf(max_x, corner.x)
				min_z = minf(min_z, corner.z)
				max_z = maxf(max_z, corner.z)
	if min_x == INF or max_x - min_x <= 0.001 or max_z - min_z <= 0.001:
		# No vertex found within the slice -- should not happen for a model that actually
		# reaches the ground, but a zero-size plinth under a standing model is worse than
		# the eave rectangle this falls back to.
		return fallback
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


## Terrain height at this footprint's four corners, its four edge midpoints and its centre
## -- nine points across the building's own turned basis, matching how
## test_building_base.gd's per-building invariant walks it -- sampled through
## `ground_sampler` (Terrain.height_at, handed over the same way Strip.configure() and
## RegionFence.configure() already take one). Returns (lowest, highest); called before
## seating (see seat_ground()) and again by ranch.gd's own gate so the number a building was
## actually seated by and the number the gate checks it against can never drift apart.
func footprint_relief(ground_sampler: Callable) -> Vector2:
	var half := Vector2(width * 0.5, depth * 0.5)
	var lowest := INF
	var highest := -INF
	for dx: float in [-half.x, 0.0, half.x]:
		for dz: float in [-half.y, 0.0, half.y]:
			var corner: Vector3 = global_position + global_transform.basis * Vector3(dx, 0.0, dz)
			var h: float = float(ground_sampler.call(corner.x, corner.z))
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	return Vector2(lowest, highest)


## The ground height ranch.gd hands Props.seat() for this building, rather than the height
## under its own origin: SEAT_CLEARANCE below the LOWEST point footprint_relief() finds.
## See SEAT_CLEARANCE for why a single centre sample cannot do this job.
func seat_ground(ground_sampler: Callable) -> float:
	return footprint_relief(ground_sampler).x - SEAT_CLEARANCE


## A warm fill light inside the shell.
##
## WHY A BUILDING NEEDS ITS OWN LIGHT. Phase 1A Task 9's integration pass walked the
## player in through the barn door and the render came back a black box: floor, walls
## and roof all at effectively zero luminance, with the pony a silhouette. The ranch is
## lit by one directional sun plus a low sky-ambient term (ranch.tscn's Environment:
## ambient_light_energy 0.32, 85% sky contribution), and there is no global illumination
## in a Forward+ scene without SDFGI -- so a closed box gets the ambient term and nothing
## else. That is physically reasonable and it is a bad room to walk into.
##
## FIXED HERE RATHER THAN BY RAISING THE ENVIRONMENT'S AMBIENT, deliberately: the
## exterior is already lit the way it should be (the establishing renders read well),
## and turning ambient up to rescue two interiors would flatten every outdoor shadow on
## the map to do it. A light that belongs to the building only affects the building.
##
## SHADOWS ARE ON, AND THAT IS NOT OPTIONAL. An OmniLight3D without shadows passes
## straight through geometry, so a shadowless fill inside the barn would light the
## OUTSIDE of its own walls and the grass around it -- a glowing barn in daylight. Two
## shadow-casting omnis on a low-poly map is a cost worth paying to avoid that.
func _add_interior_light() -> void:
	var light := OmniLight3D.new()
	light.name = "InteriorFill"
	# Just under the eaves and slightly back from the door, so the brightest part of the
	# room is the far end you are walking toward rather than the threshold.
	light.position = Vector3(0.0, wall_height * 0.78, -depth * 0.12)
	# Enough to reach every corner of the shell and no further -- the shadow map does the
	# real containment, but a range that stops near the walls also keeps the cost down.
	light.omni_range = maxf(width, depth) * 0.95
	light.light_color = Color(1.0, 0.92, 0.80)
	light.light_energy = 1.6
	# Straw and lamplight, not a spotlight: the falloff is deliberately soft so the room
	# reads as generally lit rather than as having a bulb hanging in it.
	light.omni_attenuation = 0.6
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	add_child(light)


## THREE SURFACES, THREE ROUGHNESSES, and the whole difference is one exported float.
##
## Every surface of every building shipped at roughness 0.9 with specular disabled, so nothing
## in the world had a highlight and the Palace's gold trim could not glint. A roof slightly
## less rough than its wall reads as a different material without a texture, which is the
## cheapest material variation there is.
##
## trim_metallic IS OPT IN AND DEFAULTS TO ZERO, so every building except the one that asks
## renders byte for byte as it does today. Only Buildings/Palace asks (ranch.tscn sets 0.45),
## and the result is that the casino's gold catches the sun and the marquee bulbs and nothing
## else in the game changes at all.
func _material(colour: Color, surface_roughness := 0.88, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = surface_roughness
	mat.metallic = metallic
	if metallic <= 0.0:
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## One box: a MeshInstance3D and a matching CollisionShape3D sharing a transform, so
## what you see and what you bump into cannot drift apart. `roll` (rotation about Z) is
## what the roof slabs lean on; `pitch` (rotation about X) is what the door apron leans
## on -- see build()'s door apron block for the rotation this is derived from.
##
## `_hideable` marks a slab that a worn model replaces. It is deliberately UNREAD: the
## hiding happens in build() through the HIDEABLE list, so the set of parts a model covers
## is one list in one place rather than eight booleans spread down a function. The parameter
## exists so a reader of the call site knows which slabs are structural (Floor, DoorApron)
## and which are the shell.
const StoneworkShader := preload("res://shaders/stonework.gdshader")
static var _stone_mat: ShaderMaterial
static var _plank_mats: Dictionary = {}


func _skin(node: MeshInstance3D, pattern: int, plank_dir: Vector2) -> void:
	if node == null or DisplayServer.get_name() == "headless":
		return
	if pattern == 0:
		if _stone_mat == null:
			_stone_mat = ShaderMaterial.new()
			_stone_mat.shader = StoneworkShader
			_stone_mat.set_shader_parameter(&"pattern", 0)
		node.material_override = _stone_mat
		return
	var key := "%.2f,%.2f" % [plank_dir.x, plank_dir.y]
	var m: ShaderMaterial = _plank_mats.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = StoneworkShader
		m.set_shader_parameter(&"pattern", 1)
		m.set_shader_parameter(&"base", Color(0.66, 0.46, 0.3))
		m.set_shader_parameter(&"joint", Color(0.33, 0.22, 0.15))
		m.set_shader_parameter(&"plank_dir", plank_dir)
		_plank_mats[key] = m
	node.material_override = m


func _slab(slab_name: String, size: Vector3, at: Vector3, mat: StandardMaterial3D,
		roll := 0.0, pitch := 0.0, _hideable := false) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat

	var mesh_node := MeshInstance3D.new()
	mesh_node.name = slab_name
	mesh_node.mesh = box
	mesh_node.position = at
	mesh_node.rotation.z = roll
	mesh_node.rotation.x = pitch
	add_child(mesh_node)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = slab_name + "Col"
	col.shape = shape
	col.position = at
	col.rotation.z = roll
	col.rotation.x = pitch
	add_child(col)
