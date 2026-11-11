extends SceneTree
## P9 item 53: where each donor body's haunch is, in model space: the body mesh's box and the
## thigh bones' rest heads, so the mark can be placed per body rather than at one measured spot.
##   -s res://scenes/test/laneb_w5_haunch.gd
const DonorTableScript := preload("res://systems/donor_table.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var table: DonorTable = DonorTableScript.load_table()
	var seen := {}
	for id: StringName in table.ids():
		var path := "res://assets/converted/ponies/%s.glb" % id
		if not ResourceLoader.exists(path):
			continue
		var model: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var body: MeshInstance3D = null
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var n := String(mi.name).to_lower()
			if mi.mesh != null and not n.contains("head") and (n.contains("bodies") or n.contains("_body")):
				body = mi
				break
		var box := AABB()
		if body != null:
			box = (model.global_transform.affine_inverse() * body.global_transform) * body.mesh.get_aabb()
		var th := ""
		for names in [["LeftThigh", "RightThigh"], ["DEF_Thigh.L", "DEF_Thigh.R"]]:
			var b := sk.find_bone(names[0]) if sk != null else -1
			if b >= 0:
				var p := (model.global_transform.affine_inverse() * sk.global_transform) * sk.get_bone_global_rest(b).origin
				th = "thigh=%s" % p
		var key := "%s %s" % [box, th]
		if not seen.has(key):
			seen[key] = true
			print("HAUNCH %s body=%s %s" % [id, box, th])
		model.queue_free()
	print("HAUNCH_OK")
	quit(0)
