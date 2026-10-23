extends Node
## THE SCORE (autoload `Music`): one track per context, crossfaded, with the dread dial
## acting on whatever is playing (STORY.md section 9, GDD section 9):
##   - a drone (dread_ossuary) rises underneath as dread climbs, the cozy track sinking;
##   - a low-pass closes on the Music bus, so the warm top end drains away first;
##   - pitch sags a hair (at most 4 percent), the "a little too slow" the lift ride wants.
## Context is set by whoever owns the moment (`play_context(&"day")`), dread by
## Events.dread_changed. No class_name (an autoload of the same name would clash).

const TRACKS := {
	&"day": "res://assets/audio/music/day_morning.ogg",
	&"night": "res://assets/audio/music/night_evening.ogg",
	&"town": "res://assets/audio/music/town_carefree.ogg",
	&"casino": "res://assets/audio/music/casino_backbay.ogg",
	&"works": "res://assets/audio/music/works_gone_beyond.ogg",
	&"stealth": "res://assets/audio/music/stealth_stay_the_course.ogg",
	&"ending_hope": "res://assets/audio/music/ending_promises.ogg",
	&"ending_sad": "res://assets/audio/music/ending_lost_time.ogg",
	&"drone": "res://assets/audio/music/dread_ossuary.ogg",
}
const BUS := &"Music"
const FADE_SECONDS := 2.5
const SILENT_DB := -60.0

var context: StringName = &""
var dread := 0.0

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _current: AudioStreamPlayer
var _tween: Tween
var _lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _player("A")
	_b = _player("B")
	_drone = _player("Drone")
	_current = _a
	var bus := AudioServer.get_bus_index(BUS)
	if bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus)):
			var fx := AudioServer.get_bus_effect(bus, i)
			if fx is AudioEffectLowPassFilter:
				_lowpass = fx
		if _lowpass == null:
			_lowpass = AudioEffectLowPassFilter.new()
			_lowpass.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(bus, _lowpass)
	var events := get_node_or_null("/root/Events")
	if events != null:
		events.connect("dread_changed", set_dread)
	if context != &"":
		var pending := context
		context = &""
		play_context(pending)


## On the way out, let go of the tracks: a player still holding a playing Ogg at quit leaves
## its playback objects for the engine to report as leaked.
func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
	for p in [_a, _b, _drone]:
		if p != null:
			p.stop()
			p.stream = null


func _player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.volume_db = SILENT_DB
	if AudioServer.get_bus_index(BUS) >= 0:
		p.bus = BUS
	add_child(p)
	return p


## Crossfade to the track for `ctx` (no-op if it is already playing). &"" fades to silence.
func play_context(ctx: StringName) -> void:
	if ctx == context:
		return
	context = ctx
	if _a == null:
		# Asked before _ready (a scene's own _ready can run first): _ready starts it.
		return
	var next := _b if _current == _a else _a
	var path: String = TRACKS.get(ctx, "")
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if path != "" and ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		next.stream = stream
		next.volume_db = SILENT_DB
		next.play()
		_tween.tween_property(next, "volume_db", _track_db(), FADE_SECONDS)
	_tween.tween_property(_current, "volume_db", SILENT_DB, FADE_SECONDS)
	_tween.chain().tween_callback(_current.stop)
	_current = next


func set_dread(d: float) -> void:
	dread = clampf(d, 0.0, 1.0)
	if _current != null and _current.playing and (_tween == null or not _tween.is_running()):
		_current.volume_db = _track_db()
	if dread > 0.05 and not _drone.playing and ResourceLoader.exists(TRACKS[&"drone"]):
		var s: AudioStream = load(TRACKS[&"drone"])
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_drone.stream = s
		_drone.play()
	_drone.volume_db = linear_to_db(maxf(0.0001, smoothstep(0.1, 0.9, dread))) - 4.0
	for p in [_a, _b]:
		(p as AudioStreamPlayer).pitch_scale = 1.0 - 0.04 * dread
	if _lowpass != null:
		_lowpass.cutoff_hz = lerpf(20000.0, 900.0, pow(dread, 1.4))


## The cozy track's level: full at dread 0, sinking under the drone as it climbs.
func _track_db() -> float:
	return linear_to_db(maxf(0.0001, 1.0 - 0.75 * dread))


func stop_all() -> void:
	play_context(&"")
	_drone.stop()
