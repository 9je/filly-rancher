class_name Decor
extends RefCounted
## SOMETHING TO SPEND ON LATER (FS7.1). After an ending bits piled up with nothing worth
## buying. The Market sells twelve decorations, each with its own hand-placed spot round the
## homestead; buying one stands it there (world/decor_layer.gd). Spots and not free placement,
## so a decoration can never block a road, a pen gate or a townspony (test_decor.gd holds every
## spot clear of them; DECISIONS.md 2026-11-05). What she owns is a story var, so it saves.
##
## Each entry: id, name, cost, at (on the ground; the layer seats it), yaw (degrees), clear
## (metres it needs round it), and either scene (a prop) or statue (a pony id, in stone).
## A prop is sized as the world's layout sizes the same model, or by its own s.

const PROPS := "res://assets/converted/props/"
const CATALOGUE: Array[Dictionary] = [
	{"id": &"flower_bushes", "name": "Flower Bushes", "cost": 200, "at": Vector3(8.0, 0, -6.5), "yaw": 0.0, "clear": 1.2, "scene": PROPS + "mlp_bush.glb"},
	{"id": &"hay_bales", "name": "Hay Bales", "cost": 300, "at": Vector3(-13.6, 0, -13.75), "yaw": 20.0, "clear": 1.2, "scene": PROPS + "saa_hay_pile.glb"},
	{"id": &"picnic_table", "name": "Picnic Table", "cost": 450, "at": Vector3(10.0, 0, 4.0), "yaw": 15.0, "clear": 1.4, "scene": PROPS + "school_picnic_table.glb"},
	{"id": &"wagon", "name": "Farm Wagon", "cost": 800, "at": Vector3(-5.0, 0, 2.8), "yaw": 70.0, "clear": 1.6, "scene": PROPS + "saa_wagon.glb"},
	{"id": &"well", "name": "Wishing Well", "cost": 1200, "at": Vector3(6.0, 0, 12.0), "yaw": 0.0, "clear": 1.4, "scene": PROPS + "mlp_farm_well.glb"},
	{"id": &"tetherball", "name": "Tetherball", "cost": 1500, "at": Vector3(7.0, 0, 18.0), "yaw": 90.0, "clear": 1.4, "scene": PROPS + "school_tetherball_pole.glb"},
	{"id": &"garden_arch", "name": "Garden Arch", "cost": 2500, "at": Vector3(-2.2, 0, 24.0), "yaw": 90.0, "clear": 1.2, "scene": PROPS + "saa_wire_arch.glb"},
	{"id": &"apple_tree", "name": "Apple Tree", "cost": 3500, "at": Vector3(7.0, 0, 26.0), "yaw": 0.0, "clear": 2.0, "scene": PROPS + "mlp_apple_tree.glb"},
	{"id": &"statue_fluttershy", "name": "Fluttershy Statue", "cost": 6000, "at": Vector3(-1.2, 0, -6.6), "yaw": 180.0, "clear": 1.0, "statue": &"fluttershy"},
	{"id": &"lemonade_stand", "name": "Lemonade Stand", "cost": 9000, "at": Vector3(-6.0, 0, 30.0), "yaw": 90.0, "clear": 2.0, "scene": PROPS + "kenney_market_stall.glb"},
	{"id": &"chicken_coop", "name": "Chicken Coop", "cost": 12000, "at": Vector3(32.5, 0, 4.0), "yaw": 270.0, "clear": 2.5, "scene": PROPS + "mlp_chicken_coop.glb"},
	{"id": &"statue_rainbowdash", "name": "Rainbow Dash Statue", "cost": 20000, "at": Vector3(5.2, 0, -6.6), "yaw": 180.0, "clear": 1.0, "statue": &"rainbowdash"},
]
const VAR := "decor"


static func find(id: StringName) -> Dictionary:
	for d: Dictionary in CATALOGUE:
		if d.id == id:
			return d
	return {}


static func owned(story: Story) -> Array:
	return (story.get_var(VAR, []) as Array).duplicate() if story != null else []


static func owns(story: Story, id: StringName) -> bool:
	return String(id) in owned(story)


static func add(story: Story, id: StringName) -> void:
	if story == null or find(id).is_empty() or owns(story, id):
		return
	var list := owned(story)
	list.append(String(id))
	story.set_var(VAR, list)
