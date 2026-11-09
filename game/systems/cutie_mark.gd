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
##
## Which way up the drawing then lands is a separate question, answered by the UV
## convention block above _flank_transform().

const LEFT_NAME := &"CutieMarkLeft"
const RIGHT_NAME := &"CutieMarkRight"

## The bone the flanks hang off, in order of preference. `Pelvis` is the haunch; `Chest1`
## is the fallback for a rig that names its hips something else; a model with neither gets
## the decals on its root, which does not animate but does at least show the mark.
const BONE_NAMES: Array[StringName] = [&"Pelvis", &"Chest1"]

## Model space (x out to the flank, y up the barrel, z back toward the haunch). P8 item 40
## ("the show puts it larger, centred on the upper haunch"): the old (0.26, 0.86, 0.22) sat
## down by the stifle, half under a wing. Raised onto the top of the haunch and a little further
## back, placed by eye on a side render of the player (p8_checks, player_flank).
const FLANK := Vector3(0.26, 1.06, 0.3)

## Decal box: across the flank, INTO the pony (the projection depth), and along her. Larger
## than it was (0.30), as the show draws marks.
const DECAL_SIZE := Vector3(0.38, 0.26, 0.38)
## THE MARK PAINTS HER BODY AND NOTHING ELSE. A Decal paints whatever is in its box: a tail
## swinging through, a wing, a mane thrown by the bounce (owner 2026-11-05: "Make sure this
## cutie mark bug doesn't happen anywhere"). Her body mesh carries this render layer, and the
## decals paint only it.
const MARK_LAYER := 1 << 19

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
	_mark_body(model)
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
		decal.cull_mask = MARK_LAYER
		decal.upper_fade = 0.4
		decal.lower_fade = 0.4
		anchor.add_child(decal)
		decal.global_transform = _flank_transform(model, side)
		placed += 1
	return placed


## HOW A DECAL'S TEXTURE IS ORIENTED, and the bug this block exists to close.
##
## A Decal projects along its own local minus Y and samples its albedo across the local XZ
## plane: the sampled U runs with local plus X and the sampled V runs with local plus Z,
## and V = 0 is the TOP row of the image. So the world direction the drawing's own "up"
## points in is the decal's MINUS Z axis, and the direction its "right" points in is the
## PLUS X axis. IMAGE_UP_AXIS and IMAGE_RIGHT_AXIS below are that convention written down
## once, and image_up()/image_right() are the only two places it is applied.
##
## WHAT WENT WRONG. This file used to pass Vector3(0, 1, 0) as the local Z column, with the
## comment "local Z runs up the barrel". That is the barrel's up, not the image's: it put
## image up at world DOWN. The same basis also came out LEFT HANDED (determinant minus one
## on both flanks), which mirrors the drawing. A vertical flip plus a mirror is a half
## turn, which is exactly what the 2026-08-31 playtest screenshot shows: a heart drawn
## point down rendered point up. Passing Vector3(0, -1, 0) instead fixes both halves in one
## column, because it puts image up at world up AND makes the basis right handed.
const IMAGE_UP_AXIS := Vector3(0.0, 0.0, -1.0)
const IMAGE_RIGHT_AXIS := Vector3(1.0, 0.0, 0.0)


## The world transform of one flank's decal. Its local minus Y is the projection axis, so
## it is aimed INWARD along the barrel: for the plus X flank that is minus X, and the
## reverse for the other.
##
## THE RIGHT FLANK REPEATS THE DRAWING RATHER THAN MIRRORING IT, and that is the decision,
## not an accident of the arithmetic. Image right lands on world minus Z on the plus X
## flank and on world plus Z on the minus X flank, and a viewer standing outside either one
## has that direction on her own right; so a letter reads as a letter and a heart reads as
## a heart from both sides. The cost is that an asymmetric mark is not the same paint seen
## from two angles, which is the correct trade for a mark the player drew herself and has
## to be able to recognise.
static func _flank_transform(model: Node3D, side: float) -> Transform3D:
	var basis := Basis(
		Vector3(0.0, 0.0, -side),   # local X: image RIGHT, running along the pony
		Vector3(side, 0.0, 0.0),    # local Y: outward, so the projection down minus Y goes in
		Vector3(0.0, -1.0, 0.0))    # local Z: image DOWN, so image up is world up
	var where := Vector3(FLANK.x * side, FLANK.y, FLANK.z)
	return model.global_transform * Transform3D(basis, where)


## The world direction the TOP of the drawing points in. See the convention block above.
static func image_up(decal: Decal) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return (decal.global_transform.basis * IMAGE_UP_AXIS).normalized()


## The world direction the RIGHT of the drawing points in.
static func image_right(decal: Decal) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return (decal.global_transform.basis * IMAGE_RIGHT_AXIS).normalized()


## The way the decal faces: out of the flank, back along the projection.
static func image_out(decal: Decal) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return decal.global_transform.basis.y.normalized()


## Is the drawing MIRRORED as seen by somebody standing outside this flank? right cross up
## points at that viewer for an un mirrored image and away from her for a mirrored one, so
## this one dot product answers the question without caring which flank it is or how the
## model happens to be turned.
static func is_mirrored(decal: Decal) -> bool:
	if decal == null:
		return false
	return image_right(decal).cross(image_up(decal)).dot(image_out(decal)) < 0.0


## Where the pixel at image coordinate (u, v), both in [0, 1] with (0, 0) at the TOP LEFT
## of the canvas, lands in world space on the flank. The one function a headless test can
## use to ask where a drawn pixel actually goes, since a headless run renders nothing.
static func image_point_to_world(decal: Decal, u: float, v: float) -> Vector3:
	if decal == null:
		return Vector3.ZERO
	return decal.global_transform * Vector3(
		(u - 0.5) * decal.size.x, 0.0, (v - 0.5) * decal.size.z)


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
## Put her body (the biggest mesh that is not hair, tail, wing or eye) on MARK_LAYER.
## THE BODY, BY NAME FIRST (PS7, 2026-11-07): the mesh named as the body ("bodies" or "_body"),
## and only failing that the most vertices among what is left. By vertices alone the PonySFM
## rig's head won (13,207 against the body's 4,078), so every drawn mark was laid on a head the
## flank decals never reach, and no player's mark ever showed.
static func _mark_body(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var named := String(mi.name).to_lower()
		if mi.mesh != null and not named.contains("head") \
				and (named.contains("bodies") or named.contains("_body")):
			mi.layers |= MARK_LAYER
			return
	var best: MeshInstance3D = null
	var most := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if mi.mesh == null or n.contains("tail") or n.contains("hair") or n.contains("mane") \
				or n.contains("wing") or n.contains("eye") or n.contains("head") or n.contains("horn"):
			continue
		var verts := 0
		for i in mi.mesh.get_surface_count():
			verts += mi.mesh.surface_get_array_len(i)
		if verts > most:
			most = verts
			best = mi
	if best != null:
		best.layers |= MARK_LAYER


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
