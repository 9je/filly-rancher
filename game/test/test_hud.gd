extends GutTest
## Tests for the ranch HUD (game/ui/hud.gd).
##
## WHAT IS WORTH TESTING HERE AND WHAT IS NOT. Whether the crosshair is legible over
## grass, whether the saddlebag is unobtrusive, whether the capture rings read at a
## glance -- none of that is a number, and all of it was judged from rendered frames
## during Phase 1A Task 9's integration pass instead. What IS a number, and what a
## rendered frame is actively bad at showing, is whether the HUD is displaying the
## PLAYER'S ACTUAL STATE or a plausible-looking default: an unbound HUD draws "0 / 12"
## and twelve empty pips, perfectly, forever, and looks exactly like a bound one over an
## empty bag. So these tests are about the binding and the data, and game/world/ranch.gd
## asserts the same thing again against the real Player in the real scene.
##
## Preloads by path rather than by the global class_name, per the convention at the top
## of game/scripts/pony_rig.gd.

const HudScene := preload("res://ui/hud.tscn")
const StorageScript := preload("res://systems/storage.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")

var _hud: CanvasLayer
## The HUD's own parent. It looks for a sibling named "Player" (that is how it is
## mounted in ranch.tscn), so the tests that exercise the binding drop a stand-in Player
## in here alongside it rather than re-parenting the HUD, which would leave it running
## with a stale parent for a frame.
var _world: Node


func before_each() -> void:
	_world = Node.new()
	add_child_autofree(_world)
	_hud = HudScene.instantiate()
	_world.add_child(_hud)


## One caught pony of the named ROSTER character. Real roster ids on purpose: the pip
## colour now comes from `instance.data().rarity`, resolved through PonyRegistry, so a
## made-up id would resolve to null and every pip would draw as the COMMON fallback --
## which would make this file pass whether or not the resolution worked at all.
func _instance(id: String) -> PonyInstance:
	return PonyInstanceScript.create(StringName(id))


func test_the_hud_scene_loads_and_carries_its_script() -> void:
	assert_true(_hud.has_method("get_beam"),
		"hud.tscn must have hud.gd attached -- a parse error leaves a bare CanvasLayer")


## NOTHING ELSE IN THE PROJECT GATES THIS. The magic beam aims along
## CameraRig.get_aim_ray() (game/actors/player/camera_rig.gd), which is projected
## through the camera's SCREEN CENTRE -- and hud.gd draws the reticle at
## `_crosshair.size * 0.5` (its `_draw_crosshair()`), the centre of the "Crosshair"
## Control. Those two only agree because that Control is anchored to fill the whole
## viewport (hud.tscn: anchors_preset=15, offsets zero) so ITS centre lands on the
## viewport's. Nothing ties the two centres together at runtime; a single anchor/offset
## edit on that one node would silently move the reticle off the aim ray while
## game/scenes/test/camera_test.gd's own crosshair round-trip -- which only ever checks
## the camera/projection half of that agreement, never the HUD's node layout -- stayed
## green throughout. This is the other half.
func test_the_crosshair_control_is_centred_on_the_viewport() -> void:
	var crosshair: Control = _hud.get_node("Crosshair")
	await wait_process_frames(1)
	var viewport_centre: Vector2 = _hud.get_viewport().get_visible_rect().size * 0.5
	var crosshair_centre: Vector2 = crosshair.global_position + crosshair.size * 0.5
	assert_almost_eq(crosshair_centre.x, viewport_centre.x, 0.5,
		"the crosshair control's centre must land on the viewport's horizontal centre")
	assert_almost_eq(crosshair_centre.y, viewport_centre.y, 0.5,
		"the crosshair control's centre must land on the viewport's vertical centre")


func test_an_unbound_hud_reports_that_it_is_unbound() -> void:
	# The important one. Standalone -- no Player anywhere -- the HUD must not pretend.
	assert_null(_hud.get_beam(), "a HUD that found no beam must say so, not show a default")
	assert_eq(_hud.get_capacity(), 0, "capacity must be 0 until a real Storage is found")
	assert_eq(_hud.get_shown_rarities(), [] as Array[int])


func test_the_hints_action_is_bound_for_both_keyboard_and_gamepad() -> void:
	assert_true(InputMap.has_action("toggle_hints"),
		"project.godot must define 'toggle_hints'")
	var has_desktop := false
	var has_pad := false
	for event in InputMap.action_get_events("toggle_hints"):
		if event is InputEventKey or event is InputEventMouseButton:
			has_desktop = true
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			has_pad = true
	assert_true(has_desktop, "'toggle_hints' needs a keyboard binding")
	assert_true(has_pad, "'toggle_hints' needs a gamepad binding -- the build is played "
		+ "on a pad too, and a keyboard-only toggle strands that player with the card up")


func test_every_rarity_tier_has_a_pip_colour() -> void:
	# A tier with no colour falls back to COMMON, so a new rarity would silently draw as
	# the most common thing in the game -- exactly backwards for a collection HUD.
	for tier in [PonyDataScript.Rarity.COMMON, PonyDataScript.Rarity.UNCOMMON,
			PonyDataScript.Rarity.RARE, PonyDataScript.Rarity.LEGENDARY]:
		assert_true(_hud.RARITY_COLORS.has(tier),
			"HUD.RARITY_COLORS is missing rarity tier %d" % tier)


func test_the_control_hints_cover_every_action_the_player_needs() -> void:
	var listed := ""
	for row: Array in _hud.HINTS:
		listed += String(row[0]).to_lower() + " "
	# "sneak" rather than "gallop" since the second playtest turned the modifier round --
	# running is the default now and Shift is the hold-to-walk stealth option.
	for needed in ["move", "sneak", "jump", "interact", "look", "zoom", "magic beam"]:
		assert_true(listed.find(needed) >= 0,
			"the hints card must mention '%s'" % needed)


# --- the binding, against a real Storage ------------------------------------------
# A stand-in for the Player: the one thing the HUD needs of her is get_magic_beam(),
# and the one thing it needs of the beam is get_storage() plus the three signals. Built
# here rather than instancing player.tscn so the test does not drag in a pony model, a
# camera rig and a capture of the mouse.

class FakeBeam:
	extends Node3D
	signal captured(data: PonyData)
	signal escaped(body: Node3D)
	signal capture_refused(body: Node3D)

	var storage: Storage

	func get_storage() -> Storage:
		return storage

	func is_active() -> bool:
		return false

	func is_holding() -> bool:
		return false

	# The rest of the reading surface the HUD's crosshair uses. Unreachable while
	# is_active() and is_holding() both answer false (the draw code short-circuits on
	# them), and declared anyway: a stand-in missing half the interface it stands in for
	# is one refactor away from turning a HUD change into a null-method crash in a test
	# that is nominally about the saddlebag.
	func has_target() -> bool:
		return false

	func is_secured() -> bool:
		return false

	func get_secure_progress() -> float:
		return 0.0

	func get_secure_seconds() -> float:
		return 0.0

	func get_struggle_seconds() -> float:
		return INF

	func get_hold_seconds() -> float:
		return 0.0

	func get_last_loss() -> int:
		return MagicBeamScript.Loss.NONE

	func is_wrenching() -> bool:
		return false


class FakePlayer:
	extends Node3D
	var beam: Node3D

	func get_magic_beam() -> Node3D:
		return beam


func _bind_to_a_fake_player(capacity: int) -> FakeBeam:
	var beam := FakeBeam.new()
	beam.storage = StorageScript.new(capacity)
	var player := FakePlayer.new()
	player.name = "Player"
	player.beam = beam
	player.add_child(beam)

	# The HUD looks for a sibling named "Player", so both go under one parent.
	_world.add_child(player)
	return beam


func test_the_hud_binds_to_a_sibling_players_beam_and_shows_its_capacity() -> void:
	var beam := _bind_to_a_fake_player(7)
	# Binding is retried from _process() rather than done in _ready(), because sibling
	# ready order is not something to depend on -- so give it a frame.
	await wait_process_frames(3)
	assert_eq(_hud.get_beam(), beam, "the HUD must find the Player's beam")
	assert_eq(_hud.get_capacity(), 7, "the HUD must show the beam's real capacity")


func test_storing_a_pony_updates_the_pips_without_the_hud_polling() -> void:
	var beam := _bind_to_a_fake_player(4)
	await wait_process_frames(3)
	assert_eq(_hud.get_shown_rarities().size(), 0, "the bag starts empty")

	# store() emits Storage.changed; nothing else is called, so if the pips update it is
	# because the HUD is connected to that signal and not because it re-reads every frame.
	beam.storage.store(_instance("fluttershy"))
	beam.storage.store(_instance("twilight"))
	assert_eq(_hud.get_shown_rarities(),
		[PonyDataScript.Rarity.UNCOMMON, PonyDataScript.Rarity.RARE] as Array[int],
		"the pips must show what is in the bag, oldest first, by rarity tier -- resolved "
		+ "from each individual's data_id, since rarity lives on the character not the pony")

	beam.storage.release()
	assert_eq(_hud.get_shown_rarities(),
		[PonyDataScript.Rarity.UNCOMMON] as Array[int],
		"letting one out must take a pip back off")


func test_a_refused_store_does_not_change_what_the_hud_shows() -> void:
	var beam := _bind_to_a_fake_player(1)
	await wait_process_frames(3)
	beam.storage.store(_instance("twilight"))
	var before: Array[int] = _hud.get_shown_rarities()
	assert_false(beam.storage.store(_instance("fluttershy")),
		"the bag is full, so this store must be refused")
	assert_eq(_hud.get_shown_rarities(), before,
		"a refused capture must leave the pips exactly as they were")
