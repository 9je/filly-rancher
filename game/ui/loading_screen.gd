class_name LoadingScreen
extends CanvasLayer
## THE LOADING SCREEN (docs/playtest_fixes/loading.md). The owner's playtest note: "No
## loading screen after New Game. I thought it froze." The title's New game used to call
## change_scene_to_file(), which loads world/ranch.tscn on the main thread, and the ranch's
## own _ready() then built the whole valley in one go: the window showed the title, unmoving,
## for half a minute.
##
## WHAT IT DOES. LoadingScreen.change_scene() puts this layer over everything, loads the
## next scene a dependency at a time on the main thread (game/ui/staged_loader.gd, its
## progress on the bar; never on a worker thread, which could hang for good), changes to
## it, and then stays up while the arriving scene builds itself: a scene
## that claim()s the screen reports its own boot steps with report() and calls release() when
## the player can play; one that does not claim it is shown as soon as it is in. The screen
## lives under the tree's root, not under either scene, so it survives the change.
##
## EVERY TRANSITION GOES THROUGH HERE: New game and Continue (game/ui/title_screen.gd), the
## pause menu's Load game and the lift to the Rainbow Factory (game/world/ranch.gd), and the
## ride back down (game/world/factory_run.gd). Automated runs never see it: a headless boot
## changes scene the old way, so no gate's timing moves.

const GROUP := &"loading_screen"

## The share of the bar that the staged load of the scene file fills; the arriving scene's
## own boot steps fill the rest.
const LOAD_SHARE := 0.3
const FADE_SECONDS := 0.35
## FILLY_LOADING_TRACE=1 prints every step with its time (the numbers in the doc).
const TRACE_ENV := "FILLY_LOADING_TRACE"

## The two looks: the cozy valley, and the lift up into the Factory.
enum Look { RANCH, FACTORY }

const SKY_TOP := Color(0.38, 0.68, 0.95, 1.0)
const SKY_BOTTOM := Color(0.86, 0.93, 0.99, 1.0)
const GROUND := Color(0.52, 0.78, 0.44, 1.0)
const GROUND_FAR := Color(0.62, 0.84, 0.52, 1.0)
const FACTORY_TOP := Color(0.16, 0.12, 0.24, 1.0)
const FACTORY_BOTTOM := Color(0.55, 0.36, 0.58, 1.0)
const FACTORY_GROUND := Color(0.22, 0.20, 0.27, 1.0)
const CLOUD := Color(1.0, 1.0, 1.0, 1.0)
const CLOUD_SHADE := Color(0.86, 0.91, 0.97, 1.0)
const FACTORY_CLOUD := Color(0.46, 0.38, 0.52, 1.0)
const FACTORY_CLOUD_SHADE := Color(0.36, 0.29, 0.42, 1.0)
## The six bands of the rainbow the bar fills with. In the valley it is a rainbow; on the
## way up to the Factory it is the same rainbow, which is the joke.
const BANDS: Array[Color] = [Color(0.96, 0.33, 0.36), Color(1.0, 0.62, 0.25),
	Color(1.0, 0.86, 0.30), Color(0.45, 0.82, 0.42), Color(0.35, 0.62, 0.96),
	Color(0.66, 0.45, 0.90)]
## KEY ART (P8 S10; owner playtest 2026-11-08 item 67: "still felt kind of cheap"; references
## Hades, Stardew): a painted-looking still of the valley itself, captured from the game at its
## best hour (scenes/test/key_art_shot.gd), drifting in slowly behind the title, with one tip
## and a slim rainbow bar along the bottom. Without the picture, the drawn valley below.
const ART := {
	Look.RANCH: "res://assets/ui/loading_ranch.png",
	Look.FACTORY: "res://assets/ui/loading_factory.png",
}
const TIPS: Array[String] = [
	"A happy pony Blooms sooner. A full pen is not a happy pen.",
	"Every pony has a favourite food. Her card says which.",
	"Skittish ponies bolt if they see you coming. Walk up behind them.",
	"Bramble buys gems at the Market. The Depot takes ponies.",
	"Sleep at the house to end the day. It saves, too.",
	"The Company only wants ponies who have found their colour.",
	"Hold the beam on her until she is lifted, and she is yours.",
]
const BAR_WOOD := Color(0.31, 0.20, 0.13, 1.0)
const BAR_TRACK := Color(1.0, 0.98, 0.93, 0.95)

## One cloud = three puffs: x fraction, y fraction, radius as a fraction of the width, the
## creation backdrop's own clouds, drifting.
const CLOUDS: Array[Vector3] = [
	Vector3(0.13, 0.18, 0.055), Vector3(0.18, 0.16, 0.070), Vector3(0.24, 0.19, 0.048),
	Vector3(0.62, 0.11, 0.046), Vector3(0.67, 0.09, 0.062), Vector3(0.72, 0.12, 0.040),
	Vector3(0.86, 0.31, 0.038), Vector3(0.90, 0.29, 0.052), Vector3(0.95, 0.32, 0.034),
]

const MenuStyleScript := preload("res://ui/menu_style.gd")
const StagedLoaderScript := preload("res://ui/staged_loader.gd")
const HouseStyleScript := preload("res://ui/house_style.gd")
const LogotypeScript := preload("res://ui/logotype.gd")
## Milliseconds of each frame the staged load may spend before the screen draws again. A
## single resource can take longer (ranch.gd compiles in about 0.6 s); the bar moves after it.
const LOAD_BUDGET_MS := 12.0

## The screen that is up, if any. Untyped and built through load() rather than through the
## class name, so the screen works on a checkout whose class cache has not been rebuilt yet.
static var _current = null
const SELF_PATH := "res://ui/loading_screen.gd"

var scene_path := ""
var look: Look = Look.RANCH
var headline := ""

enum State { LOADING, INSTANCING, SWITCHING, ARRIVING, FADING }
var _state: State = State.LOADING
var _target := 0.0
var _shown := 0.0
var _caption := ""
var _claimed := false
var _loader = null
var _packed: PackedScene = null
var _released := false
var _frames_in := 0
var _alpha := 1.0
var _t := 0.0
var _trace := false
var _t0 := 0
var _last_step_ms := 0
var _canvas: Control
var _frame: Panel
var _track: Panel
var _fill: VBoxContainer
var _shine: ColorRect
var _sparkle: Control
var _title: Label
var _headline: Label
var _caption_label: Label
var _percent: Label
var _art: Texture2D
var _tip: Label
## The drawn name (game/ui/logotype.gd), the title screen's own, over the art.
var _logo: Control


## Change to `path` behind the loading screen. The one door every interactive transition
## uses; returns the screen (already up, from this frame on).
static func change_scene(tree: SceneTree, path: String, screen_look: Look = Look.RANCH,
		line: String = "") -> CanvasLayer:
	if is_instance_valid(_current) and not _current._released:
		return _current
	var screen = load(SELF_PATH).new()
	screen.scene_path = path
	screen.look = screen_look
	screen.headline = line
	screen.name = "LoadingScreen"
	tree.root.add_child(screen)
	return screen


## Whether a loading screen is up and waiting for the scene that is arriving.
static func active() -> bool:
	return is_instance_valid(_current) and not _current._released


## The arriving scene says it will report its boot and release the screen itself. False
## when there is no screen (a gate, a headless run): that scene then boots exactly as before.
static func claim() -> bool:
	if not active():
		return false
	_current._claimed = true
	return true


## One boot step: `fraction` of the arriving scene's own boot is done.
static func report(fraction: float, caption: String) -> void:
	if not active():
		return
	_current._step(fraction, caption)


## The arriving scene is playable: fade the screen out.
static func release() -> void:
	if not active():
		return
	_current._step(1.0, "")
	_current._lift()
	_current._print_trace("done")


func is_showing() -> bool:
	return is_inside_tree() and _alpha > 0.0


## The bar's true value, 0 to 1 (what the bar is easing toward).
func progress() -> float:
	return _target


func caption() -> String:
	return _caption


func _ready() -> void:
	_current = self
	add_to_group(GROUP)
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_trace = OS.get_environment(TRACE_ENV) == "1"
	_t0 = Time.get_ticks_msec()
	_last_step_ms = _t0
	_build()
	_set_world_drawn(false)
	_caption = "Saddling up" if look == Look.RANCH else "Riding the lift up"
	_refresh_text()
	# Already in memory (Load game reloads the scene that is running): nothing to stage.
	if not ResourceLoader.has_cached(scene_path):
		_loader = StagedLoaderScript.new(scene_path)


func _exit_tree() -> void:
	_set_world_drawn(true)
	if _current == self:
		_current = null


## The screen starts to fade: the world behind it is drawn again from this frame.
func _lift() -> void:
	_released = true
	_state = State.FADING
	_set_world_drawn(true)
	# A click on what is underneath (the creator's "This is me") goes through the fade.
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE


## NOTHING 3D IS DRAWN WHILE THE SCREEN IS UP. The screen is opaque, so the world behind it
## is never seen, and drawing it costs the main thread: every boot step that reads a mesh
## back (the fences, the props' colliders, the dressing; hundreds of reads) waits for the
## render thread to finish its frame, and a frame of the whole valley is a long wait.
## Measured in docs/playtest_fixes/loading.md.
func _set_world_drawn(drawn: bool) -> void:
	if is_inside_tree():
		get_tree().root.disable_3d = not drawn


func _build() -> void:
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)

	var art_path: String = ART.get(look, "")
	if art_path != "" and ResourceLoader.exists(art_path):
		_art = load(art_path) as Texture2D
	_build_bar()
	_title = _label(MenuStyleScript.title_font(), 96 if _art != null else 84, MenuStyleScript.COLOR_TITLE)
	_title.text = "Filly Rancher"
	# THE NAME IS THE LOGOTYPE (Fable AAA review round 1, #9), the same drawing the title
	# screen wears; the Label keeps the words for a reader of the tree and is not shown.
	_title.visible = false
	_logo = LogotypeScript.new()
	_logo.name = "Logotype"
	_canvas.add_child(_logo)
	_headline = _label(MenuStyleScript.title_font(), 32, HouseStyleScript.GOLD)
	_headline.add_theme_constant_override(&"outline_size", 10)
	_headline.add_theme_color_override(&"font_outline_color", HouseStyleScript.PLUM_DARK)
	_headline.text = headline if headline != "" else \
		("Off to the ranch" if look == Look.RANCH else "Up to the Rainbow Factory")
	_caption_label = _label(MenuStyleScript.numeral_font(), 26, MenuStyleScript.COLOR_NAME)
	_percent = _label(MenuStyleScript.numeral_font(), 26, MenuStyleScript.COLOR_VALUE)
	_tip = _label(MenuStyleScript.numeral_font(), 24, Color(1.0, 0.97, 0.9, 0.92))
	# A different tip each time, by the clock: no random generator lives under game/ui/.
	_tip.text = TIPS[int(Time.get_unix_time_from_system()) % TIPS.size()] \
		if look == Look.RANCH else ""
	_tip.visible = _art != null
	# The tip is a card: a lightbulb on a cream disc, the line on the HUD's plum pill.
	_tip.add_theme_stylebox_override(&"normal", HouseStyleScript.pill_box(26, 0.9, Vector2(22, 10)))
	(_tip.get_theme_stylebox(&"normal") as StyleBoxFlat).content_margin_left = 22.0 + TIP_ICON + 14.0
	HouseStyleScript.ink_label(_tip, 24, HouseStyleScript.CREAM)
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bulb := Control.new()
	bulb.name = "Bulb"
	bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulb.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(TIP_ICON, TIP_ICON))
		bulb.draw_style_box(HouseStyleScript.disc_box(TIP_ICON, HouseStyleScript.KEY_FACE,
			HouseStyleScript.GOLD, 3), r)
		IconSet.draw(bulb, "hint", r.grow(-8.0)))
	_tip.add_child(bulb)
	_tip.resized.connect(func() -> void:
		bulb.position = Vector2(16.0, (_tip.size.y - TIP_ICON) * 0.5))
	if _art != null:
		for l: Label in [_title, _headline, _tip, _caption_label, _percent]:
			l.add_theme_color_override(&"font_shadow_color", Color(0.08, 0.04, 0.12, 0.75))
			l.add_theme_constant_override(&"shadow_offset_x", 0)
			l.add_theme_constant_override(&"shadow_offset_y", 3)
			l.add_theme_constant_override(&"shadow_outline_size", 6)
	_canvas.resized.connect(_layout)
	_layout()


const TIP_ICON := 44.0


func _label(font: Font, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyleScript.style_label(l, size, colour)
	l.add_theme_font_override(&"font", font)
	_canvas.add_child(l)
	return l


func _bar_rect() -> Rect2:
	var s := _canvas.size
	if _art != null:
		# Slim, along the bottom, under the tip: the picture is the screen, not the bar. It
		# keeps to the left half with the name and the tip, clear of the key art's hero at the
		# right third (Fable AAA round 6).
		return Rect2(Vector2(s.x * 0.06, s.y * 0.9), Vector2(s.x * 0.52, clampf(s.y * 0.014, 10.0, 18.0)))
	var w := clampf(s.x * 0.46, 320.0, 900.0)
	var h := clampf(s.y * 0.06, 28.0, 56.0)
	return Rect2(Vector2((s.x - w) * 0.5, s.y * 0.53), Vector2(w, h))


## THE BAR: a wooden frame, a cream track, and the rainbow filling it, clipped to the track's
## rounded ends (clip_children), with a shine across the top and a star riding the front.
func _build_bar() -> void:
	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wood := StyleBoxFlat.new()
	# The house frame: plum with a gold edge, the casino's own, round the rainbow.
	wood.bg_color = HouseStyleScript.PLUM_DARK
	wood.border_color = HouseStyleScript.GOLD
	wood.set_border_width_all(2)
	wood.set_corner_radius_all(40)
	wood.shadow_color = Color(0, 0, 0, 0.22)
	wood.shadow_size = 10
	wood.shadow_offset = Vector2(0, 5)
	_frame.add_theme_stylebox_override(&"panel", wood)
	_canvas.add_child(_frame)
	_track = Panel.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cream := StyleBoxFlat.new()
	cream.bg_color = BAR_TRACK
	cream.set_corner_radius_all(34)
	_track.add_theme_stylebox_override(&"panel", cream)
	_track.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_canvas.add_child(_track)
	_fill = VBoxContainer.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.add_theme_constant_override(&"separation", 0)
	_track.add_child(_fill)
	for c: Color in BANDS:
		var band := ColorRect.new()
		band.color = c
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_fill.add_child(band)
	_shine = ColorRect.new()
	_shine.color = Color(1, 1, 1, 0.26)
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_shine)
	_sparkle = Control.new()
	_sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle.draw.connect(_draw_sparkle)
	_canvas.add_child(_sparkle)


func _place_fill() -> void:
	if _track == null:
		return
	var r := _bar_rect()
	var w := r.size.x * clampf(_shown, 0.0, 1.0)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(w, r.size.y)
	_shine.position = Vector2(r.size.y * 0.3, r.size.y * 0.14)
	_shine.size = Vector2(maxf(0.0, w - r.size.y * 0.6), r.size.y * 0.16)
	_sparkle.position = Vector2.ZERO
	_sparkle.size = _canvas.size
	_sparkle.queue_redraw()


func _layout() -> void:
	var s := _canvas.size
	var bar := _bar_rect()
	_frame.position = bar.position - Vector2(7.0, 7.0)
	_frame.size = bar.size + Vector2(14.0, 14.0)
	var wood := _frame.get_theme_stylebox(&"panel") as StyleBoxFlat
	wood.set_corner_radius_all(int(_frame.size.y * 0.5))
	_track.position = bar.position
	_track.size = bar.size
	var cream := _track.get_theme_stylebox(&"panel") as StyleBoxFlat
	cream.set_corner_radius_all(int(bar.size.y * 0.5))
	_place_fill()
	if _art != null:
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_title.position = Vector2(s.x * 0.06, s.y * 0.07)
		_title.size = Vector2(s.x * 0.6, 116.0)
		_logo.size = Vector2(s.x * 0.36, s.x * 0.36 * 300.0 / 700.0)
		_logo.position = Vector2(s.x * 0.05, s.y * 0.05)
		_headline.position = Vector2(s.x * 0.06 + 4.0, _logo.position.y + _logo.size.y + 6.0)
		_headline.size = Vector2(s.x * 0.6, 40.0)
		_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tip_w := _tip.get_theme_font(&"font").get_string_size(_tip.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _tip.get_theme_font_size(&"font_size")).x
		_tip.size = Vector2(tip_w + 22.0 + TIP_ICON + 14.0 + 26.0, 64.0)
		_tip.position = Vector2(bar.position.x, bar.position.y - 132.0)
		_caption_label.position = Vector2(bar.position.x, bar.position.y - 46.0)
		_caption_label.size = Vector2(bar.size.x * 0.8, 36.0)
		_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_percent.position = Vector2(bar.end.x - bar.size.x * 0.2, bar.position.y - 46.0)
		_percent.size = Vector2(bar.size.x * 0.2, 36.0)
		_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		return
	_title.position = Vector2(0.0, s.y * 0.25)
	_title.size = Vector2(s.x, 104.0)
	_logo.size = Vector2(s.x * 0.4, s.x * 0.4 * 300.0 / 700.0)
	_logo.position = Vector2((s.x - _logo.size.x) * 0.5, s.y * 0.53 - _logo.size.y - 60.0)
	_headline.position = Vector2(0.0, s.y * 0.53 - 54.0)
	_headline.size = Vector2(s.x, 40.0)
	_caption_label.position = Vector2(bar.position.x + 4.0, bar.end.y + 18.0)
	_caption_label.size = Vector2(bar.size.x * 0.8, 36.0)
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_percent.position = Vector2(bar.end.x - bar.size.x * 0.2 - 4.0, bar.end.y + 18.0)
	_percent.size = Vector2(bar.size.x * 0.2, 36.0)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _step(fraction: float, caption_text: String) -> void:
	var v := LOAD_SHARE + (1.0 - LOAD_SHARE) * clampf(fraction, 0.0, 1.0)
	# Never backwards, and every step a little forwards, so a step is always visible.
	_target = maxf(v, minf(1.0, _target + 0.0005))
	if caption_text != "" and caption_text != _caption:
		_print_trace(_caption)
		_caption = caption_text
	_refresh_text()


func _print_trace(what: String) -> void:
	if not _trace:
		return
	var now := Time.get_ticks_msec()
	print("LOADING_TRACE %6d ms  +%5d ms  %s" % [now - _t0, now - _last_step_ms, what])
	_last_step_ms = now


func _refresh_text() -> void:
	if _caption_label == null:
		return
	_caption_label.text = _caption + "..." if _caption != "" else ""
	_percent.text = "%d%%" % roundi(_target * 100.0)


func _process(delta: float) -> void:
	_t += delta
	match _state:
		State.LOADING:
			_poll_load()
		State.INSTANCING:
			_poll_instance()
		State.SWITCHING:
			# change_scene_to_packed() swaps at the end of the frame it is called in.
			_frames_in += 1
			if _frames_in >= 2:
				_state = State.ARRIVING
		State.ARRIVING:
			if not _claimed:
				# A scene that does not report (the Factory): it is in, so it is up.
				_step(1.0, "")
				_lift()
				_print_trace("done (unclaimed)")
		State.FADING:
			if absf(_shown - _target) < 0.01:
				_alpha = maxf(0.0, _alpha - delta / FADE_SECONDS)
				if _alpha <= 0.0:
					queue_free()
	_shown = move_toward(_shown, _target, delta * 1.6)
	_shown = lerpf(_shown, _target, minf(1.0, delta * 8.0))
	_canvas.modulate.a = _alpha
	_canvas.queue_redraw()
	_place_fill()


func _poll_load() -> void:
	var res: Resource = null
	if _loader == null:
		res = load(scene_path)
	else:
		if not _loader.step(LOAD_BUDGET_MS):
			_target = maxf(_target, LOAD_SHARE * 0.8 * float(_loader.progress()))
			_refresh_text()
			return
		res = _loader.result()
		_loader = null
		if res == null:
			push_error("LoadingScreen: the staged load of %s failed; loading it directly"
				% scene_path)
			res = load(scene_path)
	_target = maxf(_target, LOAD_SHARE * 0.8)
	_print_trace("scene file loaded")
	_caption = "Saddling up" if look == Look.RANCH else "Riding the lift up"
	_refresh_text()
	# INSTANCED ON THE NEXT FRAME, ON THE MAIN THREAD. It used to be a WorkerThreadPool task;
	# with everything already loaded the ranch instances in a few milliseconds, and a thread
	# is one more thing that could stop and never come back. Nothing is in the tree until
	# change_scene_to_node(), below.
	_packed = res as PackedScene
	_state = State.INSTANCING


func _poll_instance() -> void:
	var instance: Node = _packed.instantiate() if _packed != null else null
	_target = maxf(_target, LOAD_SHARE)
	_print_trace("scene instanced")
	_refresh_text()
	_state = State.SWITCHING
	var tree := get_tree()
	tree.paused = false
	if instance == null:
		push_error("LoadingScreen: %s did not instance; changing to it directly" % scene_path)
		tree.change_scene_to_file(scene_path)
		return
	tree.change_scene_to_node(instance)


## Nothing gets past the screen while it is up: no menu opens behind it, no key reaches the
## world it is building.
func _input(event: InputEvent) -> void:
	if is_showing() and not _released:
		get_viewport().set_input_as_handled()


# --- drawing --------------------------------------------------------------------------

func _draw_canvas() -> void:
	var s := _canvas.size
	if _art != null:
		_draw_art(s)
		return
	var factory := look == Look.FACTORY
	var top := FACTORY_TOP if factory else SKY_TOP
	var bottom := FACTORY_BOTTOM if factory else SKY_BOTTOM
	var horizon := s.y * 0.80
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0.0),
		Vector2(s.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([top, top, bottom, bottom]))
	# The hills: two rolling bands, far and near, as the show paints Ponyville's.
	_hill(s, horizon - s.y * 0.03, s.y * 0.05, 1.3, 0.4,
		Color(0.27, 0.22, 0.33) if factory else GROUND_FAR)
	_hill(s, horizon + s.y * 0.01, s.y * 0.04, 2.1, 1.7,
		FACTORY_GROUND if factory else GROUND)
	_canvas.draw_rect(Rect2(0.0, horizon + s.y * 0.03, s.x, s.y), FACTORY_GROUND if factory else GROUND)
	# The clouds drift, so the screen is visibly alive between steps.
	var drift := fmod(_t * 0.012, 1.0)
	for puff: Vector3 in CLOUDS:
		var x := fposmod(puff.x + drift, 1.2) - 0.1
		var centre := Vector2(x * s.x, puff.y * s.y)
		var radius: float = puff.z * s.x
		_canvas.draw_circle(centre + Vector2(0.0, radius * 0.18), radius,
			FACTORY_CLOUD_SHADE if factory else CLOUD_SHADE)
	for puff: Vector3 in CLOUDS:
		var x := fposmod(puff.x + drift, 1.2) - 0.1
		_canvas.draw_circle(Vector2(x * s.x, puff.y * s.y), puff.z * s.x,
			FACTORY_CLOUD if factory else CLOUD)


## The key art, covering the screen, pushing in slowly (a Ken Burns drift, so the screen is
## alive between load steps), with a dark band rising from the bottom for the words to sit on.
func _draw_art(s: Vector2) -> void:
	var tex := _art.get_size()
	var zoom := 1.03 + 0.05 * clampf(_t / 24.0, 0.0, 1.0)
	var cover := maxf(s.x / tex.x, s.y / tex.y) * zoom
	var size := tex * cover
	var drift := Vector2(-0.012 * s.x * clampf(_t / 24.0, 0.0, 1.0), 0.0)
	_canvas.draw_texture_rect(_art, Rect2((s - size) * 0.5 + drift, size), false)
	var fade_top := s.y * 0.58
	var dark := Color(0.09, 0.05, 0.13, 0.86)
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, fade_top), Vector2(s.x, fade_top),
		Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([Color(dark, 0.0), Color(dark, 0.0), dark, dark]))
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.7, 0),
		Vector2(s.x * 0.5, s.y * 0.32), Vector2(0, s.y * 0.38)]),
		PackedColorArray([Color(dark, 0.5), Color(dark, 0.0), Color(dark, 0.0), Color(dark, 0.0)]))


func _hill(s: Vector2, base: float, amp: float, waves: float, phase: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := s.x * float(i) / float(steps)
		pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(phase + waves * TAU * float(i) / float(steps)))))
	pts.append(Vector2(s.x, s.y))
	pts.append(Vector2(0.0, s.y))
	_canvas.draw_colored_polygon(pts, colour)


func _draw_sparkle() -> void:
	if _shown <= 0.002:
		return
	var r := _bar_rect()
	var tip := Vector2(r.position.x + r.size.x * clampf(_shown, 0.0, 1.0),
		r.get_center().y + sin(_t * 6.0) * r.size.y * 0.1)
	_star(tip, r.size.y * (0.62 + 0.08 * sin(_t * 9.0)), _t * 2.0)


func _star(at: Vector2, size: float, spin: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := spin + TAU * float(i) / 10.0 - PI * 0.5
		var rad := size if i % 2 == 0 else size * 0.45
		pts.append(at + Vector2(cos(a), sin(a)) * rad)
	_sparkle.draw_colored_polygon(pts, Color(1.0, 0.97, 0.80))
	var outline := pts.duplicate()
	outline.append(pts[0])
	_sparkle.draw_polyline(outline, BAR_WOOD, 2.5, true)
