extends SceneTree
## THE PONY TURNTABLE (playtest note "bad textures on some pony models and weird eyes on
## others"). Every roster model, every story character and N generated Drifters, each built
## the way the game builds her (pony.tscn + setup()/set_stock(), npc.gd for the cast, the
## real SpikeActor), under the ranch's own sun, shot at front, side, three-quarter, an eye
## close-up, from 16 m through a long lens (where the shadow speckle showed), and the
## three-quarter again at the FAR detail tier (outline-free twins, tongue and teeth hidden),
## so a twin that lost its texture shows. tools/pony_turntable.sh tiles the shots into
## contact sheets. Also prints every material problem PonyMaterialAudit finds.
##
## Renders, does not assert. Windowed only (the invisible display, see the .sh).
##   ... -s res://scenes/test/pony_turntable.gd -- out=/abs/dir [set=all|roster|cast|generated]
##       [count=50] [seed=20261024] [only=id,id]

const PonyScene := preload("res://actors/pony/pony.tscn")
const NpcScript := preload("res://actors/npc/npc.gd")
const SpikeScript := preload("res://world/spike_actor.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const AuditScript := preload("res://test_input/pony_material_audit.gd")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

var _out := ""
var _set := "all"
var _count := 50
var _seed := 20261024
var _only: PackedStringArray = []
var _stage: Node3D
var _cam: Camera3D
var _problems := 0
var _ssao := true
## Sun elevation in degrees: 30 is mid-morning; the new game starts at DAWN with it low, and a
## low sun is where the shadow speckle was worst.
var _sun_elev := 30.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"out": _out = kv[1]
			"set": _set = kv[1]
			"count": _count = int(kv[1])
			"seed": _seed = int(kv[1])
			"only": _only = kv[1].split(",")
			"ssao": _ssao = kv[1] != "0"
			"sun": _sun_elev = float(kv[1])
	if _out == "":
		_out = OS.get_user_data_dir() + "/turntable"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _build_stage() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	# The ranch's own Environment (world/ranch.tscn "Env"), less its sky (ambient and exposure
	# nudged up to stand in for the sky's share of the light), so what a pony looks
	# like here is what she looks like in the game: SSAO, glow, fog and the grade included.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.729412, 0.803922, 0.878431)
	env.ambient_light_energy = 0.32 + 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.8 * 1.25
	env.ssao_enabled = _ssao
	env.ssao_radius = 0.9
	env.ssao_intensity = 0.45
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.15
	env.ssao_ao_channel_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	# The ranch's own sun (world/ranch.tscn), soft shadows and all, so a shadow artefact on a
	# pony in the game shows here too.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-_sun_elev, 45, 0)
	sun.light_color = Color(1, 0.968627, 0.905882)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.1
	sun.light_angular_distance = 0.9
	sun.directional_shadow_max_distance = 85.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.17
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_blend_splits = true
	_stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.78, 0.45)
	ground.material_override = gm
	_stage.add_child(ground)
	_cam = Camera3D.new()
	_stage.add_child(_cam)
	_cam.make_current()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_build_stage()
	await _frames(5)
	var jobs: Array = []
	if _set in ["all", "roster"]:
		for f in DirAccess.get_files_at("res://data/ponies"):
			if f.ends_with(".tres"):
				jobs.append(["roster", f.get_basename()])
		jobs.append(["spike", "spike"])
	if _set in ["all", "cast"]:
		for f in DirAccess.get_files_at("res://data/characters"):
			if f.ends_with(".tres"):
				jobs.append(["cast", f.get_basename()])
	if _set in ["all", "generated"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		for i in _count:
			jobs.append(["gen", "gen%02d" % i, rng.randi(), rng.randf() < 0.12])
	for job: Array in jobs:
		if not _only.is_empty() and not (String(job[1]) in _only):
			continue
		await _shoot(job)
	print("TURNTABLE_DONE shots_in=%s problems=%d" % [_out, _problems])
	quit(0)


func _make(job: Array) -> Node3D:
	match String(job[0]):
		"roster":
			var p: CharacterBody3D = PonyScene.instantiate()
			p.set("calm", 999.0)
			_stage.add_child(p)
			p.call("setup", load("res://data/ponies/%s.tres" % job[1]))
			return p
		"gen":
			var opts := {"foal": true} if bool(job[3]) else {}
			var look := GeneratorScript.generate(int(job[2]), opts)
			var p: CharacterBody3D = PonyScene.instantiate()
			p.set("calm", 999.0)
			p.call("set_stock", look.to_dict())
			_stage.add_child(p)
			p.call("setup", _stock_record(StockPaletteScript.IDS[int(job[2]) % 3]))
			print("TURNTABLE_GEN %s donor=%s race=%s foal=%s coat=%s" % [job[1], look.donor, look.race, look.foal, look.coat.to_html(false)])
			return p
		"cast":
			var n: CharacterBody3D = NpcScript.new()
			n.set("character_id", StringName(job[1]))
			_stage.add_child(n)
			return n
		"spike":
			var s: Node3D = SpikeScript.new()
			_stage.add_child(s)
			return s
	return null


var _reg: Object


## A Drifter's hidden personality record, from the registry exactly as the spawner reads it.
func _stock_record(id: StringName) -> Resource:
	if _reg == null:
		_reg = load("res://systems/pony_registry.gd").new()
		_reg.call("load_all", "res://data/ponies")
	return _reg.call("by_id", id)


func _shoot(job: Array) -> void:
	var tag := "%s_%s" % [job[0], job[1]]
	var a := _make(job)
	if a == null:
		print("TURNTABLE_SKIP ", tag)
		return
	await _frames(6)
	a.set_physics_process(false)
	if a is SpikeActor:
		a.set_process(false)
	for p in AuditScript.audit(a, tag):
		print("TURNTABLE_PROBLEM ", p)
		_problems += 1
	var vis: Node3D = a.get_node_or_null("Visuals")
	if vis == null:
		vis = a
	var box := _bounds(a)
	var c := box.get_center()
	var size := box.size.length()
	var dist := size * 1.25
	# Which way she faces, from her own head: the eyes sit forward of the body's centre.
	# (Pony donors face -Z of their Visuals node and Spike +Z, so no axis can be assumed.)
	var eye := _eye_point(a, box, vis.global_basis.z)
	var fwd := eye - c
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, 1)
	var right := fwd.cross(Vector3.UP).normalized()
	var sc := box.size.y
	var shots := [
		["front", c + fwd * dist + Vector3(0, sc * 0.1, 0), c, 40.0],
		["side", c - right * dist + Vector3(0, sc * 0.1, 0), c, 40.0],
		["threequarter", c + (fwd - right).normalized() * dist + Vector3(0, sc * 0.25, 0), c, 40.0],
		["eyes", eye + (fwd * 0.93 - right * 0.36).normalized() * sc * 0.55 + Vector3(0, sc * 0.03, 0), eye, 30.0],
	]
	for s: Array in shots:
		await _snap(tag, s)
	# Mid distance (16 m, a long lens so she fills the frame): where the in-game speckle showed.
	await _snap(tag, ["mid", c + (fwd - right).normalized() * 16.0 + Vector3(0, 1.5, 0), c, 7.0])
	# The FAR tier the game puts her in past DETAIL_FAR_AT: twins on, tongue and teeth off.
	_go_far(a)
	await _frames(2)
	for p in AuditScript.audit(a, tag + "@far"):
		print("TURNTABLE_PROBLEM ", p)
		_problems += 1
	await _snap(tag, ["far", c + (fwd - right).normalized() * dist + Vector3(0, sc * 0.25, 0), c, 40.0])
	a.queue_free()
	await _frames(2)


func _go_far(a: Node) -> void:
	if a.has_method("_set_detail"):
		a.call("_set_detail", 2)
	else:
		ToonStylerScript.wear_outline(a.find_children("*", "MeshInstance3D", true, false), false, {})


func _snap(tag: String, s: Array) -> void:
	_cam.fov = float(s[3])
	_cam.global_position = s[1]
	_cam.look_at(s[2])
	await _frames(3)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [_out, tag, s[0]])


func _bounds(a: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in a.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return AABB((a as Node3D).global_position, Vector3.ONE)
	return box


## Between her eyes: the skeleton's eye bones if she has them, else the front top of her head.
func _eye_point(a: Node, box: AABB, fwd: Vector3) -> Vector3:
	for s in a.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var acc := Vector3.ZERO
		var n := 0
		for b in sk.get_bone_count():
			var bn := sk.get_bone_name(b).to_lower()
			if "eye" in bn and not ("lid" in bn or "brow" in bn or "lash" in bn):
				acc += sk.global_transform * sk.get_bone_global_pose(b).origin
				n += 1
		if n > 0:
			return acc / n
		# No eye bones (Spike): the eyeballs' own vertices, which he holds in his rest pose.
		var eyes := Vector3.ZERO
		var ne := 0
		for m in a.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(si)
				if sm != null and sm.resource_name.begins_with("eyeball"):
					for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
						eyes += mi.global_transform * v
						ne += 1
		if ne > 0:
			return eyes / float(ne)
		for nm in ["DEF_Head", "Head", "head", "DEF-head", "ValveBiped.Bip01_Head1"]:
			var hb := sk.find_bone(nm)
			if hb >= 0:
				# A head bone sits at the jaw hinge; the eyes are a fifth of her height above it
				# (Spike, the one rig here with no eye bones).
				return sk.global_transform * sk.get_bone_global_pose(hb).origin + Vector3.UP * box.size.y * 0.2
	return box.get_center() + Vector3(0, box.size.y * 0.35, 0) + fwd * box.size.z * 0.4
