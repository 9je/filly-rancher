class_name PalaceFacade
extends Node3D
## THE SPECTRA PALACE'S FRONT, ASSEMBLED FROM TOWN BUILDINGS BECAUSE NOBODY SELLS A CASINO.
##
## WHY THIS IS A KIT BASH. scratchpad/ledgers/redesign/palace-sourcing.md queried PonySFM --
## the one source that supports true anonymous download -- for casino, Las Pegasus,
## Gladmane, resort, hotel, vegas, gambling, slot, dice, carnival, fairground, boardwalk and
## storefront, and every one of them returned nothing. The two Las Pegasus uploads that do
## exist are minigame props (we own one of them: lp_skeeball, lp_dance_game). Everything on
## SFMLab, Open3DLab, TurboSquid, CGTrader and Sketchfab either has no show style casino or
## gates the download behind an account, which is disqualifying outright. So the Palace is
## Ponyville Environments pieces standing shoulder to shoulder inside its shell's own
## rectangle.
##
## THE NEON IS DRAWN, NOT LOADED, AND THAT WAS A LATE CALL. This task's own brief still names
## `neon_*` ids off a "Neon Lights Pack". tools/prop_manifest.txt's `# NEON IDS:` line says
## `(none)`: that pack was downloaded and opened and turned out to be a background pony's
## character skin (mane/tail rig, a suit and a pair of sunglasses) -- there is no neon
## signage, no glowing lettering and no freestanding prop of any kind in it. So the neon
## dressing the spec's acceptance item 12 asks for ("Palace exterior looks like a
## destination") is CODE-BUILT emissive geometry instead: a tube, a gold trim frame and bulb
## accents, in the same visual language game/world/strip.gd's marquee already established
## (MARQUEE_TRIM_COLOR for the gold, individual MeshInstance3D children rather than a
## MultiMesh for the reason marquee_arch_peak_y()'s own comment gives -- a MultiMesh's
## instance data cannot be read back under this suite's headless runner, so geometry a test
## can check has to live in ordinary node transforms). NEON below is that composition table;
## _stand_neon() is the builder. No Light3D node is added for any of it: the brief caps new
## realtime lights and an unlit emissive material reads as lit signage without spending one.
##
## IT IS NOT IN THE CENSUS AND THAT IS DELIBERATE. ranch.gd counts Props.expected_count()
## plus the Buildings children; these are children OF a building, one structure rather than
## a row of props, and adding them to a count every doc in the repo names would be churn
## with no claim attached. The claims a test can make about them are geometric and they are
## in game/test/test_palace_facade.gd.
##
## EVERY PIECE STANDS ON THE PLINTH. Building.FLOOR_TOP is the top of the Palace's own
## foundation and the height its door apron ramps up to; a piece dropped at local zero would
## be buried nearly a metre inside solid plinth (see Building.GROUND_DROP) and would drag the
## whole building's world AABB down, which is the number ranch.gd seats it by.
##
## AND NOTHING STANDS IN THE DOOR. The door bay is left clear across the front so the apron
## the player walks up leads somewhere rather than into a wall.

const ToonStylerScript := preload("res://systems/toon_styler.gd")
const PropsScript := preload("res://world/props.gd")
const BuildingScript := preload("res://world/building.gd")

## How far past the shell's own rectangle a piece may reach, on every side. Building's own
## eave_overhang is 0.45 m and nobody reads a roof that oversails its walls as a mistake;
## a metre is that idea at the scale of a fourteen metre frontage.
const OVERSAIL := 1.0

## THE COMPOSITION, in the shell's own local XZ metres, and every number is arithmetic
## rather than taste. `at` is the piece's footprint CENTRE; `yaw` turns it inside the facade.
##
## Read across the front: a courtyard block either side of the door bay, a narrow pink block
## outboard of each, and one tower behind the whole thing so the silhouette has a top to it.
## The x figures are (door half 1.6) + a reveal + (the piece's own seated half width), then
## the next piece's own half width past the previous piece's outer edge plus a second,
## tighter reveal. The z figures put each front piece's own face just inside the shell's
## front plane (half depth 4.5) and the tower well behind them.
##
## THE SEATED HALF WIDTHS BELOW ARE MEASURED, NOT THE BRIEF'S OWN ESTIMATE. A probe
## instantiating each piece at Props.MLP_SCALE and reading Props.world_aabb() off it found
## pv_pink_b's true half width to be 1.157 m, not the 1.155 the brief's own arithmetic used --
## close enough that the difference looks like rounding, and large enough that at the brief's
## own 0.15 m reveal the pink block's outer edge landed at 8.167 m, past HALF_WIDTH (7.0) +
## OVERSAIL (1.0). Both reveals below are shaved from the brief's 0.2 / 0.15 to 0.08 / 0.04 so
## the real, measured geometry clears the same budget with room left over, rather than a
## hand-typed distance clearing it only on paper:
##
##   pv_courtyard_b  3.898 x 3.295 seated, half 1.949 / 1.647 -> x = 1.6 + 0.08 + 1.949 = 3.629
##   pv_pink_b       2.314 x 3.886 seated, half 1.157 / 1.943 -> x = 5.578 + 0.04 + 1.157 = 6.775
##   pv_tower_b      6.289 x 3.052 seated, half 3.144 / 1.526 -> centred, set back
const PIECES := [
	{"file": "pv_courtyard_b.glb", "at": Vector2(-3.63, 2.75), "yaw": 0.0},
	{"file": "pv_courtyard_b.glb", "at": Vector2(3.63, 2.75), "yaw": 0.0},
	{"file": "pv_pink_b.glb", "at": Vector2(-6.78, 2.45), "yaw": 0.0},
	{"file": "pv_pink_b.glb", "at": Vector2(6.78, 2.45), "yaw": 0.0},
	{"file": "pv_tower_b.glb", "at": Vector2(0.0, -2.60), "yaw": 0.0},
]

## THE NEON, DRAWN RATHER THAN LOADED (see the class doc for why). `at` is local XZ, on or
## just in front of the piece it dresses; `y` is metres ABOVE Building.FLOOR_TOP, because a
## sign hangs on a wall rather than standing on the ground; `height` is the tube's own
## standing height; `color` is its emissive colour, alternating pink and cyan so the
## frontage reads as more than one sign repeated.
##
## KEPT CLEAR OF STRIP'S OWN MARQUEE AND LOBBYSIGN, BY MEASUREMENT, NOT BY EYE. Both are
## mounted on this same front wall (strip.gd's mount_marquee(), ranch.gd's LobbySign call
## just above _stand_request_board()) and between them they claim nearly the whole frontage:
## the marquee spans |x| up to half_extents.x*MARQUEE_WIDTH_FRACTION + MARQUEE_TRIM (about
## 4.44 m here) at y in roughly [2.65, 4.25], and the lobby sign -- mounted on ONE side only,
## the positive x flank, LOBBY_SIGN_GAP past the marquee's own trim -- runs on to about
## x = 6.98. A neon fixture placed by guesswork at the brief's own x = 2.60 sat BEHIND the
## marquee board entirely (verified in build/r2_shots/19z_facade_close_TEMP.png during this
## task's own look pass: no glow visible anywhere on the frontage). Two placements clear both
## boards on BOTH flanks rather than only the unclaimed left one:
##
##   THE DORMER PAIR, x = +-3.63 (the courtyard blocks' own centreline): held ABOVE
##   strip.gd's own arch (built peak measured at roughly ridge_y - 0.15 m directly over the
##   board's centre, lower off-centre) by mounting at FLOOR_TOP + 4.10 = 4.95 m, comfortably
##   above the arch's own highest measured point and still under the courtyard piece's own
##   roof cap (its seated top is 0.85 + 4.476 = 5.33 m, from the same probe PIECES' own
##   comment cites).
##   THE FLANK PAIR, x = +-7.50 (on the pink blocks, past the lobby sign's own x = 6.98 on
##   the flank that has one, and past nothing at all on the flank that does not): full
##   height, the way a real marquee runs its biggest letters over the doors it actually
##   flanks and smaller accents further down the row.
##   The z of 4.40 in every row is a REQUEST, not the resting place: build() clamps neon z
##   to half_depth - 0.2 (4.3 on the shipped shell), so each fixture stands 0.1 closer to
##   the door than this table reads. The clamp is the authority; the table stays at 4.40 so
##   a deeper shell would push the neon out with it.
const NEON := [
	{"at": Vector2(-3.63, 4.40), "y": 4.10, "height": 0.55, "yaw": 0.0,
		"color": Color(1.0, 0.16, 0.55)},
	{"at": Vector2(3.63, 4.40), "y": 4.10, "height": 0.55, "yaw": 0.0,
		"color": Color(0.15, 0.85, 1.0)},
	{"at": Vector2(-7.50, 4.40), "y": 1.85, "height": 1.9, "yaw": 0.0,
		"color": Color(0.15, 0.85, 1.0)},
	{"at": Vector2(7.50, 4.40), "y": 1.85, "height": 1.9, "yaw": 0.0,
		"color": Color(1.0, 0.16, 0.55)},
]

## The gold every trim frame and bulb accent is drawn in -- strip.gd's own MARQUEE_TRIM_COLOR,
## reused rather than re-picked so the marquee and the facade's own signage read as one
## fixture family instead of two designers' guesses at "gold".
const NEON_TRIM_COLOR := Color(0.98, 0.86, 0.45)

const NEON_TUBE_THICKNESS := 0.15
const NEON_TRIM_MARGIN := 0.13
const NEON_TRIM_DEPTH := 0.06
## How far the tube stands proud of the trim frame behind it -- strip.gd's
## MARQUEE_STANDOFF_LAYER's own reason: two surfaces sharing a depth fight for the same
## pixels, and a hand's width of separation is small enough nobody reads it as a gap.
const NEON_STANDOFF := 0.05
const NEON_BULB_RADIUS := 0.06
## BRIGHTER THAN THE MARQUEE'S OWN BULBS (MARQUEE_TRIM_COLOR at 2.2), on purpose: those are a
## gold accent on a lit board; this is meant to read as NEON, the more saturated, higher
## contrast fixture a casino actually hangs, at both the render's own dawn light (all of these
## screenshots capture at world elapsed 0.0) and after dark.
const NEON_TUBE_ENERGY := 5.5
const NEON_BULB_ENERGY := 3.0

var _pieces := 0
var _neon := 0


func piece_count() -> int:
	return _pieces


func neon_count() -> int:
	return _neon


## Stand the facade. `half_width`/`half_depth` are the shell's own half extents, `door_half`
## is half its doorway, and `facing` is the direction its door looks in WORLD space. Returns
## the number of pieces that actually went up -- zero on a checkout with no converted props,
## which is a reported state and not an error, exactly as Props.build() treats it. The drawn
## neon is not counted in this return value, the same way it is not counted in ranch.gd's
## prop census: see the class doc.
func build(half_width: float, half_depth: float, door_half: float, facing: Vector3) -> int:
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() <= 0.0:
		# A degenerate direction is a caller bug, not a reason to stand no facade: fall back
		# on the way every Building's own door faces before it is turned. Same rule
		# LobbySign.build() and Strip.mount_marquee() already follow.
		flat = Vector3(0.0, 0.0, 1.0)
	for piece: Dictionary in PIECES:
		var at: Vector2 = piece["at"]
		# Clamped so a re-proportioned shell cannot push a piece past its own frontage.
		var x: float = clampf(at.x, -(half_width + OVERSAIL * 0.5), half_width + OVERSAIL * 0.5)
		var z: float = clampf(at.y, -(half_depth - 0.2), half_depth - 0.2)
		if absf(x) < door_half and z > half_depth - 0.5:
			continue
		if _stand(String(piece["file"]), Vector3(x, BuildingScript.FLOOR_TOP, z),
				float(piece["yaw"]), true):
			_pieces += 1
	for lamp: Dictionary in NEON:
		var at: Vector2 = lamp["at"]
		# Same clamp budget as a stood piece (OVERSAIL past the shell's own frontage): the
		# flank pair sits on the outer pink blocks, which themselves reach past half_width.
		var x: float = clampf(at.x, -(half_width + OVERSAIL * 0.5), half_width + OVERSAIL * 0.5)
		var z: float = clampf(at.y, -(half_depth - 0.2), half_depth - 0.2)
		if absf(x) < door_half:
			continue
		_neon += _stand_neon(lamp, Vector3(x, BuildingScript.FLOOR_TOP + float(lamp["y"]), z))
	return _pieces


## One piece. `sit_on_base` puts the model's own floor at `at.y`; a neon sign is hung by its
## centre instead, because a sign has no floor. Everything is measured after the scale and
## the yaw are applied and the node is in the tree, for props.gd's reason: these packs do not
## agree about where a model's origin is.
func _stand(file: String, at: Vector3, yaw: float, sit_on_base: bool) -> bool:
	var path: String = PropsScript.PROP_DIR + file
	if not ResourceLoader.exists(path):
		return false
	var scene: Resource = load(path)
	if scene == null or not (scene is PackedScene):
		push_error("PalaceFacade: '%s' did not load as a PackedScene" % path)
		return false
	var inst: Node3D = (scene as PackedScene).instantiate()
	if inst == null:
		return false
	ToonStylerScript.style(inst, &"building")
	inst.name = "%s_%d" % [file.get_basename(), get_child_count()]
	inst.scale = Vector3.ONE * PropsScript.MLP_SCALE
	inst.rotation.y = deg_to_rad(yaw)
	add_child(inst)
	inst.position = at
	var box: AABB = PropsScript.world_aabb(inst)
	if box.size == Vector3.ZERO:
		inst.queue_free()
		return false
	var centre: Vector3 = box.get_center()
	var local_at: Vector3 = to_local(Vector3(centre.x, 0.0, centre.z))
	inst.position -= Vector3(local_at.x - at.x, 0.0, local_at.z - at.z)
	inst.global_position.y += (to_global(at).y - box.position.y) if sit_on_base \
		else (to_global(at).y - centre.y)
	return true


## ONE DRAWN NEON FIXTURE: a gold trim frame (non-emissive, metallic, strip.gd's own trim
## treatment), a vertical emissive tube standing NEON_STANDOFF proud of it, and a bulb accent
## capping each end of the tube (emissive gold, the same colour the frame is painted, the way
## strip.gd's own bulb rail is gold against a coloured board rather than matching the board's
## own hue). Returns the number of EMISSIVE meshes built -- the tube and its two bulbs -- so
## neon_count() reports real drawn geometry rather than a fixture count with no meshes
## checked against it.
func _stand_neon(entry: Dictionary, at: Vector3) -> int:
	var root := Node3D.new()
	root.name = "Neon%d" % NEON.find(entry)
	add_child(root)
	root.position = at
	root.rotation.y = deg_to_rad(float(entry["yaw"]))

	var height: float = float(entry["height"])
	var color: Color = entry["color"]

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = NEON_TRIM_COLOR
	trim_mat.metallic = 0.45
	trim_mat.roughness = 0.35
	var trim_box := BoxMesh.new()
	trim_box.size = Vector3(NEON_TUBE_THICKNESS + NEON_TRIM_MARGIN * 2.0,
		height + NEON_TRIM_MARGIN * 2.0, NEON_TRIM_DEPTH)
	trim_box.material = trim_mat
	var trim := MeshInstance3D.new()
	trim.name = "Trim"
	trim.mesh = trim_box
	root.add_child(trim)

	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = color
	tube_mat.emission_enabled = true
	tube_mat.emission = color
	tube_mat.emission_energy_multiplier = NEON_TUBE_ENERGY
	var capsule := CapsuleMesh.new()
	capsule.radius = NEON_TUBE_THICKNESS * 0.5
	capsule.height = height
	capsule.material = tube_mat
	var tube := MeshInstance3D.new()
	tube.name = "Tube"
	tube.mesh = capsule
	root.add_child(tube)
	tube.position = Vector3(0.0, 0.0, NEON_STANDOFF)

	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = NEON_TRIM_COLOR
	bulb_mat.emission_enabled = true
	bulb_mat.emission = NEON_TRIM_COLOR
	bulb_mat.emission_energy_multiplier = NEON_BULB_ENERGY
	var sphere := SphereMesh.new()
	sphere.radius = NEON_BULB_RADIUS
	sphere.height = NEON_BULB_RADIUS * 2.0
	sphere.material = bulb_mat
	for end: float in [1.0, -1.0]:
		var bulb := MeshInstance3D.new()
		bulb.name = "BulbTop" if end > 0.0 else "BulbBottom"
		bulb.mesh = sphere
		root.add_child(bulb)
		bulb.position = Vector3(0.0, end * height * 0.5, NEON_STANDOFF)

	return 3
