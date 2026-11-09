extends SceneTree
## BAKES THE CREATOR'S MANE STYLE CARDS (P8 item 37; docs/aaa-review-2026-11-08.md 2.5: "mane
## styles are words"; Animal Crossing draws every hairstyle as a picture of that hairstyle). For
## each race and each of its styles (PlayerLook.styles_for), the donor body with a neutral coat
## and a mid-tone mane, three-quarter on at the head, into
## res://assets/ui/style_icons/mane_<race>_<index>.png. Run again when the donor list changes:
##   xvfb-run ... tools/bin/godot ... --path game -s res://scenes/test/mane_icons.gd
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const PlayerLookScript := preload("res://systems/player_look.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const OUT := "res://assets/ui/style_icons"
const SIZE := 128
const VIEW := [Vector3(0.7, 0.2, -1.0), Vector3(0, 1.62, -0.45), 0.72]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(600, 600)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.9, 0.84)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 50, 0)
	root.add_child(sun)
	var reg := preload("res://systems/pony_registry.gd").new()
	reg.load_all("res://data/ponies")
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	var made := 0
	for race in 3:
		var styles: Array = PlayerLookScript.styles_for(race)
		for i in styles.size():
			var donor: StringName = styles[i]
			var body: Node3D = PonyVisualsScript.build(reg.by_id(StockPaletteScript.IDS[0]),
				DonorTableScript.model_path(donor))
			if body == null:
				continue
			root.add_child(body)
			for sim: SkeletonModifier3D in body.find_children("*", "SpringBoneSimulator3D", true, false):
				sim.active = false
			var look := PonyLookScript.new()
			look.donor = donor
			look.coat = Color(0.92, 0.88, 0.95)
			look.mane = Color(0.55, 0.38, 0.72)
			look.tail = look.mane
			look.mane2 = look.mane
			look.race = PlayerLookScript.RACE_NAMES[race]
			PonyPaintScript.apply(body, look)
			var dist: float = float(VIEW[2]) / tan(deg_to_rad(cam.fov * 0.5))
			cam.global_position = (VIEW[1] as Vector3) + (VIEW[0] as Vector3).normalized() * dist
			cam.look_at(VIEW[1])
			cam.make_current()
			for k in 8:
				await process_frame
			var img := root.get_texture().get_image()
			var side := mini(img.get_width(), img.get_height())
			var crop := img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
			crop.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			crop.save_png(ProjectSettings.globalize_path(OUT.path_join("mane_%d_%d.png" % [race, i])))
			body.free()
			made += 1
	print("MANE_ICONS_OK %d" % made)
	quit(0)
