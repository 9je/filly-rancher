class_name BoutiqueStage
extends Node3D
## THE CREATOR'S STAGE IS A PLACE (Fable AAA round 4: "a flat green plane with a lone fence
## and a gradient sky in a wooden frame"; it asked for the show's Carousel Boutique). Built in
## code, all of it, round the turntable: the boutique's round wall in lavender stripes over a
## cream wainscot with a gold rail, a pink carpet, a fitting dais with a gold rim for her to
## stand on, a tall gold oval mirror on its stand, a sun hat on a stand, bolts of cloth, velvet
## drapes with gold tie-backs framing the view, all warm under a spot from above.
##
## TOON LIKE THE VALLEY. Every surface is a plain StandardMaterial3D handed to ToonStyler as a
## prop, so the stage wears the same banded light and ink line as the world she walks into.
##
## A FIXED SET, NO DICE (game/test/test_menu_sound.gd sweeps game/ui/ for a generator): every
## position below is a constant, so the stage photographs the same every time.

const WALL := Color(0.80, 0.70, 0.92)
const WALL_STRIPE := Color(0.88, 0.80, 0.97)
const WAINSCOT := Color(0.99, 0.95, 0.90)
const GOLD := Color(0.96, 0.78, 0.36)
const CARPET := Color(0.90, 0.62, 0.74)
const DAIS := Color(0.99, 0.94, 0.97)
const DAIS_TOP := Color(0.62, 0.36, 0.70)
const DRAPE := Color(0.33, 0.27, 0.66)
const GLASS := Color(0.78, 0.88, 0.98)
const FORM := Color(0.97, 0.66, 0.78)
const BOLTS: Array[Color] = [Color(0.40, 0.72, 0.86), Color(0.98, 0.84, 0.44),
	Color(0.62, 0.42, 0.82)]

## The turntable stands at the origin with her hooves at y = 0; the dais top is that floor.
const DAIS_TOP_Y := 0.0
const DAIS_H := 0.18
const FLOOR_Y := -0.18
const WALL_R := 3.8
const WALL_CENTRE := Vector3(0.0, 0.0, 0.6)
## The drapes frame the lens's view at its edges: their inner hem this far from the middle,
## this near the lens (the creator's camera stands at z 3.2).
const DRAPE_X := 0.78
const DRAPE_Z := 1.6


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	_floor()
	_dais()
	_wall()
	_mirror(Vector3(-1.9, FLOOR_Y, -1.5), deg_to_rad(28.0))
	_hat_stand(Vector3(1.95, FLOOR_Y, -1.3))
	_bolts(Vector3(1.25, FLOOR_Y, -2.15))
	_drape(-1.0)
	_drape(1.0)
	_valance()
	_lights()
	ToonStyler.style(self, &"prop", {}, 1.0)


static func mat(colour: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = Vector3.ONE
	m.roughness = 0.9
	return m


func _mesh(mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO,
		scale_by := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.scale = scale_by
	add_child(mi)
	return mi


func _floor() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.04
	disc.radial_segments = 48
	_mesh(disc, mat(CARPET), Vector3(0.0, FLOOR_Y - 0.02, 0.0))
	# A rug ring round the dais, a shade deeper, so the dais sits on something.
	var rug := CylinderMesh.new()
	rug.top_radius = 1.75
	rug.bottom_radius = 1.75
	rug.height = 0.02
	rug.radial_segments = 48
	_mesh(rug, mat(CARPET.darkened(0.16)), Vector3(0.0, FLOOR_Y + 0.005, 0.0))


func _dais() -> void:
	var body := CylinderMesh.new()
	body.top_radius = 1.2
	body.bottom_radius = 1.28
	body.height = DAIS_H
	body.radial_segments = 48
	_mesh(body, mat(DAIS), Vector3(0.0, DAIS_TOP_Y - DAIS_H * 0.5, 0.0))
	var top := CylinderMesh.new()
	top.top_radius = 1.08
	top.bottom_radius = 1.08
	top.height = 0.012
	top.radial_segments = 48
	_mesh(top, mat(DAIS_TOP), Vector3(0.0, DAIS_TOP_Y + 0.004, 0.0))
	var rim := TorusMesh.new()
	rim.inner_radius = 1.17
	rim.outer_radius = 1.24
	rim.rings = 64
	_mesh(rim, mat(GOLD), Vector3(0.0, DAIS_TOP_Y, 0.0))


## The wallpaper: lavender with paler stripes and a small gold diamond between them.
static func wallpaper() -> ImageTexture:
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := WALL if x < 32 else WALL_STRIPE
			var dx := absf(float(x) - 16.0)
			var dy := absf(float(y) - 32.0)
			if dx + dy * 0.6 < 5.0:
				c = GOLD
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## An inward-facing band of the round wall from angle `a0` to `a1` (radians about +Y, 0 on
## +X, the back of the room at -PI/2), `r` from the wall centre, `y0` to `y1` high, its
## texture repeated `rep` times round and `vrep` times up.
func _band(r: float, a0: float, a1: float, y0: float, y1: float, m: Material,
		rep: float = 1.0, vrep: float = 1.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var b0 := lerpf(a0, a1, t0)
		var b1 := lerpf(a0, a1, t1)
		var p0 := WALL_CENTRE + Vector3(cos(b0) * r, y0, sin(b0) * r)
		var p1 := WALL_CENTRE + Vector3(cos(b1) * r, y0, sin(b1) * r)
		var q0 := WALL_CENTRE + Vector3(cos(b0) * r, y1, sin(b0) * r)
		var q1 := WALL_CENTRE + Vector3(cos(b1) * r, y1, sin(b1) * r)
		var n0 := Vector3(-cos(b0), 0.0, -sin(b0))
		var n1 := Vector3(-cos(b1), 0.0, -sin(b1))
		# Facing the centre: wound so the inside is the front.
		for v: Array in [[p0, n0, Vector2(t0 * rep, vrep)], [q0, n0, Vector2(t0 * rep, 0.0)],
				[q1, n1, Vector2(t1 * rep, 0.0)], [p0, n0, Vector2(t0 * rep, vrep)],
				[q1, n1, Vector2(t1 * rep, 0.0)], [p1, n1, Vector2(t1 * rep, vrep)]]:
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)


func _wall() -> void:
	var a0 := deg_to_rad(-200.0)
	var a1 := deg_to_rad(20.0)
	var paper := mat(Color.WHITE, wallpaper())
	paper.texture_repeat = true
	_band(WALL_R, a0, a1, FLOOR_Y + 0.95, 7.0, paper, 26.0, 7.0)
	_band(WALL_R - 0.01, a0, a1, FLOOR_Y, FLOOR_Y + 0.95, mat(WAINSCOT))
	# The rail on the wainscot, and the skirting at the floor, in gold.
	_band(WALL_R - 0.03, a0, a1, FLOOR_Y + 0.9, FLOOR_Y + 1.0, mat(GOLD))
	_band(WALL_R - 0.03, a0, a1, FLOOR_Y, FLOOR_Y + 0.08, mat(GOLD.darkened(0.2)))
	# Panels on the wainscot: slim gold uprights.
	for k in 12:
		var a := lerpf(a0, a1, (float(k) + 0.5) / 12.0)
		var at := WALL_CENTRE + Vector3(cos(a) * (WALL_R - 0.04), FLOOR_Y + 0.47, sin(a) * (WALL_R - 0.04))
		var post := BoxMesh.new()
		post.size = Vector3(0.05, 0.8, 0.03)
		_mesh(post, mat(GOLD), at, Vector3(0.0, -a - PI * 0.5, 0.0))


## The tall oval mirror on its stand, turned `yaw` toward the dais.
func _mirror(at: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	add_child(holder)
	var centre := Vector3(0.0, 1.45, 0.0)
	var frame := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.6
	torus.rings = 48
	frame.mesh = torus
	frame.material_override = mat(GOLD)
	frame.position = centre
	frame.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	frame.scale = Vector3(1.0, 1.0, 1.55)
	holder.add_child(frame)
	var glass := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.52
	disc.bottom_radius = 0.52
	disc.height = 0.02
	disc.radial_segments = 48
	glass.mesh = disc
	var gm := mat(GLASS)
	gm.metallic = 0.4
	glass.material_override = gm
	glass.position = centre
	glass.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	glass.scale = Vector3(1.0, 1.0, 1.55)
	holder.add_child(glass)
	# Two streaks of light across the glass.
	for s: Array in [[Vector3(-0.12, 0.25, 0.02), 0.07], [Vector3(0.06, 0.05, 0.02), 0.04]]:
		var streak := MeshInstance3D.new()
		var q := BoxMesh.new()
		q.size = Vector3(s[1], 0.62, 0.005)
		streak.mesh = q
		streak.material_override = mat(Color(1.0, 1.0, 1.0))
		streak.position = centre + (s[0] as Vector3)
		streak.rotation.z = deg_to_rad(-28.0)
		holder.add_child(streak)
	# The stand: two gold legs splayed to the floor and a crest on top.
	for side: float in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var bar := CylinderMesh.new()
		bar.top_radius = 0.035
		bar.bottom_radius = 0.045
		bar.height = 1.1
		leg.mesh = bar
		leg.material_override = mat(GOLD.darkened(0.1))
		leg.position = Vector3(side * 0.45, 0.5, 0.0)
		leg.rotation.z = side * deg_to_rad(10.0)
		holder.add_child(leg)
	var crest := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.1
	gem.height = 0.2
	crest.mesh = gem
	crest.material_override = mat(Color(0.30, 0.55, 0.95))
	crest.position = centre + Vector3(0.0, 0.98, 0.0)
	holder.add_child(crest)


## A hat stand with one of the boutique's sun hats on it: a gold pole, a wide brim, a round
## crown and a ribbon with a bow's tails.
func _hat_stand(at: Vector3) -> void:
	var foot := CylinderMesh.new()
	foot.top_radius = 0.05
	foot.bottom_radius = 0.26
	foot.height = 0.06
	_mesh(foot, mat(GOLD.darkened(0.2)), at + Vector3(0.0, 0.03, 0.0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.035
	pole.height = 1.3
	_mesh(pole, mat(GOLD.darkened(0.2)), at + Vector3(0.0, 0.65, 0.0))
	var tilt := Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(8.0))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.52
	brim.bottom_radius = 0.56
	brim.height = 0.035
	brim.radial_segments = 40
	_mesh(brim, mat(FORM), at + Vector3(0.0, 1.32, 0.0), tilt)
	var crown := SphereMesh.new()
	crown.radius = 0.24
	crown.height = 0.36
	crown.is_hemisphere = true
	_mesh(crown, mat(FORM.lightened(0.08)), at + Vector3(0.0, 1.33, 0.0), tilt)
	var band := CylinderMesh.new()
	band.top_radius = 0.245
	band.bottom_radius = 0.25
	band.height = 0.07
	_mesh(band, mat(Color(0.40, 0.72, 0.86)), at + Vector3(0.0, 1.37, 0.0), tilt)
	var bow := SphereMesh.new()
	bow.radius = 0.07
	bow.height = 0.12
	_mesh(bow, mat(Color(0.40, 0.72, 0.86)), at + Vector3(0.18, 1.38, 0.17))
	var flower := SphereMesh.new()
	flower.radius = 0.07
	flower.height = 0.14
	_mesh(flower, mat(Color(0.98, 0.84, 0.44)), at + Vector3(-0.2, 1.42, 0.12))


func _bolts(at: Vector3) -> void:
	for i in BOLTS.size():
		var roll := CylinderMesh.new()
		roll.top_radius = 0.16
		roll.bottom_radius = 0.16
		roll.height = 1.0
		var y := 0.16 + float(i) * 0.3
		var x := 0.0 if i < 2 else 0.17
		_mesh(roll, mat(BOLTS[i]), at + Vector3(x + float(i % 2) * 0.33, y, 0.0),
			Vector3(0.0, deg_to_rad(18.0), PI * 0.5))


## A velvet drape at the frame's `side` edge (-1 left, +1 right): a folded sheet from the
## valance to the floor, caught back by a gold tie-back.
func _drape(side: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 24
	var rows := 20
	var width := 0.8
	var top := 2.6
	var tie := 0.9
	var pts: Array = []
	for j in rows + 1:
		var v := float(j) / float(rows)
		var y := lerpf(top, FLOOR_Y, v)
		# Pinched at the tie-back, fuller above and below it.
		var pinch := 1.0 - 0.55 * exp(-pow((y - tie) / 0.45, 2.0))
		var row: Array = []
		for i in cols + 1:
			var u := float(i) / float(cols)
			# The outer edge hangs straight; the inner hem is drawn back to the tie-back.
			var x := width * (1.0 - (1.0 - u) * pinch)
			var z := 0.09 * sin(u * TAU * 3.5) * (0.6 + 0.4 * pinch)
			row.append(Vector3(x, y, z))
		pts.append(row)
	for j in rows:
		for i in cols:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var c: Vector3 = pts[j + 1][i]
			var d: Vector3 = pts[j + 1][i + 1]
			var n := (b - a).cross(c - a).normalized()
			if n.z < 0.0:
				n = -n
			for p: Vector3 in [a, b, d, a, d, c]:
				st.set_normal(n)
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat(DRAPE)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	# The sheet's inner edge at x = 0 sits toward the middle of the view.
	mi.position = Vector3(side * DRAPE_X, 0.0, DRAPE_Z)
	mi.scale = Vector3(side, 1.0, 1.0)
	add_child(mi)
	var band := TorusMesh.new()
	band.inner_radius = 0.2
	band.outer_radius = 0.26
	_mesh(band, mat(GOLD), Vector3(side * (DRAPE_X + 0.58), tie, DRAPE_Z), Vector3(0.0, 0.0, PI * 0.5),
		Vector3(1.0, 1.0, 0.6))
	var tassel := SphereMesh.new()
	tassel.radius = 0.07
	tassel.height = 0.14
	_mesh(tassel, mat(GOLD), Vector3(side * (DRAPE_X + 0.5), tie - 0.3, DRAPE_Z + 0.08))


## The swag across the top of the view, in the drapes' velvet with a gold fringe.
func _valance() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	var left := -1.6
	var right := 1.6
	var top := 2.52
	for i in segs:
		var u0 := float(i) / float(segs)
		var u1 := float(i + 1) / float(segs)
		var x0 := lerpf(left, right, u0)
		var x1 := lerpf(left, right, u1)
		# Three scallops of cloth hanging from the rod.
		var d0 := 0.16 + 0.16 * absf(sin(u0 * PI * 3.0))
		var d1 := 0.16 + 0.16 * absf(sin(u1 * PI * 3.0))
		for p: Vector3 in [Vector3(x0, top, 0.0), Vector3(x1, top, 0.0),
				Vector3(x1, top - d1, 0.0), Vector3(x0, top, 0.0), Vector3(x1, top - d1, 0.0),
				Vector3(x0, top - d0, 0.0)]:
			st.set_normal(Vector3(0.0, 0.0, 1.0))
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat(DRAPE.darkened(0.08))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0.0, 0.0, DRAPE_Z + 0.02)
	add_child(mi)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.04
	rod.bottom_radius = 0.04
	rod.height = 3.4
	_mesh(rod, mat(GOLD), Vector3(0.0, top, DRAPE_Z + 0.05), Vector3(0.0, 0.0, PI * 0.5))


func _lights() -> void:
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, 4.2, 1.2)
	spot.rotation = Vector3(deg_to_rad(-76.0), 0.0, 0.0)
	spot.light_color = Color(1.0, 0.88, 0.72)
	spot.light_energy = 2.4
	spot.spot_range = 7.0
	spot.spot_angle = 30.0
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	add_child(spot)
	# A warm lamp glow on the back wall, left and right of the mirror.
	for x: float in [-2.4, 2.4]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 2.4, -1.8)
		lamp.light_color = Color(1.0, 0.82, 0.6)
		lamp.light_energy = 1.4
		lamp.omni_range = 4.5
		add_child(lamp)
