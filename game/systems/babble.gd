class_name Babble
extends Node
## A PONY'S VOICE AS CARTOON BABBLE: a short formant-shaped syllable per letter group, at
## her own pitch and timbre (CharacterDef.voice_pitch / voice_timbre), synthesised live
## into an AudioStreamGenerator. Never a recording and never a horse sound
## (feedback memory: no realistic pony vocals); the real voice-line hook is `line_stream`,
## which plays instead when a recorded line exists.
##
## `envelope` (0..1) follows the syllable's loudness so the talk box can open her jaw.

const RATE := 22050.0
## Vowel formant pairs (Hz) the syllables cycle through: a, e, i, o, u-ish.
const VOWELS: Array[Vector2] = [Vector2(800, 1200), Vector2(500, 1900), Vector2(320, 2300),
	Vector2(500, 900), Vector2(350, 800)]

@export var bus: StringName = &"Voice"
## Heard at all (Settings.pony_chatter, off by default). Silent, she still "speaks": the queue
## runs and `envelope` still opens the jaw with the words.
static var audible := false
const VOLUME_DB := -9.0
var pitch := 1.0
var timbre := 0
var envelope := 0.0

var _player: AudioStreamPlayer
var _gen: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []
var _phase := 0.0
var _t := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.25
	_player.stream = stream
	if AudioServer.get_bus_index(bus) >= 0:
		_player.bus = bus
	_player.volume_db = VOLUME_DB if audible else -80.0
	add_child(_player)
	_player.play()
	_gen = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_rng.randomize()


## THE EXIT HANG (DECISIONS.md, 2026-10-23). Godot's AudioStreamGeneratorPlayback holds its
## AudioStreamGenerator by a RAW POINTER (servers/audio/effects/audio_stream_generator.h) and
## reads the generator's rate on every mix. Stopping a player does not drop its playback at
## once: the server marks it FADE_OUT_TO_DELETION and mixes it one more time. Freeing this node
## freed the generator (the player's `stream` was its only reference) before that last mix, so
## the mix read the rate out of freed memory; a garbage rate makes the resampler's catch-up
## loop all but endless while it holds the audio lock, and then quit()'s join on the audio
## thread (or any AudioServer call that needs the lock) waits forever. Reproduced with a live
## generator at a 1e15 rate: the frames run, then the process never exits.
##
## So a leaving Babble's generator is BURIED rather than dropped: held, with an extra
## reference, until the server is long done with it (BURY_SECONDS), and released by a later
## burial. Whatever is still buried at shutdown stays referenced on purpose: GDScript is torn
## down before the AudioServer (main/main.cpp, Main::cleanup), so releasing them then would
## reopen the same race at exit, which is where the hang was first seen.
const BURY_SECONDS := 1.0
static var _graveyard: Array = []


## Back in the tree after a reparent: _ready() does not run twice, so restart the stream.
func _enter_tree() -> void:
	if _player != null and _player.is_inside_tree() and not _player.playing:
		_player.play()
		_gen = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _exit_tree() -> void:
	if _player == null or _player.stream == null:
		return
	_player.stop()
	var now := Time.get_ticks_msec() / 1000.0
	while not _graveyard.is_empty() and now - float(_graveyard[0][1]) > BURY_SECONDS:
		var old: RefCounted = _graveyard.pop_front()[0]
		old.unreference()
	var stream: RefCounted = _player.stream
	stream.reference()
	_graveyard.append([stream, now])


func set_voice(p: float, t: int) -> void:
	pitch = p
	timbre = t


## Queue the syllables for `text` (about one per two or three letters, punctuation pauses).
func say(text: String) -> void:
	_rng.seed = hash(text) ^ timbre
	var count := 0
	for i in range(text.length()):
		var c := text[i]
		if c in ".!?":
			_queue.append({"pause": 0.16})
		elif c == ",":
			_queue.append({"pause": 0.08})
		elif c != " " and count % 2 == 0:
			_queue.append(_syllable(c))
		if c != " ":
			count += 1


func stop() -> void:
	_queue.clear()
	_pos = _cur_len
	envelope = 0.0


func is_speaking() -> bool:
	return not _queue.is_empty() or (_pos < _cur_len and _cur != _silence)


func _syllable(c: String) -> Dictionary:
	var v := VOWELS[(c.unicode_at(0) + timbre) % VOWELS.size()]
	var question := false
	# QUANTISED, so the syllables a voice can say are a finite set and each is rendered once
	# (see _render): pitch to 6 Hz steps, length to 10 ms.
	var f0 := snappedf(220.0 * pitch * _rng.randf_range(0.92, 1.12), 6.0)
	return {"f0": f0, "f1": snappedf(v.x * lerpf(1.0, pitch, 0.35), 10.0),
		"f2": snappedf(v.y * lerpf(1.0, pitch, 0.35), 10.0),
		"dur": snappedf(_rng.randf_range(0.06, 0.09), 0.01), "rise": question}


var _silence := PackedVector2Array()
## What is being played now: a rendered syllable or a stretch of silence, and how far in.
var _cur := PackedVector2Array()
var _pos := 0
var _cur_len := 0
## Every syllable ever rendered, by its parameters: the voice is synthesised once per
## syllable shape, not once per sample per frame. That per-sample GDScript loop (eight
## harmonics, two formant bumps, at 22 kHz) was a 10 ms hitch on every buffer refill while
## anypony talked, found by the 60-pony check (scenes/test/perf.gd).
static var _rendered: Dictionary = {}


static func _render(s: Dictionary) -> PackedVector2Array:
	var key := "%s|%s|%s|%s" % [s.f0, s.f1, s.f2, s.dur]
	if _rendered.has(key):
		return _rendered[key]
	var dur: float = s.dur
	var n := int(dur * RATE)
	var out := PackedVector2Array()
	out.resize(n)
	var f0n: float = s.f0
	var w: PackedFloat32Array = []
	for h in range(1, 9):
		var fh := f0n * h
		w.append(exp(-pow((fh - float(s.f1)) / 260.0, 2.0)) + 0.7 * exp(-pow((fh - float(s.f2)) / 380.0, 2.0)) + 0.08 / h)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var env := sin(u * PI)
		env = env * env
		var f0 := f0n * (1.0 + 0.06 * sin(u * PI))
		phase = fposmod(phase + f0 / RATE, 1.0)
		var sample := 0.0
		for h in 8:
			sample += sin(TAU * phase * (h + 1)) * w[h]
		sample *= 0.16 * env
		out[i] = Vector2(sample, sample)
	_rendered[key] = out
	return out


func _next_piece() -> bool:
	if _queue.is_empty():
		return false
	var s: Dictionary = _queue.pop_front()
	if s.has("pause"):
		var n := int(float(s.pause) * RATE)
		if _silence.size() < n:
			_silence.resize(n)
			_silence.fill(Vector2.ZERO)
		_cur = _silence
		_cur_len = n
	else:
		_cur = _render(s)
		_cur_len = _cur.size()
	_pos = 0
	return true


func _process(_delta: float) -> void:
	if _player != null:
		_player.volume_db = VOLUME_DB if audible else -80.0
	if _gen == null:
		return
	var frames := _gen.get_frames_available()
	if frames <= 0:
		return
	while frames > 0:
		if _pos >= _cur_len and not _next_piece():
			# Nothing to say: the rest of the buffer is silence, in one push.
			if _silence.size() < frames:
				_silence.resize(frames)
				_silence.fill(Vector2.ZERO)
			_gen.push_buffer(_silence.slice(0, frames))
			envelope = move_toward(envelope, 0.0, 0.2)
			return
		var take := mini(frames, _cur_len - _pos)
		_gen.push_buffer(_cur.slice(_pos, _pos + take))
		# The mouth follows the sound: the envelope where this chunk ends.
		if _cur != _silence and _cur_len > 0:
			var u := float(_pos + take) / float(_cur_len)
			envelope = pow(sin(clampf(u, 0.0, 1.0) * PI), 2.0)
		else:
			envelope = move_toward(envelope, 0.0, 0.2)
		_pos += take
		frames -= take
