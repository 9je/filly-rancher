extends RefCounted
## WHAT A PONY CAN WEAR (PS7, playtest 2026-11-05 item 6: "More customisation"). Six pieces,
## each a model held on one bone of the rig so it moves with her: a hat and a bow ride the
## head, the goggles sit on the brow, the scarf rings the neck, the sash and the saddlebags go
## round her barrel. PonyLook.accessory is an index into LIST, -1 for none.
##
## Each entry's `at` is where the piece sits on her rest pose in the body's own space (the
## body's space: up +Y, her face toward -Z, the rig turned under it), fitted by eye on renders
## (build/ps_evidence/item6/accessories.png); it is turned into the bone's space when worn.
##
## Preloaded by path, never by a class_name (the class cache lives in the gitignored .godot/).

## The node a worn piece hangs from, so the next wear() finds and replaces it.
const NODE_NAME := &"Accessory"

const LIST: Array[Dictionary] = [
	{"id": &"straw_hat", "name": "Straw hat", "model": "res://assets/models/straw_hat.glb",
		"bone": "Head", "at": Vector3(0.0, 2.02, -0.45), "rot": Vector3(10, 0, 0), "scale": 1.35,
		"on_mane": 0.1},
	{"id": &"hair_bow", "name": "Hair bow", "model": "res://assets/models/hair_bow.glb",
		"bone": "Head", "at": Vector3(0.24, 2.0, -0.42), "rot": Vector3(0, -15, -25), "scale": 1.3},
	{"id": &"pony_goggles", "name": "Goggles", "model": "res://assets/models/pony_goggles.glb",
		"bone": "Head", "at": Vector3(0.0, 1.97, -0.72), "rot": Vector3(32, 0, 0), "scale": 1.12},
	{"id": &"scarf", "name": "Scarf", "model": "res://assets/models/scarf.glb",
		"bone": "Neck", "at": Vector3(0.0, 1.2, -0.44), "rot": Vector3(-30, 0, 0), "scale": 0.85},
	{"id": &"pony_sash", "name": "Sash", "model": "res://assets/models/pony_sash.glb",
		"bone": "Chest2", "at": Vector3(0.0, 0.82, -0.22), "rot": Vector3(-28, 0, 0), "scale": 1.0},
	{"id": &"saddlebags", "name": "Saddlebags", "model": "res://assets/models/saddlebags.glb",
		"bone": "Chest1", "at": Vector3(0.0, 0.84, 0.02), "rot": Vector3(0, 0, 0), "scale": 1.0},
]

## STORY KIT, never offered in the creator (PS8 item 56a): the Collector's grey coat, round
## her barrel, and the clipboard he carries at the shoulder.
const KIT: Dictionary = {
	&"collector_coat": {"id": &"collector_coat", "model": "res://assets/models/collector_coat.glb",
		"bone": "Chest1", "at": Vector3(0.0, 0.83, -0.06), "rot": Vector3.ZERO, "scale": 1.0},
	&"clipboard": {"id": &"clipboard", "model": "res://assets/models/clipboard.glb",
		"bone": "Chest2", "at": Vector3(0.33, 0.9, -0.36), "rot": Vector3(0, -80, -10), "scale": 1.0},
}


static func count() -> int:
	return LIST.size()


static func label(index: int) -> String:
	return String(LIST[index].name) if index >= 0 and index < LIST.size() else "None"


## Put piece `index` on `body` (a donor instance), taking off whatever she wore before; -1
## takes it off. Returns the piece, or null when none is worn.
static func wear(body: Node3D, index: int) -> Node3D:
	take_off(body, NODE_NAME)
	if index < 0 or index >= LIST.size():
		return null
	return put_on(body, LIST[index], NODE_NAME)


## A story character's own kit (KIT), each piece under its own node so several are worn at
## once beside the player's one LIST piece. Returns the piece.
static func wear_kit(body: Node3D, id: StringName) -> Node3D:
	var node_name := StringName("Kit_" + String(id))
	take_off(body, node_name)
	return put_on(body, KIT[id], node_name) if KIT.has(id) else null


static func take_off(body: Node3D, node_name: StringName) -> void:
	var sk := _skeleton(body)
	if sk == null:
		return
	var old := sk.get_node_or_null(NodePath(node_name))
	if old != null:
		sk.remove_child(old)
		old.free()


static func _skeleton(body: Node3D) -> Skeleton3D:
	if body == null:
		return null
	var sks := body.find_children("*", "Skeleton3D", true, false)
	return null if sks.is_empty() else sks[0]


## Entry `e` on `body`'s rig under a BoneAttachment3D named `node_name`.
static func put_on(body: Node3D, e: Dictionary, node_name: StringName) -> Node3D:
	var sk := _skeleton(body)
	if sk == null:
		return null
	var bone := sk.find_bone(String(e.bone))
	if bone < 0 or not ResourceLoader.exists(String(e.model)):
		return null
	var attach := BoneAttachment3D.new()
	attach.name = node_name
	attach.bone_idx = bone
	sk.add_child(attach)
	# A holder between the bone and the model: the model's own root may carry a turn from its
	# file, which setting its transform would wipe.
	var piece := Node3D.new()
	piece.name = StringName(e.id)
	attach.add_child(piece)
	var model: Node3D = (load(String(e.model)) as PackedScene).instantiate()
	piece.add_child(model)
	# Body space on the rest pose, into the bone's own space: skeleton-from-body, then the
	# bone's rest pose in the skeleton.
	var sk_from_body := _relative(body, sk).affine_inverse()
	var bone_rest: Transform3D = sk.get_bone_global_rest(bone)
	var at: Vector3 = e.at
	# A HAT SITS ON HER MANE, whichever mane it is: a tall style's tuft came up through the
	# crown (render, 2026-11-07). `on_mane` is how far the hat sinks into the mane's top.
	if e.has("on_mane"):
		at.y = maxf(at.y, _mane_top(body, at) - float(e.on_mane))
	var want := Transform3D(Basis.from_euler((e.rot as Vector3) * (PI / 180.0)).scaled(
		Vector3.ONE * float(e.scale)), at)
	piece.transform = bone_rest.affine_inverse() * sk_from_body * want
	return piece


## The highest point of her mane within a hat's reach of `at` (body space, rest pose), or
## -INF when she has none there.
static func _mane_top(body: Node3D, at: Vector3) -> float:
	var top := -INF
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null or not String(mi.name).containsn("mane"):
			continue
		var xf := _relative(body, mi)
		for i in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := xf * v
				if Vector2(p.x - at.x, p.z - at.z).length() < 0.42:
					top = maxf(top, p.y)
	return top


## `node`'s transform in `ancestor`'s space, by its local transforms (no scene tree needed).
static func _relative(ancestor: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
