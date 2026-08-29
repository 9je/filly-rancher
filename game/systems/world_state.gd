class_name WorldState
extends RefCounted
## THE WORLD CLOCK, AS ARITHMETIC. Elapsed play time in, a phase of day and a kind of
## weather out. Both are pure functions of the save's seed and the clock, so the same
## save always shows the same sky, and a gate can pin any pair without touching anyone's
## file. Nothing here renders: game/world/sky_rig.gd reads this and moves the sun.
##
## THE CYCLE IS TWENTY REAL MINUTES, so a single sitting sees every phase; DAY is the
## longest because it is where the ranch work happens. Weather is rolled once per phase
## from the seed, the cycle index and the phase, never simulated, so a player who quits
## in a storm comes back to the same storm.

enum Phase { DAWN, DAY, DUSK, NIGHT }
enum Weather { CLEAR, RAIN, FOG, STORM }

const CYCLE_SECONDS := 1200.0
const PHASE_SECONDS: Array[float] = [120.0, 540.0, 120.0, 420.0]
const WEATHER_WEIGHTS: Array[int] = [55, 20, 15, 10]

const PHASE_NAMES: Array[String] = ["Dawn", "Day", "Dusk", "Night"]
const WEATHER_NAMES: Array[String] = ["clear", "rain", "fog", "storm"]

signal phase_changed(phase: int)
signal weather_changed(weather: int)

var _seed: int
var _elapsed := 0.0
var _phase: int = Phase.DAWN
var _weather: int = Weather.CLEAR
var _pinned := false


func _init(seed: int, elapsed: float = 0.0) -> void:
	_seed = seed
	_elapsed = maxf(0.0, elapsed)
	_phase = phase_at(_elapsed)
	_weather = weather_for(_seed, cycle_index(), _phase)


static func phase_at(elapsed: float) -> int:
	var t := fposmod(elapsed, CYCLE_SECONDS)
	for p in range(PHASE_SECONDS.size()):
		if t < PHASE_SECONDS[p]:
			return p
		t -= PHASE_SECONDS[p]
	return Phase.NIGHT


## A hash of (seed, cycle, phase) folded onto the weights. Deterministic and cheap; a
## RandomNumberGenerator would be seeded the same way and give the same answer with more
## ceremony.
static func weather_for(seed: int, cycle: int, phase: int) -> int:
	var h := hash(Vector3i(seed, cycle, phase))
	var total := 0
	for w in WEATHER_WEIGHTS:
		total += w
	var roll := int(absi(h) % total)
	for i in range(WEATHER_WEIGHTS.size()):
		if roll < WEATHER_WEIGHTS[i]:
			return i
		roll -= WEATHER_WEIGHTS[i]
	return Weather.CLEAR


static func phase_name(p: int) -> String:
	return PHASE_NAMES[clampi(p, 0, PHASE_NAMES.size() - 1)]


static func weather_name(w: int) -> String:
	return WEATHER_NAMES[clampi(w, 0, WEATHER_NAMES.size() - 1)]


func advance(delta: float) -> void:
	if _pinned or delta <= 0.0:
		return
	set_elapsed(_elapsed + delta)


func set_elapsed(seconds: float) -> void:
	if _pinned:
		return
	_elapsed = maxf(0.0, seconds)
	var new_phase := phase_at(_elapsed)
	var new_weather := weather_for(_seed, cycle_index(), new_phase)
	if new_phase != _phase:
		_phase = new_phase
		phase_changed.emit(_phase)
	if new_weather != _weather:
		_weather = new_weather
		weather_changed.emit(_weather)


func elapsed() -> float:
	return _elapsed


func phase() -> int:
	return _phase


func weather() -> int:
	return _weather


func cycle_index() -> int:
	return int(floor(_elapsed / CYCLE_SECONDS))


## 0 at the start of the current phase, 1 at its end.
func phase_progress() -> float:
	var t := fposmod(_elapsed, CYCLE_SECONDS)
	for p in range(_phase):
		t -= PHASE_SECONDS[p]
	return clampf(t / PHASE_SECONDS[_phase], 0.0, 1.0)


## Freeze at a chosen pair. For gates and renders. The clock stops so a pinned run can
## never write a moved clock back into a save.
func pin(phase_value: int, weather_value: int) -> void:
	_pinned = true
	if phase_value != _phase:
		_phase = phase_value
		phase_changed.emit(_phase)
	if weather_value != _weather:
		_weather = weather_value
		weather_changed.emit(_weather)


func is_pinned() -> bool:
	return _pinned


func describe() -> String:
	return "%s, %s" % [phase_name(_phase), weather_name(_weather)]
