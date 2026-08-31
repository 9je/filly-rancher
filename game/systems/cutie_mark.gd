class_name CutieMark
extends RefCounted
## THE MARK, ON THE PONY. Two Decal nodes, one per flank, hung off a BoneAttachment3D so
## they follow the haunch through the walk cycle instead of sliding off it.
##
## WHY A DECAL AND NOT A TEXTURE. The base model
## (res://assets/converted/ponies/pokeypierce.glb) has no spare UV island and no overlay
## surface, and its body albedo is a flat colour that StockTint replaces outright
## (game/systems/stock_tint.gd), so there is nowhere to paint a mark into. A Decal projects
## the drawing onto whatever geometry is inside its box, needs no knowledge of the model's
## UVs, and is undone by deleting a node. Decals require the Forward+ renderer, which
## game/project.godot already declares.
##
## THE NUMBERS ARE MEASURED, NOT GUESSED. The base model's body mesh spans x in
## [-0.238, 0.238], y in [0.459, 1.164] and z in [-0.504, 0.393] in model space, and its
## tail sits at +z, so the model faces -z and the haunch is the +z end. FLANK therefore puts
## each decal at x = +/- 0.26 (just clear of the surface), y = 0.86 (mid barrel) and
## z = 0.22 (the haunch). DECAL_SIZE is 0.26 deep, which is shallower than the barrel is
## wide, so the left flank's projection cannot reach the right flank through the pony.
##
## THE PLACEMENT IS COMPUTED IN MODEL SPACE AND CONVERTED. The rest orientation of the
## `Pelvis` bone is not something this file can state and does not have to: the target
## transform is built in the model's own space and then multiplied through the attachment's
## inverse global transform, so whatever the bone's rest pose is, the decal lands on the
## flank.

const LEFT_NAME := &"CutieMarkLeft"
const RIGHT_NAME := &"CutieMarkRight"

## The bone the flanks hang off, in order of preference. `Pelvis` is the haunch; `Chest1`
## is the fallback for a rig that names its hips something else; a model with neither gets
## the decals on its root, which does not animate but does at least show the mark.
const BONE_NAMES: Array[StringName] = [&"Pelvis", &"Chest1"]

## Model space (x out to the flank, y up the barrel, z back toward the haunch).
const FLANK := Vector3(0.26, 0.86, 0.22)

## Decal box: across the flank, INTO the pony (the projection depth), and along her.
const DECAL_SIZE := Vector3(0.30, 0.26, 0.30)

const MarkPaintScript := preload("res://systems/mark_paint.gd")


## Put `mark` on both flanks of `model`. Returns how many flanks were marked: two on
## success, ZERO for a blank drawing, which is a real look and not a failure. Any previous
## mark is removed first, so applying twice replaces rather than stacks.
static func apply(model: Node3D, mark: Image) -> int:
	if model == null:
		return 0
	clear(model)
	if mark == null or MarkPaintScript.is_blank(mark):
		return 0
	var texture: ImageTexture = ImageTexture.create_from_image(mark)
	var anchor: Node3D = _anchor(model)
	if anchor == null:
		return 0
	var placed := 0
	for side in [1.0, -1.0]:
		var decal := Decal.new()
		decal.name = LEFT_NAME if side < 0.0 else RIGHT_NAME
		decal.size = DECAL_SIZE
		decal.texture_albedo = texture
		decal.albedo_mix = 1.0
		# Softened at the rim so the square canvas does not read as a sticker with a hard
		# edge on a curved barrel.
		decal.upper_fade = 0.4
		decal.lower_fade = 0.4
		anchor.add_child(decal)
		decal.global_transform = _flank_transform(model, side)
		placed += 1
	return placed


## The world transform of one flank's decal. Its local -Y is the projection axis, so it is
## aimed INWARD along the barrel: for the +X flank that is -X, and the reverse for the other.
static func _flank_transform(model: Node3D, side: float) -> Transform3D:
	var basis := Basis(
		Vector3(0.0, 0.0, -side),   # local X runs along the pony
		Vector3(side, 0.0, 0.0),    # local Y is the projection axis, pointing outward
		Vector3(0.0, 1.0, 0.0))     # local Z runs up the barrel
	var where := Vector3(FLANK.x * side, FLANK.y, FLANK.z)
	return model.global_transform * Transform3D(basis, where)


static func decals_of(model: Node3D) -> Array[Decal]:
	var out: Array[Decal] = []
	if model == null:
		return out
	for node: Node in model.find_children("*", "Decal", true, false):
		if StringName(node.name) == LEFT_NAME or StringName(node.name) == RIGHT_NAME:
			out.append(node as Decal)
	return out


static func clear(model: Node3D) -> void:
	for decal in decals_of(model):
		decal.get_parent().remove_child(decal)
		decal.queue_free()


## Where the decals hang. A BoneAttachment3D on the haunch when the model has a skeleton
## with one of BONE_NAMES; the model itself otherwise. Reused across calls so applying a new
## mark does not leave a trail of empty attachments behind it.
static func _anchor(model: Node3D) -> Node3D:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return model
	var existing := skeleton.get_node_or_null(^"CutieMarkAnchor") as BoneAttachment3D
	if existing != null:
		return existing
	for bone_name: StringName in BONE_NAMES:
		var index: int = skeleton.find_bone(String(bone_name))
		if index < 0:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "CutieMarkAnchor"
		attachment.bone_name = String(bone_name)
		attachment.bone_idx = index
		skeleton.add_child(attachment)
		return attachment
	return model
