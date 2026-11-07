extends SceneTree
## BAKES THE CREATOR'S PICTURE CARDS (PS7 item 6): each marking, eye shape and worn piece on
## one plain pony, rendered through PonyPaint and cropped to the part it changes, into
## res://assets/ui/style_icons/. Run again whenever a marking, an eye or a piece changes:
##   xvfb-run ... tools/bin/godot ... --path game -s res://scenes/test/style_icons.gd
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const PonyLookScript := preload("res://systems/pony_look.gd")
const AccessoriesScript := preload("res://systems/accessories.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const OUT := "res://assets/ui/style_icons"
const SIZE := 128

## The views: [from (a direction), the part looked at, its radius in metres]; the camera stands
## back far enough for that radius to fill the card.
const FACE := [Vector3(0.35, 0.05, -1.0), Vector3(0, 1.5, -0.8), 0.42]
const EYE := [Vector3(0.35, 0.05, -1.0), Vector3(0.14, 1.6, -0.86), 0.2]
const LEGS := [Vector3(1.0, 0.25, -0.35), Vector3(0, 0.32, -0.05), 0.5]
const RUMP := [Vector3(1.0, 0.35, 0.3), Vector3(0, 0.9, 0.1), 0.42]
const HEAD := [Vector3(0.6, 0.25, -1.0), Vector3(0, 1.65, -0.55), 0.6]
const BODY := [Vector3(1.0, 0.5, -0.7), Vector3(0, 0.95, -0.15), 0.62]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(900, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	# [file, marking, eye shape, accessory, view]
	var cases: Array = [["marking_0", 0, 0, -1, FACE], ["marking_1", 1, 0, -1, LEGS],
		["marking_2", 2, 0, -1, FACE], ["marking_3", 3, 0, -1, FACE], ["marking_4", 4, 0, -1, RUMP],
		["eye_0", 0, 0, -1, EYE], ["eye_1", 0, 1, -1, EYE], ["eye_2", 0, 2, -1, EYE],
		["acc_none", 0, 0, -1, HEAD]]
	for i in AccessoriesScript.count():
		var bone := String(AccessoriesScript.LIST[i].bone)
		cases.append(["acc_%d" % i, 0, 0, i, HEAD if bone in ["Head", "Neck"] else BODY])
	for c: Array in cases:
		var body: Node3D = PonyVisualsScript.build(reg.by_id(StockPaletteScript.IDS[0]), "")
		root.add_child(body)
		var look := PonyLookScript.new()
		look.coat = Color(0.55, 0.36, 0.24)
		look.mane = Color(0.15, 0.12, 0.14)
		look.race = &"earth"
		look.marking = int(c[1])
		look.eye_shape = int(c[2])
		look.accessory = int(c[3])
		PonyPaintScript.apply(body, look)
		var view: Array = c[4]
		var dist: float = float(view[2]) / tan(deg_to_rad(cam.fov * 0.5))
		cam.global_position = (view[1] as Vector3) + (view[0] as Vector3).normalized() * dist
		cam.look_at(view[1])
		cam.make_current()
		for k in 8:
			await process_frame
		var img := root.get_texture().get_image()
		var side := mini(img.get_width(), img.get_height())
		var crop := img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		crop.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		crop.save_png(ProjectSettings.globalize_path(OUT.path_join(String(c[0]) + ".png")))
		body.free()
	print("STYLE_ICONS_OK")
	quit(0)
