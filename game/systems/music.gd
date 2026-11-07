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
	# THE COUNTERS (PS10 gap G5; FS5.2): the town's carefree tune at the Market, and the same
	# tune behind the Depot's glass (DEPOT_CUTOFF_HZ on the bus's low pass).
	&"market": "res://assets/audio/music/town_carefree.ogg",
	&"depot": "res://assets/audio/music/town_carefree.ogg",
	&"casino": "res://assets/audio/music/casino_backbay.ogg",
	&"works": "res://assets/audio/music/works_gone_beyond.ogg",
	&"stealth": "res://assets/audio/music/stealth_stay_the_course.ogg",
	&"ending_hope": "res://assets/audio/music/ending_promises.ogg",
	&"ending_sad": "res://assets/audio/music/ending_lost_time.ogg",
	&"drone": "res://assets/audio/music/dread_ossuary.ogg",
}
## THE STINGS (FS5.2; tools/make_stings.py): a short figure over the bed on the moments that
## matter. The bed dips DUCK_DB under it and comes back as it ends.
const STINGS := {
	&"first_catch": "res://assets/audio/music/sting_first_catch.wav",
	&"rare": "res://assets/audio/music/sting_rare.wav",
	&"delivery": "res://assets/audio/music/sting_delivery.wav",
	&"bloom": "res://assets/audio/music/sting_bloom.wav",
}
const DUCK_DB := 4.0
## The Depot's muffle: the low pass on the music bus while its counter is open.
const DEPOT_CUTOFF_HZ := 1100.0
var _muffled := false
const BUS := &"Music"
const FADE_SECONDS := 2.5
const SILENT_DB := -60.0

var context: StringName = &""
var dread := 0.0
## How far the bed is dipped for a sting, in dB (0 at rest).
var duck_db := 0.0:
	set(v):
		duck_db = v
		if _current != null and _current.playing and (_tween == null or not _tween.is_running()):
			_current.volume_db = _track_db()
var _sting: AudioStreamPlayer
var _duck_tween: Tween

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
	_sting = _player("Sting")
	_sting.volume_db = 0.0
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
		events.connect("delivered", func(_uid: String, _look: Dictionary) -> void: stinger(&"delivery"))
		events.connect("bloomed", func(_uid: String, _look: Dictionary) -> void: stinger(&"bloom"))
	set_dread(dread)
	if context != &"":
		var pending := context
		context = &""
		play_context(pending)


## On the way out, let go of the tracks: a player still holding a playing Ogg at quit leaves
## its playback objects for the engine to report as leaked.
func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
	if _duck_tween != null:
		_duck_tween.kill()
	for p in [_a, _b, _drone, _sting]:
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
	_muffled = ctx == &"depot"
	_apply_cutoff()
	if _a == null:
		# Asked before _ready (a scene's own _ready can run first): _ready starts it.
		return
	var next := _b if _current == _a else _a
	var path: String = TRACKS.get(ctx, "")
	if _tween != null:
		_tween.kill()
	# A fade cut short leaves the player it was fading out still going: stop it now, so a
	# change of context never leaves a third track playing under the other two.
	if next.playing:
		next.stop()
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
	# Dread may have moved during the fade: land on the level it asks for now.
	_tween.tween_callback(_settle)
	_current = next


func _settle() -> void:
	if _current != null and _current.playing:
		_current.volume_db = _track_db()


func set_dread(d: float) -> void:
	dread = clampf(d, 0.0, 1.0)
	if _current != null and _current.playing and (_tween == null or not _tween.is_running()):
		_current.volume_db = _track_db()
	if _drone == null:
		# Before _ready: the level is kept and applied when the players exist.
		return
	if dread > 0.05 and not _drone.playing and ResourceLoader.exists(TRACKS[&"drone"]):
		var s: AudioStream = load(TRACKS[&"drone"])
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_drone.stream = s
		_drone.play()
	_drone.volume_db = linear_to_db(maxf(0.0001, smoothstep(0.1, 0.9, dread))) - 4.0
	for p in [_a, _b]:
		(p as AudioStreamPlayer).pitch_scale = 1.0 - 0.04 * dread
	_apply_cutoff()


## The bus's low pass: dread closes it as it climbs, the Depot's glass to DEPOT_CUTOFF_HZ;
## whichever is lower wins.
func _apply_cutoff() -> void:
	if _lowpass == null:
		return
	var hz := lerpf(20000.0, 900.0, pow(dread, 1.4))
	if _muffled:
		hz = minf(hz, DEPOT_CUTOFF_HZ)
	_lowpass.cutoff_hz = hz


## True while the score is heard through the Depot's glass.
func muffled() -> bool:
	return _muffled


## The cozy track's level: full at dread 0, sinking under the drone as it climbs, and dipped
## under a sting.
func _track_db() -> float:
	return linear_to_db(maxf(0.0001, 1.0 - 0.75 * dread)) + duck_db


## Play the sting `id` over the bed. False for one this build does not have.
func stinger(id: StringName) -> bool:
	var path: String = STINGS.get(id, "")
	if path == "" or not ResourceLoader.exists(path) or _sting == null:
		return false
	# A batch of deliveries is one sting, not three on top of each other.
	if _sting.playing and _sting.stream != null and _sting.stream.resource_path == path:
		return true
	_sting.stream = load(path)
	_sting.play()
	var seconds := sting_seconds(id)
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(self, ^"duck_db", -DUCK_DB, 0.08)
	_duck_tween.tween_interval(maxf(0.0, seconds - 0.7))
	_duck_tween.tween_property(self, ^"duck_db", 0.0, 0.6)
	return true


## How long the sting `id` runs, in seconds (0 for none).
func sting_seconds(id: StringName) -> float:
	var path: String = STINGS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	var st: AudioStream = load(path)
	return st.get_length() if st != null else 0.0


func stop_all() -> void:
	play_context(&"")
	if _drone != null:
		_drone.stop()
