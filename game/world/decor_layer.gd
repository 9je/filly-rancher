class_name DecorLayer
extends Node3D
## THE DECORATIONS SHE HAS BOUGHT, STANDING IN THEIR SPOTS (systems/decor.gd). build() stands
## every owned one, each a child named by its id, seated on the ground, in the game's light,
## solid to walk round, fading out far off like any prop. A statue is the pony herself, frozen
## mid-stand, in grey stone on a plinth.

const STONE := Color(0.72, 0.71, 0.74)

## (x, z) -> ground height; unset, 0.
var height_at: Callable


func build(story: Story) -> void:
	for id: String in Decor.owned(story):
		if get_node_or_null(NodePath(id)) != null:
			continue
		var d := Decor.find(StringName(id))
		if d.is_empty():
			continue
		var node := _make(d)
		if node == null:
			continue
		node.name = id
		add_child(node)
		var at: Vector3 = d.at
		at.y = float(height_at.call(at.x, at.z)) if height_at.is_valid() else 0.0
		node.position = at
		node.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
		Props.apply_fade(node)


func _make(d: Dictionary) -> Node3D:
	if d.has("statue"):
		return _statue(StringName(d.statue))
	var path := String(d.get("scene", ""))
	if path == "" or not ResourceLoader.exists(path):
		return Node3D.new()
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * size_for(d)
	ToonStyler.style(inst, &"prop")
	_solid(inst)
	return inst


## A decoration's size: its own s, else the size the world's layout gives the same model
## (each kit has its own unit), else as modelled.
static func size_for(d: Dictionary) -> float:
	if d.has("s"):
		return float(d.s)
	var file := String(d.get("scene", "")).get_file()
	for e: Dictionary in Props.LAYOUT:
		if e.file == file:
			return Props.scale_for(e)
	return 1.0


func _statue(pony: StringName) -> Node3D:
	var root := Node3D.new()
	var plinth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.5, 2.4)
	plinth.mesh = box
	plinth.position.y = 0.25
	var pm := StandardMaterial3D.new()
	pm.albedo_color = STONE.darkened(0.15)
	plinth.material_override = pm
	root.add_child(plinth)
	var data: PonyData = load("res://data/ponies/%s.tres" % pony) if ResourceLoader.exists("res://data/ponies/%s.tres" % pony) else null
	if data != null:
		var body := PonyVisuals.build(data)
		if body != null:
			body.position.y = 0.5
			root.add_child(body)
			# Stone: every surface the one grey, and nothing moving.
			var stone := StandardMaterial3D.new()
			stone.albedo_color = STONE
			for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = stone
			for ap: AnimationPlayer in body.find_children("*", "AnimationPlayer", true, false):
				if ap.has_animation(&"idle"):
					ap.play(&"idle")
					ap.seek(0.0, true)
				ap.pause()
			for m: SkeletonModifier3D in body.find_children("*", "SkeletonModifier3D", true, false):
				m.active = false
			var bounce := body.get_node_or_null(^"RumpBounce")
			if bounce != null:
				bounce.set_process(false)
	ToonStyler.style(root, &"prop")
	_solid(plinth)
	return root


## Solid to walk round: a trimesh body per mesh, on the props' layer.
func _solid(node: Node) -> void:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = preload("res://world/collision_layers.gd").PROPS
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		body.add_child(cs)
		mi.add_child(body)
