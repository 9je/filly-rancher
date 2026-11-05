class_name EyeFrame
extends RefCounted
## WHERE AN EYE TEXTURE DRAWS ITS PUPIL AND ITS IRIS: the check that every eye the roster
## ships has the show's pupil (tools/show_pupils.py redraws them; this is its mirror). A PonySFM eye draws a pupil nine tenths the width of its iris; on
## screen a pony looked out through two black discs ringed in colour (face close-ups,
## 2026-11-05). The show draws a big coloured iris with a pupil about half its width.
##
## measure() floods out from the pupil nearest the middle of the coloured disc: the black run
## is the pupil, the not-white run around it the iris (the sclera's white stops it). Radii are
## the half extents of each run, in UV, so a highlight inside the pupil does not shrink it.
## (Idea from home-equestria's show iris, which draws its pupil as a fitted ellipse.)

## The pupil's width as a share of the iris's, the way the show draws it.
const SHOW_PUPIL := 0.55  # tools/show_pupils.py SHOW_PUPIL
## Measured on a copy this size: enough for a pupil's edge, cheap on a whole roster.
const SAMPLE := 128


## {pupil_centre, pupil_radius, disc_radius} in UV, or {} when no pupil can be found.
static func measure(img: Image) -> Dictionary:
	if img == null or img.is_empty():
		return {}
	var src := img.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	src.resize(SAMPLE, SAMPLE, Image.INTERPOLATE_BILINEAR)
	var n := SAMPLE
	var kind := PackedByteArray()
	kind.resize(n * n)
	# 0 sclera (or outside), 1 iris, 2 pupil.
	var sum := Vector2.ZERO
	var count := 0
	for y in n:
		for x in n:
			var c := src.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var k := 0
			if c.a >= 0.5 and mn < 0.86:
				k = 2 if mx < 0.14 else 1
			kind[y * n + x] = k
			if k > 0:
				sum += Vector2(x, y)
				count += 1
	if count == 0:
		return {}
	var mid := sum / count
	# The pupil pixel nearest the middle of the disc.
	var seed := -1
	var best := INF
	for i in n * n:
		if kind[i] == 2:
			var d := Vector2(i % n, i / n).distance_squared_to(mid)
			if d < best:
				best = d
				seed = i
	if seed < 0:
		return {}
	var pupil := _flood(kind, n, seed, [2])
	var disc := _flood(kind, n, seed, [1, 2])
	var pr := (pupil.size + Vector2.ONE) * 0.5 / n
	var dr := (disc.size + Vector2.ONE) * 0.5 / n
	if pr.x <= 0.0 or dr.x <= pr.x * 0.99:
		return {}
	return {
		"pupil_centre": (pupil.position + (pupil.size + Vector2.ONE) * 0.5) / n,
		"pupil_radius": pr,
		"disc_radius": dr,
	}


## The bounding box of the run of `kinds` connected to `seed`, in pixels.
static func _flood(kind: PackedByteArray, n: int, seed: int, kinds: Array) -> Rect2:
	var seen := PackedByteArray()
	seen.resize(n * n)
	var stack: Array[int] = [seed]
	seen[seed] = 1
	var lo := Vector2i(n, n)
	var hi := Vector2i(-1, -1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % n
		var y := i / n
		lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
		hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + o.x
			var ny := y + o.y
			if nx < 0 or ny < 0 or nx >= n or ny >= n:
				continue
			var j := ny * n + nx
			if seen[j] == 0 and int(kind[j]) in kinds:
				seen[j] = 1
				stack.append(j)
	return Rect2(Vector2(lo), Vector2(hi - lo))


## The pupil's width as a share of the iris's, or -1.0 when there is no pupil to measure.
static func pupil_share(img: Image) -> float:
	var f := measure(img)
	if f.is_empty():
		return -1.0
	var pr: Vector2 = f.pupil_radius
	var dr: Vector2 = f.disc_radius
	return (pr.x / dr.x + pr.y / dr.y) * 0.5
