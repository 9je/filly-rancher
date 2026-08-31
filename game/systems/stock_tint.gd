class_name StockTint
extends RefCounted
## THE ONE RECOLOUR PIPELINE, WITH TWO USERS: the stock crowd
## (game/world/spawner.gd, game/actors/pony/pony.gd) and the player's own pony
## (game/actors/player/player.gd, built in the creation screen). Both go through
## apply(); there is no second path, and there must never be one.
##
## MATCHED ON THE MATERIAL NAME, NOT ON A SURFACE INDEX. Godot's glTF importer copies each
## glTF material's name into the imported StandardMaterial3D.resource_name, and the base
## model's names are the descriptive ones the artist wrote: `body`, `hair`, `tail`,
## `eyeball_l`, `eyeball_r`. Indices would break the first time a mesh was re-exported with
## its surfaces in another order; a name survives that.
##
## WHY A COAT DROPS ITS TEXTURE AND AN EYE DOES NOT. The base model's body and hair
## textures are flat colour (its body texture is 99.2% one RGB value, the rest being the
## character's own cutie mark), so replacing them with a flat albedo_color loses nothing
## except that mark, which is exactly what an unregistered stock pony should not have. The
## eyeball texture is different: it carries the pupil, the white and the iris, so it is
## KEPT and the swatch modulates it. That means an eye swatch tints the baked iris rather
## than replacing it, and the shipped eye rows are authored against that base. Replacing
## the iris outright is Phase 5's look system.
##
## OVERRIDES, NEVER EDITS. set_surface_override_material() leaves the imported material
## untouched, so two ponies built from the same .glb do not share a recolour; editing the
## material off the mesh would recolour every pony in the world at once, which is the exact
## bug this shape exists to make impossible.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

enum Role { NONE, COAT, MANE, EYE }

const COAT_SURFACES: Array[StringName] = [&"body", &"wings"]
const MANE_SURFACES: Array[StringName] = [&"hair", &"tail"]
const EYE_SURFACES: Array[StringName] = [&"eyeball_l", &"eyeball_r"]


static func role_of(material_name: StringName) -> int:
	if material_name in COAT_SURFACES:
		return Role.COAT
	if material_name in MANE_SURFACES:
		return Role.MANE
	if material_name in EYE_SURFACES:
		return Role.EYE
	return Role.NONE


## Recolour `model` in place. Returns how many surfaces were overridden, which is zero for
## a null model and zero for a model whose materials carry none of the names above; both
## are reported by the caller rather than pushed as an error here, because an assetless
## checkout legitimately has neither.
static func apply_colors(model: Node3D, coat: Color, mane: Color, eyes: Color) -> int:
	if model == null:
		return 0
	var touched := 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh == null:
			continue
		for i in range(mesh_node.mesh.get_surface_count()):
			var source: Material = mesh_node.get_active_material(i)
			if source == null or not (source is StandardMaterial3D):
				continue
			var role: int = role_of(StringName(source.resource_name))
			if role == Role.NONE:
				continue
			var colour := coat
			if role == Role.MANE:
				colour = mane
			elif role == Role.EYE:
				colour = eyes
			mesh_node.set_surface_override_material(i,
				_tinted(source as StandardMaterial3D, colour, role == Role.EYE))
			touched += 1
	return touched


static func apply(model: Node3D, palette: StockPalette, triple: Dictionary) -> int:
	if palette == null:
		return 0
	return apply_colors(model,
		palette.coat_at(int(triple.get("coat", 0))),
		palette.mane_at(int(triple.get("mane", 0))),
		palette.eye_at(int(triple.get("eyes", 0))))


## The override this pipeline put on the surface named `material_name`, or null if there is
## none. For the tests and the gates, which otherwise have no way to tell "the tint was
## applied" from "the model happened to be that colour already".
static func override_of(model: Node3D, material_name: StringName) -> StandardMaterial3D:
	if model == null:
		return null
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh == null:
			continue
		for i in range(mesh_node.mesh.get_surface_count()):
			var override: Material = mesh_node.get_surface_override_material(i)
			if override == null:
				continue
			if StringName(override.resource_name) == material_name:
				return override as StandardMaterial3D
	return null


## A copy of `source` recoloured to `colour`. The copy keeps the normal map, the cull mode
## and the shading mode, so a tinted pony still lights and silhouettes like the model she
## was built from. `keep_texture` is true only for the eyes; see the class comment.
static func _tinted(source: StandardMaterial3D, colour: Color,
		keep_texture: bool) -> StandardMaterial3D:
	var out: StandardMaterial3D = source.duplicate()
	# Carried through so override_of() can find this material by the name of the surface it
	# replaced; duplicate() copies resource_name already, and this states that it must.
	out.resource_name = source.resource_name
	if not keep_texture:
		out.albedo_texture = null
	out.albedo_color = colour
	return out
