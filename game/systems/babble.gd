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
	_player.volume_db = -9.0
	add_child(_player)
	_player.play()
	_gen = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_rng.randomize()


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
	envelope = 0.0


func is_speaking() -> bool:
	return not _queue.is_empty()


func _syllable(c: String) -> Dictionary:
	var v := VOWELS[(c.unicode_at(0) + timbre) % VOWELS.size()]
	var question := false
	return {"f0": 220.0 * pitch * _rng.randf_range(0.92, 1.12), "f1": v.x * lerpf(1.0, pitch, 0.35),
		"f2": v.y * lerpf(1.0, pitch, 0.35), "dur": _rng.randf_range(0.06, 0.09), "rise": question}


func _process(_delta: float) -> void:
	if _gen == null:
		return
	var frames := _gen.get_frames_available()
	while frames > 0:
		if _queue.is_empty():
			envelope = move_toward(envelope, 0.0, 0.05)
			_gen.push_frame(Vector2.ZERO)
			frames -= 1
			continue
		var s: Dictionary = _queue[0]
		if s.has("pause"):
			_t += 1.0 / RATE
			_gen.push_frame(Vector2.ZERO)
			envelope = move_toward(envelope, 0.0, 0.01)
			if _t >= float(s["pause"]):
				_t = 0.0
				_queue.pop_front()
			frames -= 1
			continue
		var dur: float = s["dur"]
		var u := _t / dur
		var env := sin(clampf(u, 0.0, 1.0) * PI)
		env = env * env
		var f0: float = s["f0"] * (1.0 + 0.06 * sin(u * PI))
		_phase = fposmod(_phase + f0 / RATE, 1.0)
		var sample := 0.0
		# A handful of harmonics weighted by two formant bumps: a cartoon "voice".
		for h in range(1, 9):
			var fh := f0 * h
			var w := exp(-pow((fh - float(s["f1"])) / 260.0, 2.0)) + 0.7 * exp(-pow((fh - float(s["f2"])) / 380.0, 2.0)) + 0.08 / h
			sample += sin(TAU * _phase * h) * w
		sample *= 0.16 * env
		_gen.push_frame(Vector2(sample, sample))
		envelope = env
		_t += 1.0 / RATE
		if _t >= dur:
			_t = 0.0
			_queue.pop_front()
		frames -= 1
