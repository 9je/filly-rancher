extends RefCounted
## FACES ARE NEVER COVERED (P9, playtest 2026-11-10 items 39 and 71: the talk box sat on the
## speaker's head, Spike's prompt on his face, "Talk to Tumble" on the player's own pony).
## Screen rectangles round the heads of the characters in view, and a picker that takes the
## first of a UI element's candidate spots that covers none of them.

## Metres round a head's centre that count as the face (ears and forelock included).
const HEAD_RADIUS := 0.42
## How far out a character can be and still count (further, her face is a few pixels).
const MAX_DISTANCE := 16.0
## Head heights over the feet when a body has no head bone we know.
const FALLBACK_HEAD := 1.45
const HEAD_BONES := ["DEF_Head", "Head", "head", "Bip01_Head", "Bip01 Head", "mixamorig:Head"]


## The world position of `body`'s head: its skeleton's head bone if it has one, else a fixed
## height over its origin. The bone lookup is cached on the node.
static func head_of(body: Node3D) -> Vector3:
	if not body.has_meta(&"_face_sk"):
		var found: Skeleton3D = null
		var bone := -1
		for sk: Skeleton3D in body.find_children("*", "Skeleton3D", true, false):
			for n: String in HEAD_BONES:
				bone = sk.find_bone(n)
				if bone >= 0:
					found = sk
					break
			if found != null:
				break
		body.set_meta(&"_face_sk", found)
		body.set_meta(&"_face_bone", bone)
	var sk := body.get_meta(&"_face_sk") as Skeleton3D
	var b := int(body.get_meta(&"_face_bone"))
	if sk != null and is_instance_valid(sk) and b >= 0 and sk.is_inside_tree():
		# A little up from the bone's root (it sits at the poll), to the middle of the face.
		return sk.global_transform * sk.get_bone_global_pose(b).origin + Vector3.UP * 0.12
	return body.global_position + Vector3.UP * FALLBACK_HEAD


## `body`'s face on screen (canvas pixels), or an empty Rect2 when it is behind the lens,
## too far, or hidden.
static func face_rect(camera: Camera3D, body: Node3D, radius := HEAD_RADIUS) -> Rect2:
	if camera == null or body == null or not is_instance_valid(body) or not body.is_visible_in_tree():
		return Rect2()
	var head := head_of(body)
	if camera.is_position_behind(head):
		return Rect2()
	if camera.global_position.distance_to(head) > MAX_DISTANCE:
		return Rect2()
	var c := camera.unproject_position(head)
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var rx := absf(camera.unproject_position(head + right * radius).x - c.x)
	var ry := absf(camera.unproject_position(head + up * radius).y - c.y)
	var r := maxf(rx, ry)
	return Rect2(c - Vector2(r, r * 1.15), Vector2(r * 2.0, r * 2.15))


## The faces of everyone who talks or stands near: townsfolk, Spike (lens_fade), the player,
## and `extra`. Empty rects dropped.
static func faces(tree: SceneTree, camera: Camera3D, extra: Array = []) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if tree == null or camera == null:
		return out
	var seen := {}
	var bodies: Array = []
	for g: StringName in [&"townsfolk", &"lens_fade", &"player"]:
		bodies.append_array(tree.get_nodes_in_group(g))
	var player := player_of(camera)
	if player != null:
		bodies.append(player)
	bodies.append_array(extra)
	for n in bodies:
		var b := n as Node3D
		if b == null or seen.has(b):
			continue
		seen[b] = true
		var r := face_rect(camera, b)
		if r.has_area():
			out.append(r)
	return out


## The player a gameplay camera belongs to (its rig hangs under her), or null.
static func player_of(camera: Camera3D) -> Node3D:
	var n: Node = camera
	while n != null:
		if n is CharacterBody3D and n.has_method(&"get_camera_pivot"):
			return n as Node3D
		n = n.get_parent()
	return null


## How much of `r` lies over any of `faces` (pixels squared).
static func overlap(r: Rect2, faces_in: Array[Rect2]) -> float:
	var total := 0.0
	for f in faces_in:
		var i := r.intersection(f)
		total += i.get_area()
	return total


## Index of the first of `spots` that covers no face; failing that, the one covering least.
## `keep` (a previous pick) wins while it still covers none, so the element does not hop.
static func pick(spots: Array[Rect2], faces_in: Array[Rect2], keep := -1) -> int:
	if keep >= 0 and keep < spots.size() and overlap(spots[keep], faces_in) <= 0.0:
		return keep
	var best := 0
	var best_o := INF
	for i in spots.size():
		var o := overlap(spots[i], faces_in)
		if o <= 0.0:
			return i
		if o < best_o:
			best_o = o
			best = i
	return best


## `r` moved inside `screen` (inset by `edge`), keeping its size.
static func clamp_rect(r: Rect2, screen: Rect2, edge: float, top: float = 0.0) -> Rect2:
	var p := r.position
	p.x = clampf(p.x, screen.position.x + edge, maxf(screen.position.x + edge, screen.end.x - r.size.x - edge))
	p.y = clampf(p.y, maxf(screen.position.y + edge, top), maxf(top, screen.end.y - r.size.y - edge))
	return Rect2(p, r.size)
